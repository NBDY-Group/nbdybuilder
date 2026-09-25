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

touch "$TMP/repo/.cursor/skills/nbdybuilder/dropped-by-a-newer-build.md"
bash "$PKG/install.sh" --repo "$TMP/repo" >/dev/null
[ ! -e "$TMP/repo/.cursor/skills/nbdybuilder/dropped-by-a-newer-build.md" ] && ok "re-install removes files the package no longer has" || bad "re-install removes files the package no longer has"

cp -R "$PKG" "$TMP/built" && echo "build-9" > "$TMP/built/VERSION"
git -C "$TMP" init -q repo2
bash "$TMP/built/install.sh" --repo "$TMP/repo2" >/dev/null
grep -qx build-9 "$TMP/repo2/.cursor/skills/nbdybuilder/VERSION" && ok "repo install carries VERSION" || bad "repo install carries VERSION"
printf 'build\n' > "$TMP/repo2/.gitignore"
git -C "$TMP/repo2" config core.ignorecase true
git -C "$TMP/repo2" check-ignore -q .cursor/skills/nbdybuilder/VERSION \
  && bad "VERSION survives a repo that ignores build/" || ok "VERSION survives a repo that ignores build/"

HOME="$TMP/home" bash "$PKG/install.sh" --global >/dev/null
[ -f "$TMP/home/.cursor/skills/nbdybuilder/install.sh" ] && ok "global install adds the package" || bad "global install adds the package"
[ ! -e "$TMP/home/.cursor/commands/nbdybuilder.md" ] && ok "global install adds no separate command" || bad "global install adds no separate command"

SYNCED="$TMP/home2/Library/Application Support/Cursor/AgentStores/cursor_agent_stores/u1/files/skills"
mkdir -p "$SYNCED/nbdybuilder"
HOME="$TMP/home2" bash "$PKG/install.sh" --global >/dev/null
[ -f "$SYNCED/nbdybuilder/SKILL.md" ] && [ ! -e "$TMP/home2/.cursor/skills/nbdybuilder" ] \
  && ok "global install updates the synced copy, not a second one" || bad "global install updates the synced copy, not a second one"

REPO_ROOT="$(git -C "$PKG" rev-parse --show-toplevel 2>/dev/null || true)"
if [ -n "$REPO_ROOT" ] && [ -f "$REPO_ROOT/.cursor/commands/nbdybuilder.md" ]; then
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
