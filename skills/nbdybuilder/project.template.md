# Project config: <name>

The only harness prose that changes between repos. Keep it factual and short; lanes read it first.

## Identity
- Repo: `<owner/repo>`, base branch `<main>`.
- Commit identity: `<name> <email>` (preview deploys may require it).

## Sources of truth
- Ledger: `<path>` (item IDs, states, acceptance criteria). If the repo has none, the orchestrator creates `docs/BUILD_LEDGER.md` from the issue list and the owner's goals.
- Decisions log: `<path>`.
- Owner actions: `<path>`.
- Session log: `<path>` (append-only; plain commits on feature branches).

## Definition of done
- <e.g. every launch-scope P0 done or blocked only on an owner action>
- <e.g. the base branch green on three consecutive full CI runs>
- <e.g. staging serves the current base and /api/health is 200>

## Secrets
- Runner: `<e.g. op run --environment <id> -- <cmd>>`. Never print values; names and counts only.

## Local gate (before the first push)
- Full check: `<e.g. pnpm run ci>` (note any env it needs, e.g. placeholders for builds without secrets).
- Browser tests: `<command>`, per project `<chromium, mobile-safari>`, against `<local/ephemeral backend>`.
- Migrations: `<command>`.
- `.cursor/skills/nbdybuilder/scripts/pre-push-check.sh`.

## Remote gate
- Workflows and required checks: `<names>`. What "green" means: `<checks>`.
- Checks to ignore: `<e.g. preview deploy statuses>`.
- Base-branch-only jobs: `<e.g. staging contract>`.

## Environments
- Staging: `<url, project ids>`. Production: `<url, project ids>`, and what lanes may do there (usually read-only checks plus scripted promotions).

## Conventions
- <test coverage rules, tenancy scoping, migration rules, UI rules>
