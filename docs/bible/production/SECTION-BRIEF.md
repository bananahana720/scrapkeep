# Bible production brief

**Owner clarification during image review, 6 September 2026:** upgrade trees use recursive binary forks: one root → two → four → eight endpoints, one connected lineage selected. This supersedes earlier uncertainty about tree shape. U02 attempt 3 is Andrew's explicit revision after the one automatic audit correction. The original worker procedure below records how the first edition was produced; the coordinator aligned the final Bible and accepted planning references with this clarification.

Andrew approved Step 0 revision 2 on 6 September 2026 with "proceed, looks great now". Produce the Art & Game Bible only. No game implementation, deployment, dependency changes, new tasks or persistent memory.

## Frozen direction

Read `docs/bible/ART-DIRECTION-LOCK.md` from the main workspace. Its exact bytes are mandatory in EVERY submitted image prompt, including edits and regeneration. SHA-256: `0f694b904454716669d844e833973852c51a6ec48c719918797b06a7841322c7`. Its historical phrase "proposed revision for this gate" remains verbatim because the user approved that exact block. The coordinator explains its now-approved status outside the lock.

The current working planning docs, not Git HEAD, supply source context. Latest publisher direction and the frozen block supersede the older clean miniature finish, old world catalogue and fixed animal/class assumptions. Use `BIBLE.md`, `docs/DISCOVERY.md`, `docs/CHARACTER-BIBLE.md`, `docs/WORLD-ENVIRONMENTS.md`, `docs/LEVEL-DESIGN.md`, `docs/RUNTIME-BLUEPRINT.md` and `docs/project/DECISION-REGISTER.md` as relevant.

## Shared design tests

The Pillars worker will explain these three coordinator formulations, derived from the accepted direction. Preserve these names and meanings so parallel sections use one design test.

1. **Joyful physical mastery.** Rolling, aim, jumps, rebounds, collisions and quick deployments keep the player active. Challenges show understandable threats and openings. A useful starting kit works before rare loot.
2. **Scrap becomes your build.** Electromagnetic collection grows the mech and feeds internal fabrication. The weapon and three skills evolve visibly. Items, devices and one main companion can combine into earned, sometimes overwhelming power.
3. **A world worth crossing.** Distinct Southwest landforms, inhabited places, engineering traditions and themed discoveries make the route matter. Natural scale and local work remain legible as battles escalate.

## Shared content inventory

These are creative candidates for THIS review edition, not a selected launch roster or world count. Do not invent additional proper names without telling the coordinator. Developed fiction is welcome inside these boundaries. Mark it as a creative proposal once per relevant subsection; don't interrupt every sentence with qualifiers.

Five named area pages form a comparison catalogue. Four worlds per run remains the accepted structure; no fixed start, order or finale is chosen. A world is a run-region here; the larger universe's astronomy remains unspecified.

| Area | Landscape and function | Adaptation status |
| --- | --- | --- |
| Yard Commons | Sonoran desert foothills, rocky washes, living cactus country, scrapyard settlement and field repairs | Existing candidate reinterpreted |
| Spillway Works | Sandstone canyon and green river valley, reclaimed pumps, suspended service paths and water infrastructure | Existing candidate reinterpreted |
| The Iron Orchard | Upland valley and cultivated foothills, orchard machines, irrigation, patched greenhouses and maintained routes | Existing encounter adapted; full region remains candidate |
| Foundry Crown | Forested mountain slopes opening to high rocky ridges, salvage furnaces, cableways and metalworking terraces | Existing candidate reinterpreted |
| Pale Basin | White gypsum-like dunes and exposed basin machinery, buried scrap, wind-driven maintenance and wide horizons | New creative candidate; use fictional geography |

Five highlighted playable-character candidates each receive ONE page and ONE sheet with three clearly labeled A/B/C directions. All remain enclosed pilots in irregular rolling salvage mechs; hover or claw expressions can alter silhouette without silently abandoning the protected cockpit or accumulation. Do not select A/B/C for the user.

| Name | Candidate identity | Class expression |
| --- | --- | --- |
| Sable | Fox from the Switchback Enclaves | Stealth and grapple traversal, compact winches and quiet mechanisms |
| Kest | Bird from the Highdraft Roosts | Light hovering mortar mech, open frames and lift hardware |
| Tarn | Tiger from the Redjaw Workshops | Articulated claw attacks and forceful close-range movement |
| Fuse | Squirrel itinerant apprentice | Directed chaos casting and a short automatic field; multiple elements and occasional genuinely harmful/inconvenient miscasts |
| Rivet | Mole machinist | Cyborg laser, alignment tools, cutting optics and controlled beam geometry |

Switchback Enclaves, Highdraft Roosts and Redjaw Workshops are candidate engineering cultures, not rigid species personality laws. Their relations can extend beyond the current area catalogue. Don't assign a mandatory home biome in one lane that other lanes must obey. Fuse and Rivet adapt earlier candidate work. Sable, Kest and Tarn are new proposals responding to the user's examples. Earlier Pip/Vane species-to-kit assignments are not silently inherited.

Use **Furnace Fleet** as a retained candidate antagonist organization, and **Admiral Brindle** as its proposed leader, with their prior machine-requisition conflict adapted to electromagnetic salvage. They are not approved final canon or a guaranteed final boss. **Moss** can be a supporting workshop keeper. These two supporting characters need concise roles, not extra highlighted A/B/C sheets. Do not add named lieutenants or companion characters this pass. Use generic role descriptors for additional populations.

