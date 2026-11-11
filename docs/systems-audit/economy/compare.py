"""Pass B before/after chart for the min-maxer, from analyse.py's summaries.

    python3 -I docs/systems-audit/economy/compare.py docs/systems-audit/economy/evidence
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from analyse import svg_bars  # noqa: E402

d = sys.argv[1]
b = json.load(open(os.path.join(d, "before-summary.json")))["summary"]["minmax"]
a = json.load(open(os.path.join(d, "after-summary.json")))["summary"]["minmax"]
GREY, GREEN = "#8a8a8a", "#3c9d5d"
svg_bars([
    ("Cogs earned", [("before", b["cogs_earned"], GREY), ("after", a["cogs_earned"], GREEN)]),
    ("Cogs spent", [("before", b["cogs_spent"], GREY), ("after", a["cogs_spent"], GREEN)]),
    ("Cogs held at end", [("before", b["cogs_end"], GREY), ("after", a["cogs_end"], GREEN)]),
    ("Dam wallet", [("before", b["bay"]["1"]["wallet"], GREY), ("after", a["bay"]["1"]["wallet"], GREEN)]),
    ("Flume wallet", [("before", b["bay"]["2"]["wallet"], GREY), ("after", a["bay"]["2"]["wallet"], GREEN)]),
], os.path.join(d, "minmax-cogs-before-after.svg"), "Min-maxer, median of 24 world 1 runs: cogs before and after", "cogs")
svg_bars([
    ("Dam shelf bought out", [("before", b["bay"]["1"]["bought_out"], GREY), ("after", a["bay"]["1"]["bought_out"], GREEN)]),
    ("Flume shelf bought out", [("before", b["bay"]["2"]["bought_out"], GREY), ("after", a["bay"]["2"]["bought_out"], GREEN)]),
    ("Parts at the end", [("before", b["parts_end"], GREY), ("after", a["parts_end"], GREEN)]),
    ("World 1 cleared", [("before", b["wins"], GREY), ("after", a["wins"], GREEN)]),
], os.path.join(d, "minmax-shelf-before-after.svg"), "Min-maxer, 24 world 1 runs: shelf buy-outs (count of 24), parts (median), clears", "runs or parts")
