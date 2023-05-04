#!/usr/bin/env bash

: '
V2 helpers
'

icav2_get_project_id_from_project_name() {
  : '
  Get project id from project name
  '
  # Input variables
  project_name="$1"
  icav2_base_url="$2"
  icav2_access_token="$3"

  curl --silent --fail --location --request "GET" \
    --url "${icav2_base_url}/api/projects" \
    --header 'Accept: application/vnd.illumina.v3+json' \
    --header "Authorization: Bearer ${icav2_access_token}" | \
  jq --raw-output \
    --arg "project_name" "${project_name}" \
    '.items[] | select(.name==$project_name) | .id'
}

get_v2_folder_id() {
  : '
  Get folder id from folder name
  '

  # Get inputs
  project_id="$1"
  folder_path="$2"
  icav2_base_url="$3"
  dest_project_access_token="$4"

  # Vars
  local parent_folder_path

  # Get parent folder path
  parent_folder_path="$(dirname "${folder_path}")"

  # Add '/' to suffix - but keep as just '/' if root
  parent_folder_path="${parent_folder_path%/}/"

  curl --silent --fail --location \
    --request "GET" \
    --header "Accept: application/vnd.illumina.v3+json" \
    --header "Authorization: Bearer ${dest_project_access_token}" \
    --get \
    --url "${icav2_base_url}/api/projects/${project_id}/data" \
    --data "$( \
      jq --null-input --raw-output --compact-output \
        --arg parent_folder_path "${parent_folder_path}" \
        --arg filename "$(basename "${folder_path}")" \
        --arg filename_match_mode "EXACT" \
        --arg data_type "FOLDER" \
        '{
            "parentFolderPath": $parent_folder_path,
            "filename": $filename,
            "filenameMatchMode": $filename_match_mode,
            "type": $data_type
        } |
        to_entries |
        map("\(.key)=\(.value)") |
        join("&")'
    )" | \
    jq --raw-output \
      '.items[] | .data.id'
}


create_v2_folder() {
  : '
  Get folder id from folder name
  '
  # Get inputs
  project_id="$1"
  folder_path="$2"
  icav2_base_url="$3"
  project_access_token="$4"

  # Vars
  local parent_folder_path

  # Get parent folder path
  parent_folder_path="$(dirname "${folder_path}")"

  # Add '/' to suffix - but keep as just '/' if root
  parent_folder_path="${parent_folder_path%/}/"

  curl --silent --fail --location \
    --request "POST" \
    --header "Accept: application/vnd.illumina.v3+json" \
    --header 'Content-Type: application/vnd.illumina.v3+json' \
    --header "Authorization: Bearer ${project_access_token}" \
    --url "${icav2_base_url}/api/projects/${project_id}/data" \
    --data "$( \
      jq --null-input --raw-output --compact-output \
        --arg parent_folder_path "${parent_folder_path}" \
        --arg name "$(basename "${folder_path}")" \
        --arg data_type "FOLDER" \
        '{
            "name": $name,
            "folderPath": $parent_folder_path,
            "dataType": $data_type
        }'
      )" | \
    jq --raw-output \
      '.data.id'
}

create_v2_file(){
  : '
  Create v2 file in a project.

  Return the id of the file
  '

  # Get inputs
  project_id="$1"
  file_path="$2"
  icav2_base_url="$3"
  project_access_token="$4"

  # Vars
  local parent_folder_path

  # Get parent folder path
  parent_folder_path="$(dirname "${file_path}")"

  # Add '/' to suffix - but keep as just '/' if root
  parent_folder_path="${parent_folder_path%/}/"

  curl --silent --fail --location \
    --request "POST" \
    --header "Accept: application/vnd.illumina.v3+json" \
    --header 'Content-Type: application/vnd.illumina.v3+json' \
    --header "Authorization: Bearer ${project_access_token}" \
    --url "${icav2_base_url}/api/projects/${project_id}/data" \
    --data "$( \
      jq --null-input --raw-output --compact-output \
        --arg parent_folder_path "${parent_folder_path}" \
        --arg name "$(basename "${file_path}")" \
        --arg data_type "FILE" \
        '{
            "name": $name,
            "folderPath": $parent_folder_path,
            "dataType": $data_type
        }'
      )" | \
    jq --raw-output \
      '.data.id'
}

