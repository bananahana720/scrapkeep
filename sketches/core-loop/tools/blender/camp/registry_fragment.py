#!/usr/bin/env python3
"""Turns build_all.sh's CAMP_EXPORT rows into the assets/registry.d/camp.json fragment (rows sorted by path).

Every camp row ships false: the camp scene, its stations and the pet are machine work (wave 19), so nothing loads these yet.
  python3 registry_fragment.py BUILD_LOG > assets/registry.d/camp.json
"""
import json
import sys

RECIPES = {
    "camp_plaza": "plaza", "camp_shortcut": "plaza",
    "camp_launch_gate": "gate_lockers", "camp_lockers": "gate_lockers",
    "camp_moss_stall": "moss", "camp_trophy_wall": "stations", "camp_settings_console": "stations",
    "camp_skee_lane": "skee",
    "camp_pet": "pet", "camp_pet_pen": "pet", "camp_toy_ball": "pet", "camp_toy_wrench": "pet", "camp_toy_tire": "pet",
    "camp_trial_track": "practice", "camp_trial_arch": "practice", "camp_sandbox_yard": "practice", "camp_call_box": "practice",
}


def recipe_for(stem):
    base = stem.replace("_detail1", "").replace("_detail2", "")
    return RECIPES.get(base, "dressing")


def main():
    rows = []
    for line in open(sys.argv[1]):
        if not line.startswith("CAMP_EXPORT "):
            continue
        r = json.loads(line[len("CAMP_EXPORT "):])
        stem = r["file"][:-4]
        rows.append({
            "id": stem,
            "path": "res://assets/models/camp/" + r["file"],
            "class": r["class"],
            "ships": False,
            "loader": "none (camp scene wiring pending, wave 19 machine work)",
            "provenance": {
                "recipe": "tools/blender/camp/%s.py" % recipe_for(stem),
                "notes": "Camp hub kit (storyboard 7, hub ring). Authored procedurally in this repository from kit.Surface parts "
                         "(tools/blender/camp/_camp.py); no imported mesh, texture or scan. assets/models/camp/camp.PROVENANCE.txt. "
                         "sha256 " + r["sha256"],
            },
        })
    rows.sort(key=lambda r: r["path"])
    print(json.dumps({"assets": rows}, indent=1))


if __name__ == "__main__":
    main()
