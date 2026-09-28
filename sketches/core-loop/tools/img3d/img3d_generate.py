"""Image to 3D with microsoft/TRELLIS (v1), mesh-only decode, vertex-coloured GLB export.

Run with ~/.local/share/img3d/venv-trellis1/bin/python through gpu_job.sh.
Usage: img3d_generate.py <out_dir> <name>=<image.png> [...] [--seeds 1,2]
Writes <out_dir>/<name>_s<seed>_raw.glb, <name>_input.png and appends generate.jsonl.
"""
import os

os.environ.setdefault("ATTN_BACKEND", "xformers")
os.environ.setdefault("SPARSE_ATTN_BACKEND", "xformers")
os.environ.setdefault("SPCONV_ALGO", "native")
IMG3D = os.path.expanduser("~/.local/share/img3d")
os.environ.setdefault("TORCH_HOME", os.path.join(IMG3D, "torch-hub"))
os.environ.setdefault("U2NET_HOME", os.path.join(IMG3D, "u2net"))

import argparse
import json
import sys
import time
from pathlib import Path

import numpy as np
import torch
import trimesh
from PIL import Image

sys.path.insert(0, os.path.join(IMG3D, "trellis1"))
from trellis.pipelines import TrellisImageTo3DPipeline  # noqa: E402

Z_UP_TO_Y_UP = np.array([[1, 0, 0], [0, 0, -1], [0, 1, 0]], dtype=np.float32)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("out_dir", type=Path)
    parser.add_argument("inputs", nargs="+", help="name=path/to/image.png")
    parser.add_argument("--seeds", default="1")
    parser.add_argument("--ss-steps", type=int, default=25)
    parser.add_argument("--slat-steps", type=int, default=25)
    args = parser.parse_args()
    args.out_dir.mkdir(parents=True, exist_ok=True)

    load_start = time.time()
    pipeline = TrellisImageTo3DPipeline.from_pretrained("microsoft/TRELLIS-image-large")
    pipeline.cuda()
    load_seconds = round(time.time() - load_start, 1)

    with (args.out_dir / "generate.jsonl").open("a") as log:
        for item in args.inputs:
            name, path = item.split("=", 1)
            image = pipeline.preprocess_image(Image.open(path))
            image.save(args.out_dir / f"{name}_input.png")
            for seed in [int(s) for s in args.seeds.split(",")]:
                torch.cuda.synchronize()
                torch.cuda.reset_peak_memory_stats()
                start = time.time()
                outputs = pipeline.run(
                    image,
                    seed=seed,
                    formats=["mesh"],
                    preprocess_image=False,
                    sparse_structure_sampler_params={"steps": args.ss_steps},
                    slat_sampler_params={"steps": args.slat_steps},
                )
                torch.cuda.synchronize()
                seconds = round(time.time() - start, 1)
                mesh = outputs["mesh"][0]
                vertices = mesh.vertices.detach().float().cpu().numpy() @ Z_UP_TO_Y_UP
                faces = mesh.faces.detach().cpu().numpy()
                colors = (mesh.vertex_attrs[:, :3].clamp(0, 1).detach().float().cpu().numpy() * 255).astype(np.uint8)
                out = args.out_dir / f"{name}_s{seed}_raw.glb"
                trimesh.Trimesh(vertices, faces, vertex_colors=colors, process=False).export(out)
                record = {
                    "name": name,
                    "seed": seed,
                    "source": path,
                    "raw_glb": str(out),
                    "seconds": seconds,
                    "load_seconds": load_seconds,
                    "torch_peak_allocated_mib": torch.cuda.max_memory_allocated() // 2**20,
                    "torch_peak_reserved_mib": torch.cuda.max_memory_reserved() // 2**20,
                    "raw_vertices": int(vertices.shape[0]),
                    "raw_triangles": int(faces.shape[0]),
                }
                log.write(json.dumps(record) + "\n")
                log.flush()
                print(json.dumps(record), flush=True)


if __name__ == "__main__":
    main()
