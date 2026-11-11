"""Pass B economy analysis: reads run.sh output and writes a per-run table, per-type medians,
per-game-minute rates carried to 10 game hours, flags, and SVG charts.

    python3 -I docs/systems-audit/economy/analyse.py <runs-dir> <out-dir> [<label>]

<runs-dir> holds <type>-<seed>/econ-<seed>.ndjson and bots.ndjson (run.sh). Writes
<out-dir>/<label>-runs.json, <label>-summary.json and <label>-*.svg.
"""
import collections
import glob
import json
import os
import statistics
import sys

TYPES = ["rusher", "completionist", "minmax"]
COLORS = {"rusher": "#d1495b", "completionist": "#2e86ab", "minmax": "#3c9d5d"}
NAMES = {"rusher": "Rusher", "completionist": "Completionist", "minmax": "Min-maxer"}


def load(path):
    rows = []
    if os.path.exists(path):
        for line in open(path):
            try:
                rows.append(json.loads(line))
            except ValueError:
                pass
    return rows


def cog_source(r):
    if r.get("source") == "unsignalled":
        return "activities, events, start pick"
    a = r.get("amount", 0)
    if a == 1:
        return "kill and boss gears"
    if a == 20 * r.get("stage", 0):
        return "discovery bursts (by amount)"
    return "other pickups (folded gears, Brindle piles)"


def one_run(d):
    name = os.path.basename(d.rstrip("/"))
    typ, seed = name.rsplit("-", 1)
    rows = []
    for f in glob.glob(os.path.join(d, "econ-*.ndjson")):
        rows += load(f)
    bots = load(os.path.join(d, "bots.ndjson"))
    if not rows or not bots:
        return None
    b = bots[0]
    end = rows[-1]
    earned = collections.Counter()
    for r in rows:
        if r["kind"] == "cogs+":
            earned[cog_source(r)] += r.get("amount", 0)
    buys = [r for r in rows if r["kind"] == "buy"]
    spent = collections.Counter()
    for r in buys:
        spent[r["what"]] += r.get("price", 0)
    other_spend = sum(r.get("amount", 0) for r in rows if r["kind"] == "cogs-") - sum(spent.values())
    if other_spend > 0:
        spent["other"] += other_spend
    bays = [r for r in rows if r["kind"] == "bay"]
    bay_visits = []
    for bay in bays:
        after = [r for r in buys if r["stage"] == bay["stage"]]
        unbought = [r for r in rows if r["kind"] == "no_buy" and r["what"] == "shelf" and r["stage"] == bay["stage"]]
        sold = [r for r in rows if r["kind"] == "weigh" and r["stage"] == bay["stage"]]
        bay_visits.append({"stage": bay["stage"], "wallet": bay["cogs"], "spent": sum(r["price"] for r in after),
            "presses": len(sold), "mass_sold": sum(r.get("mass_sold", 0) for r in sold), "scale_cogs": sum(r.get("paid", 0) for r in sold),
            "heft_on_boarding": bay.get("heft"),
            "bought": len([r for r in after if r["what"] != "reroll"]), "left_on_shelf": len(unbought),
            "unbought_cost": sum(r.get("price", 0) for r in unbought),
            "hook": next((r.get("why", "") or "bought" for r in rows if r["kind"] in ("buy", "no_buy") and r.get("what") == "top" and r["stage"] == bay["stage"]), "")})
    parts = collections.Counter(r.get("source") for r in rows if r["kind"] == "part+")
    cores = collections.Counter(r.get("source") for r in rows if r["kind"] == "core+")
    # A core held at a stage entry is wiped there (run_state enter_stage): the row before the entry holds it.
    cores_wiped = 0
    prev = None
    for r in rows:
        if r["kind"] == "stage" and prev is not None and not r.get("retry"):
            cores_wiped += prev.get("cores", 0)
        prev = r
    lost = collections.Counter()
    for r in rows:
        if r["kind"] == "scrap-":
            lost[r.get("cause")] += r.get("amount", 0)
    # Newer ledgers carry running totals: hp_healed (regen and heals, every tick) and max_hp_grown.
    # Older ones only logged single-tick rises over 0.5 hull ("heal" rows), which miss regen.
    heal = end.get("hp_healed")
    big_heals = sum(r.get("amount", 0) for r in rows if r["kind"] == "heal")
    weighs = [r for r in rows if r["kind"] == "weigh"]
    stages = b.get("stages", [])
    boss = b.get("boss") or {}
    wall_trace = [(r["t"], r["cogs"]) for r in rows]
    return {
        "run": name, "type": typ, "seed": int(seed), "pilot": b.get("class"), "outcome": b.get("outcome"),
        "stage_reached": b.get("stage_reached"), "won_world1": b.get("stage_reached", 0) >= 3,
        "game_min": round(float(b.get("game_seconds") or end["t"]) / 60.0, 2), "min_hp": b.get("min_hp"),
        "hits": sum(s.get("hits", 0) or 0 for s in stages), "hp_lost": round(sum(s.get("hp_lost", 0) or 0 for s in stages), 1),
        "hull_lost": round(sum(s.get("hull_lost", 0) or 0 for s in stages), 1),
        "brindle_s": boss.get("defeated_s"), "brindle_hits": boss.get("hits"),
        "cogs_earned": sum(earned.values()), "cogs_earned_by": dict(earned), "cogs_spent": sum(spent.values()),
        "cogs_spent_by": dict(spent), "cogs_end": end["cogs"], "bay_visits": bay_visits,
        "scrap_end": end["scrap"], "mass_end": end["mass"], "heft_end": end.get("heft"), "scrap_lost_by": dict(lost),
        "parts_end": end["parts"], "parts_by": dict(parts), "panels_end": end["panels"], "cores_by": dict(cores),
        "cores_gained": sum(cores.values()), "cores_wiped": cores_wiped, "tree_end": len([r for r in rows if r["kind"] == "tree+"]) or end.get("tree", 0),
        "relics_end": end["relics"], "regen_and_heals_hp": round(heal, 1) if heal is not None else None, "big_heals_hp": round(big_heals, 1),
        "max_hp_grown": end.get("max_hp_grown"), "max_hp_end": end.get("max_hp"),
        "presses": len(weighs), "mass_sold": sum(r.get("mass_sold", 0) for r in weighs), "scale_cogs": sum(r.get("paid", 0) for r in weighs),
        "start_pick": next((r["id"] for r in rows if r["kind"] == "start_pick"), ""),
        "rib_caches": sum(s.get("rib_caches_taken", 0) or 0 for s in stages),
        "rogues": sum(s.get("rogues_beaten", 0) or 0 for s in stages),
        "secrets": sum(len(s.get("secrets_found") or []) for s in stages),
        "trace": wall_trace,
    }


