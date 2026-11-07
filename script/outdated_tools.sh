#!/usr/bin/env bash
# Fails while anything that the repository pins outside a Dependabot ecosystem is not on its newest release: the
# tools of tools/releases.txt (release binaries and npm), Node.js (.node-version), Python (.python-version) and
# the Java of the Nu validator (the java-version of the CI workflow). Dependabot keeps the npm packages, the
# actions and the pip-installed linters current, and `npm outdated` fails on an outdated npm package.
# Needs curl, jq, Python 3 with pip, and gh, authenticated (GH_TOKEN in CI).
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

# Python (.python-version) runs the pip-installed linters, so it may stay one minor version behind the newest
# CPython only while a pinned distribution of tools/requirements.txt publishes no wheel for the newer one.
python_latest=$(fetch https://raw.githubusercontent.com/actions/python-versions/main/versions-manifest.json \
  | jq --raw-output '[.[] | select(.stable)][0].version')
python_newest=${python_latest%.*}
python_version=$(tr -d '[:space:]' < "${root}/.python-version")
wheels=$(mktemp -d)
if [[ ${python_version} == "${python_newest}" ]]; then
  compare Python "${python_version}" "${python_newest}"
elif python3 -m pip download --quiet --disable-pip-version-check --no-deps --only-binary :all: \
  --python-version "${python_newest}" --implementation cp --platform manylinux_2_28_x86_64 \
  --platform manylinux_2_17_x86_64 --platform manylinux_2_5_x86_64 --dest "${wheels}" --require-hashes \
  -r "${root}/tools/requirements.txt" > /dev/null 2>&1; then
  compare Python "${python_version}" "${python_newest}"
else
  printf 'Python %s: held, because a linter of tools/requirements.txt has no wheel for Python %s yet\n' \
    "${python_version}" "${python_newest}"
fi

exit "${status}"
