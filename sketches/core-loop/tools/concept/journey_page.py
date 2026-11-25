"""journey_page.py --journeys <dir> --manifests <dir> --out <html>: writes one Artifact page (no doctype, like board_page.py)
holding the three world journey pages as three sections, each a vertical timeline of beats with its panel picture.
Verdicts live in the artifact's db capability, collection `journeys`, doc id `<world>__<stage>__<beat>` per beat and
`<world>__world` per world. A missing manifest or panel file shows the panel as pending; the tool still runs.

Journey pages: <journeys>/world-N-*.md. Manifests: <manifests>/world-N/manifest.json, any of
  {"panels": {id: file}}, {id: file}, or [{"id": id, "file": file}] (file may also be under path/image/png/src;
  a relative file resolves against the manifest's folder). Images are referenced by absolute file path in <img src>,
  as the consumer of board_page.py rewrites them at publish time."""
import argparse, glob, html, json, os, re, subprocess, sys

LABEL = r"[A-Z]?\d+[a-z]?"
LABELS = rf"{LABEL}(?:,\s*{LABEL})*"
BEAT_HEAD = re.compile(rf"^#{{3,4}}\s+(?:(?:Beat|Side loop)\s+)?({LABELS})\.\s+(.+?)\s*$")
BEAT_BOLD = re.compile(rf"^\*\*(?:(?:Beat|Side loop)\s+)?({LABELS})\.\s+(.+?)\*\*\s*$")
FIELDS = ["You see", "You", "Pull in", "Pull out", "Pull", "Pressure", "Seconds", "Music", "Panel", "Where", "Next"]
FIELD = re.compile(r"^[-*]\s+(?:\*\*)?(" + "|".join(FIELDS) + r")(?:\*\*)?\s*[:.]\s*(?:\*\*)?\s*(.*)$")
SHOWN = ["Where", "You", "You see", "Pull", "Pull in", "Pull out", "Pressure", "Seconds", "Music", "Next"]


def inline(s):
    s = html.escape(s, quote=False)
    s = re.sub(r"`([^`]+)`", r"<code>\1</code>", s)
    return re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", s)


def slug(s):
    return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")


def find_root(manifests):
    """Directories to try for a repo-relative panel path: cwd, git root, every parent of the manifests folder."""
    roots = [os.getcwd()]
    try:
        roots.append(subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True).stdout.strip())
    except OSError:
        pass
    d = os.path.abspath(manifests)
    while d != os.path.dirname(d):
        roots.append(d); d = os.path.dirname(d)
    return [r for r in roots if r]


def resolve_path(p, roots, base=None):
    if os.path.isabs(p):
        return p if os.path.exists(p) else None
    for r in ([base] if base else []) + roots:
        c = os.path.join(r, p)
        if os.path.exists(c):
            return os.path.abspath(c)
    return None


def load_manifest(mdir, n):
    path = os.path.join(mdir, f"world-{n}", "manifest.json")
    out = {}
    if not os.path.exists(path):
        return out
    try:
        data = json.load(open(path))
    except (OSError, ValueError) as e:
        print(f"world {n}: manifest unreadable ({e}); every panel pending", file=sys.stderr)
        return out
    base = os.path.dirname(path)
    if isinstance(data, dict) and isinstance(data.get("panels"), (dict, list)):
        data = data["panels"]
    items = []
    if isinstance(data, dict):
        items = list(data.items())
    elif isinstance(data, list):
        for e in data:
            if isinstance(e, dict) and (e.get("id") or e.get("panel")):
                items.append((e.get("id") or e.get("panel"), e))
    for pid, v in items:
        if isinstance(v, dict):
            v = next((v[k] for k in ("file", "path", "image", "png", "src") if isinstance(v.get(k), str)), None)
        if isinstance(v, str):
            out[str(pid).lower()] = v if os.path.isabs(v) else os.path.join(base, v)
    return out


