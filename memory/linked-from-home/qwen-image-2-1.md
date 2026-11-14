---
name: qwen-image-2-1
description: "Andrew's pick for best-in-class small local image generation is Qwen-Image-2.1 (7B DiT); how it runs on the RTX 4080"
metadata:
  node_type: memory
  type: reference
  originSessionId: 45199d33-955e-4e58-887a-39edc625fb1b
  modified: 2026-09-22T21:21:38.608Z
---

Andrew named Qwen-Image-2.1 the best-in-class small image generator (2026-09-22). Default to it for local image generation before SDXL or cloud tools.

- HF: `Qwen/Qwen-Image-2.1`, 7B single-stream DiT, bf16, Qwen Research License (fine for personal use). Community GGUFs: `unsloth/Qwen-Image-2.1-GGUF` (Q4_K_M recommended; denoiser only, still needs the VAE + Qwen3-VL text encoder).
- diffusers: `QwenImage21Pipeline` (git diffusers 0.41.0.dev0, transformers 5.17, torch 2.6 cu124 + **torchvision 0.21** (Qwen3VL processor needs it) + bitsandbytes).
- Weights are 33 GB: text encoder is Qwen3-VL-8B at **17 GB bf16**, transformer 14 GB, VAE 1.3 GB. The HF cache uses xet, so `du` on the model dir shows ~5 MB; use `du -shL snapshots/*`.
- **Recipe that works on the 16 GB 4080 (verified 2026-09-22):** `PipelineQuantizationConfig(quant_backend="bitsandbytes_4bit", quant_kwargs={load_in_4bit, nf4, compute bf16}, components_to_quantize=["text_encoder"])` → `pipe.transformer.enable_layerwise_casting(storage_dtype=torch.float8_e4m3fn, compute_dtype=torch.bfloat16)` → `pipe.vae.enable_tiling()` → `pipe.enable_model_cpu_offload()`, with `PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True`. Peak ~10 GB, ~200 s per 2752x1536 image at 40 steps. Plain model offload alone OOMs, because the text encoder can't fit.
- Ultrawide 3440x1440: render 16:9 2752x1536, center-crop 2752x1152, Lanczos resize. Native 3440x1440 snaps to 3424 wide and composes worse (a boxy frame).
- Keep hex color codes out of prompts. Describe colors in words, because the model can render them as text.
- Persistent venv: `~/.local/share/genai-venv` (Python 3.12, rebuilt from `~/.config/omarchy/themes/neon-noir/generate/requirements.lock.txt` with `--extra-index-url https://download.pytorch.org/whl/cu124 --index-strategy unsafe-best-match`). Renders: `~/.local/share/genai-venv/bin/python generate/render.py` or `generate/wan_i2v.py`. Both cap PyTorch at 85% VRAM. Wan 2.2 TI2V-5B needs ftfy + opencv too (in the lock file); 121 frames at 1280x544 take ~8.6 min at 12.3 GB peak.
- Also cached locally: Qwen-Image-Edit-2511 (+ unsloth GGUF), SDXL base.
