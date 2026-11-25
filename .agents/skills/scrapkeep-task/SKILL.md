---
name: scrapkeep-task
description: Execute an authorized Scrapkeep task card with isolated work, independent review and serial admission. Use when asked to implement or continue an approved Scrapkeep card or bounded scope.
---

# Execute an authorized Scrapkeep task

Resolve this skill directory through symlinks, then run `git -C <resolved-skill-directory> rev-parse --show-toplevel` to identify the repository root. Read `AGENTS.md`, `GEMINI.md`, and `project-guide/handoff/START-HERE.md`. Use root-relative source paths below. The linked Claude skill resolves to this same body.

ORCHESTRATOR owns the assignment packet, concurrency, leases, review and acceptance; do not substitute an external planning board. The coordinator is the sole canonical record writer. Each step below links the record that owns its rule instead of restating it.

## In a claude.ai project thread

The thread is the writer (ruling by; [ORCHESTRATOR.md#roles-and-concurrency](../../../ORCHESTRATOR.md#roles-and-concurrency)). Its branch and its claim on the wave board are its isolation and its lease, so steps 3 to 6 do not apply: no writer worktree, packet, lease record or dispatch. The thread reads the sources, writes the change, runs the checks in step 7 itself, and starts one fresh read-only reviewer for step 8. The Gate thread stacks the pull request; steps 9 and 10 are the coordinator's. The procedure below is the heavy lane, for a coordinator that runs writers inside one local session.

## Procedure

1. Authorization check. Confirm the current program authorization covers this card and action type, per [TRACKING.md#program-authorization](../../../TRACKING.md#program-authorization). Read the exact `BACKLOG.md` card and its source sections. Missing authorization or a missing prerequisite output blocks the card even if its status says ready. Capture a direct new scope request in the existing board before dispatch.
2. Admission checklist. Verify the six admission conditions in [ORCHESTRATOR.md#admission-and-assignment](../../../ORCHESTRATOR.md#admission-and-assignment) and the ready to in_progress row of [TRACKING.md#transition-authority](../../../TRACKING.md#transition-authority). Inspect Git state and owner changes; never reset, stash or stage them wholesale.
3. Worktree at the recorded base. Create the writer's worktree with `scripts/new-worktree.sh <task-id> <base-sha>`, which branches at the accepted revision and exits nonzero when HEAD differs. Record the printed base identity. Never let a writer self-isolate or start from a guessed `main`.
4. Packet. Write the GOAL, SCOPE, CONTEXT, ACCEPTANCE, VERIFY, TIMEBOX, FORBIDDEN and REPORT packet from [ORCHESTRATOR.md#admission-and-assignment](../../../ORCHESTRATOR.md#admission-and-assignment). Name the worktree path, base SHA, permitted files, lease ID and the resolved documentation references the worker needs. A lab card names the epoch and pin it runs against, its call cap, and forbids the writer reading the blind corpus, its provenance and TRACKING when it authors question text (EV-0525).
5. Lease record. Add the expanded attempt record and assignment event before the worker starts, per [TRACKING.md#task-record-schema](../../../TRACKING.md#task-record-schema) and [TRACKING.md#event-schema-and-write-discipline](../../../TRACKING.md#event-schema-and-write-discipline).
6. Dispatch. Launch the writer through the host adapter below within the concurrency ceiling in [ORCHESTRATOR.md#roles-and-concurrency](../../../ORCHESTRATOR.md#roles-and-concurrency). Expect checkpoints and handle interruption per [ORCHESTRATOR.md#ownership-checkpoints-and-interruption](../../../ORCHESTRATOR.md#ownership-checkpoints-and-interruption).
7. Handoff verification. Check the handoff against [ORCHESTRATOR.md#handoff-and-review](../../../ORCHESTRATOR.md#handoff-and-review). Run `npm run check:scope -- <base> <candidate> [--no-build]`; it classifies the changed paths against the lease and prints the required commands. Run those commands yourself and keep the receipts under `artifacts/local/tasks/<task-id>/`.
8. Reviewer dispatch. Assign a fresh read-only reviewer who did not write the candidate. Give it the packet acceptance, the candidate identity and your exact receipts, never the writer's brief. Record the verdict per [ORCHESTRATOR.md#handoff-and-review](../../../ORCHESTRATOR.md#handoff-and-review); a failed criterion becomes changes_requested, bounded to attempts 2 and 3.
9. Serial integration. Integrate one approved candidate at a time per [ORCHESTRATOR.md#serial-integration-and-completion](../../../ORCHESTRATOR.md#serial-integration-and-completion). Rerun the commands `check:scope` named on the integrated result. A failure keeps the task out of done with its evidence retained.
10. Done event. Record candidate, review and integrated identities separately and append the completion event, per the review to done row of [TRACKING.md#transition-authority](../../../TRACKING.md#transition-authority). Prerequisites unlock only then.

## Sprint handback

When the selected sprint has no remaining active work, follow [ORCHESTRATOR.md#sprint-closure](../../../ORCHESTRATOR.md#sprint-closure) before reporting SPRINT COMPLETE. Task completion alone cannot close a sprint. Specification contradictions follow [the amendment rule](../../../ORCHESTRATOR.md#specification-contradictions); stop affected work and submit a request rather than deviating.

## Host adapter and base identity

- Antigravity: use `invoke_subagent` with `.agents/agents/scrapkeep-*.md` (or `scrapkeep-gemini-workflows` with `run_workflow` for card batches), isolate writers with `workspace: "share"` or `scripts/new-worktree.sh`, follow `AGENTS.md` Rule 11 (Gemini 4 Neon at high for admission reviews), and report active Gemini model/tier from runtime metadata.
- Claude Code: in any session, write the change yourself and use sub-agents only for wide search (`scrapkeep-explorer`), research, a noisy run and the independent review (`scrapkeep-reviewer-medium`, or `scrapkeep-reviewer` for a consequential seam) (ruling by). `scrapkeep-writer` and `scrapkeep-writer-low` are for a coordinator that has already split work into parallel units with their own worktrees. `.claude/agents/` holds the fallback tier pins to `AGENTS.md` Rule 11 (ruling `ej`).
- Codex (GPT 6.2 Astra/Sol, rulings `ec`/`ee`/`ej`): create distinct worktrees explicitly at the accepted revision for ruled assistive work (world 1 promise cards, QA, concept art, model drafts, second review opinions); Codex verdicts are evidence and never admit a unit.
- On any host, verify the requested model/tier against `AGENTS.md` Rule 11 and actual runtime metadata; a review or gate verdict on a non-compliant model does not count. Verify the actual worktree base and write scope before admission. The coordinator runs executable checks and supplies the exact artifact and evidence to review.

Use `scrapkeep-verify` for the candidate and integrated result. Resume from TRACKING and artifacts, not a remembered PID or a chat summary. Report actual runtime identities and evidence limits.
