# GPU queue

`gpu_queue.sh --gpu N --need MIB --name NAME [--display] [--shared] [--timeout S] -- cmd args...`

- Exclusive by default: holds `/tmp/scrapkeep-gpu$N.lock` for the whole run. `--shared` skips the lock but still pins, waits for free memory and logs.
- Waits (polls every 15 s, default `--timeout` 2700 s) until card N has `--need` MiB free; on expiry prints BLOCKED and exits 3.
- Exports `CUDA_VISIBLE_DEVICES=N` and `SCRAPKEEP_GPU_INDEX=N`. Godot callers pass `--gpu-index $SCRAPKEEP_GPU_INDEX` themselves (CUDA_VISIBLE_DEVICES does not pin Vulkan).
- `--display`: starts Xvnc on the first free display in :93-:100 (a `/tmp/.X11-unix/X<n>` socket means taken), exports `DISPLAY`, unsets `WAYLAND_DISPLAY`, sets `PULSE_SINK=claude_silent`, kills that Xvnc on exit. It also exports `__NV_PRIME_RENDER_OFFLOAD=1` and `__VK_LAYER_NV_optimus=NVIDIA_only`: without both, `--gpu-index 1` fails on Xvnc with `Condition "!present_queue_family"` (the 3060 cannot present to the X screen) and Godot falls back to Wayland.
- Log: one line per run in `/tmp/claude-1000/scrapkeep-gpu-queue.log` (and `$SCRAPKEEP_GPU_LOG` if set): `ts gpu= name= need= pid= rc= wall= display=`. Exit code is the command's.
- Self-test: `tools/coordinator/gpu_queue_selftest.sh` (exit 0 on PASS).

## Card table (measured 2026-10-09, Godot 4.7.2, Vulkan Forward+, "Using Device" line)

| nvidia-smi index | card | memory | Godot `--gpu-index` | Godot "Using Device" |
|---|---|---|---|---|
| 0 | RTX 4080 | 16376 MiB | 0 | `#0: NVIDIA - NVIDIA GeForce RTX 4080` |
| 1 | RTX 3060 | 12288 MiB | 1 | `#1: NVIDIA - NVIDIA GeForce RTX 3060` |

Indexes agree. During a capture with `--gpu-index 1`, nvidia-smi showed 674 MiB and 43 % utilization on index 1 only.
