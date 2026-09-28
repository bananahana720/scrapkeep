"""Hero sphere paintovers (design-v2/HERO-SPHERE.md), rendered locally with Qwen-Image 2.1.

Concept references only, beside the Blender blockouts that are the readability ground
truth. Never runtime assets and never admission evidence. Same style block, size and
step count as render_board.py; the shared load_pipe/render_one come from the same
renderer. Run under the venv and a memory-capped scope, with at least 11 GB of VRAM
free (nvidia-smi) and one Qwen batch at a time on this GPU:

  PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True systemd-run --user --scope \
    -p MemoryMax=28G -p MemorySwapMax=2G \
    /home/andrew/.local/share/genai-venv/bin/python render_hero.py --out DIR [--only h01,h04] [--try 1]
"""
import argparse
import json
import os
import sys
import time

RENDER_PY_DIR = "/home/andrew/.config/omarchy/themes/neon-noir/generate"

WIDTH, HEIGHT, STEPS = 1344, 768, 30

STYLE = (
    "Stylized chunky low-poly 3D game concept art with tactile hand-built surfaces. "
    "A greasy, workshop-built steam-cyberpunk American Southwest: dusty sandstone, worn paint, "
    "oily dark metal, mismatched bolted panels, weld beads, hose clamps and rubber. "
    "One coherent sunlit lighting condition with long canyon shadows and atmospheric distance. "
    "Readable silhouettes, clean composition. "
    "No text, no letters, no numbers, no logos, no user interface, no watermark."
)
RETRY_STYLE = "Stylized and simplified chunky shapes, painterly, not photorealistic."

SPHERE = (
    "a perfectly round, clear glass sphere the size of a small car, with the animal pilot sitting "
    "upright inside it on a gimbal cradle of two nested hand-forged metal rings, a glowing flywheel "
    "disc under the seat, and thin hand-forged metal rings orbiting outside the sphere at a lean"
)

