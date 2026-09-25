#!/usr/bin/env bash
# Self-test for the nbdybuilder package: installs into a scratch repo and globally into a scratch
# HOME, checks the files land, config is preserved on re-install, and scripts load their config.
# Usage: bash .cursor/skills/nbdybuilder/scripts/__tests__/package.test.sh
set -euo pipefail
PKG="$(cd "$(dirname "$0")/../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fail=0
ok() { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }

git -C "$TMP" init -q repo
bash "$PKG/install.sh" --repo "$TMP/repo" >/dev/null
for f in .cursor/commands/nbdybuilder.md .cursor/rules/nbdybuilder.mdc .cursor/nbdybuilder/harness.env \
         .cursor/skills/nbdybuilder/SKILL.md .cursor/skills/nbdybuilder/scripts/merge-pr.sh; do
  [ -f "$TMP/repo/$f" ] && ok "repo install creates $f" || bad "repo install creates $f"
done
[ -x "$TMP/repo/.cursor/skills/nbdybuilder/scripts/pre-push-check.sh" ] && ok "scripts stay executable" || bad "scripts stay executable"
cmp -s "$PKG/command.md" "$TMP/repo/.cursor/commands/nbdybuilder.md" && ok "command matches the package" || bad "command matches the package"

echo 'HARNESS_BASE=trunk' > "$TMP/repo/.cursor/nbdybuilder/harness.env"
echo '# mine' > "$TMP/repo/.cursor/nbdybuilder/project.md"
bash "$PKG/install.sh" --repo "$TMP/repo" >/dev/null
grep -q trunk "$TMP/repo/.cursor/nbdybuilder/harness.env" && ok "re-install keeps harness.env" || bad "re-install keeps harness.env"
grep -q mine "$TMP/repo/.cursor/nbdybuilder/project.md" && ok "re-install keeps project.md" || bad "re-install keeps project.md"

base="$(cd "$TMP/repo" && bash -c '. .cursor/skills/nbdybuilder/scripts/_config.sh; echo "$HARNESS_BASE"')"
[ "$base" = trunk ] && ok "_config.sh loads the repo harness.env" || bad "_config.sh loads the repo harness.env (got $base)"

HOME="$TMP/home" bash "$PKG/install.sh" --global >/dev/null
[ -f "$TMP/home/.cursor/commands/nbdybuilder.md" ] && ok "global install adds the command" || bad "global install adds the command"
[ -f "$TMP/home/.cursor/skills/nbdybuilder/install.sh" ] && ok "global install adds the package" || bad "global install adds the package"

REPO_ROOT="$(git -C "$PKG" rev-parse --show-toplevel)"
if [ -f "$REPO_ROOT/.cursor/commands/nbdybuilder.md" ]; then
  cmp -s "$PKG/command.md" "$REPO_ROOT/.cursor/commands/nbdybuilder.md" && ok "this repo's /nbdybuilder is current" || bad "this repo's /nbdybuilder differs from command.md (run install.sh --repo .)"
  cmp -s "$PKG/rule.mdc" "$REPO_ROOT/.cursor/rules/nbdybuilder.mdc" && ok "this repo's rule is current" || bad "this repo's rule differs from rule.mdc (run install.sh --repo .)"
fi

pattern="$(cd "$TMP/repo" && bash "$PKG/scripts/classify-failures.sh" --pattern)"
echo "Staging contract  Verify BIL-002 billing backfill parity failed" | grep -qE "$pattern" \
  && bad "infra pattern ignores product steps that mention billing" || ok "infra pattern ignores product steps that mention billing"
echo "The job was not started because recent account payments have failed or your spending limit needs to be increased." | grep -qE "$pattern" \
  && ok "infra pattern catches the GitHub billing block" || bad "infra pattern catches the GitHub billing block"

bash "$PKG/scripts/__tests__/resolvers.test.sh" >/dev/null && ok "resolver self-test" || bad "resolver self-test"
exit "$fail"
