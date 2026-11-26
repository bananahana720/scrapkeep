#!/usr/bin/env python3
"""Every-park intentionality scorecard: counts authored content per park, world, boss and camp.

Static read of a Scrapkeep checkout; no Godot. Run from anywhere:

  python3 -I scorecard.py --repo <scrapkeep checkout> [--json out.json] [--md out.md]

It reads sketches/core-loop and runs scripts/placeholder-gate.mjs --json (needs node).
METHOD.md beside this file says what each number means and how to judge it.
"""
import argparse, collections as C, json, math, os, re, subprocess, sys

PARKS = ["park_dam", "park_flume", "park_pit", "park_sinkhole", "park_islands", "park_crown"]
WORLD_NAMES = {1: "Spillway", 2: "The Dig", 3: "The Highdraft"}
BOSSES = {1: "brindle", 2: "waking", 3: "mind"}
# A park's declared skill line: the route its stage page names as the one test. Its top verb is the verb of that
# line (rows weighted by length), not the most common verb over every row, so anchors and piers beside a line don't
# outvote it. Parks with no declared line keep the row count.
SKILL_LINES = {"park_flume": "flume_whole"}
ROSTERS = ["src/combat/roster.gd", "src/combat/roster_dig.gd", "src/combat/roster_highdraft.gd"]


def read(p):
    with open(p, encoding="utf-8") as f:
        return f.read()


def lines_of(paths):
    return sum(read(p).count("\n") for p in paths if os.path.exists(p))


def park_defs(game):
    """stage, world, map, music ace and pack kinds per stage, from park_defs.gd DEFS."""
    src = read(os.path.join(game, "src/core/park_defs.gd"))
    w1 = re.search(r"const PACKS := \[(.*?)\n\]", src, re.S).group(1)
    elite = re.findall(r'"([a-z_]+)"', re.search(r"const ELITE := \{.*?\[(.*?)\]", src, re.S).group(1))
    rows = []
    for m in re.finditer(r'\{"stage": (\d), "world": (\d), "music": \{"theme": (\d), "ace": "([a-z_]+)"\}.*?"map": "([a-z_]+)"(.*?)"warden_variant"', src, re.S):
        body = m.group(6)
        packs = re.search(r'"packs": ([A-Z_]+|\[.*?\]),\s*"elite"', body, re.S).group(1)
        text = packs
        if packs[0] != "[":
            text = w1 if packs == "PACKS" else re.search(r"const " + packs + r" := \[(.*?)\n\]", src, re.S).group(1)
        kinds = re.findall(r'"kinds": \[(.*?)\]', text)
        rows.append({
            "stage": int(m.group(1)), "world": int(m.group(2)), "theme": int(m.group(3)),
            "ace": m.group(4), "map": m.group(5),
            "pack_count": len(kinds),
            "pack_kinds": sorted({k for ks in kinds for k in re.findall(r'"([a-z_]+)"', ks)}),
        })
    return rows, elite


def roster(game):
    out = {}
    for rel in ROSTERS:
        src = read(os.path.join(game, rel))
        for m in re.finditer(r'"([a-z_]+)": \{"faction"(.*?)"line"', src, re.S):
            b = m.group(2)
            br = re.search(r'"breaks": \[(.*?)\]', b)
            ts = re.search(r'"tests": "([a-z_]*)"', b)
            mech = re.search(r'"mechanic": "([a-z_]*)"', b)
            out[m.group(1)] = {
                "breaks": re.findall(r'"([a-z_]+)"', br.group(1)) if br else [],
                "tests": ts.group(1) if ts else "",
                "mechanic": mech.group(1) if mech else "",
            }
    return out


def cue_resolver(game):
    src = read(os.path.join(game, "src/presentation/music_rows.gd"))
    alias = dict(re.findall(r'"([a-z_]+)": \{"alias": "([a-z_]+)"\}', src))
    defined = set(re.findall(r'^\t"([a-z_]+)": \{', src, re.M))

    def resolve(c):
        seen = set()
        while c in alias and c not in seen:
            seen.add(c)
            c = alias[c]
        return c
    return resolve, defined


