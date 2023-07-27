#!/usr/bin/env bash

flatten_inputs_from_launch_json(){
  : '
  Returns a flatten list of inputs
  '
  local launch_json_str="$1"
  local inputs

  inputs="$( \
    jq --raw-output \
      '
        .input
      ' <<< "${launch_json_str}"
  )"

  # Check if inputs are null
  if [[ -z "${inputs}" || "${inputs}" == "null" ]]; then
    echo_stderr "Could not find any inputs"
    return 1
  fi

  # Flatten input json into .dot format
  flatten_inputs "${inputs}"
}


presign_flatten_inputs(){
  : '
  Find files inputs, returns key val pairing of gds path and presigned url
  '

  flattened_inputs="$1"

  # Iterate through key val pairs
  # Like tumor_fastq_list_rows.0.read_1.location=gds://...
  while read -r input_key_val_pair; do
     # Split into keys and values
     input_key="$(cut -d'=' -f1 <<< "${input_key_val_pair}")"
     # Strip input key to just get first element umccrise_tsv_rows.0.sv_vcf.path to umccrise_tsv_rows
     input_key_lstripped="$(strip_first_period "${input_key}")"
     # Stripped input key umccrise_tsv_rows.0.sv_vcf.path to just umccrise_tsv_rows.0.sv_vcf
     input_key_rstripped="$(strip_last_period "${input_key}")"
     input_value="$(cut -d'=' -f2 <<< "${input_key_val_pair}")"

     class_type="$(get_class_type "${input_key_rstripped}" "${flattened_inputs}")"
     # Check if the input-key ends in .path or .location
     if [[ "${input_key}" =~ .*\.path || "${input_key}" =~ .*\.location ]]; then
        # Get class type
        class_type="$(get_class_type "${input_key_rstripped}" "${flattened_inputs}")"
        if [[ "${class_type}" == "gds_file" && "${input_value}" =~ ^gds://.* ]]; then
          echo_stderr "Input '${input_key}' is a gds file at '${input_value}' presigning"
          volume_name="$(get_volume_from_gds_path "${input_value}")"
          file_path="$(get_file_path_from_gds_path "${input_value}")"
          input_file_id="$( \
            get_file_id \
              "${volume_name}" \
              "${file_path}" \
              "${ICA_BASE_URL}" \
              "${ICA_ACCESS_TOKEN}" \
          )"
          presigned_url="$( \
            get_presigned_url_from_file_id \
              "${input_file_id}" \
              "${ICA_BASE_URL}" \
              "${ICA_ACCESS_TOKEN}" \
          )"
          jq --null-input --raw-output \
            --arg "gds_path" "${input_value}" \
            --arg "presigned_url" "${presigned_url}" \
            '
              {
                "key": $gds_path,
                "value": $presigned_url
              }
            '
        fi
     fi
  done <<< "${flattened_inputs}" | \
  jq --raw-output --compact-output --slurp \
    '
     .[]
    '
}

