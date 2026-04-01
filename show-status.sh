#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="${1:?image name required}"
CONTAINER_NAME="${2:?container name required}"
VOLUME_NAME="${3:?volume name required}"
PORT="${4:?port required}"
LABEL_NAME="${5:?label name required}"

shorten() {
  local value="${1:-}"
  local max="${2:-80}"

  if [ "${#value}" -le "${max}" ]; then
    printf '%s' "${value}"
  else
    printf '%s...' "${value:0:max}"
  fi
}

image_status() {
  if docker image inspect "${IMAGE_NAME}" >/dev/null 2>&1; then
    local image_id created commit
    image_id="$(docker image inspect "${IMAGE_NAME}" --format '{{.Id}}' 2>/dev/null || true)"
    created="$(docker image inspect "${IMAGE_NAME}" --format '{{.Created}}' 2>/dev/null || true)"
    commit="$(docker image inspect "${IMAGE_NAME}" --format "{{ index .Config.Labels \"${LABEL_NAME}\" }}" 2>/dev/null || true)"

    echo "Image     : present"
    echo "  Name    : ${IMAGE_NAME}"
    echo "  ID      : $(shorten "${image_id}" 24)"
    echo "  Created : $(shorten "${created}" 32)"
    echo "  Commit  : ${commit:-unknown}"
  else
    echo "Image     : none"
  fi
}

container_status() {
  if docker container inspect "${CONTAINER_NAME}" >/dev/null 2>&1; then
    local status running started exit_code
    status="$(docker inspect "${CONTAINER_NAME}" --format '{{.State.Status}}' 2>/dev/null || true)"
    running="$(docker inspect "${CONTAINER_NAME}" --format '{{.State.Running}}' 2>/dev/null || true)"
    started="$(docker inspect "${CONTAINER_NAME}" --format '{{.State.StartedAt}}' 2>/dev/null || true)"
    exit_code="$(docker inspect "${CONTAINER_NAME}" --format '{{.State.ExitCode}}' 2>/dev/null || true)"

    echo "Container : present"
    echo "  Name    : ${CONTAINER_NAME}"
    echo "  Status  : ${status}"
    echo "  Running : ${running}"
    echo "  Exit    : ${exit_code}"
    echo "  Started : $(shorten "${started}" 32)"

    local ports
    ports="$(docker port "${CONTAINER_NAME}" 2>/dev/null || true)"
    if [ -n "${ports}" ]; then
      echo "  Ports   :"
      echo "${ports}" | sed 's/^/    /'
    else
      echo "  Ports   : none published"
    fi
  else
    echo "Container : none"
  fi
}

volume_status() {
  if docker volume inspect "${VOLUME_NAME}" >/dev/null 2>&1; then
    local mountpoint
    mountpoint="$(docker volume inspect "${VOLUME_NAME}" --format '{{.Mountpoint}}' 2>/dev/null || true)"

    echo "Volume    : present"
    echo "  Name    : ${VOLUME_NAME}"
    echo "  Path    : $(shorten "${mountpoint}" 70)"
  else
    echo "Volume    : none"
  fi
}

echo
echo "tempdb_web_shell status"
echo "-----------------------"
echo "Host URL  : http://localhost:${PORT}"
echo
image_status
echo
container_status
echo
volume_status
echo

