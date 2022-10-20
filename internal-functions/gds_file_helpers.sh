#!/usr/bin/env bash

: '
File Helpers

* get_volume_from_gds_path
* get_folder_path_from_gds_path
* get_workflow_run_ids

'

MAX_PAGE_SIZE=1000

get_volume_from_gds_path() {
  : '
  Assumes urllib is available on python3
  '
  local gds_path="$1"

  # Returns the netloc attribute of the gds_path
  python3 -c "from urllib.parse import urlparse; print(urlparse(\"${gds_path}\").netloc)"
}

get_directory_as_disk_usage(){
  : '
  Returns output as sizeInBytes\tpath
  '
  local volume_name="$1"
  local gds_path_attr="$2"
  local ica_base_url="$3"
  local ica_access_token="$4"

  local params
  local next_page_token="null"
  local page_size="1000"
  local page_number="0"
  local total_item_count="0"

  while :; do
    params="$(  \
      jq --null-input --raw-output \
        --arg volume_name "${volume_name}" \
        --arg path "${gds_path_attr}*" \
        --arg recursive "true" \
        --arg total_item_count "totalItemCount" \
        --arg next_page_token "${next_page_token}" \
        --arg page_size "${page_size}" \
        '
          {
            "volume.name": $volume_name,
            "path": $path,
            "recursive": $recursive,
            "pageToken": $next_page_token,
            "pageSize": $page_size,
            "include": $total_item_count
          } |
          to_entries |
          map(
            select(.value == "null" | not)
          ) |
          map(
            "\(.key)=\(.value)"
          ) |
          join("&")
        ' \
    )"

    response="$( \
      curl \
        --fail --silent --location \
        --header "Accept: application/json" \
        --header "Authorization: Bearer ${ica_access_token}" \
        --url "${ica_base_url}/v1/files?${params}"
    )"

    # Print outputs
    jq --raw-output \
      '
        .items |
        map(
          select(
            .sizeInBytes == null |
            not
          )
        ) |
        map(
          {
            "sizeInKb": ((.sizeInBytes / 1024) | floor),
            "path": .path
          }
        ) |
        map(
          "\(.sizeInKb)\t\(.path)"
        ) |
        .[]
      ' <<< "${response}"

    next_page_token="$( \
      jq --raw-output '.nextPageToken' <<< "${response}"
    )"

    if [[ "${next_page_token}" == "null" ]]; then
      break
    else
      # Report number of files to go
      total_item_count="$( \
        jq --raw-output '.totalItemCount' <<< "${response}"
      )"
      page_number=$((page_number+1))
      echo_stderr "Collected $((page_number * page_size)) of ${total_item_count} files"
    fi

  done
}

# Get folder path
get_folder_path_from_gds_path() {
  : '
  Assumes urllib is available on python3
  '
  local gds_path="$1"

  # Returns the path attribute of gds_path input
  python3 -c "from urllib.parse import urlparse; from pathlib import Path; print(str(Path(urlparse(\"${gds_path}\").path)).rstrip(\"/\") + \"/\")"
}

