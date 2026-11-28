extends Node3D

const GameEvents := preload("res://src/core/game_events.gd")
const FxLibrary := preload("res://src/presentation/fx_library.gd")
const RunState := preload("res://src/core/run_state.gd")
const Context := preload("res://src/core/context.gd")
const ScreenBusy := preload("res://src/ui/screen_busy.gd")
const Flow := preload("res://src/core/flow.gd")
const SittingNotes := preload("res://src/core/sitting_notes.gd")
const FrameLog := preload("res://src/core/frame_log.gd")
const Beacon := preload("res://src/core/beacon.gd")
const Secrets := preload("res://src/core/secrets.gd")
const Codex := preload("res://src/core/codex.gd")
const RunLog := preload("res://src/core/run_log.gd")
const RunMoments := preload("res://src/core/run_moments.gd")
const Profile := preload("res://src/core/profile.gd")
const SafeStore := preload("res://src/core/safe_store.gd")
const CliFlags := preload("res://src/core/cli_flags.gd")
const AppShell := preload("res://src/core/app_shell.gd")
const Progress := preload("res://src/core/progress.gd")
const ShiftBoard := preload("res://src/core/shift_board.gd")
const PilotStory := preload("res://src/core/pilot_story.gd")
const MetaOptions := preload("res://src/core/meta_options.gd")
const Parts := preload("res://src/build/parts.gd")
const Relics := preload("res://src/build/relics.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const PlayerBall := preload("res://src/movement/player_ball.gd")
const ChaseCamera := preload("res://src/movement/chase_camera.gd")
const Intent := preload("res://src/movement/intent.gd")
const Harpoon := preload("res://src/movement/harpoon.gd")
const Grip := preload("res://src/movement/grip.gd")
const Augments := preload("res://src/movement/augments.gd")
const Hud := preload("res://src/ui/hud.gd")
const Screens := preload("res://src/ui/screens.gd")
const UiProfile := preload("res://src/ui/ui_profile.gd")
const FieldNotes := preload("res://src/ui/field_notes.gd")
const TuningPanel := preload("res://src/ui/tuning_panel.gd")
const World := preload("res://src/world/world.gd")
const Combat := preload("res://src/combat/combat.gd")
const Build := preload("res://src/build/build.gd")
const Presentation := preload("res://src/presentation/presentation.gd")
const Bindings := preload("res://src/core/bindings.gd")
const Glyphs := preload("res://src/core/glyphs.gd")
const GraphicsPreset := preload("res://src/presentation/graphics_preset.gd")
const SettingsStore := preload("res://src/ui/settings_store.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")
const WorldFx := preload("res://src/presentation/world_fx/world_fx.gd")
const RunStore := preload("res://src/core/run_store.gd")
const MetRecord := preload("res://src/core/met_record.gd")
const TuneRows := preload("res://src/core/tune_rows.gd")
const RadioDeck := preload("res://src/presentation/radio_deck.gd")
const LaunchTake := preload("res://src/presentation/launch_take.gd")
const Opening := preload("res://src/presentation/opening.gd")
const MENU_PATHS := [
	"res://src/world/camp_hub.gd",
	"res://src/ui/camp_enemy_picker.gd",
	"res://src/ui/workshop.gd",
	"res://src/ui/pause_menu.gd",
]
const MENU_STEPS := 4
const MENU_MODULES_FRAMES_APART := 2


const RESTART_HOLD := 0.5
const GATE_OUT := 9.0
const GATE_UP := 15.0
const HIT_STOP_MAX := 0.06
const HIT_STOP_SCALE := 0.05
const SLOW_MOTION_FLOOR := 0.1
const SEED := 20260926
const SimClock := preload("res://src/core/sim_clock.gd")
const Comfort := preload("res://src/core/comfort.gd")
const BOSS_PATH := "res://src/boss/boss.gd"
const StageDefs := preload("res://src/core/stage_defs.gd")
const SliceDefs := preload("res://src/core/slice_defs.gd")
const AlphaDefs := preload("res://src/core/alpha_defs.gd")
const ParkDefs := preload("res://src/core/park_defs.gd")
const TABLES := {"default": StageDefs, "slice": SliceDefs, "alpha": AlphaDefs, "park": ParkDefs}
const LAUNCH_TABLE := "park"

var test_mode := false:
	set(value):
		test_mode = value
		bot_driven = value
var bot_driven := false:
	set(value):
		bot_driven = value
		if run != null:
			run.bot_driven = value
var table := ""
var ground_behind_menu := false
var dev := false:
	set(value):
		dev = value
		if ctx != null:
			ctx.dev = value

var events
var run
var tuning
var player
var camera
var flow
var beacon
var ctx
var world
var combat
var build
var boss
var presentation
var _session_seed := randi() # lint: session seed
var hud
var screens
var radio_deck
var launch_take
var opening
var _first_control_said := false
var camp_hub:
	get:
		menu_modules()
		return camp_hub
var _menu_step := 0
var _menu_wait := -1
var _menu_requested := -1
var notes
var panel
var keyboard
var _dev_held := false
var _dev_frozen := false
var codex
var run_log
var run_moments
var progress
var _progress_ready := false
var storage_dir := "user://"
var run_store_path := ""
var _settings_store

var _pause_toggled := false
var _notes_held := false
var _restart_held := 0.0
var _restart_latched := false
var summary_latched := false
var _dead_c_latched := false
var _hit_stopped := false
var _stop_ticks_left := -1
var _scale_before_stop := 1.0
var _slow := 1.0
var last_device := "kbm"
var frame_smoothing := true
var wide_picture := true
const SELF_PLAY := "res://tools/self_play.gd"
const HELD_UNNAMED := "held"
const EXPERIMENTAL_BRIDGE := "res://src/experimental/live_run_bridge.gd"
const EXPERIMENTAL_FLAG := "--experimental-depth"
const EXPERIMENTAL_ENV := "SCRAPKEEP_EXPERIMENTAL"
var experimental_bridge: Node = null
var experimental_override := false


func _ready() -> void:
	_boot("ready")
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if not test_mode:
		AppShell.apply()
	dev = dev or _launch_flag("--dev")
	ground_behind_menu = ground_behind_menu or not test_mode
	_register_actions()
	events = GameEvents.new()
	events.name = "GameEvents"
	add_child(events)
	events.flow_changed.connect(func(state: String):
		if state == "summary":
			arm_summary_latch()
		elif state == "dead":
			_dead_c_latched = Input.is_physical_key_pressed(KEY_C)
		else:
			_dead_c_latched = false)
	run = RunState.new(events, _session_seed)
	run.bot_driven = bot_driven
	tuning = Tuning.new()
	tuning.apply_cmdline("launch")

	player = PlayerBall.new()
	player.name = "Player"
	add_child(player)
	player.setup(tuning, events, Vector3(0.0, 60.0, 0.0))
	player.shockwave.connect(_on_shockwave)

	camera = ChaseCamera.new()
	camera.name = "ChaseCamera"
	add_child(camera)
	camera.setup(player, tuning)

	beacon = Beacon.new()
	beacon.name = "Beacon"
	add_child(beacon)
	beacon.setup()

	ctx = Context.new(hit_stop)
	ctx.dev = dev
	ctx.stages = _chosen_table()
	ctx.events = events
	ctx.run = run
	ctx.tuning = tuning
	ctx.player = player
	ctx.camera = camera
	ctx.root = self
	ctx.rng.seed = SEED
	flow = Flow.new()
	flow.name = "Flow"
	add_child(flow)
	ctx.flow = flow
	opening = Opening.new()
	add_child(opening)
	opening.setup(self)
	if test_mode:
		storage_dir = "user://test-%d" % OS.get_process_id()
		DirAccess.make_dir_recursive_absolute(storage_dir)
	elif _launch_flag("--self-play"):
		storage_dir = "user://self-play-%s" % _self_play_save()
		DirAccess.make_dir_recursive_absolute(storage_dir)
	elif tuning != null and tuning.sitting_earned():
		storage_dir = "user://sitting-earned"
		DirAccess.make_dir_recursive_absolute(storage_dir)
		var settings := storage_dir.path_join(SettingsStore.FILE)
		if not FileAccess.file_exists(settings) and FileAccess.file_exists("user://".path_join(SettingsStore.FILE)):
			DirAccess.copy_absolute("user://".path_join(SettingsStore.FILE), settings)
	apply_saved_bindings()
	camera.apply_look_settings(settings_store())
	codex = Codex.new()
	add_child(codex)
	codex.setup(events, run, flow, storage_dir, func(id: String) -> bool: var d: Resource = Parts.def(id); return d != null and d.rarity == "relic")
	codex.declare_story_entries(PilotStory.codex_declarations())
	codex.set_story_hooks(PilotStory.entry_visible, PilotStory.synthesis_margin)
	ctx.codex = codex
	run_log = RunLog.new()
	add_child(run_log)
	run_log.setup(events, run, player, codex, storage_dir)
	ctx.run_log = run_log
	run_moments = RunMoments.new()
	add_child(run_moments)
	run_moments.setup(events, run, player, flow, ctx.stages, storage_dir, func(id: String) -> Dictionary: var d: Resource = Parts.def(id); return {"tier": d.tier if d != null else 1, "name": Parts.display_name(id)}, preload("res://src/combat/roster.gd").warden_name)
	ctx.profile = Profile.new(storage_dir.path_join("profile.json"))
	if not ctx.profile.load_profile():
		push_warning("profile: %s" % ctx.profile.last_error)
	sitting_save_guard()
	progress = Progress.new()
	progress.name = "Progress"
	add_child(progress)
	progress.set_story_chapter_hook(func(trigger_id: String, profile): return PilotStory.chapters_matching_trigger(trigger_id, profile, codex))
	ctx.progress = progress
	events.run_started.connect(func(_class_id: String): open_board_items())

	_boot("modules")
	world = _module(World)
	_boot("world")
	for row in ctx.stages.DEFS:
		if row["map"] == "spillway":
			preload("res://src/presentation/spillway_scenery.gd").build(ctx.terrain.geometry_root(row["stage"]))
	preload("res://src/presentation/spillway_scenery.gd").hook(ctx)
	preload("res://src/presentation/dig_scenery.gd").hook(ctx)
	preload("res://src/presentation/highdraft_scenery.gd").hook(ctx)
	preload("res://src/presentation/world_look.gd").hook(ctx)
	WorldFx.hook(ctx)
	preload("res://src/presentation/bake_warm.gd").hook(ctx)
	_boot("world_hooks")
	combat = _module(Combat)
	_boot("combat")
	build = _module(Build)
	events.run_started.connect(_apply_player_run_options)
	if ResourceLoader.exists(BOSS_PATH):
		boss = _module(load(BOSS_PATH))
	_boot("build_boss")
	ctx.screen_busy = ScreenBusy.new()
	add_child(ctx.screen_busy)
	ctx.screen_busy.setup(ctx)
	ctx.ui_profile = UiProfile.new(storage_dir)
	presentation = _module(Presentation)
	_boot("presentation")
	apply_saved_display()
	assert(ctx.terrain != null, "world.setup(ctx) must set ctx.terrain")
	assert(ctx.spawner != null, "combat.setup(ctx) must set ctx.spawner")
	player.struck.connect(func(enemy: Node3D, kind: String, force: float): ctx.spawner.strike(enemy, kind, force))
	player.crush_check = func(enemy: Node3D, kind: String, force: float) -> bool:
		if ctx.spawner == null or not ctx.spawner.has_method("would_crush"):
			flow.warn_once("would_crush", "game: spawner has no would_crush(); crush pass-through is off")
			return false
		return ctx.spawner.would_crush(enemy, kind, force)

	flow.setup(ctx, beacon, Build.Panels.draw)
	if not test_mode or run_store_path != "":
		flow.store = RunStore.new(run_store_path if run_store_path != "" else storage_dir.path_join("run.json"))
	events.flow_changed.connect(_on_flow_changed)

	_boot("flow")
	hud = Hud.new()
	hud.name = "Hud"
	add_child(hud)
	hud.setup(self)
	screens = Screens.new()
	screens.name = "Screens"
	add_child(screens)
	screens.setup(self)
	_listen_for_tunes()
	radio_deck = RadioDeck.new()
	radio_deck.name = "RadioDeck"
	add_child(radio_deck)
	radio_deck.setup(self)
	launch_take = LaunchTake.new()
	add_child(launch_take)
	launch_take.finished.connect(_on_take_finished)
	notes = FieldNotes.new()
	notes.name = "FieldNotes"
	add_child(notes)
	notes.setup(self)
	panel = TuningPanel.new()
	panel.name = "TuningPanel"
	add_child(panel)
	panel.setup(tuning)
	var drawer: CanvasLayer = load("res://src/ui/panel_drawer.gd").new()
	add_child(drawer)
	drawer.setup(self, panel)
	var auto_pause: Node = load("res://src/ui/auto_pause.gd").new()
	add_child(auto_pause)
	auto_pause.setup(self)
	if dev and not test_mode:
		load("res://src/dev/dev_console.gd").hook(self)
	if test_mode:
		menu_modules()
	else:
		events.flow_changed.connect(func(state: String):
			if state != "title":
				menu_modules())
		events.run_started.connect(func(_class_id: String): menu_modules())

	if not test_mode:
		keyboard = Intent.Keyboard.new()
		keyboard.tuning = tuning
		keyboard.enabled = false
		player.source = keyboard
	if ctx.terrain.is_ready(1):
		_park_on_title_ground(1)
	else:
		camera.snap(ctx.terrain.entry_heading(1))
		ctx.terrain.stage_built.connect(_park_on_title_ground)
	_boot("ui")
	_attach_experimental()
	flow.show_title()
	_boot("title")
	if not test_mode:
		_menu_wait = MENU_MODULES_FRAMES_APART
	if _launch_flag("--self-play") and not test_mode:
		_start_self_play()
	if SittingNotes.wanted() and not test_mode:
		var sitting_notes := SittingNotes.new()
		sitting_notes.game = self
		add_child(sitting_notes)
	if FrameLog.wanted() and not test_mode:
		add_child(FrameLog.new())
	if _launch_flag("--boot-profile"):
		for frame in 5:
			await get_tree().process_frame
			if not is_inside_tree():
				return
			_boot("frame %d" % (frame + 1))


func menu_modules() -> void:
	while _menu_step < MENU_STEPS:
		_menu_step_once()


func _menu_step_once() -> void:
	if _menu_step >= MENU_STEPS:
		return
	var started := Time.get_ticks_msec()
	var step := _menu_step
	_menu_step += 1
	var script: Script = _menu_script(step)
	var loaded := Time.get_ticks_msec()
	match step:
		0:
			var hub = script.new()
			camp_hub = hub
			add_child(hub)
			hub.setup(self)
			hub.camp_store = ctx.profile
		1:
			MetRecord.watch(self)
		2:
			add_child(script.new())
		3:
			add_child(script.new())
	_boot("menu_modules step %d: script %d ms, main-thread build %d ms" % [step, loaded - started, Time.get_ticks_msec() - loaded])


func _menu_script(step: int) -> Script:
	var path: String = MENU_PATHS[step]
	if _menu_requested == step:
		_menu_requested = -1
		var threaded: Script = ResourceLoader.load_threaded_get(path)
		if threaded != null:
			return threaded
	return load(path)


func workshop() -> Node:
	menu_modules()
	return get_node("Workshop")


# Poll one ResourceLoader.load_threaded_request at a time; parallel preload requests deadlock in Godot.
func _step_menu_modules_later() -> void:
	if _menu_wait < 0 or _menu_step >= MENU_STEPS:
		return
	if get_tree().root.get_node_or_null("Boot") != null:
		return
	if _menu_requested < 0:
		_menu_wait -= 1
		if _menu_wait > 0:
			return
		_menu_requested = _menu_step
		if ResourceLoader.load_threaded_request(MENU_PATHS[_menu_step], "", false) != OK:
			_menu_requested = -1
			_menu_step_once()
			_menu_wait = MENU_MODULES_FRAMES_APART
		return
	match ResourceLoader.load_threaded_get_status(MENU_PATHS[_menu_requested]):
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return
		_:
			_menu_step_once()
			_menu_wait = MENU_MODULES_FRAMES_APART


func _park_on_title_ground(stage: int) -> void:
	if stage != 1:
		return
	if ctx.terrain.stage_built.is_connected(_park_on_title_ground):
		ctx.terrain.stage_built.disconnect(_park_on_title_ground)
	if flow.in_play():
		return
	if _menu_step >= MENU_STEPS and camp_hub != null and camp_hub.get("walking") == true:
		return
	player.reset_to(ctx.terrain.spawn_point(1))
	camera.snap(ctx.terrain.entry_heading(1))


func _attach_experimental() -> void:
	if not experimental_override and (test_mode or not _experimental_asked() or not load(EXPERIMENTAL_BRIDGE).is_enabled()):
		return
	experimental_bridge = load(EXPERIMENTAL_BRIDGE).new()
	experimental_bridge.name = "ExperimentalLiveRunBridge"
	add_child(experimental_bridge)
	experimental_bridge.bridge_fact_emitted.connect(_on_experimental_fact)
	experimental_bridge.attach_live(ctx)


static func _experimental_asked() -> bool:
	if OS.get_environment(EXPERIMENTAL_ENV) != "":
		return true
	return CliFlags.has_prefix(EXPERIMENTAL_FLAG, true)


func _on_experimental_fact(fact: Dictionary) -> void:
	hud.toast(experimental_bridge.callout_for(fact))


func _start_self_play() -> void:
	var script_path := CliFlags.value_of("--self-play-script=", SELF_PLAY)
	if not ResourceLoader.exists(script_path):
		push_error("game: --self-play needs a pack with tools/ (npm run sketch:export -- --self-play)")
		get_tree().quit(2)
		return
	var bot: Node = load(script_path).new()
	bot.set("game", self)
	add_child(bot)


func _listen_for_tunes() -> void:
	var sound = audio()
	if sound == null or not sound.has_signal("tune_heard"):
		return
	for id in ctx.profile.tune_ids():
		sound.knows_tune(id)
	sound.tune_heard.connect(_on_tune_heard)


func _on_tune_heard(id: String) -> void:
	if not ctx.profile.hear_tune(id):
		return
	if not ctx.profile.save_if_allowed():
		push_warning("game: tune %s heard but not saved: %s" % [id, ctx.profile.last_error])
	hud.tune_found(String(TuneRows.row(id).get("name", id)))


func _chosen_table():
	var id := table
	if id.is_empty():
		id = CliFlags.value_of("--table=", "", true)
	if id.is_empty():
		return StageDefs if test_mode else TABLES[LAUNCH_TABLE]
	if not TABLES.has(id):
		push_warning("game: unknown stage table '%s'; using the default" % id)
		return StageDefs
	return TABLES[id]


func audio():
	return presentation.get("audio") if presentation != null else null


func _module(script: GDScript) -> Node:
	var module: Node = script.new()
	add_child(module)
	module.setup(ctx)
	return module


func continue_refusal() -> String:
	return flow.continue_refusal()


func sitting_save_guard() -> void:
	if tuning != null and tuning.sitting() and ctx.profile != null:
		ctx.profile.disable_saving("sitting profile: this session does not save")
		Secrets.open_for_sitting(ctx.profile)


func open_board_items() -> void:
	var opened := {}
	if not bot_driven and ctx.profile != null:
		for id in ShiftBoard.opened_items(ctx.profile):
			opened[id] = true
	Parts.set_opened_items(opened)


func _apply_player_run_options(class_id: String) -> void:
	if bot_driven or ctx == null or ctx.profile == null or run == null:
		return
	var sitting: bool = tuning != null and tuning.sitting()
	var overrides: Array = MetaOptions.active_overrides(ctx.profile, bot_driven, sitting)
	if not overrides.is_empty():
		run.extra["overrides"] = overrides
		if run.override_on("hull_half"):
			run.set_max_hp(run.base_max_hp())
			run.hp = run.max_hp
	var equipped: Dictionary = MetaOptions.equipped_alt_loadouts(ctx.profile, class_id, bot_driven, sitting)
	if not equipped.is_empty():
		for slot in equipped:
			var alt_id := String(equipped[slot])
			var relic_id := String(MetaOptions.alt_loadout(alt_id).get("relic", ""))
			if relic_id == "" and alt_id in Relics.alt_loadouts(class_id):
				relic_id = alt_id
			var part_id := Relics.part_of(relic_id)
			if part_id != "" and not part_id in run.parts:
				run.add_part(part_id, "alt_loadout")
		if build != null and build.has_method("sync_relics"):
			build.sync_relics()


func pilot_unlocked(def) -> bool:
	return def.starter or (tuning != null and tuning.sitting()) or ctx.profile.has_pilot(def.id)


func _exit_tree() -> void:
	slow_motion(1.0)
	_end_hit_stop()
	if not test_mode:
		return
	var dir := DirAccess.open(storage_dir)
	if dir == null:
		return
	for file in dir.get_files():
		dir.remove(file)
	var book := storage_dir.path_join(RunMoments.DIR)
	if DirAccess.dir_exists_absolute(book):
		for file in DirAccess.get_files_at(book):
			DirAccess.remove_absolute(book.path_join(file))
		DirAccess.remove_absolute(book)
	DirAccess.remove_absolute(storage_dir)


func _physics_process(delta: float) -> void:
	if not _progress_ready:
		_progress_ready = true
		progress.setup(events, run, ctx.profile, Callable(), codex)
	if _stop_ticks_left > 0:
		_stop_ticks_left -= 1
		if _stop_ticks_left == 0:
			_end_hit_stop()
	player.drive_basis = camera.yaw_basis()
	flow.physics_step(delta)
	if flow.in_play():
		aim_along(camera.aim_origin(), camera.aim_forward())
	if experimental_bridge != null and not get_tree().paused:
		experimental_bridge.live_step(delta)


func _process(delta: float) -> void:
	step_summary_latch()
	if _dead_c_latched and not Input.is_physical_key_pressed(KEY_C):
		_dead_c_latched = false
	if test_mode:
		return
	_step_menu_modules_later()
	step_restart_hold(delta, Input.is_action_pressed("cl_retry"))
	step_stick_look(delta)


func step_stick_look(delta: float) -> void:
	var stick := Input.get_vector("cl_look_left", "cl_look_right", "cl_look_up", "cl_look_down")
	if stick != Vector2.ZERO:
		camera.look_stick(stick, delta, stick_on_target())


func stick_on_target() -> bool:
	return player != null and player.kit.aim.get("state", Augments.AIM_NONE) != Augments.AIM_NONE


func apply_look() -> void:
	camera.apply_look_settings(settings_store())


func step_restart_hold(delta: float, r_down: bool) -> void:
	if not r_down:
		_restart_latched = false
	if r_down and not flow.in_play():
		_restart_latched = true
	if not flow.in_play() or not r_down or _restart_latched:
		_restart_held = 0.0
		return
	if flow.store != null and flow.state == flow.LAP:
		_restart_held = 0.0
		return
	_restart_held += delta
	if _restart_held >= RESTART_HOLD:
		_restart_held = 0.0
		_restart_latched = true
		if flow.store != null:
			flow.new_run()
		else:
			flow.retry_stage()


func restart_hold_fraction() -> float:
	return clampf(_restart_held / RESTART_HOLD, 0.0, 1.0)


func aim_along(from: Vector3, forward: Vector3) -> Dictionary:
	player.kit.aim = Harpoon.target(player.kit, tuning, get_world_3d().direct_space_state,
		get_tree().get_nodes_in_group("enemy"), from, forward, player.ball_position())
	Grip.mark(player.kit.aim, player.heft(), player.enemy_heft(player.kit.aim.get("body")), tuning.pole_flail())
	return player.kit.aim


# Godot reads Engine.time_scale once per frame, so tick-based hit-stop precision requires one tick per frame.
func hit_stop(seconds: float) -> void:
	if _hit_stopped or seconds <= 0.0 or not flow.in_play():
		return
	_hit_stopped = true
	_scale_before_stop = Engine.time_scale
	Engine.time_scale = HIT_STOP_SCALE
	var held := minf(seconds, HIT_STOP_MAX)
	if test_mode and not SimClock.ticks:
		_stop_ticks_left = maxi(1, floori(held * Engine.physics_ticks_per_second))
		return
	var timer := get_tree().create_timer(held, true, false, true)
	timer.timeout.connect(_end_hit_stop)


func _end_hit_stop() -> void:
	if not _hit_stopped:
		return
	Engine.time_scale = _scale_before_stop
	_stop_ticks_left = -1
	_hit_stopped = false


func slow_motion(scale: float) -> void:
	scale = clampf(scale, SLOW_MOTION_FLOOR, 1.0)
	if is_equal_approx(scale, _slow):
		return
	var base := (_scale_before_stop if _hit_stopped else Engine.time_scale) / _slow
	_slow = scale
	if _hit_stopped:
		_scale_before_stop = base * scale
	else:
		Engine.time_scale = base * scale
	if audio() != null:
		audio().slowed(scale < 1.0)


func toggle_interpolation() -> bool:
	_smooth(not interpolating())
	return interpolating()


func interpolating() -> bool:
	return get_tree().physics_interpolation


func dump_tuning() -> String:
	var values := {}
	var mods := {}
	for spec in Tuning.SPECS:
		values[spec["key"]] = tuning.base(spec["key"])
		mods[spec["key"]] = tuning.mod(spec["key"])
	var record := {
		"sketch": "core-loop",
		"saved_unix": Time.get_unix_time_from_system(),
		"class": run.class_id(),
		"stage": run.stage,
		"parts": run.parts,
		"physics_interpolation": interpolating(),
		"tuning": values,
		"part_mods": mods,
		"boost_cooldown_scale": tuning.boost_cooldown_scale,
	}
	var path := "user://tuning-%d.json" % int(Time.get_unix_time_from_system())
	var err := SafeStore.write_atomic(path, JSON.stringify(record, "  "))
	if err != OK:
		push_warning("tuning dump failed: %s" % error_string(err))
		return ""
	var shown := ProjectSettings.globalize_path(path)
	print("tuning saved to ", shown)
	return shown


func toggle_pause() -> void:
	_pause_toggled = not _pause_toggled
	_apply_pause()


func hold_notes(held: bool) -> void:
	_notes_held = held
	_apply_pause()


func pause_toggled() -> bool:
	return _pause_toggled


func cycle_breath() -> String:
	var options: Array = tuning.options_of(Tuning.BREATH_KEY)
	var style: String = options[(options.find(tuning.option(Tuning.BREATH_KEY)) + 1) % options.size()]
	tuning.set_option(Tuning.BREATH_KEY, style)
	var sound = audio()
	if sound != null and sound.has_method("set_breath"):
		sound.set_breath(style)
	return style


func notes_held() -> bool:
	return _notes_held


func _apply_pause() -> void:
	get_tree().paused = _pause_toggled or _notes_held or _dev_frozen


func pause_wanted() -> bool:
	var shop := get_node_or_null("Workshop")
	return _pause_toggled or _notes_held or (shop != null and shop.pausing())


func freeze_for_dev(on: bool) -> void:
	_dev_frozen = on
	get_tree().paused = on or pause_wanted()


func hold_for_dev(on: bool) -> void:
	_dev_held = on
	if keyboard != null:
		keyboard.held = on
	if on:
		capture_mouse(false)
	else:
		recapture_mouse()


func _on_flow_changed(_state: String) -> void:
	var playing: bool = flow.in_play()
	if playing and not launch_take.busy():
		_say_first_control()
	if keyboard != null:
		keyboard.enabled = playing
		keyboard.walk = false
	capture_mouse(playing)
	if playing:
		var holder := get_viewport().gui_get_focus_owner()
		if holder != null:
			holder.release_focus()


func walk_input(live: bool) -> void:
	if keyboard != null:
		keyboard.enabled = live
		keyboard.walk = live
	capture_mouse(live)


func _take_live() -> bool:
	return launch_take.force_live or (not test_mode and not bot_driven and not AppShell.headless())


func play_launch_take(on_cover: Callable, flight_over: Callable, ready_check: Callable, flight_s: float, taken_part := "") -> bool:
	if launch_take.busy() or not _take_live():
		return false
	launch_take.live = true
	return launch_take.play_over_flight(on_cover, flight_over, ready_check, flight_s, taken_part)


func stamp_launch_take(part_id: String) -> void:
	launch_take.stamp_taken(part_id)


func pick_pilot(index: int) -> void:
	launch_take.live = _take_live()
	launch_take.play(func():
		if flow.state_name() == "class_select":
			_begin_opening()
		flow.choose_class(index), func():
		screens.fade_for_launch()
		_launch_whoosh()
		var title_stage = presentation.get("title_stage") if presentation != null else null
		if title_stage != null:
			title_stage.launch_push(LaunchTake.WIND_S + LaunchTake.COVER_S), _dam_drawn)


func gate_pilot() -> Resource:
	var last: String = ctx.profile.last_pilot() if ctx.profile != null else ""
	var first: Resource = null
	for def in flow.classes:
		if not pilot_unlocked(def):
			continue
		if def.id == last:
			return def
		if first == null:
			first = def
	return first


func gate_label() -> String:
	var def := gate_pilot()
	return "Launch as %s" % def.display_name if def != null and def.display_name != "" else "Launch"


func launch_from_gate() -> void:
	var def := gate_pilot()
	if def == null or screens.prologue_due():
		flow.press_start()
		return
	launch_take.live = _take_live()
	launch_take.play(func():
		if flow.state_name() != "title":
			return
		screens.stop_walk_for_launch()
		_begin_opening()
		flow.launch_from_title(def), _fire_gate, _dam_drawn)


func _fire_gate() -> void:
	walk_input(false)
	camp_hub.set_prompts_visible(false)
	var out: Vector3 = camp_hub.zone_position("gate") - camp_hub.root.global_position
	out.y = 0.0
	out = out.normalized() if out.length() > 0.01 else Vector3.FORWARD
	player.set_frozen(false)
	player.set_velocity_now(out * GATE_OUT + Vector3.UP * GATE_UP)
	_launch_whoosh()


func _launch_whoosh() -> void:
	var sound = audio()
	if sound != null:
		sound.play("launched")


func _dam_drawn() -> bool:
	return not flow.in_play() or ctx.terrain.is_ready(run.stage)


func _say_first_control() -> void:
	if _first_control_said or bot_driven or not flow.in_play():
		return
	_first_control_said = true
	print("SCRAPKEEP_FIRST_CONTROL ms=%d" % Time.get_ticks_msec())


func _begin_opening() -> void:
	if launch_take.live:
		opening.begin()


func _on_take_finished() -> void:
	if flow.in_stage():
		flow.show_start_card()
	_say_first_control()


func arm_summary_latch() -> void:
	summary_latched = input_held()


func summary_shut() -> bool:
	return summary_latched or (screens != null and screens.ending_open())


func step_summary_latch() -> void:
	if summary_latched and not (screens != null and screens.ending_open()) and not input_held():
		summary_latched = false


func input_held() -> bool:
	return held_glyph() != ""


func held_glyph() -> String:
	var pads := Input.get_connected_joypads()
	var table := Bindings.actions()
	for action in table:
		var record: Dictionary = table[action]
		for key in record.get("keys", []):
			if Input.is_physical_key_pressed(key):
				return "key_" + OS.get_keycode_string(key).to_lower().replace(" ", "_")
		if record.has("button") and Input.is_mouse_button_pressed(record["button"]):
			return {MOUSE_BUTTON_LEFT: "key_lmb", MOUSE_BUTTON_RIGHT: "key_rmb"}.get(record["button"], HELD_UNNAMED)
		if record.has("pad"):
			for device in pads:
				if Input.is_joy_button_pressed(device, record["pad"]):
					return Glyphs.PAD_BUTTONS.get(record["pad"], HELD_UNNAMED)
		if record.has("axis") and record["axis"][0] in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]:
			for device in pads:
				if Input.get_joy_axis(device, record["axis"][0]) > 0.5:
					return Glyphs.PAD_TRIGGERS[record["axis"][0]]
	for ui_action in Bindings.UI_PAD:
		for device in pads:
			if Input.is_joy_button_pressed(device, Bindings.UI_PAD[ui_action]):
				return Glyphs.PAD_BUTTONS.get(Bindings.UI_PAD[ui_action], HELD_UNNAMED)
	return ""


