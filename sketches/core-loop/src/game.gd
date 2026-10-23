extends Node3D

const GameEvents := preload("res://src/core/game_events.gd")
const FxLibrary := preload("res://src/presentation/fx_library.gd")
const RunState := preload("res://src/core/run_state.gd")
const Context := preload("res://src/core/context.gd")
const Flow := preload("res://src/core/flow.gd")
const Beacon := preload("res://src/core/beacon.gd")
const Secrets := preload("res://src/core/secrets.gd")
const Codex := preload("res://src/core/codex.gd")
const RunLog := preload("res://src/core/run_log.gd")
const RunMoments := preload("res://src/core/run_moments.gd")
const Profile := preload("res://src/core/profile.gd")
const AppShell := preload("res://src/core/app_shell.gd")
const Progress := preload("res://src/core/progress.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const PlayerBall := preload("res://src/movement/player_ball.gd")
const ChaseCamera := preload("res://src/movement/chase_camera.gd")
const Intent := preload("res://src/movement/intent.gd")
const Harpoon := preload("res://src/movement/harpoon.gd")
const Grip := preload("res://src/movement/grip.gd")
const Augments := preload("res://src/movement/augments.gd")
const Hud := preload("res://src/ui/hud.gd")
const Screens := preload("res://src/ui/screens.gd")
const FieldNotes := preload("res://src/ui/field_notes.gd")
const TuningPanel := preload("res://src/ui/tuning_panel.gd")
const World := preload("res://src/world/world.gd")
const Combat := preload("res://src/combat/combat.gd")
const Build := preload("res://src/build/build.gd")
const Presentation := preload("res://src/presentation/presentation.gd")
const Bindings := preload("res://src/core/bindings.gd")
const GraphicsPreset := preload("res://src/presentation/graphics_preset.gd")
const SettingsStore := preload("res://src/ui/settings_store.gd")
const EnemyMotion := preload("res://src/presentation/enemy_motion.gd")
const HighdraftFx := preload("res://src/presentation/highdraft_fx.gd")
const AbilityBar := preload("res://src/ui/ability_bar.gd")
const AimReticle := preload("res://src/ui/aim_reticle.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")
const WorldFx := preload("res://src/presentation/world_fx/world_fx.gd")
const RunStore := preload("res://src/core/run_store.gd")
const TuneRows := preload("res://src/core/tune_rows.gd")
const RadioDeck := preload("res://src/presentation/radio_deck.gd")
# The camp, the workshop, the pause menu and the met-enemy watch are not on the title's path, so they
# are loaded when first needed (menu_modules); a played game builds them a few frames after the menu.
const MENU_PATHS := [
	"res://src/world/camp_hub.gd",
	"res://src/ui/camp_enemy_picker.gd",
	"res://src/ui/workshop.gd",
	"res://src/ui/pause_menu.gd",
]
const MENU_STEPS := 4
const MENU_MODULES_FRAMES_APART := 2

# The root. It builds the spine (bus, run, tuning, ball, camera, flow, beacon), hands
# one context to the four modules in a fixed order, then owns input, pause, hit-stop
# and the tuning dump. Modules never reach past the context; see CONTRACTS.md.

const RESTART_HOLD := 0.5
const HIT_STOP_MAX := 0.06
const HIT_STOP_SCALE := 0.05
const SEED := 20260926
const BOSS_PATH := "res://src/boss/boss.gd"
const StageDefs := preload("res://src/core/stage_defs.gd")
const SliceDefs := preload("res://src/core/slice_defs.gd")
const AlphaDefs := preload("res://src/core/alpha_defs.gd")
const ParkDefs := preload("res://src/core/park_defs.gd")
const TABLES := {"default": StageDefs, "slice": SliceDefs, "alpha": AlphaDefs, "park": ParkDefs}
# A launched game with no --table plays the six parks (KD7), so the app-menu entry reaches them.
# Headless tests and bot runs (test_mode) keep the legacy maps unless they pick a table;
# --table=default still reaches those maps from a launch.
const LAUNCH_TABLE := "park"

# The headless tests drive the same scene with a scripted source and no mouse capture.
var test_mode := false:
	set(value):
		test_mode = value
		bot_driven = value
# No human answers a prompt: a bot (tools/bot_driver.gd sets it) or a headless test (test_mode
# sets it; a test that plays the human clears it after). The hot-wire screen never opens or
# pauses while it is set.
var bot_driven := false
# The stage table's id (a key of TABLES), set before the game enters the tree; empty reads
# --table= from the launch args, and no argument is LAUNCH_TABLE (the default table in test_mode).
var table := ""
# Stage 1's park ground builds on worker threads behind the menu (world.gd MENU-READY); on for a
# played game, and for a test that sets it before the game enters the tree.
var ground_behind_menu := false
# The dev keys (F1 tuning panel, F3 interpolation, F4 tuning dump, F6 boss tempo) work only when
# the game was launched with --dev; a test sets it directly. Modules read ctx.dev.
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
# Taken when the game object is created, before any child can draw (see RunState._init).
var _session_seed := randi() # lint: session seed
var hud
var screens
# The pilot radio (radio_deck.gd): the HUD dial, the takes a run finds, the playlists.
var radio_deck
# The walkable camp (camp_hub.gd). Reading it builds the menu modules if they are not up yet.
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
var codex
var run_log
# The run-end comic page's moments (src/core/run_moments.gd).
var run_moments
var progress
var _progress_ready := false
# Where the codex and the run log write: user:// in play, a per-process folder the
# tests clean up when the game leaves the tree.
var storage_dir := "user://"
# The run save's file (RS3). Play keeps it at user://run.json; a test names its own file to
# turn run saves on, and with none set a test runs without them (unlimited death retries).
var run_store_path := ""
var _settings_store

var _pause_toggled := false
var _notes_held := false
var _restart_held := 0.0
var _restart_latched := false
# The summary's input latch: it opens with the summary and stays shut while any input that was
# held then (a key, mouse button, pad button or trigger) is still held, and while the ending page
# is up. The victory beat and a death end with the player on Space or the fire button, and a
# held input must not skip the summary or start a run. A fresh press after the release takes it,
# with no time lock (wave 19).
var summary_latched := false
var _hit_stopped := false
# The device the player touched last, "kbm" or "pad": the later glyph unit reads this.
var last_device := "kbm"
# Loaded at run time only when the pack carries tools/, never preloaded (lint L7 allows this line).
const SELF_PLAY := "res://tools/self_play.gd"


func _ready() -> void:
	_boot("ready")
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
			arm_summary_latch())
	run = RunState.new(events, _session_seed)
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
	if test_mode:
		storage_dir = "user://test-%d" % OS.get_process_id()
		DirAccess.make_dir_recursive_absolute(storage_dir)
	elif _launch_flag("--self-play"):
		# A bot's run never touches the player's saves: codex, profile, run log and the run save
		# all follow storage_dir, so they land in a folder of their own.
		storage_dir = "user://self-play-%d" % OS.get_process_id()
		DirAccess.make_dir_recursive_absolute(storage_dir)
	apply_saved_bindings()
	camera.apply_look_settings(settings_store())
	codex = Codex.new()
	add_child(codex)
	codex.setup(events, run, flow, storage_dir)
	ctx.codex = codex
	run_log = RunLog.new()
	add_child(run_log)
	run_log.setup(events, run, player, codex, storage_dir)
	ctx.run_log = run_log
	run_moments = RunMoments.new()
	add_child(run_moments)
	run_moments.setup(events, run, player, flow, ctx.stages, storage_dir)
	ctx.profile = Profile.new(storage_dir.path_join("profile.json"))
	if not ctx.profile.load_profile():
		push_warning("profile: %s" % ctx.profile.last_error)
	sitting_save_guard()
	progress = Progress.new()
	progress.name = "Progress"
	add_child(progress)
	ctx.progress = progress

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
	_boot("world_hooks")
	combat = _module(Combat)
	_boot("combat")
	build = _module(Build)
	# Wave 4's boss module sets up after build and before presentation when it exists.
	if ResourceLoader.exists(BOSS_PATH):
		boss = _module(load(BOSS_PATH))
	_boot("build_boss")
	presentation = _module(Presentation)
	_boot("presentation")
	apply_saved_display()
	assert(ctx.terrain != null, "world.setup(ctx) must set ctx.terrain")
	assert(ctx.spawner != null, "combat.setup(ctx) must set ctx.spawner")
	player.struck.connect(func(enemy: Node3D, kind: String, force: float): ctx.spawner.strike(enemy, kind, force))
	# Read ctx.spawner at call time, so a test double or a late swap is honoured.
	player.crush_check = func(enemy: Node3D, kind: String, force: float) -> bool:
		if ctx.spawner == null or not ctx.spawner.has_method("would_crush"):
			flow.warn_once("would_crush", "game: spawner has no would_crush(); crush pass-through is off")
			return false
		return ctx.spawner.would_crush(enemy, kind, force)

	flow.setup(ctx, beacon)
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
	# Tests and bots build the menu modules here; a played game builds them behind the menu, and
	# at once if a run or a camp visit starts first.
	if test_mode:
		menu_modules()
	else:
		events.flow_changed.connect(func(state: String):
			if state != "title":
				menu_modules())
		# A Continue starts a run without leaving class select: the picker's watch must be up for it.
		events.run_started.connect(func(_class_id: String): menu_modules())

	if not test_mode:
		keyboard = Intent.Keyboard.new()
		keyboard.tuning = tuning
		keyboard.enabled = false
		player.source = keyboard
	# The first stage's ground is where the title parks the ball, once it is built (world.gd).
	if ctx.terrain.is_ready(1):
		_park_on_title_ground(1)
	else:
		camera.snap(ctx.terrain.entry_heading(1))
		ctx.terrain.stage_built.connect(_park_on_title_ground)
	_boot("ui")
	flow.show_title()
	_boot("title")
	if not test_mode:
		_menu_wait = MENU_MODULES_FRAMES_APART
	if _launch_flag("--self-play") and not test_mode:
		_start_self_play()
	if _launch_flag("--boot-profile"):
		for frame in 5:
			await get_tree().process_frame
			if not is_inside_tree():
				return
			_boot("frame %d" % (frame + 1))


