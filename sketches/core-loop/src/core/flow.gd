extends Node

const EventKinds := preload("res://src/core/event_kinds.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Beacon := preload("res://src/core/beacon.gd")
const Worlds := preload("res://src/core/worlds.gd")
const Secrets := preload("res://src/core/secrets.gd")
const Companion := preload("res://src/core/companion.gd")
const RunState := preload("res://src/core/run_state.gd")
const RunStore := preload("res://src/core/run_store.gd")
const RunTier := preload("res://src/core/run_tier.gd")
const ShiftVariants := preload("res://src/core/shift_variants.gd")
const DeathCause := preload("res://src/core/death_cause.gd")
const SpeedTier := preload("res://src/movement/speed_tier.gd")
const DeathTips := preload("res://src/core/death_tips.gd")
const UpgradeTree := preload("res://src/core/upgrade_tree.gd")
const StartPickCard := preload("res://src/ui/start_pick_card.gd")
const VictoryLap := preload("res://src/world/victory_lap.gd")
const SlagBowl := preload("res://src/boss/arena.gd")
const EventDirector := preload("res://src/world/event_director.gd")


enum { TITLE, CLASS_SELECT, STAGE, BEACON, GATES, LAUNCH, SUMMARY, DEAD, BOSS, VICTORY, LAP }

const NAMES := ["title", "class_select", "stage", "beacon", "gates", "launch", "summary", "dead", "boss", "victory", "lap"]
const VICTORY_SECONDS := 2.5
const BOSS_WON_KEY := "boss_won"
const LAUNCH_FLIGHT := 0.6
const ENTRY_LIFT := 14.0
const FIRST_DROP_SPEED := 0.8
const RESCUE_DEPTH := 14.0
const NET_DECK_SLACK := 2.0
const NET_DAMP := 0.5

var ctx
var start_card
const START_CARD_TOP := 160.0
const BRIEFING_CENTRE := 0.6
var beacon
var state := TITLE
var classes: Array[Resource] = []
var beacon_seconds_override := -1.0
var force_warden := false
var sealed := false
var warden: Node3D = null
var gate = null
var boss_active := false
var boss_plating := 120.0
var in_arena := false
var death_cause := ""
var death_tip := ""
var _arrival := {}
var _last_hit_source := ""
var _victory_left := 0.0
var victory_plan := Callable()
var victory_veil := 0.0
var _victory_hold := 0.0
var _engaged := false
var _sighted := false
const SIGHT_SHARE := 3.5
var _warden_at := Vector3.ZERO
const SEALED_CAP := 0.99
const WARDEN_MATCH := 6.0
var _warned := {}

var boss_row_override := {}
const SCENE_BOSS := "res://src/boss/boss.gd"
var _row_modules := {}
var _boss_reads := {}
var _boss_warms := {}
var _home_boss: Node = null
var _world := 0
var _launched := false
var _flight := 0.0
var _seam_take := false
var _taken_part := ""
var _last_percent := -1

var store = null
var store_error := ""
var continue_ready := false
var saved_run_cause := ""
var saved_run_why := ""
const INVALID_RUN_SENTENCE := "The saved run does not fit this version of the game, so it cannot be continued."
var run_won := false
var victory_lap := true
var lap: Node3D = null
var lap_stats := {}
var _entrance := {}
var _save_spend_owed := false
var _owed_entrance := {}
var _draw_panel := Callable()


func setup(ctx_ref, beacon_ref, draw_panel_fn := Callable()) -> void:
	ctx = ctx_ref
	beacon = beacon_ref
	_draw_panel = draw_panel_fn
	classes = ClassDef.all()
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	start_card = StartPickCard.new()
	layer.add_child(start_card)
	start_card.pick_requested.connect(take_start_pick)
	start_card.reroll_requested.connect(reroll_start_pick)
	start_card.tier_requested.connect(func(value: int): if not _start_card_covered(): choose_run_tier(value))
	start_card.covered = _start_card_covered
	ctx.events.player_hit.connect(func(_amount: float, source: String): _last_hit_source = source)
	ctx.events.player_died.connect(_on_player_died)
	ctx.run.death_saved.connect(func(_hp: float): _on_death_saved())
	ctx.events.reward_chosen.connect(_on_reward_chosen)
	ctx.events.launched.connect(_on_launched)
	ctx.events.enemy_killed.connect(_on_enemy_killed)
	ctx.events.enemy_struck.connect(_on_enemy_struck)
	ctx.events.boss_defeated.connect(_on_boss_defeated)
	ctx.events.activity_done.connect(func(_id: String, _at: Vector3): _persist_companion())


func state_name() -> String:
	return NAMES[state]


func trace_snapshot() -> Dictionary:
	return {
		"launched": _launched,
		"flight": _flight,
		"seam_take": _seam_take,
	}


func engaged() -> bool:
	return _engaged


func warden_fight_live() -> bool:
	if not sealed or not is_instance_valid(warden) or not engaged():
		return false
	return not (warden.has_method("is_dead") and warden.is_dead())


func in_play() -> bool:
	return state == STAGE or state == BEACON or state == GATES or state == LAUNCH or state == BOSS or state == LAP


func calm() -> bool:
	return state == GATES or state == LAUNCH


func in_stage() -> bool:
	return state == STAGE or state == BEACON or state == GATES or state == LAUNCH


func _boss_module() -> Node:
	if ctx.stages.BOSS == "":
		return null
	return _module_for(ctx.stages.world_of(ctx.run.stage))


func _module_for(world: int) -> Node:
	var path := String(boss_row(world).get("script", SCENE_BOSS))
	if path == SCENE_BOSS:
		return _scene_boss()
	if not _row_modules.has(path):
		_row_modules[path] = _load_module(path)
	return _row_modules[path]


func _scene_boss() -> Node:
	var boss: Node = _home_boss if is_instance_valid(_home_boss) else (ctx.boss if "boss" in ctx else null)
	return boss if boss != null and boss.has_method("enter_arena") else null


# Settle threaded boss loads before teardown; unsettled loader threads abort Godot on quit (exit 134).
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_flush_save_spend()


func _exit_tree() -> void:
	_flush_save_spend()
	for path in _boss_reads:
		var script = _boss_reads[path]
		if script == null and ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			script = ResourceLoader.load_threaded_get(path)
		if script is Script and script.get_script_method_list().any(func(m): return m.name == "settle_arena"):
			script.call("settle_arena")
	EventDirector.settle_prewarm()
	SlagBowl.drop_ahead()


func _load_module(path: String) -> Node:
	if not ResourceLoader.exists(path):
		warn_once("boss_script_" + path, "flow: boss script %s does not exist" % path)
		return null
	var script = _boss_reads.get(path)
	if not script is Script:
		script = ResourceLoader.load_threaded_get(path) if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE else null
	if not script is Script:
		script = load(path)
	var module: Node = script.new()
	add_child(module)
	module.setup(ctx)
	return module


func _read_boss_ahead() -> void:
	if ctx.stages.BOSS == "" or not ctx.stages.is_world_last(ctx.run.stage):
		return
	var row: Dictionary = boss_row(ctx.stages.world_of(ctx.run.stage))
	var path := String(row.get("script", SCENE_BOSS))
	if not bool(row.get("built", false)) or _row_modules.has(path):
		return
	if path == SCENE_BOSS:
		if _scene_boss() != null:
			SlagBowl.warm_ahead()
		return
	if not _boss_reads.has(path):
		_boss_reads[path] = null
		if not ResourceLoader.exists(path) or ResourceLoader.load_threaded_request(path) != OK:
			_boss_reads[path] = false
		return
	if _boss_reads[path] != null:
		if _boss_reads[path] is Script:
			if not _boss_warms.has(path):
				_boss_warms[path] = _boss_reads[path].get_script_method_list().any(func(m): return m.name == "warm_arena")
			if _boss_warms[path] and _boss_reads[path].call("warm_arena"):
				_boss_warms[path] = false
		return
	var status := ResourceLoader.load_threaded_get_status(path)
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return
	var script = ResourceLoader.load_threaded_get(path) if status == ResourceLoader.THREAD_LOAD_LOADED else null
	_boss_reads[path] = script if script is Script else false
	if script is Script and script.get_script_method_list().any(func(m): return m.name == "prepare_arena"):
		script.call("prepare_arena")


func boss_row(world: int) -> Dictionary:
	return boss_row_override.get(world, Worlds.boss_of(world))


func won_final() -> bool:
	return run_won and _final_world_cleared()


func _final_world_cleared() -> bool:
	var world: int = ctx.stages.world_of(ctx.run.stage)
	var boss_table: bool = ctx.stages.BOSS != "" or world == int(Worlds.ROWS.back()["id"])
	return ctx.stages.is_run_last(ctx.run.stage) and bool(boss_row(world).get("built", false)) and boss_table


func run_ends_after(stage: int) -> bool:
	if ctx.stages.is_run_last(stage):
		return true
	var final_world: int = ctx.tuning.final_world() if ctx.tuning != null else 0
	return final_world > 0 and ctx.stages.world_of(stage) == final_world and ctx.stages.is_world_last(stage)


func run_stage_count() -> int:
	var final_world: int = ctx.tuning.final_world() if ctx.tuning != null else 0
	var last: int = ctx.stages.last_of(final_world) if final_world > 0 else 0
	return last if last > 0 else int(ctx.stages.COUNT)


func _ending_due() -> bool:
	return _final_world_cleared() and String(boss_row(ctx.stages.world_of(ctx.run.stage)).get("music", "")) == "mind"

func _world_boss(world: int) -> Node:
	if ctx.stages.BOSS == "":
		return null
	var row: Dictionary = boss_row(world)
	if not bool(row.get("built", false)):
		warn_once("boss_unbuilt_%d" % world, "flow: world %d's boss is not built; skipping to the next world" % world)
		return null
	var module := _module_for(world)
	if module == null and ctx.stages.worlds().size() > 1:
		warn_once("boss_module_%d" % world, "flow: no boss module in the scene for world %d; skipping to the next world" % world)
	return module


func final_stage() -> int:
	return ctx.stages.last_of(ctx.stages.world_of(ctx.run.stage))


func stage() -> int:
	return ctx.run.stage


func stage_def() -> Dictionary:
	return ShiftVariants.stage_def(ctx.stages.of(ctx.run.stage), ctx.run, ctx.run.stage)


func stage_look_id() -> String:
	return ShiftVariants.look_id(ctx.run, ctx.run.stage)


func _is_bot() -> bool:
	return ctx != null and ctx.root != null and bool(ctx.root.get("bot_driven"))


func show_title() -> void:
	_flush_save_spend()
	_drop_lap()
	ctx.player.set_frozen(true)
	state = TITLE
	ctx.events.flow_changed.emit(NAMES[TITLE])


func open_class_select() -> void:
	if not in_play():
		ctx.player.set_frozen(true)
		_set_state(CLASS_SELECT)


func press_start() -> void:
	if state == TITLE or state == SUMMARY:
		_set_state(CLASS_SELECT)


func choose_class(index: int) -> void:
	if state != CLASS_SELECT or index < 0 or index >= classes.size():
		return
	_begin_run(classes[index])


func launch_from_title(chosen: Resource) -> bool:
	if state != TITLE or chosen == null:
		return false
	_begin_run(chosen)
	return true


func new_run() -> void:
	if ctx.run.class_def == null:
		_set_state(CLASS_SELECT)
		return
	_begin_run(ctx.run.class_def)


func show_start_card() -> void:
	var take = ctx.root.get("launch_take")
	var host = ctx.root.get_node_or_null("Workshop")
	var interactive: bool = not ctx.root.bot_driven and not (take != null and take.busy())
	var briefing: bool = host != null and host.armed
	start_card.set_interactive(interactive)
	start_card.set_briefing(briefing)
	start_card.show_picks(ctx.run, ctx.profile)
	var view := get_viewport().get_visible_rect().size
	start_card.position = Vector2((view.x - start_card.size.x) * 0.5,
		maxf(START_CARD_TOP, (view.y - start_card.size.y) * BRIEFING_CENTRE) if briefing else START_CARD_TOP)
	if not interactive or not in_stage() or (host != null and host.kit_pick_due()) or start_pick_waits():
		start_card.hide_card()
	if host != null:
		host.sync_start_card_pointer()
		host.sync_briefing()


func start_pick_waits() -> bool:
	return start_pick_at_yard() and gate.yard_ahead()


func start_pick_open() -> bool:
	return start_card != null and start_card.visible


func start_pick_at_yard() -> bool:
	return ctx.run.stage == 1 and gate != null and not gate.lock_row().is_empty() \
			and RunTier.top_unlocked(ctx.profile) < RunTier.HARD


func _start_card_covered() -> bool:
	var game = ctx.root
	var menu = game.get_node_or_null("PauseMenu")
	return menu != null and menu.is_open()


func take_start_pick(index: int) -> bool:
	var taken: bool = in_stage() and not _start_card_covered() and ctx.run.take_start_pick(index)
	show_start_card()
	return taken


func reroll_start_pick() -> bool:
	var rerolled: bool = in_stage() and not _start_card_covered() and ctx.run.reroll_start_pick()
	show_start_card()
	return rerolled


func choose_run_tier(value: int, check_unlock := true) -> bool:
	if not (state == STAGE or state == BEACON) or not ctx.run.select_run_tier(value, ctx.profile, check_unlock):
		return false
	if ctx.build != null:
		ctx.build.recompute()
	if store != null and not _entrance.is_empty():
		if value == 0:
			_entrance.erase("run_tier")
			_entrance.erase("event_core_grants")
		else:
			_entrance["run_tier"] = value
			_entrance["event_core_grants"] = int(_entrance.get("event_core_grants", 0))
		_save(_entrance)
	show_start_card()
	return true


func _begin_run(chosen: Resource) -> void:
	_untake()
	_flush_save_spend()
	if store == null:
		_clear_save_spend()
	in_arena = false
	boss_active = false
	lap_stats = {}
	_world = 0
	death_cause = ""
	death_tip = ""
	_arrival = {}
	_last_hit_source = ""
	if ctx.run_log != null:
		ctx.run_log.abandon_open_run()
	if ctx.profile != null and ctx.profile.settle_previous_run_tallies() and ctx.profile.can_save and not ctx.profile.save():
		warn_once("profile_tally_save", "flow: earlier run tallies not saved: %s" % ctx.profile.last_error)
	run_won = false
	if ctx.profile != null:
		ctx.profile.set_last_pilot(chosen.id)
	Secrets.roll_door(ctx.profile)
	var variant_debuts := ShiftVariants.consume_debuts(ctx.profile, _is_bot())
	_save_profile("profile_door_save")
	ctx.run.route_seed = int(ctx.tuning.base("route_seed")) if ctx.tuning != null else 0
	ctx.run.begin(chosen)
	ShiftVariants.attach_run(ctx.run, ctx.profile, variant_debuts, _is_bot())
	_seed_companion()
	_taken_part = ""
	ctx.events.run_started.emit(chosen.id)
	if store != null and not store.keep_prev():
		warn_once("run_prev_backup", "flow: could not keep the old run: %s" % store.last_error)
	var heading: Vector3 = ctx.terrain.entry_heading(1)
	enter_stage(1, heading * ctx.tuning.f("cruise") * FIRST_DROP_SPEED, false)
	show_start_card()


func _stage_fit_error(doc: Dictionary) -> String:
	if ctx == null or ctx.stages == null:
		return ""
	var stage := int(doc["stage"])
	var count: int = ctx.stages.DEFS.size()
	if stage > count:
		return "stage %d is past this table's %d stages" % [stage, count]
	return ""


func saved_run() -> Dictionary:
	continue_ready = false
	saved_run_cause = ""
	saved_run_why = ""
	if store == null:
		return {}
	var doc: Dictionary = store.load()
	if doc.is_empty():
		if store.refusal == RunStore.REFUSED_CHANGED or (store.refusal == "" and store.last_error != ""):
			saved_run_cause = "unreadable"
		elif store.refusal != RunStore.REFUSED_ENDED:
			saved_run_cause = store.refusal
		saved_run_why = store.last_error
		return {}
	var why := RunState.validate_entrance_doc(doc)
	if why == "" and ClassDef.by_id(String(doc["class_id"])) == null:
		why = "unknown pilot %s" % doc["class_id"]
	if why == "":
		why = _stage_fit_error(doc)
	if why != "":
		saved_run_cause = "invalid_run"
		saved_run_why = why
		return {}
	continue_ready = true
	return doc


func continue_refusal() -> String:
	if continue_ready or store == null:
		return ""
	if saved_run_cause == "invalid_run":
		return INVALID_RUN_SENTENCE
	return store.refusal_sentence()


func resume_run() -> bool:
	if in_play():
		return false
	var doc := saved_run()
	if doc.is_empty():
		return false
	var chosen: Resource = ClassDef.by_id(String(doc["class_id"]))
	in_arena = false
	boss_active = false
	run_won = false
	_world = 0
	if ctx.run_log != null:
		ctx.run_log.abandon_open_run()
	ctx.run.begin(chosen)
	_taken_part = ""
	ctx.events.run_started.emit(chosen.id)
	ctx.run.from_entrance_doc(doc)
	if _save_spend_owed:
		doc["death_save_spent"] = true
		ctx.run.death_save_spent = true
	_keep_found_pieces()
	if ctx.progress != null:
		ctx.progress.reconcile_settled()
	if ctx.build != null and ctx.build.has_method("sync_relics"):
		ctx.build.sync_relics()
	_apply_tree_picks()
	var p: Array = doc["entry_velocity"]
	if ctx.run.cleared:
		_entrance = doc
		if _save_spend_owed:
			_owed_entrance = doc.duplicate(true)
		_flush_save_spend()
		if ctx.run.extra.has(BOSS_WON_KEY):
			_resume_after_boss(Vector3(p[0], p[1], p[2]))
		else:
			_finish_stage(Vector3(p[0], p[1], p[2]))
	else:
		enter_stage(ctx.run.stage, Vector3(p[0], p[1], p[2]), false)
	show_start_card()
	return true


func _tree():
	return ctx.player.get("tree") if ctx.player != null else null


func _apply_tree_picks() -> void:
	var tree = _tree()
	if tree == null:
		return
	var world: int = ctx.stages.world_of(ctx.run.stage)
	var final_world_one: bool = ctx.tuning.world_one() and world == 1
	tree.max_depth = UpgradeTree.depth_cap(world) if ctx.tuning.world_one() else UpgradeTree.DEPTHS
	tree.world_one = final_world_one
	var saved: Array[String] = ctx.run.tree_picks.duplicate()
	var allowed: int = ctx.run.tree_allowed
	tree.restore_late_skip(ctx.run.tree_late_skipped)
	tree.allowed = saved.size()
	for id in saved:
		var picked_ok: bool = tree.pick(id)
		if not picked_ok and ctx.tuning.world_one() and not tree.world_one and tree.picks.size() < UpgradeTree.depth_cap(1):
			tree.world_one = true
			picked_ok = tree.pick(id)
			tree.world_one = final_world_one
		if not picked_ok:
			warn_once("resume_pick", "flow: saved tree pick %s does not fit the tree; later picks dropped" % id)
			break
	tree.world_one = final_world_one
	if allowed > tree.picks.size():
		tree.allowed = allowed - 1
		tree.open_checkpoint()
	else:
		tree.allowed = maxi(allowed, tree.picks.size())


func _on_death_saved() -> void:
	if store == null:
		return
	_save_spend_owed = true
	if _entrance.is_empty():
		return
	_entrance["death_save_spent"] = true
	_owed_entrance = _entrance.duplicate(true)
	_save(_entrance)


func _flush_save_spend() -> void:
	if not _save_spend_owed or store == null:
		return
	var doc: Dictionary = _owed_entrance if not _owed_entrance.is_empty() else _entrance
	if doc.is_empty():
		return
	doc["death_save_spent"] = true
	_save(doc)


func _clear_save_spend() -> void:
	_save_spend_owed = false
	_owed_entrance = {}


func _seed_companion() -> void:
	if ctx.profile != null and ctx.run.companion.is_empty():
		ctx.run.companion = profile_companion()


func profile_companion() -> Dictionary:
	var fixed: Array = Companion.sanitize(ctx.profile.companion())
	if fixed[1] != "":
		warn_once("profile_companion", "flow: %s" % fixed[1])
	return fixed[0]


func _keep_found_pieces() -> void:
	if ctx.profile == null:
		return
	for id in profile_companion().get("owned", []):
		if not ctx.run.companion.get("owned", []).has(id):
			ctx.run.companion = Companion.with_piece(ctx.run.companion, String(id))


func _persist_companion() -> void:
	_keep_found_pieces()
	var whole: Dictionary = ctx.run.companion_whole()
	if ctx.profile == null or whole.is_empty() or profile_companion() == whole:
		return
	ctx.profile.set_companion(whole)
	if ctx.profile.can_save and not ctx.profile.save():
		warn_once("profile_companion_save", "flow: companion not saved to the profile: %s" % ctx.profile.last_error)


func _save_profile(warn_id: String) -> void:
	if ctx.profile != null and ctx.profile.can_save and not ctx.profile.save():
		warn_once(warn_id, "flow: profile not saved: %s" % ctx.profile.last_error)


func _save(doc: Dictionary) -> void:
	if _save_spend_owed and ctx != null and ctx.run != null and ctx.run.death_save_spent:
		doc["death_save_spent"] = true
	_persist_companion()
	store_error = store.save(doc)
	if store_error == "" and _save_spend_owed:
		_clear_save_spend()
	elif store_error != "" and _save_spend_owed and bool(doc.get("death_save_spent", false)):
		_owed_entrance = doc.duplicate(true)
	if store_error != "":
		warn_once("run_save_" + store_error, "flow: run not saved (%s): %s" % [store_error, store.last_error])


func enter_stage(index: int, carried: Vector3, retry: bool) -> void:
	ctx.run.enter_stage(index)
	var world: int = ctx.stages.world_of(index)
	ctx.run.world = world
	if not retry and world != _world:
		_world = world
		ctx.events.world_entered.emit(world)
	_launched = false
	_flight = 0.0
	_last_percent = -1
	ctx.run.snapshot(Vector3.ZERO, Vector3.ZERO, ctx.camera.yaw)
	var doc: Dictionary = ctx.run.to_entrance_doc(_tree()) if store != null else {}
	seed_stage_stream(index)
	ctx.events.stage_entered.emit(index, retry)
	var heading: Vector3 = ctx.terrain.entry_heading(index)
	var flat := Vector2(carried.x, carried.z).length()
	var velocity := heading * flat + Vector3.UP * carried.y
	var at: Vector3 = ctx.terrain.spawn_point(index) + Vector3.UP * ENTRY_LIFT
	_place_ball(at, velocity, heading)
	_place_beacon()
	ctx.run.set_snapshot_entry(at, velocity, ctx.camera.yaw)
	if store != null:
		doc["entry_position"] = [at.x, at.y, at.z]
		doc["entry_velocity"] = [velocity.x, velocity.y, velocity.z]
		doc["camera_yaw"] = ctx.camera.yaw
		_entrance = doc
		_save(doc)
	_set_state(STAGE)


func seed_stage_stream(index: int, place: String = "stage") -> void:
	if ctx.rng != null and ctx.run != null:
		var mixed := RandomNumberGenerator.new()
		mixed.seed = hash([ctx.rng.seed, run_key(), index, place])
		ctx.rng.state = mixed.state


func run_key() -> int:
	if ctx.run == null:
		return 0
	if ctx.run.run_seed_override == null and ctx.run.route_seed <= 0 and ctx.root != null and bool(ctx.root.get("test_mode")):
		return 0
	return ctx.run.run_seed


func retry_stage() -> void:
	if not ctx.run.has_snapshot() or state == TITLE or state == CLASS_SELECT or state == SUMMARY or state == VICTORY or state == LAP:
		return
	_flush_save_spend()
	if in_arena:
		_retry_arena()
		return
	_untake()
	ctx.run.restore()
	ShiftVariants.on_stage_retry(ctx.run)
	_launched = false
	_flight = 0.0
	_last_percent = -1
	seed_stage_stream(ctx.run.stage)
	ctx.events.stage_entered.emit(ctx.run.stage, true)
	var velocity: Vector3 = ctx.run.snapshot_value("entry_velocity")
	_place_ball(ctx.run.snapshot_value("entry_position"), velocity, velocity)
	ctx.camera.yaw = ctx.run.snapshot_value("camera_yaw")
	_place_beacon()
	_set_state(STAGE)
	show_start_card()


func replay_stage(index: int) -> bool:
	if not ctx.run.use_stage_start(index):
		return false
	boss_active = false
	in_arena = false
	retry_stage()
	return true


func enter_boss(carried: Vector3) -> void:
	var boss := _boss_module()
	if "boss" in ctx and ctx.boss != boss:
		if not is_instance_valid(_home_boss):
			_home_boss = ctx.boss
		ctx.boss = boss
	in_arena = true
	ctx.run.snapshot(Vector3.ZERO, Vector3.ZERO, ctx.camera.yaw)
	_set_state(BOSS)
	ctx.events.stage_content_cleared.emit("arena")
	ctx.player.set_frozen(false)
	seed_stage_stream(ctx.run.stage, "arena")
	boss.enter_arena(carried)
	_arrival = _met(_boss_called(), boss_plating_now())
	ctx.run.set_snapshot_entry(ctx.player.ball_position(), ctx.player.state.velocity, ctx.camera.yaw)


func _retry_arena() -> void:
	var boss := _boss_module()
	if boss == null and "boss" in ctx and is_instance_valid(ctx.boss) and ctx.boss.has_method("enter_arena"):
		boss = ctx.boss
	ctx.run.restore()
	ctx.player.set_frozen(false)
	if boss == null:
		warn_once("arena_retry", "flow: no boss module to retry the arena against; moving on")
		in_arena = false
		boss_active = false
		_advance_from(ctx.run.stage)
		return
	_set_state(BOSS)
	ctx.events.stage_content_cleared.emit("arena_retry")
	seed_stage_stream(ctx.run.stage, "arena")
	boss.enter_arena(ctx.run.snapshot_value("entry_velocity"))
	_arrival = _met(_boss_called(), boss_plating_now())


func boss_plating_now() -> float:
	var boss := _boss_module()
	if boss != null and boss.has_method("live_plating"):
		return float(boss.live_plating())
	return boss_plating


func _boss_objective() -> String:
	var boss := _boss_module()
	if boss != null and boss.has_method("objective_text"):
		var text := String(boss.objective_text())
		if text != "":
			return text
	return EventKinds.objective("boss_arena_entered", {"punch": int(punch_now()), "plating": int(boss_plating_now())})


const ARENA_FALL := 40.0


func _rescue_in_arena(ball: Vector3) -> void:
	if not ball.is_finite():
		_rescue_lost_ball()
		return
	var boss := _boss_module()
	var floor_y: float = boss.floor_y() if boss != null and boss.has_method("floor_y") and boss.has_method("rescue_point") else NAN
	var landing: Vector3
	if is_finite(floor_y):
		if ball.y >= floor_y:
			return
		landing = boss.rescue_point()
		if not landing.is_finite():
			landing = ctx.run.snapshot_value("entry_position")
	else:
		var entry: Vector3 = ctx.run.snapshot_value("entry_position")
		if ball.y >= entry.y - ARENA_FALL:
			return
		warn_once("arena_rescue", "flow: boss module has no floor_y()/rescue_point(); rescuing to the arena entry")
		landing = entry
	var v: Vector3 = ctx.player.state.velocity
	ctx.player.reset_to(landing, Vector3(v.x, 0.0, v.z))


const BURST_PER_STAGE := 20


func discovery_burst(at: Vector3) -> void:
	ctx.run.add_scrap(BURST_PER_STAGE * ctx.run.stage, at)
	ctx.run.add_cogs(BURST_PER_STAGE * ctx.run.stage)
	ctx.events.cogs_collected.emit(BURST_PER_STAGE * ctx.run.stage, ctx.run.cogs)


func can_replay_final_stage() -> bool:
	return boss_active and ctx.run.has_stage_start(final_stage())


func _fight_gap() -> Dictionary:
	if state == BOSS or (state in [STAGE, BEACON] and sealed and _engaged and is_instance_valid(warden)):
		return _arrival
	return {}


func _met(who: String, plating: float) -> Dictionary:
	return {"who": who, "punch": build_punch(), "plating": plating}


func _boss_called() -> String:
	var called := String(boss_row(ctx.stages.world_of(ctx.run.stage)).get("name", "the boss"))
	return "the " + called.substr(4) if called.begins_with("The ") else called


func build_punch() -> float:
	var punch := punch_now()
	if ctx.spawner != null and ctx.spawner.has_method("punch_of") and ctx.spawner.has_method("panel_punch"):
		punch = maxf(punch, ctx.spawner.punch_of("ram", ctx.player.tuning.tier_cruise()) + ctx.spawner.panel_punch("ram", "ram_or_contact"))
	return punch


func arrival_heading_after(stage: int) -> Vector3:
	if ctx.stages.is_world_last(stage) and ctx.stages.BOSS != "":
		var row: Dictionary = boss_row(ctx.stages.world_of(stage))
		if bool(row.get("built", false)):
			var path := String(row.get("script", SCENE_BOSS))
			var boss = _scene_boss() if path == SCENE_BOSS else _row_modules.get(path)
			if is_instance_valid(boss) and boss.has_method("arrival_heading"):
				return boss.arrival_heading()
			return Vector3.ZERO
	if ctx.stages.is_run_last(stage):
		return Vector3.ZERO
	return ctx.terrain.entry_heading(stage + 1)


func _place_ball(at: Vector3, velocity: Vector3, heading: Vector3) -> void:
	ctx.player.set_frozen(false)
	ctx.player.reset_to(at, velocity)
	ctx.camera.snap(heading)


func _place_beacon() -> void:
	var def := stage_def()
	var seconds: float = beacon_seconds_override if beacon_seconds_override >= 0.0 else def["beacon_seconds"]
	var radius: float = def["beacon_radius"]
	if ctx.stages == preload("res://src/core/park_defs.gd"):
		const ParkMap := preload("res://src/world/park/park_map.gd")
		var map = ctx.terrain.map()
		if map is ParkMap and map.ok:
			radius = map.reach_m
	beacon.place(ctx.terrain.beacon_point(ctx.run.stage), seconds, radius)
	if is_instance_valid(warden):
		warden.queue_free()
	_engaged = false
	_arrival = {}
	_sighted = false
	sealed = (not ctx.calm) or force_warden
	warden = _spawn_warden() if sealed else null
	_warden_at = warden.global_position if warden != null else Vector3.ZERO
	if warden == null:
		sealed = false


func _spawn_warden() -> Node3D:
	if not ctx.can_spawn():
		return null
	var spawned = ctx.spawner.spawn_enemy("warden", ctx.terrain.beacon_point(ctx.run.stage))
	return spawned if spawned is Node3D else null


func warden_integrity() -> float:
	if not is_instance_valid(warden):
		return 1.0
	if not ctx.spawner.has_method("integrity_of"):
		warn_once("integrity_of", "flow: spawner has no integrity_of(); the Warden charge reads 0")
		return 1.0
	return ctx.spawner.integrity_of(warden)


func punch_now() -> float:
	if ctx.spawner == null or not ctx.spawner.has_method("punch_now"):
		warn_once("punch_now", "flow: spawner has no punch_now(); punch reads 0")
		return 0.0
	return ctx.spawner.punch_now()


func warden_plating() -> float:
	if is_instance_valid(warden) and ctx.spawner.has_method("plating_of"):
		return ctx.spawner.plating_of(warden)
	if is_instance_valid(warden):
		warn_once("plating_of", "flow: spawner has no plating_of(); showing the stage's warden_plating")
	return stage_def()["warden_plating"]


func warn_once(key: String, message: String) -> void:
	if _warned.has(key):
		return
	_warned[key] = true
	push_warning(message)


func physics_step(delta: float) -> void:
	if state == VICTORY:
		if not run_ends_after(ctx.run.stage):
			_prewarm_next_stage_events()
		_victory_left -= delta
		if _victory_left <= 0.0:
			_advance_from(ctx.run.stage)
		return
	if state == LAP:
		if not is_instance_valid(lap) or lap.step(delta):
			_close_lap()
		return
	if not in_play():
		return
	ctx.run.advance(delta, ctx.player.speed_tier() >= SpeedTier.CRUISE)
	if state == BEACON or state == GATES or state == LAUNCH:
		_read_boss_ahead()
	if state == GATES or state == LAUNCH:
		_prewarm_next_stage_events()
	var ball: Vector3 = ctx.player.ball_position()
	match state:
		STAGE, BEACON:
			if sealed and not is_instance_valid(warden):
				_warden_vanished()
				return
			var done: bool = beacon.advance(delta, ball, sealed)
			if sealed:
				var charge: float = 1.0 - warden_integrity()
				beacon.show_progress(beacon.duration * minf(SEALED_CAP, charge))
				var to_warden := Vector2(ball.x - _warden_at.x, ball.z - _warden_at.z).length()
				var yard_waiting: bool = gate != null and gate.yard_ahead()
				if beacon.phase != Beacon.IDLE or ShiftVariants.wakes_warden(ctx.run, beacon.radius, to_warden, yard_waiting):
					_engage()
				else:
					_read_sighting(ball)
			if state == STAGE and beacon.phase != Beacon.IDLE:
				_set_state(BEACON)
			var percent := int(beacon.fraction() * 100.0)
			if percent != _last_percent and not done:
				_last_percent = percent
				ctx.events.beacon_charge_changed.emit(beacon.fraction())
			if done:
				_set_state(GATES)
				ctx.events.beacon_charge_changed.emit(1.0)
		LAUNCH:
			if _launched:
				_flight += delta
				if _flight >= LAUNCH_FLIGHT and not _seam_take:
					_finish_stage()
		BOSS:
			_rescue_in_arena(ball)
			return
	_rescue_if_fallen(ball)


func _finish_stage(velocity = null) -> void:
	var carried: Vector3 = ctx.player.state.velocity if velocity == null else velocity
	var cleared: int = ctx.run.stage
	if not ctx.run.landed:
		ctx.events.stage_cleared.emit(cleared)
	var world: int = ctx.stages.world_of(cleared)
	if ctx.stages.is_world_last(cleared) and _world_boss(world) != null:
		if world != _world:
			_world = world
			ctx.events.world_entered.emit(world)
		ctx.run.landed = true
		_save_cleared(carried)
		enter_boss(carried)
		return
	_advance_from(cleared, carried)


func _advance_from(cleared: int, velocity = null) -> void:
	if run_ends_after(cleared):
		_end_run_won()
		return
	_settle_brindle_cobalt_pick()
	enter_stage(cleared + 1, ctx.player.state.velocity if velocity == null else velocity, false)


func _settle_brindle_cobalt_pick() -> void:
	if ctx == null or ctx.run == null or not ctx.run.extra.has("brindle_cobalt_pending"):
		return
	var pending := String(ctx.run.extra["brindle_cobalt_pending"])
	ctx.run.extra.erase("brindle_cobalt_pending")
	if pending == "" or String(ctx.run.extra.get("brindle_cobalt_picked", "")) != "":
		return
	if ctx.build != null and ctx.build.has_method("scrapless") and ctx.build.scrapless():
		return
	ctx.run.extra["brindle_cobalt_picked"] = pending
	ctx.run.add_part(pending, "boss_cobalt")


func _prewarm_next_stage_events() -> void:
	if ctx == null or ctx.terrain == null or ctx.run == null or ctx.stages == null:
		return
	var next_stage: int = ctx.run.stage + 1
	if next_stage <= int(ctx.stages.COUNT):
		EventDirector.prewarm_stage_families(ctx.terrain, next_stage)


func _resume_after_boss(velocity: Vector3) -> void:
	ctx.run.extra.erase(BOSS_WON_KEY)
	_advance_from(ctx.run.stage, velocity)


func save_boss_won() -> void:
	_save_boss_won()


func _save_boss_won() -> void:
	if store == null or ctx.run.over or state != VICTORY:
		return
	var v: Vector3 = ctx.player.state.velocity
	var doc: Dictionary = ctx.run.to_cleared_doc(_tree(), v)
	doc[BOSS_WON_KEY] = true
	_entrance = doc
	_save(doc)


func _on_boss_defeated() -> void:
	if state != BOSS:
		return
	boss_active = false
	in_arena = false
	_victory_left = VICTORY_SECONDS
	_victory_hold = 0.0
	victory_veil = 0.0
	if victory_plan.is_valid():
		var plan: Dictionary = victory_plan.call()
		_victory_hold = maxf(0.0, float(plan.get("hold", 0.0)))
		_victory_left += _victory_hold
		victory_veil = maxf(0.0, float(plan.get("veil", 0.0)))
	var boss := String(Worlds.row(ctx.stages.world_of(ctx.run.stage)).get("boss", ""))
	if Secrets.note_rout(ctx.profile, boss, ctx.run.run_time):
		_save_profile("profile_door_save")
	_save_boss_won.call_deferred()
	_set_state(VICTORY)


func cut_victory(seconds: float) -> void:
	if state != VICTORY:
		return
	var back := clampf(seconds, 0.0, _victory_hold)
	_victory_hold -= back
	_victory_left = maxf(0.0, _victory_left - back)
	victory_veil = 0.0


func _end_run_won() -> void:
	if victory_lap and _ending_due() and _begin_ending():
		return
	_end_run(true)
	if won_final() and _ending_due():
		_roll_ending()


func _roll_ending() -> void:
	var screens = _screens()
	if screens != null and screens.has_method("start_ending_sequence"):
		screens.start_ending_sequence()


func _screens():
	return ctx.root.get("screens") if ctx.root != null else null


func _begin_ending() -> bool:
	var boss := _boss_module()
	if boss != null and boss.has_method("exit_arena"):
		boss.exit_arena()
	boss_active = false
	in_arena = false
	ctx.events.stage_content_cleared.emit("lap")
	lap = VictoryLap.new()
	ctx.root.add_child(lap)
	if not lap.build(ctx):
		warn_once("victory_lap", "flow: the crater did not place; the run ends without the victory lap")
		_drop_lap()
		return false
	lap_stats = {}
	_victory_left = INF
	_record_end(true)
	ctx.events.run_ended.emit(true)
	var screens = _screens()
	if screens != null and screens.has_method("start_ending_prelude"):
		screens.start_ending_prelude()
	else:
		start_lap()
	return true


func start_lap() -> void:
	if state != VICTORY or not is_instance_valid(lap):
		return
	var hud = ctx.root.get("hud") if ctx.root != null else null
	if hud != null and hud.has_method("clear_toasts"):
		hud.clear_toasts()
	lap.begin(ctx.player.state.velocity)
	_set_state(LAP)


func _close_lap() -> void:
	if is_instance_valid(lap):
		lap_stats = lap.stats()
	ctx.player.set_frozen(true)
	_set_state(SUMMARY)
	_roll_ending()


func _drop_lap() -> void:
	if is_instance_valid(lap):
		lap.get_parent().remove_child(lap)
		lap.queue_free()
	lap = null


func _end_run(won: bool) -> void:
	_untake()
	_record_end(won)
	_set_state(SUMMARY)
	ctx.events.run_ended.emit(won)


func _record_end(won: bool) -> void:
	ctx.run.over = true
	run_won = won
	if won and RunTier.note_win(ctx.profile, ctx.run.run_tier):
		_save_profile("profile_ladder_save")
	ctx.player.set_frozen(true)
	_entrance = {}
	ctx.run.end_ride()
	_persist_companion()
	if store != null and store.refusal == "":
		if store.clear():
			_clear_save_spend()
		else:
			push_warning("flow: run save not cleared: %s" % store.last_error)
			_flush_save_spend()
			store_error = "clear_failed"
	else:
		_clear_save_spend()


func _on_reward_chosen(part_id: String) -> void:
	var granted := part_id if ctx.build == null or not ctx.build.scrapless() else ""
	if _seam_take and ctx.root != null and ctx.root.has_method("stamp_launch_take"):
		ctx.root.stamp_launch_take(granted)
	else:
		_taken_part = granted
	if state == GATES:
		_set_state(LAUNCH)


func _on_launched(velocity: Vector3) -> void:
	if state == GATES or state == LAUNCH:
		_set_state(LAUNCH)
		_launched = true
		_flight = 0.0
		_prewarm_next_stage_events()
		_save_cleared(velocity)
		_seam_take = _play_seam_take()


func _save_cleared(velocity: Vector3) -> void:
	if store == null or ctx.run.over:
		return
	_entrance = ctx.run.to_cleared_doc(_tree(), velocity)
	_save(_entrance)


func _play_seam_take() -> bool:
	var root = ctx.root
	var taken := _taken_part
	_taken_part = ""
	if root == null or not root.has_method("play_launch_take") or ctx.stages.is_run_last(ctx.run.stage):
		return false
	return root.play_launch_take(_cut_under_cover, _flight_over, _next_drawn, LAUNCH_FLIGHT, taken)


func _untake() -> void:
	if _seam_take and ctx.root != null and ctx.root.has_method("stamp_launch_take"):
		ctx.root.stamp_launch_take("")


func _flight_over() -> bool:
	return _flight >= LAUNCH_FLIGHT or not (state == LAUNCH and _launched)


func _cut_under_cover() -> void:
	_seam_take = false
	if state == LAUNCH and _launched:
		_finish_stage()


func _next_drawn() -> bool:
	return not in_play() or ctx.terrain.is_ready(ctx.run.stage)


func _on_enemy_killed(kind: String, at: Vector3, _scrap_value: int) -> void:
	if kind != "warden" or not sealed or not (state == STAGE or state == BEACON):
		return
	if not _is_this_warden(at):
		return
	if ctx.build == null or not ctx.build.scrapless():
		var drawer: Callable = _draw_panel if _draw_panel.is_valid() else (ctx.build.Panels.draw if ctx.build != null else Callable())
		var bonus_panel := ShiftVariants.claim_overtime_panel(ctx.run, drawer)
		if bonus_panel != "":
			ctx.run.add_panel(bonus_panel, _warden_at)
	_unseal()


func _is_this_warden(at: Vector3) -> bool:
	if is_instance_valid(warden) and ctx.spawner.has_method("integrity_of"):
		return ctx.spawner.integrity_of(warden) <= 0.0
	return at.distance_to(_warden_at) <= WARDEN_MATCH


func _warden_vanished() -> void:
	warn_once("warden_vanished", "flow: the Warden left without a recorded kill; unsealing stage %d" % ctx.run.stage)
	ctx.run.note_anomaly("warden_vanished")
	_unseal()


func _unseal() -> void:
	sealed = false
	warden = null
	beacon.open()
	ctx.events.beacon_unsealed.emit(ctx.run.stage)
	_set_state(GATES)
	ctx.events.beacon_charge_changed.emit(1.0)


func force_unseal() -> bool:
	if not in_stage():
		return false
	_unseal()
	return true


func _on_enemy_struck(enemy: Node3D, _kind: String, _force: float) -> void:
	if sealed and enemy == warden:
		_engage()


func _read_sighting(ball: Vector3) -> void:
	if _sighted or _engaged:
		return
	var flat := Vector2(ball.x - _warden_at.x, ball.z - _warden_at.z)
	if flat.length() <= beacon.radius * SIGHT_SHARE:
		_sighted = true
		ctx.events.warden_sighted.emit(ctx.run.stage)


func _engage() -> void:
	if _engaged:
		return
	_engaged = true
	_arrival = _met("the Warden", warden_plating()) if is_instance_valid(warden) else {}
	_sighted = true
	if ctx.run.run_tier_open():
		ctx.run.close_run_tier()
		show_start_card()
	ctx.events.warden_engaged.emit(ctx.run.stage)


func _landed_attack() -> String:
	var last = ctx.spawner.get("last_player_hit") if ctx.spawner != null else null
	if not (last is Dictionary) or int(last.get("frame", -1)) != Engine.get_physics_frames() or String(last.get("source", "")) != _last_hit_source:
		return ""
	return String(last.get("attack", ""))


func _on_player_died() -> void:
	if not in_play() or state == LAP:
		return
	death_cause = DeathCause.line(_last_hit_source, _landed_attack(), DeathCause.phase_note(_boss_module()) if state == BOSS else "")
	death_tip = DeathTips.line(_last_hit_source, _landed_attack(), _fight_gap())
	ctx.player.set_frozen(true)
	ctx.run.end_ride()
	if store != null:
		_end_run(false)
		return
	_set_state(DEAD)


func _rescue_if_fallen(ball: Vector3) -> void:
	if not ball.is_finite():
		_rescue_lost_ball()
		return
	var v: Vector3 = ctx.player.state.velocity
	var map = ctx.terrain.map()
	if map.has_method("net_deck_height"):
		var deck: float = map.net_deck_height()
		if ball.y < deck - NET_DECK_SLACK:
			var radius: float = preload("res://src/movement/tuning.gd").RADIUS
			ctx.player.reset_to(Vector3(ball.x, deck + radius, ball.z), Vector3(v.x, 0.0, v.z) * NET_DAMP)
			return
	if ctx.terrain.contains(ball) and ball.y > ctx.terrain.floor_height(ball.x, ball.z) - RESCUE_DEPTH:
		return
	ctx.player.reset_to(ctx.terrain.rescue_point(ball), Vector3(v.x, 0.0, v.z))


func _rescue_lost_ball() -> void:
	var at = ctx.run.snapshot_value("entry_position") if ctx.run != null else null
	if not (at is Vector3) or not (at as Vector3).is_finite():
		at = ctx.terrain.spawn_point(ctx.run.stage) if ctx.terrain != null and ctx.run != null else Vector3.ZERO
	warn_once("ball_not_finite", "flow: the ball's position is not finite; returned to the stage entry")
	ctx.player.reset_to(at, Vector3.ZERO)


func objective_text() -> String:
	var ball: Vector3 = ctx.player.ball_position()
	var to_beacon: float = Vector2(ball.x - beacon.global_position.x, ball.z - beacon.global_position.z).length()
	var percent := int(beacon.fraction() * 100.0)
	var fight := {
		"distance": int(to_beacon),
		"percent": percent,
		"punch": int(punch_now()),
		"plating": int(warden_plating()),
		"hint": stage_def()["warden_hint"],
	}
	match state:
		STAGE, BEACON:
			if sealed:
				var held: String = gate.objective() if gate != null else ""
				if held != "":
					return held
				return EventKinds.objective("stage_entered" if state == STAGE else "beacon_charge_changed", fight)
			var text := EventKinds.objective("beacon_unsealed", fight)
			if not beacon.in_ring(ball):
				text += "  The ring is %d m away." % int(maxf(0.0, to_beacon - beacon.radius))
			return text
		GATES:
			return EventKinds.objective("reward_offered")
		LAUNCH:
			return EventKinds.objective("launched" if _launched else "reward_chosen")
		BOSS:
			return _boss_objective()
	return ""


func _set_state(next: int) -> void:
	if start_card != null and (next not in [STAGE, BEACON] or ctx.run.stage != 1):
		start_card.hide_card()
	if state == next:
		return
	if next != LAP:
		_drop_lap()
	state = next
	ctx.events.flow_changed.emit(NAMES[next])
