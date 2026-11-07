#!/usr/bin/env bash
# Runs the checks of the CI, Workflow lint and Security workflows locally, with the same tools and settings, and
# fails if any of them fails. Only the checks that need GitHub itself (dependency review, CodeQL, OpenSSF
# Scorecard, the warning gates over the job logs) and the egress policy of harden-runner are CI-only.
#
# Usage: script/check.sh          every check
#        script/check.sh --fast   the offline static checks only (the pre-commit hook): no browser audits, no
#                                 link check, no registry or advisory lookups
#
# Needs: Node.js (.node-version) with the npm dependencies installed (`npm ci`), Python 3 (the linters of
# tools/requirements.txt are installed into .venv-tools/ on first use), Java (Nu validator), jq, and on the PATH
# the tools of tools/releases.txt: actionlint, editorconfig-checker, gitleaks, lychee and shfmt. The full run also
# needs gh (authenticated) and Chrome or Chromium (CHROME_PATH).
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly root
cd "${root}"

fast=false
if [[ ${1:-} == --fast ]]; then
  fast=true
fi

# The same Node.js deprecation policy as CI.
export NODE_OPTIONS=--throw-deprecation

missing=()
for tool in node npm python3 java jq actionlint editorconfig-checker gitleaks lychee shfmt; do
  command -v "${tool}" > /dev/null || missing+=("${tool}")
done
if [[ ${fast} == false ]]; then
  command -v gh > /dev/null || missing+=(gh)
  [[ -x ${CHROME_PATH:-} ]] || missing+=('Chrome (CHROME_PATH)')
fi
if ((${#missing[@]} > 0)); then
  printf 'Missing: %s\n' "${missing[@]}" >&2
  exit 1
fi

# The pip-installed linters, pinned by hash (tools/requirements.txt).
venv="${root}/.venv-tools"
if [[ ! -x "${venv}/bin/yamllint" || tools/requirements.txt -nt "${venv}/bin/yamllint" ]]; then
  python3 -m venv "${venv}"
  "${venv}/bin/python" -m pip install --quiet --disable-pip-version-check --require-hashes --only-binary :all: \
    -r tools/requirements.txt
  touch "${venv}/bin/yamllint"
fi
PATH="${venv}/bin:${root}/node_modules/.bin:${PATH}"

failed=()
run() {
  local name=${1}
  shift
  printf '\n==> %s\n' "${name}"
  if "$@"; then
    printf 'ok: %s\n' "${name}"
  else
    failed+=("${name}")
  fi
}

# CI: Lint.
run Prettier prettier --check .
run Stylelint stylelint --max-warnings 0 '**/*.css'
run markdownlint markdownlint-cli2 '**/*.md'
run yamllint yamllint --strict .
run ShellCheck shellcheck --enable=all --severity=style script/*.sh .githooks/pre-commit
run shfmt shfmt --diff script/*.sh .githooks/pre-commit
run editorconfig-checker editorconfig-checker
run typos typos --format brief
run 'No suppressions' script/forbidden_suppressions.sh
run 'No JavaScript' script/no_javascript.sh
run 'Stylesheet integrity' script/check_integrity.sh

# CI: HTML.
run html-validate html-validate --max-warnings 0 '*.html'
run 'Nu validator' java -jar node_modules/vnu-jar/build/dist/vnu.jar --Werror --also-check-css --also-check-svg \
  ./*.html ./*.css ./*.svg

# Workflow lint.
run actionlint env SHELLCHECK_OPTS='--enable=all --severity=style' actionlint -color
if [[ ${fast} == true ]]; then
  run zizmor zizmor --offline --persona pedantic --format plain .
else
  token=$(gh auth token)
  run zizmor env GH_TOKEN="${token}" \
    zizmor --persona pedantic --format plain .
fi

# Security: secrets.
run gitleaks gitleaks git --redact --exit-code 1 .

if [[ ${fast} == false ]]; then
  # Security: dependencies.
  run 'Lockfile' script/check_lockfile.sh
  run 'npm audit' npm audit --audit-level=low
  run 'npm audit signatures' npm audit signatures
  run 'npm outdated' npm outdated
  run 'Pinned tools are current' script/outdated_tools.sh

  # CI: Links.
  run lychee env GITHUB_TOKEN="${token}" lychee --no-progress --include-fragments --index-files index.html \
    --root-dir "${root}" --max-retries 3 '*.html' '*.md'

  # CI: Accessibility and Lighthouse, on a local server of the site.
  # A free port, so that no other local server answers instead of this one.
  port=$(python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')
  python3 -m http.server "${port}" --bind 127.0.0.1 > /dev/null 2>&1 &
  server=$!
  trap 'kill "${server}" 2> /dev/null || true' EXIT
  curl --fail --silent --show-error --retry 10 --retry-connrefused --retry-delay 1 --output /dev/null \
    "http://127.0.0.1:${port}/"
  kill -0 "${server}"
  run 'pa11y and Lighthouse' env PUPPETEER_EXECUTABLE_PATH="${CHROME_PATH}" \
    script/browser_audit.sh "http://127.0.0.1:${port}"
fi

if ((${#failed[@]} > 0)); then
  printf '\nFailed:\n' >&2
  printf '  %s\n' "${failed[@]}" >&2
  exit 1
fi
printf '\nEvery check passed.\n'
