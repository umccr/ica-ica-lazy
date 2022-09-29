#!/usr/bin/env bash

: '
AWS helpers
'

get_aws_write_file_access(){
  : '
  Get AWS Access tokens for a file
  '
  local volume_name="$1"
  local gds_file_path="$2"
  local base_url="$3"
  local access_token="$4"

  # Other local vars
  local file_name

  # Set file name
  file_name="$(basename "${gds_file_path}")"
  folder_path="$(dirname "${gds_file_path}")"

  # Create a json object as the --data-raw attribute
  body_arg="$( \
    jq --null-input --raw-output \
      --arg "name" "${file_name}" \
      --arg "volume_name" "${volume_name}" \
      --arg "folder_path" "${folder_path}/" \
      --arg "type" "application/json" \
      '
        {
          "name": $name,
          "volumeName": $volume_name,
          "folderPath": $folder_path
        }
      ' \
  )"

  # Pipe curl output into jq to collect ID and return
  file_object="$(curl \
    --silent \
    --request POST \
    --header 'Content-Type: application/json' \
    --header "Authorization: Bearer ${access_token}" \
    --data-raw "${body_arg}" \
    "${base_url}/v1/files?include=objectStoreAccess")"

  # Return access credentials
  jq \
    --raw-output \
    '.objectStoreAccess.awsS3TemporaryUploadCredentials' <<< "${file_object}"
}


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
get_access_key_id_from_credentials() {
  : '
  Returns access_Key_id attribute
  '

  local aws_credentials="$1"

  echo "${aws_credentials}" | jq --raw-output '.access_Key_Id'
}

get_secret_access_key_from_credentials() {
  : '
  Returns secret_Access_Key attribute
  '

  local aws_credentials="$1"

  echo "${aws_credentials}" | jq --raw-output '.secret_Access_Key'
}

get_session_token_from_credentials() {
  : '
  Returns the session_Token attribute
  '

  local aws_credentials="$1"

  echo "${aws_credentials}" | jq --raw-output '.session_Token'
}

get_region_from_credentials() {
  : '
  Returns the region attribute
  '

  local aws_credentials="$1"

  echo "${aws_credentials}" | jq --raw-output '.region'

}

get_bucket_name_from_credentials() {
  : '
  Returns the bucketName attribute
  '

  local aws_credentials="$1"

  echo "${aws_credentials}" | jq --raw-output '.bucketName'

}

get_key_prefix_from_credentials() {
  : '
  Returns the keyPrefix attribute
  '

  local aws_credentials="$1"

  echo "${aws_credentials}" | jq --raw-output '.keyPrefix'

}