get_folder_id(){
  : '
  Check if the current path is a folder by first listing the folders in the parent path
  and searching for this folder
  '

  local volume_name="$1"
  local gds_path_attr="$2"
  local ica_base_url="$3"
  local ica_access_token="$4"

  local data_params=( "--data" "volume.name=${volume_name}"
                      "--data" "recursive=false"
                      "--data" "pageSize=${MAX_PAGE_SIZE}" )

  if [[ -z "${gds_path_attr}" || "${gds_path_attr}" == "/" ]]; then
    # Check volume exists
    if ! check_volume "${volume_name}" "${ica_base_url}" "${ica_access_token}"; then
      return 1
    else
      return 0
    fi
  fi


  if [[ -n "${gds_path_attr}" && "${gds_path_attr}" != "/" ]]; then
    data_params+=( "--data" "path=$(get_parent_path "${gds_path_attr}")*" )
  fi

  if ! folders_obj="$(curl \
                        --silent \
                        --location \
                        --fail \
                        --request GET \
                        --header "Authorization: Bearer ${ica_access_token}" \
                        --url "${ica_base_url}/v1/folders" \
                        --get \
                        "${data_params[@]}" 2>/dev/null)"; then
    return 1
  fi

  if [[ "$(jq \
            --raw-output \
            --arg "gds_path_attr" "${gds_path_attr}" \
            '.items[] | select ( .path == $gds_path_attr ) | .path' <<< "${folders_obj}")" != "${gds_path_attr}" ]]; then
      return 1
  fi

  jq \
    --raw-output \
    --arg "gds_path_attr" "${gds_path_attr}" \
    '.items[] | select ( .path == $gds_path_attr ) | .id' <<< "${folders_obj}"
}

get_folder_creator_username(){
  : '
  Given the id of a folder, return the user name of the creator of that folder.
  This is achieved by running a get on the folder path, followed by
  a get on the createdBy id on the accounts api
  '

  local folder_id="$1"
  local ica_base_url="$2"
  local ica_access_token="$3"

  local creator_account_id

  creator_account_id="$(curl \
                         --silent \
                         --location \
                         --fail \
                         --request GET \
                         --header "Accept: application/json" \
                         --header "Authorization: Bearer ${ica_access_token}" \
                         --url "${ica_base_url}/v1/folders/${folder_id}" | \
                       jq \
                         --raw-output \
                         '.createdBy')"

  # Use accounts endpoint with creator account id
  curl \
    --silent \
    --location \
    --fail \
    --request GET \
    --header "Accept: application/json" \
    --header "Authorization: Bearer ${ica_access_token}" \
    --url "${ica_base_url}/v1/accounts/${creator_account_id}" | \
  jq \
    --raw-output \
    '.name'
}

check_volume(){
  : '
  Confirm the volume exists
  '
  local volume_name="$1"
  local ica_base_url="$2"
  local ica_access_token="$3"

  if ! curl \
         --silent \
         --location \
         --fail \
         --request GET \
         --header 'Accept: application/json' \
         --header "Authorization: Bearer ${ica_access_token}" \
         --url "${ica_base_url}/v1/volumes/${volume_name}" \
         --get >/dev/null 2>&1; then
    return 1
  else
    return 0
  fi
}

check_path_is_folder(){
  : '
  Check if the current path is a folder by first listing the folders in the parent path
  and searching for this folder
  '

  local volume_name="$1"
  local gds_path_attr="$2"
  local ica_base_url="$3"
  local ica_access_token="$4"

  local data_params=( "--data" "volume.name=${volume_name}"
                      "--data" "recursive=false"
                      "--data" "pageSize=${MAX_PAGE_SIZE}" )

  if [[ -z "${gds_path_attr}" || "${gds_path_attr}" == "/" ]]; then
    # Check volume exists
    if ! check_volume "${volume_name}" "${ica_base_url}" "${ica_access_token}"; then
      return 1
    else
      return 0
    fi
  fi


  if [[ -n "${gds_path_attr}" && "${gds_path_attr}" != "/" ]]; then
    data_params+=( "--data" "path=$(get_parent_path "${gds_path_attr}")*" )
  fi

  if ! folders_obj="$(curl \
                        --silent \
                        --location \
                        --fail \
                        --request GET \
                        --header "Authorization: Bearer ${ica_access_token}" \
                        --url "${ica_base_url}/v1/folders" \
                        --get \
                        "${data_params[@]}" 2>/dev/null)"; then
    return 1
  fi

  if [[ "$(jq \
            --raw-output \
            --arg "gds_path_attr" "${gds_path_attr}" \
            '.items[] | select ( .path == $gds_path_attr ) | .path' <<< "${folders_obj}")" != "${gds_path_attr}" ]]; then
      return 1
  fi
}

