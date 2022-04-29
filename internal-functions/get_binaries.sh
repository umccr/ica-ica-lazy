#!/usr/bin/env bash

get_docker_binary(){
  if type docker 1>/dev/null 2>&1; then
    echo "docker"
  else
    echo "podman"
  fi
}

get_base64_binary(){
  if [[ "${OSTYPE}" == "darwin"* ]]; then
    echo "gbase64"
  else
    echo "base64"
  fi
}

get_date_binary(){
  if [[ "${OSTYPE}" == "darwin"* ]]; then
    echo "gdate"
  else
    echo "date"
  fi
}

get_mktemp_binary(){
  if [[ "${OSTYPE}" == "darwin"* ]]; then
    echo "gmktemp"
  else
    echo "mktemp"
  fi
}

get_printf_binary(){
  if [[ "${OSTYPE}" == "darwin"* ]]; then
    echo "gprintf"
  else
    echo "printf"
  fi
}

get_sed_binary(){
  if [[ "${OSTYPE}" == "darwin"* ]]; then
    echo "gsed"
  else
    echo "sed"
  fi
}

get_wc_binary(){
    if [[ "${OSTYPE}" == "darwin"* ]]; then
    echo "gwc"
  else
    echo "wc"
  fi
}