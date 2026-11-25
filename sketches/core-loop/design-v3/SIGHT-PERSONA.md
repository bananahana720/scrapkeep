# Sight persona: one hand, four makers

**Status: the year is picked. Andrew chose 2010 on 10 Nov 2026** (the joint look and sound card: "agreed wholly on this, approved"). Sections 1 to 4 are working calls from the thread "Develop visual artist and 3D models", written 9 Nov 2026; section 5 is the year and section 7 is the sight lane's own checking method (10 Nov). Nothing here changes a ruling.

This page owns the look persona: who draws the game, their habits, how one hand keeps the four makers apart, and how the sight lane checks its own models, clips and effects (section 7). It does not own story facts ([STORY-MAP.md](STORY-MAP.md) does), colour and shape rules ([VISUAL-LANGUAGE.md](../VISUAL-LANGUAGE.md)), per-pilot looks ([ROSTER-LOOK.md](ROSTER-LOOK.md)) or the finish recipe ([POLISH.md](../tools/blender/POLISH.md)). Where this page and one of those disagree, that page wins and this one is fixed. The sound persona is its sibling and shares the year, 2010.

The phone copy with sample sheets and the model audit is the project library page "Scrapkeep Sight Persona", listed under "Art and look" in the shared project files' INDEX.md (outside this repository).

## 1. The artist

Dot Marrow, born 1981 in Flagstaff, Arizona. A fictional person written for this project. She imitates no living artist or studio; a year anchors a look, never a named designer.

Her father Walt was a mechanic at the dam at Page and built enamelled training models of its gates and cranes. Her mother Ines ran a quilt and upholstery shop. Dot grew up between a machine shop and a fabric shop, which is why her machines have an edge you can run a thumb along and her people are stuffed. She opened a one-bench shop, Loose Tolerance, in a former pump-repair garage next door to the house band's rehearsal room, and she draws the band's sleeves and posters. In the game those are the title cards, boss name cards, item cards and the run-over page.

**Her creed:** if a hand made it, you can see how it comes apart. If the foreman made it, you cannot.

The sound persona's line for the same idea is "the grid is the machine's, the bend is ours".

## 2. Seven habits

They were written to hold in any of the three years considered, and they hold in 2010.

1. **Fasteners are the signature.** A keeper's thing shows at least one bolt, strap, stitch or weld on every part you could take off. The old works show none.
2. **People are stuffed, machines are built.** A body has no hard edge and its seams are stitching. A machine has crisp bevels and its seams are joints. No ordinary enemy is a person (ruling ch).
3. **A job before a face.** The outline is the tool for the job. The face comes second and small.
4. **Wear goes where a hand, a rope or water goes,** in broad shapes. Never an all-over grit.
5. **Three colours and one metal per object.** Glow only on the part that is working.
6. **One mark per piece.** A stamped plate, a brass tag, a cast crew number or a stencil, by maker (section 3).
7. **Something hand-sized on everything big:** a wheel, a rung, a lever, a glove. It is how a ball of radius 1.0 m reads as small.

## 3. One hand, four makers

The four makers are the [story map](STORY-MAP.md)'s (section 3). This table says only how Dot draws each so they can be told apart at a glance.

| Maker | How it is put together | Mark |
| --- | --- | --- |
| Keepers | Bolted, strapped, stitched. Mismatched plates, copper windings, wear at every grip. Nothing matches anything else. | A hand-stamped bone number plate |
| The Fleet | Standard issue laid over other people's machines: iron-oxide paint, charcoal bands, one bolted-on tool. Its people are stuffed animals in uniform, seen and never fought. | One brass tag, riveted on |
| The old works | Cast in one piece. No fastener anywhere. Where a join would be, a notched seam of ANCIENT light. Every unit matches its neighbour. Where the Mind has taken a thing over, the seams fill with one flat purple. | A cast crew number |
| Rogues | An old-works casting with one rough cut where the command line was, and a brass governor. | Its number stencilled large |

Five consequences:

