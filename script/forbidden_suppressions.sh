#!/usr/bin/env bash
# Fails when a tracked file silences a linter, validator, scanner or warning, or when a linter configuration
# switches a rule off. Suppressions are forbidden everywhere in this repository: fix the cause.
# Markdown files are skipped because they document the rules.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

# This script names the patterns, so it is not scanned for them. package-lock.json and tools/requirements.txt
# only list dependencies.
files=$(git ls-files -z -- . ':(exclude)*.md' ':(exclude)script/forbidden_suppressions.sh' \
  ':(exclude)package-lock.json' ':(exclude)tools/requirements.txt' | tr '\0' '\n')

status=0
check() {
  local description=${1} pattern=${2} scope=${3:-.}
  local hits
  hits=$(printf '%s\n' "${files}" | grep -E "^${scope}" | xargs -r grep -nEHi -e "${pattern}" -- || true)
  if [[ -n ${hits} ]]; then
    printf 'Forbidden (%s):\n%s\n\n' "${description}" "${hits}"
    status=1
  fi
}

# Inline directives of the tools.
check 'ESLint directive' 'eslint-(disable|enable)|eslint +[a-z-]+: *(0|off)|/\* *global '
check 'html-validate directive' 'html-validate-(disable|enable)|\[html-validate-'
check 'Stylelint directive' 'stylelint-(disable|enable)'
check 'Prettier ignore comment' 'prettier-ignore'
check 'markdownlint directive' 'markdownlint-(disable|enable|capture|restore|configure-file)'
check 'typos ignore comment' 'spellchecker: *(off|disable|ignore)|typos: *(off|disable|ignore)'
check 'gitleaks allow' 'gitleaks:allow'
check 'ShellCheck disable' 'shellcheck +disable'
check 'yamllint directive' 'yamllint +(disable|enable)'
check 'zizmor ignore comment' 'zizmor: *ignore'
check 'editorconfig-checker directive' 'editorconfig-checker-(disable|enable)'
check 'CodeQL or LGTM suppression' 'lgtm\[|codeql\[|codeql-disable|lgtm: *ignore|nosec'
check 'TypeScript or coverage escape hatch' \
  '@ts-(ignore|nocheck|expect-error)|(istanbul|c8|v8) +ignore|stryker +disable'

# Command-line options and workflow inputs that silence or weaken a check.
check 'warning silenced' '--no-warnings|--no-deprecation|--disable-warning|NODE_NO_WARNINGS|PYTHONWARNINGS'
check 'Lighthouse output silenced or audits skipped' \
  'lighthouse.*--quiet|--log-level[= ](silent|error)|skip-audits|only-audits|only-categories|"?skipAudits"?'
check 'Nu validator message filter' '--filter(pattern|file)'
check 'lychee exclusion' \
  '--exclude|^ *exclude(_path|_all_private|_private|_loopback|_link_local)? *=' '(\.github|script|lychee)'
check 'npm audit threshold above low' 'audit-level[= ]*(moderate|high|critical)|npm audit.*--omit'
check 'dependency review allowance' \
  'allow-ghsas|allow-dependencies-licenses|fail-on-severity: *(moderate|high|critical)'
check 'harden-runner not blocking' 'egress-policy: *audit'
check 'zizmor persona or threshold lowered' \
  'zizmor.*--(persona[= ](regular|auditor)|min-(severity|confidence)[= ](low|medium|high))'

# Rules switched off or lowered in the configuration files.
check 'pa11y ignored rule' '"(ignore|hideElements)" *:' 'pa11y/'
check 'html-validate rule switched off' '"(off|warn)"|: *\[? *[01] *[],]' '\.htmlvalidate\.json'
check 'Stylelint rule switched off' ': *null|severity"? *: *"?warning' '\.stylelintrc'
check 'markdownlint rule switched off' ': *false' '\.markdownlint'
check 'yamllint rule switched off or lowered' ': *disable|level: *warning|^ *ignore:' '\.yamllint'

# Files that silence a tool wholesale.
for ignore in .lycheeignore .eslintignore .stylelintignore .markdownlintignore .gitleaksignore .typos.toml \
  _typos.toml typos.toml .gitleaks.toml .shellcheckrc .ecrc .editorconfig-checker.json .github/zizmor.yml \
  zizmor.yml .hadolint.yaml .yamllint .yamllint.yml .htmlvalidateignore .lighthouserc.json; do
  if printf '%s\n' "${files}" | grep -qxF "${ignore}"; then
    printf 'Forbidden (tool ignore or override file): %s\n\n' "${ignore}"
    status=1
  fi
done

exit "${status}"
