extends Node3D

const Terrain := preload("res://src/terrain.gd")
const Tuning := preload("res://src/tuning.gd")
const Intent := preload("res://src/intent.gd")
const PlayerBall := preload("res://src/player_ball.gd")
const ChaseCamera := preload("res://src/chase_camera.gd")
const Materials := preload("res://src/materials.gd")
const RunState := preload("res://src/run_state.gd")
const Buffs := preload("res://src/buffs.gd")
const Loadout := preload("res://src/loadout.gd")
const Director := preload("res://src/director.gd")
const Flood := preload("res://src/flood.gd")
const FloodCycle := preload("res://src/flood_cycle.gd")
const ScrapField := preload("res://src/scrap_field.gd")
const LootCache := preload("res://src/loot_cache.gd")
const ExitTerminal := preload("res://src/exit_terminal.gd")
const ExitCharge := preload("res://src/exit_charge.gd")
const Chaser := preload("res://src/chaser.gd")
const Lobber := preload("res://src/lobber.gd")
const Projectile := preload("res://src/projectile.gd")
const Hud := preload("res://src/hud.gd")
const Screens := preload("res://src/screens.gd")

const ACTIONS := {
	"sd_forward": [KEY_W, KEY_UP],
	"sd_back": [KEY_S, KEY_DOWN],
	"sd_left": [KEY_A, KEY_LEFT],
	"sd_right": [KEY_D, KEY_RIGHT],
	"sd_jump": [KEY_SPACE],
	"sd_boost": [KEY_SHIFT],
	"sd_brake": [KEY_CTRL],
}

const STOMP_DAMAGE := 30.0
const STOMP_PER_SPEED := 1.1
const RAM_DAMAGE := 14.0
const RAM_PER_SPEED := 1.3
const MINIBOSS_HP := 320.0
const CACHE_COST := 25
const CACHE_COST_STEP := 12
const SECRET_COST := 20
const MESSAGE_SECONDS := 5.0
const FALL_RESCUE := 14.0
const DEFAULT_SEED := 20260922

# The headless tests drive the same scene with no input source, HUD or screens.
var test_mode := false
# Set before the stage enters the tree to reseed the scrap layout, the director and
# every other stage roll (the Jev Lab runner's trial seed). -1 keeps DEFAULT_SEED, the
# stage as it was played.
var seed_override := -1

var tuning
var terrain
var run
var player
var camera
var flood
var scrap
var director
var exit_terminal
var hud
var screens
var caches: Array = []

var _interactables: Array = []
var _secret
var _rng := RandomNumberGenerator.new()
var _message := ""
var _message_timer := 0.0


func _ready() -> void:
	_register_actions()
	var stage_seed: int = seed_override if seed_override >= 0 else DEFAULT_SEED
	_rng.seed = stage_seed
	tuning = Tuning.new()
	run = RunState.new()
	run.phase_changed.connect(_on_phase_changed)
	director = Director.new(stage_seed)

	terrain = Terrain.new()
	terrain.build(self)

	player = PlayerBall.new()
	player.name = "Player"
	add_child(player)
	player.setup(tuning, Terrain.at(Terrain.SPAWN, 2.5))
	player.shockwave.connect(_on_shockwave)
	player.enemy_struck.connect(_on_enemy_struck)

	camera = ChaseCamera.new()
	camera.name = "ChaseCamera"
	add_child(camera)
	camera.setup(player, tuning)

	flood = Flood.new()
	flood.name = "Flood"
	add_child(flood)
	flood.setup()

	scrap = ScrapField.new()
	scrap.name = "Scrap"
	add_child(scrap)
	scrap.setup(_rng)

	_build_caches()

	exit_terminal = ExitTerminal.new()
	exit_terminal.name = "ExitTerminal"
	add_child(exit_terminal)
	exit_terminal.setup(Terrain.at(Terrain.PUMP_HOUSE + Vector2(0.0, 12.0), 0.0))
	exit_terminal.used.connect(_on_exit_used)
	_interactables.append(exit_terminal)

	Loadout.apply(tuning, run)

	if test_mode:
		return
	player.source = Intent.Keyboard.new()
	hud = Hud.new()
	add_child(hud)
	hud.setup(self)
	screens = Screens.new()
	add_child(screens)
	screens.setup()
	_capture_mouse(true)


