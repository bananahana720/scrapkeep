#!/usr/bin/env python3
"""Build the local storyboard page and hash manifest. Does not generate or alter images."""
import hashlib
import html
import json
import pathlib
import struct
import subprocess

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[4]
COORD = pathlib.Path("/home/andrew/Projects/scrapkeep-worktrees/core-loop-v2")
CATALOG = json.loads((HERE / "catalog.json").read_text())
STYLE = ROOT / "sketches/core-loop/design-v2/visual-development/images/style-a.png"

def sha(data):
    return hashlib.sha256(data).hexdigest()

def git_bytes(revision, path):
    return subprocess.check_output(["git", "-C", str(COORD), "show", revision + ":" + path])

def source(revision, path, sections):
    data = git_bytes(revision, path)
    return dict(revision=revision, path=path, sections=sections, sha256=sha(data))

sources = [
    source("1589f4f26fd437d65b5d954e2b300bd7f50e673c", "sketches/core-loop/design-v3/LOOP-REDESIGN.md", ["2", "3", "8", "9", "11 A", "12"]),
    source("1589f4f26fd437d65b5d954e2b300bd7f50e673c", "sketches/core-loop/design-v3/ROADMAP.md", ["definition of done row 9"]),
    source("19fc173c7bdd852b99b16f878403621d7dee2852", "sketches/core-loop/DESIGN-V2.md", ["2"]),
    source("19fc173c7bdd852b99b16f878403621d7dee2852", "sketches/core-loop/src/core/palette.gd", ["palette constants"]),
    source("3c219ab564c55ee6c7c0ba6701363f8e9b67e972", "sketches/core-loop/src/world/map_spillway.gd", ["LOOP_LINES", "build_props"]),
    source("3c219ab564c55ee6c7c0ba6701363f8e9b67e972", "sketches/core-loop/src/world/contraptions.gd", ["_build_launcher"])
]
for rel in ["BIBLE.md", "sketches/core-loop/DESIGN-V2.md",
            "sketches/core-loop/design-v2/visual-development/COORDINATOR-HANDOFF.md",
            "sketches/core-loop/design-v2/visual-development/FIDELITY-GAPS.md",
            "sketches/core-loop/design-v2/visual-development/INTEGRATED-VERIFICATION.md"]:
    sources.append(dict(revision="69f40fd1cedad997f6bba87ef6f4451a1fef43c6", path=rel,
                        sha256=sha((ROOT / rel).read_bytes())))

manifest = dict(schema="scrapkeep-storyboard/1", date="2026-09-28",
    method="built-in image_gen.imagegen; no local image synthesis or image editing",
    branch="codex/visual-development", checkout_head="69f40fd1cedad997f6bba87ef6f4451a1fef43c6",
    refresh=dict(requested="19fc173c7bdd852b99b16f878403621d7dee2852", merged=False,
                 error="cannot open '.git/FETCH_HEAD': Read-only file system"),
    style_reference=dict(path=str(STYLE.relative_to(ROOT)), sha256=sha(STYLE.read_bytes()),
                         use="Style only; legacy threat markings and topology excluded"),
    sources=sources, images=[], claims=dict(runtime=False, gameplay_rules=False,
    performance=False, calibrated_camera=False, human_acceptance=False))
ledger = ["# Viewed image ledger", "", "Each image was inspected when imagegen returned it. Hashes bind those observations to the local copies. Rejected attempts remain available.", "",
          "| Image | SHA-256 | Disposition |", "| --- | --- | --- |"]
for item in CATALOG:
    for attempt in item["versions"]:
        p = HERE / attempt["file"]
        data = p.read_bytes()
        assert data[:8] == b"\x89PNG\r\n\x1a\n"
        width, height = struct.unpack(">II", data[16:24])
        prompt = HERE / attempt["prompt"]
        parent = (HERE / attempt["parent"]).resolve()
        entry = dict(board=item["id"], title=item["title"], **attempt,
                     sha256=sha(data), width=width, height=height,
                     prompt_sha256=sha(prompt.read_bytes()), prompt_text=prompt.read_text(),
                     parent_sha256=sha(parent.read_bytes()), visually_inspected=True,
                     inspection_method="direct tool image display; no repeated view of copied image")
        manifest["images"].append(entry)
        verdict = "selected with documented limits" if attempt["selected"] else "superseded"
        if item["id"] == "05-return" and attempt["version"] == 2:
            verdict = "rejected: duplicated Warden and lost lift"
        ledger.append("| " + attempt["file"] + " | " + sha(data) + " | " + verdict + " |")
