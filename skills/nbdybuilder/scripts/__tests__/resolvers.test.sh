#!/usr/bin/env bash
# Self-test for the conflict resolvers used by merge-pr.sh.
# Usage: bash .cursor/skills/nbdybuilder/scripts/__tests__/resolvers.test.sh
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fail=0
check() {
  if [ "$2" = "$3" ]; then echo "ok   $1"; else
    echo "FAIL $1"; diff <(printf '%s' "$3") <(printf '%s' "$2") || true; fail=1
  fi
}

cat > "$TMP/log.md" <<'EOF'
# Updates

<<<<<<< HEAD
### Security
- **Type**: Security
- Ours entry

=======
### Security
- **Type**: Security
- Theirs entry

>>>>>>> origin/main
## Older
EOF
python3 "$HERE/union-resolve.py" "$TMP/log.md" >/dev/null
check "union-resolve keeps repeated headings from both sides verbatim" "$(cat "$TMP/log.md")" "$(cat <<'EOF'
# Updates

### Security
- **Type**: Security
- Ours entry

### Security
- **Type**: Security
- Theirs entry

## Older
EOF
)"

cat > "$TMP/diff3.md" <<'EOF'
<<<<<<< HEAD
ours
||||||| base
base
=======
theirs
>>>>>>> branch
EOF
python3 "$HERE/union-resolve.py" "$TMP/diff3.md" >/dev/null
check "union-resolve drops the diff3 base section" "$(cat "$TMP/diff3.md")" "$(printf 'ours\ntheirs')"

cat > "$TMP/ledger.md" <<'EOF'
| ID | State | Notes |
|---|---|---|
<<<<<<< HEAD
| **SEC-007** | `verified` | **2026-09-24**: ours proof |
| **ONB-001** | `in_progress` | **2026-09-20**: started |
### Notes
=======
| **SEC-007** | `in_progress` | **2026-09-23**: theirs note |
| **ONB-001** | `done` | **2026-09-25**: merged |
| **INT-009** | `proposed` | **2026-09-25**: new |
### Notes
>>>>>>> origin/main
EOF
python3 "$HERE/merge-ledger-rows.py" "$TMP/ledger.md" >/dev/null
check "merge-ledger-rows merges rows by ID, keeps the most advanced state and both notes, keeps non-row lines verbatim" \
  "$(cat "$TMP/ledger.md")" "$(cat <<'EOF'
| ID | State | Notes |
|---|---|---|
| **SEC-007** | `verified` | **2026-09-24**: ours proof **2026-09-23**: theirs note |
| **ONB-001** | `done` | **2026-09-25**: merged **2026-09-20**: started |
### Notes
| **INT-009** | `proposed` | **2026-09-25**: new |
### Notes
EOF
)"

exit "$fail"
