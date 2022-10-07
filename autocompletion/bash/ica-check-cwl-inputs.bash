#!/usr/bin/env bash

# Generated with perl module App::Spec v0.013

_ica-check-cwl-inputs() {

    COMPREPLY=()
    local program=ica-check-cwl-inputs
    local cur prev words cword
    _init_completion -n : || return
    declare -a FLAGS
    declare -a OPTIONS
    declare -a MYWORDS

    local INDEX=`expr $cword - 1`
    MYWORDS=("${words[@]:1:$cword}")

    FLAGS=('--help' 'Show command help' '-h' 'Show command help')
    OPTIONS=('--input-json' 'The WES launch input json
' '--ica-workflow-id' 'The ica workflow id you wish to check inputs against
' '--ica-workflow-version-name' 'The ica workflow version name you wish to check inputs against
')
    __ica-check-cwl-inputs_handle_options_flags

    case ${MYWORDS[$INDEX-1]} in
      --input-json)
        _ica-check-cwl-inputs__option_input_json_completion
      ;;
      --ica-workflow-id)
        _ica-check-cwl-inputs__option_ica_workflow_id_completion
      ;;
      --ica-workflow-version-name)
      ;;

    esac
    case $INDEX in

    *)
        __comp_current_options || return
    ;;
    esac

}

_ica-check-cwl-inputs_compreply() {
    local prefix=""
    local IFS=$'\n'
    cur="$(printf '%q' "$cur")"
    IFS=$'\n' COMPREPLY=($(compgen -P "$prefix" -W "$*" -- "$cur"))
    __ltrim_colon_completions "$prefix$cur"

    # http://stackoverflow.com/questions/7267185/bash-autocompletion-add-description-for-possible-completions
    if [[ ${#COMPREPLY[*]} -eq 1 ]]; then # Only one completion
        COMPREPLY=( "${COMPREPLY[0]%% -- *}" ) # Remove ' -- ' and everything after
        COMPREPLY=( "${COMPREPLY[0]%%+( )}" ) # Remove trailing spaces
    fi
}

_ica-check-cwl-inputs__option_input_json_completion() {
    local CURRENT_WORD="${words[$cword]}"
    local param_input_json="$(find $PWD -name '*.json')"
    _ica-check-cwl-inputs_compreply "$param_input_json"
}
_ica-check-cwl-inputs__option_ica_workflow_id_completion() {
    local CURRENT_WORD="${words[$cword]}"
    local param_ica_workflow_id="$(curl \
  --silent \
  --request GET \
  --header "Authorization: Bearer $ICA_ACCESS_TOKEN" \
  "$ICA_BASE_URL/v1/workflows/?pageSize=1000" | \
jq --raw-output '.items[] | .id')"
    _ica-check-cwl-inputs_compreply "$param_ica_workflow_id"
}

__ica-check-cwl-inputs_dynamic_comp() {
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
    _ica-check-cwl-inputs_compreply ${comp[@]}
}

function __ica-check-cwl-inputs_handle_options() {
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

function __ica-check-cwl-inputs_handle_flags() {
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

__ica-check-cwl-inputs_handle_options_flags() {
    __ica-check-cwl-inputs_handle_options
    __ica-check-cwl-inputs_handle_flags
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
      __ica-check-cwl-inputs_dynamic_comp 'options' "$options_spec"

      return 1
    else
      return 0
    fi
}


complete -o default -F _ica-check-cwl-inputs ica-check-cwl-inputs