def lore(game):
    src = read(os.path.join(game, "src/core/lore_rows.gd"))
    z = C.Counter()
    for kind, zone in re.findall(r'"kind": "([a-z_]+)", "zone": "([0-9]-[0-9])"', src):
        z[(zone, kind)] += 1
    return z


def music(game):
    out = {}
    base = os.path.join(game, "assets/music_ace")
    for d in sorted(os.listdir(base)):
        f = os.path.join(base, d, "manifest.json")
        if os.path.exists(f):
            out[d] = sorted(json.load(open(f)).get("clips", {}).keys())
    return out


def placeholders(repo, game):
    try:
        r = subprocess.run(["node", os.path.join(repo, "scripts/placeholder-gate.mjs"), "--json", "--project", game],
                           capture_output=True, text=True, timeout=300)
        data = json.loads(r.stdout)
    except Exception as e:  # report, don't hide
        return None, str(e)
    per = C.Counter()
    total = 0
    for f in data:
        n = int(f.get("count", 1))
        total += n
        per[f.get("where", "") if f.get("kind") == "park" else "_other"] += n
    return {"total": total, "by_park": dict(per)}, ""


def entropy(counter):
    n = sum(counter.values())
    if not n:
        return 0.0
    return round(-sum(v / n * math.log2(v / n) for v in counter.values() if v), 2)


