#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

ENV_FILE="${REPO_ROOT}/.env"
ENV_EXAMPLE="${REPO_ROOT}/.env.example"

if [[ ! -f "${ENV_FILE}" ]]; then
  if [[ -f "${ENV_EXAMPLE}" ]]; then
    echo "Creating .env from .env.example..."
    cp "${ENV_EXAMPLE}" "${ENV_FILE}"
  else
    echo "WARNING: .env.example not found, creating minimal .env with defaults."
    cat > "${ENV_FILE}" <<'EOF'
KIWIX_PORT=8282
KIWIX_DATA_DIR=/mnt/storage/kiwix
KIWIX_ZIM_DIR=/mnt/storage/kiwix/zims
KIWIX_LIBRARY=/mnt/storage/kiwix/library.xml
KIWIX_BACKUP_DIR=/mnt/storage/kiwix/backups
BACKUP_ZIMS=false
TZ=America/Vancouver
EOF
  fi
else
  echo ".env already exists, leaving it unchanged."
fi

# shellcheck source=/dev/null
source "${ENV_FILE}"

: "${KIWIX_DATA_DIR:=/mnt/storage/kiwix}"
: "${KIWIX_ZIM_DIR:=${KIWIX_DATA_DIR}/zims}"
: "${KIWIX_LIBRARY:=${KIWIX_DATA_DIR}/library.xml}"
: "${KIWIX_BACKUP_DIR:=${KIWIX_DATA_DIR}/backups}"

echo "Creating data directories..."
mkdir -p "${KIWIX_DATA_DIR}"
mkdir -p "${KIWIX_ZIM_DIR}"
mkdir -p "${KIWIX_BACKUP_DIR}"
mkdir -p "${KIWIX_DATA_DIR}/tmp"

echo "Ensuring docker network 'homelab-web' exists..."
if ! docker network inspect homelab-web >/dev/null 2>&1; then
  docker network create homelab-web
  echo "Created docker network homelab-web"
else
  echo "Docker network homelab-web already exists"
fi

echo "Initialization complete."