func _register_actions() -> void:
	var table_actions := Bindings.actions()
	for action in table_actions:
		_fresh_action(action)
		var record: Dictionary = table_actions[action]
		for key in record.get("keys", []):
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
		if record.has("button"):
			var button := InputEventMouseButton.new()
			button.button_index = record["button"]
			InputMap.action_add_event(action, button)
		if record.get("motion", false):
			InputMap.action_add_event(action, InputEventMouseMotion.new())
		if record.has("pad"):
			var pad := InputEventJoypadButton.new()
			pad.button_index = record["pad"]
			InputMap.action_add_event(action, pad)
		if record.has("axis"):
			var motion := InputEventJoypadMotion.new()
			motion.axis = record["axis"][0]
			motion.axis_value = float(record["axis"][1])
			InputMap.action_add_event(action, motion)
	for ui_action in Bindings.UI_PAD:
		if not InputMap.has_action(ui_action):
			continue
		var held := false
		for old in InputMap.action_get_events(ui_action):
			if old is InputEventJoypadButton and old.button_index == Bindings.UI_PAD[ui_action]:
				held = true
		if not held:
			var ui_pad := InputEventJoypadButton.new()
			ui_pad.button_index = Bindings.UI_PAD[ui_action]
			InputMap.action_add_event(ui_action, ui_pad)


