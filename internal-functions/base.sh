#!/usr/bin/env bash

: '
Basic functions

* echo_stderr

'

echo_stderr(){
  : '
  Print output to stderr
  '
  echo "$@" 1>&2
}

get_parent_path(){
  : '
  Take the path input as a python lib and then return the parent (with a trailing slash)
  '

  local gds_path_attr="$1"

  python3 -c "from pathlib import Path; print(str(Path(\"${gds_path_attr}\").parent).rstrip(\"/\") + \"/\")"
}

# Check destination path
check_download_path(){
  local dest_path="$1"

  if [[ ! -d "$(dirname "${dest_path}")" ]]; then
    echo_stderr "Error \"${dest_path}\". Output path's parent must exist"
    return 1
  fi
}

# Check destination path
check_src_path(){
  local src_path="$1"
  if [[ ! -d "${src_path}" ]]; then
    echo_stderr "Error could not find \"${src_path}\". --src path must exist as a file or folder"
    return 1
  fi
}

flatten_inputs(){
  : '
  Get the flattened inputs object as a . based flattened output
  Much credit to this snippet for flattening arrays in jq
  https://gist.github.com/olih/f7437fb6962fb3ee9fe95bda8d2c8fa4#gistcomment-3045352
  '
  jq --raw-output '[
         . as $in |
         (paths(scalars), paths((. | length == 0)?)) |
         join(".") as $key |
         $key + "=" + ($in | getpath($key | split(".") | map((. | tonumber)? // .)) | tostring)
       ] |
       sort |
       .[]' <<< "$1"
}

strip_first_period(){
  : '
  Equivalent of split(".", 1)[0] in python
  '
  local input_key="$1"
  cut -d'.' -f1 <<< "${input_key}"
}

strip_last_period(){
  : '
  Equivalent of rsplit(".", 1)[0] in python
  '
  local input_key="$1"
  # This is gross, I am sorry
  # sed is greedy, so the first (.*) will match as much as it can
  "$(get_sed_binary)" -r "s/(.*)\.(.*)/\1/" <<< "${input_key}"
}

delete_item_from_array(){
  : '
  Delete an item from array
  '
  local -n input_array="$1"
  local input_value="$2"
  local input_del_array=( "${input_value}" )

  for target in "${input_del_array[@]}"; do
    for i in "${!input_array[@]}"; do
      if [[ "${input_array[${i}]}" == "${target}" ]]; then
        unset "input_array[${i}]"
      fi
    done
  done
}