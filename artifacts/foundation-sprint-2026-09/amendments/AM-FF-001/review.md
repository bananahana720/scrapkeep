**PASS+NOTES — AM-FF-001 acceptance contract.** The factual correction preserves accepted product and architecture decisions, retains all four required runtime patterns, and replaces sketches with historical source evidence where applicable. The unparsed scene-lifecycle exception accurately reflects missing coverage. No blocking contract defect found.

Requested startup configuration: `gpt-6-astra`, effort `high`. Internal model/effort introspection is unavailable; actual startup selection cannot be independently confirmed. No substitution or delegation occurred.

Reviewed `/home/andrew/Projects/scrapkeep`, branch `main`, HEAD and accepted base `70c8c054fa1ee04bcfec1e3f3acae869c482668f`. All four proposal-manifest hashes match. `card-before.md` exactly matches the original card bytes; `card-after.md` exactly matches proposed BACKLOG HF-04b revision 2.

| Reviewed source | SHA-256 |
| --- | --- |
| `BACKLOG.md` | `7a0a99a8af6371b6a11c783d011709cc021d61421130da228c1bb93ca0097a74` |
| `AM-FF-001/card-after.md` | `9706c0fe882cbc2b51607ddabab05908f21593867542f9dcd1cd312c28620d3d` |
| `AM-FF-001/request.md` | `917dcf2c86747e90f29072cdec9e31d162c8acf338e1d689a2a8bd326b8abb6c` |
| `AM-FF-001/card-before.md` | `21e4e3029b4b028c4190092fe01bfc8291521b3f3ad2ca36bd9e9988c9d7eb30` |

Amendment paths above are relative to `artifacts/foundation-sprint-2026-09/amendments/`.

| Criterion | Evidence and assessment |
| --- | --- |
| Correction authority and original trigger | Original card DoD2 requires revision 2 after S0-04. `docs/tech/proofs/S0-04-runtime-ownership.md:109–111` already proposes source links with an unparsed lifecycle exception. Consistent with ORCHESTRATOR’s factual-correction authority. |
| Unchanged contract | DoD1/3, dependencies, owner, size, lane, output paths and boundary are byte-identical. Added HF-03a input is already prerequisite through HF-04a. |
| Preserved architecture | `adr/TADR-002-runtime-model.md:24–34` retains explicit ownership, one gameplay tick owner, scoped result reporting and separate input/cancel/pause operations. HF-04a DoD3 still requires replacement, teardown and surviving run/profile ownership. |
| Exact historical source | All seven scripts match admitted `f8d1b04cd336991bab4fd8ea6274c6e365c23ab8` byte-for-byte and match the retained `native-smoke-report.json` hashes. EV-0031 identifies integration and direct receipts; receipts were retained at `4e3ffd06e77018392bcfec9b88bd99ca13c863b0`. |
| Single owner and rejected mutation | `proof_runner.gd:59,72–74` asserts tick/callback equality, rejected external calls and copied-record isolation. Normal receipt lines 4–8 pass; fault receipt lines 7/16 detect direct-write drift. |
| Minimal transitions and pause/input | `proof_runner.gd:88,102–104,120–126` asserts prepare/release/cast, paused tick, active menu, preserved preparation, cleared input and resume without casting. Normal receipt lines 9–16 supports these claims. |
| Missing coverage remains explicit | Proposed card line 23 excludes complete production state machines, positive result-signal delivery and scoped teardown; replacement remains an unparsed sketch. Reconciliation with admitted HF-04a is mandatory. |
| Typing and discovery | Seven typed scripts inspected; `native/project.godot:11–16` warning settings match the admitted configuration. `scripts/native-smoke.mjs:208–275` discovers runners and checks normal/fault outcomes. No execution performed. |

Nonblocking findings:

- `native/proofs/tadr-002/proof_runner.gd:120`: pending cancellation is **printed, not asserted**. Source establishes queuing; assertions establish cleared input, frozen ticks and post-resume cancellation. Downstream examples must preserve that distinction, as revision 2’s assertion-mapping requirement demands.
- `artifacts/local/foundation-full/amendment-docs.json:95,103`: retained check:docs PASS matches the exact proposed BACKLOG hash, but its TRACKING hash predates the current administrative snapshot. It does not qualify current EV-0082. Coordinator-reported check:project PASS was not independently rerun.

Evidence limits: retained normal proof reports 12 assertions, zero failures and exit 0; injected fault reports two failures and exit 1 on Godot `4.7.2.stable.official.ed1daf0bf`. These establish bounded historical headless behavior only. They do not establish field privacy, production timing, scene replacement, real input/focus events, rendering, hardware support or human feel. No new checks, native execution, builds, browser work, network research, edits or records were produced. The separate HF-03a writer candidate was not reviewed. **This review does not admit the amendment.**