- **An ordinary enemy carries two marks** (ruling ch). Underneath it is a sealed casting with a crew number and a HIRED stamp cast in. On top the Fleet laid oxide paint, riveted one brass tag and bolted on one tool. The tool is the only hand-fitted part, so it is the silhouette and where the eye goes.
- **What a hand made comes apart; what the foreman made can only break.** A boss's weak point is a crew-built service part ([DECISIONS.md](../../../project-guide/handoff/DECISIONS.md) section 6, 21 Oct): the only bolted, hand-sized, glove-worn part on the giant. A Warden is old works with no crew fitting, so its weak point is an exposed core where a cast shell has cracked away, with no bolt, weld or brass ([VISUAL-LANGUAGE.md](../VISUAL-LANGUAGE.md) section 9 owns that).
- **The china shop and the bulls** (ruling cj). The Foreman's works are tidy, level, evenly spaced and matched, and beautiful in a cold way. The keepers are the mess. Both are drawn with the same care, so that breaking the tidy line is the best picture in the game.
- **The Shift Boss is not the Foreman** (ruling ck, [DECISIONS.md](../../../project-guide/handoff/DECISIONS.md)). The common enemy that sounds a horn is the Shift Boss on every screen, so also on any label or plate drawn on a model. "The Foreman" always means the Mind. The model file keeps its old name, `enemy_foreman.glb`; nothing a player reads does.
- **The Foreman's signs are typeset; the crew's are written by hand** (working call; it extends the story map's [Foreman's voice](STORY-MAP.md#the-foremans-voice-w-from-andrews-idea-9-nov), which covers words, to how the words are set). An old-works sign reads as a cheerful announcement in one clean, even, aligned type, cast or enamelled, with nothing crossed out. A crew sign is chalk, paint or a stamped plate, a little off level. As there, the joke is the genre of talk, never a named real person or company; on a sign that also rules out a real logo.

### Words and numerals in the world (ruling ek)

Ruling ek ([DECISIONS.md](../../../project-guide/handoff/DECISIONS.md), 22 Nov 2026) puts hand-made route marks and place signs into the parks ([WAYFINDING.md](WAYFINDING.md)). Each maker writes differently, so a mark says who left it before it says anything else.

| Maker | Words | Numerals |
| --- | --- | --- |
| Keepers | Almost none. A chalk arrow, a chalk X, cloth bunting, one square flag. Shape comes before any word, and every mark is hand-made and a little crooked. Chalk is bone; cloth is sand or bone, tied with copper | Hand-stamped on a bone plate, or chalked |
| The Fleet | A rubber stamp on a brass tag | Ledger digits, punched into the tag |
| The old works | A place sign in one clean, even, aligned type, cast or enamelled. It uses the place names in [NAMES.md](NAMES.md) and no others | **Cast or typeset. Never stencilled** |
| Rogues | None | Their number, stencilled large. The stencil is the Rogues' alone |

Four rules:

- A district is named in the world only by an old-works sign. The HUD never prints a place name.
- No object in the world carries `PAID`. That stamp is Tally's and lands only where she stamps.
- No cloth, chalk or sign is mint. Mint means press now ([LEGIBILITY.md](LEGIBILITY.md) section 14.3).
- Uranium green is the old works' mechanism: a seam, the beam, the beads of a command cable. It is never mood light. Frost is ice blue, so it is never mistaken for a seam.

## 4. What she never does

- Hide a screw on keeper gear, or put one on the old works outside a service part or a bolted-on tool.
- Paint the Fleet in petrol, or anything but the Mind's takeover in purple.
- Use gears, pipes or glow as decoration with no job.
- Stack balls and leave the joins showing on a body.
- Make the ball bigger to show power. Heft is panels, caps and chunks ([ROSTER-LOOK.md](ROSTER-LOOK.md) owns the rule).
- Borrow a real brand, a franchise design, or East Asian dress for the genre's tropes (Bible AD-11 and DECISIONS.md section 3 own these).

## 5. The year: 2010

Andrew picked 2010 on 10 Nov 2026, on one card for look and sound: "2010, the festival years. Sax over a machine, big-room anthems. Look: today's game plus edge wear and real brass. Replaces nothing." The sound half lives with the sound persona.

**What 2010 is.** Hand-painted custom vinyl for machines, wool felt for crews, real copper and brass fittings. Satin, never glossy. Wear brushed on in bone at edges, ink left in seams like a comic line. The old works look like the sealed product design that followed the maker years: one-piece shells, soft square corners, a status light. Lettering is gig poster and record sleeve: thick ink, halftone, stamped numbers.

**What stays.** The palette, the silhouettes, the warm daylight and every ruling. The year changes finish, wear and lettering only.

**The guard.** A toy finish can drift clean, which Bible AD-11 forbids. The brushed wear is the guard, and habit 4 says where it goes. Working call: brushed bone wear belongs to what a hand made or repainted, so to keeper gear and Fleet paint, and a casting takes none. The Wardens' enamel already bakes with `edge=0` ([POLISH.md](../tools/blender/POLISH.md), for the enamel colour cap), which suits a casting.

**Where the game stood on the day** (PC stills at build 1c9bc643, RTX 4080; code at stage 31fae243). The mechanism belongs to [POLISH.md](../tools/blender/POLISH.md) and `src/presentation/bake_look.gd`; this is a dated reading of them.

- Keeper gear wears most. The `paint` slot draws a salvaged-plate map that carries its own wear, over the bake's vertex colours (`src/presentation/hero_assets.gd`). On the PC, Sable's ball has chipped bone on its hoop.
- Fleet machines carry the bake's shading but not its bright edge. Enemy and boss scripts put their own materials on the model, and `BakeLook.dress` gives those the bake's occlusion and crease darkening through a multiply layer. A multiply cannot brighten, so convex edges stop at neutral, and the body drops the world grain on purpose so a soft-toy body reads smooth. On the PC the Shift Boss and the lobber read as clean paint with soft shading.
- The rogues' hulls do carry the bake's edge: their kit makes `fleet_paint` a vertex-colour slot and the hull draws vertex colour. The bake lightens an edge by at most 18 percent in its own hue, so it reads as a soft highlight, not as bone. On the PC the rogue crane reads as clean paint.
- Brass is drawn three ways: vertex colour in `paint` (the tags), `requisition_tag` at half metal, and a brass material built in an enemy's own script. In the one still that shows horn bells, the Shift Boss at the dam at dawn, they read dark. The cause is not established.
- Nothing on screen is glossy, and the light at the rogue crane is warm daylight on sandstone, as the 2010 sample shows it.

**The years not picked.** 1996 (moulded toy plastic, chrome, stickers, hard flash) and 1978 (die-cast under chipped gloss enamel, flocked animals, one warm lamp). A separable extra, not approved: either could come back as a finish earned in play, as the sound persona keeps its other two periods as radio stations.

## 6. What changes in the pipeline for 2010

Proposals, not yet built. Each is its own small change.

1. **The maker becomes a setting.** A recipe names its maker once, and the shared kit supplies the allowed paints, the fastener style and the mark. A check fails Fleet paint in petrol, or a bolt on the old works outside a service part or a bolted-on tool.
2. **The finish lives in two places only:** the bake ([POLISH.md](../tools/blender/POLISH.md)) and the game's slot table, so a year is one switch.
3. **Fasteners and marks become kit parts:** strap, stitch seam, weld bead, number plate, brass tag, stencil, seam of light. The rogues' kit already has the stencil, the cut line and the governor.
4. **Reference sheets open with these habits and the year** in place of the generic style line.
5. **Every art change posts a before and after contact sheet.** Form is checked on cloud stills; the look is checked on the PC, in the game's renderer.
6. **Fleet paint gets the bright edge.** `BakeLook` already carries the bake's shading to every enemy and boss material. It also lifts convex edges toward bone, on Fleet paint and not on a casting.
7. **One brass.** Brass parts share one slot and one satin recipe, judged on the PC at dawn and in daylight.

## 7. How a model, clip or effect gets checked

Andrew asked on 10 Nov 2026 for a fresh look at how sight is verified. This section is the sight thread's working method, like sections 1 to 4: it binds this lane's own work and is not a gate rule for other lanes. The existing checks hold numbers: budgets, names, sizes, loop seams, whether a warning clip fits its warning time, particle ceilings. No test found judges a drawn frame of an enemy, a clip or an effect, and none asks whether someone who has never seen the game can tell what a thing is. A model can pass all of them and still not read. So a new or changed model, clip or effect takes five steps, cheapest first.

1. **Numbers.** The existing tests, plus the mesh and clip fault scan: `python3 tools/model_audit.py faults <glb>...` (flipped, doubled and empty faces, skin weights, one-frame snaps in clips).
2. **A picture at play size, beside its neighbours.** `python3 tools/model_audit.py outlines <glb>... --out=<dir>` draws each model as a black outline at 32 pixels a metre (a 1080p frame from 30 m) and scores every pair's overlap. A close-up alone does not count.
3. **A blind read, by at least three readers.** Give the lettered sheet from step 2, and nothing else, to fresh reviewers that have not seen the game, and ask what each thing is and does. Report the answers as a count. If most cannot name the job, the outline is not doing the work. One reader is noise: the first run's single reader named a different leader from four of the five that followed. The same read works on an effect's frames.
4. **Frames over time,** for clips and effects, on the ground they play on. One still is not a check. A snap the scan flags is a candidate: look for keys one frame apart in the pilot's pose table (`src/presentation/clips/<pilot>.json`) and draw the frames ([anim_clip_capture.gd](../tools/anim_clip_capture.gd)) before calling it a fault, because a step written on purpose looks the same to a number.
5. **The PC for the look, Andrew's hands for the feel.** Nothing above stands in for either.

Three tools take steps 3 to 5 into the running game (10 Nov):

- **A danger mark, read from inside it.** [danger_read_capture.gd](../tools/danger_read_capture.gd) stands the ball inside and outside the silt boil ring, a real lobber's landing ring, Brindle's own slag ring and his own charge lane, and inside the yard lock's wall, on the park maps with the play camera and the HUD, and takes the inside still twice: as drawn, and with the HUD's danger mark hidden. The boil ring and the yard wall are staged; the rest are the game's own attacks. Each still carries the game's own word on whether the ball is in the warning and a list of every warning on screen, and the tool fails a still the game contradicts (on its second run in the cloud the ball was still on its opening drop, and every "inside" still was outside). The stills go to blind readers as step 3.
- **An effect that can be seen.** [fx_capture.gd](../tools/fx_capture.gd) writes `drawn_px` and `contrast` for every still: how much of the picture the effect changed against the empty stage, and by how much. An effect nobody could see reads a handful.
- **A body at play speed.** [sight_reel.gd](../tools/sight_reel.gd) plays the panel pickup's pop and then fourteen Spillway kinds, one at a time (arrives, works on the ball, takes a hit, stands stunned if it is a kind that can be, dies), and films it with Godot's movie writer. The same run counts snaps from the game with the scan's rule, part against body, every frame, through the death clip; a part that jumps and jumps back counts too. A snap on the frame a clip starts is a cut, which the wind-up, attack, hit and death make by design, and is listed apart. The pass line is no snap inside a clip. In a cloud run outside the repository, a planted 30 degree jump on the chaser's fin was counted, and without it the chaser counted none. The Warden, Brindle and the pilots are not in the reel.

**A taste call** (Andrew, 10 Nov: the 2010 roaming tune's pick is the bar everywhere) takes four things: several real candidates, a pass line in numbers written down before choosing, a check in the running game on the PC, and one page where Andrew can judge the result and overturn it. The first is the pickup pop's size. The lines: letters no taller than the player's ordinary hit word (7.5 percent of the view's height), no smaller than 2.5 percent (27 pixels at 1080p, for a line that lasts 1.2 seconds), the longest and shortest line within 1.5 times of each other, no line wider than nine tenths of the view's height (0.51 of a 16:9 view's width), and all of it the same on an ultrawide screen. Five candidates drawn in the cloud on the dam:

