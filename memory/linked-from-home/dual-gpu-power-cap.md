---
name: dual-gpu-power-cap
description: ahana runs RTX 4080 (display, GPU 0) + RTX 3060 (compute only, GPU 1) on a 750 W PSU; power caps 280/140 W via nvidia-power-cap.service since 2026-10-07
metadata:
  type: project
---

Since 2026-10-07 ahana has two GPUs: the RTX 4080 FE at PCI 3a:00.0 (GPU 0, drives both monitors, /dev/dri/card1) and an MSI RTX 3060 12 GB at 3b:00.0 (GPU 1, no display, /dev/dri/card0). Both run PCIe gen 4 x8 because the board splits the CPU lanes; verified 13.5 GB/s host-to-device on each. Driver: NVIDIA open module 610.57.04.

The PSU is 750 W. Nameplate sum (320 + 170 + 5950X 142 + about 60 W rest) is about 690 W, so `/etc/systemd/system/nvidia-power-cap.service` (root oneshot, enabled) sets 4080 to 280 W and 3060 to 140 W at boot by GPU UUID. Remove with `sudo systemctl disable --now nvidia-power-cap.service` and delete the file.

**Measured 2026-10-24 (Cycles OptiX, 1024 samples, 1080p, 2 runs each):** the caps never bind in Blender. 4080 peaked 199 W (32.3-32.9 s at both 280 and 320 W); 3060 peaked 123 W (106-110 s at both 140 and 170 W). Lifting the caps gains nothing for rendering; a 1000 W PSU only buys transient margin. Raster, measured same day (Godot 4.7 Forward+ stress at 4K, SDFGI/SSR/SSAO/MSAA 4x, headless gamescope `-r 1000 --immediate-flips`, 3 alternating runs): 280 W cap = 103.6 fps mean, 320 W = 104.6 fps (+1%, inside run-to-run spread of 101-107); uncapped peaked 307 W, mean ~290 W, clocks 2741 vs 2788 MHz. The cap costs at most ~2% even in a worst-case raster load.

**Blender uses both GPUs (2026-10-24):** prefs had Cycles compute device NONE (every GUI Cycles render ran on CPU, ~17x slower than the 4080). Now OptiX on 4080 + 3060 in `~/.config/blender/5.2/config/userpref.blend` (backup `userpref.blend.bak-2026-10-24-gpus`), plus a new `startup.blend` (factory scene, cycles.device=GPU). Both together measured 26.3 s vs 32.5 s 4080-only (+19%); scenes must fit 12 GB, and a render competes with AI jobs on the 3060. Old .blend files keep their saved device.

**Why:** Andrew asked for a dual-GPU setup check and power management on 2026-10-07; caps trade a few percent for transient headroom given the August freeze history ([[pc-freeze-troubleshooting]]).
**How to apply:** Target inference jobs at GPU 1 (`CUDA_VISIBLE_DEVICES=1` or the 3060 UUID) to keep the desktop card free. Do not raise the caps without revisiting the PSU budget. Related: [[andrew-machine-preferences]].
