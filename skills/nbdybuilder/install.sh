#!/usr/bin/env bash
# Install the nbdybuilder harness.
#   install.sh --global        Make /nbdybuilder available in every local Cursor session (~/.cursor).
#   install.sh --repo <path>   Vendor the harness into a repo so cloud lanes can read it too.
# Re-running either mode updates the package files and never overwrites a repo's own config
# (.cursor/nbdybuilder/project.md, harness.env).
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)"

copy_package() {
  local dest="$1"
  mkdir -p "$dest"
  if [ "$(cd "$dest" && pwd)" = "$SRC" ]; then
    return
  fi
  (cd "$SRC" && tar --exclude='__pycache__' -cf - .) | (cd "$dest" && tar -xf -)
  chmod +x "$dest"/install.sh "$dest"/scripts/*.sh "$dest"/scripts/*.py "$dest"/scripts/__tests__/*.sh
}

case "${1:-}" in
  --global)
    copy_package "$HOME/.cursor/skills/nbdybuilder"
    mkdir -p "$HOME/.cursor/commands"
    cp "$SRC/command.md" "$HOME/.cursor/commands/nbdybuilder.md"
    echo "nbdybuilder: installed globally. In any repo, run /nbdybuilder; it vendors itself into the repo on first run."
    ;;
  --repo)
    REPO="$(cd "${2:?usage: install.sh --repo <path>}" && pwd)"
    copy_package "$REPO/.cursor/skills/nbdybuilder"
    mkdir -p "$REPO/.cursor/commands" "$REPO/.cursor/rules" "$REPO/.cursor/nbdybuilder"
    cp "$SRC/command.md" "$REPO/.cursor/commands/nbdybuilder.md"
    cp "$SRC/rule.mdc" "$REPO/.cursor/rules/nbdybuilder.mdc"
    [ -f "$REPO/.cursor/nbdybuilder/harness.env" ] || cp "$SRC/harness.env.template" "$REPO/.cursor/nbdybuilder/harness.env"
    if [ -f "$REPO/.cursor/nbdybuilder/project.md" ]; then
      echo "nbdybuilder: vendored into $REPO (kept the existing project.md and harness.env)."
    else
      echo "nbdybuilder: vendored into $REPO. Next: fill .cursor/nbdybuilder/project.md from project.template.md (/nbdybuilder does this for you)."
    fi
    ;;
  *)
    sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'
    exit 1
    ;;
esac