func apply_saved_bindings() -> void:
	var store = settings_store()
	for action in Bindings.actions():
		if store.binding(action).is_empty() or not InputMap.has_action(action):
			continue
		var decoded: Array = store.binding_events(action)
		if decoded.is_empty():
			continue
		apply_binding(action, decoded)


func apply_binding(action: String, events: Array) -> void:
	if events.is_empty() or not InputMap.has_action(action):
		return
	var has_pad := false
	var has_desk := false
	var has_axis := false
	for event in events:
		if event is InputEventJoypadButton:
			has_pad = true
		elif event is InputEventJoypadMotion:
			has_axis = true
		else:
			has_desk = true
	for old in InputMap.action_get_events(action):
		var desk: bool = old is InputEventKey or old is InputEventMouseButton
		if (has_desk and desk) or (has_pad and old is InputEventJoypadButton) or (has_axis and old is InputEventJoypadMotion):
			InputMap.action_erase_event(action, old)
	for event in events:
		InputMap.action_add_event(action, event)


func reset_bindings() -> void:
	var store = settings_store()
	for action in store.bindings.keys():
		store.clear_binding(action)
	_register_actions()
	camera.apply_look_settings(store)


func settings_store():
	if _settings_store == null:
		_settings_store = SettingsStore.new(storage_dir)
	return _settings_store


