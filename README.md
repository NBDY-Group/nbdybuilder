# nbdybuilder

Source and builds of `/nbdybuilder`, the NBDY multi-lane build harness: one orchestrator session, parallel cloud build lanes, and a merge steward. The package is `skills/nbdybuilder/`; its `SKILL.md` explains how the harness works.

## Builds

Every release is an immutable tag, `build-1`, `build-2`, and so on. Branch `active` points at the build in use. Every installed or vendored copy has a `BUILD` file naming its build.

| Command | What it does |
|---|---|
| `nbdybuilder list` | Builds, newest first; `*` marks the installed one |
| `nbdybuilder status` | What's installed and where, what `active` points at, unreleased changes |
| `nbdybuilder try` | Install your working tree as a `dev` build, to test changes in real sessions |
| `nbdybuilder release "what changed"` | Self-test, commit, tag the next `build-N`, push, install it and make it active |
| `nbdybuilder use <build-N\|latest\|previous>` | Switch to any build, or roll back |
| `nbdybuilder vendor <repo>` | Copy the installed build into a repo (`/nbdybuilder` also does this itself) |
| `nbdybuilder test` | Run the package self-test on the working tree |

To tune the harness: edit `skills/nbdybuilder/`, run `nbdybuilder try`, use it, then either `release` it or `use previous` to undo. You can also ask any agent, for example "roll nbdybuilder back to build-1".

## Where it runs

- **Local sessions** (IDE, Agents window, CLI): the installed copy is a personal skill. With Cursor's "Sync Skills for Cloud Agents" on, it lives in the personal agent store's synced `skills/nbdybuilder/` folder; otherwise in `~/.cursor/skills/nbdybuilder/`. There is only ever one installed copy.
- **Cloud Agents:** the synced skill. Agents that don't get synced skills (for example ones started from the web or Slack) fetch branch `active` from this repo, as the owner's user rule and `command.md` instruct.
- **Repos:** `/nbdybuilder` vendors the installed build into `.cursor/skills/nbdybuilder/`, so the cloud lanes it dispatches can read it, and re-vendors when the repo's copy is a different build.

This repo has no GitHub Actions. Tests run locally: `nbdybuilder test` and `bash tests/cli.test.sh`.
