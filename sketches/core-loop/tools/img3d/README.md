# Image-to-3D trial tools

These scripts turn a Style A reference image into a game-budget GLB. They use microsoft/TRELLIS (v1), Blender 5.2.2 and Godot 4.7.2. The trial ran on 2026-09-28 on the RTX 4080 16 GB machine. Results and the verdict are in [TRIAL.md](TRIAL.md). The three trial GLBs sit in `assets/models/trial_img3d_*.glb` and nothing in the game loads them.

## Pipeline

| Step | Script | Runs in | GPU |
| --- | --- | --- | --- |
| Reference image | `gen_reference.py` | `~/.local/share/genai-venv` (Qwen-Image-2.1, nf4 text encoder, fp8 layerwise transformer, VAE tiling, CPU offload) | yes, through `gpu_job.sh` |
| Image to raw mesh | `img3d_generate.py` | `~/.local/share/img3d/venv-trellis1` | yes, through `gpu_job.sh` |
| Cleanup, bake, export | `clean_blender.py` | Blender, headless, `MemoryMax=20G` | no, CPU Cycles bake |
| Turntable and chase still | `turntable_blender.py` | Blender, headless, `MemoryMax=20G` | no, CPU Cycles |
| Cleanup plus renders per mesh | `run_trial.sh` | wraps the two Blender scripts | no |
| Godot load check | `godot_check.gd` | Godot 4.7.2 headless | no |
| Shared-GPU etiquette | `gpu_job.sh` | wraps any GPU command | yes |

`gpu_job.sh` waits in 60 s steps while any GPU process holds more than 3000 MiB, for up to 45 minutes. It then holds `/tmp/scrapkeep-gpu.lock` and runs the job in `systemd-run --user --scope -p MemoryMax=28G -p MemorySwapMax=2G`. It samples `nvidia-smi` once a second and appends a peak row to `artifacts/local/img3d/logs/gpu-peaks.tsv`, with waits in `gpu-waits.log`. It never signals another process.

## Rerun

Paths below are relative to the worktree root. Evidence goes to `artifacts/local/img3d/`, which git ignores.

```sh
sketches/core-loop/tools/img3d/install_trellis1.sh

T=sketches/core-loop/tools/img3d
E=artifacts/local/img3d
HF_HUB_OFFLINE=1 $T/gpu_job.sh qwen-refs ~/.local/share/genai-venv/bin/python \
  $T/gen_reference.py $E/refs warden_clean cliff prop --seeds 11,23
HF_HUB_OFFLINE=1 $T/gpu_job.sh trellis1 ~/.local/share/img3d/venv-trellis1/bin/python \
  $T/img3d_generate.py $E/raw warden_c=$E/refs/ref_warden_clean_s11.png \
  cliff_b=$E/refs/ref_cliff_s23.png prop_b=$E/refs/ref_prop_s23.png --seeds 1,2,3
$T/run_trial.sh warden_c_s1 6000 7.8 z
$T/run_trial.sh cliff_b_s3 3000 8.0 x --tile-axis x
$T/run_trial.sh prop_b_s1 1000 2.6 z

G=~/.local/share/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64
$G --headless --path sketches/core-loop --import
$G --headless --path sketches/core-loop --script res://tools/img3d/godot_check.gd
```

`run_trial.sh` takes the raw stem, then the triangle budget, the size in metres along one axis and that axis. Any further flags go to `clean_blender.py`: `--tile-axis`, `--floor-cut`, `--min-island`, `--tex` and `--smooth-angle`. The cleanup scales the mesh and drops loose islands under 1% of the faces. It can cut flat tile ends, decimates by collapse to the budget and smart-UVs the result. It then bakes the vertex colour to a 1024 px base-colour texture from the high-poly mesh, smooths by angle and exports with the origin at the base centre.

Godot's import extracts each GLB's embedded texture beside it, as `trial_img3d_*_trial_img3d_basecolor.png`. Import regenerates those files, so they stay uncommitted.

## What was installed

| Path | Size | Contents |
| --- | --- | --- |
| `~/.local/share/img3d/trellis1` | 1.2 GB | microsoft/TRELLIS at `442aa1e`, recursive clone |
| `~/.local/share/img3d/venv-trellis1` | 7.9 GB | Python 3.10 uv venv: torch 2.6.0+cu124, torchvision 0.21.0, xformers 0.0.29.post3, spconv-cu124 2.3.8, kaolin 0.18.0 (NVIDIA wheel), utils3d at `9a4eb15`, rembg, onnxruntime, open3d, trimesh, `transformers<5`, `numpy<2` |
| `~/.local/share/img3d/torch-hub` | 1.2 GB | DINOv2 ViT-L/14-reg code and weights (`TORCH_HOME`) |
| `~/.local/share/img3d/u2net` | 168 MB | `u2net.onnx` for rembg (`U2NET_HOME`) |
| `~/.local/share/img3d/trellis2` | 822 MB | microsoft/TRELLIS.2 at `75fbf01`, cloned only, no venv, never run |
| `~/.cache/huggingface/hub/models--microsoft--TRELLIS-image-large` | 3.1 GB | TRELLIS v1 weights |
| `/tmp/uv-cache` | 7.9 GB, tmpfs | uv download cache; other installs may share this location |