| Candidate | Letters, shortest / middle / longest line, percent of the view's height | Widest line | Passes |
| --- | --- | --- | --- |
| A, 60 percent of the width (the first fix) | 8.7 / 6.2 / 4.0 | 0.60 | no: taller than a hit word, uneven, wide |
| B, 50 percent of the width | 7.2 / 5.2 / 3.3 | 0.50 | no: uneven, and taller on an ultrawide |
| C, 40 percent of the width | 5.8 / 4.1 / 2.6 | 0.40 | no: uneven, and taller on an ultrawide |
| D, pop at 0.6, room 90 percent of the height | 5.5 / 5.2 / 3.3 | 0.51 | no: uneven (1.64) |
| E, pop at 0.5, room 90 percent of the height | 4.6 / 4.6 / 3.3 | 0.51 | yes |

E is in the game (`WORD_FIT` in `machine_fx.gd`; `POP_SIZE` in `panel_fx.gd` was retired on 12 Nov, below): a word's room is now a share of the view's height, as the player's words are sized, so the letters hold on any screen shape. Every machine word shares that room, not only the pop: a hit word, a tell, Brindle's phase and fall words now stop at 0.51 of a 16:9 view's width where they stopped at 0.60, which only a word stamped within a few metres of the camera reaches. With reduced motion the pop is 0.4, by the same arithmetic 3.7 / 3.7 / 3.3 percent; that size was not drawn. Two pickups in a row stand on two lines (look and feel's change, the same day). With both up the letters measure 3.3 to 4.7 percent and the widest line 0.51, so the lines hold; the step between the two lines went from 1.5 m to 0.7 m with the smaller letters (about one and a half letter lines, as before), which keeps the upper line under the hint line below the objective plate. The PC measured the same letters (4.6 / 4.6 / 3.3 percent) and the same widest line (0.51) on 10 Nov. The lines about an ultrawide screen are arithmetic and do not arise today: the game keeps its view at 16:9 whatever the window's shape (the project's stretch aspect is "keep"), so the PC's film at 3440 by 1440 was the same view, and a wide window gains nothing at the sides. If the view is ever let go wide, a share of the height still holds where a share of the width would have grown. Where the pop stands (2.6 m over the ball) is unchanged.

