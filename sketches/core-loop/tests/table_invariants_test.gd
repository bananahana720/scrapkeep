extends SceneTree

# Cross-table invariants the game reads without checking (invariants inventory, 2026-11-08).
# Each check names the consumer that would crash or misread if the row drifted. The content
# registry (content_registry.gd) pins its own 27 tables; these are the ones it does not reach.
const AlphaDefs := preload("res://src/core/alpha_defs.gd")
const ParkDefs := preload("res://src/core/park_defs.gd")
const Director := preload("res://src/world/director.gd")
const Cards := preload("res://src/world/director_cards.gd")
const ChallengeDials := preload("res://src/core/challenge_dials.gd")
const RunState := preload("res://src/core/run_state.gd")
const Ultimate := preload("res://src/combat/ultimate.gd")
const Weapons := preload("res://src/combat/weapons.gd")
const Synergies := preload("res://src/build/synergies.gd")
const Parts := preload("res://src/build/parts.gd")
const ShiftBoard := preload("res://src/core/shift_board.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Elements := preload("res://src/build/elements.gd")
const Rogue := preload("res://src/combat/rogue.gd")
const Secrets := preload("res://src/core/secrets.gd")
const Panels := preload("res://src/build/panels.gd")
const Nemesis := preload("res://src/combat/nemesis.gd")
const Relics := preload("res://src/build/relics.gd")
const MusicRows := preload("res://src/presentation/music_rows.gd")
const Achievements := preload("res://src/core/achievements.gd")
const MaterialSlots := preload("res://src/presentation/material_slots.gd")
const T := preload("res://tests/support/t.gd")

const WORLD_ONE_PARKS := ["res://src/world/park/park_dam.json", "res://src/world/park/park_flume.json"]
const LOOK_CALL := "(?:look_texture|warm_look)\\(\"([A-Za-z0-9_.-]+)\""

var _t := T.new("table_invariants_test")


func _initialize() -> void:
	_heft_tables()
	_dial_lengths()
	for table in [AlphaDefs, ParkDefs]:
		_stage_rows(table)
		_synergies(table)
	_run_tiers()
	_shift_board_pilots()
	_rogues_are_bosses()
	_world_one_secrets()
	_nemesis_axes()
	_relic_cooldowns()
	_park_scores()
	_look_textures()
	_panel_readers()
	_no_rows_on_player_died()
	quit(_t.verdict())


func _label(table) -> String:
	return "park" if table == ParkDefs else "alpha"


# combat.gd reads CLIP_CAP[_heft_index()], rivet_kit.gd CUTTER_WIDTH[class - 1] and
# warden_reactor.gd HEFT_CLASS_AT[class - 1]: one entry per heft class, or class V crashes.
func _heft_tables() -> void:
	var classes: int = RunState.HEFT_CLASS_AT.size()
	for pair in [["Ultimate.HEFT_MULT", Ultimate.HEFT_MULT], ["Ultimate.ARC_REACH", Ultimate.ARC_REACH],
			["Ultimate.LANDING_RADIUS", Ultimate.LANDING_RADIUS], ["Weapons.CUTTER_WIDTH", Weapons.CUTTER_WIDTH],
			["Weapons.CLIP_CAP", Weapons.CLIP_CAP]]:
		_t.eq("%s has one entry per heft class" % pair[0], (pair[1] as Array).size(), classes)


# by_stage reads identity past the list's end and by_phase repeats the last entry, so a short
# list silently drops a stage's or a phase's tuning.
func _dial_lengths() -> void:
	for key in ChallengeDials.DEFAULTS:
		var want := 6 if String(key).ends_with("_by_stage") else 4 if String(key).ends_with("_by_phase") else -1
		if want < 0:
			continue
		var got = ChallengeDials.DEFAULTS[key]
		_t.check("%s has %d entries" % [key, want], got is Array and (got as Array).size() == want, str(got))


# director.gd divides the spawn interval by threat and multiplies the crowd cap by the
# pressure row; a missing key reads 1.0 without a word.
func _stage_rows(table) -> void:
	var name := _label(table)
	_t.eq("%s: one pressure row per stage" % name, table.PRESSURE.size(), table.COUNT)
	for stage in range(1, table.COUNT + 1):
		var row: Dictionary = table.of(stage)
		_t.check("%s stage %d threat is above zero" % [name, stage], float(row.get("threat", 0.0)) > 0.0, str(row.get("threat")))
		var pressure: Dictionary = row.get("pressure", {})
		for key in Director.PRESSURE_KEYS:
			var v := float(pressure.get(key, -1.0))
			_t.check("%s stage %d pressure %s in [0.5, 2.0]" % [name, stage, key], v >= 0.5 and v <= 2.0, str(pressure.get(key)))


# synergies.gd trusts the table's list: an unknown id or a missing part drops the synergy or its
# evolution from every run on that table without a warning.
func _synergies(table) -> void:
	var name := _label(table)
	for id in table.SYNERGIES:
		_t.check("%s synergy %s is a trick row" % [name, id], Synergies.ROWS.has(id))
		if not Synergies.ROWS.has(id):
			continue
		var maker: String = Synergies.ROWS[id]["maker"]
		var pieces: Array = table.PARTS.filter(func(part): return Parts.maker_of(part) == maker)
		_t.check("%s trick %s has two %s parts in the table's parts" % [name, id, maker], pieces.size() >= Synergies.AT, str(pieces))


# director.gd interval() and cap() multiply by these weights; zero or less stalls or floods a stage.
func _run_tiers() -> void:
	for tier in Cards.RUN_TIERS:
		var row: Dictionary = Cards.RUN_TIERS[tier]
		for key in ["cap_weight", "interval_weight"]:
			_t.check("run tier %s %s is above zero" % [tier, key], float(row.get(key, 1.0)) > 0.0, str(row.get(key)))


# shift_board.gd shows a pilot-gated rung only when ClassDef.by_id finds the pilot: a typo hides
# the rung for good.
func _shift_board_pilots() -> void:
	var ids := ClassDef.all().map(func(p): return p.id)
	for id in ShiftBoard.RUNGS:
		var rung: Dictionary = ShiftBoard.RUNGS[id]
		if rung.has("pilot"):
			_t.check("shift board %s names a real pilot" % id, String(rung["pilot"]) in ids, String(rung["pilot"]))


# elements.gd elite_rules: "elites and bosses never lock"; a rogue missing from BOSS_KINDS can be
# frost-locked.
func _rogues_are_bosses() -> void:
	for id in Rogue.ROWS:
		_t.check("rogue %s counts as a boss for elements" % id, id in Elements.BOSS_KINDS)


# The camp's "Spillway secrets: N of 8" counts WORLD_CODEX[1]; each id needs something in world 1
# that files it (a field find, the clock door, or a park contraption's codex row).
func _world_one_secrets() -> void:
	var filed := {}
	for id in Secrets.FINDS:
		var find: Dictionary = Secrets.FINDS[id]
		if int(find.get("world", 0)) == 1 and find.get("codex") is Dictionary:
			filed[String(find["codex"].get("id", ""))] = id
	if Secrets.DOOR.get("codex") is Dictionary and int(Secrets.DOOR.get("world", 0)) == 1:
		filed[String(Secrets.DOOR["codex"].get("id", ""))] = "door"
	for path in WORLD_ONE_PARKS:
		_collect_codex(JSON.parse_string(FileAccess.get_file_as_string(path)), path.get_file(), filed)
	for id in Secrets.WORLD_CODEX[1]:
		_t.check("Spillway secret %s is filed by something in world 1" % id, filed.has(id), str(filed.keys()))


func _collect_codex(node, where: String, filed: Dictionary) -> void:
	if node is Dictionary:
		if node.get("codex") is Dictionary and node["codex"].has("id"):
			filed[String(node["codex"]["id"])] = where
		for key in node:
			_collect_codex(node[key], where, filed)
	elif node is Array:
		for item in node:
			_collect_codex(item, where, filed)


# nemesis.gd compares axis strings plainly; a typo means a panel or pack never leans.
func _nemesis_axes() -> void:
	for id in Panels.ROWS:
		for axis in Panels.ROWS[id].get("answers", []):
			_t.check("panel %s answer %s is a nemesis axis" % [id, axis], axis in Nemesis.AXES)
	for pilot in Nemesis.PILOT:
		for axis in Nemesis.PILOT[pilot]:
			_t.check("nemesis pilot %s axis %s is an axis" % [pilot, axis], axis in Nemesis.AXES)
	for kind in Nemesis.KIND_AXES:
		_t.check("nemesis kind %s is a director kind" % kind, kind in Director.KIND_NAMES)
		for axis in Nemesis.KIND_AXES[kind]:
			_t.check("nemesis kind %s axis %s is an axis" % [kind, axis], axis in Nemesis.AXES)


# build.gd undoes a relic by dividing the slot's cooldown scale by the row's cooldown.
func _relic_cooldowns() -> void:
	for id in Relics.ROWS:
		var row: Dictionary = Relics.ROWS[id]
		if row.has("cooldown"):
			var c := float(row["cooldown"])
			_t.check("relic %s cooldown in (0, 1]" % id, c > 0.0 and c <= 1.0, str(c))


# The launched table's stage rows name their ACE score directly; a typo falls back to synth.
func _park_scores() -> void:
	for stage in range(1, ParkDefs.COUNT + 1):
		var ace := String(ParkDefs.of(stage).get("music", {}).get("ace", ""))
		if ace == "":
			continue
		_t.check("park stage %d score %s has a manifest" % [stage, ace],
			FileAccess.file_exists("res://assets/music_ace/%s/manifest.json" % ace))


# palette.gd falls back to a flat painted texture, with one warning, when a look id is missing.
func _look_textures() -> void:
	var re := RegEx.create_from_string(LOOK_CALL)
	var ids := {}
	# Ids passed through a variable: the hero shells pick a map by slot, and the arena warms its
	# neutral looks from a list.
	var held := RegEx.create_from_string("\\bmap = \"([A-Za-z0-9_.-]+)\"")
	for path in _scripts("res://src"):
		var text := FileAccess.get_file_as_string(path)
		for m in re.search_all(text):
			ids[m.get_string(1)] = path
		if text.contains("look_texture(map"):
			for m in held.search_all(text):
				ids[m.get_string(1)] = path
	for id in preload("res://src/boss/arena.gd").NEUTRAL_LOOKS:
		ids[id] = "arena.gd"
	for slot in MaterialSlots.SLOTS.values():
		for id in (slot["textures"] as Dictionary).values():
			ids[id] = "material_slots.gd"
	_t.check("source names some look textures", ids.size() >= 3, str(ids.keys()))
	for id in ids:
		_t.check("look texture %s exists (%s)" % [id, ids[id].get_file()],
			ResourceLoader.exists("res://assets/textures/%s.webp" % id))


func _scripts(dir: String) -> Array:
	var out := []
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"):
			out.append(dir.path_join(file))
	for sub in DirAccess.get_directories_at(dir):
		out.append_array(_scripts(dir.path_join(sub)))
	return out


# panels.gd folds pct and add rows into sheet.mods / sheet.adds under the row's stat key; a key no
# script reads gives a panel that drops, stacks and does nothing.
func _panel_readers() -> void:
	var sources := {}
	for path in _scripts("res://src"):
		if path.get_file() != "panels.gd":
			sources[path] = FileAccess.get_file_as_string(path)
	for id in Panels.ROWS:
		var row: Dictionary = Panels.ROWS[id]
		if not String(row["kind"]) in ["pct", "add"]:
			continue
		var quoted := "\"%s\"" % row["stat"]
		var reader := ""
		for path in sources:
			if sources[path].contains(quoted):
				reader = path.get_file()
				break
		_t.check("panel %s stat %s has a reader" % [id, row["stat"]], reader != "", reader)


# Progress subscribes on the first physics frame, after flow, and flow ends the run inside its own
# player_died handler: progress closes the shift's time card on run_ended before it hears
# player_died. A row on player_died would stamp after the card closed; one needs progress to
# subscribe ahead of flow first.
func _no_rows_on_player_died() -> void:
	for id in Achievements.ROWS:
		_t.check("achievement %s does not listen on player_died" % id, Achievements.ROWS[id].get("on", "") != "player_died")
