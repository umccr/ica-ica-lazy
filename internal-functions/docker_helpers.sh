#!/usr/bin/env bash

check_port_not_in_use(){
  : '
  Check port not in use
  '

  # Check port doesn't have an existing container running on it
  iterable=0
  max_iterable=10

  while :; do
    # Don't go through an infinite loop!
    iterable=$(("${iterable}" + 1))
    if [[ "${iterable}" -ge "${max_iterable}" ]]; then
      echo_stderr "Tried 10 ports, all of them are full!"
      exit 1
    fi

    # Check if port is in use - podman doesn't support the --publish filter
    if [[ "$(get_docker_binary)" == "docker" && "$(docker ps --filter publish="${port}" --quiet | "$(get_wc_binary)" -l)" == "0" ]]; then
      # Port not in use!
      break
    elif [[ "$(get_docker_binary)" == "podman" && "$(podman ps --format "{{.Ports}}" | "$(get_sed_binary)" -r 's%^[0-9|\.]+\:([0-9]+)->[0-9]+\/tcp$%\1%' | grep -c "^${port}$")" == "0" ]]; then
      # Port not in use!
      break
    fi

    # Iterate port by one
    echo_stderr "Port ${port} in use, trying $(("${port}" + 1))"
    port="$(("${port}" + 1))"
  done

  echo "${port}"
}