def panel_info(text, prior, stage=None):
    """Return (key, display id, explicit path or None, same-as beat or None) from a Panel line.

    A share ("shared with beat 4") only matches an earlier beat of the same stage: labels repeat across
    stages, and a forward share (the later beat is not parsed yet) resolves the picture on this beat."""
    for m in re.finditer(r"(?i)\bshare[sd]?\s+(?:with\s+)?(?:beats?\s+)?(" + LABEL + r")\b", text):
        ref = m.group(1)
        for b in reversed(prior):
            if stage is not None and b.get("stage") != stage:
                continue
            if b["label"] == ref or ref in [x.strip() for x in b["label"].split(",")]:
                return ("beat:" + b["id"], "", None, b)
    ticks = re.findall(r"`([^`]+)`", text)
    path = next((t for t in ticks if t.lower().endswith((".png", ".jpg", ".jpeg", ".webp")) and ("/" in t)), None)
    if path:
        pid = re.sub(r"\.\w+$", "", "/".join(path.split("/")[-2:]))
        return (path, pid, path, None)
    m = re.search(r"\bNEW\s+`?([\w.-]*\w)`?", text)
    if m:
        return (m.group(1), m.group(1), None, None)
    bare = next((t for t in ticks if t.lower().endswith((".png", ".jpg"))), None)
    if bare:
        return (bare, re.sub(r"\.\w+$", "", bare), None, None)
    if ticks:
        return (ticks[0], ticks[0], None, None)
    m = re.search(r"(?i)\bshares?\s+`?([\w.-]*\w)`?", text)
    if m:
        return (m.group(1), m.group(1), None, None)
    return (text[:40], text[:40] or "unnamed", None, None)


def parse_world(path):
    lines = open(path).read().split("\n")
    title = next((l[2:].strip() for l in lines if l.startswith("# ")), os.path.basename(path))
    para, arc = [], []
    mode = None
    for l in lines:
        if re.match(r"^##\s+(?:\d+\.\s+)?The journey in one paragraph", l):
            mode = "para"; continue
        if re.match(r"^##\s+(?:\d+\.\s+)?The world arc", l):
            mode = "arc"; continue
        if l.startswith("#"):
            mode = None
        if mode == "para" and l.strip():
            para.append(l.strip())
        elif mode == "arc" and l.startswith("|"):
            arc.append(l)
    beats, stage, group, in_warden = [], None, None, False
    cur = None
    for l in lines + ["## end"]:
        h = re.match(r"^(#{1,6})\s+(.*)$", l)
        bm = BEAT_HEAD.match(l) or BEAT_BOLD.match(l)
        exit_h = h and in_warden and len(h.group(1)) == 3 and re.search(r"\bexit\b", h.group(2), re.I) and not bm
        if h or bm:
            if cur is not None:
                beats.append(cur); cur = None
        if bm:
            if stage:
                cur = dict(label=bm.group(1).strip(), title=re.sub(r"\*\*", "", bm.group(2)).strip(), stage=stage, group=group, fields=[], notes=[], last=None)
            continue
        if exit_h:
            cur = dict(label="exit", title=re.sub(r"^\d+(?:\.\d+)*\s+", "", h.group(2)).strip(), stage=stage, group=group, fields=[], notes=[], last=None)
            continue
        if h:
            lvl, text = len(h.group(1)), h.group(2).strip()
            if re.match(r"Stage\s+(\d+)", text) and lvl in (2, 3):
                stage = ("s" + re.match(r"Stage\s+(\d+)", text).group(1), text); group = text; in_warden = False
            elif "Warden" in text and lvl == 2:
                stage = ("warden", text); group = text; in_warden = True
            elif lvl == 2 and re.search(r"between the stages|bay between", text, re.I):
                stage = ("between", text); group = text; in_warden = False
            elif in_warden and lvl == 3:
                group = text
            elif stage and stage[0] == "between" and lvl == 3:
                cur = dict(label="bay", title=text, stage=stage, group=group, fields=[], notes=[], last=None)
            else:
                stage = None; in_warden = False; group = None
            continue
        if cur is None:
            continue
        fm = FIELD.match(l)
        if fm:
            cur["fields"].append([fm.group(1), fm.group(2).strip()]); cur["last"] = cur["fields"][-1]
        elif l.startswith("- ") and cur["label"] == "exit":
            cur["notes"].append(l[2:].strip()); cur["last"] = None
        elif l.startswith(("  ", "\t")) and l.strip() and cur["last"] is not None:
            cur["last"][1] += " " + l.strip()
    return title, " ".join(para), arc, beats