# Builds the camp, the workshop, the pause menu and the met-enemy watch, in four steps (_menu_step).
# Called by the first reader of game.camp_hub, by workshop(), when a run leaves the title (each
# finishes what is left at once), and a few frames apart behind the menu, so no one frame loads them all.
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
			# Runs mark the enemies they spawn as met from the start, before the camp is ever opened.
			script.watch(self)
		2:
			add_child(script.new())
		3:
			add_child(script.new())
	_boot("menu_modules step %d: script %d ms, main-thread build %d ms" % [step, loaded - started, Time.get_ticks_msec() - loaded])


func _menu_script(step: int) -> Script:
	var path: String = MENU_PATHS[step]
	if _menu_requested == step:
		_menu_requested = -1
		# Blocks only when a forced build (a Start, a camp visit) finds the load still running.
		var threaded: Script = ResourceLoader.load_threaded_get(path)
		if threaded != null:
			return threaded
	return load(path)


func workshop() -> Node:
	menu_modules()
	return get_node("Workshop")


# Behind the menu, once the boot card is gone: one script at a time loads on the loader's thread
# (ONE load_threaded_request, polled a frame at a time, never a parallel pair: the preload cycles
# deadlock), and the main thread only instantiates and sets it up once it has loaded.
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
	# A run started before the ground was built finishes it on entry and places the ball after.
	if flow.in_play():
		return
	player.reset_to(ctx.terrain.spawn_point(1))
	player.body().global_position = ctx.terrain.spawn_point(1)
	camera.snap(ctx.terrain.entry_heading(1))


