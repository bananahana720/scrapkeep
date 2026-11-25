extends Node3D

const Palette := preload("res://src/core/palette.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const WarningBound := preload("res://src/combat/warning_bound.gd")

const PRIORITY := Threat.PRIORITY
const LIFT := 0.2
const SECONDARY_TELL_FLOOR := 0.60

signal went_live

enum Shape { RING, LANE, WEDGE }

var type := Threat.UNSET
var shape := Shape.RING
var center := Vector3.ZERO
var radius := 0.0
var dir := Vector3.FORWARD
var half_angle := 0.0
var length := 0.0
var width := 0.0
var reach_up := 3.5
var aerial := false
var terrain
var progress := 0.0
var age := 0.0
var warn_seconds := 0.0
var speed := 0.0
var launch := Vector3.ZERO
var bump := 0.0
var has_flight := false
var air_only := false
var color := Palette.HAZARD
var owner_voice := ""
var mechanic_tag := ""

var _painter
var _flashed := false
var lands_on_live := true
var _body_m := 0.0
var _body_reach := -1.0
var _driven := false
var _fill_tint := Color(-1.0, -1.0, -1.0, -1.0)
var _bound := AABB()
var _bound_centre := Vector3.ZERO
var _bound_stale := false
var bound_merges := 0


static func ring(parent: Node, terrain_ref, threat_type: int, at: Vector3, ring_radius: float, reach := 3.5,
		tint := Palette.HAZARD) -> Node3D:
	var node: Node3D = load("res://src/combat/telegraph.gd").new()
	node.type = threat_type
	node.color = tint
	node.shape = Shape.RING
	node.terrain = terrain_ref
	node.radius = ring_radius
	node.reach_up = reach
	node.center = Vector3(at.x, ground_under(terrain_ref, at), at.z)
	parent.add_child(node)
	node._build()
	return node


static func aerial_ring(parent: Node, terrain_ref, threat_type: int, band_bottom: Vector3, ring_radius: float,
		band_height: float, tint := Palette.HAZARD) -> Node3D:
	var node: Node3D = load("res://src/combat/telegraph.gd").new()
	node.type = threat_type
	node.color = tint
	node.shape = Shape.RING
	node.terrain = terrain_ref
	node.radius = ring_radius
	node.reach_up = band_height
	node.aerial = true
	node.center = band_bottom
	parent.add_child(node)
	node._build()
	return node


static func wave(parent: Node, terrain_ref, at: Vector3, wave_radius: float, wave_speed: float, warn: float,
		reach := 3.5) -> Node3D:
	var node: Node3D = load("res://src/combat/telegraph.gd").new()
	node.type = Threat.Type.WAVE
	node.shape = Shape.RING
	node.terrain = terrain_ref
	node.radius = wave_radius
	node.speed = wave_speed
	node.warn_seconds = warn
	node.reach_up = reach
	node.center = Vector3(at.x, ground_under(terrain_ref, at), at.z)
	parent.add_child(node)
	node._build()
	return node


static func lane(parent: Node, terrain_ref, threat_type: int, from: Vector3, heading: Vector3, lane_length: float,
		lane_width: float, reach := 3.5) -> Node3D:
	var node: Node3D = load("res://src/combat/telegraph.gd").new()
	node.type = threat_type
	node.shape = Shape.LANE
	node.terrain = terrain_ref
	var flat := Vector3(heading.x, 0.0, heading.z)
	node.dir = flat.normalized() if flat.length() > 0.01 else Vector3.FORWARD
	node.length = lane_length
	node.width = lane_width
	node.reach_up = reach
	node.center = Vector3(from.x, ground_under(terrain_ref, from), from.z)
	parent.add_child(node)
	node._build()
	return node


static func wedge(parent: Node, terrain_ref, threat_type: int, apex: Vector3, heading: Vector3, wedge_radius: float,
		half_angle_deg: float, reach := 3.5) -> Node3D:
	var node: Node3D = load("res://src/combat/telegraph.gd").new()
	node.type = threat_type
	node.shape = Shape.WEDGE
	node.terrain = terrain_ref
	var flat := Vector3(heading.x, 0.0, heading.z)
	node.dir = flat.normalized() if flat.length() > 0.01 else Vector3.FORWARD
	node.radius = wedge_radius
	node.half_angle = deg_to_rad(half_angle_deg)
	node.reach_up = reach
	node.center = Vector3(apex.x, ground_under(terrain_ref, apex), apex.z)
	parent.add_child(node)
	node._build()
	return node


static func secondary_ring(parent: Node, terrain_ref, threat_type: int, at: Vector3, ring_radius: float,
		warn: float, reach := 3.5) -> Node3D:
	var node := ring(parent, terrain_ref, threat_type, at, ring_radius, reach, Palette.HAZARD)
	node.warn_seconds = maxf(warn, SECONDARY_TELL_FLOOR)
	return node


static func secondary_lane(parent: Node, terrain_ref, threat_type: int, from: Vector3, heading: Vector3,
		lane_length: float, lane_width: float, warn: float, reach := 3.5) -> Node3D:
	var node := lane(parent, terrain_ref, threat_type, from, heading, lane_length, lane_width, reach)
	node.warn_seconds = maxf(warn, SECONDARY_TELL_FLOOR)
	return node


static func secondary_wedge(parent: Node, terrain_ref, threat_type: int, apex: Vector3, heading: Vector3,
		wedge_radius: float, half_angle_deg: float, warn: float, reach := 3.5) -> Node3D:
	var node := wedge(parent, terrain_ref, threat_type, apex, heading, wedge_radius, half_angle_deg, reach)
	node.warn_seconds = maxf(warn, SECONDARY_TELL_FLOOR)
	return node


static func ground_under(terrain_ref, point: Vector3) -> float:
	if terrain_ref.has_method("height_at"):
		return terrain_ref.height_at(point)
	return terrain_ref.height(point.x, point.z)


func contains(point: Vector3) -> bool:
	var ground: float = center.y if aerial else (ground_under(terrain, point) if terrain != null else center.y)
	var above := point.y - ground
	if above > reach_up or above < (0.0 if aerial else -2.0):
		return false
	var flat := Vector3(point.x - center.x, 0.0, point.z - center.z)
	if shape == Shape.RING:
		if type == Threat.Type.WAVE:
			var front := front_radius()
			return front >= 0.0 and flat.length() <= radius and absf(flat.length() - front) <= Threat.WAVE_EDGE
		return flat.length() <= radius
	if shape == Shape.WEDGE:
		var out := flat.length()
		return out <= radius and (out < 0.01 or flat.dot(dir) >= out * cos(half_angle))
	var along := flat.dot(dir)
	if along < 0.0 or along > length:
		return false
	return (flat - dir * along).length() <= width * 0.5


func end_point() -> Vector3:
	return center + dir * length


func front_radius() -> float:
	if type != Threat.Type.WAVE or age < warn_seconds:
		return -1.0
	return speed * (age - warn_seconds)


func is_spent() -> bool:
	return type == Threat.Type.WAVE and front_radius() - Threat.WAVE_EDGE > radius


func step(delta: float) -> void:
	age += delta
	set_progress(age / maxf(warn_seconds, 0.001))


func set_flight(from: Vector3, arc_bump: float) -> void:
	launch = from
	bump = arc_bump
	has_flight = true
	_paint_motion()
	_repaint()
	_cut_bound()


func set_progress(value: float) -> void:
	var armed := progress < 1.0
	progress = clampf(value, 0.0, 1.0)
	_repaint()
	if armed and progress >= 1.0:
		went_live.emit()
	if progress >= 1.0 and not _flashed:
		_flashed = true
		if lands_on_live:
			land()


func land() -> void:
	if not is_inside_tree() or not is_hostile():
		return
	var floor: bool = _painter != null
	Threat.flash(get_parent(), descriptor(), center.y, LIFT, _painter.ground if floor else Callable(), _painter.ground_many if floor else Callable())


func run_body(along: float, reach: float) -> void:
	_body_m = along
	_body_reach = reach


func descriptor() -> Dictionary:
	var d := {"type": type, "tone": color, "centre": center, "reach": reach_up, "progress": progress, "live": progress >= 1.0}
	match shape:
		Shape.RING:
			d.merge({"form": "radial", "r_in": 0.0, "r_out": radius, "a0": 0.0, "a1": TAU})
		Shape.WEDGE:
			var mid := atan2(dir.z, dir.x)
			d.merge({"form": "radial", "r_in": 0.0, "r_out": radius, "a0": mid - half_angle, "a1": mid + half_angle, "pull": true})
		Shape.LANE:
			d.merge({"form": "lane", "dir": dir, "back": 0.0, "length": length, "half_width": width * 0.5})
			if _body_reach >= 0.0:
				d["body_m"] = _body_m
				d["body_reach"] = _body_reach
	if aerial:
		d["aerial"] = true
	if type == Threat.Type.WAVE:
		d["front"] = front_radius()
	if has_flight:
		d["launch"] = launch
		d["bump"] = bump
	if air_only:
		d["air"] = true
	return d


func threat_kind() -> String:
	return Threat.kind(type)


func is_hostile() -> bool:
	return Threat.stance(color) == "hostile"


func threat_at() -> Vector3:
	return center


func painter():
	return _painter


func screen_bound_box() -> AABB:
	if _painter == null or center != _bound_centre:
		return AABB()
	if _bound_stale:
		_bound_stale = false
		bound_merges += 1
		_bound = _bound.merge(WarningBound.mesh_box(_painter))
	return _bound


func _cut_bound() -> void:
	if _painter == null or not is_hostile():
		return
	_bound_centre = center
	_bound = WarningBound.box(descriptor(), WarningBound.mesh_box(_painter))


func _build() -> void:
	add_to_group("telegraph")
	if is_hostile():
		add_to_group(Threat.GROUP)
	global_position = center + Vector3.UP * LIFT
	if not Threat.valid(type):
		push_error("telegraph committed without an attack type")
		return
	var d := descriptor()
	_driven = Threat.can_drive(d)
	_painter = Threat.Painter.new()
	_painter.floor_y = center.y
	if aerial:
		var flat_y := center.y
		_painter.ground = func(_point: Vector3) -> float: return flat_y
	elif terrain != null:
		_painter.ground = func(point: Vector3) -> float: return ground_under(terrain, point)
		if terrain.has_method("heights"):
			_painter.ground_many = terrain.heights
	_painter.lift = LIFT
	_painter.driven = _driven
	_painter.centre = center
	_painter.heading = Vector2(dir.x, dir.z)
	_painter.motion_class = {Threat.Type.WAVE: "swept", Threat.Type.LANE: "run"}.get(type, "fill")
	_painter.area_class = "reach" if type == Threat.Type.PROJECTILE else "area"
	add_child(_painter)
	_painter.paint(Threat.marks(d, false), Threat.STATIC_LAYERS)
	_paint_motion()
	_repaint()
	_cut_bound()


func _paint_motion() -> void:
	if _painter != null and _driven:
		_painter.paint(Threat.driven_marks(descriptor()), Threat.MOTION_LAYERS)


func _repaint() -> void:
	if _painter == null:
		return
	var d := descriptor()
	if _driven:
		_painter.drive(Threat.drive(d))
	else:
		_painter.paint(Threat.marks(d, true), Threat.MOTION_LAYERS)
		_bound_stale = _bound_stale or _bound.size != Vector3.ZERO
	var fill := Threat.fill_tint(d)
	if fill != _fill_tint:
		_fill_tint = fill
		_painter.tint("fill", fill)


static func material(alpha: float, tint := Palette.HAZARD) -> StandardMaterial3D:
	var mat := Palette.unshaded(Color(tint, alpha))
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.render_priority = PRIORITY
	return mat