def med(xs):
    xs = [x for x in xs if x is not None]
    return round(statistics.median(xs), 2) if xs else None


def rng(xs):
    xs = [x for x in xs if x is not None]
    return [round(min(xs), 2), round(max(xs), 2)] if xs else None


def summarise(runs):
    out = {}
    for t in TYPES:
        rs = [r for r in runs if r["type"] == t]
        if not rs:
            continue
        mins = sum(r["game_min"] for r in rs)
        s = {"runs": len(rs), "wins": sum(1 for r in rs if r["won_world1"]), "game_min": med([r["game_min"] for r in rs]),
            "game_min_range": rng([r["game_min"] for r in rs]), "game_hours_total": round(mins / 60.0, 2)}
        for k in ["cogs_earned", "cogs_spent", "cogs_end", "parts_end", "panels_end", "cores_gained", "cores_wiped", "tree_end",
                  "relics_end", "min_hp", "hits", "hp_lost", "hull_lost", "brindle_s", "scrap_end", "mass_end", "heft_end",
                  "regen_and_heals_hp", "big_heals_hp", "max_hp_grown", "max_hp_end", "rib_caches", "rogues", "secrets",
                  "presses", "mass_sold", "scale_cogs"]:
            s[k] = med([r[k] for r in rs])
            s[k + "_range"] = rng([r[k] for r in rs])
        # Rates per game minute, pooled over every run of the type, then carried to 10 game hours.
        totals = collections.Counter()
        for r in rs:
            for k in ["cogs_earned", "cogs_spent", "parts_end", "panels_end", "cores_gained", "cores_wiped", "tree_end", "relics_end",
                      "scrap_end", "hp_lost", "hull_lost", "regen_and_heals_hp", "big_heals_hp", "max_hp_grown", "mass_sold", "scale_cogs"]:
                totals[k] += r[k] or 0
            for src, n in r["parts_by"].items():
                totals["parts:" + str(src)] += n
            for src, n in r["cogs_earned_by"].items():
                totals["cogs:" + src] += n
            for src, n in r["cogs_spent_by"].items():
                totals["spent:" + src] += n
        s["per_min"] = {k: round(v / mins, 3) for k, v in sorted(totals.items())}
        s["per_10h"] = {k: round(v / mins * 600) for k, v in sorted(totals.items())}
        visits = [v for r in rs for v in r["bay_visits"]]
        if visits:
            s["bay"] = {st: {"visits": len([v for v in visits if v["stage"] == st]),
                "wallet": med([v["wallet"] for v in visits if v["stage"] == st]),
                "spent": med([v["spent"] for v in visits if v["stage"] == st]),
                "spent_share": med([v["spent"] / v["wallet"] if v["wallet"] else 0 for v in visits if v["stage"] == st]),
                "left_on_shelf": med([v["left_on_shelf"] for v in visits if v["stage"] == st]),
                "presses": med([v["presses"] for v in visits if v["stage"] == st]),
                "mass_sold": med([v["mass_sold"] for v in visits if v["stage"] == st]),
                "hook_bought": sum(1 for v in visits if v["stage"] == st and v["hook"] == "bought"),
                "bought_out": sum(1 for v in visits if v["stage"] == st and v["left_on_shelf"] == 0)}
                for st in sorted({v["stage"] for v in visits})}
        s["start_picks"] = dict(collections.Counter(r["start_pick"] for r in rs if r["start_pick"]))
        s["pilots"] = dict(collections.Counter(r["pilot"] for r in rs))
        out[t] = s
    return out