get_gds_file_list_as_digestible(){
  : '
  Return a list of gds files with the following attributes
  * presigned_url
  * output_path
  * etag
  * file_size

  Where output_path has the gds_path_attr component stripped by sed and then return in compact-output format
  for base64 ingestion
  '
  local volume_name="$1"
  local gds_path_attr="$2"
  local recursive="$3"
  local ica_base_url="$4"
  local ica_access_token="$5"
  local all_files_obj
  local files_obj
  local files
  local next_page_token
  local data_params

  next_page_token="null"
  all_files_obj="[]"

  while :; do
    data_params=( "--data" "volume.name=${volume_name}"
                  "--data" "recursive=${recursive}"
                  "--data" "pageSize=${MAX_PAGE_SIZE}"
                  "--data" "include=presignedUrl"
                  "--data" "path=${gds_path_attr}*" )
    if [[ ! "${next_page_token}" == "null" ]]; then
      data_params+=( "--data" "pageToken=${next_page_token}" )
    fi
    # Response
    response="$(curl \
                   --silent \
                   --location \
                   --fail \
                   --request GET \
                   --header "Authorization: Bearer ${ica_access_token}" \
                   --url "${ica_base_url}/v1/files" \
                   --get \
                   "${data_params[@]}"  2>/dev/null)"

    # Assign token
    next_page_token="$(jq -r '.nextPageToken' <<< "${response}")"

    files_obj="$(jq \
                  --raw-output \
                  '.items[] |
                    {
                       "presigned_url": .presignedUrl,
                       "output_path": .path,
                       "etag": .eTag,
                       "file_size": .sizeInBytes,
                       "time_modified": .timeModified
                    }' <<< "${response}" | {
                   # Strip to the relative path
                   "$(get_sed_binary)" "s%\"output_path\": \"${gds_path_attr}%\"output_path\": \"%"
                 } | {
                   # Append to the existing and get output as compact
                   jq \
                     --raw-output \
                     --compact-output
                 })"
    all_files_obj="$(jq 'flatten' --raw-output --slurp <<< "${all_files_obj}${files_obj}")"
    # Break if no more items
    if [[ "${next_page_token}" == "null" ]]; then
      break
    fi
  done

  # Write output line by line
  jq --raw-output '.[]' <<< "${all_files_obj}"
}

get_gds_file_names(){
  : '
  list the files of the path that match
  '
  local volume_name="$1"
  local gds_path_attr="$2"
  local name="$3"
  local recursive="$4"
  local ica_base_url="$5"
  local ica_access_token="$6"
  local files_obj
  local files

  files_obj="$(curl \
                 --silent \
                 --location \
                 --fail \
                 --request GET \
                 --header "Authorization: Bearer ${ica_access_token}" \
                 --url "${ica_base_url}/v1/files" \
                 --get \
                 --data "volume.name=${volume_name}" \
                 --data "recursive=${recursive}" \
                 --data "pageSize=${MAX_PAGE_SIZE}" \
                 --data "path=${gds_path_attr}*" 2>/dev/null)"

  files="$(jq --raw-output \
             --arg "volume_name" "${volume_name}" \
             --arg "name" "${name}" \
             '.items[] | select(.name | test($name)) | "gds://\($volume_name)\(.path)"' <<< "${files_obj}")"

  printf "%s" "${files}" | sort -f
}

