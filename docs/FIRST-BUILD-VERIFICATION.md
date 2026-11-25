# Iron Orchard first-build verification

5 September 2026. The first third-person rolling proof is playable at [the local production entry](http://127.0.0.1:8787/orchard.html). The original yard remains at [its existing entry](http://127.0.0.1:8787/). The local server was started with contact capture disabled for this verification session.

## Accepted scope

Pip sits inside a stabilized cockpit enclosed by a rotating, irregular scrap cage. Camera-relative rolling, braking, a short ram burst, and an aimed charge-release pulse connect exploration to combat. Two Snipcarts close inward; two Spreadlegs push their feet outward. One Grand Pruner arm repeats the shearing motion at larger scale and throws announced rolling offcuts when approached from a distance.

Damage follows the declared tool paths. Ordinary body collisions bump the ball; damaging strokes commit to a direction. Recovery exposes a housing that rewards well-aimed attacks and rams. Enemies take ordinary damage in every live phase. Earned Shear and Brace parts visibly attach to the mech and affect its abilities. Shear unlocks one following support machine that damages and primes nearby enemies.

This is the bounded first-build goal. The full class roster, transformative item combinations, assembled companion recipes, planted infrastructure, long expedition, and co-op remain design work.

## Executed checks

| Evidence | Result | What it establishes |
| --- | --- | --- |
| `npm test` | 70 passed, 0 failed | Original systems plus 25 orchard simulation cases and 2 renderer regressions |
| `npm run test:orchard:models` | Passed | Finite geometry and transforms, 126 poses per enemy, matching tool articulation, growth attachments, enclosed cabin bounds |
| `npm run build` | Passed | Both HTML entries and their production assets generated |
| Production HTTP requests | Both HTML entries and all 10 linked asset references returned 200 | Static serving and entry configuration; [request record and SHA-256 hashes](../artifacts/orchard-first-build/production-http.json) |
| Orchard DOM control replay | 11/11 passed in development and production | Start, movement, brake, charge/release, burst, pause/resume, reset, right aim and camera-relative movement |
| Orchard state fixtures | 7/7 passed in development and production | Mechanism effects, companion rendering, maximum-scale cockpit, victory/defeat guide navigation, restart cleanup |
| Input-driven expedition | All 7 assertions passed in development and production | All five enemies dismantled, both mechanisms earned, companion deployed, victory reached through ordinary handlers; [browser result record](../artifacts/orchard-first-build/browser-results.json) |
| Original yard browser replay | 20/20 passed | Preserved class controls, firing/collection, breach/loss, upgrade, result, collection and return-to-title paths |
| Fresh independent review | Three P2 findings fixed and verified | Correct diagonal hazard orientation, no early physical offcut, and guide closure returning to terminal results |

The built-in QA interface is available only at `orchard.html?qa`. Its input replay sends keyboard and right-drag events through production handlers. The expedition script reads state for precise steering but does not inject health, enemy deaths, pickups, or progress. State-fixture buttons explicitly stage those values for isolated presentation and lifecycle checks. These are different evidence types; neither is a human playthrough.

## Visual inspection

Inspected real WebGL frames in the Codex browser at 1280 × 720: the opening screen, gameplay chase view, front cockpit view, Snipcart windup, giant-arm windup, and victory results. The first cockpit version read as a hamster sitting on top; the admitted model lowers the full animal and glass cabin inside the cage. The repeatable mesh check measured a maximum cabin radius of 0.868 in the unit ball's local space, including its animated lean.

The first visual-fixture implementation failed to refresh hazards. That fixture was corrected to update enemies while the simulation is still playing, then pause. Subsequent inspected frames include the declared windup paths. A contrast pass darkened the telegraph on the pale orchard ground. These screenshots were inspected inline in the browser session; no saved image path is claimed here.

The production orchard and original baseline produced no error-level browser console entries during the checked interactions. That is an observed check, not a guarantee covering every device or input combination.

## Playtest limits and next decisions

- **Difficulty and pacing:** the precise input script cleared the development encounter in 37.05 simulation seconds and the production build in 37.01 seconds, each with 27 shots, 1 counter, 14 collected parts, and zero damage. Ranged circling is currently strong. The proposed 2–4 minute human proof and eventual 30–45 minute expedition remain unmeasured. Adding tougher enemy pressure should preserve ordinary movement exits and useful baseline damage.
- **Handling:** keyboard handlers and right-drag aiming were exercised. Physical mouse capture, controller hardware, and mobile ergonomics need hands-on checks. Touch has fallback movement/action controls but does not yet have a dedicated camera gesture.
- **Presentation:** the environment and articulated models are source-authored procedural geometry. They are a playable art prototype. The generated research artwork remains a separate concept reference.
- **Scale and combat systems:** normal radius grows from 1 to 1.65. The large arm demonstrates enemy scale; giant player transformations, timed shields/parries, ultimates, and class-specific movement are not implemented in this proof.
- **Performance:** a late-run production sample reported about 60 frames per second, 145 draw calls and 97,518 triangles. It is a short local observation, not a hardware benchmark or mobile claim. Vite reports a 533 KB minified shared Three.js chunk warning; the build succeeds.

Andrew's first playtest should answer one concrete question: does rolling out of a committed attack and returning for a powerful hit feel good enough to build the class and item systems around? The historical play guide (`FIRST-BUILD-PLAYGUIDE.md`) and team record (`FIRST-BUILD-SWARM.md`) live in git history.
