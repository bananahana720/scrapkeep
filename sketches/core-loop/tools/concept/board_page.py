"""board_page.py <board_name> [<board_name> ...]: writes boards/page.html (an Artifact page, no doctype) holding every
named board as a section, and boards/<board>/img/<key>.jpg (1024 px JPEG per picture). Verdicts live in the artifact's
db capability, collection `verdicts`, doc id `<board>__<key>`, so several boards share one page and one store."""
import json, os, sys
from PIL import Image
W = os.environ.get("BOARD_ROOT") or os.path.dirname(os.path.abspath(__file__))
boards = []
for name in sys.argv[1:]:
    spec = json.load(open(os.path.join(W, "boards", name + ".json")))
    seeds = [str(s) for s in spec.get("seeds", [101])]
    seed = ", ".join(seeds)
    bdir = os.path.join(W, "boards", name)
    os.makedirs(os.path.join(bdir, "img"), exist_ok=True)
    cards = []
    for key in spec["subjects"]:
        for n, s in enumerate(seeds, 1):
            src = os.path.join(bdir, f"{key}_{s}.png")
            if not os.path.exists(src):
                continue
            card = key if len(seeds) == 1 else f"{key}_{s}"
            label = spec.get("labels", {}).get(key, key.replace("_", " "))
            Image.open(src).convert("RGB").save(os.path.join(bdir, "img", card + ".jpg"), quality=85)
            cards.append({"key": card, "label": label if len(seeds) == 1 else f"{label}, take {n}",
                          "role": spec.get("roles", {}).get(key, ""), "img": f"img/{name}/{card}.jpg"})
    boards.append({"name": name, "seed": seed, "cards": cards, "maker": spec.get("maker_line", "")})
