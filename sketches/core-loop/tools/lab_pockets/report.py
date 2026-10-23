"""Write <shape>.md for each lab pocket from build.json, proofs.json and a lab_pockets_test log.

Run from sketches/core-loop:
  godot --headless --path . --script res://tests/lab_pockets_test.gd > /tmp/lab_pockets.log
  python3 tools/lab_pockets/report.py /tmp/lab_pockets.log
"""
import json
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
TITLES = {"half_pipe": "Half pipe", "rolling_wall": "Rolling wall", "crevice": "Crevice", "hazard_field": "Hazard field", "rail_grove": "Rail grove"}


def main():
    log = pathlib.Path(sys.argv[1]).read_text().splitlines()
    proofs = [json.loads(line[len("PROOF "):]) for line in log if line.startswith("PROOF ")]
    section = next((json.loads(line[len("PARK_SECTION "):]) for line in log if line.startswith("PARK_SECTION ")), None)
    verdict = next((line for line in log if line.startswith("lab_pockets_test: ")), "lab_pockets_test: no verdict")
    build = json.loads((HERE / "build.json").read_text())
    spec = json.loads((HERE / "proofs.json").read_text())
    for name, title in TITLES.items():
        b, s = build[name], spec["shapes"][name]
        w, d = s["size_m"]
        rows = [p for p in proofs if p["shape"] == name]
        lines = [
            f"# {title} (lab pocket)",
            "",
            f"Lab-only greybox for Challenge's pocket-against-mobility sweeps. It is not in `assets/registry.json` or any shipping list, and the folder's `.gdignore` keeps Godot from importing or exporting it.",
            "",
            f"- **Size:** {w} x {d} m, {s['cells']} cells of the 8 m lattice. Mojulo frame: x along travel, y lateral, z up, entry at x = 0. In Godot, a mojulo point (x, y, z) is (x, z, -y).",
            f"- **Triangles:** {b['triangles']} (cap 50,000). **File:** `{name}.glb`, {b['bytes']:,} bytes.",
            f"- **Geometry sha256** (positions and indices only): `{b['geometry_sha256']}`",
            f"- **What it is:** {s['note']}",
            "",
            "## Mojulo command",
            "",
            "From `sketches/core-loop`, with Node 22.14 or newer:",
            "",
            "```bash",
            f"python3 tools/lab_pockets/build.py {name}",
            "```",
            "",
            f"That runs `tools/lab_pockets/gen.py`, which writes `recipes/{name}.json`, then calls `npx -y mojulo@3.0.0 call mint_solid` with `{{ kind: 'workbench', spec: <recipe> }}` and `export_model {{ ref, format: 'glb', lit: true }}`. The tool budget is raised to 600 s. It then decodes COLOR_0 from sRGB with gamma 2.2 and drops mojulo's studio plate and cameras. The last build minted `{b['ref']}`.",
            "",
            "## Ball proof",
            "",
            f"`tests/lab_pockets_test.gd`: a 0.92 m ball under gravity 26, with no damping, launched already rolling in headless Jolt. Verdict: `{verdict.split(': ', 1)[-1]}`.",
            "",
            "| Case | Start (m) | Velocity (m/s) | Expected | Result | Peak z (m) | Why |",
            "|---|---|---|---|---|---|---|",
        ]
        for p in rows:
            c = s["cases"][p["case"]]
            ok = p["passed"] == (p["expect"] == "pass")
            lines.append(f"| {p['case']} | {c['start']} | {c['vel']} | {p['expect']} | {'passed' if p['passed'] else 'failed'}{'' if ok else ' (WRONG)'} | {p['peak_z']} | {'; '.join(p['why']) or 'all rules held'} |")
        if name == "half_pipe" and section:
            lines += ["", "## Against the park's half pipe",
                      "",
                      f"Measured by ray on both models (`assets/models/park/half_pipe_concrete.glb` gauges):",
                      "",
                      "| | Lab | Park |", "|---|---|---|",
                      f"| Crest to crest (m) | {section['lab_width']:.2f} | {section['park_width']:.2f} |",
                      f"| Wall over the floor (m) | {section['lab_wall']:.2f} | {section['park_wall']:.2f} |",
                      f"| Floor fall | {section['lab_grade'] * 100:.2f}% | 3% (halfpipes.py GRADE) |",
                      "",
                      "The lab's crest is read on a 0.1 m ray grid, so its width can read up to 0.2 m wide. The lab piece is 64 m long, to fit whole cells; the park's is 60 m."]
        if name == "rail_grove":
            lines += ["", f"Ride paths: the rails' underside stays at least {spec['meta']['ride_clear_m']} m over the walkable floor (DECISIONS, map design veto pass, 23 Oct). The test checks every rail vertex."]
        if name == "crevice":
            lines += ["", "Choke: the guide walls and the slot walls are tagged `slick_*` (mesh names `slick_guide`, `slick_mouth`, `slick_slot`). A lab scene gives them friction 0, as the test does; the floor keeps its grip."]
        (HERE / f"{name}.md").write_text("\n".join(lines) + "\n")
        print("wrote", name + ".md")


if __name__ == "__main__":
    main()
