extends RefCounted

const Intent := preload("res://src/movement/intent.gd")
const EventDirector := preload("res://src/world/event_director.gd")
const TelegraphScript := preload("res://src/combat/telegraph.gd")
const Palette := preload("res://src/core/palette.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const Weapons := preload("res://src/combat/weapons.gd")
const Pattern := preload("res://src/combat/pattern.gd")
const WeaponDriver := preload("res://src/combat/weapon_driver.gd")
const Augments := preload("res://src/movement/augments.gd")
const Grip := preload("res://src/movement/grip.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const SkillBand := preload("res://tools/skill_band.gd")
const BossRules := preload("res://src/boss/boss_rules.gd")
const Requisition := preload("res://src/boss/requisition.gd")
const BotKite := preload("res://tools/bot_kite.gd")
const BotFairness := preload("res://tools/bot_fairness.gd")
const BotLoops := preload("res://tools/bot_loops.gd")


const POLICIES := ["skipper", "completionist", "random", "camper", "traversal", "orbit", "terrain"]
const GATE_HUNT := 140.0
const PROFILES := {"brawler": "completionist", "camper": "camper", "skipper": "skipper"}
const CAMP_RANGE := 30.0
const CAMP_NEAR := 12.0
const TRAVERSE_REACTION := 0.15
const TRAVERSE_PRESS_GAP := 0.4
const TRAVERSE_REACHED := 12.0
const HAND_NAMES := ["harpoon", "glide"]
const SWING_ABOVE := 6.0
const SWING_AHEAD := 0.5
const SWING_MIN_SPEED := 6.0
const SWING_YAWS := [0.0, 0.35, -0.35, 0.7, -0.7]
const SWING_PITCHES := [0.3, 0.55, 0.8]
const SWING_CARRY := 3.0
const SWING_GRACE := 0.8
const SWING_HOLD_MAX := 5.0
const SWING_GAP := 1.5
const SWING_SENT := 0.4
const GLIDE_DROP := 10.0
const GLIDE_GAIN := 2.0
const GLIDE_ABOVE := 6.0
const GLIDE_NEAR := 40.0
const TURN_RATE := 5.0
const SENSITIVITY := 0.0022
const STAGE_LIMIT := 240.0
const PARK_MIND_LIMIT := 480.0
const GATE_LIMIT := 90.0
const BOSS_LIMIT := 420.0
const STUCK_SPEED := 2.5
const STUCK_SECONDS := 2.0
const DETOUR_SECONDS := 1.4
const WALL_REACH := 4.0
const WALL_TILT := 0.5
const WALL_TURNS := [0.0, 0.5, -0.5, 1.0, -1.0, 1.5, -1.5]
const WALL_SIDE_KEEP_DEG := 45.0
const BOOST_GAP := 1.6
const CARD_PRESS_GAP := 0.5
const SHIFT_HOLD := 1.2
const CHARGE_CLOSE := 3.8
const HARPOON_FLOOR := 30.0
const LINE_REACH := 50.0
const DROP_MEMORY := 6.0
const PASS_BITE_GAP_S := 0.25
const LATCH_REACH := 40.0
const HUNG_ABOVE := 5.0
const ANCHOR_MOVING := 2.0
const LATCH_STANDOFF := 1.6
const LATCH_STANDOFF_MAX := 30.0
const DROP_ABOVE := 0.0
const DROP_WAIT := 0.6
const DROP_JUMP_REACH := 8.0
const DROP_REACH_UP := 6.0
const LINE_FINISH := 80.0
const LINE_FINISH_STANDOFF := 12.0
const RUNUP := 24.0
const RUNUP_SECONDS := 3.2
const RUNUP_EDGE := 6.0
const RUNUP_DROP := 2.0
const RUNUP_STEP := 2.0
const RUNUP_MIN := 8.0
const SHEET_HAND_REACH := 60.0
const SHEET_LAUNCH_LINED := 0.97
const SHEET_HOLD_FIRE := 90.0
const CHARGE_WINDOW := 6.0
const CHARGE_PROGRESS := 2.0
const RECOVER_BACK := 8.0
const RECOVER_SIDE := 14.0
const RECOVER_REACHED := 3.0
const RECOVER_LEG_SECONDS := 3.0
const RECOVER_LIMIT := 3
const RECOVER_PROBE := 10.0
const RECOVER_BACK_MAX := 12.0
const RECOVER_JUMP_AT := 3.0
const RECOVER_OVER := 6.0
const AIM_REACH := 40.0
const WAYPOINT_REACHED := 9.0
const WAYPOINT_SECONDS := 14.0
const GATE_HOP_SECONDS := 6.0
const GATE_HOP_EVERY := 1.5
const GATE_PROBE := 9.0
const GATE_PROBE_NEAR := 30.0
const GATE_TURN := 30.0
const GATE_MARGIN := 4.0
const GATE_RUNUP_AFTER := 14.0
const GATE_RUNUP_BACK := 70.0
const GATE_RUNUP_SECONDS := 12.0
const GATE_CHARGE_SECONDS := 10.0
const GATE_DETOUR_SECONDS := 6.0
const GATE_SWITCH_FALLS := 2
const GATE_SWITCH_SECONDS := 40.0
const GATE_CALM_RANGE := 25.0
const GATE_CALM_SPEED := 12.0
const GATE_LINE_SIDE := 6.0
const GATE_LINE_BACK := 14.0
const GATE_LINE_NEAR := 2.0
const GATE_LINE_LEAD := 6.0
const VAULT_SECONDS := 45.0
const EVENT_PURSUIT_SECONDS := 40.0
const EVENT_LATEST := 150.0
const WANDER_GAP := Vector2(3.0, 6.0)
const WANDER_SPREAD := 1.0
const WANDER_COMMIT_DISTANCE := 45.0
const WANDER_COMMIT_TIME := 45.0
const REACTION := 0.25
const CONTACT_RADIUS := 30.0
const CONTACT_WINDOW_S := 120.0
const PREDICT := 0.35
const FIELD_RADIUS := 20.0
const ESCAPE_DIRECTIONS := 16
const ESCAPE_REACH := [5.0, 9.0, 13.0, 18.0]
const CAP_JUMP := 4.6
const CAP_INSIDE := 3.3
const CAP_BESIDE := 3.8
const PULSE_HP_SHARE := 0.45
const PUNCH_FADE := 4.0
const KNOCK_S := 1.5
const RING_OUT_PAST := 6.0
const PLANT_SEARCH := 22.0
const PLANT_RANGE := 45.0
const PLANT_REACH := 2.6
const PLANT_TIMEOUT := 5.0
const PLANT_EVERY := 10.0
const TURRET_SECONDS := 3.5
const FACE_TILT := 0.866
const SLING_STEP := 0.05
const SLING_FLIGHT := 4.0
const MIND_STAGE := 5
const MIND_CLIMB_GIVE_UP := 45.0
const CROWD := 2
const CROWD_RADIUS := 12.0
const CLOSE_FIGHT := 14.0
const BOSS_ORBIT := 32.0
const BAIT_RADIUS := 47.0
const CHARGE_MARGIN := 2.0
const CLASH_SPEED := 8.0
const CLASH_MIN_GAP := 5.0
const CLASH_ALIGN := 1.5
const CLASH_ROLL := 12.0
const CLASH_SPARE := 0.3
const RAMP_ANGLES := [0.0, 180.0]
const RAMP_BOTTOM := 46.0
const RAMP_PAST := 18.0
const RAMP_JUMP := 26.0
const RAMP_WINDOW := 0.5
const PICKUP_CHASE := 30.0
const SHED_CHASE := 8.0
const SHED_AHEAD := 0.4
const SHED_ROLLING := 1.0
const CAP_ABOVE := 1.2
const CAP_REACH := 2.6
const ACTIVITY_SECONDS := 40.0
const SURGE_SECONDS := 80.0
const SURGE_LEAD_M := 18.0
const SURGE_GATE_AIM_M := 35.0
const SURGE_RUNUP_M := 14.0
const FIND_SECONDS := 60.0
const CACHE_RUNUP := 24.0
const CACHE_RUNUP_SECONDS := 5.0
const CACHE_RAM_SECONDS := 3.0
const CACHE_STAGE := 45.0
const PAY_BACKOFF := 6.0
const LEVEL_BAND := 8.0
const PLATE_REACH := 30.0
const CAMP_LAST := 1000.0
const FIND_LEG_M := 24.0
const FIND_NEAR_M := 120.0
const FIND_LEG_SECONDS := 10.0
const CLIMB_STEP := 4.0
const CLIMB_PAD := 100.0
const CLIMB_SLOPE := 0.5
const CLIMB_SLOPE_RETRY := [0.6, 0.75]
const SLOPE_SLACK := 0.001
const KICKER_LAUNCH := 8.0
const KICKER_JUMP_AT := 3.0
const CLIMB_REACHED := 6.0
const ROUTE_REACHED := 15.0
const CABLE_CLEAR := 2.0
const FIGHT_CLIMB_REPLAN := 6.0
const CLIMB_LEVEL := 1.5
const ENGAGE_BY := 140.0
const CAST_GAP := 0.1
const LINE_CAST_REACH := 15.0
const ULT_CORE_REACH := 45.0
const ULT_CROWD := 3
const ULT_CROWD_RADIUS := 20.0
const ULT_TRAVERSE_NEAR := 25.0
const ULT_TRAVERSE_FAR := 70.0
const ULT_RETRY := 1.0
const ACTIVE_RANGE := 32.0
const ACTIVE_RETRY := 0.5

var game
var policy := "skipper"
var seed_value := 1
var profile := ""
var route: Array[Vector2] = []
var press_ticks: Array[int] = []
var class_index := 0
var rng := RandomNumberGenerator.new()
var source := Intent.Scripted.new()
var trace := false
var tree_policy := "world_one"
var tree_picks: Array[String] = []
var late_offer_policy := ""
var relay_stake := 0
var loops
var hands_off: Array = []
var engage_by := ENGAGE_BY
const ACTIVITY_NEAR := 40.0
const ACTIVITY_TRAVEL_SECONDS := 60.0
const ACTIVITY_TRAVEL_SPEED := 8.0
var _activity_travel := {}
var _activity_travel_cap := {}
const ACTIVITY_RETRY_MOVE := 150.0
var _activity_deferred := {}
const CLOSING_M := 10.0
const CLOSING_SECONDS := 30.0
var _closing := {}
const RAM_TRIES := 4
var _ram_tries := {}
const RELAY_ARM_SECONDS := 150.0
var _relay_clock := 0.0
var _relay_closed := {}
var late_offer_counts := {"offered": 0, "taken": 0, "declined": 0}
var _tree_rng := RandomNumberGenerator.new()

var stage_limit := STAGE_LIMIT
var fight_limit := 0.0

var outcome := ""
var ticks := 0
var stage_notes: Array[Dictionary] = []
var boss_note := {}

var _offers: Array = []
var _gate_pick := -1
var _gate_time := 0.0
var _gate_hop := 0.0
var _gate_detour := Vector3.ZERO
var _gate_detour_left := 0.0
var _gate_run := ""
var _gate_run_clock := 0.0
var _gate_on_top := false
var _island_gates := false
var _gate_falls := 0
var _stage := 0
var _fight_phase := "charge"
var _fight_target: Node3D = null
var _runup_point := Vector3.ZERO
var _runup_time := 0.0
var _charge_best := INF
var _charge_clock := 0.0
var _recoveries := 0
var _recover_legs: Array[Vector3] = []
var _recover_time := 0.0
var _recover_wall := false
var _recover_climb := false
var _slow_time := 0.0
var _detour_time := 0.0
var _detour := Vector3.ZERO
var _wall_side := 0.0
var _wall_dir := Vector3.ZERO
var _boost_clock := 0.0
var _card_press_tick := -1000000
var _shift_left := 0.0
var _waypoints: Array[Vector3] = []
var _find_route: Array[Vector3] = []
var _find_route_for := ""
var _find_exit := Vector3.INF
var _find_leg_clock := 0.0
var _waypoint_time := 0.0
var _vault_time := 0.0
var _vault_done := false
var _event_time := {}
var _event_skip := {}
var _wander_clock := 0.0
var _wander_heading := Vector3.FORWARD
var _committed := false
var _planned := false
var _note := {}
var _goal := ""
var _camp_backing := false
var _activity := ""
var _caches_seen := {}
var _rib_spot := {}
var _rogue_seen: Node3D = null
var _rogue_id := 0
var _rogue_clock := 0.0
var _rib_clock := {}
var _activity_time := {}
var _activity_skip := {}
var _cache_phase := "runup"
var _cache_clock := 0.0
var _climb: Array[Vector3] = []
var _climb_for := ""
var _route: Array[Vector3] = []
var _fight_climb: Array[Vector3] = []
var _fight_climb_clock := 0.0
var _fight_climb_held := 0.0
var _fight_climb_tick := -1
var _mind_slope_spent := false
var _route_lips: Array[Vector3] = []
var _plate_hand := {}
var _ignore_walls := false
var _seen := {}
var band = null
var _min_hp := INF
var _evaded := {}
var _read := {}
var _charge_read := {}
var _charge_stepped := {}
var _clash_tried := {}
var _clash_latched := {}
var _welcome_ring_at := Vector3.INF
var _plant_state := "idle"
var _plant_clock := 0.0
var _plant_cool := 0.0
var _plant_face := Vector3.ZERO
var _plant_target: Node3D = null
var _boss_clock := 0.0
var _hull_seen := -1.0
const FIRST_45_S := 45.0
var _sheet_live_s := -1.0
var _punch_seen := 0.0
var _knock_until := -1
var _rings := BrindleRings.new()
var _ring_fight = null
var _warden_hp_at := -1.0
var _warden_kinds := {}
var _harpoon_held := false
var _line_hold_off := 0.0
var _pass_bite_frame := -100000
var _weak_seen := ""
var _weak_age := 0.0
var _weak_roll := 0.0
var _weak_go := false
var _weak_warden: Node3D = null
var _harpoon_commit := false
var kite
var _cruise_hold := false
var hide_pack_telegraphs := false
var _fair := BotFairness.new()
var chain_hand_enabled := true
var _chain_phase := ""
var _chain_first: Node3D = null
var _chain_second: Node3D = null
var _chain_rose := false
var _chain_launch_y := 0.0
var _chain_driving := false
var _anchor_target: Node3D = null
var _anchor_last_y := INF
var _anchor_vy := 0.0
var _anchor_lined := false
var _anchor_below := 0.0
var _haul_made := false
var _haul_above := false
var _haul_pressed_above := false
var _haul_chunks := -1
var _drop_jumped := false
var _anchor_chunks_seen := -1
var _anchor_seen_hung := false
var _off_line := 0.0
var _out: Array[Dictionary] = []
var _defer_look := false
var _look_delta := Vector2.ZERO
var _leg := 0
var _last_press_tick := -1000000
var _cast_slot := 0
var _cast_hold := 0.0
var _cast_phase := ""
var _cast_click_tick := -1
var _ult_wait := 0.0
var _active_wait := 0.0
var _sheet_hold_fire := false
var _cadence_index := 0
var _cadence_reload_rolled := false
var _cadence_reload_hit := false
var _cadence_reload_pressed := false
var _cadence_window_rolled := false
var _cadence_window_hit := false
var _cadence_window_pressed := false
var _cadence_lock_late := false
var _cadence_lob_reach_m := 0.0
var _cadence_lob_flight_s := 0.0
var _traverse_point := Vector3.INF
var hands: Array[String] = []
var _glide_held := false
var _hand_aim := false
var _gliding := false
var _swing_clock := 0.0
var _swing_cool := 0.0
var _swing_sent := 0.0
var _play_clock := 0.0
var _fill_from := 0.0
var _fills: Array[float] = []
var _fill_open := true
var _totals := {"slot_casts_special": 0, "slot_casts_line": 0, "ultimates": 0, "ult_presses": 0, "shots": 0,
	"cadence_windows": 0, "cadence_hits": 0, "active_presses": 0}
var _first_fill_sources := {}


static func class_index_for(seed_number: int, pilot := "") -> int:
	var roster: Array = ClassDef.all()
	if pilot == "":
		return seed_number % roster.size()
	for i in roster.size():
		if roster[i].id == pilot:
			return i
	return -1


func _init(game_ref, policy_name: String, seed_number: int) -> void:
	game = game_ref
	game.bot_driven = true
	profile = policy_name if policy_name in PROFILES else ""
	var named: String = PROFILES.get(policy_name, policy_name)
	policy = named if named in POLICIES else "skipper"
	seed_value = seed_number
	class_index = class_index_for(seed_number)
	rng.seed = hash([policy, seed_number])
	_tree_rng.seed = hash(["tree", seed_number])


func start(resume := false) -> void:
	wire(not resume)
	if resume and game.flow.resume_run():
		if game.player != null and game.player.tree != null:
			tree_picks.assign(game.player.tree.path())
		_wire_tree()
		return
	if resume:
		_wire_tree()
	game.flow.press_start()
	game.flow.choose_class(class_index)


func wire(connect_tree := true) -> void:
	game.ctx.rng.seed = 20260926 + seed_value * 7919
	game.player.source = source
	var events = game.events
	if policy == "completionist":
		events.line_state_changed.connect(_on_explorer_line)
	events.stage_entered.connect(_on_stage_entered)
	events.stage_cleared.connect(func(_s: int): _close_note())
	events.reward_offered.connect(_on_offers)
	events.reward_chosen.connect(func(_id: String): _offers = [])
	events.player_died.connect(func(): _end("died"))
	events.run_ended.connect(func(won: bool): _end("won" if won else "lost"))
	events.warden_engaged.connect(func(_s: int):
		_note_set("warden_engaged_s", snappedf(game.run.stage_time, 0.01))
		_punch_seen = float(game.flow.punch_now()))
	events.beacon_unsealed.connect(func(_s: int):
		_note_set("warden_broken_s", snappedf(game.run.stage_time, 0.01))
		if _haul_made:
			_count("latch_chunks")
			_note_set("latch_break", true)
			if _haul_above:
				_count("drop_chunks")
				_note_set("drop_break", true)
			_haul_made = false
		if _warden_hp_at >= 0.0:
			_settle_warden_damage(0.0))
	events.event_started.connect(func(id: String):
		if id in EventDirector.PARTICIPATORY:
			_note_add("events_joined", id))
	events.core_gained.connect(func(source_id: String, _at: Vector3, _n: int): _note_add("cores", source_id))
	events.part_gained.connect(func(id: String, source_id: String): _note_add("parts", "%s:%s" % [source_id, id]))
	events.player_hit.connect(_on_player_hit)
	_fair.setup(game, Callable(self, "boss_hazards"))
	events.enemy_struck.connect(_on_enemy_struck)
	events.special_used.connect(func(_id: String, _at: Vector3): _count("specials"))
	events.shot_fired.connect(func(_weapon: String, _from: Vector3, _to: Vector3):
		_totals["shots"] = int(_totals["shots"]) + 1
		var kit = game.player.kit
		if kit.hooked and kit.on_body and _anchor_warden(kit.anchor_body):
			_count("latch_shots"))
	_connect_optional("slot_cast", func(slot: String, _id: String, _at: Vector3): _on_slot_cast(slot))
	_connect_optional("ultimate_started", func(_id: String, _path: String, _from: Vector3, _to: Vector3, _s: float): _on_ultimate_started())
	_connect_optional("ultimate_ready", func(_id: String): _on_ultimate_ready())
	events.world_fact.connect(func(fact: String, _at: Vector3):
		if fact == "thermal_ride" and game.flow.in_stage():
			_count("thermal_rides")
		if kite != null and game.flow.in_stage():
			kite.on_ride_fact(fact))
	events.slammed.connect(func(at: Vector3, _strength: float, _flatness: float):
		if not _plate_hand.is_empty() and game.flow.in_stage() and _plate_contains(_plate_hand, at):
			_count("plate_slams"))
	events.mounted.connect(func(_at: Vector3, _banked: float): _count("plants"))
	events.dismounted.connect(func(v: Vector3):
		if v.length() > 0.5:
			_count("slingshots"))
	_connect_optional("boss_arena_entered", func(): _on_boss_entered())
	_connect_optional("boss_phase_changed", func(phase: int, phase_name: String): _on_boss_phase(phase, phase_name))
	_connect_optional("boss_weak_point_hit", func(point_id: String):
		if not boss_note.is_empty():
			var hits: Dictionary = boss_note["weak_point_hits"]
			hits[point_id] = int(hits.get(point_id, 0)) + 1)
	_connect_optional("boss_defeated", func():
		_boss_set("defeated_s", snappedf(_boss_clock, 0.01))
		_boss_hold_note())
	events.scrap_lost.connect(func(amount: int, _at: Vector3, _total: int, cause: String):
		_fair.loss(cause, float(amount))
		if cause == "crane":
			_boss_set("stolen", int(boss_note.get("stolen", 0)) + amount))
	if late_offer_policy != "":
		game.player.tree.late_offer = true
	if connect_tree:
		_wire_tree()


func _wire_tree() -> void:
	if tree_policy == "random":
		_connect_optional("tree_offered", _on_tree_offered)
		_answer_pending_tree()
	elif tree_policy == "world_one" and policy != "traversal":
		_connect_optional("tree_offered", _on_world_one_tree_offered)
		_answer_pending_tree()


func _on_world_one_tree_offered(for_class: String, depth: int, choices: Array) -> void:
	if game.player != null and game.player.tree != null and game.player.tree.world_one:
		_on_tree_offered(for_class, depth, choices)


func _on_tree_offered(_class_id: String, depth: int, choices: Array) -> void:
	if choices.is_empty():
		return
	var tree = game.player.tree
	if late_offer_policy != "" and tree.offer_kind(depth) == tree.OFFER_TAKE_OR_SKIP:
		late_offer_counts["offered"] += 1
		if late_offer_policy == "skip":
			if tree.skip():
				late_offer_counts["declined"] += 1
			return
		if tree.pick(String(choices[0])):
			tree_picks.append(String(choices[0]))
			late_offer_counts["taken"] += 1
		return
	var choice := ""
	if tree.world_one and depth == 1 and choices.size() == 2:
		var roster_n := maxi(ClassDef.all().size(), 1)
		choice = String(choices[posmod(seed_value + floori(float(seed_value) / float(roster_n)), choices.size())])
	else:
		choice = String(choices[_tree_rng.randi() % choices.size()])
	if tree.pick(choice):
		tree_picks.append(choice)


func _answer_pending_tree() -> void:
	if tree_policy not in ["random", "world_one"] or (tree_policy == "world_one" and policy == "traversal"):
		return
	var player = game.get("player") if game != null else null
	var tree = player.get("tree") if player != null else null
	if tree == null or not tree.pending():
		return
	if tree_policy == "world_one" and not tree.world_one:
		return
	var guard := 0
	while tree.pending() and guard < 8:
		guard += 1
		var depth: int = tree.picks.size() + 1
		var offered: Array = tree.offered(tree.class_id, depth)
		if offered.is_empty():
			break
		var ids: Array = offered.map(func(n): return String(n["id"]))
		var before: int = tree.picks.size()
		_on_tree_offered(tree.class_id, depth, ids)
		if tree.picks.size() == before:
			break


func _connect_optional(signal_name: String, handler: Callable) -> void:
	if game.events.has_signal(signal_name):
		game.events.connect(signal_name, handler)


func class_id() -> String:
	return game.run.class_id()


func _engineer() -> bool:
	return class_id() == "pylon_engineer"


func _throw_hold(aim) -> bool:
	var gauge = game.player.abilities.gauge(AbilityState.WEAPON)
	if gauge == null or not gauge.charging or not _aim_valid(aim):
		return true
	var reach: float = _flat(game.player.ball_position(), _aim_point(aim))
	var combat = game.get("combat")
	var snap: Dictionary = combat.weapon_driver.state_snapshot() if combat != null and combat.get("weapon_driver") != null else {}
	if String(snap.get("trigger", "")) == Pattern.TRIGGER_LOB_SNAP:
		if reach <= 3.5:
			_cadence_lob_reach_m = 0.0
			_cadence_lob_flight_s = 0.0
			return false
		var tail_frac := Weapons.STICKY_TAIL_HOLD_S / Weapons.STICKY_CHARGE_MAX
		var want_lob := clampf(reach / float(Weapons.BASE[Weapons.STICKY_CHARGE]["range_m"]), tail_frac + 0.02, 1.0)
		_cadence_lob_reach_m = reach
		_cadence_lob_flight_s = clampf(reach / 22.0, 0.35, 1.1)
		return gauge.fraction() < want_lob
	var want := clampf((reach - Weapons.STICKY_THROW_MIN) / (Weapons.BASE[Weapons.STICKY_CHARGE]["range_m"] - Weapons.STICKY_THROW_MIN), 0.0, 1.0)
	return gauge.fraction() < want


func tick(delta: float) -> bool:
	if outcome != "":
		return true
	ticks += 1
	_hull_seen = float(game.run.hp)
	var flow = game.flow
	var state: String = flow.state_name()
	match state:
		"dead":
			_end("died")
			return true
		"summary":
			_end("won" if flow.run_won else "lost")
			return true
		"victory":
			source.hold = {}
			return false
		"boss":
			if _boss() == null:
				_end("boss")
				return true
	if not flow.in_play():
		source.hold = {}
		return false
	if tree_policy in ["random", "world_one"] and game.player != null and game.player.tree != null and game.player.tree.pending():
		_answer_pending_tree()
	if policy == "completionist" and state not in ["stage", "beacon"]:
		_clear_chain_hand()
	if flow.in_stage() and game.run.stage_time > _stage_cap():
		_note_set("stall_state", state)
		_end("stalled")
		return true
	var fight_start = fight_start_of(_note)
	if fight_limit > 0.0 and fight_start != null and _note.get("warden_broken_s") == null \
			and game.run.stage_time - float(fight_start) > fight_limit:
		_end("fight_capped")
		return true
	if loops == null and game.ctx.tuning != null and (game.ctx.tuning.sitting() or game.ctx.tuning.sitting_earned()):
		loops = BotLoops.new(self, game)
		for name in hands_off:
			loops.hands[name] = false
	_boost_clock -= delta
	_line_hold_off = maxf(0.0, _line_hold_off - delta)
	_play_clock += delta
	_min_hp = minf(_min_hp, float(game.run.hp))
	_ult_wait -= delta
	_active_wait -= delta
	_harpoon_held = false
	_harpoon_commit = false
	_cruise_hold = false
	_ring_fight = null
	_contact_scan()
	_fair.tick(delta)
	if flow.in_stage():
		_content_scan()
	_plant_cool -= delta
	var punch_now: float = float(flow.punch_now()) if ticks >= _knock_until else 0.0
	_punch_seen = maxf(punch_now, _punch_seen - PUNCH_FADE * delta)
	if trace and ticks % (Engine.physics_ticks_per_second * 2) == 0:
		var b: Vector3 = game.player.ball_position()
		print("  trace t=%.0f stage %d %s goal=%s ball=(%.0f, %.0f, %.0f) speed=%.1f hp=%.0f heft=%.2f punch=%.0f" % [game.run.stage_time,
			game.run.stage, state, _goal, b.x, b.y, b.z, game.player.planar_velocity().length(), game.run.hp, game.run.heft(), flow.punch_now()])
	if trace and is_instance_valid(_anchor_target) and ticks % (Engine.physics_ticks_per_second * 2) == 0:
		print("    anchor y=%.1f vy=%.1f staggered=%s chunks=%d posture=%.0f; line hooked=%s on_body=%s state=%s" % [
			_anchor_target.global_position.y, _anchor_vy, _anchor_target.staggered(), _anchor_target.chunks_left(),
			_anchor_target.posture(), game.player.kit.hooked, game.player.kit.on_body, game.player.kit.line_state])
	if trace and state == "boss" and ticks % (Engine.physics_ticks_per_second * 2) == 0:
		var boss = _boss()
		if boss != null and is_instance_valid(boss.get("arena")) and boss.get("ship") != null:
			var b: Vector3 = game.player.ball_position()
			print("    boss phase %s %s hp %.0f; ball r %.1f above arena ground %.1f, grounded %s, body velocity %s" % [boss.phase,
				boss.state_name(), boss.hp, boss.arena.radius_of(b), b.y - boss.arena.ground(b), game.player.state.grounded,
				game.player.body().linear_velocity])
			print("    posture %.1f stagger %s; hull=%s distance=%.1f; line=%s hooked=%s on_body=%s" % [boss.posture(), boss.staggered(),
				boss.ship.hull.global_position, _flat(b, boss.ship.hull.global_position), game.player.kit.line_state,
				game.player.kit.hooked, game.player.kit.on_body])
	match state:
		"stage", "beacon":
			if loops == null or not loops.stage(delta):
				_roam(delta)
		"gates":
			if loops == null or not loops.gates(delta):
				_to_gate(delta)
		"boss":
			_boss_clock += delta
			if _boss_clock > BOSS_LIMIT:
				_end("boss_stalled")
				return true
			_fight_boss(delta)
		"lap":
			_lap_roll()
		_:
			source.hold = {}
	if loops != null:
		loops.step(delta)
	_set_piece_hands()
	return outcome != ""


func _lap_roll() -> void:
	var lap = game.flow.lap
	if not is_instance_valid(lap):
		source.hold = {}
		return
	var to: Vector3 = lap.centre() - game.player.ball_position()
	var wish := Vector3(to.x, 0.0, to.z).normalized() if Vector2(to.x, to.z).length() > 1.0 else Vector3.BACK
	source.hold = {"move": _world_to_stick(wish), "shift_held": true}


func _stage_cap() -> float:
	if stage_limit != STAGE_LIMIT:
		return stage_limit
	var cap := stage_limit
	if game.run.stage == 6:
		cap = PARK_MIND_LIMIT
	var broken = _note.get("warden_broken_s")
	if broken != null:
		cap = maxf(stage_limit, float(broken) + GATE_LIMIT)
	return cap + maxf(0.0, engage_by - ENGAGE_BY) + _lock_held_s()


func _lock_held_s() -> float:
	var lock_at = _note.get("lock_s")
	var engaged = _note.get("warden_engaged_s")
	if lock_at == null and engaged == null:
		return 0.0
	var gate = game.flow.get("gate")
	if gate == null:
		return 0.0
	var held := 0.0
	if lock_at != null:
		var unlock_at = _note.get("unlock_s")
		var until := float(unlock_at) if unlock_at != null else float(game.run.stage_time)
		held += clampf(until - float(lock_at), 0.0, float(gate.lock_row().get("max_s", 0.0)))
	if engaged != null and gate.has_gate():
		var open_at = _note.get("gate_open_s")
		var until := float(open_at) if open_at != null else float(game.run.stage_time)
		held += clampf(until - float(engaged), 0.0, float(gate.gate_row().get("max_s", 0.0)))
	return held


static func fight_start_of(note: Dictionary):
	var turned = note.get("warden_fight_s")
	var engaged = note.get("warden_engaged_s")
	if turned == null:
		return engaged
	if engaged == null:
		return turned
	return maxf(float(turned), float(engaged))


func warden_broken() -> bool:
	return _note.get("warden_broken_s") != null


func _end(why: String) -> void:
	if outcome != "":
		return
	outcome = why
	_close_note()
	if not boss_note.is_empty():
		if why == "died" and not boss_note.has("outcome"):
			boss_note["died_s"] = snappedf(_boss_clock, 0.01)
		boss_note["outcome"] = why
		boss_note["seconds"] = snappedf(_boss_clock, 0.01)
		_boss_hold_note()
		var boss = _boss()
		if boss != null:
			boss_note["phase_reached"] = boss.get("phase")
			boss_note["wall_stuns"] = boss.get("stuns")
			boss_note["clashes"] = boss.get("clashes")
	source.hold = {}


func _on_stage_entered(stage: int, _retry: bool) -> void:
	_plate_hand = {}
	_clear_chain_hand()
	_active_wait = 0.0
	_sheet_hold_fire = false
	_cadence_reload_rolled = false
	_cadence_reload_hit = false
	_cadence_reload_pressed = false
	_cadence_window_rolled = false
	_cadence_window_hit = false
	_cadence_window_pressed = false
	_cadence_lock_late = false
	_cadence_lob_reach_m = 0.0
	_cadence_lob_flight_s = 0.0
	_close_note()
	_window_hits = []
	_stage = stage
	_offers = []
	_gate_pick = -1
	_fight_phase = "charge"
	_fight_target = null
	_reset_charge_watch()
	_recoveries = 0
	_slow_time = 0.0
	_detour_time = 0.0
	_wall_side = 0.0
	_waypoints = []
	_find_route = []
	_find_route_for = ""
	_find_exit = Vector3.INF
	_waypoint_time = 0.0
	_vault_time = 0.0
	_vault_done = false
	_event_time = {}
	_event_skip = {}
	_activity = ""
	_activity_time = {}
	_activity_travel = {}
	_activity_travel_cap = {}
	_activity_deferred = {}
	_activity_skip = {}
	_closing = {}
	_ram_tries = {}
	_relay_clock = 0.0
	_relay_closed = {}
	_caches_seen = {}
	_rib_spot = {}
	_rogue_seen = null
	_rogue_id = 0
	_rogue_clock = 0.0
	_rib_clock = {}
	_rogue_done = false
	_rogue_travel = 0.0
	_rogue_travel_cap = -1.0
	_rib_skip = {}
	_rib_travel_cap = {}
	_leg_route = []
	_leg_for = ""
	_cache_phase = "runup"
	_cache_clock = 0.0
	_climb = []
	_route_lips.clear()
	_climb_for = ""
	_route.clear()
	_fight_climb = []
	_fight_climb_clock = 0.0
	_fight_climb_held = 0.0
	_fight_climb_tick = -1
	_mind_slope_spent = false
	_wander_clock = 0.0
	_committed = policy == "skipper"
	_planned = false
	_seen = {}
	_evaded = {}
	_plant_state = "idle"
	_plant_cool = 0.0
	_warden_hp_at = -1.0
	_warden_kinds = {}
	_note = {"stage": stage, "warden_engaged_s": null, "warden_fight_s": null, "warden_broken_s": null, "exit_s": null, "events_joined": [],
		"cores": [], "parts": [], "vault_tried": false, "pockets_drawn": null, "waypoints": 0, "stuck_detours": 0, "hp_lost": 0.0, "hits": 0,
		"max_hp": game.run.max_hp, "evasions": 0, "cap_hits": 0, "magnet_stuns": 0, "plants": 0, "slingshots": 0,
		"specials": 0, "punch_short_s": 0.0, "plate_slams": 0, "thermal_rides": 0,
		"first_contact_s": null, "first_hit_s": null, "hull_lost_120s": 0.0, "alive_120s": null, "fight_s": 0.0, "circle_s": 0.0,
		"circle_share": null, "line_rides": 0, "lines_in_reach": null, "line_misses": 0, "telegraph_reads": 0,
		"rogue_woke_s": null, "rogue_beaten_s": null, "rogues_beaten": 0, "rib_caches_placed": 0, "rib_caches_taken": 0}


func _note_set(key: String, value) -> void:
	if not _note.is_empty():
		_note[key] = value


func _note_add(key: String, value) -> void:
	if not _note.is_empty():
		(_note[key] as Array).append(value)


func _count(key: String, by: float = 1.0) -> void:
	var into: Dictionary = boss_note if _in_boss() else _note
	if into.is_empty():
		return
	into[key] = into.get(key, 0) + by


func _on_slot_cast(slot: String) -> void:
	var key := "slot_casts_special" if slot == AbilityState.SPECIAL else "slot_casts_line" if slot == AbilityState.LINE else ""
	if key == "":
		return
	_totals[key] = int(_totals[key]) + 1
	_count(key)


func _on_ultimate_started() -> void:
	_totals["ultimates"] = int(_totals["ultimates"]) + 1
	_count("ultimates")
	_fill_from = _play_clock
	_fill_open = true


func _on_ultimate_ready() -> void:
	if not _fill_open:
		return
	_fill_open = false
	_fills.append(snappedf(_play_clock - _fill_from, 0.01))
	if _first_fill_sources.is_empty():
		_first_fill_sources = _meter_sources()


func _meter_sources() -> Dictionary:
	var meter = game.player.abilities.get("meter")
	if meter == null:
		return {}
	var out := {}
	for key in meter.sources:
		out[key] = snappedf(float(meter.sources[key]), 0.01)
	return out


func _boss_set(key: String, value) -> void:
	if not boss_note.is_empty():
		boss_note[key] = value


func _boss_add(key: String, value) -> void:
	if not boss_note.is_empty():
		(boss_note[key] as Array).append(value)


func _in_boss() -> bool:
	return game.flow.state_name() == "boss" and not boss_note.is_empty() and not boss_note.has("outcome")


func _on_player_hit(amount: float, source_id: String) -> void:
	var hull: float = amount if _hull_seen < 0.0 else maxf(0.0, _hull_seen - float(game.run.hp))
	_hull_seen = float(game.run.hp)
	_count("hp_lost", amount)
	_count("hull_lost", hull)
	_count("hits")
	_note_contact_hit(hull)
	_fair.hit(source_id, hull)
	if source_id == "brindle_charge":
		_count("charge_hits")
	var in_boss := _in_boss()
	if in_boss:
		_knock_until = ticks + ceili(KNOCK_S * Engine.physics_ticks_per_second)
	var into: Dictionary = boss_note if in_boss else _note
	if not into.is_empty():
		if not into.has("hit_sources"):
			into["hit_sources"] = {}
		into["hit_sources"][source_id] = snappedf(float(into["hit_sources"].get(source_id, 0.0)) + amount, 0.1)
		var fight_start = null if in_boss else fight_start_of(_note)
		if in_boss or (fight_start != null and _note.get("warden_broken_s") == null):
			var fight_s: float = _boss_clock if in_boss else game.run.stage_time - float(fight_start)
			if amount > float(into.get("largest_hit", 0.0)):
				into["largest_hit"] = snappedf(amount, 0.1)
				into["largest_hit_source"] = source_id
				into["largest_hit_share"] = snappedf(amount / maxf(float(game.run.max_hp), 1.0), 0.001)
			if hull > float(into.get("largest_hull_hit", 0.0)):
				into["largest_hull_hit"] = snappedf(hull, 0.1)
				into["largest_hull_hit_share"] = snappedf(hull / maxf(float(game.run.max_hp), 1.0), 0.001)
			var clock: float = _boss_clock if in_boss else game.run.stage_time
			note_worst_window(_window_hits, into, clock, amount, hull, float(game.run.max_hp))
			if fight_s <= FIRST_45_S:
				into["hp_lost_45s"] = snappedf(float(into.get("hp_lost_45s", 0.0)) + amount, 0.1)
				into["hull_lost_45s"] = snappedf(float(into.get("hull_lost_45s", 0.0)) + hull, 0.1)


const WORST_WINDOW_S := 60.0
var _window_hits: Array = []


static func note_worst_window(hits: Array, into: Dictionary, t: float, amount: float, hull: float, max_hp: float) -> void:
	hits.append([t, amount, hull])
	while float(hits[0][0]) <= t - WORST_WINDOW_S:
		hits.pop_front()
	var hp_sum := 0.0
	var hull_sum := 0.0
	for h in hits:
		hp_sum += float(h[1])
		hull_sum += float(h[2])
	into["worst_60s_hp"] = snappedf(maxf(float(into.get("worst_60s_hp", 0.0)), hp_sum), 0.1)
	if hull_sum > float(into.get("worst_60s_hull", 0.0)) or not into.has("worst_60s_max_hp"):
		into["worst_60s_max_hp"] = snappedf(max_hp, 0.1)
	into["worst_60s_hull"] = snappedf(maxf(float(into.get("worst_60s_hull", 0.0)), hull_sum), 0.1)


func _on_enemy_struck(enemy: Node3D, kind: String, _force: float) -> void:
	if _note.is_empty():
		return
	if is_instance_valid(enemy) and enemy == game.flow.warden:
		if _warden_hp_at < 0.0:
			_warden_hp_at = float(enemy.get("hp"))
		_warden_kinds[kind] = true
	if not (kind == "slam" or kind == "stomp"):
		return
	if is_instance_valid(enemy) and enemy == game.flow.warden and enemy.has_method("contact_part") \
			and enemy.contact_part(game.player.ball_position(), kind) == "cap":
		_count("cap_hits")


func _settle_warden_damage(hp_now: float) -> void:
	var dealt := maxf(0.0, _warden_hp_at - hp_now)
	if dealt > 0.0 and not _note.is_empty() and not _warden_kinds.is_empty():
		if not _note.has("warden_damage"):
			_note["warden_damage"] = {}
		var by: Dictionary = _note["warden_damage"]
		for kind in _warden_kinds:
			by[kind] = snappedf(float(by.get(kind, 0.0)) + dealt / _warden_kinds.size(), 0.1)
	_warden_hp_at = -1.0
	_warden_kinds = {}


const ROGUE_SECONDS := 120.0
const RIB_SECONDS := 20.0
const RIB_NEAR := 60.0
var _rogue_done := false
var _rogue_travel := 0.0
var _rogue_travel_cap := -1.0
var _rib_skip := {}
var _rib_travel_cap := {}
var _leg_route: Array[Vector3] = []
var _leg_for := ""
var _leg_clock := 0.0


func _rogue_fight(delta: float) -> bool:
	if engage_by <= ENGAGE_BY or _rogue_done or _rogue_seen == null or game.run.stage_time > engage_by:
		return false
	if not is_instance_valid(_rogue_seen) or _rogue_seen.is_dead():
		_rogue_done = true
		return false
	_rogue_clock += delta
	if _rogue_clock > ROGUE_SECONDS:
		_rogue_done = true
		return false
	_ignore_walls = false
	_leg_for = ""
	_goal = "rogue fight"
	_fight(_rogue_seen, delta)
	return true


func _rogue_goal(delta: float) -> bool:
	if engage_by <= ENGAGE_BY or _rogue_done or _rogue_seen != null or game.world == null or game.run.stage_time > engage_by:
		return false
	var plan: Dictionary = game.world.get("rogue_plan")
	if plan.is_empty():
		return false
	var ball: Vector3 = game.player.ball_position()
	var at: Vector3 = game.ctx.terrain.drop_point(float(plan.at.x), float(plan.at.y), 1.0)
	if _rogue_travel_cap < 0.0:
		_rogue_travel_cap = ACTIVITY_TRAVEL_SECONDS + _flat(ball, at) / ACTIVITY_TRAVEL_SPEED
	_rogue_travel += delta
	if _rogue_travel > _rogue_travel_cap or _stalled("rogue", _flat(ball, at), delta):
		_rogue_done = true
		return false
	_ignore_walls = false
	_goal = "rogue site"
	if not _leg_to("rogue", ball, at, delta):
		_act(at, _nearest_enemy(), delta)
	return true


func _rib_goal(delta: float, reach: float) -> bool:
	if engage_by <= ENGAGE_BY or game.build == null or game.build.get("scrap") == null or game.run.stage_time > engage_by:
		return false
	var ball: Vector3 = game.player.ball_position()
	var best = null
	var best_d := INF
	for c in game.build.scrap.caches():
		var key := "rib:%d" % (c["item"] as Object).get_instance_id()
		var d := _flat(ball, c["at"])
		if not _rib_skip.has(key) and d < best_d and d <= reach:
			best_d = d
			best = c
	if best == null:
		return false
	var key := "rib:%d" % (best["item"] as Object).get_instance_id()
	if not _rib_travel_cap.has(key):
		_rib_travel_cap[key] = RIB_SECONDS + best_d / ACTIVITY_TRAVEL_SPEED
	_rib_clock[key] = float(_rib_clock.get(key, 0.0)) + delta
	if float(_rib_clock[key]) > float(_rib_travel_cap[key]) or _stalled(key, best_d, delta):
		_rib_skip[key] = true
		return false
	_ignore_walls = false
	_goal = "rib cache"
	var at: Vector3 = best["at"]
	if best_d < WAYPOINT_REACHED or not _leg_to(key, ball, at, delta):
		_act(at, _nearest_enemy(), delta)
	return true


func _stalled(key: String, d: float, delta: float) -> bool:
	var c: Array = _closing.get(key, [d, 0.0])
	if d < float(c[0]) - CLOSING_M:
		c = [d, 0.0]
	else:
		c[1] = float(c[1]) + delta
	_closing[key] = c
	return float(c[1]) > CLOSING_SECONDS


func _leg_to(key: String, ball: Vector3, point: Vector3, delta: float) -> bool:
	if _leg_for != key:
		_leg_for = key
		_leg_route = _graph_path(ball, point)
		_leg_clock = 0.0
	while not _leg_route.is_empty() and _flat(ball, _leg_route[0]) < WAYPOINT_REACHED:
		_leg_route.pop_front()
		_leg_clock = 0.0
	if _leg_route.is_empty():
		return false
	_leg_clock += delta
	if _leg_clock > FIND_LEG_SECONDS:
		_leg_route = []
		return false
	_act(_leg_route[0], _nearest_enemy(), delta)
	return true


const RIB_TAKEN_M := 8.0


func _content_scan() -> void:
	if _note.is_empty():
		return
	var world = game.world
	var activities = world.get("activities") if world != null else null
	if activities != null and _note.get("pockets_drawn") == null:
		_note["pockets_drawn"] = drawn_pockets(activities.sites)
	var rogue = world.get("rogue") if world != null else null
	if rogue != null and is_instance_valid(rogue) and rogue.get_instance_id() != _rogue_id:
		_rogue_seen = rogue
		_rogue_id = rogue.get_instance_id()
		_note["rogue_woke_s"] = snappedf(game.run.stage_time, 0.01)
		_note["rogue_kind"] = String(rogue.get("kind"))
	if _rogue_id != 0 and _note["rogue_beaten_s"] == null:
		var body = instance_from_id(_rogue_id)
		if body == null or body.is_dead():
			_note["rogue_beaten_s"] = snappedf(game.run.stage_time, 0.01)
			_note["rogues_beaten"] = 1
	var scrap = game.build.get("scrap") if game.build != null else null
	if scrap == null or not scrap.has_method("caches"):
		return
	var ball: Vector3 = game.player.ball_position()
	var now := {}
	for c in scrap.caches():
		now[(c["item"] as Object).get_instance_id()] = c["at"]
	for id in now:
		if not _caches_seen.has(id):
			_note["rib_caches_placed"] = int(_note["rib_caches_placed"]) + 1
	for id in _caches_seen:
		if not now.has(id) and _flat(ball, _caches_seen[id]) < RIB_TAKEN_M:
			_note["rib_caches_taken"] = int(_note["rib_caches_taken"]) + 1
	var closest: Dictionary = _note.get("rib_closest_m", {})
	for id in now:
		if not _caches_seen.has(id):
			_rib_spot[id] = "%.0f,%.0f" % [now[id].x, now[id].z]
		var key: String = _rib_spot.get(id, "")
		closest[key] = snappedf(minf(float(closest.get(key, INF)), _flat(ball, now[id])), 0.1)
	_note["rib_closest_m"] = closest
	_caches_seen = now


static func drawn_pockets(sites: Array) -> Array:
	var out: Array = []
	for s in sites:
		if s.drawn:
			out.append(String(s.interior.get("id", s.id)))
	return out


func _close_note() -> void:
	if _note.is_empty():
		return
	_note["exit_s"] = snappedf(game.run.stage_time, 0.01)
	_note["hp_lost"] = snappedf(float(_note["hp_lost"]), 0.1)
	_note["hull_lost"] = snappedf(float(_note.get("hull_lost", 0.0)), 0.1)
	_note["punch_short_s"] = snappedf(float(_note["punch_short_s"]), 0.01)
	if not _note.has("secrets_found"):
		_note["secrets_found"] = []
	_close_contact()
	stage_notes.append(_note)
	_note = {}


func _on_boss_entered() -> void:
	_close_note()
	_boss_clock = 0.0
	_window_hits = []
	_seen = {}
	_evaded = {}
	_charge_read = {}
	_charge_stepped = {}
	_clash_tried = {}
	_clash_latched = {}
	_plant_state = "idle"
	_fight_phase = "charge"
	_fight_target = null
	boss_note = {"entered_run_s": snappedf(game.run.run_time, 0.01), "entry_heft": snappedf(game.run.heft(), 0.001),
		"entry_parts": game.run.parts.size(), "phases": [], "weak_point_hits": {}, "hp_lost": 0.0, "hits": 0,
		"evasions": 0, "plants": 0, "slingshots": 0, "specials": 0, "stolen": 0, "defeated_s": null,
		"hold_s": null, "hold_bound_s": null,
		"weak_opened": null, "weak_sealed": null, "weak_timed_out": null, "weak_broken": null, "weak_open_at_end": null,
		"crew_waves": null,
		"charge_reads": 0, "charge_sidesteps": 0, "charge_hits": 0, "clash_tries": 0}


func _boss_hold_note() -> void:
	var boss = _boss()
	if boss == null or not "hold_s" in boss:
		return
	_boss_set("hold_s", snappedf(boss.hold_s, 0.01))
	_boss_set("hold_bound_s", snappedf(boss.hold_bound_s, 0.01))
	_boss_weak_note(boss)


func _boss_weak_note(boss) -> void:
	if not "weak_stats" in boss or not boss.weak.active():
		return
	var stats: Dictionary = boss.weak_stats
	_boss_set("weak_opened", (stats["opened"] as Dictionary).duplicate())
	_boss_set("weak_sealed", (stats["sealed"] as Dictionary).duplicate())
	_boss_set("weak_timed_out", (stats["timed_out"] as Dictionary).duplicate())
	_boss_set("weak_broken", (stats["broken"] as Dictionary).duplicate())
	_boss_set("weak_open_at_end", (stats["open_at_end"] as Dictionary).duplicate())
	_boss_set("crew_waves", (stats["crew_waves"] as Dictionary).duplicate())


func _on_boss_phase(phase: int, phase_name: String) -> void:
	_boss_add("phases", {"phase": phase, "name": phase_name, "at_s": snappedf(_boss_clock, 0.01),
		"heft": snappedf(game.run.heft(), 0.001), "hp": snappedf(game.run.hp, 0.1)})


func _plan() -> void:
	_planned = true
	if policy != "completionist":
		return
	var terrain = game.ctx.terrain
	var spawn: Vector3 = terrain.spawn_point(_stage)
	var beacon: Vector3 = terrain.beacon_point(_stage)
	var axis := Vector2(beacon.x - spawn.x, beacon.z - spawn.z).normalized()
	var lines: Array = terrain.scrap_lines(_stage).duplicate()
	lines.sort_custom(func(a, b): return _along(a, spawn, axis) < _along(b, spawn, axis))
	var at := Vector2(spawn.x, spawn.z)
	for line in lines:
		var from: Vector2 = line[0]
		var to: Vector2 = line[1]
		if at.distance_to(to) < at.distance_to(from):
			var swap := from
			from = to
			to = swap
		_waypoints.append(terrain.drop_point(from.x, from.y, 1.0))
		_waypoints.append(terrain.drop_point(to.x, to.y, 1.0))
		at = to
	_note["waypoints"] = _waypoints.size()


static func _along(line: Array, spawn: Vector3, axis: Vector2) -> float:
	var mid: Vector2 = ((line[0] as Vector2) + (line[1] as Vector2)) * 0.5
	return (mid - Vector2(spawn.x, spawn.z)).dot(axis)


func _roam(delta: float) -> void:
	if policy == "completionist" and _chain_phase != "":
		_explorer_chain(delta)
		return
	if not _planned:
		_plan()
	_welcome_ring_at = Vector3.INF
	var warden: Node3D = game.flow.warden if is_instance_valid(game.flow.warden) else null
	if warden != null and _warden_hp_at >= 0.0:
		_settle_warden_damage(float(warden.get("hp")))
	if warden != null:
		_note["magnet_stuns"] = maxi(int(_note.get("magnet_stuns", 0)), int(warden.get("magnet_stuns") if warden.get("magnet_stuns") != null else 0))
	var crew := _gate_foe()
	if crew != null:
		_goal = "gate crew"
		_fight(crew, delta)
		return
	match policy:
		"skipper":
			if relay_stake > 0 and _relay_arm(delta):
				return
			_fight(warden, delta)
		"completionist":
			_completionist(warden, delta)
		"camper":
			_camper(warden, delta)
		"traversal":
			_traverse(delta)
		"orbit", "terrain":
			if kite == null:
				kite = BotKite.new(self)
			kite.step(delta, policy == "terrain")
		_:
			_random(warden, delta)


func _gate_foe() -> Node3D:
	var gate = game.flow.get("gate")
	if gate == null or policy == "traversal":
		return null
	if gate.lock_active() and _note.get("lock_s") == null:
		_note_set("lock_s", snappedf(game.run.stage_time, 0.01))
	if not gate.lock_active() and _note.get("lock_s") != null and _note.get("unlock_s") == null:
		_note_set("unlock_s", snappedf(game.run.stage_time, 0.01))
	if gate.has_gate() and not gate.locked() and _note.get("gate_open_s") == null:
		_note_set("gate_open_s", snappedf(game.run.stage_time, 0.01))
	var ball: Vector3 = game.player.ball_position()
	if gate.lock_active():
		return gate.foe_for(ball)
	if gate.locked() and game.flow.engaged():
		return gate.foe_for(ball, GATE_HUNT)
	return null


func _traverse(delta: float) -> void:
	_welcome_ring_at = Vector3.INF
	var lag := int(ceil(TRAVERSE_REACTION * Engine.physics_ticks_per_second))
	var ball: Vector3 = game.player.ball_position()
	while _leg < route.size():
		var leg: Vector2 = route[_leg]
		if _flat(ball, game.ctx.terrain.drop_point(leg.x, leg.y, 1.0)) > TRAVERSE_REACHED:
			break
		_leg += 1
	var point: Vector3 = game.ctx.terrain.beacon_point(_stage)
	if _leg < route.size():
		point = game.ctx.terrain.drop_point(route[_leg].x, route[_leg].y, 1.0)
	_goal = "traverse leg %d" % _leg
	_traverse_point = point
	source.hold = {}
	source.press = {}
	_defer_look = true
	_look_delta = Vector2.ZERO
	_act(point, _traverse_hands(ball, point, delta), delta)
	_defer_look = false
	source.hold.erase("fire_held")
	var stick: Vector2 = source.hold.get("move", Vector2.ZERO)
	_out.append({"hold": source.hold, "press": source.press, "look": _look_delta, "wish": _stick_to_world(stick)})
	source.hold = {}
	source.press = {}
	if _out.size() <= lag:
		return
	var sent: Dictionary = _out.pop_front()
	var look: Vector2 = sent["look"]
	game.camera.look(Vector2(-look.x / SENSITIVITY, -look.y / SENSITIVITY))
	source.hold = sent["hold"]
	if source.hold.has("move"):
		source.hold["move"] = _world_to_stick(sent["wish"])
	source.press = sent["press"]
	if source.press.has("harpoon_pressed") and "harpoon" in hands:
		var now: Dictionary = game.player.kit.aim
		if now.get("state", Augments.AIM_NONE) == Augments.AIM_NONE or now.get("body") != null:
			source.press.erase("harpoon_pressed")
	var picked: bool = source.press.has("slot_pick")
	_gate_presses()
	_traverse_click(picked)


func _traverse_hands(ball: Vector3, point: Vector3, delta: float) -> Variant:
	_glide_held = false
	_hand_aim = false
	if hands.is_empty():
		return null
	if "glide" in hands:
		_glide_hand(ball, point)
	if "harpoon" in hands:
		var aim = _swing_hand(ball, point, delta)
		_hand_aim = aim != null
		return aim
	return null


func _swing_hand(ball: Vector3, point: Vector3, delta: float) -> Variant:
	var kit = game.player.kit
	var way := Vector3(point.x - ball.x, 0.0, point.z - ball.z)
	if way.length() < 0.5:
		return null
	way = way.normalized()
	_swing_cool -= delta
	_swing_sent -= delta
	if kit.hooked:
		_swing_clock += delta
		var anchor: Vector3 = kit.anchor
		var carried: float = game.player.planar_velocity().dot(way)
		var past: bool = Vector3(anchor.x - ball.x, 0.0, anchor.z - ball.z).dot(way) < 0.0
		if _swing_sent <= 0.0 and (kit.on_body or past or _swing_clock > SWING_HOLD_MAX \
				or (_swing_clock > SWING_GRACE and carried < SWING_CARRY)):
			_swing_sent = SWING_SENT
			source.press["harpoon_released"] = true
			_swing_cool = SWING_GAP
			return null
		_harpoon_held = true
		return null
	_swing_clock = 0.0
	if _swing_cool > 0.0 or _swing_sent > 0.0 or kit.mounted or _cast_phase != "" or game.player.frozen() \
			or not game.player.verb_ready("harpoon") or game.player.planar_velocity().length() < SWING_MIN_SPEED:
		return null
	if _swing_bites(kit.aim, ball, way):
		source.press["harpoon_pressed"] = true
		_swing_sent = SWING_SENT
		return null
	var best := Vector3.INF
	var far := 0.0
	var space = game.get_world_3d().direct_space_state
	var reach: float = game.player.tuning.f("rope_range")
	var assist: float = game.player.tuning.f("grapple_assist_deg")
	for yaw in SWING_YAWS:
		for pitch in SWING_PITCHES:
			var dir: Vector3 = (way.rotated(Vector3.UP, yaw) * cos(pitch) + Vector3.UP * sin(pitch)).normalized()
			var hit := Augments.grapple_target(space, ball + Vector3.UP * 0.8, dir, ball, reach, assist,
				Augments.WORLD_MASK | Augments.ENEMY_MASK, false)
			if _swing_bites(hit, ball, way) and (hit["point"] - ball).dot(way) > far:
				far = (hit["point"] - ball).dot(way)
				best = hit["point"]
	return {"at": best} if best != Vector3.INF else null


func _swing_bites(aim: Dictionary, ball: Vector3, way: Vector3) -> bool:
	if aim.get("state", Augments.AIM_NONE) == Augments.AIM_NONE:
		return false
	if aim.get("body") != null:
		return false
	var to: Vector3 = aim["point"] - ball
	return to.y >= SWING_ABOVE and to.length() > 0.5 and Vector3(to.x, 0.0, to.z).normalized().dot(way) >= SWING_AHEAD


func _glide_hand(ball: Vector3, point: Vector3) -> void:
	var player = game.player
	if not player.kit.on("glide") or player.state.grounded or player.kit.hooked:
		_gliding = false
		return
	var way := Vector3(point.x - ball.x, 0.0, point.z - ball.z).normalized()
	var over := _inside_thermal(ball)
	var drop: float = ball.y - _ground_point(ball.x, ball.z).y
	var gains: bool = player.planar_velocity().dot(way) >= GLIDE_GAIN
	var room: bool = ball.y - point.y >= GLIDE_ABOVE and Vector2(point.x - ball.x, point.z - ball.z).length() >= GLIDE_NEAR
	_gliding = over or (room and gains and (drop >= GLIDE_DROP or _gliding))
	_glide_held = _gliding


func _traverse_click(picked: bool) -> void:
	if picked:
		if source.press.has("slot_pick") and _cast_phase == "sent":
			_cast_click_tick = ticks + int(ceil(CAST_GAP * Engine.physics_ticks_per_second))
		elif _cast_phase == "sent":
			_cast_phase = ""
	if _cast_click_tick >= 0 and ticks >= _cast_click_tick:
		_cast_click_tick = -1
		source.press["fire_pressed"] = true
		_cast_phase = "release"


func _stick_to_world(stick: Vector2) -> Vector3:
	var yaw: float = game.camera.yaw
	return Vector3(cos(yaw), 0.0, -sin(yaw)) * stick.x + Vector3(-sin(yaw), 0.0, -cos(yaw)) * stick.y


func _world_to_stick(wish: Vector3) -> Vector2:
	var yaw: float = game.camera.yaw
	return Vector2(wish.dot(Vector3(cos(yaw), 0.0, -sin(yaw))), wish.dot(Vector3(-sin(yaw), 0.0, -cos(yaw))))


func _gate_presses() -> void:
	var pressed: Array = []
	for key in source.press:
		var value = source.press[key]
		if (value is int and value >= 0) or (value is bool and value):
			pressed.append(key)
	if pressed.is_empty():
		return
	if ticks - _last_press_tick < int(ceil(TRAVERSE_PRESS_GAP * Engine.physics_ticks_per_second)):
		source.press = {}
		return
	source.press = {pressed[0]: source.press[pressed[0]]}
	_last_press_tick = ticks
	press_ticks.append(ticks)


func _camper(target: Node3D, delta: float) -> void:
	_welcome_ring_at = Vector3.INF
	if target == null or not is_instance_valid(target):
		_goal = "beacon"
		_act(game.flow.beacon.global_position, _nearest_enemy(), delta)
		return
	var ball: Vector3 = game.player.ball_position()
	var flat: float = _flat(ball, target.global_position)
	var in_range: bool = flat <= CAMP_RANGE
	if in_range and (flat < CAMP_NEAR or (_camp_backing and flat < CAMP_RANGE * 0.8)):
		_camp_backing = true
		_goal = "camp back"
		var out := Vector3(ball.x - target.global_position.x, 0.0, ball.z - target.global_position.z)
		out = out.normalized() if out.length() > 0.1 else Vector3.RIGHT
		_act(ball + out * CAMP_RANGE, target, delta, target)
		return
	_camp_backing = false
	_goal = "camp"
	_act(ball if in_range else target.global_position, target, delta, target)
	if in_range and game.player.state.grounded:
		source.hold["brake_held"] = true


func _completionist(warden: Node3D, delta: float) -> void:
	if _activity_rushed():
		if engage_by > ENGAGE_BY and _note.get("warden_fight_s") == null:
			_note["explore_clock_hit"] = true
		_fight(warden, delta)
		return
	if _rogue_fight(delta) or _rib_goal(delta, RIB_NEAR):
		return
	if _activity_goal(delta):
		return
	var event := _event_goal(delta)
	if not event.is_empty():
		_goal = event["goal"]
		_act(event["steer"], event.get("aim", null), delta)
		return
	if _rogue_goal(delta) or _rib_goal(delta, INF):
		return
	if not _waypoints.is_empty():
		_waypoint_time += delta
		var ball: Vector3 = game.player.ball_position()
		if _flat(ball, _waypoints[0]) < WAYPOINT_REACHED or _waypoint_time > WAYPOINT_SECONDS:
			_waypoints.pop_front()
			_waypoint_time = 0.0
		if not _waypoints.is_empty():
			_goal = "waypoint %d" % _waypoints.size()
			_act(_waypoints[0], _nearest_enemy(), delta)
			return
	var vault: Node3D = _vault()
	if vault != null and not _vault_done:
		_note["vault_tried"] = true
		_vault_time += delta
		if _vault_time > VAULT_SECONDS:
			_vault_done = true
		else:
			_fight(vault, delta)
			return
	_fight(warden, delta)


func _random(warden: Node3D, delta: float) -> void:
	var ball: Vector3 = game.player.ball_position()
	if warden != null and not _committed:
		_committed = _flat(ball, warden.global_position) < WANDER_COMMIT_DISTANCE or game.run.stage_time > WANDER_COMMIT_TIME
	if _committed or warden == null:
		_fight(warden, delta)
		return
	_wander_clock -= delta
	if _wander_clock <= 0.0:
		_wander_clock = rng.randf_range(WANDER_GAP.x, WANDER_GAP.y)
		var to_beacon: Vector3 = game.ctx.terrain.beacon_point(_stage) - ball
		var base := atan2(to_beacon.x, to_beacon.z)
		var angle := base + rng.randfn(0.0, WANDER_SPREAD)
		_wander_heading = Vector3(sin(angle), 0.0, cos(angle))
		if rng.randf() < 0.3:
			source.press["jump_pressed"] = true
	_goal = "wander"
	_act(ball + _wander_heading * 30.0, _nearest_enemy(), delta)


func _relay_arm(delta: float) -> bool:
	if relay_stake <= 0:
		return false
	var world = game.world
	if world == null or world.activities == null:
		return false
	var s = world.activities.site("hold_the_relay")
	if s == null or s.relay == null or _relay_closed.has(s.id):
		return false
	var rows: Array = _note.get("relay_stakes", [])
	var row: Dictionary
	if rows.is_empty():
		s.relay.set_stakes(relay_stake)
		row = {"stage": game.run.stage, "k": s.relay.stakes, "parts_before": game.run.parts.size()}
		rows.append(row)
		_note["relay_stakes"] = rows
	else:
		row = rows[0]
	_relay_clock += delta
	var ball: Vector3 = game.player.ball_position()
	if s.started and not row.has("credit"):
		var activities = world.activities
		row["credit"] = snappedf(s.relay.pack_credit(activities.relay_pack_cost(s) * int(s.rule["waves"])), 0.01)
		row["rewards"] = s.relay.rewards()
	row["minibosses"] = s.minibosses_sent
	if s.done:
		row["outcome"] = "won"
		if s.pickup != null and not s.pickup_taken and _relay_clock <= RELAY_ARM_SECONDS:
			_goal = "relay pay"
			_pay_roll(s, ball, delta)
			return true
	elif _relay_clock > RELAY_ARM_SECONDS:
		row["outcome"] = "gave_up"
	else:
		_goal = "relay charge" if s.started else "relay approach"
		_act(_approach(s, ball), _nearest_enemy(), delta)
		return true
	row["parts"] = game.run.parts.size() - int(row["parts_before"])
	row["seconds"] = snappedf(_relay_clock, 0.01)
	_relay_closed[s.id] = true
	return false


func _activity_goal(delta: float) -> bool:
	_ignore_walls = false
	var world = game.world
	if world == null or world.activities == null or world.activities.sites.is_empty():
		_activity = ""
		return false
	var activities = world.activities
	var ball: Vector3 = game.player.ball_position()
	var s = _site_by_key(activities, _activity) if _activity != "" else null
	if s != null and not _activity_open(s):
		if s.has_meta("find"):
			var out: Vector2 = Vector2(s.rule.get("face", Vector2(0.0, -1.0))).normalized() * CACHE_RUNUP * 1.5
			_find_exit = _ground_point(s.global_position.x + out.x, s.global_position.z + out.y)
		s = null
		_activity = ""
	if _find_exit != Vector3.INF:
		if _flat(ball, _find_exit) < WAYPOINT_REACHED or _activity_rushed() \
				or (engage_by > ENGAGE_BY and _stalled("find_exit", _flat(ball, _find_exit), delta)):
			_find_exit = Vector3.INF
			_closing.erase("find_exit")
		else:
			_goal = "activity find exit"
			_act(_find_exit, _nearest_enemy(), delta)
			return true
	if s == null:
		var best_level := -INF
		var best := INF
		for c in activities.sites:
			if not is_instance_valid(c) or not _activity_open(c):
				continue
			if c.rule.has("bar_tier"):
				continue
			var level := roundf(c.global_position.y / LEVEL_BAND)
			if _site_has_authored_pack(c):
				level -= CAMP_LAST
			if c.has_meta("find") and engage_by <= ENGAGE_BY:
				continue
			if c.has_meta("find") and _flat(ball, c.global_position) > FIND_NEAR_M:
				level -= CAMP_LAST * 2.0
			var d := _flat(ball, c.global_position)
			if level > best_level or (level == best_level and d < best):
				best_level = level
				best = d
				s = c
		_activity = _site_key(s) if s != null else ""
		_cache_phase = "runup"
		_cache_clock = 0.0
	if s == null:
		return false
	if _activity_deferred.get(_site_key(s)) is Vector3:
		_activity_deferred[_site_key(s)] = true
	var finished: Array = []
	var secrets: Array = []
	for c in activities.sites:
		if is_instance_valid(c) and c.done:
			finished.append(c.id)
			if c.has_meta("find"):
				secrets.append(String(c.get_meta("find")))
	_note["activities_finished"] = finished
	_note["secrets_found"] = secrets
	var entered: Array = _note.get("activities_entered", [])
	if not s.id in entered:
		entered.append(s.id)
		_note["activities_entered"] = entered
	var key := _site_key(s)
	var near: float = ACTIVITY_NEAR + (CACHE_RUNUP if s.id == "cracked_cache" else 0.0)
	if engage_by > ENGAGE_BY and _flat(ball, s.global_position) > near:
		if not _activity_travel_cap.has(key):
			var leg: float = 0.0 if _activity_deferred.has(key) else _flat(ball, s.global_position) / ACTIVITY_TRAVEL_SPEED
			_activity_travel_cap[key] = ACTIVITY_TRAVEL_SECONDS + leg
		_activity_travel[key] = float(_activity_travel.get(key, 0.0)) + delta
		if _stalled(key, _flat(ball, s.global_position), delta):
			_activity_travel[key] = INF
	else:
		_activity_time[key] = float(_activity_time.get(key, 0.0)) + delta
	if float(_activity_travel.get(key, 0.0)) > float(_activity_travel_cap.get(key, INF)) and not _activity_deferred.has(key):
		_activity_deferred[key] = ball
		_activity_travel.erase(key)
		_activity_travel_cap.erase(key)
		_closing.erase(key)
		_activity = ""
		return false
	if float(_activity_time.get(key, 0.0)) > (FIND_SECONDS if s.has_meta("find") else (SURGE_SECONDS if s.id == "surge_run" else ACTIVITY_SECONDS)) \
			or float(_activity_travel.get(key, 0.0)) > float(_activity_travel_cap.get(key, INF)):
		_activity_skip[key] = true
		_activity = ""
		return false
	if s.done:
		_goal = "activity %s pay" % s.id
		_pay_roll(s, ball, delta)
		return true
	if _site_has_authored_pack(s) or s.id == "ambush_altar":
		var foe := _pack_foe(s, ball)
		if foe != null:
			_goal = "activity %s fight" % s.id
			_fight(foe, delta)
		else:
			_goal = "activity %s" % s.id
			_act(_approach(s, ball), _nearest_enemy(), delta)
		return true
	match s.id:
		"cracked_cache":
			_cache_ram(s, ball, delta)
		"surge_run":
			var course = s.course
			if course == null or (not s.started and s.relay_cooldown > 0.0):
				_activity_skip[s.id] = true
				_activity = ""
				return false
			if s.surge_live:
				_goal = "activity surge_run gate %d" % course.model.next_gate
				var gate: Vector3 = course.next_gate_point()
				var close := Vector2(gate.x - ball.x, gate.z - ball.z).length() < SURGE_GATE_AIM_M
				_act(gate if close else course.lead_point(ball, SURGE_LEAD_M), _nearest_enemy(), delta)
			elif s.started:
				_goal = "activity surge_run head"
				var head: Vector2 = course.model.route.points[0] - course.model.route.tangent(0.0) * SURGE_RUNUP_M
				_act(Vector3(head.x, ball.y, head.y), _nearest_enemy(), delta)
			else:
				_goal = "activity surge_run ring"
				_act(_approach(s, ball), _nearest_enemy(), delta)
		"hauler_bounty":
			if s.brute != null and is_instance_valid(s.brute) and not s.brute.is_dead():
				_goal = "activity %s fight" % s.id
				_fight(s.brute, delta)
			else:
				_activity_skip[s.id] = true
				_activity = ""
				return false
		_:
			_activity_skip[s.id] = true
			_activity = ""
			return false
	return true


func _site_has_authored_pack(s) -> bool:
	var map = game.ctx.terrain.map()
	if not "activity_sites" in map:
		return false
	for authored in map.activity_sites:
		for spec in [authored] + authored.get("alts", []):
			if String(spec.get("id", "")) == s.id:
				return not spec.get("pack", []).is_empty()
	return false


func _approach(s, ball: Vector3) -> Vector3:
	var at: Vector3 = s.global_position
	if _climb_for != s.id:
		_climb_for = s.id
		_climb.clear()
		_route.clear()
		if engage_by > ENGAGE_BY:
			_route = _graph_path(ball, at)
			if _route.is_empty():
				_route = _route_to(s, ball)
		if _route.is_empty() and at.y - ball.y > LEVEL_BAND:
			_climb = _climb_route_any(ball, at)
	while not _route.is_empty() and _flat(ball, _route[0]) < ROUTE_REACHED:
		_route.pop_front()
		if _route.is_empty() and at.y - ball.y > LEVEL_BAND:
			_climb = _climb_route_any(ball, at)
	while not _climb.is_empty() and _flat(ball, _climb[0]) < CLIMB_REACHED:
		_climb.pop_front()
	_kicker_jump(ball)
	if not _route.is_empty():
		return _route[0]
	return at if _climb.is_empty() else _climb[0]


func _route_to(s, ball: Vector3) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var map = game.ctx.terrain.map()
	if s.has_meta("find") or not "park" in map:
		return out
	var site_row := ""
	var site_d := INF
	for spec in map.park.get("activity_rows", []):
		var spot: Array = spec.get("at", [])
		var kinds: Array = [String(spec.get("activity", ""))]
		for alt in spec.get("alts", []):
			kinds.append(String(alt.get("activity", "")))
		if not kinds.has(s.id) or spot.size() < 2:
			continue
		var d := Vector2(float(spot[0]), float(spot[1])).distance_to(Vector2(s.global_position.x, s.global_position.z))
		if d < site_d:
			site_d = d
			site_row = String(spec.get("site", ""))
	if site_row == "":
		return out
	var rows := {}
	for r in map.park.get("park_rows", []):
		rows[String(r.get("id", ""))] = r
	for route in map.park.get("routes", []):
		var ids: Array = [route.get("from", "")]
		ids.append_array(route.get("via", []))
		var end := ids.find(site_row)
		if end < 0:
			continue
		for i in end + 1:
			var r = rows.get(String(ids[i]))
			if r == null or not r.has("at"):
				continue
			var p: Vector3 = _ground_point(float(r.at[0]), float(r.at[1]))
			if out.is_empty() or _flat(out[-1], p) > ROUTE_REACHED:
				out.append(p)
		break
	var nearest := 0
	for i in out.size():
		if _flat(ball, out[i]) < _flat(ball, out[nearest]):
			nearest = i
	return out.slice(nearest)


func _climb_route(from: Vector3, to: Vector3, slope := CLIMB_SLOPE) -> Array[Vector3]:
	var terrain = game.ctx.terrain
	var lo := Vector2(minf(from.x, to.x), minf(from.z, to.z)) - Vector2.ONE * CLIMB_PAD
	var hi := Vector2(maxf(from.x, to.x), maxf(from.z, to.z)) + Vector2.ONE * CLIMB_PAD
	var nx := int(ceilf((hi.x - lo.x) / CLIMB_STEP)) + 1
	var nz := int(ceilf((hi.y - lo.y) / CLIMB_STEP)) + 1
	var hx := 2 * nx - 1
	var legacy := _mind_slope()
	var graph := AStar2D.new()
	graph.reserve_space(nx * nz)
	var half := PackedFloat32Array()
	half.resize(hx * (2 * nz - 1))
	var kickers := _kickers_within(lo, hi)
	for j in 2 * nz - 1:
		for i in hx:
			var p := lo + Vector2(i, j) * CLIMB_STEP * 0.5
			half[j * hx + i] = maxf(terrain.height(p.x, p.y), _kicker_height(kickers, p))
	for j in nz:
		for i in nx:
			graph.add_point(j * nx + i, lo + Vector2(i, j) * CLIMB_STEP)
	for j in nz:
		for i in nx:
			var a := j * nx + i
			for step in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(-1, 1)]:
				var bi: int = i + step.x
				var bj: int = j + step.y
				if bi < 0 or bi >= nx or bj >= nz:
					continue
				var b := bj * nx + bi
				var ha: float = half[2 * j * hx + 2 * i]
				var hm: float = half[(2 * j + step.y) * hx + 2 * i + step.x]
				var hb: float = half[2 * bj * hx + 2 * bi]
				var run := Vector2(step).length() * CLIMB_STEP * 0.5
				var up := maxf(hm - ha, hb - hm) / run
				var down := maxf(ha - hm, hm - hb) / run
				var drop := absf(hb - ha) / CLIMB_STEP
				var high := a if ha > hb else b
				graph.set_point_weight_scale(high, maxf(graph.get_point_weight_scale(high), 1.0 + drop))
				if legacy:
					up = (hb - ha) / (run * 2.0)
					if absf(up) <= slope:
						graph.connect_points(a, b)
					elif up > 0.0:
						graph.connect_points(b, a, false)
					else:
						graph.connect_points(a, b, false)
				elif up <= slope + SLOPE_SLACK and down <= slope + SLOPE_SLACK:
					graph.connect_points(a, b)
				elif up <= slope + SLOPE_SLACK:
					graph.connect_points(a, b, false)
				elif down <= slope + SLOPE_SLACK:
					graph.connect_points(b, a, false)
	var lifted := {}
	var lips := {}
	for k in kickers:
		var lip: Vector3 = k["lip"]
		var land2: Vector2 = Vector2(lip.x, lip.z) + Vector2(k["dir"].x, k["dir"].z) * KICKER_LAUNCH
		var land_y: float = terrain.height(land2.x, land2.y)
		if land_y > lip.y + CLIMB_LEVEL:
			continue
		var lip_id := graph.get_available_point_id()
		graph.add_point(lip_id, Vector2(lip.x, lip.z))
		var land_id := graph.get_available_point_id()
		graph.add_point(land_id, land2)
		graph.connect_points(lip_id, land_id, false)
		lifted[lip_id] = lip.y
		lifted[land_id] = land_y
		lips[lip_id] = true
		for j in nz:
			for i in nx:
				var c := lo + Vector2(i, j) * CLIMB_STEP
				var hc: float = half[2 * j * hx + 2 * i]
				var to_lip := c.distance_to(Vector2(lip.x, lip.z))
				if to_lip <= CLIMB_STEP * 1.5 and lip.y - hc <= (slope + SLOPE_SLACK) * maxf(to_lip, 0.01) \
						and hc - lip.y <= slope * maxf(to_lip, 0.01):
					graph.connect_points(j * nx + i, lip_id, false)
				var to_land := c.distance_to(land2)
				if to_land <= CLIMB_STEP * 1.5 and absf(hc - land_y) <= slope * maxf(to_land, 0.01):
					graph.connect_points(land_id, j * nx + i)
	var start := graph.get_closest_point(Vector2(from.x, from.z))
	var goal := graph.get_closest_point(Vector2(to.x, to.z))
	for mouth in _cable_mouths():
		var reach: float = mouth["radius"] + CABLE_CLEAR
		var top: Vector3 = mouth["at"]
		for j in range(maxi(0, floori((top.z - reach - lo.y) / CLIMB_STEP)), mini(nz, ceili((top.z + reach - lo.y) / CLIMB_STEP) + 1)):
			for i in range(maxi(0, floori((top.x - reach - lo.x) / CLIMB_STEP)), mini(nx, ceili((top.x + reach - lo.x) / CLIMB_STEP) + 1)):
				var id := j * nx + i
				var c := lo + Vector2(i, j) * CLIMB_STEP
				if id != start and id != goal and Vector3(c.x, half[2 * j * hx + 2 * i] + 1.0, c.y).distance_to(top) <= reach:
					graph.set_point_disabled(id)
	var ids := graph.get_id_path(start, goal)
	var out: Array[Vector3] = []
	_route_lips.clear()
	var ramp := []
	for id in ids:
		var at := graph.get_point_position(id)
		ramp.append(not lifted.has(id) and _kicker_height(kickers, at) > terrain.height(at.x, at.y) + CLIMB_LEVEL)
	for k in range(1, ids.size()):
		var id: int = ids[k]
		var at := graph.get_point_position(id)
		if lifted.has(id):
			out.append(Vector3(at.x, float(lifted[id]) + 1.0, at.y))
			if lips.has(id):
				_route_lips.append(out.back())
		elif k % 2 == 1 or ramp[k] or (k + 1 < ids.size() and ramp[k + 1]):
			out.append(_ground_point(at.x, at.y))
	return out


func _cable_mouths() -> Array:
	var out := []
	var map = game.ctx.terrain.map()
	if map == null or not "contraptions" in map:
		return out
	for spec in map.contraptions:
		if spec["kind"] == "cable":
			out.append({"at": spec["from"], "radius": float(spec["radius"])})
	return out


func _climb_route_any(from: Vector3, to: Vector3) -> Array[Vector3]:
	var out := _climb_route(from, to)
	for slope in CLIMB_SLOPE_RETRY:
		if not out.is_empty():
			break
		out = _climb_route(from, to, slope)
	return out


func _kickers_within(lo: Vector2, hi: Vector2) -> Array:
	var out := []
	var terrain = game.ctx.terrain
	var map = terrain.map()
	if map == null or not "park" in map or not terrain.has_method("geometry_root"):
		return out
	var root: Node3D = terrain.geometry_root(terrain.stage)
	if root == null:
		return out
	for row in map.park.get("park_rows", []):
		if row.get("element") != "kicker":
			continue
		var node := root.find_child("Park_" + String(row["id"]), true, false) as Node3D
		if node == null:
			continue
		var xf: Transform3D = node.global_transform
		var half_len := float(row["size"][0]) * 0.5
		var reach := Vector2(float(row["size"][0]), float(row["size"][2])).length() * 0.5
		var at := Vector2(xf.origin.x, xf.origin.z)
		if at.x + reach < lo.x or at.x - reach > hi.x or at.y + reach < lo.y or at.y - reach > hi.y:
			continue
		out.append({"xf": xf, "hw": float(row["size"][2]) * 0.5, "hl": half_len, "rise": float(row["size"][1]),
			"dir": xf.basis.z.normalized(), "lip": xf * Vector3(0.0, float(row["size"][1]), half_len)})
	return out


static func _kicker_height(kickers: Array, p: Vector2) -> float:
	var top := -INF
	for k in kickers:
		var xf: Transform3D = k["xf"]
		var local: Vector3 = xf.affine_inverse() * Vector3(p.x, xf.origin.y, p.y)
		if absf(local.x) <= float(k["hw"]) and absf(local.z) <= float(k["hl"]):
			top = maxf(top, xf.origin.y + float(k["rise"]) * (local.z + float(k["hl"])) / (2.0 * float(k["hl"])))
	return top


func _activity_rushed() -> bool:
	var world = game.world
	if world == null or world.activities == null or world.activities.sites.is_empty():
		return false
	return game.run.stage_time > engage_by


func _site_key(s) -> String:
	if s.has_meta("find"):
		return "find:%s" % s.get_meta("find")
	return "door:%s" % s.id if s.has_meta("door") else String(s.id)


func _site_by_key(activities, key: String):
	for c in activities.sites:
		if is_instance_valid(c) and _site_key(c) == key:
			return c
	return null


func _activity_open(s) -> bool:
	if _activity_skip.has(_site_key(s)):
		return false
	var put_off = _activity_deferred.get(_site_key(s))
	if put_off is Vector3 and _flat(game.player.ball_position(), put_off) < ACTIVITY_RETRY_MOVE:
		return false
	return not s.done or (s.pickup != null and not s.pickup_taken)


func _pack_foe(s, ball: Vector3) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for enemy in s.pack:
		if is_instance_valid(enemy) and not (enemy.has_method("is_dead") and enemy.is_dead()):
			var d := _flat(ball, enemy.global_position)
			if d < best_d:
				best_d = d
				best = enemy
	return best


func _pay_roll(s, ball: Vector3, delta: float) -> void:
	if s.pickup == null:
		return
	var at: Vector3 = s.pickup.global_position
	var steer := at
	if s.inside_pickup or _flat(ball, at) < 1.0:
		steer = at + Vector3(PAY_BACKOFF, 0.0, 0.0)
	_act(steer, _nearest_enemy(), delta)


func _cache_ram(s, ball: Vector3, delta: float) -> void:
	var out: Vector3 = s.global_basis.z
	out.y = 0.0
	out = out.normalized()
	if engage_by > ENGAGE_BY and not s.has_meta("find") and _flat(ball, s.global_position) > ACTIVITY_NEAR + CACHE_RUNUP:
		_goal = "activity %s approach" % s.id
		_act(_approach(s, ball), _nearest_enemy(), delta)
		return
	_cache_clock += delta
	if _cache_phase == "runup":
		var runup: float = CACHE_RUNUP * (2.0 if engage_by > ENGAGE_BY else 1.0)
		var point: Vector3 = _ground_point(s.global_position.x + out.x * runup, s.global_position.z + out.z * runup)
		_goal = "activity %s runup" % s.id
		if s.has_meta("find") and _find_leg(s, ball, point, delta):
			return
		var heading := point
		if _flat(ball, point) > CACHE_STAGE and absf(ball.z - point.z) > CACHE_STAGE:
			heading = _ground_point(point.x, ball.z)
		_act(heading, null, delta)
		if _flat(ball, point) < 5.0 or _cache_clock > CACHE_RUNUP_SECONDS:
			_cache_phase = "ram"
			_cache_clock = 0.0
			if engage_by > ENGAGE_BY:
				var key := _site_key(s)
				_ram_tries[key] = int(_ram_tries.get(key, 0)) + 1
				if int(_ram_tries[key]) > RAM_TRIES:
					_activity_skip[key] = true
					_activity = ""
		return
	_goal = "activity %s ram" % s.id
	_ignore_walls = true
	var through: Vector3 = s.global_position - out * 4.0
	_act(Vector3(through.x, ball.y, through.z), null, delta, null, false)
	if _cache_clock > CACHE_RAM_SECONDS * (2.0 if engage_by > ENGAGE_BY else 1.0):
		_cache_phase = "runup"
		_cache_clock = 0.0


func _find_leg(s, ball: Vector3, point: Vector3, delta: float) -> bool:
	var key := _site_key(s)
	if _find_route_for != key:
		_find_route_for = key
		_find_route = _graph_path(ball, point)
		_find_leg_clock = 0.0
	while not _find_route.is_empty() and _flat(ball, _find_route[0]) < WAYPOINT_REACHED:
		_find_route.pop_front()
		_find_leg_clock = 0.0
	if _find_route.is_empty():
		return false
	_find_leg_clock += delta
	if _find_leg_clock > FIND_LEG_SECONDS:
		_activity_skip[key] = true
		_activity = ""
		_find_route = []
		return true
	_cache_clock = 0.0
	_goal = "activity %s path %d" % [s.id, _find_route.size()]
	_act(_find_route[0], _nearest_enemy(), delta)
	return true


func _graph_path(from: Vector3, to: Vector3) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var graph = game.world.activities.get("_graph") if game.world != null and game.world.activities != null else null
	if graph == null:
		return out
	var start: int = graph.nearest(Vector2(from.x, from.z))
	var goal: int = graph.nearest(Vector2(to.x, to.z))
	var prev: PackedInt32Array = graph.search_prev(start)["prev"]
	var nodes: Array[int] = []
	var at := goal
	while at != -1 and at != start and nodes.size() < 4096:
		nodes.push_front(at)
		at = prev[at]
	if at != start:
		return out
	var since := 0.0
	var last: Vector3 = graph.position(start)
	for node in nodes:
		var p: Vector3 = graph.position(node)
		since += _flat(last, p)
		last = p
		if since >= FIND_LEG_M:
			out.append(p)
			since = 0.0
	return out


func _event_goal(delta: float) -> Dictionary:
	var world = game.world
	if world == null or world.events == null:
		return {}
	for offer in world.events.offers:
		var id: String = offer["id"]
		if _event_skip.has(id):
			continue
		var phase: int = offer["phase"]
		var model = offer["model"]
		if phase == EventDirector.LIVE:
			return {"goal": "live " + id, "steer": _live_target(id, model), "aim": _nearest_enemy()}
		if phase == EventDirector.ANNOUNCED or phase == EventDirector.ARMED:
			if game.run.stage_time > EVENT_LATEST + maxf(0.0, engage_by - ENGAGE_BY):
				continue
			_event_time[id] = float(_event_time.get(id, 0.0)) + delta
			if _event_time[id] > EVENT_PURSUIT_SECONDS:
				_event_skip[id] = true
				continue
			var ring: Vector2 = model.ring
			return {"goal": "ring " + id, "steer": game.ctx.terrain.drop_point(ring.x, ring.y, 1.0), "aim": _nearest_enemy()}
		if phase == EventDirector.COOLDOWN:
			_event_skip[id] = true
	return {}


func _live_target(id: String, model) -> Vector3:
	var ball: Vector3 = game.player.ball_position()
	match id:
		"scrap_stampede":
			return model.hauler_position()
		"surge_run":
			var next: int = clampi(model.next_gate, 0, model.gates.size() - 1)
			var g: Vector2 = model.gates[next]
			return game.ctx.terrain.drop_point(g.x, g.y, 1.0)
		"hold_the_relay":
			var relay: Vector2 = model.relay
			var out := Vector2(ball.x - relay.x, ball.z - relay.y)
			if out.length() < 0.5:
				out = Vector2(1.0, 0.0)
			var around := out.normalized().rotated(0.7) * 12.0
			return game.ctx.terrain.drop_point(relay.x + around.x, relay.y + around.y, 1.0)
	var ring: Vector2 = model.ring
	return game.ctx.terrain.drop_point(ring.x, ring.y, 1.0)


func _plating(target: Node3D) -> float:
	var spawner = game.ctx.spawner
	if spawner != null and spawner.has_method("plating_of"):
		return float(spawner.plating_of(target))
	if target.has_method("plating_now"):
		return float(target.plating_now())
	return 0.0


func _fight(target: Node3D, delta: float) -> void:
	_welcome_ring_at = Vector3.INF
	if target == null or not is_instance_valid(target):
		_goal = "beacon"
		_act(game.flow.beacon.global_position, _nearest_enemy(), delta)
		return
	if target != _fight_target:
		_fight_target = target
		_fight_phase = "charge"
		_reset_charge_watch()
	if target == game.flow.warden and _note.get("warden_fight_s") == null:
		_note["warden_fight_s"] = snappedf(game.run.stage_time, 0.01)
		_note["warden_fight_heft"] = snappedf(game.run.heft(), 0.001)
		if engage_by > ENGAGE_BY and not _note.has("explore_clock_hit"):
			_note["explore_clock_hit"] = false
	var short: bool = _punch_seen < _plating(target)
	if short:
		_count("punch_short_s", delta)
	_note_shred(target, delta)
	if _anchor_warden(target) and (_kit("harpoon") or _sheet_warden(target)):
		_anchor_fight(target, short, delta)
		return
	_ground_fight(target, short, delta)


func _ground_fight(target: Node3D, short: bool, delta: float) -> void:
	var caps: bool = target.has_method("cap_points") and not (target.cap_points() as Array).is_empty()
	if caps and short and _kit("weak_points"):
		_goal = "caps %s" % target.get("kind")
		_cap_loop(target, delta)
		return
	_goal = "fight %s %s%s" % [target.get("kind"), _fight_phase, " short" if short else ""]
	_ram_laps(target, _aim_node(target, short), delta)


func _anchor_warden(target) -> bool:
	return target != null and is_instance_valid(target) and target.get("harpoon_anchor") == true


func _is_flume_warden(target) -> bool:
	return target != null and is_instance_valid(target) \
			and target.get("family") == "reactor" and target.get("mounting") == "flume"


func _is_flume_stage() -> bool:
	if _is_flume_warden(_fight_target) or _is_flume_warden(_anchor_target):
		return true
	if game != null and game.flow != null:
		if _is_flume_warden(game.flow.warden):
			return true
		if game.flow.has_method("stage_def") and String(game.flow.stage_def().get("map", "")) == "park_flume":
			return true
	return false


func _sheet_warden(target: Node3D) -> bool:
	return target.get("family") == "reactor" and target.get("mounting") == "dam_face" \
			and target.spec.get("park_landmark", false) and target.mount_driver != null \
			and target.mount_driver.has_method("sheet_live")


func skip_activity(key: String) -> void:
	_activity_skip[key] = true


func hold_off_warden_line(seconds: float) -> void:
	_line_hold_off = maxf(_line_hold_off, seconds)


func _anchor_fight(target: Node3D, short: bool, delta: float) -> void:
	var kit = game.player.kit
	var ball: Vector3 = game.player.ball_position()
	var at: Vector3 = target.global_position
	if target != _anchor_target:
		_anchor_target = target
		_anchor_last_y = at.y
		_anchor_lined = false
		_anchor_below = 0.0
		_haul_made = false
		_haul_pressed_above = false
		_drop_jumped = false
		_anchor_seen_hung = false
	_anchor_vy = (at.y - _anchor_last_y) / maxf(delta, 0.0001)
	_anchor_last_y = at.y
	var staggered: bool = target.staggered()
	_anchor_seen_hung = _anchor_seen_hung or _anchor_hung(target)
	_watch_haul(target, staggered)
	var lined: bool = kit.hooked and kit.on_body and kit.anchor_body == target
	if lined and not _anchor_lined:
		_count("latch_bites")
		if not game.player.state.grounded:
			_count("latch_bites_air")
	_anchor_lined = lined
	if _sheet_warden(target):
		var sheet = target.mount_driver
		var dir: Vector3 = sheet.sheet_dir if sheet.sheet_dir != Vector3.ZERO else sheet._face_heading(target)
		var runup: float = minf(RUNUP, float(sheet.SHEET_RUN) - RUNUP_EDGE)
		var foot: Vector3 = at + dir * runup + dir.cross(Vector3.UP) * sheet.lane_offset()
		var live: bool = sheet.sheet_live()
		if kit.hooked:
			source.press["harpoon_released"] = true
		var until_pulse: float = target._charge_len - target._charge_time if target._charging else target.cycle_now() - target._pulse_clock
		if live and sheet.entered_sheet_cycle == sheet.gates_opened and game.player.body().get_colliding_bodies().has(target):
			_fight_phase = "sheet return %d" % sheet.gates_opened
		var rammed: bool = _fight_phase == "sheet return %d" % sheet.gates_opened
		var launching: bool = (live and (not rammed or staggered)) or (not live and target._charging and until_pulse <= DROP_WAIT)
		var timed := _sheet_timed()
		if not timed:
			if not live:
				_sheet_live_s = -1.0
			elif _sheet_live_s < 0.0:
				_sheet_live_s = 0.0
			else:
				_sheet_live_s += delta
			var seen: bool = live and _sheet_live_s >= _reaction() \
					and band.reads(target.get_instance_id() * 1000 + int(sheet.gates_opened))
			launching = seen and (not rammed or (staggered and _kit("weak_points")))
		var steer: Vector3 = target.family_point_at() if launching else _ground_point(foot.x, foot.z)
		_harpoon_held = false
		_harpoon_commit = false
		_anchor_below = 0.0
		if _flat(ball, foot) > SHEET_HAND_REACH:
			_goal = "roll to spillway sheet"
			_act(steer, target, delta, target)
			return
		_goal = "ride spillway sheet" if live else "wait spillway sheet"
		if trace and ticks % (Engine.physics_ticks_per_second / 4) == 0:
			var bv: Vector3 = game.player.body().linear_velocity
			print("    sheet t=%.2f live=%s launch=%s phase=%s ball=(%.1f, %.1f, %.1f) v=(%.1f, %.1f, %.1f) grounded=%s posture=%.1f staggered=%s entered=%d gates=%d riding=%s foot=(%.1f, %.1f)" % [
				game.run.stage_time, live, launching, _fight_phase, ball.x, ball.y, ball.z, bv.x, bv.y, bv.z,
				game.player.state.grounded, target.posture(), staggered, sheet.entered_sheet_cycle, sheet.gates_opened, sheet.riding, foot.x, foot.z])
		var boost_clock := _boost_clock
		var ignore_walls := _ignore_walls
		_boost_clock = maxf(_boost_clock, delta)
		_ignore_walls = launching
		_slow_time = 0.0
		_detour_time = 0.0
		var hold_fire: bool = timed and (staggered or float(target.posture()) >= SHEET_HOLD_FIRE)
		_sheet_hold_fire = hold_fire
		_act(steer, target, delta, target, not timed)
		_sheet_hold_fire = false
		_ignore_walls = ignore_walls
		_boost_clock = boost_clock
		if hold_fire:
			source.hold.erase("fire_held")
			source.press.erase("fire_pressed")
			source.press.erase("ultimate_pressed")
			source.press.erase("active_pressed")
		var offset := Vector3(steer.x - ball.x, 0.0, steer.z - ball.z)
		var planar: Vector3 = game.player.planar_velocity()
		var desired := offset.normalized() * minf(game.player.tuning.f("cruise"), offset.length() * RUNUP_DROP)
		var change := desired - planar
		var wish := change.normalized() if change.length() > game.player.tuning.RADIUS / RUNUP_DROP else Vector3.ZERO
		var yaw: float = game.camera.yaw
		var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
		var right := Vector3(cos(yaw), 0.0, -sin(yaw))
		source.hold["move"] = Vector2(wish.dot(right), wish.dot(forward))
		if not launching:
			source.press.erase("shift_pressed")
			source.hold.erase("shift_held")
			_boost_clock = 0.0
			_shift_left = 0.0
			if game.player.state.grounded and _flat(ball, foot) <= RUNUP_EDGE:
				source.hold["brake_held"] = true
		else:
			source.hold.erase("brake_held")
			if live and ball.y >= target.family_point_at().y:
				source.hold["brake_held"] = true
			var at_core: bool = planar.dot(dir) <= 0.0 \
					and (planar.length() <= 1.0 or planar.normalized().dot(offset.normalized()) >= SHEET_LAUNCH_LINED)
			if at_core and _boost_clock <= 0.0 and game.player.state.grounded and game.player.verb_ready("boost"):
				source.press["shift_pressed"] = true
				source.hold["shift_held"] = true
				_boost_clock = BOOST_GAP
				_shift_left = SHIFT_HOLD
		return
	if _line_hold_off > 0.0:
		if kit.hooked:
			source.press["harpoon_released"] = true
		_harpoon_held = false
		_harpoon_commit = false
		_goal = "line home for the call"
		_act(at, target, delta, target)
		return
	if lined:
		_anchor_ride(target, staggered, ball, delta)
		return
	_anchor_below = 0.0
	if kit.hooked:
		source.press["harpoon_released"] = true
	if staggered:
		_anchor_open(target, short, ball, delta)
		return
	var finish := _line_finish(target)
	if not _anchor_hung(target) and not finish:
		_ground_fight(target, short, delta)
		return
	_goal = "latch %s%s" % [target.get("kind"), " finish" if finish else ""]
	if not kit.hooked:
		_anchor_bite(target, ball)
	var away := Vector3(ball.x - at.x, 0.0, ball.z - at.z)
	if away.length() < 0.5:
		away = Vector3.FORWARD
	var dy := maxf(0.0, at.y - ball.y)
	var reach_cap := sqrt(maxf(0.0, (LATCH_REACH - 3.0) * (LATCH_REACH - 3.0) - dy * dy))
	var standoff := clampf(dy * LATCH_STANDOFF, LINE_FINISH_STANDOFF if finish else 0.0, minf(LATCH_STANDOFF_MAX, reach_cap))
	_act(at + away.normalized() * standoff, target, delta, target)


func _line_finish(target: Node3D) -> bool:
	return _anchor_seen_hung and target.has_method("posture") and float(target.posture()) >= LINE_FINISH


func _anchor_hung(target: Node3D) -> bool:
	var at: Vector3 = target.global_position
	var floor_y: float = _ground_point(at.x, at.z).y - 1.0
	return _anchor_vy > ANCHOR_MOVING or (at.y - floor_y > HUNG_ABOVE and _anchor_vy > -ANCHOR_MOVING)


func _anchor_bite(target: Node3D, ball: Vector3) -> void:
	var kit = game.player.kit
	var swallowed: bool = game.player.frozen() or kit.slingshot.charging
	var special = game.player.abilities.gauge(AbilityState.SPECIAL)
	if special != null and special.charging:
		swallowed = true
	if swallowed or kit.rewind_left > 0.0 or kit.aim.get("body") != target or ball.distance_to(target.global_position) > LATCH_REACH:
		return
	if not (not _is_flume_warden(target) and target.has_method("staggered") and target.staggered()):
		_cast(3)
	source.press["harpoon_pressed"] = true
	_harpoon_held = true
	_count("latch_presses")


func _anchor_open(target: Node3D, short: bool, ball: Vector3, delta: float) -> void:
	var point := _open_point(target)
	var grounded: bool = game.player.state.grounded
	var spent: bool = _drop_jumped and not grounded and game.player.state.air_actions <= 0 and game.player.state.velocity.y < 0.0
	var beyond_jump := point.y - ball.y > DROP_REACH_UP
	var high_deck := grounded and ball.y > point.y + LEVEL_BAND
	if high_deck:
		_act(point, target, delta, target)
		_goal = "tipple drop"
		if _flat(ball, point) <= 22.0 and game.player.verb_ready("jump"):
			source.press["jump_pressed"] = true
			_drop_jumped = true
		_anchor_bite(target, ball)
		return
	var bite := (not grounded and ball.y > point.y + DROP_ABOVE) or spent or (grounded and _drop_jumped) or beyond_jump
	_ground_fight(target, short, delta)
	_goal = "drop climb"
	if bite:
		_anchor_bite(target, ball)
	elif grounded and _flat(ball, point) < DROP_JUMP_REACH and game.player.verb_ready("jump"):
		source.press["jump_pressed"] = true
		_drop_jumped = true
	elif not grounded and _drop_jumped and game.player.state.velocity.y < 1.0 and game.player.state.air_actions > 0:
		source.press["jump_pressed"] = true


func _open_point(target: Node3D) -> Vector3:
	return target.family_point_at() if target.has_method("family_point_at") else target.global_position


func _anchor_ride(target: Node3D, staggered: bool, ball: Vector3, delta: float) -> void:
	var kit = game.player.kit
	_count("latch_ride_s", delta)
	_harpoon_held = true
	if staggered:
		var point := _open_point(target)
		var above := ball.y > point.y + DROP_ABOVE
		if kit.line_state == Augments.LINE_SMASH:
			_goal = "haul"
			_harpoon_commit = true
			if not _haul_made:
				_haul_made = true
				_haul_above = _haul_pressed_above
				_haul_chunks = int(target.chunks_left())
				_count("latch_hauls")
				if _haul_above:
					_count("drop_hauls")
				if trace:
					print("    haul t=%.2f above=%s ball=%s point=%s stagger_left=%.2f" % [game.run.stage_time, _haul_above, ball,
						point, target.stagger_left()])
		elif above or _anchor_below > DROP_WAIT:
			_goal = "drop" if above else "haul from below"
			_harpoon_commit = not game.player._brake_was_held
			_haul_pressed_above = above
		else:
			_goal = "drop wait"
			_anchor_below += delta
		_act(point, target, delta, target, false)
		return
	_anchor_below = 0.0
	if not _anchor_hung(target) and _anchor_vy > -ANCHOR_MOVING and not _line_finish(target):
		_goal = "latch let go"
		source.press["harpoon_released"] = true
		_harpoon_held = false
		_ground_fight(target, _punch_seen < _plating(target), delta)
		return
	_goal = "ride %s" % target.get("kind")
	_act(target.global_position, target, delta, target)


func _watch_haul(target: Node3D, staggered: bool) -> void:
	var left := int(target.chunks_left())
	if trace and _anchor_chunks_seen >= 0 and left < _anchor_chunks_seen:
		print("    chunk t=%.2f left=%d haul=%s above=%s line=%s" % [game.run.stage_time, left, _haul_made, _haul_above,
			game.player.kit.line_state])
	_anchor_chunks_seen = left
	if _haul_made and left < _haul_chunks:
		_count("latch_chunks", float(_haul_chunks - left))
		if _haul_above:
			_count("drop_chunks", float(_haul_chunks - left))
		_haul_chunks = left
	if not staggered:
		_haul_made = false
		_haul_pressed_above = false
		_drop_jumped = false


func _note_shred(target: Node3D, delta: float) -> void:
	var spawner = game.ctx.spawner
	if target != game.flow.warden or spawner == null or not spawner.has_method("shred_of"):
		return
	var plating: float = float(target.get("plating"))
	if plating <= 0.0:
		return
	var share: float = spawner.shred_of(target) / plating
	_note["shred_peak"] = snappedf(maxf(float(_note.get("shred_peak", 0.0)), share), 0.01)
	if share >= 0.5:
		_note["stripped_half_s"] = snappedf(float(_note.get("stripped_half_s", 0.0)) + delta, 0.01)


func _harpoon_hand(target: Node3D, delta: float) -> void:
	if not _kit("harpoon"):
		return
	var kit = game.player.kit
	var bank_shot: bool = game.player.abilities.id_of(AbilityState.LINE) == "bank_shot"
	if _cast_phase == "await_smash":
		_cast_phase = ""
	if _smash_pending():
		if _cast_phase == "":
			_cast_slot = 3
			_cast_phase = "await_smash"
	elif bank_shot and kit.hooked and kit.on_body and is_instance_valid(kit.anchor_body):
		_cast(3)
	_harpoon_commit = false
	_off_line = 0.0 if _flat(game.player.ball_position(), target.global_position) > LINE_REACH else _off_line + delta
	if kit.hooked and not kit.on_body:
		source.press["harpoon_released"] = true
		_harpoon_held = false
		return
	if kit.hooked and kit.on_body and is_instance_valid(kit.anchor_body):
		_harpoon_held = true
		_harpoon_commit = not (kit.on_body and kit.line_state == Augments.LINE_LATCHED \
			and game.player._brake_was_held)
		return
	_harpoon_held = false
	var swallowed: bool = game.player.frozen() or kit.slingshot.charging
	var special = game.player.abilities.gauge(AbilityState.SPECIAL)
	if special != null and special.charging:
		swallowed = true
	if not swallowed and kit.aim.get("body") == target and kit.rewind_left <= 0.0 and game.player.state.grounded \
			and (_off_line > DROP_MEMORY or (_weak_go and is_instance_valid(_weak_warden) and target == _weak_warden)) and _flat(game.player.ball_position(), target.global_position) <= HARPOON_FLOOR:
		if _bite_passes(target) and not _chain_takeoff(target):
			if _pass_bite_blocked(target):
				return
			_pass_bite_frame = Engine.get_physics_frames()
		if not bank_shot:
			_cast(3)
		source.press["harpoon_pressed"] = true
		_harpoon_held = true
		if _chain_takeoff(target):
			var second := _chain_partner(target)
			if second != null:
				_chain_phase = "takeoff"
				_chain_first = target
				_chain_second = second
				_chain_rose = false
				_chain_launch_y = game.player.ball_position().y
				source.press.erase("harpoon_pressed")
				_harpoon_held = false
				source.press["jump_pressed"] = true
		if source.press.get("harpoon_pressed", false):
			_count("harpoon_bites")


func _chain_takeoff(target: Node3D) -> bool:
	return chain_hand_enabled and _kit("chain") and policy == "completionist" and not _in_boss() \
			and target != game.flow.warden and target.is_in_group("enemy") and game.player.verb_ready("jump") \
			and _chain_partner(target) != null


func _pass_bite_blocked(target: Node3D) -> bool:
	if game.player.abilities.id_of(AbilityState.LINE) == "cable_charge" and target.get("role") == "hull":
		return true
	return Engine.get_physics_frames() - _pass_bite_frame < roundi(PASS_BITE_GAP_S * Engine.physics_ticks_per_second)


func _bite_passes(target: Node3D) -> bool:
	if Augments.anchor_line(target) or Grip.of(target, game.player.heft(), game.player.enemy_heft(target), game.player.tuning.pole_flail()) in ["pole", "flail"]:
		return false
	var radius = target.get("radius")
	var passing: float = Augments.MIN_ROPE + Tuning.RADIUS + (float(radius) if radius != null else 0.0)
	return game.player.ball_position().distance_to(target.global_position) <= passing


func _smash_pending() -> bool:
	var kit = game.player.kit
	if game.player.abilities.id_of(AbilityState.LINE) != "bank_shot" \
			or not kit.hooked or not kit.on_body or not is_instance_valid(kit.anchor_body):
		return false
	var guarded: bool = kit.anchor_body.has_method("posture") and kit.anchor_body.has_method("staggered")
	return not (kit.line_state == Augments.LINE_SMASH and (not guarded or kit.anchor_body.staggered()))


func _await_smash_holds() -> bool:
	var target: Node3D = _fight_target if is_instance_valid(_fight_target) else _anchor_target
	if _smash_pending() and not _anchor_warden(target):
		return true
	_cast_phase = ""
	return false


func _clear_chain_hand() -> void:
	_chain_phase = ""
	_chain_first = null
	_chain_second = null
	_chain_rose = false


func _on_explorer_line(state: String, _target: Node3D, _at: Vector3, _cause: String) -> void:
	if state == "let_go" and _chain_phase == "second":
		_count("chain_releases")
	elif state == "broke" and _chain_phase in ["first", "rise"]:
		_count("chain_breaks_" + _cause)
	elif state == "chain_end" and not game.player.chain.finished.is_empty():
		_count("chain_ends_" + String(game.player.chain.finished.back()["cause"]))


func _chain_partner(first: Node3D) -> Node3D:
	var ball: Vector3 = game.player.ball_position()
	var nearest: float = game.player.tuning.f("rope_range")
	var second: Node3D = null
	for enemy in game.get_tree().get_nodes_in_group("enemy"):
		if enemy == first or not enemy is Node3D or not is_instance_valid(enemy):
			continue
		if not Augments.hookable_body(enemy):
			continue
		var distance := ball.distance_to(enemy.global_position)
		if distance < nearest:
			nearest = distance
			second = enemy
	return second


func _explorer_chain(delta: float) -> void:
	var player = game.player
	var kit = player.kit
	if not is_instance_valid(_chain_second) or (_chain_second.has_method("is_dead") and _chain_second.is_dead()):
		var first: Node3D = _chain_first if is_instance_valid(_chain_first) else null
		_chain_second = _chain_partner(first)
	if _chain_second == null or player.frozen() or (_chain_phase != "takeoff" and not player.chain.active()):
		_clear_chain_hand()
		source.hold = {}
		return
	_goal = "two-hook %s" % _chain_phase
	_harpoon_held = false
	_harpoon_commit = false
	match _chain_phase:
		"takeoff":
			var up: float = player.body().linear_velocity.y
			_chain_rose = _chain_rose or (not player.state.grounded and up > 0.0)
			if not is_instance_valid(_chain_first) or (_chain_rose and up <= 0.0):
				_clear_chain_hand()
				source.hold = {}
				return
			if not player.state.grounded and player.ball_position().y > _chain_launch_y + Tuning.RADIUS \
					and kit.aim.get("body") == _chain_first and player.verb_ready("harpoon"):
				_chain_phase = "first"
				source.press["harpoon_pressed"] = true
				_harpoon_held = true
				_count("harpoon_bites")
		"first", "rise":
			_chain_phase = "rise"
			var up: float = player.body().linear_velocity.y
			_chain_rose = _chain_rose or (not player.state.grounded and up > 0.0)
			if not kit.hooked or (_chain_rose and up <= 0.0):
				if kit.hooked:
					source.press["harpoon_released"] = true
				_chain_phase = "second"
			else:
				_harpoon_held = true
		"second":
			if kit.hooked and kit.anchor_body == _chain_second:
				_chain_phase = "smash"
				_harpoon_held = true
				_harpoon_commit = true
			elif player.chain.grace_left > 0.0 and not player.state.grounded \
					and kit.aim.get("body") == _chain_second and player.verb_ready("harpoon"):
				source.press["harpoon_pressed"] = true
				_harpoon_held = true
				_count("harpoon_bites")
		"smash":
			_harpoon_held = kit.hooked
			_harpoon_commit = kit.hooked
			if not kit.hooked:
				_clear_chain_hand()
	_chain_drive(delta)


func _chain_drive(delta: float) -> void:
	_chain_driving = true
	_drive(game.player.ball_position(), _chain_first if _chain_phase == "takeoff" else _chain_second, delta)
	_chain_driving = false
	source.hold.erase("fire_held")
	source.hold.erase("shift_held")
	source.press.erase("shift_pressed")


func _ram_laps(target: Node3D, aim, delta: float) -> void:
	if not _anchor_warden(target):
		_harpoon_hand(target, delta)
	var ball: Vector3 = game.player.ball_position()
	var at: Vector3 = target.global_position
	var distance := _flat(ball, at)
	var close := CHARGE_CLOSE
	if target.get("role") == "hull":
		close = maxf(close, float(target.get("radius")) + Augments.MIN_ROPE + 3.0)
	match _fight_phase:
		"charge":
			if distance < close:
				_fight_phase = "runup"
				_runup_time = 0.0
				var away := Vector3(ball.x - at.x, 0.0, ball.z - at.z)
				if away.length() < 0.5:
					away = Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0))
				away = away.normalized().rotated(Vector3.UP, rng.randf_range(-0.7, 0.7))
				var run := RUNUP
				while run > RUNUP_MIN and not _runup_on_shelf(at, away, run):
					run -= RUNUP_STEP
				_runup_point = _ground_point(at.x + away.x * run, at.z + away.z * run)
			elif target == game.flow.warden:
				_charge_watch(ball, at, distance, delta)
		"runup":
			_runup_time += delta
			if _flat(ball, _runup_point) < 4.0 or _runup_time > RUNUP_SECONDS:
				_fight_phase = "charge"
		"recover":
			_recover_time += delta
			if _flat(ball, _recover_legs[0]) < RECOVER_REACHED or _recover_time > RECOVER_LEG_SECONDS:
				_recover_legs.pop_front()
				_recover_time = 0.0
				if _recover_legs.is_empty():
					_fight_phase = "charge"
				elif not _recover_wall:
					source.press["jump_pressed"] = true
			_recover_climb = _fight_phase == "recover" and _recover_wall and _recover_legs.size() == 1
			if _recover_climb:
				_wall_jump(ball, _recover_legs[0])
	var steer: Vector3 = at
	if _fight_phase == "runup":
		steer = _runup_point
	elif _fight_phase == "recover":
		steer = _recover_legs[0]
	if _fight_phase != "recover" and _climbing(ball, at):
		steer = _fight_way_up(ball, at, delta)
		_goal += " climb"
	else:
		_fight_climb.clear()
		_fight_climb_clock = 0.0
	_act(steer, aim, delta, target)
	_recover_climb = false


