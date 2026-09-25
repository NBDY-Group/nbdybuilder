#!/usr/bin/env bash
# Install the nbdybuilder harness.
#   install.sh --global        Make /nbdybuilder available in every Cursor session on this machine. With Cursor's
#                              "Sync Skills for Cloud Agents" on, this updates the synced copy, so Cloud Agents get it too.
#   install.sh --repo <path>   Vendor the harness into a repo so cloud lanes can read it too.
# Re-running either mode replaces the package files and never touches a repo's own config
# (.cursor/nbdybuilder/project.md, harness.env).
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)"

copy_package() {
  local dest="${1:?}"
  if [ -d "$dest" ] && [ "$(cd "$dest" && pwd)" = "$SRC" ]; then
    return
  fi
  rm -rf "$dest"
  mkdir -p "$dest"
  (cd "$SRC" && tar --exclude='__pycache__' -cf - .) | (cd "$dest" && tar -xf -)
  chmod +x "$dest"/install.sh "$dest"/scripts/*.sh "$dest"/scripts/*.py "$dest"/scripts/__tests__/*.sh
}

# Skill sync moves personal skills into Cursor's agent store; its skills folder exists once that has happened.
global_dir() {
  local files store=""
  for files in "$HOME/Library/Application Support/Cursor/AgentStores/cursor_agent_stores"/u*/files; do
    if [ -d "$files/skills" ]; then store="$files/skills"; break; fi
  done
  if [ -n "$store" ] && [ -d "$store/nbdybuilder" ]; then echo "$store/nbdybuilder"
  elif [ -d "$HOME/.cursor/skills/nbdybuilder" ]; then echo "$HOME/.cursor/skills/nbdybuilder"
  elif [ -n "$store" ]; then echo "$store/nbdybuilder"
  else echo "$HOME/.cursor/skills/nbdybuilder"
  fi
}

case "${1:-}" in
  --global)
    DEST="$(global_dir)"
    copy_package "$DEST"
    echo "nbdybuilder: installed at $DEST. In any repo, run /nbdybuilder; it vendors itself into the repo on first run."
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
    sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'
    exit 1
    ;;
esac
