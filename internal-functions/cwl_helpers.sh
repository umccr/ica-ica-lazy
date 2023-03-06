#!/usr/bin/env bash


get_inputs_from_cwl_definition(){
  : '
    Get the inputs objects from the cwl definition object
    First we split by type packed workflows use graphs and
    have the inputs in the last element of the graph array
    commandlinetools just have the inputs in the top key
    we then strip out the "#" from the id.
    if the "id" is not set on the on the cwltool it will have a "main/" prefix, which we strip out
  '

  local packed_cwl_definition="$1"

  jq --raw-output '(
         if (.["$graph"] | length) !=0 then
             .["$graph"] | map(select(.id == ("#main"))) | .[]
         else
             .
         end) |
         .inputs[]' <<< "${packed_cwl_definition}"
}

get_input_block_from_input_name(){
  : '
  Get the input chunk from the input name - matches on id
  '
  # Get inputs
  local input_name="$1"
  local input_json="$2"

  jq --raw-output \
    --arg input_name "${input_name}" \
    'select(.id == ("#" + $input_name) or .id == ("#/main" + $input_name))' <<< "${input_json}"
}

is_input_required(){
  : '
  Given an input chunk, determine it is required
  echo "false" if not required
  echo "true" if required
  '
  # Get inputs
  local input_chunk="$1"

  # Input is optional if type attribute is an array and "null" is in the type array
  jq --raw-output \
      'if ((.type | type == "array") and (.type | any("null"))) then
          "false"
      else
          "true"
      end' <<< "${input_chunk}"
}

get_id_from_input_chunk(){
  : '
  Given an input collect the id and remove the "#" and the "/main" attributes
  '
  local input_chunk="$1"

  jq --raw-output \
    '.id | sub("^#"; "") | sub("^main/"; "")' <<< "${input_chunk}"

}

get_required_inputs_list(){
  : '
  Get a chunk of inputs that are required for the workflow
  '

  # Use nameref
  local -n temp_required_inputs_array="$1"
  local input_json="$2"
  local input_chunks_array
  local input_id

  readarray -t input_chunks_array < <(jq --raw-output --compact-output <<< "${input_json}")

  # Iterate over the input ids, if input is required, then append the id to true
  for input_chunk in "${input_chunks_array[@]}"; do
    input_id="$(get_id_from_input_chunk "${input_chunk}")"
    if [[ "$(is_input_required "${input_chunk}")" == "true" ]]; then
      temp_required_inputs_array+=("${input_id}")
    fi
  done
}

get_class_type(){
  : '
  Get the class type, iterate over flattened inputs, get value of "input_key_stripped"."class"
  '
  local input_key_stripped="$1"
  local flattened_inputs="$2"

  while read -r input_key_val_pair; do
     # Split into keys and values
     input_key="$(cut -d'=' -f1 <<< "${input_key_val_pair}")"
     input_value="$(cut -d'=' -f2 <<< "${input_key_val_pair}")"

     # Get the input value
     if [[ "${input_key}" == "${input_key_stripped}.class" ]]; then
       if [[ "${input_value,,}" == "file"  || "${input_value,,}" == "directory" ]]; then
         # ,, syntax means .tolower()
         echo "gds_${input_value,,}"
       fi
     fi
  done <<< "${flattened_inputs}"
}