func _reset_charge_watch() -> void:
	_charge_best = INF
	_charge_clock = 0.0
	_recover_legs = []
	_recover_time = 0.0
	_recover_wall = false
	_recover_climb = false


func _charge_watch(ball: Vector3, at: Vector3, distance: float, delta: float) -> void:
	if distance <= RUNUP or _climbing(ball, at):
		_charge_best = INF
		_charge_clock = 0.0
		return
	if distance < _charge_best - CHARGE_PROGRESS:
		_charge_best = distance
		_charge_clock = 0.0
		return
	_charge_clock += delta
	if _charge_clock < CHARGE_WINDOW or _recoveries >= RECOVER_LIMIT:
		return
	_recoveries += 1
	_count("charge_recoveries")
	_charge_best = INF
	_charge_clock = 0.0
	_recover_legs = _charge_escape(ball, at)
	_recover_time = 0.0
	_fight_phase = "recover"
	source.press["jump_pressed"] = true


func _charge_escape(ball: Vector3, at: Vector3) -> Array[Vector3]:
	var toward := Vector3(at.x - ball.x, 0.0, at.z - ball.z).normalized()
	var ahead := _face_ahead(ball, toward, RECOVER_PROBE)
	_recover_wall = ahead < INF
	if _recover_wall:
		var room := minf(RECOVER_BACK_MAX, _face_ahead(ball, -toward, RECOVER_BACK_MAX) - RECOVER_JUMP_AT)
		var from := ball - toward * maxf(room, RECOVER_JUMP_AT)
		var over := ball + toward * (ahead + RECOVER_OVER)
		var climb: Array[Vector3] = [_ground_point(from.x, from.z), _ground_point(over.x, over.z)]
		return climb
	var back := ball - toward * RECOVER_BACK
	var best := Vector3.INF
	var best_score := -INF
	for turn in [PI * 0.5, -PI * 0.5]:
		var side := _ground_point(back.x, back.z) + toward.rotated(Vector3.UP, turn) * RECOVER_SIDE
		side = _ground_point(side.x, side.z)
		var score := -_flat(side, at)
		if _way_clear(side, side + toward * RECOVER_SIDE):
			score += 1000.0
		if score > best_score:
			best_score = score
			best = side
	var out: Array[Vector3] = [_ground_point(back.x, back.z), best]
	return out