get_gds_subfolder_names(){
  : '
  list the files and the subfolders of the path that match
  '
  local volume_name="$1"
  local gds_path_attr="$2"
  local name="${3-}"
  local ica_base_url="$4"
  local ica_access_token="$5"
  local folders_obj
  local folders

  # Get folders and files
  folders_obj="$(curl \
                   --silent \
                   --location \
                   --fail \
                   --request GET \
                   --header "Authorization: Bearer ${ica_access_token}" \
                   --url "${ica_base_url}/v1/folders" \
                   --get \
                   --data "volume.name=${volume_name}" \
                   --data "recursive=false" \
                   --data "pageSize=${MAX_PAGE_SIZE}" \
                   --data "path=${gds_path_attr}*" 2>/dev/null)"

  if [[ -z "${name}" ]]; then
    # We're returning the path
    jq --compact-output --raw-output \
      '.items[] | .path' <<< "${folders_obj}"
  else
    # We're printing the outputs with the volume name included
    folders="$(jq --raw-output \
                 --arg "volume_name" "${volume_name}" \
                 --arg "name" "${name}" \
                 '.items[] | select(.name|test($name)) | "gds://\($volume_name)\(.path)"' <<< "${folders_obj}")"
    "$(get_printf_binary)" "%s" "${folders}" | sort -f
  fi
}

gds_search(){
  : '
  Recursively list and print all files / directories with the existing dirs
  '
  local volume_name="$1"
  local folder_path="$2"
  local depth="$3"
  local mindepth="$4"
  local maxdepth="$5"
  local type="$6"
  local name="$7"
  local ica_base_url="$8"
  local ica_access_token="$9"
  local subfolder_paths_array=()

  # Check we haven't depthed too far
  if [[ "${maxdepth}" != "-1" && "${maxdepth}" -le "${depth}" ]]; then
    # We've gone too far
    return 0
  fi

  # If we're within 'range' of printing files / dirs, then do so
  if [[ ( "${mindepth}" == "-1" || "${mindepth}" -le "${depth}" ) && ( "${maxdepth}" == "-1" || "${depth}" -le "${maxdepth}" ) ]]; then
    if [[ "${type}" == "directory" ]]; then
      get_gds_subfolder_names "${volume_name}" "${folder_path}" "${name}" "${ica_base_url}" "${ica_access_token}"
    else
      get_gds_file_names "${volume_name}" "${folder_path}" "${name}" "false" "${ica_base_url}" "${ica_access_token}"
    fi
  fi

  # We're still not beyond the maximum depth
  depth="$(expr "${depth}" + 1)"

  # Recollect the array of subfolders
  readarray -t subfolder_paths_array < <(get_gds_subfolder_names "${volume_name}" "${folder_path}" "" "${ica_base_url}" "${ica_access_token}")

  # Iterate through array
  for subfolder_path in "${subfolder_paths_array[@]}"; do
    # echo_stderr "Checking folder gds://${volume_name}/${subfolder_path}"  # FIXME - add in as a debug parameter
    gds_search "${volume_name}" "${subfolder_path}" "${depth}" "${mindepth}" "${maxdepth}" "${type}" "${name}" "${ica_base_url}" "${ica_access_token}"
  done
}

print_volumes(){
  : '
  Print list of volumes
  '
  local ica_base_url="$1"
  local ica_access_token="$2"

  curl \
      --silent \
      --location \
      --fail \
      --request GET \
      --header "Authorization: Bearer ${ica_access_token}" \
      --url "${ica_base_url}/v1/volumes" \
      --get \
      --data "pageSize=${MAX_PAGE_SIZE}" 2>/dev/null | \
  jq --raw-output \
    '.items[] | "gds://\(.name)"'
}