FRAMES = [
    {
        "id": "h01", "title": "Sable's sphere, rolling",
        "seed": 3001,
        "prompt": (
            "Three-quarter rear view of a small rolling mech, " + SPHERE + ". The pilot is a fox with a "
            "narrow russet face, dark-tipped ears and a close work cap, curled into a felt-lined seat with "
            "her tail wrapped around it, leaning into the turn. The flywheel glows soft mint green. Two clean "
            "circular orbit rings studded with small mint lights lean hard into the turn, and a compact rope "
            "spool sits inside beside her. Rolling fast down a banked sandstone chute, dust kicked up behind."
        ),
        "revision": "The sphere is a single smooth clear glass ball, not a cage and not lumpy scrap. The fox is clearly visible inside the glass.",
    },
    {
        "id": "h02", "title": "Rivet's sphere, sprinting",
        "seed": 3002,
        "prompt": (
            "Side view of a small rolling mech at full sprint, " + SPHERE + ". The pilot is a mole machinist "
            "with a rectangular visor glowing copper, a blunt nose and big digging claws, sitting low in a "
            "dark teal half-bucket cowl inside the glass with four raked copper cooling fins and twin exhaust "
            "stacks behind him, and a straight copper-tipped optical rail pointing forward. Two heavy orbit "
            "rings with copper chevron teeth on their rims and bolted scrap plates riding their tracks, both "
            "banked forward and spinning fast. Copper streaks behind. A flat sandstone straight with a ruined "
            "fence of rusted girders."
        ),
        "revision": "The sphere is a single smooth clear glass ball. The mole is clearly visible inside the glass. The chevron teeth all point the same way, like a saw blade.",
    },
    {
        "id": "h03", "title": "Kest's sphere, gliding",
        "seed": 3003,
        "prompt": (
            "A small rolling mech in mid-air over a canyon drop, " + SPHERE + ". The pilot is a bird with a "
            "swept feather crest, pushed-up goggles and a small hooked beak, standing on a perch bar inside "
            "the glass. Her orbit ring has eight short spikes with amber tips like fuse ends, two cloth "
            "satchels with horizontal amber bands hang from the ring, and the ring's two halves have folded "
            "out sideways into a pair of stiff glide vanes. A short mortar tube sits inside beside her. Amber "
            "glow under the flywheel. A long amber trail behind, sandstone cliffs far below."
        ),
        "revision": "The sphere is a single smooth clear glass ball with the bird clearly visible inside. The satchel bands are horizontal stripes, never diagonal.",
    },
    {
        "id": "h04", "title": "Growth: run start and late run",
        "seed": 3004,
        "prompt": (
            "Two small rolling mechs side by side on a sandstone ledge, both " + SPHERE + ", the same fox pilot "
            "in a work cap sitting in each, the same size in both. Left: a young sphere with one thin bare orbit "
            "ring, a slim gimbal cradle and a dim mint flywheel. Right: the same sphere grown heavy, three orbit "
            "rings stacked at different leans, each ring's track loaded with bolted salvaged armour plates, a "
            "thick gimbal cage inside and a bright mint flywheel lighting the pilot from below. The glass ball is "
            "exactly the same size on both; only the rings, plates and light grew."
        ),
        "revision": "Both glass balls are exactly the same diameter. The fox is clearly visible inside each. The right one has far more rings and plates.",
    },
    {
        "id": "h05", "title": "Tally, the friendly ancient, in Moss's bay",
        "seed": 3005,
        "prompt": (
            "A cozy salvage workshop under amber work lamps. On a turntable pedestal sits a small rolling mech: "
            "a perfectly round clear glass sphere the size of a small car, and inside it, where a pilot would "
            "sit, a barrel-sized ancient machine housing: seamless cast dark teal enamel with one dark unlit "
            "groove running around it, a single round bone-white lens for an eye, and two mismatched bolted-on "
            "salvaged metal arms holding the cradle's controls. The gimbal cradle and the single smooth orbit "
            "ring outside are hand-forged tribal metalwork with worn bone-coloured lights. Tools on pegboards, "
            "a chipped mug, a plant in a tin. Quiet, gentle, a little uncanny."
        ),
        "revision": "The housing inside the sphere is smooth and seamless with no bolts, no welds and no glowing seams; the arms bolted onto it are crude salvage. The sphere is a single clear glass ball.",
    },
    {
        "id": "h06", "title": "Mortal against the god",
        "seed": 3006,
        "prompt": (
            "Wide low-angle shot. In the foreground a tiny rolling mech, " + SPHERE + ", its three orbit rings "
            "spinning, its mint flywheel and the small fox pilot inside glowing warm, racing across a cracked "
            "sandstone floor. Towering over it, filling the frame, a colossal ancient cast machine: layered "
            "seamless dark teal enamel shells with thin glowing electric blue seams set in dark grooves, two "
            "thin jointed arms and a lens cluster tilting down to look at the sphere. Cold blue light against "
            "the sphere's warm small light. The sphere is the only living, handmade thing in the frame."
        ),
        "revision": "The mech is a single small clear glass ball with a fox visible inside, dwarfed by the machine. The machine has no bolts and no glowing colours except thin blue seams.",
    },
]


def full_prompt(frame, attempt=0):
    if attempt >= 1 and frame.get("revision"):
        return frame["prompt"] + " " + frame["revision"] + " " + RETRY_STYLE + " " + STYLE
    return frame["prompt"] + " " + STYLE


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--only", default="")
    ap.add_argument("--try", dest="attempt", type=int, default=0)
    args = ap.parse_args()
    only = {x for x in args.only.split(",") if x}
    frames = [f for f in FRAMES if not only or f["id"] in only]
    os.makedirs(args.out, exist_ok=True)
    sys.path.insert(0, RENDER_PY_DIR)
    import torch
    from render import load_pipe, render_one
    pipe = load_pipe("model")
    log = open(os.path.join(args.out, "renders.jsonl"), "a")
    for f in frames:
        seed = f["seed"] + 100 * args.attempt
        out_path = os.path.join(args.out, "%s_try%d.png" % (f["id"], args.attempt))
        prompt = full_prompt(f, args.attempt)
        dt, vram = render_one(pipe, prompt, WIDTH, HEIGHT, STEPS, seed, out_path)
        row = {"id": f["id"], "seed": seed, "attempt": args.attempt, "seconds": round(dt, 1),
               "peak_vram_gb": round(vram, 2), "out": out_path, "prompt": prompt, "at": time.time()}
        log.write(json.dumps(row) + "\n")
        log.flush()
        print("DONE %s %.1fs vram %.2f GB" % (f["id"], dt, vram), flush=True)
    print("ALL_DONE max_reserved_gb=%.2f" % (torch.cuda.max_memory_reserved() / 1e9), flush=True)


if __name__ == "__main__":
    main()