func _wall_jump(ball: Vector3, over: Vector3) -> void:
	var state = game.player.state
	if state.grounded:
		var toward := Vector3(over.x - ball.x, 0.0, over.z - ball.z).normalized()
		if _face_ahead(ball, toward, RECOVER_JUMP_AT) < INF:
			source.press["jump_pressed"] = true
	elif state.air_actions > 0 and state.velocity.y < 1.0:
		source.press["jump_pressed"] = true


func _face_ahead(from: Vector3, dir: Vector3, reach: float) -> float:
	var space = game.get_world_3d().direct_space_state
	var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + dir * reach, 1))
	if hit.is_empty() or absf((hit["normal"] as Vector3).y) >= WALL_TILT:
		return INF
	return _flat(from, hit["position"])


func _way_clear(from: Vector3, to: Vector3) -> bool:
	var space = game.get_world_3d().direct_space_state
	var lift := Vector3.UP * 0.2
	var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(from + lift, to + lift, 1))
	return hit.is_empty() or absf((hit["normal"] as Vector3).y) >= WALL_TILT


func _climbing(ball: Vector3, at: Vector3) -> bool:
	if at.y - ball.y > LEVEL_BAND:
		return true
	return not _fight_climb.is_empty() and _ground_point(at.x, at.z).y - _ground_point(ball.x, ball.z).y > CLIMB_LEVEL