The pop left the ball on 12 Nov 2026 (PF-14: "SIGHT +4% WEAPON RANGE" hid behind an enemy and "BUMPER +5% RAM FORCE" sat on the gates' feet). It is now a HUD line rising from the top of the bottom band at its left (`src/ui/pickup_lines.gd`), at the HEADING type step: letters 2.6 percent of the view's height, inside this call's lines, and no longer sized in metres. Assumption Andrew can overturn: the HUD edge beats the ball for a pickup read, because the ratchet and the phrase already say a panel landed at the ball.

A written claim about how the game or the pipeline works, and a finding from a new check, get the same independent check as a code change before they are sent.

The first run on world 1 (10 Nov) and its pictures are on the phone copy of this page. What it found, all small, none fixed before the world 1 sitting because each fix changes pixels:

- **Outlines.** Five blind readers, by majority, named the job for 11 of the 24 Spillway enemies. Four of the five picked the Shift Boss as the one in charge, by its twin horns; all five listed it and the lobber as a pair they would confuse at a glance, and the fifth picked the lobber. The two share a cart and overlap by 81 percent; the dispatcher and the vault overlap by 78. All five read the plated brute as crates, the deflector as a mushroom, the netcaster as a gong and the bola thrower as a bottle with a ring, and found the swarm remnant, the splitter piece and the catch trap too small or plain to read. The readers' answers are not in the repository. An outline has no colour, motion or sound, so whether any of this matters in play is on the [sitting watch list](../../../project-guide/handoff/shared/alpha-status/sitting-watch-list.md).
- **Meshes.** 1,554 of 1,727 models scan clean. On enemies and bosses: two top faces of the lobber lit as if they faced away, 36 slivers on the dam Warden's clamp tower lit inside out, 64 slivers of Brindle's armour drawn twice, 60 faces of the Mind Warden lit inside out (a ray test outside this tool puts them inside its body). On scenery: 94 of the 286 far versions of park props carry faces lit inside out, 7 of them over a tenth of their surface (cable drums a and b, spool shed c, knot boards a and b, rope baskets a and b). At the default preset those seven are drawn from 90 m out (`PROP_RANGES` in `park_props.gd`); the large pieces among the 94 from 180 m. Not yet looked at on the PC.
- **Clips.** 59 one-frame snaps: Rivet 46, Tally 11, Kest 1, and one on Brindle's `enter_scuttle`. 55 of the pilots' 58 start on a pose-table key that has another key on the next frame (Rivet 45, Tally 10), so the step is written, such as Rivet's visor taps in `ult_ready`. Three do not: Rivet `cast_line` lower_arm.R at 0.367 s, Tally `cast_special` hand.R at 0.1 s, Kest `smash` lower_arm.R at 0.4 s. Those three, Brindle's, and one written step that is very large (Tally `cast_line` turns hand.R 171 degrees in one frame) want an eye on film.
- **Effects.** [fx_capture.gd](../tools/fx_capture.gd) takes one still per effect on sand. The PC drew strips of four stills over each effect's life (10 Nov). Measured on those strips, of 256,000 pixels: `dig_grit` changed none (world 2), `fuse_sputter` at most 4 (the splitter's lit fuse), `daze_halo` at most 23 (the only sign that a pack unit is stunned), `arc_crawl` at most 132 and `cache_ember` at most 199. Amber and pale motes added onto orange sand barely move it. Whether a stunned enemy reads as stunned in play is the question for the reel; any change waits for the world 1 sitting.
- **Bodies in play.** The reel's first count, in a cloud run outside the repository: of the eight kinds with baked clips (chaser, lobber, mag trapper, jolt layer, hooker, sluice flap, boom tender, plated brute), seven count no snap inside a clip, through the hit and the death; the hooker's harpoon jumps once in its wind-up. The catch trap, splitter, linker, Shift Boss, dispatcher and miniboss have no baked clips and move by their scripts alone. Three written steps there want an eye on film: the catch trap's cup arrives over the ball in one frame, the Shift Boss's hand ticks a twelfth of a turn on each beat (19 in 8 seconds), and the miniboss's core jumps between sockets when a weak point opens. reel.json names the second of each.
- **The reel on the PC** (10 Nov, stage dbb2cf05, 60 frames a second). In-clip snaps: the catch trap's cup three, the hooker's harpoon two, every other kind none. The Shift Boss's hand, 19 in the cloud, counted none on the PC; not yet explained. The first film was not fit to judge from, by the PC lane's report: the ball was scrapped as the dispatcher died, so the last kind played under the game-over screen, and from the ball's camera the debris of eight of fourteen deaths could not be seen. The tool now fills the hull before every kind, stops if the ball is scrapped, and films the hit, the stun and the death from a second camera 7 m from the kind.
- **Danger marks, read from inside them** (twelve readers, cloud and PC stills). With the HUD's danger diamond, 12 of 12 readers said a ball standing in Brindle's slag ring or charge lane was about to be hurt; without it, 3 of 12. A ring on open sand reads without the diamond (12 of 12). Standing just outside a ring on the sand, 14 of 24 answers did not say the ball was safe: the ring's wall and slab stand behind the ball and overlap it. A still has no motion, so that one waits for film. Seven of twelve could not tell which part of a ring hurts, and eleven of twelve called the yard wall's red tint confusing. On the PC a ring's floor fill is far more solid than in the cloud and nearly hides the ball inside it.
- **The postcard's line.** Five drawings, fifteen readers; "this is her." as a bare line with an arrow is in the game. The read is in [TITLE-INTROS.md](TITLE-INTROS.md).
- **Flood foam from far.** On the PC the dam's flood foam, seen from about 60 m at a low angle, stands up like stacked pale blocks. The count is capped (four pieces a flood, 24 rings and 20 flecks a piece), so it is a look, not a cost. After the sitting.

