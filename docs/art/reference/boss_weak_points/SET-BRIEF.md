# Crew-built boss weak points

Written before image generation. Scope: U4-DESIGN.md only. These sheets propose appearance for Andrew's review. They do not approve implementation, dimensions, collision, timing changes or new attacks.

## Purpose

What: one shared maintenance-part family for the Waking and the Mind, with an ensemble mood board, two boss reference sheets and one chase-view readability sheet.

Why: a reel impact must land on an exposed working part. A successful break leaves a hole and removes the attack tied to that part. The former maintenance job explains the opening and the repair crew's response. Sources: U4-DESIGN.md:5-13,17-40; DECISIONS.md:167,183,248.

Why it should work: a closed cover, an exposed patterned green seat and an unlit torn cavity differ in shape and value as well as colour. The pilot ball supplies a consistent visual comparison. Open green stays inside a charcoal recess; attack warnings retain orange-red stripes. Large bevels and broad wear match the accepted style boards.

Checked: U4 first; Bible world, culture, character and art passages; DECISIONS sections 6-10 and later retained colour ruling; VISUAL-LANGUAGE palette, redundancy, faction and readability rules; all ART-MISTAKES entries 11-18; research result sections; existing boss and hierarchy boards; asset registry and existing boss model files; design-v3/wardens/mind.md. The latter explicitly excludes the arena boss and supplies no new mechanics here. Existing board questions are superseded only where U4 answers them. No project files are changed.

## Source paths

All project-relative citations below resolve under `/home/andrew/Projects/scrapkeep/.claude/worktrees/focused-curie-deb115/`.

- `BIBLE.md:42-59,74-81,107-139,622-645,661-689,697-711,729-735`: physical cause, lived-in work, materials, palette, chase framing and readable effects.
- `project-guide/handoff/DECISIONS.md:167,179-183,199,207-209,243-248,274-275`: reel, bosses, light, finish, purpose, references, utility fleet and green ancient light.
- `sketches/core-loop/VISUAL-LANGUAGE.md:31-51,62-83,425-440,446-481`: material eras, palette roles, patterned seams and readable enemy families. The old Cherenkov-blue wording at 479-481 is superseded by line 50 and DECISIONS:274.
- `docs/art/reference/bosses/README.md:21-27,37-59`: access parts and existing boss identities. The cuff placement at 43 is a prior proposal, superseded by U4's hand lens.
- `docs/art/reference/hierarchy/README.md:5-11`: pilot comparison and giant utility-machine hierarchy.
- `/home/andrew/scratch/w18/comps-reviews.json:40-64,121-126`: visible part loss, mechanical openings and camera framing. Research suggestions are not additional gameplay approval.
- `/home/andrew/scratch/w18/purpose-pass.json:11-41`: readable tells and actual spatial weak points.
- `sketches/core-loop/assets/registry.d/boss_waking_base.json:4-11`, `boss_mind_base.json:4-11`, `enemy_swarm_remnant.json:4-12`: current asset identities and recipe provenance.

## Members and ownership

| Member | Job and silhouette | Shut / open / broken | Art lane |
| --- | --- | --- | --- |
| Floor-body service hatch | One recessed, broad bevelled access hatch on each Spoil, Seam and Bedrock rim face above the bank. Retain the Waking's nested collars. | Flush cover / cover clear, exposed seat and green notches / torn rim with missing internal linkage and dark cavity. Break removes that floor's burrow, cave-in or bore family. | Modeling |
| Seam plate | Replaceable plate sized to the hatch seat. Two identical fitters carry one plate by opposite edges. No Fleet crest. | Fitted over hatch / lifted clear while fitting / fallen or fractured beside the permanent hole. Plate is not an extra weak point. | Modeling; Animation fits and drops it |
| Bore-head override button | Recessed crew-stop plunger on the bore head in the pit, with a protective cover. | Covered / exposed button and patterned green rim / button and coupling missing, dark socket. Break ends the pit's three-lane spray. Its read gate is not specified by U4; do not invent one. | Modeling |
| Three choir lens seats | Three discrete circular lens seats behind the Mind's sweeping plates. Preserve the foreman's numbered-hand identity. | Plate masks seat / sweep clears its own seat / lens missing and rim damaged. First seat break removes split_lane; second removes rush. Third-break consequence is unspecified. | Modeling |
| Hand override button | The existing mind_hand tracking lens, framed as a crew-stop control. It is not an additional cuff button. | Lens plated over / brace clears cover and exposes lens / missing lens and severed coupling, disabled hand slack. | Modeling |
| Broken hole | A persistent missing component within each original frame, with recognisable failed couplings. | Not an independent state machine: it is the broken appearance of the parts above. No surviving bright target in the cavity. | Modeling supplies cavity; Effects supplies brief break burst |
| Fitting drone | Existing swarm_remnant, identical flat triangular cast bodies with notch-patterned ancient seams. Two carry the plate. | Waiting near shut hatch / fitting at open hatch / knocked off and plate falling. These are action poses, not invented drone weak-point states. | Animation, reusing existing drone model |

