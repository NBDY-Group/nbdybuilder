#!/usr/bin/env bash
# Classify a failed workflow run's jobs as INFRA, MIXED or PRODUCT from its failed-step logs.
# INFRA is only a hint for one-off external faults: a failure that recurs across runs is a defect regardless.
# Add project signatures with HARNESS_INFRA_PATTERN_EXTRA in .cursor/nbdybuilder/harness.env.
# Usage: classify-failures.sh <run-id> [owner/repo]
set -euo pipefail
. "$(dirname "$0")/_config.sh"
INFRA_PATTERN='server certificate verification failed|Could not resolve host|ECONNRESET|ETIMEDOUT|socket hang up|JavaScript heap out of memory|The runner has received a shutdown signal|spending limit needs to be increased|recent account payments have failed|exit code 100.*apt|toomanyrequests|pull rate limit|error pulling image|failed to pull image|Error response from daemon: (Get|Head) "https://|address already in use'
if [ -n "$HARNESS_INFRA_PATTERN_EXTRA" ]; then
  INFRA_PATTERN="$INFRA_PATTERN|$HARNESS_INFRA_PATTERN_EXTRA"
fi
if [ "${1:-}" = "--pattern" ]; then
  printf '%s\n' "$INFRA_PATTERN"
  exit 0
fi
RUN="${1:?run id required}"
REPO="${2:-$(gh repo view --json nameWithOwner --jq .nameWithOwner)}"

LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT
gh run view "$RUN" --repo "$REPO" --log-failed > "$LOG" 2>/dev/null || true

gh api "repos/$REPO/actions/runs/$RUN/jobs?per_page=100" \
  --jq '.jobs[] | select(.conclusion=="failure") | "\(.name)\t\(.steps|length)"' |
while IFS=$'\t' read -r job steps; do
  if [ "$steps" = "0" ]; then
    echo "INFRA    $job (zero steps: budget or runner allocation; do not rerun until the budget is restored)"
    continue
  fi
  job_log="$(grep -F "$job" "$LOG" || true)"
  failed_tests="$(printf '%s\n' "$job_log" | grep -oE '(✘ +[0-9]+|[0-9]+\)) \[[^]]+\] › [^(]+' | sed -E 's/^(✘ +[0-9]+|[0-9]+\)) //' | sort -u || true)"
  infra_hits="$(printf '%s\n' "$job_log" | grep -cE "$INFRA_PATTERN" || true)"
  # next/font fetches Google Fonts at build time; an unexpected response surfaces as this
  # TypeError. Either line alone can be a real defect, so require both.
  if printf '%s\n' "$job_log" | grep -qF 'An error occurred in `next/font`' &&
     printf '%s\n' "$job_log" | grep -qF "Cannot read properties of null (reading '1')"; then
    infra_hits=$((infra_hits + 1))
  fi
  if [ -z "$failed_tests" ] && [ "$infra_hits" -gt 0 ]; then
    echo "INFRA    $job ($infra_hits infrastructure signature lines, no failed tests)"
  elif [ -n "$failed_tests" ] && [ "$infra_hits" -gt 0 ]; then
    echo "MIXED    $job ($infra_hits infrastructure lines); check each test:"
    printf '         %s\n' "$failed_tests"
  elif [ -n "$failed_tests" ]; then
    echo "PRODUCT  $job:"
    printf '         %s\n' "$failed_tests"
  else
    echo "PRODUCT  $job (no infrastructure signature; read the log)"
  fi
done
