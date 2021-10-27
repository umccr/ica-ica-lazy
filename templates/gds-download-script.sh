#!/usr/bin/env bash

: '
Download files from gds based on presigned urls
'

# Set to fail
set -euo pipefail

# Number of times to try and correctly download a file
MAX_ATTEMPTS=5
AWS_PART_SIZE_IN_MB=8

echo_stderr(){
  : '
  Write output to stderr
  '
  echo "${@}" 1>&2
}

get_base64_binary(){
  if [[ "${OSTYPE}" == "darwin"* ]]; then
    echo "gbase64"
  else
    echo "base64"
  fi
}

get_dd_binary(){
  if [[ "${OSTYPE}" == "darwin"* ]]; then
    echo "gdd"
  else
    echo "dd"
  fi
}

get_sed_binary(){
  if [[ "${OSTYPE}" == "darwin"* ]]; then
    echo "gsed"
  else
    echo "sed"
  fi
}

get_md5sum_binary(){
  if [[ "${OSTYPE}" == "darwin"* ]]; then
    echo "gmd5sum"
  else
    echo "md5sum"
  fi
}

get_stat_binary(){
  if [[ "${OSTYPE}" == "darwin"* ]]; then
    echo "gstat"
  else
    echo "stat"
  fi
}

check_binaries(){
  : '
  Make sure that jq / python3 / wget binary exists in PATH
  '
  if ! (type jq \
             python3 \
             wget \
             get_base64_binary \
             get_dd_binary \
             get_sed_binary \
             get_md5sum_binary \
             get_stat_binary \
             xxd 1>/dev/null); then
    return 1
  fi
}

bytes_to_megabytes(){
  : '
  Get bytes in megabytes
  '
  local bytes="$1"

  python3 -c "print(f'{float(${bytes}/pow(2,20)):f}')"
}

get_filesize_in_bytes(){
  : '
  Get the size of the file in bytes
  '
  local file="$1"

  stat --format "%s" "${file}"
}

get_filesize_in_mb(){
  : '
  Run du command and collect filesize in mb (ceiling)
  '
  # Inputs
  local file="$1"

  # Local vars
  local bytes

  # Get file size in bytes
  bytes="$(get_filesize_in_bytes "${file}")"

  # Convert to megabytes and return
  bytes_to_megabytes "${bytes}"
}

compute_local_etag(){
  : '
  Compute the local etag of the file
  Credit: https://gist.github.com/emersonf/7413337
  '
  local file_path="$1"
  local block_size_mb="$2"

  # Additional local variables
  local file_size_mb
  local num_parts
  local part_iter

  # Calculate filesize
  file_size_mb="$(get_filesize_in_mb "${file_path}")"

  # Number of paths
  num_parts="$(python3 -c "from math import ceil; print(ceil(${file_size_mb} / ${block_size_mb}))")"

  # Check how many parts, we may just need to return the md5sum
  if [[ "${num_parts}" == "1" ]]; then
    "$(get_md5sum_binary)" "${file_path}" | cut -d' ' -f1
    return 0
  fi

  # Otherwise we need to go this in multiple checks
  checksum_file="$(mktemp -t "checksum_file.$(basename "${file_path}").XXX")"

  # Set iter
  part_iter=0

  # Start loop
  while [[ "${part_iter}" -lt "${num_parts}" ]]; do
    # Sections we've already done
    skip="$((block_size_mb * part_iter))"
    "$(get_dd_binary)" \
      bs="$(python3 -c "from math import pow; print(int(pow(2,20)))")" \
      count="${block_size_mb}" \
      skip="${skip}" \
      if="${file_path}" 2>/dev/null | \
    "$(get_md5sum_binary)" >> "${checksum_file}"

    # Iterate
    part_iter="$((part_iter + 1))"
  done

  # Calculate and 'return' etag
  echo "$(xxd -r -p "${checksum_file}" | "$(get_md5sum_binary)")-${num_parts}" | "$(get_sed_binary)" 's%  --%-%'
}


download_file_with_wget(){
  : '
  Download file with wget
  '
  local output_path="$1"
  local presigned_url="$2"

  wget \
    --quiet \
    --output-document "${output_path}" \
   "${presigned_url}"

  return "$?"
}

print_help(){
  echo "
  Usage __SCRIPT_NAME__ (--output-directory <output_directory>)

  Description:
    Download a suite of files from __GDS_PATH__

  Options:
    --output-directory:  Local output path

  Requirements:
    * jq
    * python3
  "
}

