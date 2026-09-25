#!/usr/bin/env bash
# Land a green PR branch on the base branch as a --no-ff merge commit.
# Doc-only conflicts are resolved automatically: log files keep both sides verbatim, ledger
# tables merge per row, prose docs keep both sides, generated files are regenerated. Any other
# conflict aborts so the owning lane can resolve it on its branch.
# Generated files are also regenerated when they merged cleanly but went stale.
# Usage: merge-pr.sh <pr-number> <branch> [base]
set -euo pipefail
. "$(dirname "$0")/_config.sh"
PR="$1"; BRANCH="$2"; BASE="${3:-$HARNESS_BASE}"

git -C "$NBDY_REPO_ROOT" fetch -q origin "$BASE" "$BRANCH"
WT="$(mktemp -d)"
cleanup() { git -C "$NBDY_REPO_ROOT" worktree remove --force "$WT" >/dev/null 2>&1 || true; }
trap cleanup EXIT
git -C "$NBDY_REPO_ROOT" worktree add -q --detach "$WT" "origin/$BASE"
cd "$WT"
for d in node_modules packages/*/node_modules apps/*/node_modules; do
  [ -d "$NBDY_REPO_ROOT/$d" ] && ln -sfn "$NBDY_REPO_ROOT/$d" "$d"
done

git merge --no-ff --no-commit "origin/$BRANCH" >/dev/null 2>&1 || true
mapfile -t conflicts < <(git diff --name-only --diff-filter=U)
regen=0
for f in "${conflicts[@]}"; do
  if [[ " $HARNESS_LOG_FILES " == *" $f "* ]]; then
    python3 "$NBDY_SCRIPTS/union-resolve.py" "$f" >/dev/null
  elif [ -n "$HARNESS_LEDGER_FILES" ] && [[ " $HARNESS_LEDGER_FILES " == *" $f "* ]]; then
    python3 "$NBDY_SCRIPTS/merge-ledger-rows.py" "$f" >/dev/null
  elif [ -n "$HARNESS_GENERATED_GLOB" ] && [[ "$f" == $HARNESS_GENERATED_GLOB* ]]; then
    git checkout --theirs -- "$f"; regen=1
  elif [[ "$f" == $HARNESS_PROSE_GLOB*.md ]]; then
    python3 "$NBDY_SCRIPTS/union-resolve.py" "$f" >/dev/null
  else
    echo "merge-pr: code conflict in $f; resolve it on the branch first" >&2
    git merge --abort; exit 2
  fi
  git add "$f"
done
if [ -n "$HARNESS_GENERATED_GLOB" ] && [ -n "$HARNESS_REGEN_CMD" ]; then
  if [ "$regen" = 1 ] || ! { [ -z "$HARNESS_VERIFY_CMD" ] || $HARNESS_VERIFY_CMD >/dev/null 2>&1; }; then
    $HARNESS_REGEN_CMD >/dev/null
    git add "$HARNESS_GENERATED_GLOB"
  fi
fi
if [ -n "$HARNESS_VERIFY_CMD" ]; then
  $HARNESS_VERIFY_CMD | tail -1
fi
OWNER="$(gh repo view --json nameWithOwner --jq .nameWithOwner | cut -d/ -f1)"
git -c user.name="$HARNESS_COMMIT_NAME" -c user.email="$HARNESS_COMMIT_EMAIL" \
  commit -q --no-verify -m "Merge pull request #$PR from $OWNER/$BRANCH"
git push -q origin "HEAD:$BASE"
echo "merge-pr: #$PR landed on $BASE as $(git rev-parse --short HEAD) (resolved: ${conflicts[*]:-none})"
