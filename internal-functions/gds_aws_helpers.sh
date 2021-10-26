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