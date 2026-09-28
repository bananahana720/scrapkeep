# Image-to-3D trial tools

These scripts turn a Style A reference image into a game-budget GLB. They use microsoft/TRELLIS (v1), Blender 5.2.2 and Godot 4.7.2. The trial ran on 2026-09-28 on the RTX 4080 16 GB machine. Results and the verdict are in [TRIAL.md](TRIAL.md). The three trial GLBs sit in `assets/models/trial_img3d_*.glb` and nothing in the game loads them.

## Pipeline

| Step | Script | Runs in | GPU |
| --- | --- | --- | --- |
| License and gate evidence | `fetch_licenses.sh` | curl, plus `venv-trellis1` for the Hugging Face gate check | no |
| Reference image | `gen_reference.py` | `~/.local/share/genai-venv` (Qwen-Image-2.1, nf4 text encoder, fp8 layerwise transformer, VAE tiling, CPU offload) | yes, through `gpu_job.sh` |
| Image to raw mesh | `img3d_generate.py` | `~/.local/share/img3d/venv-trellis1` | yes, through `gpu_job.sh` |
| Cleanup, bake, export | `clean_blender.py` | Blender, headless, `MemoryMax=20G` | no, CPU Cycles bake |
| Turntable, chase still and backface check | `turntable_blender.py` | Blender, headless, `MemoryMax=20G` | no, CPU Cycles |
| Cleanup plus renders per mesh | `run_trial.sh` | wraps the two Blender scripts | no |
| Godot load check | `godot_check.gd` | Godot 4.7.2 headless | no |
| Shared-GPU etiquette | `gpu_job.sh` | wraps any GPU command | yes |

`gpu_job.sh` first takes `/tmp/scrapkeep-gpu.lock` and holds it until the job ends, so the VRAM check and the job cannot be split by another lock holder. While holding the lock it waits in 60 s steps until no process holds more than 3000 MiB and at least `GPU_NEED_MIB` is free. The default of 12000 fits TRELLIS v1; Qwen-Image-2.1 needs 8500. Either wait gives up after 45 minutes with exit 75. The job runs in `systemd-run --user --scope -p MemoryMax=28G -p MemorySwapMax=2G`. The script samples `nvidia-smi` once a second and appends a peak row to `artifacts/local/img3d/logs/gpu-peaks.tsv`. It logs lock requested, lock acquired, each wait step with the free VRAM, and lock released to `gpu-waits.log`. It never signals another process.

The lock only orders jobs that take it. A GPU tenant that skips the lock is still caught by the free-VRAM check, but only at the moment of the check. The trial jobs before this fix used the older gate, which counted processes over 3000 MiB and checked before taking the lock; see VRAM below.

## Rerun

Paths below are relative to the worktree root. Evidence goes to `artifacts/local/img3d/`, which git ignores. These commands produce exactly the three committed picks. GPU sampling uses the same seeds, but it is not guaranteed to be bit-identical across driver or library versions. The Blender steps were rerun on 2026-09-28 and matched the original triangle counts and pre-scale sizes.

```sh
sketches/core-loop/tools/img3d/install_trellis1.sh
sketches/core-loop/tools/img3d/fetch_licenses.sh

T=sketches/core-loop/tools/img3d
E=artifacts/local/img3d
QWEN=~/.local/share/genai-venv/bin/python
TRELLIS=~/.local/share/img3d/venv-trellis1/bin/python
GPU_NEED_MIB=8500 HF_HUB_OFFLINE=1 $T/gpu_job.sh qwen-cliff-prop $QWEN $T/gen_reference.py $E/refs cliff prop --seeds 23
GPU_NEED_MIB=8500 HF_HUB_OFFLINE=1 $T/gpu_job.sh qwen-warden $QWEN $T/gen_reference.py $E/refs warden_clean --seeds 11
HF_HUB_OFFLINE=1 $T/gpu_job.sh trellis-warden $TRELLIS $T/img3d_generate.py $E/raw warden_c=$E/refs/ref_warden_clean_s11.png --seeds 1
HF_HUB_OFFLINE=1 $T/gpu_job.sh trellis-cliff $TRELLIS $T/img3d_generate.py $E/raw cliff_b=$E/refs/ref_cliff_s23.png --seeds 3
HF_HUB_OFFLINE=1 $T/gpu_job.sh trellis-prop $TRELLIS $T/img3d_generate.py $E/raw prop_b=$E/refs/ref_prop_s23.png --seeds 1

$T/run_trial.sh warden_c_s1 6000 7.8 z
$T/run_trial.sh cliff_b_s3 3000 6.0 x --tile-axis x
$T/run_trial.sh prop_b_s1 1000 2.6 z
cp $E/clean/warden_c_s1.glb sketches/core-loop/assets/models/trial_img3d_warden.glb
cp $E/clean/cliff_b_s3.glb sketches/core-loop/assets/models/trial_img3d_cliff.glb
cp $E/clean/prop_b_s1.glb sketches/core-loop/assets/models/trial_img3d_prop.glb

G=~/.local/share/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64
$G --headless --path sketches/core-loop --import
$G --headless --path sketches/core-loop --script res://tools/img3d/godot_check.gd
```

