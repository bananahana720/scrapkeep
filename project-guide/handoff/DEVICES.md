# Andrew's PC and the cloud: who runs what

## The PC

- **Machine:** "ahana", Omarchy (Arch Linux), RTX 4080 as GPU device 0 and an RTX 3060 as device 1. Always pin GPU work to device 0.
- **Checkout:** `/home/andrew/Projects/scrapkeep`. It is the default Remote Control folder.
- **Two Remote Control sessions run there, and they share the 4080:**
  1. **The machine session** (old thread "/astack:a-mode"). It runs GPU checks (frame times, menu-ready time, Eevee/Vulkan captures, the real `sketch:export` with ACE stems and the Vulkan boss smoke) on each promoted head. It also runs the 4080 benches, such as the Rivet carve timing.
  2. **The music session** (old thread "Compose Scrapkeep's music and sounds"). It runs ACE-Step renders and stem splits, using `scripts/music/mx` as its single allow-listed entry point.
- The two sessions message each other directly. Perf readings count only on an idle GPU, so music renders pause during them.
- **GPU handoff:** the coordinator gives "go", and the session that held the GPU replies "GPU released" when it is done.
- **Remote Control is tied to the account.** In the new project, start fresh Remote Control sessions on the same folder. The new account's Claude app must be signed in on the PC, and Andrew approves the folder once.

## Rules learned on the PC

- **Reboot rule.** An NVIDIA driver auto-update locks the 4080 ("Driver/library version mismatch") until a reboot. Ask Andrew to reboot after any update, and don't pin the driver. Last reboot: 18 Oct 02:29Z.
- **Phantom prompts.** These sessions often report "paused on a permission prompt" that Andrew can't see. Raise one only if the session stays stalled for several minutes.
- **Allow-list.** `~/.claude/settings.json` on the PC allows test and check scripts, read-only git, and pushes to `cand/*` and `scratch/*`. A push to main and force-push are "ask". The repo `.claude/settings.json` on main allows `node scripts/crash-harvest.mjs *` and `node scripts/redteam/run.mjs|merge.mjs *`.
- **Compound shell commands trigger allow-once prompts.** Use one checked-in script with subcommands, called as one plain command.
- **Commands for Andrew.** When something needs him on the PC, post one paste-ready bash block in the project chat. He runs it himself.

## Cloud sessions

Environment setup for the new project's cloud sessions is in [tools/cloud/CLOUD-SETUP.md](../../tools/cloud/CLOUD-SETUP.md), which lands through its own PR.


- **Container:** 4 vCPU, 15 GB RAM, about 30 GB disk, no GPU. It is reclaimed when idle, and `artifacts/local/` goes with it.
- **Setup.** `.claude/hooks/session-start.sh` installs Godot 4.7.2 with Linux templates (`GODOT_BIN`), Blender 5.2.2 via the PyPI `bpy` wheel (shim `scripts/cloud/blender`), and runs `npm ci`. It takes about 70 s fresh and about 2 s cached.
- **Cloud can run:** sketch smoke and the gate, bot runs, the headless win-proof export, Blender recipes, and Cycles on the CPU.
- **Cloud can't prove:** 60 fps, menu-ready time, or anything GPU. Cloud perf numbers never count.
- **Concurrency limit.** More than 6 Godot lanes on 4 vCPU causes mass 180 s timeouts. Band sweeps can be killed for running out of memory.
- **Cloud threads edit `src/` and `assets/`** on their own branches and gate them in the cloud (Andrew, 17 Oct 16:38Z). The PC keeps GPU checks.