func _dips(ball: Vector3, at: Vector3) -> bool:
	var terrain = game.ctx.terrain
	var low := minf(terrain.height(ball.x, ball.z), terrain.height(at.x, at.z)) - LEVEL_BAND
	var steps := int(_flat(ball, at) / CLIMB_STEP)
	for k in range(1, steps):
		var p := ball.lerp(at, float(k) / steps)
		if terrain.height(p.x, p.z) < low:
			return true
	return false


func _fight_way_up(ball: Vector3, at: Vector3, delta: float) -> Vector3:
	if _fight_climb_tick != ticks:
		_fight_climb_held = _fight_climb_held + delta if _fight_climb_tick == ticks - 1 else delta
		_fight_climb_tick = ticks
	if _fight_climb_held > MIND_CLIMB_GIVE_UP and _in_mind_stage() and not _mind_slope_spent:
		_mind_slope_spent = true
		_fight_climb_clock = 0.0
	_fight_climb_clock -= delta
	if _fight_climb_clock <= 0.0:
		_fight_climb = _climb_route_any(ball, at)
		_fight_climb_clock = FIGHT_CLIMB_REPLAN
	while not _fight_climb.is_empty() and _flat(ball, _fight_climb[0]) < CLIMB_REACHED:
		_fight_climb.pop_front()
	_kicker_jump(ball)
	return at if _fight_climb.is_empty() else _fight_climb[0]


