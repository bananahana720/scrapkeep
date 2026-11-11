# First-timer PC film, systems audit pass E (PR 776)

This branch holds the film only. It shares no history with the game.

- **Build:** `stage/alpha-w37` at 965e31f6, which has PR 776 stacked.
- **Machine:** Andrew's PC, 11 Nov 2026, 21:44Z. The GPU was the RTX 4080 (Godot's log reads "Using Device #0: NVIDIA GeForce RTX 4080"), power-capped at 280 W. Its load was Andrew's desktop only: the wallpaper, Chrome and ChatGPT. It ran headless inside gamescope, with no window on his screen. Godot 4.7.2.
- **Profile:** a fresh first-time profile. The scratch user-data home is `~/scratch/world1/xdg/w37pc-film965e`, from `env-pc.sh`. The run never touched `~/.local/share/godot/app_userdata/core-loop`.
- **Command,** from the repo root:
  `gamescope --backend headless --prefer-vk-device 10de:2704 -W 1280 -H 720 -w 1280 -h 720 -- node scripts/redteam/eye.mjs --persona=first-timer --film=whole --seed=1 --gpu --no-xvfb --out=<dir>`
- **Result:** exit 0 in 345 s wall. The run played 447 s of game time and covered stages 1, 2 and 3. The film kept 166 frames, and 1,143 frames were drawn.

**Input: not a pad.** The film tool drives the game with the first-timer bot (`random` policy), and it has no pad mode. The prompts on screen are keyboard prompts: WASD, Shift and Ctrl.

**Not a frame-time reading.** The film is not a frame-time record (see the `eye_film.gd` header), and the 4080 carried the desktop's load.

**Layout:**
- `film-965e31f6/film/`: the frames, plus `film.ndjson`, which holds one row of the game's own state for each frame.
- `film-965e31f6/judge/SHEET.md`: each frame beside the game's state.
- `film-965e31f6/game.log`: the game's log.

## Second film: stage head 93d3fd86, with PR 780 (the first-run tips paced)

`film-93d3fd86/` was filmed the same way at 22:00Z, on the RTX 4080 with a fresh scratch profile (`w37pc-film93d3`). It exited 0 in 487 s wall. The run played 425 s of game time across stages 1 to 3 and kept 135 frames. The CPU was running the pass B economy jobs at the same time. The film's frame rate is fixed, so that load changed only the wall time.
