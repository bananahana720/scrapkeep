extends Node3D

const Palette := preload("res://src/core/palette.gd")

# A committed telegraph: the one piece of geometry an enemy attack both draws and
# damages with. The attack decides its shape once, at commit, and the hit test later
# asks this node's contains(); nothing else decides whether the player was hit. That is
# "damage and telegraphs consume the same committed geometry" (AGENTS.md, TADR-008).
#
# Shapes: a ring on the ground (a slam or a shell's blast), a lane along the ground
# (a lunge or a charge) or a wedge fanning out from a point (the Warden's magnet pull).
# All reach `reach_up` metres above the ground under the ball, so jumping or gliding
# over one dodges it: a read the player can act on at speed. The wedge's rim is dashed
# and chevrons along its middle point back at the apex, so a pull never reads as the
# solid ring of a push.
#
# Readability: every telegraph draws in HAZARD, with no depth test, at a render priority
# above every player effect (Bolts.PRIORITY, Effects.PRIORITY), so our own bolts, arcs
# and blasts can never paint over the next threat (principle 4).

const PRIORITY := 40
const AREA_ALPHA := 0.16
const FILL_ALPHA := 0.34
const EDGE_ALPHA := 0.9
const LIFT := 0.2
# The Spillway ground is an orange-and-sand checker, so HAZARD alone washes into it. Every
# edge is drawn over a wider dark underlay, and a ring's edge thickens with its radius,
# so a 30 m Warden ring still reads as a bold line from 60 m.
const EDGE_MIN := 0.35
const EDGE_PER_METRE := 0.04
const UNDERLAY := 0.35
const UNDERLAY_ALPHA := 0.85
const RAIL := 0.5
const WEDGE_SEGMENTS := 24
const WEDGE_DASHES := 11
const CHEVRONS := [0.3, 0.55, 0.8]
const CHEVRON_HALF_WIDTH := 1.6
const CHEVRON_DEPTH := 1.3

enum Shape { RING, LANE, WEDGE }

var shape := Shape.RING
var center := Vector3.ZERO
var radius := 0.0
var dir := Vector3.FORWARD
var half_angle := 0.0
var length := 0.0
var width := 0.0
var reach_up := 3.5
var terrain
var progress := 0.0
# HAZARD for every enemy threat. A ring the player owns (a batted shell) draws in AMBER.
var color := Palette.HAZARD

var _fill: Node3D


static func ring(parent: Node, terrain_ref, at: Vector3, ring_radius: float, reach := 3.5, tint := Palette.HAZARD) -> Node3D:
	var node: Node3D = load("res://src/combat/telegraph.gd").new()
	node.color = tint
	node.shape = Shape.RING
	node.terrain = terrain_ref
	node.radius = ring_radius
	node.reach_up = reach
	node.center = Vector3(at.x, ground_under(terrain_ref, at), at.z)
	parent.add_child(node)
	node._build()
	return node


static func lane(parent: Node, terrain_ref, from: Vector3, heading: Vector3, lane_length: float,
		lane_width: float, reach := 3.5) -> Node3D:
	var node: Node3D = load("res://src/combat/telegraph.gd").new()
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


# A fan of `half_angle_deg` either side of `heading`, out to `wedge_radius` from `apex`.
static func wedge(parent: Node, terrain_ref, apex: Vector3, heading: Vector3, wedge_radius: float,
		half_angle_deg: float, reach := 3.5) -> Node3D:
	var node: Node3D = load("res://src/combat/telegraph.gd").new()
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


# The ground under a point. Combat's ground (ground.gd) answers at the point itself, so
# in the arena a telegraph stands on the boss floor; a plain terrain answers by x and z.
static func ground_under(terrain_ref, point: Vector3) -> float:
	if terrain_ref.has_method("height_at"):
		return terrain_ref.height_at(point)
	return terrain_ref.height(point.x, point.z)


# The hit test every attack uses. The height is measured from the ground under the
# point, so a ring on a slope still means what it shows.
func contains(point: Vector3) -> bool:
	var ground: float = ground_under(terrain, point) if terrain != null else center.y
	var above := point.y - ground
	if above > reach_up or above < -2.0:
		return false
	var flat := Vector3(point.x - center.x, 0.0, point.z - center.z)
	if shape == Shape.RING:
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


func set_progress(value: float) -> void:
	progress = clampf(value, 0.0, 1.0)
	if _fill == null:
		return
	if shape == Shape.RING or shape == Shape.WEDGE:
		var r := maxf(0.05, radius * progress)
		_fill.scale = Vector3(r, 1.0, r)
	else:
		_fill.scale = Vector3(1.0, 1.0, maxf(0.02, progress))