def score(repo):
    game = os.path.join(repo, "sketches/core-loop")
    defs, elite = park_defs(game)
    by_map = {d["map"]: d for d in defs}
    ros = roster(game)
    resolve, defined_cues = cue_resolver(game)
    lz = lore(game)
    mus = music(game)
    ph, ph_err = placeholders(repo, game)
    parks = json.load(open(os.path.join(game, "src/world/park/park_dam.json")))  # schema probe
    del parks

    # Which parks use each event kind, contraption kind and enemy, for "unique to this park/world".
    loaded = {p: json.load(open(os.path.join(game, f"src/world/park/{p}.json"))) for p in PARKS}
    event_parks = C.defaultdict(set)
    for p, d in loaded.items():
        for e in d["event_rows"]:
            event_parks[e["kind"]].add(p)
    world_of = {p: by_map[p]["world"] for p in PARKS}
    kind_worlds = C.defaultdict(set)
    for p in PARKS:
        d = by_map[p]
        for k in d["pack_kinds"]:
            kind_worlds[k].add(d["world"])
        for h in loaded[p]["home_rows"]:
            kind_worlds[h["enemy"]].add(d["world"])
    for k in elite:
        kind_worlds[k].update({1, 2, 3})

    rsrc = read(os.path.join(game, "src/world/park/park_recipes.gd"))
    efacts = dict(re.findall(r'"([a-z_]+)": "([a-z_]*)"', re.search(r"const ELEMENT_FACTS := \{(.*?)\n\}", rsrc, re.S).group(1)))
    rows = []
    for p in PARKS:
        d, meta = loaded[p], by_map[p]
        pr = d["park_rows"]
        authored = [r for r in pr if r["element"] != "anchor_field"]
        dressed = [r for r in pr if r["recipe"] and not r["recipe"].startswith("greybox")]
        verbs = C.Counter(r["verb"] for r in pr if r["element"] not in ("ground",))
        verbs_auth = C.Counter(r["verb"] for r in authored if r["element"] != "ground")
        top_verb, top_n = (verbs_auth.most_common(1) or [("", 0)])[0]
        top_share = round(top_n / max(1, sum(verbs_auth.values())), 2)
        line = SKILL_LINES.get(p)
        if line:
            via = next((set(rt.get("via", [])) for rt in d["routes"] if rt["id"] == line), set())
            on_line = [r for r in authored if r["element"] != "ground" and (r["id"] in via or line in (r.get("routes") or []))]
            line_verbs = C.Counter()
            for r in on_line:
                line_verbs[r["verb"]] += max(r["size"][0], r["size"][2])
            if line_verbs:
                top_verb, top_n = line_verbs.most_common(1)[0]
                top_share = round(top_n / sum(line_verbs.values()), 2)
        society = [r for r in authored if r["society"] not in ("none", "")]
        frags = [r["fragment"] for r in pr if r["fragment"]] + ([d["landmark"]["fragment"]] if d["landmark"].get("fragment") else [])
        story_frags = [f for f in frags if not f.startswith(("none_", "ref_"))]
        kinds = sorted(set(meta["pack_kinds"]) | {h["enemy"] for h in d["home_rows"]})
        own = [k for k in kinds if kind_worlds[k] == {meta["world"]}]
        cues = set()
        for e in d["event_rows"]:
            cues.update((e.get("music_cue") or {}).values())
        cues_real = {resolve(c) for c in cues}
        zone = f"{meta['world']}-{1 if meta['stage'] % 2 else 2}"
        tests = sorted({ros[k]["tests"] for k in kinds if k in ros and ros[k]["tests"]})
        breaks = sorted({b for k in kinds if k in ros for b in ros[k]["breaks"]})
        contr = C.Counter(c["kind"] for c in d["contraption_rows"])
        rows.append({
            "park": p, "stage": meta["stage"], "world": meta["world"], "world_name": WORLD_NAMES[meta["world"]],
            "landmark": d["landmark"]["id"], "landmark_recipe": d["landmark"]["recipe"],
            "time_of_day": d["time_of_day"],
            # encounters
            "enemy_kinds": kinds, "enemy_kinds_own_world": own, "packs": meta["pack_count"],
            "homes": len(d["home_rows"]), "elite_shared": sorted(elite),
            "verbs_enemies_test": tests, "verbs_enemies_break": breaks,
            # set pieces
            "events": len(d["event_rows"]), "event_kinds": sorted({e["kind"] for e in d["event_rows"]}),
            "event_kinds_only_here": sorted({e["kind"] for e in d["event_rows"] if event_parks[e["kind"]] == {p}}),
            "event_families": sorted({e["family"] for e in d["event_rows"]}),
            "warden_phase_events": [e["id"] for e in d["event_rows"] if e["trigger"]["on"] == "warden_phase"],
            "contraptions": len(d["contraption_rows"]), "contraption_kinds": len(contr),
            "contraption_mix": dict(contr.most_common()),
            "weather": [w["kind"] for w in d["weather_rows"]],
            "activities": [a["activity"] for a in d["activity_rows"]],
            # dressing
            "rows": len(pr), "authored_rows": len(authored), "anchor_fields": len(pr) - len(authored),
            "dressed_rows": len(dressed),
            "ride_fact_share": round(sum(1 for r in authored if r["ride_fact"] or efacts.get(r["element"], "")) / max(1, len(authored)), 2),
            "society_share": round(len(society) / max(1, len(authored)), 2),
            "societies": sorted({r["society"] for r in society}),
            "routes": len(d["routes"]),
            "placeholders": (ph or {}).get("by_park", {}).get(p),
            # discoverables and lore
            "secrets": sum(1 for a in d["activity_rows"] if a["activity"] in ("cracked_cache", "ambush_altar", "hauler_bounty")),
            "fragments": len(frags), "story_fragments": len(story_frags),
            "lore_field_notes": lz.get((zone, "field_note"), 0), "lore_exchanges": lz.get((zone, "exchange"), 0),
            "lore_intros": lz.get((zone, "intro"), 0),
            # music
            "music_sections": len(mus.get(meta["ace"], [])), "music_set": meta["ace"],
            "event_cues_named": len(cues), "event_cues_distinct_sound": len(cues_real),
            "weather_layers_named": sum(1 for w in d["weather_rows"] if w["music_layer"]),
            # skill tests
            "top_verb": top_verb, "top_verb_share": top_share, "skill_line": line or "",
            "verb_spread_bits": entropy(verbs_auth), "verbs": dict(verbs_auth.most_common()),
        })

    bosses = {}
    for w, b in BOSSES.items():
        files = {"brindle": ["src/boss/boss.gd", "src/boss/requisition.gd"],
                 "waking": ["src/boss/waking.gd", "src/boss/waking_floors.gd", "src/boss/waking_dress.gd"],
                 "mind": ["src/boss/mind.gd", "src/boss/mind_attacks.gd", "src/boss/mind_dress.gd"]}[b]
        dress = {"brindle": "arena_bowl_dress.gd", "waking": "arena_waking_dress.gd", "mind": "arena_mind_dress.gd"}[b]
        codex = re.findall(r'"(%s_[a-z_]+)"' % b, read(os.path.join(game, "src/boss/codex_entries.gd")))
        bosses[b] = {
            "world": w, "fight_code_lines": lines_of([os.path.join(game, f) for f in files]),
            "arena_dress_lines": lines_of([os.path.join(game, "src/presentation", dress)]),
            "music_sections": len(mus.get(b, [])), "codex_entries": len(set(codex)),
        }
    fx_src = read(os.path.join(game, "src/presentation/fx_library.gd"))
    fx_ids = re.findall(r'^\t"([a-z_]+)": \{"pool"', fx_src, re.M)
    mats = os.listdir(os.path.join(game, "assets/materials")) + [f for f in os.listdir(os.path.join(game, "src/presentation")) if f.endswith(".gdshader")]
    world_fx = {1: [f for f in fx_ids if f.startswith(("spill", "dam_", "flume"))] + [m for m in mats if m.startswith(("spill", "world_one", "sandstone"))],
                2: [f for f in fx_ids if f.startswith("dig_")] + [m for m in mats if m.startswith("dig")],
                3: [f for f in fx_ids if f.startswith(("net_", "high", "sky_"))] + [m for m in mats if m.startswith("highdraft")]}
    for r in rows:
        r["world_effects"] = len(world_fx[r["world"]])
    camp = {
        "camp_level_files": sorted(f for f in os.listdir(os.path.join(game, "src/world")) if "camp" in f and f.endswith(".gd")),
        "camp_ui_files": sorted(f for f in os.listdir(os.path.join(game, "src/ui")) if "camp" in f and f.endswith(".gd")),
    }
    return {"parks": rows, "bosses": bosses, "camp": camp, "placeholders_total": (ph or {}).get("total"),
            "placeholder_error": ph_err, "global": {
                "auras_in_src": sum(read(os.path.join(dp, f)).lower().count("aura") for dp, _, fs in os.walk(os.path.join(game, "src")) for f in fs if f.endswith(".gd")),
                "music_sets": mus}}


