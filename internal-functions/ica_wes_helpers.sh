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

  # This jq snippet can be experimented with at
  # https://jqplay.org/s/BbdkVIMoUql
  jq --raw-output \
  '
    # Functions
    def get_launch_objects:
      # Collect TaskRunId attributes from history objects
      # Returns a dictionary where each key is defined by the eventDetails.additionalDetails[0].absolutePath attribute

      # Get items that have .eventDetails attribute
      # And that the eventDetails is not a null list
      # And that the eventDetails.additionalDetails is not null
      # And that the first eventDetails.additionalDetails item has a TaskRunId attribute
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

      # Convert items with TaskRunId to a dict with a single key
      # Which is the .eventDetails.additionalDetails[0].AbsolutePath attribute
      # The key has the following dict as a value
      # Key: task_id, Value Description: task run id (trn...)
      # Key: task_name, Value Description: Basename of task step
      # Key: task_launch_time, Value Description: UTC Launch time of task
      # Key: task_stderr, Value Description: GDS Path to task stderr
      # Key: task_stdout, Value Description: GDS Path to task stdout
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
      ) |
      # Merge list of dictionaries together
      add
    ;
    def get_collection_objects:
      # Get item objects that end in _collect
      # These define when a task has finished
      # Returns a dictionary where each key is defined by the eventDetails.additionalDetails[0].absolutePath attribute
      .items |
      # Filter items by
      # has non empty eventDetails attribute
      # And has eventDetails.additionalDetails attribute
      # And eventDetails.additionalDetails[0].AbsolutePath attribute endswith "_collect"
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

      # Collect the task completion time
      # And the task status
      # Convert items to a dict with a single key
      # Which is the .eventDetails.additionalDetails[0].AbsolutePath attribute
      # The key has the following dict as a value
      # Key: "task_completion_time", Value Description: UTC time of task collection
      # Key: "task_status", One of "Failed" or "Succeeded"
      map(
        # Set the additionalDetails dict as variable $additional_details
        .eventDetails.additionalDetails[0] as $additional_details |
        # Set the event type (Failed or Succeeded) as $event_type
        .eventType? as $event_type |
        # Set the absolutePath with the _collect suffix removed as $abs_path
        ($additional_details | .AbsolutePath | sub("_collect$"; "")) as $abs_path |

        # Return a dictionary with a single key $abs_path
        # With the following dict as a value
        # Key: "task_completion_time", Value Description: UTC time of task collection
        {
          ($abs_path): {
            "task_completion_time": .timestamp,
            "task_status": $event_type,
          }
        }
      ) |
      # Merge dictionaries together
      add
    ;
    # Start process
    # Return a list of tasks launched with their associated metadata

    # Collect launch items
    (. | get_launch_objects) as $launchers |

    # Collect completion items
    (. | get_collection_objects) as $completers |

    # Iterate through launch items by key
    $launchers | keys |

    # For each launch item key
    # Collect the launch item dict
    # And then collect the completion dict of the same key
    # And merge the dictionaries together
    map(
      # Set key name to variable $key_name
      . as $key_name |
      # Output an object with a single key which is the launch item key name
      {
        # Create an object with the launch item key name as the key
        ($key_name): (
          [
            $launchers[($key_name)],
            $completers[($key_name)]
          ] |
          # Merge dictionaries together
          add |
          # Write out the value of the launch item key name as a dict
          # In the following order
          {
            "task_id": .task_id,
            "task_name": .task_name,
            "task_launch_time": .task_launch_time,
            "task_completion_time": .task_completion_time?,
            "task_status": .task_status?,
            "task_stdout": .task_stdout,
            "task_stderr": .task_stderr
          }
        )
      }
    ) |
    # Add all tasks together
    add |
    # Then sort by timestamp
    to_entries |
    sort_by(
      .value.task_launch_time
    ) |
    from_entries
  ' <<< "${history}"
}