# --self-play hands the run to a bot from tools/ (tools/self_play.gd), which the shipped pack
# leaves out; without it the game says so and quits, rather than waiting for a player.
func _start_self_play() -> void:
	var script_path := SELF_PLAY
	# Test override: --self-play-script=<res path> points the hook elsewhere (a missing path proves exit 2).
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--self-play-script="):
			script_path = arg.trim_prefix("--self-play-script=")
	if not ResourceLoader.exists(script_path):
		push_error("game: --self-play needs a pack with tools/ (npm run sketch:export -- --self-play)")
		get_tree().quit(2)
		return
	var bot: Node = load(script_path).new()
	bot.set("game", self)
	add_child(bot)


# Moss's jukebox: a tune heard in play long enough is filed in the profile and announced on
# the HUD's record plate. Tunes the profile holds are never announced again.
func _listen_for_tunes() -> void:
	var audio = presentation.get("audio") if presentation != null else null
	if audio == null or not audio.has_signal("tune_heard"):
		return
	for id in ctx.profile.tune_ids():
		audio.knows_tune(id)
	audio.tune_heard.connect(_on_tune_heard)


func _on_tune_heard(id: String) -> void:
	if not ctx.profile.hear_tune(id):
		return
	if ctx.profile.can_save and not ctx.profile.save():
		push_warning("game: tune %s heard but not saved: %s" % [id, ctx.profile.last_error])
	hud.tune_found(String(TuneRows.row(id).get("name", id)))


