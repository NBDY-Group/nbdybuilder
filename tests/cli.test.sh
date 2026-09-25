#!/usr/bin/env bash
# End-to-end test of bin/nbdybuilder against a scratch HOME and a local bare remote standing in for GitHub.
# Needs at least two build tags. Usage: bash tests/cli.test.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fail=0
ok() { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }

git clone -q --bare "$ROOT" "$TMP/remote.git"
git clone -q "$TMP/remote.git" "$TMP/work"
git -C "$TMP/work" config user.name "nbdybuilder test"
git -C "$TMP/work" config user.email test@example.invalid
export HOME="$TMP/home" NBDY_NO_GH=1
mkdir -p "$HOME"
CLI="$TMP/work/bin/nbdybuilder"
L="$(git -C "$TMP/work" tag -l 'build-*' --sort=-version:refname | head -1)"
NEXT="build-$(( ${L#build-} + 1 ))"
build_of() { head -1 "$1/VERSION"; }
active() { git -C "$TMP/remote.git" rev-parse -q --verify refs/heads/active || true; }
tag_sha() { git -C "$TMP/work" rev-list -n1 "$1"; }

"$CLI" use build-1 >/dev/null
[ "$(build_of "$HOME/.cursor/skills/nbdybuilder")" = build-1 ] && ok "use installs build-1 and stamps VERSION" || bad "use installs build-1 and stamps VERSION"
[ "$(active)" = "$(tag_sha build-1)" ] && ok "use points active at build-1" || bad "use points active at build-1"
[ ! -e "$HOME/.cursor/commands/nbdybuilder.md" ] && ok "no separate global command" || bad "no separate global command"

STORE="$HOME/Library/Application Support/Cursor/AgentStores/cursor_agent_stores/u1/files/skills"
mkdir -p "$STORE"
mv "$HOME/.cursor/skills/nbdybuilder" "$STORE/"
"$CLI" use $L >/dev/null
[ "$(build_of "$STORE/nbdybuilder")" = $L ] && ok "use updates the synced copy" || bad "use updates the synced copy"
[ ! -e "$HOME/.cursor/skills/nbdybuilder" ] && ok "no second, unsynced copy appears" || bad "no second, unsynced copy appears"

mkdir -p "$HOME/.cursor/skills/nbdybuilder"
"$CLI" use $L >/dev/null
[ ! -e "$HOME/.cursor/skills/nbdybuilder" ] && compgen -G "$HOME/.Trash/nbdybuilder-duplicate-*" >/dev/null && ok "a stray unsynced copy goes to the Trash" || bad "a stray unsynced copy goes to the Trash"

echo "Tuned line." >> "$TMP/work/skills/nbdybuilder/worker-brief.md"
"$CLI" try >/dev/null
case "$(build_of "$STORE/nbdybuilder")" in "dev (based on $L"*) ok "try installs the working tree as a dev build" ;; *) bad "try installs the working tree as a dev build" ;; esac
grep -q "Tuned line." "$STORE/nbdybuilder/worker-brief.md" && ok "try carries the uncommitted edit" || bad "try carries the uncommitted edit"
[ "$(active)" = "$(tag_sha $L)" ] && ok "try leaves active alone" || bad "try leaves active alone"
[ "$(head -1 "$TMP/work/skills/nbdybuilder/VERSION")" = $L ] && ok "try doesn't touch the source VERSION" || bad "try doesn't touch the source VERSION"

"$CLI" release "Tuned the lane brief" >/dev/null
[ "$(build_of "$STORE/nbdybuilder")" = $NEXT ] && ok "release installs $NEXT" || bad "release installs $NEXT"
git -C "$TMP/remote.git" rev-parse -q --verify refs/tags/$NEXT >/dev/null && ok "release pushes the $NEXT tag" || bad "release pushes the $NEXT tag"
[ "$(active)" = "$(tag_sha $NEXT)" ] && ok "release points active at $NEXT" || bad "release points active at $NEXT"
grep -q "^## $NEXT — .*" "$TMP/work/CHANGELOG.md" && grep -q "Tuned the lane brief" "$TMP/work/CHANGELOG.md" && ok "release adds a changelog entry" || bad "release adds a changelog entry"
"$CLI" release "Nothing new" >/dev/null 2>&1 && bad "release refuses when nothing changed" || ok "release refuses when nothing changed"

"$CLI" use previous >/dev/null
[ "$(build_of "$STORE/nbdybuilder")" = $L ] && ! grep -q "Tuned line." "$STORE/nbdybuilder/worker-brief.md" && ok "use previous rolls back to $L" || bad "use previous rolls back to $L"
[ "$(active)" = "$(tag_sha $L)" ] && ok "rollback moves active back" || bad "rollback moves active back"
listing="$("$CLI" list)"
grep -q "^\* $L " <<<"$listing" && ok "list marks the installed build" || bad "list marks the installed build"
report="$("$CLI" status)"
grep -q "branch active -> $L" <<<"$report" && ok "status reports GitHub's active build" || bad "status reports GitHub's active build"
"$CLI" use build-99 >/dev/null 2>&1 && bad "use rejects a build that doesn't exist" || ok "use rejects a build that doesn't exist"

git init -q "$TMP/app"
"$CLI" vendor "$TMP/app" >/dev/null
[ "$(build_of "$TMP/app/.cursor/skills/nbdybuilder")" = $L ] && ok "vendor copies the installed build into a repo" || bad "vendor copies the installed build into a repo"
exit "$fail"
