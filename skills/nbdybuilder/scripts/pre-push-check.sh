#!/usr/bin/env bash
# Fast pre-push checks: commit identity, forbidden patterns in the branch diff, and the Semgrep
# rules remote CI runs. When rules are configured, missing semgrep fails the check unless
# HARNESS_ALLOW_NO_SEMGREP=1.
# Usage: pre-push-check.sh [base-ref]
set -euo pipefail
. "$(dirname "$0")/_config.sh"
BASE="${1:-origin/$HARNESS_BASE}"
status=0

bad_authors="$(git log --format='%h %ae' "$BASE"..HEAD | awk -v e="$HARNESS_COMMIT_EMAIL" '$2 != e')"
if [ -n "$bad_authors" ]; then
  echo "Commits not authored as $HARNESS_COMMIT_EMAIL:"
  echo "$bad_authors"
  status=1
fi

hits="$(git diff "$BASE"...HEAD -- . ':(exclude)*.md' ':(exclude)scripts/harness/*' ':(exclude).cursor/skills/nbdybuilder/*' \
  | grep -E '^\+' | grep -nE "$HARNESS_FORBIDDEN_PATTERN" || true)"
if [ -n "$hits" ]; then
  echo "Forbidden patterns in added lines:"
  echo "$hits"
  status=1
fi

PARSE='import json,sys; r=json.load(sys.stdin)["results"]; print("\n".join(f"{x["path"]}:{x["start"]["line"]} {x["check_id"]}" for x in r))'
semgrep_findings() {
  local out
  if ! out="$(semgrep "$@" --severity ERROR --quiet --json --metrics=off 2>/dev/null | python3 -c "$PARSE" 2>/dev/null)"; then
    echo "semgrep did not produce a result (run it by hand: semgrep $*)"
    return
  fi
  printf '%s' "$out"
}
if [ -n "$HARNESS_SEMGREP_RULES" ] || [ "$HARNESS_SEMGREP_PUBLIC" = 1 ]; then
  if command -v semgrep >/dev/null 2>&1; then
    if [ -n "$HARNESS_SEMGREP_RULES" ] && [ -f "$HARNESS_SEMGREP_RULES" ]; then
      # shellcheck disable=SC2086
      findings="$(semgrep_findings --config "$HARNESS_SEMGREP_RULES" $HARNESS_SEMGREP_PATHS)"
      if [ -n "$findings" ]; then
        echo "Semgrep ERROR findings ($HARNESS_SEMGREP_RULES):"
        echo "$findings"
        status=1
      fi
    fi
    if [ "$HARNESS_SEMGREP_PUBLIC" = 1 ]; then
      # shellcheck disable=SC2086
      public="$(semgrep_findings scan --config p/default --config p/security-audit --config p/secrets --config p/jwt --config p/nodejs ${HARNESS_SEMGREP_PUBLIC_PATHS:-$HARNESS_SEMGREP_PATHS})"
      if [ -n "$public" ]; then
        echo "Semgrep ERROR findings (public rulesets):"
        echo "$public"
        status=1
      fi
    fi
  elif [ "${HARNESS_ALLOW_NO_SEMGREP:-0}" = 1 ]; then
    echo "pre-push-check: semgrep not installed; skipped (HARNESS_ALLOW_NO_SEMGREP=1)"
  else
    echo "pre-push-check: semgrep not installed (pip install --user semgrep); set HARNESS_ALLOW_NO_SEMGREP=1 to skip"
    status=1
  fi
fi

[ "$status" -eq 0 ] && echo "pre-push-check: clean"
exit "$status"
