extends RefCounted

# The SPIL-9 companion as pure data: one hover chassis, two unordered module sockets, and
# one piece or any two different families. Pieces are found in runs and acquired without equipping;
# assemble() runs at intermission. Run state consumes the escape corridor after a
# survived low-hull hit; it never revives and never
# spends or refills a retry; the ready/spent flag is what the body and chirp cues show.
# Combat (combat.gd) runs the conductive primer, the ram brace and the escape piece's act,
# each chosen by pick() from the DRIVERS rows; the body and its chirp read the CUES rows.

const CHASSIS := "spil9"
const SOCKETS := 2
const CONDUCTIVE_PRIMER := "conductive_primer"
const RAM_BRACE := "ram_brace"
const ESCAPE_CORRIDOR := "escape_corridor"
const FAMILIES := [CONDUCTIVE_PRIMER, RAM_BRACE, ESCAPE_CORRIDOR]
const MAX_NAME_WORDS := 3
# Conductive primer (combat.gd): a weapon hit primes a foe for PRIMER_SECONDS; the next ball
# contact or special on it consumes the prime. Coil scales that hit, Mesh shares it out.
const PRIMER_SECONDS := 3.0
const PRIMER_COIL_MULT := 1.5
const PRIMER_MESH_SHARE := 0.4
const PRIMER_MESH_TARGETS := 2
const PRIMER_MESH_RANGE := 6.0
# Escape corridor (combat.gd _escape_act): when run state opens the window, the seated piece's
# `escape` row acts for its seconds. A shove adds velocity away from the hitter, sized from the
# ball's speed (SHARE of it, at least FLOOR) and capped at CAP times that speed; it never slows
# the ball. A lane is LANE_LENGTH m along the travel direction, LANE_HALF_WIDTH m either side,
# where the ball keeps its speed (at least LANE_FLOOR) with only LANE_FRICTION of the loss.
const ESCAPE_STYLES := ["shove", "lane"]
const ESCAPE_SECONDS := 1.2
const ESCAPE_SHOVE_SHARE := 0.5
const ESCAPE_SHOVE_FLOOR := 8.0
const ESCAPE_SHOVE_CAP := 1.5
const ESCAPE_LANE_LENGTH := 6.0
const ESCAPE_LANE_HALF_WIDTH := 1.5
const ESCAPE_LANE_FRICTION := 0.2
const ESCAPE_LANE_FLOOR := 7.0

