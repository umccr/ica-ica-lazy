#!/usr/bin/env bash

: '
* ica base url
'

# Globals
TOKEN_FILE_PATH="${ICA_ICA_LAZY_HOME}/tokens/tokens.json"

# Scopes
ADMIN_SCOPE_STRING="BSSH.RUNS.READ,DCS.USAGES.READ,ENS.SUBSCRIPTIONS.MANAGE,GDS.FILES.ARCHIVE,GDS.FILES.CREATE,GDS.FILES.DELETE,GDS.FILES.DOWNLOAD,GDS.FILES.READ,GDS.FILES.UPDATE,GDS.FOLDERS.ARCHIVE,GDS.FOLDERS.CREATE,GDS.FOLDERS.DELETE,GDS.FOLDERS.GRANT,GDS.FOLDERS.READ,GDS.FOLDERS.UPDATE,GDS.VOLUMES.ARCHIVE,GDS.VOLUMES.CREATE,GDS.VOLUMES.DELETE,GDS.VOLUMES.GRANT,GDS.VOLUMES.READ,GDS.VOLUMES.UPDATE,IMS.ASSETS.READ,IMS.ASSETVERSIONS.READ,IMS.INSTRUMENTS.CREATE,IMS.INSTRUMENTS.DELETE,IMS.INSTRUMENTS.GRANT,IMS.INSTRUMENTS.READ,IMS.INSTRUMENTS.UPDATE,TES.RUNS.CREATE,TES.RUNS.DELETE,TES.RUNS.GRANT,TES.RUNS.READ,TES.RUNS.UPDATE,TES.TASKS.CREATE,TES.TASKS.DELETE,TES.TASKS.GRANT,TES.TASKS.READ,TES.TASKS.UPDATE,TES.VERSIONS.CREATE,TES.VERSIONS.DELETE,TES.VERSIONS.GRANT,TES.VERSIONS.READ,TES.VERSIONS.UPDATE,WES.RUNS.CREATE,WES.RUNS.DELETE,WES.RUNS.GRANT,WES.RUNS.READ,WES.RUNS.UPDATE,WES.SIGNALS.CREATE,WES.SIGNALS.DELETE,WES.SIGNALS.GRANT,WES.SIGNALS.READ,WES.SIGNALS.UPDATE,WES.VERSIONS.CREATE,WES.VERSIONS.DELETE,WES.VERSIONS.GRANT,WES.VERSIONS.READ,WES.VERSIONS.UPDATE,WES.WORKFLOWS.CREATE,WES.WORKFLOWS.DELETE,WES.WORKFLOWS.GRANT,WES.WORKFLOWS.READ,WES.WORKFLOWS.UPDATE"
READ_ONLY_SCOPE_STRING="BSSH.RUNS.READ,DCS.USAGES.READ,ENS.SUBSCRIPTIONS.MANAGE,GDS.FILES.DOWNLOAD,GDS.FILES.READ,GDS.FOLDERS.GRANT,GDS.FOLDERS.READ,GDS.VOLUMES.READ,IMS.INSTRUMENTS.READ,TES.RUNS.READ,TES.TASKS.READ,TES.VERSIONS.READ,WES.RUNS.READ,WES.SIGNALS.READ,WES.VERSIONS.READ,WES.WORKFLOWS.READ"


strip_path_from_base_url() {
  : '
  Base url should not contain any path content. We use python3 urlparse to return just the scheme and netloc.
  '
  local base_url="$1"
  # Returns the path attribute of base_url input
  python3 -c "from urllib.parse import urlparse; print(urlparse(\"${base_url}\").scheme + \"://\" + urlparse(\"${base_url}\").netloc)"
}


get_volume_name(){
  : '
  Get the volume name from the gds path
  '
  # Get inputs
  local gds_path="$1"

  # Function outputs
  python3 -c "from urllib.parse import urlparse; print(urlparse(\"${gds_path}\").netloc)"
}

get_path(){
  : '
  Get the path attribute from the gds path
  '
  local gds_path="$1"

  # Function outputs
  python3 -c "from urllib.parse import urlparse; print(str(urlparse(\"${gds_path}\").path).rstrip(\"/\") + \"/\")"
}


get_folder_parent_from_folder_path() {
  : '
  Returns the gds folder parent name from the folder path
  '
  local gds_folder_path="$1"
  python3 -c "from pathlib import Path; print(Path(\"${gds_folder_path}\").parent)"
}

get_folder_name_from_folder_path() {
  : '
  Returns the gds folder name from the folder path
  '
  local gds_folder_path="$1"
  python3 -c "from pathlib import Path; print(Path(\"${gds_folder_path}\").name)"
}

