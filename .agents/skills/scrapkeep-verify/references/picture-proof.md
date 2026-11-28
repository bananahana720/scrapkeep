# Picture proof: boards, before and after pairs, rounds and frames on the Mac

This page is the picture contract for the world 1 promise cards (`docs/promises/README.md`) and any change a player sees. A picture never proves a change by itself: a change is proven by a number from a named tool on fixed stations, with a planted fault shown failing. Paths below are from the repo root. Files marked `(W1-132*, unbuilt)` do not exist on `main` yet (whereas `W1-131a` tools `scripts/gate/display-run.mjs`, `scripts/gate/window-watch.mjs`, `sketches/core-loop/tools/offscreen_window.gd`, and `sketches/core-loop/tools/offscreen_probe.gd` have landed).

## (a) The board: one agreed look per subject, before any build

A board is required before any build round on a subject a card lists under Boards: a crew kind or boss part, a place a subtask changes, a look topic (the value sheet, a stage's light, an effect family) and a sign (a guide or a marker). A build round on a subject with no frozen board is refused.

**Layout.** Every row of a board is a pair at one camera: the game frame on the left, drawn by `sketches/core-loop/tools/look_harness.gd` through the off-screen lane (part d), and the concept on the right, painted over that frame. The camera, the scale ball, the footprint and the horizon are therefore the game's; the image supplies shape, pose and surface only.

**Views per subject kind.**

| Subject | Rows |
| --- | --- |
| Crew kind or boss part | front, side, rear and top (a 25 degree lens, the eye at three bound radii on the kind's axes); the rider at speed (chase camera at full speed: `PROFILES` `arm` 12.0 m in `sketches/core-loop/src/movement/chase_camera.gd:44-48`; lens `FOV_FAST`, `sketches/core-loop/src/movement/chase_camera.gd:17`; the ball 25 m from the subject at cruise speed in `sketches/core-loop/src/movement/tuning.gd`); a silhouette at 30 m (the subject black, everything else the flat sky colour); and for a crew with a wind-up, the rider view at the wind-up's last frame and at the strike's first |
| Place | the plan (top-down, 55 degree lens, as the `arb_bowl` `top_down` camera in `sketches/core-loop/tools/look_subjects.gd`), the rider entry and the rider exit on the place's route; for an arrival, the frame the arrival camera already shows |
| Look topic | each of the card's stations on High and Low, today against proposed, plus a greyscale strip the composer makes from the proposed panel (never painted) |
| Sign | the look rows plus the moment frame (for a fight's end, the frame 1.0 s after the clear) |

**The cheap way to one look.** The thread makes three candidates, A, B and C, at the rider-at-speed row only (the plan row for a place, the first station for a look topic). One is picked (below). Every other row is then painted from the pick, with the picked panel given to the image skill as the reference image, so the views of one subject agree.

**The image skill is checked first.** "The image skill" is whatever image generation tool the thread's host gives it (for a Codex thread, its built-in image generation); no card names a vendor. The board tool's first proof (W1-132f) is one real game frame given to the image skill and returned painted over with the camera kept. If the skill cannot edit an input image, the fallback is a generated panel with the frame given as a reference, and the fixed facts stamped on by the composer. The board's record notes which way was used (`method`: `paint_over` or `reference`).

**Fixed from game data, written by a script, never typed by the thread.** The composer (sketches/core-loop/tools/board_compose.gd, unbuilt W1-132f spec) writes these into the board's record from the source and draws them over both sides of each row: the scale ball where the harness put it; the subject's collision size and bounds; each attack's telegraph shape, range and timing from its kind's constants (for example `sketches/core-loop/src/combat/chaser.gd` `WINDUP` 0.6 s); for a place, terrain heights, route lines (`sketches/core-loop/assets/park/park_dam/lines.json` and the flume's), homes and landmarks; the palette roles the board uses (`sketches/core-loop/src/core/palette.gd`); and the station, tick, seed and preset as a caption. **Free:** the silhouette inside the collision bounds, surface, wear, tool form, pose, and the shape of new pieces. A concept may not move a telegraph, a range, a timing or a camera.

**Palette and tone.** The palette strip may name only palette roles: `Palette.HAZARD` only on a live warning, `Palette.BRASS` only on a boss fact (`sketches/core-loop/src/core/palette.gd`). A fill is judged by colour distance and an edge by luminance: HAZARD on SAND is 1.81 to 1 by luminance, so no board asks a fill for 3 to 1 against sand, and no board darkens the sand to get it (the "Look targets" row of `project-guide/handoff/DECISIONS.md`: Arizona sandstone for world one). The board answers yes or no to the tone bible's lines (`sketches/core-loop/design-v3/TONE-BIBLE.md`) and `sketches/core-loop/design-v3/STORY-MAP.md`: machines are workers, not monsters; no gore; no real brands; no decoration crosses a telegraph, a hit read or the HUD; the harpoon is a rope and a hook, never a beam. After the world 1 value sheet is frozen (W1-138b), a board's greyscale strip keeps the separations the sheet sets.

**Choosing and freezing.** The Gate publishes one pick page per batch of subjects (the pattern of `sketches/core-loop/tools/concept/board_page.py`, a page with a verdict store per picture), and Andrew marks A, B or C. Unmarked after 48 hours, the Gate's top-tier reviewer picks blind with the candidates shuffled, against the card's question and the tone lines, and the pick is logged as an assumption he can overturn (decision A8). The Gate commits the pick with `frozen: true` and the image's sha256. There is one folder per subject, so two looks for one subject cannot coexist; the card check fails a second board for a subject and a frozen board whose hash differs from its record. A veto from Andrew unfreezes the subject.

**The distinctness read across the roster.** It runs twice by one rule. A fresh reader (a reviewer the Gate starts that has seen no board) gets one rider-at-speed panel per kind, shrunk to 120 x 68 and shuffled, and names each kind. Pass: every kind named. The control: two panels of one kind under different labels; the reader must flag them as the same kind, or the read is void. The first read is on the concept panels before the batch of crew boards is frozen, so two looks that would be confused are caught before anything is built; it is part of freezing the boards and proves nothing about the game. The second is on game frames from each kind's rider station after the rim and pose subtasks (W1-136d and e), and only that one counts for the `machines-read` row. The Gate writes the reader's answers to sketches/core-loop/design-v3/boards/roster-read.json (unbuilt W1-136b), which the row's test reads.

**Files and sizes.** Candidates go on the card's proof branch as sketches/core-loop/design-v3/boards/`<subject>`/candidates/`<A|B|C>`/ at 1920 x 1080. The frozen board is `sketches/core-loop/design-v3/boards/<subject>/board.jpg`: two columns (game, concept), one row per view in the order above, rows at 960 x 540, JPEG quality 80, at most 1 MB. Its record `sketches/core-loop/design-v3/boards/<subject>/board.json`, at most 20 KB, holds the subject, kind, stations, rows, the fixed facts with their source lines, the palette roles, the tone answers, the candidates, the pick and who picked, `method`, the frozen hash, and for a place or sign a `changes` list: each proposed change with the id of the geometry or behaviour check that proves it built.

## (b) The before and after pair

| Fixed | Value |
| --- | --- |
| Tool | `sketches/core-loop/tools/look_harness.gd` with `--pair --base=<sha7>` (blind pairs: which side is the base is a coin per subject and camera, kept in the pair's key file), run through the off-screen lane (part d) |
| Stations | card station file (`sketches/core-loop/tools/stations/<card>.json`) and shared route file (unbuilt W1-132a); `sketches/core-loop/src/game.gd` `LAUNCH_TABLE` defaults to `"park"`, while `sketches/core-loop/tools/look_harness.gd` `_boot` defaults to `alpha` |
| Seed | `sketches/core-loop/tools/look_harness.gd` `SEED` (`280928`) |
| Moment | the row's physics tick; motion is a strip, `--frames=N --fps=60` |
| Presets | High and Low, both, every pair. Low turns off SSAO and glow (`sketches/core-loop/src/presentation/graphics_preset.gd`), so a cue must survive Low |
| Size | 1920 x 1080 (the harness's `SIZE`), the Mac's Metal renderer |
| Base | the stage head the subtask branched from, rendered once into the harness's baseline folder with `--baseline=<sha7>` |
| Films | `sketches/core-loop/tools/self_play.gd --self-play-film=<dir>` with a marks file (W1-132i), seeds 1 to 3, the `skipper` and `camper` bots |

**The numbers, and which tool prints each.**

- `seen.<node>`: the share of the node's own footprint on screen whose pixels change when the node is hidden and the frame drawn again: 0 when a wall or the frame edge hides it, near 1 in plain view. `sketches/core-loop/tools/look_harness.gd` (`ball_seen`) already measures this for the ball (`SEEN_SHARE` = `0.2`), and W1-132g extends it to any node. "Is it visible" is the render's answer, not a ray's.
- Contrast on a node's own pixels: the WCAG 2.1 relative-luminance ratio between the node's changed pixels and a 12-pixel ring round them (W1-132g). 3 to 1 is the line for anything a player must find (success criterion 1.4.11, non-text contrast), the line `sketches/core-loop/tools/hud_contrast_capture.gd` already holds for HUD marks.
- CIE76 per rect and per rect pair: `sketches/core-loop/tools/still_compare.gd` with `--station=<subject>/<camera> --json` (unbuilt W1-132b).
- `--peak`: the brightness a flash adds, already in the compare tool; over a strip, the frames a node stays lit.
- Behaviour numbers (threats per pass, pop-ins, hull per minute) come from the card's producer, not from a picture.
- `to_board`, the distance from a frame to the painted board, is printed for the reviewer and is advisory only. A frame can move towards a painting by being recoloured, so it never proves a build. A place change is proven by the geometry check its board's `changes` entry names.

**Noise.** Unbuilt W1-132b would measure base noise into look_noise.json. Until built, treat a guard rect drift above 2.3 CIE76 as beyond just-noticeable difference.

**What the reviewer does.** For each station the reviewer opens the blind pair before reading the key, answers the card's question ("which shows the lobber's commit sooner?") with a, b or same, then reads the key and the numbers. If the blind pick and the number disagree, the round is disputed and does not count as better; a picture never silently overrides a number, and a number never silently overrides a picture. The reviewer names the ruling each kept change keeps. The answers go in the review file (part c).

**The sheet.** At close the composer's `--sheet` (W1-132f) lays every station's pair on one page per card: round 0 on the left and the best kept round on the right, High above Low, each pair captioned with its number and the noise, at most 2 MB a page. The sheet and the pairs are pushed to the card's proof branch, `proof/<card>`, in a sheets folder and a pairs folder, and the pull request body links them; that link is where Andrew and the reviewer see them.

## (c) The iteration rule, and how a subtask closes

- **Round 0** is the base: the producer's number, every guard, every station pair, and the plant shown caught. A measure whose plant is not caught decides nothing.
- **A round** is one commit to a file the subtask owns, then one measure and one capture.
- **Better**: the measure beats the best kept round by at least one step and by more than noise; every guard holds; no blind pick disagrees. Steps come from facts outside the code: a count moves by one; a colour by 2.3 CIE76; a time by one 60 Hz frame, 16.7 ms; a contrast ratio by 0.1.
- **Flat**: less than a step either way, guards holding. Reverted.
- **Worse**: the measure falls below round 0, a guard leaves its noise (a count loses one, a guard rect drifts, a guard test goes red, a gated done-read row gains a miss), or a blind pick prefers the base. Reverted at once and recorded. A worse round never ships.
- **Stop** at the first flat or worse round after a kept round; when the floor is met and the next round is flat; or after five rounds. Andrew's words are this rule: passes continue "until the before and after isn't an improvement while not worst or regressing from the original".
- **Void**: a round whose commit touches no owned file, or whose frames and number equal the last round's, is not a round. Three void rounds end the subtask blocked.

Until scripts/proof/rounds.mjs (unbuilt W1-132c) lands, keep the round record as a table in your draft pull request body.

**How a subtask closes, by kind.** The words are the receipt verdicts of `project-guide/handoff/COMMS.md` (the Receipt row).

| Kind | Built (PASS) | Built in part (PASS+NOTES) | Already true | Blocked (BLOCKED) | Not built (FAIL) |
| --- | --- | --- | --- | --- | --- |
| `game` | owned game files differ from the base, the best kept round meets the floor, guards hold, level 1 passes | files differ and the best round beats round 0 by a step, short of the floor; the next lever named | round 0 meets the floor with its plant caught; the level 2 reviewer agrees; the Gate marks the gap "measured, holds" | a named input is missing (a decision, a tool, a board) | every round flat or worse and reverted |
| `measure` | the measure runs, its plant is caught, round 0 is recorded | the measure runs on part of its scope, the rest named | not used | as for `game` | the plant cannot be caught |
| `board` | one board frozen | not used | not used | waiting on the pick | the tone lines or facts fail on every candidate |
| `model` | the model passes on the configs that stand for the code and its plant config breaks | not used | not used | as for `game` | the model breaks on the code configs (a bug: the Gate cuts a `game` subtask) |
| `finding` | the owning file and line named, with a check that fails on the stage head | part of the cause found, the rest named | not used | as for `game` | no cause found in five probes (the round limit); the evidence pushed |

On not built, the round record is pushed, the measure row stays red at `report`, and the Gate the same day cuts a new subtask with a different lever, or a decision card for Andrew. "Keep stock" is not a close, and only a `game` subtask is refused for an unchanged game.

**Review files.** Level 1 and level 2 reviews are posted as pull request reviews/comments opening with `VERDICT` (until scripts/proof/rounds.mjs is built).

## (d) Frames on the Mac with no window on screen

`scripts/gate/display-run.mjs` (`W1-131a`, landed) is the only way a card draws frames on the Mac. It starts Godot with `--embedded`, so no ordinary window is made, and refuses any script not qualified in `watchedTools`. Never pass `--windowed` directly on the Mac.

**The lane.** `node scripts/gate/display-run.mjs --offscreen <script> -- <args>` keeps scratch saves (`scratchEnv`) and process-group kill cleanly off Andrew's screen.

**Which tools use it.** Currently qualified `watchedTools` entrypoints in `scripts/gate/display-run.mjs`: `sketches/core-loop/tools/water_flow_stills.gd` and `sketches/core-loop/tools/offscreen_probe.gd` (with `sketches/core-loop/tools/dam_look_capture.gd` and `sketches/core-loop/tools/offscreen_window.gd` hashed as dependencies under `sketches/core-loop/tools/offscreen_probe.gd`). Future tools (look harness, film tools, W1-137a collision sweep, W1-144a Mac timing probe) must qualify via `watchedTools` in `scripts/gate/display-run.mjs` + `scripts/gate/display-run.test.mjs` before running on Mac.

**How a tool qualifies.** Add its path and SHA-256 of loaded files to `watchedTools` in `scripts/gate/display-run.mjs` (and `scripts/gate/display-run.test.mjs`) with the kept watcher result from its offscreen run.

**Windowed Linux capture command.** `node scripts/frametime-check.mjs --capture=engine` is for Linux and refuses Mac captures itself (`frametime-check.mjs:400`).

**The check.** `scripts/gate/window-watch.mjs` (landed W1-131a) samples every 50 ms via `osascript -l JavaScript` (`CGWindowListCopyWindowInfo`) and checks 0 Godot windows crossing displays, 0 focus changes to Godot, and non-dead captured frames.

**It proves itself alone.** W1-131a's self-check uses `sketches/core-loop/tools/offscreen_probe.gd` (landed).

**One at a time.** The lane takes a lock, so only one drawn run holds the Mac at a time; a second run waits and prints that it is waiting. Nine threads do not have nine displays: a thread runs its headless measure while its drawn pair waits.

**The true-frame check.** An off-screen frame must be a real frame. The Gate draws one windowed reference of the probe's frame once, with Andrew told beforehand; the off-screen frame must sit within 2.3 CIE76 of it in each quadrant. That is the only window this work opens on his screen.

**Real keys.** A drive with real keys (`scrapkeep-verify-game`) is not a bot run, so `sketches/core-loop/src/ui/auto_pause.gd` pauses it when focus leaves. W1-131b tries one drive under the lane and records whether it needs a focus stub.