func _kicker_jump(ball: Vector3) -> void:
	if not game.player.state.grounded or not game.player.verb_ready("jump"):
		return
	for lip in _route_lips:
		if _flat(ball, lip) < KICKER_JUMP_AT and ball.y > lip.y - KICKER_JUMP_AT:
			source.press["jump_pressed"] = true
			return


func _runup_on_shelf(at: Vector3, away: Vector3, run: float) -> bool:
	var floor_y: float = _ground_point(at.x, at.z).y
	var side := away.cross(Vector3.UP)
	for offset in [away * (run + RUNUP_EDGE), away * run + side * RUNUP_EDGE, away * run - side * RUNUP_EDGE]:
		if _ground_point(at.x + offset.x, at.z + offset.z).y < floor_y - RUNUP_DROP:
			return false
	return true


func _cap_loop(target: Node3D, delta: float) -> void:
	var ball: Vector3 = game.player.ball_position()
	var at: Vector3 = target.global_position
	_welcome_ring_at = at if game.run.hp > PULSE_HP_SHARE * game.run.max_hp else Vector3.INF
	var from_ball := Vector3(ball.x - at.x, 0.0, ball.z - at.z).normalized()
	var line := from_ball
	var best := -INF
	for cap in target.cap_points():
		var dir := Vector3(cap.x - at.x, 0.0, cap.z - at.z).normalized()
		if dir.dot(from_ball) > best:
			best = dir.dot(from_ball)
			line = dir
	var d := _flat(ball, at)
	var steer: Vector3 = at + line * CAP_BESIDE if d > CAP_JUMP + 2.0 else at
	_act(steer, target, delta, target)
	var v: Vector3 = game.player.state.velocity
	if game.player.state.grounded:
		if d < CAP_JUMP:
			source.press["jump_pressed"] = true
	elif d > CAP_INSIDE and d < CAP_JUMP + 1.0 and v.y < 2.0:
		source.hold["brake_held"] = true


