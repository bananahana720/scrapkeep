extends "res://src/combat/counter.gd"

# The burrower (world 2 row, roster_dig.gd): a Fleet crew that hides under the floor and
# shows only a flat surface marker. It hunts a ball that is on the floor (FloorRule) and under
# cruise: its wind-up commits a ring where the ball is heading, and LIVE it bursts up under
# that ring, pops a ball still on the floor there into the air, and stands surfaced and
# rammable for live_seconds. A ball carving a bank or wall, or in the air, is out of its reach
# (design-v3/WORLD-ROSTERS.md, Andrew's "Commit" tap). A slam that lands on the marker while
# it is hidden kills it, so a lip drop onto the marker is the clean kill.

const FloorRule := preload("res://src/combat/floor_rule.gd")
const SpeedTier := preload("res://src/movement/speed_tier.gd")

const HP := 45.0
const BURST_RADIUS := 2.6
const LEAD := 0.5
const MARKER_RADIUS := 1.6
const BURST_DAMAGE := 10.0
const POP := 9.0
const SHOVE := 3.0
const SINK := 3.0
# It tunnels at TUNNEL_SPEED while it roams, and during the wind-up it digs to the ring, which is
# never farther than BURST_REACH from it: at most BURST_REACH / WARN m/s under the floor.
const TUNNEL_SPEED := 4.5
const WARN := 1.0
const BURST_REACH := 18.0

var hidden := true
var bursts := 0
var slam_kills := 0
# The committed ring contained the ball: leaving the floor before the burst is burrow_lane.
var _ring_had_ball := false
var _marker: MeshInstance3D
var _marker_lip := -1
static var _shared: Array = []


func setup(target_ref, terrain_ref, root_ref, live_ref: Callable, threat: float, spec_ref := {}) -> void:
	super(target_ref, terrain_ref, root_ref, live_ref, threat, spec_ref)
	_build_marker()
	_set_hidden(true)
	if _reaction_bus != null:
		_reaction_bus.slammed.connect(_on_slammed)


func _configure(threat: float) -> void:
	_set_health(HP * threat)
	scrap_value = 4
	weight = 1.4
	walk_speed = TUNNEL_SPEED
	warn_seconds = WARN
	live_seconds = 1.2
	rest_seconds = 3.0
	attack_range = BURST_REACH


func _build_marker() -> void:
	for part in _parts():
		if part.name == "BurrowMarker":
			_marker = MeshInstance3D.new()
			_marker.name = part.name
			_marker.mesh = part.mesh
			_marker.transform = part.xform
			add_child(_marker)
			_marker_lip = _marker.find_blend_shape_by_name("MarkerWorkingLip")
			return
	var disc := CylinderMesh.new()
	disc.top_radius = MARKER_RADIUS
	disc.bottom_radius = MARKER_RADIUS
	disc.height = 0.05
	disc.radial_segments = 24
	disc.rings = 1
	_marker = MeshInstance3D.new()
	_marker.name = "BurrowMarker"
	_marker.mesh = disc
	_marker.material_override = Palette.solid(Palette.CHARCOAL)
	_marker.position.y = -half_height
	_marker.top_level = false
	add_child(_marker)


func _build_tool() -> void:
	for part in _parts():
		if part.name == "BurrowHull":
			_crew.free()
			_crew = MeshInstance3D.new()
			_crew.name = "BurrowBody"
			_crew.mesh = part.mesh
			_crew.transform = part.xform
			_base_color = Color.WHITE
			_material.albedo_color = _base_color
			_material.vertex_color_use_as_albedo = true
			_crew.set_surface_override_material(part.flash, _material)
			_visual_parent().add_child(_crew)
			return


static func _parts() -> Array:
	if _shared.is_empty():
		_shared = EnemyCasting.parts("res://assets/models/world_two/enemy_burrower.glb", "burrower")
	return _shared


func _pose() -> void:
	if _marker != null and _marker_lip >= 0:
		var progress := clampf(_warn_progress(), 0.0, 1.0) if phase == Phase.WARN else 0.0
		_marker.set_blend_shape_value(_marker_lip, progress)


func _set_hidden(value: bool) -> void:
	hidden = value
	collision_layer = 0
	if not value:
		set_collision_layer_value(3, true)
	if _crew != null:
		_crew.position.y = -SINK if value else 0.0
	if _marker != null:
		_marker.visible = value


# It only goes for a ball it can reach: on the floor and under cruise.
func _wants_attack(to_ball: Vector3) -> bool:
	var player = _player()
	if player == null or not FloorRule.on_floor(player.state) or player.speed_tier() >= SpeedTier.CRUISE:
		return false
	return to_ball.length() <= attack_range


func _commit(_to_ball: Vector3) -> Node3D:
	var aim: Vector3 = _ball() + target.planar_velocity() * LEAD
	var reach: Vector3 = aim - global_position
	reach.y = 0.0
	if reach.length() > BURST_REACH:
		aim = global_position + reach.normalized() * BURST_REACH + Vector3.UP * (aim.y - global_position.y)
	_facing(aim - global_position)
	var ring := _commit_ring(Threat.Type.INSTANT, aim, BURST_RADIUS, 2.0)
	_ring_had_ball = ring != null and ring.contains(_real_ball())
	return ring


# It tunnelled to the ring during the wind-up and breaks the floor there.
func _go_live() -> void:
	var ring := telegraph()
	if ring != null:
		global_position = Vector3(ring.center.x, Telegraph.ground_under(terrain, ring.center) + half_height, ring.center.z)
	_set_hidden(false)
	bursts += 1
	if ring == null:
		return
	var player = _player()
	var ball := _real_ball()
	if ring.contains(ball) and player != null and FloorRule.on_floor(player.state):
		var out: Vector3 = ball - ring.center
		out.y = 0.0
		var dir := out.normalized() if out.length() > 0.1 else Vector3.FORWARD
		hit_player.emit(BURST_DAMAGE, dir * SHOVE + Vector3.UP * POP)
	elif _ring_had_ball and fleet != null and player != null and not FloorRule.on_floor(player.state):
		fleet.discover("burrow_lane", ball)


func _live_motion(_to_ball: Vector3) -> Vector3:
	return Vector3.ZERO


func _on_end() -> void:
	if not is_dead():
		_set_hidden(true)


func _on_slammed(at: Vector3, _strength: float, _flatness: float) -> void:
	if not hidden or is_dead():
		return
	if Vector2(at.x - global_position.x, at.z - global_position.z).length() <= MARKER_RADIUS:
		slam_kills += 1
		take_damage(hp)
