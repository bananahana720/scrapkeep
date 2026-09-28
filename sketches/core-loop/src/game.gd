extends Node3D

const GameEvents := preload("res://src/core/game_events.gd")
const RunState := preload("res://src/core/run_state.gd")
const Context := preload("res://src/core/context.gd")
const Flow := preload("res://src/core/flow.gd")
const Beacon := preload("res://src/core/beacon.gd")
const Codex := preload("res://src/core/codex.gd")
const RunLog := preload("res://src/core/run_log.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const LoopMode := preload("res://src/core/loop_mode.gd")
const SimClock := preload("res://src/core/sim_clock.gd")
const PlayerBall := preload("res://src/movement/player_ball.gd")
const ChaseCamera := preload("res://src/movement/chase_camera.gd")
const Intent := preload("res://src/movement/intent.gd")
const Augments := preload("res://src/movement/augments.gd")
const Hud := preload("res://src/ui/hud.gd")
const Screens := preload("res://src/ui/screens.gd")
const FieldNotes := preload("res://src/ui/field_notes.gd")
const TuningPanel := preload("res://src/ui/tuning_panel.gd")
const World := preload("res://src/world/world.gd")
const Combat := preload("res://src/combat/combat.gd")
const Build := preload("res://src/build/build.gd")
const Presentation := preload("res://src/presentation/presentation.gd")

# The root. It builds the spine (bus, run, tuning, ball, camera, flow, beacon), hands
# one context to the four modules in a fixed order, then owns input, pause, hit-stop
# and the tuning dump. Modules never reach past the context; see CONTRACTS.md.

const REEL_NOTCH := 1.2
const RESTART_HOLD := 0.5
const SUMMARY_GUARD := 0.75
const HIT_STOP_MAX := 0.06
const HIT_STOP_SCALE := 0.05
const HIT_STOP_BUDGET := 0.12
const HIT_STOP_WINDOW_MS := 1000
const SEED := 20260926
const BOSS_PATH := "res://src/boss/boss.gd"

const ACTIONS := {
	"cl_forward": [KEY_W, KEY_UP],
	"cl_back": [KEY_S, KEY_DOWN],
	"cl_left": [KEY_A, KEY_LEFT],
	"cl_right": [KEY_D, KEY_RIGHT],
	"cl_jump": [KEY_SPACE],
	"cl_boost": [KEY_SHIFT],
	"cl_brake": [KEY_CTRL],
	"cl_mount": [KEY_E],
	"cl_reel": [KEY_Q],
	"cl_special": [KEY_F],
}
# RMB is every class's movement ability (Sable's grapple rides it through the intent).
const MOUSE_ACTIONS := {"cl_fire": MOUSE_BUTTON_LEFT, "cl_movement": MOUSE_BUTTON_RIGHT}

# The headless tests drive the same scene with a scripted source and no mouse capture.
var test_mode := false

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
var hud
var screens
var notes
var panel
var keyboard
var codex
var run_log
# Where the codex and the run log write: user:// in play, a per-process folder the
# tests clean up when the game leaves the tree.
var storage_dir := "user://"

var _pause_toggled := false
var _notes_held := false
var _restart_held := 0.0
var _restart_latched := false
# Seconds before the summary takes a key: the victory beat ends while the player may
# still be pressing Space to jump, and the run's only summary must stay readable.
var summary_guard_left := 0.0
var _hit_stopped := false
# The loop modes' hit-stop budget: [msec, seconds] per stop taken, and the running totals.
var _stop_log: Array = []
var hit_stop_spent := 0.0
var hit_stops_skipped := 0


func _ready() -> void:
	_register_actions()
	events = GameEvents.new()
	events.name = "GameEvents"
	add_child(events)
	events.flow_changed.connect(func(state: String):
		if state == "summary":
			summary_guard_left = SUMMARY_GUARD)
	run = RunState.new(events)
	tuning = Tuning.new()
	LoopMode.apply_cmdline(tuning)

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
	codex = Codex.new()
	add_child(codex)
	codex.setup(events, run, flow, storage_dir)
	ctx.codex = codex
	run_log = RunLog.new()
	add_child(run_log)
	run_log.setup(events, run, player, codex, storage_dir)

	world = _module(World)
	preload("res://src/presentation/spillway_scenery.gd").build(ctx.terrain.geometry_root(1))
	combat = _module(Combat)
	build = _module(Build)
	# Wave 4's boss module sets up after build and before presentation when it exists.
	if ResourceLoader.exists(BOSS_PATH):
		boss = _module(load(BOSS_PATH))
	presentation = _module(Presentation)
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
	events.flow_changed.connect(_on_flow_changed)

	hud = Hud.new()
	hud.name = "Hud"
	add_child(hud)
	hud.setup(self)
	screens = Screens.new()
	screens.name = "Screens"
	add_child(screens)
	screens.setup(self)
	notes = FieldNotes.new()
	notes.name = "FieldNotes"
	add_child(notes)
	notes.setup(self)
	panel = TuningPanel.new()
	panel.name = "TuningPanel"
	add_child(panel)
	panel.setup(tuning)
	add_child(preload("res://src/ui/workshop.gd").new())
	add_child(preload("res://src/ui/pause_menu.gd").new())

	if not test_mode:
		keyboard = Intent.Keyboard.new()
		keyboard.enabled = false
		player.source = keyboard
	# The first stage's ground is where the title parks the ball.
	player.reset_to(ctx.terrain.spawn_point(1))
	player.body().global_position = ctx.terrain.spawn_point(1)
	camera.snap(ctx.terrain.entry_heading(1))
	flow.show_title()


# The fixed order: world first (it sets ctx.terrain), then combat (ctx.spawner), then
# build and presentation, which only read.
func _module(script: GDScript) -> Node:
	var module: Node = script.new()
	add_child(module)
	module.setup(ctx)
	return module


func _exit_tree() -> void:
	if not test_mode:
		return
	var dir := DirAccess.open(storage_dir)
	if dir == null:
		return
	for file in dir.get_files():
		dir.remove(file)
	DirAccess.remove_absolute(storage_dir)


func _physics_process(delta: float) -> void:
	player.drive_basis = camera.yaw_basis()
	flow.physics_step(delta)
	if flow.in_play():
		aim_along(camera.cam.global_position, -camera.cam.global_basis.z)


func _process(delta: float) -> void:
	summary_guard_left = maxf(0.0, summary_guard_left - delta)
	if test_mode:
		return
	step_restart_hold(delta, Input.is_physical_key_pressed(KEY_R))


# Hold R in play to retry. One retry per press: after any retry, from the hold or from
# the death screen's R, the hold waits for R to come up before it counts again, so a
# held R never retries twice.
func step_restart_hold(delta: float, r_down: bool) -> void:
	if not r_down:
		_restart_latched = false
	if not flow.in_play() or not r_down or _restart_latched:
		_restart_held = 0.0
		return
	_restart_held += delta
	if _restart_held >= RESTART_HOLD:
		_restart_held = 0.0
		_restart_latched = true
		flow.retry_stage()


func restart_hold_fraction() -> float:
	return clampf(_restart_held / RESTART_HOLD, 0.0, 1.0)


# The single answer to "what would the grapple hit right now". The reticle, the world
# marker and the ball's RMB grapple all read the record this stores.
func aim_along(from: Vector3, forward: Vector3) -> Dictionary:
	player.kit.aim = Augments.grapple_target(get_world_3d().direct_space_state, from, forward,
		player.ball_position(), player.grapple_range(), tuning.f("grapple_assist_deg"))
	return player.kit.aim


func hit_stop(seconds: float) -> void:
	if _hit_stopped or seconds <= 0.0 or not flow.in_play():
		return
	# The v3 loop modes add a cumulative budget (Codex review finding 5): at most
	# HIT_STOP_BUDGET of stops in any HIT_STOP_WINDOW_MS, so a chain of drops, kills and
	# slams never piles up into a stall. v2 keeps its per-stop cap alone.
	if LoopMode.mode(tuning) != "v2":
		var now := SimClock.msec()
		_stop_log = _stop_log.filter(func(entry: Array) -> bool: return now - int(entry[0]) < HIT_STOP_WINDOW_MS)
		var spent := 0.0
		for entry in _stop_log:
			spent += float(entry[1])
		var stop := minf(seconds, HIT_STOP_MAX)
		if spent + stop > HIT_STOP_BUDGET:
			hit_stops_skipped += 1
			return
		_stop_log.append([now, stop])
		hit_stop_spent += stop
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


func notes_held() -> bool:
	return _notes_held


func _apply_pause() -> void:
	get_tree().paused = _pause_toggled or _notes_held


func _on_flow_changed(_state: String) -> void:
	var playing: bool = flow.in_play()
	if keyboard != null:
		keyboard.enabled = playing
	_capture_mouse(playing)


func _register_actions() -> void:
	for action in ACTIONS:
		_fresh_action(action)
		for key in ACTIONS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
	for action in MOUSE_ACTIONS:
		_fresh_action(action)
		var button := InputEventMouseButton.new()
		button.button_index = MOUSE_ACTIONS[action]
		InputMap.action_add_event(action, button)


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
	if test_mode:
		return
	if event is InputEventMouseMotion and _mouse_captured():
		camera.look(event.relative)
		return
	if event is InputEventMouseButton:
		if not _mouse_captured():
			if event.pressed and flow.in_play() and not panel.visible and not get_meta("menu_held", false):
				_capture_mouse(true)
			return
		_mouse_button(event)
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if _screen_key(event.physical_keycode):
		get_viewport().set_input_as_handled()
		return
	match event.physical_keycode:
		KEY_F3:
			toggle_interpolation()
			get_viewport().set_input_as_handled()
		KEY_F4:
			var saved := dump_tuning()
			hud.toast("tuning saved: %s" % saved if saved != "" else "tuning dump failed (see console)")
			get_viewport().set_input_as_handled()
		KEY_F1:
			panel.visible = not panel.visible
			_capture_mouse(not panel.visible and flow.in_play())
			get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			if _mouse_captured():
				_capture_mouse(false)
			else:
				get_tree().quit()
			get_viewport().set_input_as_handled()


# One key per choice on every screen outside play. The screens' buttons press these
# same keys, so a click and a key always do the same thing.
func _screen_key(key: int) -> bool:
	match flow.state_name():
		"title":
			if key == KEY_SPACE or key == KEY_ENTER:
				flow.press_start()
				return true
			if key == KEY_H:
				screens.toggle_help()
				return true
			if key == KEY_L or key == KEY_G:
				LoopMode.cycle(tuning, LoopMode.LOOP_KEY if key == KEY_L else LoopMode.GUN_KEY)
				screens.refresh_lab_row()
				return true
		"class_select":
			if key >= KEY_1 and key < KEY_1 + mini(flow.classes.size(), 9):
				flow.choose_class(key - KEY_1)
				return true
		"dead":
			if key == KEY_R:
				_restart_latched = true
				flow.retry_stage()
				return true
			if key == KEY_N:
				flow.new_run()
				return true
			if key == KEY_C:
				flow.open_class_select()
				return true
			if key == KEY_T and flow.can_replay_final_stage():
				flow.replay_stage(3)
				return true
		"summary":
			if summary_guard_left > 0.0:
				return true
			if key == KEY_SPACE or key == KEY_ENTER:
				flow.press_start()
				return true
			if key == KEY_N:
				flow.new_run()
				return true
	return false


func _mouse_button(event: InputEventMouseButton) -> void:
	if not flow.in_play():
		return
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			if event.pressed:
				player.reel_step(REEL_NOTCH)
		MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				player.reel_step(-REEL_NOTCH)


func _on_shockwave(_at: Vector3, strength: float) -> void:
	camera.shake(strength)