func _chosen_table():
	var id := table
	if id.is_empty():
		var args := OS.get_cmdline_args()
		args.append_array(OS.get_cmdline_user_args())
		for arg in args:
			if arg.begins_with("--table="):
				id = arg.trim_prefix("--table=")
	if id.is_empty():
		return StageDefs if test_mode else TABLES[LAUNCH_TABLE]
	if not TABLES.has(id):
		push_warning("game: unknown stage table '%s'; using the default" % id)
		return StageDefs
	return TABLES[id]


# The fixed order: world first (it sets ctx.terrain), then combat (ctx.spawner), then
# build and presentation, which only read.
func _module(script: GDScript) -> Node:
	var module: Node = script.new()
	add_child(module)
	module.setup(ctx)
	return module


# The title's one line on why Continue is not offered (SAFE1); "" when it is, or no run exists.
func continue_refusal() -> String:
	return flow.continue_refusal()


# A pilot is playable when it is a starter or the profile holds it. Only the keys and card
# clicks ask; flow.choose_class stays ungated for bots and tests.
# A sitting run never writes the saved profile: every save path goes through Profile.save, which
# checks can_save. The launch flag is applied before the profile loads, so this runs once at setup.
func sitting_save_guard() -> void:
	if tuning != null and tuning.sitting() and ctx.profile != null:
		ctx.profile._refuse("sitting profile: this session does not save")
		# The sitting opens every first-win secret, as it opens every pilot (secrets.gd).
		Secrets.open_for_sitting(ctx.profile)


func pilot_unlocked(def) -> bool:
	return def.starter or (tuning != null and tuning.sitting()) or ctx.profile.has_pilot(def.id)


func _exit_tree() -> void:
	if not test_mode:
		return
	var dir := DirAccess.open(storage_dir)
	if dir == null:
		return
	for file in dir.get_files():
		dir.remove(file)
	# The scrapbook's pages and stills (run_moments.gd).
	var book := storage_dir.path_join(RunMoments.DIR)
	if DirAccess.dir_exists_absolute(book):
		for file in DirAccess.get_files_at(book):
			DirAccess.remove_absolute(book.path_join(file))
		DirAccess.remove_absolute(book)
	DirAccess.remove_absolute(storage_dir)


func _physics_process(delta: float) -> void:
	# The listener joins the bus after the first frame, once the scene is built, so a test that
	# builds its own Progress on this bus in its first frame hears each fact once.
	if not _progress_ready:
		_progress_ready = true
		progress.setup(events, run, ctx.profile, Callable(), codex)
	player.drive_basis = camera.yaw_basis()
	flow.physics_step(delta)
	if flow.in_play():
		aim_along(camera.aim_origin(), camera.aim_forward())


func _process(delta: float) -> void:
	step_summary_latch()
	if test_mode:
		return
	_step_menu_modules_later()
	step_restart_hold(delta, Input.is_action_pressed("cl_retry"))
	step_stick_look(delta)


# The right stick turns the camera every frame, captured mouse or not.
func step_stick_look(delta: float) -> void:
	var stick := Input.get_vector("cl_look_left", "cl_look_right", "cl_look_up", "cl_look_down")
	if stick != Vector2.ZERO:
		camera.look_stick(stick, delta, stick_on_target())


# True while the crosshair is on a hookable surface or enemy: the harpoon's aim record, which
# the physics step refreshes in play, holds a target. Aim assist reads it for the stick only.
func stick_on_target() -> bool:
	return player != null and player.kit.aim.get("state", Augments.AIM_NONE) != Augments.AIM_NONE


# Pushes the saved look settings to the camera; the settings page calls it after each step.
func apply_look() -> void:
	camera.apply_look_settings(settings_store())


