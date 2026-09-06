# Scrapkeep Bible: cohesion report

**Review edition · 6 September 2026.**

**PASS+NOTES.** Nine section workers delivered all nine manuscripts and 25 concept images. An independent reviewer inspected every initial image, all four automatic corrections, Andrew's separate binary-tree revision and the nine sections. All requested corrections passed. No persistent actionable image outlier or material cross-section contradiction remains within the reviewed scope.

The [Bible](BIBLE.md) remains the shared reference. The [decisions list](BIBLE_DECISIONS.md) holds unselected character directions, proposed fiction and unresolved content details. The evidence below is concept-image inspection and document/source review. No game build, gameplay test, audio audition or controller test accompanies this edition.

## Method and coverage

All nine section workers used `gpt-6-astra` with high reasoning effort in separate detached worktrees. The coordinator supplied the common inventory and pillars, admitted outputs serially, reconciled names and owned the final document. A fresh `gpt-6-astra` reviewer independently compared actual images against the approved Art Direction and text against the three pillars and accepted planning rules. All nine sections delivered; there were no missing worker results.

The image pass applied scene-relevant rules: a landscape, cutaway or character sheet can use its appropriate view; gameplay mockups must preserve visible action and readable instrumentation. The three explicitly labeled DON'T panels intentionally violate only their named lesson. Concept detail was not treated as a chosen roster, working geometry or final manufactured dimension.

Every prompt contains the approved Art Direction verbatim. Its SHA-256 remains `0f694b904454716669d844e833973852c51a6ec48c719918797b06a7841322c7`. The Bible's Appendix A retains 30 complete submitted prompts: 25 originals, four automatic corrections, and one explicit owner revision of U02. Andrew requested that final revision after seeing the fan-out diagram; it is recorded separately from the single automatic correction allowance.

## Corrections and owner revision

| Image | Observed issue and rule | Action and selected result |
| --- | --- | --- |
| M04 | AD-01: pilot visibly exposed on top of the rolling body. | One correction enclosed the pilot in framed glass while preserving the mountain composition. [M04 v2](docs/bible/images/M04-v2.png) passed reinspection. |
| C03 | AD-08 and the character deliverable: the middle design lacked its B label. | One correction restored clear A/B/C labels. [C03 v2](docs/bible/images/C03-v2.png) passed reinspection. |
| U01 | AD-01/08 and systems: two revival sockets implied extra allowance; the companion read as an organic fox; a tread-heavy chassis weakened rolling accumulation. | One correction supplies a single AVAILABLE revival lamp, an assembled mechanical companion and an irregular rolling scrap body. [U01 v2](docs/bible/images/U01-v2.png) passed reinspection. |
| U02, automatic correction | AD-08 and systems: the tree had six terminal nodes instead of eight. | One correction supplied eight terminals and one selected route. [U02 v2](docs/bible/images/U02-v2.png) passed the earlier brief, then was superseded by Andrew's explicit topology instruction. |
| U02, owner revision | Andrew specified recursive forks: every node offers two upgrades, and each forks again. | [U02 v3](docs/bible/images/U02-v3.png) shows 1 root → 2 → 4 → 8, with one connected lineage selected. Coordinator and independent reviewer each counted 15 nodes, 14 edges and eight leaves, with two children per nonterminal. The revision passed reinspection. |

The [owner revision record](docs/bible/production/owner-revisions.json) preserves Andrew's instruction and the aligned documents. No original image or submitted prompt was overwritten.

## Every image reviewed

Links open the selected image. Initial FAIL verdicts indicate errors found and corrected, not the current acceptance of the displayed version.