func _aim_node(target: Node3D, short: bool):
	if short and _kit("weak_points") and target.has_method("weak_points") and not (target.weak_points() as Array).is_empty():
		return {"at": target.weak_points()[0]["at"]}
	return target


func _boss():
	var ctx = game.ctx
	var boss = ctx.get("boss") if "boss" in ctx else null
	if boss == null and ctx.has_meta("boss"):
		boss = ctx.get_meta("boss")
	if boss == null or not is_instance_valid(boss) or not boss.has_method("enter_arena"):
		return null
	return boss


func trace_snapshot() -> Dictionary:
	return {
		"boss": _boss(),
		"boss_clock": _boss_clock,
		"goal": _goal,
		"offers": _offers,
		"gate_pick": _gate_pick,
		"gate_time": _gate_time,
		"gate_run": _gate_run,
		"fight_climb_pts": _fight_climb.size(),
	}


func _fight_posture_boss(boss, delta: float) -> void:
	_read_weak_points(boss, delta)
	var target = boss.get("warden")
	if not boss.has_method("active") or not boss.active() or not is_instance_valid(target) or not target is Node3D:
		_goal = "boss wait"
		_act(game.player.ball_position() + game.player.planar_velocity(), null, delta)
		return
	var fitter := _open_fitter(boss)
	if fitter != null:
		_fight_fitter(fitter, delta)
		return
	var part := _open_part(boss)
	if part != null:
		_fight_part(part, delta)
		return
	_fight(target, delta)


func _open_part(boss) -> Node3D:
	if not _weak_go or not boss.has_method("weak_part"):
		return null
	var open: Array = boss.weak_open()
	return boss.weak_part(String(open[-1])) if not open.is_empty() else null


func _open_fitter(boss) -> Node3D:
	if not _weak_go or not boss.has_method("crew") or not boss.has_method("weak_open"):
		return null
	var open: Array = boss.weak_open()
	if open.is_empty():
		return null
	var id := String(open[-1])
	var weak = boss.get("weak")
	if weak != null and weak.fitters(id) < weak.fit_min:
		return null
	for f in boss.crew():
		if f.point_id != id or f.is_dead():
			continue
		if f.fit_state == f.State.FITTING:
			return f
	return null


func _fight_fitter(fitter: Node3D, delta: float) -> void:
	_goal = "fitter %s" % fitter.point_id
	_weak_warden = fitter
	_harpoon_hand(fitter, delta)
	_act(fitter.global_position, fitter, delta, fitter)


func _fight_part(part: Node3D, delta: float) -> void:
	_goal = "part %s" % part.get("point_id")
	_weak_warden = part
	_harpoon_hand(part, delta)
	_act(part.global_position, part, delta, part)


static func weak_point_go(band_name: String, opened_age: float, roll: float) -> bool:
	match band_name:
		"expert":
			return true
		"learner":
			return opened_age >= 0.6 and roll < 0.5
	return false


func _read_weak_points(boss, delta: float) -> void:
	_weak_go = false
	var open: Array = boss.weak_open() if boss.has_method("weak_open") else []
	if open.is_empty():
		_weak_seen = ""
		_weak_warden = null
		return
	var id := String(open[-1])
	if id != _weak_seen:
		_weak_seen = id
		_weak_age = 0.0
		_weak_roll = rng.randf() if band != null and band.name == "learner" else 0.0
	_weak_age += delta
	_weak_go = weak_point_go(band.name if band != null else "expert", _weak_age, _weak_roll)
	_weak_warden = boss.get("warden") if _weak_go else null


func _fight_boss(delta: float) -> void:
	var boss = _boss()
	if boss_note.is_empty():
		_on_boss_entered()
	var ship = boss.get("ship")
	var arena = boss.get("arena")
	if ship == null:
		_fight_posture_boss(boss, delta)
		return
	if not boss.has_method("active") or not boss.active() or ship == null or not is_instance_valid(arena):
		_goal = "boss wait"
		_act(game.player.ball_position() + game.player.planar_velocity(), null, delta)
		return
	_ring_fight = boss
	var ball: Vector3 = game.player.ball_position()
	var hull: Node3D = ship.hull
	var punch: float = _punch_seen
	var phase: int = int(boss.phase)
	var scooter = boss.get("scooter")
	if scooter != null and is_instance_valid(scooter):
		_goal = "boss scooter"
		_ram_laps(scooter, scooter, delta)
		return
	var hold := _ring_hold(boss, arena, ball)
	if hold != Vector3.INF:
		_goal = "boss ring out"
		_act(hold, hull, delta, hull, arena.radius_of(ball) >= _rings.safe_radius())
		return
	var pickup := _nearest_pickup(boss, ball)
	if hull.has_method("fight") and hull.fight() == "posture":
		if pickup != Vector3.INF and not hull.staggered():
			_goal = "boss pickup"
			if game.player.kit.hooked:
				source.press["harpoon_released"] = true
			_act(pickup, hull, delta)
			return
		if hull.staggered():
			_goal = "boss open cockpit"
			_harpoon_hand(hull, delta)
			_act(hull.global_position, hull, delta, hull, false)
			if not game.player.kit.hooked and _flat(ball, hull.global_position) < hull.radius + 3.0:
				if game.player.state.grounded:
					source.press["jump_pressed"] = true
				else:
					source.hold["brake_held"] = true
			return
		if phase == 3 and _charge_plan(boss, hull, ball, punch, delta):
			return
		_fight(hull, delta)
		return
	match phase:
		1:
			var magnet: Node3D = _live_part(boss, ship.magnets, ball) if _kit("weak_points") else null
			if pickup != Vector3.INF:
				_goal = "boss pickup"
				_act(pickup, magnet if magnet != null else hull, delta)
			elif punch >= _plating(hull) or not _kit("weak_points"):
				_goal = "boss ram"
				_ram_laps(hull, magnet if magnet != null else hull, delta)
			else:
				_goal = "boss magnets"
				_act(_orbit_point(arena, ball, BOSS_ORBIT), magnet if magnet != null else hull, delta)
		2:
			if punch >= _plating(hull) or not _kit("weak_points"):
				_goal = "boss ram"
				_ram_laps(hull, hull, delta)
			else:
				_ramp_to_cap(boss, arena, ship, delta)
		_:
			if boss.has_method("stunned") and boss.stunned():
				_goal = "boss stunned"
				_ram_laps(hull, hull, delta)
			elif _charge_plan(boss, hull, ball, punch, delta):
				pass
			else:
				_goal = "boss bait"
				_act(arena.point_at(arena.angle_of(ball), BAIT_RADIUS), hull, delta, hull)


func _charge_lane(boss):
	var c = boss.get("_charge")
	if not c is Dictionary or not String(c.get("state", "")) in ["brace", "run"]:
		return null
	var h = c.get("hazard")
	if h == null or not is_instance_valid(h) or h.is_done():
		return null
	var id: int = h.get_instance_id()
	if not _seen.has(id):
		_seen[id] = ticks
		return null
	if float(ticks - int(_seen[id])) / float(Engine.physics_ticks_per_second) < _reaction():
		return null
	if band != null and not band.reads(id):
		return null
	if not _charge_read.has(id):
		_charge_read[id] = true
		_count("charge_reads")
	return h


func _charge_plan(boss, hull: Node3D, ball: Vector3, punch: float, delta: float) -> bool:
	var h = _charge_lane(boss)
	if h == null:
		return false
	var id: int = h.get_instance_id()
	var lateral: float = h.lane_lateral(ball)
	if _clash_viable(boss, h, ball, punch, id):
		if not _clash_tried.has(id):
			_clash_tried[id] = true
			_count("clash_tries")
		_goal = "boss clash"
		_act(hull.global_position, hull, delta, hull, false)
		return true
	_clash_latched.erase(id)
	if not _charge_stepped.has(id):
		_charge_stepped[id] = true
		_count("charge_sidesteps")
	var out: float = h.half_width + CHARGE_MARGIN
	var sign_side := 1.0 if lateral >= 0.0 else -1.0
	var along: float = h.lane_along(ball)
	var at: Vector3 = h.centre + h.heading * along + h.side() * sign_side * (out + 1.0)
	_goal = "boss sidestep"
	_act(Vector3(at.x, ball.y, at.z), hull, delta, hull, absf(lateral) >= h.half_width + 1.0)
	return true


func _clash_viable(boss, h, ball: Vector3, punch: float, id: int) -> bool:
	if band != null and band.kit != "full":
		return false
	var clash_punch: float = float(boss.get("clash_punch") if boss.get("clash_punch") != null else 150.0)
	if punch < clash_punch:
		return false
	var c: Dictionary = boss.get("_charge")
	var front: float = float(c.get("travelled", 0.0)) + Requisition.HULL.z * 0.5
	var gap: float = h.lane_along(ball) - front
	if gap < CLASH_MIN_GAP:
		return _clash_latched.has(id) and gap > 0.0
	var v: Vector3 = game.player.planar_velocity()
	var closing: float = -v.dot(h.heading)
	var wait: float = h.seconds_until_live() if not h.is_live() else 0.0
	var arrive: float = wait + gap / (BossRules.CHARGE_SPEED + maxf(closing, 0.0))
	var align: float = maxf(absf(h.lane_lateral(ball)) - CLASH_ALIGN, 0.0) / CLASH_ROLL
	var ok: bool = _clash_latched.has(id) or closing >= CLASH_SPEED
	ok = ok and (align <= 0.0 or align <= arrive - CLASH_SPARE)
	if ok:
		_clash_latched[id] = true
	return ok


func _live_part(boss, parts: Array, ball: Vector3) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for part in parts:
		if not is_instance_valid(part):
			continue
		if boss.has_method("target_live") and not boss.target_live(part):
			continue
		var d := ball.distance_to(part.global_position)
		if d < best_d:
			best_d = d
			best = part
	return best


func _nearest_pickup(boss, ball: Vector3) -> Vector3:
	if not boss.has_method("pickups_left"):
		return Vector3.INF
	var best := Vector3.INF
	var best_d := PICKUP_CHASE
	var rings := _brindle_rings(boss)
	for p in boss.pickups_left():
		var at: Vector3 = p["at"]
		var d := _flat(ball, at)
		if String(p.get("source", "")) == "shed" and d > SHED_CHASE and not _shed_ahead(ball, at):
			continue
		if rings.crosses(ball, at):
			continue
		if d < best_d:
			best_d = d
			best = at
	return best


func _shed_ahead(ball: Vector3, at: Vector3) -> bool:
	var v: Vector3 = game.player.planar_velocity()
	v.y = 0.0
	var to := at - ball
	to.y = 0.0
	if v.length() < SHED_ROLLING or to.length() < 0.01:
		return false
	return v.normalized().dot(to.normalized()) > SHED_AHEAD


func _orbit_point(arena, ball: Vector3, r: float) -> Vector3:
	return arena.point_at(arena.angle_of(ball) + 0.5, r)


func _ramp_to_cap(boss, arena, ship, delta: float) -> void:
	var ball: Vector3 = game.player.ball_position()
	var cap := _live_part(boss, ship.caps, ball)
	var hull: Node3D = ship.hull
	if cap != null and not game.player.state.grounded:
		var over := _flat(ball, cap.global_position) <= CAP_REACH and ball.y - cap.global_position.y >= CAP_ABOVE
		_goal = "boss cap air"
		_act(cap.global_position, cap, delta, cap)
		if over:
			source.hold["brake_held"] = true
		return
	var ship_angle: float = arena.angle_of(hull.global_position)
	var ramp := 0.0
	var gap := INF
	for a in RAMP_ANGLES:
		var g := absf(wrapf(ship_angle - deg_to_rad(a), -PI, PI))
		if g < gap:
			gap = g
			ramp = deg_to_rad(a)
	var r: float = arena.radius_of(ball)
	var on_ramp: bool = absf(wrapf(arena.angle_of(ball) - ramp, -PI, PI)) < 0.2
	if gap < RAMP_WINDOW and on_ramp and r < RAMP_BOTTOM + 3.0:
		_goal = "boss ramp climb"
		_act(arena.point_at(ramp, RAMP_PAST), cap if cap != null else hull, delta, hull)
		if r < RAMP_JUMP and game.player.state.grounded:
			source.press["jump_pressed"] = true
		return
	_goal = "boss ramp foot"
	_act(arena.point_at(ramp, RAMP_BOTTOM), hull, delta, hull)


func _brindle_rings(boss) -> BrindleRings:
	_rings.read(boss, ticks, _reaction(), Engine.physics_ticks_per_second, band)
	return _rings


func _ring_hold(boss, arena, ball: Vector3) -> Vector3:
	var rings := _brindle_rings(boss)
	if not rings.close_known():
		return Vector3.INF
	var r: float = arena.radius_of(ball)
	var safe := rings.safe_radius()
	if r < safe:
		return arena.point_at(arena.angle_of(ball), safe + RING_OUT_PAST)
	return arena.point_at(arena.angle_of(ball) + 0.5, safe if rings.covers_radius(r) else r)


class CuedRing:
	extends RefCounted
	var preview: Node3D
	var reach: float

	func _init(of: Node3D, height: float) -> void:
		preview = of
		reach = height

	func band() -> Vector2:
		return Vector2(preview.r_in, preview.r_out)

	func centre() -> Vector3:
		return preview.centre

	func contains(point: Vector3) -> bool:
		if not is_instance_valid(preview):
			return false
		var above: float = point.y - preview.ground_at(point)
		if above > reach or above < -2.0:
			return false
		var r := Vector2(point.x - preview.centre.x, point.z - preview.centre.z).length()
		return r >= preview.r_in and r <= preview.r_out


class BrindleRings:
	extends RefCounted
	const Rules := preload("res://src/boss/boss_rules.gd")
	const EDGE := 2.0
	const PATH_STEP := 1.0
	const GAP_TURN := 0.3
	const BRAKE_LOOK := 0.4
	var known: Array[Dictionary] = []
	var _tick := -1
	var _first := {}
	var _cue: CuedRing = null
	var _cue_known := {}

	func cue_of(boss) -> CuedRing:
		var preview = boss.reprise_preview() if boss != null and boss.has_method("reprise_preview") else null
		if preview == null or not is_instance_valid(preview):
			_cue = null
			return null
		if _cue == null or _cue.preview != preview:
			_cue = CuedRing.new(preview, Rules.SLAG_REACH)
		return _cue

	func read(boss, now: int, reaction_s: float, tps: int, band) -> void:
		if now == _tick:
			return
		_tick = now
		known.clear()
		var up := {}
		var bands := {}
		var cue := cue_of(boss)
		if cue != null:
			var id := cue.get_instance_id()
			up[id] = true
			bands[_key(cue.band())] = true
			if _seen_for(id, now, reaction_s, tps) and (band == null or band.reads(id)):
				_cue_known[_key(cue.band())] = true
				known.append({"band": cue.band(), "centre": cue.centre(), "state": "cued"})
		var hazards: Array = boss.active_hazards() if boss != null and boss.has_method("active_hazards") else []
		for h in hazards:
			if not is_instance_valid(h) or not String(h.attack_id).begins_with("slag_ring"):
				continue
			var id: int = h.get_instance_id()
			var b := Vector2(h.r_in, h.r_out)
			up[id] = true
			bands[_key(b)] = true
			var seen: bool = _seen_for(id, now, reaction_s, tps) and (band == null or band.reads(id))
			if seen or _cue_known.has(_key(b)):
				known.append({"band": b, "centre": h.centre, "state": "live" if h.is_live() else "warned"})
		for id in _first.keys():
			if not up.has(id):
				_first.erase(id)
		for k in _cue_known.keys():
			if not bands.has(k):
				_cue_known.erase(k)

	func close_known() -> bool:
		for ring in known:
			if (ring["band"] as Vector2).y <= Rules.FURNACE_CLOSE_BAND.y + 0.5:
				return true
		return false

	func safe_radius() -> float:
		var r := Rules.FURNACE_CLOSE_BAND.y + EDGE + 0.5
		for _pass in known.size() + 1:
			var moved := false
			for ring in known:
				var b: Vector2 = ring["band"]
				if r >= b.x - EDGE and r <= b.y + EDGE:
					r = b.y + EDGE + 0.5
					moved = true
			if not moved:
				break
		return r

	func covers(point: Vector3) -> bool:
		for ring in known:
			var c: Vector3 = ring["centre"]
			var r := Vector2(point.x - c.x, point.z - c.z).length()
			var b: Vector2 = ring["band"]
			if r >= b.x - EDGE and r <= b.y + EDGE:
				return true
		return false

	func crosses(from: Vector3, to: Vector3) -> bool:
		if known.is_empty():
			return false
		var length := Vector2(to.x - from.x, to.z - from.z).length()
		var steps := maxi(1, ceili(length / PATH_STEP))
		for i in range(1, steps + 1):
			if covers(from.lerp(to, float(i) / float(steps))):
				return true
		return false

	func steer_within(ball: Vector3, steer: Vector3) -> Vector3:
		if known.is_empty() or not crosses(ball, steer):
			return steer
		var c: Vector3 = known[0]["centre"]
		var r_ball := Vector2(ball.x - c.x, ball.z - c.z).length()
		var lo := 0.0
		var hi := INF
		for ring in known:
			var b: Vector2 = ring["band"]
			if r_ball >= b.x and r_ball <= b.y:
				return steer
			if b.y < r_ball:
				lo = maxf(lo, b.y + EDGE)
			else:
				hi = minf(hi, b.x - EDGE)
		if hi - lo < 2.0 * EDGE:
			return steer
		var a_ball := atan2(ball.z - c.z, ball.x - c.x)
		var a_steer := atan2(steer.z - c.z, steer.x - c.x)
		var a := a_ball + clampf(wrapf(a_steer - a_ball, -PI, PI), -GAP_TURN, GAP_TURN)
		var r := clampf(Vector2(steer.x - c.x, steer.z - c.z).length(), lo + EDGE * 0.5, hi - EDGE * 0.5)
		return Vector3(c.x + cos(a) * r, steer.y, c.z + sin(a) * r)

	func rolling_onto(ball: Vector3, velocity: Vector3) -> bool:
		if known.is_empty() or _on_ring(ball):
			return false
		return _on_ring(ball + Vector3(velocity.x, 0.0, velocity.z) * BRAKE_LOOK)

	func _on_ring(point: Vector3) -> bool:
		for ring in known:
			var c: Vector3 = ring["centre"]
			var r := Vector2(point.x - c.x, point.z - c.z).length()
			var b: Vector2 = ring["band"]
			if r >= b.x and r <= b.y:
				return true
		return false

	func covers_radius(r: float) -> bool:
		for ring in known:
			var b: Vector2 = ring["band"]
			if r >= b.x - EDGE and r <= b.y + EDGE:
				return true
		return false

	func _seen_for(id: int, now: int, reaction_s: float, tps: int) -> bool:
		if not _first.has(id):
			_first[id] = now
		return float(now - int(_first[id])) / float(tps) >= reaction_s

	static func _key(b: Vector2) -> String:
		return "%.1f:%.1f" % [b.x, b.y]


func _on_offers(offers: Array) -> void:
	_offers = offers
	_gate_pick = _choose_gate(offers)
	_gate_time = 0.0
	_gate_hop = 0.0
	_gate_detour_left = 0.0
	_gate_run = ""
	_gate_run_clock = 0.0
	_gate_on_top = false
	_gate_falls = 0
	var map = game.ctx.terrain.map_for(game.run.stage)
	_island_gates = map != null and map.has_method("_islands")
	if _island_gates:
		_fight_climb.clear()
		_fight_climb_clock = 0.0


func _choose_gate(offers: Array) -> int:
	if offers.is_empty():
		return -1
	match policy:
		"skipper":
			return 0
		"completionist":
			var best := 0
			var best_score := -1.0
			for i in offers.size():
				var o: Dictionary = offers[i]
				var score := float(o.get("tier", 1)) + (10.0 if String(o.get("synergy", "")) != "" else 0.0) \
					+ (0.5 if String(o.get("mark", "")) != "" else 0.0)
				if score > best_score:
					best_score = score
					best = i
			return best
	return rng.randi_range(0, offers.size() - 1)


func _to_gate(delta: float) -> void:
	_goal = "gate %d" % _gate_pick
	if _offers.is_empty() or _gate_pick < 0:
		source.hold = {"move": Vector2(0.0, 1.0)}
		return
	var offer: Dictionary = _offers[mini(_gate_pick, _offers.size() - 1)]
	var at: Vector3 = offer["at"]
	var facing: Vector3 = offer["facing"]
	var rel: Vector3 = game.player.ball_position() - at
	var along := rel.dot(facing)
	var side := (rel - facing * along).length()
	var target := at - facing * 9.0
	if side < 2.5 and along < 1.0:
		target = at + facing * 10.0
	elif side < GATE_LINE_SIDE and along > -GATE_LINE_BACK and along < -GATE_LINE_NEAR:
		target = at + facing * (along + GATE_LINE_LEAD)
	var ball_at: Vector3 = game.player.ball_position()
	if _climbing(ball_at, at) or (not _island_gates and _dips(ball_at, at)):
		if _gate_on_top and _island_gates:
			_gate_on_top = false
			_gate_falls += 1
			if _gate_falls >= GATE_SWITCH_FALLS:
				_switch_gate()
		target = _fight_way_up(ball_at, target, delta)
		_goal += " climb"
	else:
		_gate_on_top = true
		_fight_climb.clear()
		_fight_climb_clock = 0.0
	if rel.length() < GATE_PROBE_NEAR:
		target = _gate_round_props(ball_at, target, delta)
	else:
		_gate_detour_left = 0.0
	if _fight_climb.is_empty() or not _island_gates:
		target = _gate_runup(at, facing, rel, ball_at, target, delta)
	else:
		_gate_run = ""
	_gate_time += delta
	_gate_hop -= delta
	if _gate_time > GATE_SWITCH_SECONDS and _gate_on_top and _island_gates:
		_switch_gate()
	if _gate_time > GATE_HOP_SECONDS and _gate_hop <= 0.0 and game.player.state.grounded and along < 0.0 and along > -14.0:
		_gate_hop = GATE_HOP_EVERY
		source.press["jump_pressed"] = true
	if not game.player.state.grounded and game.player.state.air_actions > 0 and game.player.state.velocity.y < 0.0 \
			and game.player.verb_ready("jump"):
		for lip in _route_lips:
			if _flat(ball_at, lip) < 12.0 and ball_at.y < lip.y + 2.5 and ball_at.y > lip.y - 2.0:
				source.press["jump_pressed"] = true
				_count("gate_air_jumps")
				break
	if trace and ticks % (Engine.physics_ticks_per_second * 2) == 0:
		var ball: Vector3 = game.player.ball_position()
		print("    gate %d at=(%.1f, %.1f, %.1f) facing=(%.2f, %.2f, %.2f) ball=(%.1f, %.1f, %.1f) along=%.1f side=%.1f dy=%.1f ground=%.1f target=(%.1f, %.1f, %.1f)"
			% [_gate_pick, at.x, at.y, at.z, facing.x, facing.y, facing.z, ball.x, ball.y, ball.z, along, side, rel.y,
				game.ctx.terrain.height(ball.x, ball.z), target.x, target.y, target.z])
	var calm: bool = (_island_gates or _gate_time > GATE_HOP_SECONDS) and _gate_on_top and _gate_run == "" \
		and absf(rel.y) < 3.0 and rel.length() < GATE_CALM_RANGE
	if not calm:
		_act(target, null, delta)
		return
	var boost_clock := _boost_clock
	_boost_clock = maxf(_boost_clock, delta)
	_act(target, null, delta)
	_boost_clock = boost_clock
	if game.player.state.grounded and game.player.planar_velocity().length() > GATE_CALM_SPEED:
		source.hold["brake_held"] = true


