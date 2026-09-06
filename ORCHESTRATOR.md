# Scrapkeep swarm operating manual

Revision 2. Documentation preparation approved 6 September 2026. The prepare-stage program is in progress; the foundation sprint is proposed, not started.

## Read first and preserve authority

Start at the Bible contents at [BIBLE.md § Contents](BIBLE.md#contents) (`BIBLE.md:24-36`) and read the section the task names, not the whole book. Read the accepted engineering ADR sections the card cites from [the ADR index](adr/README.md), the exact card in [BACKLOG.md](BACKLOG.md) rather than BACKLOG whole, [docs/project/SOURCE-DISPOSITIONS.md](docs/project/SOURCE-DISPOSITIONS.md) only when a card cites a historical identifier, then [TRACKING.md](TRACKING.md) for current execution state. Read the task's exact source sections and [CONTRIBUTING.md](CONTRIBUTING.md) before working. The completed engineering handoff will add TECH_BIBLE.md as the implementation reference; it does not exist yet.

The settled baseline is Godot 4.7.2 standard edition, typed GDScript, explicit hybrid/session ownership, native Resource/scene content, JSON aggregate saves and offline solo play. Do not reopen it because an older document says the engine is undecided. Preserve the approved art direction and binary trees. Questions concern missing details, not permission to replace settled choices.

These documents authorize preparation. A ready card is not permission to start its sprint. TRACKING must contain the applicable user scope authorization before dispatch. Native implementation additionally requires the completed engineering handoff, resolved task-specific questions and a scoped build authorization. The existing browser entries remain separate working proofs.

Task definitions live only in BACKLOG. Source dispositions and the source inventory live in [docs/project/SOURCE-DISPOSITIONS.md](docs/project/SOURCE-DISPOSITIONS.md), which the coordinator owns. Live task and question states live only in TRACKING. This manual owns operating rules. Older planning records are dated evidence, not additional active queues.

## Roles and concurrency

Read the active host's pstack model map at assignment time. Codex uses only `gpt-6-astra` with its configured effort. Claude Code uses only the validated `claude-fable-5-1` model through the project agent definitions under `.claude/agents/`: `scrapkeep-writer-low`, `scrapkeep-writer-medium` and `scrapkeep-writer` (high) for writing, `scrapkeep-explorer` (high) for read-only exploration, and `scrapkeep-reviewer-medium` and `scrapkeep-reviewer` (xhigh) for review; max stays reserved for explicitly scoped hardest tasks. The coordinator assigns effort by a unit's importance and difficulty, not by slot availability. These definitions no longer self-isolate. The coordinator creates each writer's worktree at the recorded base with `scripts/new-worktree.sh <task-id> <base-sha>` (delivered by PS-01) and names that path in the packet. The runtime contract maps model/effort to supported tool fields. Check actual runtime selection; a model label in a prompt cannot change it. If the required model or effort cannot run, retain the task and report the capability blocker. Do not silently substitute another model.

| Role | Responsibility | Authority limit |
| --- | --- | --- |
| Coordinator | Source alignment, task admission, exact briefs, leases, board, serial integration and reports | Sole writer of canonical shared records; cannot invent publisher answers or expand approved scope. |
| Conventions | Path ownership, naming, contribution and definition-of-done contracts | Preserve existing proof conventions; new production contracts stay within accepted ADRs. |
| Runtime | Module interfaces, timing, movement/combat ownership and system contracts | Simulation owns outcomes; presentation cannot become another rules owner. |
| Content | Definition schemas, stable identities, catalogue admission and content coverage | No invented roster, recipes, costs or launch catalogue. |
| Persistence | Save projections, transactions, recovery and migrations | Preserve rewards, spent revival and terminal authority through every supported path. |
| Rendering/input/UI | Presentation, control, focus and feedback contracts | Use committed gameplay state; physical support claims need hardware evidence. |
| Technical art | Assembly, animation, import and visual production contracts | Production scope must name selected content and respect the art lock. |
| Audio | Event cues, mix, music and sound production contracts | Audible feedback cannot delay or decide gameplay outcomes. |
| Tooling | Inspectors, telemetry, maintained agent playtesting and comparison tools | Tool changes and game changes retain separate identities and evidence. |
| Verification | Test design, qualification, source/version capture and evidence interpretation | A source review or staged fixture cannot establish human feel or native performance. |
| Independent review | Read actual candidate/integrated artifacts and report findings | Does not edit the candidate, approve its own work, merge or write the board. |
| Andrew | Missing product choices, launch scope, human feedback and consequential authorization | Agent success cannot substitute for Andrew's play feedback. |

At most three delegates may run alongside the coordinator. A reviewer consumes one of those slots, leaving at most two writers. Use a lower limit when the host provides fewer slots. Idle or interrupted agents do not regain write authority merely because a slot becomes available. This is a concurrency ceiling, not a requirement to keep every slot busy.

## Admission and assignment

Before changing a task from ready to in_progress, the coordinator verifies all of the following:

1. The current sprint/scope authorization covers this task and action type.
2. The pinned card revision has one outcome, exact sources, inputs, permitted files, one owner role, S/M size, observable completion and verification requirements.
3. Every prerequisite task is done at its accepted version. Its promised output actually exists and matches the evidence. Every blocking question has an applicable recorded answer.
4. No live lease overlaps the proposed write set. Directory ownership includes descendants; a broad directory lease conflicts with a file lease inside it. Generated files, tests and shared manifests count as writes.
5. The worktree, base revision and current user changes have been inspected. The task is based on the accepted integrated state, not a guessed `main` branch.
6. The assignment and lease are recorded in TRACKING before the worker starts.

Separate repository writers into real worktrees with unique branches, created by the coordinator at the accepted base; the writer verifies base and branch before its first edit and stops on a mismatch. A separate agent name does not isolate files. The current checkout contains owner changes; never reset, stash, overwrite or stage them wholesale. For prose-only drafts, disjoint staging copies are permitted by the pstack runtime. The board must record their base manifest and allowed draft paths. The coordinator alone admits their final shared-document changes.

Task output paths in BACKLOG are contracts, not proof that those files exist. Inputs produced by dependencies are unavailable until their producer is done. If a task cannot be made complete without choosing missing product rules or discovering its intended file ownership, convert that part to a question and split the remaining work before dispatch.

Use this packet for every worker, including one with no conversation memory:

```text
GOAL: task ID, pinned card revision, one observable outcome
SCOPE: actual worktree/staging path, base identity, permitted files, lease ID
CONTEXT: source sections, settled constraints, dependency results, applicable question answers
ACCEPTANCE: the complete definition of done and evidence required
VERIFY: exact applicable commands or bounded document-review procedure; expected outputs and limits
TIMEBOX: checkpoint interval and a bounded attempt budget appropriate to S/M
FORBIDDEN: task-specific exclusions, shared files, builds/publication outside authorization
REPORT: task/attempt IDs, changes, result identity, evidence, failures and blockers
```

Do not replace the packet with “continue the previous work.” Pass relevant upstream results directly and cite their actual files. Retrieve a library's current primary documentation before relying on its API. Give the resolved documentation references to workers who need them.

## Ownership, checkpoints and interruption

The coordinator owns BACKLOG, ORCHESTRATOR, TRACKING, canonical TECH_BIBLE assembly and cross-cutting navigation. Workers return suggested shared changes through their handoff. A worker must request an amended lease before editing outside its recorded set. The coordinator checks conflicts and records the new card/lease revision before granting that change.

Workers checkpoint at least every 15 minutes of active work and at handoff. Include current outcome, actual changed paths, evidence produced, remaining work and blockers. A checkpoint advances the task's state-record revision even when its workflow state stays in_progress. Record meaningful discoveries and scope changes promptly; do not turn every keystroke into a board event.

Formal reports to Andrew occur after a work wave or 30 minutes of active work, whichever comes first. State accepted outcomes, evidence limits, active and blocked tasks, decisions needed and the next dependency-ready work. Report consequential blockers, scope changes and evidence failures immediately. Host-required lightweight progress updates still apply. These rules create no background schedule or reminder.

After a crash, silence, cancellation or stale checkpoint, retain the lease. Confirm the worker/process has stopped, inspect its branch and actual changed files, preserve its evidence, and record recovery. Only then release or transfer ownership. A clock timeout alone cannot free a write set. Treat late output from an old attempt as unadmitted material; it cannot overwrite the current attempt or unlock dependencies.

On context loss, reconstruct authority from the board, card revision, actual worktree and evidence. Do not infer state from a chat summary or remembered PID. If the coordinator changes, record the transfer and current event sequence before dispatching more work. Only one coordinator may own board writes at a time.

## Handoff and review

A complete handoff contains:

- Task/card revision, attempt and lease IDs; actual worker model/effort.
- Base identity and candidate commit, or a complete content-hash manifest for a permitted prose staging copy.
- Changed paths, output paths and a concise explanation of the resulting behavior or contract.
- Commands or review procedure actually run, outcomes and evidence references tied to that candidate.
- Failures, skipped checks, uncertainty, remaining blockers and any requested shared-file changes.

The coordinator verifies that the handoff matches the lease and card, then records review state. “Done,” a screenshot, or a test count without its source identity is insufficient.

Assign a fresh independent reviewer who did not write the candidate. The reviewer checks the actual diff/artifact, every completion criterion, relevant Bible/ADR rules and boundary effects. Findings name a path or artifact and the concrete violated requirement. Record PASS, PASS+NOTES, FAIL, BLOCKED or INCONCLUSIVE and the evidence method. PASS+NOTES is admissible only when its notes do not violate the definition of done. A single reviewer is one independent opinion.

One fresh reviewer may read a wave's two candidates together when their write sets are disjoint; each candidate still receives its own verdict and evidence method. A sprint-level review report, such as HF-10's foundation review, is itself reviewed for coverage by a different fresh reviewer before the coordinator records it; per-card reviews do not carry that second pass. After HF-01, HF-02, HF-03a, HF-03b, HF-04a, HF-04b and HF-05 are admitted, the coordinator runs one integrated read of those outputs together before assigning HF-06a; findings return through changes_requested on the card they name.

Reviewers remain read-only. They send their report; the coordinator records it. A failed requirement becomes changes_requested with actionable findings. Use at most two revised attempts after the initial attempt, numbered 2 and 3. A remaining failure returns the task to blocked with preserved evidence. Do not erase attempt history or substitute a different model family to evade capacity limits. Retry an environmental failure only after the condition changes.

## Serial integration and completion

Integrate one approved candidate at a time. Inspect the actual base and existing owner changes, admit only the leased changes and run the applicable checks on the integrated result. If another integration changed a relevant dependency, reassess the candidate and rerun affected checks before accepting it. Never silently broaden the lease to absorb unrelated changes.

Record the candidate identity, review identity and accepted integrated identity separately. Code tasks require a local commit identity for acceptance. Documentation-only work may use a coordinator-admitted exact file-hash manifest when commits are outside scope; that exception must be explicit in the authorization and board evidence. The manifest must include every delivered artifact and its source context. Do not claim off-machine backup or a remote merge from a local snapshot.

If integration or its checks fail, keep the task out of done, retain its failure evidence and stop dependent admission. Restore or isolate only the coordinator's candidate changes when safe; never destroy pre-existing user edits. Rework goes through changes_requested, or blocked when a required input/environment is unavailable. The initial attempt plus two revised attempts remains the bound.

Only the coordinator transitions review to done after independent approval, successful serial admission and required checks on that exact result. Prerequisites unlock only then. An approved candidate sitting in another worktree is not a completed dependency.

For legacy code changes, use the applicable checks in CONTRIBUTING, including `npm run verify` when builds are authorized and the required browser/physical checks. For this preparation and the documentation-only foundation sprint, run `npm run check:docs` (local links and anchors, card field sets, event sequence, required section headings) as the documentation-only command and `npm run check:scope -- <base> <candidate>` as the scope-selection command that prints the required checks; PS-01 delivers both under S0-02 and S0-03. Until they are admitted, the coordinator runs the equivalent checks by script and retains the receipt. Add schema/contract coverage and explicit scenario review. Do not run the build-containing verification command under a no-build instruction. Future Godot qualification commands come from the engineering handoff; the existing browser suite cannot certify the native game.

A fixture, source review, automated play, human session and hardware/performance measurement are different evidence. Every result states which method was used, its version and its limits. Historical completed work retains its historical scope. A new failure or changed requirement needs a recorded reopen or new task; it does not rewrite old evidence as if a different version had been tested.

## Questions and scope changes

BACKLOG defines each open question and its affected work. TRACKING records its live answer state, owner, evidence and resolution event. The coordinator may close an engineering question from an accepted producer contract or observed evidence when the question delegates that authority. Andrew supplies product choices and other decisions reserved to him. Never interpret elapsed time, lack of reply, a finished concept image or an old recommendation as an answer.

Recording an unknown is a valid completion for a documentation card whose definition explicitly requires a question register. It is not a valid replacement for a required runtime behavior. After an answer or completed path/schema contract makes downstream work concrete, revise the relevant card or materialize a new atomic card with sources, exact files, dependencies and evidence. Record that change before assignment. A former question is not silently transformed into broad implementation authorization.

Park or cancel a task only with a sourced disposition. Stop its worker and handle the lease first. Reopening done/parked/cancelled work requires a recorded reason, a revised card when scope changed, and fresh readiness checks. Do not reuse old review evidence for a changed acceptance contract.

## Checkpoint and handback

At a safe stop, leave no unowned active writer. Record remaining leases, worker/process status, integrated evidence, blockers and next eligible tasks. Release a lease only after its owner has stopped or completed the verified handoff. A pending review or blocked environment remains pending; it does not become done because a session is ending.

HF-01 through HF-10, with HF-03, HF-04, HF-06 and HF-07 split into a and b cards, form the proposed foundation sprint; the S0 cards form the prepare-stage program. HF-01 and HF-02 can be input-ready while sprint authorization is awaiting_review. Later contracts, per-system pages, full TECH_BIBLE assembly and the final architecture audit remain separate cards. Their absence is visible in the board. No game execution, remote setup, publication or scheduled work follows automatically from delivery of this manual.
