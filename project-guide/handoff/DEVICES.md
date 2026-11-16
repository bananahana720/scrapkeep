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

- **Machine:** M5 Max, 32 GB unified memory, 512 GB disk, macOS. Andrew's main development machine from 16 Nov 2026. Checkout: `~/Projects/scrapkeep`.
- **Saves are not isolated on the Mac yet.** Godot on macOS ignores `XDG_DATA_HOME` and keeps `user://` under `$HOME/Library/Application Support/godot/app_userdata/core-loop` (upstream `platform/macos/os_macos.mm`, `get_data_path`). Every script that gives a test its own `XDG_DATA_HOME` (`sketch-fast.mjs`, `sketch-smoke.mjs`, `challenge/run.mjs`, `gate/pc.mjs`) therefore shares one folder on the Mac: parallel tests collide, and they write where the Mac game keeps its saves. Until those spawns also set `HOME` on macOS, run Godot commands with `HOME` set to a scratch folder and run the fast lane with `--width 1`.
- **What stays on the PC.** Frame-time and timing captures (the 4080 and headless gamescope), GPU stills, band reads and the wave gate. The PC is on Tailscale as `ahana`; it runs no SSH server.
- **Packed music.** The Oggs are gitignored. The copy on the PC (`~/scratch/repage/music_ace`, packed as `~/scratch/archive/music_ace-repaged-2026-11-16.tar`) is 20 ms paged but does not hash as `STEMS.sha256` lists, so `stems-sync` refuses it and an export with it reports stale stems. Tests do not need the Oggs. An export does: re-page, rewrite the list with `scripts/music/mx stem-hashes`, and land the list in its own pull request first. To move the tar to the Mac, join the Mac to the same Tailscale network and send it from the PC with `tailscale file cp <tar> <mac name>:`.

### Set up the Mac

1. Install the tools: `xcode-select --install`, then with Homebrew `brew install git gh node ffmpeg python`. Node must match `package.json#engines` (20.19 or 22.12 and later).
2. Install Godot 4.7.2: download `Godot_v4.7.2-stable_macos.universal.zip` from the Godot releases on GitHub, unzip it to `~/Applications/Godot_4.7.2.app`, and run it once from Finder so macOS clears its quarantine. Add `export GODOT_BIN="$HOME/Applications/Godot_4.7.2.app/Contents/MacOS/Godot"` to `~/.zshrc`.
3. Sign in and clone: `gh auth login`, then `git clone https://github.com/bananahana720/scrapkeep.git ~/Projects/scrapkeep`, then `cd ~/Projects/scrapkeep`. Set `git config --global user.name` and `user.email` to the same values as on the PC.
4. Install the locked packages and import the project: `npm ci`, then `node scripts/import-stamp.mjs import`. The import writes `.godot/` and the `.uid` files, so the first run takes several minutes.
5. Check the setup on the stage: `git switch --detach origin/stage/alpha-w43`, `mkdir -p artifacts/local/mac-home`, then `HOME="$PWD/artifacts/local/mac-home" npm run sketch:fast -- --base origin/stage/alpha-w43 --width 1`. A clean stage passes.
6. Bring Claude's project memory across. It lives only on the PC under `~/.claude/projects/-home-andrew-Projects-scrapkeep/memory/`. On the Mac it goes under `~/.claude/projects/-Users-<you>-Projects-scrapkeep/memory/`. The folder name is the checkout path with each `/` written as `-`.

### Pick up wave 43

Start a Claude Code session in `~/Projects/scrapkeep`. Tell it to read AGENTS.md and then the newest handoff comment on the wave 43 board (issue #1076). It names the open branches and what each still owes. The first Mac card is the saves isolation above, because the fast lane's parallel width depends on it.

## The cloud box

Setup is in [tools/cloud/CLOUD-SETUP.md](../../tools/cloud/CLOUD-SETUP.md). The rules for a cloud thread are in [AGENTS.md](../../AGENTS.md).

- **Size:** 4 vCPU, 15 GB RAM, about 30 GB disk, no GPU. Background tasks cap at 2 hours. The box is reclaimed when idle, and `artifacts/local/` goes with it.
- **Setup hook:** `.claude/hooks/session-start.sh` installs Godot 4.7.2, Blender 5.2.2 (shim `scripts/cloud/blender`) and npm deps. It takes about 70 s fresh and about 2 s cached.
- **Cloud can run:** sketch smoke, gate shards as overflow (the gate itself runs on the PC since 10 Nov), bot runs, the headless win-proof export, Blender recipes, and Cycles on the CPU.
- **Cloud can't prove:** 60 fps, menu-ready time, or anything GPU. Cloud perf numbers never count, and the cloud-to-PC ratio differs by kind of work (LESSONS 55-58).
- **Concurrency:** more than 6 Godot lanes on 4 vCPU causes mass 180 s timeouts, and band sweeps can be killed for running out of memory.
