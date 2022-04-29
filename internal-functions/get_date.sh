#!/usr/bin/env bash

: '
Functions to ensure that ica-access-token is not expired

* get_epoch_expiry
* get_seconds_to_expiry
* warn_time_to_expiry
'

SECONDS_PER_WEEK="604800"

get_epoch_expiry(){
  : '
  Get the epoch value of the expiry date of the tokens
  '
  local access_token="$1"
  echo "${access_token}" | \
    "$(get_sed_binary)" -r 's/^(\S+)\.(\S+)\.(\S+)$/\2/' | \
    ( "$(get_base64_binary)" --decode 2>/dev/null || true ) | \
  jq --raw-output \
    '.exp'
}

get_seconds_to_expiry(){
  : '
  Get seconds to expiry based on epoch time
  '
  local expiry_epoch="$1"
  bc <<< "${expiry_epoch} - $("$(get_date_binary)" +%s)"
}

warn_time_to_expiry(){
  : '
  Convert the epoch time to expiry to a readable date format
  '
  local expiry_in_seconds="$1"

  python3 -c "from datetime import timedelta; from sys import stderr; \
              time_to_expiry=timedelta(seconds=${expiry_in_seconds}); \
              d = {'days': time_to_expiry.days}; \
              d['hours'], rem = divmod(time_to_expiry.seconds, 3600); \
              d['minutes'], d['seconds'] = divmod(rem, 60); \
              print('Expired') if ${expiry_in_seconds} < 0 \
              else print(f\"Warning: Your ica access token will end in {d['days']} days, {d['hours']} hours, {d['minutes']} minutes, {d['seconds']} seconds\", file=stderr)"
}

check_token_expiry(){
  : '
  Return the expiry in printable format
  '
  # Inputs
  local access_token="$1"

  # local vars
  local epoch_expiry
  local seconds_to_expiry

  # Get the JWT token expiry time
  epoch_expiry="$(get_epoch_expiry "${access_token}")"

  # Compare expiry to current time
  seconds_to_expiry="$(get_seconds_to_expiry "${epoch_expiry}")"

  # Check token expiry
  if [[ "${seconds_to_expiry}" -le 0 ]]; then
    # Token has expired
    echo_stderr "Error - Your access token has expired! Please refresh with 'ica-add-access-token'"
    exit 1
  elif [[ "${seconds_to_expiry}" -le "${SECONDS_PER_WEEK}" ]]; then
    # Warn user token expires in less than a week
    echo_stderr "$(warn_time_to_expiry "${seconds_to_expiry}")"
  fi
}

get_print_time_to_expiry_from_access_token(){
  : '
  Return the expiry in printable format
  '
  # Inputs
  local access_token="$1"

  # local vars
  local epoch_expiry
  local seconds_to_expiry

  # Get the JWT token expiry time
  epoch_expiry="$(get_epoch_expiry "${access_token}")"

  # Compare expiry to current time
  seconds_to_expiry="$(get_seconds_to_expiry "${epoch_expiry}")"

  # Return print version
  print_time_to_expiry "${seconds_to_expiry}"
}

print_time_to_expiry(){
  : '
  Convert the epoch time to expiry to a readable date format
  '
  local expiry_in_seconds="$1"

  python3 -c "from datetime import timedelta; \
              time_to_expiry=timedelta(seconds=${expiry_in_seconds}); \
              d = {'days': time_to_expiry.days}; \
              d['hours'], rem = divmod(time_to_expiry.seconds, 3600); \
              d['minutes'], d['seconds'] = divmod(rem, 60); \
              print('Expired') if ${expiry_in_seconds} < 0 \
              else print(f\"{d['days']} days, {d['hours']} hours, {d['minutes']} minutes, {d['seconds']} seconds\")"
}