print_files_and_subfolders(){
  : '
  list the files and the subfolders of the path that match
  '

  local volume_name="$1"
  local gds_path_attr="$2"
  local ica_base_url="$3"
  local ica_access_token="$4"

  # Get folders and files
  folders_obj="$(curl \
                   --silent \
                   --location \
                   --fail \
                   --request GET \
                   --header "Authorization: Bearer ${ica_access_token}" \
                   --url "${ica_base_url}/v1/folders" \
                   --get \
                   --data "volume.name=${volume_name}" \
                   --data "recursive=false" \
                   --data "pageSize=${MAX_PAGE_SIZE}" \
                   --data "path=${gds_path_attr}*" 2>/dev/null)"

  files_obj="$(curl \
                 --silent \
                 --location \
                 --fail \
                 --request GET \
                 --header "Authorization: Bearer ${ica_access_token}" \
                 --url "${ica_base_url}/v1/files" \
                 --get \
                 --data "volume.name=${volume_name}" \
                 --data "recursive=false" \
                 --data "pageSize=${MAX_PAGE_SIZE}" \
                 --data "path=${gds_path_attr}*" 2>/dev/null)"

  # Get jq items
  folders="$(jq \
              --raw-output \
              --arg "volume_name" "${volume_name}" \
              '.items[] | "gds://\($volume_name)\(.path)"' <<< "${folders_obj}")"
  files="$(jq \
            --raw-output \
            --arg "volume_name" "${volume_name}" \
            '.items[] | "gds://\($volume_name)\(.path)"' <<< "${files_obj}")"

  # Write out files and folders but sort on print
  if [[ -z "${files}" && -z "${folders}" ]]; then
    echo ""
  elif [[ -z "${files}" ]]; then
    echo "${folders}" | sort -f
  elif [[ -z "${folders}" ]]; then
    echo "${files}" | sort -f
  else
    printf "%s\n%s" "${files}" "${folders}" | sort -f
  fi
}

create_gds_folder() {
  : '
  Create a gds folder and get temporary access credentials too
  '
  local volume_name="$1"
  local folder_parent="$2"
  local folder_name="$3"
  local base_url="$4"
  local access_token="$5"

  # Create a json object as the --data-raw attribute
  body_arg="$(jq --raw-output \
                 --arg "volumeName" "${volume_name}" \
                 --arg "folderPath" "${folder_parent}/" \
                 --arg "name" "${folder_name}" \
                 '. | .["volumeName"]=$volumeName | .["folderPath"]=$folderPath | .["name"]=$name' <<< '{}'
            )"

  # Pipe curl output into jq to collect ID and return
  curl \
    --silent \
    --request POST \
    --header 'Content-Type: application/json' \
    --header "Authorization: Bearer ${access_token}" \
    --data-raw "${body_arg}" \
    "${base_url}/v1/folders" |
    jq \
      --raw-output \
      '.id'
}

get_file_path_from_gds_path(){
  : '
  Assumes urllib is available on python3
  '
  local gds_path="$1"
  # Returns the path attribute of gds_path input
  python3 -c "from urllib.parse import urlparse; print(urlparse(\"${gds_path}\").path)"
}

get_file_id(){
  : '
  Use files list on the file and collect the file id from the single item
  '
  local volume_name="$1"
  local file_path="$2"
  local base_url="$3"
  local access_token="$4"

  # Pipe curl output into jq to collect ID and return
  curl \
    --silent \
    --request GET \
    --header "Authorization: Bearer ${access_token}" \
    "${base_url}/v1/files?volume.name=${volume_name}&path=${file_path}" | \
  jq \
    --raw-output \
    '.items[] | .id'
}

get_presigned_url_from_file_id(){
  : '
  Use files list on the file and collect the file id from the single item
  '
  local file_id="$1"
  local base_url="$2"
  local access_token="$3"

  curl \
    --silent \
    --request GET \
    --header "Authorization: Bearer ${access_token}" \
    "${base_url}/v1/files/${file_id}" | \
  jq \
    --raw-output \
    '.presignedUrl'
}

