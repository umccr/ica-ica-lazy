#!/usr/bin/env bash

# Generated with perl module App::Spec v0.014

_gds-migrate-v2() {

    COMPREPLY=()
    local IFS=$'\n'
    local program=gds-migrate-v2
    local cur prev words cword
    _init_completion -n : || return
    declare -a FLAGS
    declare -a OPTIONS
    declare -a MYWORDS

    local INDEX=`expr $cword - 1`
    MYWORDS=("${words[@]:1:$cword}")

    FLAGS=('--help' 'Show command help' '-h' 'Show command help')
    OPTIONS=('--src-project' 'The source gds project
' '--src-path' 'The source gds folder path
' '--dest-project' 'The destination gds project
' '--dest-path' 'The destination folder path for the v2 directory
' '--rsync-args' 'Comma separated list of rsync args
' '--stream' 'Stream inputs rather than download into container
')
    __gds-migrate-v2_handle_options_flags

    case ${MYWORDS[$INDEX-1]} in
      --src-project)
        _gds-migrate-v2__option_src_project_completion
      ;;
      --src-path)
        _gds-migrate-v2__option_src_path_completion
      ;;
      --dest-project)
        _gds-migrate-v2__option_dest_project_completion
      ;;
      --dest-path)
        _gds-migrate-v2__option_dest_path_completion
      ;;
      --rsync-args)
      ;;
      --stream)
      ;;

    esac
    case $INDEX in

    *)
        __comp_current_options || return
    ;;
    esac

}