That is about 15.3 GB on disk plus the uv cache in RAM-backed `/tmp`. The install compiled no CUDA extension, and the system nvcc 13.3 was not used. The mesh-only path does not need nvdiffrast, diffoctreerast, diff-gaussian-rasterization or flash-attn. Kaolin is imported only for `check_tensor`.

Remove everything:

```sh
rm -rf ~/.local/share/img3d
rm -rf ~/.cache/huggingface/hub/models--microsoft--TRELLIS-image-large
rm -rf /tmp/uv-cache   # only if nothing else relies on it; it is tmpfs and clears on reboot anyway
```

## License verdicts

| Candidate or dependency | Verdict | Quoted line and source |
| --- | --- | --- |
| microsoft/TRELLIS.2 code and TRELLIS.2-4B weights | MIT, usable | LICENSE: "MIT License / Copyright (c) Microsoft Corporation." Model card front matter: `license: mit`. |
| TRELLIS.2 image conditioner `facebook/dinov3-vitl16-pretrain-lvd1689m` | Usable terms, but gated and **blocked** | DINOv3 License §1a: "a non-exclusive, worldwide, non-transferable and royalty-free limited license ... to use, reproduce, distribute, copy, create derivative works of". §1b.v excludes ITAR and military uses. Hugging Face lists the repo as `gated: manual`, and the local token has no access. |
| TRELLIS.2 background remover `briaai/RMBG-2.0` | Non-commercial, avoid | Hugging Face card license link is `creativecommons.org/licenses/by-nc/4.0`. The token has no access either. If TRELLIS.2 is ever used, pass RGBA input or swap in `ZhengPeng7/BiRefNet`, which is MIT. |
| microsoft/TRELLIS (v1) code and TRELLIS-image-large weights | MIT, usable | LICENSE: "Permission is hereby granted, free of charge, to any person obtaining a copy of this software". README: "TRELLIS models and the majority of the code are licensed under the MIT License." Model card: `license: mit`. |
| v1 dependencies on this path | Apache-2.0, usable | DINOv2, U-2-Net (`u2net.onnx`) and the vendored FlexiCubes each ship an "Apache License, Version 2.0" file. |
| Hunyuan3D 2.0 and 2.1 | Territorial and scale limits, comparison only, not installed | 2.1 LICENSE: "THIS LICENSE AGREEMENT DOES NOT APPLY IN THE EUROPEAN UNION, UNITED KINGDOM AND SOUTH KOREA". §5c: "You must not use, reproduce, modify, distribute, or display the Tencent Hunyuan 3D 2.1 Works, Output or results ... outside the Territory." A licensee above "1 million monthly active users" must request a license. The 2.0 LICENSE opens with the same territorial clause. |
| Qwen-Image-2.1 (the reference images) | **Non-commercial.** Fine for this evaluation; do not use it for shipped assets. | Local LICENSE, "Qwen RESEARCH LICENSE AGREEMENT", §2a: "create derivative works of, and make modifications to the Materials FOR NON-COMMERCIAL PURPOSES ONLY". §1i: "Non-Commercial shall mean for research or evaluation purposes only." |

## VRAM

These peaks are measured by `gpu_job.sh`, which reports total GPU memory minus the desktop baseline, and by `torch.cuda.max_memory_reserved`.

| Job | Wall s | Job peak MiB | Total GPU peak MiB | Torch reserved MiB |
| --- | --- | --- | --- | --- |
| Qwen-Image-2.1, 6 images | 366 | 7,195 | 10,816 | 7,786 |
| Qwen-Image-2.1, 3 Warden images | 200 | 8,059 | 10,501 | 7,756 |
| TRELLIS v1, 6 meshes | 75 | 13,325 | 15,674 | 13,016 |
| TRELLIS v1, 4 seed meshes | 58 | 11,918 | 15,661 | 12,738 |
| TRELLIS v1, 4 Warden meshes | 62 | 12,771 | 15,824 | 13,158 |

TRELLIS v1 fits the 16 GB card with about 550 to 700 MiB to spare above the desktop baseline. It cannot run beside an ACE-Step render; the 3000 MiB wait gate prevents that. No job waited during this trial.

TRELLIS.2 states "An NVIDIA GPU with at least 24GB of memory is necessary." Its default `low_vram=True` path loads one 1.3B-parameter stage at a time, so a 512³ run may fit 16 GB. This is untested, because the DINOv3 gate stopped the trial before any install.
