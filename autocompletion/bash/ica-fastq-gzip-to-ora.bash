#!/usr/bin/env bash

# Generated with perl module App::Spec v0.000

_ica-fastq-gzip-to-ora() {

    COMPREPLY=()
    local program=ica-fastq-gzip-to-ora
    local cur prev words cword
    _init_completion -n : || return
    declare -a FLAGS
    declare -a OPTIONS
    declare -a MYWORDS

    local INDEX=`expr $cword - 1`
    MYWORDS=("${words[@]:1:$cword}")

    FLAGS=()
    OPTIONS=('--input-path' 'The input path
' '--output-path' 'The output path
' '--ora-reference-path' 'The ora reference path
' '--compression-type' 'The type of compression used
' '--help' 'Print help
')
    __ica-fastq-gzip-to-ora_handle_options_flags

    case ${MYWORDS[$INDEX-1]} in
      --input-path)
        _ica-fastq-gzip-to-ora__option_input_path_completion
      ;;
      --output-path)
        _ica-fastq-gzip-to-ora__option_output_path_completion
      ;;
      --ora-reference-path)
        _ica-fastq-gzip-to-ora__option_ora_reference_path_completion
      ;;
      --compression-type)
        _ica-fastq-gzip-to-ora_compreply "dragen" "dragen-interleaved"
        return
      ;;
      --help)
      ;;

    esac
    case $INDEX in

    *)
        __comp_current_options || return
    ;;
    esac

}

_ica-fastq-gzip-to-ora_compreply() {
    local prefix=""
    local IFS=$'\n'
    cur="$(printf '%q' "$cur")"
    IFS=$IFS COMPREPLY=($(compgen -P "$prefix" -W "$*" -- "$cur"))
    __ltrim_colon_completions "$prefix$cur"

    # http://stackoverflow.com/questions/7267185/bash-autocompletion-add-description-for-possible-completions
    if [[ ${#COMPREPLY[*]} -eq 1 ]]; then # Only one completion
        COMPREPLY=( "${COMPREPLY[0]%% -- *}" ) # Remove ' -- ' and everything after
        COMPREPLY=( "${COMPREPLY[0]%%+( )}" ) # Remove trailing spaces
    fi
}

_ica-fastq-gzip-to-ora__option_input_path_completion() {
    local CURRENT_WORD="${words[$cword]}"
    local param_input_path="$(
gds-ls "${CURRENT_WORD}" 2>/dev/null
)"
    _ica-fastq-gzip-to-ora_compreply "$param_input_path"
}
_ica-fastq-gzip-to-ora__option_output_path_completion() {
    local CURRENT_WORD="${words[$cword]}"
    local param_output_path="$(
gds-ls "${CURRENT_WORD}" 2>/dev/null
)"
    _ica-fastq-gzip-to-ora_compreply "$param_output_path"
}
_ica-fastq-gzip-to-ora__option_ora_reference_path_completion() {
    local CURRENT_WORD="${words[$cword]}"
    local param_ora_reference_path="$(
gds-ls "${CURRENT_WORD}" 2>/dev/null
)"
    _ica-fastq-gzip-to-ora_compreply "$param_ora_reference_path"
}

__ica-fastq-gzip-to-ora_dynamic_comp() {
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
    _ica-fastq-gzip-to-ora_compreply ${comp[@]}
}

function __ica-fastq-gzip-to-ora_handle_options() {
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

function __ica-fastq-gzip-to-ora_handle_flags() {
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

__ica-fastq-gzip-to-ora_handle_options_flags() {
    __ica-fastq-gzip-to-ora_handle_options
    __ica-fastq-gzip-to-ora_handle_flags
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
      __ica-fastq-gzip-to-ora_dynamic_comp 'options' "$options_spec"

      return 1
    else
      return 0
    fi
}


complete -o default -F _ica-fastq-gzip-to-ora ica-fastq-gzip-to-ora

