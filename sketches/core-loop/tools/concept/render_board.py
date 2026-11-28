"""Primer visual board: concept references rendered locally with Qwen-Image 2.1.

Concept references only. They are never runtime assets and never admission evidence.
Run under the venv and a memory-capped scope, for example:

  PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True systemd-run --user --scope \
    -p MemoryMax=28G -p MemorySwapMax=2G \
    $HOME/.local/share/genai-venv/bin/python render_board.py --out DIR [--only f03,s2] [--try 1]

--prompts-md PATH writes the prompt record and exits without loading the model.
"""
import argparse
import json
import os
import sys
import time

RENDER_PY_DIR = os.path.expanduser("~/.config/omarchy/themes/neon-noir/generate")

WIDTH, HEIGHT, STEPS = 1344, 768, 30

STYLE = (
    "Stylized chunky low-poly 3D game concept art with tactile hand-built surfaces. "
    "A greasy, workshop-built steam-cyberpunk American Southwest: dusty sandstone, worn paint, "
    "oily dark metal, mismatched bolted panels, weld beads, hose clamps and rubber. "
    "One coherent sunlit lighting condition with long canyon shadows and atmospheric distance. "
    "Readable silhouettes, clean composition. "
    "No text, no letters, no numbers, no logos, no user interface, no watermark."
)

BALL = (
    "a small irregular rolling ball of welded salvage the size of a car, lopsided with bolted "
    "scrap plates, with a clear glass cockpit dome on top where the animal pilot sits visible"
)

