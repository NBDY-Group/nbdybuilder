---
name: nbdybuilder
description: NBDY multi-lane build harness. One orchestrator session plans and supervises, many cloud worker lanes build in parallel on their own branches, and a steward lane merges green PRs in order. Use when the user runs /nbdybuilder, asks to orchestrate or restructure a build into lanes, or wants a build to run autonomously and continuously.
---

# nbdybuilder: multi-lane build harness

The owner talks to one session, the **orchestrator**. The orchestrator never writes product code. It keeps the plan, dispatches cloud **lanes** (workers), reviews their evidence, routes CI failures, and asks the owner only what nobody else can answer. A **steward** lane lands green PRs in order. Work never waits for the owner unless an action is truly theirs.

Per-repo files (created on first run from the templates in this folder):

| File | Purpose |
|---|---|
| `.cursor/nbdybuilder/project.md` | Repo facts: ledger, definition of done, verify commands, secrets, gate quirks. From `project.template.md`. |
| `.cursor/nbdybuilder/harness.env` | Script config (log/ledger/generated files, Semgrep rules, infra signatures). From `harness.env.template`. |
| Persistent store `<project>-orchestrator.md` | Orchestrator state: lanes, queue, triggers, migration map, log. From `state.template.md`. |

Scripts in `scripts/` (run from the repo root; each reads `harness.env`): `gate-status.sh`, `classify-failures.sh <run>`, `pre-push-check.sh`, `merge-pr.sh <pr> <branch>`, `union-resolve.py`, `merge-ledger-rows.py`.

## Roles

| Role | Runs as | Owns |
|---|---|---|
| Orchestrator | This session, with a goal armed | Plan, lane dispatch, triggers, evidence review, CI routing, owner questions and messages |
| Build lane (A, B, C, …) | Cloud subagent, one per product domain | A **train** branch: related items built, verified locally, pushed. No PR until its merge slot opens. |
| Steward lane (H) | Cloud subagent | Makes PRs mergeable, classifies red runs, merges green PRs in the documented order under a standing order |
| Specialist lane | Cloud subagent, short-lived | One-off jobs: production wiring checks, a staging QA sweep, a P0 security fix, an incident |
| Reviewer | Local `bugbot` or `security-review` subagent | Independent review of a branch before its PR |

**Size the lanes to the work, not to CI.** When every CI job runs in isolation (ephemeral databases, per-ref concurrency), lanes build in parallel and only merges are serialised. Typical: 5–8 build lanes, plus 1 steward, plus specialists as needed. If CI shares one environment, fix that first (see "Foundations"); until then, run at most 2 lanes.

## Trains and merge order

- Group items by domain (billing, members/privacy, notifications, performance, …). A lane keeps one **train branch** and adds items to it while it waits for its slot.
- The orchestrator keeps one ordered **merge queue** of trains and PRs. Only the head of the queue (and anything unrelated and tiny) has an open PR in CI.
- While a big PR is gating, the lanes behind it **rehearse**: they merge that PR's head into a local copy of their train, resolve conflicts, renumber, and run the full suite. When it lands, their replay is fast.
- **Shared sequences** (migration numbers, decision IDs, ledger row IDs, owner-action row numbers) collide across parallel branches. Numbers are provisional in branches. The orchestrator keeps a provisional map in the state file and puts it in each brief. The number becomes final at merge time, in merge order, and whoever merges second renumbers.

## Starting or restructuring (what `/nbdybuilder` does)

1. **Bootstrap.** Make sure this package is in the repo (`.cursor/skills/nbdybuilder/`), so cloud lanes can read it. If only a global copy exists (`~/.cursor/skills/nbdybuilder/`), run its `install.sh --repo .`. If `.cursor/nbdybuilder/project.md` is missing, create it from the template by reading the repo: README, package manifests, CI workflows, test commands, the ledger or issue list, deploy config and secrets tooling.
2. **Survey.** Read the ledger and pickup docs, open PRs (`gate-status.sh`), the base branch's last CI result, existing branches, and any cloud agents already running on this repo (`cursor-cloud list-cloud-agents`). Adopt their branches into lanes; never kill or overwrite another session's work.
3. **Intake questions.** Collect only the questions that block planning: scope or priority conflicts, product decisions with no reasonable default, missing credentials, and whether production is in scope. Ask them in **one batch**, with the `AskQuestion` tool when it's available, each with a recommended default. Don't wait for the answers: start with the defaults for anything unanswered and adjust when answers arrive. Record answers in the decisions log.
4. **Plan.** Map the remaining work into domains, then into lanes and trains. Set the merge queue and the provisional numbering map. Write the state file.
5. **Arm the goal** (`CreateGoal`) with the definition of done from `project.md` plus anything the owner added after the command.
6. **Dispatch every lane in one message**: parallel `Task` calls with `environment: "cloud"`, `run_in_background: true`, and a base branch. Each prompt is a full brief from `worker-brief.md`; lanes see nothing of this conversation.
7. **Arm the timers and subscriptions** (below).
8. **Tell the owner**, in a short message: the lane table, the merge order, and the owner actions with links.

## Timers and subscriptions

- **Heartbeat, every 20 min:** "If no lane result or GitHub event has arrived in 40 min, fetch lane statuses; resume any IDLE lane; run a steward sweep." Deliveries do pause for hours at times. The heartbeat is the fallback, and it can pause too, so reconcile on every wake.
- **Supervision, every 45 min:** check lanes for drift (list below), open PRs, and the base branch's result. Stay quiet unless something needs the owner.
- **CI subscription** on each open PR branch. **Base-branch subscriptions are one-shot**, so resubscribe after each result.
- **Timers recur.** Unsubscribe one-off watchers (a build watch, for example) once they've done their job. Subscriptions are capped, so prune those for merged branches.