func _switch_gate() -> void:
	_gate_falls = 0
	_gate_time = 0.0
	_gate_run = ""
	_gate_detour_left = 0.0
	if _offers.size() > 1:
		_gate_pick = (_gate_pick + 1) % _offers.size()
		_count("gate_switches")


func _gate_runup(at: Vector3, facing: Vector3, rel: Vector3, ball: Vector3, target: Vector3, delta: float) -> Vector3:
	if _gate_time < GATE_RUNUP_AFTER or rel.y > -3.0:
		_gate_run = ""
		return target
	var start := at - facing * GATE_RUNUP_BACK
	start.y = ball.y
	if _gate_run == "":
		_gate_run = "runup"
		_gate_run_clock = 0.0
		_count("gate_runups")
	_gate_run_clock += delta
	if _gate_run == "runup" and (_flat(ball, start) < 8.0 or _gate_run_clock > GATE_RUNUP_SECONDS):
		_gate_run = "charge"
		_gate_run_clock = 0.0
	elif _gate_run == "charge" and _gate_run_clock > GATE_CHARGE_SECONDS:
		_gate_run = "runup"
		_gate_run_clock = 0.0
		_count("gate_runups")
	_goal += " " + _gate_run
	if _gate_run == "runup":
		return start
	return at + facing * 10.0


func _gate_probe(from: Vector3, heading: Vector3, length: float) -> Dictionary:
	var origin := from + Vector3.UP * 0.5
	var query := PhysicsRayQueryParameters3D.create(origin, origin + heading * length)
	var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {}
	var node := hit["collider"] as Node
	if "/Ground" in str(node.get_path()):
		return {}
	return hit


func _body_shapes(body: Node) -> Array:
	var out: Array = []
	var body_3d := body as CollisionObject3D
	if body_3d == null:
		return out
	for owner_id in body_3d.get_shape_owners():
		var at := body_3d.global_transform * body_3d.shape_owner_get_transform(owner_id)
		for i in body_3d.shape_owner_get_shape_count(owner_id):
			out.append({"shape": body_3d.shape_owner_get_shape(owner_id, i), "global_transform": at})
	return out


func _prop_footprint(body: Node) -> Rect2:
	var owner_node: Node = body.get_parent()
	var shapes: Array = []
	if owner_node != null and owner_node.get_child_count() <= 12:
		for child in owner_node.get_children():
			if child is CollisionObject3D:
				shapes.append_array(_body_shapes(child))
	if shapes.is_empty():
		shapes = _body_shapes(body)
	var box := Rect2()
	var first := true
	for cs in shapes:
		var bs := cs.shape as BoxShape3D
		if bs == null:
			continue
		for sx in [-0.5, 0.5]:
			for sz in [-0.5, 0.5]:
				var corner: Vector3 = cs.global_transform * Vector3(bs.size.x * sx, 0.0, bs.size.z * sz)
				if first:
					box = Rect2(Vector2(corner.x, corner.z), Vector2.ZERO)
					first = false
				else:
					box = box.expand(Vector2(corner.x, corner.z))
	return box


func _gate_round_props(ball: Vector3, target: Vector3, delta: float) -> Vector3:
	_gate_detour_left -= delta
	if _gate_detour_left > 0.0 and _flat(ball, _gate_detour) > 3.0:
		return _gate_detour
	var line := target - ball
	line.y = 0.0
	if line.length() < 1.0:
		return target
	var reach := minf(line.length(), GATE_PROBE)
	line = line.normalized()
	var hit := _gate_probe(ball, line, reach)
	if hit.is_empty():
		return target
	var walls := _prop_footprint(hit["collider"])
	if _island_gates and walls.has_point(Vector2(ball.x, ball.z)):
		_gate_detour = ball - line * (walls.size.length() * 0.5 + GATE_MARGIN)
		_gate_detour_left = GATE_DETOUR_SECONDS
		_count("gate_backouts")
		return _gate_detour
	var box := walls.grow(GATE_MARGIN)
	var best_cost := INF
	var best := Vector3.ZERO
	if box.has_area():
		for corner in [box.position, box.position + Vector2(box.size.x, 0.0), box.position + Vector2(0.0, box.size.y), box.end]:
			var at := Vector3(corner.x, ball.y, corner.y)
			var way := at - ball
			way.y = 0.0
			if way.length() < 1.0 or not _gate_probe(ball, way.normalized(), way.length()).is_empty():
				continue
			var cost := way.length() + _flat(at, target)
			if cost < best_cost:
				best_cost = cost
				best = at
	if best_cost < INF:
		_gate_detour = best
		_gate_detour_left = GATE_DETOUR_SECONDS
		_count("gate_detours")
		return best
	for step in range(1, 7):
		for side in [1.0, -1.0]:
			var heading := line.rotated(Vector3.UP, deg_to_rad(GATE_TURN * step * side))
			if _gate_probe(ball, heading, GATE_PROBE).is_empty():
				_gate_detour = ball + heading * GATE_PROBE
				_gate_detour_left = 1.0
				_count("gate_detours")
				return _gate_detour
	return target


func _act(steer: Vector3, aim, delta: float, fight: Node3D = null, evade := true) -> void:
	var player = game.player
	if policy == "completionist" and _chain_phase != "":
		_chain_drive(delta)
		return
	if player.kit.mounted:
		_turret(aim, delta)
		return
	if _plant_state == "mounted":
		_plant_state = "idle"
	_ultimate_hands(fight)
	_active_hands(fight)
	_line_hands()
	var brake := false
	if _ring_fight != null and is_instance_valid(_ring_fight):
		var rings := _brindle_rings(_ring_fight)
		var within := rings.steer_within(player.ball_position(), steer)
		brake = within != steer and player.state.grounded and rings.rolling_onto(player.ball_position(), player.state.velocity)
		steer = within
	var threats := _threats() if evade else []
	if not threats.is_empty():
		for h in threats:
			if not _evaded.has(h.get_instance_id()):
				_evaded[h.get_instance_id()] = true
				_count("evasions")
		var escape := _escape(threats, steer, fight if policy == "camper" else null)
		_plant_state = "idle" if _plant_state == "seek" else _plant_state
		_specials(fight, true)
		_drive(escape, aim, delta)
		return
	if _engineer() and _kit("plant") and fight != null and is_instance_valid(fight):
		if _climbing(player.ball_position(), fight.global_position):
			_plant_state = "idle" if _plant_state == "seek" else _plant_state
		else:
			var planted := _plant(fight, delta)
			if planted != Vector3.INF:
				steer = planted
	_specials(fight, false)
	_drive(steer, aim, delta)
	if brake:
		source.hold["brake_held"] = true


func _threats() -> Array:
	var ball: Vector3 = game.player.ball_position()
	var ahead: Vector3 = ball + game.player.state.velocity * PREDICT
	var out: Array = []
	var live := {}
	for h in _hazards():
		var id: int = h.get_instance_id()
		live[id] = true
		if not _seen.has(id):
			_seen[id] = ticks
			continue
		if float(ticks - int(_seen[id])) / float(Engine.physics_ticks_per_second) < _reaction():
			continue
		if band != null and not band.reads(id):
			continue
		if _welcome_ring_at != Vector3.INF and h.get("center") != null and _flat(h.center, _welcome_ring_at) < 1.0:
			continue
		if not _read.has(id):
			_read[id] = true
			_count("telegraph_reads")
		if h.contains(ball) or h.contains(ahead):
			out.append(h)
	if _seen.size() > 64:
		for id in _seen.keys():
			if not live.has(id):
				_seen.erase(id)
				_read.erase(id)
	if band != null:
		band.forget(live)
	return out


func _sheet_timed() -> bool:
	return band == null or band.timed_sheet()


func _reaction() -> float:
	return REACTION if band == null else band.reaction_s


func _kit(verb: String) -> bool:
	return band == null or band.allows(verb)


func _hazards() -> Array:
	var out: Array = []
	var pack_telegraphs := _pack_telegraphs() if hide_pack_telegraphs else {}
	for child in game.get_children():
		if child.get_script() != TelegraphScript or child.is_queued_for_deletion():
			continue
		if child.color == Palette.AMBER:
			continue
		if child.shape == TelegraphScript.Shape.RING and child.radius > FIELD_RADIUS:
			continue
		if hide_pack_telegraphs and pack_telegraphs.has(child):
			continue
		out.append(child)
	var boss = _boss() if game.flow.state_name() == "boss" else null
	if boss != null and boss.has_method("active_hazards"):
		for h in boss.active_hazards():
			if is_instance_valid(h) and h.has_method("contains"):
				out.append(h)
		var cued = _rings.cue_of(boss)
		if cued != null:
			out.append(cued)
	return out


func _escape(threats: Array, steer: Vector3, away: Node3D = null) -> Vector3:
	var ball: Vector3 = game.player.ball_position()
	var v: Vector3 = game.player.planar_velocity()
	var line := Vector3(v.x, 0.0, v.z).normalized() if v.length() > 1.0 else Vector3.ZERO
	var goal := Vector3(steer.x - ball.x, 0.0, steer.z - ball.z).normalized()
	if away != null and is_instance_valid(away) and _flat(ball, away.global_position) <= CAMP_RANGE:
		goal = Vector3(ball.x - away.global_position.x, 0.0, ball.z - away.global_position.z).normalized()
		line = Vector3.ZERO
	for reach in ESCAPE_REACH:
		var best := Vector3.INF
		var best_score := -INF
		for i in ESCAPE_DIRECTIONS:
			var angle := TAU * i / ESCAPE_DIRECTIONS
			var dir := Vector3(sin(angle), 0.0, cos(angle))
			var at := _ground_point(ball.x + dir.x * reach, ball.z + dir.z * reach)
			var safe := true
			for h in threats:
				if h.contains(at):
					safe = false
					break
			if not safe:
				continue
			var score := dir.dot(line) + 0.7 * dir.dot(goal)
			if score > best_score:
				best_score = score
				best = ball + dir * (reach + 6.0)
		if best != Vector3.INF:
			return best
	source.press["jump_pressed"] = true
	return ball + (line if line != Vector3.ZERO else goal) * 12.0


func _ground_point(x: float, z: float) -> Vector3:
	var boss = _boss() if game.flow.state_name() == "boss" else null
	if boss != null and is_instance_valid(boss.get("arena")) and boss.arena.has_method("ground"):
		var p := Vector3(x, 0.0, z)
		return Vector3(x, boss.arena.ground(p) + 1.0, z)
	return game.ctx.terrain.drop_point(x, z, 1.0)


func _plant(fight: Node3D, delta: float) -> Vector3:
	var ball: Vector3 = game.player.ball_position()
	match _plant_state:
		"idle":
			if _plant_cool > 0.0 or ball.distance_to(fight.global_position) > PLANT_RANGE:
				return Vector3.INF
			var face := _find_face(fight)
			if face == Vector3.INF:
				_plant_cool = 2.0
				return Vector3.INF
			_plant_face = face
			_plant_target = fight
			_plant_state = "seek"
			_plant_clock = 0.0
			return face
		"seek":
			_plant_clock += delta
			if _plant_clock > PLANT_TIMEOUT:
				_plant_state = "idle"
				_plant_cool = PLANT_EVERY
				return Vector3.INF
			if ball.distance_to(_plant_face) < PLANT_REACH:
				source.press["mount_pressed"] = true
			return _plant_face
	return Vector3.INF


func _turret(aim, delta: float) -> void:
	if _plant_state != "mounted":
		_plant_state = "mounted"
		_plant_clock = 0.0
	_plant_clock += delta
	var ball: Vector3 = game.player.ball_position()
	var look_at: Vector3 = _aim_point(aim) if _aim_valid(aim) else ball + game.camera.yaw_basis() * Vector3.FORWARD
	_look(ball, look_at, _aim_valid(aim), delta)
	source.hold = {"fire_held": true}
	_cadence_fire_hand()
	var threatened := false
	for h in _threats():
		threatened = true
	if _plant_clock > TURRET_SECONDS or threatened or not _aim_valid(aim):
		if _sling_lands_low():
			source.press["mount_pressed"] = true
		else:
			source.press["jump_pressed"] = true
		_plant_state = "idle"
		_plant_cool = PLANT_EVERY


func _in_mind_stage() -> bool:
	return int(_note.get("stage", 0)) == MIND_STAGE


func _mind_slope() -> bool:
	return _in_mind_stage() and not _mind_slope_spent


func _sling_lands_low() -> bool:
	var cone: Dictionary = game.player.kit.slingshot_aim
	if cone.is_empty():
		return false
	var p: Vector3 = game.player.ball_position()
	var low: float = _ground_point(p.x, p.z).y
	if is_instance_valid(_plant_target):
		low = minf(low, _ground_point(_plant_target.global_position.x, _plant_target.global_position.z).y)
	var v: Vector3 = (cone["dir"] as Vector3) * float(cone["speed"])
	var gravity: float = game.player.tuning.f("gravity")
	var t := 0.0
	while t < SLING_FLIGHT:
		p += v * SLING_STEP
		v.y -= gravity * SLING_STEP
		t += SLING_STEP
		var ground: float = _ground_point(p.x, p.z).y
		if v.y < 0.0 and p.y <= ground:
			return ground < low - LEVEL_BAND
	return true


func _find_face(fight: Node3D) -> Vector3:
	var space = game.get_world_3d().direct_space_state
	var ball: Vector3 = game.player.ball_position()
	var to_fight := Vector3(fight.global_position.x - ball.x, 0.0, fight.global_position.z - ball.z).normalized()
	var best := Vector3.INF
	var best_score := INF
	for i in 16:
		var angle := TAU * i / 16.0
		var dir := Vector3(sin(angle), 0.0, cos(angle))
		var from := ball + Vector3.UP * 0.3
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + dir * PLANT_SEARCH, 1))
		if hit.is_empty():
			continue
		var n: Vector3 = hit["normal"]
		if absf(n.y) >= FACE_TILT:
			continue
		var score: float = ball.distance_to(hit["position"]) - 6.0 * dir.dot(to_fight)
		if score < best_score:
			best_score = score
			best = hit["position"]
	return best


func _specials(fight: Node3D, pressed_by_threat: bool) -> void:
	if not _kit("special"):
		return
	var ball: Vector3 = game.player.ball_position()
	var near := 0
	for node in game.get_tree().get_nodes_in_group("enemy"):
		if node is Node3D and is_instance_valid(node) and ball.distance_to(node.global_position) < CROWD_RADIUS:
			if not (node.has_method("is_dead") and node.is_dead()):
				near += 1
	var close: bool = fight != null and is_instance_valid(fight) and ball.distance_to(fight.global_position) < CLOSE_FIGHT
	if near >= CROWD or close or (pressed_by_threat and near >= 1):
		_cast(2)


func _cast(slot: int, hold_seconds := 0.0) -> bool:
	if _cast_phase == "await_smash": _await_smash_holds()
	if slot == 3 and game.player.abilities.id_of(AbilityState.LINE) == "bank_shot" and source.press.get("harpoon_released", false): return false
	if _cast_phase != "" or _set_piece_up() or slot < 2 or slot > AbilityState.BAR.size():
		return false
	if _bar_state(slot) != AbilityState.READY or (slot == 3 and _line_loaded()):
		return false
	_cast_slot = slot
	_cast_hold = hold_seconds
	_cast_phase = "click"
	return true


func _bar_state(slot: int) -> String:
	for s in game.player.abilities.slots():
		if int(s["number"]) == slot:
			return String(s["state"])
	return AbilityState.UNAVAILABLE


func _cast_hands() -> void:
	var abilities = game.player.abilities
	var name: String = AbilityState.BAR[_cast_slot - 1] if _cast_slot >= 1 else ""
	match _cast_phase:
		"click":
			if abilities.selected != name:
				source.press["slot_pick"] = _cast_slot - 1
			if policy == "traversal":
				_cast_phase = "sent"
				source.hold.erase("fire_held")
				return
			source.press["fire_pressed"] = true
			source.hold["fire_held"] = true
			_cast_phase = "hold" if _cast_hold > 0.0 else "release"
		"hold":
			_cast_hold -= 1.0 / Engine.physics_ticks_per_second
			source.hold["fire_held"] = true
			if _cast_hold <= 0.0:
				_cast_phase = "release"
		"release":
			source.hold.erase("fire_held")
			if abilities.selected == name and not abilities.charging():
				source.press["slot_pick"] = 0
			_cast_phase = ""


func _line_hands() -> void:
	if not _kit("line_cast"):
		return
	var kit = game.player.kit
	if not kit.hooked or not kit.on_body or not is_instance_valid(kit.anchor_body):
		return
	var body: Node3D = kit.anchor_body
	if not body.is_in_group("enemy"):
		return
	if not _is_flume_warden(body) and body.has_method("staggered") and body.staggered():
		return
	if game.player.ball_position().distance_to(body.global_position) <= LINE_CAST_REACH:
		_cast(3)


func _line_loaded() -> bool:
	var combat = game.get("combat")
	return combat != null and combat.has_method("line_load") and not (combat.line_load() as Dictionary).is_empty()


func _set_piece_up() -> bool:
	var combat = game.get("combat")
	return combat != null and combat.get("ultimate") != null and combat.ultimate.phase() != "idle"


func _ultimate_hands(fight: Node3D) -> void:
	if _cast_phase == "await_smash": _await_smash_holds()
	if not _kit("ultimate"):
		return
	if _ult_wait > 0.0 or _set_piece_up() or _cast_phase != "":
		return
	if String(game.player.abilities.ultimate().get("state", "")) != AbilityState.READY:
		return
	var ball: Vector3 = game.player.ball_position()
	var want := false
	if policy == "traversal":
		if _traverse_point != Vector3.INF:
			var ahead := _flat(ball, _traverse_point)
			want = not _hand_aim and ahead >= ULT_TRAVERSE_NEAR and ahead <= ULT_TRAVERSE_FAR and _way_clear(ball, _traverse_point)
	elif band != null and not band.timed_ultimate():
		var near_lock: bool = fight != null and is_instance_valid(fight) and ball.distance_to(fight.global_position) <= ULT_CROWD_RADIUS
		want = near_lock or _enemies_within(ball, ULT_CROWD_RADIUS) >= 1
	else:
		want = _core_open(fight, ball) or _enemies_within(ball, ULT_CROWD_RADIUS) >= ULT_CROWD
	if not want:
		return
	source.press["ultimate_pressed"] = true
	_ult_wait = ULT_RETRY
	_totals["ult_presses"] = int(_totals["ult_presses"]) + 1


func _active_hands(fight: Node3D) -> void:
	if not _kit("active"):
		return
	if policy == "traversal" or _active_wait > 0.0 or _set_piece_up() or _cast_phase != "" or _chain_driving or _sheet_hold_fire:
		return
	var combat = game.get("combat")
	if combat == null:
		return
	var rack = combat.get("actives")
	if rack == null or not rack.enabled() or rack.active_id == "" or rack.charges < 1 or rack.winding > 0.0 or rack.locked():
		return
	var ball: Vector3 = game.player.ball_position()
	var near_fight: bool = fight != null and is_instance_valid(fight) \
		and not (fight.has_method("is_dead") and fight.is_dead()) \
		and ball.distance_to(fight.global_position) <= ACTIVE_RANGE
	if not near_fight and _enemies_within(ball, ACTIVE_RANGE) < 1 and not _core_open(fight, ball):
		return
	source.press["active_pressed"] = true
	_active_wait = ACTIVE_RETRY
	_totals["active_presses"] = int(_totals["active_presses"]) + 1


func _core_open(fight: Node3D, ball: Vector3) -> bool:
	var cores: Array = [fight]
	if game.flow != null and is_instance_valid(game.flow.warden):
		cores.append(game.flow.warden)
	var boss = _boss() if game.flow.state_name() == "boss" else null
	if boss != null:
		if boss.get("ship") != null and is_instance_valid(boss.ship.hull):
			cores.append(boss.ship.hull)
		if boss.get("warden") is Node3D:
			cores.append(boss.get("warden"))
	for core in cores:
		if core == null or not is_instance_valid(core) or not core.has_method("staggered"):
			continue
		if core.staggered() and ball.distance_to(core.global_position) <= ULT_CORE_REACH:
			return true
	return false


func _enemies_within(ball: Vector3, radius: float) -> int:
	var near := 0
	for node in game.get_tree().get_nodes_in_group("enemy"):
		if node is Node3D and is_instance_valid(node) and ball.distance_to(node.global_position) < radius:
			if not (node.has_method("is_dead") and node.is_dead()):
				near += 1
	return near


func _set_piece_hands() -> void:
	if not _set_piece_up():
		return
	source.press.erase("jump_pressed")
	source.press.erase("ultimate_pressed")


static func _plate_contains(plate: Dictionary, ball: Vector3) -> bool:
	var rect: Rect2 = plate["rect"]
	return ball.x >= rect.position.x and ball.x <= rect.end.x and ball.z >= rect.position.y and ball.z <= rect.end.y


func _plate_shortcut(steer: Vector3, ball: Vector3) -> Dictionary:
	if not game.flow.in_stage() or ball.y - steer.y <= LEVEL_BAND or game.world.breach == null:
		return {}
	var chosen := {}
	var nearest := PLATE_REACH
	for plate in game.world.breach.plates:
		if game.world.breach.breached(plate["id"]):
			continue
		var centre: Vector2 = (plate["rect"] as Rect2).get_center()
		var at := Vector3(centre.x, ball.y, centre.y)
		var distance := _flat(ball, at)
		if distance <= nearest and _flat(at, steer) <= _flat(ball, steer):
			chosen = plate
			nearest = distance
	return chosen


func _inside_thermal(ball: Vector3) -> bool:
	if not game.flow.in_stage() or not game.player.kit.on("glide"):
		return false
	var map = game.ctx.terrain.map()
	if not "contraptions" in map:
		return false
	for spec in map.contraptions:
		if spec["kind"] == "thermal" and Vector2(ball.x, ball.z).distance_to(spec["at"]) <= float(spec["radius"]):
			return true
	return false


