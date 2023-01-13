#!/usr/bin/env bash

: '
Provides helper functions for collecting CPU and MEM usages
'

get_pod_metrics_gds_path_from_trn(){
  # Given a task run id, return the file path for the pod metrics

  # Get local vars
  local task_id="$1"
  local ica_base_url="$2"
  local ica_access_token="$3"

  curl \
    --silent \
    --request GET \
    --header "Authorization: Bearer ${ica_access_token}" \
    "${ica_base_url}/v1/tasks/runs/${task_id}" | \
  jq \
    --raw-output \
    '
      .execution.outputs |
      map(
        select(
          .path == "/var/log/tessystemlogs"
        )
      ) |
      map(
        "\(.url)/pod-metrics-0.log"
      ) |
      .[]
    '
}

get_trn_pod_metrics_file_contents(){
  # Given a task run id, get the file path for the pod metrics
  # Stream outputs of the file path to stdout and pipe into jq
  # Input vars
  local task_id="$1"
  local ica_base_url="$2"
  local ica_access_token="$3"

  # Other local vars
  local pod_metrics_path
  local pod_metrics_volume
  local pod_metrics_path_attr
  local pod_metrics_file_id
  local pod_metrics_presigned_url

  # Get the pod metrics
  pod_metrics_path="$(
    get_pod_metrics_gds_path_from_trn \
      "${task_id}" \
      "${ica_base_url}" \
      "${ica_access_token}"
  )"

  # Get the tes path
  pod_metrics_volume="$(
    get_volume_from_gds_path "${pod_metrics_path}"
  )"
  pod_metrics_path_attr="$(
    get_file_path_from_gds_path "${pod_metrics_path}"
  )"

  # Get the file id from the path
  pod_metrics_file_id="$( \
    get_file_id \
      "${pod_metrics_volume}" \
      "${pod_metrics_path_attr}" \
      "${ica_base_url}" \
      "${ica_access_token}"
  )"

  if [[ -v "${pod_metrics_file_id}" ]]; then
    echo_stderr "Could not get pod-metrics file for task '${task_id}'"
    return 1
  fi

  # Get the file id
  pod_metrics_presigned_url="$( \
    get_presigned_url_from_file_id \
      "${pod_metrics_file_id}" \
      "${ica_base_url}" \
      "${ica_access_token}"
  )"

  # Return the contents of the pod metrics file as a list
  wget \
    --quiet \
    --output-document - \
    "${pod_metrics_presigned_url}" | \
  jq --raw-output --slurp
}

curate_pod_metrics_obj(){
  # JQ magic to convert pod metrics to a palatable input
  local raw_pod_metrics_obj="$1"

  # CPU suffixes are
  # n, m, k
  # Where n needs to be divided by 1 bil (nano)
  # u needs to be divided by 1 million (micro)
  # And m needs to be divided by 1 thousand (mill)

  # Memory suffixes are
  # Ki, where number needs to be multiplied by 1000
  # Mi, where number needs to be multiplied by 1,000,000
  # Gi, where number needs to be multiplied by 1,000,000

  # We measure the cpu in standard values
  # And measure the memory in Gb
  jq --raw-output \
    '
      def round_whole:
        . + 0.5 | floor
      ;
      def round(dec):
        dec as $dec |
        (. * pow(10; $dec) | round_whole) / pow(10; $dec)
      ;
      def get_cpu(cpu):
        cpu as $cpu |
        if ($cpu | endswith("n")) then
          (($cpu | split("n")[0]) | tonumber) / pow(10; 9)
        else
          if ($cpu | endswith("u")) then
            (($cpu | split("u")[0]) | tonumber) / pow(10; 6)
          else
            if ($cpu | endswith("m")) then
              (($cpu | split("m")[0]) | tonumber) / pow(10; 3)
            else
              $cpu | tonumber
            end
          end
        end
      ;
      def get_mem_in_gb(mem):
        mem as $mem |
        if ($mem | endswith("Gi")) then
          (($mem | split("Gi")[0]) | tonumber)
        else
          if ($mem | endswith("Mi")) then
            (($mem | split("Mi")[0]) | tonumber) / pow(10; 3)
          else
            if ($mem | endswith("Ki")) then
              (($mem | split("Ki")[0]) | tonumber) / pow(10; 6)
            else
              $mem / pow(10; 9)
            end
          end
        end
      ;
      map(
        select(has("containers"))
      ) |
      map(
        .containers |
        map(
          select(.name == "task")
        )
      ) |
      flatten |
      map(
        .usage |
        {
          "cpu": get_cpu(.cpu) | round(2),
          "memory_gb": get_mem_in_gb(.memory) | round(2)
        }
      )
    ' \
    <<< "${raw_pod_metrics_obj}"
}

