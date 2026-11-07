#!/usr/bin/env bash
# Downloads the named tools of tools/releases.txt (the linux x86_64 release binaries, and npm from the npm
# registry), verifies each against its pinned SHA-256 and installs it into <directory>, which is also added to the
# PATH of the later steps of a GitHub Actions job (GITHUB_PATH). npm runs on the Node.js of .node-version, which
# must be the active node.
# Usage: script/install_tools.sh <directory> <tool>...
#        script/install_tools.sh --list   (prints "<tool> <version> <GitHub repository>" for every pinned tool)
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly root

# The GitHub repository whose releases publish the tool.
repository() {
  case "${1}" in
    actionlint) echo rhysd/actionlint ;;
    editorconfig-checker) echo editorconfig-checker/editorconfig-checker ;;
    gitleaks) echo gitleaks/gitleaks ;;
    lychee) echo lycheeverse/lychee ;;
    npm) echo npm/cli ;;
    shfmt) echo mvdan/sh ;;
    *)
      echo "Unknown tool: ${1}" >&2
      return 1
      ;;
  esac
}

# Prints "<version> <sha256>" of a tool from tools/releases.txt.
pin() {
  local pinned
  pinned=$(awk -v tool="${1}" '$1 == tool { print $2, $3 }' "${root}/tools/releases.txt")
  if [[ -z ${pinned} ]]; then
    echo "${1} is not pinned in tools/releases.txt" >&2
    return 1
  fi
  echo "${pinned}"
}

install_tool() {
  local tool=${1} directory=${2}
  local pinned version sha256 repo release asset
  pinned=$(pin "${tool}")
  read -r version sha256 <<< "${pinned}"
  repo=$(repository "${tool}")
  release="https://github.com/${repo}/releases/download"
  case "${tool}" in
    npm)
      release=https://registry.npmjs.org
      asset="npm/-/npm-${version}.tgz"
      ;;
    actionlint) asset="v${version}/actionlint_${version}_linux_amd64.tar.gz" ;;
    editorconfig-checker) asset="v${version}/editorconfig-checker-linux-amd64.tar.gz" ;;
    gitleaks) asset="v${version}/gitleaks_${version}_linux_x64.tar.gz" ;;
    lychee) asset="lychee-v${version}/lychee-x86_64-unknown-linux-gnu.tar.gz" ;;
    shfmt) asset="v${version}/shfmt_v${version}_linux_amd64" ;;
    *) return 1 ;;
  esac

  local download
  download="$(mktemp -d)/${asset##*/}"
  curl --fail --silent --show-error --location --output "${download}" "${release}/${asset}"
  echo "${sha256}  ${download}" | sha256sum --check --strict
  case "${tool}" in
    lychee) tar -xzf "${download}" -C "${directory}" --strip-components 1 lychee-x86_64-unknown-linux-gnu/lychee ;;
    shfmt) install -m 0755 "${download}" "${directory}/shfmt" ;;
    npm) install_npm "${download}" "${directory}" "${version}" ;;
    *) tar -xzf "${download}" -C "${directory}" "${tool}" ;;
  esac
}

# Unpacks the npm package next to <directory>, puts npm and npx wrappers into <directory>, and checks the versions.
install_npm() {
  local archive=${1} directory=${2} version=${3}
  local package="${directory}/../npm-${version}" command
  mkdir -p "${package}"
  package=$(cd "${package}" && pwd)
  tar -xzf "${archive}" -C "${package}" --strip-components 1
  for command in npm npx; do
    printf '#!/usr/bin/env bash\nexec node "%s/bin/%s-cli.js" "$@"\n' "${package}" "${command}" \
      > "${directory}/${command}"
    chmod 0755 "${directory}/${command}"
  done

  local node_version npm_version expected_node
  node_version=$(node --version)
  npm_version=$("${directory}/npm" --version)
  expected_node=$(tr -d '[:space:]' < "${root}/.node-version")
  echo "node ${node_version}, npm ${npm_version}"
  if [[ ${node_version} != "v${expected_node}" || ${npm_version} != "${version}" ]]; then
    echo "Expected node v${expected_node} and npm ${version}" >&2
    return 1
  fi
}

list() {
  local tool version repo
  while read -r tool version _; do
    [[ ${tool} == '#'* ]] && continue
    repo=$(repository "${tool}")
    echo "${tool} ${version} ${repo}"
  done < "${root}/tools/releases.txt"
}

main() {
  if [[ ${1} == --list ]]; then
    list
    return
  fi
  local directory=${1}
  shift
  mkdir -p "${directory}"
  local tool
  for tool in "$@"; do
    install_tool "${tool}" "${directory}"
  done
  if [[ -n ${GITHUB_PATH:-} ]]; then
    echo "${directory}" >> "${GITHUB_PATH}"
  fi
}

main "$@"
