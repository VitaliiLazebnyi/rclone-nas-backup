#!/usr/bin/env bash
# Fails when package-lock.json resolves a package from anywhere other than the npm registry, or when the lockfile
# is out of date with package.json.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

foreign=$(jq --raw-output '.packages | to_entries[] | select(.value.resolved != null)
  | select(.value.resolved | startswith("https://registry.npmjs.org/") | not) | "\(.key): \(.value.resolved)"' \
  package-lock.json)
if [[ -n ${foreign} ]]; then
  printf 'package-lock.json resolves packages outside https://registry.npmjs.org/:\n%s\n' "${foreign}" >&2
  exit 1
fi
npm install --package-lock-only --ignore-scripts --no-audit --no-fund
if ! git diff --quiet -- package-lock.json; then
  echo 'package-lock.json is out of date with package.json: run npm install and commit the lockfile.' >&2
  git --no-pager diff --stat -- package-lock.json >&2
  exit 1
fi
