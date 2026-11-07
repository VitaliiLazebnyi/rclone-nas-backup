#!/usr/bin/env bash
# Fails while anything that the repository pins outside a Dependabot ecosystem is not on its newest release: the
# tools of tools/releases.txt (release binaries and npm), Node.js (.node-version) and the Java of the Nu validator
# (the java-version of the CI workflow). Dependabot keeps the npm packages, the actions and the pip-installed
# linters current, and `npm outdated` fails on an outdated npm package.
# Needs curl, jq and gh, authenticated (GH_TOKEN in CI).
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly root

status=0
compare() {
  local name=${1} pinned=${2} newest=${3}
  if [[ ${pinned} == "${newest}" ]]; then
    printf '%s %s is the newest release\n' "${name}" "${pinned}"
  else
    printf '::error::%s is pinned to %s, but the newest release is %s\n' "${name}" "${pinned}" "${newest}"
    status=1
  fi
}

fetch() {
  curl --fail --silent --show-error --location "${1}"
}

# The release tags read v1.2.3, or lychee-v1.2.3 for lychee.
tools=$("${root}/script/install_tools.sh" --list)
while read -r tool version repo; do
  tag=$(gh api "repos/${repo}/releases/latest" --jq .tag_name)
  tag=${tag#"${tool}-"}
  compare "${tool}" "${version}" "${tag#v}"
done <<< "${tools}"

# The newest Node.js release that is not a pre-release (the index lists the newest first).
node_latest=$(fetch https://nodejs.org/dist/index.json \
  | jq --raw-output 'map(select(.version | test("^v[0-9]+[.][0-9]+[.][0-9]+$")))[0].version')
node_version=$(tr -d '[:space:]' < "${root}/.node-version")
compare Node.js "${node_version}" "${node_latest#v}"

java_latest=$(fetch https://api.adoptium.net/v3/info/available_releases | jq --raw-output .most_recent_feature_release)
java_version=$(sed -nE 's/^ *java-version: *"?([0-9]+)"?$/\1/p' "${root}/.github/workflows/ci.yml")
compare 'Java (Temurin)' "${java_version}" "${java_latest}"

exit "${status}"
