# Picture proof: boards, before and after pairs, rounds and frames on the Mac

This page is the picture contract for the world 1 promise cards (`docs/promises/README.md`) and any change a player sees. A picture never proves a change by itself: a change is proven by a number from a named tool on fixed stations, with a planted fault shown failing. Paths below are from the repo root. A file marked (new) is built by the subtask named beside it and does not exist until that subtask is stacked.

## (a) The board: one agreed look per subject, before any build

A board is required before any build round on a subject a card lists under Boards: a crew kind or boss part, a place a subtask changes, a look topic (the value sheet, a stage's light, an effect family) and a sign (a guide or a marker). A build round on a subject with no frozen board is refused.

**Layout.** Every row of a board is a pair at one camera: the game frame on the left, drawn by `sketches/core-loop/tools/look_harness.gd` through the off-screen lane (part d), and the concept on the right, painted over that frame. The camera, the scale ball, the footprint and the horizon are therefore the game's; the image supplies shape, pose and surface only.

**Views per subject kind.**

| Subject | Rows |
| --- | --- |
| Crew kind or boss part | front, side, rear and top (a 25 degree lens, the eye at three bound radii on the kind's axes); the rider at speed (the chase camera at full speed: arm 10.5 m, `sketches/core-loop/src/movement/chase_camera.gd:410`; lens 80, `FOV_FAST` at line 21; the ball 25 m from the subject at the 14 m/s cruise of `sketches/core-loop/src/movement/tuning.gd:7`); a silhouette at 30 m (the subject black, everything else the flat sky colour); and for a crew with a wind-up, the rider view at the wind-up's last frame and at the strike's first |
| Place | the plan (top-down, 55 degree lens, as the `arb_bowl` `top_down` camera in `sketches/core-loop/tools/look_subjects.gd`), the rider entry and the rider exit on the place's route; for an arrival, the frame the arrival camera already shows |
| Look topic | each of the card's stations on High and Low, today against proposed, plus a greyscale strip the composer makes from the proposed panel (never painted) |
| Sign | the look rows plus the moment frame (for a fight's end, the frame 1.0 s after the clear) |

**The cheap way to one look.** The thread makes three candidates, A, B and C, at the rider-at-speed row only (the plan row for a place, the first station for a look topic). One is picked (below). Every other row is then painted from the pick, with the picked panel given to the image skill as the reference image, so the views of one subject agree.

**The image skill is checked first.** The board tool's first proof (W1-132f) is one real game frame given to the image skill and returned painted over with the camera kept. If the skill cannot edit an input image, the fallback is a generated panel with the frame given as a reference, and the fixed facts stamped on by the composer. The board's record notes which way was used (`method`: `paint_over` or `reference`).

**Fixed from game data, written by a script, never typed by the thread.** The composer, sketches/core-loop/tools/board_compose.gd (new, W1-132f), writes these into the board's record from the source and draws them over both sides of each row: the scale ball where the harness put it; the subject's collision size and bounds; each attack's telegraph shape, range and timing from its kind's constants (for example the chaser's `WINDUP` 0.6 s at `sketches/core-loop/src/combat/chaser.gd:24`); for a place, terrain heights, route lines (`sketches/core-loop/assets/park/park_dam/lines.json` and the flume's), homes and landmarks; the palette roles the board uses (`sketches/core-loop/src/core/palette.gd`); and the station, tick, seed and preset as a caption. **Free:** the silhouette inside the collision bounds, surface, wear, tool form, pose, and the shape of new pieces. A concept may not move a telegraph, a range, a timing or a camera.

**Palette and tone.** The palette strip may name only palette roles: HAZARD only on a live warning, BRASS only on a boss fact (the role notes at `sketches/core-loop/src/core/palette.gd` lines 21 and 23). A fill is judged by colour distance and an edge by luminance: HAZARD on SAND is 1.81 to 1 by luminance, so no board asks a fill for 3 to 1 against sand, and no board darkens the sand to get it (`project-guide/handoff/DECISIONS.md:433`, Arizona sandstone). The board answers yes or no to the tone bible's lines (`project-guide/handoff/shared/tone/TONE-BIBLE.md`) and `sketches/core-loop/design-v3/STORY-MAP.md`: machines are workers, not monsters; no gore; no real brands; no decoration crosses a telegraph, a hit read or the HUD; the harpoon is a rope and a hook, never a beam. After the world 1 value sheet is frozen (W1-138b), a board's greyscale strip keeps the separations the sheet sets.

**Choosing and freezing.** The Gate publishes one pick page per batch of subjects (the pattern of `sketches/core-loop/tools/concept/board_page.py`, a page with a verdict store per picture), and Andrew marks A, B or C. Unmarked after 48 hours, the Gate's top-tier reviewer picks blind with the candidates shuffled, against the card's question and the tone lines, and the pick is logged as an assumption he can overturn (decision A8). The Gate commits the pick with `frozen: true` and the image's sha256. There is one folder per subject, so two looks for one subject cannot coexist; the card check fails a second board for a subject and a frozen board whose hash differs from its record. A veto from Andrew unfreezes the subject.

**The distinctness read across the roster.** After the crew boards freeze (W1-136b), a fresh reader who saw no board gets every kind's rider-at-speed panel shrunk to 120 x 68, shuffled, and names each kind. Pass: every kind named. The control: two panels of one kind under different labels; the reader must flag them as the same kind, or the read is void.

**Files and sizes.** Candidates go on the card's proof branch as sketches/core-loop/design-v3/boards/`<subject>`/candidates/`<A|B|C>`/ at 1920 x 1080. The frozen board is `sketches/core-loop/design-v3/boards/<subject>/board.jpg`: two columns (game, concept), one row per view in the order above, rows at 960 x 540, JPEG quality 80, at most 1 MB. Its record `sketches/core-loop/design-v3/boards/<subject>/board.json`, at most 20 KB, holds the subject, kind, stations, rows, the fixed facts with their source lines, the palette roles, the tone answers, the candidates, the pick and who picked, `method`, the frozen hash, and for a place or sign a `changes` list: each proposed change with the id of the geometry or behaviour check that proves it built.

## (b) The before and after pair

| Fixed | Value |
| --- | --- |
| Tool | `sketches/core-loop/tools/look_harness.gd` with `--pair --base=<sha7>` (blind pairs: which side is the base is a coin per subject and camera, kept in the pair's key file), run through the off-screen lane (part d) |
| Stations | the card's own file, sketches/core-loop/tools/stations/`<card>`.json (new per card), and the shared route file (new, W1-132a), merged by the harness's subject list. A station row stages its subject on the **park** table that world 1 ships on (`sketches/core-loop/src/game.gd:91`); the harness's `_boot` defaults to `alpha` (line 499), and W1-132a proves the staging |
| Seed | 280928, the harness's `SEED` (`sketches/core-loop/tools/look_harness.gd:73`) |
| Moment | the row's physics tick; motion is a strip, `--frames=N --fps=60` |
| Presets | High and Low, both, every pair. Low has no SSAO and no glow (`sketches/core-loop/src/presentation/graphics_preset.gd:28`), so a cue must survive Low |
| Size | 1920 x 1080 (the harness's `SIZE`), the Mac's Metal renderer |
| Base | the stage head the subtask branched from, rendered once into the harness's baseline folder with `--baseline=<sha7>` |
| Films | `sketches/core-loop/tools/self_play.gd --self-play-film=<dir>` with a marks file (W1-132i), seeds 1 to 3, the `skipper` and `camper` bots |

**The numbers, and which tool prints each.**

- `seen.<node>`: the share of frame pixels that change when the named node is hidden and the frame drawn again. The harness already does this for the ball (`ball_seen`, `sketches/core-loop/tools/look_harness.gd:364`); W1-132g extends it to any node. "Is it visible" is the render's answer, not a ray's. A node counts as seen at 0.2 or more, the harness's `SEEN_SHARE` (line 81).
- Contrast on a node's own pixels: the WCAG 2.1 relative-luminance ratio between the node's changed pixels and a 12-pixel ring round them (W1-132g). 3 to 1 is the line for anything a player must find (success criterion 1.4.11, non-text contrast), the line `sketches/core-loop/tools/hud_contrast_capture.gd` already holds for HUD marks.
- CIE76 per rect and per rect pair: `sketches/core-loop/tools/still_compare.gd` with `--station=<subject>/<camera> --json` (W1-132b).
- `--peak`: the brightness a flash adds, already in the compare tool; over a strip, the frames a node stays lit.
- Behaviour numbers (threats per pass, pop-ins, hull per minute) come from the card's producer, not from a picture.
- `to_board`, the distance from a frame to the painted board, is printed for the reviewer and is advisory only. A frame can move towards a painting by being recoloured, so it never proves a build. A place change is proven by the geometry check its board's `changes` entry names.

**Noise.** W1-132b renders the base three times and keeps the largest spread of each measure per station in sketches/core-loop/tools/look_noise.json (new). A change smaller than the noise is no change. A guard rect outside the subject may not drift by more than the larger of its noise and 2.3 CIE76, the just-noticeable difference for CIE76.

**What the reviewer does.** For each station the reviewer opens the blind pair before reading the key, answers the card's question ("which shows the lobber's commit sooner?") with a, b or same, then reads the key and the numbers. If the blind pick and the number disagree, the round is disputed and does not count as better; a picture never silently overrides a number, and a number never silently overrides a picture. The reviewer names the ruling each kept change keeps. The answers go in the review file (part c).

## (c) The iteration rule, and how a subtask closes

- **Round 0** is the base: the producer's number, every guard, every station pair, and the plant shown caught. A measure whose plant is not caught decides nothing.
- **A round** is one commit to a file the subtask owns, then one measure and one capture.
- **Better**: the measure beats the best kept round by at least one step and by more than noise; every guard holds; no blind pick disagrees. Steps come from facts outside the code: a count moves by one; a colour by 2.3 CIE76; a time by one 60 Hz frame, 16.7 ms; a contrast ratio by 0.1.
- **Flat**: less than a step either way, guards holding. Reverted.
- **Worse**: the measure falls below round 0, a guard leaves its noise (a count loses one, a guard rect drifts, a guard test goes red, a gated done-read row gains a miss), or a blind pick prefers the base. Reverted at once and recorded. A worse round never ships.
- **Stop** at the first flat or worse round after a kept round; when the floor is met and the next round is flat; or after five rounds. Andrew's words are this rule: passes continue "until the before and after isn't an improvement while not worst or regressing from the original".
- **Void**: a round whose commit touches no owned file, or whose frames and number equal the last round's, is not a round. Three void rounds end the subtask blocked.

Until scripts/proof/rounds.mjs (new, W1-132c) is stacked, the thread keeps the round record as a table in its draft pull request's body; afterwards the script keeps it on branch `proof/<card>` and refuses a close the rule does not allow.

**How a subtask closes, by kind.** The words are the receipt verdicts of `project-guide/handoff/COMMS.md` (the Receipt row).

| Kind | Built (PASS) | Built in part (PASS+NOTES) | Already true | Blocked (BLOCKED) | Not built (FAIL) |
| --- | --- | --- | --- | --- | --- |
| `game` | owned game files differ from the base, the best kept round meets the floor, guards hold, level 1 passes | files differ and the best round beats round 0 by a step, short of the floor; the next lever named | round 0 meets the floor with its plant caught; the level 2 reviewer agrees; the Gate marks the gap "measured, holds" | a named input is missing (a decision, a tool, a board) | every round flat or worse and reverted |
| `measure` | the measure runs, its plant is caught, round 0 is recorded | the measure runs on part of its scope, the rest named | not used | as for `game` | the plant cannot be caught |
| `board` | one board frozen | not used | not used | waiting on the pick | the tone lines or facts fail on every candidate |
| `model` | the model passes on the configs that stand for the code and its plant config breaks | not used | not used | as for `game` | the model breaks on the code configs (a bug: the Gate cuts a `game` subtask) |
| `finding` | the owning file and line named, with a check that fails on the stage head | part of the cause found, the rest named | not used | as for `game` | no cause found in the time box; the evidence pushed |

On not built, the round record is pushed, the measure row stays red at `report`, and the Gate the same day cuts a new subtask with a different lever, or a decision card for Andrew. "Keep stock" is not a close, and only a `game` subtask is refused for an unchanged game.

**Review files.** Level 1 (per pull request) and level 2 (per promise) answers are written by the Gate with the round script's review command (scripts/proof/rounds.mjs review, new in W1-132c, taking the card, the level, the pull request and the reviewer's output file) once that subtask lands; the script refuses a review that misses a criterion or names no ruling for a kept change. Until then the review is a pull request comment that opens with the VERDICT line.

## (d) Frames on the Mac with no window on screen

No tool does this today: `scripts/gate/display-run.mjs` (lines 17 to 19) says a Mac run opens a window. W1-131a builds the lane, and until it is stacked nothing opens a game window on the Mac: work runs on headless numbers and takes its pictures when the lane exists.

**The lane.** `node scripts/gate/display-run.mjs --offscreen <script> -- <args>` keeps the runner's scratch home (`scratchEnv`, so Andrew's saves are never touched) and its process-group kill, and starts the game where no display shows it. Methods are tried in order and the first that passes its check is kept; each is a **guess** until tried: (1) start without activating the app (`open -g -n`) at an off-screen position, with a small helper, sketches/core-loop/tools/offscreen_window.gd (new), setting the window borderless, unfocusable and off every display at boot; (2) the same from a copy of the app with no Dock icon; (3) decision A7, the Linux PC's headless gamescope lane through the Gate.

**The check.** A watcher, scripts/gate/window-watch.mjs (new), samples every 50 ms from launch to exit the macOS window list (`CGWindowListCopyWindowInfo` through `osascript -l JavaScript`) and the frontmost application. Pass: 0 samples in which a Godot window crosses any display, 0 changes of the frontmost application, and frames the harness does not call dead. Plant: the same run without `--offscreen` must count at least one on-screen sample.

**It proves itself alone.** W1-131a's proof runs its own probe script, sketches/core-loop/tools/offscreen_probe.gd (new), and depends on no line another card adds to the harness.

**One at a time.** The lane takes a lock, so only one drawn run holds the Mac at a time; a second run waits and prints that it is waiting. Nine threads do not have nine displays: a thread runs its headless measure while its drawn pair waits.

**The true-frame check.** An off-screen frame must be a real frame. The Gate draws one windowed reference of the probe's frame once, with Andrew told beforehand; the off-screen frame must sit within 2.3 CIE76 of it in each quadrant. That is the only window this work opens on his screen.

**Real keys.** A drive with real keys (`scrapkeep-verify-game`) is not a bot run, so `sketches/core-loop/src/ui/auto_pause.gd` pauses it when focus leaves. W1-131b tries one drive under the lane and records whether it needs a focus stub.