check_input_paths_and_locations(){
  : '
  Iterate through inputs, make sure each gds path exists in this context
  '
  local flattened_inputs="$1"
  local ica_workflow_inputs="$2"
  local ica_base_url="$3"
  local ica_access_token="$4"
  local original_required_inputs_array_length
  local all_there=0  # Is everything present?
  local input_key
  local input_key_lstripped
  local input_key_rstripped
  local input_value
  local input_block
  # Assigned in get_required_inputs_list
  # Uses some nameref magic as shown here: https://stackoverflow.com/questions/10582763/how-to-return-an-array-in-bash-without-using-globals
  local required_inputs_array

  # Get required array
  if [[ -n "${ica_workflow_inputs}" ]]; then
    get_required_inputs_list required_inputs_array "${ica_workflow_inputs}"
    original_required_inputs_array_length="${#required_inputs_array[@]}"
  fi

  echo_stderr "Ensuring that all required inputs are present: " "${required_inputs_array[@]}"

  # Iterate through key val pairs
  # Like tumor_fastq_list_rows.0.read_1.location=gds://...
  while read -r input_key_val_pair; do
     # Split into keys and values
     input_key="$(cut -d'=' -f1 <<< "${input_key_val_pair}")"
     # Stripp input key to just get first elmeent umccrise_tsv_rows.0.sv_vcf.path to umccrise_tsv_rows
     input_key_lstripped="$(strip_first_period "${input_key}")"
     # Stripped input key umccrise_tsv_rows.0.sv_vcf.path to just umccrise_tsv_rows.0.sv_vcf
     input_key_rstripped="$(strip_last_period "${input_key}")"
     input_value="$(cut -d'=' -f2 <<< "${input_key_val_pair}")"

     # Check if is part of the inputs?
     if [[ -n "${ica_workflow_inputs}" ]]; then
       input_block="$(get_input_block_from_input_name "${input_key_lstripped}" "${ica_workflow_inputs}")"

       # Check input block is present
       if [[ -z "${input_block}" ]]; then
         echo_stderr "Error! '${input_key}' is not a recognised input of the workflow"
         echo_stderr "Error: got '${input_key_lstripped}'"
         all_there=1
       fi

       # Remove an element from the array
       # As shown here: https://stackoverflow.com/questions/16860877/remove-an-element-from-a-bash-array
       delete_item_from_array required_inputs_array "${input_key_lstripped}"
     fi

     # Check if the input-key ends in .path or .location
     if [[ "${input_key}" =~ .*\.path || "${input_key}" =~ .*\.location ]]; then
       # Get class type
       class_type="$(get_class_type "${input_key_rstripped}" "${flattened_inputs}")"

       # If a directory, make sure it exists
       if [[ "${class_type}" == "gds_directory" && "${input_value}" =~ ^gds://.*  ]]; then
         echo_stderr "Input '${input_key}' is a gds directory at '${input_value}', checking it's present."
         if ! check_folder_exists "${input_key_rstripped}" "${input_value}" "${ica_access_token}" "${ica_base_url}"; then
           echo_stderr "Error! Could not find gds directory '${input_value}' for input '${input_key_rstripped}'"
           all_there=1
         fi
       # If a file, make sure it exists
       elif [[ "${class_type}" == "gds_file" && "${input_value}" =~ ^gds://.* ]]; then
        echo_stderr "Input '${input_key}' is a gds file at '${input_value}' checking it's present."
         if ! check_file_exists "${input_key_rstripped}" "${input_value}" "${ica_access_token}" "${ica_base_url}"; then
           echo_stderr "Error! Could not find gds file '${input_value}' for input '${input_key_rstripped}'"
           all_there=1
         fi
       fi
     fi
  done <<< "${flattened_inputs}"

  # Get length of the required input array
  if [[ -n "${ica_workflow_inputs}" && "${original_required_inputs_array_length}" != 0 && "${#required_inputs_array[@]}" != "0" ]]; then
    echo_stderr "Error! Some required inputs are not satisfied"
    echo_stderr "Error! The following inputs could not be found in the input.json: " "${required_inputs_array[@]}"
    return 1
  fi

  # Return 1 if not all inputs are present on gds otherwise return 0
  if [[ "${all_there}" == 1 ]]; then
    return 1
  else
    return 0
  fi
}

check_input_value(){
  : '
  Check input value
  '
  local inputs="$1"
  local ica_workflow_inputs="$2"
  local ica_base_url="$3"
  local ica_access_token="$4"

  local flattened_inputs

  # Check if inputs are null
  if [[ -z "${inputs}" || "${inputs}" == "null" ]]; then
    echo_stderr "Could not find any inputs, under 'input'. Are you sure you want this?"
    return 0
  fi

  # Flatten input json into .dot format
  flattened_inputs="$(flatten_inputs "${inputs}")"

  # Check paths are present on gds and match input ids in definition on ICA if ica_workflow_inputs is defined
  check_input_paths_and_locations "${flattened_inputs}" "${ica_workflow_inputs}" "${ica_base_url}" "${ica_access_token}"
}
