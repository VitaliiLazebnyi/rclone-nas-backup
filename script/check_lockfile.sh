#!/usr/bin/env bash
# Fails when package-lock.json resolves a package from anywhere other than the npm registry, or when the lockfile
# is out of date with package.json. It installs nothing and rewrites no file: the lockfile must already be the one
# `npm install` writes.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

foreign=$(jq --raw-output '.packages | to_entries[] | select(.value.resolved != null)
  | select(.value.resolved | startswith("https://registry.npmjs.org/") | not) | "\(.key): \(.value.resolved)"' \
  package-lock.json)
if [[ -n ${foreign} ]]; then
  printf 'package-lock.json resolves packages outside https://registry.npmjs.org/:\n%s\n' "${foreign}" >&2
  exit 1
fi

stale() {
  printf 'package-lock.json is out of date with package.json (%s): run npm install and commit the lockfile.\n' \
    "${1}" >&2
  exit 1
}

# The root entry of the lockfile repeats the fields of package.json it was resolved from, so a dependency removed
# from package.json, or a changed name, version, license or engine, shows up as a difference.
manifest='{name, version, license, bin, engines, dependencies, devDependencies, optionalDependencies,
  peerDependencies} | with_entries(select(.value != null))'
jq --exit-status --null-input --slurpfile manifest package.json --slurpfile lock package-lock.json \
  "(\$manifest[0] | ${manifest}) == (\$lock[0].packages[\"\"] | ${manifest})" > /dev/null \
  || stale 'its root entry differs'

# npm ci refuses a lockfile that does not satisfy every dependency range and override of package.json; with
# --dry-run it only resolves the tree and installs nothing.
npm ci --dry-run --ignore-scripts --no-audit --no-fund > /dev/null || stale 'npm ci refuses it'
