extends SceneTree

const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const Twins := preload("res://src/presentation/sound_twins.gd")
const Rows := preload("res://src/presentation/rows.gd")
const MusicRows := preload("res://src/presentation/music_rows.gd")
const WindupRows := preload("res://src/presentation/windup_rows.gd")
const SpecialCues := preload("res://src/combat/special_cues.gd")
const Affixes := preload("res://src/combat/elite_affixes.gd")
const Roster := preload("res://src/combat/roster.gd")
const Hud := preload("res://src/ui/hud.gd")
const T := preload("res://tests/support/t.gd")

# UI principle P9 (UA-07): every sound the player must act on has a visible twin. The judgement
# lives in src/presentation/sound_twins.gd, one row per FACT (a place the game decides to make a
# sound), because one cue serves several facts and act-on status belongs to the fact.
#
# Where the list of facts comes from, so nobody types it. From the game's own data: every row of
# EventKinds' eight sound tables (ROWS, UI_ROWS, LOOT_ROWS, WORLD_ROWS, THREAT_ROWS, LINE_ROWS,
# STATE_ROWS, ACTIVITY_ROWS), with the cue Rows.heard resolves (the fallback the game uses); every
# MusicRows.CUES row; every Roster row's tag and hold sound (the hold sound as Rows.hold_of picks
# it); every WindupRows sound; every SpecialCues special's tell; every elite affix tag; the sound
# bank's composed id families (cause_note_, grid_note_, pilot_quote_, set_answer_,
# companion_assist_, say|); and every bank cue no fact above names ("bank:").
# By scanning the source text of res://src (a headless test cannot run the game's call sites):
# each publisher of boss_attack_telegraphed, each attack_cued emit and _phases.cue call, each
# world_fact.emit of a kind the list marks as relayed, each pressure cue, each warn_sound
# assignment, and each file-level const, play() or Foley call that names a bank cue ("site:").
# Park telegraph sounds and the riser and stinger cues are covered by their WORLD_ROWS and
# MusicRows.CUES rows. A scanned id names its file and the function that holds the call
# ("emit:arena_wave@overtime.gd:_land_wave"), so a new call site, or one moved to another
# function, fails the test until the list is updated.
# Not covered: a sound played from a call pattern the scan does not know (an id built at run time
# from two strings), and the weather rows' music cues in the park files.

var _t := T.new("sound_twins_test")

const TABLES := ["ROWS", "UI_ROWS", "LOOT_ROWS", "WORLD_ROWS", "THREAT_ROWS", "LINE_ROWS", "STATE_ROWS", "ACTIVITY_ROWS"]
const SKIP_FILES := ["sfx_bank.gd", "mix_rows.gd", "event_kinds.gd", "rows.gd", "sound_twins.gd"]


static func bank_cues() -> Array:
	var seen := {}
	for id in SfxBank.TRIM_DB:
		seen[id] = true
	for id in SfxBank.EVENT_CUES:
		seen[id] = true
	for id in SfxBank.STINGER_BEATS:
		seen[id] = true
	for base in SfxBank.TIER_CUES:
		seen[base] = true
		for id in SfxBank.TIER_CUES[base]:
			seen[id] = true
	for list in [SfxBank.DANGER_SOUNDS, SfxBank.KEYED_SOUNDS, SfxBank.KEST_SOUNDS]:
		for id in list:
			seen[id] = true
	var out := seen.keys()
	out.sort()
	return out


static func _source_files(dir := "res://src") -> Array:
	var out: Array = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_source_files(dir + "/" + d))
	out.sort()
	return out


static func _matches(pattern: String, text: String) -> Array:
	var re := RegEx.new()
	re.compile(pattern)
	return re.search_all(text)


