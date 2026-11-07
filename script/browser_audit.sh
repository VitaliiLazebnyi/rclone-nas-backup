#!/usr/bin/env bash
# Audits every page (every tracked .html file) of the site served at <base-url> in Chrome:
# - pa11y with axe-core (WCAG 2.0, 2.1 and 2.2 A and AA, best practices) and with HTML_CodeSniffer (WCAG 2 AA),
#   warnings and notices included;
# - Lighthouse, whose every category (performance, accessibility, best practices, SEO, agentic browsing) must
#   score 100 with no run warning.
# Needs the npm dependencies and Chrome (CHROME_PATH and PUPPETEER_EXECUTABLE_PATH).
# Usage: script/browser_audit.sh <base-url>
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly root
base=${1%/}
bin="${root}/node_modules/.bin"
reports=$(mktemp -d)

status=0
pages=$(git -C "${root}" ls-files -- '*.html')
while read -r page; do
  url="${base}/${page}"
  [[ ${page} != index.html ]] || url="${base}/"
  echo "== ${url}"

  for runner in axe htmlcs; do
    "${bin}/pa11y" --config "${root}/pa11y/${runner}.json" "${url}" < /dev/null || status=1
  done

  report="${reports}/${page%.html}.json"
  # Lighthouse logs at its default level, so that any warning of its own reaches the CI warning gate. Only its
  # progress lines that name the audit being run are dropped: titles such as "Auditing: Avoids deprecated APIs"
  # are not warnings. The run's own problems are in the report's runWarnings, which fail the check below.
  "${bin}/lighthouse" "${url}" --chrome-flags=--headless=new --output=json --output-path="${report}" \
    < /dev/null 2>&1 | sed -e '/ LH:status Auditing: /d'
  jq --raw-output '.categories[] | "  \(.title): \(.score * 100)"' "${report}"
  jq --raw-output '.audits[] | select(.score != null and .score < 1) | "  audit below 100: \(.id) (\(.title))"' \
    "${report}"
  jq --raw-output '.runWarnings[] | "  run problem: \(.)"' "${report}"
  jq --exit-status '([.categories[].score] | all(. == 1)) and (.runWarnings | length == 0)' "${report}" \
    > /dev/null || status=1
done <<< "${pages}"

exit "${status}"
