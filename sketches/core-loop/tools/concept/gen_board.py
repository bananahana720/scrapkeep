"""Concept board renderer: FLUX.1 schnell on the RTX 4080 (nf4 transformer, bf16 encoders, CPU offload).
python -I gen_board.py <snapshot_dir> <prompts.json> <out_dir>
prompts.json: {"style": "<shared style suffix>", "seeds": [101], "subjects": {"<key>": "<object prompt>", ...}}
Writes <out_dir>/<key>_<seed>.png plus a 320 px JPEG thumbnail <key>_<seed>.t.jpg, and prints one FLUX_JSON line per image.
Generalised from probes/gen2/gen_flux.py (same recipe, same style suffix) so a whole board renders in one queued run."""
import json, os, sys, time
import torch
from diffusers import BitsAndBytesConfig, FluxPipeline, FluxTransformer2DModel
from PIL import Image

snap, spec_path, out_dir = sys.argv[1], sys.argv[2], sys.argv[3]
with open(spec_path) as f:
    spec = json.load(f)
style = spec["style"]
seeds = spec.get("seeds", [101])
subjects = spec["subjects"]
steps = int(spec.get("steps", 4))

t0 = time.time()
quant = BitsAndBytesConfig(load_in_4bit=True, bnb_4bit_quant_type="nf4", bnb_4bit_compute_dtype=torch.bfloat16)
transformer = FluxTransformer2DModel.from_pretrained(snap, subfolder="transformer", quantization_config=quant,
                                                     torch_dtype=torch.bfloat16)
pipe = FluxPipeline.from_pretrained(snap, transformer=transformer, torch_dtype=torch.bfloat16)
pipe.enable_model_cpu_offload()
load_s = time.time() - t0
print("FLUX_LOAD", round(load_s, 1), flush=True)
os.makedirs(out_dir, exist_ok=True)
for key, body in subjects.items():
    for seed in seeds:
        path = os.path.join(out_dir, f"{key}_{seed}.png")
        if os.path.exists(path):
            print("FLUX_SKIP " + path, flush=True)
            continue
        torch.cuda.reset_peak_memory_stats()
        t1 = time.time()
        img = pipe(body + " " + style, height=1024, width=1024, num_inference_steps=steps, guidance_scale=0.0,
                   max_sequence_length=256, generator=torch.Generator("cpu").manual_seed(seed)).images[0]
        dt = time.time() - t1
        img.save(path)
        thumb = img.convert("RGB").resize((320, 320), Image.LANCZOS)
        thumb.save(os.path.join(out_dir, f"{key}_{seed}.t.jpg"), quality=80)
        print("FLUX_JSON " + json.dumps({"subject": key, "seed": seed, "out": path, "seconds": round(dt, 1),
              "peak_alloc_gb": round(torch.cuda.max_memory_allocated() / 2**30, 2), "steps": steps, "size": 1024,
              "device": torch.cuda.get_device_name(0), "load_s": round(load_s, 1)}), flush=True)
