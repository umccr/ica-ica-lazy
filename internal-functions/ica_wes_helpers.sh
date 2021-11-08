#!/usr/bin/env bash

: '
ICA WES helper scripts

'

MAX_PAGE_SIZE=1000

get_workflow_run_ids(){
  : '
  Get the list of workflow run ids
  '
  local status="$1"
  local ica_base_url="$2"
  local ica_access_token="$3"

  local response
  local next_page_token
  local url
  local data_params

  # Initalise next_page_token and set url
  next_page_token="null"
  url="${ica_base_url}/v1/workflows/runs"

  while :; do
    data_params=( "--data" "pageSize=${MAX_PAGE_SIZE}"
                  "--data" "sort=timeCreated+desc"
                  "--data" "include=totalItemCount" )

    if [[ ! "${status}" == "all" ]]; then
      data_params+=( "--data" "status=${status}" )
    fi

    # Check next token
    if [[ ! "${next_page_token}" == "null" ]]; then
      data_params+=( "--data" "pageToken=${next_page_token}" )
    fi


    response="$(curl \
                  --silent \
                  --fail \
                  --location \
                  --request GET \
                  --header "Accept: application/json" \
                  --header "Authorization: Bearer ${ica_access_token}" \
                  --url "${url}" \
                  --get \
                  "${data_params[@]}")"

    # Print existing items
    jq --raw-output --compact-output '.items[] | .id' <<< "${response}"

    # Assign token
    next_page_token="$(jq -r '.nextPageToken' <<< "${response}")"

    # Break if no more items
    if [[ "${next_page_token}" == "null" ]]; then
      break
    fi
  done
}

get_engine_parameters_from_workflow_id(){
  : '
  Use engine parameters to pull down the workflow
  '
  local ica_workflow_run_id="$1"
  local ica_base_url="$2"
  local ica_access_token="$3"
  curl \
    --silent \
    --fail \
    --location \
    --request GET \
    --header "Authorization: Bearer ${ica_access_token}" \
    "${ica_base_url}/v1/workflows/runs/${ica_workflow_run_id}/?include=engineParameters" | \
  jq \
    --raw-output \
    '.engineParameters // empty | fromjson'
}

get_definition_from_ica(){
  : '
  Use curl to pull down the packed cwl defintion of the workflow
  '

  local ica_workflow_id="$1"
  local ica_workflow_version_name="$2"
  local ica_base_url="$3"
  local ica_access_token="$4"
  curl \
    --silent \
    --request GET \
    --header "Authorization: Bearer ${ica_access_token}" \
    "${ica_base_url}/v1/workflows/${ica_workflow_id}/versions/${ica_workflow_version_name}" |
  jq \
    --raw-output \
    '.definition | fromjson'
}

check_name_value(){
  : '
  Check name value
  '
  local name_value="$1"

  if [[ "${name_value}" =~ [^a-zA-Z0-9_-\.] ]]; then
    echo_stderr "Name must be a-zA-Z0-9_-, please don't put in spaces or symbols"
    return 1
  fi
}

check_engine_parameters(){
  : '
  Check the engine parameters
  '
  local engine_parameters="$1"

  # Check if inputs are null
  if [[ -z "${engine_parameters}" || "${engine_parameters}" == "null" || "$(jq 'keys | length' <<< "${engine_parameters}")" == "0" ]]; then
    echo_stderr "Could not find any engine parameters, under 'engineParameters'"
    echo_stderr "For future runs, I would recommend setting outputDirectory and workDirectory."
  fi

  return 0
}