extends RefCounted


const CHASSIS := "spil9"
const SOCKETS := 2
const CONDUCTIVE_PRIMER := "conductive_primer"
const RAM_BRACE := "ram_brace"
const ESCAPE_CORRIDOR := "escape_corridor"
const SALVAGE_MAGNET := "salvage_magnet"
const FAMILIES := [CONDUCTIVE_PRIMER, RAM_BRACE, ESCAPE_CORRIDOR, SALVAGE_MAGNET]
const MAX_NAME_WORDS := 3
const COG_SCOOP_VACUUM_MULT := 1.65
const COG_SCOOP_STREAK_STEP := 5
const COG_SCOOP_STREAK_COGS := 2
const COG_SCOOP_STAGE_CAP := 24
const CADDY_EVERY_CLEARS := 2
const CADDY_STAGE_CAP := 3
const SALVAGE_META := "w50_companion_salvage"
const PRIMER_SECONDS := 3.0
const PRIMER_COIL_MULT := 1.5
const PRIMER_MESH_SHARE := 0.4
const PRIMER_MESH_TARGETS := 2
const PRIMER_MESH_RANGE := 6.0
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
	{"id": "cog_scoop", "family": SALVAGE_MAGNET, "name": "Cog Scoop",
		"effect": "Widens scrap and cog vacuum pull and drips extra cogs on kill streaks."},
	{"id": "cartridge_caddy", "family": SALVAGE_MAGNET, "name": "Cartridge Caddy",
		"effect": "Prints a random Pocket Consumable every two cleared yards or activities."},
]
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
	SALVAGE_MAGNET: [
		{"id": "scoop_drip", "piece": "cog_scoop", "on": ["kill", "pickup"], "needs": {"streak_ready": true},
			"act": "drip_cogs", "cue": "salvage_drip"},
		{"id": "caddy_print", "piece": "cartridge_caddy", "on": ["yard_cleared"], "needs": {"print_ready": true},
			"act": "print_cartridge", "cue": "salvage_print"},
	],
}
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
	"assist_full": {"clip": "spring_arm", "chirp": "companion_ready"},
	"assist_bonk": {"clip": "assist_rise", "chirp": "companion_ready"},
	"assist_arc": {"clip": "assist_rise", "chirp": "companion_ready"},
	"assist_pile": {"clip": "assist_rise", "chirp": "companion_ready"},
	"assist_slip": {"clip": "assist_rise", "chirp": "companion_ready"},
	"assist_anvil": {"clip": "assist_rise", "chirp": "companion_ready"},
	"assist_static": {"clip": "assist_rise", "chirp": "companion_ready"},
	"assist_bulldozer": {"clip": "assist_rise", "chirp": "companion_ready"},
	"salvage_drip": {"clip": "spring_arm", "chirp": ""},
	"salvage_print": {"clip": "spring_arm", "chirp": "companion_ready"},
	"assist_magnet": {"clip": "assist_rise", "chirp": "companion_ready"},
	"assist_flux": {"clip": "assist_rise", "chirp": "companion_ready"},
	"assist_scrap_plow": {"clip": "assist_rise", "chirp": "companion_ready"},
	"assist_skim_scoop": {"clip": "assist_rise", "chirp": "companion_ready"},
}

const MARKS := [
	{"mark": 1, "scale": 1.0, "adds": ""},
	{"mark": 2, "scale": 1.1, "adds": "fins"},
	{"mark": 3, "scale": 1.2, "adds": "double_halo"},
	{"mark": 4, "scale": 1.3, "adds": "exhaust"},
	{"mark": 5, "scale": 1.4, "adds": "core_crest"},
]
const ASSIST_FULL := 24.0
const ASSIST_PER_HIT := 1.0
const ASSIST_PER_CONTACT := 3.0
const ASSIST_PER_HULL_HIT := 4.0
const ASSIST_TRIGGER := "ram"
const ASSIST_RADIUS := 2.6
const ASSIST_KNOCK := 10.0
const ASSIST_DAMAGE_FLOOR := 10.0
const ASSIST_AREA_STEP := 0.25
const ASSIST_KNOCK_STEP := 0.25
const ASSIST_LANE_HALF_WIDTH := 0.4
const ASSIST_SLICK_SECONDS := 1.2
const ASSISTS := {
	"": {"id": "bonk", "name": "Bonk", "word": "BONK!", "shape": "single", "prime": false, "shove": true, "slick": false},
	CONDUCTIVE_PRIMER: {"id": "arc", "name": "Arc Call", "word": "ZZAK!", "shape": "ring", "prime": true, "shove": false, "slick": false},
	RAM_BRACE: {"id": "pile", "name": "Pile Driver", "word": "KLANG!", "shape": "ring", "prime": false, "shove": true, "slick": false},
	ESCAPE_CORRIDOR: {"id": "slip", "name": "Slipstream", "word": "FWOOSH!", "shape": "ring", "prime": false, "shove": true, "slick": true},
	CONDUCTIVE_PRIMER + "+" + RAM_BRACE: {"id": "anvil", "name": "Thunder Anvil", "word": "KRA-KOOM!", "shape": "ring", "prime": true, "shove": true, "slick": false},
	CONDUCTIVE_PRIMER + "+" + ESCAPE_CORRIDOR: {"id": "static", "name": "Static Slipstream", "word": "ZZZWAP!", "shape": "ring", "prime": true, "shove": true, "slick": true},
	RAM_BRACE + "+" + ESCAPE_CORRIDOR: {"id": "bulldozer", "name": "Bulldozer Bow", "word": "WHUMP!", "shape": "lane", "prime": false, "shove": true, "slick": true},
	SALVAGE_MAGNET: {"id": "magnet", "name": "Scrap Magnet", "word": "SCHLUNK!", "shape": "ring", "prime": false, "shove": true, "slick": false},
	CONDUCTIVE_PRIMER + "+" + SALVAGE_MAGNET: {"id": "flux", "name": "Flux Scoop", "word": "ZAP-POP!", "shape": "ring", "prime": true, "shove": false, "slick": false},
	RAM_BRACE + "+" + SALVAGE_MAGNET: {"id": "scrap_plow", "name": "Scrap Plow", "word": "CRUNCH!", "shape": "ring", "prime": false, "shove": true, "slick": false},
	ESCAPE_CORRIDOR + "+" + SALVAGE_MAGNET: {"id": "skim_scoop", "name": "Skim Scoop", "word": "SWOOSH!", "shape": "ring", "prime": false, "shove": true, "slick": true},
}
const STALL_AFTER := 0.5
const LEASH_RANGE := 14.0
const LEASH_SECONDS := 2.0