_gds-migrate-v2_compreply() {
    local prefix=""
    cur="$(printf '%q' "$cur")"
    COMPREPLY=($(compgen -P "$prefix" -W "$*" -- "$cur"))
    __ltrim_colon_completions "$prefix$cur"

    # http://stackoverflow.com/questions/7267185/bash-autocompletion-add-description-for-possible-completions
    if [[ ${#COMPREPLY[*]} -eq 1 ]]; then # Only one completion
        COMPREPLY=( "${COMPREPLY[0]%% -- *}" ) # Remove ' -- ' and everything after
        COMPREPLY=( "${COMPREPLY[0]%%+( )}" ) # Remove trailing spaces
    fi
}

_gds-migrate-v2__option_src_project_completion() {
    local CURRENT_WORD="${words[$cword]}"
    local param_src_project="$(
cat "$HOME/.ica-ica-lazy/tokens/tokens.json" | jq -r 'keys[]'
)"
    _gds-migrate-v2_compreply "$param_src_project"
}
_gds-migrate-v2__option_src_path_completion() {
    local CURRENT_WORD="${words[$cword]}"
    local param_src_path="$(
project_index="-1";
project_name="";
if [[ "$(basename "${SHELL}")" == "bash" ]]; then
  for i in "${!words[@]}"; do
     if [[ "${words[$i]}" == "--src-project" ]]; then
         project_index="$(expr $i + 1)";
     fi;
  done;
  project_name="${words[$project_index]}";
elif [[ "$(basename "${SHELL}")" == "zsh" ]]; then
  for ((i = 1; i <= $#words; i++)); do
     if [[ "${words[$i]}" == "--src-project" ]]; then
         project_index="$(expr $i + 1)";
     fi;
  done;
  project_name="${words[$project_index]}";
fi;
if [[ -z "${project_name}" ]]; then
  gds-ls "${CURRENT_WORD}" 2>/dev/null;
else
  ica_access_token="$(jq --raw-output --arg project_name "${project_name}" '.[$project_name] | to_entries[0] | .value' "$HOME/.ica-ica-lazy/tokens/tokens.json")";
  ICA_ACCESS_TOKEN="${ica_access_token}" gds-ls "${CURRENT_WORD}" 2>/dev/null;
fi
)"
    _gds-migrate-v2_compreply "$param_src_path"
}
_gds-migrate-v2__option_dest_project_completion() {
    local CURRENT_WORD="${words[$cword]}"
    local param_dest_project="$(
if [[ -n "${ICAV2_ACCESS_TOKEN-}" ]]; then
  curl --silent --fail --location --request "GET" \
       --url "${ICAV2_BASE_URL-https://ica.illumina.com/ica/rest/}api/projects" \
       --header 'Accept: application/vnd.illumina.v3+json' \
       --header "Authorization: Bearer ${ICAV2_ACCESS_TOKEN}" | \
  jq --raw-output '.items[] | .name'
fi
)"
    _gds-migrate-v2_compreply "$param_dest_project"
}
_gds-migrate-v2__option_dest_path_completion() {
    local CURRENT_WORD="${words[$cword]}"
    local param_dest_path="$(
if [[ -n "${ICAV2_ACCESS_TOKEN-}" ]]; then
    project_index="-1";
    project_name="";
    if [[ "$(basename "${SHELL}")" == "bash" ]]; then
        for i in "${!words[@]}"; do
           if [[ "${words[$i]}" == "--dest-project" ]]; then
               project_index="$(expr $i + 1)";
               project_name="${words[$project_index]}";
           fi;
        done;
    elif [[ "$(basename "${SHELL}")" == "zsh" ]]; then
        for ((i = 1; i <= $#words; i++)); do
           if [[ "${words[$i]}" == "--dest-project" ]]; then
               project_index="$(expr $i + 1)";
               project_name="${words[$project_index]}";
           fi;
        done;
    fi;
  if [[ -n "${project_name}" ]]; then
    project_id="$(curl --silent --fail --location \
                    --request "GET" \
                    --url "${ICAV2_BASE_URL-https://ica.illumina.com/ica/rest/}api/projects" \
                    --header "Accept: application/vnd.illumina.v3+json" \
                    --header "Authorization: Bearer ${ICAV2_ACCESS_TOKEN}" | \
                  jq --raw-output \
                    --arg "project_name" "${project_name}" \
                    '.items[] | select(.name==$project_name) | .id')";
    if [[ "${CURRENT_WORD}" == */ ]]; then
      parent_folder="${CURRENT_WORD}";
    else
      parent_folder="$(dirname "${CURRENT_WORD}")";
    fi;
    curl --silent --fail --location \
      --request "GET" \
      --header "Accept: application/vnd.illumina.v3+json" \
      --header "Authorization: Bearer ${ICAV2_ACCESS_TOKEN}" \
      --url "${ICAV2_BASE_URL-https://ica.illumina.com/ica/rest/}api/projects/${project_id}/data?parentFolderPath=${parent_folder%/}/&filenameMatchMode=EXACT&type=FOLDER" | 
    jq --raw-output \
      '.items[] | .data.details.path';
  fi
fi
)"
    _gds-migrate-v2_compreply "$param_dest_path"
}

__gds-migrate-v2_dynamic_comp() {
    local argname="$1"
    local arg="$2"
    local name desc cols desclength formatted
    local comp=()
    local max=0

    while read -r line; do
        name="$line"
        desc="$line"
        name="${name%$'\t'*}"
        if [[ "${#name}" -gt "$max" ]]; then
            max="${#name}"
        fi
    done <<< "$arg"

    while read -r line; do
        name="$line"
        desc="$line"
        name="${name%$'\t'*}"
        desc="${desc/*$'\t'}"
        if [[ -n "$desc" && "$desc" != "$name" ]]; then
            # TODO portable?
            cols=`tput cols`
            [[ -z $cols ]] && cols=80
            desclength=`expr $cols - 4 - $max`
            formatted=`printf "%-*s -- %-*s" "$max" "$name" "$desclength" "$desc"`
            comp+=("$formatted")
        else
            comp+=("'$name'")
        fi
    done <<< "$arg"
    _gds-migrate-v2_compreply ${comp[@]}
}

function __gds-migrate-v2_handle_options() {
    local i j
    declare -a copy
    local last="${MYWORDS[$INDEX]}"
    local max=`expr ${#MYWORDS[@]} - 1`
    for ((i=0; i<$max; i++))
    do
        local word="${MYWORDS[$i]}"
        local found=
        for ((j=0; j<${#OPTIONS[@]}; j+=2))
        do
            local option="${OPTIONS[$j]}"
            if [[ "$word" == "$option" ]]; then
                found=1
                i=`expr $i + 1`
                break
            fi
        done
        if [[ -n $found && $i -lt $max ]]; then
            INDEX=`expr $INDEX - 2`
        else
            copy+=("$word")
        fi
    done
    MYWORDS=("${copy[@]}" "$last")
}

function __gds-migrate-v2_handle_flags() {
    local i j
    declare -a copy
    local last="${MYWORDS[$INDEX]}"
    local max=`expr ${#MYWORDS[@]} - 1`
    for ((i=0; i<$max; i++))
    do
        local word="${MYWORDS[$i]}"
        local found=
        for ((j=0; j<${#FLAGS[@]}; j+=2))
        do
            local flag="${FLAGS[$j]}"
            if [[ "$word" == "$flag" ]]; then
                found=1
                break
            fi
        done
        if [[ -n $found ]]; then
            INDEX=`expr $INDEX - 1`
        else
            copy+=("$word")
        fi
    done
    MYWORDS=("${copy[@]}" "$last")
}

__gds-migrate-v2_handle_options_flags() {
    __gds-migrate-v2_handle_options
    __gds-migrate-v2_handle_flags
}

__comp_current_options() {
    local always="$1"
    if [[ -n $always || ${MYWORDS[$INDEX]} =~ ^- ]]; then

      local options_spec=''
      local j=

      for ((j=0; j<${#FLAGS[@]}; j+=2))
      do
          local name="${FLAGS[$j]}"
          local desc="${FLAGS[$j+1]}"
          options_spec+="$name"$'\t'"$desc"$'\n'
      done

      for ((j=0; j<${#OPTIONS[@]}; j+=2))
      do
          local name="${OPTIONS[$j]}"
          local desc="${OPTIONS[$j+1]}"
          options_spec+="$name"$'\t'"$desc"$'\n'
      done
      __gds-migrate-v2_dynamic_comp 'options' "$options_spec"

      return 1
    else
      return 0
    fi
}


complete -o default -F _gds-migrate-v2 gds-migrate-v2