TEMPLATE = r'''<title>Scrapkeep Concept Board</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Chakra+Petch:wght@500;700&family=Atkinson+Hyperlegible:ital,wght@0,400;0,700;1,400&display=swap">
<style>
/* Layout: a sticky tally bar, then one section per board, each a responsive card grid; a card's verdict is its left stripe. */
:root{
  --bg:#f3ede1; --bg2:#fbf8f1; --fg:#23282b; --mute:#6b716f; --line:#d9d0bd;
  --teal:#1f6f7a; --approve:#3f8a5c; --reroll:#c98a1d; --skip:#6f7f8f;
  --display:"Chakra Petch",system-ui,sans-serif; --body:"Atkinson Hyperlegible",system-ui,sans-serif;
}
@media (prefers-color-scheme: dark){ :root:not([data-theme="light"]){
  --bg:#1b2124; --bg2:#242b2f; --fg:#ece6d8; --mute:#a3aba6; --line:#3a4448;
  --teal:#5fb3bd; --approve:#6fc08c; --reroll:#e5a73a; --skip:#93a3b1; color-scheme:dark } }
:root[data-theme="dark"]{
  --bg:#1b2124; --bg2:#242b2f; --fg:#ece6d8; --mute:#a3aba6; --line:#3a4448;
  --teal:#5fb3bd; --approve:#6fc08c; --reroll:#e5a73a; --skip:#93a3b1; color-scheme:dark }
body{background:var(--bg);color:var(--fg);font-family:var(--body);margin:0}
.wrap{padding-block:0 32px;padding-inline:16px;max-width:1280px;margin:0 auto}
header{position:sticky;top:env(safe-area-inset-top,0px);z-index:3;background:var(--bg);border-bottom:1px solid var(--line);
  padding-block:12px;display:flex;flex-wrap:wrap;gap:10px 18px;align-items:center}
h1{font-family:var(--display);font-weight:700;font-size:1.35rem;margin:0;letter-spacing:.01em;text-wrap:balance}
h2{font-family:var(--display);font-weight:700;font-size:1.1rem;margin:26px 0 4px;display:flex;flex-wrap:wrap;gap:8px 14px;align-items:baseline}
h2 small{font-family:var(--body);font-weight:400;color:var(--mute);font-size:.85rem}
.maker{font-size:.85rem;color:var(--mute);line-height:1.4;max-width:70ch;margin:0 0 10px}
.tally{display:flex;gap:8px;flex-wrap:wrap;font-variant-numeric:tabular-nums}
.chip{border:1px solid var(--line);border-radius:999px;padding:3px 10px;font-size:.8rem;display:inline-flex;gap:6px;align-items:center}
.chip i{width:9px;height:9px;border-radius:50%;display:inline-block;background:var(--mute)}
.chip.a i{background:var(--approve)} .chip.r i{background:var(--reroll)} .chip.s i{background:var(--skip)}
.tools{margin-left:auto;display:flex;gap:8px}
button{font:inherit;cursor:pointer;border-radius:8px;border:1px solid var(--line);background:var(--bg2);color:var(--fg);padding:7px 10px}
button:focus-visible{outline:2px solid var(--teal);outline-offset:2px}
.note{font-size:.8rem;color:var(--mute);margin:10px 0 0}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(270px,1fr));gap:16px;margin-top:10px}
.card{background:var(--bg2);border:1px solid var(--line);border-radius:12px;overflow:hidden;display:flex;flex-direction:column;
  border-left:6px solid var(--line);min-width:0}
.card[data-v="approve"]{border-left-color:var(--approve)} .card[data-v="reroll"]{border-left-color:var(--reroll)} .card[data-v="skip"]{border-left-color:var(--skip)}
.card img{width:100%;aspect-ratio:1;max-width:100%;display:block;background:#e9e9e9;cursor:zoom-in}
.body{padding:10px 12px 12px;display:flex;flex-direction:column;gap:8px}
.name{font-family:var(--display);font-weight:700;font-size:1.05rem}
.role{font-size:.82rem;color:var(--mute);line-height:1.35}
.row{display:flex;gap:6px}
.row button{flex:1;padding:8px 4px;font-size:.85rem;font-family:var(--display);font-weight:500}
.row button[aria-pressed="true"]{color:#fff;border-color:transparent}
.row .a[aria-pressed="true"]{background:var(--approve)} .row .r[aria-pressed="true"]{background:var(--reroll)} .row .s[aria-pressed="true"]{background:var(--skip)}
.memo{font:inherit;font-size:.85rem;border:1px solid var(--line);border-radius:8px;padding:7px 9px;background:var(--bg);color:var(--fg);width:100%;box-sizing:border-box}
dialog{border:0;padding:0;background:transparent;max-width:min(96vw,1024px)}
dialog::backdrop{background:rgba(0,0,0,.75)}
dialog img{width:100%;max-width:100%;border-radius:10px;display:block;cursor:zoom-out}
.banner{background:var(--bg2);border:1px dashed var(--line);border-radius:8px;padding:8px 12px;font-size:.85rem;color:var(--mute);margin-top:12px}
.banner[hidden]{display:none}
@media (prefers-reduced-motion:no-preference){ .card{transition:border-color .2s} }
</style>
<div class="wrap">
<header>
  <h1>Concept boards</h1>
  <div class="tally">
    <span class="chip a"><i></i><b id="nA">0</b> approve</span>
    <span class="chip r"><i></i><b id="nR">0</b> re-roll</span>
    <span class="chip s"><i></i><b id="nS">0</b> skip</span>
    <span class="chip"><i></i><b id="nU">0</b> undecided</span>
  </div>
  <div class="tools"><button id="copy" type="button">Copy summary for Claude</button></div>
</header>
<div class="banner" id="banner" hidden>Saving is off in this view. Your clicks stay on this page only.</div>
<p class="note">Newest board first. Click a picture to see it full size. One verdict per card; click the same button again to clear it. Verdicts save as you click, and Claude reads them back from this page.</p>
<div id="boards"></div>
</div>
<dialog id="box"><img id="boxImg" alt=""></dialog>
<script>
const BOARDS = __BOARDS_JSON__;
const V = ["approve","reroll","skip"], LBL = {approve:"Approve", reroll:"Re-roll", skip:"Skip"};
const state = {verdicts: {}, notes: {}, db: null};
const $ = (s, el=document) => el.querySelector(s);
const idOf = (b, k) => b + "__" + k;
const ALL = []; BOARDS.forEach(b => b.cards.forEach(c => ALL.push({board: b.name, seed: b.seed, card: c, id: idOf(b.name, c.key)})));

function build(){
  const root = $("#boards"); root.textContent = "";
  for (const b of BOARDS.slice().reverse()){
    const h = document.createElement("h2"); h.textContent = b.name + " ";
    const sm = document.createElement("small"); sm.textContent = "seed " + b.seed + ", " + b.cards.length + " pictures"; h.appendChild(sm);
    root.appendChild(h);
    if (b.maker){ const m = document.createElement("p"); m.className = "maker"; m.textContent = "Maker line: " + b.maker; root.appendChild(m); }
    const grid = document.createElement("div"); grid.className = "grid"; root.appendChild(grid);
    for (const c of b.cards){
      const id = idOf(b.name, c.key);
      const card = document.createElement("article"); card.className = "card"; card.id = "card-" + id;
      const img = document.createElement("img"); img.src = c.img; img.alt = c.label; img.loading = "lazy";
      img.addEventListener("click", () => { $("#boxImg").src = c.img; $("#boxImg").alt = c.label; $("#box").showModal(); });
      const body = document.createElement("div"); body.className = "body";
      const name = document.createElement("div"); name.className = "name"; name.textContent = c.label;
      const role = document.createElement("div"); role.className = "role"; role.textContent = c.role;
      const row = document.createElement("div"); row.className = "row";
      for (const v of V){
        const btn = document.createElement("button"); btn.type = "button"; btn.className = v[0]; btn.textContent = LBL[v];
        btn.dataset.v = v; btn.setAttribute("aria-pressed", "false");
        btn.addEventListener("click", () => setVerdict(id, state.verdicts[id] === v ? "" : v));
        row.appendChild(btn);
      }
      const memo = document.createElement("input"); memo.className = "memo"; memo.id = "memo-" + id;
      memo.placeholder = "Note for the recipe (optional)"; memo.autocomplete = "off";
      let t; memo.addEventListener("input", () => { clearTimeout(t); t = setTimeout(() => setNote(id, memo.value), 700); });
      body.append(name, role, row, memo); card.append(img, body); grid.appendChild(card);
    }
  }
  $("#box").addEventListener("click", () => $("#box").close());
  $("#copy").addEventListener("click", copySummary);
  paint();
}
function paint(){
  const n = {approve:0, reroll:0, skip:0, undecided:0};
  for (const e of ALL){
    const v = state.verdicts[e.id] || ""; n[v || "undecided"]++;
    const card = $("#card-" + e.id); card.dataset.v = v;
    card.querySelectorAll(".row button").forEach(b => b.setAttribute("aria-pressed", String(b.dataset.v === v)));
    const memo = $("#memo-" + e.id); if (document.activeElement !== memo && (state.notes[e.id] || "") !== memo.value) memo.value = state.notes[e.id] || "";
  }
  $("#nA").textContent = n.approve; $("#nR").textContent = n.reroll; $("#nS").textContent = n.skip; $("#nU").textContent = n.undecided;
}
const queue = {};
async function save(id){
  const e = ALL.find(x => x.id === id); if (!e || !state.db) return;
  const doc = {board: e.board, key: e.card.key, seed: e.seed, verdict: state.verdicts[id] || "", note: state.notes[id] || "", at: new Date().toISOString()};
  if (queue[id]) { queue[id] = "again"; return; }
  queue[id] = "busy";
  try { await state.db.doc("verdicts/" + id).set(doc); }
  catch (err) { if (err && err.code === "invalid_argument") { $("#banner").hidden = false; } }
  const again = queue[id] === "again"; delete queue[id]; if (again) save(id);
}
function setVerdict(id, v){ if ((state.verdicts[id] || "") === v) return; state.verdicts[id] = v; paint(); save(id); }
function setNote(id, text){ if ((state.notes[id] || "") === text) return; state.notes[id] = text; save(id); }
function summary(){
  return BOARDS.map(b => {
    const by = {approve:[], reroll:[], skip:[], undecided:[]};
    for (const c of b.cards){ const id = idOf(b.name, c.key); const v = state.verdicts[id] || "undecided"; by[v].push(state.notes[id] ? c.key + " (" + state.notes[id] + ")" : c.key); }
    return "Board " + b.name + " seed " + b.seed + ": approve " + (by.approve.join(", ") || "none") + "; re-roll " + (by.reroll.join(", ") || "none") + "; skip " + (by.skip.join(", ") || "none") + "; undecided " + (by.undecided.join(", ") || "none") + ".";
  }).join("\n");
}
async function copySummary(){
  const text = summary(); const b = $("#copy");
  try { await navigator.clipboard.writeText(text); b.textContent = "Copied"; }
  catch (err) { const ta = document.createElement("textarea"); ta.value = text; ta.style.width = "100%"; ta.rows = 4; b.after(ta); ta.select(); b.textContent = "Select and copy the text below"; }
  setTimeout(() => { b.textContent = "Copy summary for Claude"; }, 2000);
}
build();
(async () => {
  const db = window.claude && window.claude.use ? await window.claude.use("db") : null;
  if (!db) { $("#banner").hidden = false; return; }
  state.db = db;
  db.collection("verdicts").onSnapshot(snap => {
    for (const d of snap.docs){ const x = d.data(); if (!x || !x.board || !x.key) continue; const id = idOf(x.board, x.key);
      if (!queue[id]) { state.verdicts[id] = x.verdict || ""; state.notes[id] = x.note || ""; } }
    paint();
  }, () => { $("#banner").hidden = false; });
})();
</script>
'''
html = TEMPLATE.replace("__BOARDS_JSON__", json.dumps(boards))
out = os.path.join(W, "boards", "page.html")
open(out, "w").write(html)
print(out, len(html), "bytes;", ", ".join(f"{b['name']}: {len(b['cards'])} cards" for b in boards))