check_folder_exists(){
  : '
  Check that the input folder exists
  folder checking is a little more complex than file checking, need to run an ica folders list on the folder itself and
  then get the folder id
  # TODO - test this bit
  '
  local input_key_stripped="$1"
  local input_value="$2"
  local ica_access_token="$3"
  local ica_base_url="$4"
  local volume_name
  local folder_path

  volume_name="$(get_volume_from_gds_path "${input_value}")"
  folder_path="$(get_folder_path_from_gds_path "${input_value}")"

  # Return the folder id
  folder_id="$(curl \
                 --silent \
                 --request GET \
                 --header "Authorization: Bearer ${ica_access_token}" \
                 "${ica_base_url}/v1/folders?volume.name=${volume_name}&path=${folder_path}" |
               jq \
                 --raw-output \
                 '.items[] | .id')"

  if [[ -z "${folder_id}" || "${folder_id}" == "null" ]]; then
    echo_stderr "Could not get folder id for \"${input_value}\""
    return 1
  fi
}

check_file_exists(){
  : '
  Check that the input file exists
  '
  local input_key_stripped="$1"
  local input_value="$2"
  local ica_access_token="$3"
  local ica_base_url="$4"
  local volume_name
  local file_path

  volume_name="$(get_volume_from_gds_path "${input_value}")"
  file_path="$(get_file_path_from_gds_path "${input_value}")"

  # Return the folder id
  file_id="$(curl \
                 --silent \
                 --request GET \
                 --header "Authorization: Bearer ${ica_access_token}" \
                 "${ica_base_url}/v1/files?volume.name=${volume_name}&path=${file_path}" |
               jq \
                 --raw-output \
                 '.items[] | .id')"

  if [[ -z "${file_id}" || "${file_id}" == "null" ]]; then
    echo_stderr "Could not get file id for \"${input_value}\""
    return 1
  fi
}

upload_gds_file(){
  : '
  Upload a file to gds
  '
  local volume_name="$1"
  local gds_file_path="$2"
  local local_file_path="$3"
  local base_url="$4"
  local access_token="$5"

  # Other local vars
  local local_file_name

  # Check file exists
  if ! [[ -f "${local_file_path}" ]]; then
    echo_stderr "Could not confirm ${local_file_path} exists"
    return 1
  fi

  # File name
  local_file_name="$(python3 -c "from pathlib import Path; print(Path('${local_file_path}').name)")"

  # Create a json object as the --data-raw attribute
  body_arg="$(jq --raw-output \
                 --arg "name" "${local_file_name}" \
                 --arg "volumeName" "${volume_name}" \
                 --arg "folderPath" "${gds_file_path}/" \
                 --arg "type" "application/json" \
                 '. | .["name"]=$name | .["volumeName"]=$volumeName | .["folderPath"]=$folderPath' <<< '{}'
            )"

  # Pipe curl output into jq to collect ID and return
  file_object="$(curl \
    --silent \
    --request POST \
    --header 'Content-Type: application/json' \
    --header "Authorization: Bearer ${access_token}" \
    --data-raw "${body_arg}" \
    "${base_url}/v1/files?include=objectStoreAccess")"

  aws_upload_creds="$(jq \
      --raw-output \
      '.objectStoreAccess.awsS3TemporaryUploadCredentials' <<< "${file_object}")"

  # Get creds
  access_key_id="$(get_access_key_id_from_credentials "${aws_upload_creds}")"
  secret_access_key="$(get_secret_access_key_from_credentials "${aws_upload_creds}")"
  session_token="$(get_session_token_from_credentials "${aws_upload_creds}")"
  region="$(get_region_from_credentials "${aws_upload_creds}")"
  bucket_name="$(get_bucket_name_from_credentials "${aws_upload_creds}")"
  key_prefix="$(get_key_prefix_from_credentials "${aws_upload_creds}")"

  # Upload file
  if ! AWS_ACCESS_KEY_ID="${access_key_id}" \
       AWS_SECRET_ACCESS_KEY="${secret_access_key}" \
       AWS_SESSION_TOKEN="${session_token}" \
       AWS_REGION="${region}" \
       aws s3 cp "${local_file_path}" "s3://${bucket_name}/${key_prefix}" 1>&2; then
    return 1
  fi

  # Otherwise return the file id
  jq --raw-output '.id' <<< "${file_object}"
}