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

get_workflow_run_history(){
  : '
  Given a workflow id, return the workflow run history of that object (first 1000 items)
  '
  local workflow_run_id="$1"
  local ica_base_url="$2"
  local ica_access_token="$3"

  # Other local vars
  local page_size
  local sort_type

  page_size="1000"
  sort_type="eventId%20asc"

  params="$(
    jq --null-input --raw-output \
      --arg "page_size" "${page_size}" \
      --arg "sort_type" "${sort_type}" \
      '
        {
          "sort": ($sort_type),
          "pageSize": ($page_size)
        } |
        to_entries |
        map(
          "\(.key)=\(.value)"
        ) |
        join("&")
      ' \
  )"

  # Collect and return the history
  curl --silent --fail --location \
    --request GET \
    --url "${ica_base_url}/v1/workflows/runs/${workflow_run_id}/history?${params}" \
    --header "Accept: application/json" \
    --header "Authorization: Bearer ${ica_access_token}" | \
  jq --raw-output
}

clean_history(){
  : '
  Clean up the history of a WES task to return a nice clean summary of tasks spawned
  '
  local history="$1"

  jq --raw-output \
  '
    def get_launch_objects:
      .items |
      map(
        select(
          (
            has("eventDetails")
          ) and
          (
            .eventDetails | length > 0
          ) and
          (
            .eventDetails |
            select(
              has("additionalDetails")
            )
          ) and
          (
            .eventDetails.additionalDetails[0] |
            has("TaskRunId")
          )
        )
      ) |
      map(
        .eventDetails.additionalDetails[0] as $additional_details |
        ($additional_details | .AbsolutePath | sub("_launch$"; "")) as $abs_path |
        {
          ($abs_path): {
            "task_id": ($additional_details | .TaskRunId),
            "task_name": ($abs_path | split("/")[-1]),
            "task_launch_time": .timestamp,
            "task_stderr": ($additional_details | .StdErr),
            "task_stdout": ($additional_details | .StdOut)
          }
        }
      ) | add
    ;
    def get_collection_objects:
      .items |
      map(
        select(
          (
            has("eventDetails")
          ) and
          (
            .eventDetails | length > 0
          ) and
          (
            .eventDetails |
            select(
              has("additionalDetails")
            )
          ) and
          (
            .eventDetails.additionalDetails[0].AbsolutePath |
            endswith("_collect")
          )
        )
      ) |
      map(
        .eventDetails.additionalDetails[0] as $additional_details |
        ($additional_details | .AbsolutePath | sub("_collect$"; "")) as $abs_path |
        {
          ($abs_path): {
            "task_completion_time": .timestamp,
          }
        }
      ) | add
    ;
    (. | get_launch_objects) as $launchers |
    (. | get_collection_objects) as $completers |
    $launchers | keys |
    map(
      . as $key_name |
      {
        ($key_name): (
          [
            $launchers[($key_name)],
            $completers[($key_name)]
          ] |
          add |
          {
            "task_id": .task_id,
            "task_name": .task_name,
            "task_launch_time": .task_launch_time,
            "task_completion_time": .task_completion_time?,
            "task_stdout": .task_stdout,
            "task_stderr": .task_stderr
          }
        )
      }
    )
  ' <<< "${history}"
}