# The facts, as {fact id: cue heard}. relay is the list's RELAY dictionary: it names which shared
# rows get their call sites enumerated.
static func universe(relay: Dictionary) -> Dictionary:
	var out := {}
	var bank := bank_cues()
	var tables: Dictionary = (load("res://src/core/event_kinds.gd") as GDScript).get_script_constant_map()
	for table in TABLES:
		for key in tables[table]:
			var row: Dictionary = tables[table][key]
			var cue := Rows.heard(row)
			if cue == "":
				cue = String(row.get("sound_next", row.get("sound", "")))
			if cue != "" and cue != "none":
				out["%s:%s" % [table, key]] = cue
	for key in MusicRows.CUES:
		out["music:%s" % key] = key
	for unit in Roster.ROWS:
		var r: Dictionary = Roster.ROWS[unit]
		if String(r.get("tag", "")) != "":
			out["roster:%s.tag" % unit] = String(r["tag"])
		if bool(r.get("holds", false)) and Rows.hold_of(String(r.get("mechanic", ""))) != "":
			out["roster:%s.hold" % unit] = Rows.hold_of(String(r["mechanic"]))
	for kind in WindupRows.ROWS:
		var sound := String(WindupRows.ROWS[kind].get("sound", "none"))
		if sound != "none":
			out["windup:%s" % kind] = sound
	for special in SpecialCues.SPECIALS:
		out["special:%s.tell" % special] = "%s_tell" % special
	for id in Affixes.ROWS:
		out["affix:%s" % id] = String(Affixes.ROWS[id]["mechanic_tag"])
	for prefix in [SfxBank.CAUSE_NOTE, SfxBank.GRID_NOTE, SfxBank.PILOT_QUOTE, SfxBank.SET_ANSWER, SfxBank.ASSIST_STING, SfxBank.SAY]:
		out["family:%s" % prefix] = prefix
	var bank_set := {}
	for id in bank:
		bank_set[id] = true
	var tele_cue := Rows.heard(tables["ROWS"]["boss_attack_telegraphed"])
	var cued_cue := Rows.heard(tables["ROWS"]["attack_cued"])
	var seen_pressure := {}
	for path in _source_files():
		var base: String = path.get_file()
		if base in SKIP_FILES:
			continue
		var text := FileAccess.get_file_as_string(path)
		var found := scan_text(base, text, relay, bank_set)
		for id in found:
			var hit: Dictionary = found[id]
			match hit["kind"]:
				"tele":
					out[id] = tele_cue
				"cued":
					out[id] = cued_cue
				"emit":
					out[id] = Rows.heard(tables["WORLD_ROWS"][hit["key"]])
				"sig":
					out[id] = Rows.heard(tables["ROWS"][hit["key"]])
				_:
					out[id] = hit["key"]
		for pattern in ["pressure_cue\\.emit\\(\"([a-z_0-9]+)\"", "_on_pressure_cue\\(\"([a-z_0-9]+)\""]:
			for m in _matches(pattern, text):
				if not seen_pressure.has(m.get_string(1)):
					seen_pressure[m.get_string(1)] = true
					out["pressure:%s" % m.get_string(1)] = m.get_string(1)
	var named := {}
	for fact in out:
		named[out[fact]] = true
	for id in bank:
		if not named.has(id):
			out["bank:%s" % id] = id
	return out


