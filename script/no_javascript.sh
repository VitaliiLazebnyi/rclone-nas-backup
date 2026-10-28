#!/usr/bin/env bash
# Fails when the site gains any JavaScript: a script file, a <script> element or an inline event handler.
# The site is static HTML and CSS, so it has no ESLint, unit test or mutation testing gate; adding JavaScript
# requires adding those gates first (in a separate .js file, never inline).
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

status=0
scripts=$(git ls-files -- '*.js' '*.mjs' '*.cjs' '*.jsx' '*.ts' '*.mts' '*.cts' '*.tsx')
if [[ -n "${scripts}" ]]; then
  printf 'JavaScript files:\n%s\n\n' "${scripts}"
  status=1
fi

inline=$(git ls-files -z -- '*.html' '*.svg' | xargs -0 -r grep -nEHi -e '<script|[[:space:]]on[a-z]+ *=|javascript:' -- || true)
if [[ -n "${inline}" ]]; then
  printf 'Inline JavaScript:\n%s\n\n' "${inline}"
  status=1
fi

exit "${status}"