func _build() -> void:
	add_to_group("telegraph")
	global_position = center + Vector3.UP * LIFT
	if shape == Shape.RING:
		var area := CylinderMesh.new()
		area.top_radius = radius
		area.bottom_radius = radius
		area.height = 0.04
		_mesh(area, AREA_ALPHA, Vector3.ZERO)
		var width := maxf(EDGE_MIN, radius * EDGE_PER_METRE)
		var under := TorusMesh.new()
		under.inner_radius = maxf(0.05, radius - width - UNDERLAY)
		under.outer_radius = radius + UNDERLAY
		under.rings = 96
		_underlay(under, Vector3.DOWN * 0.05)
		var edge := TorusMesh.new()
		edge.inner_radius = maxf(0.05, radius - width)
		edge.outer_radius = radius
		edge.rings = 96
		_mesh(edge, EDGE_ALPHA, Vector3.ZERO)
		var fill := CylinderMesh.new()
		fill.top_radius = 1.0
		fill.bottom_radius = 1.0
		fill.height = 0.06
		_fill = _mesh(fill, FILL_ALPHA, Vector3.ZERO)
	elif shape == Shape.WEDGE:
		_build_wedge()
	else:
		basis = Basis.looking_at(dir, Vector3.UP)
		var area := BoxMesh.new()
		area.size = Vector3(width, 0.04, length)
		_mesh(area, AREA_ALPHA, Vector3(0.0, 0.0, -length * 0.5))
		for side in [-1.0, 1.0]:
			var under := BoxMesh.new()
			under.size = Vector3(0.5 + UNDERLAY * 2.0, 0.06, length + UNDERLAY * 2.0)
			_underlay(under, Vector3(side * width * 0.5, -0.05, -length * 0.5))
			var rail := BoxMesh.new()
			rail.size = Vector3(0.5, 0.08, length)
			_mesh(rail, EDGE_ALPHA, Vector3(side * width * 0.5, 0.0, -length * 0.5))
		# The fill grows from the attacker's end, so the lane reads as "coming this way".
		var holder := Node3D.new()
		add_child(holder)
		var fill := BoxMesh.new()
		fill.size = Vector3(width * 0.9, 0.06, length)
		var inner := MeshInstance3D.new()
		inner.mesh = fill
		inner.material_override = material(FILL_ALPHA, color)
		inner.position = Vector3(0.0, 0.0, -length * 0.5)
		inner.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(inner)
		_fill = holder
	set_progress(progress)


# Local -Z is dir. Solid side rails, a dashed rim and chevrons pointing back at the apex;
# the fill fans out from the apex as the pull charges.
func _build_wedge() -> void:
	basis = Basis.looking_at(dir, Vector3.UP)
	_mesh(_sector(radius), AREA_ALPHA, Vector3.ZERO)
	for side in [-1.0, 1.0]:
		var turn := Basis(Vector3.UP, side * half_angle)
		var mid := _spoke(side * half_angle) * radius * 0.5
		_edge(Vector3(RAIL, 0.08, radius), mid, turn)
	var dash := 2.0 * half_angle * radius / WEDGE_DASHES * 0.55
	for i in WEDGE_DASHES:
		var angle := lerpf(-half_angle, half_angle, (i + 0.5) / WEDGE_DASHES)
		_edge(Vector3(dash, 0.08, RAIL * 1.4), _spoke(angle) * (radius - RAIL), Basis(Vector3.UP, angle))
	for share in CHEVRONS:
		var tip := Vector3(0.0, 0.0, -radius * share)
		for side in [-1.0, 1.0]:
			var arm := Vector3(side * CHEVRON_HALF_WIDTH, 0.0, -CHEVRON_DEPTH)
			_edge(Vector3(RAIL, 0.08, arm.length()), tip + arm * 0.5, Basis.looking_at(arm.normalized(), Vector3.UP))
	_fill = _mesh(_sector(1.0), FILL_ALPHA, Vector3.ZERO)


# One edge piece of the wedge over its dark underlay.
func _edge(size: Vector3, at: Vector3, turn: Basis) -> void:
	var under := BoxMesh.new()
	under.size = size + Vector3(UNDERLAY * 2.0, -0.02, UNDERLAY * 2.0)
	_underlay(under, at + Vector3.DOWN * 0.05).basis = turn
	var edge := BoxMesh.new()
	edge.size = size
	_mesh(edge, EDGE_ALPHA, at).basis = turn


func _spoke(angle: float) -> Vector3:
	return Vector3(-sin(angle), 0.0, -cos(angle))


func _sector(sector_radius: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	for i in WEDGE_SEGMENTS:
		verts.append(Vector3.ZERO)
		verts.append(_spoke(lerpf(-half_angle, half_angle, float(i) / WEDGE_SEGMENTS)) * sector_radius)
		verts.append(_spoke(lerpf(-half_angle, half_angle, float(i + 1) / WEDGE_SEGMENTS)) * sector_radius)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


# The dark band under an edge: charcoal, drawn just before the edge itself.
func _underlay(mesh: Mesh, offset: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	var mat := material(UNDERLAY_ALPHA, Palette.CHARCOAL)
	mat.render_priority = PRIORITY - 1
	instance.material_override = mat
	instance.position = offset
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance


func _mesh(mesh: Mesh, alpha: float, offset: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material(alpha, color)
	instance.position = offset
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance


static func material(alpha: float, tint := Palette.HAZARD) -> StandardMaterial3D:
	var mat := Palette.unshaded(Color(tint, alpha))
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.render_priority = PRIORITY
	return mat
