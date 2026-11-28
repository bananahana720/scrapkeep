extends Node3D

const ActivityView := preload("res://src/world/activity_view.gd")
const Companion := preload("res://src/core/companion.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Cards := preload("res://src/world/director_cards.gd")
const HoldRelay := preload("res://src/world/hold_relay.gd")
const RelayStake := preload("res://src/world/relay_stake.gd")
const SurvivalCount := preload("res://src/world/survival_count.gd")
const Interact := preload("res://src/world/interact.gd")
const ItemGen := preload("res://src/build/item_gen.gd")
const OddsReadout := preload("res://src/ui/odds_readout.gd")
const Palette := preload("res://src/core/palette.gd")
const PropMeshes := preload("res://src/presentation/craft_prop_meshes.gd")
const BakeLook := preload("res://src/presentation/bake_look.gd")
const Parts := preload("res://src/build/parts.gd")
const ParkGraph := preload("res://src/world/park/park_graph.gd")
const StocktakeDress := preload("res://src/world/stocktake_dress.gd")
const PocketFog := preload("res://src/world/events/pocket_fog.gd")
const TradePockets := preload("res://src/world/trade_pockets.gd")
const StakeDevices := preload("res://src/world/stake_devices.gd")
const PocketDraw := preload("res://src/world/pockets/pocket_draw.gd")
const PocketLibrary := preload("res://src/world/pockets/pocket_library.gd")
const Secrets := preload("res://src/core/secrets.gd")
const PilotStory := preload("res://src/core/pilot_story.gd")
const AmbushAltar := preload("res://src/world/ambush_altar.gd")
const CrackedCache := preload("res://src/world/cracked_cache.gd")
const ModelKit := preload("res://src/world/model_kit.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const SpeedTier := preload("res://src/movement/speed_tier.gd")
const WorldFx := preload("res://src/presentation/world_fx/world_fx.gd")
const WorldFxAnchor := preload("res://src/presentation/world_fx/world_fx_anchor.gd")
const StageModifier := preload("res://src/world/events/stage_modifier.gd")
const ShiftVariants := preload("res://src/core/shift_variants.gd")
const SurgeCourse := preload("res://src/world/surge_course.gd")
const EventDirector := preload("res://src/world/event_director.gd")

signal sluice_opened(row_id: String)
signal sluice_closed(row_id: String)

const PAY_RARITIES := ["common", "rare"]
const PAY_SCRAP := 180
const POCKET_KIT := "res://assets/models/world_one/pocket_kit.glb"
const POCKET_PARTS := ["PocketBlock", "PocketPost"]
const FIND_KIT := "res://assets/models/world_one/find_kit.glb"
const FIND_PARTS := ["FindBoardFrame", "FindBoard", "FindAerial", "FindSeep"]
const POCKET_BLOCK := Vector3(4.0, 3.0, 4.0)
const SITE_VIEW_END_M := 420.0
const PROP_VIEW_END_M := 360.0
const VIEW_MARGIN_M := 30.0
const RULES := {
	"trade_risk": {"starts": "none", "ring": 6.0, "finishes": "trade", "pay": {"scrap": 0, "rarities": [], "source": "trade_risk", "where": "device"}, "cue": {"view": "cracked_cache"}},
	"trade_safe": {"starts": "none", "ring": 6.0, "finishes": "trade", "pay": {"scrap": 0, "rarities": [], "source": "trade_safe", "where": "device"}, "cue": {"view": "cracked_cache"}},
	"curse": {"starts": "none", "ring": 6.0, "finishes": "trade", "pay": {"scrap": 0, "rarities": [], "source": "curse", "where": "device"}, "cue": {"view": "cracked_cache"}},
	"sacrifice": {"starts": "none", "ring": 6.0, "finishes": "trade", "pay": {"scrap": 0, "rarities": [], "source": "sacrifice", "where": "device"}, "cue": {"view": "cracked_cache"}},
	"movement_course": {
		"starts": "ring", "ring": 8.0, "finishes": "course", "bundle": ["course", "chest"],
		"cue": {"view": "surge_run", "word": "Course", "telegraph": "event_announced", "clear": "event_ended", "pay": "reward_chosen"},
		"pay": {"scrap": PAY_SCRAP, "rarities": ["common"], "tier": 1, "parts": 1, "source": "pocket_course", "where": "stand"},
	},
	"arena": {
		"starts": "ring", "ring": 8.0, "finishes": "arena", "pack": ["chaser", "chaser", "lobber"], "bundle": ["spawners", "hazard", "heal", "chest"],
		"cue": {"view": "enemy_camp", "word": "Arena", "telegraph": "event_announced", "clear": "event_ended", "pay": "reward_chosen"},
		"pay": {"scrap": PAY_SCRAP, "rarities": ["rare"], "tier": 2, "parts": 1, "source": "pocket_arena", "where": "stand"},
	},
	"elite_arena": {
		"starts": "ring", "ring": 8.0, "finishes": "elite", "pack": ["chaser", "lobber", "miniboss"], "bundle": ["elite", "spawners", "hazard", "heal", "chest"],
		"cue": {"view": "hauler_bounty", "word": "Elite arena", "telegraph": "event_announced", "clear": "event_ended", "pay": "reward_chosen"},
		"pay": {"scrap": PAY_SCRAP, "rarities": ["rare"], "tier": 3, "parts": 2, "source": "pocket_elite", "where": "stand"},
	},
	"objective_limit": {
		"starts": "ring", "ring": 8.0, "finishes": "timed_pickup", "limit_ticks": 600, "bundle": ["timed_pickup", "chest"],
		"cue": {"view": "cracked_cache", "word": "Pickup course", "telegraph": "event_announced", "clear": "event_ended", "pay": "reward_chosen"},
		"pay": {"scrap": PAY_SCRAP, "rarities": ["rare"], "tier": 4, "parts": 3, "source": "pocket_objective", "where": "stand"},
	},
	"round_arena": {
		"starts": "ring", "ring": 8.0, "finishes": "rounds", "rounds": 3, "base": 12.0, "step": 6.0, "difficulty_cap": 3.0, "enemy_credit": 6.0,
		"elements": ["chaser", "lobber", "plated_brute"], "bundle": ["spawners", "hazard", "safe_zone", "heal", "round_chests"],
		"cue": {"view": "enemy_camp", "word": "Round arena", "telegraph": "event_announced", "clear": "event_ended", "pay": "reward_chosen"},
		"pay": {"scrap": PAY_SCRAP, "rarities": ["rare"], "tier": 2, "parts": 1, "source": "pocket_round", "where": "safe_zone"},
	},
	"ambush": {
		"starts": "ring", "ring": 8.0, "finishes": "waves", "waves": [["chaser"], ["chaser", "lobber", "chaser"], ["chaser", "lobber", "chaser", "lobber", "chaser"]],
		"bundle": ["spawners", "hazard", "heal", "chest"],
		"cue": {"view": "ambush_altar", "word": "Ambush", "telegraph": "event_announced", "clear": "event_ended", "pay": "reward_chosen"},
		"pay": {"scrap": PAY_SCRAP, "rarities": ["rare"], "tier": 2, "parts": 1, "source": "pocket_ambush", "where": "stand"},
	},
	"scattered_marks": {
		"starts": "none", "ring": 8.0, "finishes": "marks", "bundle": ["marks", "chest"],
		"cue": {"view": "cracked_cache", "word": "Scattered marks", "telegraph": "event_announced", "clear": "event_ended", "pay": "reward_chosen"},
		"pay": {"scrap": PAY_SCRAP, "rarities": ["rare"], "tier": 2, "parts": 1, "source": "pocket_marks", "where": "stand"},
	},
	"enemy_camp": {
		"starts": "ring", "ring": 8.0, "pack": ["chaser", "chaser", "chaser"], "finishes": "pack_dead",
		"pay": {"scrap": PAY_SCRAP, "rarities": ["common"], "source": "activity_camp", "where": "camp"},
	},
	"ambush_altar": {
		"starts": "ring", "ring": 8.0, "pack": ["chaser", "chaser", "lobber"], "finishes": "pack_dead",
		"pay": {"scrap": PAY_SCRAP, "rarities": PAY_RARITIES, "source": "activity_ambush", "where": "altar"},
	},
	"cracked_cache": {
		"starts": "none", "ring": 5.0, "finishes": "wall_broken", "face": Vector2(0.0, -1.0),
		"pay": {"scrap": PAY_SCRAP, "rarities": PAY_RARITIES, "source": "activity_cache", "where": "pedestal"},
		"refused": {"worlds": [1], "floor": 0.4, "gap_s": 3.0},
	},
	"hold_the_relay": {
		"starts": "ring", "ring": HoldRelay.RULE["radius"], "finishes": "relay", "pack": ["chaser", "chaser", "lobber"],
		"waves": 3, "wave_s": 6.0, "pack_gap_s": 0.5, "miniboss_at": 0.35, "miniboss_step": 0.12,
		"post_out": 26.0, "retry_s": 12.0, "budget": {"start": 6, "per_class": 1, "per_world": 2, "cap": 12},
		"pay": {"scrap": PAY_SCRAP, "rarities": PAY_RARITIES, "source": "activity_relay", "where": "relay"},
	},
	"stocktake_yard": {
		"starts": "ring", "ring": 40.0, "finishes": "count", "pack": [], "form": "yard", "arrive_s": 0.4, "out_s": 4.0,
		"pay_ahead_m": 12.0, "pay": {"scrap": 0, "rarities": [], "source": "activity_yard", "where": "gate"},
		"cue": {"view": "hauler_bounty", "word": "Stocktake"},
	},
	"stocktake_muster": {
		"starts": "ring", "ring": 24.0, "finishes": "count", "pack": [], "form": "muster", "arrive_s": 0.4, "out_s": 4.0,
		"one_in": 3, "call_m": 100.0, "siren_s": 6.0,
		"pay_ahead_m": 12.0, "pay": {"scrap": 0, "rarities": [], "source": "activity_yard", "where": "gate"},
		"cue": {"view": "hauler_bounty", "word": "Stocktake"},
	},
	"surge_run": {
		"starts": "ring", "ring": 7.0, "finishes": "surge", "fallback_s": 10.0, "retry_s": 12.0,
		"pay": {"scrap": PAY_SCRAP, "rarities": PAY_RARITIES, "source": "activity_surge", "where": "ball"},
	},
	"hauler_bounty": {
		"starts": "near_or_hit", "ring": 4.0, "wake": 30.0, "leash": 40.0, "return_speed": 9.0, "kind": "plated_brute",
		"finishes": "brute_dead",
		"pay": {"scrap": PAY_SCRAP, "rarities": PAY_RARITIES, "source": "activity_bounty", "where": "fall"},
	},
}

const PICKUP_REACH := 1.7
const PICKUP_HEIGHT := 3.0
const RING_RISE_M := 10.0
const RING_SLOPE := 0.45
const SITE_PAD_M := 20.0
const RING_READ_M := 6.0
const MUSTER_WAIT_S := 20.0
const CONTRAPTION_M := 6.0
const SURVIVAL_KINDS := ["stocktake_yard", "stocktake_muster"]
const RING_HEIGHT := 8.0
const BRUTE_DROP := 2.4
const SPAWN_CLEARANCE := 2.4
const PACK_TURN := PI / 6.0

const WALL_HALF_W := 6.0
const WALL_DEPTH := 8.0
const WALL_HEIGHT := 6.0
const WALL_SINK := 3.0
const WALL_REACH := 3.0
const WALL_CONTACT := 1.2
const SLAM_REACH := 7.0
const SLAM_MIN_PER_CRUISE := 1.0
const RAM_MIN_PER_CRUISE := 0.85
const BARS := {"blazing": SpeedTier.BLAZING}
const PEDESTAL_BACK := 4.0
const CACHE_LANE_OFFSET := 6.0
const ROOM_LOG_HEIGHT := 4.5
const ROOM_LOG_WIDTH_PX := 1240.0
const ROOM_BOARD_SIZE := Vector2(7.0, 1.5)
const ROOM_TALLY_AT := Vector3(3.6, 1.3, 0.52)
const ROOM_TALLY_STROKE := Vector2(0.14, 1.1)
const ROOM_GLOVE_AT := Vector3(2.3, 2.3, 0.5)
const ROOM_GLOVE_SCALE := 1.6
const CACHE_FIRED_GLOW := {"energy": 0.8}
const FIND_SEEP_STREAKS := [Vector3(-2.6, 0.4, 0.5), Vector3(-1.9, 0.1, 0.3), Vector3(2.2, 0.6, 0.4)]
const FIND_AERIAL_M := 3.2
const DOOR_CLOCK_M := 1.6
static var _find_wet: StandardMaterial3D

const AT_HAND_M := 80.0
const LET_GO_M := 100.0

var ctx
var room_sites := Callable()
var door_sites := Callable()
var settle := Callable()
var sites: Array = []
var _keep_map
var _keep_rows: Array = []
var _piece_paid := false
var _pending_stage := false
var _elite_arrivals := 0
var _graph
var _graph_map := ""
var _draw_layout := {}
var _draw_map := ""
var stage_modifier := {}
var _mark_pools := {}
var _prep := {}
static var _shared_graphs := {}
var last_entry_usec := 0
var last_entry_steps := PackedStringArray()
var _ahead := {}
var _site_parent: Node = null
const AHEAD_PLAN_TICKS := 2
var last_ahead_plan_usec := 0
var last_ahead_steps := PackedStringArray()
var last_entry_adopted := 0
var _holders: Array = []
var wards: Array = []
var plates: Array = []
static var _interior_block: StandardMaterial3D
static var _wall: PhysicsMaterial
var _owns_shared := false

const POCKET_HEAL_SHARE := 0.15
const POCKET_FOG_SIZE := Vector3(32, 8, 32)
const POCKET_SAFE_M := 4.0
const POCKET_DAMAGE_PER_S := 8.0
const MARK_SPACING_M := 80.0
const MARK_POOL_SIZE := 16
const RELAY_PROGRESS_STEP := 0.01
const SURGE_WORDS := {
	"open": "Head gate: wheel turning. Stay ahead of the water.",
	"won": "Head gate log: wheel shut. One ball through, flume dry.",
	"lost": "Head gate: winding the wheel back.",
}


class Site extends Node3D:
	var id := ""
	var row_id := ""
	var rule := {}
	var view
	var done := false
	var started := false
	var pack: Array = []
	var brute
	var wall: Node3D
	var pedestal := Vector3.ZERO
	var pickup: Node3D
	var pickup_part := ""
	var pickup_parts: Array = []
	var reward_parts: Array = []
	var cap: Node3D
	var pickup_taken := false
	var inside_pickup := true
	var fired_glow: StandardMaterial3D
	var hazards: Array = []
	var fog
	var graph
	var targets: Array = []
	var target_views: Array = []
	var taken := {}
	var marks_taken := 0
	var next_target := 0
	var ticks := 0
	var failed := false
	var heal_paid := false
	var tier_label: Label3D
	var difficulty := 1.0
	var refused_frame := -1
	var round := 0
	var round_elements: Array = []
	var round_credits := 0.0
	var round_payments := 0
	var round_rewards: Array = []
	var awaiting_round := false
	var wave := 0
	var spawn_positions: Array = []
	var phase_view: Node3D
	var drawn := false
	var interior := {}
	var interior_collision_ready := false
	var trade := {}
	var trade_devices: Array = []
	var trade_sign: Label3D
	var footprint := POCKET_FOG_SIZE
	var relay
	var stake_post: Node3D
	var relay_credit := 0.0
	var relay_wave_s := 0.0
	var relay_gap_s := 0.0
	var relay_wave_left := 0
	var relay_shown := -1.0
	var relay_cooldown := 0.0
	var minibosses_sent := 0
	var minibosses: Array = []
	var course
	var surge_row := ""
	var surge_live := false
	var surge_wait := 0.0
	var surge_shown := -1.0
	var yard
	var yard_owed: Array = []
	var yard_wait := 0.0
	var yard_out := 0.0
	var yard_may_bank := false
	var yard_called := false
	var yard_siren := -1.0
	var yard_stood := false
	var yard_dress
	var yard_mast: Node3D

	func _exit_tree() -> void:
		for enemy in pack + minibosses:
			if is_instance_valid(enemy):
				enemy.queue_free()
		if is_instance_valid(yard_mast):
			yard_mast.queue_free()


class MendWard extends Node3D:
	const RING_M := 5.0
	const GUARD_M := 9.0
	const CHARGE_S := 8.0
	const DRAIN := 0.5
	const HEAL_SHARE := 0.4
	const PACK := ["chaser", "chaser", "lobber"]

	var ward_id := ""
	var charge := 0.0
	var woke := false
	var paid := false
	var guard: Array = []
	var fill: MeshInstance3D

	func step(delta: float, inside: bool) -> String:
		if paid:
			return ""
		if not woke:
			if not inside:
				return ""
			woke = true
			return "wake"
		if guard.is_empty():
			return ""
		charge = clampf(charge + (delta if inside else -delta * DRAIN), 0.0, CHARGE_S)
		if charge < CHARGE_S:
			return ""
		paid = true
		return "mend"

	func share() -> float:
		return charge / CHARGE_S

	func _exit_tree() -> void:
		for enemy in guard:
			if is_instance_valid(enemy):
				enemy.queue_free()


class LorePlate extends Node3D:
	const REACH_M := 2.6
	const HEIGHT_M := 3.0
	const BELOW_M := 0.25

	var note := ""
	var read := false
	var seated := false
	var reseat := false
	var at := Vector2.ZERO
	var face: MeshInstance3D

	func touch() -> bool:
		if read:
			return false
		read = true
		return true


func setup(ctx_ref) -> void:
	ctx = ctx_ref
	_owns_shared = true
	name = "Activities"
	ctx.events.stage_entered.connect(_on_stage_entered)
	ctx.events.stage_content_cleared.connect(func(_reason: String):
		clear()
		_drop_ahead())
	ctx.events.launched.connect(_on_launched)
	ctx.events.flow_changed.connect(_on_flow_changed)
	if ctx.terrain != null and ctx.terrain.has_signal("surface_changed"):
		ctx.terrain.surface_changed.connect(_on_surface_changed)
	ctx.events.slammed.connect(func(at: Vector3, strength: float, _flatness: float): _slammed(at, strength))
	ctx.events.world_fact.connect(_on_world_fact)
	ctx.events.player_died.connect(_forfeit_yards)
	Palette.look_texture("rusted-salvaged-plate-worn", true)
	BakeLook.ramp()
	_prepare_stage(1)


func _exit_tree() -> void:
	for id in _prep:
		_settle(id)
	if not _owns_shared:
		return
	load("res://src/world/director.gd").release_parks()
	load("res://src/world/events/natural.gd").release_plans()
	load("res://src/presentation/set_dressing.gd").release_shared()
	load("res://src/presentation/park_props.gd").release_shared()
	_interior_block = null
	_wall = null


func _settle(id: String) -> void:
	if not _prep.has(id) or not _prep[id].has("task"):
		return
	WorkerThreadPool.wait_for_task_completion(_prep[id].task)
	var done: Dictionary = _prep[id].out
	_adopt_graph(graph_path(id), done.graph)
	_prep[id] = {"pool": done.pool, "layout": done.layout, "worker_layout": not done.layout.is_empty()}


func _prepare_stage(stage_number: int) -> void:
	var terrain = ctx.terrain
	if terrain == null or not "maps" in terrain or not terrain.has_method("map_for"):
		return
	if stage_number >= 1 and stage_number <= terrain.maps.size():
		_prepare_map(terrain.map_for(stage_number))


static func graph_path(map_id: String) -> String:
	return "res://assets/park/%s/graph.bin" % map_id


static func shared_graph(path: String):
	if not _shared_graphs.has(path):
		_shared_graphs[path] = ParkGraph.read(path) if FileAccess.file_exists(path) else null
	return _shared_graphs[path]


static func _adopt_graph(path: String, graph) -> void:
	if graph != null and _shared_graphs.get(path) == null:
		_shared_graphs[path] = graph


func _prepare_map(map) -> void:
	if map == null or not "park" in map or map.park.is_empty():
		return
	var id := String(map.park.map)
	if _prep.has(id):
		return
	var rows := {"park": map.park.duplicate(true), "activity_sites": map.activity_sites.duplicate(true), "play_rect": map.play_rect}
	var out := {}
	var path := graph_path(id)
	_prep[id] = {"task": WorkerThreadPool.add_task(func(): out.merge(prepare_data(path, rows, true)), false, "activities prep " + id), "out": out}
	load("res://src/world/director.gd").prepare_park(id)


static func prepare_data(path: String, map, layout: bool) -> Dictionary:
	var graph = ParkGraph.read(path) if FileAccess.file_exists(path) else null
	if graph == null:
		return {"graph": null, "pool": PackedInt32Array(), "layout": {}}
	if graph.zone_count() > 0:
		graph.zone_nodes(0)
	return {"graph": graph, "pool": TradePockets.candidates(graph, map), "layout": PocketDraw.prepare_world(graph, map) if layout else {}}


func _entry_data(map) -> Dictionary:
	var id := String(map.park.map)
	_settle(id)
	var graph = shared_graph(graph_path(id))
	if not _prep.has(id):
		_prep[id] = {"pool": TradePockets.candidates(graph, map) if graph != null else PackedInt32Array(), "layout": {}}
	return _prep[id]


func _on_stage_entered(_stage: int, retry: bool) -> void:
	var started := Time.get_ticks_usec()
	last_entry_steps = PackedStringArray()
	_enter_stage(retry)
	last_entry_usec = Time.get_ticks_usec() - started


func _enter_stage(retry: bool) -> void:
	var cleared := Time.get_ticks_usec()
	clear()
	last_entry_steps.append("clear %.1f" % ((Time.get_ticks_usec() - cleared) / 1000.0))
	_elite_arrivals = 0
	stage_modifier = {}
	last_entry_adopted = 0
	_site_parent = null
	if not retry:
		_piece_paid = false
	var map = ctx.terrain.map()
	var entry_data := _use_map(map)
	if "stage" in ctx.terrain:
		_prepare_stage(int(ctx.terrain.stage) + 1)
	if not "activity_sites" in map:
		_drop_ahead()
		StageModifier.set_air({})
		return
	var plan := _plan(map, entry_data)
	stage_modifier = plan.modifier
	var ahead := {}
	if not retry and int(_ahead.get("stage", 0)) == ctx.run.stage and not _ahead.plan.is_empty():
		ahead = _ahead
		_ahead = {}
	else:
		_drop_ahead()
	for i in plan.sites.size():
		var entry: Dictionary = plan.sites[i]
		var site: Site = _adopt(ahead, i, entry)
		if site == null:
			site = _build_entry(entry, stage_modifier)
		else:
			_arm(site)
			last_entry_adopted += 1
		sites.append(site)
	if not ahead.is_empty():
		_uncover(ahead)
	if _graph_map != "":
		_build_wards_and_plates(map)
	StageModifier.set_air(stage_modifier)
	_pending_stage = true


func _use_map(map) -> Dictionary:
	_graph = null
	_graph_map = ""
	_mark_pools.clear()
	if "park" in map and not map.park.is_empty():
		_graph_map = String(map.park.map)
		var entry_data := _entry_data(map)
		_graph = shared_graph(graph_path(_graph_map))
		return entry_data
	return {}


func _plan(map, entry_data: Dictionary) -> Dictionary:
	var out := []
	var modifier := {}
	var crates_shut: bool = ctx != null and ctx.run != null and ctx.run.has_method("override_on") and ctx.run.override_on("shops_and_crates_shut")
	for authored in map.activity_sites:
		var spec := drawn(authored)
		var id := String(spec["id"])
		if not RULES.has(id):
			continue
		if crates_shut and id == "cracked_cache":
			continue
		if ctx.calm and String(RULES[id]["finishes"]) != "wall_broken":
			continue
		var map_id := _graph_map if _graph_map != "" else String(ctx.stages.of(ctx.terrain.stage).get("map", ""))
		var entry := PocketLibrary.for_site(map_id, String(spec.get("row", id)))
		var built_spec: Dictionary = spec
		if not entry.is_empty() and entry.activity == id:
			built_spec = spec.merged(PocketLibrary.site_spec(entry), true)
			if not spec.get("pack", []).is_empty():
				built_spec.pack = spec.pack.duplicate()
				built_spec.tell = spec.get("tell", {}).duplicate(true)
		out.append({"kind": "row", "id": id, "at": spec["at"], "spec": built_spec})
	for kind in SURVIVAL_KINDS:
		var stand := survival_spec(map, kind)
		if not stand.is_empty():
			out.append({"kind": "row", "id": kind, "at": stand["at"], "spec": stand})
	if _graph_map != "":
		var tuning = ctx.get("tuning")
		var sitting: bool = tuning != null and tuning.has_method("sitting") and tuning.sitting()
		for room_spec in (room_sites.call(_graph_map, sitting) if room_sites.is_valid() else []):
			out.append({"kind": "room", "id": "cracked_cache", "at": room_spec["at"], "spec": room_spec, "secret": String(room_spec["secret"])})
		for find_spec in Secrets.find_sites(_graph_map, hash([ctx.rng.seed, ctx.run.run_seed, "field_finds"])):
			out.append({"kind": "find", "id": "cracked_cache", "at": find_spec["at"], "spec": find_spec, "find": String(find_spec["find"])})
		for door_spec in (door_sites.call(_graph_map) if door_sites.is_valid() else []):
			out.append({"kind": "door", "id": "cracked_cache", "at": door_spec["at"], "spec": door_spec})
		for wire_spec in Secrets.patch_wire_sites(_graph_map, hash([ctx.rng.seed, ctx.run.run_seed, "patch_wires"]), ctx.get("codex")):
			out.append({"kind": "patch_wire", "id": "cracked_cache", "at": wire_spec["at"], "spec": wire_spec, "patch_wire": String(wire_spec["patch_wire"])})
		for variant_spec in ShiftVariants.extra_sites(_graph_map, ctx.run):
			out.append({"kind": "row", "id": String(variant_spec["id"]), "at": variant_spec["at"], "spec": variant_spec})
	if _graph != null:
		var pool: PackedInt32Array = entry_data.pool
		var trade_spec := TradePockets.stage_site(_graph, map, ctx.run, ctx.rng.seed, pool)
		if not trade_spec.is_empty():
			out.append({"kind": "trade", "id": trade_spec.id, "at": trade_spec.at, "spec": trade_spec})
		if _draw_map != _graph_map:
			_draw_layout = {}
			_draw_map = _graph_map
		if _draw_layout.is_empty():
			if entry_data.layout.is_empty():
				entry_data.layout = PocketDraw.prepare_world(_graph, map)
			_draw_layout = entry_data.layout
		modifier = StageModifier.for_stage(ctx.run, ctx.terrain, ctx.run.stage)
		for drawn_spec in PocketDraw.stage_sites(_graph, map, ctx.run, ctx.rng.seed, trade_spec, _draw_layout, modifier, true):
			if crates_shut and String(drawn_spec.id) == "cracked_cache":
				continue
			if not ctx.calm or RULES[drawn_spec.id].finishes == "wall_broken":
				out.append({"kind": "drawn", "id": drawn_spec.id, "at": drawn_spec.at, "spec": drawn_spec})
	return {"sites": out, "modifier": modifier}


func survival_spec(map, kind: String) -> Dictionary:
	var tuning = ctx.get("tuning")
	if tuning == null or tuning.option("stocktake") != "on" or ctx.calm or not "survival_sites" in map:
		return {}
	var form := String(RULES[kind]["form"])
	var rows: Array = map.survival_sites.filter(func(row: Dictionary) -> bool: return row["form"] == form)
	if rows.is_empty() or not SurvivalCount.ROSTERS.has(ctx.stages.world_of(ctx.run.stage)):
		return {}
	if posmod(hash([ctx.rng.seed, ctx.run.run_seed, "survival_called_" + form]), int(RULES[kind].get("one_in", 1))) != 0:
		return {}
	return rows[posmod(hash([ctx.rng.seed, ctx.run.run_seed, "survival_" + form]), rows.size())]


func drawn(spec: Dictionary) -> Dictionary:
	return variant(spec, hash([ctx.rng.seed, ctx.run.run_seed, "site_variants"]))


static func variant(spec: Dictionary, seed: int) -> Dictionary:
	var alts: Array = spec.get("alts", [])
	var pick := posmod(hash([seed, String(spec.get("row", ""))]), alts.size() + 1)
	if pick == 0:
		return spec
	var out := spec.duplicate(true)
	out.erase("pack")
	out.erase("alts")
	out.merge(alts[pick - 1].duplicate(true), true)
	return out


static func called(id: String) -> String:
	return String(RULES.get(id, {}).get("cue", {}).get("word", ""))


func _build_entry(entry: Dictionary, modifier: Dictionary) -> Site:
	var site := _build(entry.id, entry.at, entry.spec)
	match String(entry.kind):
		"room":
			_hang_room_log(site, entry.secret)
		"find":
			var dressed := Time.get_ticks_usec()
			_dress_find(site, entry.find)
			last_entry_steps.append("find %s %.1f" % [entry.find, (Time.get_ticks_usec() - dressed) / 1000.0])
		"door":
			_dress_door(site)
		"patch_wire":
			_dress_patch_wire(site, String(entry.patch_wire))
		"drawn":
			site.view.set_sight(float(modifier.get("sight_scale", 1.0)))
			StageModifier.mark_far(modifier, site)
	return site


func _arm(site: Site) -> void:
	var interact: Node = ctx.root.get_node("Interact")
	for device in site.trade_devices:
		interact.register(device)
	if site.stake_post != null:
		interact.register(site.stake_post)


func _on_launched(_velocity: Vector3) -> void:
	_drop_ahead()
	var flow = ctx.get("flow")
	if flow == null or not flow.state_name() in ["gates", "launch"] or ctx.stages.is_world_last(ctx.run.stage):
		return
	_start_ahead(ctx.run.stage + 1)


func _on_flow_changed(state: String) -> void:
	if state != "victory":
		return
	_drop_ahead()
	var flow = ctx.get("flow")
	if flow == null or not flow.has_method("run_ends_after") or flow.run_ends_after(ctx.run.stage):
		return
	_start_ahead(ctx.run.stage + 1)


func _start_ahead(stage: int) -> void:
	if ctx.terrain == null or not ctx.terrain.has_method("worker_builds") or not ctx.terrain.worker_builds():
		return
	if not "maps" in ctx.terrain or stage > ctx.terrain.maps.size() or not ctx.terrain.is_ready(stage):
		return
	var map = ctx.terrain.map_for(stage)
	if not "park" in map or map.park.is_empty() or not "activity_sites" in map:
		return
	var holder := Node3D.new()
	holder.name = "AheadSites_%d" % stage
	holder.visible = false
	holder.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(holder)
	_ahead = {"stage": stage, "holder": holder, "plan": {}, "built": [], "grounds": [], "run": _run_key(), "wait": AHEAD_PLAN_TICKS}


func _plan_ahead() -> void:
	var stage: int = _ahead.stage
	var map = ctx.terrain.map_for(stage)
	var started := Time.get_ticks_usec()
	last_ahead_steps = PackedStringArray()
	var memory: Dictionary = ctx.run.trade_memory
	var draws: Dictionary = ctx.run.pocket_draw_cache
	ctx.run.trade_memory = memory.duplicate(true)
	ctx.run.pocket_draw_cache = draws.duplicate(true)
	for offer in ctx.run.trade_memory.seen:
		if int(offer.stage) == stage - 1 and not ctx.run.trade_memory.decisions.has(str(stage - 1)):
			TradePockets.decide(ctx.run.trade_memory, offer, false)
	_as_stage(stage, map, func(): _ahead.plan = _plan(map, _entry_data(map)))
	ctx.run.trade_memory = memory
	ctx.run.pocket_draw_cache = draws
	last_ahead_plan_usec = Time.get_ticks_usec() - started
	if _ahead.plan.is_empty():
		_drop_ahead()


func _run_key() -> int:
	return hash([ctx.run.parts, ctx.run.max_hp, ctx.run.class_id(), ctx.run.heft_class()])


func _step_ahead() -> void:
	var i: int = _ahead.built.size()
	var entry: Dictionary = _ahead.plan.sites[i]
	var map = ctx.terrain.map_for(int(_ahead.stage))
	var steps := last_entry_steps
	var started := Time.get_ticks_usec()
	_site_parent = _ahead.holder
	_as_stage(int(_ahead.stage), map, func():
		_ahead.built.append(_build_entry(entry, _ahead.plan.modifier))
		_ahead.grounds.append(ctx.terrain.height(float(entry.at.x), float(entry.at.y))))
	_site_parent = null
	last_entry_steps = steps
	last_ahead_steps.append("%s %.1f" % [entry.id, (Time.get_ticks_usec() - started) / 1000.0])
	if _ahead.built.size() <= i:
		_ahead.plan.sites.resize(i)


func _as_stage(stage: int, map, fn: Callable) -> void:
	var saved := [ctx.run.stage, ctx.terrain.stage, ctx.terrain.overlays.duplicate(), _graph, _graph_map, _draw_layout, _draw_map, _mark_pools]
	ctx.run.stage = stage
	ctx.terrain.stage = stage
	ctx.terrain.overlays.clear()
	if "start_overlays" in map:
		ctx.terrain.overlays.append_array(map.start_overlays)
	_mark_pools = {}
	_graph_map = String(map.park.map)
	_settle(_graph_map)
	_graph = shared_graph(graph_path(_graph_map))
	fn.call()
	ctx.run.stage = saved[0]
	ctx.terrain.stage = saved[1]
	ctx.terrain.overlays.assign(saved[2])
	_graph = saved[3]
	_graph_map = saved[4]
	_draw_layout = saved[5]
	_draw_map = saved[6]
	_mark_pools = saved[7]


func _adopt(ahead: Dictionary, i: int, entry: Dictionary) -> Site:
	if ahead.is_empty() or i >= ahead.built.size() or i >= ahead.plan.sites.size() or ahead.run != _run_key():
		return null
	var planned: Dictionary = ahead.plan.sites[i]
	if not _same_entry(planned, entry) or (String(entry.kind) == "drawn" and hash(ahead.plan.modifier) != hash(stage_modifier)):
		return null
	if absf(float(ahead.grounds[i]) - ctx.terrain.height(float(entry.at.x), float(entry.at.y))) > 0.01:
		return null
	var site: Site = ahead.built[i]
	ahead.built[i] = null
	return site


static func _same_entry(a: Dictionary, b: Dictionary) -> bool:
	return a.kind == b.kind and a.id == b.id and a.at == b.at and hash(a.spec) == hash(b.spec) \
		and a.get("secret", "") == b.get("secret", "") and a.get("find", "") == b.get("find", "") \
		and a.get("patch_wire", "") == b.get("patch_wire", "")


func _uncover(ahead: Dictionary) -> void:
	var taken := sites.filter(func(site): return is_instance_valid(site) and site.get_parent() == ahead.holder)
	if taken.is_empty():
		_free_holder(ahead)
		return
	for child in ahead.holder.get_children():
		if not child in taken and not taken.any(func(site): return site.yard_mast == child):
			ahead.holder.remove_child(child)
			child.queue_free()
	ahead.holder.visible = true
	ahead.holder.process_mode = Node.PROCESS_MODE_INHERIT
	_holders.append(ahead.holder)


func _drop_ahead() -> void:
	if not _ahead.is_empty():
		_free_holder(_ahead)
	_ahead = {}


func _free_holder(ahead: Dictionary) -> void:
	if is_instance_valid(ahead.holder):
		ahead.holder.queue_free()


func clear() -> void:
	for site in sites:
		if is_instance_valid(site):
			for device in site.trade_devices:
				ctx.root.get_node("Interact").unregister(device)
			if site.stake_post != null:
				ctx.root.get_node("Interact").unregister(site.stake_post)
			for enemy in site.minibosses:
				if is_instance_valid(enemy):
					enemy.queue_free()
			for hazard in site.hazards:
				hazard.stop()
			for enemy in site.pack:
				if is_instance_valid(enemy):
					enemy.queue_free()
			site.queue_free()
	sites.clear()
	for holder in _holders:
		if is_instance_valid(holder):
			holder.queue_free()
	_holders.clear()
	for node in wards + plates:
		if is_instance_valid(node):
			node.queue_free()
	wards.clear()
	plates.clear()
	_pending_stage = false


func on_offer() -> Array:
	return sites.filter(func(s) -> bool: return is_instance_valid(s) and not s.done and not s.has_meta("find") and s.visible)


func site(id: String) -> Site:
	for s in sites:
		if s.id == id:
			return s
	return null


func standing() -> int:
	var n := 0
	for s in sites:
		if s.brute != null and is_instance_valid(s.brute) and not s.brute.is_dead():
			n += 1
	return n


func keeps(enemy: Node) -> bool:
	for s in sites:
		if s.brute == enemy:
			return true
	return false


func _build(id: String, at: Vector2, spec := {}) -> Site:
	var started := Time.get_ticks_usec()
	var site := _build_site(id, at, spec)
	last_entry_steps.append("%s %.1f" % [id, (Time.get_ticks_usec() - started) / 1000.0])
	return site


func _build_site(id: String, at: Vector2, spec: Dictionary) -> Site:
	var s := Site.new()
	s.id = id
	s.row_id = String(spec.get("row", ""))
	s.rule = RULES[id]
	s.interior = spec.get("interior", {})
	s.drawn = spec.get("drawn", false)
	s.trade = spec.get("trade", {})
	var spec_pay: Dictionary = spec.get("pay", {})
	if id in ["enemy_camp", "hold_the_relay", "ambush_altar"] or id in SURVIVAL_KINDS or not spec_pay.is_empty() or spec.has("face") or s.rule.has("bundle") or not s.interior.is_empty():
		s.rule = s.rule.duplicate(true)
	if not s.interior.is_empty():
		s.footprint = spec.footprint
		s.difficulty = clampf(float(spec.get("difficulty", 1.0)), 1.0, float(s.rule.get("difficulty_cap", 3.0)))
		s.rule["ring"] = spec.ring
		if not spec.pack.is_empty():
			s.rule["pack"] = spec.pack.duplicate()
			if id == "ambush":
				s.rule["waves"] = [spec.pack.slice(0, 1), spec.pack.slice(0, ceili(spec.pack.size() * 0.5)), spec.pack.duplicate()]
		if s.rule.has("cue") and not spec.get("tell", {}).is_empty():
			s.rule.cue.word = spec.tell.word
	if id == "enemy_camp":
		s.rule["pack"] = spec.get("pack", s.rule["pack"])
	elif id in ["hold_the_relay", "ambush_altar"] and not spec.get("pack", []).is_empty():
		s.rule["pack"] = spec.pack.duplicate()
	for key in ["rarities", "named"]:
		if spec_pay.has(key):
			s.rule["pay"][key] = spec_pay[key]
	if spec.has("face"):
		s.rule["face"] = spec["face"]
	if BARS.has(spec.get("bar", "")):
		s.rule = s.rule.duplicate(true)
		s.rule["bar_tier"] = BARS[spec["bar"]]
	if spec.get("extra", "") == "card_2":
		s.set_meta("extra", String(spec.get("row", id)))
	s.name = "Activity_" + id
	(_site_parent if _site_parent != null else self).add_child(s)
	s.global_position = ctx.terrain.drop_point(at.x, at.y, 0.0)
	if s.drawn:
		s.rotation.y = -spec.get("turn", 0) * PI * 0.5
	s.view = ActivityView.new()
	s.add_child(s.view)
	var presentation: Node = ctx.root.get_node_or_null("Presentation")
	var tell_audio = presentation.audio if presentation != null and not s.interior.is_empty() else null
	s.view.build(String(s.rule.cue.view) if s.rule.has("cue") else id, float(s.rule["ring"]), spec.get("tell", {}), tell_audio)
	if s.rule.has("bundle"):
		_build_pocket(s, spec)
	elif id == "enemy_camp" and (spec.has("site") or not s.interior.is_empty()):
		_build_hazard(s)
	match id:
		"hold_the_relay":
			_build_relay(s)
		"stocktake_yard", "stocktake_muster":
			s.yard = SurvivalCount.new(ctx.stages.world_of(ctx.run.stage), String(s.rule["form"]))
			s.view.say(String(s.rule.cue.word))
			s.visible = not s.rule.has("siren_s")
			var onward: Vector2 = ctx.terrain.map().beacon - Vector2(s.global_position.x, s.global_position.z)
			if s.visible:
				s.yard_dress = StocktakeDress.attach(s, float(s.rule["ring"]), onward, ctx.terrain.height)
			else:
				s.yard_mast = StocktakeDress.mast(s.get_parent(), Vector2(s.global_position.x, s.global_position.z), onward, ctx.terrain.height)
		"surge_run":
			_build_surge(s, spec)
		"ambush_altar":
			_build_altar(s)
		"cracked_cache":
			_build_cache(s)
	if not s.interior.is_empty():
		_build_interior(s)
	if s.rule.finishes == "trade":
		_build_trade(s)
	_range_tree(s, SITE_VIEW_END_M, s.view)
	return s


static func _range_tree(root: Node, end_m: float, skip: Node = null) -> void:
	if root == null or root == skip:
		return
	if root is GeometryInstance3D:
		var view := root as GeometryInstance3D
		if view.visibility_range_end <= 0.0:
			view.visibility_range_end = end_m
			view.visibility_range_end_margin = VIEW_MARGIN_M
			view.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	for child in root.get_children():
		_range_tree(child, end_m, skip)


func _build_trade(s: Site) -> void:
	for i in TradePockets.devices(s.trade).size():
		var spec: Dictionary = TradePockets.devices(s.trade)[i].duplicate()
		spec["id"] = "trade_%d_%s_%d" % [ctx.run.stage, s.trade.interior_id, i]
		var device := StakeDevices.new()
		s.add_child(device)
		device.position = Vector3(-4.0 if i == 0 else 4.0, 0.0, 0.0)
		device.setup(ctx, ctx.root.get_node("Interact"), spec)
		if _site_parent == null:
			ctx.root.get_node("Interact").register(device)
		s.trade_devices.append(device)
	var door: Array = s.interior.entrances[0].at
	var label := Label3D.new()
	label.name = "TradePrices"
	label.position = Vector3(door[0], 3.4, door[1] + 1.0)
	label.text = _trade_sign(s)
	label.font_size = 36
	label.outline_size = 8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	s.add_child(label)
	s.trade_sign = label


func _trade_sign(s: Site) -> String:
	var lines := [TradePockets.door_words(s.trade, s.interior.tell.word)]
	for device in s.trade_devices:
		if device.sign_words() != "":
			lines.append(device.sign_words())
	lines.append("Hold at a device")
	return "\n".join(lines)


func _watch_trade(s: Site, ball: Vector3) -> void:
	var sign := _trade_sign(s)
	if s.trade_sign != null and s.trade_sign.text != sign:
		s.trade_sign.text = sign
	if not s.started and _planar(ball, s.global_position) <= s.footprint.z * 0.5 + 16.0:
		s.started = true
		TradePockets.see(ctx.run.trade_memory, s.trade)
	if not s.done and s.trade_devices.any(func(device): return device.spent):
		s.done = true
		TradePockets.see(ctx.run.trade_memory, s.trade)
		TradePockets.decide(ctx.run.trade_memory, s.trade, true)
		ctx.events.trade_taken.emit(s.id, s.global_position)


func _build_interior(s: Site) -> void:
	var root := Node3D.new()
	root.name = "Interior_" + String(s.interior.id)
	s.add_child(root)
	for block in s.interior.terrain:
		var size := Vector3(block.size[0], block.size[1], block.size[2])
		var at := Vector3(block.at[0], size.y * 0.5, block.at[1])
		var holder := Node3D.new()
		holder.position = at
		root.add_child(holder)
		var view := ModelKit.part(POCKET_KIT, POCKET_PARTS, "PocketBlock", holder)
		if view != null:
			view.scale = size / POCKET_BLOCK
			PropMeshes.weather_node_materials(view, 3.6)
			continue
		holder.free()
		if _interior_block == null:
			_interior_block = PropMeshes.weathered_material(Palette.VERDIGRIS, 0.82, 0.14, 0.0, "interior_block")
		_mesh_box(root, size, at, _interior_block)
	for entrance in s.interior.entrances:
		for side in [-1.0, 1.0]:
			var post_at := Vector3(entrance.at[0] + side * entrance.width * 0.5, 1.0, entrance.at[1])
			var post := ModelKit.part(POCKET_KIT, POCKET_PARTS, "PocketPost", root)
			if post != null:
				post.position = post_at
				post.material_override = _solid(EventKinds.activity_color(s.view.id))
			else:
				_mesh_box(root, Vector3(0.3, 2.0, 0.3), post_at, _solid(EventKinds.activity_color(s.view.id)))
	load("res://src/presentation/spillway_scenery.gd").dress_props(root)


func _wall_material() -> PhysicsMaterial:
	if _wall == null:
		_wall = PhysicsMaterial.new()
		_wall.friction = 0.0
		_wall.bounce = 0.3
	return _wall


func _activate_interior_collision(s: Site) -> void:
	var root := s.get_node("Interior_" + String(s.interior.id))
	for i in s.interior.terrain.size():
		var block: Dictionary = s.interior.terrain[i]
		var body := StaticBody3D.new()
		body.physics_material_override = _wall_material()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(block.size[0], block.size[1], block.size[2])
		shape.shape = box
		body.add_child(shape)
		root.get_child(i).add_child(body)
	s.interior_collision_ready = true


func _build_altar(s: Site) -> void:
	s.cap = AmbushAltar.dress(s)
	if s.cap != null:
		return
	_mesh_cylinder(s, 0.45, 3.2, Vector3.UP * 1.6, _solid(Palette.VERDIGRIS))
	s.cap = _mesh_box(s, Vector3(1.4, 0.6, 1.4), Vector3.UP * 3.5, _solid(Palette.BRASS))
	_mesh_box(s, Vector3(1.42, 0.12, 1.42), Vector3.UP * 3.22, _solid(Palette.SAND))


func _build_cache(s: Site) -> void:
	if not s.drawn:
		var face: Vector2 = s.rule["face"]
		s.rotation.y = atan2(face.x, face.y)
		s.global_position += s.global_basis.z * CACHE_LANE_OFFSET
		s.global_position.y = ctx.terrain.height(s.global_position.x, s.global_position.z)
	var local := Vector3(0.0, 0.0, -PEDESTAL_BACK)
	s.pedestal = s.to_global(local)
	s.pedestal.y = ctx.terrain.height(s.pedestal.x, s.pedestal.z)
	s.fired_glow = StandardMaterial3D.new()
	s.fired_glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	s.fired_glow.albedo_color = Color.BLACK
	s.fired_glow.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	if not _model_cache(s):
		_greybox_cache(s)


func _model_cache(s: Site) -> bool:
	var shell := CrackedCache.model_part("CacheShell", s)
	if shell == null:
		return false
	var tall := WALL_HEIGHT + WALL_SINK
	var mid := tall * 0.5 - WALL_SINK
	var rise := tall / (CrackedCache.HEIGHT + CrackedCache.SINK)
	var deep := WALL_DEPTH / (CrackedCache.HALF_D * 2.0 + 0.5)
	var front := CrackedCache.HALF_D + 0.5
	shell.transform = Transform3D(Basis.from_scale(Vector3(1.0, rise, deep)),
		Vector3(0.0, WALL_HEIGHT - CrackedCache.HEIGHT * rise, -front * deep)) * shell.transform
	shell.material_overlay = s.fired_glow
	s.wall = _wall_body(s, Vector3(WALL_HALF_W * 2.0, tall, 1.0), Vector3(0.0, mid, 0.0))
	var panel := CrackedCache.model_part("CacheWall", s.wall)
	panel.transform = Transform3D(Basis.from_scale(Vector3(1.0, rise, 1.0)) * panel.basis, Vector3.ZERO)
	for side in [-1.0, 1.0]:
		_wall_body(s, Vector3(1.0, tall, WALL_DEPTH), Vector3(side * (WALL_HALF_W + 0.5), mid, -WALL_DEPTH * 0.5))
	_wall_body(s, Vector3(WALL_HALF_W * 2.0 + 2.0, tall, 1.0), Vector3(0.0, mid, -WALL_DEPTH - 0.5))
	CrackedCache.model_part("CachePedestal", s).position = s.to_local(s.pedestal)
	return true


func _greybox_cache(s: Site) -> void:
	var concrete := PropMeshes.weathered_material(Palette.VERDIGRIS.lerp(Palette.CHARCOAL, 0.35), 0.84, 0.14, 0.0, "cache_concrete")
	var tall := WALL_HEIGHT + WALL_SINK
	var mid := tall * 0.5 - WALL_SINK
	s.wall = _mesh_box(s, Vector3(WALL_HALF_W * 2.0, tall, 1.0), Vector3(0.0, mid, 0.0),
		PropMeshes.weathered_material(Palette.SANDSTONE.lerp(Palette.VERDIGRIS, 0.3), 0.80, 0.12, 0.0, "cache_face"), true)
	for k in 3:
		var crack := _mesh_box(s.wall, Vector3(WALL_HALF_W * 1.3, 0.2, 1.1), Vector3(0.0, -1.2 + k * 1.6, 0.0),
			_solid(Palette.CHARCOAL))
		crack.rotation.z = 0.5 - k * 0.45
	for side in [-1.0, 1.0]:
		_mesh_box(s, Vector3(1.0, tall, WALL_DEPTH), Vector3(side * (WALL_HALF_W + 0.5), mid, -WALL_DEPTH * 0.5), concrete, true)
	var back := _mesh_box(s, Vector3(WALL_HALF_W * 2.0 + 2.0, tall, 1.0), Vector3(0.0, mid, -WALL_DEPTH - 0.5), concrete, true)
	_mesh_cylinder(s, 0.8, 0.6, s.to_local(s.pedestal) + Vector3.UP * 0.3, _solid(Palette.CHARCOAL))
	load("res://src/presentation/spillway_scenery.gd").dress_props(s, s.view)
	(back.get_child(1) as GeometryInstance3D).material_overlay = s.fired_glow


func _dress_find(s: Site, find_id: String) -> void:
	var f: Dictionary = Secrets.FINDS[find_id]
	_hang_board(s, "Find_" + find_id, String(f["name"]), String(f["log"]))
	s.set_meta("find", find_id)
	s.view.finish()
	if ctx.get("codex") != null:
		ctx.codex.declare(f["codex"])
	if f["kind"] == "radio":
		_radio_tell(s)
	else:
		_seep_tell(s)
	_range_tree(s, SITE_VIEW_END_M, s.view)


func _dress_patch_wire(s: Site, wire_id: String) -> void:
	var row: Dictionary = PilotStory.PATCH_TRAIL.get(wire_id, {})
	_hang_board(s, "PatchWire_" + wire_id, String(row.get("name", wire_id)), String(row.get("log", "")))
	s.set_meta("patch_wire", wire_id)
	s.set_meta("find", wire_id)
	s.view.finish()
	_seep_tell(s)
	_range_tree(s, SITE_VIEW_END_M, s.view)


func _seep_tell(s: Site) -> void:
	if _find_wet == null:
		_find_wet = _solid(Palette.CHARCOAL.lerp(Palette.VERDIGRIS, 0.35))
	var wet := _find_wet
	for k in FIND_SEEP_STREAKS.size():
		var streak: Vector3 = FIND_SEEP_STREAKS[k]
		var mark: Node3D = ModelKit.part(FIND_KIT, FIND_PARTS, "FindSeep", s.wall)
		if mark != null:
			mark.position = Vector3(streak.x, streak.y, 0.52)
			mark.scale = Vector3(streak.z, WALL_HEIGHT * 0.8, 1.0)
		else:
			mark = _mesh_box(s.wall, Vector3(streak.z, WALL_HEIGHT * 0.8, 0.04), Vector3(streak.x, streak.y, 0.52), wet)
		mark.name = "FindSeep%d" % k
	var glint: Node3D = WorldFxAnchor.make("secret")
	glint.name = "FindGlint"
	glint.position = Vector3(0.0, WALL_HEIGHT * 0.6, 1.2)
	s.wall.add_child(glint)
	s.wall.add_child(_find_sound("find_drip", Secrets.DRIP_HEAR_M))


func _dress_door(s: Site) -> void:
	_hang_board(s, "Door_clock", String(Secrets.DOOR["name"]), String(Secrets.DOOR["log"]))
	s.set_meta("door", true)
	if ctx.get("codex") != null:
		ctx.codex.declare(Secrets.DOOR["codex"])
	var clock := Node3D.new()
	clock.name = "DoorClock"
	clock.position = Vector3(0.0, 1.3, 0.52)
	s.wall.add_child(clock)
	var casing := MeshInstance3D.new()
	casing.mesh = PropMeshes.door_clock_casing(DOOR_CLOCK_M)
	casing.material_override = PropMeshes.weathered_material(Palette.BRASS, 0.52, 0.52, 0.0, "clock_brass")
	clock.add_child(casing)
	var dial := MeshInstance3D.new()
	dial.mesh = PropMeshes.door_clock_face(DOOR_CLOCK_M)
	dial.position = Vector3(0.0, 0.0, 0.05)
	dial.material_override = PropMeshes.weathered_material(Palette.LEDGER.darkened(0.12), 0.78, 0.06, 0.0, "clock_face")
	clock.add_child(dial)
	var ink := _solid(Palette.CHARCOAL)
	var hour := MeshInstance3D.new()
	hour.mesh = PropMeshes.door_clock_hand(0.1, DOOR_CLOCK_M * 0.3)
	hour.position = Vector3(0.0, DOOR_CLOCK_M * 0.15, 0.1)
	hour.material_override = ink
	hour.name = "HourHand"
	clock.add_child(hour)
	var minute := Node3D.new()
	minute.position = Vector3(0.0, 0.0, 0.12)
	minute.rotation.z = deg_to_rad(30.0)
	clock.add_child(minute)
	var min_hand := MeshInstance3D.new()
	min_hand.mesh = PropMeshes.door_clock_hand(0.07, DOOR_CLOCK_M * 0.42)
	min_hand.position = Vector3(0.0, DOOR_CLOCK_M * 0.21, 0.0)
	min_hand.material_override = ink
	minute.add_child(min_hand)
	_range_tree(s, SITE_VIEW_END_M, s.view)


func _radio_tell(s: Site) -> void:
	var aerial: Node3D = ModelKit.part(FIND_KIT, FIND_PARTS, "FindAerial", s)
	if aerial != null:
		aerial.position = Vector3(WALL_HALF_W + 0.5, WALL_HEIGHT, -1.0)
	else:
		aerial = _mesh_box(s, Vector3(0.12, FIND_AERIAL_M, 0.12), Vector3(WALL_HALF_W - 1.0, WALL_HEIGHT + FIND_AERIAL_M * 0.5, -1.0),
			_solid(Palette.BRASS))
	aerial.name = "FindAerial"
	s.wall.add_child(_find_sound("find_radio", Secrets.RADIO_HEAR_M))


func _find_sound(id: String, reach: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.name = "FindTell"
	p.stream = SfxBank.loop_stream(id)
	p.bus = "SFX"
	p.volume_db = SfxBank.trim_db(id)
	p.unit_size = reach * 0.25
	p.max_distance = reach
	p.position = Vector3(0.0, 2.0, 0.6)
	p.autoplay = true
	return p


func _hang_room_log(s: Site, room_id: String) -> void:
	var room: Dictionary = Secrets.room_by_id(room_id)
	_hang_board(s, "Secret_" + room_id, String(room["name"]), String(room["log"]))
	s.set_meta("room", room_id)
	_chalk_tally(s.wall)
	_hang_glove(s)
	_range_tree(s, SITE_VIEW_END_M, s.view)


func _hang_board(s: Site, site_name: String, title: String, text: String) -> void:
	s.name = site_name
	var board_z := -WALL_DEPTH + 0.06
	var frame: Node3D = ModelKit.part(FIND_KIT, FIND_PARTS, "FindBoardFrame", s)
	var board: Node3D = ModelKit.part(FIND_KIT, FIND_PARTS, "FindBoard", s)
	if frame != null and board != null:
		frame.position = Vector3(0.0, ROOM_LOG_HEIGHT, board_z - 0.04)
		board.position = frame.position
		(board as MeshInstance3D).material_override = _solid(Palette.CHARCOAL)
	else:
		frame = _mesh_box(s, Vector3(ROOM_BOARD_SIZE.x + 0.3, ROOM_BOARD_SIZE.y + 0.3, 0.08),
			Vector3(0.0, ROOM_LOG_HEIGHT, board_z), _solid(Palette.BRASS))
		board = _mesh_box(s, Vector3(ROOM_BOARD_SIZE.x, ROOM_BOARD_SIZE.y, 0.08),
			Vector3(0.0, ROOM_LOG_HEIGHT, board_z + 0.04), _solid(Palette.CHARCOAL))
	frame.name = "RoomBoardFrame"
	board.name = "RoomBoard"
	var label := Label3D.new()
	label.name = "RoomLog"
	label.text = "%s\n%s" % [title.to_upper(), text]
	label.position = Vector3(0.0, ROOM_LOG_HEIGHT, board_z + 0.1)
	label.font_size = 40
	label.outline_size = 4
	label.outline_modulate = Palette.CHARCOAL
	label.width = ROOM_LOG_WIDTH_PX
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.modulate = Palette.LEDGER
	label.render_priority = 2
	label.outline_render_priority = 1
	s.add_child(label)


func _chalk_tally(wall: Node3D) -> void:
	var chalk := _solid(Palette.LEDGER)
	var tally := Node3D.new()
	tally.name = "RoomTally"
	tally.position = ROOM_TALLY_AT
	wall.add_child(tally)
	var stroke_mesh := PropMeshes.chalk_stroke(ROOM_TALLY_STROKE.x, ROOM_TALLY_STROKE.y)
	for k in 4:
		var stroke := MeshInstance3D.new()
		stroke.mesh = stroke_mesh
		stroke.material_override = chalk
		stroke.position = Vector3(-0.39 + k * 0.26, 0.0, 0.0)
		stroke.rotation.z = 0.06 * (k % 2 * 2 - 1)
		tally.add_child(stroke)
	var bar := MeshInstance3D.new()
	bar.mesh = PropMeshes.chalk_stroke(ROOM_TALLY_STROKE.x, ROOM_TALLY_STROKE.y * 1.25)
	bar.material_override = chalk
	bar.position = Vector3(0.0, 0.0, 0.01)
	bar.rotation.z = -1.05
	tally.add_child(bar)


func _hang_glove(s: Site) -> void:
	var glove := Node3D.new()
	glove.name = "RoomGlove"
	glove.position = ROOM_GLOVE_AT + Vector3(0.0, 0.0, 0.1 * ROOM_GLOVE_SCALE + 0.02)
	glove.basis = (Basis(Vector3.BACK, 0.22) * Basis(Vector3.RIGHT, -PI * 0.5)).scaled(Vector3.ONE * ROOM_GLOVE_SCALE)
	s.wall.add_child(glove)
	var hand := MeshInstance3D.new()
	hand.mesh = PropMeshes.work_glove_leather()
	hand.material_override = PropMeshes.weathered_material(Palette.COPPER, 0.78, 0.12, 0.0, "glove_leather")
	glove.add_child(hand)
	var cuff := MeshInstance3D.new()
	cuff.mesh = PropMeshes.work_glove_cuff()
	cuff.material_override = PropMeshes.weathered_material(Palette.LEDGER.darkened(0.16), 0.88, 0.02, 0.0, "glove_cuff")
	glove.add_child(cuff)
	var peg := MeshInstance3D.new()
	peg.mesh = PropMeshes.work_glove_peg()
	peg.material_override = PropMeshes.weathered_material(Palette.CHARCOAL, 0.65, 0.45, 0.0, "glove_peg")
	glove.add_child(peg)


static var _parts := {}


static func _solid(color: Color) -> StandardMaterial3D:
	var key := "solid:" + color.to_html()
	if not _parts.has(key):
		_parts[key] = PropMeshes.weathered_material(color, 0.76, 0.22, 0.0, "act_" + color.to_html(false))
	return _parts[key]


func _mesh_box(parent: Node3D, size: Vector3, at: Vector3, mat: Material, solid := false) -> Node3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = PropMeshes.bevel_prop_box(size)
	mesh.material_override = mat
	if not solid:
		mesh.position = at
		parent.add_child(mesh)
		return mesh
	var body := _wall_body(parent, size, at)
	body.add_child(mesh)
	return body


func _wall_body(parent: Node3D, size: Vector3, at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	body.physics_material_override = _wall_material()
	body.add_child(shape)
	body.position = at
	parent.add_child(body)
	return body


func _mesh_cylinder(parent: Node3D, radius: float, height: float, at: Vector3, mat: Material) -> void:
	var mesh := MeshInstance3D.new()
	mesh.mesh = PropMeshes.fluted_plume_column(radius, radius, height)
	mesh.material_override = mat
	mesh.position = at
	parent.add_child(mesh)


func _physics_process(delta: float) -> void:
	if not _ahead.is_empty():
		if _ahead.wait > 0:
			_ahead.wait -= 1
			if _ahead.wait == 0:
				_plan_ahead()
		elif _ahead.built.size() < _ahead.plan.sites.size():
			_step_ahead()
	if ctx == null or not ctx.flow.in_stage():
		return
	if _pending_stage and ctx.spawner != null and not ctx.calm:
		_pending_stage = false
		for s in sites:
			if s.id == "hauler_bounty":
				_spawn_bounty(s)
	var ball: Vector3 = ctx.player.ball_position()
	for s in sites:
		if not is_instance_valid(s):
			continue
		if not s.interior.is_empty() and not s.interior_collision_ready:
			var local: Vector3 = s.to_local(ball)
			if absf(local.x) <= s.footprint.x * 0.5 and absf(local.z) <= s.footprint.z * 0.5 \
					and local.y >= 0.0 and local.y <= s.footprint.y:
				_activate_interior_collision(s)
		s.view.near(ball)
		if s.rule.finishes == "trade":
			_watch_trade(s, ball)
			continue
		if s.rule.has("bundle"):
			step_pocket(s, delta, ball)
			_watch_pickup(s, ball)
			continue
		if not s.done:
			match String(s.rule["finishes"]):
				"relay":
					_watch_relay(s, delta, ball)
				"count":
					_watch_yard(s, delta, ball)
				"surge":
					_watch_surge(s, delta, ball)
				"pack_dead":
					_watch_ambush(s, ball)
				"wall_broken":
					_watch_wall(s, ball)
			_advance_hazards(s, delta, ball)
		_watch_pickup(s, ball)
	for ward in wards:
		_watch_ward(ward, delta, ball)
	for plate in plates:
		_watch_plate(plate, ball)


func _planar(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func at_hand(ball: Vector3, held: Site = null) -> Site:
	if is_instance_valid(held) and _hand_metres(held, ball) <= LET_GO_M:
		return held
	var best: Site = null
	var best_m := AT_HAND_M
	for s in sites:
		var m := _hand_metres(s, ball)
		if m <= best_m:
			best = s
			best_m = m
	return best


func _hand_metres(s: Site, ball: Vector3) -> float:
	if not is_instance_valid(s) or s.done or s.failed or not s.started or s.has_meta("find") or s.rule.finishes == "trade":
		return INF
	if s.id == "hauler_bounty":
		return _planar(ball, s.brute.global_position) if is_instance_valid(s.brute) and s.brute.bounty_met else INF
	return 0.0 if s.surge_live else _planar(ball, s.global_position)


func _build_pocket(s: Site, spec: Dictionary) -> void:
	s.graph = spec.get("graph", _graph)
	s.difficulty = clampf(float(spec.get("difficulty", 1.0)), 1.0, float(s.rule.get("difficulty_cap", 3.0)))
	s.tier_label = s.view.word
	_show_reward(s)
	if "hazard" in s.rule.bundle:
		_build_hazard(s)
	match s.id:
		"movement_course":
			for offset in [12.0, 24.0, 36.0]:
				s.targets.append(ctx.terrain.drop_point(s.global_position.x + offset, s.global_position.z, 0.0))
		"objective_limit":
			s.targets.append(ctx.terrain.drop_point(s.global_position.x + 24.0, s.global_position.z, 0.0))
		"scattered_marks":
			if s.graph != null:
				var graph_id: int = s.graph.get_instance_id()
				if not _mark_pools.has(graph_id):
					_mark_pools[graph_id] = mark_candidates(s.graph)
				var pool: Array = _mark_pools[graph_id]
				for n in draw_marks(s.graph, ctx.rng.seed, pool):
					s.targets.append(s.graph.position(n))
			if s.targets.size() < 3:
				s.failed = true
	for target in s.targets:
		var marker := ActivityView.gem(String(s.rule.cue.view))
		s.add_child(marker)
		marker.global_position = target
		s.target_views.append(marker)


func _show_reward(s: Site) -> void:
	var suffix := "round_%d" % maxi(1, s.round) if s.id == "round_arena" else "clear"
	s.reward_parts = _reward_parts(s, suffix)
	var shown := stand_odds(s)
	s.tier_label.text = "%s — Tier %d (%s)" % [s.rule.cue.word, shown.tier, shown.reward_text]
	s.tier_label.modulate = ItemGen.RARITY[shown.reward_rarity].color


func step_pocket(s: Site, delta: float, ball: Vector3) -> void:
	_watch_round_pickups(s, ball)
	if s.done or s.failed:
		return
	if s.id == "scattered_marks":
		for i in s.targets.size():
			if not s.taken.has(i) and _touches(ball, s.targets[i]):
				s.taken[i] = true
				s.marks_taken += 1
				s.target_views[i].visible = false
				_cue(s, "telegraph")
		if s.marks_taken == s.targets.size() and s.marks_taken >= 3:
			_finish(s, s.global_position)
		return
	if not s.started:
		if _planar(ball, s.global_position) > float(s.rule.ring) or absf(ball.y - s.global_position.y) > RING_HEIGHT:
			return
		if s.id in ["arena", "elite_arena", "round_arena", "ambush"] and (ctx.calm or ctx.spawner == null):
			return
		if s.id == "elite_arena" and _elite_arrivals >= 3:
			return
		s.started = true
		_cue(s, "telegraph")
		match s.id:
			"arena", "elite_arena":
				_spawn_pocket_pack(s, s.rule.pack)
				if s.pack.is_empty():
					s.started = false
					return
				_begin_hazards(s, 1)
				if s.id == "elite_arena":
					_elite_arrivals += 1
					s.brute = s.pack.back()
					s.brute.died.connect(func(_at, _scrap): _elite_clear(s))
			"round_arena":
				_begin_round(s)
			"ambush":
				_begin_hazards(s, 1)
				_next_wave(s)
	_advance_hazards(s, delta, ball)
	match String(s.rule.finishes):
		"course":
			if s.next_target < s.targets.size() and _touches(ball, s.targets[s.next_target]):
				s.target_views[s.next_target].visible = false
				s.next_target += 1
			if s.next_target == s.targets.size():
				_finish(s, s.global_position)
		"timed_pickup":
			s.ticks += 1
			if s.ticks > int(s.rule.limit_ticks):
				s.failed = true
				s.view.finish()
				for marker in s.target_views:
					marker.visible = false
			elif _touches(ball, s.targets[0]):
				s.target_views[0].visible = false
				_finish(s, s.global_position)
		"arena":
			if _alive(s.pack) == 0:
				_finish(s, s.global_position)
		"elite":
			if is_instance_valid(s.brute) and s.brute.is_dead():
				_elite_clear(s)
		"waves":
			if _alive(s.pack) == 0:
				if s.wave == s.rule.waves.size():
					_finish(s, s.global_position)
				else:
					_next_wave(s)
		"rounds":
			if s.awaiting_round:
				if s.fog.active:
					s.awaiting_round = false
					var kinds := []
					for i in maxi(s.round_elements.size(), floori(s.round_credits / float(s.rule.enemy_credit))):
						kinds.append(s.round_elements[i % s.round_elements.size()])
					if not s.interior.is_empty():
						kinds.clear()
						for i in maxi(s.rule.pack.size(), floori(s.round_credits / float(s.rule.enemy_credit))):
							kinds.append(s.rule.pack[i % s.rule.pack.size()])
					_spawn_pocket_pack(s, kinds)
			elif _alive(s.pack) == 0:
				_pay_round(s)
				if s.round == int(s.rule.rounds):
					_finish(s, s.global_position)
				else:
					_begin_round(s)


func _touches(ball: Vector3, at: Vector3) -> bool:
	return _planar(ball, at) <= PICKUP_REACH and absf(ball.y - at.y) <= PICKUP_HEIGHT


func _build_hazard(s: Site) -> void:
	if not s.interior.is_empty():
		for box in s.interior.hazards:
			var hazard := PocketFog.new()
			s.add_child(hazard)
			var centre := s.global_position + Vector3(box.at[0], 0, box.at[1])
			var size := Vector3(box.size[0], box.size[1], box.size[2])
			if s.drawn:
				centre = s.to_global(Vector3(box.at[0], 0, box.at[1]))
				size = (s.global_basis * size).abs()
				hazard.top_level = true
				hazard.global_transform = Transform3D.IDENTITY
			hazard.setup(centre, size, POCKET_SAFE_M, POCKET_DAMAGE_PER_S, ctx.rng.seed)
			s.hazards.append(hazard)
		if not s.hazards.is_empty():
			s.fog = s.hazards[0]
		return
	s.fog = PocketFog.new()
	s.add_child(s.fog)
	s.fog.setup(s.global_position, s.footprint, POCKET_SAFE_M, POCKET_DAMAGE_PER_S, ctx.rng.seed)
	s.hazards.append(s.fog)


func _begin_hazards(s: Site, round_number: int) -> void:
	for hazard in s.hazards:
		hazard.begin(round_number)


func _advance_hazards(s: Site, delta: float, ball: Vector3) -> void:
	for hazard in s.hazards:
		for fact in hazard.advance(delta, ball):
			if fact.kind == "world":
				ctx.events.world_fact.emit(fact.fact, fact.at)
		var damage: float = hazard.damage_at(ball) * delta
		if damage > 0.0:
			ctx.run.damage(damage, "pocket_veil")


func _cue(s: Site, phase: String) -> void:
	var kind := String(s.rule.cue[phase])
	var row := EventKinds.row(kind)
	var presentation: Node = ctx.root.get_node_or_null("Presentation")
	if presentation != null:
		presentation.audio.play(kind)
		if presentation.audio.has_method("activity_cue"):
			presentation.audio.activity_cue(s.id, phase)
	if is_instance_valid(s.phase_view):
		s.phase_view.queue_free()
	s.phase_view = ActivityView._glyph(String(row.shape), row.color)
	s.add_child(s.phase_view)
	s.phase_view.position = Vector3.UP * 2.0
	if s.view.word != null:
		s.view.word.modulate = row.color


func _pocket_roll(s: Site, suffix: String, count := 1) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = Interact.luck_seed(ctx.rng.seed, ctx.run.run_id, ctx.run.stage, s.id + suffix)
	return Parts.roll(rng, pay_table(s).rarities, ctx.run.class_id(), ctx.run.parts, count)


func _reward_parts(s: Site, suffix: String) -> Array:
	var table := pay_table(s)
	if table.named != "":
		return [table.named]
	return _pocket_roll(s, suffix, int(s.rule.pay.parts))


func _heal(s: Site) -> void:
	if s.heal_paid or not "heal" in s.rule.get("bundle", []):
		return
	ctx.run.heal(ctx.run.max_hp * POCKET_HEAL_SHARE)
	s.heal_paid = true


func _elite_clear(s: Site) -> void:
	if not is_instance_valid(s) or s.done:
		return
	for enemy in s.pack:
		if is_instance_valid(enemy) and enemy != s.brute:
			enemy.queue_free()
	s.pack.clear()
	_finish(s, s.global_position)


func _spawn_pocket_pack(s: Site, kinds: Array) -> void:
	s.pack.clear()
	var positions := pocket_positions(s, kinds.size())
	if positions.size() != kinds.size():
		s.failed = true
		for hazard in s.hazards:
			hazard.stop()
		return
	for i in kinds.size():
		var spot: Vector3 = positions[i]
		var enemy = ctx.spawner.spawn_enemy(String(kinds[i]), ctx.terrain.drop_point(spot.x, spot.z, SPAWN_CLEARANCE))
		if enemy != null:
			s.pack.append(enemy)
			s.spawn_positions.append(enemy.global_position)


func pocket_positions(s: Site, count: int) -> Array:
	if not s.interior.is_empty():
		return _library_positions(s, count)
	var result := []
	for i in count:
		var angle := PACK_TURN + TAU * float(i) / count
		var point := s.global_position + Vector3(cos(angle), 0, sin(angle)) * float(s.rule.ring)
		if s.id == "ambush" and s.interior.is_empty():
			if s.graph == null:
				return []
			var candidates: PackedInt32Array = s.graph.disc_nodes(Vector2(point.x, point.z), float(s.rule.ring))
			var eligible := PackedInt32Array()
			for n in candidates:
				if s.graph.flags(n) & ParkGraph.DOOR_OK != 0 and s.graph.flags(n) & ParkGraph.LINE == 0:
					eligible.append(n)
			var node: int = s.graph.nearest_in(eligible, point)
			if node < 0:
				return []
			point = s.graph.position(node)
		result.append(point)
	return result


func _library_positions(s: Site, count: int) -> Array:
	var entry := Vector2(s.interior.entry_spot[0], s.interior.entry_spot[1])
	var rear := entry.angle() + PI
	var radius := maxf(float(s.rule.ring), minf(s.footprint.x, s.footprint.z) * 0.35)
	var result := []
	for i in count:
		var angle := rear - PI * 0.25 + PI * 0.5 * (float(i) + 0.5) / count
		result.append(s.to_global(Vector3(cos(angle), 0, sin(angle)) * radius))
	return result


func _next_wave(s: Site) -> void:
	var kinds: Array = s.rule.waves[s.wave]
	s.wave += 1
	_spawn_pocket_pack(s, kinds)


func _begin_round(s: Site) -> void:
	s.round += 1
	s.round_elements.append(s.rule.elements[s.round - 1])
	s.round_credits = (float(s.rule.base) + float(s.rule.step) * (s.round - 1)) * s.difficulty
	s.awaiting_round = true
	_begin_hazards(s, s.round)
	_show_reward(s)


func _pay_round(s: Site) -> void:
	for hazard in s.hazards:
		hazard.stop()
	s.heal_paid = false
	_heal(s)
	var picks: Array = s.reward_parts.duplicate()
	var pickup := ActivityView.gem(String(s.rule.cue.view))
	s.add_child(pickup)
	pickup.global_position = s.fog.committed.safe_at
	s.round_rewards.append({"pickup": pickup, "parts": picks, "inside": _touches(ctx.player.ball_position(), pickup.global_position)})
	s.round_payments += 1
	_cue(s, "clear")


func _watch_round_pickups(s: Site, ball: Vector3) -> void:
	for reward in s.round_rewards.duplicate():
		var now := _touches(ball, reward.pickup.global_position)
		if now and not reward.inside:
			for part in reward.parts:
				ctx.run.add_part(part, String(s.rule.pay.source))
			_pay_scrap(s, reward.pickup.global_position)
			reward.pickup.queue_free()
			s.round_rewards.erase(reward)
			_cue(s, "pay")
		else:
			reward.inside = now


static func mark_far_m(graph) -> float:
	var farthest := 0.0
	for n in graph.node_count():
		if graph.flags(n) & ParkGraph.DOOR_OK != 0 and is_finite(graph.d_spawn_node(n)):
			farthest = maxf(farthest, graph.d_spawn_node(n))
	return farthest * 0.5


static func mark_candidates(graph) -> Array:
	var far := mark_far_m(graph)
	var nodes := []
	for n in graph.node_count():
		if graph.flags(n) & ParkGraph.DOOR_OK != 0 and is_finite(graph.d_spawn_node(n)) and is_finite(graph.d_landmark_node(n)) and graph.d_spawn_node(n) >= far:
			nodes.append(n)
	nodes.sort_custom(func(a, b): return graph.d_spawn_node(a) < graph.d_spawn_node(b))
	var pool := []
	if nodes.is_empty():
		return pool
	var anchor := PackedInt32Array([nodes[0]])
	var from_anchor: PackedByteArray = graph.reach(anchor)
	var to_anchor: PackedFloat32Array = graph.search(anchor, true)
	nodes = nodes.filter(func(n): return from_anchor[n] != 0 and is_finite(to_anchor[n]))
	for i in mini(MARK_POOL_SIZE, nodes.size()):
		pool.append(nodes[roundi(float(i) * (nodes.size() - 1) / (MARK_POOL_SIZE - 1))])
	return pool


static func draw_marks(graph, seed_value: int, pool: Array = []) -> Array:
	if pool.is_empty():
		pool = mark_candidates(graph)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var count := rng.randi_range(3, 4)
	var candidates := pool.duplicate()
	for i in range(candidates.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap = candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = swap
	var marks := []
	for n in candidates:
		if marks.all(func(other): return absf(graph.d_spawn_node(n) - graph.d_spawn_node(other)) >= MARK_SPACING_M):
			marks.append(n)
			if marks.size() == count:
				return marks
	return marks


func _watch_ambush(s: Site, ball: Vector3) -> void:
	if not s.started:
		if ctx.calm or not ctx.can_spawn():
			return
		if _planar(ball, s.global_position) > float(s.rule["ring"]) or absf(ball.y - s.global_position.y) > RING_HEIGHT:
			return
		_spawn_pack(s)
		return
	if _alive(s.pack) == 0:
		_finish(s, s.global_position)


func _spawn_pack(s: Site) -> void:
	if not s.interior.is_empty():
		_spawn_pocket_pack(s, s.rule.pack)
		s.started = not s.pack.is_empty()
		if s.started:
			_begin_hazards(s, 1)
		return
	var kinds: Array = s.rule["pack"]
	s.pack.clear()
	var entry: Vector3 = ctx.player.ball_position() - s.global_position
	var first := atan2(entry.z, entry.x) + PI + PACK_TURN
	for i in kinds.size():
		var a := first + TAU * float(i) / kinds.size()
		var spot := s.global_position + Vector3(cos(a), 0.0, sin(a)) * float(s.rule["ring"])
		var enemy = ctx.spawner.spawn_enemy(kinds[i], ctx.terrain.drop_point(spot.x, spot.z, SPAWN_CLEARANCE))
		if enemy != null:
			s.pack.append(enemy)
	s.started = not s.pack.is_empty()
	if s.started and s.fog != null:
		s.fog.begin(1)


static func _alive(pack: Array) -> int:
	var n := 0
	for enemy in pack:
		if is_instance_valid(enemy) and not (enemy.has_method("is_dead") and enemy.is_dead()):
			n += 1
	return n


func _build_relay(s: Site) -> void:
	var at := Vector2(s.global_position.x, s.global_position.z)
	s.relay = HoldRelay.new({"relay": at, "ring": at}, s.global_position.y)
	var post := RelayStake.new()
	post.relay = s.relay
	s.add_child(post)
	var spawn: Vector3 = ctx.terrain.spawn_point(ctx.run.stage)
	var toward := Vector2(spawn.x, spawn.z) - at
	toward = toward.normalized() if toward.length() > 0.01 else Vector2(0.0, -1.0)
	var post_at := at + toward * (float(s.rule["ring"]) + float(s.rule["post_out"]))
	post.global_position = ctx.terrain.drop_point(post_at.x, post_at.y, 0.0)
	post.setup(ctx, ctx.root.get_node("Interact"), {"id": "relay_stake_%d_%s" % [ctx.run.stage, s.name]})
	if _site_parent == null:
		ctx.root.get_node("Interact").register(post)
	s.stake_post = post
	s.view.word.text = s.relay.stake_line()


func relay_pack_cost(s: Site) -> float:
	return Cards.cost(s.rule["pack"])


func relay_miniboss_count(s: Site) -> int:
	return int(round(s.relay.miniboss_credit(1.0)))


func relay_budget(s: Site) -> int:
	var b: Dictionary = s.rule["budget"]
	var world: int = ctx.stages.world_of(ctx.run.stage)
	return mini(int(b["cap"]), int(b["start"]) + int(b["per_class"]) * maxi(0, ctx.run.heft_class() - 1) + int(b["per_world"]) * maxi(0, world - 1))


func relay_standing(s: Site) -> int:
	return _alive(s.pack) + _alive(s.minibosses)


func _watch_relay(s: Site, delta: float, ball: Vector3) -> void:
	var relay = s.relay
	if not s.started:
		s.view.word.text = relay.stake_line()
		s.relay_cooldown -= delta
		if s.relay_cooldown > 0.0:
			return
		if not ctx.can_spawn():
			return
		if _planar(ball, s.global_position) > float(s.rule["ring"]) or absf(ball.y - s.global_position.y) > HoldRelay.REACH_UP:
			return
		s.started = true
		relay.begin()
		s.relay_credit = relay.pack_credit(relay_pack_cost(s) * int(s.rule["waves"]))
		s.relay_wave_s = 0.0
		s.relay_gap_s = 0.0
		s.relay_wave_left = 0
		s.minibosses_sent = 0
		s.relay_shown = -1.0
		ctx.events.event_started.emit(s.id)
	var outcome: String = relay.step(delta, ball, ctx.player.state.velocity)
	if relay.progress() - s.relay_shown >= RELAY_PROGRESS_STEP or (relay.progress() >= 1.0 and s.relay_shown < 1.0):
		s.relay_shown = relay.progress()
		ctx.events.event_progress.emit(s.id, s.relay_shown)
	s.view.word.text = relay.status()
	s.pack = s.pack.filter(func(enemy): return is_instance_valid(enemy) and not (enemy.has_method("is_dead") and enemy.is_dead()))
	s.relay_wave_s -= delta
	s.relay_gap_s -= delta
	var cost := relay_pack_cost(s)
	var room := relay_budget(s) - relay_standing(s)
	var due: int = mini(relay_miniboss_count(s), int(floor((relay.progress() - float(s.rule["miniboss_at"])) / float(s.rule["miniboss_step"]))) + 1)
	if s.relay_wave_s <= 0.0 and s.relay_wave_left == 0 and s.relay_credit >= cost - 0.0001:
		s.relay_wave_left = relay.stakes + 1
		s.relay_wave_s = float(s.rule["wave_s"])
	if s.relay_gap_s <= 0.0:
		if s.minibosses_sent < due and room >= 1:
			_relay_miniboss(s)
		elif s.relay_wave_left > 0 and s.relay_credit >= cost - 0.0001 and room >= s.rule["pack"].size():
			_relay_pack(s, ball)
			s.relay_credit -= cost
			s.relay_wave_left -= 1
	if outcome == "won":
		s.stake_post.spent = true
		ctx.events.event_ended.emit(s.id, "won")
		ctx.events.relay_stake_paid.emit(int(relay.stakes))
		_finish(s, s.global_position + Vector3(0.0, 0.0, 6.0))
	elif outcome == "lost":
		ctx.events.event_ended.emit(s.id, "lost")
		s.started = false
		s.relay_cooldown = float(s.rule["retry_s"])


func _build_surge(s: Site, spec: Dictionary) -> void:
	var map = ctx.terrain.map()
	if not "park" in map or map.park.is_empty() or String(spec.get("route", "")) == "":
		return
	var course := SurgeCourse.new()
	s.add_child(course)
	var ring := Vector2(s.global_position.x, s.global_position.z)
	course.setup({"ring": ring, "route": spec.route}, ctx.tuning.f("cruise"), map.park, Callable(ctx.terrain, "height"))
	if course.model.route.points.size() < 2:
		course.queue_free()
		return
	s.course = course
	s.surge_row = String(spec.get("row", s.id))


func _on_world_fact(kind: String, _at: Vector3) -> void:
	if kind != "sluice_landed":
		return
	for s in sites:
		if is_instance_valid(s) and s.course != null and s.started and not s.surge_live and not s.done:
			_surge_begin(s)


func _surge_begin(s: Site) -> void:
	s.surge_live = true
	s.surge_shown = -1.0
	s.course.settle()
	s.course.model.begin()
	ctx.events.event_started.emit(s.id)


func _watch_surge(s: Site, delta: float, ball: Vector3) -> void:
	if s.course == null:
		return
	var model = s.course.model
	if not s.started:
		s.relay_cooldown -= delta
		if s.relay_cooldown > 0.0 or _planar(ball, s.global_position) > float(s.rule["ring"]) or absf(ball.y - s.global_position.y) > RING_HEIGHT:
			return
		s.started = true
		s.surge_wait = float(s.rule["fallback_s"])
		s.view.word.text = SURGE_WORDS.open
		sluice_opened.emit(s.surge_row)
		return
	if not s.surge_live:
		s.surge_wait -= delta
		if s.surge_wait <= 0.0:
			_surge_begin(s)
		return
	var velocity: Vector3 = ctx.player.state.velocity
	var outcome: String = model.step(delta, ball, velocity)
	ctx.player.add_external_accel(EventDirector.never_brake(model.push(ball, velocity), velocity))
	s.course.show_live(outcome == "", fmod(model.elapsed * 2.0, 1.0))
	s.view.word.text = model.status()
	if model.progress() - s.surge_shown >= RELAY_PROGRESS_STEP:
		s.surge_shown = model.progress()
		ctx.events.event_progress.emit(s.id, s.surge_shown)
	if outcome == "won":
		s.surge_live = false
		ctx.events.event_ended.emit(s.id, "won")
		sluice_closed.emit(s.surge_row)
		_finish(s, ball)
		s.view.word.text = SURGE_WORDS.won
		s.inside_pickup = false
	elif outcome == "lost":
		s.surge_live = false
		s.started = false
		s.relay_cooldown = float(s.rule["retry_s"])
		s.course.show_live(false, 0.0)
		s.view.word.text = SURGE_WORDS.lost
		ctx.events.event_ended.emit(s.id, "lost")
		sluice_closed.emit(s.surge_row)


func _relay_pack(s: Site, ball: Vector3) -> void:
	var kinds: Array = s.rule["pack"]
	var entry: Vector3 = ball - s.global_position
	var first := atan2(entry.z, entry.x) + PI + PACK_TURN
	for i in kinds.size():
		var a := first + TAU * float(i) / kinds.size()
		var spot := s.global_position + Vector3(cos(a), 0.0, sin(a)) * float(s.rule["ring"])
		var enemy = ctx.spawner.spawn_enemy(kinds[i], ctx.terrain.drop_point(spot.x, spot.z, SPAWN_CLEARANCE))
		if enemy != null:
			s.pack.append(enemy)
	s.relay_gap_s = float(s.rule["pack_gap_s"])


func yard_standing(s: Site) -> int:
	return _alive(s.pack) + s.yard_owed.size()


func _watch_yard(s: Site, delta: float, ball: Vector3) -> void:
	var yard = s.yard
	if not s.started:
		if not ctx.can_spawn():
			return
		if s.rule.has("siren_s"):
			if not _muster_lands(s, delta, ball):
				return
		elif _planar(ball, s.global_position) > float(s.rule["ring"]) or absf(ball.y - s.global_position.y) > RING_HEIGHT:
			return
		s.started = true
		var going: Vector3 = ctx.player.planar_velocity()
		var landed := Vector2(s.global_position.x, s.global_position.z)
		var heading := Vector2(going.x, going.z)
		yard.begin(landed, heading, func(lap: PackedVector2Array) -> bool: return clear_ground(lap, float(s.rule["ring"]), s))
		_yard_owe(s)
		ctx.events.event_started.emit(s.id)
	elif s.rule.has("siren_s"):
		var ground: Vector2 = yard.ground()
		s.global_position = ctx.terrain.drop_point(ground.x, ground.y, 0.0)
	var inside := _planar(ball, s.global_position) <= float(s.rule["ring"])
	s.pack = s.pack.filter(func(enemy): return is_instance_valid(enemy) and not (enemy.has_method("is_dead") and enemy.is_dead()))
	s.yard_wait -= delta
	if s.yard_wait <= 0.0 and not s.yard_owed.is_empty():
		_yard_arrive(s, ball)
	match yard.step(delta, yard_standing(s)):
		"gate":
			s.view.ring_role("live")
		"count":
			s.view.ring_role("amber")
			s.yard_may_bank = false
			_yard_owe(s)
		"pile":
			_yard_owe(s)
	s.view.say(str(yard.count))
	if s.yard_dress != null:
		s.yard_dress.step(delta, yard.gate_open, [ball] + s.pack.map(func(enemy): return enemy.global_position))
	if inside:
		s.yard_out = 0.0
		s.yard_may_bank = yard.gate_open
	elif yard.gate_open:
		if s.yard_may_bank:
			_yard_pay(s, yard.leave(), ball)
	else:
		s.yard_out += delta
		if s.yard_out >= float(s.rule["out_s"]):
			_yard_forfeit(s)


func _muster_lands(s: Site, delta: float, ball: Vector3) -> bool:
	if ctx.flow.engaged():
		return false
	if not s.yard_called:
		var close: bool = _planar(ball, s.global_position) <= float(s.rule["call_m"])
		s.yard_stood = s.yard_stood and close
		if close and not s.yard_stood:
			s.yard_called = true
			s.yard_siren = float(s.rule["siren_s"])
			ctx.events.event_announced.emit(s.id, s.yard_siren, Vector3.INF)
		return false
	s.yard_siren -= delta
	if s.yard_siren > 0.0:
		return false
	if not clear_ground(PackedVector2Array([Vector2(ball.x, ball.z)]), float(s.rule["ring"]), s):
		if s.yard_siren < -MUSTER_WAIT_S:
			s.yard_called = false
			s.yard_stood = true
		return false
	s.global_position = ctx.terrain.drop_point(ball.x, ball.z, 0.0)
	s.visible = true
	return true


func clear_ground(points: PackedVector2Array, ring: float, but: Site = null) -> bool:
	return ground_fault(points, ring, but) == ""


func ground_fault(points: PackedVector2Array, ring: float, but: Site = null) -> String:
	var map = ctx.terrain.map()
	var keep := _keep_off(map)
	for other in sites:
		if other != but and is_instance_valid(other) and other.visible:
			keep.append({"at": Vector2(other.global_position.x, other.global_position.z), "r": float(other.rule.get("ring", 0.0)) + SITE_PAD_M})
	var inside: Rect2 = map.play_rect.grow(-ring)
	var reads := PackedVector2Array()
	for band in range(1 if points.size() == 1 else 2, int(ring / RING_READ_M) + 1):
		var around := 6 * band
		for k in around / 2:
			var read := Vector2.RIGHT.rotated(TAU * k / around) * minf(ring, band * RING_READ_M)
			reads.append(read)
			reads.append(-read)
	var centres: PackedFloat64Array = ctx.terrain.heights(points)
	var under := PackedVector2Array()
	under.resize(reads.size())
	for i in points.size():
		var p := points[i]
		if not inside.has_point(p):
			return "edge"
		for row in keep:
			var local: Vector2 = p - row["at"]
			var reach: float = float(row["r"]) + ring
			if row.has("half"):
				local = local.rotated(deg_to_rad(float(row["yaw_deg"])))
				var half: Vector2 = row["half"]
				local = Vector2(maxf(0.0, absf(local.x) - half.x), maxf(0.0, absf(local.y) - half.y))
			if local.length() < reach:
				return "taken"
		for k in reads.size():
			under[k] = p + reads[k]
		var across: PackedFloat64Array = ctx.terrain.heights(under)
		for k in range(0, across.size(), 2):
			var lump: float = absf(across[k] + across[k + 1] - 2.0 * centres[i])
			var slope: float = absf(across[k] - across[k + 1]) / (2.0 * reads[k].length())
			if lump > RING_RISE_M or slope > RING_SLOPE:
				return "rise"
	return ""


func _keep_off(map) -> Array:
	if map != _keep_map:
		_keep_map = map
		_keep_rows = []
		for fight in (map.fight_sites() if map.has_method("fight_sites") else []):
			if fight.has("half"):
				_keep_rows.append({"at": fight["at"], "half": fight["half"], "yaw_deg": float(fight.get("yaw_deg", 0.0)), "r": 0.0})
			else:
				_keep_rows.append({"at": fight["at"], "r": float((fight["ring"] as Vector2).y)})
		for row in (map.park.get("contraption_rows", []) if "park" in map else []):
			var wide := CONTRAPTION_M
			for part in [row] + row.values().filter(func(v): return v is Dictionary):
				for n in (part.get("size", []) as Array) + [2.0 * float(part.get("radius", 0.0))]:
					wide = maxf(wide, float(n) * 0.5)
			for part in [row] + row.values().filter(func(v): return v is Dictionary):
				for key in ["at", "from", "to", "target"]:
					if part.get(key) is Array:
						_keep_rows.append({"at": Vector2(float(part[key][0]), float(part[key][-1])), "r": wide})
	return _keep_rows.duplicate()


func _yard_owe(s: Site) -> void:
	var strength: float = s.yard.strength(s.yard.count)
	for kind in s.yard.pack(s.yard.count):
		s.yard_owed.append([kind, strength])


func _yard_arrive(s: Site, ball: Vector3) -> void:
	var owed: Array = s.yard_owed.pop_front()
	var entry: Vector3 = ball - s.global_position
	var a := atan2(entry.z, entry.x) + PI + PACK_TURN * float(s.yard_owed.size() % 5 - 2)
	var spot := s.global_position + Vector3(cos(a), 0.0, sin(a)) * float(s.rule["ring"])
	var enemy = ctx.spawner.spawn_enemy(owed[0], ctx.terrain.drop_point(spot.x, spot.z, SPAWN_CLEARANCE), "", Vector3.INF, owed[1])
	if enemy != null:
		s.pack.append(enemy)
	s.yard_wait = float(s.rule["arrive_s"])


func _yard_pay(s: Site, pay: Dictionary, ball: Vector3) -> void:
	s.reward_parts = []
	var rarities: Array = pay.get("rarities", [])
	for i in rarities.size():
		var rng := RandomNumberGenerator.new()
		rng.seed = Interact.luck_seed(ctx.rng.seed, ctx.run.run_id, ctx.run.stage, "%s:%d" % [s.id, i])
		s.reward_parts.append_array(Parts.roll(rng, [rarities[i]], ctx.run.class_id(), ctx.run.parts + s.reward_parts, 1, s.reward_parts))
	var out: Vector3 = ball - s.global_position
	out.y = 0.0
	var at: Vector3 = ball + out.normalized() * float(s.rule["pay_ahead_m"])
	at = ctx.terrain.drop_point(at.x, at.z, 1.0)
	for i in int(pay.get("cores", 0)):
		ctx.run.add_core(String(s.rule["pay"]["source"]), at)
	var scrap := int(pay.get("scrap", 0))
	if scrap > 0:
		ctx.run.add_scrap(scrap, at)
		ctx.run.add_cogs(scrap)
	ctx.events.event_ended.emit(s.id, "won")
	if s.yard_dress != null:
		s.yard_dress.stand_down()
	_finish(s, at)


func _yard_forfeit(s: Site) -> void:
	s.yard.forfeit()
	s.yard_owed = []
	s.done = true
	if s.yard_dress != null:
		s.yard_dress.stand_down()
	s.view.finish()
	ctx.events.event_ended.emit(s.id, "lost")


func _forfeit_yards() -> void:
	for s in sites:
		if is_instance_valid(s) and s.yard != null and s.started and not s.done:
			_yard_forfeit(s)


func _relay_miniboss(s: Site) -> void:
	var zone: Array = s.relay.miniboss_zone()
	var rng := RandomNumberGenerator.new()
	rng.seed = Interact.luck_seed(ctx.rng.seed, ctx.run.run_id, ctx.run.stage, "%s_miniboss_%d" % [s.id, s.minibosses_sent])
	var angle := rng.randf() * TAU
	var dist := rng.randf_range(zone[1].x, zone[1].y)
	var at: Vector2 = (zone[0] as Vector2) + Vector2(cos(angle), sin(angle)) * dist
	var enemy = ctx.spawner.spawn_enemy("miniboss", ctx.terrain.drop_point(at.x, at.y, BRUTE_DROP))
	s.minibosses_sent += 1
	if enemy != null:
		s.minibosses.append(enemy)
	s.relay_gap_s = float(s.rule["pack_gap_s"])


func _watch_wall(s: Site, ball: Vector3) -> void:
	var v: Vector3 = ctx.player.state.velocity
	var toward := -(v.x * s.global_basis.z.x + v.z * s.global_basis.z.z)
	var local := s.to_local(ball)
	var ahead := local.z - 0.5
	if ahead < -1.0 or ahead > WALL_REACH + maxf(0.0, toward) / 30.0 or absf(local.x) > WALL_HALF_W + 1.0 or local.y > WALL_HEIGHT + 2.0:
		return
	if toward >= ram_bar(s):
		_break_wall(s)
	elif ahead <= WALL_CONTACT and local.y < WALL_HEIGHT:
		_refuse_ram(s, toward)


func _refuse_ram(s: Site, toward: float) -> void:
	var cue: Dictionary = s.rule.get("refused", {})
	if cue.is_empty() or toward < ctx.tuning.f("cruise") * float(cue["floor"]):
		return
	if not int(ctx.stages.world_of(ctx.run.stage)) in cue["worlds"]:
		return
	var frame := Engine.get_physics_frames()
	if s.refused_frame >= 0 and frame - s.refused_frame < int(float(cue["gap_s"]) * Engine.physics_ticks_per_second):
		return
	s.refused_frame = frame
	ctx.events.verb_failed.emit("roll", "under_bar", ctx.player.ball_position())


func ram_bar(s: Site) -> float:
	if s.rule.has("bar_tier"):
		return ctx.tuning.tier_cruise() * SpeedTier.MULTIPLES[int(s.rule["bar_tier"])]
	return ctx.tuning.f("cruise") * RAM_MIN_PER_CRUISE


func _slammed(at: Vector3, strength: float) -> void:
	if strength < ctx.player.slam_strength(ctx.tuning.f("cruise")) * SLAM_MIN_PER_CRUISE:
		return
	for s in sites:
		if s.wall == null or s.done or s.rule.has("bar_tier"):
			continue
		var local: Vector3 = s.to_local(at)
		if local.z > 0.5 and local.z < 0.5 + SLAM_REACH and absf(local.x) <= WALL_HALF_W + 1.0:
			_break_wall(s)


func _break_wall(s: Site) -> void:
	if s.done:
		return
	s.wall.position += Vector3.DOWN * 400.0
	s.wall.visible = false
	if s.fired_glow != null:
		s.fired_glow.emission_enabled = true
		s.fired_glow.emission = Palette.SAND
		s.fired_glow.emission_energy_multiplier = CACHE_FIRED_GLOW.energy
	ctx.events.world_fact.emit("wall_crumbled", s.global_position)
	if s.has_meta("patch_wire"):
		_found_patch_wire(s)
	elif s.has_meta("find"):
		_found(s)
	elif s.has_meta("door") and ctx.get("codex") != null:
		ctx.codex.mark_discovered(String(Secrets.DOOR["codex"]["id"]), s.pedestal)
	_finish(s, s.pedestal)


func _found_patch_wire(s: Site) -> void:
	var wire_id := String(s.get_meta("patch_wire"))
	var tell: Node = s.wall.get_node_or_null("FindTell")
	if tell != null:
		tell.queue_free()
	WorldFx.fire("secret_found", s.pedestal + Vector3.UP)
	if ctx.get("codex") != null:
		ctx.codex.mark_discovered(wire_id, s.pedestal)
	ctx.events.world_fact.emit(wire_id, s.pedestal)
	ctx.events.world_fact.emit("patch_wire_found", s.pedestal)
	if settle.is_valid():
		settle.call(wire_id)


func _found(s: Site) -> void:
	var f: Dictionary = Secrets.FINDS[String(s.get_meta("find"))]
	var tell: Node = s.wall.get_node_or_null("FindTell")
	if tell != null:
		tell.queue_free()
	WorldFx.fire("secret_found", s.pedestal + Vector3.UP)
	if ctx.get("codex") != null:
		ctx.codex.mark_discovered(String(f["codex"]["id"]), s.pedestal)


func _spawn_bounty(s: Site) -> void:
	var at: Vector3 = ctx.terrain.drop_point(s.global_position.x, s.global_position.z, BRUTE_DROP)
	var brute = ctx.spawner.spawn_enemy(String(s.rule["kind"]), at)
	if brute == null or not brute.has_method("carry_bounty"):
		return
	brute.carry_bounty(s.global_position, EventKinds.activity_color(s.id))
	brute.bounty_wake = float(s.rule["wake"])
	brute.bounty_leash = float(s.rule["leash"])
	brute.bounty_return_speed = float(s.rule["return_speed"])
	brute.died.connect(func(where: Vector3, _scrap: int): _bounty_died(s, where))
	s.brute = brute
	s.started = true


func _bounty_died(s: Site, where: Vector3) -> void:
	if not is_instance_valid(s) or s.done:
		return
	_finish(s, Vector3(where.x, ctx.terrain.height(where.x, where.z), where.z))


func pay_table(s: Site) -> Dictionary:
	var pay: Dictionary = s.rule["pay"]
	if pay.has("named"):
		var named := String(pay["named"])
		if (Parts.rows().has(named) or Parts.is_burden(named)) and ctx.stages.part_in_play(named):
			return {"named": named, "rarities": [Parts.rarity_of(named)]}
	return {"named": "", "rarities": ItemGen.resolve_rarities(pay.get("rarities", ["common"]))}


func stand_odds(s: Site) -> Dictionary:
	var table := pay_table(s)
	var odds: Array = ItemGen.odds(table["rarities"]) if table["named"] != "" \
			else OddsReadout.odds_for(table["rarities"], ctx.run.class_id())
	var result := {"named": table["named"], "rarities": table["rarities"], "odds": odds, "text": OddsReadout.text(odds)}
	if s.rule.has("bundle"):
		var picks: Array = s.reward_parts
		var rung := 0
		var descriptions := []
		var rarity := "common"
		for part in picks:
			var part_rarity := Parts.rarity_of(part)
			if int(ItemGen.RARITY[part_rarity].rung) >= rung:
				rung = int(ItemGen.RARITY[part_rarity].rung)
				rarity = part_rarity
			if not part_rarity in descriptions:
				descriptions.append(part_rarity)
		result["tier"] = picks.size() + rung
		result["parts"] = picks.size()
		result["reward_rarity"] = rarity
		result["reward_text"] = Parts.display_name(String(table.named)) if table.named != "" else "%d %s parts" % [picks.size(), "/".join(descriptions)]
	return result

func _finish(s: Site, at: Vector3) -> void:
	if s.done:
		return
	assert(s.rule.has("pay"), "activities: rule missing pay for '%s'" % s.id)
	s.done = true
	for hazard in s.hazards:
		hazard.stop()
	if s.rule.has("bundle"):
		_heal(s)
		if s.id != "round_arena":
			_cue(s, "clear")
	s.view.finish()
	if s.tier_label != null:
		s.tier_label.visible = false
	if s.cap != null:
		s.cap.visible = false
	if s.id == "round_arena":
		_pay_piece()
		ctx.events.activity_done.emit(s.id, at)
		return
	var table := pay_table(s)
	if table["named"] != "":
		s.pickup_part = table["named"]
		if s.rule.has("bundle"):
			s.pickup_parts = [s.pickup_part]
	else:
		if s.rule.has("bundle"):
			s.pickup_parts = s.reward_parts.duplicate()
			s.pickup_part = String(s.pickup_parts[0]) if not s.pickup_parts.is_empty() else ""
		elif s.yard != null:
			s.pickup_parts = s.reward_parts.duplicate()
			s.pickup_part = String(s.pickup_parts[0]) if not s.pickup_parts.is_empty() else ""
		elif s.relay != null:
			s.pickup_parts = _roll_many(s.id, table["rarities"], s.relay.rewards())
			s.pickup_part = String(s.pickup_parts[0]) if not s.pickup_parts.is_empty() else ""
		elif far_rung(s):
			s.pickup_part = _far_roll(s)
		else:
			s.pickup_part = _roll(_luck_id(s), table["rarities"])
	if s.pickup_part != "":
		s.pickup = ActivityView.gem(String(s.rule.cue.view) if s.rule.has("bundle") or s.yard != null else s.id)
		s.add_child(s.pickup)
		s.pickup.global_position = at
		if far_rung(s):
			WorldFx.fire("secret_found", at + Vector3.UP)
		s.inside_pickup = _planar(ctx.player.ball_position(), at) <= PICKUP_REACH
	else:
		_pay_scrap(s, at)
	_pay_piece()
	ctx.events.activity_done.emit(s.id, at)


func _pay_piece() -> void:
	if _piece_paid:
		return
	var id := Companion.next_drop(ctx.run.companion)
	if id == "":
		return
	ctx.run.companion = Companion.with_piece(ctx.run.companion, id)
	_piece_paid = true


func _pay_scrap(s: Site, at: Vector3) -> void:
	var amount := int(s.rule["pay"].get("scrap", 0))
	if amount > 0:
		ctx.run.add_scrap(amount, at)
		ctx.run.add_cogs(amount)


func _luck_id(s: Site) -> String:
	if s.has_meta("find"):
		return "%s:%s" % [s.id, s.get_meta("find")]
	if s.has_meta("room"):
		return "%s:%s" % [s.id, s.get_meta("room")]
	if s.has_meta("door"):
		return "%s:timed_door" % s.id
	if s.has_meta("extra"):
		return "%s:%s" % [s.id, s.get_meta("extra")]
	if s.has_meta("sealed"):
		return "%s:%s" % [s.id, s.get_meta("sealed")]
	if s.drawn:
		return "%s:%s" % [s.id, s.interior.id]
	return s.id


func _roll(id: String, rarities: Array) -> String:
	var picks := _roll_many(id, rarities, 1)
	return String(picks[0]) if not picks.is_empty() else ""


func _roll_many(id: String, rarities: Array, count: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = Interact.luck_seed(ctx.rng.seed, ctx.run.run_id, ctx.run.stage, id)
	return Parts.roll(rng, rarities, ctx.run.class_id(), ctx.run.parts, count)


func _watch_pickup(s: Site, ball: Vector3) -> void:
	if s.pickup == null or s.pickup_taken:
		return
	var at: Vector3 = s.pickup.global_position
	var now := _planar(ball, at) <= PICKUP_REACH and absf(ball.y - at.y) < PICKUP_HEIGHT
	if now and not s.inside_pickup:
		s.pickup_taken = true
		s.pickup.queue_free()
		s.pickup = null
		if s.rule.has("bundle") or not s.pickup_parts.is_empty():
			for part in s.pickup_parts:
				ctx.run.add_part(part, String(s.rule.pay.source))
		else:
			ctx.run.add_part(s.pickup_part, String(s.rule["pay"]["source"]))
		_pay_scrap(s, at)
		if s.rule.has("bundle"):
			_cue(s, "pay")
		return
	s.inside_pickup = now


const FAR_RUNG := ["rare"]


func far_rung(s: Site) -> bool:
	if s.id != "cracked_cache" or s.drawn or s.has_meta("find") or s.has_meta("room") or s.has_meta("door"):
		return false
	var table := pay_table(s)
	return table["named"] == "" and table["rarities"] == FAR_RUNG


static func far_pool(class_id: String, held: Array) -> Array:
	var weapons: Array = Parts.offer_pool(class_id, FAR_RUNG).filter(func(key) -> bool:
		var r: Dictionary = Parts.rows().get(key, {})
		return String(r.get("family", "")) == "weapon" and String(r.get("rarity", "")) == FAR_RUNG[0] and not Parts.maxed(key, held))
	weapons.sort()
	var kit: Array = weapons.filter(func(key) -> bool: return Parts.in_kit(class_id, key))
	return kit if not kit.is_empty() else weapons


func _far_roll(s: Site) -> String:
	return _far_pick(s, far_pool(ctx.run.class_id(), ctx.run.parts))


func _far_pick(s: Site, pool: Array) -> String:
	var stream := s.row_id if s.row_id != "" else _luck_id(s)
	if pool.is_empty():
		return _roll(stream, FAR_RUNG)
	var rng := RandomNumberGenerator.new()
	rng.seed = Interact.luck_seed(ctx.rng.seed, ctx.run.run_id, ctx.run.stage, stream)
	return String(pool[rng.randi_range(0, pool.size() - 1)])


const WARD_POST := Vector3(0.9, 2.4, 0.9)
const WARD_MODEL := "res://assets/models/world_one/mend_ward_post.glb"
const WARD_RING_H := 0.08
const PLATE_RADIUS := 1.1
const PLATE_H := 0.1
const PLATE_FACE_RADIUS := 0.78
const PLATE_FACE_RAISE := 0.06
const PLATE_GLOW := 0.6


func _build_wards_and_plates(map) -> void:
	for spec in Secrets.ward_sites(map.park):
		wards.append(_build_ward(spec))
	for spec in Secrets.plate_sites(map.park):
		plates.append(_build_plate(spec))


func _build_ward(spec: Dictionary) -> MendWard:
	var w := MendWard.new()
	w.name = "Ward_" + String(spec["id"])
	w.ward_id = String(spec["id"])
	add_child(w)
	var at: Vector2 = spec["at"]
	w.global_position = ctx.terrain.drop_point(at.x, at.y, 0.0)
	var ward_view := ModelKit.whole(WARD_MODEL, w)
	if ward_view == null:
		var post := MeshInstance3D.new()
		post.mesh = PropMeshes.mend_ward_monolith(WARD_POST)
		post.material_override = PropMeshes.weathered_material(Palette.VERDIGRIS.lerp(Palette.SLATE, 0.45), 0.72, 0.28, 0.0, "ward_post")
		post.position = Vector3.UP * WARD_POST.y * 0.5
		w.add_child(post)
	else:
		PropMeshes.weather_node_materials(ward_view, 2.8)
	var ring := MeshInstance3D.new()
	ring.mesh = PropMeshes.mend_ward_ring(MendWard.RING_M, WARD_RING_H)
	ring.material_override = PropMeshes.weathered_material(Palette.CHARCOAL, 0.74, 0.28, 0.0, "ward_ring")
	ring.position = Vector3.UP * WARD_RING_H * 0.5
	w.add_child(ring)
	w.fill = MeshInstance3D.new()
	w.fill.mesh = PropMeshes.mend_ward_fill(MendWard.RING_M, WARD_RING_H)
	w.fill.material_override = PropMeshes.weathered_material(Palette.OLD_VERDIGRIS, 0.56, 0.24, 0.75, "ward_fill")
	w.fill.position = Vector3.UP * WARD_RING_H * 1.5
	w.fill.scale = Vector3(0.001, 1.0, 0.001)
	w.add_child(w.fill)
	_range_tree(w, PROP_VIEW_END_M)
	return w


func _build_plate(spec: Dictionary) -> LorePlate:
	var p := LorePlate.new()
	p.name = "Plate_" + String(spec["fragment"])
	p.note = String(spec["note"])
	p.at = spec["at"]
	add_child(p)
	p.global_position = Vector3(p.at.x, ctx.terrain.height(p.at.x, p.at.y), p.at.y)
	p.visible = false
	var rim := MeshInstance3D.new()
	rim.mesh = PropMeshes.lore_plate_rim(PLATE_RADIUS, PLATE_H)
	rim.material_override = PropMeshes.weathered_material(Palette.CHARCOAL, 0.72, 0.35, 0.0, "plate_rim")
	rim.position = Vector3.UP * PLATE_H * 0.5
	p.add_child(rim)
	p.face = MeshInstance3D.new()
	p.face.mesh = PropMeshes.lore_plate_face(PLATE_FACE_RADIUS, PLATE_H)
	p.add_child(p.face)
	p.read = ctx.get("codex") != null and ctx.codex.known(p.note)
	_show_plate(p)
	_seat_plate(p)
	_range_tree(p, PROP_VIEW_END_M)
	return p


func _seat_plate(p: LorePlate) -> void:
	var seat: Dictionary = ctx.terrain.top_surface(p.at.x, p.at.y, PLATE_RADIUS * 1.08)
	if seat.is_empty():
		return
	p.seated = true
	p.reseat = false
	p.visible = true
	p.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, seat.normal)), seat.point)


func _on_surface_changed() -> void:
	for p in plates:
		if is_instance_valid(p):
			p.reseat = true


func _show_plate(p: LorePlate) -> void:
	if p.read:
		p.face.material_override = PropMeshes.weathered_material(Palette.COPPER, 0.62, 0.48, 0.0, "plate_read")
		p.face.position = Vector3.UP * (PLATE_H * 0.5 + 0.005)
		return
	if not _parts.has("plate_glow"):
		_parts["plate_glow"] = PropMeshes.weathered_material(Palette.AMBER, 0.56, 0.34, PLATE_GLOW, "plate_glow")
	p.face.material_override = _parts["plate_glow"]
	p.face.position = Vector3.UP * (PLATE_H * 0.5 + PLATE_FACE_RAISE)


func _watch_ward(w: MendWard, delta: float, ball: Vector3) -> void:
	if not is_instance_valid(w):
		return
	var inside := _planar(ball, w.global_position) <= MendWard.RING_M and absf(ball.y - w.global_position.y) < PICKUP_HEIGHT
	match w.step(delta, inside):
		"wake":
			_raise_guard(w, ball)
			_ward_cue("event_announced")
		"mend":
			ctx.run.heal(ctx.run.max_hp * MendWard.HEAL_SHARE)
			_ward_cue("event_ended")
	var s := maxf(w.share(), 0.001)
	w.fill.scale = Vector3(s, 1.0, s)


func _raise_guard(w: MendWard, ball: Vector3) -> void:
	if ctx.calm or ctx.spawner == null:
		return
	var entry: Vector3 = ball - w.global_position
	var first := atan2(entry.z, entry.x) + PI
	for i in MendWard.PACK.size():
		var a := first + TAU * float(i) / MendWard.PACK.size()
		var spot := w.global_position + Vector3(cos(a), 0.0, sin(a)) * MendWard.GUARD_M
		var enemy = ctx.spawner.spawn_enemy(String(MendWard.PACK[i]), ctx.terrain.drop_point(spot.x, spot.z, SPAWN_CLEARANCE))
		if enemy != null:
			w.guard.append(enemy)


func _ward_cue(kind: String) -> void:
	var presentation: Node = ctx.root.get_node_or_null("Presentation")
	if presentation != null:
		presentation.audio.play(kind)


func _watch_plate(p: LorePlate, ball: Vector3) -> void:
	if not is_instance_valid(p):
		return
	if not p.seated or p.reseat:
		_seat_plate(p)
	if p.read or not p.seated:
		return
	var offset := ball - p.global_position
	var up := p.global_basis.y.normalized()
	var rise := offset.dot(up)
	if (offset - up * rise).length() > LorePlate.REACH_M or rise < -LorePlate.BELOW_M or rise > LorePlate.HEIGHT_M:
		return
	read_plate(p)


func read_plate(p: LorePlate) -> bool:
	if not p.touch():
		return false
	_show_plate(p)
	var codex = ctx.get("codex")
	if codex == null or not codex.file_note(p.note):
		return false
	var presentation: Node = ctx.root.get_node_or_null("Presentation")
	if presentation != null:
		presentation.audio.play("interaction_found", 0.0, 1.0, "SFX", "lore_found")
	return true
