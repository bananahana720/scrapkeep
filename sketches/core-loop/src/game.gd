extends Node3D

const GameEvents := preload("res://src/core/game_events.gd")
const RunState := preload("res://src/core/run_state.gd")
const Context := preload("res://src/core/context.gd")
const Flow := preload("res://src/core/flow.gd")
const Beacon := preload("res://src/core/beacon.gd")
const Codex := preload("res://src/core/codex.gd")
const RunLog := preload("res://src/core/run_log.gd")
const Profile := preload("res://src/core/profile.gd")
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
const RunStore := preload("res://src/core/run_store.gd")

# The root. It builds the spine (bus, run, tuning, ball, camera, flow, beacon), hands
# one context to the four modules in a fixed order, then owns input, pause, hit-stop
# and the tuning dump. Modules never reach past the context; see CONTRACTS.md.

const RESTART_HOLD := 0.5
const SUMMARY_GUARD := 0.75
const HIT_STOP_MAX := 0.06
const HIT_STOP_SCALE := 0.05
const SEED := 20260926
const BOSS_PATH := "res://src/boss/boss.gd"
const StageDefs := preload("res://src/core/stage_defs.gd")
const SliceDefs := preload("res://src/core/slice_defs.gd")
const AlphaDefs := preload("res://src/core/alpha_defs.gd")
const ParkDefs := preload("res://src/core/park_defs.gd")
const TABLES := {"default": StageDefs, "slice": SliceDefs, "alpha": AlphaDefs, "park": ParkDefs}

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
# --table= from the launch args, and no argument is the default table.
var table := ""
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
var notes
var panel
var keyboard
var codex
var run_log
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
# Seconds before the summary takes a key: the victory beat ends while the player may
# still be pressing Space to jump, and the run's only summary must stay readable.
var summary_guard_left := 0.0
var _hit_stopped := false
# The device the player touched last, "kbm" or "pad": the later glyph unit reads this.
var last_device := "kbm"


func _ready() -> void:
	dev = dev or _launch_flag("--dev")
	_register_actions()
	events = GameEvents.new()
	events.name = "GameEvents"
	add_child(events)
	events.flow_changed.connect(func(state: String):
		if state == "summary":
			summary_guard_left = SUMMARY_GUARD)
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
	ctx.profile = Profile.new(storage_dir.path_join("profile.json"))
	if not ctx.profile.load_profile():
		push_warning("profile: %s" % ctx.profile.last_error)
	sitting_save_guard()
	progress = Progress.new()
	progress.name = "Progress"
	add_child(progress)
	ctx.progress = progress

	world = _module(World)
	for row in ctx.stages.DEFS:
		if row["map"] == "spillway":
			preload("res://src/presentation/spillway_scenery.gd").build(ctx.terrain.geometry_root(row["stage"]))
	preload("res://src/presentation/dig_scenery.gd").hook(ctx)
	preload("res://src/presentation/highdraft_scenery.gd").hook(ctx)
	preload("res://src/presentation/world_look.gd").hook(ctx)
	combat = _module(Combat)
	build = _module(Build)
	# Wave 4's boss module sets up after build and before presentation when it exists.
	if ResourceLoader.exists(BOSS_PATH):
		boss = _module(load(BOSS_PATH))
	presentation = _module(Presentation)
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
		keyboard.tuning = tuning
		keyboard.enabled = false
		player.source = keyboard
	# The first stage's ground is where the title parks the ball.
	player.reset_to(ctx.terrain.spawn_point(1))
	player.body().global_position = ctx.terrain.spawn_point(1)
	camera.snap(ctx.terrain.entry_heading(1))
	flow.show_title()


func _chosen_table():
	var id := table
	if id.is_empty():
		var args := OS.get_cmdline_args()
		args.append_array(OS.get_cmdline_user_args())
		for arg in args:
			if arg.begins_with("--table="):
				id = arg.trim_prefix("--table=")
	if id.is_empty():
		return StageDefs
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
	summary_guard_left = maxf(0.0, summary_guard_left - delta)
	if test_mode:
		return
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
	_capture_mouse(playing)
	if playing:
		# A is jump in play and ui_accept in a menu: nothing may keep focus into play.
		var holder := get_viewport().gui_get_focus_owner()
		if holder != null:
			holder.release_focus()


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
	if presentation != null and presentation.get("juice") != null:
		presentation.juice.set_reduced_motion(on)
	elif camera != null:
		camera.reduced_motion = on
	for node in find_children("*", "Node3D", true, false):
		if node.get_script() == HighdraftFx:
			node.reduced_motion = on


func set_fullscreen(on: bool) -> void:
	if not _windowed():
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)


# The key a pad press stands for on the title, death and summary screens, or KEY_NONE: A is
# the screen's primary key (Space; R on death), B on the death screen is N, Y there opens class
# select and X replays, B on the summary starts a new run. On the title a focused Control or an
# open overlay keeps A for the GUI (ui_accept presses the focused button; an overlay swallows it).
func pad_screen_key(event: InputEvent) -> int:
	if not (event is InputEventJoypadButton) or not event.pressed:
		return KEY_NONE
	var state: String = flow.state_name()
	if event.button_index == JOY_BUTTON_A:
		if state == "title":
			if screens != null and screens.overlay_open():
				return KEY_NONE
			if get_viewport().gui_get_focus_owner() != null:
				return KEY_NONE
			return KEY_SPACE
		if state == "summary":
			return KEY_SPACE
		if state == "dead":
			return KEY_R
	elif event.button_index == JOY_BUTTON_B:
		if state == "dead" or state == "summary":
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
		if not _mouse_captured() and event.pressed and flow.in_play() and not panel.visible and not get_meta("menu_held", false):
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


static func _launch_flag(flag: String) -> bool:
	return flag in OS.get_cmdline_args() or flag in OS.get_cmdline_user_args()


# One key per choice on every screen outside play. The screens' buttons press these
# same keys, so a click and a key always do the same thing.
func _screen_key(key: int) -> bool:
	match flow.state_name():
		"title":
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
				flow.replay_stage(flow.final_stage())
				return true
		"summary":
			if summary_guard_left > 0.0:
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