func apply_saved_display(args: Array = []) -> void:
	var launch: Array = args if not args.is_empty() else Array(CliFlags.args())
	var saved = settings_store()
	if not launch.any(func(arg): return String(arg).begins_with("--preset=") and GraphicsPreset.PRESETS.has(String(arg).trim_prefix("--preset="))):
		set_quality(saved.quality())
	if launches_fullscreen(saved.fullscreen(), Array(CliFlags.args(true))):
		set_fullscreen(true)
	set_reduced_motion(saved.reduced_motion())
	set_reduce_flashes(saved.reduce_flashes())
	set_frame_smoothing(saved.frame_smoothing())
	set_wide_picture(saved.wide_picture())


func set_quality(level: int) -> void:
	var preset := "low" if level == 1 else "high"
	if GraphicsPreset.current != preset:
		GraphicsPreset.apply(preset)


static func set_motion_statics(on: bool) -> void:
	Comfort.reduced_motion = on
	preload("res://src/presentation/spillway_scenery.gd").set_water_calm(on)


func set_reduced_motion(on: bool) -> void:
	set_motion_statics(on)
	if is_instance_valid(WorldFx.current):
		WorldFx.current.set_quality(WorldFx.current.low, on)
	if presentation != null and presentation.get("juice") != null:
		presentation.juice.set_reduced_motion(on)