const DROP_ORDER := ["escape_vent", "ram_prow", "primer_coil", "escape_rail", "ram_spring", "primer_mesh", "cog_scoop", "cartridge_caddy"]

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


static func escape_of(id: String) -> Dictionary:
	return _row(id).get("escape", {})


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


static func mark_of(heft_class: int) -> Dictionary:
	return MARKS[clampi(heft_class, 1, MARKS.size()) - 1]


static func adds_of(heft_class: int) -> Array:
	var out := []
	for row in MARKS:
		if int(row["mark"]) <= clampi(heft_class, 1, MARKS.size()) and row["adds"] != "":
			out.append(row["adds"])
	return out


static func family_key(socket_ids: Array) -> String:
	var fams := []
	for f in FAMILIES:
		for id in socket_ids:
			if typeof(id) == TYPE_STRING and family_of(id) == f and not fams.has(f):
				fams.append(f)
	return "+".join(fams)


static func assist_of(socket_ids: Array) -> Dictionary:
	var row: Dictionary = ASSISTS.get(family_key(socket_ids), ASSISTS[""]).duplicate()
	row["cue"] = "assist_" + String(row["id"])
	return row


static func assist_power(heft_class: int) -> Dictionary:
	var steps := clampi(heft_class, 1, MARKS.size()) - 1
	var area := 1.0 + ASSIST_AREA_STEP * steps
	return {"area": area, "radius": ASSIST_RADIUS * sqrt(area), "knock": 1.0 + ASSIST_KNOCK_STEP * steps,
		"layers": 2 + floori(steps / 2.0)}


static func assist_charge(charge: float, kind: String) -> float:
	var add := ASSIST_PER_HULL_HIT if kind == "hull" else (ASSIST_PER_CONTACT if kind in ["ram", "slam", "stomp"] else ASSIST_PER_HIT)
	return minf(charge + add, ASSIST_FULL)


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


func acquire(id: String) -> bool:
	if _row(id).is_empty() or owned.has(id):
		return false
	owned.append(id)
	return true


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
	assert(sockets.size() <= SOCKETS, "Companion sockets exceeded max")
	return ""


func unassemble() -> void:
	sockets.clear()


func escape_ready() -> bool:
	return has_family(ESCAPE_CORRIDOR) and not _escape_spent


func escape_spent() -> bool:
	return _escape_spent


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


static func next_drop(doc: Dictionary) -> String:
	var model = new()
	if not doc.is_empty() and not model.from_dict(doc):
		return ""
	for id in DROP_ORDER:
		if not model.owned.has(id):
			return id
	return ""


static func with_piece(doc: Dictionary, id: String) -> Dictionary:
	var model = new()
	if not doc.is_empty() and not model.from_dict(doc):
		return doc
	model.acquire(id)
	return model.to_dict()


static func unseat(doc: Dictionary) -> Array:
	var out := doc.duplicate(true)
	var seated: Array = out.get("sockets", [])
	if seated.size() < SOCKETS:
		return [out, ""]
	var piece := String(seated[-1])
	seated.remove_at(seated.size() - 1)
	out["sockets"] = seated
	return [out, piece]


static func reseat(doc: Dictionary, piece: String) -> Dictionary:
	if piece == "" or doc.is_empty():
		return doc
	var model = load("res://src/core/companion.gd").new()
	if not model.from_dict(doc):
		return doc
	var ids: Array = model.sockets.duplicate()
	if ids.has(piece):
		return doc
	ids.append(piece)
	if model.assemble(ids) != "":
		return doc
	var out := doc.duplicate(true)
	out["sockets"] = Array(model.sockets)
	return out


