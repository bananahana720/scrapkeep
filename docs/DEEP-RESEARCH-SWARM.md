# Deep research swarm record

5 September 2026. Team record for the five-lane deep-research pass Andrew requested after the design audit. The coordinator ran a scripted workflow: five research lanes, two adversarial critics per lane, one cross-lane coherence judge, and targeted revisions. 22 agents completed, none dropped. The run was interrupted once by a host restart and resumed from its cached journal; completed agents replayed from cache and only the unfinished tail ran live.

## Delivered documents

| Lane | Document | Model | Canon critic (opus) | Craft critic (sonnet) | Revised in run |
| --- | --- | --- | --- | --- | --- |
| Character | [Character bible](CHARACTER-BIBLE.md) | fable | PASS+NOTES | PASS+NOTES | Coherence fixes only |
| Enemy roster | [Campaign enemy roster](ENEMY-ROSTER.md) | fable | PASS+NOTES | PASS+NOTES | Coherence fixes only |
| World environments | [World and environment kits](WORLD-ENVIRONMENTS.md) | fable | PASS+NOTES | PASS+NOTES | Coherence fixes only |
| Level design | [Level design](LEVEL-DESIGN.md) | fable | FAIL, then fixed | PASS+NOTES | 13 blocking fixes applied and citations re-verified |
| Runtime | [Runtime blueprint](RUNTIME-BLUEPRINT.md) | fable | PASS+NOTES | PASS+NOTES | 4 coherence fixes applied |

The full critic findings, the nine cross-lane conflicts with their resolutions, and every lane's open questions are preserved in [review notes](research-2026-09-05/REVIEW-NOTES.md). After the run the coordinator applied the character bible's four citation corrections and one staging fix the canon critic had flagged as non-blocking.

## Cross-lane conflicts resolved

The coherence judge found nine conflicts; revisers resolved all of them under ownership precedence (enemies lane owns rosters and stats, world owns biome kits, levels owns spatial grammar, character owns cast canon, runtime owns feasibility and schemas). The notable ones:

- Sluiceback and Rowkeeper each had two competing specs; the enemy roster's versions won and the other documents now defer to them.
- The Furnace City miniboss Quartermaster collided with Moss's title; Moss is now the depot provisioner.
- The defense objective ring geometry is now one shared spec (radius 14 to 18 u, anchors on the ring, lane mouths 20 to 26 u out).
- The global one-windup stagger contradicted multi-lane defense waves; escalation is now per lane, and the per-lane windup gate is a named runtime work item with an acceptance test.
- The runtime envelope schema widened to carry branch-mouth sightings, declined field drops, and expedition-persistent stage effects, which three lanes write into.

## Evidence limits

Every document is a paper proposal pending Andrew's approval, and everything downstream of the Requisition premise, the campaign ladder, and the mass-as-currency model inherits that pending status from the audit. Implemented numbers cite `src/orchard/` files read in-session; all other numbers are tuning sketches. No runtime was executed, no image generated. Thirteen new enemy designs carry occupational groundings labeled inference and need one reference pass before their registry rows count as grounded.
