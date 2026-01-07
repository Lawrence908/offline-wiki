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

if [[ -z "${RESTIC_PASSWORD:-}" ]]; then
  echo "RESTIC_PASSWORD is not set. Aborting restore."
  exit 1
fi

RESTIC_REPOSITORY_DEFAULT="${KIWIX_BACKUP_DIR}/restic-repo"
: "${RESTIC_REPOSITORY:=${RESTIC_REPOSITORY_DEFAULT}}"
export RESTIC_REPOSITORY
export RESTIC_PASSWORD

if ! command -v restic >/dev/null 2>&1; then
  echo "restic is not installed. Please install restic and retry."
  exit 1
fi

SNAPSHOT="${1:-latest}"

echo "Restoring snapshot '${SNAPSHOT}'..."

RESTORE_TMP="${KIWIX_DATA_DIR}.restore-$(date +%Y%m%d-%H%M%S)"
mkdir -p "${RESTORE_TMP}"

restic restore "${SNAPSHOT}" --target "${RESTORE_TMP}"

echo "Copying restored data back into ${KIWIX_DATA_DIR}..."
mkdir -p "${KIWIX_DATA_DIR}"
rsync -a --delete \
  "${RESTORE_TMP}${KIWIX_DATA_DIR}/" "${KIWIX_DATA_DIR}/" || true

echo "Cleaning up temporary restore directory..."
rm -rf "${RESTORE_TMP}"

echo "Restarting docker stack..."
(
  cd "${REPO_ROOT}"
  docker compose down
  docker compose up -d
)

echo "Restore completed."






