# Lane briefs and resume messages

Paste a filled brief as the `Task` prompt (`environment: "cloud"`, `run_in_background: true`, `cloud_base_branch` set). Lanes see nothing of the orchestrator's conversation, so every brief is self-contained. Refer to `project.md` sections rather than restating them.

## Build lane

```text
You are Lane <X>, a build lane on <project> (<owner/repo>). An orchestrator assigns and reviews your work; the owner has authorised autonomous execution.
FIRST READ: .cursor/skills/nbdybuilder/SKILL.md ("Quality rules"), .cursor/nbdybuilder/project.md, and the rules in .cursor/rules/.

TRAIN BRANCH: <cursor/train-<domain>-<suffix>> (create it from <base>@<sha> if it doesn't exist).
ITEMS, in order: <ledger IDs + one-line intent each; acceptance = the ledger row>.
CONTEXT: <files, prior PRs, decisions in force, known pitfalls>.
NUMBERING: provisional migration numbers <NNN–MMM>; the orchestrator confirms at merge time.
COORDINATION: <e.g. "PR #66 is gating: rehearse against its head 69c65417 but push your train only after it merges (gh pr view 66 --json state)">. Never touch another lane's branch. Don't open PRs; the orchestrator does.

SHIP: plain git commits (never release/versioning scripts). Local gate from project.md, focused specs on every browser project, the full suite before pushing, then pre-push-check. Push WIP at least hourly. Update the ledger rows, the docs and the session log on the branch.

RETURN (final message):
HEAD: <branch @ sha>
DONE: <items and user-visible changes>
EVIDENCE: <suite counts per project, gate commands run, migration checks>
NUMBERING: <final provisional numbers used>
FINDINGS: <defects found outside your scope, with evidence>
DECISIONS: <provisional decisions made>
OWNER: <exact owner actions needed, or "none">
NEXT: <what you'd do next in this domain>
```

## Steward lane

```text
You are Lane H, the merge steward on <project>. STANDING ORDER: merge <#A, #B, #C> in that order, each once fully green and mergeable, with .cursor/skills/nbdybuilder/scripts/merge-pr.sh (a --no-ff merge commit). For a PR that's behind or conflicting: merge the base into it (a normal merge), resolve docs with union-resolve.py / merge-ledger-rows.py, regenerate generated files, run the project gate plus the specs in the conflict area, and push once. For a red run: read the failing tests, check recurrence, fix a known-class race with the shared helpers (proved with --repeat-each=5 on every browser), or rerun failed jobs once only for a one-off infrastructure signature. Never rerun zero-step, quota or billing failures.
Report: what merged (SHAs), each PR's head and state, root causes, and anything that needs a product lane.
```

## Specialist lane

```text
You are Lane <X>, a specialist on <project>. JOB: <one outcome>. SCOPE: <what may change; staging only / read-only on production / etc.>. Bounded wait: <e.g. poll /api/health every 2 min for up to 50 min>. Never print secret values; use <secrets runner>. Record evidence in <doc>. Report: the result, evidence, before/after with the revert, and owner actions.
```

## Resume messages

- **Trigger:** `'#66 merged' (main <sha>, last migration <NNN>). Finalise your train: merge real main, renumber to <NNN+1…>, re-verify fully, push <branch>, report the head.`
- **Next item:** `Great work. Next: <item + acceptance>. Base: <branch>. Ship and report as before.`
- **Missed result:** `Your last result didn't reach me (a delivery gap). First give a 10-line summary of it, then <next instruction>.`
- **Correction:** `Stop <what>. Instead <what>. Done means <observable result>.`