(HERE / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
(HERE / "VIEWED-IMAGES.md").write_text("\n".join(ledger) + "\n")

review = ["# Storyboard critique", "", "Twelve selected concepts in Style A. The full retained lineage is in manifest.json. Initial attempts had at most two focused corrections. No image establishes engine geometry, timings, hit detection or performance.", "",
          "The six loop beats show the first circuit and its repeatable structure across the first three minutes. Later encounters and the final break are described in HANDOFF.md, not claimed as additional illustrated frames.", ""]
groups = {"loop": "Drop Loop", "states": "Warden states", "families": "Interactables",
          "teases": "Anticipation", "pilots": "Pilot cards"}
cards = []
for item in CATALOG:
    esc = html.escape
    current = next(a for a in item["versions"] if a["selected"])
    review.extend(["## " + item["title"], "", "Source: " + item["source"], "",
                   "Initial: " + item["initial"], "", "Correction: " + item["correction"], "",
                   "Largest remaining discrepancy: " + item["largest"], ""])
    panels_html = ""
    if item["panels"]:
        review.extend(["| Panel | Largest discrepancy |", "| --- | --- |"])
        for title, finding in item["panels"]:
            review.append("| " + title + " | " + finding + " |")
        review.append("")
        panels_html = '<details><summary>Read each panel</summary><dl>' + "".join(
            "<dt>" + esc(t) + "</dt><dd>" + esc(f) + "</dd>" for t, f in item["panels"]) + "</dl></details>"
    panel_key = ('<p class="source">Panel order: ' + ' · '.join(esc(p[0]) for p in item["panels"]) + '</p>') if item["panels"] else ''
    attempts = "".join('<li><a href="' + a["file"] + '">Attempt ' + str(a["version"]) +
        (' · selected' if a["selected"] else '') + '</a> · <a href="' + a["prompt"] +
        '">exact prompt</a></li>' for a in item["versions"])
    cards.append('<article data-group="' + item["group"] + '" id="' + item["id"] + '"><div class="label">' +
        esc(groups[item["group"]]) + ' · ' + esc(item["id"].split("-")[0]) + '</div><h2>' +
        esc(item["title"]) + '</h2><a class="image-link" href="' + current["file"] +
        '" aria-label="Open full image: ' + esc(item["title"]) + '"><img loading="lazy" src="' +
        current["file"] + '" alt="' + esc(item["title"] + ". Style A appearance concept.") +
        '"></a>' + panel_key + '<p class="source">' + esc(item["source"]) + '</p><p><strong>Largest gap.</strong> ' +
        esc(item["largest"]) + '</p>' + panels_html +
        '<details><summary>Critique and retained attempts</summary><p>' + esc(item["initial"]) +
        '</p><p>' + esc(item["correction"]) + '</p><ul>' + attempts + '</ul></details></article>')
(HERE / "CRITIQUE.md").write_text("\n".join(review) + "\n")
page = """<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Scrapkeep · Drop Loop storyboards</title>
<style>
:root{color-scheme:dark;--ink:#e9dfc8;--muted:#b8c5bf;--bg:#172421;--panel:#223530;--line:#52665d;--amber:#e5a044;--mint:#8bf0d3}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);font:16px/1.55 system-ui,sans-serif}
header,main,footer{max-width:1440px;margin:auto;padding:32px}header{border-bottom:1px solid var(--line)}
.eyebrow,.label{font-size:.8rem;letter-spacing:.1em;text-transform:uppercase;color:var(--amber)}
h1{font-size:clamp(2rem,5vw,4.3rem);line-height:1.06;max-width:900px;margin:18px 0}
h2{font-size:1.35rem;margin:8px 0 18px}p{max-width:82ch}.intro{font-size:1.15rem}
a{color:var(--mint);text-underline-offset:3px}a:hover{color:white}a:focus-visible,button:focus-visible,summary:focus-visible{outline:3px solid var(--amber);outline-offset:4px}
nav{display:flex;gap:16px;flex-wrap:wrap;margin:20px 0}.notice{padding:16px 20px;border-left:3px solid var(--amber);background:#29362f}
.filters{display:flex;flex-wrap:wrap;gap:8px;margin:24px 0}button{background:transparent;color:var(--ink);border:1px solid var(--line);padding:10px 16px;border-radius:6px;font:inherit;cursor:pointer}
button[aria-pressed=true]{background:var(--amber);color:#172421;border-color:var(--amber)}
.grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:24px;align-items:start}
article{padding:22px;background:var(--panel);border:1px solid var(--line);border-radius:8px;min-width:0}
article[data-group=states],article[data-group=families],article[data-group=teases]{grid-column:1/-1}
.image-link{display:block}img{display:block;width:100%;height:auto;border-radius:4px;background:#18231f}
article[data-group=pilots] img{max-height:720px;object-fit:contain}
.source{font-size:.84rem;color:var(--muted)}summary{cursor:pointer;color:var(--mint);padding:8px 0}details{border-top:1px solid var(--line);margin-top:12px}
dt{font-weight:700;margin-top:16px}dd{margin:4px 0 16px;color:var(--muted)}li{margin:8px 0}
[hidden]{display:none!important}footer{color:var(--muted);border-top:1px solid var(--line)}#count{color:var(--muted)}
@media(max-width:760px){header,main,footer{padding:20px}.grid{grid-template-columns:1fr}article{padding:16px}h1{font-size:2.3rem}}
@media(prefers-reduced-motion:no-preference){a,button{transition:color .12s,background .12s}}
</style></head><body>
<header><div class="eyebrow">Scrapkeep / Visual development / Style A</div>
<h1>The map is the run-up.</h1>
<p class="intro">Twelve appearance boards for the Drop Loop, its machines, visible promises and three pilots. Painted workshop miniatures, grounded in the redesign.</p>
<p>Six loop frames show the first circuit, the pattern repeated through the first three minutes. Open a frame for full size; expand its critique for source checks and earlier attempts.</p>
<nav aria-label="Package documents"><a href="PROP-APPEARANCE.md">Prop appearance plan</a><a href="CRITIQUE.md">Complete critique</a><a href="HANDOFF.md">Coordinator and W12 handoff</a><a href="manifest.json">Hashes and lineage</a><a href="VIEWED-IMAGES.md">Viewed image ledger</a></nav>
<div class="notice">Concepts, not runtime captures. Geometry and timing remain source-owned. The refresh merge and commit are blocked by read-only Git metadata; checkout remains 69f40fd. PNGs are local and ignored.</div>
</header><main><div class="filters" role="group" aria-label="Filter storyboards">
<button data-filter="all" aria-pressed="true">All boards</button><button data-filter="loop" aria-pressed="false">Drop Loop</button>
<button data-filter="states" aria-pressed="false">Warden</button><button data-filter="families" aria-pressed="false">Interactables</button>
<button data-filter="teases" aria-pressed="false">Anticipation</button><button data-filter="pilots" aria-pressed="false">Pilots</button>
</div><p id="count" role="status">12 boards shown</p><section class="grid" aria-label="Storyboards">""" + "".join(cards) + """</section></main>
<footer><p>Built-in imagegen · 24 retained attempts · no more than two corrections per board. The twelve selections retain explicit discrepancies. ROADMAP row 9 remains open until implementation and captures on the coordinator's merged base.</p>
<p>Ancient blue #3d8bff · danger #ff5a3c with charcoal keylines · travel amber #e5a044 · class cues from the selected pilot. Browser checks only inspect this gallery.</p></footer>
<script>
for(const button of document.querySelectorAll('[data-filter]')){
button.addEventListener('click',()=>{
const group=button.dataset.filter; let count=0;
for(const b of document.querySelectorAll('[data-filter]')) b.setAttribute('aria-pressed',String(b===button));
for(const card of document.querySelectorAll('[data-group]')){card.hidden=group!=='all'&&card.dataset.group!==group;if(!card.hidden)count++;}
document.getElementById('count').textContent=count+' board'+(count===1?'':'s')+' shown';
});}
</script></body></html>"""
(HERE / "index.html").write_text(page)
print(json.dumps({"selected_boards":len(CATALOG), "attempts":len(manifest["images"]), "page":"index.html",
                  "manifest":"manifest.json", "sources":len(sources)}))
