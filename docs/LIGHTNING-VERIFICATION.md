# Lightning caster verification

Tested on 5 September 2026, Phoenix time (6 September UTC), on the local `ahana` machine. This record covers [increment 01](project/INCREMENT-01-lightning-playtest.md), after serial admission and independent review. It supersedes current controls and mechanics in the [first-proof verification](FIRST-BUILD-VERIFICATION.md); that older evidence remains unchanged.

## Result and limits

The lightning caster, three waves, rewards, equipment dashboard and preserved original yard have passed the executed local and browser checks below. Andrew's human playtest remains open for natural aiming, controlled jumping, satisfying density and readable combat information. Hardware controller testing remains open.

Real mouse capture was attempted through both Chrome and the in-app browser. Both automated surfaces returned `pointerlockerror`, with a focused visible document and the API available. The game displayed its capture-and-resume recovery action and released no queued spell. Successful physical capture and its feel are not established by this session. Synthetic DOM replays explicitly bypass capture; they are not evidence that native capture succeeded.

## Executed checks

| Method | Observed result | What it establishes |
| --- | --- | --- |
| `npm run verify` | All six stages passed, including 96 Node tests: project, tests, models, baseline expedition, build, built HTTP | Local assertions, finite model geometry, production build and both served entries; see the retained source hashes and logs |
| Orchard DOM input replay | 25 checks passed | Movement, braking, double-jump limits, focused aim, repeat fire, valid Q/E casts, cancel, dashboard sections, equipment locking and clean resume/restart |
| Orchard state fixtures | 16 checks passed | Staged collection/companion unlock, charged ultimate, rewards, item/companion toggles, continuation, victory, loss and reset |
| Orchard input expedition | All three waves cleared through ordinary handlers; Ground Loop and Echo earned | A complete input-driven route with scripted aiming; no staged progression or enemy-health changes |
| Original yard DOM regression | All 20 checks passed | Preserved movement, class ability, pause/help, mounting/attacking, upgrades, loss/victory, collection view and result settlement |
| Visual inspection | 1280×720 and 1920×1080; keyboard navigation and interface scale up to 125% | Stable HUD locations, legible dashboard text, settings and map, visible spell circles/connections and distinct low/tall warnings |

The input expedition cleared in 41.96 simulation seconds with 187 shots, 278 hits and no damage taken. It collected three scrap and earned the two chosen rewards. This precise scripted route does not establish balanced difficulty or normal player completion time. Its Chrome frame history contains long throttled intervals and is not the performance benchmark below.

## Sustained rendered load

The retained final stress report records sixty seconds of both real time and active simulation at 1920×1080, device pixel ratio 1. The browser reported NVIDIA GeForce RTX 4080 through ANGLE/OpenGL ES 3.2. It rendered fourteen durable workers plus the Pruner, both modifiers, two conductors and the companion, using normal animation frames and DOM input. Durable health and the equipment/population are explicit fixtures; damage, attacks and rendering remain active.

The final run recorded 60.09 real seconds and 60.08 simulation seconds. Frame times averaged **16.69 ms**, with **16.8 ms p95**, **16.9 ms p99**, and **34.1 ms maximum**. It observed up to 637 draw calls and 182,668 triangles, with no browser errors. Player, conductor, companion, Echo and Ground Loop attacks all occurred.

The report includes every frame-time sample, frame percentiles, draw calls, triangles, geometry counts, graphics identity, errors and source-attributed attack counts. It requires player, conductor, companion and Echo activity and rejects paused or ended simulation. Measurements apply to this browser, machine and scene. Geometry allocation may grow during initial pool warm-up; this one-minute run does not establish hours-long memory stability.

## Independent review and corrections

The fresh read-only reviewer reproduced and then confirmed fixes for three defects: missing conductor connection geometry in placement previews, missing/mislabeled distant Pruner warnings, and loss of a second rebound on the same enemy. The coordinator also tightened Q/E browser checks to require successful casts and stress checks to require simulation advancement and attack activity.

A final visual inspection found insufficient contrast against the bright floor. Spell rings and conductor footprints now use dark backing inside their authoritative boundaries, and trajectories use decorative dark halos on the same centerlines. Renderer tests protect the unchanged damage bounds and pooled backing resources. The rendered load check was repeated after this correction.

## Evidence

The named record retains [input controls](../artifacts/lightning-playtest/dom-input.json), [state fixtures](../artifacts/lightning-playtest/state-fixtures.json), [earned expedition](../artifacts/lightning-playtest/input-expedition.json), [original-yard checks](../artifacts/lightning-playtest/baseline-browser.json), [final stress samples](../artifacts/lightning-playtest/stress-1920x1080.json), source hashes/logs, and selected screenshots. See the [dashboard](../artifacts/lightning-playtest/dashboard-1920x1080.png), [equipment](../artifacts/lightning-playtest/equipment-1920x1080.png), [map](../artifacts/lightning-playtest/map-1280x720.png), [placement geometry](../artifacts/lightning-playtest/placement-1280x720.png) and [attack-height warnings](../artifacts/lightning-playtest/warnings-1280x720.png). Visual fixtures are labeled in the QA interface and are separate from the earned expedition. The [play guide](LIGHTNING-PLAYGUIDE.md) gives the current controls.

The final source head is `49175ac`, including gameplay admission through `aef51fe` and the updated visual QA fixtures. The [evidence manifest](../artifacts/lightning-playtest/manifest.json) identifies each record's version, method and hash; the retained verification report identifies exact source hashes. The earned expedition and dashboard/map screenshots were captured at `4e066a8`; their underlying input and simulation sources are unchanged at the final head. Controls, state fixtures, placement/warning images and the final stress run were captured at `49175ac`, including the contrast correction. No dependency upgrade, engine migration, remote publication or deployment occurred. The original `/` implementation and first-proof evidence were preserved.
