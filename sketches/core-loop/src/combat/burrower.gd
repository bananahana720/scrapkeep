extends "res://src/combat/counter.gd"

const FloorRule := preload("res://src/combat/floor_rule.gd")
const SpeedTier := preload("res://src/movement/speed_tier.gd")
const EnemyBossCraft := preload("res://src/presentation/craft/enemy_boss_craft.gd")

const HP := 45.0
const BURST_RADIUS := 2.6
const LEAD := 0.5
const MARKER_RADIUS := 1.6
const BURST_DAMAGE := 10.0
const POP := 9.0
const SHOVE := 3.0
const SINK := 3.0
const TUNNEL_SPEED := 4.5
const WARN := 1.0
const BURST_REACH := 18.0
const PRIMARY_LIVE := 1.2

const WALL_SKIM_WARN := 0.85
const WALL_SKIM_LIVE := 1.1
const WALL_SKIM_LENGTH := 16.0
const WALL_SKIM_WIDTH := 2.8
const WALL_SKIM_DAMAGE := 9.0
const WALL_SKIM_SHOVE := 5.0
const WALL_SKIM_ARC_H := 4.5
const AIRBORNE_PIN_RADIUS := 3.2

var hidden := true
var bursts := 0
var slam_kills := 0
var wall_skims := 0
var airborne_pins := 0
var airborne_skim := false
var next_attack := ""
var last_pin := {}
var _ring_had_ball := false
var _wall_skim := false
var _skim_origin := Vector3.ZERO
var _skim_dir := Vector3.FORWARD
var _skim_base_y := 0.0
var _skim_hit := false
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
	_marker = MeshInstance3D.new()
	_marker.name = "BurrowMarker"
	_marker.mesh = EnemyBossCraft.burrow_marker_mesh(MARKER_RADIUS, 0.05)
	var marker_mat := StandardMaterial3D.new()
	marker_mat.albedo_color = Palette.CHARCOAL
	marker_mat.roughness = 0.72
	marker_mat.metallic = 0.24
	Palette.surface_grain(marker_mat)
	_marker.material_override = marker_mat
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
			Palette.surface_grain(_material)
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


func _use_wall_skim() -> bool:
	if next_attack == "wall_skim":
		return true
	if next_attack == "burst":
		return false
	return bursts > wall_skims


func _commit(to_ball: Vector3) -> Node3D:
	var is_skim := _use_wall_skim()
	_wall_skim = is_skim
	next_attack = ""
	if is_skim:
		warn_seconds = WALL_SKIM_WARN
		live_seconds = WALL_SKIM_LIVE
		var flat := Vector3(to_ball.x, 0.0, to_ball.z)
		_skim_dir = flat.normalized() if flat.length() > 0.1 else Vector3.FORWARD
		_skim_origin = global_position
		_skim_hit = false
		_facing(_skim_dir)
		return _commit_lane(Threat.Type.LANE, global_position, _skim_dir, WALL_SKIM_LENGTH, WALL_SKIM_WIDTH, 3.0)
	warn_seconds = WARN
	live_seconds = PRIMARY_LIVE
	var aim: Vector3 = _ball() + target.planar_velocity() * LEAD
	var reach: Vector3 = aim - global_position
	reach.y = 0.0
	if reach.length() > BURST_REACH:
		aim = global_position + reach.normalized() * BURST_REACH + Vector3.UP * (aim.y - global_position.y)
	_facing(aim - global_position)
	var ring := _commit_ring(Threat.Type.INSTANT, aim, BURST_RADIUS, 2.0)
	_ring_had_ball = ring != null and ring.contains(_real_ball())
	return ring


# It tunnelled to the ring during the wind-up and breaks the floor there; on Wall-Skim
# Eruption it vaults airborne down its committed lane, exposed to an airborne slam pin.
func _go_live() -> void:
	if _wall_skim:
		_set_hidden(false)
		airborne_skim = true
		wall_skims += 1
		_skim_base_y = Telegraph.ground_under(terrain, global_position) + half_height
		_skim_origin = global_position
		_skim_hit = false
		return
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


func _live(_delta: float) -> bool:
	if not _wall_skim:
		return true
	var tele := telegraph()
	if tele == null:
		return false
	var frac := clampf(_t / maxf(WALL_SKIM_LIVE, 0.05), 0.0, 1.0)
	var horiz := _skim_origin + _skim_dir * (WALL_SKIM_LENGTH * 0.65 * frac)
	var ground_y := Telegraph.ground_under(terrain, horiz) + half_height
	global_position = Vector3(horiz.x, ground_y + sin(frac * PI) * WALL_SKIM_ARC_H, horiz.z)
	if not _skim_hit:
		var player = _player()
		var ball := _real_ball()
		if player != null and FloorRule.on_floor(player.state) and player.speed_tier() < SpeedTier.CRUISE and tele.contains(ball):
			_skim_hit = true
			var side := _skim_dir.cross(Vector3.UP).normalized()
			hit_player.emit(WALL_SKIM_DAMAGE, side * WALL_SKIM_SHOVE + Vector3.UP * (POP * 0.65))
	return true


func _live_motion(_to_ball: Vector3) -> Vector3:
	return Vector3.ZERO


func _on_end() -> void:
	airborne_skim = false
	_wall_skim = false
	warn_seconds = WARN
	live_seconds = PRIMARY_LIVE
	if not is_dead():
		if terrain != null:
			global_position.y = Telegraph.ground_under(terrain, global_position) + half_height
		_set_hidden(true)


func _pin_airborne(at: Vector3) -> void:
	if not airborne_skim or is_dead():
		return
	airborne_pins += 1
	airborne_skim = false
	broken_by = "airborne_pin"
	if terrain != null:
		global_position.y = Telegraph.ground_under(terrain, global_position) + half_height
	last_pin = {"at": global_position, "slam_at": at, "frame": Engine.get_physics_frames()}
	if fleet != null:
		fleet.discover("burrow_lane", global_position)
	take_damage(hp)


func on_struck(kind_hit: String, _part: String, _result: Dictionary) -> void:
	if kind_hit == "slam" and airborne_skim and not is_dead():
		_pin_airborne(global_position)


func _on_slammed(at: Vector3, _strength: float, _flatness: float) -> void:
	if is_dead():
		return
	if airborne_skim:
		if Vector2(at.x - global_position.x, at.z - global_position.z).length() <= AIRBORNE_PIN_RADIUS:
			_pin_airborne(at)
		return
	if not hidden:
		return
	if Vector2(at.x - global_position.x, at.z - global_position.z).length() <= MARKER_RADIUS:
		slam_kills += 1
		take_damage(hp)