# The call sites in one file's text, keyed on the enclosing function and what the line names, never
# on a count across the file, so adding a call elsewhere changes no other id. Returns
# {id: {"kind", "key"}}. A repeat inside one function gets "#2". Pure, so a test can feed it text.
static func scan_text(base: String, text: String, relay: Dictionary, bank_set: Dictionary) -> Dictionary:
	var hits: Array = []
	var add := func(pattern: String, kind: String, key: String, tag_pattern: String) -> void:
		for m in _matches(pattern, text):
			var tag := ""
			if tag_pattern != "":
				var rest := text.substr(m.get_end(), 90).get_slice("\n", 0)
				var tm := RegEx.create_from_string(tag_pattern).search(rest)
				tag = tm.get_string(1) if tm != null else ""
			hits.append([m.get_start(), kind, key, tag if m.get_group_count() == 0 else m.get_string(1)])
	if relay.has("ROWS:boss_attack_telegraphed"):
		add.call("_publish\\(\"boss_attack_telegraphed\",\\s*\\[|boss_attack_telegraphed\\.emit\\(", "tele", "", "^\\s*\"?([A-Za-z_0-9]+)")
	if relay.has("ROWS:attack_cued"):
		add.call("attack_cued\\.emit\\(|_phases\\.cue\\(", "cued", "", "\"([A-Za-z_0-9]+)\"")
	for fact in relay:
		var key := String(fact).get_slice(":", 1)
		if String(fact).begins_with("WORLD_ROWS:"):
			add.call("world_fact\\.emit\\(\"%s\"" % key, "emit", key, "")
		elif String(fact).begins_with("ROWS:") and key not in ["boss_attack_telegraphed", "attack_cued", "hold_started"]:
			add.call("\\b%s\\.emit\\(" % key, "sig", key, "")
	add.call("warn_sound = \"([a-z_0-9]+)\"", "warn", "", "")
	for pattern in ["(?m)^const [A-Z_0-9]+ := \"([a-z_0-9]+)\"", "play\\([^\\n]*\"SFX\", \"([a-z_0-9]+)\"\\)", "\\bplay\\(\"([a-z_0-9]+)\"", "(?:one_shot|player)\\(\"([a-z_0-9]+)\""]:
		for m in _matches(pattern, text):
			if bank_set.has(m.get_string(1)):
				hits.append([m.get_start(), "site", m.get_string(1), ""])
	var out := {}
	if hits.is_empty():
		return out
	var funcs: Array = []
	for m in _matches("(?m)^(?:static )?func (\\w+)", text):
		funcs.append([m.get_start(), m.get_string(1)])
	hits.sort_custom(func(a, b): return a[0] < b[0])
	for hit in hits:
		var fn := "top"
		for f in funcs:
			if f[0] <= hit[0]:
				fn = f[1]
		var id := ""
		match hit[1]:
			"tele":
				id = "tele@%s:%s:%s" % [base, fn, hit[3]]
			"cued":
				id = "cued@%s:%s:%s" % [base, fn, hit[3] if hit[3] != "" else "emit"]
			"emit":
				id = "emit:%s@%s:%s" % [hit[2], base, fn]
			"sig":
				id = "sig:%s@%s:%s" % [hit[2], base, fn]
			"warn":
				id = "warn_sound:%s@%s:%s" % [hit[3], base, fn]
				hit[2] = hit[3]
			_:
				id = "site:%s:%s:%s" % [base, fn, hit[2]]
		var n := 1
		var unique := id
		while out.has(unique):
			n += 1
			unique = "%s#%d" % [id, n]
		out[unique] = {"kind": hit[1], "key": hit[2]}
	return out


# Every "<signal>.emit(" and world_fact.emit("<kind>" in res://src: {name: ["file:function", ...]}.
static func emit_index() -> Dictionary:
	var index := {}
	for path in _source_files():
		if path.get_file() in SKIP_FILES:
			continue
		var text := FileAccess.get_file_as_string(path)
		var ms := _matches("(\\w+)\\.emit\\(\"?(\\w*)", text)
		if ms.is_empty():
			continue
		var funcs: Array = []
		for m in _matches("(?m)^(?:static )?func (\\w+)", text):
			funcs.append([m.get_start(), m.get_string(1)])
		for m in ms:
			var fn := "top"
			for f in funcs:
				if f[0] <= m.get_start():
					fn = f[1]
			var site := "%s:%s" % [path.get_file(), fn]
			for name in [m.get_string(1), m.get_string(2)]:
				if name == "":
					continue
				if not index.has(name):
					index[name] = []
				if not index[name].has(site):
					index[name].append(site)
	return index


# The facts that can fire in world 1, each with the site that puts it there: the dam and flume
# park files' telegraph, land and music forms; the roster units those files name or the roster
# marks world 1; the scanned call sites in the files that are world 1's own (Twins.WORLD1_FILES);
# and every table fact the emit index shows a firing site for. Returns {fact: site text}.
static func world1(facts: Dictionary, index: Dictionary) -> Dictionary:
	var out := {}
	var park_text := ""
	var land: Dictionary = (load("res://src/world/event_director.gd") as GDScript).get_script_constant_map()["PARK_LAND_FACTS"]
	for file in ["park_dam.json", "park_flume.json"]:
		var raw := FileAccess.get_file_as_string("res://src/world/park/" + file)
		park_text += raw
		var data: Dictionary = JSON.parse_string(raw)
		for row in data["event_rows"]:
			var form := String(row["telegraph"]["form"])
			for fact in ["WORLD_ROWS:" + form, "WORLD_ROWS:" + String(land.get(form, ""))]:
				if facts.has(fact):
					out[fact] = "%s row %s" % [file, row["id"]]
			for phase in row["music_cue"]:
				out["music:" + String(row["music_cue"][phase])] = "%s row %s (%s)" % [file, row["id"], phase]
	for unit in Roster.ROWS:
		if int(Roster.ROWS[unit].get("world", 0)) == 1 or park_text.contains("\"%s\"" % unit):
			for fact in ["roster:%s.tag" % unit, "roster:%s.hold" % unit, "windup:%s" % unit, "special:%s.tell" % unit]:
				if facts.has(fact):
					out[fact] = "roster row %s" % unit
	for id in facts:
		var text := String(id)
		var at := text.find("@")
		if text.begins_with("site:") or text.begins_with("warn_sound:") or at > 0:
			var file := text.get_slice(":", 1) if text.begins_with("site:") else text.substr(at + 1).get_slice(":", 0)
			if file in Twins.WORLD1_FILES:
				out[id] = text
		elif text.begins_with("pressure:"):
			out[id] = "chaser.gd and presentation.gd"
		elif text.contains(":"):
			var key := text.get_slice(":", 1)
			if text.get_slice(":", 0) in TABLES and index.has(key):
				out[id] = ", ".join(index[key])
	for id in Twins.WORLD1_EXTRA:
		if facts.has(id):
			out[id] = String(Twins.WORLD1_EXTRA[id])
	return out