const PIECES := [
	{"id": "primer_coil", "family": CONDUCTIVE_PRIMER, "name": "Primer Coil",
		"effect": "Shots prime a machine. Your next ram, slam or special on it hits half again as hard."},
	{"id": "primer_mesh", "family": CONDUCTIVE_PRIMER, "name": "Conductive Mesh",
		"effect": "Shots prime a machine. Your next ram, slam or special on it arcs to two neighbours."},
	{"id": "ram_prow", "family": RAM_BRACE, "name": "Ram Prow",
		"effect": "Ram hits shove machines out of their wind-up."},
	{"id": "ram_spring", "family": RAM_BRACE, "name": "Brace Spring",
		"effect": "A landed ram makes your next shot hit harder."},
	{"id": "escape_vent", "family": ESCAPE_CORRIDOR, "name": "Escape Vent",
		"effect": "After a hit that leaves you at a quarter health or less, vents once and shoves you clear of the hitter.",
		"escape": {"style": "shove", "seconds": ESCAPE_SECONDS}},
	{"id": "escape_rail", "family": ESCAPE_CORRIDOR, "name": "Corridor Rail",
		"effect": "After a hit that leaves you at a quarter health or less, lays a short slick lane once for you to ride out on.",
		"escape": {"style": "lane", "seconds": ESCAPE_SECONDS}},
]
# Module drivers (SR7; comps/ror2/companions.md "Skill-driver list as the behavior model"):
# each family is an ordered list of rows and pick() runs the first row the state meets, so
# behaviour is edited as data. A row names its piece ("" for any seated piece of the family),
# the triggers it answers ("on"), the state flags it needs, the act combat runs and the cue
# (a CUES key) the body's animation, its chirp and the chirp's motif all read.
const DRIVERS := {
	CONDUCTIVE_PRIMER: [
		{"id": "primer_consume", "piece": "", "on": ["contact", "special"], "needs": {"primed": true},
			"act": "consume", "cue": "primer_consume"},
		{"id": "primer_prime", "piece": "", "on": ["weapon"], "needs": {}, "act": "prime", "cue": "primer_set"},
	],
	RAM_BRACE: [
		{"id": "prow_shove", "piece": "ram_prow", "on": ["ram"], "needs": {"foe_free": true, "prow_ready": true},
			"act": "shove", "cue": "prow_response"},
		{"id": "spring_arm", "piece": "ram_spring", "on": ["ram"], "needs": {"dealt": true}, "act": "arm", "cue": "spring_arm"},
	],
	ESCAPE_CORRIDOR: [
		{"id": "escape_shove", "piece": "escape_vent", "on": ["escape_window"], "needs": {"alive": true},
			"act": "shove", "cue": "escape_acted"},
		{"id": "escape_lane", "piece": "escape_rail", "on": ["escape_window"], "needs": {"alive": true},
			"act": "lane", "cue": "escape_acted"},
	],
}
# One row per thing the companion shows: the clip the body plays and the UI row its chirp
# sounds ("" stays silent). Chirps mark availability and recovery (BIBLE.md:570); the escape
# piece's ready and spent chirps stay with the HUD's companion_ready / companion_spent rows.
const CUES := {
	"primer_set": {"clip": "primer_set", "chirp": "companion_ready"},
	"primer_consume": {"clip": "primer_consume", "chirp": ""},
	"primer_expire": {"clip": "primer_expire", "chirp": ""},
	"prow_response": {"clip": "prow_response", "chirp": ""},
	"spring_arm": {"clip": "spring_arm", "chirp": "companion_ready"},
	"spring_spend": {"clip": "spring_spend", "chirp": ""},
	"escape_acted": {"clip": "escape_spent", "chirp": "escape_acted"},
	"escape_rearm": {"clip": "escape_rearm", "chirp": ""},
	"stalled": {"clip": "idle", "chirp": ""},
	"rejoined": {"clip": "follow", "chirp": "companion_ready"},
	# A called assist plays assist_rise; the body queues assist_drop and assist_return after it.
	"assist_full": {"clip": "spring_arm", "chirp": "companion_ready"},
	"assist_bonk": {"clip": "assist_rise", "chirp": "companion_ready"},
	"assist_arc": {"clip": "assist_rise", "chirp": "companion_ready"},
	"assist_pile": {"clip": "assist_rise", "chirp": "companion_ready"},
	"assist_slip": {"clip": "assist_rise", "chirp": "companion_ready"},
	"assist_anvil": {"clip": "assist_rise", "chirp": "companion_ready"},
	"assist_static": {"clip": "assist_rise", "chirp": "companion_ready"},
	"assist_bulldozer": {"clip": "assist_rise", "chirp": "companion_ready"},
}