func _build_caches() -> void:
	for i in Terrain.CACHE_SPOTS.size():
		var cache := LootCache.new()
		add_child(cache)
		cache.setup(Terrain.at(Terrain.CACHE_SPOTS[i], 0.0), false, CACHE_COST + i * CACHE_COST_STEP)
		cache.used.connect(_on_cache_used)
		caches.append(cache)
		_interactables.append(cache)

	_secret = LootCache.new()
	add_child(_secret)
	_secret.setup(Terrain.at(Terrain.HATCH, 0.0), true, SECRET_COST)
	_secret.used.connect(_on_cache_used)
	caches.append(_secret)
	_interactables.append(_secret)


func enemy_count() -> int:
	return get_tree().get_nodes_in_group("enemy").size()


func _physics_process(delta: float) -> void:
	player.drive_basis = camera.yaw_basis()
	_message_timer = maxf(0.0, _message_timer - delta)
	if not run.alive():
		return

	run.advance(delta)
	flood.step(delta)
	if _secret != null and not _secret.revealed and flood.cycle.hatch_revealed():
		_secret.reveal()
		_flash("the water has drained: a maintenance hatch is open in the basin floor")

	var ball: Vector3 = player.ball_position()
	player.external_accel = flood.external_accel(ball, player.state.velocity)
	run.add_scrap(scrap.step(ball, delta))
	step_director(delta)

	exit_terminal.step(delta, ball)
	if exit_terminal.charge.phase == ExitCharge.READY and run.phase == RunState.CHARGING:
		run.set_phase(RunState.CHARGED)
	if exit_terminal.boarded(ball):
		run.set_phase(RunState.CLEARED)

	_rescue_if_fallen(ball)


# Kept separate from _physics_process so a test can step a whole stage's worth of
# difficulty in a loop instead of waiting out the real seconds.
func step_director(delta: float) -> void:
	director.spike = run.phase == RunState.CHARGING
	for kind in director.advance(delta, enemy_count()):
		spawn_enemy(kind)


func spawn_enemy(kind: int) -> Node3D:
	var enemy: Node3D
	if kind == Director.LOBBER:
		var lobber := Lobber.new()
		add_child(lobber)
		lobber.setup(player, director.lobber_hp(), 4)
		lobber.fired.connect(_on_lobber_fired)
		lobber.hit_player.connect(_on_hit_player)
		lobber.died.connect(_on_enemy_died)
		enemy = lobber
	else:
		var chaser := Chaser.new()
		add_child(chaser)
		chaser.setup(player, director.chaser_hp(), 1.0, 9.0, 3)
		chaser.hit_player.connect(_on_hit_player)
		chaser.died.connect(_on_enemy_died)
		enemy = chaser
	enemy.global_position = spawn_point()
	return enemy


# Off-screen and near: the ring is scored against where the camera is looking,
# so an enemy appears beside or behind you rather than popping in ahead.
func spawn_point() -> Vector3:
	var ball: Vector3 = player.ball_position()
	var forward: Vector3 = -camera.yaw_basis().z
	var best := ball + Vector3.UP * 2.0
	var best_score := -99.0
	for i in 12:
		var angle: float = _rng.randf() * TAU
		var dir := Vector3(cos(angle), 0.0, sin(angle))
		var spot: Vector3 = ball + dir * _rng.randf_range(34.0, 56.0)
		var x := clampf(spot.x, -108.0, 155.0)
		var z := clampf(spot.z, -178.0, 178.0)
		var ground := Terrain.height(x, z)
		var score := -dir.dot(forward)
		if absf(ground - Terrain.height(x + 3.0, z)) > 6.0:
			score -= 3.0
		if absf(ground - Terrain.height(x, z + 3.0)) > 6.0:
			score -= 3.0
		if score > best_score:
			best_score = score
			best = Vector3(x, ground + 2.4, z)
	return best


func _rescue_if_fallen(ball: Vector3) -> void:
	if ball.y > Terrain.height(ball.x, ball.z) - FALL_RESCUE and absf(ball.x) < 199.0 and absf(ball.z) < 199.0:
		return
	var x := clampf(ball.x, -105.0, 152.0)
	var z := clampf(ball.z, -178.0, 178.0)
	player.active_body().teleport(Terrain.drop_point(x, z, 3.0), Vector3.ZERO)
	run.damage(8.0)
	_flash("pulled out of the geometry")