# The body of function fn in text: the lines from its declaration to the next top-level func.
static func function_body(text: String, fn: String) -> Array:
	var body: Array = []
	var inside := false
	for line in text.split("\n"):
		if line.begins_with("func ") or line.begins_with("static func "):
			if inside:
				break
			var head: String = line.trim_prefix("static ").trim_prefix("func ")
			inside = head.begins_with(fn + "(")
			continue
		if inside:
			body.append(line)
	return body


# Why a twin does not hold, or "". The token must be a real drawing line inside the named function.
static func twin_problem(row: Dictionary, toasts: Array) -> String:
	for field in ["script", "fn", "token", "what"]:
		if String(row.get(field, "")) == "":
			return "no %s" % field
	var path: String = row["script"]
	if not FileAccess.file_exists(path):
		return "script %s does not exist" % path
	var token: String = row["token"]
	if token.contains(".connect("):
		return "token \"%s\" is a signal hookup, not the drawing line" % token
	if token.length() < 12:
		return "token \"%s\" is too short to point at a drawing call" % token
	var body := function_body(FileAccess.get_file_as_string(path), String(row["fn"]))
	if body.is_empty():
		return "%s has no function %s" % [path, row["fn"]]
	var found := false
	for line in body:
		var code := String(line).strip_edges()
		if code.begins_with("#") or code.begins_with("const ") or code.begins_with("signal ") or code.begins_with("@onready"):
			continue
		# A "var x = call(...)" line counts as the call; a token that only spells the declaration does not.
		if code.begins_with("var ") and code.find(token) < code.find("="):
			continue
		if code.contains(token):
			found = true
			break
	if not found:
		return "%s function %s has no code line with \"%s\" (a declaration, a comment or another function does not count)" % [path, row["fn"], token]
	if row.has("toast") and not toasts.has(row["toast"]):
		return "the HUD does not toast %s" % row["toast"]
	for extra in row.get("also", []):
		var more := twin_problem(extra, toasts)
		if more != "":
			return "second twin: " + more
	return ""


# An open row names "file:function" and a "pattern" that function must contain, so the row is tied to
# the code that plays the sound and not to a line number.
static func open_problems(row: Dictionary) -> Array:
	var plays := String(row.get("plays", ""))
	var path := "res://" + plays.get_slice(":", 0)
	var fn := plays.get_slice(":", 1)
	if plays.count(":") != 1 or not FileAccess.file_exists(path):
		return ["open row %s: \"plays\" must be file:function and name a real file (%s)" % [row.get("fact", "?"), plays]]
	var found := false
	for line in function_body(FileAccess.get_file_as_string(path), fn):
		if String(row.get("pattern", "")) != "" and String(line).contains(String(row["pattern"])):
			found = true
	if not found:
		return ["open row %s: function %s in %s has no line with \"%s\"" % [row.get("fact", "?"), fn, path, row.get("pattern", "")]]
	return []


