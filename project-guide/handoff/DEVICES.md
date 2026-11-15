# Andrew's PC and the cloud box

## The PC

- **Machine:** "ahana", Omarchy (Arch Linux), RTX 4080 as GPU device 0 and an RTX 3060 as device 1. Checkout: `/home/andrew/Projects/scrapkeep`.
- **How work reaches it.** Since 15 Nov the Gate is a local session on this PC and runs the work directly (ruling ds). Until 14 Nov the board thread drove it through a Remote Control session, which could end silently. A PC session waits on a background job for at most about 45 minutes, then takes a short turn, so the app's idle sweep does not stop it (ruling dn). Godot runs there only with the scratch folder, and Andrew's saves and settings (`~/.local/share/godot/app_userdata/core-loop`) need his go-ahead.
- **The 4080 is device 0 for perf.** Pin all frame-time and timing work to it, through headless gamescope. Readings count only on an idle card: a capture is void if Andrew plays or another process touches the card during it. Run the stems sync first. Power caps: 4080 280 W, 3060 140 W (#446).
- **Wallpaper.** The live wallpaper pauses only for a process named exactly `godot`, so launch captures through a `godot` link and count `mpvpaper` as foreign (#446).
- **The 3060 renders music** (ACE-Step renders and stem splits) and stills. Music renders pause while a 4080 perf reading runs.
- **Reboot rule.** An NVIDIA driver auto-update locks the GPU ("Driver/library version mismatch") until a reboot. Ask Andrew to reboot after any update, and don't pin the driver.
- **One script, not compound shells.** Pipes, `&&` and `cd` chains trigger allow-once prompts. Use one checked-in script with subcommands (`scripts/music/mx` for music), called as one plain command.
- **Allow-list.** The PC allows test and check scripts, read-only git, and pushes to `cand/*` and `scratch/*`. A push to main follows the standing merge authority in [DECISIONS.md](DECISIONS.md); a force-push or an install needs Andrew's go-ahead first.

## The cloud box

Setup is in [tools/cloud/CLOUD-SETUP.md](../../tools/cloud/CLOUD-SETUP.md). The rules for a cloud thread are in [AGENTS.md](../../AGENTS.md).

- **Size:** 4 vCPU, 15 GB RAM, about 30 GB disk, no GPU. Background tasks cap at 2 hours. The box is reclaimed when idle, and `artifacts/local/` goes with it.
- **Setup hook:** `.claude/hooks/session-start.sh` installs Godot 4.7.2, Blender 5.2.2 (shim `scripts/cloud/blender`) and npm deps. It takes about 70 s fresh and about 2 s cached.
- **Cloud can run:** sketch smoke, gate shards as overflow (the gate itself runs on the PC since 10 Nov), bot runs, the headless win-proof export, Blender recipes, and Cycles on the CPU.
- **Cloud can't prove:** 60 fps, menu-ready time, or anything GPU. Cloud perf numbers never count, and the cloud-to-PC ratio differs by kind of work (LESSONS 55-58).
- **Concurrency:** more than 6 Godot lanes on 4 vCPU causes mass 180 s timeouts, and band sweeps can be killed for running out of memory.
