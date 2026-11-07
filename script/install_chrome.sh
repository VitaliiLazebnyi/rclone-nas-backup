#!/usr/bin/env bash
# Installs the latest stable Chrome (Chrome for Testing, with @puppeteer/browsers of the npm dependencies) into
# <directory> and points Lighthouse (CHROME_PATH) and pa11y (PUPPETEER_EXECUTABLE_PATH) at it for the later steps
# of a GitHub Actions job (GITHUB_ENV).
# Usage: script/install_chrome.sh <directory>
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly root

# The last line reads "chrome@<version> <path of the executable>".
installed=$("${root}/node_modules/.bin/browsers" install chrome@stable --path "${1}")
chrome=$(tail -n 1 <<< "${installed}" | cut -d ' ' -f 2-)
"${chrome}" --version
{
  echo "CHROME_PATH=${chrome}"
  echo "PUPPETEER_EXECUTABLE_PATH=${chrome}"
} >> "${GITHUB_ENV:?GITHUB_ENV is required}"
