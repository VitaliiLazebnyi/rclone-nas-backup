#!/usr/bin/env bash
# Fails unless every page links style.css with the Subresource Integrity hash of the committed stylesheet. A stale
# hash makes browsers block the stylesheet. After changing style.css, update the pages with the hash printed here.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

expected="sha384-$(openssl dgst -sha384 -binary style.css | openssl base64 -A)"
status=0
pages=$(git ls-files -- '*.html')
while read -r page; do
  if grep -qF "integrity=\"${expected}\"" "${page}"; then
    echo "${page}: style.css integrity is ${expected}"
  else
    echo "${page}: style.css must be linked with integrity=\"${expected}\"" >&2
    status=1
  fi
done <<< "${pages}"
exit "${status}"