func set_reduce_flashes(on: bool) -> void:
	FlashGuard.on = on
	if is_inside_tree():
		for p in get_tree().get_nodes_in_group(FxLibrary.HEAT_GROUP):
			FxLibrary.set_heat(p)


func set_frame_smoothing(on: bool) -> void:
	frame_smoothing = on
	var smooth := on and not test_mode and _windowed()
	for raw in CliFlags.values_of("--smoothing=", true):
		if raw == "0" or raw == "1":
			smooth = raw == "1"
	_smooth(smooth)


func set_wide_picture(on: bool) -> void:
	wide_picture = on
	if not is_inside_tree():
		return
	var window := get_tree().root
	if not window.size_changed.is_connected(_fit_picture):
		window.size_changed.connect(_fit_picture)
	_fit_picture()


func _fit_picture() -> void:
	var window := get_tree().root
	var fill := wide_fills(wide_picture, not test_mode and _windowed(), Array(CliFlags.args(true)), window.size)
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND if fill else Window.CONTENT_SCALE_ASPECT_KEEP


static func wide_fills(wish: bool, played_window: bool, args: Array, size: Vector2i) -> bool:
	var fill := wish and played_window
	for arg in args:
		if arg == "--wide=0" or arg == "--wide=1":
			fill = arg == "--wide=1"
	return fill and size.y > 0 and size.x * 9 > size.y * 16


