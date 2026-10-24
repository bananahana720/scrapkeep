# Rogue body reference sheets: prompts

Andrew asked on 23 Oct for multi-angle reference images before any rogue body is modelled, so the modeller works to exact views instead of one concept painting. Each rogue gets two sheets, drawn by Codex `gpt-6-astra` (the board image engine) with the approved boards as references:

- `<kind>/<kind>-turnaround.png`: front, left side, back, three-quarter and top views at one scale, with metre callouts.
- `<kind>/<kind>-details.png`: close-ups of the governor, the cut command line, the service hatch closed and open (core showing), and an exploded view of the moving parts labelled with their bone names.

References passed to every run: `docs/art/reference/hierarchy/hierarchy-rogues-moodboard.jpg`, `docs/art/reference/hierarchy/hierarchy-rogue-sky-cable-tender-reference.jpg`, and the four style masters (palette, shape, materials, lighting) in `~/scratch/w18/boards/style/`. Sources for every spec below: `sketches/core-loop/design-v3/rogues/BRIEFS.md` (branch `claude/project-thread-vsimkq`), DECISIONS "The Mind's reach", principles 7, 12 and 15, and ART-MISTAKES (machines in petrol enamel with copper or brass fittings, 22 Oct #251).

## Shared preamble (every run)

You are drawing model reference sheets for Scrapkeep, a 3D action roguelite. A 3D modeller will build the machine from these sheets, so accuracy and consistency between views matter more than drama.

Canon to follow:
- These are rogue utility machines: freed, not corrupted. The Mind's command line to the machine is cut (a cut cable end in oxide red with frayed copper strands), and a local brass flyball governor (a vertical spindle with two weighted balls on hinged arms) still runs its old job on a loop. No purple anywhere, no glowing eyes, no evil face. It is a worker doing its shift with nobody left to tell it to stop.
- All hands: the crew number is stencilled large in bone #d2c5a5 on the body, and a small rectangular HIRED stamp sits near it.
- Look: soft-toy proportions (chunky, slightly oversized, friendly), but a machine: crisp bevelled edges, a bold silhouette, one smooth cast shell for the main body with panel lines and bolts on it, never a body built from stacked spheres or primitives. Separate small parts only for the moving pieces named below.
- Palette, exact hexes: petrol #365754 enamel, oxide #9b513a, sandstone #c6a274 wear, charcoal #242a28, brass #d9b44a, copper #b77843, bone #d2c5a5, amber #e5a044, frost #c8f0ff, mint #8bf0d3 (only the weak-point core when open).
- The weak point is a service hatch: two armour plates swing open outward and a round core shows behind them. Draw the plates in slate grey-blue #6f7f8f.
- Scale: put a 1.84 m diameter pilot ball (a Hoberman-lattice gyrosphere) beside the machine in the turnaround for scale.
- Sheet style: clean model sheet on a flat light grey background, even studio light, no scenery, no perspective distortion in the orthographic views (front, side, back, top), thin dimension lines with metre labels, view names as small captions. Original design only; imitate no living artist or studio.

Make two images, saved as PNG in the current directory with the exact names given below.

## Gate Crane No. 14 (Spillway: dam and flume), `gate_crane`

Spec:
- Old job: a gantry crane that lifts the dam's gate leaves for service. It still lifts and drops a leaf and swings its hook block. Why it is free: the command line was cut at the cab; the governor on top of the mast keeps the lift cycle going.
- Silhouette: a tall L from 100 m. A four-legged bogie base on short rails (base 3.8 m square), one tall mast (6.5 m), a long jib pointing forward (7 m), a hook block (1.4 m) hanging on a cable under the jib tip, holding a flat steel gate leaf, and a counterweight drum at the back. A small operator cab at the mast foot with the cut command line hanging from it.
- Moving parts: CraneJib (the jib swings left and right about the mast), CraneHook (hook block on its cable), CraneLeaf (the gate leaf it drops), CraneGovernor (brass flyball on top of the mast), CranePlateLeft and CranePlateRight (the two hatch plates on the counterweight drum).
- Hatch: the service hatch is on the back of the counterweight drum.
- Colour: petrol body with sandstone wear, brass rails and fittings, stencil "14" large on the mast in bone, HIRED stamp on the cab.
- Front is the side the jib points to.

Images:
1. `gate_crane-turnaround.png`: front, left side, back, three-quarter (front-left, from slightly above) and top views, plus the scale ball. Label overall height, base width, mast height and jib reach.
2. `gate_crane-details.png`: close-up of the governor on the mast top; close-up of the cut command line at the cab; the counterweight hatch closed, then open with the mint core showing; and an exploded view separating the body shell from the jib, hook, leaf, governor and the two plates, each labelled with its part name.

## Haul Skip No. 31 (the Dig: pit and sinkhole), `haul_skip`

Spec:
- Old job: an ore skip that hauls tailings from the face to the dump and tips them, out and back on its route, forever. Why it is free: its route receiver was crushed in a slump (draw it dented and crumpled, with the cut command line hanging from it); the analog governor on the hoist runs the out-and-back.
- Silhouette: low and wide, a bathtub that charges. A deep, wide bucket (4.4 m wide, 5 m long) on four flanged rail wheels, a hoist frame arching over the bucket (4.8 m tall to the frame top), and a tip ram underneath.
- Moving parts: SkipBucket (tips forward about a front axle), SkipWheel0 to SkipWheel3, SkipGovernor (brass flyball on the hoist frame), SkipPlateLeft and SkipPlateRight (the two hatch plates at the back).
- Hatch: the hoist hook ring at the back; it shows when the bucket stays tipped.
- Colour: oxide #9b513a bucket with sandstone wear, charcoal wheels and chassis, amber #e5a044 lamps (the Dig's colour), stencil "31" large on the bucket side in bone, HIRED stamp on the chassis.
- Front is the direction it hauls (the tipping end).

Images:
1. `haul_skip-turnaround.png`: front, left side, back, three-quarter (front-left, slightly above) and top views, plus the scale ball. Label width, length and height.
2. `haul_skip-details.png`: close-up of the governor on the hoist frame; close-up of the crushed route receiver with the cut command line; the back hatch closed, then open with the mint core showing; the bucket tipped; and an exploded view separating the body shell from the bucket, four wheels, governor and the two plates, each labelled.

## Cable Tender No. 7 (the Highdraft: islands and crown), `cable_tender`

Spec:
- Old job: it keeps the cableways' tension (from the approved Sky cable tender board). Here it is a single-spool tender sized to an island shelf, not the colossal span on that board. Why it is free: the command line is cut and the local governor holds tension, as on the board.
- Silhouette: a big horizontal cable spool (3.7 m across) on two A-frame legs (6 m tall overall), with a boom forward (5 m) carrying a mooring harpoon at its tip. Loose cable ends hang off the spool.
- Moving parts: TenderSpool (spins about its horizontal axle), TenderBoom (aims), TenderHarpoon (fires from the boom tip), TenderGovernor (brass flyball beside the spool, as on the board), TenderPlateLeft and TenderPlateRight (the two hatch plates on the spool's service hatch).
- Hatch: the spool's service hatch: tension, reset, reel impact, as on the board.
- Colour: petrol and copper as on the board, brass governor, frost-blue #c8f0ff sheen on the cable, stencil "07" large on an A-frame leg in bone, HIRED stamp on the base.
- Front is the side the boom points to.

Images:
1. `cable_tender-turnaround.png`: front, left side, back, three-quarter (front-left, slightly above) and top views, plus the scale ball. Label height, spool diameter and boom length.
2. `cable_tender-details.png`: close-up of the governor; close-up of the cut command line; the spool hatch closed, then open with the mint core showing; and an exploded view separating the body shell (A-frames and base) from the spool, boom, harpoon, governor and the two plates, each labelled.