# Hold R in play to restart. One restart per press: after one, or when R was already down
# outside play (the death screen), the hold waits for R to come up before it counts, so a
# held R never restarts twice.
func step_restart_hold(delta: float, r_down: bool) -> void:
	if not r_down:
		_restart_latched = false
	# An R held through a death (or any frame outside play) must be released before it counts:
	# the retry or new run that follows would otherwise restart again at once.
	if r_down and not flow.in_play():
		_restart_latched = true
	if not flow.in_play() or not r_down or _restart_latched:
		_restart_held = 0.0
		return
	# The victory lap is not a stage to restart: with a store, R never abandons the credits.
	if flow.store != null and flow.state == flow.LAP:
		_restart_held = 0.0
		return
	_restart_held += delta
	if _restart_held >= RESTART_HOLD:
		_restart_held = 0.0
		_restart_latched = true
		# With a run store (the real game) a held R is a restart of the run: a new run as the same
		# pilot, the open one logged as abandoned, never as a death. A store-less flow (tests,
		# bots) keeps the stage retry.
		if flow.store != null:
			flow.new_run()
		else:
			flow.retry_stage()


func restart_hold_fraction() -> float:
	return clampf(_restart_held / RESTART_HOLD, 0.0, 1.0)


# The single answer to "what would the grapple hit right now". The reticle, the world
# marker and the ball's RMB grapple all read the record this stores.
func aim_along(from: Vector3, forward: Vector3) -> Dictionary:
	player.kit.aim = Harpoon.target(player.kit, tuning, get_world_3d().direct_space_state,
		get_tree().get_nodes_in_group("enemy"), from, forward, player.ball_position())
	Grip.mark(player.kit.aim, player.heft(), tuning.pole_flail())
	return player.kit.aim


func hit_stop(seconds: float) -> void:
	if _hit_stopped or seconds <= 0.0 or not flow.in_play():
		return
	_hit_stopped = true
	Engine.time_scale = HIT_STOP_SCALE
	var timer := get_tree().create_timer(minf(seconds, HIT_STOP_MAX), true, false, true)
	timer.timeout.connect(_end_hit_stop)


func _end_hit_stop() -> void:
	Engine.time_scale = 1.0
	_hit_stopped = false


func toggle_interpolation() -> bool:
	get_tree().physics_interpolation = not get_tree().physics_interpolation
	reset_physics_interpolation()
	return get_tree().physics_interpolation


func interpolating() -> bool:
	return get_tree().physics_interpolation


# The panel keeps nothing between runs, so F4 records exactly what was being played.
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
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("tuning dump failed: %s" % error_string(FileAccess.get_open_error()))
		return ""
	file.store_string(JSON.stringify(record, "  "))
	file.close()
	var shown := ProjectSettings.globalize_path(path)
	print("tuning saved to ", shown)
	return shown


# Tab holds the notes open and P toggles; either one pauses the tree.
func toggle_pause() -> void:
	_pause_toggled = not _pause_toggled
	_apply_pause()


func hold_notes(held: bool) -> void:
	_notes_held = held
	_apply_pause()


func pause_toggled() -> bool:
	return _pause_toggled


# The ACE music's held breath, raw to hard to gentle: the title's B and the pause row.
func cycle_breath() -> String:
	var options: Array = tuning.options_of(Tuning.BREATH_KEY)
	var style: String = options[(options.find(tuning.option(Tuning.BREATH_KEY)) + 1) % options.size()]
	tuning.set_option(Tuning.BREATH_KEY, style)
	var audio = presentation.get("audio") if presentation != null else null
	if audio != null and audio.has_method("set_breath"):
		audio.set_breath(style)
	return style


func notes_held() -> bool:
	return _notes_held


func _apply_pause() -> void:
	get_tree().paused = _pause_toggled or _notes_held


func _on_flow_changed(_state: String) -> void:
	var playing: bool = flow.in_play()
	if keyboard != null:
		keyboard.enabled = playing
		keyboard.walk = false
	_capture_mouse(playing)
	if playing:
		# A is jump in play and ui_accept in a menu: nothing may keep focus into play.
		var holder := get_viewport().gui_get_focus_owner()
		if holder != null:
			holder.release_focus()


# The camp walk (camp_hub.gd) rolls the ball from the title: the keyboard and the captured mouse are live while the
# walk shows no page, and off while a page covers it. The walk's keyboard only rolls, jumps, boosts and brakes.
func walk_input(live: bool) -> void:
	if keyboard != null:
		keyboard.enabled = live
		keyboard.walk = live
	_capture_mouse(live)


# Latches the summary against whatever is held right now.
func arm_summary_latch() -> void:
	summary_latched = input_held()


# True while the summary takes no key: an input held at its opening, or the ending page over it.
func summary_shut() -> bool:
	return summary_latched or (screens != null and screens.ending_open())