func _smooth(on: bool) -> void:
	if not is_inside_tree() or get_tree().physics_interpolation == on:
		return
	get_tree().physics_interpolation = on
	Engine.physics_jitter_fix = 0.0 if on else float(ProjectSettings.get_setting("physics/common/physics_jitter_fix", 0.5))
	reset_physics_interpolation()


func set_fullscreen(on: bool) -> void:
	if not _windowed():
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)


# Godot consumes --windowed before user args reach GDScript, so --fullscreen=0 overrides the saved setting.
func launches_fullscreen(wanted: bool, args: Array) -> bool:
	if "--fullscreen=0" in args or "--fullscreen=1" in args:
		return args.rfind("--fullscreen=1") > args.rfind("--fullscreen=0")
	if test_mode or _launch_flag("--self-play"):
		return false
	return wanted


func pad_screen_key(event: InputEvent) -> int:
	if not (event is InputEventJoypadButton) or not event.pressed:
		return KEY_NONE
	var state: String = flow.state_name()
	if state == "title" and screens != null and screens.walk_live() and event.is_action("cl_interact"):
		return camp_hub.confirm_key()
	if event.button_index == JOY_BUTTON_A:
		if state == "title":
			if screens != null and screens.walk_live():
				return camp_hub.confirm_key()
			if screens != null and screens.walking():
				return KEY_NONE
			if screens != null and screens.overlay_open():
				return KEY_NONE
			if get_viewport().gui_get_focus_owner() != null:
				return KEY_NONE
			return KEY_SPACE
		if state == "summary" or state == "dead":
			if get_viewport().gui_get_focus_owner() != null:
				return KEY_NONE
			return KEY_N
	elif event.button_index == JOY_BUTTON_B:
		if state == "summary":
			return KEY_SPACE
		if state == "dead":
			return KEY_N
	elif event.button_index == JOY_BUTTON_Y and state == "dead":
		return KEY_C
	elif event.button_index == JOY_BUTTON_Y and state == "summary":
		return KEY_K
	elif event.button_index == JOY_BUTTON_X and state == "dead":
		return KEY_T
	return KEY_NONE