| Image | Initial verdict | Observation against Art Direction | Selected-image status |
| --- | --- | --- | --- |
| [P01](docs/bible/images/P01-v1.png) | PASS+NOTES | AD-01/03/05/06: protected irregular mech, magnetic intake, inhabited canyon and natural scale. Key-art viewpoint is appropriate; fabrication is clearer in E02/W03. | PASS+NOTES |
| [W01](docs/bible/images/W01-v1.png) | PASS | AD-03/06/09: cool mountains, forest and exposed ridges dominate the small metalworking terraces. | PASS |
| [W02](docs/bible/images/W02-v1.png) | PASS | AD-04/05/06/09: shaded repair settlement, cactus foothills, work wear and a magnetic handler. | PASS |
| [W03](docs/bible/images/W03-v1.png) | PASS | AD-04/05: internal machinery, collector path and pump maintenance share coherent workshop light. | PASS |
| [W04](docs/bible/images/W04-v1.png) | PASS | AD-04/05/09: repaired metal, copper winding, shaped grease and small comforts communicate continuing work. | PASS |
| [M00](docs/bible/images/M00-v1.png) | PASS+NOTES | AD-06/08: five named terrain samples, four-world context and no fixed route. Pale Basin relief is harder than its intended dune identity. | PASS+NOTES |
| [M01](docs/bible/images/M01-v1.png) | PASS+NOTES | AD-01/05/06: protected cockpit, patched rounded body and Sonoran wash settlement. Tread forms leave rolling articulation unresolved. | PASS+NOTES |
| [M02](docs/bible/images/M02-v1.png) | PASS | AD-03/06: green river corridor, sandstone walls and suspended service paths. | PASS |
| [M03](docs/bible/images/M03-v1.png) | PASS | AD-01/05/06: collector, cultivated valley, greenhouse and supported pruning machinery. | PASS |
| [M04](docs/bible/images/M04-v2.png) | FAIL | AD-01: original exposed pilot corrected with an integrated framed cockpit. | Corrected / PASS |
| [M05](docs/bible/images/M05-v1.png) | PASS+NOTES | AD-05/06: pale dry dunes, sparse marginal plants, wind maintenance and intake stream. Caption clarifies mineral sand and still-image locomotion limits. | PASS+NOTES |
| [C01](docs/bible/images/C01-v1.png) | PASS | AD-01/05/07/08: three labeled winch/anchor constructions, consistent fox identity, cockpit and fabrication. | PASS |
| [C02](docs/bible/images/C02-v1.png) | PASS | AD-01/05/07/08: labeled fans, hoop and ducts distinguish three light bird constructions. | PASS |
| [C03](docs/bible/images/C03-v2.png) | FAIL | AD-08: missing B corrected; tiger identity, distinct claws, cockpits and fabrication retained. | Corrected / PASS |
| [C04](docs/bible/images/C04-v1.png) | PASS | AD-01/05/07/08: labeled pressure, switchboard and discharge constructions preserve squirrel identity. | PASS |
| [C05](docs/bible/images/C05-v1.png) | PASS | AD-01/05/07/08: rail, yoke and mirror alternatives distinguish controlled optics with consistent mole identity. | PASS |
| [E01](docs/bible/images/E01-v1.png) | PASS+NOTES | AD-04/08: both weapon/device rows share D references. Large tool size is conceptual; final mounted dimensions remain open. | PASS+NOTES |
| [E02](docs/bible/images/E02-v1.png) | PASS+NOTES | AD-05/08: internal recycling, all four upgrade roles and a common reference in the lower loot lineup. Caption identifies the independently enlarged cutaway. | PASS+NOTES |
| [U01](docs/bible/images/U01-v2.png) | FAIL | AD-01/08: corrected single revival, mechanical companion and irregular rolling body preserve four slots, cockpit, threat and escape. | Corrected / PASS |
| [U02](docs/bible/images/U02-v3.png) | FAIL | AD-08: original six endpoints corrected; owner then specified recursive binary topology. | Owner revision / PASS |
| [A01](docs/bible/images/A01-v1.png) | PASS | AD-04 teaching pair: shaped wear versus indiscriminate grime; labels clearly distinguish the lesson. | PASS |
| [A02](docs/bible/images/A02-v1.png) | PASS | AD-06 teaching pair: coherent forested mountains versus misplaced cactus in the same view. | PASS |
| [A03](docs/bible/images/A03-v1.png) | PASS+NOTES | AD-08/11 teaching pair: readable cutter, danger and escape versus effects obscuring the attack. Minor card cropping in the negative panel does not prevent the lesson. | PASS+NOTES |
| [F01](docs/bible/images/F01-v1.png) | PASS | AD-04/05/08: four labeled action/sound phases, physical sources, collection and construction. | PASS |
| [G01](docs/bible/images/G01-v1.png) | PASS+NOTES | AD-07/08: ten clear identity keys; separate rows avoid assigning home regions or A/B/C choices. Fur and glass detail remain illustrative. | PASS+NOTES |

## Nine-section cohesion

All three pillars were applied: Joyful physical mastery; Scrap becomes your build; A world worth crossing.