# COMPANION-GROWS (Andrew's taps 16:36Z and 16:44Z, 17 Oct 2026; storyboard
# https://claude.ai/artifact/D3kPhtU161uiv44JS5r8uT). SPIL-9 gains a mark per heft class:
# a little bigger and one more add-on part, capped at 1.4x so it never hides the ball or a
# warning. Add-ons are cumulative: a mark shows its own and every earlier one.
const MARKS := [
	{"mark": 1, "scale": 1.0, "adds": ""},
	{"mark": 2, "scale": 1.1, "adds": "fins"},
	{"mark": 3, "scale": 1.2, "adds": "double_halo"},
	{"mark": 4, "scale": 1.3, "adds": "exhaust"},
	{"mark": 5, "scale": 1.4, "adds": "core_crest"},
]
# The assist ("Call SPIL-9"): landed hits fill the halo gauge, a hull hit taken fills it
# faster, and when it is full the next ram calls it in (no new combat key, BIBLE.md:570).
# Start values for the lab.
const ASSIST_FULL := 24.0
const ASSIST_PER_HIT := 1.0
const ASSIST_PER_CONTACT := 3.0
const ASSIST_PER_HULL_HIT := 4.0
const ASSIST_TRIGGER := "ram"
# At heft class 1 the ring is ASSIST_RADIUS m and shoves at ASSIST_KNOCK; damage is the
# calling ram's dealt (at least ASSIST_DAMAGE_FLOOR), which already grows with heft. Per
# class above 1 the area grows by ASSIST_AREA_STEP and knockback by ASSIST_KNOCK_STEP, so class 5 is 2x the area
# and 2x the knockback ("Presence, centre clear", 17:28Z: late growth reads through heat,
# words and aura, and area stays within 1.5-2x). Sound layers: 2, 2, 3, 3, 4.
const ASSIST_RADIUS := 2.6
const ASSIST_KNOCK := 10.0
const ASSIST_DAMAGE_FLOOR := 10.0
const ASSIST_AREA_STEP := 0.25
const ASSIST_KNOCK_STEP := 0.25
const ASSIST_LANE_HALF_WIDTH := 0.4
const ASSIST_SLICK_SECONDS := 1.2
# One assist per seated family set, keyed by family_key(). shape: "single" hits the nearest
# foe only, "ring" every foe within the radius of the called hit, "lane" every foe along the
# ball's travel for twice the radius. prime primes what it hits, shove knocks it out, slick
# lays the escape lane under the ball. word is the ink sound effect; cue a CUES key.
const ASSISTS := {
	"": {"id": "bonk", "name": "Bonk", "word": "BONK!", "shape": "single", "prime": false, "shove": true, "slick": false},
	CONDUCTIVE_PRIMER: {"id": "arc", "name": "Arc Call", "word": "ZZAK!", "shape": "ring", "prime": true, "shove": false, "slick": false},
	RAM_BRACE: {"id": "pile", "name": "Pile Driver", "word": "KLANG!", "shape": "ring", "prime": false, "shove": true, "slick": false},
	ESCAPE_CORRIDOR: {"id": "slip", "name": "Slipstream", "word": "FWOOSH!", "shape": "ring", "prime": false, "shove": true, "slick": true},
	CONDUCTIVE_PRIMER + "+" + RAM_BRACE: {"id": "anvil", "name": "Thunder Anvil", "word": "KRA-KOOM!", "shape": "ring", "prime": true, "shove": true, "slick": false},
	CONDUCTIVE_PRIMER + "+" + ESCAPE_CORRIDOR: {"id": "static", "name": "Static Slipstream", "word": "ZZZWAP!", "shape": "ring", "prime": true, "shove": true, "slick": true},
	RAM_BRACE + "+" + ESCAPE_CORRIDOR: {"id": "bulldozer", "name": "Bulldozer Bow", "word": "WHUMP!", "shape": "lane", "prime": false, "shove": true, "slick": true},
}
# The leash (comps/ror2/companions.md:157, "use a Scrapkeep value tuned in the lab"): start
# values. With no leader the companion stalls after STALL_AFTER s (must stay under 1 s) and
# waits where its leader last stood alive; a companion over LEASH_RANGE m from a live leader
# for LEASH_SECONDS s is recalled beside it. Respawn clears the stall and recalls it.
const STALL_AFTER := 0.5
const LEASH_RANGE := 14.0
const LEASH_SECONDS := 2.0

# The order run-found pieces arrive: the first two make a legal pair, and escape comes first.
const DROP_ORDER := ["escape_vent", "ram_prow", "primer_coil", "escape_rail", "ram_spring", "primer_mesh"]

var owned: Array[String] = []
var sockets: Array[String] = []
var _escape_spent := false


static func _row(id: String) -> Dictionary:
	for p in PIECES:
		if p["id"] == id:
			return p
	return {}


static func family_of(id: String) -> String:
	return String(_row(id).get("family", ""))


# The piece's escape act {style, seconds}, empty for a piece that has none.
static func escape_of(id: String) -> Dictionary:
	return _row(id).get("escape", {})


# The first driver row of the state's piece family that the state meets, or {}. state holds
# "piece" (the seated piece, "" for none), "on" (the trigger) and the flags rows may need.
static func pick(state: Dictionary, table: Dictionary = DRIVERS) -> Dictionary:
	var piece := String(state.get("piece", ""))
	var family := family_of(piece)
	if family == "":
		return {}
	for row in table.get(family, []):
		var for_piece := String(row.get("piece", ""))
		if for_piece != "" and for_piece != piece:
			continue
		if not (row.get("on", []) as Array).has(state.get("on", "")):
			continue
		var needs: Dictionary = row.get("needs", {})
		var met := true
		for flag in needs:
			if state.get(flag) != needs[flag]:
				met = false
				break
		if met:
			return row
	return {}


# The MARKS row for a heft class (clamped to the table).
static func mark_of(heft_class: int) -> Dictionary:
	return MARKS[clampi(heft_class, 1, MARKS.size()) - 1]


# The add-ons a heft class shows: its own and every earlier mark's.
static func adds_of(heft_class: int) -> Array:
	var out := []
	for row in MARKS:
		if int(row["mark"]) <= clampi(heft_class, 1, MARKS.size()) and row["adds"] != "":
			out.append(row["adds"])
	return out