To reproduce the seed search instead of only the picks, pass several seeds, for example `--seeds 1,2,3`, and pick by the turntable sheets.

`run_trial.sh` takes the raw stem, then the triangle budget, the final size in metres along one axis and that axis. Any further flags go to `clean_blender.py`: `--tile-axis`, `--floor-cut`, `--min-island`, `--tex` and `--smooth-angle`. The cleanup scales the mesh and drops loose islands under 1% of the faces. It can cut flat tile ends, decimates by collapse to the budget and smart-UVs the result. It then bakes the vertex colour to a 1024 px base-colour texture from the high-poly mesh. After the bake it rescales so the size axis ends at exactly the requested size. It smooths by angle and exports with the origin at the base centre.

The exported material is single-sided (`doubleSided` absent, and Godot imports it with `cull_mode` back). `clean_blender.py` writes a winding report into `clean/clean.jsonl`: per connected island, the faces, open edges, non-manifold edges and edges whose two faces disagree on winding. For a visual check, run `turntable_blender.py` with `--backface-check`. It renders eight views in which any camera ray that lands on a back face is flat magenta, and it prints the magenta share of object pixels. Cycles ignores the material's backface-culling flag, so this shows where the engine would open a hole.

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

`fetch_licenses.sh` saved every source quoted here to `artifacts/local/img3d/licenses/` on 2026-09-28, with `SHA256SUMS` and `fetch.log` naming each URL or local path. The `file:line` citations below point into that folder. `hf_auth_check.txt` is the Hugging Face gate check, run with the local token.

| Candidate or dependency | Verdict | Quoted line and source |
| --- | --- | --- |
| microsoft/TRELLIS.2 code and TRELLIS.2-4B weights | MIT, usable | `trellis2_LICENSE.txt:1` "MIT License". `trellis2-4B_api.json` card data `license: mit`, `gated: false`. |
| TRELLIS.2 image conditioner `facebook/dinov3-vitl16-pretrain-lvd1689m` | Usable terms, but gated and **blocked** | `dinov3_LICENSE.md:24` "a non-exclusive, worldwide, non-transferable and royalty-free limited license ... to use, reproduce, distribute, copy, create derivative works of, and make modifications to the DINO Materials". `dinov3_LICENSE.md:36` excludes "activities subject to the International Traffic in Arms Regulations (ITAR)" and "military or warfare purposes". `dinov3-vitl16_api.json` has `gated: manual`. `hf_auth_check.txt` "facebook/dinov3-vitl16-pretrain-lvd1689m gated=manual GatedRepoError: 403 Client Error." The TRELLIS.2 configs load it by name, for example `trellis2/configs/gen/ss_flow_img_dit_1_3B_64_bf16.json:72` in the clone. |
| TRELLIS.2 background remover `briaai/RMBG-2.0` | Non-commercial, avoid | `trellis2-4B_pipeline.json` `"rembg_model": {"name": "BiRefNet", "args": {"model_name": "briaai/RMBG-2.0"}}`. `rmbg2_api.json` card data `license_name: bria-rmbg-2.0`, `license_link: https://creativecommons.org/licenses/by-nc/4.0/deed.en`, `gated: auto`. `hf_auth_check.txt` "briaai/RMBG-2.0 gated=auto GatedRepoError: 403". If TRELLIS.2 is ever used, pass RGBA input or swap in `ZhengPeng7/BiRefNet` (`birefnet_api.json` `license: mit`). |
| microsoft/TRELLIS (v1) code and TRELLIS-image-large weights | MIT, usable | `trellis1_LICENSE.txt:5` "Permission is hereby granted, free of charge, to any person obtaining a copy". `trellis1_README.md:329` "TRELLIS models and the majority of the code are licensed under the MIT License." `trellis-image-large_api.json` `license: mit`. |
| DINOv2 ViT-L/14-reg, the v1 image conditioner | Apache-2.0, usable | `dinov2_hub_LICENSE.txt:3` "Apache License", line 4 "Version 2.0, January 2004", copied from the torch-hub checkout. TRELLIS v1 loads `dinov2_vitl14_reg`: the TRELLIS-image-large `pipeline.json` names it as `image_cond_model`, and `trellis/pipelines/trellis_image_to_3d.py:74` in the clone passes that name to `torch.hub.load('facebookresearch/dinov2', ...)`. **Caution:** the same checkout also ships `LICENSE_CELL_DINO_MODELS` ("FAIR Noncommercial Research License", `dinov2_hub_LICENSE_CELL_DINO_MODELS.txt:1`) and `LICENSE_XRAY_DINO_MODEL` ("X-Ray DINO Research License", `dinov2_hub_LICENSE_XRAY_DINO_MODEL.txt:1`). Those cover the Cell-DINO and X-Ray DINO entrypoints that `hubconf.py:9-10` imports, not the weights used here. A future torch-hub call to those entrypoints would pull non-commercial or research-only weights. |
| Vendored FlexiCubes | Apache-2.0, usable | `flexicubes_vendored_LICENSE.txt:2` "Apache License", line 3 "Version 2.0, January 2004". |
| U-2-Net (`u2net.onnx`, loaded by rembg) | Apache-2.0 upstream, usable | The local install is only `u2net.onnx`, with no license file beside it. Upstream `u2net_LICENSE.txt:1` "Apache License", from xuebinqin/U-2-Net. rembg itself is MIT (`rembg_LICENSE.txt:1` "MIT License"). |
| Hunyuan3D 2.0 and 2.1 | Territorial and scale limits, comparison only, not installed | `hunyuan3d-2.1_LICENSE.txt:3` "THIS LICENSE AGREEMENT DOES NOT APPLY IN THE EUROPEAN UNION, UNITED KINGDOM AND SOUTH KOREA AND IS EXPRESSLY LIMITED TO THE TERRITORY". `hunyuan3d-2.1_LICENSE.txt:40` "You must not use, reproduce, modify, distribute, or display the Tencent Hunyuan 3D 2.1 Works, Output or results of the Tencent Hunyuan 3D 2.1 Works outside the Territory." `hunyuan3d-2.1_LICENSE.txt:32` a licensee above "1 million monthly active users" "must request a license from Tencent". The 2.0 license has the same clauses at `hunyuan3d-2.0_LICENSE.txt:3`, `:39` and `:32`. |
| Qwen-Image-2.1 (the reference images) | **Non-commercial.** Fine for this evaluation; do not use it for shipped assets. | `qwen-image-2.1_LICENSE.txt:1` "Qwen RESEARCH LICENSE AGREEMENT". `:19` "create derivative works of, and make modifications to the Materials FOR NON-COMMERCIAL PURPOSES ONLY". `:16` "\"Non-Commercial\" shall mean for research or evaluation purposes only." |

