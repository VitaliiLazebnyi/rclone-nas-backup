#!/usr/bin/env bash
# Fails when the log of any other job of the current workflow run contains a warning or a deprecation notice.
# Run by the "Warning gate" job; the repository tolerates no warnings.
#
# Needs GH_TOKEN (actions: read), GITHUB_REPOSITORY, GITHUB_RUN_ID and GATE_JOB_NAME (the name of the gate job
# itself, whose own log quotes the pattern).
set -euo pipefail

# Case-insensitive: "npm warn", "[warn]", "Warning:", "WARNING", "deprecated", "DEPRECATION", "::warning",
# "##[warning]" and GitHub's "Node.js 20 actions are deprecated" all match. "warnings" (as in "--max-warnings 0")
# does not.
pattern='\bwarn(ing)?\b|deprecate|deprecation'

jobs=$(gh api --paginate "repos/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}/jobs?per_page=100" \
  --jq ".jobs[] | select(.name != \"${GATE_JOB_NAME}\" and .conclusion != \"skipped\") | \"\(.id)\t\(.name)\"")

status=0
while IFS=$'\t' read -r id name; do
  [ -n "$id" ] || continue
  # Downloaded with curl: depending on its version, gh refuses to print a log that contains terminal escape
  # sequences (colored tool output).
  log=$(curl --fail --silent --show-error --location \
    --header "Authorization: Bearer ${GH_TOKEN}" --header 'Accept: application/vnd.github+json' \
    "${GITHUB_API_URL:-https://api.github.com}/repos/${GITHUB_REPOSITORY}/actions/jobs/${id}/logs")
  hits=$(printf '%s\n' "$log" | grep -niE -e "$pattern" || true)
  if [ -n "$hits" ]; then
    printf '::error::Warnings in the log of job "%s"\n%s\n\n' "$name" "$hits"
    status=1
  else
    printf 'No warnings in the log of job "%s"\n' "$name"
  fi
done <<< "$jobs"

exit "$status"