def flags(summary):
    f = []
    for t, s in summary.items():
        if s["cogs_end"] and s["cogs_spent"] is not None and s["cogs_end"] > 2 * max(1, s["cogs_spent"]):
            f.append({"flag": "hoarding", "type": t, "detail": "median %d cogs held at the end against %d spent" % (s["cogs_end"], s["cogs_spent"])})
        if s.get("cores_gained") == 0:
            f.append({"flag": "dead currency", "type": t, "detail": "median 0 cores gained"})
        for st, b in (s.get("bay") or {}).items():
            if b["bought_out"] * 2 >= b["visits"]:
                f.append({"flag": "inflation", "type": t, "detail": "stage %s shelf bought out in %d of %d visits (median %.0f%% of the wallet spent)"
                          % (st, b["bought_out"], b["visits"], 100 * b["spent_share"])})
        win = s["wins"] / s["runs"]
        if win > 0.6:
            f.append({"flag": "wins over 60%", "type": t, "detail": "%d of %d runs cleared world 1" % (s["wins"], s["runs"])})
    return f


# ---- SVG charts (no plotting library on the cloud box) ----

def svg_lines(runs, path, title, ylabel, key="trace", ymax=None):
    W, H, L, B, T, R = 720, 380, 64, 44, 40, 150
    xmax = max(t for r in runs for t, _ in r[key]) / 60.0
    ymax = ymax or max(c for r in runs for _, c in r[key]) * 1.05
    sx = lambda x: L + (W - L - R) * x / xmax
    sy = lambda y: H - B - (H - B - T) * y / ymax
    out = ['<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" font-family="sans-serif" font-size="12">' % (W, H),
           '<rect width="100%" height="100%" fill="#fff"/>', '<text x="%d" y="22" font-size="15" font-weight="bold">%s</text>' % (L, title)]
    for i in range(6):
        y = ymax * i / 5
        out.append('<line x1="%d" x2="%d" y1="%.1f" y2="%.1f" stroke="#e4e4e4"/>' % (L, W - R, sy(y), sy(y)))
        out.append('<text x="%d" y="%.1f" text-anchor="end">%d</text>' % (L - 6, sy(y) + 4, y))
    for m in range(0, int(xmax) + 1, 2):
        out.append('<text x="%.1f" y="%d" text-anchor="middle">%d</text>' % (sx(m), H - B + 16, m))
    out.append('<text x="%d" y="%d" text-anchor="middle">game minutes</text>' % ((L + W - R) / 2, H - 8))
    out.append('<text x="14" y="%d" transform="rotate(-90 14 %d)" text-anchor="middle">%s</text>' % ((H - B + T) / 2, (H - B + T) / 2, ylabel))
    for r in runs:
        pts = " ".join("%.1f,%.1f" % (sx(t / 60.0), sy(c)) for t, c in r[key][::5] + r[key][-1:])
        out.append('<polyline fill="none" stroke="%s" stroke-opacity="0.35" stroke-width="1.2" points="%s"/>' % (COLORS[r["type"]], pts))
    for i, t in enumerate(TYPES):
        y = T + 10 + i * 22
        out.append('<rect x="%d" y="%d" width="14" height="4" fill="%s"/><text x="%d" y="%d">%s</text>' % (W - R + 14, y, COLORS[t], W - R + 34, y + 6, NAMES[t]))
    out.append("</svg>")
    open(path, "w").write("\n".join(out))


