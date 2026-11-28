extends RefCounted

const SourceScan := preload("res://tests/support/source_scan.gd")

const CORE_ROOT := "res://src/core"
const UPWARD_PATTERN := "[\"'](res://src/(?:build|combat|boss|world|movement|presentation|ui)/[^\"']+)[\"']"

const ALLOWED := [
	["res://src/core/beacon.gd", "res://src/combat/dispatcher.gd"],
	["res://src/core/beacon.gd", "res://src/combat/roster_dig.gd"],
	["res://src/core/beacon.gd", "res://src/presentation/material_slots.gd"],
	["res://src/core/beacon.gd", "res://src/presentation/recipe_props.gd"],
	["res://src/core/death_cause.gd", "res://src/combat/rogue.gd"],
	["res://src/core/flow.gd", "res://src/boss/arena.gd"],
	["res://src/core/flow.gd", "res://src/boss/boss.gd"],
	["res://src/core/flow.gd", "res://src/movement/tuning.gd"],
	["res://src/core/flow.gd", "res://src/ui/start_pick_card.gd"],
	["res://src/core/flow.gd", "res://src/world/event_director.gd"],
	["res://src/core/flow.gd", "res://src/world/park/park_map.gd"],
	["res://src/core/flow.gd", "res://src/world/victory_lap.gd"],
	["res://src/core/run_state.gd", "res://src/build/consumables.gd"],
	["res://src/core/run_state.gd", "res://src/build/fabricators.gd"],
	["res://src/core/run_state.gd", "res://src/build/panels.gd"],
	["res://src/core/run_state.gd", "res://src/build/parts.gd"],
	["res://src/core/run_state.gd", "res://src/build/relics.gd"],
	["res://src/core/run_state.gd", "res://src/combat/roster.gd"],
	["res://src/core/run_state.gd", "res://src/world/pockets/pocket_draw.gd"],
	["res://src/core/run_state.gd", "res://src/world/trade_pockets.gd"],
	["res://src/core/shift_board.gd", "res://src/build/parts.gd"],
	["res://src/core/upgrade_tree.gd", "res://src/combat/weapons.gd"],
	["res://src/core/upgrade_tree.gd", "res://src/movement/augments.gd"],
	["res://src/core/worlds.gd", "res://src/boss/boss.gd"],
	["res://src/core/worlds.gd", "res://src/boss/mind.gd"],
	["res://src/core/worlds.gd", "res://src/boss/waking.gd"],
]


func _pair_key(pair: Array) -> String:
	return "%s -> %s" % [pair[0], pair[1]]


func run(t) -> void:
	var allowed_set := {}
	for pair in ALLOWED:
		allowed_set[_pair_key(pair)] = true
	var found_set := {}
	var unexpected: Array[String] = []
	var hits: Dictionary = SourceScan.captures(t, [CORE_ROOT], UPWARD_PATTERN)
	for path in hits:
		for row in hits[path]:
			var key := _pair_key([path, row[1]])
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
