# Scrapkeep swarm operating manual

Revision 12 (2026-11-15, ruling ds; moved to Mac Studio by ruling eb and flattened onto `main` by ruling ep: one local coordinator/Gate session runs on the Mac Studio, integrates reviewed pull requests directly onto `main`, and delegates disjoint units to worktrees; earlier claude.ai/PC wave history sits in git history and [DECISIONS.md](project-guide/handoff/DECISIONS.md)). Operational Sprint 0 (`docs/project/sprint-0/AUTHORIZATION.md`, archived in git history) is a closed historical record. For heavy-lane work, current authorization comes from [TRACKING.md](TRACKING.md#program-authorization); this manual grants none.

## Read first and preserve authority

For active alpha work in `sketches/core-loop`, follow the read-first order in [AGENTS.md](AGENTS.md) ("Read first, in this order"). For heavy-lane cards, start at the Bible contents at [BIBLE.md § Contents](BIBLE.md#contents) (`BIBLE.md:24-36`) and read the section the task names, not the whole book, then read the accepted engineering ADR sections the card cites from [the ADR index](adr/README.md), the exact card in [BACKLOG.md](BACKLOG.md) rather than BACKLOG whole, [TRACKING.md](TRACKING.md) for current execution state, the task's exact source sections, and [CONTRIBUTING.md](CONTRIBUTING.md) before working. The completed engineering handoff will add TECH_BIBLE.md as the implementation reference; it does not exist yet (alpha architecture lives in [sketches/core-loop/ARCHITECTURE.md](sketches/core-loop/ARCHITECTURE.md)).

The settled baseline is Godot 4.7.2 standard edition, typed GDScript, explicit hybrid/session ownership, native Resource/scene content, JSON aggregate saves and offline solo play. Do not reopen it because an older document says the engine is undecided. Preserve the approved art direction and binary trees. Questions concern missing details, not permission to replace settled choices.

These documents authorize preparation. A ready card is not permission to start its sprint. TRACKING must contain the applicable user scope authorization before dispatch. Production native implementation additionally requires the completed engineering handoff, resolved task-specific questions and a scoped build authorization. The authorized operational Sprint 0 extends prepare-stage proofs to an integrated smoke scene and exports before that handoff. The existing browser entries remain separate working proofs.

Task definitions live only in BACKLOG. Live heavy-lane task and question states live only in TRACKING. Alpha integration state lives in [project-guide/handoff/STATE.md](project-guide/handoff/STATE.md) (`Open stage: main` under ruling ep; `project-guide/coord/GRAPH.md` is archived in git history), and its rulings live in [project-guide/handoff/DECISIONS.md](project-guide/handoff/DECISIONS.md). This manual owns operating rules. Older planning records are dated evidence, not active queues.

## Roles and concurrency

[AGENTS.md](AGENTS.md) rule 11 owns worker routing, model selection, and fallback definitions (`.claude/agents/` and `.agents/agents/`); [project-guide/handoff/DECISIONS.md](project-guide/handoff/DECISIONS.md) owns active stand-ins. The coordinator creates each writer's worktree at the recorded base with `scripts/new-worktree.sh <task-id> <base-sha>` and names that path in the packet. Do not silently substitute models; report capability blockers to Andrew.

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

One thread, one writer (ruling by, Andrew, 9 November 2026). In the local coordinator session on the Mac Studio (rulings ds, eb, el), sequential and shared-file changes stay in the coordinator session, disjoint units go to one writer agent per worktree, and no writer reviews its own diff. Sub-agents run read-only for wide searches, outside research, long noisy runs, or independent diff reviews ([AGENTS.md](AGENTS.md) rules 2, 4 and 11). A review sub-agent receives only the diff and acceptance criteria, never the writer's reasoning. (Archived claude.ai thread background: `/mnt/project-files/ways-of-working/sub-agents-in-threads.md`.)

The delegate concurrency cap for coordinator worktrees is at most eight delegates alongside the coordinator (at most five writers and at most three reviewers, verifiers, or read-only explorers), or fewer when the host provides fewer slots. Idle or interrupted agents do not regain write authority merely because a slot becomes available. This is a concurrency ceiling, not a requirement to keep every slot busy.

Breadth over depth (Andrew, 2026-09-28). Work runs as a lane board: each area (for example geometry, attack reads, discovery, audio feedback, debt, kit trees, economy, hot-wired parts and assets) gets one small finished slice per wave. A slice gets one build and at most one fix round; then it merges, or it parks with its notes and the next wave rotates to another lane. A third round needs Andrew's word. Assets fan out widest: one shared direction sheet per asset category (geography and terrain, infrastructure and architecture, environment and weather, characters and props) and one unit per asset, each owning its own recipe and files, so no two units in a wave share a file. The lab flags are collapsed into defaults; only a checkpoint's single `--variant=` row may switch behaviour, and its losing arms are deleted after Andrew's verdict.

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

Write a handoff so it stands on its own for a reader who saw none of the work ([COMMS.md](project-guide/handoff/COMMS.md), ruling cz). A complete handoff contains:

- Task/card revision, attempt and lease IDs; actual worker model/effort.
- Base identity and candidate commit, or a complete content-hash manifest for a permitted prose staging copy.
- Changed paths, output paths and a concise explanation of the resulting behavior or contract.
- Commands or review procedure actually run, outcomes and evidence references tied to that candidate.
- Failures, skipped checks, uncertainty, remaining blockers and any requested shared-file changes.

The coordinator verifies that the handoff matches the lease and card, then records review state. “Done,” a screenshot, or a test count without its source identity is insufficient.

Assign a fresh independent reviewer who did not write the candidate. The reviewer checks the actual diff/artifact, every completion criterion, relevant Bible/ADR rules and boundary effects. Findings name a path or artifact and the concrete violated requirement. Record PASS, PASS+NOTES, FAIL, BLOCKED or INCONCLUSIVE and the evidence method. PASS+NOTES is admissible only when its notes do not violate the definition of done. A single reviewer is one independent opinion.

One fresh reviewer may read a wave's two candidates together when their write sets are disjoint; each candidate still receives its own verdict and evidence method. A sprint-level review report, such as HF-10's foundation review, is itself reviewed for coverage by a different fresh reviewer before the coordinator records it; per-card reviews do not carry that second pass. After HF-01, HF-02, HF-03a, HF-03b, HF-04a, HF-04b and HF-05 are admitted, the coordinator runs one integrated read of those outputs together before assigning HF-06a; findings return through changes_requested on the card they name.

Reviewers remain read-only. They send their report; the coordinator records it. A failed requirement becomes changes_requested with actionable findings. Use at most two revised attempts after the initial attempt, numbered 2 and 3. A remaining failure returns the task to blocked with preserved evidence. Do not erase attempt history or substitute a different model family to evade capacity limits. Retry an environmental failure (a busy tool, a timeout, a reclaimed container, a crashed first import) at once and without asking; it does not count as an attempt. Change something first only when the same failure repeats.

## Serial integration and completion

Integrate one approved candidate at a time. Inspect the actual base and existing owner changes, admit only the leased changes and run the applicable checks on the integrated result. If another integration changed a relevant dependency, reassess the candidate and rerun affected checks before accepting it. Never silently broaden the lease to absorb unrelated changes.

Record the candidate identity, review identity and accepted integrated identity separately. Code tasks require a local commit identity for acceptance. Documentation-only work may use a coordinator-admitted exact file-hash manifest when commits are outside scope; that exception must be explicit in the authorization and board evidence. The manifest must include every delivered artifact and its source context. Do not claim off-machine backup or a remote merge from a local snapshot.

If integration or its checks fail, keep the task out of done, retain its failure evidence and stop dependent admission. Restore or isolate only the coordinator's candidate changes when safe; never destroy pre-existing user edits. Rework goes through changes_requested, or blocked when a required input/environment is unavailable. The initial attempt plus two revised attempts remains the bound.

Only the coordinator transitions review to done after independent approval, successful serial admission and required checks on that exact result. Prerequisites unlock only then. An approved candidate sitting in another worktree is not a completed dependency.

For legacy code changes, use the applicable checks in CONTRIBUTING, including `npm run verify` when builds are authorized and the required browser/physical checks. For documentation-only scopes, run `npm run check:docs` (repo-wide Markdown links and `#anchor` targets, `check:skills`, `check:agents`, `wave-state`, `known-failing`, `weekly-list`, duplicate `DECISIONS.md` ruling letters, and `ARCHITECTURE.md` sync) and `npm run check:scope -- <base> <candidate>` as the scope-selection command that prints the required checks. Add schema/contract coverage and explicit scenario review. Do not run the build-containing verification command under a no-build instruction. Future Godot qualification commands come from the engineering handoff; the existing browser suite cannot certify the native game.

A fixture, source review, automated play, human session and hardware/performance measurement are different evidence. Every result states which method was used, its version and its limits. Historical completed work retains its historical scope. A new failure or changed requirement needs a recorded reopen or new task; it does not rewrite old evidence as if a different version had been tested.

## Light play lane

Andrew chose this lane on 22 September 2026 (TRACKING EV-0479, EV-0480) for throwaway gameplay sketches. Entry test: `npm run check:scope -- <base> <candidate>` reports only `sketch`, which claims `sketches/`. Each sketch is a self-contained Godot project under `sketches/<name>/`. Any other class, a mixed scope, or a `package.json` dependency edit exits to the heavy lane above.

Loop: one writer on one `proto/<name>` branch in its own worktree, `npm run sketch:smoke`, Andrew plays, then the coordinator merges. No card, lease, packet revision or independent reviewer is required. Andrew's play is the review, and no automated result substitutes for it. TRACKING receives an event only when the lane is entered or left, a question changes state, or a sketch is promoted.

Under ruling ep (and earlier wave stacking under `stage/alpha-w<N>`), the alpha program runs flat on `main` across Worlds 1–3 (`eq` full-alpha milestone); [ALPHA-PLAN.md](sketches/core-loop/design-v3/ALPHA-PLAN.md) holds the testing method, [ROADMAP.md](project-guide/handoff/ROADMAP.md) holds remaining work order, and [STATE.md](project-guide/handoff/STATE.md) tracks open branches and carried state. Andrew plays human sittings only; automation gates what reaches him.

Tiered gate (Andrew, 18 and 22 October 2026; moved to Mac Studio by `eb`, relaxed for active dev waves by `eo`, flattened to `main` by `ep`): this block is the single owner of the gate rule ([CONTRIBUTING.md](CONTRIBUTING.md) and [AGENTS.md](AGENTS.md) point here). Each unit is built by one writer in an isolated worktree against a checkable definition of done and file fence (ruling by). Only the coordinator/Gate session integrates reviewed pull requests onto the open branch (`main`, formerly `stage/alpha-w<N>`) in the Mac Studio checkout. Each unit gets one build and at most one fix round before merging or parking. The gate runs in three tiers (ruling cy, amended by ruling eo) so a PR gets a verdict in minutes, a wave or dev merge checks what it changed, and full sweeps run before human sittings.

- Per PR: focused tests on the feature the PR changes, plus `npm run sketch:fast -- --base <branch the PR is gated against>`, in about 10 minutes or less (pass `--budget 600`). No bot sweeps, medians, full-tier runs or personas per PR. Widen only when a focused test points outside the unit or a shared contract changes. The fast lane first fails a head that adds a symlink, a root file or a new top-level folder, or that carries another branch (a merge on its first-parent path) at an old head; `--pre <PR>` names prerequisite PRs that the head and the base both include. Then it runs cheapest first and stops at the first failure that is the PR's own: sketch-lint, placeholders no higher than the base in any kind and place, `check:docs` when Markdown changed, the node tests that touch changed scripts, then a Godot import (up to three tries), a 300-frame boot and the tests the diff reaches within the budget. A failing test reruns alone, then on the merge base. Red twice on the head and green on the base fails the lane, and so does red on both when the head fails a check the base passes. `unit_suite` (the content pins) always runs; park data changes pull in every park test; movement, boss, posture and damage changes name the posture-band proofs for the shards. Green on rerun is listed as flaky; red on the base too is listed as base-red; neither is blamed on the PR. A test with a `flake` row in the known-failing ledger gets up to three more head runs before it fails the lane: one green lists it as flaky (the receipt's `ledger_flaky`), and red on every run still fails the lane, so the row never excuses a test the PR broke. Tests past the budget and bot-tier tests the diff reaches are named in the receipt for the promotion gate. Two reports in the receipt never fail the lane. `checks_removed` lists each check label a changed or renamed test no longer makes, and the pull request names each one and says what now covers it. `deep_sweep` counts the deep sweep's leads on the branch's own lines ([DEEP-SWEEP.md](project-guide/handoff/DEEP-SWEEP.md)); the reviewer reads them. The fast lane plus an independent reviewer admits a PR to `main` (or the open integration branch).
- Per promotion, on `main` head: the wave gate. It runs the whole node suite, every non-bot test (the three windows), and a scoped set: the bot and band tests the wave's changes reach, by name. The fast lane's receipt already names the bot-tier tests and posture-band proofs a diff reaches; the Gate session adds any fight, stage or bot run the diff plainly touches and writes the list with its reason in the gate plan. `world1_run_test` is always on it while world 1 is the sitting target. Bot blocks the wave does not reach, the win-rate bands (B and C) and the red team are not read; their rows say DEFERRED and name their last full read (`node scripts/gate/tally.mjs --wave`). A new red is bisected across the PRs stacked since the last promoted head. Why: the first wave 36 gate took 4 h 57 min, and every one of its eleven reds sat in a file or a fight the wave had changed; the bot blocks, bands B and C and the red team, about three of those hours, found nothing outside those areas.
- Per sprint, on the head a sitting build is cut from: the release gate. It is the full gate, `npm run sketch:gate` with the bot tier sharded, every band and the red team, with nothing deferred (`tally.mjs` without `--wave`). A sitting build is cut only from a release-gated head. The release gate also carries the release film (ruling dz, Andrew, 16 November 2026): one first-timer film of the whole of world 1 on the PC, read by fresh readers beside a control film whose planted fault must be caught. It is the user acceptance bug hunt: its findings are clustered by cause, each cluster is fixed as one batch with one review, and one confirm film closes the rows. No wave gate waits for a film. A change a player can see still shows its work per pull request: before and after stills, or a short run of frames, of the scene it changes, from the same seed and moment on the PC, named in the pull request and looked at by its reviewer. Difficulty tuning lands last in a sprint, after the polish waves and before the release gate, so its band reads are taken once on the game that ships.
- Promotion and GPU checks: when running a staged promotion (`ruling ep` dev waves integrate directly onto `main` under `ruling eo`), integration proceeds once the wave gate shows no new red (and for release gates, no red-team blockers). Gate CPU and Mac capture work run on the Mac Studio (`eb`); Linux GPU and AppImage bench runs execute on `ahana` (`[DEVICES.md](project-guide/handoff/DEVICES.md)`). Frame timing runs only while heavier jobs are idle.
- Frame-time evidence on `ahana` follows [GATE.md](project-guide/handoff/GATE.md) and [DEVICES.md](project-guide/handoff/DEVICES.md) (gamescope headless, never `godot --headless`; pre-2026-10-24 captures carry `"wallpaper running"`; headless Blender bakes configure OptiX).
- After each promotion, the deep-modules sweep runs on the promoted diff (Andrew, 8 November 2026): `node scripts/deep-sweep.mjs` on main, triaged with [DEEP-SWEEP.md](project-guide/handoff/DEEP-SWEEP.md). Its refactors are behaviour-preserving PRs under the per-PR gate above; they never hold a promotion.
- An independent fresh Gemini 4 Neon High reviewer (Rule 11 / `ej`, or `scrapkeep-reviewer` fallback) reviews consequential seams before integration. Andrew plays at sittings only.
- A flaky test is made deterministic (fixed seeds, multi-seed medians, sim-clock timing). Never skip or silence a test: carried known reds belong in [KNOWN-FAILING.tsv](project-guide/handoff/KNOWN-FAILING.tsv) with owner, cause, and review date (`KNOWN-FAILING.tsv` is the sole carried-red ledger; rulings `bq`, `dx`, and [GATE.md](project-guide/handoff/GATE.md) govern row scope and expiry).
- The gate's own steps are checked in: [GATE.md](project-guide/handoff/GATE.md) is the recipe, `scripts/gate/shard.mjs` runs one resumable shard, `scripts/gate/carry.mjs` says which rows carry when the head moves, and `scripts/gate/tally.mjs` refuses a CLEAN verdict while any row is empty, red or without a receipt.
- `scripts/sketch-fast.timings.json` orders the lane. Refresh it after each full gate with `node scripts/sketch-fast.mjs --fold-timings <receipts...>`: it takes the gate shards' `shard.json` files, a full-smoke receipt or a fast-lane receipt, and folds passing tests only. A test with no row is priced at 180 s, and one named like a bot run or a sweep is listed for the bot shards.

Sketches are not proofs. Their checks qualify nothing, typed-GDScript warnings are optional, and promotion into `native/`, `/`, `/orchard.html`, the Bible or an ADR is a heavy-lane decision.

## Questions and scope changes

BACKLOG defines each open question and its affected work. TRACKING records its live answer state, owner, evidence and resolution event. The coordinator may close an engineering question from an accepted producer contract or observed evidence when the question delegates that authority. Andrew supplies product choices and other decisions reserved to him. Never interpret elapsed time, lack of reply, a finished concept image or an old recommendation as an answer.

Recording an unknown is a valid completion for a documentation card whose definition explicitly requires a question register. It is not a valid replacement for a required runtime behavior. After an answer or completed path/schema contract makes downstream work concrete, revise the relevant card or materialize a new atomic card with sources, exact files, dependencies and evidence. Record that change before assignment. A former question is not silently transformed into broad implementation authorization.

Park or cancel a task only with a sourced disposition. Stop its worker and handle the lease first. Reopening done/parked/cancelled work requires a recorded reason, a revised card when scope changed, and fresh readiness checks. Do not reuse old review evidence for a changed acceptance contract.

## Sprint closure

The coordinator runs sprint closure when the selected sprint has no remaining active writer or task requiring work. A blocked card may be handed back through failed or pending closure; it cannot be silently counted as complete. Task completion is not sprint completion.

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

A worker encountering a contradiction stops affected work and submits an ADR-style amendment request. Unaffected leased work may continue. The worker cites conflicting source clauses, observed evidence, affected cards, the proposed change, alternatives and compatibility consequences. It cannot silently deviate or edit shared authority.

The coordinator first distinguishes implementation defects from specification defects. Implementation defects return through changes_requested. Andrew decides changes to accepted architecture or product direction. The coordinator may correct a factual documentation error supported by observed evidence only when the correction preserves those decisions.

A request is proposed, accepted, rejected or deferred. Acceptance is not admission. TRACKING records the decision owner, evidence, affected cards and the separate source/card propagation receipt. Dependent work remains blocked until every required accepted amendment is admitted. An accepted but unapplied amendment is still a blocker. Rejected requests return affected work to the unchanged contract only after readiness is checked. Deferred contradictions remain blockers for affected work.

Blocking amendments may be admitted during a sprint. Update authoritative source clauses and affected card revisions together, review the changed acceptance contract, record propagation and recheck readiness before work resumes. The closeout reconciles all remaining requests before pinning final evidence. Never defer a needed source change to closeout while implementing against an unaccepted design.

## Checkpoint and handback

When selected sprint work is exhausted, invoke [Sprint closure](#sprint-closure) before reporting SPRINT COMPLETE. At a safe stop, leave no unowned active writer. Record remaining leases, worker/process status, integrated evidence, blockers and next eligible tasks. Release a lease only after its owner has stopped or completed the verified handoff. A pending review or blocked environment remains pending; it does not become done because a session is ending.

HF-01 through HF-10, with HF-03, HF-04, HF-06 and HF-07 split into a and b cards, form the fourteen-card foundation set; the S0 cards form the closed prepare-stage program. The [TRACKING.md program authorization row](TRACKING.md#program-authorization) states what is authorized and the task index states each card's state; this manual restates neither. Per-system pages, full TECH_BIBLE assembly and the final architecture audit remain separate cards. Their absence is visible in the board. No game execution, remote setup, publication or scheduled work follows automatically from delivery of this manual.
