"""board_widget.py <board_name> [seed]: builds boards/<board_name>.widget.html, an inline widget body (no html/head/body
tags) with one card per subject: the 320 px thumbnail as a data URI, the object's one-line role from the board JSON,
and three buttons that call sendPrompt(). Thumbnails are JPEG so a 12-card board stays near 250 KB."""
import base64, html, json, os, sys
W = os.environ.get("BOARD_ROOT") or os.path.dirname(os.path.abspath(__file__))
name = sys.argv[1]
seed = sys.argv[2] if len(sys.argv) > 2 else None
spec = json.load(open(os.path.join(W, "boards", name + ".json")))
seed = seed or str(spec.get("seeds", [101])[0])
roles = spec.get("roles", {})
cards = []
for key in spec["subjects"]:
    t = os.path.join(W, "boards", name, f"{key}_{seed}.t.jpg")
    if not os.path.exists(t):
        continue
    b64 = base64.b64encode(open(t, "rb").read()).decode()
    label = html.escape(spec.get("labels", {}).get(key, key.replace("_", " ")))
    role = html.escape(roles.get(key, ""))
    k = html.escape(key)
    cards.append(f"""
<div class="card">
  <img src="data:image/jpeg;base64,{b64}" alt="{label}">
  <div class="name">{label}</div>
  <div class="role">{role}</div>
  <div class="row">
    <button class="ok" onclick="sendPrompt('Approve concept {k} seed {seed} from board {name}: author its Blender recipe through the detail loop')">Approve</button>
    <button onclick="sendPrompt('Re-roll concept {k} on board {name} with a new seed')">Re-roll</button>
    <button class="no" onclick="sendPrompt('Skip concept {k} on board {name}')">Skip</button>
  </div>
</div>""")
body = f"""
<style>
.board{{display:grid;grid-template-columns:repeat(auto-fill,minmax(230px,1fr));gap:14px;font-family:system-ui,sans-serif}}
.card{{background:var(--color-background-secondary,#1b1f24);border:1px solid var(--color-border-primary,#333);border-radius:12px;padding:10px;color:var(--color-text-primary,#eee)}}
.card img{{width:100%;border-radius:8px;display:block;background:#ddd}}
.name{{font-weight:700;margin-top:8px;font-size:15px}}
.role{{font-size:12px;opacity:.75;min-height:2.6em;margin:4px 0 8px}}
.row{{display:flex;gap:6px}}
.row button{{flex:1;padding:7px 4px;border-radius:8px;border:1px solid var(--color-border-primary,#444);background:var(--color-background-primary,#111);color:inherit;cursor:pointer;font-size:12px}}
.row .ok{{background:#2f7d4a;border-color:#2f7d4a;color:#fff}}
.row .no{{opacity:.7}}
.hdr{{margin:0 0 10px;font-family:system-ui,sans-serif;color:var(--color-text-primary,#eee)}}
.hdr button{{margin-left:8px;padding:6px 10px;border-radius:8px;border:1px solid #444;background:#222;color:#eee;cursor:pointer}}
</style>
<div class="hdr"><b>Concept board: {html.escape(name)}</b>, seed {seed}, {len(cards)} pictures
<button onclick="sendPrompt('Approve every concept on board {name} seed {seed} that I did not skip, and start the recipe wave')">Approve all remaining</button>
<button onclick="sendPrompt('Re-roll board {name} with a new seed for every card')">Re-roll all</button></div>
<div class="board">{''.join(cards)}</div>"""
out = os.path.join(W, "boards", name + ".widget.html")
open(out, "w").write(body)
print(out, len(body), "bytes,", len(cards), "cards")