def arc_html(arc):
    rows = [[c.strip() for c in r.strip().strip("|").split("|")] for r in arc if not re.match(r"^\|[\s|:-]+\|?$", r)]
    if not rows:
        return ""
    t = "<table class=\"arc\"><thead><tr>" + "".join(f"<th>{inline(c)}</th>" for c in rows[0]) + "</tr></thead><tbody>"
    for r in rows[1:]:
        t += "<tr>" + "".join(f"<td>{inline(c)}</td>" for c in r) + "</tr>"
    return t + "</tbody></table>"


TEMPLATE = r'''<title>Scrapkeep Journeys</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Chakra+Petch:wght@500;700&family=Atkinson+Hyperlegible:ital,wght@0,400;0,700;1,400&display=swap">
<style>
/* Layout: sticky tally bar, then one section per world; each has a sticky mini-map of beat chips and a timeline of beat rows
   (picture left, fields right). A beat's verdict is its left stripe and its mini-map chip colour. */
:root{
  --bg:#f3ede1; --bg2:#fbf8f1; --fg:#23282b; --mute:#6b716f; --line:#d9d0bd;
  --teal:#1f6f7a; --approve:#3f8a5c; --rework:#c98a1d; --pull:#fff2cf;
  --display:"Chakra Petch",system-ui,sans-serif; --body:"Atkinson Hyperlegible",system-ui,sans-serif; --hh:60px;
}
@media (prefers-color-scheme: dark){ :root:not([data-theme="light"]){
  --bg:#1b2124; --bg2:#242b2f; --fg:#ece6d8; --mute:#a3aba6; --line:#3a4448;
  --teal:#5fb3bd; --approve:#6fc08c; --rework:#e5a73a; --pull:#3a3420; color-scheme:dark } }
:root[data-theme="dark"]{
  --bg:#1b2124; --bg2:#242b2f; --fg:#ece6d8; --mute:#a3aba6; --line:#3a4448;
  --teal:#5fb3bd; --approve:#6fc08c; --rework:#e5a73a; --pull:#3a3420; color-scheme:dark }
body{background:var(--bg);color:var(--fg);font-family:var(--body);margin:0}
.wrap{padding-block:0 48px;padding-inline:16px;max-width:1280px;margin:0 auto}
header{position:sticky;top:env(safe-area-inset-top,0px);z-index:4;background:var(--bg);border-bottom:1px solid var(--line);
  padding-block:12px;display:flex;flex-wrap:wrap;gap:10px 18px;align-items:center}
h1{font-family:var(--display);font-weight:700;font-size:1.35rem;margin:0;letter-spacing:.01em;text-wrap:balance}
h2{font-family:var(--display);font-weight:700;font-size:1.4rem;margin:36px 0 6px;text-wrap:balance}
h3{font-family:var(--display);font-weight:700;font-size:1.05rem;margin:26px 0 8px;color:var(--teal)}
h4{font-family:var(--display);font-weight:700;font-size:1.05rem;margin:0}
.journey{max-width:75ch;line-height:1.5;margin:0 0 12px}
.tally{display:flex;gap:8px;flex-wrap:wrap;font-variant-numeric:tabular-nums}
.chip{border:1px solid var(--line);border-radius:999px;padding:3px 10px;font-size:.8rem;display:inline-flex;gap:6px;align-items:center}
.chip i{width:9px;height:9px;border-radius:50%;display:inline-block;background:var(--mute)}
.chip.a i{background:var(--approve)} .chip.r i{background:var(--rework)}
.tools{margin-left:auto;display:flex;gap:8px}
button{font:inherit;cursor:pointer;border-radius:8px;border:1px solid var(--line);background:var(--bg2);color:var(--fg);padding:7px 10px}
button:focus-visible,.map a:focus-visible{outline:2px solid var(--teal);outline-offset:2px}
.note{font-size:.8rem;color:var(--mute);margin:10px 0 0}
.arc{border-collapse:collapse;font-size:.85rem;width:100%;margin:8px 0 12px;background:var(--bg2)}
.arc th,.arc td{border:1px solid var(--line);padding:6px 8px;text-align:left;vertical-align:top}
.arc th{font-family:var(--display)}
.map{position:sticky;top:var(--hh);z-index:3;background:var(--bg);padding:8px 0;border-bottom:1px solid var(--line);display:flex;flex-wrap:wrap;gap:5px}
.map a{font-size:.74rem;text-decoration:none;color:var(--fg);border:1px solid var(--line);border-left:5px solid var(--line);border-radius:6px;padding:2px 7px;background:var(--bg2);white-space:nowrap}
.map a[data-v="approve"]{border-left-color:var(--approve)} .map a[data-v="rework"]{border-left-color:var(--rework)}
.beat{display:grid;grid-template-columns:minmax(260px,5fr) 7fr;gap:16px;background:var(--bg2);border:1px solid var(--line);border-left:6px solid var(--line);
  border-radius:12px;padding:12px;margin:0 0 14px;scroll-margin-top:calc(var(--hh) + 64px)}
.beat[data-v="approve"]{border-left-color:var(--approve)} .beat[data-v="rework"]{border-left-color:var(--rework)}
@media (max-width:760px){ .beat{grid-template-columns:1fr} }
.shot img{width:100%;aspect-ratio:3/2;object-fit:cover;display:block;border-radius:8px;background:#e9e9e9;cursor:zoom-in}
.pending{aspect-ratio:3/2;border:2px dashed var(--line);border-radius:8px;display:flex;align-items:center;justify-content:center;color:var(--mute);
  font-size:.85rem;text-align:center;padding:8px;box-sizing:border-box}
.same{color:var(--mute);font-size:.85rem;border:1px dashed var(--line);border-radius:8px;padding:10px}
.same a{color:var(--teal)}
.txt{min-width:0;display:flex;flex-direction:column;gap:6px}
.fld{font-size:.88rem;line-height:1.4;margin:0}
.fld span{font-family:var(--display);font-weight:700;font-size:.72rem;text-transform:uppercase;letter-spacing:.05em;color:var(--mute);margin-right:6px}
.fld.pull{background:var(--pull);border-left:4px solid var(--teal);padding:6px 10px;border-radius:6px;font-size:.98rem}
.fld.pull span{color:var(--teal)}
.fld.minor{color:var(--mute);font-size:.8rem}
code{font-size:.82em;background:rgba(127,127,127,.15);border-radius:4px;padding:0 3px;overflow-wrap:anywhere}
.row{display:flex;gap:6px;margin-top:auto}
.row button{flex:1;padding:8px 4px;font-size:.85rem;font-family:var(--display);font-weight:500}
.row button[aria-pressed="true"]{color:#fff;border-color:transparent}
.row .a[aria-pressed="true"]{background:var(--approve)} .row .r[aria-pressed="true"]{background:var(--rework)}
.memo{font:inherit;font-size:.85rem;border:1px solid var(--line);border-radius:8px;padding:7px 9px;background:var(--bg);color:var(--fg);width:100%;box-sizing:border-box}
.worldctl{display:flex;gap:10px;align-items:center;margin:18px 0 0;padding:12px;border:1px solid var(--line);border-radius:12px;background:var(--bg2)}
.worldctl button[aria-pressed="true"]{background:var(--approve);color:#fff;border-color:transparent}
dialog{border:0;padding:0;background:transparent;max-width:min(96vw,1536px)}
dialog::backdrop{background:rgba(0,0,0,.75)}
dialog img{width:100%;max-width:100%;border-radius:10px;display:block;cursor:zoom-out}
.banner{background:var(--bg2);border:1px dashed var(--line);border-radius:8px;padding:8px 12px;font-size:.85rem;color:var(--mute);margin-top:12px}
.banner[hidden]{display:none}
@media (prefers-reduced-motion:no-preference){ .beat{transition:border-color .2s} html{scroll-behavior:smooth} }
</style>
<div class="wrap">
<header id="top">
  <h1>Scrapkeep journeys</h1>
  <div class="tally">
    <span class="chip a"><i></i><b id="nA">0</b> approve</span>
    <span class="chip r"><i></i><b id="nR">0</b> rework</span>
    <span class="chip"><i></i><b id="nU">0</b> undecided</span>
    <span class="chip a"><i></i><b id="nW">0</b> of __NWORLDS__ worlds approved</span>
  </div>
  <div class="tools"><button id="copy" type="button">Copy summary for Claude</button></div>
</header>
<div class="banner" id="banner" hidden>Saving is off in this view. Your clicks stay on this page only.</div>
<p class="note">Scroll world by world. Click a picture to see it full size. Approve or Rework each beat; click the same button again to clear it. The yellow line in each beat is what pulls you on to the next one. Verdicts save as you click, and Claude reads them back from this page.</p>
__SECTIONS__
</div>
<dialog id="box"><img id="boxImg" alt=""></dialog>
<script>
const BEATS = __BEATS_JSON__, WORLDS = __WORLDS_JSON__;
const V = ["approve","rework"], LBL = {approve:"Approve", rework:"Rework"};
const state = {verdicts: {}, notes: {}, db: null};
const $ = (s, el=document) => el.querySelector(s);
const $$ = (s, el=document) => Array.from(el.querySelectorAll(s));
const ALL = BEATS.map(b => ({id: b.id, beat: b})).concat(WORLDS.map(w => ({id: w.id, world: w})));

function build(){
  for (const b of BEATS){
    const ctl = $("#ctl-" + b.id), row = document.createElement("div"); row.className = "row";
    for (const v of V){
      const btn = document.createElement("button"); btn.type = "button"; btn.className = v[0]; btn.textContent = LBL[v];
      btn.dataset.v = v; btn.setAttribute("aria-pressed", "false");
      btn.addEventListener("click", () => setVerdict(b.id, state.verdicts[b.id] === v ? "" : v));
      row.appendChild(btn);
    }
    const memo = document.createElement("input"); memo.className = "memo"; memo.id = "memo-" + b.id;
    memo.placeholder = "Memo for the rework (optional)"; memo.autocomplete = "off";
    let t; memo.addEventListener("input", () => { clearTimeout(t); t = setTimeout(() => setNote(b.id, memo.value), 700); });
    ctl.append(row, memo);
  }
  for (const w of WORLDS){
    const btn = document.createElement("button"); btn.type = "button"; btn.id = "wbtn-" + w.id; btn.setAttribute("aria-pressed", "false");
    btn.textContent = "Approve this world's journey";
    btn.addEventListener("click", () => setVerdict(w.id, state.verdicts[w.id] === "approve" ? "" : "approve"));
    $("#wctl-" + w.id).prepend(btn);
  }
  $$(".shot img").forEach(img => img.addEventListener("click", () => { $("#boxImg").src = img.src; $("#boxImg").alt = img.alt; $("#box").showModal(); }));
  $("#box").addEventListener("click", () => $("#box").close());
  $("#copy").addEventListener("click", copySummary);
  const hh = () => document.documentElement.style.setProperty("--hh", $("#top").offsetHeight + "px");
  hh(); addEventListener("resize", hh);
  paint();
}
function paint(){
  const n = {approve:0, rework:0, undecided:0}; let nw = 0;
  for (const e of ALL){
    const v = state.verdicts[e.id] || "";
    if (e.world){
      if (v === "approve") nw++;
      $("#wbtn-" + e.id).setAttribute("aria-pressed", String(v === "approve"));
      continue;
    }
    n[v || "undecided"]++;
    const el = $("#beat-" + e.id); el.dataset.v = v;
    $("#chip-" + e.id).dataset.v = v;
    $$(".row button", el).forEach(b => b.setAttribute("aria-pressed", String(b.dataset.v === v)));
    const memo = $("#memo-" + e.id); if (document.activeElement !== memo && (state.notes[e.id] || "") !== memo.value) memo.value = state.notes[e.id] || "";
  }
  $("#nA").textContent = n.approve; $("#nR").textContent = n.rework; $("#nU").textContent = n.undecided; $("#nW").textContent = nw;
}
const queue = {};
async function save(id){
  const e = ALL.find(x => x.id === id); if (!e || !state.db) return;
  const b = e.beat, w = e.world;
  const doc = b ? {world: b.world, stage: b.stage, beat: b.label, title: b.title, verdict: state.verdicts[id] || "", note: state.notes[id] || "", at: new Date().toISOString()}
                : {world: w.key, stage: "world", beat: "world", title: w.title, verdict: state.verdicts[id] || "", note: "", at: new Date().toISOString()};
  if (queue[id]) { queue[id] = "again"; return; }
  queue[id] = "busy";
  try { await state.db.doc("journeys/" + id).set(doc); }
  catch (err) { if (err && err.code === "invalid_argument") { $("#banner").hidden = false; } }
  const again = queue[id] === "again"; delete queue[id]; if (again) save(id);
}
function setVerdict(id, v){ if ((state.verdicts[id] || "") === v) return; state.verdicts[id] = v; paint(); save(id); }
function setNote(id, text){ if ((state.notes[id] || "") === text) return; state.notes[id] = text; save(id); }
function summary(){
  const out = [];
  for (const w of WORLDS){
    const bs = BEATS.filter(b => b.world === w.key);
    const ap = bs.filter(b => state.verdicts[b.id] === "approve").length, un = bs.filter(b => !state.verdicts[b.id]).length;
    out.push(w.title + ": " + (state.verdicts[w.id] === "approve" ? "world approved" : "world not approved") + "; beats approved " + ap + " of " + bs.length + ", undecided " + un + ".");
    for (const b of bs) if (state.verdicts[b.id] === "rework") out.push("  Rework " + b.stage + " beat " + b.label + " (" + b.title + ")" + (state.notes[b.id] ? ": " + state.notes[b.id] : ""));
  }
  return out.join("\n");
}
async function copySummary(){
  const text = summary(); const b = $("#copy");
  try { await navigator.clipboard.writeText(text); b.textContent = "Copied"; }
  catch (err) { const ta = document.createElement("textarea"); ta.value = text; ta.style.width = "100%"; ta.rows = 6; b.after(ta); ta.select(); b.textContent = "Select and copy the text below"; }
  setTimeout(() => { b.textContent = "Copy summary for Claude"; }, 2000);
}
build();
(async () => {
  const db = window.claude && window.claude.use ? await window.claude.use("db") : null;
  if (!db) { $("#banner").hidden = false; return; }
  state.db = db;
  db.collection("journeys").onSnapshot(snap => {
    for (const d of snap.docs){ const x = d.data(); if (!x || !x.world || !x.beat) continue;
      const id = d.id; if (!ALL.some(e => e.id === id)) continue;
      if (!queue[id]) { state.verdicts[id] = x.verdict || ""; state.notes[id] = x.note || ""; } }
    paint();
  }, () => { $("#banner").hidden = false; });
})();
</script>
'''


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--journeys", required=True)
    ap.add_argument("--manifests", required=True)
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    roots = find_root(a.manifests)
    sections, all_beats, worlds, bad = [], [], [], False
    for n in (1, 2, 3):
        files = sorted(glob.glob(os.path.join(a.journeys, f"world-{n}-*.md")))
        if not files:
            print(f"world {n}: no journey page in {a.journeys}", file=sys.stderr); bad = True; continue
        title, para, arc, beats = parse_world(files[0])
        manifest = load_manifest(a.manifests, n)
        wkey = f"world-{n}"
        ids, done, group_seen = set(), [], None
        body, nres, npend, nshared = [], 0, 0, 0
        for b in beats:
            bid = f"{wkey}__{b['stage'][0]}__{slug(b['label'])}"
            while bid in ids:
                bid += "-2"
            ids.add(bid)
            b["id"], b["world"], b["stageName"] = bid, wkey, b["stage"][0]
            ptext = next((v for k, v in b["fields"] if k == "Panel"), "")
            key, pid, ppath, same = panel_info(ptext, done, b.get("stage")) if ptext else ("", "", None, None)
            if not same and key:
                same = next((d for d in done if d.get("pkey") == key), None)
            if not same and pid and "/" not in pid:
                same = next((d for d in reversed(done) if d.get("ppid", "").endswith("/" + pid)), None)
            b["pkey"], b["ppid"] = key, pid
            if same:
                shot = f'<div class="same">same panel as <a href="#beat-{same["id"]}">beat {html.escape(same["label"])}</a></div>'
                nshared += 1
            else:
                img = None
                if ppath:
                    img = resolve_path(ppath, roots)
                if not img:
                    for cand in (pid, pid.split("/")[-1], key):
                        if cand and cand.lower() in manifest:
                            m = manifest[cand.lower()]
                            img = m if os.path.exists(m) else None
                            if img: break
                if img:
                    shot = f'<img src="{html.escape(img)}" alt="{html.escape(b["title"])}" data-panel="{html.escape(pid)}" loading="lazy">'
                    nres += 1
                    for extra in re.findall(r"\bNEW\s+`?([\w.-]*\w)`?", ptext or "")[1:]:
                        more = manifest.get(extra.lower())
                        if more and os.path.exists(more):
                            shot += f'<img src="{html.escape(more)}" alt="{html.escape(b["title"])}" data-panel="{html.escape(extra)}" loading="lazy">'
                            nres += 1
                else:
                    shot = f'<div class="pending">panel pending: {html.escape(pid or "no panel named on the page")}</div>'
                    npend += 1
            done.append(b)
            if b["group"] != group_seen:
                group_seen = b["group"]
                if group_seen:
                    body.append(f"<h3>{inline(group_seen)}</h3>")
            fl = []
            for lab in SHOWN:
                for k, v in b["fields"]:
                    if k == lab and v:
                        cls = "fld pull" if k.startswith("Pull") and k == "Pull" else ("fld minor" if k in ("Where", "Next") else "fld")
                        fl.append(f'<p class="{cls}"><span>{html.escape(k)}</span>{inline(v)}</p>')
            for t in b["notes"]:
                fl.append(f'<p class="fld">{inline(t)}</p>')
            body.append(
                f'<article class="beat" id="beat-{bid}">'
                f'<div class="shot">{shot}</div>'
                f'<div class="txt"><h4>{html.escape(b["label"])}. {inline(b["title"])}</h4>{"".join(fl)}<div id="ctl-{bid}"></div></div></article>')
        chips = "".join(f'<a id="chip-{b["id"]}" href="#beat-{b["id"]}" title="{html.escape(b["title"])}">{html.escape(b["label"])} {html.escape(b["title"][:28])}</a>' for b in beats)
        wid = f"{wkey}__world"
        sections.append(
            f'<section id="{wkey}">\n<h2>{inline(title)}</h2>\n<p class="journey">{inline(para)}</p>\n{arc_html(arc)}\n'
            f'<nav class="map" aria-label="Beats in world {n}">{chips}</nav>\n{chr(10).join(body)}\n'
            f'<div class="worldctl" id="wctl-{wid}"><span class="note">After the last beat: is this the journey you want built?</span></div>\n</section>')
        worlds.append(dict(id=wid, key=wkey, title=title))
        all_beats += [dict(id=b["id"], world=wkey, stage=b["stageName"], label=b["label"], title=b["title"]) for b in beats]
        print(f"world {n}: {len(beats)} beats, {nres} panels resolved, {npend} pending, {nshared} shared")
        if len(beats) < 5:
            print(f"world {n}: only {len(beats)} beats parsed (need at least 5)", file=sys.stderr); bad = True
    dump = lambda o: json.dumps(o).replace("</", "<\\/")
    page = (TEMPLATE.replace("__NWORLDS__", str(len(worlds))).replace("__SECTIONS__", "\n".join(sections))
            .replace("__BEATS_JSON__", dump(all_beats)).replace("__WORLDS_JSON__", dump(worlds)))
    os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
    open(a.out, "w").write(page)
    print(a.out, len(page), "bytes;", len(all_beats), "beats")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