FRAMES = [
    {
        "id": "f01", "kind": "key", "title": "Title",
        "revision": "Each pilot's face is clearly visible through its glass dome: a fox in a cap, a mole with a visor, a bird with goggles. The three balls look clearly different: one ringed by a mint-glowing plate collar with a rope spool, one with raked copper fins, one caged in an open truss with amber-and-black striped satchels. Round, lumpy balls with no wheels.",
        "seed": 1001,
        "prompt": (
            "Wide cinematic title key art. Three small rolling salvage mechs, each " + BALL + ", "
            "rest on a sandstone mesa edge at golden hour, looking out over an enormous river gorge. "
            "Far away, a ruined dam-works tower cluster stands in the gorge, its smooth ancient concrete "
            "towers patched with steam pipes and wooden scaffolds, a small electric blue light at its top. "
            "One mech glows faint mint green at its coil collar, one has copper cooling fins, one carries "
            "amber-striped satchels. Empty sky across the upper third. Awe and adventure, tiny machines "
            "under a vast sky."
        ),
    },
    {
        "id": "f02", "kind": "key", "title": "Character select",
        "seed": 1002,
        "prompt": (
            "A cozy salvage workshop with three round turntable pedestals under amber work lamps. On each "
            "pedestal sits a small rolling salvage mech, " + BALL + ". Left: a fox pilot with a russet "
            "face, dark-tipped ears and a close work cap, in a ball ringed by a collar of bolted plates "
            "with a faint mint green glow and a rope spool on its flank. Middle: a mole pilot with a "
            "rectangular visor and a blunt nose, in a ball with raked copper cooling fins, twin exhaust "
            "stacks and a straight optical rail pointing forward. Right: a bird pilot with a swept feather "
            "crest, pushed-up goggles and a small hooked beak, in a ball inside an open truss frame with "
            "amber-and-charcoal striped satchels and a short mortar tube. Dark oil charcoal floor, tools "
            "on pegboards."
        ),
    },
    {
        "id": "f03", "kind": "key", "title": "Stage 1: the reactor-relic Warden",
        "revision": "The camera is directly behind the player's ball, looking past it toward the machine. The player's ball is worn bone white and charcoal with a faint mint green coil ring, clearly different from the machine. The machine's two jaws clamp around a tall slender beacon mast with a glowing ring on top. The machine is cast and seamless with no bolts.",
        "seed": 1003,
        "prompt": (
            "Third-person chase view from just behind and above a small rolling salvage mech, " + BALL + ", "
            "rolling fast across a dusty sandstone basin toward a huge ancient machine. The machine is a "
            "smooth cast concrete-and-steel clamp with two massive C-shaped jaws gripping a tall beacon "
            "mast, a squat dome on its pivot and three thick vent stacks with heat shimmer. Its dull "
            "teal-green enamel is cracked and dusty, with thin glowing electric blue seams in dark grooves. "
            "On the ground in front of it, a large circular danger zone painted with bold diagonal "
            "red-orange and black hazard stripes. A clear open lane to the right of the danger zone."
        ),
    },
    {
        "id": "f04", "kind": "key", "title": "The vertical gorge",
        "seed": 1004,
        "prompt": (
            "A vertical river gorge with three levels: a shadowy undercroft canal at the bottom, a rocky "
            "ground shelf in the middle and a sky layer of cables above a void. At the center stands the "
            "focal landmark, a ruined dam-works tower cluster of smooth ancient concrete towers overgrown "
            "with steam pipes, wooden scaffolds and repaired catwalks, a small electric blue light on top. "
            "Cable towers string heavy cables across the gorge, and flat hover barges drift between them. "
            "A tiny rolling salvage ball rides a cable line in the foreground to show scale. Green "
            "riverside vegetation below, sandstone walls, cool blue shade in the depths."
        ),
    },
    {
        "id": "f05", "kind": "key", "title": "Fleet reinforcement pack",
        "revision": "The player's ball is worn bone white and charcoal with copper cooling fins, never rust red. The striped disc lies flat on the ground just ahead of the ball. The bola machine is ridden by a small animal crew member in a helmet. The four red-orange corner brackets surround one landing circle on the ground.",
        "seed": 1005,
        "prompt": (
            "Third-person action view of a small rolling salvage mech, " + BALL + ", facing two enemy "
            "machines on a dusty shelf. Left: a squat crew cart painted rust red with a stack of round "
            "metal discs on its back, a brass tag plate bolted on its side; in front of the ball a round "
            "disc on the ground with bold diagonal red-orange and black hazard stripes. Right: a rust red "
            "machine swinging a bola of weights and cords overhead; a dotted arcing trail runs from it to a "
            "landing point marked by four red-orange corner brackets closing in. The enemies are "
            "bolted, welded, stenciled standard-issue gear, crewed by small animal figures in helmets."
        ),
    },
    {
        "id": "f06", "kind": "key", "title": "Moss's workshop bay",
        "revision2": 'Close view of a closed shop counter: the corrugated shutter covers the whole counter opening from top to bottom, and the only opening is a small square hatch in it with darkness behind. The shelf of three parts and the locked hook hang on the rock wall beside the shutter. In the foreground rests a round salvage ball on the ground, no wheels and no legs, a fox pilot visible in its glass dome.',
        "revision": 'The workbench shutter is pulled all the way down and closed, with only the small square hatch cracked open, showing darkness and one glint. The rolling salvage ball at the entrance is round with a glass dome and a fox pilot visible inside, no wheels.',
        "seed": 1006,
        "prompt": (
            "A calm, warm side bay of a salvage workshop carved into a sandstone cliff, lit by amber work "
            "lamps and a shaft of evening light. A long workbench with its rolled-down corrugated metal "
            "shutter and a small square hatch in the shutter, slightly open, dark inside, nobody visible. "
            "Beside the bench, a shelf holding three odd salvaged machine parts on display, and one special "
            "part hanging from a locked hook with a padlock. A small pressure dial gauge on the wall. A "
            "potted plant in a reused tin, a chipped mug, coiled hoses. A small rolling salvage ball parked "
            "at the bay entrance, its pilot visible in the glass cockpit dome. Quiet, cozy, the calm before "
            "the storm."
        ),
    },
    {
        "id": "f07", "kind": "key", "title": "Terrain event: impact crater",
        "revision2": "The player's ball is worn bone white and charcoal, never orange or red. The chunk that landed in the crater is smooth, cast, dull teal-green ancient machinery with thin electric blue seams, cracked open and smoking.",
        "revision": "The hazard stripes are only red-orange and black, with no yellow. A smoking chunk of smooth ancient machinery sits in the crater's center. The ball leaves a short amber streak.",
        "seed": 1007,
        "prompt": (
            "A dramatic terrain event on a sandstone shelf: a huge chunk of ancient smooth machinery has "
            "just slammed into the ground, leaving a fresh smooth crater bowl with dust still rising and "
            "debris settling. The crater rim is clean enough to ride like a halfpipe. A small rolling "
            "salvage ball, " + BALL + ", rides up the crater wall at speed with a short amber trail. Across "
            "the shelf, a narrow strip of ground marked with bold diagonal red-orange and black hazard "
            "stripes shows where a cliff section is about to collapse. Dust, but the ball, the crater and "
            "the striped strip stay clearly readable."
        ),
    },
    {
        "id": "f08", "kind": "key", "title": "Brindle's arena",
        "seed": 1008,
        "prompt": (
            "A huge open quarry arena under a hazy sky. At the far end stands an enormous armored war "
            "machine assembled by a military fleet: rust red plating, heavy brass trim and brass stenciled "
            "tag plates, furnace vents glowing, crane arms and clamps. A small badger commander in a brass "
            "captain's cap sits in a high armored cabin with a window. One of its chest plates is cracked, "
            "showing a thin electric blue glowing seam behind it. A long straight lane on the ground in "
            "front of it is filling with bold diagonal red-orange and black hazard stripes. In the "
            "foreground, a small rolling salvage ball, " + BALL + ", faces it. Tiny against the machine, "
            "defiant."
        ),
    },
    {
        "id": "s1", "kind": "sheet", "title": "Sheet: three pilots and shells",
        "seed": 2001,
        "prompt": (
            "Character concept sheet, three rolling salvage mechs side by side at the same scale, front "
            "three-quarter view, on a plain neutral warm grey background with a soft floor shadow. Each is "
            + BALL + ". Left: fox pilot, russet face, dark-tipped ears, work cap; the ball has a collar of "
            "felt-lined bolted plates with a faint mint green glow and a compact rope spool on its flank. "
            "Middle: mole pilot, rectangular visor, blunt nose, an instrument cable from the visor; the "
            "ball has raked copper cooling fins, twin exhaust stacks and a straight optical rail forward to "
            "a cutting lens. Right: bird pilot, swept feather crest, pushed-up goggles, small hooked beak; "
            "the ball sits in an open truss cage with amber-and-charcoal striped satchels, a short mortar "
            "tube and a folded glide vane on top. Clean model-sheet presentation."
        ),
    },
    {
        "id": "s2", "kind": "sheet", "title": "Sheet: the three ancient families",
        "revision": "The Mind's hands has no legs and no humanoid body: it is a slender vertical pylon rooted in the ground with many long jointed arms branching from it. All three machines carry thin electric blue seams. The drones fly in a clean arrowhead.",
        "seed": 2002,
        "prompt": (
            "Enemy concept sheet of three ancient machines built long ago by humans, side by side on a plain "
            "neutral grey background. All three are smooth, seamless, cast and geometric, no bolts, no "
            "welds, dull teal-green enamel that is cracked, buried and dusty, with thin glowing electric "
            "blue seams set in dark grooves. Left: a squat heavy reactor relic, low domes, a cooling-tower "
            "waist and thick vent stacks with heat shimmer. Middle: a swarm remnant, many small identical "
            "flat triangular drones flying in a tight arrowhead formation above a honeycomb hive housing. "
            "Right: the Mind's hands, a tall thin machine of many-jointed manipulator arms with a cluster "
            "of round camera lenses at the top. Each silhouette completely different."
        ),
    },
    {
        "id": "s3", "kind": "sheet", "title": "Sheet: Fleet crew units",
        "seed": 2003,
        "prompt": (
            "Enemy concept lineup of seven workshop-built military units side by side on a plain neutral "
            "grey background, all painted rust red with charcoal parts and one small brass stenciled tag "
            "plate each, bolted and welded standard-issue gear, crewed by small animal figures in helmets. "
            "From left: a cart with a stack of round magnetic discs; a harpoon gun on a tall anchor post; "
            "two masts with a crackling net strung between; a figure spinning a bola overhead; a hulking "
            "unit with thick layers of bolted plating; a unit behind a big curved dish shield; a small "
            "flying rotor drone with a winch drum slung beneath. Each silhouette shaped by its tool."
        ),
    },
    {
        "id": "s4", "kind": "sheet", "title": "Sheet: the dam-works tower landmark",
        "seed": 2004,
        "prompt": (
            "Environment concept sheet of a single landmark: a ruined dam-works tower cluster standing in a "
            "sandstone river gorge. The core is smooth ancient concrete towers and a cracked spillway built "
            "long ago, dull teal-green enamel with thin electric blue glowing seams. Grown over it are later "
            "repairs by a salvage community: steam pipes, wooden scaffolds, copper plumbing, catwalks, "
            "winches and cable lines running off to the gorge walls, a small electric blue beacon light at "
            "the top. Green vegetation along the river below. Presented as a clean three-quarter view."
        ),
    },
]


