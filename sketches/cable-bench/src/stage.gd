extends Node3D

const Tuning := preload("res://src/tuning.gd")
const Layout := preload("res://src/layout.gd")
const Terrain := preload("res://src/terrain.gd")
const PlayerBall := preload("res://src/player_ball.gd")
const ChaseCamera := preload("res://src/chase_camera.gd")
const Intent := preload("res://src/intent.gd")
const RunState := preload("res://src/run_state.gd")
const Rules := preload("res://src/rules.gd")
const Loadout := preload("res://src/loadout.gd")
const ScrapField := preload("res://src/scrap_field.gd")
const Cache := preload("res://src/cache.gd")
const Cableway := preload("res://src/cableway.gd")
const Director := preload("res://src/director.gd")
const Forge := preload("res://src/forge.gd")
const Materials := preload("res://src/materials.gd")
const Palette := preload("res://src/palette.gd")
const Hud := preload("res://src/hud.gd")
const Screens := preload("res://src/screens.gd")

const ACTIONS := {
	"lab_forward": [KEY_W, KEY_UP],
	"lab_back": [KEY_S, KEY_DOWN],
	"lab_left": [KEY_A, KEY_LEFT],
	"lab_right": [KEY_D, KEY_RIGHT],
	"lab_jump": [KEY_SPACE],
	"lab_boost": [KEY_SHIFT],
	"lab_brake": [KEY_CTRL],
}

const SCRAP_COUNT := 84

# The headless tests drive the same scene with no input source, HUD or screens.
var test_mode := false
# A Jev Lab trial sets this before the stage enters the tree, so one trial seed fixes
# every stage random stream: cache buffs, the scrap scatter and drops, and the
# director. -1 keeps the hand-picked seeds below.
var seed_override := -1

var tuning
var run
var loadout
var terrain
var player
var camera
var forge
var scrap_field
var director
var hud
var screens
var caches: Array[Node3D] = []
var cableways: Array[Node3D] = []

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_register_actions()
	_rng.seed = _seed_for(90210)
	tuning = Tuning.new()
	run = RunState.new()

	terrain = Terrain.new()
	terrain.build(self)

	player = PlayerBall.new()
	player.name = "Player"
	add_child(player)
	player.setup(tuning, Layout.spawn_point())
	# Rigid is the mode Andrew accepted; Tab is still here to feel the difference.
	player.set_mode(PlayerBall.RIGID)
	player.enemy_struck.connect(_on_enemy_struck)
	player.shockwave.connect(_on_shockwave)

	loadout = Loadout.new()
	loadout.bind(tuning, player.state, run)

	camera = ChaseCamera.new()
	camera.name = "ChaseCamera"
	add_child(camera)
	camera.setup(player, tuning)
	# Aim the spawn view down the first line; everything else about the camera is
	# the accepted ball-lab one, untouched.
	camera.yaw = Layout.spawn_yaw()

	forge = Forge.new()
	forge.name = "Forge"
	add_child(forge)
	forge.setup(run)

	scrap_field = ScrapField.new()
	scrap_field.name = "ScrapField"
	add_child(scrap_field)
	scrap_field.setup(run, player, _seed_for(4711))
	scrap_field.scatter(SCRAP_COUNT)

	for spot in Layout.cache_spots():
		var cache := Cache.new()
		add_child(cache)
		cache.setup(spot["name"], spot["at"], run, loadout, _rng)
		caches.append(cache)

	for spec in Layout.CABLEWAYS:
		var cableway := Cableway.new()
		add_child(cableway)
		cableway.setup(spec, run, player)
		cableways.append(cableway)

	director = Director.new()
	director.name = "Director"
	add_child(director)
	director.setup(run, player, camera.cam, _seed_for(1337))
	director.spawned.connect(_on_spawned)

	run.phase_changed.connect(_on_phase_changed)

	if test_mode:
		return
	player.source = Intent.Keyboard.new()
	hud = Hud.new()
	add_child(hud)
	hud.setup(player, tuning, run, loadout)
	screens = Screens.new()
	add_child(screens)
	screens.setup()
	_capture_mouse(true)


func _physics_process(delta: float) -> void:
	player.drive_basis = camera.yaw_basis()
	var ball: Vector3 = player.ball_position()
	run.tick(delta, forge.in_zone(ball))
	if run.phase == RunState.Phase.READY and forge.at_exit(ball):
		run.take_exit()


# Each stream keeps its own default seed as an offset, so the three streams stay
# independent under one trial seed.
func _seed_for(default_seed: int) -> int:
	if seed_override < 0:
		return default_seed
	return seed_override * 1000003 + default_seed


func interact() -> String:
	var ball: Vector3 = player.ball_position()
	if run.phase == RunState.Phase.RUNNING and forge.at_exit(ball):
		run.start_charge()
		return "forge charging"
	for cache in caches:
		if not cache.in_reach(ball):
			continue
		if not cache.affordable():
			return "need %d scrap (you have %d)" % [cache.cost(), run.scrap]
		var buff: Dictionary = cache.open()
		if buff.is_empty():
			return ""
		return "%s: %s" % [buff["label"], buff["effect"]]
	return ""


func restart() -> void:
	get_tree().reload_current_scene()


func _on_phase_changed(phase: int) -> void:
	match phase:
		RunState.Phase.CHARGING:
			# The charge is the bill for everything you took on the way up.
			director.spike_miniboss()
			_say("Forge charging. Hold the apron for %ds." % int(run.charge_seconds))
		RunState.Phase.READY:
			_say("Forge charged. Roll into the rig.")
		RunState.Phase.CLEAR, RunState.Phase.DEAD:
			if screens != null:
				screens.show_result(run, loadout)
			_capture_mouse(false)


func _on_spawned(foe: Node3D) -> void:
	foe.died.connect(_on_foe_died)


func _on_foe_died(foe: Node3D, scrap_value: int) -> void:
	scrap_field.drop(foe.global_position, scrap_value)


func _on_enemy_struck(foe: Node3D, kind: String, force: float) -> void:
	if not is_instance_valid(foe):
		return
	var damage: float = Rules.STOMP_DAMAGE if kind == "stomp" else force * Rules.RAM_DAMAGE_PER_SPEED
	foe.take_damage(damage * loadout.damage_multiplier)


func _say(text: String) -> void:
	if hud != null:
		hud.say(text)


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
	if not _windowed() or test_mode:
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
	if event is InputEventMouseButton and event.pressed and not _mouse_captured() and run.live():
		_capture_mouse(true)
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_E:
			var said := interact()
			if said != "":
				_say(said)
			get_viewport().set_input_as_handled()
		KEY_TAB:
			player.toggle_mode()
			get_viewport().set_input_as_handled()
		KEY_R:
			restart()
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
	var mat := Materials.solid(Palette.AMBER)
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