func to_dict() -> Dictionary:
	return {"chassis": CHASSIS, "owned": owned.duplicate(), "sockets": sockets.duplicate(),
		"escape_ready": not _escape_spent, "escape_spent": _escape_spent}


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
		return [out, "companion doc does not load (chassis, escape or socket rule)"]
	return [out, "" if dropped.is_empty() else "dropped companion pieces %s" % [dropped]]


func from_dict(d: Dictionary) -> bool:
	if d.get("chassis", "") != CHASSIS or typeof(d.get("escape_ready")) != TYPE_BOOL:
		return false
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


static func vacuum_scale(doc: Dictionary) -> float:
	return COG_SCOOP_VACUUM_MULT if seated(doc, SALVAGE_MAGNET) == "cog_scoop" else 1.0


static func _salvage_state(run) -> Dictionary:
	if run == null:
		return {"stage": 0, "streak": 0, "cogs_dripped": 0, "yards": 0, "prints": 0}
	var cur := int(run.stage)
	var raw = run.get_meta(SALVAGE_META) if run.has_meta(SALVAGE_META) else null
	if not (raw is Dictionary) or int(raw.get("stage", -1)) != cur:
		raw = {"stage": cur, "streak": 0, "cogs_dripped": 0, "yards": 0, "prints": 0}
		run.set_meta(SALVAGE_META, raw)
	return raw


static func reset_salvage_stage(run) -> void:
	if run == null:
		return
	run.set_meta(SALVAGE_META, {"stage": int(run.stage), "streak": 0, "cogs_dripped": 0, "yards": 0, "prints": 0})


static func on_salvage_kill(run, table: Dictionary = DRIVERS) -> Dictionary:
	if run == null or not run.alive():
		return {"dripped": 0}
	var piece := seated(run.companion, SALVAGE_MAGNET)
	if piece != "cog_scoop":
		return {"dripped": 0}
	var st := _salvage_state(run)
	st["streak"] = int(st.get("streak", 0)) + 1
	var ready := int(st["streak"]) >= COG_SCOOP_STREAK_STEP and int(st.get("cogs_dripped", 0)) < COG_SCOOP_STAGE_CAP
	var row := pick({"piece": piece, "on": "kill", "streak_ready": ready}, table)
	if row.is_empty():
		return {"dripped": 0, "streak": int(st["streak"]), "stage_total": int(st.get("cogs_dripped", 0))}
	st["streak"] = 0
	var room := COG_SCOOP_STAGE_CAP - int(st.get("cogs_dripped", 0))
	var drip := mini(COG_SCOOP_STREAK_COGS, room)
	if drip > 0:
		st["cogs_dripped"] = int(st.get("cogs_dripped", 0)) + drip
		run.add_cogs(drip)
	return {"dripped": drip, "stage_total": int(st["cogs_dripped"]), "cap": COG_SCOOP_STAGE_CAP, "cue": String(row["cue"])}


static func on_yard_cleared(run, combat = null, at := Vector3.ZERO, rng: RandomNumberGenerator = null, roll_consumable := Callable(), table: Dictionary = DRIVERS) -> Dictionary:
	if run == null or not run.alive():
		return {"printed": false, "consumable_id": ""}
	var piece := seated(run.companion, SALVAGE_MAGNET)
	if piece != "cartridge_caddy":
		return {"printed": false, "consumable_id": ""}
	var st := _salvage_state(run)
	st["yards"] = int(st.get("yards", 0)) + 1
	var ready := (int(st["yards"]) % CADDY_EVERY_CLEARS == 0) and int(st.get("prints", 0)) < CADDY_STAGE_CAP
	var row := pick({"piece": piece, "on": "yard_cleared", "print_ready": ready}, table)
	if row.is_empty() or not roll_consumable.is_valid():
		return {"printed": false, "consumable_id": "", "yards": int(st["yards"]), "stage_prints": int(st.get("prints", 0)), "cap": CADDY_STAGE_CAP}
	var roll_rng := rng
	if roll_rng == null:
		roll_rng = RandomNumberGenerator.new()
		roll_rng.seed = hash([run.run_seed, run.stage, "cartridge_caddy", int(st["yards"])])
	var cid := String(roll_consumable.call(roll_rng))
	st["prints"] = int(st.get("prints", 0)) + 1
	var stored_in_belt := false
	if run.has_method("add_consumable") and run.add_consumable(cid):
		stored_in_belt = true
	elif combat != null and combat.get("consumables") != null:
		combat.consumables.drop_consumable(cid, at + Vector3(2.8, 0.0, 0.0))
	return {
		"printed": true,
		"consumable_id": cid,
		"stored_in_belt": stored_in_belt,
		"yards": int(st["yards"]),
		"stage_prints": int(st["prints"]),
		"cap": CADDY_STAGE_CAP,
		"cue": String(row["cue"]),
	}
