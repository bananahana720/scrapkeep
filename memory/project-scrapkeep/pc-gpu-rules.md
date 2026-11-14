---
name: pc-gpu-rules
description: "Scrapkeep PC rules: 4080 (device 0) for perf and the GPU bench, 3060 (device 1) for music renders, driver auto-update needs a reboot, one checked-in script instead of compound shells, perf only on an idle GPU"
metadata:
  node_type: memory
  type: reference
  originSessionId: 4a2277c3-040b-4307-a006-0aaff95dc0a3
  modified: 2026-10-24T16:49:29.386Z
---

- The PC "ahana" has an RTX 4080 (device 0) and an RTX 3060 (device 1). Pin frame times and perf benches to device 0. Exception by design: `sketch:export`'s Vulkan boss smoke runs on card 1, the 3060 (`scripts/sketch-export.mjs:272`, and its test expects "RTX 3060"); it is a correctness smoke that keeps the 4080 free, never a perf number.
- An NVIDIA driver auto-update locks the 4080 ("Driver/library version mismatch") until a reboot. Ask Andrew to reboot; do not pin the driver. Driver 615.78.08 was healthy on 2026-10-18.
- The 4080 belongs to the GPU bench (frame times, menu-ready, real `sketch:export` with ACE stems). The queue file is `~/scratch/w17/gpu-queue.md`; perf readings count only on an idle 4080.
- **The 3060 is the music render card (Andrew, 2026-10-19: "go have at it", full approval).** Music renders (`scripts/music/mx`, ACE-Step or a successor) run there continuously, so they never pause for the bench. Music may borrow the 4080 only when the bench queue is empty and the lock is free. The export's short boss smoke also uses the 3060; it can share.
- **Since 2026-10-24 (PC bottleneck session; repo lesson SKL-37, PR #446):** the wallpaper pauses while blender/godot runs, so pre-24-Oct 4080 captures are labelled "wallpaper running". Frame times off screen come from gamescope headless (`-r 1000 --immediate-flips`), never `godot --headless`. Blender Cycles uses OptiX on both cards, but a dual-GPU render must fit the 3060's 12 GB and competes with music and model jobs there; use the 4080 alone for big scenes or while the 3060 is busy. Power caps cost about 1%; see [[dual-gpu-power-cap]].
- Compound shell commands cause allow-once prompts; use one checked-in script with subcommands, called as a plain command.
- Remote sessions often report phantom permission prompts; raise one only if it stays stalled for several minutes.
Related: [[cloud-lanes-github-bus]], [[alpha-coordinator-handoff]].

**Local lane CPU budget (2026-10-19).** Three local lanes running bot sweeps at once drove load to 116 on 32 threads, and 43 matchup-lab Godot processes ran at nice 0. That spoils the 4080 frame timings. Caps: Systems B 12 concurrent Godot, Content 8, Music CPU encodes at nice 10; everything goes through `cpuq` at nice 10. The GPU bench times runs only below a 1-minute load of 40, interleaved base/PR, otherwise it reports the paired delta as INCONCLUSIVE for absolute ms. State each lane's cap in its start brief.

2026-10-27: every frame-capture tree gets `scripts/music/mx stems-sync` first (stems are gitignored; a fresh worktree silently plays the synth engine, and the synth funk stab costs 22-37 ms script frames in the flume). Receipts state "stems present" or "synth"; check the run log for "playing the synth engine instead". Fresh-tree Godot import can crash on NotoSansMono-Bold.ttf; copy a sibling tree's .godot plus *.import when only scripts differ.

2026-10-29: until a stage head includes #592 (serialises the music band bake), any 4080 row with --warm-band=1 can SIGSEGV at random (Godot 4.7.2 thread race); a solo rerun of that seed is valid. Once #592 is on a stage, delete the kept core for pid 3787094 (coredumpctl, 517 MB).
