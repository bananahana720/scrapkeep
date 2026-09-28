"""Boss concept board: the three family Wardens and the roster, rendered locally with
Qwen-Image 2.1. A copy of render_board.py with its own frames, for
design-v2/WARDEN-DESIGN.md and design-v2/board/BOSS-BOARD.md.

Concept references only. They are never runtime assets and never admission evidence.
Run under the venv and a memory-capped scope, for example:

  PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True systemd-run --user --scope \
    -p MemoryMax=28G -p MemorySwapMax=2G \
    /home/andrew/.local/share/genai-venv/bin/python render_bosses.py --out DIR [--only r1,m1] [--try 1]

--prompts-md PATH writes the prompt record and exits without loading the model.
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

# The player as the hero pass is redrawing it (design-v2/HERO-SPHERE.md, in parallel):
# a clean sphere with the pilot inside and gyro rings, not the lumpy scrap ball.
SPHERE = (
    "a small sleek spherical mech, a clear glass sphere with a small fox pilot seated visible "
    "inside (a fox with pointed ears, a russet muzzle and a work cap, not a human), wrapped by "
    "two thin metal gyroscope rings that orbit it at angles, no legs, no arms, no wheels, with a "
    "faint mint green glow"
)

ANCIENT = (
    "Dull dark petrol grey-green matte enamel, dusty and cracked, with thin glowing electric blue "
    "seams set in dark grooves; cast and seamless, no bolts, no welds, no rivets"
)

BASE = (
    "Its lower half is a wide ancient clamp: four heavy cast jaw plates biting around the base of "
    "the mast, the plates sized to close on a rolling sphere, half buried in sand"
)

HAZARD = "bold diagonal red-orange and black hazard stripes"

REACTOR = (
    "a slumped, hunched reactor hulk, an ancient cast containment vessel fused onto a tall beacon "
    "mast by its own meltdown. " + BASE + ". Above the jaws hunch two massive shoulders: one clean "
    "cast geometry, the other melted into frozen drips of dark slag. On its back three thick vent "
    "stacks swell and glow at their crowns. Its head is a cracked containment dome tilted down "
    "toward the player, split by one jagged crack that leaks intense electric blue light like a "
    "single eye. " + ANCIENT + ". Heat shimmer rises over the vents."
)

HIVE = (
    "a huge ancient drone hive grown around a tall beacon mast. " + BASE + ". Above the jaws rises "
    "a tall honeycomb tower of hexagonal cast cells leaning toward the player, many cells cracked "
    "open and empty, the comb wrapped around the mast. At its top sits a large shuttered hexagonal "
    "iris, dark and closed, the queen cell, with two wide louvred vent wings folded at its sides. "
    "Ten identical small flat triangular drones, each with a thin electric blue seam, hover in the "
    "air in front of it locked in a tight bowling-pin rack formation, apex pointed at the player. "
    "Three bulging hexagonal brood caps glow amber on the deck below the tower. " + ANCIENT + "."
)

MIND = (
    "a tall, thin, terribly still ancient machine at the base of a tall beacon mast, one of the "
    "Mind's hands. " + BASE + ". From the deck rise two long thin many-jointed cast arms: one arm "
    "reaches up and its slender fingers close around the glowing ring at the top of the mast, "
    "holding the light; the other is folded like a mantis forelimb with its hand open toward the "
    "player, palm glowing pale sand. Between the arms a slender jointed stalk arcs forward over "
    "the mast and ends in a lens cluster: one big round glass eye ringed by smaller lenses, one "
    "small lens dead and dark, the big eye lit electric blue and staring straight at the player. "
    + ANCIENT + ". Still, exact, watching."
)

FRAMES = [
    {
        "id": "r1", "kind": "hero", "title": "Reactor Warden: hero shot",
        "seed": 3101,
        "revision": "The machine's four jaw plates grip the base of one tall slender mast with a glowing ring on top. The dome's crack is the only eye. The player's sphere is clean glass with a fox inside and orbiting rings, tiny beside the machine.",
        "prompt": (
            "Low third-person chase view from just behind " + SPHERE + ", rolling across cracked, "
            "blackened ground toward " + REACTOR + " On the ground before it a huge circular danger "
            "zone of " + HAZARD + " fills toward the machine. Menacing, wounded, colossal presence. "
            "Golden hour, long shadows."
        ),
    },
    {
        "id": "r2", "kind": "sheet", "title": "Reactor Warden: design sheet",
        "seed": 3102,
        "revision": "One machine only, no humanoid body, no arms: a clamp of four jaw plates gripping one tall slender beacon mast that rises through it, two hunched shoulders, three vent stacks, a cracked dome. Shown twice: left with the dome closed, right with the dome split open in two halves like petals exposing a glowing blue core sphere.",
        "prompt": (
            "Concept design sheet on a plain neutral warm grey background with a soft floor shadow, "
            "three-quarter view of one ancient war machine shown whole: " + REACTOR + " Beside it, "
            "for scale, " + SPHERE + ". Clean model-sheet presentation."
        ),
    },
    {
        "id": "r3", "kind": "broken", "title": "Reactor Warden: broken state",
        "seed": 3103,
        "revision": "The player sphere is a separate small object in the foreground, apart from the machine, with no legs, no arms, no wheels. The melted shoulder lies on the ground as a sheared slab. The dome is split open with the blue core blazing. Amber cracks glow across the jaw plates. No other machines.",
        "prompt": (
            "Third-person view past " + SPHERE + " of " + REACTOR + " The machine is near defeat: the "
            "melted shoulder has sheared off and lies on the ground as a slab, the dome is split "
            "open permanently with a glowing blue-white reactor core blazing inside, all three vent "
            "stacks are broken and venting continuously, cracks glowing amber run across the jaw "
            "plates, and the ground around it is blackened into fallout craters. Electric blue "
            "light leaks from every wound. Furious, exposed, dying."
        ),
    },
    {
        "id": "h1", "kind": "hero", "title": "Hive Warden: hero shot",
        "seed": 3201,
        "revision": "The hive is a tall honeycomb tower leaning toward the player with a tall slender beacon mast rising through its top. At its top a large shuttered hexagonal iris, dark and closed. Exactly ten small flat triangular drones hover in the air between the hive and the player in a tight triangular rack, apex toward the player. Exactly three amber brood caps on the deck. The player sphere is a separate small object, no legs, no arms.",
        "prompt": (
            "Low third-person chase view from just behind " + SPHERE + ", rolling across a dusty "
            "sandstone basin toward " + HIVE + " A striped lane of " + HAZARD + " runs from the drone "
            "rack toward the sphere. Menacing, many bodies with one will. Golden hour, long shadows."
        ),
    },
    {
        "id": "h2", "kind": "sheet", "title": "Hive Warden: design sheet",
        "seed": 3202,
        "revision": "One machine only, whole, three-quarter view, shown twice: left with the iris shuttered dark and the drone rack in place, right with the drones scattered and the hexagonal iris open like a camera aperture on a swollen glowing blue queen cell.",
        "prompt": (
            "Concept design sheet on a plain neutral warm grey background with a soft floor shadow, "
            "three-quarter view of one ancient war machine shown whole: " + HIVE + " Beside it, for "
            "scale, " + SPHERE + ". Clean model-sheet presentation."
        ),
    },
    {
        "id": "h3", "kind": "broken", "title": "Hive Warden: broken state",
        "seed": 3203,
        "revision": "The player sphere is a separate small object in the foreground, apart from the machine, with no legs, no arms, no wheels. Only three drones remain, drifting with their seams dark. The hexagonal iris at the top is jammed half open on a swollen glowing blue queen cell. One side of the honeycomb is torn away. No other machines.",
        "prompt": (
            "Third-person view past " + SPHERE + " of " + HIVE + " The hive is near defeat: one side "
            "of the honeycomb sheet has sheared away exposing an inner cast lattice, dead cells lie "
            "fallen at its foot, the hexagonal iris is jammed half open on a swollen glowing blue "
            "queen cell, the louvred wings hang broken, and only three drones remain, drifting with "
            "their seams dark. Amber cracks glow across the jaw plates. Furious, exposed, dying."
        ),
    },
    {
        "id": "m1", "kind": "hero", "title": "Mind Warden: hero shot",
        "seed": 3301,
        "revision": "Two thin arms only, no legs, no torso, no humanoid body: the machine is a clamp base with two jointed arms and one lens stalk. The big eye looks at the player's sphere. The player's sphere is clean glass with a fox inside and orbiting rings.",
        "prompt": (
            "Low third-person chase view from just behind " + SPHERE + ", rolling across a dusty "
            "sandstone basin toward " + MIND + " A wedge of " + HAZARD + " on the ground opens from "
            "the open hand toward the sphere. Menacing, still, it already knows you. Golden hour, "
            "long shadows."
        ),
    },
    {
        "id": "m2", "kind": "sheet", "title": "Mind Warden: design sheet",
        "seed": 3302,
        "revision": "One machine only, whole, three-quarter view, no humanoid body, no legs, no torso: a clamp base, two thin jointed arms, one lens stalk. Shown twice: left at rest with the eye half lidded, right braced with both arms crossed in front of the mast and the big eye wide open and blazing.",
        "prompt": (
            "Concept design sheet on a plain neutral warm grey background with a soft floor shadow, "
            "three-quarter view of one ancient war machine shown whole: " + MIND + " Beside it, for "
            "scale, " + SPHERE + ". Clean model-sheet presentation."
        ),
    },
    {
        "id": "m3", "kind": "broken", "title": "Mind Warden: broken state",
        "seed": 3303,
        "revision": "No humanoid body, no legs. One arm sheared at the elbow and hanging by glowing blue cables; the lens housing split open; the fingers of the other arm still clutch the beacon ring. No new machines.",
        "prompt": (
            "Third-person view past " + SPHERE + " of " + MIND + " The machine is near defeat: the "
            "open-handed arm has sheared at the elbow and hangs by glowing blue seam cables, the lens "
            "cluster's shell has split open so the big eye is bare and blazing white-blue, the stalk "
            "is kinked, amber cracks glow down the jaw plates, and the other arm's fingers still "
            "clutch the beacon ring. Furious, exposed, dying."
        ),
    },
    {
        "id": "j1", "kind": "key", "title": "Stage 3 reveal: mortal versus god",
        "seed": 3401,
        "revision": "In the foreground there is only the tiny glass sphere with its fox pilot, alone at the cliff edge, nothing else near it. There is exactly one machine and it stands far below on the basin floor at the mast, seen from above and behind the sphere, its huge blue eye turned up toward the sphere; it dominates the basin by its height and its light. No machine in the foreground, no humanoid body, no legs, no torso.",
        "prompt": (
            "Wide cinematic shot from high behind " + SPHERE + ", tiny, launching off a cliff edge at "
            "the top of a vast canyon basin at dawn. Far below in the basin, at the base of a tall "
            "beacon mast, stands " + MIND + " It has already turned to face the tiny sphere, its huge "
            "electric blue eye lifted toward it, one thin arm holding the mast's glowing ring against "
            "the low sun. Empty sky across the upper third. Mortal against god, insurmountable odds, "
            "a dare to take on the challenge."
        ),
    },
    {
        "id": "x1", "kind": "sheet", "title": "Roster lineup: the ancients and the anti-ball Fleet gear",
        "seed": 3501,
        "revision": "Seven units in one row at the same scale. The drones are a clean arrowhead of six with nothing under them. The Mind's hand has no legs and no body: a cast foot, a thin jointed arm, a lens cluster. Every crew figure is a small animal in a helmet, never a human.",
        "prompt": (
            "Enemy concept lineup of seven units side by side on a plain neutral warm grey background. "
            "The left three are ancient machines, cast and seamless, dull dark petrol grey-green matte "
            "enamel with thin glowing electric blue seams: a squat hunched reactor relic with a "
            "cooling-tower waist and three swelling vent stacks; a tight arrowhead formation of six "
            "identical flat triangular drones hovering; a tall thin many-jointed arm on a cast foot "
            "with a cluster of lenses on top that stares sideways. The right four are workshop-built "
            "Fleet units painted rust red with charcoal parts and one small brass tag plate each, "
            "bolted and welded, crewed by small animal figures in helmets: a hunched figure under a "
            "tall wobbling aerial mast; a figure behind a long low paddle arm; a figure hauling a "
            "hinged floor plate tilted up; a figure setting a spring-jawed cup trap on the ground. "
            "Each silhouette shaped by its tool."
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
        "# Boss concept board: prompts",
        "",
        "Written by `tools/concept/render_bosses.py --prompts-md`. Every frame uses Qwen-Image 2.1, "
        f"{WIDTH}x{HEIGHT}, {STEPS} steps and the seed shown; a retry adds 100 per attempt to the seed. "
        "Every prompt ends with the shared style block below (the primer board's). A retry of a frame "
        "that has a revision inserts the revision and the retry style line before that block. Concept "
        "references only, never runtime assets and never admission evidence.",
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