def world_rollup(parks):
    out = {}
    for w in (1, 2, 3):
        ps = [p for p in parks if p["world"] == w]
        out[w] = {k: sum(p[k] or 0 for p in ps) for k in (
            "authored_rows", "dressed_rows", "events", "contraptions", "secrets", "story_fragments",
            "lore_field_notes", "music_sections", "placeholders")}
        out[w]["enemy_kinds_own_world"] = sorted({k for p in ps for k in p["enemy_kinds_own_world"]})
        out[w]["event_kinds_only_here"] = sorted({k for p in ps for k in p["event_kinds_only_here"]})
        out[w]["society_share"] = round(sum(p["society_share"] for p in ps) / len(ps), 2)
    return out


def flags(parks, worlds):
    """Where the Dig or the Highdraft sits clearly (under 70%) below the Spillway."""
    out = []
    base = worlds[1]
    for k in ("authored_rows", "events", "secrets", "story_fragments", "lore_field_notes", "music_sections"):
        for w in (2, 3):
            if base[k] and worlds[w][k] < 0.7 * base[k]:
                out.append(f"{WORLD_NAMES[w]} {k} {worlds[w][k]} vs Spillway {base[k]}")
    for k in ("society_share",):
        for w in (2, 3):
            if base[k] and worlds[w][k] < 0.7 * base[k]:
                out.append(f"{WORLD_NAMES[w]} {k} {worlds[w][k]} vs Spillway {base[k]}")
    for k in ("enemy_kinds_own_world", "event_kinds_only_here"):
        for w in (2, 3):
            if len(worlds[w][k]) < 0.7 * len(base[k]):
                out.append(f"{WORLD_NAMES[w]} {k} {len(worlds[w][k])} vs Spillway {len(base[k])}")
    med = sorted(p["authored_rows"] for p in parks)[len(parks) // 2]
    for p in parks:
        if p["authored_rows"] < 0.5 * med:
            out.append(f"{p['park']} authored_rows {p['authored_rows']} under half the park median {med}")
    return out


def to_md(res):
    P = res["parks"]
    cols = [("World", "world_name"), ("Authored rows (no anchors)", "authored_rows"), ("Dressed rows", "dressed_rows"),
            ("Placeholders", "placeholders"), ("Own-world enemy kinds", lambda p: len(p["enemy_kinds_own_world"])),
            ("Packs", "packs"), ("Events", "events"), ("Event kinds only here", lambda p: len(p["event_kinds_only_here"])),
            ("Contraptions (kinds)", lambda p: f"{p['contraptions']} ({p['contraption_kinds']})"),
            ("Discoverables", "secrets"), ("Story fragments", "story_fragments"), ("Field notes", "lore_field_notes"),
            ("Music sections", "music_sections"), ("World-flavoured effects", "world_effects"), ("Distinct event sounds", "event_cues_distinct_sound"),
            ("Top verb (share)", lambda p: f"{p['top_verb']} ({p['top_verb_share']})" + (f" on {p['skill_line']}" if p.get("skill_line") else "")),
            ("Society share", "society_share"), ("Ride-fact share", "ride_fact_share")]
    out = ["| Measure | " + " | ".join(p["park"].replace("park_", "") for p in P) + " |",
           "| --- |" + " ---: |" * len(P)]
    for label, key in cols:
        vals = [key(p) if callable(key) else p[key] for p in P]
        out.append(f"| {label} | " + " | ".join(str(v) for v in vals) + " |")
    out.append("")
    out.append("| Boss | Fight code lines | Arena dress lines | Music sections | Codex |")
    out.append("| --- | ---: | ---: | ---: | ---: |")
    for b, v in res["bosses"].items():
        out.append(f"| {b} | {v['fight_code_lines']} | {v['arena_dress_lines']} | {v['music_sections']} | {v['codex_entries']} |")
    out.append("")
    out.append(f"Camp: level files {res['camp']['camp_level_files'] or 'none'}; UI files {res['camp']['camp_ui_files']}.")
    out.append(f"Placeholders total: {res['placeholders_total']}. 'aura' mentions in src: {res['global']['auras_in_src']}.")
    out.append("")
    out.append("Flags (Dig or Highdraft under 70% of the Spillway, or a park under half the median):")
    out += [f"- {f}" for f in res["flags"]] or ["- none"]
    return "\n".join(out) + "\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", required=True)
    ap.add_argument("--json")
    ap.add_argument("--md")
    a = ap.parse_args()
    res = score(os.path.abspath(a.repo))
    res["worlds"] = world_rollup(res["parks"])
    res["flags"] = flags(res["parks"], res["worlds"])
    try:
        res["commit"] = subprocess.run(["git", "-C", a.repo, "rev-parse", "--short=8", "HEAD"], capture_output=True, text=True).stdout.strip()
    except Exception:
        res["commit"] = ""
    md = f"Scorecard at {res['commit']}\n\n" + to_md(res)
    if a.json:
        with open(a.json, "w", encoding="utf8") as f:
            json.dump(res, f, indent=1)
    if a.md:
        with open(a.md, "w", encoding="utf8") as f:
            f.write(md)
    sys.stdout.write(md)


if __name__ == "__main__":
    main()
