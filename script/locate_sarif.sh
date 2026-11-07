#!/usr/bin/env bash
# Scorecard reports findings about the whole repository (Branch-Protection, Code-Review, ...) under the
# placeholder URI "no file associated with this alert", which upload-sarif rejects with a warning. Points them at
# the Scorecard workflow, the file that produces them.
# Usage: script/locate_sarif.sh <results.sarif>
set -euo pipefail

sarif=${1}
located=$(jq '(.runs[].results[]?.locations[]?.physicalLocation.artifactLocation
  | select(.uri == "no file associated with this alert")).uri = ".github/workflows/scorecard.yml"' "${sarif}")
printf '%s\n' "${located}" > "${sarif}"
