#!/usr/bin/env bash

set -o errexit -o pipefail -o nounset

# Waits DOCKERD_TIMEOUT seconds for startup (default: 60)
DOCKERD_TIMEOUT="${DOCKERD_TIMEOUT:-60}"
# Accepts optional DOCKER_OPTS (default: --data-root /scratch/docker)
DOCKER_OPTS="${DOCKER_OPTS:-}"

# Constants
DOCKERD_PID_FILE="/tmp/docker.pid"
DOCKERD_LOG_FILE="/tmp/docker.log"

# Function to start the Docker daemon
start_docker() {
  echo >&2 "Setting up Docker environment..."
  
  # Ensure cgroups are mounted correctly
  if ! mountpoint -q /sys/fs/cgroup; then
    echo >&2 "Mounting cgroups..."
    mkdir -p /sys/fs/cgroup
    mount -t cgroup2 none /sys/fs/cgroup || mount -t cgroup -o rdma cgroup /sys/fs/cgroup
  fi

  echo >&2 "Starting Docker daemon..."
  dockerd ${DOCKER_OPTS} &> "${DOCKERD_LOG_FILE}" &
  echo "$!" > "${DOCKERD_PID_FILE}"
}

# Function to wait for the Docker daemon to be healthy
await_docker() {
  local timeout="${DOCKERD_TIMEOUT}"
  echo >&2 "Waiting ${timeout} seconds for Docker to be available..."
  local start=${SECONDS}
  timeout=$(( timeout + start ))
  until docker info &>/dev/null; do
    if (( SECONDS >= timeout )); then
      echo >&2 'Timed out trying to connect to docker daemon.'
      if [[ -f "${DOCKERD_LOG_FILE}" ]]; then
        echo >&2 '---DOCKERD LOGS---'
        cat >&2 "${DOCKERD_LOG_FILE}"
      fi
      exit 1
    fi
    if [[ -f "${DOCKERD_PID_FILE}" ]] && ! kill -0 "$(cat "${DOCKERD_PID_FILE}")"; then
      echo >&2 'Docker daemon failed to start.'
      if [[ -f "${DOCKERD_LOG_FILE}" ]]; then
        echo >&2 '---DOCKERD LOGS---'
        cat >&2 "${DOCKERD_LOG_FILE}"
      fi
      exit 1
    fi
    sleep 1
  done
  local duration=$(( SECONDS - start ))
  echo >&2 "Docker available after ${duration} seconds."
}

# Function to stop the Docker daemon gracefully
stop_docker() {
  if ! [[ -f "${DOCKERD_PID_FILE}" ]]; then
    return 0
  fi
  local docker_pid
  docker_pid="$(cat "${DOCKERD_PID_FILE}")"
  if [[ -z "${docker_pid}" ]]; then
    return 0
  fi
  echo >&2 "Terminating Docker daemon."
  kill -TERM "${docker_pid}"
  local start=${SECONDS}
  echo >&2 "Waiting for Docker daemon to exit..."
  wait "${docker_pid}"
  local duration=$(( SECONDS - start ))
  echo >&2 "Docker exited after ${duration} seconds."
}

# Start Docker and set up trap to stop it on exit
start_docker
trap stop_docker EXIT
await_docker

# Execute passed commands or start a shell
if [[ "$#" != "0" ]]; then
  "$@"
else
  bash --login
fi
