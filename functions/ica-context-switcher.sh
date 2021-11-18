#!/usr/bin/env bash

: '
This file is to be sourced
The function below changes the access token environment variable.
This means you can use this context switcher for running standard ica functions as well
'

ica-context-switcher(){
  : '
  Find / check jq files and then export the ica context switcher env var
  '

  #########
  # GLOCALS
  #########
  local tokens_file_path
  local ica_access_token
  tokens_file_path="$HOME/.ica-ica-lazy/tokens/tokens.json"

  ###########
  # FUNCTIONS
  ###########
  _echo_stderr(){
    : '
    Write to stderr
    '
    echo "$@" 1>&2
  }

  _check_binaries(){
    : '
    Make sure that curl / jq / python3 pass / binary exists in PATH
    '
    if ! (type curl jq python3 1>/dev/null); then
      return 1
    fi
  }

  _check_env_vars(){
    : '
    Make sure that ICA BASE URL is set
    '
    if [[ -z "${ICA_BASE_URL-}" ]]; then
      _echo_stderr "Env var ICA_BASE_URL is not set"
      return 1
    fi
  }

  _print_help(){
  echo "
  Usage ica-context-switcher [--project-name <project-name>] (--scope read-only|admin|contributor)

  Description:
    This program will take a token for this project / scope combination that's stored in '~/.ica-ica-lazy/tokens/tokens.json'

  Options:
    -p / --project-name: Name of project context to enter
    -s / --scope: Scope level to enter, read-only by default

  Requirements:
    * curl
    * jq
    * python3

  Environment variables:
    * ICA_BASE_URL

  "
  }

  _get_access_token(){
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

  # Get args from command line
  while [ $# -gt 0 ]; do
    case "$1" in
      -p | --project-name)
        project_name="$2"
        shift 1
        ;;
      -s | --scope)
        scope="$2"
        shift 1
        ;;
      -h | --help)
        _print_help
        return 0
        ;;
    esac
    shift 1
  done

  # Check args
  if [[ -z "${project_name-}" ]]; then
    _echo_stderr "--project-name not defined"
    _print_help
    return 1
  fi

  if [[ -z "${scope-}" ]]; then
    # Set scope to 'read-only'
    scope="read-only"
  elif [[ "${scope}" != "admin" && "${scope}" != "read-only" && "${scope}" != "contributor" ]]; then
    _echo_stderr "--scope must be one of read-only, contributor or admin"
    _print_help
    return 1
  fi

  # Check available binaries exist
  if ! _check_binaries; then
    _echo_stderr "Please make sure binaries curl, jq and python3 are all available on your PATH variable"
    _print_help
    return 1
  fi

  # Check env vars exist
  if ! _check_env_vars; then
    _echo_stderr "Please make sure the ICA_BASE_URL is set"
    _print_help
    return 1
  fi

  # Check file exists
  if [[ ! -f "${tokens_file_path}" ]]; then
    _echo_stderr "Tokens file path \"${tokens_file_path}\" does not exist, please run \"ica-add-access-token\" first"
  fi

  # Read token file
  ica_access_token="$(_get_access_token "${project_name}" "${scope}" "${tokens_file_path}")"

  if [[ -z "${ica_access_token}" || "${ica_access_token}" == "null" ]]; then
    _echo_stderr "Could not get token for project \"${project_name}\", scope level \"${scope}\". Please first run \"ica-add-access-token\" --project-name \"${project_name}\" --scope \"${scope}\""
    return 1
  fi

  # Export the access token
  ICA_ACCESS_TOKEN="${ica_access_token}"
  export ICA_ACCESS_TOKEN

  _echo_stderr "Successfully switched to ICA project \"${project_name}\" with scope level \"${scope}\""
}