Snipcart, Spreadleg and Grand Pruner remain identifiable orchard mechanism examples. Distinguish the implemented Pruner arm from a complete proposed Grand Pruner boss. Ground Loop, Echo, Shear Linkage, Brace Shoe and Shear Buddy can illustrate prototype or future adapted systems with their status stated. Avoid inventing named abilities/items; descriptive lowercase tool labels are enough.

## Systems that must agree

- Standalone PC/controller target, solo first. Browser prototypes are evidence, not the final platform/engine choice.
- Successful run: 60–75 minutes, four worlds, compact procedural encounter levels, a boss per world, two random next-world choices at transitions. Catalogue size, repeats, starting world, levels/world and final-boss placement stay open.
- Four slots: weapon, main hero skill, mobility, ultimate. Each character has eight endpoints per slot tree and follows one route per slot, no crosspathing. Start weapon plus special mobility. Ordinary movement always works. Main hero skill and ultimate unlock in world one through play milestones; normal successful play completes all paths by the final boss.
- Material recycling expresses construction of upgrades; do not invent prices, permanent-stat grinding, required mass sacrifice, external crafting stations, or a replacement time/collection threshold system. Costs and how supply meets milestones remain open.
- Special opportunities permit tree respec. Acquired equipment can be reconfigured between fights. Themed loot and fixed secret endpoint recipes alter builds. Do not supply fake final recipes or 160 unapproved endpoints.
- Low-cooldown abilities, class-earned ultimates, active aiming and quick autonomous deployments. One main loot-assembled companion can prime/buff/rescue; exact chassis rules remain open.
- One standard revival, then death ends a run. Save completed levels and resume at next entrance without duplicated rewards or revival. Permanent unlocks expand options; combat power is rebuilt each run. Mid-level interruption details remain open.
- Earned dominance is welcome. Readable attack geometry, player agency and coherent silhouettes still matter during spectacle. Prototype numbers and controls must be identified as prototype-specific.

## Output and image procedure

Each worker writes ONLY within its assigned detached worktree. Do not edit the live Bible or other workers' files. Worktrees have no checked-out source; read planning files from the main workspace. Coordinator admits output serially.

Write `section.md`, `assets.json`, `decisions.md`, and a `prompts/` directory. Your section begins with its exact `## N. Title` header. Use inline images with token paths `@@IMAGE_ID@@`; coordinator replaces them with final relative paths. Captions state image ID and whether it is a proposal, diagram, or mockup. Ensure text remains useful without reading tiny text inside images.

For every requested image, write a complete prompt file using the EXACT frozen Art Direction text followed by the asset-specific scene request. Verify the lock is a literal substring before submitting. Read the file into functions JavaScript via exec_command and submit that returned text to the built-in `image_gen__imagegen`. Don't paste a paraphrase. Use the imagegen skill, built-in mode only; no paid CLI/API fallback. Use one call per sheet or scene. Character A/B/C is one deliberately composed comparison sheet, not three unrelated file requests.

The tool can take minutes. Use the required first-line exec directive with a 120000 ms yield for generation calls; remain within the tool's supported interfaces. When it returns, use generatedImage(result) to display it, inspect the result, and copy the actual generated local output into your worktree's `images/`. If returned structure differs, inspect it and report actual paths; don't invent paths. Never use code to substitute a generated concept image. Do not edit images with Python.

`assets.json` is a JSON array. Each entry has `id`, `caption`, `prompt_path`, `image_path`, `generation_result_path` if saved, `references` array of actual input paths/roles, `status` and `self_review`. Use absolute paths. Save the complete tool result when practical. Don't claim precise dimensions or image quality without inspection. If generation fails, preserve prompt and report actual error. Do not count a blank placeholder as art.

Keep composition readable. For labels, request few large exact labels and repeat their meaning in prose captions. For concept scenes, avoid decorative UI. Cross-section scenes may use anonymous pilots, not a secretly selected character direction. Character comparisons should visibly differ in construction while retaining their shared role. Equipment uses a common starter-mech diameter reference, marked diagrammatic rather than measured engineering scale.

Do not regenerate after self-review merely for taste. A separate cohesion reviewer will decide which images need the user's one allowed regeneration. Flag visual problems in `self_review` for that review.

## Section asset allocation

| Section | Required assets |
| --- | --- |
| 1 Pillars & Fantasy | P01, one fantasy key image |
| 2 World & Lore | W01–W04, four distinct establishing shots: regional panorama, settlement, workplace, intimate mechanism/life detail |
| 3 Maps & Areas | M00, overview map, plus M01–M05, separate key art for each of the five named areas |
| 4 Characters | C01–C05, five A/B/C sheets in the highlighted character order above |
| 5 Weapons & Items | E01 weapon/device lineup and E02 loot/fabrication lineup, with consistent scale references |
| 6 Core Systems | U01 combat HUD mock frame and U02 dashboard/build-management mock frames |
| 7 Art Direction | A01 construction/grime do-don't pair, A02 regional-identity pair, A03 combat-readability pair |
| 8 Audio & Feel | F01 annotated audio/motion concept sheet |
| 9 Glossary | G01 illustrated name-to-identity reference sheet based on completed sections |

## Delivery standard

Write readable, specific prose. The Bible is a creative reference, not a compliance report. Give each section the detail the user requested. Explain meaningful choices and open details without filling gaps with invented approvals. Decisions file contains concrete choices for Andrew, source gaps and cross-section conflicts only. The coordinator owns final canon wording, file integration and the cohesion report. Source citations can be compact relative file links for planning docs; the coordinator normalizes them for the root Bible.
