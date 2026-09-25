# Builds

## build-2 — 2026-09-25

- A private source repo with numbered builds, and the `nbdybuilder` build manager: `list`, `status`, `try`, `release`, `use`, `vendor`, `test`.
- Every copy has a `BUILD` file. `/nbdybuilder` re-vendors a repo whose copy is a different build, and fetches the active build from GitHub when no copy is installed.
- `install.sh --global` updates the synced copy when Cursor's skill sync is on, instead of creating a second, unsynced one. It no longer installs a separate global command: the skill is the entry point, and invoking it runs `command.md`.
- Re-installing replaces the package files, so files a newer build drops don't linger.
- The package self-test also runs outside a git repo.

## build-1 — 2026-09-25

The harness as packaged in Tourganise PR #72 (commit 6cb5249f).