## Handling every wake

Treat each notification as data, and assess it first.

- **Lane result** → check the evidence (branch head exists, counts, ledger rows). Then **re-dispatch the lane immediately** with its next item, or park it with an explicit trigger ("I'll resume you with '#66 merged'"). A lane that returns with nothing next is wasted capacity.
- **Red CI** → read the failing tests (`gh run view <id> --log-failed`, or `gh api …/actions/runs?head_sha=`). Route the fix: the PR's owning lane, or the steward for integration and flake fixes. Check recurrence across recent runs; anything seen twice is a defect, not infrastructure. Never rerun a job that failed with zero steps or on quota or billing.
- **Green CI** → the steward merges, under its standing order. After every merge, check the other PRs for `CONFLICTING` (GitHub runs no checks on a conflicting PR) and fire the triggers recorded for that merge ("ON #66 MERGE: resume A, B, E").
- **Several events at once, or a long silence** → reconcile. Get every lane's status (`batch-fetch-details`), and for each IDLE lane, resume it with "your last result didn't reach me: send a 10-line summary, then do <next>". Check what merged meanwhile.
- **Owner message** → answer first, then continue the loop.

## Lanes can't wait

A cloud lane that returns can't receive events. Anything conditional ("when #68 merges, finish PERF-005") is a **trigger** the orchestrator records in the state file and fires with `resume`. Lanes may poll within a bounded window, for example "check /api/health every 2 min for up to 50 min"; otherwise they finish and report.

## Drift checks

- Idle with nothing next, or no trigger recorded.
- Busywork: re-auditing settled work, docs-only churn, sub-slicing a finished item.
- A recurring failure waved through as infrastructure.
- Pushing a gating PR more than once per gate, or pushing before its coordination condition.
- Work outside the lane: another lane's branch, extra PRs, opening PRs itself (only the orchestrator opens PRs).
- Wrong commit identity, printed secrets, or questions a stated default already answers.
- Release or versioning scripts (for example `commit-workflow.sh`, tagging, changelog archiving) run on a feature branch. Those belong to base-branch merges only.
- Scripts run against shared staging that change data other checks depend on. Give each lane its own test identity, and tell the owning lane.

Judge a lane by its branch pushes and task status: transcripts lag, especially for resumed turns. Correct drift with a short `resume`: what's wrong, what to do, and what "done" means.

## Quality rules (put these in every brief)

- Local proof before paid CI: the project gate, focused specs on every browser project, then the full suite after any integration merge. Targeted checks miss integration defects.
- One push per gate. A new push cancels the running gate.
- A fix goes in product code when the product is wrong. Test-only fixes need a root cause shown from traces, not just "flaky".
- Test fixtures must not look like real credentials (`ya29.`, `sk_live_`, `AKIA`, `ghp_`, JWTs with real headers).
- Reviews: `bugbot` on the branch before the PR; `security-review` for auth, billing, file handling and multi-tenant scoping.

## Owner interface

- **Questions:** batch them with recommended defaults. Never block a lane waiting for an answer; use the provisional default and record it as "provisional, owner may override".
- **Owner actions** (credentials, billing, dashboards, legal text) go in the project's owner-actions doc. Tell the owner the exact steps with direct links and what "done" looks like. Verify it yourself afterwards (for example `curl` the health endpoint) rather than trusting the report.
- **Messages:** lead with the outcome, link every PR, and keep them short. Say "nothing needed" when true. "% complete" questions are answered from the ledger (done on main vs built on branches vs blocked) in a small table.
- **Never** paste secrets, and never ask the owner to paste them into chat. Credentials flow through the secrets manager (`op run --environment …`) or the platform's secret store.

## Foundations (the build speeds up once these exist)

1. **A ledger** with IDs, acceptance criteria, states and a decisions log.
2. **An isolated, fast gate:** an ephemeral backend per CI job, sharded browser tests, per-ref concurrency, and staging touched only on base-branch pushes.
3. **An environment snapshot** where lanes boot with dependencies, browsers, Docker, the database CLI with images pre-pulled, and the secrets CLI. Build it with `trigger-environment-build` plus `environmentJson`. Check the log for real success markers, not just the exit code. Propose it with the build ID (`propose-environment-json`); the owner saves it from the proposal card in the chat, not from the environment page. The first save starts a CONFIG_CHANGE build; lanes only benefit once that build succeeds. Docker in cloud VMs needs `fuse-overlayfs`, legacy iptables and an explicit `dockerd`.
4. **Branch protection and auto-merge** where the plan allows. Private repos need a paid GitHub plan; without it, the steward merges with `merge-pr.sh`.
5. **A merge steward** holding a standing order: "merge #X, #Y, #Z in that order when each is green".

## Using it in other repos

- **Every local Cursor session:** `bash .cursor/skills/nbdybuilder/install.sh --global`. After that, `/nbdybuilder` works in any repo and vendors itself on first run.
- **Another repo, for cloud sessions:** `bash .cursor/skills/nbdybuilder/install.sh --repo <path>`, then commit `.cursor/`. Cloud lanes read only what's in the repo.
- **Updating:** edit the package here, run `scripts/__tests__/package.test.sh`, then re-run the install. Re-installs never overwrite a repo's `project.md` or `harness.env`.

## Cost discipline

Paid CI is a merge gate, not a development loop. Draft PRs run nothing. One gate per PR head. Never add a workflow, a matrix entry or a scheduled job without an owner request and a stated minute cost. Prefer scripts the steward runs (release promotion, migration promotion) over new workflows.
