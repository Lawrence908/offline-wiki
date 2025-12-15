#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${REPO_ROOT}/.env"

if [[ -f "${ENV_FILE}" ]]; then
  # shellcheck source=/dev/null
  source "${ENV_FILE}"
fi

: "${KIWIX_PORT:=8282}"
: "${KIWIX_HEALTH_TITLE:=Kiwix}"

URL="http://localhost:${KIWIX_PORT}/"

echo "Checking Kiwix service at ${URL}..."

if ! output="$(curl -fsS "${URL}")"; then
  echo "❌ Failed to reach kiwix-serve at ${URL}"
  exit 1
fi

if echo "${output}" | grep -qi "${KIWIX_HEALTH_TITLE}"; then
  echo "✅ kiwix-serve is up and responding."
  exit 0
else
  echo "⚠️  kiwix-serve responded but '${KIWIX_HEALTH_TITLE}' was not found in page content."
  exit 1
fi


