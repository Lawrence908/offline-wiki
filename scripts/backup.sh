#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${REPO_ROOT}/.env"

if [[ -f "${ENV_FILE}" ]]; then
  # shellcheck source=/dev/null
  source "${ENV_FILE}"
fi

: "${KIWIX_DATA_DIR:=/mnt/storage/kiwix}"
: "${KIWIX_ZIM_DIR:=${KIWIX_DATA_DIR}/zims}"
: "${KIWIX_LIBRARY:=${KIWIX_DATA_DIR}/library.xml}"
: "${KIWIX_BACKUP_DIR:=${KIWIX_DATA_DIR}/backups}"
: "${BACKUP_ZIMS:=false}"

if [[ -z "${RESTIC_PASSWORD:-}" ]]; then
  echo "RESTIC_PASSWORD is not set. Aborting backup."
  exit 1
fi

RESTIC_REPOSITORY_DEFAULT="${KIWIX_BACKUP_DIR}/restic-repo"
: "${RESTIC_REPOSITORY:=${RESTIC_REPOSITORY_DEFAULT}}"
export RESTIC_REPOSITORY
export RESTIC_PASSWORD

mkdir -p "${KIWIX_BACKUP_DIR}"

if ! command -v restic >/dev/null 2>&1; then
  echo "restic is not installed. Please install restic and retry."
  exit 1
fi

if ! restic snapshots >/dev/null 2>&1; then
  echo "Initializing new restic repository at ${RESTIC_REPOSITORY}..."
  restic init
fi

INCLUDE_PATHS=()

if [[ -f "${KIWIX_LIBRARY}" ]]; then
  INCLUDE_PATHS+=("${KIWIX_LIBRARY}")
fi

if [[ "${BACKUP_ZIMS}" == "true" ]]; then
  if [[ -d "${KIWIX_ZIM_DIR}" ]]; then
    INCLUDE_PATHS+=("${KIWIX_ZIM_DIR}")
  fi
else
  echo "BACKUP_ZIMS=false: ZIM files will NOT be included in backups."
fi

if [[ -f "${REPO_ROOT}/compose.yaml" ]]; then
  INCLUDE_PATHS+=("${REPO_ROOT}/compose.yaml")
elif [[ -f "${REPO_ROOT}/docker-compose.yml" ]]; then
  INCLUDE_PATHS+=("${REPO_ROOT}/docker-compose.yml")
fi

if [[ -f "${REPO_ROOT}/.env" ]]; then
  INCLUDE_PATHS+=("${REPO_ROOT}/.env")
fi
INCLUDE_PATHS+=("${REPO_ROOT}/scripts")

if (( ${#INCLUDE_PATHS[@]} == 0 )); then
  echo "Nothing to back up. Aborting."
  exit 0
fi

echo "Starting restic backup..."
restic backup "${INCLUDE_PATHS[@]}" --tag offline-wiki

echo "Applying retention policy (daily 7, weekly 4, monthly 6)..."
restic forget --prune --tag offline-wiki \
  --keep-daily 7 \
  --keep-weekly 4 \
  --keep-monthly 6

echo "Backup completed successfully."