get_project_id_from_project_name(){
  : '
  Checks that the project exists from the personal context
  and returns the project id
  '

  local project_name="$1"
  local personal_access_token="$2"
  local projects_list_obj

  # List project objects
  projects_list_obj="$(curl \
                         --silent \
                         --location \
                         --fail \
                         --request GET \
                         --url "${ICA_BASE_URL}/v1/projects" \
                         --header "Authorization: Bearer ${personal_access_token}")"

  # Although we don't actually use the project id
  project_id="$(jq --raw-output \
                   --arg project_name "${project_name}" \
                   '.items[] | select(.name==$project_name) | .id' \
                   <<< "${projects_list_obj}")"

  # Get the project id from the project name
  if [[ -z "${project_id}" || "${project_id}" == "null" ]]; then
    echo_stderr "Could not get the project id from the project name \"${project_name}\""
    return 1
  fi

  # Return the project id
  echo "${project_id}"
}

create_personal_access_token(){
  : '
  Create a personal access token
  '
  local ica_base_url="$1"

  local token_obj

  token_obj="$(curl \
                 --silent \
                 --location \
                 --fail \
                 --request POST \
                 --url "${ica_base_url}/v1/tokens" \
                 --header "Accept: application/json" \
                 --header "X-API-Key: $(get_default_api_key)" \
                 --header "Content-Length: 0")"

  # Return the access token attribute
  jq --raw-output \
    '.access_token' \
    <<< "${token_obj}"
}

create_project_token(){
  : '
  Creates an ica access token for a given project
  '
  local project_id="$1"
  local scope="$2"
  local ica_base_url="$3"
  local personal_access_token="$4"

  local token_obj

  token_obj="$(curl \
                 --silent \
                 --location \
                 --fail \
                 --request POST \
                 --url "${ica_base_url}/v1/tokens" \
                 --header "Accept: application/json" \
                 --header "Content-Length: 0" \
                 --header "X-API-Key: $(get_default_api_key)" \
                 --header "Authorization: Bearer ${personal_access_token}" \
                 --get \
                 --data "cid=${project_id}" \
                 --data "scopes=$(get_scope_string "${scope}")")"

  # Return the access token attribute
  jq --raw-output \
    '.access_token' \
    <<< "${token_obj}"
}

# Get scope string based on different use cases
get_scope_string(){
  : '
  Return the scopes based on the users desired access level
  '
  local scope_level="$1"
  local scope

  if [[ "${scope_level}" == "read-only" ]]; then
    echo "${READ_ONLY_SCOPE_STRING}"
  elif [[ "${scope_level}" == "admin" ]]; then
    echo "${ADMIN_SCOPE_STRING}"
  fi
}

# Personal access token functions
get_default_api_key(){
  : '
  Gets the api key by calling ~/.ica-ica-lazy/get_api_key.sh in users password store
  '
  "${ICA_ICA_LAZY_HOME}/get_api_key.sh" 2>/dev/null
}


add_token_to_json_file(){
  : '
  Adds the token to the json file
  '
  local project_name="$1"
  local scope="$2"
  local project_access_token="$3"

  # Get directory
  mkdir -p "$(dirname "${TOKEN_FILE_PATH}")"
  chmod 700 "$(dirname "${TOKEN_FILE_PATH}")"

  if [[ ! -f "${TOKEN_FILE_PATH}" ]]; then
    in_json="{}"
  else
    in_json="$(cat "${TOKEN_FILE_PATH}")"
  fi

  # Import file and add to list
  tokens_obj="$(jq \
                  --raw-output \
                  --arg project_name "${project_name}" \
                  --arg scope "${scope}" \
                  --arg project_access_token "${project_access_token}" \
                  '.[$project_name][$scope] = $project_access_token' <<< "${in_json}")"

  # Write token object back out to file
  echo "${tokens_obj}" > "${TOKEN_FILE_PATH}"

  # Change permissions on file
  chmod 600 "${TOKEN_FILE_PATH}"
}

get_access_token(){
  : '
  Check the level of the scope
  '
  # Func inputs
  local project_name="$1"
  local scope="$2"
  local tokens_file_path="$3"

  local in_json
  local project_access_token
  in_json="$(cat "${tokens_file_path}")"
  project_access_token="$(jq \
                            --raw-output \
                            --arg project_name "${project_name}" \
                            --arg scope "${scope}" \
                          '.[$project_name][$scope]' <<< "${in_json}")"
  echo "${project_access_token}"
}

get_tokens_path(){
  : '
  Return the tokens path from the ica-ica-lazy home var
  '

  local ica_ica_lazy_home="$1"

  echo "${ica_ica_lazy_home}/tokens/tokens.json"

}