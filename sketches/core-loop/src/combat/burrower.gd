extends "res://src/combat/counter.gd"

# The burrower (world 2 row, roster_dig.gd): a Fleet crew that hides under the floor and
# shows only a flat surface marker. Its wind-up commits a lane from its hiding spot toward
# the ball; LIVE it bursts up and lunges along that lane. A slam that lands on the marker
# while it is hidden kills it.

const HP := 45.0
const LANE_LENGTH := 14.0
const LANE_WIDTH := 2.2
const MARKER_RADIUS := 1.6
const BURST_DAMAGE := 10.0
const SHOVE := 8.0
const LUNGE_SPEED := 16.0
const SINK := 3.0

var hidden := true
var bursts := 0
var slam_kills := 0
# The committed lane contained the ball: rolling off it before the burst is burrow_lane.
var _lane_had_ball := false
var _marker: MeshInstance3D
var _marker_lip := -1
static var _warned_asset := false
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
	walk_speed = 4.5
	warn_seconds = 1.0
	live_seconds = 0.6
	rest_seconds = 3.0
	attack_range = 18.0


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
	if not _shared.is_empty():
		return _shared
	var path := "res://assets/models/world_two/enemy_burrower.glb"
	if not ResourceLoader.exists(path):
		return _shared
	var packed := load(path) as PackedScene
	if packed == null:
		return _shared
	var scene := packed.instantiate()
	var painted := Palette.solid(Color.WHITE)
	painted.vertex_color_use_as_albedo = true
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var mesh: Mesh = mi.mesh.duplicate()
		var flash := -1
		for i in mesh.get_surface_count():
			var surface_material := mesh.surface_get_material(i)
			if surface_material == null and not _warned_asset:
				_warned_asset = true
				push_warning("burrower: surface has no material; using default finish")
			if surface_material != null and surface_material.resource_name == "fleet_paint":
				flash = i
			mesh.surface_set_material(i, painted)
		_shared.append({"name": mi.name, "mesh": mesh, "xform": mi.transform, "flash": flash})
	scene.free()
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


func _commit(to_ball: Vector3) -> Node3D:
	_facing(to_ball)
	var lane := _commit_lane(Threat.Type.LANE, global_position, to_ball, LANE_LENGTH, LANE_WIDTH)
	_lane_had_ball = lane != null and lane.contains(_real_ball())
	return lane


func _go_live() -> void:
	_set_hidden(false)
	bursts += 1
	var lane := telegraph()
	if lane != null and lane.contains(_real_ball()):
		hit_player.emit(BURST_DAMAGE, lane.dir * SHOVE + Vector3.UP * 4.0)
	elif lane != null and _lane_had_ball and fleet != null:
		fleet.discover("burrow_lane", _real_ball())


func _live_motion(_to_ball: Vector3) -> Vector3:
	var lane := telegraph()
	if lane == null:
		return Vector3.ZERO
	return lane.dir * LUNGE_SPEED


func _on_end() -> void:
	if not is_dead():
		_set_hidden(true)


func _on_slammed(at: Vector3, _strength: float, _flatness: float) -> void:
	if not hidden or is_dead():
		return
	if Vector2(at.x - global_position.x, at.z - global_position.z).length() <= MARKER_RADIUS:
		slam_kills += 1
		take_damage(hp)
