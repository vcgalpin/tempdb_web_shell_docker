#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

IMAGE_NAME=tempdb_web_shell
CONTAINER_NAME=tempdb_web_shell
VOLUME_NAME=tempdb_web_shell_pgdata
PORT=8081

APP_REPO_URL=https://github.com/vcgalpin/xps_dcc_app
APP_REPO_BRANCH=main
DUMP_RELATIVE_PATH=sql/xps_dcc_app.sql

POSTGRES_DB=linksdb
POSTGRES_USER=linksuser
POSTGRES_PASSWORD=change_me

APP_START_COMMAND='linx --config=config.debug.0.9.8 src/startXPS.links'

LABEL_NAME=tempdb_web_shell.repo_commit

TMPDIR_PATH=""

cleanup() {
  if [ -n "${TMPDIR_PATH}" ] && [ -d "${TMPDIR_PATH}" ]; then
    rm -rf "${TMPDIR_PATH}"
  fi
}

trap cleanup EXIT HUP INT TERM

get_local_commit() {
  docker image inspect "${IMAGE_NAME}" \
    --format "{{ index .Config.Labels \"${LABEL_NAME}\" }}" 2>/dev/null || true
}

build_image() {
  local remote_commit="$1"

  echo "Building image..."
  docker build --no-cache \
    --build-arg APP_REPO_URL="${APP_REPO_URL}" \
    --build-arg APP_REPO_BRANCH="${APP_REPO_BRANCH}" \
    --build-arg APP_REPO_COMMIT="${remote_commit}" \
    -t "${IMAGE_NAME}" .

  echo "Removing old container if it exists..."
  docker rm -f "${CONTAINER_NAME}" 2>/dev/null || true
}

recreate_database_volume() {
  echo "Removing old container if it exists..."
  docker rm -f "${CONTAINER_NAME}" 2>/dev/null || true

  echo "Removing database volume..."
  docker volume rm "${VOLUME_NAME}" 2>/dev/null || true
}

clone_repo_for_check() {
  TMPDIR_PATH="$(mktemp -d)"
  git clone --branch "${APP_REPO_BRANCH}" "${APP_REPO_URL}" "${TMPDIR_PATH}/repo" >/dev/null 2>&1
}

classify_changes() {
  local local_commit="$1"
  local remote_commit="$2"

  CODE_CHANGED=no
  DUMP_CHANGED=no

  local changed_files
  changed_files="$(cd "${TMPDIR_PATH}/repo" && git diff --name-only "${local_commit}" "${remote_commit}" 2>/dev/null || true)"

  if [ -z "${changed_files}" ]; then
    return
  fi

  echo "Changed files:"
  echo "${changed_files}" | sed 's/^/  - /'

  while IFS= read -r file; do
    [ -z "${file}" ] && continue

    if [ "${file}" = "${DUMP_RELATIVE_PATH}" ]; then
      DUMP_CHANGED=yes
    else
      CODE_CHANGED=yes
    fi
  done <<EOF
${changed_files}
EOF
}

manual_action_prompt() {
  echo
  echo "Manual actions (optional override)"
  echo "----------------------------------"
  echo "Choose one of these if you want to act now regardless of detected changes:"
  echo
  echo "[r] Rebuild image anyway"
  echo "[v] Recreate database volume anyway"
  echo "[b] Rebuild image and recreate database volume anyway"
  echo "[Enter] No manual override; continue using the detected change information"
  echo
  printf "Choose manual action: "
  read -r MANUAL_ACTION

  case "${MANUAL_ACTION:-}" in
    r|R)
      REBUILD_IMAGE=yes
      ;;
    v|V)
      RECREATE_VOLUME=yes
      ;;
    b|B)
      REBUILD_IMAGE=yes
      RECREATE_VOLUME=yes
      ;;
    *)
      ;;
  esac
}

open_shell_in_running_container() {
  echo "Container is already running."
  "${SCRIPT_DIR}/show-commands.sh" "${PORT}" "${POSTGRES_DB}" "${POSTGRES_USER}" "${APP_START_COMMAND}"
  echo "Opening shell..."
  docker exec -it "${CONTAINER_NAME}" bash -lc 'eval "$(opam env --switch=5.1.1)"; cd /opt/app; exec bash -i'
}

start_existing_container() {
  "${SCRIPT_DIR}/show-commands.sh" "${PORT}" "${POSTGRES_DB}" "${POSTGRES_USER}" "${APP_START_COMMAND}"
  echo "Starting existing container and attaching..."
  exec docker start -ai "${CONTAINER_NAME}"
}

run_new_container() {
  "${SCRIPT_DIR}/show-commands.sh" "${PORT}" "${POSTGRES_DB}" "${POSTGRES_USER}" "${APP_START_COMMAND}"
  echo "Creating and starting container..."
  exec docker run -it \
    --name "${CONTAINER_NAME}" \
    -p "${PORT}:8080" \
    -v "${VOLUME_NAME}:/opt/postgres-data" \
    -e POSTGRES_DB="${POSTGRES_DB}" \
    -e POSTGRES_USER="${POSTGRES_USER}" \
    -e POSTGRES_PASSWORD="${POSTGRES_PASSWORD}" \
    -e APP_START_COMMAND="${APP_START_COMMAND}" \
    "${IMAGE_NAME}"
}

REBUILD_IMAGE=no
RECREATE_VOLUME=no
IMAGE_PRESENT=no
LOCAL_COMMIT=""
REMOTE_COMMIT=""
CODE_CHANGED=unknown
DUMP_CHANGED=unknown

