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
: "${KIWIX_ZIM_UPDATE_BASE_URL:=}"

if [[ -z "${KIWIX_ZIM_UPDATE_BASE_URL}" ]]; then
  echo "KIWIX_ZIM_UPDATE_BASE_URL is not set."
  echo "Automatic ZIM updates are disabled. Set it to e.g.:"
  echo "  https://download.kiwix.org/zim/wikipedia"
  exit 0
fi

mkdir -p "${KIWIX_ZIM_DIR}"
TMP_DIR="${KIWIX_DATA_DIR}/tmp"
mkdir -p "${TMP_DIR}"

shopt -s nullglob
ZIM_FILES=("${KIWIX_ZIM_DIR}"/*.zim)
shopt -u nullglob

if (( ${#ZIM_FILES[@]} == 0 )); then
  echo "No ZIM files found in ${KIWIX_ZIM_DIR}. Nothing to update."
  exit 0
fi

fetch_latest_remote_for() {
  local base_name="$1"
  local url="${KIWIX_ZIM_UPDATE_BASE_URL}/"

  echo "Checking remote for newer versions of ${base_name}..."

  local html
  if ! html="$(wget -qO- "${url}")"; then
    echo "  Failed to fetch index from ${url}, skipping."
    return 1
  fi

  local candidates
  candidates="$(printf '%s\n' "${html}" | grep -o "${base_name}_[0-9-]*\.zim" | sort -u || true)"
  if [[ -z "${candidates}" ]]; then
    echo "  No matching remote ZIMs found for ${base_name}."
    return 1
  fi

  # Pick the latest by date (lexicographical sort works on YYYY-MM)
  local latest
  latest="$(printf '%s\n' "${candidates}" | sort | tail -n 1)"
  printf '%s\n' "${latest}"
}

for zim_path in "${ZIM_FILES[@]}"; do
  zim_file="$(basename "${zim_path}")"

  if [[ "${zim_file}" =~ ^(.+)_([0-9]{4}-[0-9]{2})\.zim$ ]]; then
    base_name="${BASH_REMATCH[1]}"
    current_date="${BASH_REMATCH[2]}"
  else
    echo "Skipping ${zim_file}: does not match expected pattern <name>_YYYY-MM.zim"
    continue
  fi

  latest_remote_file="$(fetch_latest_remote_for "${base_name}" || true)"
  if [[ -z "${latest_remote_file}" ]]; then
    continue
  fi

  if [[ "${latest_remote_file}" == "${zim_file}" ]]; then
    echo "${zim_file} is already up to date (${current_date})."
    continue
  fi

  remote_url="${KIWIX_ZIM_UPDATE_BASE_URL}/${latest_remote_file}"
  tmp_file="${TMP_DIR}/${latest_remote_file}.partial"

  echo "Found newer remote ZIM: ${latest_remote_file}"
  echo "Downloading with resume support from ${remote_url}..."

  if ! wget -c -O "${tmp_file}" "${remote_url}"; then
    echo "  Download failed for ${remote_url}, leaving partial file at ${tmp_file}"
    continue
  fi

  # Attempt checksum verification if .sha256 exists
  sha_url="${remote_url}.sha256"
  echo "Attempting to verify checksum from ${sha_url}..."
  if wget -qO- "${sha_url}" >/dev/null 2>&1; then
    checksum_line="$(wget -qO- "${sha_url}" | head -n 1 || true)"
    if [[ -n "${checksum_line}" ]]; then
      tmp_sha="${TMP_DIR}/${latest_remote_file}.sha256"
      echo "${checksum_line}  ${tmp_file##*/}" > "${tmp_sha}"
      (cd "${TMP_DIR}" && sha256sum -c "$(basename "${tmp_sha}")") || {
        echo "  Checksum verification failed for ${latest_remote_file}, skipping replace."
        rm -f "${tmp_file}" "${tmp_sha}"
        continue
      }
      rm -f "${tmp_sha}"
      echo "  Checksum verification passed."
    else
      echo "  Empty checksum file, skipping verification."
    fi
  else
    echo "  No checksum file found, skipping verification."
  fi

  final_path="${KIWIX_ZIM_DIR}/${latest_remote_file}"
  echo "Atomically moving new ZIM into place: ${final_path}"
  mv "${tmp_file}" "${final_path}"

  echo "Keeping old ZIM ${zim_file} (you may delete it manually after validation)."
done

echo "Rebuilding library after updates..."
"${SCRIPT_DIR}/add_zims.sh"


