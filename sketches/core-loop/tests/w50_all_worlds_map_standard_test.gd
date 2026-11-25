extends SceneTree

# Wave 50 unified pre-UI/UX integration verification across all 3 worlds (stages 1-6):
# - All 6 parks (W1-W3) meet Roboquest map standards, schema, and graph/bake integrity.
# - Full handover chain: dam -> flume -> pit -> sinkhole -> islands -> crown -> mind_sky_deck.
# - All 49 pockets + 6 stage secret rooms + W2/W3 shift variants (Malpais Monsoon, Highdraft Eclipse).
# - Additive RoR2/Isaac parts + relics + economy + 4th element "heat" + stage 1 plating 105.0.
# - PilotStory + WorkOrders + OverrideCodes + AltLoadouts + Codex/Progress/Foreman wiring.

const T := preload("res://tests/support/t.gd")
const ParkDefs := preload("res://src/core/park_defs.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const ParkSchema := preload("res://src/world/park/park_schema.gd")
const ParkGraph := preload("res://src/world/park/park_graph.gd")
const GraphTool := preload("res://tools/park_graph.gd")
const PocketLibrary := preload("res://src/world/pockets/pocket_library.gd")
const PocketDraw := preload("res://src/world/pockets/pocket_draw.gd")
const Secrets := preload("res://src/core/secrets.gd")
const ShiftVariants := preload("res://src/core/shift_variants.gd")
const StageModifier := preload("res://src/world/events/stage_modifier.gd")
const AlphaDefs := preload("res://src/core/alpha_defs.gd")
const Parts := preload("res://src/build/parts.gd")
const Relics := preload("res://src/build/relics.gd")
const Elements := preload("res://src/build/elements.gd")
const RunClock := preload("res://src/build/run_clock.gd")
const StakeDevices := preload("res://src/world/stake_devices.gd")
const ActiveDefs := preload("res://src/combat/actives/active_defs.gd")
const Consumables := preload("res://src/build/consumables.gd")
const Companion := preload("res://src/core/companion.gd")
const PilotStory := preload("res://src/core/pilot_story.gd")
const LoreRows := preload("res://src/core/lore_rows.gd")
const WorkOrders := preload("res://src/core/work_orders.gd")
const MetaOptions := preload("res://src/core/meta_options.gd")
const DeathCause := preload("res://src/core/death_cause.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const Codex := preload("res://src/core/codex.gd")
const Profile := preload("res://src/core/profile.gd")
const RunState := preload("res://src/core/run_state.gd")

const PARK_DIR := "res://src/world/park"
const ASSET_DIR := "res://assets/park"
const PARK_ORDER := ["park_dam", "park_flume", "park_pit", "park_sinkhole", "park_islands", "park_crown"]

var _t := T.new("w50_all_worlds_map_standard_test")


func _initialize() -> void:
	_check_all_six_parks_and_handovers()
	_check_pockets_secrets_and_variants()
	_check_isaac_ror2_stack()
	_check_story_progression_and_wiring()
	quit(_t.verdict())


func _check_all_six_parks_and_handovers() -> void:
	_t.eq("park table has 6 stages", ParkDefs.COUNT, 6)
	var maps := {}
	var graphs := {}
	for i in PARK_ORDER.size():
		var map_id: String = PARK_ORDER[i]
		var stage := i + 1
		_t.eq("stage %d maps to %s" % [stage, map_id], String(ParkDefs.of(stage)["map"]), map_id)
		var json_path := "%s/%s.json" % [PARK_DIR, map_id]
		var map := ParkMap.new(json_path)
		_t.check("%s loads cleanly" % map_id, map.ok, str(map.errors))
		if not map.ok:
			continue
		maps[map_id] = map
		var out_dir := "%s/%s" % [ASSET_DIR, map_id]
		var bake_path := "%s/bake.json" % out_dir
		var graph_path := "%s/graph.bin" % out_dir
		_t.check("%s has bake.json and graph.bin" % map_id, FileAccess.file_exists(bake_path) and FileAccess.file_exists(graph_path))
		var graph_stale: Array = GraphTool.freshness(json_path, out_dir, out_dir)
		_t.eq("%s committed graph is fresh" % map_id, graph_stale, [])
		var graph = ParkGraph.read(graph_path)
		_t.check("%s graph readable with nodes" % map_id, graph != null and graph.node_count() > 100)
		if graph != null:
			graphs[map_id] = graph
			var spawn_arr: Array = map.park["spawn"]["at"]
			var spawn_node: int = graph.nearest(Vector2(float(spawn_arr[0]), float(spawn_arr[1])))
			var lm_arr: Array = map.park["landmark"]["at"]
			var lm_node: int = graph.nearest(Vector2(float(lm_arr[0]), float(lm_arr[1])))
			_t.check("%s spawn and landmark sit on graph" % map_id, spawn_node >= 0 and lm_node >= 0)
		var districts: Array = map.park.get("district_rows", [])
		_t.check("%s declares district rows" % map_id, districts.size() >= 2, str(districts.size()))
		var ho: Dictionary = map.handover()
		_t.check("%s declares handover exit + arrives + atlas" % map_id,
			ho.has("exit") and ho.has("arrives") and ho.has("atlas"), str(ho.keys()))

	# Handover chain: intra-world stage pairs (dam->flume, pit->sinkhole, islands->crown)
	# plus world-end boss handovers (flume->slag_bowl, sinkhole->waking_shaft, crown->mind_sky_deck).
	var pairs := [
		["park_dam", "park_flume"],
		["park_pit", "park_sinkhole"],
		["park_islands", "park_crown"],
	]
	for pair in pairs:
		var from_id: String = pair[0]
		var to_id: String = pair[1]
		var exit_kind := String(maps[from_id].handover()["exit"]["kind"])
		var arrive_kind := String(maps[to_id].handover()["arrives"]["kind"])
		_t.eq("handover %s -> %s kind pair valid" % [from_id, to_id],
			String(ParkSchema.HANDOVER_PAIRS.get(exit_kind, "")), arrive_kind)
	_t.eq("park_flume approach leads to slag_bowl", String(maps["park_flume"].park.get("approach", {}).get("to", "")), "slag_bowl")
	_t.eq("park_sinkhole exit drops into waking_shaft",
		[String(maps["park_sinkhole"].handover()["exit"]["kind"]), String(maps["park_sinkhole"].park.get("approach", {}).get("to", ""))],
		["drop", "waking_shaft"])
	_t.eq("park_crown approach leads to mind_sky_deck", String(maps["park_crown"].park.get("approach", {}).get("to", "")), "mind_sky_deck")


func _check_pockets_secrets_and_variants() -> void:
	_t.eq("PocketLibrary W1 rows stay pinned at 25", PocketLibrary.rows().size(), 25)
	_t.eq("PocketLibrary W2 rows == 12", PocketLibrary.rows_for_world(2).size(), 12)
	_t.eq("PocketLibrary W3 rows == 12", PocketLibrary.rows_for_world(3).size(), 12)
	_t.eq("PocketLibrary all_rows == 49", PocketLibrary.all_rows().size(), 49)

	var all_rooms := Secrets.all_rooms()
	_t.eq("Secrets.all_rooms has 6 stage rooms", all_rooms.size(), 6)
	var covered_maps := {}
	for rid in all_rooms:
		covered_maps[String(all_rooms[rid]["map"])] = rid
	for map_id in PARK_ORDER:
		_t.check("secret room covers %s" % map_id, covered_maps.has(map_id), map_id)

	_t.check("W2/W3 shift variants registered",
		ShiftVariants.MALPAIS_MONSOON in ShiftVariants.BUILT and ShiftVariants.HIGHDRAFT_ECLIPSE in ShiftVariants.BUILT)
	_t.eq("Monsoon has 2 W2 caches", ShiftVariants.MONSOON_CACHES.size(), 2)
	_t.eq("Eclipse has 2 W3 caches", ShiftVariants.ECLIPSE_CACHES.size(), 2)

	# World-aware pocket draw smoke on W2 (stage 3) and W3 (stage 5).
	for stage in [3, 5]:
		var map_id := String(ParkDefs.of(stage)["map"])
		var map := ParkMap.new("%s/%s.json" % [PARK_DIR, map_id])
		var graph = ParkGraph.read("%s/%s/graph.bin" % [ASSET_DIR, map_id])
		var prepared := PocketDraw.prepare_world(graph, map)
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([78000, 1, stage, "w50_unified"])
		var drawn := PocketDraw.draw_for_world(prepared, map, stage, rng)
		_t.check("stage %d (%s) world-aware draw places pockets" % [stage, map_id], not drawn.sites.is_empty())


func _check_isaac_ror2_stack() -> void:
	_t.eq("AlphaDefs stage 1 warden_plating == 105.0 (W46 close preserved)", float(AlphaDefs.DEFS[0]["warden_plating"]), 105.0)
	_t.eq("AlphaDefs.PARTS pinned at 71", AlphaDefs.PARTS.size(), 71)
	_t.eq("AlphaDefs.EXPANSION_PARTS == 8", AlphaDefs.EXPANSION_PARTS.size(), 8)
	for pid in AlphaDefs.EXPANSION_PARTS:
		_t.check("expansion part %s admitted and defined" % pid, AlphaDefs.part_in_play(pid) and Parts.def(pid) != null)

	_t.eq("Relics alt_loadouts == 6 W2/W3 kit swaps", Relics.alt_loadouts().size(), 6)
	_t.check("Relics.all_ids includes base + ALT_ROWS", Relics.all_ids().size() >= Relics.ROWS.size() + 12)

	_t.eq("RunClock quick break covers all 6 stages", RunClock.QUICK_BREAK_SECONDS, [30.0, 20.0, 28.0, 24.0, 26.0, 22.0])
	_t.eq("Challenge Stake HP mult strictly 1.0", StakeDevices.CHALLENGE_HP_MULT, 1.0)
	_t.eq("Challenge Stake cap == 3", StakeDevices.CHALLENGE_STAKE_CAP, 3)
	_t.eq("ActiveDefs has 8 actives", ActiveDefs.ROWS.size(), 8)
	_t.eq("Consumables has 9 cartridges", Consumables.all_order().size(), 9)
	_t.check("4th element heat fusions present", Elements.all_fusions().has("frost+heat") and Elements.all_fusions().has("arc+heat"))
	_t.check("Companion SALVAGE_MAGNET cog_scoop scales vacuum", Companion.vacuum_scale({"sockets": ["cog_scoop"]}) > 1.0)


func _check_story_progression_and_wiring() -> void:
	var cids: Array = ClassDef.all().map(func(d): return String(d.id))
	var sigs: Array = []
	for s in GameEvents.signal_names():
		sigs.append(String(s))
	var spks: Array = LoreRows.SPEAKERS.keys()
	_t.eq("PilotStory.validate clean", PilotStory.validate(cids, sigs, spks), [])
	_t.eq("PilotStory has 40 chapters and 15 pairs", [PilotStory.CHAPTERS.size(), PilotStory.pair_ids().size()], [40, 15])

	# Deduplication check: no call.patch.rogue_* duplicates in WORLD_CALLS.
	var has_dup_rogue := LoreRows.WORLD_CALLS.any(func(r): return String(r.get("id", "")).begins_with("call.patch.rogue_"))
	_t.check("WORLD_CALLS has no duplicate call.patch.rogue_* rows", not has_dup_rogue)
	_t.eq("LoreRows.voice_of resolves W2/W3 crews by default",
		LoreRows.voice_of({"kind": "exchange", "speaker": "Deck crew", "text": "x"}), "roost_crew")

	# WorkOrders + MetaOptions + AltLoadouts -> Relics.part_of() link check.
	_t.eq("WorkOrders counts (24 crew, 12 shift, 7 licenses)",
		[WorkOrders.CREW_ORDERS.size(), WorkOrders.SHIFT_ORDERS.size(), WorkOrders.LICENSES.size()], [24, 12, 7])
	_t.eq("MetaOptions has 6 Override Codes and 9 Alt Loadouts",
		[MetaOptions.OVERRIDE_CODES.size(), MetaOptions.ALT_LOADOUTS.size()], [6, 9])
	for alt_id in MetaOptions.ALT_LOADOUTS:
		var relic_id := String(MetaOptions.ALT_LOADOUTS[alt_id]["relic"])
		_t.check("Alt loadout %s maps to live Relics.part_of(%s)" % [alt_id, relic_id],
			Relics.part_of(relic_id) == "relic:" + relic_id)

	# Codex + Secrets.patch_wire_sites + Foreman habit memo dormancy vs seasoned activation.
	var events := GameEvents.new()
	var run := RunState.new(events, 7)
	var codex := Codex.new()
	codex.setup(events, run, null, "user://w50-unified-%d" % OS.get_process_id())
	codex.declare_story_entries(PilotStory.codex_declarations())
	codex.set_story_hooks(PilotStory.entry_visible, PilotStory.synthesis_margin)
	_t.eq("patch wire w1 hidden before rogue kill", Secrets.patch_wire_sites("park_dam", 42, codex).size(), 0)
	codex.mark_known("patch.rogue.w1")
	_t.eq("patch wire w1 revealed after rogue kill", Secrets.patch_wire_sites("park_dam", 42, codex).size(), 1)

	var p := Profile.new("user://w50-unified-profile-%d.json" % OS.get_process_id())
	p.can_save = false
	p.set_stat("habit.runs_total", 2.0)
	p.set_stat("habit.trade_risk", 8.0)
	var fresh_loss := DeathCause.memo(11, 1, "warden", p, [], run)
	_t.eq("DeathCause.memo stays baseline when runs < 3", fresh_loss, DeathCause.memo(11, 1))
	p.set_stat("habit.runs_total", 5.0)
	var seasoned_loss := DeathCause.memo(11, 1, "warden", p, [], run)
	var expected_adapt := "%s: %s" % [LoreRows.SPEAKERS["mind"], PilotStory.foreman_loss_memo(11, "warden", p, [], run)]
	_t.eq("DeathCause.memo uses adaptive Foreman memo when runs >= 3", seasoned_loss, expected_adapt)

	codex.free()
	events.free()