func nearest_interactable() -> Node:
	if not run.alive():
		return null
	var ball: Vector3 = player.ball_position()
	var best: Node = null
	var best_distance := 1e9
	for node in _interactables:
		if not is_instance_valid(node) or node.prompt(run) == "":
			continue
		var d: float = ball.distance_to(node.interact_point())
		if d < node.interact_radius() and d < best_distance:
			best_distance = d
			best = node
	return best


func prompt_text() -> String:
	var node := nearest_interactable()
	return node.prompt(run) if node != null else ""


func alert_text() -> String:
	var lines: Array[String] = []
	if _message_timer > 0.0:
		lines.append(_message)
	match flood.cycle.phase:
		FloodCycle.WARNING:
			lines.append("KLAXON  ·  the basin floods in %d s" % int(ceil(flood.cycle.seconds_to_flood())))
		FloodCycle.RISING, FloodCycle.HIGH:
			lines.append("BASIN FLOODED  ·  the water is dragging you down")
		_:
			pass
	if run.phase == RunState.CHARGING:
		lines.append("PUMP-HOUSE CHARGE %d%%  ·  hold within %d m" % [
			int(exit_terminal.charge.fraction() * 100.0), int(ExitCharge.RADIUS),
		])
	elif run.phase == RunState.CHARGED:
		lines.append("CHARGED  ·  roll into the gate")
	return "\n".join(lines)


func _flash(text: String) -> void:
	_message = text
	_message_timer = MESSAGE_SECONDS


func _on_cache_used(cache) -> void:
	run.caches_opened += 1
	if cache.secret:
		run.secret_found = true
	var id: String = Buffs.roll(_rng)
	run.take_buff(id)
	Loadout.apply(tuning, run)
	_flash("cache opened: %s" % Buffs.label(id))


func _on_exit_used(_node) -> void:
	run.set_phase(RunState.CHARGING)
	var boss := Chaser.new()
	add_child(boss)
	boss.setup(player, MINIBOSS_HP, 2.3, 20.0, 24)
	boss.hit_player.connect(_on_hit_player)
	boss.died.connect(_on_enemy_died)
	boss.global_position = spawn_point()
	_flash("charge started: the director has woken something up")


func _on_lobber_fired(origin: Vector3, launch_velocity: Vector3) -> void:
	var shot := Projectile.new()
	add_child(shot)
	shot.setup(player, origin, launch_velocity)
	shot.hit_player.connect(_on_hit_player)


func _on_hit_player(amount: float) -> void:
	run.damage(amount)


func _on_enemy_died(at: Vector3, scrap_value: int) -> void:
	scrap.drop(at, scrap_value, _rng)


func _on_enemy_struck(enemy: Node3D, stomped: bool, speed: float) -> void:
	if not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
		return
	var amount := (STOMP_DAMAGE + speed * STOMP_PER_SPEED) if stomped else (RAM_DAMAGE + speed * RAM_PER_SPEED)
	enemy.take_damage(amount * Loadout.impact_multiplier(run))


func _on_phase_changed(phase: int) -> void:
	if screens == null:
		return
	if phase == RunState.DEAD or phase == RunState.CLEARED:
		screens.show_result(run)


func _on_shockwave(at: Vector3, strength: float) -> void:
	camera.shake(strength)
	if test_mode:
		return
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.15
	ring.mesh = torus
	var mat := Materials.solid(Materials.ARC, 2.0)
	mat.albedo_color = Color(Materials.ARC.r, Materials.ARC.g, Materials.ARC.b, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ring.material_override = mat
	ring.position = at
	add_child(ring)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3.ONE * (7.0 * strength), 0.45)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.45)
	tween.chain().tween_callback(ring.queue_free)


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
		_capture_mouse(true)
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_E:
			var node := nearest_interactable()
			if node != null:
				node.interact(run)
			get_viewport().set_input_as_handled()
		KEY_TAB:
			player.toggle_mode()
			get_viewport().set_input_as_handled()
		KEY_R:
			get_tree().reload_current_scene()
			get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			if _mouse_captured():
				_capture_mouse(false)
			else:
				get_tree().quit()
			get_viewport().set_input_as_handled()