# The seated families in FAMILIES order joined by "+": "" bare, one family, or a pair.
static func family_key(socket_ids: Array) -> String:
	var fams := []
	for f in FAMILIES:
		for id in socket_ids:
			if typeof(id) == TYPE_STRING and family_of(id) == f and not fams.has(f):
				fams.append(f)
	return "+".join(fams)


# The assist a socket set calls, with its cue: ASSISTS[family_key] plus "cue".
static func assist_of(socket_ids: Array) -> Dictionary:
	var row: Dictionary = ASSISTS.get(family_key(socket_ids), ASSISTS[""]).duplicate()
	row["cue"] = "assist_" + String(row["id"])
	return row


# How hard the assist hits at a heft class: {area, radius, knock, layers}. area and knock
# are multipliers on class 1; radius is metres.
static func assist_power(heft_class: int) -> Dictionary:
	var steps := clampi(heft_class, 1, MARKS.size()) - 1
	var area := 1.0 + ASSIST_AREA_STEP * steps
	return {"area": area, "radius": ASSIST_RADIUS * sqrt(area), "knock": 1.0 + ASSIST_KNOCK_STEP * steps,
		"layers": 2 + floori(steps / 2.0)}


# The gauge after one landed hit or hull hit. kind is the strike kind, or "hull" for a hit
# taken; a full gauge stays full.
static func assist_charge(charge: float, kind: String) -> float:
	var add := ASSIST_PER_HULL_HIT if kind == "hull" else (ASSIST_PER_CONTACT if kind in ["ram", "slam", "stomp"] else ASSIST_PER_HIT)
	return minf(charge + add, ASSIST_FULL)


# Problems in a driver table, empty when it is sound.
static func validate_drivers(table: Dictionary = DRIVERS) -> Array:
	var problems := []
	var seen := {}
	for family in FAMILIES:
		var rows = table.get(family)
		if typeof(rows) != TYPE_ARRAY or rows.is_empty():
			problems.append("%s: no driver rows" % family)
			continue
		var served := {}
		for row in rows:
			var id := String(row.get("id", ""))
			if id == "" or seen.has(id):
				problems.append("bad or duplicate driver id: %s" % id)
			seen[id] = true
			var piece := String(row.get("piece", ""))
			if piece != "" and family_of(piece) != family:
				problems.append("%s: piece %s is not a %s piece" % [id, piece, family])
			if typeof(row.get("on")) != TYPE_ARRAY or (row["on"] as Array).is_empty():
				problems.append("%s: needs at least one trigger" % id)
			if typeof(row.get("needs", {})) != TYPE_DICTIONARY:
				problems.append("%s: needs must be a dictionary" % id)
			if String(row.get("act", "")) == "":
				problems.append("%s: missing act" % id)
			if not CUES.has(row.get("cue", "")):
				problems.append("%s: cue not in CUES" % id)
			var esc := escape_of(piece)
			if not esc.is_empty() and esc["style"] != row.get("act"):
				problems.append("%s: act must be the piece's escape style" % id)
			if piece == "":
				for p in PIECES:
					if p["family"] == family:
						served[p["id"]] = true
			else:
				served[piece] = true
		for p in PIECES:
			if p["family"] == family and not served.has(p["id"]):
				problems.append("%s: no driver row serves it" % p["id"])
	for family in table:
		if not FAMILIES.has(family):
			problems.append("%s: not a family" % family)
	return problems


# One leash tick. prev is the last result ({} to start). Returns {state: "follow" or
# "stalled", lost, far, safe, event: "" / "stalled" / "rejoined", recall}. Pure: the same
# inputs give the same result, so a seed's replay stalls on the same frame.
static func leash_step(prev: Dictionary, delta: float, leader_alive: bool, leader_at: Vector3, at: Vector3) -> Dictionary:
	var out := {"state": String(prev.get("state", "follow")), "lost": float(prev.get("lost", 0.0)),
		"far": float(prev.get("far", 0.0)), "safe": prev.get("safe", leader_at), "event": "", "recall": false}
	if leader_alive:
		out["safe"] = leader_at
		out["lost"] = 0.0
		if out["state"] == "stalled":
			out["state"] = "follow"
			out["event"] = "rejoined"
			out["recall"] = true
			out["far"] = 0.0
			return out
		out["far"] = float(out["far"]) + delta if at.distance_to(leader_at) > LEASH_RANGE else 0.0
		if float(out["far"]) >= LEASH_SECONDS:
			out["recall"] = true
			out["far"] = 0.0
		return out
	out["far"] = 0.0
	out["lost"] = float(out["lost"]) + delta
	if out["state"] != "stalled" and float(out["lost"]) >= STALL_AFTER:
		out["state"] = "stalled"
		out["event"] = "stalled"
	return out


