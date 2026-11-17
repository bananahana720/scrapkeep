# Andrew's PC, the Mac Studio and the cloud box

## The PC

- **Machine:** "ahana", Omarchy (Arch Linux), RTX 4080 as GPU device 0 and an RTX 3060 as device 1. Checkout: `/home/andrew/Projects/scrapkeep`.
- **How work reaches it.** Since 15 Nov the Gate is a local session on this PC and runs the work directly (ruling ds). Until 14 Nov the board thread drove it through a Remote Control session, which could end silently. A PC session waits on a background job for at most about 45 minutes, then takes a short turn, so the app's idle sweep does not stop it (ruling dn). Godot runs there only with the scratch folder, and Andrew's saves and settings (`~/.local/share/godot/app_userdata/core-loop`) need his go-ahead.
- **The 4080 is device 0 for perf.** Pin all frame-time and timing work to it, through headless gamescope. Readings count only on an idle card: a capture is void if Andrew plays or another process touches the card during it. Run the stems sync first. Power caps: 4080 280 W, 3060 140 W (#446).
- **Wallpaper.** The live wallpaper pauses only for a process named exactly `godot`, so launch captures through a `godot` link and count `mpvpaper` as foreign (#446).
- **The 3060 renders music** (ACE-Step renders and stem splits) and stills. Music renders pause while a 4080 perf reading runs.
- **Reboot rule.** An NVIDIA driver auto-update locks the GPU ("Driver/library version mismatch") until a reboot. Ask Andrew to reboot after any update, and don't pin the driver.
- **One script, not compound shells.** Pipes, `&&` and `cd` chains trigger allow-once prompts. Use one checked-in script with subcommands (`scripts/music/mx` for music), called as one plain command.
- **Allow-list.** The PC allows test and check scripts, read-only git, and pushes to `cand/*` and `scratch/*`. A push to main follows the standing merge authority in [DECISIONS.md](DECISIONS.md); a force-push or an install needs Andrew's go-ahead first.

## The Mac Studio

- **Machine:** M5 Max (18 cores), 36 GB unified memory, 512 GB disk, macOS. Andrew's main development machine from 16 Nov 2026, quiet and for the agents' use alone, so checks run wide. Checkout: `~/projects/scrapkeep`.
- **The Mac is the Gate machine** (ruling eb, 16 Nov, [DECISIONS.md](DECISIONS.md)). The local session here stacks, runs the wave gate, the release gate, the band reads and the frame-time and press-latency captures, and its readings count. Each Mac reading needs a Mac base: do not compare a Mac number with a PC receipt.
- **Shell.** A non-interactive shell has no Homebrew on its path: start commands with `export PATH=/opt/homebrew/bin:$PATH GODOT_BIN="$HOME/Applications/Godot_4.7.2.app/Contents/MacOS/Godot"`.
- **Saves.** Godot on macOS ignores `XDG_DATA_HOME` and keeps `user://` under `$HOME/Library/Application Support/godot/app_userdata/core-loop`. The runners (`sketch-fast.mjs`, `sketch-smoke.mjs`, `gate/pc.mjs`, through `scripts/godot-home.mjs`) and the tests that launch a child game (`tests/trees/child_runs.gd` `home_env`) move `HOME` with the data folder (PRs 1099 and 1103). A hand launch still needs `HOME` set to a scratch folder under `artifacts/local/`. Ten bot tests still launch children that share the test's folder (BACKLOG MG-02).
- **Shutdown lines.** The headless engine on macOS prints "RID allocations ... leaked at exit" and "resources still in use at exit" on tests that end clean on Linux. The runner and the gate skip those two lines on macOS only, so a real exit leak is not caught here (BACKLOG MG-01).
- **Pins.** The Mac repeats its own runs exactly, but each seed plays a different fight than on Linux, so hashes and posture medians differ. A pin that differs holds both values through `tests/support/platform_pin.gd` (`pick(linux, mac)`); never replace a Linux value with a Mac one. The cause is not established: the test comments name the platform's `sinf` and `cosf` rounding, which does differ, but a run with that patched still gave the Mac's hashes (BACKLOG MG-03).
- **Timings (17 Nov).** `npm run sketch:fast` takes 6 to 8 minutes. The full suite takes about 30 minutes at `SMOKE_JOBS=12 SMOKE_SOLO_JOBS=8`; at that width a few tests fail under load and pass alone (BACKLOG MG-04 names them). The wave gate's time is in [STATE.md](STATE.md).
- **Frame time.** `node scripts/frametime-check.mjs --capture=engine` logs each drawn frame from inside the game (the PC's MangoHud path stays as `--capture=mangohud`). A reading from the editor binary on a cold shader cache is not graded: grade a packed build, or the second pass of a debug run, and say which (BACKLOG MG-05). A reading that launches the game waits for running `sketch:smoke` and `sketch:fast` runs and keeps new ones from starting Godot until the game exits; the header of [scripts/frametime-check.mjs](../../scripts/frametime-check.mjs) says what that covers and what it does not (a running gate, nightly, red team, band read or export). So take every reading through `frametime-check.mjs`, on either machine, and not during a gate.
- **Packed Mac build.** `npm run sketch:export-mac` exports the "macOS" preset to `artifacts/local/core-loop-export-mac/<run>/Scrapkeep.app` and boots it headless for 300 frames; `-- --self-play` keeps `tools/` in the pack for a frame reading. The header of [scripts/sketch-export-mac.mjs](../../scripts/sketch-export-mac.mjs) says what it isolates, what it changes for the export alone and what it does not check; `BUILD.txt` beside the app records the run. Grade the reading on the self-play app: `node scripts/frametime-check.mjs --self-play --self-play-until=win --warmup=30 --seconds=300 --self-play-min=340 --exe=<run>/Scrapkeep.app/Contents/MacOS/Scrapkeep -- --profile=sitting`. For a warm-cache reading add `--home=artifacts/local/frametime/<earlier run>/home`, which reuses that run's shader cache.
- **Packed music.** The Oggs are gitignored. The copy on the PC (`~/scratch/repage/music_ace`, packed as `~/scratch/archive/music_ace-repaged-2026-11-16.tar`) already has the short 20 ms Ogg pages that `sketches/core-loop/tools/ace/repage.py` writes, but it does not hash as `STEMS.sha256` lists, so `stems-sync` refuses it and an export with it reports stale stems. Tests do not need the Oggs. An export does: run `repage.py apply`, rewrite the list with `scripts/music/mx stem-hashes`, and land the list in its own pull request first. To move the tar to the Mac, join the Mac to the same Tailscale network and send it from the PC with `tailscale file cp <tar> <mac name>:`.

### Set up the Mac

1. Install the tools: `xcode-select --install`, then with Homebrew `brew install git gh node ffmpeg python`. Node must match `package.json#engines` (20.19 or 22.12 and later).
2. Install Godot 4.7.2: download `Godot_v4.7.2-stable_macos.universal.zip` from the Godot releases on GitHub, unzip it, rename the `Godot.app` it holds to `Godot_4.7.2.app`, move that into `~/Applications`, and run it once from Finder so macOS clears its quarantine. Add `export GODOT_BIN="$HOME/Applications/Godot_4.7.2.app/Contents/MacOS/Godot"` to `~/.zshrc`.
3. Sign in and clone: `gh auth login`, then `git clone https://github.com/bananahana720/scrapkeep.git ~/projects/scrapkeep`, then `cd ~/projects/scrapkeep`. Set `git config --global user.name` and `user.email` to the same values as on the PC.
4. Switch to the stage, install the locked packages and import the project: `git switch --detach origin/stage/alpha-w43`, `npm ci`, `mkdir -p artifacts/local/mac-home`, then `HOME="$PWD/artifacts/local/mac-home" node scripts/import-stamp.mjs import`. The import writes `.godot/`, so the first run takes several minutes.
5. Check the setup: `npm run sketch:fast -- --base origin/stage/alpha-w43`. A clean stage passes.
6. For the model checks (`scripts/gate/model-receipts.mjs`, the `scrapkeep-verify-formal` skill), install Java with `brew install openjdk` and put `/opt/homebrew/opt/openjdk/bin` on `PATH`. Then run the astack statechart skill's `statechart install-tlc` once. It downloads TLC 1.7.4, checks it against its pinned SHA-256 and stores it as `~/.local/share/astack/tlc/tla2tools-1.7.4.jar`.
7. Bring Claude's project memory across. It lives only on the PC under `~/.claude/projects/-home-andrew-Projects-scrapkeep/memory/`, packed as `~/scratch/archive/scrapkeep-claude-memory-2026-11-16.tar.gz`; send it the same way as the music. On the Mac it goes under `~/.claude/projects/-Users-<you>-projects-scrapkeep/memory/`. The folder name is the checkout path with each `/` written as `-`.

### Pick up the open wave

Start a Claude Code session in `~/projects/scrapkeep`. Tell it to read AGENTS.md and then the newest handoff comment on the live board ([STATE.md](STATE.md) names it). It names the open branches and what each still owes.

## The cloud box

Setup is in [tools/cloud/CLOUD-SETUP.md](../../tools/cloud/CLOUD-SETUP.md). The rules for a cloud thread are in [AGENTS.md](../../AGENTS.md).

- **Size:** 4 vCPU, 15 GB RAM, about 30 GB disk, no GPU. Background tasks cap at 2 hours. The box is reclaimed when idle, and `artifacts/local/` goes with it.
- **Setup hook:** `.claude/hooks/session-start.sh` installs Godot 4.7.2, Blender 5.2.2 (shim `scripts/cloud/blender`) and npm deps. It takes about 70 s fresh and about 2 s cached.
- **Cloud can run:** sketch smoke, gate shards as overflow (the gate itself runs on the PC since 10 Nov), bot runs, the headless win-proof export, Blender recipes, and Cycles on the CPU.
- **Cloud can't prove:** 60 fps, menu-ready time, or anything GPU. Cloud perf numbers never count, and the cloud-to-PC ratio differs by kind of work (LESSONS 55-58).
- **Concurrency:** more than 6 Godot lanes on 4 vCPU causes mass 180 s timeouts, and band sweeps can be killed for running out of memory.
