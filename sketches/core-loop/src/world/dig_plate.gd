extends Node3D

# Unit P1 probe: the Dig's breach plate. A square slab level with the deck. While the ball
# slams onto it with a strength at or above `threshold` (PlayerBall.slam_strength of its fall
# speed) the plate breaks one tick before contact: its collider goes, the slam ends, and the
# ball carries its own velocity on through the hole. A weaker slam lands on it, plants and
# leaves it whole (the engine's normal slam). The four tabs read the one `eligible` state:
# mint (the live role) when a slam pressed now would break it, slate when it would not.

const EventKinds := preload("res://src/core/event_kinds.gd")
const Palette := preload("res://src/core/palette.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const PlayerBall := preload("res://src/movement/player_ball.gd")

# Ticks of margin: the collider is off before a ball falling at up to slam_speed arrives.
const LEAD_TICKS := 3.0
# The slam's own downward acceleration from the fall (slam_speed * SLAM_RAMP, augments.gd).
const SLAM_ACCEL := 168.0

var size := 6.0
var thickness := 2.0
var threshold := 1.0

var broken := false
var eligible := false
var last_break_strength := 0.0
var landed_strengths: Array[float] = []
var breaks := 0
# Stock mode (--stock): no break-before-contact; the plate breaks on the engine's own slam landing, after its plant.
var stock := false

var _game
var _body: StaticBody3D
var _shape: CollisionShape3D
var _face: MeshInstance3D
var _tabs: Array[MeshInstance3D] = []
var _tab_mat: StandardMaterial3D
var _wired := false


func _ready() -> void:
	stock = OS.get_cmdline_user_args().has("--stock")
	_body = StaticBody3D.new()
	_body.position = Vector3(0.0, -thickness * 0.5, 0.0)
	_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size, thickness, size)
	_shape.shape = box
	_body.add_child(_shape)
	add_child(_body)
	# The pale dished face, a charcoal frame and Y-crack bars, so the plate reads as a membrane.
	_face = _mesh(Vector3(size - 0.5, 0.12, size - 0.5), Vector3(0.0, 0.0, 0.0), Palette.solid(Palette.SAND))
	_mesh(Vector3(size, 0.1, 0.35), Vector3(0.0, 0.02, size * 0.5 - 0.17), Palette.solid(Palette.CHARCOAL))
	_mesh(Vector3(size, 0.1, 0.35), Vector3(0.0, 0.02, -size * 0.5 + 0.17), Palette.solid(Palette.CHARCOAL))
	_mesh(Vector3(0.35, 0.1, size), Vector3(size * 0.5 - 0.17, 0.02, 0.0), Palette.solid(Palette.CHARCOAL))
	_mesh(Vector3(0.35, 0.1, size), Vector3(-size * 0.5 + 0.17, 0.02, 0.0), Palette.solid(Palette.CHARCOAL))
	for a in [0.0, 2.094, 4.189]:
		var crack := _mesh(Vector3(0.22, 0.14, size * 0.42), Vector3(sin(a) * size * 0.21, 0.0, cos(a) * size * 0.21), Palette.solid(Palette.CHARCOAL))
		crack.rotation.y = -a
	_tab_mat = Palette.solid(EventKinds.role_color("slate"))
	for corner in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		var tab := _mesh(Vector3(0.7, 0.2, 0.7), Vector3(corner.x * (size * 0.5 - 0.9), 0.05, corner.y * (size * 0.5 - 0.9)), _tab_mat)
		_tabs.append(tab)


func _mesh(mesh_size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = mesh_size
	m.mesh = b
	m.material_override = mat
	m.position = at
	add_child(m)
	return m


func _find_game():
	var n: Node = self
	while n != null:
		if "player" in n and "events" in n:
			return n
		n = n.get_parent()
	return null


# Puts the plate back whole (a retry, or the next scripted drop).
func restore() -> void:
	broken = false
	_shape.set_deferred("disabled", false)
	for child in get_children():
		if child is MeshInstance3D:
			child.visible = true


func _physics_process(delta: float) -> void:
	if _game == null:
		_game = _find_game()
		if _game == null or _game.player == null:
			return
	if not _wired:
		_wired = true
		_game.camera.pin_pivot_when_falling = not OS.get_cmdline_user_args().has("--no-pin")
		_game.events.slammed.connect(_on_slammed)
	var player = _game.player
	var body: RigidBody3D = player.body()
	if body == null:
		return
	var p := body.global_position
	var v := body.linear_velocity
	var local := p - global_position
	var over := absf(local.x) < size * 0.5 + 0.4 and absf(local.z) < size * 0.5 + 0.4
	var above := local.y - Tuning.RADIUS
	var tick := Engine.time_scale * delta
	eligible = false
	if over and not broken and not player.state.grounded and above > -0.5 and above < 40.0:
		var down := maxf(0.0, -v.y)
		var fall := down
		if not player.kit.slamming:
			# A slam pressed now accelerates the fall at SLAM_ACCEL up to slam_speed.
			fall = minf(player.tuning.f("slam_speed"), sqrt(down * down + 2.0 * SLAM_ACCEL * maxf(above, 0.0)))
		eligible = PlayerBall.slam_strength(fall) >= threshold
		# Only a ball whose whole footprint is over the plate drops through the opening it leaves.
		var inside: bool = absf(local.x) <= size * 0.5 - Tuning.RADIUS and absf(local.z) <= size * 0.5 - Tuning.RADIUS
		if inside and not stock and player.kit.slamming and above < maxf(1.5, down * tick * LEAD_TICKS) and v.y < 0.0:
			if PlayerBall.slam_strength(down) >= threshold:
				_break(down)
	_paint()


func _break(fall: float) -> void:
	broken = true
	breaks += 1
	last_break_strength = PlayerBall.slam_strength(fall)
	_shape.set_deferred("disabled", true)
	# The plate's slam is spent on the plate: the ball keeps its line and falls on.
	_game.player.kit.slamming = false
	# The key may still be down: it must be let go before it can slam again.
	_game.player.kit.brake_from_ground = true
	_game.events.world_fact.emit("breach_broken", global_position)
	for child in get_children():
		if child is MeshInstance3D:
			child.visible = false


func _on_slammed(at: Vector3, strength: float, _flatness: float) -> void:
	var local := at - global_position
	if absf(local.x) < size * 0.5 + 0.6 and absf(local.z) < size * 0.5 + 0.6 and absf(local.y) < 2.5:
		landed_strengths.append(strength)
		var inside: bool = absf(local.x) <= size * 0.5 - Tuning.RADIUS and absf(local.z) <= size * 0.5 - Tuning.RADIUS
		if stock and not broken and inside and strength >= threshold:
			broken = true
			breaks += 1
			last_break_strength = strength
			_shape.set_deferred("disabled", true)
			_game.events.world_fact.emit("breach_broken", global_position)
			for child in get_children():
				if child is MeshInstance3D:
					child.visible = false


func _paint() -> void:
	var role := "live" if eligible else "slate"
	var color := EventKinds.role_color(role)
	_tab_mat.albedo_color = color
	_tab_mat.emission_enabled = eligible
	_tab_mat.emission = color
	_tab_mat.emission_energy_multiplier = 2.0
	for tab in _tabs:
		tab.position.y = 0.12 if eligible else 0.02