| Section / worker slice | Result | Evidence and implications |
| --- | --- | --- |
| [1. Pillars & Fantasy](BIBLE.md#1-pillars--fantasy) | PASS | Practical tests cover baseline movement, readable danger, visible fabrication and distinct places. Four-world runs, rebuilt power, four slots and one companion agree with the rest. |
| [2. World & Lore](BIBLE.md#2-world--lore) | PASS | Local work grounds travel and collection. Cultures match character construction without determining species personalities. Fleet history and finale remain proposals. |
| [3. Maps & Areas](BIBLE.md#3-maps--areas) | PASS+NOTES | Five candidates remain distinct from a four-world run. Landforms, occupation, encounters and discoveries agree. The complete Grand Pruner proposal is separated from the implemented arm. |
| [4. Characters](BIBLE.md#4-characters) | PASS | Five candidates have consistent names, cultures, personalities, arcs and four-slot sketches. A/B/C choices remain unselected; Fuse retains occasional real harmful or inconvenient miscasts. |
| [5. Weapons & Items](BIBLE.md#5-weapons--items) | PASS+NOTES | Tools agree with character roles. Fabrication does not invent prices or replace milestones. Loot, fixed recipes and permanent options remain distinct. Scale captions record the actual drawing limits. |
| [6. Core Systems](BIBLE.md#6-core-systems) | PASS after owner-text alignment | Rules preserve active movement, shared attack geometry, milestone access, respec versus equipment swaps, one companion, single revival, completed-level resume and rebuilt combat power. Binary forks now match Andrew's clarified direction. |
| [7. Art Direction](BIBLE.md#7-art-direction) | PASS | Approved text remains byte-identical; expansion supplies material, landscape, silhouette, fabrication and readability guidance with explicitly labeled teaching exceptions. |
| [8. Audio & Feel](BIBLE.md#8-audio--feel) | PASS | Regional and class cues match the catalogue. Collection and fabrication sound different; recovery preserves movement; spectacle respects danger cues. Proposed music and mix are not auditioned assets. |
| [9. Glossary](BIBLE.md#9-glossary) | PASS after owner-text alignment | Canonical names and aliases agree across sections; candidate, prototype and reference terms remain distinct. The endpoint definition includes binary forks. |

## Contradictions, persistent outliers and limits

The independent manuscript review found no other material contradiction or accidental approval within the nine-section inventory and named planning sources. Caption cleanup removed warnings about corrected images. Older clean miniature and matte-only assumptions are explicitly historical; the project desk and design references direct future agents to the Bible. Andrew's binary-tree clarification is synchronized with the publisher discovery, runtime blueprint, requirements, D50 and the decision trail.

No persistent actionable violation remained after the four automatic corrections or the separate owner-directed U02 revision. The bronze root outline in U02 is a minor styling detail; its selected outgoing connection and full lineage remain clear.

Retained concept limitations are visible and recorded:

- M00 exaggerates hard white basin relief. M05 and the region text establish dry sculpted dunes.
- M01/M05/E02 contain pronounced tread/support forms. Still images do not resolve rolling articulation, manufacturing dimensions or route clearance.
- E01 uses a shared relative D reference for large modules. E02 enlarges its cutaway independently and uses one common D reference within the lower lineup. These are conceptual size comparisons.
- Fine fur/glass/material detail, approximate chassis continuity in sequence art and negative-panel card cropping remain illustration limits. None establishes a production model or motion solution.

Character direction picks, animal-roster scope, the proposed region catalogue and fiction still belong to Andrew. Final effects, costs, recipes, milestone allocation, respec policy, device/companion assembly, miscast tuning and interrupted-level behavior remain scoped design gaps in the [decisions list](BIBLE_DECISIONS.md). Binary tree topology is settled and has been removed from those gaps.

## Document verification and scope

The document check verifies nine ordered sections, 25 selected inline images, all 30 complete prompts, the exact approved block, actual PNG chunk checksums/decompression, file hashes and local link targets. The automatic-correction limit is enforced separately from the recorded owner revision. The selected files are indexed in the [asset manifest](docs/bible/production/assets.json).

The [independent review record](docs/bible/production/independent-review.md) preserves individual inspection findings. `npm run check:project` passed after the navigation and accepted-rule updates. A separate check found all 12 Bible navigation/source anchors valid. The game-source diff is empty for `src`, `public`, `tests`, `package.json` and `package-lock.json`. Prior workspace changes were preserved. No game build or runtime verification was run for this document-only edition.