# The seated piece of `family` in a to_dict document, or "" (also for a malformed doc).
static func seated(doc: Dictionary, family: String) -> String:
	var sockets_v = doc.get("sockets")
	if typeof(sockets_v) != TYPE_ARRAY:
		return ""
	for id in sockets_v:
		if typeof(id) == TYPE_STRING and family_of(id) == family:
			return id
	return ""


func has_family(family: String) -> bool:
	for id in sockets:
		if family_of(id) == family:
			return true
	return false


# Adds a found piece to the pile. Never equips. Refuses unknown ids and duplicates.
func acquire(id: String) -> bool:
	if _row(id).is_empty() or owned.has(id):
		return false
	owned.append(id)
	return true


# Returns "" on success or the refusal reason. One owned piece, or two of two different
# families in either order; the socket set is stored in table order so order never shows.
func assemble(ids: Array) -> String:
	if ids.is_empty() or ids.size() > SOCKETS:
		return "needs 1 to %d pieces" % SOCKETS
	for id in ids:
		if typeof(id) != TYPE_STRING or _row(id).is_empty():
			return "unknown piece"
		if not owned.has(id):
			return "piece not owned: %s" % id
	if ids.size() == SOCKETS and ids[0] == ids[1]:
		return "same piece twice"
	if ids.size() == SOCKETS and family_of(ids[0]) == family_of(ids[1]):
		return "needs two different families"
	var next: Array[String] = []
	for p in PIECES:
		if ids.has(p["id"]):
			next.append(p["id"])
	sockets = next
	return ""


func unassemble() -> void:
	sockets.clear()


func escape_ready() -> bool:
	return has_family(ESCAPE_CORRIDOR) and not _escape_spent


func escape_spent() -> bool:
	return _escape_spent


# Commit before run state publishes the window, so a listener cannot spend it twice.
func spend_escape() -> bool:
	if not escape_ready():
		return false
	_escape_spent = true
	return true


func reset_escape() -> void:
	_escape_spent = false


func reset() -> void:
	owned.clear()
	sockets.clear()
	reset_escape()


# Problems in the PIECES table, empty when it is sound.
static func validate(table: Array = PIECES) -> Array:
	var problems := []
	var seen := {}
	var per_family := {}
	for p in table:
		var id := String(p.get("id", ""))
		if id == "" or seen.has(id):
			problems.append("bad or duplicate id: %s" % id)
		seen[id] = true
		var fam := String(p.get("family", ""))
		if not FAMILIES.has(fam):
			problems.append("%s: family not in FAMILIES" % id)
		per_family[fam] = int(per_family.get(fam, 0)) + 1
		var words := String(p.get("name", "")).strip_edges().split(" ", false).size()
		if words < 1 or words > MAX_NAME_WORDS:
			problems.append("%s: name must be 1 to %d words" % [id, MAX_NAME_WORDS])
		if String(p.get("effect", "")).strip_edges() == "":
			problems.append("%s: missing effect text" % id)
		if fam == ESCAPE_CORRIDOR:
			var esc = p.get("escape")
			if typeof(esc) != TYPE_DICTIONARY or not ESCAPE_STYLES.has(esc.get("style", "")) \
					or float(esc.get("seconds", 0.0)) <= 0.0:
				problems.append("%s: escape needs a style in ESCAPE_STYLES and seconds > 0" % id)
	if table == PIECES:
		for f in FAMILIES:
			if int(per_family.get(f, 0)) < 2:
				problems.append("%s: needs at least two pieces" % f)
		for id in DROP_ORDER:
			if not seen.has(id):
				problems.append("%s: in DROP_ORDER but not in PIECES" % id)
		for id in seen:
			if not DROP_ORDER.has(id):
				problems.append("%s: missing from DROP_ORDER" % id)
	return problems


# The next piece a run finds, or "" when all are owned or the doc is malformed.
static func next_drop(doc: Dictionary) -> String:
	var model = new()
	if not doc.is_empty() and not model.from_dict(doc):
		return ""
	for id in DROP_ORDER:
		if not model.owned.has(id):
			return id
	return ""