# Every problem with a classification of the universe, and the counts. data holds ACT, OPEN, RELAY
# and NOT_ACT as in sound_twins.gd; pins holds open, untraced and danger.
static func audit(facts: Dictionary, data: Dictionary, pins: Dictionary, danger: Array, toasts: Array, w1 := {}) -> Dictionary:
	var errors: Array = []
	var kind_of := {}
	var traced := {}
	var note := func(id: String, kind: String, was_traced: bool) -> void:
		if kind_of.has(id):
			errors.append("%s is listed twice (%s and %s)" % [id, kind_of[id], kind])
		kind_of[id] = kind
		traced[id] = was_traced
	for row in data["ACT"]:
		var problem := twin_problem(row, toasts)
		if problem != "":
			errors.append("twin for %s: %s" % [row["facts"], problem])
		for id in row["facts"]:
			note.call(id, "act", bool(row.get("traced", false)))
			if row.has("cue") and facts.has(id) and facts[id] != row["cue"]:
				errors.append("%s now plays %s, the row says %s" % [id, facts[id], row["cue"]])
	for row in data["OPEN"]:
		errors.append_array(open_problems(row))
		note.call(row["fact"], "open", bool(row.get("traced", false)))
	for id in data["RELAY"]:
		note.call(id, "relay", true)
	for group in data["NOT_ACT"]:
		if String(group.get("why", "")) == "":
			errors.append("a not-act group has no reason")
		for id in group["facts"]:
			note.call(id, "not_act", bool(group.get("traced", false)) or w1.has(id))
	for id in w1:
		if kind_of.has(id) and not traced[id]:
			errors.append("world 1 fact %s (%s) is not traced" % [id, kind_of[id]])
	for id in facts:
		if not kind_of.has(id):
			errors.append("fact %s (cue %s) is not classified" % [id, facts[id]])
	for id in kind_of:
		if not facts.has(id):
			errors.append("%s is listed but the game has no such fact" % id)
	for id in data["RELAY"]:
		var prefix := ""
		if String(id).begins_with("WORLD_ROWS:"):
			prefix = "emit:%s@" % String(id).trim_prefix("WORLD_ROWS:")
		elif id == "ROWS:boss_attack_telegraphed":
			prefix = "tele@"
		elif id == "ROWS:attack_cued":
			prefix = "cued@"
		if prefix != "" and not facts.keys().any(func(f): return String(f).begins_with(prefix)):
			errors.append("relay %s has no call site to judge" % id)
	var counts := {"act": 0, "open": 0, "relay": 0, "not_act": 0, "untraced": 0, "danger_not_act": 0}
	var danger_reasons: Array = []
	for id in kind_of:
		if not facts.has(id):
			continue
		counts[kind_of[id]] += 1
		if not traced[id]:
			counts["untraced"] += 1
			counts["untraced_" + kind_of[id]] = int(counts.get("untraced_" + kind_of[id], 0)) + 1
		if kind_of[id] == "not_act" and danger.has(facts[id]):
			counts["danger_not_act"] += 1
			danger_reasons.append("%s (%s) is %s" % [id, facts[id], kind_of[id]])
	for cue in danger:
		if not facts.values().has(cue):
			errors.append("DANGER_SOUNDS cue %s is the cue of no fact" % cue)
	if counts["open"] != int(pins["open"]):
		errors.append("%d open rows, pinned at %d" % [counts["open"], pins["open"]])
	if counts["untraced"] > int(pins["untraced"]):
		errors.append("%d untraced rows, pinned at most %d" % [counts["untraced"], pins["untraced"]])
	if counts["danger_not_act"] != int(pins["danger"]):
		errors.append("%d danger-listed cues filed not act-on, pinned at %d" % [counts["danger_not_act"], pins["danger"]])
	return {"errors": errors, "counts": counts, "danger": danger_reasons}


func _data() -> Dictionary:
	return {"ACT": Twins.ACT.duplicate(true), "OPEN": Twins.OPEN.duplicate(true), "RELAY": Twins.RELAY.duplicate(true), "NOT_ACT": Twins.NOT_ACT.duplicate(true)}


# Planted cases audit a small fact set, so the untraced count is not what they test.
func _plant_pins() -> Dictionary:
	var pins := _pins()
	pins["untraced"] = 99999
	return pins


func _pins() -> Dictionary:
	return {"open": Twins.OPEN_PINNED, "untraced": Twins.UNTRACED_PINNED, "danger": Twins.DANGER_NOT_ACT_PINNED}