def svg_bars(groups, path, title, ylabel):
    """groups: [(label, [(series_name, value, color)])]"""
    W, H, L, B, T = 720, 380, 64, 64, 40
    ymax = max(v for _, ss in groups for _, v, _ in ss) * 1.1 or 1
    gw = (W - L - 20) / len(groups)
    sy = lambda y: H - B - (H - B - T) * y / ymax
    out = ['<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" font-family="sans-serif" font-size="12">' % (W, H),
           '<rect width="100%" height="100%" fill="#fff"/>', '<text x="%d" y="22" font-size="15" font-weight="bold">%s</text>' % (L, title)]
    for i in range(6):
        y = ymax * i / 5
        out.append('<line x1="%d" x2="%d" y1="%.1f" y2="%.1f" stroke="#e4e4e4"/>' % (L, W - 20, sy(y), sy(y)))
        out.append('<text x="%d" y="%.1f" text-anchor="end">%d</text>' % (L - 6, sy(y) + 4, y))
    out.append('<text x="14" y="%d" transform="rotate(-90 14 %d)" text-anchor="middle">%s</text>' % ((H - B + T) / 2, (H - B + T) / 2, ylabel))
    for g, (label, series) in enumerate(groups):
        bw = gw * 0.8 / len(series)
        for k, (name, v, color) in enumerate(series):
            x = L + g * gw + gw * 0.1 + k * bw
            out.append('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="%s"/>' % (x, sy(v), bw - 2, H - B - sy(v), color))
            out.append('<text x="%.1f" y="%.1f" text-anchor="middle" font-size="10">%d</text>' % (x + bw / 2 - 1, sy(v) - 3, v))
            out.append('<text x="%.1f" y="%d" text-anchor="middle" font-size="10">%s</text>' % (x + bw / 2 - 1, H - B + 14, name))
        out.append('<text x="%.1f" y="%d" text-anchor="middle" font-weight="bold">%s</text>' % (L + g * gw + gw / 2, H - B + 34, label))
    out.append("</svg>")
    open(path, "w").write("\n".join(out))


def main():
    runs_dir, out_dir = sys.argv[1], sys.argv[2]
    label = sys.argv[3] if len(sys.argv) > 3 else "before"
    os.makedirs(out_dir, exist_ok=True)
    runs = [r for r in (one_run(d) for d in sorted(glob.glob(os.path.join(runs_dir, "*-*/")))) if r]
    summary = summarise(runs)
    result = {"label": label, "runs": len(runs), "summary": summary, "flags": flags(summary)}
    json.dump([{k: v for k, v in r.items() if k != "trace"} for r in runs], open(os.path.join(out_dir, label + "-runs.json"), "w"), indent=1)
    json.dump(result, open(os.path.join(out_dir, label + "-summary.json"), "w"), indent=1)
    svg_lines(runs, os.path.join(out_dir, label + "-cogs-held.svg"), "Cogs held through world 1 (%s, one line per run)" % label, "cogs held")
    svg_bars([(NAMES[t], [("earned", summary[t]["cogs_earned"], "#8a8a8a"), ("spent", summary[t]["cogs_spent"], COLORS[t]),
                          ("held", summary[t]["cogs_end"], "#c9a227")]) for t in TYPES if t in summary],
             os.path.join(out_dir, label + "-cogs-flow.svg"), "Cogs per world 1 run, median (%s)" % label, "cogs")
    print(json.dumps({k: v for k, v in result.items() if k != "summary"}, indent=1))
    for t, s in summary.items():
        print(t, {k: s[k] for k in ("runs", "wins", "game_min", "cogs_earned", "cogs_spent", "cogs_end", "parts_end", "panels_end",
                                    "cores_gained", "cores_wiped", "tree_end", "brindle_s", "min_hp")}, s.get("bay"))


if __name__ == "__main__":
    main()
