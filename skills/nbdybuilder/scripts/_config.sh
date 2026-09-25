# Sourced by every nbdybuilder script. Loads the repo's harness config, then fills defaults.
# Per-repo overrides live in .cursor/nbdybuilder/harness.env (plain KEY=value lines).
NBDY_REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
NBDY_SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$NBDY_REPO_ROOT/.cursor/nbdybuilder/harness.env" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$NBDY_REPO_ROOT/.cursor/nbdybuilder/harness.env"
  set +a
fi
: "${HARNESS_BASE:=main}"
: "${HARNESS_COMMIT_NAME:=Cursor Agent}"
: "${HARNESS_COMMIT_EMAIL:=cursoragent@cursor.com}"
: "${HARNESS_LOG_FILES:=UPDATES.md CHANGELOG.md}"
: "${HARNESS_LEDGER_FILES:=}"
: "${HARNESS_PROSE_GLOB:=docs/}"
: "${HARNESS_GENERATED_GLOB:=}"
: "${HARNESS_REGEN_CMD:=}"
: "${HARNESS_VERIFY_CMD:=}"
: "${HARNESS_SEMGREP_RULES:=}"
: "${HARNESS_SEMGREP_PATHS:=.}"
: "${HARNESS_SEMGREP_PUBLIC:=0}"
: "${HARNESS_INFRA_PATTERN_EXTRA:=}"
: "${HARNESS_FORBIDDEN_PATTERN:=console\.log|debugger;|@ts-ignore|test\.skip\(|it\.skip\(|describe\.skip\(|onClick=\{\(\) => \{\}\}|[Cc]oming soon|\b(TODO|FIXME|HACK)\b[^(]*$}"
export PATH="$HOME/.local/bin:$PATH"