output_directory=""

while [ $# -gt 0 ]; do
    case "$1" in
        --output-directory)
            output_directory="$2"
            shift 1
        ;;
        -h|--help)
            print_help
            exit 1
    esac
    shift
done

if [[ -z "${output_directory}" ]]; then
  echo_stderr "Please specify the parameter --output-directory"
  print_help
  exit 1
fi

output_directory="$(python3 -c "from pathlib import Path; print(str(Path('${output_directory}').absolute().resolve()) + '/')")"

if ! check_binaries; then
  echo_stderr "Please ensure jq, python3, wget are installed"
  echo_stderr "For mac users please ensure brew is installed and gnutls is installed with 'brew install gnutls'"
  exit 1
fi

OBJECT_STORE="__OBJECT_STORE_AS_BASE64__"

object_base64_by_line="$(echo "${OBJECT_STORE}" | {
                          # Decode object
                          "$(get_base64_binary)" \
                            --decode
                        })"

# Then reiterate over each and re-decode
# Credit https://www.starkandwayne.com/blog/bash-for-loop-over-json-array-using-jq/
for row in $(echo "${object_base64_by_line}" | jq --raw-output '@base64'); do
  # Get jq
  _jq() {
    echo "${row}" | "$(get_base64_binary)" --decode | jq --raw-output "${1}"
  }

  # Get contents
  presigned_url="$(_jq '.presigned_url')"
  relative_output_path="$(_jq '.output_path')"
  output_path="${output_directory}/${relative_output_path}"
  remote_etag="$(_jq '.etag')"
  remote_filesize="$(_jq '.file_size')"
  remote_timestamp="$(_jq '.time_modified')"  # Not currently used since ica timestamps are slightly off stat %Y value

  # Initialise counter
  iterable=0

  while :; do
    # Make sure we don't continuously go in this loop
    if [[ "${iterable}" -ge "${MAX_ATTEMPTS}" ]]; then
      echo_stderr "Tried ${MAX_ATTEMPTS} times to download file __GDS_PATH__${relative_output_path} to ${output_path} and failed!"
      exit 1
    fi

    # Increment attempt iterable
    iterable="$((iterable + 1))"

    # Download file if it doesn't already exist!
    if [[ ! -f "${output_path}" ]]; then
      # First create output directory
      mkdir -p "$(dirname "${output_path}")"
      echo_stderr "Downloading from __GDS_PATH__${relative_output_path} to ${output_path}"
      if ! download_file_with_wget "${output_path}" "${presigned_url}"; then
        echo_stderr "Error! Could not download __GDS_PATH__${relative_output_path} to ${output_path}"
        continue
      fi
    fi

    # Check filesize with local filesize
    local_filesize="$("$(get_stat_binary)" --format "%s" "${output_path}")"

    if [[ ! "${remote_filesize}" == "${local_filesize}" ]]; then
      echo_stderr "File outputs do not match for local file '${output_path}' and remote file __GDS_PATH__${relative_output_path}."
      echo_stderr "Got ${local_filesize} but expected ${remote_filesize}"
      if ! download_file_with_wget "${output_path}" "${presigned_url}"; then
        echo_stderr "Error! Could not download __GDS_PATH__${relative_output_path} to ${output_path}"
        continue
      fi
    fi

    # Compute etag of local file
    local_etag="$(compute_local_etag "${output_path}" "${AWS_PART_SIZE_IN_MB}")"

    # Compare etags
    if [[ "${local_etag}" == "${remote_etag}" ]]; then
      echo_stderr "Validated locally generated etag '${local_etag}' for file ${output_path} matches remote etag '${remote_etag}' for remote file  __GDS_PATH__${relative_output_path}"
      echo_stderr "Downloaded __GDS_PATH__${relative_output_path} to ${output_path} successfully"
      break
    else
      echo_stderr "File outputs do not match, redownloading, got local etag ${local_etag} expected remote etag ${remote_etag}"
      if ! download_file_with_wget "${output_path}" "${presigned_url}"; then
        echo_stderr "Error! Could not download remote file __GDS_PATH__${relative_output_path} to local file ${output_path}"
        continue
      fi
    fi
  done
done

echo_stderr "Completed download of __GDS_PATH__ to ${output_directory}"
