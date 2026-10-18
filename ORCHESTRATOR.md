# Scrapkeep swarm operating manual

Revision 7 (2026-10-01: the alpha program runs the light play lane as batched waves with a receipt-based review shape, EV-0599). Revision 6 (2026-09-25: Opus pins moved to Opus 5.5, EV-0484; the light play lane appends each verdict to `docs/playtests/verdicts.ndjson`, EV-0500). The prepare stage and [Operational Sprint 0](docs/project/sprint-0/AUTHORIZATION.md) are complete historical records. The current authorization is whatever the [TRACKING.md program authorization row](TRACKING.md#program-authorization) records; this manual grants none.

## Read first and preserve authority

Start at the Bible contents at [BIBLE.md § Contents](BIBLE.md#contents) (`BIBLE.md:24-36`) and read the section the task names, not the whole book. Read the accepted engineering ADR sections the card cites from [the ADR index](adr/README.md), the exact card in [BACKLOG.md](BACKLOG.md) rather than BACKLOG whole, [docs/project/SOURCE-DISPOSITIONS.md](docs/project/SOURCE-DISPOSITIONS.md) only when a card cites a historical identifier, then [TRACKING.md](TRACKING.md) for current execution state. Read the task's exact source sections and [CONTRIBUTING.md](CONTRIBUTING.md) before working. The completed engineering handoff will add TECH_BIBLE.md as the implementation reference; it does not exist yet.

The settled baseline is Godot 4.7.2 standard edition, typed GDScript, explicit hybrid/session ownership, native Resource/scene content, JSON aggregate saves and offline solo play. Do not reopen it because an older document says the engine is undecided. Preserve the approved art direction and binary trees. Questions concern missing details, not permission to replace settled choices.

These documents authorize preparation. A ready card is not permission to start its sprint. TRACKING must contain the applicable user scope authorization before dispatch. Production native implementation additionally requires the completed engineering handoff, resolved task-specific questions and a scoped build authorization. The authorized operational Sprint 0 extends prepare-stage proofs to an integrated smoke scene and exports before that handoff. The existing browser entries remain separate working proofs.

Task definitions live only in BACKLOG. Source dispositions and the source inventory live in [docs/project/SOURCE-DISPOSITIONS.md](docs/project/SOURCE-DISPOSITIONS.md), which the coordinator owns. Live task and question states live only in TRACKING. This manual owns operating rules. Older planning records are dated evidence, not additional active queues.

## Roles and concurrency

Read the active host's pstack model map at assignment time. Codex uses only `gpt-6-astra` with its configured effort. Claude Code uses the project agent definitions under `.claude/agents/`, which pin model and effort by the pstack tiers Andrew set on 2026-09-19 (Opus pins moved to Opus 5.5 on 2026-09-25): `scrapkeep-writer` (Sonnet 5.5 medium) and `scrapkeep-writer-low` (Sonnet 5.5 medium, fully specified mechanical edits) for writing, `scrapkeep-explorer` (Sonnet 5.5 medium) for read-only exploration, `scrapkeep-verifier` (Opus 5.5 medium since the 2026-09-28 overturn rule fired; Sonnet 5.5 before) for check reruns with receipts, `scrapkeep-reviewer-medium` (Opus 5.5 medium) for routine review and `scrapkeep-reviewer` (Fable 5.1 high) for review that turns on Bible, ADR or contract judgement; nothing runs above high. On 2026-09-28 Andrew pinned the agents to family aliases (`sonnet`, `opus`, `fable`) so each tier runs its newest model, set Sonnet and Opus agents to medium, and moved writing, lookup and mechanical slots to Sonnet 5.5 as a trial where speed can be afforded; Opus 5.5 keeps routine review and the acceptance gate. The coordinator picks the definition by a unit's importance and difficulty, not by slot availability. These definitions no longer self-isolate. The coordinator creates each writer's worktree at the recorded base with `scripts/new-worktree.sh <task-id> <base-sha>` (delivered by PS-01) and names that path in the packet. The runtime contract maps model/effort to supported tool fields. Check actual runtime selection; a model label in a prompt cannot change it. If the required model or effort cannot run, retain the task and report the capability blocker. Do not silently substitute another model.

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

For the dress-and-finish push (Andrew, 2026-10-06, decisions P-R2): up to eight Codex `gpt-6.1-sol` writers at high effort on the fast tier, up to three `gpt-6-astra` verifiers, and one `scrapkeep-reviewer-medium` gate read per wave; the limits below otherwise stand. At most eight delegates may run alongside the coordinator: at most five writers and at most three reviewers, verifiers or read-only explorers (Andrew, 2026-09-28, a throughput trial on Sonnet 5.5; it replaced EV-0367's six, with at most four writers). Review runs as a lane: the Sonnet writer runs its own tests, `scrapkeep-verifier` (Opus since 2026-09-28) reruns the packet's checks and returns receipts, `scrapkeep-reviewer-medium` (Opus) gates from the diff and those receipts without rerunning, and `scrapkeep-reviewer` (Fable) joins only for consequential seams (threading, RR-01 damage geometry, data loss). The starting ratio is five writers to two verifiers to one gate. Rebalance on two measures: if a unit waits longer for its gate than its writer took to build it, add a gate; if the gate fails more than one in five units the verifier passed, move verification back to Opus. That rule fired on 2026-09-28: the gate failed 2 of the first 3 Sonnet-verified units (the shell scaffold, and the durability prototype in both rounds) on criteria the verifier had marked passed, such as the damage order and the hull guarantee; writing stays on Sonnet. Use a lower limit when the host provides fewer slots. Andrew's EV-0367 routing sends per-card review to `scrapkeep-reviewer-medium`. With Fable credit exhausted (EV-0406), the per-sprint integrated read and any judgement advisory run on `gpt-6-astra` at high effort through the Codex plugin's `codex:codex-rescue` forwarder, read-only, in place of `scrapkeep-reviewer`, until Andrew restores Fable. Fable is available again as of 2026-10-01 (EV-0599): `scrapkeep-reviewer` reads the consequential seams the alpha plan names, one Fable read at a time, and `gpt-6-astra` at high effort stays the fallback when Fable is rate limited. Idle or interrupted agents do not regain write authority merely because a slot becomes available. This is a concurrency ceiling, not a requirement to keep every slot busy.

Breadth over depth (Andrew, 2026-09-28). Work runs as a lane board: each area (for example geometry, attack reads, discovery, audio feedback, debt, and Codex design lanes for kit trees, economy, hot-wired parts and assets) gets one small finished slice per wave. A slice gets one build and at most one fix round; then it merges, or it parks with its notes and the next wave rotates to another lane. A third round needs Andrew's word. Assets fan out widest: one shared direction sheet per asset category (geography and terrain, infrastructure and architecture, environment and weather, characters and props) and one unit per asset, each owning its own recipe and files, so no two units in a wave share a file. Until 2026-10-01, anything that changed default behaviour before Andrew's lab sitting shipped behind a flag. Since EV-0599 the lab flags are being collapsed into defaults and deleted; only a checkpoint's single `--variant=` row may switch behaviour, and its losing arms are deleted after Andrew's verdict.

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

## Light play lane

Andrew chose this lane on 22 September 2026 (TRACKING EV-0479, EV-0480) for throwaway gameplay sketches. Entry test: `npm run check:scope -- <base> <candidate>` reports only `sketch`, which claims `sketches/`. Each sketch is a self-contained Godot project under `sketches/<name>/`. Any other class, a mixed scope, or a `package.json` dependency edit exits to the heavy lane above.

Loop: one writer on one `proto/<name>` branch in its own worktree, `npm run sketch:smoke`, Andrew plays, an entry with Andrew's verdict goes to [the playtest log](docs/playtests/PLAYTEST-LOG.md), the coordinator appends its line to `docs/playtests/verdicts.ndjson` (the verdict span copied verbatim; `node scripts/lab/verdicts.mjs` must pass, and `npm test` fails until it does), then the coordinator merges. No card, lease, packet revision or independent reviewer is required. Andrew's play is the review, and no automated result substitutes for it. TRACKING receives an event only when the lane is entered or left, a question changes state, or a sketch is promoted.

Alpha program waves (EV-0599). The alpha program on `proto/alpha` runs this lane as batched waves; [ALPHA-PLAN.md](sketches/core-loop/design-v3/ALPHA-PLAN.md) holds the plan and its testing method.

- Up to five writers build in coordinator-prepared worktrees at the integration head, each against a checkable definition of done and a file fence. No two units in a wave share a file.
- A writer runs the fast checks and the tests its packet names. It never runs the full smoke.
- One integrator merges the accepted units into a candidate on the integration head and runs the gate once on that exact tree. The gate is `npm run sketch:gate`; until that command lands it is `npm run sketch:smoke -- --sketch core-loop`.
- One read-only gate reviewer judges the diff and the receipts and runs nothing.
- The coordinator admits the candidate by fast-forward and accepts the integrator's receipt for the same tree hash. It reruns the gate only when the admitted tree differs. A receipt with unexpected skips is not merge evidence.
- Each unit gets one build and at most one fix round, then merges or parks with its notes.
- `scrapkeep-reviewer` (Fable) reads consequential seams: threading, damage geometry, saves and migrations, the run spine, and the integrated tree before each checkpoint.
- Andrew's play of each checkpoint is still the review that counts. The gate only decides what reaches him.

Tiered gate (Andrew, 18 October 2026: move fast, fail fast, promote each wave promptly). The gate runs in three tiers so a PR gets a verdict in minutes and the expensive checks run once per staging head, not once per PR.

- Per PR, the fast lane: `npm run sketch:fast -- --base <branch the PR is gated against>`. It first fails a head that adds a symlink, a root file or a new top-level folder, or that carries another branch (a merge on its first-parent path) at an old head; `--pre <PR>` names prerequisite PRs that the head and the base both include. Then it runs cheapest first and stops at the first failure that is the PR's own: sketch-lint, placeholders no higher than the base in any kind and place, `check:docs` when Markdown changed, the node tests that touch changed scripts, then a Godot import (retried once), a 300-frame boot and the tests the diff reaches within a 15-minute budget. A failing test reruns on the head and on the merge base side by side, every Godot process holding one of the lane's width slots; a solo test reruns alone first. Clean base verdicts (never a timeout or a kill) are cached per base tree in the shared git directory, so a known base-red costs one rerun on later heads in any worktree. Red twice on the head and green on the base fails the lane, and so does red on both when the head fails a check the base passes. `unit_suite` (the content pins) always runs; park data changes pull in every park test; movement, boss, posture and damage changes name the posture-band proofs for the shards. Green on rerun is listed as flaky; red on the base too is listed as base-red; neither is blamed on the PR. Tests past the budget and bot-tier tests the diff reaches are named in the receipt for the staging full gate and the bot shards. The fast lane plus an independent reviewer admits a PR to the staging head.
- Per staging head, the full gate: `npm run sketch:gate` with the bot tier sharded as today. It compares against the last promoted head; a new red is bisected across the PRs stacked since then.
- Per staging head, the red team plays the same head in parallel with the full gate; the full sweep runs once at each wave close.
- Staging promotes to main when the full gate shows no new red and the red team reports no new blocker. Promotion is a GitHub merge of the stage PR under the project coordinator's standing merge authority, not a push from Andrew's machine. The machine then runs GPU checks on each promoted head; a GPU red is a fix in the next wave, not a hold, unless it is a crash.
- A flaky test is made deterministic (fixed seeds, multi-seed medians, sim-clock timing). It is never skipped, disabled or quarantined to get a green run.
- `scripts/sketch-fast.timings.json` orders the lane. Refresh it from any full-smoke receipt with `node scripts/sketch-fast.mjs --fold-timings <receipt.json>`.

Sketches are not proofs. Their checks qualify nothing, typed-GDScript warnings are optional, and promotion into `native/`, `/`, `/orchard.html`, the Bible or an ADR is a heavy-lane decision.

## Questions and scope changes

BACKLOG defines each open question and its affected work. TRACKING records its live answer state, owner, evidence and resolution event. The coordinator may close an engineering question from an accepted producer contract or observed evidence when the question delegates that authority. Andrew supplies product choices and other decisions reserved to him. Never interpret elapsed time, lack of reply, a finished concept image or an old recommendation as an answer.

Recording an unknown is a valid completion for a documentation card whose definition explicitly requires a question register. It is not a valid replacement for a required runtime behavior. After an answer or completed path/schema contract makes downstream work concrete, revise the relevant card or materialize a new atomic card with sources, exact files, dependencies and evidence. Record that change before assignment. A former question is not silently transformed into broad implementation authorization.

Park or cancel a task only with a sourced disposition. Stop its worker and handle the lease first. Reopening done/parked/cancelled work requires a recorded reason, a revised card when scope changed, and fresh readiness checks. Do not reuse old review evidence for a changed acceptance contract.

## Sprint closure

The coordinator invokes [the sprint-close prompt](docs/project/prompts/sprint-close.md) when the selected sprint has no remaining active writer or task requiring work. A blocked card may be handed back through failed or pending closure; it cannot be silently counted as complete. Task completion is not sprint completion.

1. Stop dispatch. Reconcile every lease and attempt. Pin the integrated commit and require a clean tracked worktree. A candidate in another worktree is not the integrated result.
2. Reconcile specification amendment requests under [Specification contradictions](#specification-contradictions). Admit accepted amendments and affected card revisions together. Review changed implementation and rerun affected checks. Pin the resulting commit before collecting final evidence.
3. Execute the scope's integrated gate on that commit. Native proof sprints run the ADR harness, export both targets, execute Linux locally and in CI, and retain reports with commit and toolchain identities. The first local Linux launch must be visible with success and a working exit action. Windows export alone establishes no Windows execution.
4. Review rejected attempts, blockers and discovered work. Record each cause and disposition. Preserve evidence and prior completion history. A newly discovered regression creates an atomic repair card or an explicit reopen.
5. Groom BACKLOG. Revise sizes, dependencies and questions. Every new card needs exact inputs, permitted files, observable acceptance and a verification method. Record each definition change and readiness decision in TRACKING.
6. Prepare one next-sprint proposal with one objective and at most four S/M cards. Prioritize integration repairs, then prerequisites for accepted direction, then other eligible work. Name card revisions, dependency order, questions, permitted actions and acceptance. Only cards with complete current inputs may be in the initial dispatch set. The proposal stays awaiting_review; it grants no execution authority.
7. Record a closure receipt and outcome in TRACKING. `passed` requires every applicable gate to pass, no active lease and no unresolved applicable amendment or incomplete selected task. `failed` names an observed failed gate. `pending_evidence` names absent, stale, skipped-required or inconclusive evidence. A repair card or next-sprint proposal never changes a failed gate to a pass.

The receipt identifies sprint ID, integrated commit, scope kind, selected task revisions and states, required gates and evidence paths, lease count, amendment dispositions, retro actions, grooming changes and the next proposal. Gate evidence names its source commit, command or method, result and limitations. A documentation-only scope uses document and scenario checks with no build. Sprint 0 explicitly marks gameplay/Pillars not applicable because it contains no playable slice. That is not a gameplay pass.

Each gameplay sprint declares its playable objective and applicable Bible Pillars decision tests before dispatch. Closeout needs automated smoke and Andrew's human playtest evidence for physical mastery, visible build changes and meaningful world discovery as applicable. Missing required human feedback stays pending_evidence. Automated play cannot approve enjoyment. Performance and hardware claims require their own measurements.

The coordinator writes one closure result per sprint and integrated commit. A repeated request attaches to the same result and reuses existing task/amendment IDs. A new result after a code change names the previous receipt. Append compensating events rather than deleting history. Never accept evidence from a different source commit merely because task names match.

## Specification contradictions

A worker encountering a contradiction stops affected work and submits an ADR-style request using [the amendment template](docs/project/sprint-0/amendment-request.md). Unaffected leased work may continue. The worker cites conflicting source clauses, observed evidence, affected cards, the proposed change, alternatives and compatibility consequences. It cannot silently deviate or edit shared authority.

The coordinator first distinguishes implementation defects from specification defects. Implementation defects return through changes_requested. Andrew decides changes to accepted architecture or product direction. The coordinator may correct a factual documentation error supported by observed evidence only when the correction preserves those decisions.

A request is proposed, accepted, rejected or deferred. Acceptance is not admission. TRACKING records the decision owner, evidence, affected cards and the separate source/card propagation receipt. Dependent work remains blocked until every required accepted amendment is admitted. An accepted but unapplied amendment is still a blocker. Rejected requests return affected work to the unchanged contract only after readiness is checked. Deferred contradictions remain blockers for affected work.

Blocking amendments may be admitted during a sprint. Update authoritative source clauses and affected card revisions together, review the changed acceptance contract, record propagation and recheck readiness before work resumes. The closeout reconciles all remaining requests before pinning final evidence. Never defer a needed source change to closeout while implementing against an unaccepted design.

## Checkpoint and handback

When selected sprint work is exhausted, invoke [Sprint closure](#sprint-closure) before reporting SPRINT COMPLETE. At a safe stop, leave no unowned active writer. Record remaining leases, worker/process status, integrated evidence, blockers and next eligible tasks. Release a lease only after its owner has stopped or completed the verified handoff. A pending review or blocked environment remains pending; it does not become done because a session is ending.

HF-01 through HF-10, with HF-03, HF-04, HF-06 and HF-07 split into a and b cards, form the fourteen-card foundation set; the S0 cards form the closed prepare-stage program. The [TRACKING.md program authorization row](TRACKING.md#program-authorization) states what is authorized and the task index states each card's state; this manual restates neither. Per-system pages, full TECH_BIBLE assembly and the final architecture audit remain separate cards. Their absence is visible in the board. No game execution, remote setup, publication or scheduled work follows automatically from delivery of this manual.