printf "Show current Docker status first? [y/N] "
read -r SHOW_STATUS

case "${SHOW_STATUS:-}" in
  y|Y)
    "${SCRIPT_DIR}/show-status.sh" "${IMAGE_NAME}" "${CONTAINER_NAME}" "${VOLUME_NAME}" "${PORT}" "${LABEL_NAME}"
    ;;
  *)
    ;;
esac

echo
echo "Checking GitHub for latest version..."
clone_repo_for_check

REMOTE_COMMIT="$(cd "${TMPDIR_PATH}/repo" && git rev-parse HEAD)"

if [ -z "${REMOTE_COMMIT}" ]; then
  echo "Could not determine latest GitHub commit."
  exit 1
fi

if docker image inspect "${IMAGE_NAME}" >/dev/null 2>&1; then
  IMAGE_PRESENT=yes
  LOCAL_COMMIT="$(get_local_commit)"
else
  IMAGE_PRESENT=no
fi

if [ "${IMAGE_PRESENT}" = "no" ]; then
  CODE_CHANGED=unknown
  DUMP_CHANGED=unknown
elif [ -z "${LOCAL_COMMIT}" ] || [ "${LOCAL_COMMIT}" = "unknown" ]; then
  CODE_CHANGED=unknown
  DUMP_CHANGED=unknown
else
  if [ "${LOCAL_COMMIT}" = "${REMOTE_COMMIT}" ]; then
    CODE_CHANGED=no
    DUMP_CHANGED=no
  else
    classify_changes "${LOCAL_COMMIT}" "${REMOTE_COMMIT}"
  fi
fi

"${SCRIPT_DIR}/show-change-status.sh" \
  "${IMAGE_PRESENT}" \
  "${LOCAL_COMMIT}" \
  "${REMOTE_COMMIT}" \
  "${CODE_CHANGED}" \
  "${DUMP_CHANGED}" \
  "${REBUILD_IMAGE}" \
  "${RECREATE_VOLUME}"

echo "You can now optionally override the detected-change workflow."

manual_action_prompt

if [ "${IMAGE_PRESENT}" = "no" ]; then
  echo "No local image found. A build is required."
  REBUILD_IMAGE=yes
fi

if [ "${IMAGE_PRESENT}" = "yes" ] && { [ -z "${LOCAL_COMMIT}" ] || [ "${LOCAL_COMMIT}" = "unknown" ]; }; then
  if [ "${REBUILD_IMAGE}" != "yes" ]; then
    printf "Local image commit is unknown. Rebuild image now? [y/N] "
    read -r ANSWER
    case "${ANSWER:-}" in
      y|Y) REBUILD_IMAGE=yes ;;
    esac
  fi
fi

if [ "${IMAGE_PRESENT}" = "yes" ] && \
   [ -n "${LOCAL_COMMIT}" ] && \
   [ "${LOCAL_COMMIT}" != "unknown" ] && \
   [ "${LOCAL_COMMIT}" != "${REMOTE_COMMIT}" ]; then

  if [ "${CODE_CHANGED}" = "yes" ] && [ "${DUMP_CHANGED}" = "no" ]; then
    if [ "${REBUILD_IMAGE}" != "yes" ]; then
      printf "Only code changed. Rebuild image from GitHub? [y/N] "
      read -r ANSWER
      case "${ANSWER:-}" in
        y|Y) REBUILD_IMAGE=yes ;;
      esac
    fi

  elif [ "${CODE_CHANGED}" = "no" ] && [ "${DUMP_CHANGED}" = "yes" ]; then
    if [ "${RECREATE_VOLUME}" != "yes" ]; then
      printf "Only SQL dump changed. Recreate database volume? [y/N] "
      read -r ANSWER
      case "${ANSWER:-}" in
        y|Y) RECREATE_VOLUME=yes ;;
      esac
    fi

    if [ "${RECREATE_VOLUME}" = "yes" ]; then
      REBUILD_IMAGE=yes
    fi

  elif [ "${CODE_CHANGED}" = "yes" ] && [ "${DUMP_CHANGED}" = "yes" ]; then
    if [ "${REBUILD_IMAGE}" != "yes" ]; then
      printf "Code changed. Rebuild image from GitHub? [y/N] "
      read -r ANSWER
      case "${ANSWER:-}" in
        y|Y) REBUILD_IMAGE=yes ;;
      esac
    fi

    if [ "${RECREATE_VOLUME}" != "yes" ]; then
      printf "SQL dump changed. Recreate database volume? [y/N] "
      read -r ANSWER
      case "${ANSWER:-}" in
        y|Y) RECREATE_VOLUME=yes ;;
      esac
    fi

    if [ "${RECREATE_VOLUME}" = "yes" ]; then
      REBUILD_IMAGE=yes
    fi
  fi
fi

echo
echo "Final selected actions"
echo "----------------------"
echo "Rebuild image     : ${REBUILD_IMAGE}"
echo "Recreate DB volume: ${RECREATE_VOLUME}"
echo

if [ "${REBUILD_IMAGE}" = "yes" ]; then
  build_image "${REMOTE_COMMIT}"
fi

if [ "${RECREATE_VOLUME}" = "yes" ]; then
  recreate_database_volume
fi

if docker container inspect "${CONTAINER_NAME}" >/dev/null 2>&1; then
  RUNNING="$(docker inspect -f '{{.State.Running}}' "${CONTAINER_NAME}")"

  if [ "${RUNNING}" = "true" ]; then
    open_shell_in_running_container
    exit 0
  fi

  start_existing_container
fi

run_new_container