func _drive(steer: Vector3, aim, delta: float) -> void:
	var player = game.player
	var ball: Vector3 = player.ball_position()
	_plate_hand = _plate_shortcut(steer, ball)
	var on_plate := not _plate_hand.is_empty() and _plate_contains(_plate_hand, ball)
	if not _plate_hand.is_empty():
		var centre: Vector2 = (_plate_hand["rect"] as Rect2).get_center()
		steer = Vector3(centre.x, ball.y, centre.y)
	var thermal := _inside_thermal(ball)
	var speed: float = player.planar_velocity().length()
	var fleet = game.ctx.spawner.get("fleet") if game.ctx.spawner != null else null
	var held: bool = fleet != null and fleet.holds != null and fleet.holds.holding()
	var wedged: bool = not player.state.grounded and not player.kit.hooked and not player.frozen() and not thermal \
			and not held and absf(player.state.velocity.y) < STUCK_SPEED
	if speed < STUCK_SPEED and (player.state.grounded or wedged):
		_slow_time += delta
	else:
		_slow_time = 0.0
	if _slow_time > STUCK_SECONDS and _detour_time <= 0.0:
		_slow_time = 0.0
		_detour_time = DETOUR_SECONDS
		var to := Vector3(steer.x - ball.x, 0.0, steer.z - ball.z).normalized()
		_detour = to.rotated(Vector3.UP, PI * 0.5 * (1.0 if rng.randf() < 0.5 else -1.0))
		_wall_side = 0.0
		source.press["jump_pressed"] = true
		_count("stuck_detours")
	var heading := Vector3(steer.x - ball.x, 0.0, steer.z - ball.z)
	if _detour_time > 0.0:
		_detour_time -= delta
		heading = _detour
	elif player.state.grounded and not _ignore_walls and not _recover_climb:
		heading = _around_walls(ball, heading)
	var hold := {"fire_held": _throw_hold(aim)}
	var look_at: Vector3 = ball + heading
	var aiming := _aim_valid(aim)
	if aiming:
		look_at = _aim_point(aim)
	_look(ball, look_at, aiming, delta)
	var yaw: float = game.camera.yaw
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	if heading.length() > 0.3:
		var dir := heading.normalized()
		var v: Vector3 = player.planar_velocity()
		v.y = 0.0
		var change := dir * maxf(v.length(), 12.0) - v
		if _cruise_hold:
			change = dir * player.tuning.f("cruise") - v
		var want := dir if change.length() < 0.5 else change.normalized()
		hold["move"] = Vector2(want.dot(right), want.dot(forward)).normalized()
		if _cruise_hold and change.length() < 0.5:
			hold["move"] = Vector2.ZERO
		var lined: float = v.normalized().dot(dir) if v.length() > 0.5 else 1.0
		if _boost_clock <= 0.0 and lined > 0.9 and player.state.grounded and player.verb_ready("boost") and not _cruise_hold:
			_boost_clock = BOOST_GAP
			_shift_left = SHIFT_HOLD
			source.press["shift_pressed"] = true
	if _shift_left > 0.0:
		_shift_left -= delta
		hold["shift_held"] = true
	if _harpoon_held:
		hold["harpoon_held"] = true
	if _harpoon_commit:
		hold["brake_held"] = true
	if on_plate:
		hold["move"] = Vector2.ZERO
		hold.erase("shift_held")
		source.press.erase("shift_pressed")
		if player.state.grounded:
			source.press["jump_pressed"] = true
		elif player.state.velocity.y < 2.0:
			hold["brake_held"] = true
	if _glide_held and not thermal:
		hold.erase("shift_held")
		source.press.erase("shift_pressed")
		if player.state.air_actions > 0:
			source.press["jump_pressed"] = true
		elif player.state.velocity.y < 0.0 and not player.kit.slamming:
			hold["jump_held"] = true
	if thermal:
		hold.erase("shift_held")
		source.press.erase("shift_pressed")
		if player.state.grounded or player.state.air_actions > 0:
			source.press["jump_pressed"] = true
		elif player.state.velocity.y < 0.0 and not player.kit.slamming:
			hold["jump_held"] = true
	var chain_hand: bool = policy == "completionist" and chain_hand_enabled and _chain_phase != "" and not _in_boss()
	var haul_commit: bool = _harpoon_commit or (player.kit.hooked and player.kit.line_state == Augments.LINE_SMASH)
	var flume_stage: bool = _is_flume_stage()
	var kest_drop_hang: bool = class_id() == "demolitions_caster" and not player.state.grounded \
			and not flume_stage and is_instance_valid(_fight_target) and _anchor_warden(_fight_target) \
			and (_fight_target.staggered() or (player.kit.hooked and player.kit.on_body and player.kit.anchor_body == _fight_target))
	if ((haul_commit and not flume_stage) or kest_drop_hang) and _cast_phase == "":
		hold.erase("fire_held")
	if not chain_hand and haul_commit:
		source.press.erase("jump_pressed")
		source.press.erase("shift_pressed")
		source.press.erase("movement_pressed")
		hold.erase("shift_held")
	source.hold = hold
	_cadence_fire_hand()
	_card_hands()
	_cast_hands()


func _roll_cadence_window() -> bool:
	var idx := _cadence_index
	_cadence_index += 1
	if band != null:
		return band.hits_window(idx)
	return SkillBand.roll_window(seed_value, idx, float(SkillBand.BANDS["expert"]["window_last"]))


func _cadence_fire_hand() -> void:
	if _cast_phase != "" or policy == "traversal" or _chain_driving or _set_piece_up() or _sheet_hold_fire:
		return
	var player = game.get("player")
	var abilities = player.get("abilities") if player != null else null
	if abilities != null and abilities.selected != AbilityState.WEAPON:
		return
	var combat = game.get("combat")
	if combat == null or combat.get("weapon_driver") == null:
		return
	var snap: Dictionary = combat.weapon_driver.state_snapshot()
	var wid: String = String(snap.get("weapon", ""))
	if wid == "" and combat.has_method("active_weapon"):
		wid = combat.active_weapon()
	var pat: Resource = combat.pattern(wid) if wid != "" and combat.has_method("pattern") else null
	var trig: String = String(snap.get("trigger", ""))
	if trig != Pattern.TRIGGER_PRESS and trig != Pattern.TRIGGER_TAP_CHARGE \
			and trig != Pattern.TRIGGER_LOB_SNAP and trig != Pattern.TRIGGER_BEATS \
			and trig != Pattern.TRIGGER_STAMP and trig != Pattern.TRIGGER_LOCK:
		if pat != null:
			trig = String(pat.trigger)
	var want_fire: bool = bool(source.hold.get("fire_held", false))
	if trig == Pattern.TRIGGER_PRESS:
		var fan_hold: bool = pat != null and bool(pat.fan)
		if not bool(snap.get("reloading", false)):
			_cadence_reload_rolled = false
			_cadence_reload_hit = false
			_cadence_reload_pressed = false
			if want_fire and not fan_hold and bool(snap.get("ready", false)):
				source.press["fire_pressed"] = true
			return
		if not want_fire:
			return
		if not _cadence_reload_rolled:
			if bool(snap.get("window_spent", false)):
				return
			_cadence_reload_rolled = true
			_cadence_reload_pressed = false
			_cadence_reload_hit = _roll_cadence_window()
			_totals["cadence_windows"] = int(_totals["cadence_windows"]) + 1
		if _cadence_reload_hit and not _cadence_reload_pressed and bool(snap.get("window_open", false)):
			source.press["fire_pressed"] = true
			_cadence_reload_pressed = true
			_totals["cadence_hits"] = int(_totals["cadence_hits"]) + 1
		return
	if trig == Pattern.TRIGGER_TAP_CHARGE:
		if not want_fire:
			if bool(snap.get("charge_armed", false)) and bool(snap.get("charging", false)) and float(snap.get("charge", 0.0)) >= 0.25:
				source.press["fire_released"] = true
			source.hold.erase("fire_held")
			return
		if bool(snap.get("charge_armed", false)):
			if float(snap.get("charge", 0.0)) >= 0.9999:
				source.hold.erase("fire_held")
				source.press["fire_released"] = true
				_totals["cadence_hits"] = int(_totals["cadence_hits"]) + 1
			else:
				source.hold["fire_held"] = true
		elif bool(snap.get("ready", false)):
			var hit := _roll_cadence_window()
			_totals["cadence_windows"] = int(_totals["cadence_windows"]) + 1
			source.press["fire_pressed"] = true
			if hit:
				source.hold["fire_held"] = true
			else:
				source.hold.erase("fire_held")
		else:
			source.hold.erase("fire_held")
		return
	if trig == Pattern.TRIGGER_LOB_SNAP:
		if bool(snap.get("lob_charging", false)):
			_cadence_window_rolled = false
			_cadence_window_hit = false
			_cadence_window_pressed = false
			return
		var win: String = String(snap.get("window", WeaponDriver.WINDOW_IDLE))
		if win == WeaponDriver.WINDOW_WAITING or win == WeaponDriver.WINDOW_OPEN:
			source.hold.erase("fire_held")
			if not want_fire or _cadence_lob_reach_m > 14.5:
				return
			if not _cadence_window_rolled:
				_cadence_window_rolled = true
				_cadence_window_pressed = false
				_cadence_window_hit = _roll_cadence_window()
				_totals["cadence_windows"] = int(_totals["cadence_windows"]) + 1
			if _cadence_window_hit and not _cadence_window_pressed and win == WeaponDriver.WINDOW_OPEN:
				var win_range: Vector2 = snap.get("window_range", Vector2.ZERO)
				var snap_at: float = clampf(_cadence_lob_flight_s - 0.02, win_range.x, maxf(win_range.x, win_range.y - 0.03))
				if float(snap.get("window_t", 0.0)) >= snap_at - 0.001:
					source.press["fire_pressed"] = true
					_cadence_window_pressed = true
					_totals["cadence_hits"] = int(_totals["cadence_hits"]) + 1
			return
		_cadence_window_rolled = false
		_cadence_window_hit = false
		_cadence_window_pressed = false
		if bool(snap.get("snap_locked", false)):
			source.hold.erase("fire_held")
			return
		if want_fire and bool(snap.get("ready", false)):
			source.press["fire_pressed"] = true
		else:
			source.hold.erase("fire_held")
		return
	if trig == Pattern.TRIGGER_BEATS:
		var win: String = String(snap.get("window", WeaponDriver.WINDOW_IDLE))
		if win == WeaponDriver.WINDOW_WAITING or win == WeaponDriver.WINDOW_OPEN:
			if not want_fire:
				return
			if not _cadence_window_rolled:
				_cadence_window_rolled = true
				_cadence_window_pressed = false
				_cadence_window_hit = _roll_cadence_window()
				_totals["cadence_windows"] = int(_totals["cadence_windows"]) + 1
			if _cadence_window_hit:
				if not _cadence_window_pressed and win == WeaponDriver.WINDOW_OPEN:
					source.press["fire_pressed"] = true
					_cadence_window_pressed = true
					_totals["cadence_hits"] = int(_totals["cadence_hits"]) + 1
			elif not _cadence_window_pressed and win == WeaponDriver.WINDOW_WAITING:
				source.press["fire_pressed"] = true
				_cadence_window_pressed = true
			return
		_cadence_window_rolled = false
		_cadence_window_hit = false
		_cadence_window_pressed = false
		if want_fire and bool(snap.get("ready", false)):
			source.press["fire_pressed"] = true
		return
	if trig == Pattern.TRIGGER_STAMP:
		source.hold.erase("fire_held")
		var win: String = String(snap.get("window", "idle"))
		if win == WeaponDriver.WINDOW_WAITING or win == WeaponDriver.WINDOW_OPEN:
			if not want_fire:
				return
			if win == WeaponDriver.WINDOW_WAITING and _cadence_window_pressed and _cadence_window_hit:
				_cadence_window_rolled = false
				_cadence_window_hit = false
				_cadence_window_pressed = false
			if not _cadence_window_rolled:
				_cadence_window_rolled = true
				_cadence_window_pressed = false
				_cadence_window_hit = _roll_cadence_window()
				_totals["cadence_windows"] = int(_totals["cadence_windows"]) + 1
			if _cadence_window_hit:
				if bool(snap.get("window_open", false)) and bool(snap.get("ready", false)):
					source.press["fire_pressed"] = true
					if not _cadence_window_pressed:
						_cadence_window_pressed = true
						_totals["cadence_hits"] = int(_totals["cadence_hits"]) + 1
			elif not _cadence_window_pressed and win == WeaponDriver.WINDOW_WAITING:
				source.press["fire_pressed"] = true
				_cadence_window_pressed = true
			return
		_cadence_window_rolled = false
		_cadence_window_hit = false
		_cadence_window_pressed = false
		if want_fire and bool(snap.get("ready", false)):
			source.press["fire_pressed"] = true
		return
	if trig == Pattern.TRIGGER_LOCK:
		var painted: bool = bool(snap.get("painted", false))
		if not painted:
			_cadence_window_rolled = false
			_cadence_window_hit = false
			_cadence_window_pressed = false
			if want_fire and bool(snap.get("ready", false)):
				_cadence_window_rolled = true
				_cadence_window_hit = _roll_cadence_window()
				_cadence_lock_late = (_cadence_index % 2) == 0
				_totals["cadence_windows"] = int(_totals["cadence_windows"]) + 1
				source.press["fire_pressed"] = true
				source.hold["fire_held"] = true
			else:
				source.hold.erase("fire_held")
			return
		var win_open: bool = bool(snap.get("window_open", false))
		var win_spent: bool = bool(snap.get("window_spent", false))
		var win_range: Vector2 = snap.get("window_range", Vector2.ZERO)
		if not want_fire:
			source.hold.erase("fire_held")
			source.press["fire_released"] = true
			if win_open:
				_totals["cadence_hits"] = int(_totals["cadence_hits"]) + 1
			return
		if _cadence_window_hit:
			if win_open or win_spent or (win_range.y <= win_range.x and float(snap.get("hold", 0.0)) >= 0.30):
				source.hold.erase("fire_held")
				source.press["fire_released"] = true
				if win_open:
					_totals["cadence_hits"] = int(_totals["cadence_hits"]) + 1
			else:
				source.hold["fire_held"] = true
		elif _cadence_lock_late:
			if win_spent or float(snap.get("hold", 0.0)) > maxf(win_range.y, 0.46) + 0.02:
				source.hold.erase("fire_held")
				source.press["fire_released"] = true
			else:
				source.hold["fire_held"] = true
		else:
			source.hold.erase("fire_held")
			source.press["fire_released"] = true


const TALLY_PLATE_REACH := 45.0
const TALLY_PLATE_CROWD := 3
const TALLY_PLATE_RADIUS := 6.0
const TALLY_GATHER_RADIUS := 12.0


func _card_hands() -> void:
	if game.player.abilities.cap(AbilityState.WEAPON, "cards", null) == null:
		return
	if _kit("special"):
		_tally_gather_hands()
	if _kit("ultimate"):
		_tally_plate_hands()
	var combat = game.get("combat")
	if combat != null and combat.get("weapon_driver") != null:
		if String(combat.weapon_driver.state_snapshot().get("trigger", "")) == Pattern.TRIGGER_STAMP:
			return
	if not source.hold.get("fire_held", false):
		return
	source.hold.erase("fire_held")
	if ticks - _card_press_tick >= int(ceil(CARD_PRESS_GAP * Engine.physics_ticks_per_second)):
		source.press["fire_pressed"] = true
		_card_press_tick = ticks


func _tally_gather_hands() -> void:
	var combat = game.get("combat")
	if combat == null or _cast_phase != "" or _set_piece_up() or not combat.has_method("_card_aim"):
		return
	var aim: Dictionary = combat._card_aim()
	if not aim["valid"]:
		return
	var ordinary := 0
	for node in game.get_tree().get_nodes_in_group("enemy"):
		if node is Node3D and is_instance_valid(node) and not (node.has_method("is_dead") and node.is_dead()) \
				and combat._ordinary(node) and node.global_position.distance_to(aim["point"]) <= TALLY_GATHER_RADIUS:
			ordinary += 1
	if ordinary >= TALLY_PLATE_CROWD:
		_cast(2)


func _tally_plate_hands() -> void:
	var combat = game.get("combat")
	if combat == null or _ult_wait > 0.0 or _set_piece_up() or _cast_phase != "":
		return
	if String(game.player.abilities.ultimate().get("state", "")) != AbilityState.READY:
		return
	var plate: Dictionary = combat.get("plate") if combat.get("plate") != null else {}
	if plate.is_empty() or game.player.ball_position().distance_to(plate["at"]) > TALLY_PLATE_REACH:
		return
	if _enemies_within(plate["at"], TALLY_PLATE_RADIUS) < TALLY_PLATE_CROWD:
		return
	source.press["ultimate_pressed"] = true
	_ult_wait = ULT_RETRY
	_totals["ult_presses"] = int(_totals["ult_presses"]) + 1


func _around_walls(ball: Vector3, heading: Vector3) -> Vector3:
	if heading.length() < 0.3:
		return heading
	var space = game.get_world_3d().direct_space_state
	var dir := heading.normalized()
	if _wall_side != 0.0 and rad_to_deg(dir.angle_to(_wall_dir)) > WALL_SIDE_KEEP_DEG:
		_wall_side = 0.0
	var from := ball + Vector3.UP * 0.2
	for turn in WALL_TURNS:
		if turn * _wall_side < 0.0:
			continue
		var probe := dir.rotated(Vector3.UP, turn)
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + probe * WALL_REACH, 1))
		if hit.is_empty() or absf((hit["normal"] as Vector3).y) >= WALL_TILT:
			if turn != 0.0:
				_count("wall_turns", 1.0 / Engine.physics_ticks_per_second)
			_wall_side = signf(turn)
			_wall_dir = dir
			return probe * heading.length()
	if _wall_side != 0.0:
		_wall_side = 0.0
		return _around_walls(ball, heading)
	return heading


func _look(ball: Vector3, point: Vector3, pitch_to: bool, delta: float) -> void:
	var cam = game.camera
	var yaw: float = cam.yaw
	var pitch: float = cam.pitch
	if _defer_look:
		for waiting in _out:
			yaw += waiting["look"].x
			pitch += waiting["look"].y
	var flat := Vector3(point.x - ball.x, 0.0, point.z - ball.z)
	var dyaw := 0.0
	if flat.length() > 0.3:
		var want := atan2(-flat.x, -flat.z)
		dyaw = clampf(wrapf(want - yaw, -PI, PI), -TURN_RATE * delta, TURN_RATE * delta)
	var want_pitch := -0.30
	if pitch_to and flat.length() > 0.5:
		var lens: Vector3 = cam.aim_origin()
		var from_lens := Vector3(point.x - lens.x, 0.0, point.z - lens.z).length()
		want_pitch = clampf(atan2(point.y - lens.y, maxf(from_lens, 0.5)), -1.2, 0.5)
	var dpitch := clampf(want_pitch - pitch, -TURN_RATE * delta, TURN_RATE * delta)
	if _defer_look:
		_look_delta = Vector2(dyaw, dpitch)
		return
	cam.look(Vector2(-dyaw / SENSITIVITY, -dpitch / SENSITIVITY))


static func _aim_valid(aim) -> bool:
	if aim is Dictionary:
		return aim.has("at")
	return aim != null and is_instance_valid(aim)


func _aim_point(aim) -> Vector3:
	if aim is Dictionary:
		return aim["at"]
	var target: Node3D = aim
	return target.global_position + Vector3.UP * 1.2


func _contact_scan() -> void:
	if _note.is_empty() or _note.get("first_contact_s") != null or not game.flow.in_stage():
		return
	var ball: Vector3 = game.player.ball_position()
	for node in game.get_tree().get_nodes_in_group("enemy"):
		if not node is Node3D or not is_instance_valid(node):
			continue
		if node.has_method("is_dead") and node.is_dead():
			continue
		if ball.distance_to(node.global_position) <= CONTACT_RADIUS:
			_note["first_contact_s"] = snappedf(game.run.stage_time, 0.01)
			return


func contact_open() -> bool:
	return not _note.is_empty() and _note.get("first_contact_s") != null


func _note_contact_hit(hull: float) -> void:
	if _in_boss() or _note.is_empty():
		return
	var now := float(game.run.stage_time)
	if _note.get("first_hit_s") == null:
		_note["first_hit_s"] = snappedf(now, 0.01)
	if _note.get("first_contact_s") == null:
		_note["first_contact_s"] = snappedf(now, 0.01)
	if now - float(_note["first_contact_s"]) <= CONTACT_WINDOW_S:
		_note["hull_lost_120s"] = float(_note["hull_lost_120s"]) + hull


func _close_contact() -> void:
	_note["hull_lost_120s"] = snappedf(float(_note["hull_lost_120s"]), 0.1)
	_note["fight_s"] = snappedf(float(_note["fight_s"]), 0.01)
	_note["circle_s"] = snappedf(float(_note["circle_s"]), 0.01)
	if _note["first_contact_s"] != null:
		_note["alive_120s"] = snappedf(clampf(float(_note["exit_s"]) - float(_note["first_contact_s"]), 0.0, CONTACT_WINDOW_S), 0.01)
	if _note["alive_120s"] != null and float(_note["alive_120s"]) > 0.0:
		_note["circle_share"] = snappedf(float(_note["circle_s"]) / float(_note["alive_120s"]), 0.001)


func boss_hazards() -> Array:
	var boss = _boss() if game.flow.state_name() == "boss" else null
	return boss.active_hazards() if boss != null and boss.has_method("active_hazards") else []


func _pack_telegraphs() -> Dictionary:
	var out := {}
	for node in game.get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(node) or node == game.flow.warden:
			continue
		var t = node.get("_telegraph")
		if t != null and is_instance_valid(t):
			out[t] = true
	for child in game.get_children():
		if child.get_script() != null and String(child.get_script().resource_path).ends_with("projectile.gd"):
			var ring = child.get("ring")
			if ring != null and is_instance_valid(ring) and child.get("lobber") != game.flow.warden:
				out[ring] = true
	return out


func _nearest_enemy() -> Node3D:
	var ball: Vector3 = game.player.ball_position()
	var best: Node3D = null
	var best_d := AIM_REACH
	for node in game.get_tree().get_nodes_in_group("enemy"):
		if not node is Node3D or not is_instance_valid(node):
			continue
		if node.has_method("is_dead") and node.is_dead():
			continue
		var d := ball.distance_to(node.global_position)
		if d < best_d:
			best_d = d
			best = node
	return best


func _vault() -> Node3D:
	var world = game.world
	if world == null or world.vault == null or not is_instance_valid(world.vault):
		return null
	return world.vault


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func record(wall_seconds: float) -> Dictionary:
	var row := {
		"run_id": game.run.run_id, "policy": policy, "profile": profile, "seed": seed_value, "class": class_id(),
		"outcome": outcome, "stage_reached": game.run.stage, "ticks": ticks,
		"game_seconds": snappedf(float(ticks) / float(Engine.physics_ticks_per_second), 0.01),
		"wall_seconds": snappedf(wall_seconds, 0.01), "stages": stage_notes,
		"boss": boss_note if not boss_note.is_empty() else null,
		"reaction_s": _reaction(),
		"fairness": _fair.record(outcome == "died" or outcome == "lost"),
		"band": band.describe() if band else null,
		"min_hp": snappedf(_min_hp, 0.1) if _min_hp != INF else null, "max_hp": game.run.max_hp,
		"slot_casts": {"special": _totals["slot_casts_special"], "line": _totals["slot_casts_line"]},
		"shots": _totals["shots"], "kills": game.run.kills, "ultimates": _totals["ultimates"], "ult_presses": _totals["ult_presses"],
		"cadence_windows": _totals["cadence_windows"], "cadence_hits": _totals["cadence_hits"],
		"active_presses": _totals["active_presses"],
		"tree_picks": tree_picks.duplicate(),
		"ult_fill_s": _fills, "play_s": snappedf(_play_clock, 0.01),
		"ult_sources": _meter_sources(), "ult_sources_first_fill": _first_fill_sources,
	}
	if late_offer_policy != "":
		row["late_offer"] = {"policy": late_offer_policy, "tree_picks": tree_picks.size()}
		row["late_offer"].merge(late_offer_counts)
	var dials := ChallengeDials.describe()
	if not dials.is_empty():
		row["dials"] = dials
	var spawner = game.ctx.spawner
	var pressure_dials := dials.keys().any(func(k: String) -> bool: return k.begins_with("pack.") or k.begins_with("ground.") or k.begins_with("hazard."))
	if spawner != null and spawner.get("churn") != null and (pressure_dials or spawner.boils.boils > 0):
		row["pressure"] = {"churn_drag_s": snappedf(spawner.churn.drag_s, 0.01), "churned_cells": spawner.churn.churned_cells,
			"boils": spawner.boils.boils, "boil_hits": spawner.boils.ball_hits, "boil_tosses": spawner.boils.enemy_tosses}
	return row
