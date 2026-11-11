"""Pass B before/after charts for the min-maxer, from analyse.py's summaries (before, after-scale-off,
after-scale-on).

    python3 -I docs/systems-audit/economy/compare.py docs/systems-audit/economy/evidence
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from analyse import svg_bars  # noqa: E402

d = sys.argv[1]
ARMS = [("before", "before", "#8a8a8a"), ("after, scale off", "after-scale-off", "#2e86ab"), ("after, scale on", "after-scale-on", "#3c9d5d")]
S = {label: json.load(open(os.path.join(d, f + "-summary.json")))["summary"]["minmax"] for label, f, _ in ARMS}
short = {"before": "before", "after, scale off": "off", "after, scale on": "on"}


def group(title, pick):
    return (title, [(short[label], pick(S[label]), color) for label, _, color in ARMS])


svg_bars([
    group("Cogs spent", lambda s: s["cogs_spent"]),
    group("Cogs held at end", lambda s: s["cogs_end"]),
    group("Dam wallet", lambda s: s["bay"]["1"]["wallet"]),
    group("Flume wallet", lambda s: s["bay"]["2"]["wallet"]),
], os.path.join(d, "minmax-cogs-before-after.svg"), "Min-maxer, median of 24 world 1 runs: cogs (before / scale off / scale on)", "cogs")
svg_bars([
    group("Dam shelf bought out", lambda s: s["bay"]["1"]["bought_out"]),
    group("Flume shelf bought out", lambda s: s["bay"]["2"]["bought_out"]),
    group("Parts at the end", lambda s: s["parts_end"]),
    group("World 1 cleared", lambda s: s["wins"]),
], os.path.join(d, "minmax-shelf-before-after.svg"), "Min-maxer, 24 world 1 runs: shelf buy-outs and clears (of 24), parts (median)", "runs or parts")
