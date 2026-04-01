#!/usr/bin/env bash
set -euo pipefail

IMAGE_PRESENT="${1:-no}"
LOCAL_COMMIT="${2:-}"
REMOTE_COMMIT="${3:-}"
CODE_CHANGED="${4:-unknown}"
DUMP_CHANGED="${5:-unknown}"
REBUILD_IMAGE="${6:-no}"
RECREATE_VOLUME="${7:-no}"

shorten() {
  local value="${1:-}"
  local max="${2:-20}"

  if [ -z "${value}" ]; then
    printf '%s' "unknown"
  elif [ "${#value}" -le "${max}" ]; then
    printf '%s' "${value}"
  else
    printf '%s...' "${value:0:max}"
  fi
}

change_summary() {
  if [ "${IMAGE_PRESENT}" != "yes" ]; then
    printf '%s' "no local image"
    return
  fi

  if [ "${CODE_CHANGED}" = "no" ] && [ "${DUMP_CHANGED}" = "no" ]; then
    printf '%s' "no changes detected"
  elif [ "${CODE_CHANGED}" = "yes" ] && [ "${DUMP_CHANGED}" = "no" ]; then
    printf '%s' "only code changed"
  elif [ "${CODE_CHANGED}" = "no" ] && [ "${DUMP_CHANGED}" = "yes" ]; then
    printf '%s' "only SQL dump changed"
  elif [ "${CODE_CHANGED}" = "yes" ] && [ "${DUMP_CHANGED}" = "yes" ]; then
    printf '%s' "code and SQL dump changed"
  else
    printf '%s' "unknown / not classified"
  fi
}

echo
echo "Repository change status"
echo "------------------------"
echo "Image present     : ${IMAGE_PRESENT}"
echo "Local commit      : $(shorten "${LOCAL_COMMIT}" 24)"
echo "Remote commit     : $(shorten "${REMOTE_COMMIT}" 24)"
echo "Detected changes  : $(change_summary)"
echo
echo "Selected actions"
echo "----------------"
echo "Rebuild image     : ${REBUILD_IMAGE}"
echo "Recreate DB volume: ${RECREATE_VOLUME}"
echo

