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

mkdir -p "${KIWIX_ZIM_DIR}"
mkdir -p "$(dirname "${KIWIX_LIBRARY}")"

shopt -s nullglob
ZIM_FILES=("${KIWIX_ZIM_DIR}"/*.zim)
shopt -u nullglob

if (( ${#ZIM_FILES[@]} == 0 )); then
  echo "No ZIM files found in ${KIWIX_ZIM_DIR}. Nothing to add."
  exit 0
fi

TMP_LIST="$(mktemp)"
trap 'rm -f "${TMP_LIST}"' EXIT

# Create list with container-relative paths (zims/filename.zim)
for zim in "${ZIM_FILES[@]}"; do
  echo "zims/$(basename "${zim}")"
done | sort > "${TMP_LIST}"

echo "Rebuilding library at ${KIWIX_LIBRARY} from ZIMs in ${KIWIX_ZIM_DIR}..."

# Mount the entire data directory so zims/ is accessible relative to library.xml
docker run --rm \
  -v "${KIWIX_DATA_DIR}:/data" \
  -v "${TMP_LIST}:/tmp/zims.list:ro" \
  -w /data \
  ghcr.io/kiwix/kiwix-tools:latest \
  /bin/sh -s <<'EOF'
set -euo pipefail

LIBRARY_PATH="library.xml"
rm -f "${LIBRARY_PATH}"

# Build list of ZIM files to add (paths relative to /data)
ZIM_PATHS=()
while IFS= read -r zim_path; do
  [ -n "${zim_path}" ] || continue
  if [ -f "${zim_path}" ]; then
    ZIM_PATHS+=("${zim_path}")
  else
    echo "Warning: ZIM file not found: ${zim_path}"
  fi
done < /tmp/zims.list

if [ ${#ZIM_PATHS[@]} -eq 0 ]; then
  echo "No valid ZIM files found to add."
  exit 1
fi

echo "Adding ${#ZIM_PATHS[@]} ZIM file(s) to library..."
for zim_path in "${ZIM_PATHS[@]}"; do
  echo "  Adding ${zim_path}..."
  if ! kiwix-manage "${LIBRARY_PATH}" add "${zim_path}" 2>&1; then
    echo "ERROR: Failed to add ${zim_path} to library"
    exit 1
  fi
done

if [ ! -f "${LIBRARY_PATH}" ]; then
  echo "ERROR: Library file was not created at ${LIBRARY_PATH}"
  exit 1
fi

# Verify library contains expected number of entries
ENTRY_COUNT=$(grep -c "<book" "${LIBRARY_PATH}" || echo "0")
if [ "${ENTRY_COUNT}" -ne "${#ZIM_PATHS[@]}" ]; then
  echo "WARNING: Library contains ${ENTRY_COUNT} entries but expected ${#ZIM_PATHS[@]}"
fi

echo "Library rebuild complete. Added ${ENTRY_COUNT} ZIM file(s)."
EOF

echo "Attempting to signal kiwix-serve container to reload (SIGHUP)..."
if docker ps --format '{{.Names}}' | grep -q '^offline-wiki$'; then
  if docker kill -s HUP offline-wiki >/dev/null 2>&1; then
    echo "Sent SIGHUP to offline-wiki."
  else
    echo "Failed to send SIGHUP to offline-wiki; you may need to restart the container."
  fi
else
  echo "offline-wiki container not running; start it with: docker compose up -d"
fi


