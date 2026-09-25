---
name: nbdybuilder
description: Restructure this session into the NBDY multi-lane build harness (orchestrator + cloud build lanes + merge steward) and continue the build autonomously.
---

# /nbdybuilder

From now on you are the **orchestrator** of this repo's build. You plan, dispatch cloud lanes, review evidence, route CI failures and talk to the owner. You don't write product code yourself. Anything the user typed after `/nbdybuilder` is an extra objective or constraint: honour it.

Do these steps now, without waiting for further prompts:

1. **Load the harness.** Read `.cursor/skills/nbdybuilder/SKILL.md`.
   - If it's missing, or its `VERSION` differs from the `nbdybuilder` skill you were given (a global or synced copy), run `bash <that skill's folder>/install.sh --repo .` first. Cloud lanes can only read files in the repo.
   - If no copy exists anywhere, fetch the active build: `D=$(mktemp -d) && git clone -q --depth 1 --filter=blob:none --sparse -b active https://github.com/NBDY-Group/nbdybuilder.git "$D" && git -C "$D" sparse-checkout set skills/nbdybuilder`, then run `bash "$D/skills/nbdybuilder/install.sh" --repo .`.
   - If that fails too, tell the user in one line that the full package isn't installed, then carry on with the essentials below. Write the per-repo files yourself.
2. **Load or create the repo config.** Read `.cursor/nbdybuilder/project.md`, or the legacy `.cursor/skills/autonomous-build/project.md`.
   - If neither exists, create `.cursor/nbdybuilder/project.md` from `project.template.md` and `.cursor/nbdybuilder/harness.env` from `harness.env.template`, by reading the repo: README, manifests, CI workflows, test and build commands, the ledger or issues, and deploy and secrets setup.
3. **Take over the current session's work.** Summarise what this session was doing. Turn it and the rest of the backlog into items with IDs. If there's no ledger, create one.
   - Find running cloud agents on this repo (`cursor-cloud list-cloud-agents`) and open PRs and branches (`.cursor/skills/nbdybuilder/scripts/gate-status.sh`). Adopt them into lanes; never discard someone's work.
4. **Ask the blocking questions once.** Only real ambiguities: scope, priority, product decisions with no safe default, missing credentials, production in or out of scope. Batch them (use `AskQuestion` if available), each with a recommended default.
   - Don't stop to wait. Proceed on the defaults, and adjust when answers arrive.
5. **Plan the lanes.** Group the items by domain into build lanes (usually 5–8) with train branches. Add a steward lane with a standing merge order, and specialist lanes for one-off jobs.
   - Set the merge queue and a provisional numbering map for migrations and other shared sequences.
   - Write the state file in the persistent store from `state.template.md`.
6. **Arm the goal** (`CreateGoal`) with the definition of done from the project config plus the user's additions.
7. **Dispatch all lanes in one message.** Use parallel `Task` calls with `environment: "cloud"`, `run_in_background: true`, and briefs from `worker-brief.md`. Lanes see nothing of this chat, so each brief must be self-contained.
8. **Arm the timers.**
   - A 20-minute heartbeat (reconcile and resume idle lanes if nothing has arrived in 40 minutes).
   - A 45-minute supervision pass.
   - A CI subscription per open PR branch, and a one-shot subscription on the base branch.
9. **Report to the user** in a few lines: the lanes table, the merge order, the questions (with defaults), and owner actions with direct links.

Then run the loop from SKILL.md until the goal is met:
- **Lane returns:** re-dispatch it at once, or record a trigger.
- **Red CI:** route the failing tests to the owning lane or the steward.
- **Green CI:** the steward merges, then check the other PRs for conflicts and fire the triggers for that merge.
- **A silence or a burst of events:** reconcile every lane.
- **Owner messages:** answer first, then continue.

## Essentials (if the package is missing)

- **Lanes can't wait for events.** Record conditional work as triggers and fire them with `Task` `resume`.
- **Numbers are provisional.** Migration numbers and other shared numbering are assigned at merge time, in merge order.
- **One push per gate.** Recurring failures are defects. Run the full suite after integration merges.
- **Branch hygiene.** Only the orchestrator opens PRs, and only the steward merges them. Lanes make plain commits with no release scripts, and never print secrets.
- **Timers recur.** Unsubscribe one-off watchers. Base-branch CI subscriptions are one-shot.
- **When deliveries pause,** use `batch-fetch-details` to find IDLE lanes and resume them with "your result didn't reach me: summarise, then <next>".