get_v2_file_presigned_url_from_file_id(){
  : '
  Get a v2 presigned url from a file id
  '

  # Get v2 object and return the id
  project_id="$1"
  data_id="$2"
  icav2_base_url="$3"
  project_access_token="$4"

  curl --silent --fail --location \
    --request "POST" \
    --header "Accept: application/vnd.illumina.v3+json" \
    --header "Authorization: Bearer ${project_access_token}" \
    --url "${icav2_base_url}/api/projects/${project_id}/data/${data_id}:createDownloadUrl" | \
  jq --raw-output \
    '.url'
}

get_v2_file_upload_presigned_url_from_file_id(){
  : '
  Get a v2 presigned url from a file id
  '

  # Get v2 object and return the id
  project_id="$1"
  data_id="$2"
  icav2_base_url="$3"
  project_access_token="$4"

  curl \
    --request "POST" \
    --header "Accept: application/vnd.illumina.v3+json" \
    --header "Authorization: Bearer ${project_access_token}" \
    --url "${icav2_base_url}/api/projects/${project_id}/data/${data_id}:createUploadUrl" | \
  jq --raw-output \
    '.url'
}

v2_upload_file_to_presigned_url(){
  : '
  Upload file to presigned url using curl
  '

  # Upload file with presigned url
  file_path="$1"
  presigned_url="$2"

  curl --silent --fail --location \
    --upload-file "${file_path}" \
    "${presigned_url}"
}


get_v2_folder_aws_credentials(){
  : '
  Get a v2 presigned url from a file id
  '

  # Get v2 object and return the id
  project_id="$1"
  data_id="$2"
  icav2_base_url="$3"
  project_access_token="$4"

  curl --silent --fail --location \
    --request "POST" \
    --header "Accept: application/vnd.illumina.v3+json" \
    --header "Content-Type: application/vnd.illumina.v3+json" \
    --header "Authorization: Bearer ${project_access_token}" \
    --url "${icav2_base_url}/api/projects/${project_id}/data/${data_id}:createTemporaryCredentials" | \
  jq --raw-output \
    '.awsTempCredentials'
}


#!/usr/bin/env bash

: '

'

get_aws_access_creds_from_folder_id() {
  : '
  Use folders list on the folder and collect the folder id from the single item
  '
  local folder_id="$1"
  local ica_base_url="$2"
  local ica_access_token="$3"
  local aws_credentials=""

  # https://ica-docs.readme.io/reference#updatefolder expects
  # --header 'Content-Type: application/*+json'
  # We're not actually patching anything, we're just getting some temporary credss
  curl \
    --silent \
    --request PATCH \
    --header 'Accept: application/json' \
    --header 'Content-Type: application/*+json' \
    --header "Authorization: Bearer ${ica_access_token}" \
    "${ica_base_url}/v1/folders/${folder_id}?include=objectStoreAccess" | {
    # We take the S3 upload creds
    # Even though we're downloading only, aws s3 sync needs the put request param
    jq \
      --raw-output \
      '.objectStoreAccess.awsS3TemporaryUploadCredentials'
  }

}

# Credential get functions
get_access_key_id_from_v2_credentials() {
  : '
  Returns access_Key_id attribute
  '

  local aws_credentials="$1"

  echo "${aws_credentials}" | jq --raw-output '.accessKey'
}

get_secret_access_key_from_v2_credentials() {
  : '
  Returns secret_Access_Key attribute
  '

  local aws_credentials="$1"

  echo "${aws_credentials}" | jq --raw-output '.secretKey'
}

get_session_token_from_v2_credentials() {
  : '
  Returns the session_Token attribute
  '

  local aws_credentials="$1"

  echo "${aws_credentials}" | jq --raw-output '.sessionToken'
}

get_region_from_v2_credentials() {
  : '
  Returns the region attribute
  '

  local aws_credentials="$1"

  echo "${aws_credentials}" | jq --raw-output '.region'

}

get_bucket_name_from_v2_credentials() {
  : '
  Returns the bucketName attribute
  '

  local aws_credentials="$1"

  echo "${aws_credentials}" | jq --raw-output '.bucket'

}

get_key_prefix_from_v2_credentials() {
  : '
  Returns the keyPrefix attribute
  '

  local aws_credentials="$1"

  echo "${aws_credentials}" | jq --raw-output '.objectPrefix'

}