extends Node3D

const Tuning := preload("res://src/tuning.gd")
const Field := preload("res://src/field.gd")
const PlayerBall := preload("res://src/player_ball.gd")
const ChaseCamera := preload("res://src/chase_camera.gd")
const Enemy := preload("res://src/enemy.gd")
const Hud := preload("res://src/hud.gd")
const TuningPanel := preload("res://src/tuning_panel.gd")
const Intent := preload("res://src/intent.gd")
const Augments := preload("res://src/augments.gd")
const FieldNotes := preload("res://src/field_notes.gd")

const REEL_NOTCH := 1.2
const AUGMENT_KEYS := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5]

const ACTIONS := {
	"lab_forward": [KEY_W, KEY_UP],
	"lab_back": [KEY_S, KEY_DOWN],
	"lab_left": [KEY_A, KEY_LEFT],
	"lab_right": [KEY_D, KEY_RIGHT],
	"lab_jump": [KEY_SPACE],
	"lab_boost": [KEY_SHIFT],
	"lab_brake": [KEY_CTRL],
	"lab_mount": [KEY_E],
	"lab_reel": [KEY_Q],
}

# The headless test drives the same scene with no input source and no HUD.
var test_mode := false

var tuning
var field
var player
var camera
var hud
var panel
var notes
var enemies: Array[Node3D] = []

var _pause_toggled := false
var _notes_held := false


func _ready() -> void:
	_register_actions()
	tuning = Tuning.new()
	field = Field.new()
	field.build(self)

	player = PlayerBall.new()
	player.name = "Player"
	add_child(player)
	player.setup(tuning, field.spawn)
	player.shockwave.connect(_on_shockwave)

	camera = ChaseCamera.new()
	camera.name = "ChaseCamera"
	add_child(camera)
	camera.setup(player, tuning)

	for spot in field.enemy_spawns:
		var enemy := Enemy.new()
		add_child(enemy)
		enemy.setup(player)
		enemy.global_position = spot + Vector3.UP * 1.0
		enemies.append(enemy)

	if test_mode:
		return
	player.source = Intent.Keyboard.new()
	hud = Hud.new()
	add_child(hud)
	hud.setup(player, tuning, camera.cam)
	panel = TuningPanel.new()
	add_child(panel)
	panel.setup(tuning)
	notes = FieldNotes.new()
	notes.name = "FieldNotes"
	add_child(notes)
	notes.setup(self)
	_capture_mouse(true)


func _physics_process(_delta: float) -> void:
	player.drive_basis = camera.yaw_basis()
	if test_mode:
		return
	aim_along(camera.cam.global_position, -camera.cam.global_basis.z)


# The single answer to "what would the grapple hit right now". The reticle, the world
# marker and fire_grapple() all read the record this stores.
func aim_along(from: Vector3, forward: Vector3) -> Dictionary:
	if not player.kit.on(Augments.GRAPPLE):
		player.kit.aim = Augments.no_aim()
	else:
		player.kit.aim = Augments.grapple_target(get_world_3d().direct_space_state, from, forward,
			player.ball_position(), player.grapple_range(), tuning.f("grapple_assist_deg"))
	return player.kit.aim


func fire_grapple() -> bool:
	var aim: Dictionary = player.kit.aim
	if aim["state"] == Augments.AIM_NONE:
		return false
	player.grapple_to(aim["point"], aim["normal"])
	return true


# Off by default so v1's feel stays the baseline; F3 flips it live for comparison.
func toggle_interpolation() -> bool:
	get_tree().physics_interpolation = not get_tree().physics_interpolation
	reset_physics_interpolation()
	return get_tree().physics_interpolation


func interpolating() -> bool:
	return get_tree().physics_interpolation


# The panel keeps nothing between runs, so F4 records exactly what was being played.
func dump_tuning() -> String:
	var values := {}
	for spec in Tuning.SPECS:
		values[spec["key"]] = tuning.f(spec["key"])
	var record := {
		"sketch": "mobility-kit v2",
		"saved_unix": Time.get_unix_time_from_system(),
		"physics_mode": player.mode_name(),
		"physics_interpolation": interpolating(),
		"tuning": values,
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


func _register_actions() -> void:
	for action in ACTIONS:
		if InputMap.has_action(action):
			InputMap.erase_action(action)
		InputMap.add_action(action, 0.2)
		for key in ACTIONS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)


func _windowed() -> bool:
	return DisplayServer.get_name() != "headless"


func _capture_mouse(capture: bool) -> void:
	if not _windowed():
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
			if event.pressed and (panel == null or not panel.visible):
				_capture_mouse(true)
			return
		_grapple_button(event)
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var augment := AUGMENT_KEYS.find(event.physical_keycode)
	if augment >= 0:
		player.kit.toggle(Augments.SPECS[augment]["key"])
		get_viewport().set_input_as_handled()
		return
	match event.physical_keycode:
		KEY_F2:
			player.toggle_mode()
			get_viewport().set_input_as_handled()
		KEY_F3:
			toggle_interpolation()
			get_viewport().set_input_as_handled()
		KEY_F4:
			var saved := dump_tuning()
			hud.toast("tuning saved: %s" % saved if saved != "" else "tuning dump failed (see console)")
			get_viewport().set_input_as_handled()
		KEY_F1:
			panel.visible = not panel.visible
			_capture_mouse(not panel.visible)
			get_viewport().set_input_as_handled()
		KEY_R:
			player.reset_to(field.spawn)
			camera.global_position = field.spawn
			get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			if _mouse_captured():
				_capture_mouse(false)
			else:
				get_tree().quit()
			get_viewport().set_input_as_handled()


func _grapple_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_RIGHT:
			if event.pressed:
				fire_grapple()
			else:
				player.release_grapple()
		MOUSE_BUTTON_LEFT:
			if event.pressed:
				player.zap(camera.cam.global_position, -camera.cam.global_basis.z)
		MOUSE_BUTTON_WHEEL_UP:
			if event.pressed:
				player.reel_step(REEL_NOTCH)
		MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				player.reel_step(-REEL_NOTCH)


func _on_shockwave(at: Vector3, strength: float) -> void:
	camera.shake(strength)
	if test_mode:
		return
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.15
	ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.88, 0.55, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ring.material_override = mat
	ring.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	ring.position = at
	add_child(ring)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3.ONE * (7.0 * strength), 0.45)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.45)
	tween.chain().tween_callback(ring.queue_free)