get_max_cpu_usage_from_pod_metrics(){
  # Get the highest CPU usage for a task from the pod metrics

  # Inputs
  local pod_metrics_obj="$1"

  jq --raw-output \
    '
      map(
        .cpu
      ) |
      max
    ' <<< "${pod_metrics_obj}"
}

get_max_mem_usage_from_pod_metrics(){
  # Get the highest mem usage for a task from the pod metrics

  # Inputs
  local pod_metrics_obj="$1"

  jq --raw-output \
    '
      map(
        .memory_gb
      ) |
      max
    ' <<< "${pod_metrics_obj}"
}

get_avg_cpu_usage_from_pod_metrics(){
  # Get the average usage for a task from the pod metrics

  # Inputs
  local pod_metrics_obj="$1"

  # Get the average CPU usage for a task from the pod metrics
  jq --raw-output \
    '
      def round_whole:
        . + 0.5 | floor
      ;
      def round(dec):
        dec as $dec |
        (. * pow(10; $dec) | round_whole) / pow(10; $dec)
      ;
      def mean:
        add / length
      ;
      map(
        .cpu
      ) |
      mean |
      round(2)
    ' <<< "${pod_metrics_obj}"
}

get_avg_mem_usage_from_pod_metrics(){
  # Get the average memory usage for a task from the pod metrics

  # Inputs
  local pod_metrics_obj="$1"

  jq --raw-output \
    '
      def round_whole:
        . + 0.5 | floor
      ;
      def round(dec):
        dec as $dec |
        (. * pow(10; $dec) | round_whole) / pow(10; $dec)
      ;
      def mean:
        add / length
      ;
      map(
        .memory_gb
      ) |
      mean |
      round(2)
    ' <<< "${pod_metrics_obj}"
}

usage_json_output(){
  # Print the output to json

  # Inputs
  local pod_metrics_obj="$1"

  # Print outputs in json format
  jq --null-input --raw-output \
    --argjson max_cpu "$(get_max_cpu_usage_from_pod_metrics "${pod_metrics_obj}")" \
    --argjson avg_cpu "$(get_avg_cpu_usage_from_pod_metrics "${pod_metrics_obj}")" \
    --argjson max_mem "$(get_max_mem_usage_from_pod_metrics "${pod_metrics_obj}")" \
    --argjson avg_mem "$(get_avg_mem_usage_from_pod_metrics "${pod_metrics_obj}")" \
    '
      {
        max_cpu: $max_cpu,
        avg_cpu: $avg_cpu,
        max_mem: $max_mem,
        avg_mem: $avg_mem
      }
    '
}

usage_table_output(){
  # Print outputs in table format
  # Inputs
  local pod_metrics_obj="$1"

  # Set max cpu
  echo "Max CPU was: $(get_max_cpu_usage_from_pod_metrics "${pod_metrics_obj}")"
  echo "Avg CPU was: $(get_avg_cpu_usage_from_pod_metrics "${pod_metrics_obj}")"
  echo "Max Mem was: $(get_max_mem_usage_from_pod_metrics "${pod_metrics_obj}")"
  echo "Avg Mem was: $(get_avg_mem_usage_from_pod_metrics "${pod_metrics_obj}")"
}