func note_device(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
		last_device = "kbm"
	elif event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.2):
		last_device = "pad"
	Glyphs.device = last_device


static func _fresh_action(action: String) -> void:
	if InputMap.has_action(action):
		InputMap.erase_action(action)
	InputMap.add_action(action, 0.2)


func _windowed() -> bool:
	return not AppShell.headless()


func capture_mouse(capture: bool) -> void:
	if test_mode or not _windowed():
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if capture and not _dev_held else Input.MOUSE_MODE_VISIBLE


func mouse_captured() -> bool:
	return _windowed() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


func menu_held() -> bool:
	return _dev_held or get_meta("menu_held", false)


func set_menu_held(held: bool) -> void:
	set_meta("menu_held", held)


func recapture_mouse() -> void:
	capture_mouse(flow.in_play() and not menu_held())


func _input(event: InputEvent) -> void:
	note_device(event)
	if test_mode:
		return
	if event is InputEventMouseMotion and mouse_captured():
		camera.look(event.relative)
		return
	if event is InputEventMouseButton:
		if not mouse_captured() and event.pressed and (flow.in_play() or screens.walk_live()) and not panel.visible and not menu_held():
			capture_mouse(true)
		return
	if event is InputEventJoypadButton:
		var pad_key := pad_screen_key(event)
		if pad_key != KEY_NONE and _screen_key(pad_key):
			get_viewport().set_input_as_handled()
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if _screen_key(event.physical_keycode):
		get_viewport().set_input_as_handled()
		return
	if _dev_key(event.physical_keycode):
		get_viewport().set_input_as_handled()
		return
	if event.physical_keycode == KEY_ESCAPE:
		if mouse_captured():
			capture_mouse(false)
		elif not flow.in_play():
			_quit()
		get_viewport().set_input_as_handled()


