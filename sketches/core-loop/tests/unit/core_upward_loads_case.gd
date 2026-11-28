extends RefCounted

const CORE_ROOT := "res://src/core"
const UPWARD_PATTERN := "[\"'](res://src/(?:build|combat|boss|world|movement|presentation|ui)/[^\"']+)[\"']"

const ALLOWED := [
	["res://src/core/ability_state.gd", "res://src/ui/glyphs.gd"],
	["res://src/core/beacon.gd", "res://src/combat/dispatcher.gd"],
	["res://src/core/beacon.gd", "res://src/combat/roster_dig.gd"],
	["res://src/core/beacon.gd", "res://src/presentation/material_slots.gd"],
	["res://src/core/beacon.gd", "res://src/presentation/recipe_props.gd"],
	["res://src/core/death_cause.gd", "res://src/combat/rogue.gd"],
	["res://src/core/event_kinds.gd", "res://src/combat/boss_posture.gd"],
	["res://src/core/event_kinds.gd", "res://src/presentation/juice.gd"],
	["res://src/core/event_kinds.gd", "res://src/presentation/rows.gd"],
	["res://src/core/event_kinds.gd", "res://src/presentation/windup_rows.gd"],
	["res://src/core/flow.gd", "res://src/boss/arena.gd"],
	["res://src/core/flow.gd", "res://src/boss/boss.gd"],
	["res://src/core/flow.gd", "res://src/movement/speed_tier.gd"],
	["res://src/core/flow.gd", "res://src/movement/tuning.gd"],
	["res://src/core/flow.gd", "res://src/ui/start_pick_card.gd"],
	["res://src/core/flow.gd", "res://src/world/event_director.gd"],
	["res://src/core/flow.gd", "res://src/world/park/park_map.gd"],
	["res://src/core/flow.gd", "res://src/world/victory_lap.gd"],
	["res://src/core/palette.gd", "res://src/presentation/material_slots.gd"],
	["res://src/core/palette.gd", "res://src/presentation/time_sky.gdshader"],
	["res://src/core/run_log.gd", "res://src/combat/boss_posture.gd"],
	["res://src/core/run_log.gd", "res://src/movement/speed_tier.gd"],
	["res://src/core/run_state.gd", "res://src/build/consumables.gd"],
	["res://src/core/run_state.gd", "res://src/build/fabricators.gd"],
	["res://src/core/run_state.gd", "res://src/build/panels.gd"],
	["res://src/core/run_state.gd", "res://src/build/parts.gd"],
	["res://src/core/run_state.gd", "res://src/build/relics.gd"],
	["res://src/core/run_state.gd", "res://src/combat/roster.gd"],
	["res://src/core/run_state.gd", "res://src/world/pockets/pocket_draw.gd"],
	["res://src/core/run_state.gd", "res://src/world/trade_pockets.gd"],
	["res://src/core/run_tier.gd", "res://src/world/director_cards.gd"],
	["res://src/core/shift_board.gd", "res://src/build/parts.gd"],
	["res://src/core/stage_beats.gd", "res://src/boss/mind_dress.gd"],
	["res://src/core/stage_beats.gd", "res://src/boss/waking_dress.gd"],
	["res://src/core/stage_beats.gd", "res://src/build/scrap_field.gd"],
	["res://src/core/stage_beats.gd", "res://src/combat/boss_posture.gd"],
	["res://src/core/stage_beats.gd", "res://src/combat/warden.gd"],
	["res://src/core/stage_beats.gd", "res://src/presentation/dig_fx.gd"],
	["res://src/core/stage_beats.gd", "res://src/presentation/highdraft_fx.gd"],
	["res://src/core/stage_beats.gd", "res://src/world/activities.gd"],
	["res://src/core/stage_beats.gd", "res://src/world/launch.gd"],
	["res://src/core/stage_beats.gd", "res://src/world/victory_lap.gd"],
	["res://src/core/ultimate_meter.gd", "res://src/movement/speed_tier.gd"],
	["res://src/core/upgrade_tree.gd", "res://src/combat/weapons.gd"],
	["res://src/core/upgrade_tree.gd", "res://src/movement/augments.gd"],
	["res://src/core/worlds.gd", "res://src/boss/boss.gd"],
	["res://src/core/worlds.gd", "res://src/boss/mind.gd"],
	["res://src/core/worlds.gd", "res://src/boss/waking.gd"],
]


func _gd_files(root: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(root)
	if dir == null:
		return out
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.begins_with("."):
			name = dir.get_next()
			continue
		var full := root.path_join(name)
		if dir.current_is_dir():
			out.append_array(_gd_files(full))
		elif name.ends_with(".gd"):
			out.append(full)
		name = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out


func _pair_key(pair: Array) -> String:
	return "%s -> %s" % [pair[0], pair[1]]


func run(t) -> void:
	var re := RegEx.new()
	re.compile(UPWARD_PATTERN)
	var allowed_set := {}
	for pair in ALLOWED:
		allowed_set[_pair_key(pair)] = true
	var found_set := {}
	var unexpected: Array[String] = []
	for path in _gd_files(CORE_ROOT):
		var src := FileAccess.get_file_as_string(path)
		for m in re.search_all(src):
			var key := _pair_key([path, m.get_string(1)])
			if found_set.has(key):
				continue
			found_set[key] = true
			if not allowed_set.has(key):
				unexpected.append(key)
	var stale: Array[String] = []
	for pair in ALLOWED:
		var key := _pair_key(pair)
		if not found_set.has(key):
			stale.append(key)
	unexpected.sort()
	stale.sort()
	t.eq("no unlisted upward loads in src/core", unexpected, [])
	t.eq("no stale entries in core upward load allowlist", stale, [])