# The doc with `id` acquired, never equipped; a malformed doc comes back unchanged.
static func with_piece(doc: Dictionary, id: String) -> Dictionary:
	var model = new()
	if not doc.is_empty() and not model.from_dict(doc):
		return doc
	model.acquire(id)
	return model.to_dict()


# A carried core (run_state.stow_core, `--carry-core=on`; Andrew 11 Nov 2026 19:24Z: one core,
# only into SPIL-9) takes a module socket while it rides. Stowing seats it in a free socket, or
# unseats the last seated piece (it stays owned) into "core_seat"; unstow puts that piece back
# when the core leaves at the next stage entry, or when a retry rewinds the stow. Docs only: the
# live effects read "sockets", so the unseated piece stops helping at once.
static func stow(doc: Dictionary) -> Dictionary:
	var out := doc.duplicate(true)
	var seated: Array = out.get("sockets", [])
	if seated.size() >= SOCKETS:
		out["core_seat"] = String(seated[-1])
		seated.remove_at(seated.size() - 1)
		out["sockets"] = seated
	out["core"] = true
	return out


static func unstow(doc: Dictionary) -> Dictionary:
	var out := doc.duplicate(true)
	var piece := String(out.get("core_seat", ""))
	out.erase("core_seat")
	out.erase("core")
	var seated: Array = out.get("sockets", [])
	if piece != "" and seated.size() < SOCKETS and not seated.has(piece) and (out.get("owned", []) as Array).has(piece):
		var ordered := []
		for p in PIECES:
			if seated.has(p["id"]) or p["id"] == piece:
				ordered.append(p["id"])
		out["sockets"] = ordered
	return out


func to_dict() -> Dictionary:
	return {"chassis": CHASSIS, "owned": owned.duplicate(), "sockets": sockets.duplicate(),
		"escape_ready": not _escape_spent, "escape_spent": _escape_spent}


# A saved companion doc this build can load, or {} when nothing in it can be kept. Pieces this
# build no longer has are dropped from owned and sockets, so a cut piece costs only itself, not
# the whole companion (from_dict refuses the doc outright, which stops it growing and leaves its
# escape un-armed for good). Lists of the wrong type read as no companion. The second value is
# the warning, "" when the doc was already clean.
static func sanitize(d: Dictionary) -> Array:
	if d.is_empty():
		return [{}, ""]
	var out := d.duplicate(true)
	var dropped := []
	for key in ["owned", "sockets"]:
		if not (out.get(key) is Array):
			return [{}, "companion %s is not a list" % key]
		var kept := []
		for id in out[key]:
			if id is String and not _row(id).is_empty() and not kept.has(id):
				kept.append(id)
			else:
				dropped.append(str(id))
		out[key] = kept
	out["sockets"] = (out["sockets"] as Array).filter(func(id): return (out["owned"] as Array).has(id))
	var probe = load("res://src/core/companion.gd").new()
	if not probe.from_dict(out):
		# Kept, not wiped: its lists are clean now, so readers are safe, and nothing is lost.
		return [out, "companion doc does not load (chassis, escape or socket rule)"]
	return [out, "" if dropped.is_empty() else "dropped companion pieces %s" % [dropped]]


# Loads a saved dict. False, with nothing changed, when any field is the wrong type or
# names a piece that does not exist, or the sockets break the assembly rule.
func from_dict(d: Dictionary) -> bool:
	if d.get("chassis", "") != CHASSIS or typeof(d.get("escape_ready")) != TYPE_BOOL:
		return false
	# Wave 3 documents stored only escape_ready, independent of whether it was assembled.
	var spent: bool = not d["escape_ready"]
	if d.has("escape_spent"):
		if typeof(d["escape_spent"]) != TYPE_BOOL or d["escape_spent"] != spent:
			return false
	var o: Array[String] = []
	var s: Array[String] = []
	for pair in [["owned", o], ["sockets", s]]:
		var src = d.get(pair[0])
		if typeof(src) != TYPE_ARRAY:
			return false
		for id in src:
			if typeof(id) != TYPE_STRING or _row(id).is_empty() or pair[1].has(id):
				return false
			pair[1].append(id)
	for id in s:
		if not o.has(id):
			return false
	if s.size() > SOCKETS or (s.size() == SOCKETS and family_of(s[0]) == family_of(s[1])):
		return false
	owned = o
	sockets = s
	_escape_spent = spent
	return true