func _quit() -> void:
	get_tree().quit()


func _dev_key(key: int) -> bool:
	if not dev:
		return false
	match key:
		KEY_F3:
			toggle_interpolation()
			return true
		KEY_F4:
			var saved := dump_tuning()
			hud.toast("tuning saved: %s" % saved if saved != "" else "tuning dump failed (see console)")
			return true
		KEY_F1:
			panel.visible = not panel.visible
			capture_mouse(not panel.visible and flow.in_play())
			return true
	return false


func _boot(step: String) -> void:
	if _launch_flag("--boot-profile"):
		print("SCRAPKEEP_BOOT %s ms=%d" % [step, Time.get_ticks_msec()])


static func _self_play_save() -> String:
	for folder in CliFlags.values_of("--self-play-save="):
		if folder.is_valid_filename() and not folder.contains("."):
			return folder
	return str(OS.get_process_id())


static func _launch_flag(flag: String) -> bool:
	return CliFlags.has_flag(flag, true)


func _screen_key(key: int) -> bool:
	if launch_take != null and launch_take.busy():
		return true
	match flow.state_name():
		"title":
			if screens.jukebox_open():
				return screens.jukebox_key(key)
			if screens.radio_open():
				return screens.radio_key(key)
			if screens.walk_live():
				return screens.walk_key(key)
			if screens.walking():
				return false
			if key == KEY_SPACE or key == KEY_ENTER:
				flow.press_start()
				return true
			if key == KEY_C and flow.continue_ready:
				flow.resume_run()
				return true
			if key == KEY_H:
				screens.toggle_help()
				return true
			if key == KEY_A:
				screens.toggle_achievements()
				return true
			if key == KEY_S:
				screens.toggle_settings()
				return true
			if key == KEY_K:
				screens.toggle_camp()
				return true
			if dev and key == KEY_B and tuning.option(Tuning.MUSIC_KEY) == "ace":
				cycle_breath()
				screens.refresh_lab_row()
				return true
		"class_select":
			if key >= KEY_1 and key < KEY_1 + mini(flow.classes.size(), 9):
				if pilot_unlocked(flow.classes[key - KEY_1]):
					pick_pilot(key - KEY_1)
				return true
		"dead":
			if key == KEY_N:
				flow.new_run()
				return true
			if key == KEY_C:
				if _dead_c_latched:
					return true
				flow.open_class_select()
				return true
			if key == KEY_T and flow.can_replay_final_stage():
				flow.replay_stage(flow.final_stage())
				return true
		"summary":
			if summary_shut():
				if summary_latched:
					screens.latch_pressed()
				return true
			if key == KEY_K or key == KEY_ESCAPE:
				screens.open_camp_from_summary()
				return true
			if key == KEY_SPACE or key == KEY_ENTER:
				flow.press_start()
				return true
			if key == KEY_N:
				flow.new_run()
				return true
	return false


func _on_shockwave(_at: Vector3, strength: float) -> void:
	camera.shake(strength)