# Releases the latch once nothing is held and the ending page is down.
func step_summary_latch() -> void:
	if summary_latched and not (screens != null and screens.ending_open()) and not input_held():
		summary_latched = false


# True while a key, mouse button, pad button or trigger bound to any action is down. Sticks and
# mouse motion do not count: a drifting stick must not lock a menu.
func input_held() -> bool:
	var pads := Input.get_connected_joypads()
	var table := Bindings.actions()
	for action in table:
		var record: Dictionary = table[action]
		for key in record.get("keys", []):
			if Input.is_physical_key_pressed(key):
				return true
		if record.has("button") and Input.is_mouse_button_pressed(record["button"]):
			return true
		if record.has("pad"):
			for device in pads:
				if Input.is_joy_button_pressed(device, record["pad"]):
					return true
		if record.has("axis") and record["axis"][0] in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]:
			for device in pads:
				if Input.get_joy_axis(device, record["axis"][0]) > 0.5:
					return true
	for ui_action in Bindings.UI_PAD:
		for device in pads:
			if Input.is_joy_button_pressed(device, Bindings.UI_PAD[ui_action]):
				return true
	return false


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


# A saved binding replaces only the kinds of input it names: keys and mouse buttons together,
# pad buttons on their own; stick and trigger axes always stay. A saved text that decodes to
# nothing keeps the defaults (decode warns once per token). Runs once at boot, after
# storage_dir is settled.
func apply_saved_bindings() -> void:
	var store := SettingsStore.new(storage_dir)
	for action in Bindings.actions():
		if store.binding(action).is_empty() or not InputMap.has_action(action):
			continue
		var decoded := store.binding_events(action)
		if decoded.is_empty():
			continue
		apply_binding(action, decoded)


# Puts `events` on `action` in the InputMap: keys and mouse buttons together replace the
# desk events, pad buttons replace the pad events, a trigger axis replaces the action's
# trigger, sticks stay. Boot and the settings page
# both call this, so a live rebind and a saved one cannot differ.
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


# Clears every saved binding and puts the table's defaults back at once.
func reset_bindings() -> void:
	var store = settings_store()
	for action in store.bindings.keys():
		store.clear_binding(action)
	_register_actions()
	# Recreating the actions put the default deadzone back on the look axes.
	camera.apply_look_settings(store)


# One settings store for the pause menu and the settings page, so neither saves over the
# other's changes with a stale copy.
func settings_store():
	if _settings_store == null:
		_settings_store = SettingsStore.new(storage_dir)
	return _settings_store


# The saved quality and fullscreen, after the presentation exists. A valid --preset= user
# argument beats the saved quality, as in GraphicsPreset.bind; the window mode is only
# touched on a real window. `args` stands in for the user arguments in a test.
func apply_saved_display(args: Array = []) -> void:
	var launch: Array = args if not args.is_empty() else Array(OS.get_cmdline_user_args())
	var saved := SettingsStore.new(storage_dir)
	if not launch.any(func(arg): return String(arg).begins_with("--preset=") and GraphicsPreset.PRESETS.has(String(arg).trim_prefix("--preset="))):
		set_quality(saved.quality())
	if saved.fullscreen():
		set_fullscreen(true)
	set_reduced_motion(saved.reduced_motion())
	set_reduce_flashes(saved.reduce_flashes())


# 0 High, 1 Low.
func set_quality(level: int) -> void:
	var preset := "low" if level == 1 else "high"
	if GraphicsPreset.current != preset:
		GraphicsPreset.apply(preset)


# Reduced motion: the camera holds still, the hit-edge flash drops to a quarter, enemy idle
# and the net-deck fx go quiet. Telegraph motion reads none of these, so it keeps its timing.
func set_reduced_motion(on: bool) -> void:
	EnemyMotion.motion_scale = 0.0 if on else 1.0
	HighdraftFx.preferred = on
	AbilityBar.reduced_motion = on
	AimReticle.reduced_motion = on
	WorldFx.preferred = on
	if is_instance_valid(WorldFx.current):
		WorldFx.current.set_quality(WorldFx.current.low, on)
	if presentation != null and presentation.get("juice") != null:
		presentation.juice.set_reduced_motion(on)
		presentation.player_fx.reduced_motion = on
	elif camera != null:
		camera.reduced_motion = on
	for node in find_children("*", "Node3D", true, false):
		if node.get_script() == HighdraftFx:
			node.reduced_motion = on


