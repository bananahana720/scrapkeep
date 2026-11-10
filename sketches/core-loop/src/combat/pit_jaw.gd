extends "res://src/combat/counter.gd"

# The pit jaw (roster_dig.gd, world 2; the Spillway catch trap re-homed, Andrew's "Re-home a
# few" tap, design-v3/WORLD-ROSTERS.md): a toothed jaw set flush in the Dig's floor. It slides
# under where the ball is heading and the warning is a small instant ring over it. Live, a ball
# rolling over it ON THE FLOOR (FloorRule) is bitten and held: its speed is bled hard and it is
# pulled to the jaw's centre. A ball carving a bank or wall, or in the air, passes over it. A
# slam that lands on the open jaw before it bites shuts it for good, so a lip drop is the kill.
# Boost or smash out of a bite.

const FloorRule := preload("res://src/combat/floor_rule.gd")

const JAW_RADIUS := 2.4
const LEAD := 0.7
const HOLD := 1.2
const STOP := 14.0
const CENTRE := 10.0
const BITE_DAMAGE := 6.0
const HP := 40.0
# E30's wind-up (event_kinds.gd, e30_jaw_part; coordinator call 2026-10-18, "no silent wind-ups"):
# through the warn the jaw parts at the ring, its teeth spreading JAW_SPREAD wider and rising
# JAW_RISE out of the floor; it stays parted live until it bites, then snaps shut. Presentation
# only: the ring, the bite and the timing are unchanged.
const JAW_SPREAD := 0.35
const JAW_RISE := 0.18
const JAW_GAPE := 0.6
# The catch trap's glb stands in until the Bodies thread's world 2 pit jaw lands and replaces this path.
const BODY := "res://assets/models/world_one/enemy_catch_trap.glb"

var bitten := 0
var slam_kills := 0
var _jaw: MeshInstance3D
var _jaw_rest := Vector3.ZERO
var _jaw_set := Vector3.ZERO

static var _shared: Array = []


func setup(target_ref, terrain_ref, root_ref, live_ref: Callable, threat: float, spec_ref := {}) -> void:
	super(target_ref, terrain_ref, root_ref, live_ref, threat, spec_ref)
	if _reaction_bus != null:
		_reaction_bus.slammed.connect(_on_slammed)


func _configure(threat: float) -> void:
	_set_health(HP * threat)
	scrap_value = 4
	weight = 1.2
	warn_seconds = 1.0
	live_seconds = 2.0
	rest_seconds = 4.0
	attack_range = 20.0


# BODY's glb, its jaw sunk to the floor; a flat ring with hazard teeth if it does not load.
func _build_tool() -> void:
	var parts := _parts()
	if parts.is_empty():
		_jaw = MeshInstance3D.new()
		_jaw.name = "PitJaw"
		var mesh := CylinderMesh.new()
		mesh.top_radius = 1.5
		mesh.bottom_radius = 1.5
		mesh.height = 0.12
		mesh.radial_segments = 16
		_jaw.mesh = mesh
		_jaw.material_override = Palette.solid(Palette.CHARCOAL, 0.0)
		_visual_parent().add_child(_jaw)
		for i in 8:
			var angle := TAU * float(i) / 8.0
			_box(Vector3(0.22, 0.3, 0.22), Palette.HAZARD, Vector3(cos(angle) * 1.3, 0.15, sin(angle) * 1.3), 0.6, _jaw)
	else:
		_crew.free()
		_crew = null
		for part in parts:
			var mi := MeshInstance3D.new()
			mi.name = part.name
			mi.mesh = part.mesh
			mi.transform = part.xform
			if part.flash >= 0:
				mi.set_surface_override_material(part.flash, _material)
			if part.name == "PitJaw" or part.name == "CatchCup":
				_jaw = mi
			_visual_parent().add_child(mi)
		if _jaw == null:
			_jaw = _visual_parent().get_child(-1) as MeshInstance3D
	_jaw_rest = Vector3(0.0, -half_height + 0.06, 0.0)
	_jaw.position = _jaw_rest


static func _parts() -> Array:
	if _shared.is_empty():
		_shared = EnemyCasting.parts(BODY, "pit_jaw")
	return _shared


# It sets only for a ball it can bite: one on the floor.
func _wants_attack(to_ball: Vector3) -> bool:
	var player = _player()
	if player == null or not FloorRule.on_floor(player.state):
		return false
	return to_ball.length() <= attack_range


func _commit(_to_ball: Vector3) -> Node3D:
	var aim: Vector3 = _ball() + target.planar_velocity() * LEAD
	var ring := _commit_ring(Threat.Type.INSTANT, aim, JAW_RADIUS, 2.0)
	_jaw.top_level = true
	_jaw.global_position = Vector3(ring.center.x, Telegraph.ground_under(terrain, ring.center) + 0.06, ring.center.z)
	_jaw_set = _jaw.global_position
	return ring


func _live(_delta: float) -> bool:
	var ring := telegraph()
	if ring == null:
		return false
	var player = _player()
	var ball := _real_ball()
	if not _holding():
		if player != null and caught_live == 0 and ring.contains(ball) and FloorRule.on_floor(player.state) and _catch(HOLD):
			bitten += 1
			hit_player.emit(BITE_DAMAGE, Vector3.ZERO)
		return true
	var to_centre: Vector3 = ring.center - ball
	to_centre.y = 0.0
	_pull(-player.planar_velocity() * STOP + to_centre * CENTRE)
	return true


# A slam on the open jaw, before it has bitten, shuts it for good.
func _on_slammed(at: Vector3, _strength: float, _flatness: float) -> void:
	if is_dead() or _holding() or (phase != Phase.WARN and phase != Phase.LIVE):
		return
	# Once it has bitten this live phase it is shut: a smash out of the bite, or a slam after the
	# hold runs out, does not kill it.
	if phase == Phase.LIVE and caught_live > 0:
		return
	var ring := telegraph()
	if ring == null:
		return
	if Vector2(at.x - ring.center.x, at.z - ring.center.z).length() <= JAW_RADIUS:
		slam_kills += 1
		if fleet != null:
			fleet.discover("jaw_slam", at)
		take_damage(hp)


func _on_end() -> void:
	if _jaw != null:
		_jaw.top_level = false
		_jaw.position = _jaw_rest
		_jaw.scale = Vector3.ONE


# E30's pose, e30_jaw_part: the jaw parts through the warn and holds open until it bites.
func _pose() -> void:
	if _jaw == null or not _jaw.top_level:
		return
	var part := 0.0
	if not is_dead():
		if phase == Phase.WARN:
			var t := clampf(_warn_progress(), 0.0, 1.0)
			part = t * t * (3.0 - 2.0 * t)
		elif phase == Phase.LIVE and caught_live == 0:
			part = 1.0
	_jaw.global_position = _jaw_set + Vector3.UP * JAW_RISE * part
	_jaw.scale = Vector3(1.0 + JAW_SPREAD * part, 1.0 + JAW_GAPE * part, 1.0 + JAW_SPREAD * part)