func _initialize() -> void:
	var toasts: Array = Hud.toast_kinds()
	var facts := universe(Twins.RELAY)
	var index := emit_index()
	var w1 := world1(facts, index)
	var danger: Array = SfxBank.DANGER_SOUNDS
	var result := audit(facts, _data(), _pins(), danger, toasts, w1)
	for e in result["errors"]:
		print("  problem: %s" % e)
	_t.eq("every fact is classified, every twin holds and every world 1 fact is traced", result["errors"], [])
	var c: Dictionary = result["counts"]
	print("untraced by kind: act %d, open %d, not act %d" % [c.get("untraced_act", 0), c.get("untraced_open", 0), c.get("untraced_not_act", 0)])
	print("facts: %d; act-on with a twin: %d; open: %d; relay: %d; not act-on: %d; untraced: %d (pinned at most %d); world 1 facts: %d" % [facts.size(), c["act"], c["open"], c["relay"], c["not_act"], c["untraced"], Twins.UNTRACED_PINNED, w1.size()])
	var unsited := 0
	var unsited_ids: Array = []
	for id in facts:
		var table := String(id).get_slice(":", 0)
		if table in TABLES and not w1.has(id):
			unsited += 1
			unsited_ids.append(id)
	print("  unsited: %s" % ", ".join(unsited_ids))
	print("table facts with no firing site found, so outside the world 1 check: %d (pinned at most %d)" % [unsited, Twins.UNSITED_PINNED])
	_t.check("the unsited table facts do not grow", unsited <= Twins.UNSITED_PINNED, str(unsited))
	_t.eq("the kinds add up to the facts", c["act"] + c["open"] + c["relay"] + c["not_act"], facts.size())
	var twin_of := {}
	for row in Twins.ACT:
		for id in row["facts"]:
			twin_of[id] = "%s:%s" % [String(row["script"]).get_file(), row["fn"]]
	for row in Twins.OPEN:
		twin_of[row["fact"]] = "OPEN [%s] at %s" % [row.get("severity", "warning"), row["plays"]]
	for id in w1:
		print("  W1 %s | cue %s | site %s | %s" % [id, facts[id], w1[id], twin_of.get(id, "relay or not act-on")])
	for row in Twins.OPEN:
		print("  OPEN%s: %s (cue %s) at %s; %s" % [" [" + String(row["severity"]) + "]" if row.has("severity") else "", row["fact"], facts.get(row["fact"], "?"), row["plays"], row["what"]])
	for line in result["danger"]:
		print("  danger-listed cue filed not act-on: %s" % line)

	# Planted bad cases. Each must produce its error from the audit and nothing else.
	var plant := func(label: String, planted_facts: Dictionary, data: Dictionary, pins: Dictionary, needle: String, planted_w1 := {}) -> void:
		var errors: Array = audit(planted_facts, data, pins, danger, toasts, planted_w1)["errors"]
		_t.check("planted: %s is caught" % label, errors.size() == 1 and String(errors[0]).contains(needle), str(errors))

	var with_new := facts.duplicate()
	with_new["planted:new_warning"] = "planted_cue"
	plant.call("a new fact with no row", with_new, _data(), _plant_pins(), "planted:new_warning (cue planted_cue) is not classified")

	var second_use := facts.duplicate()
	second_use["planted:second_use"] = "klaxon"
	plant.call("a second use of a cue that already has a row", second_use, _data(), _plant_pins(), "planted:second_use (cue klaxon) is not classified")

	var base_data := _data()
	base_data["OPEN"].append({"fact": "planted:new_warning", "traced": true, "plays": "src/ui/hud.gd:toast_kind", "pattern": "toast(toast_text(kind, fields)", "what": "x"})
	plant.call("an open row past the pin", with_new, base_data, _plant_pins(), "open rows, pinned at")
	var bad_open := _data()
	bad_open["OPEN"].append({"fact": "planted:new_warning", "traced": true, "plays": "src/ui/hud.gd:toast_kind", "pattern": "this call is not in that function", "what": "x"})
	var one_more := _plant_pins()
	one_more["open"] = int(one_more["open"]) + 1
	plant.call("an open row whose function does not hold the call", with_new, bad_open, one_more, "has no line with")

	var twin := func(script: String, fn: String, token: String, traced := true) -> Dictionary:
		var data := _data()
		data["ACT"].append({"facts": ["planted:new_warning"], "traced": traced, "what": "x", "script": script, "fn": fn, "token": token})
		return data
	plant.call("a twin whose script is missing", with_new, twin.call("res://src/ui/not_a_script.gd", "setup", "game.events.threat_rose.connect("), _plant_pins(), "does not exist")
	plant.call("a twin whose function is gone", with_new, twin.call("res://src/ui/hud.gd", "this_function_was_deleted", "toast(toast_text(kind, fields)"), _plant_pins(), "has no function")
	plant.call("a weak token that is only a declaration", with_new, twin.call("res://src/ui/hud.gd", "toast_kinds", "var out: Array[String] = []"), _plant_pins(), "has no code line")
	plant.call("a token that sits in another function", with_new, twin.call("res://src/ui/hud.gd", "toast_kind", "_status.set_status(tbl.local(run.stage)"), _plant_pins(), "has no code line")
	plant.call("a token too short to point at anything", with_new, twin.call("res://src/ui/hud.gd", "setup", "toast("), _plant_pins(), "too short")
	plant.call("a token that is a signal hookup", with_new, twin.call("res://src/ui/hud.gd", "setup", "game.events.threat_rose.connect("), _plant_pins(), "signal hookup")
	plant.call("a toast the HUD does not show", with_new, _toast_twin("event_started"), _plant_pins(), "does not toast")
	plant.call("a world 1 fact that is not traced", with_new, twin.call("res://src/ui/hud.gd", "toast_kind", "toast(toast_text(kind, fields)", false), _plant_pins(), "is not traced", {"planted:new_warning": "planted site"})
	var good: Dictionary = twin.call("res://src/ui/hud.gd", "toast_kind", "toast(toast_text(kind, fields)")
	_t.eq("planted: a real twin for the new fact passes", audit(with_new, good, _plant_pins(), danger, toasts, {"planted:new_warning": "planted site"})["errors"], [])
	var many_untraced := _plant_pins()
	many_untraced["untraced"] = 0
	var raised: Array = audit(facts, _data(), many_untraced, danger, toasts, w1)["errors"]
	_t.check("planted: more untraced rows than the pin is caught", raised.size() == 1 and String(raised[0]).contains("untraced rows, pinned"), str(raised))

	# Planted: two call sites swapped in a made-up source. Ids follow the enclosing function, so each row
	# still attaches to its own function, and a row keyed on the old place no longer matches.
	var relay := {"WORLD_ROWS:arena_wave": "x", "WORLD_ROWS:arena_locked": "x"}
	var source_a := "func alpha():\n\tctx.events.world_fact.emit(\"arena_wave\", c)\n\nfunc beta():\n\tctx.events.world_fact.emit(\"arena_locked\", c)\n"
	var source_b := "func newcomer():\n\tctx.events.world_fact.emit(\"arena_locked\", c)\n\nfunc alpha():\n\tctx.events.world_fact.emit(\"arena_locked\", c)\n\nfunc beta():\n\tctx.events.world_fact.emit(\"arena_wave\", c)\n"
	var ids_a := scan_text("x.gd", source_a, relay, {}).keys()
	var ids_b := scan_text("x.gd", source_b, relay, {}).keys()
	_t.eq("planted: call sites in a made-up source take their function's name", ids_a, ["emit:arena_wave@x.gd:alpha", "emit:arena_locked@x.gd:beta"])
	_t.check("planted: swapping two call sites and adding another moves only the ids that moved", ids_b.has("emit:arena_wave@x.gd:beta") and ids_b.has("emit:arena_locked@x.gd:alpha") and ids_b.has("emit:arena_locked@x.gd:newcomer") and not ids_b.has("emit:arena_wave@x.gd:alpha"), str(ids_b))
	var swapped_facts := {}
	for id in ids_b:
		swapped_facts[id] = "arena_wave_whistle"
	var stale_data := {"ACT": [], "OPEN": [], "RELAY": {}, "NOT_ACT": [{"why": "x", "traced": true, "facts": ["emit:arena_wave@x.gd:alpha", "emit:arena_locked@x.gd:alpha", "emit:arena_locked@x.gd:newcomer", "emit:arena_wave@x.gd:beta"]}]}
	var stale: Array = audit(swapped_facts, stale_data, {"open": 0, "untraced": 99, "danger": 0}, [], toasts)["errors"]
	_t.check("planted: a row still keyed on the old place of a moved call site is caught", stale.size() == 1 and String(stale[0]).contains("emit:arena_wave@x.gd:alpha is listed but"), str(stale))
	quit(_t.verdict())


func _toast_twin(kind: String) -> Dictionary:
	var data := _data()
	data["ACT"].append({"facts": ["planted:new_warning"], "traced": true, "what": "x", "script": "res://src/ui/hud.gd", "fn": "toast_kind", "token": "toast(toast_text(kind, fields), EventKinds.color(kind)", "toast": kind})
	return data