# Reduce flashes: every flash, white pop and strobe reads FlashGuard when it fires, so the
# switch takes effect on the next flash. Particle emitters that keep running re-read it now.
func set_reduce_flashes(on: bool) -> void:
	FlashGuard.on = on
	if is_inside_tree():
		for p in get_tree().get_nodes_in_group(FxLibrary.HEAT_GROUP):
			FxLibrary.set_heat(p)


func set_fullscreen(on: bool) -> void:
	if not _windowed():
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)


# The key a pad press stands for on the title, death and summary screens, or KEY_NONE: A is
# the screen's primary key (Space on the title; N on death and on the summary), B on the death
# screen is N, Y there opens class select and X replays, B on the summary opens class select. On the title a focused Control or an
# open overlay keeps A for the GUI (ui_accept presses the focused button; an overlay swallows it).
func pad_screen_key(event: InputEvent) -> int:
	if not (event is InputEventJoypadButton) or not event.pressed:
		return KEY_NONE
	var state: String = flow.state_name()
	if event.button_index == JOY_BUTTON_A:
		if state == "title":
			# In the camp walk A presses the station the ball is in, else it is the jump.
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


# Any key, mouse button or mouse motion is kbm; any pad button or stick past the deadzone is pad.
func note_device(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
		last_device = "kbm"
	elif event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.2):
		last_device = "pad"
	preload("res://src/ui/glyphs.gd").device = last_device


static func _fresh_action(action: String) -> void:
	if InputMap.has_action(action):
		InputMap.erase_action(action)
	InputMap.add_action(action, 0.2)


func _windowed() -> bool:
	return DisplayServer.get_name() != "headless"


func _capture_mouse(capture: bool) -> void:
	if test_mode or not _windowed():
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if capture else Input.MOUSE_MODE_VISIBLE


func _mouse_captured() -> bool:
	return _windowed() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


func _input(event: InputEvent) -> void:
	note_device(event)
	if test_mode:
		return
	if event is InputEventMouseMotion and _mouse_captured():
		camera.look(event.relative)
		return
	if event is InputEventMouseButton:
		if not _mouse_captured() and event.pressed and (flow.in_play() or screens.walk_live()) and not panel.visible and not get_meta("menu_held", false):
			_capture_mouse(true)
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
		if _mouse_captured():
			_capture_mouse(false)
		else:
			get_tree().quit()
		get_viewport().set_input_as_handled()


# F1, F3 and F4 are for whoever launched with --dev; without it they do nothing.
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
			_capture_mouse(not panel.visible and flow.in_play())
			return true
	return false


# --boot-profile prints the main-thread clock at each step of setup and over the first frames
# after the menu (MENU-READY), so a cold launch on real hardware shows where its time goes.
func _boot(step: String) -> void:
	if _launch_flag("--boot-profile"):
		print("SCRAPKEEP_BOOT %s ms=%d" % [step, Time.get_ticks_msec()])


static func _launch_flag(flag: String) -> bool:
	return flag in OS.get_cmdline_args() or flag in OS.get_cmdline_user_args()


# One key per choice on every screen outside play. The screens' buttons press these
# same keys, so a click and a key always do the same thing.
func _screen_key(key: int) -> bool:
	match flow.state_name():
		"title":
			if screens.jukebox_open():
				return screens.jukebox_key(key)
			if screens.radio_open():
				return screens.radio_key(key)
			# The camp walk: its keys act only inside a station's zone; the rest roll the ball.
			if screens.walk_live():
				return screens.walk_key(key)
			# A page open over the walk owns the keys (Space and Enter press its focused button through the UI);
			# no title hotkey may leak through it.
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
			if key == KEY_B and tuning.option(Tuning.MUSIC_KEY) == "ace":
				cycle_breath()
				screens.refresh_lab_row()
				return true
		"class_select":
			if key >= KEY_1 and key < KEY_1 + mini(flow.classes.size(), 9):
				if pilot_unlocked(flow.classes[key - KEY_1]):
					flow.choose_class(key - KEY_1)
				return true
		"dead":
			if key == KEY_N:
				flow.new_run()
				return true
			if key == KEY_C:
				flow.open_class_select()
				return true
			if key == KEY_T and flow.can_replay_final_stage():
				flow.replay_stage(flow.final_stage())
				return true
		"summary":
			if summary_shut():
				return true
			if key == KEY_K:
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