## VRAM

These peaks are measured by `gpu_job.sh`, which reports total GPU memory minus the desktop baseline, and by `torch.cuda.max_memory_reserved`. The card has 16,376 MiB.

| Job | Wall s | Job peak MiB | Total GPU peak MiB | Torch reserved MiB |
| --- | --- | --- | --- | --- |
| Qwen-Image-2.1, 6 images | 366 | 7,195 | 10,816 | 7,786 |
| Qwen-Image-2.1, 3 Warden images | 200 | 8,059 | 10,501 | 7,756 |
| TRELLIS v1, 6 meshes | 75 | 13,325 | 15,674 | 13,016 |
| TRELLIS v1, 4 seed meshes | 58 | 11,918 | 15,661 | 12,738 |
| TRELLIS v1, 4 Warden meshes | 62 | 12,771 | 15,824 | 13,158 |

TRELLIS v1 fits the 16 GB card, with 552 MiB left at the worst measured peak (16,376 minus 15,824). It cannot run beside an ACE-Step render. The gate the trial jobs used did not fully guarantee that. It counted only processes holding more than 3000 MiB each, so several smaller tenants, or ACE-Step split across processes, would have passed it. It also checked before taking the lock. The desktop baseline during the jobs was 2,349 to 3,743 MiB, and every logged wait was "clear after 0s" (`logs/gpu-waits.log`), so no job ran beside another heavy tenant. The current `gpu_job.sh` checks free VRAM under the lock and logs lock events. Its behaviour was tested on a scratch lock: a VRAM shortfall gave exit 75, a held lock was acquired after 5 s, a lock-wait timeout gave exit 75, and the lock stayed held for the job's duration.

`/tmp/scrapkeep-gpu.lock` shows a modification time of 10:07:44, after the last trial job at 09:34. No img3d job ran then. The audio track's `core-loop-v3-audio-3/sketches/core-loop/tools/ace/pack3.py:7` documents the same lock path, so another tenant most likely wrote it. That attribution is inferred, not proven.

TRELLIS.2 states "An NVIDIA GPU with at least 24GB of memory is necessary." (`trellis2_README.md:60`). Its default `low_vram=True` path loads one 1.3B-parameter stage at a time, so a 512³ run may fit 16 GB. This is untested, because the DINOv3 gate stopped the trial before any install.
