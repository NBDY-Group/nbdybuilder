#!/usr/bin/env bash
# Read-only snapshot of the merge gate: open PRs with mergeability, queued/running runs, and the base branch's latest results.
# Uses `gh api` so it keeps working when `gh pr`/GraphQL calls are unavailable.
# Usage: gate-status.sh [owner/repo]
set -euo pipefail
. "$(dirname "$0")/_config.sh"
REPO="${1:-$(gh repo view --json nameWithOwner --jq .nameWithOwner)}"

echo "== open PRs"
for n in $(gh api "repos/$REPO/pulls?state=open&per_page=50" --jq '.[].number'); do
  gh api "repos/$REPO/pulls/$n" --jq '"#\(.number) \(.head.ref) \(.head.sha[:8]) mergeable=\(.mergeable) state=\(.mergeable_state)\(if .draft then " (draft)" else "" end)"'
done

for status in queued in_progress; do
  echo "== runs $status"
  gh api "repos/$REPO/actions/runs?status=$status&per_page=30" \
    --jq '.workflow_runs[] | "\(.created_at[5:16]) \(.name) \(.head_branch) \(.head_sha[:8])"'
done

echo "== latest on $HARNESS_BASE"
gh api "repos/$REPO/actions/runs?branch=$HARNESS_BASE&per_page=6" \
  --jq '.workflow_runs[] | "\(.name) \(.status)/\(.conclusion // "-") \(.head_sha[:8]) \(.created_at[5:16])"'
