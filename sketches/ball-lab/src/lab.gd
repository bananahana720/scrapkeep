extends Node3D

const Tuning := preload("res://src/tuning.gd")
const Field := preload("res://src/field.gd")
const PlayerBall := preload("res://src/player_ball.gd")
const ChaseCamera := preload("res://src/chase_camera.gd")
const Enemy := preload("res://src/enemy.gd")
const Hud := preload("res://src/hud.gd")
const TuningPanel := preload("res://src/tuning_panel.gd")
const Intent := preload("res://src/intent.gd")

const ACTIONS := {
	"lab_forward": [KEY_W, KEY_UP],
	"lab_back": [KEY_S, KEY_DOWN],
	"lab_left": [KEY_A, KEY_LEFT],
	"lab_right": [KEY_D, KEY_RIGHT],
	"lab_jump": [KEY_SPACE],
	"lab_boost": [KEY_SHIFT],
	"lab_brake": [KEY_CTRL],
}

# The headless test drives the same scene with no input source and no HUD.
var test_mode := false

var tuning
var field
var player
var camera
var hud
var panel
var enemies: Array[Node3D] = []


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
	hud.setup(player, tuning)
	panel = TuningPanel.new()
	add_child(panel)
	panel.setup(tuning)
	_capture_mouse(true)


func _physics_process(_delta: float) -> void:
	player.drive_basis = camera.yaw_basis()


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
	if event is InputEventMouseButton and event.pressed and not _mouse_captured():
		if panel == null or not panel.visible:
			_capture_mouse(true)
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_TAB:
			player.toggle_mode()
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
	ring.position = at
	add_child(ring)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3.ONE * (7.0 * strength), 0.45)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.45)
	tween.chain().tween_callback(ring.queue_free)
