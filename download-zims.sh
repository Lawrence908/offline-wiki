#!/usr/bin/env bash
# Helper script to download Kiwix ZIM files
# Browse available ZIMs at: https://download.kiwix.org/zim/
#
# Usage:
#   Single file: ./download-zims.sh <zim-filename> [category]
#   Batch from list: ./download-zims.sh --list <list-file>
#
# Examples:
#   ./download-zims.sh wikipedia_en_all_maxi_2025-08.zim wikipedia
#   ./download-zims.sh --list zims-to-download.txt

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${REPO_ROOT}/.env"
LIST_FILE="${SCRIPT_DIR}/zims-to-download.txt"

if [[ -f "${ENV_FILE}" ]]; then
  # shellcheck source=/dev/null
  source "${ENV_FILE}"
fi

: "${KIWIX_ZIM_DIR:=/mnt/storage/kiwix/zims}"
: "${KIWIX_BASE_URL:=https://download.kiwix.org/zim}"

# Ensure ZIM directory exists
mkdir -p "${KIWIX_ZIM_DIR}"

# Check if using list mode
if [[ "${1:-}" == "--list" ]]; then
  LIST_FILE="${2:-${LIST_FILE}}"
  if [[ ! -f "${LIST_FILE}" ]]; then
    echo "❌ List file not found: ${LIST_FILE}"
    echo ""
    echo "Create a file with one ZIM filename per line (with optional category):"
    echo "  wikipedia_en_top_mini_2025-12.zim wikipedia"
    echo "  wikiquote_en_all_nopic_2026-01.zim wikiquote"
    echo "  gutenberg_pt_all_2023-08.zim gutenberg"
    exit 1
  fi
  
  echo "📋 Reading ZIM list from: ${LIST_FILE}"
  echo ""
  
  TOTAL=$(grep -v '^#' "${LIST_FILE}" | grep -v '^$' | wc -l)
  COUNT=0
  
  while IFS= read -r line || [[ -n "${line}" ]]; do
    # Skip comments and empty lines
    [[ "${line}" =~ ^#.*$ ]] && continue
    [[ -z "${line// }" ]] && continue
    
    COUNT=$((COUNT + 1))
    ZIM_FILE="${line%% *}"  # First word
    CATEGORY="${line#* }"    # Rest of line (if provided)
    [[ "${CATEGORY}" == "${ZIM_FILE}" ]] && CATEGORY=""
    
    echo "[${COUNT}/${TOTAL}] Processing: ${ZIM_FILE}"
    "$0" "${ZIM_FILE}" "${CATEGORY}" || {
      echo "⚠️  Failed to download ${ZIM_FILE}, continuing..."
    }
    echo ""
  done < "${LIST_FILE}"
  
  echo "✅ Batch download complete!"
  exit 0
fi

ZIM_FILE="${1:-}"
CATEGORY="${2:-}"

if [[ -z "${ZIM_FILE}" ]]; then
  echo "Usage: $0 <zim-filename> [category]"
  echo "   or: $0 --list [list-file]"
  echo ""
  echo "Single file examples:"
  echo "  $0 wikipedia_en_all_maxi_2025-08.zim wikipedia"
  echo "  $0 wiktionary_en_all_nopic_2025-09.zim wiktionary"
  echo "  $0 stackoverflow_en_all_2025-11.zim stack_exchange"
  echo ""
  echo "Batch download:"
  echo "  $0 --list zims-to-download.txt"
  echo ""
  echo "Browse all available ZIMs at: https://download.kiwix.org/zim/"
  echo ""
  echo "Common categories:"
  echo "  - wikipedia"
  echo "  - wiktionary"
  echo "  - wikibooks"
  echo "  - wikivoyage"
  echo "  - wikiquote"
  echo "  - stack_exchange"
  echo "  - gutenberg"
  echo "  - ted"
  exit 1
fi

# Auto-detect category from filename if not provided
if [[ -z "${CATEGORY}" ]]; then
  if [[ "${ZIM_FILE}" =~ ^wikipedia_ ]]; then
    CATEGORY="wikipedia"
  elif [[ "${ZIM_FILE}" =~ ^wiktionary_ ]]; then
    CATEGORY="wiktionary"
  elif [[ "${ZIM_FILE}" =~ ^wikibooks_ ]]; then
    CATEGORY="wikibooks"
  elif [[ "${ZIM_FILE}" =~ ^wikivoyage_ ]]; then
    CATEGORY="wikivoyage"
  elif [[ "${ZIM_FILE}" =~ ^wikiquote_ ]]; then
    CATEGORY="wikiquote"
  elif [[ "${ZIM_FILE}" =~ ^stackoverflow_ ]]; then
    CATEGORY="stack_exchange"
  elif [[ "${ZIM_FILE}" =~ ^gutenberg_ ]]; then
    CATEGORY="gutenberg"
  elif [[ "${ZIM_FILE}" =~ ^ted_ ]]; then
    CATEGORY="ted"
  else
    echo "Could not auto-detect category from filename. Please specify it as second argument."
    echo "Usage: $0 <zim-filename> <category>"
    exit 1
  fi
  echo "Auto-detected category: ${CATEGORY}"
fi

DOWNLOAD_URL="${KIWIX_BASE_URL}/${CATEGORY}/${ZIM_FILE}"
OUTPUT_FILE="${KIWIX_ZIM_DIR}/${ZIM_FILE}"

# Check if we can write to the directory
if [[ ! -w "${KIWIX_ZIM_DIR}" ]] && [[ ! -w "$(dirname "${OUTPUT_FILE}")" ]]; then
  echo "⚠️  Permission denied: Cannot write to ${KIWIX_ZIM_DIR}"
  echo "   You may need to run with sudo or fix directory permissions."
  echo ""
  echo "   Try: sudo $0 $*"
  exit 1
fi

if [[ -f "${OUTPUT_FILE}" ]]; then
  echo "⚠️  File already exists: ${OUTPUT_FILE}"
  echo "   Skipping (file already downloaded)"
  ls -lh "${OUTPUT_FILE}"
  exit 0
fi

echo "Downloading ${ZIM_FILE} from ${DOWNLOAD_URL}..."
echo "Saving to: ${OUTPUT_FILE}"
echo ""
echo "Note: Large files may take hours to download. You can safely interrupt and resume later."
echo ""

# Download with resume support
wget -c --progress=bar:force:noscroll -O "${OUTPUT_FILE}" "${DOWNLOAD_URL}"

if [[ -f "${OUTPUT_FILE}" ]]; then
  echo ""
  echo "✅ Download complete!"
  echo ""
  echo "Next steps:"
  echo "  1. Rebuild library: cd ~/services/offline-wiki && ./scripts/add_zims.sh"
  echo "  2. Library will auto-reload (no restart needed)"
  echo ""
  ls -lh "${OUTPUT_FILE}"
else
  echo "❌ Download failed!"
  exit 1
fi

