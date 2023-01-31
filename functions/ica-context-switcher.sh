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
  local SCOPES_ARRAY

  tokens_file_path="$HOME/.ica-ica-lazy/tokens/tokens.json"
  SCOPES_ARRAY=( "read-only" "admin" )

  ###########
  # FUNCTIONS
  ###########
  _echo_stderr(){
    : '
    Write to stderr
    '
    echo "$@" 1>&2
  }

  _get_base64_binary(){
    if [[ "${OSTYPE}" == "darwin"* ]]; then
      echo "gbase64"
    else
      echo "base64"
    fi
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
  Usage ica-context-switcher (--project-name <project-name>) [--scope read-only|admin]

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

  _check_project_in_tokens_file_path(){
    : '
    Check that the project exists in the token file path
    '

    # Func inputs
    local project_name="$1"
    local tokens_file_path="$2"

    return "$( \
      jq \
        --raw-output \
        --arg project_name "${project_name}" \
        '
          keys as $keys |
          if ( $project_name | IN($keys[]) ) then
            "0"
          else
            "1"
          end
        ' < "${tokens_file_path}"
    )"
  }

  _get_access_token(){
    : '
    Return the JWT access token
    '

    # Func inputs
    local project_name="$1"
    local scope="$2"
    local tokens_file_path="$3"

    jq \
      --raw-output \
      --arg project_name "${project_name}" \
      --arg scope "${scope}" \
      '
        .[$project_name][$scope]
      ' < "${tokens_file_path}"

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

  # Check tokens path file exists
  if [[ ! -f "${tokens_file_path}" ]]; then
    _echo_stderr "Tokens file path \"${tokens_file_path}\" does not exist, please run \"ica-add-access-token\" first"
  fi

  # Check project exists in tokens path
  if ! _check_project_in_tokens_file_path "${project_name}" "${tokens_file_path}"; then
    _echo_stderr "Project '${project_name}' does not exist in tokens file path"
  fi

  # Check scope exists
  if [[ -z "${scope-}" ]]; then
    # Check available scopes (first checking default scope) then checking
    for scope in "${SCOPES_ARRAY[@]}"; do
      ica_access_token="$( \
        _get_access_token \
          "${project_name}" \
          "${scope}" \
          "${tokens_file_path}" \
      )"
      if [[ -n "${ica_access_token}" && "${ica_access_token}" != "null" ]]; then
        _echo_stderr "Scope not specified and token for scope '${scope}' is defined so using this token"
        break
      fi
    done
  elif [[ "${scope}" != "admin" && "${scope}" != "read-only" ]]; then
    _echo_stderr "--scope must be one of read-only or admin"
    _print_help
    return 1
  else
    # Read token file anduse scope as specified in cli
    ica_access_token="$(_get_access_token "${project_name}" "${scope}" "${tokens_file_path}")"
  fi

  if [[ -z "${ica_access_token}" || "${ica_access_token}" == "null" ]]; then
    _echo_stderr "Could not get token for project \"${project_name}\", scope level \"${scope}\". Please first run \"ica-add-access-token\" --project-name \"${project_name}\" --scope \"${scope}\""
    return 1
  fi

  # Poor man's token expiry
  #  This logic appears to be breaking in zsh
  #  token_expiry="$( \
  #    {
  #      # Print token to /dev/stdin
  #      echo "${ica_access_token}"
  #    } | {
  #      # Collect second attribute
  #      cut -d'.' -f2
  #    } | {
  #      # Need to wrap this bit in a || true statement
  #      # Since Illumina tokens aren't padded
  #      (
  #        "$(_get_base64_binary)" --decode 2>/dev/null || true
  #      )
  #    } | {
  #      jq --raw-output '.exp'
  #    } \
  #  )"

  token_expiry="$( \
    echo "${ica_access_token}" | \
    cut -d'.' -f2 | \
    (
      "$(_get_base64_binary)" --decode 2>/dev/null || true
    ) | \
    jq --raw-output '.exp' \
  )"

  # Current time
  current_epoch_time="$(date "+%s")"

  if [[ "${token_expiry}" -lt "${current_epoch_time}" ]]; then
    _echo_stderr "Token found but has expired, please run 'ica-add-access-token --scope \"${scope}\" --project-name \"${project_name}\"' and then rerun this command"
    return 1
  fi

  # Export the access token
  ICA_ACCESS_TOKEN="${ica_access_token}"
  export ICA_ACCESS_TOKEN

  # Let user know run was successful
  _echo_stderr "Successfully switched to ICA project \"${project_name}\" with scope level \"${scope}\""
}