## Shared rules

Palette: sandstone `#c6a274` for rock and grit; oxide `#9b513a` for wear; petrol `#365754` for enamel; charcoal `#242a28` for cavities and separating grooves; bone `#d2c5a5` for rubbed surfaces and labels. Ancient `#9dff3c` only for patterned machine light. Mint `#8bf0d3` stays on the pilot field. Copper `#b77843` stays on pilot coils. Hazard `#ff5a3c` stripes indicate actual attack danger, never open weak points. Brass `#d9b44a` is Fleet ownership and is absent from these ancient maintenance parts. Palette strips may explain unused roles without applying them to parts. No new hue roles.

Form and wear: the four accepted style boards control the painterly stylised 3D finish, smooth chunky forms, rounded bevels, broad chipped paint and clean edges. Ancient host bodies and triangular drones stay cast and geometric. Distinct service covers may use the unbranded repair hardware established in the access reference. Do not spread bolts, pipes and workshop detail over the entire ancient body. Rub the contact edge, collect grit on ledges, and show grease only at working joints.

Scale: the pilot remains the expanding Hoberman lattice around a stabilised cockpit. Every contextual panel includes the same pilot ball. The giant-machine hierarchy and existing Waking and Mind boards supply qualitative scale only. Exact weak-point diameter, drone span, fight distance, anchor offset and camera field of view are not settled in U4. All drawn ratios are composition proposals, not metre measurements or hitbox specifications. Modeling must measure the existing boss sockets and pilot before production.

States: SHUT has an intact occluding cover and only thin ordinary body seams. OPEN has a physically unobstructed contact surface, a charcoal border and brighter uranium-green notches concentrated at the seat. BROKEN has missing hardware, a discontinuous rim and a dark hole, with target light extinguished. Avoid a glowing intact lens inside a broken socket. A fallen plate must read as inert damage, not a reward.

Effects: open glow and break burst belong to Effects. Keep green bloom local enough to retain notch edges. The bore-jam puff is sandstone grit displaced beside the opening, never a smoke screen. Break debris reveals the missing mechanism and settles away from the approach. Mint, when shown, comes from Sable's reel contact, not the boss. U4's state/event record drives both light and sound. No new audio design is prescribed.

Animation: the bore jam is 3 s; lip drop within 1.5 s also opens the hatch below. At least two fitters working for the proposed 3.5 s seal it. One wave per opening, at most three waves per floor, three drones per wave and at most six live crew. Show two carrying without implying the whole wave is two. Fitters do not dive. Reel contact knocks a fitter off and drops its plate. Mind sweep warning is 1.8 s, its opening 2.5 s, adaptation cycle 8 s, hand brace 5 s. These values are inherited from U4:19-35, not tuned by art.

Place: Waking views inherit the excavation's warm daylight and cool cavern fill, with work platforms following rock and collars. Mind views inherit dusk from the lighting anchor, with suspended maintenance access at the edge of the scene. Maintenance traces are contextual proposals. Keep them out of approach lines and telegraphs; do not add ambient characters, loot or combatants.

## Planned sheets and checks before generation

1. `boss_weak_points-maintenance-moodboard.png`: nine panels, three columns SHUT / OPEN / BROKEN. Rows combine Waking hatch, seam plate and fitters; bore override; Mind choir seats and hand lens. All members belong to the same family. Check visible holes, three seats, triangular fitters and no extra targets.
2. `boss_weak_points-waking-reference.png`: six-panel reference. Establish the rim-face hatch above the bank; show shut, bore-jam opening with grit, two drones carrying one plate, broken hatch and bore override state strip. Check collar identity and unobscured approach.
3. `boss_weak_points-mind-reference.png`: six panels. Top row shows choir seats shut, open after sweep and broken; bottom row shows hand lens shut, open during brace and broken with slack hand. Check that the button is the lens, three seats exist and the third seat's attack consequence is not invented.
4. `boss_weak_points-readability-reference.png`: six chase-camera panels: three Waking floor hatches, bore override, choir seats and hand lens. Each has the pilot ball and exposed green target against the boss. The choir view shows one active opening and the other two plated seats. Check target/anchor visibility, dark framing and no hazard colouring on openings. This is concept readability, not engine validation.

Every sheet gets a charcoal grid, bone labels, palette strip and a concept-only footer. Compare every output against all four accepted anchors before saving it as final. Record style and content findings in BOARDS.md.

## Open details for Andrew

- Exact contact-part size and camera framing await runtime measurement. Proposed drawings do not settle these.
- U4 does not name the bore override's opening tell or the third choir seat's removed attack. Keep both unspecified.
- Service-cover construction and the hand lens's crew-control framing remain visual proposals within U4's approved member list.