RETRY_STYLE = "Stylized and simplified chunky shapes, painterly, not photorealistic."


def full_prompt(frame, attempt=0):
    if attempt >= 2 and frame.get("revision2"):
        return frame["prompt"] + " " + frame["revision2"] + " " + RETRY_STYLE + " " + STYLE
    if attempt and frame.get("revision"):
        return frame["prompt"] + " " + frame["revision"] + " " + RETRY_STYLE + " " + STYLE
    return frame["prompt"] + " " + STYLE


def write_prompts_md(path):
    lines = [
        "# Primer visual board: prompts",
        "",
        "Written by `tools/concept/render_board.py --prompts-md`. Every frame uses Qwen-Image 2.1, "
        f"{WIDTH}x{HEIGHT}, {STEPS} steps and the seed shown; a retry adds 100 per attempt to the seed. "
        "Every prompt ends with the shared style block below. A retry of a frame that has a revision "
        "inserts the revision and the retry style line before that block. Concept references only, "
        "never runtime assets and never admission evidence.",
        "",
        "## Shared style block",
        "",
        STYLE,
        "",
    ]
    for f in FRAMES:
        lines += [f"## {f['id']}: {f['title']}", "", f"Seed {f['seed']}.", "", f["prompt"], ""]
        if f.get("revision"):
            lines += ["Retries add:", "", f["revision"] + " " + RETRY_STYLE, ""]
        if f.get("revision2"):
            lines += ["The second retry adds this instead:", "", f["revision2"] + " " + RETRY_STYLE, ""]
    with open(path, "w") as fh:
        fh.write("\n".join(lines))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out")
    ap.add_argument("--only", default="")
    ap.add_argument("--try", dest="attempt", type=int, default=0)
    ap.add_argument("--prompts-md")
    args = ap.parse_args()

    if args.prompts_md:
        write_prompts_md(args.prompts_md)
        return

    wanted = {x for x in args.only.split(",") if x}
    frames = [f for f in FRAMES if not wanted or f["id"] in wanted]
    os.makedirs(args.out, exist_ok=True)

    sys.path.insert(0, RENDER_PY_DIR)
    import torch
    from render import load_pipe, render_one

    t_load = time.time()
    pipe = load_pipe("model")
    print(f"PIPE_LOADED {time.time() - t_load:.1f}s", flush=True)

    log_path = os.path.join(args.out, "render_log.ndjson")
    for f in frames:
        seed = f["seed"] + 100 * args.attempt
        out_path = os.path.join(args.out, f"{f['id']}_t{args.attempt}.png")
        dt, vram = render_one(pipe, full_prompt(f, args.attempt), WIDTH, HEIGHT, STEPS, seed, out_path)
        rec = {"id": f["id"], "attempt": args.attempt, "seed": seed, "time_s": round(dt, 1),
               "peak_vram_gb": round(vram, 2), "out": out_path}
        with open(log_path, "a") as fh:
            fh.write(json.dumps(rec) + "\n")
        print("DONE " + json.dumps(rec), flush=True)
    print(f"ALL_DONE max_reserved_gb={torch.cuda.max_memory_reserved() / 1e9:.2f}", flush=True)


if __name__ == "__main__":
    main()
