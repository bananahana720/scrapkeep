"""Generate Style A reference images for image-to-3D with Qwen-Image-2.1.

Run with ~/.local/share/genai-venv/bin/python through gpu_job.sh.
Usage: gen_reference.py <out_dir> [asset ...] [--seeds 1,2]
"""
import argparse
import json
import time
from pathlib import Path

import torch
from diffusers import QwenImage21Pipeline
from transformers import BitsAndBytesConfig, Qwen3VLForConditionalGeneration

REPO = "Qwen/Qwen-Image-2.1"

STYLE = (
    "Painted workshop miniature style, hand-painted texture, chunky readable forms, "
    "clean silhouette, soft warm studio lighting, isolated game asset centered on a plain "
    "light grey background, whole object in frame, no ground plane, no cast shadow, no text."
)

PROMPTS = {
    "warden": (
        "A single hunched reactor mech called the Warden, three-quarter view from slightly above, "
        "full body visible. A bulbous cracked armor shell made of riveted weathered olive-green and "
        "rust-orange metal plates, glowing electric-blue Cherenkov light leaking through the cracks "
        "and seams, a central steel piston column rising to a small caged antenna with a round "
        "four-segment finial, stubby exhaust smokestacks on its shoulders, four crouched heavy "
        "clawed legs made of sandstone-coloured armor blocks. "
    ),
    "warden_clean": (
        "A single hunched reactor mech called the Warden, three-quarter view from slightly above, "
        "full body visible, standing directly on nothing, floating in empty space. A bulbous cracked "
        "armor shell made of riveted weathered olive-green and rust-orange metal plates, glowing "
        "electric-blue Cherenkov light leaking through the cracks and seams, a central steel piston "
        "column rising to a small caged antenna with a round four-segment finial, short capped exhaust "
        "pipes on its shoulders, four crouched heavy clawed legs made of sandstone-coloured armor "
        "blocks. No smoke, no steam, no base, no pedestal, no display stand. Stylized hand-painted "
        "game character art, "
    ),
    "cliff": (
        "A single chunk of desert sandstone cliff, three-quarter view. A wide rectangular rock block "
        "built from thick horizontal strata in warm ochre, tan and terracotta bands, the top edge an "
        "eroded overhanging lip with a few small green shrub tufts, a flat walkable top surface, "
        "near-vertical layered sides with chunky cracks. "
    ),
    "prop": (
        "A single old lantern on a post, three-quarter view. A sturdy weathered wooden post standing "
        "on a small square sandstone block base, a curved rusty iron bracket arm near the top holding "
        "a hanging brass lantern with warm amber glowing glass panes. "
    ),
}


def load_pipeline():
    text_encoder = Qwen3VLForConditionalGeneration.from_pretrained(
        REPO,
        subfolder="text_encoder",
        quantization_config=BitsAndBytesConfig(
            load_in_4bit=True,
            bnb_4bit_quant_type="nf4",
            bnb_4bit_compute_dtype=torch.bfloat16,
        ),
        dtype=torch.bfloat16,
    )
    pipe = QwenImage21Pipeline.from_pretrained(REPO, text_encoder=text_encoder, dtype=torch.bfloat16)
    pipe.transformer.enable_layerwise_casting(storage_dtype=torch.float8_e4m3fn, compute_dtype=torch.bfloat16)
    pipe.vae.enable_tiling()
    pipe.enable_model_cpu_offload()
    return pipe


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("out_dir", type=Path)
    parser.add_argument("assets", nargs="*", default=["warden", "cliff", "prop"])
    parser.add_argument("--seeds", default="11,23")
    parser.add_argument("--steps", type=int, default=40)
    args = parser.parse_args()
    args.out_dir.mkdir(parents=True, exist_ok=True)

    pipe = load_pipeline()
    records = []
    for asset in args.assets:
        style = STYLE.replace("Painted workshop miniature style, ", "") if asset.endswith("_clean") else STYLE
        prompt = PROMPTS[asset] + style
        for seed in [int(s) for s in args.seeds.split(",")]:
            torch.cuda.reset_peak_memory_stats()
            start = time.time()
            image = pipe(
                prompt=prompt,
                width=1024,
                height=1024,
                num_inference_steps=args.steps,
                generator=torch.Generator("cpu").manual_seed(seed),
            ).images[0]
            path = args.out_dir / f"ref_{asset}_s{seed}.png"
            image.save(path)
            records.append({
                "asset": asset,
                "seed": seed,
                "path": str(path),
                "seconds": round(time.time() - start, 1),
                "torch_peak_reserved_mib": torch.cuda.max_memory_reserved() // 2**20,
                "prompt": prompt,
            })
            print(json.dumps(records[-1]), flush=True)
    (args.out_dir / "references.jsonl").open("a").write("".join(json.dumps(r) + "\n" for r in records))


if __name__ == "__main__":
    main()