**Colour on the PC and in the cloud.** A material that takes its colour from the mesh has a second switch, `vertex_color_is_srgb`. The PC's renderer reads a vertex colour as linear light unless the switch is on (one PC still so far, look and feel's: a charcoal line written 36, 42, 40 drew 109, 118, 115; the probe below has not yet run there); the cloud's ignores the switch and draws the number as it stands (measured in the cloud: a palette tone as a plain colour, written into a mesh with the switch off, and with it on, all draw alike; the tone stored linear draws darker, rust 155, 81, 58 as 83, 16, 4). So the two kinds of material go opposite ways, and neither machine shows both right:

- A cast from Blender stores its colours linear ([common.py](../tools/blender/common.py)) and leaves the switch off. It is right on the PC and too dark and too strong in every cloud picture. Every enemy body, the bosses, the pilots, the props and most scenery are casts; what code builds of the Spillway's scenery carries a grey shade and no palette colour (its mist, its rock). Do not judge a cast's colour from the cloud.
- A colour that code writes straight from the palette is right in the cloud and paler on the PC, unless the code turns it linear first (the Spillway's merged masonry, the swarm remnant's enamel) or sets the switch (hostile warnings, `threat_grammar.gd`). In world 1 that leaves seven, all unshaded marks: the ball's bolts, the lines and rings of its attacks (`effects.gd`), its trail and speed lines, its aura motes, the cable arcs, the boom tender's lamps, and the aim indicator, which look and feel is fixing.

Setting the switch everywhere would darken every cast on the PC, so there is no blanket fix. [vertex_colour_probe.gd](../tools/vertex_colour_probe.gd) settles it on the machine it runs on: palette swatches each way, a census of every such material in three scenes (a lineup, the same with the ball's bolts and attack lines put up by the game's own calls, Brindle's arena) by the nearest script above it in the scene and where its mesh came from, and for each family of code-built materials (a script, and the view's name where it has one) a picture with the switch turned on and a count of the pixels that changed. Greying a family's materials in place of the switch (`--plant=1`) shows in the cloud that the count sees a change. The seven marks are a taste call by the rule above: Andrew has only ever seen them pale, and a dark teal line on sand may read worse than the pale one it replaces. Nothing changes until the PC has drawn both.
