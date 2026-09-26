extends Node3D

const Palette := preload("res://src/core/palette.gd")

# A committed telegraph: the one piece of geometry an enemy attack both draws and
# damages with. The attack decides its shape once, at commit, and the hit test later
# asks this node's contains(); nothing else decides whether the player was hit. That is
# "damage and telegraphs consume the same committed geometry" (AGENTS.md, TADR-008).
#
# Shapes: a ring on the ground (a slam or a shell's blast) or a lane along the ground
# (a lunge or a charge). Both reach `reach_up` metres above the ground under the ball,
# so jumping or gliding over one dodges it: a read the player can act on at speed.
#
# Readability: every telegraph draws in HAZARD, with no depth test, at a render priority
# above every player effect (Bolts.PRIORITY, Effects.PRIORITY), so our own bolts, arcs
# and blasts can never paint over the next threat (principle 4).

const PRIORITY := 40
const AREA_ALPHA := 0.16
const FILL_ALPHA := 0.34
const EDGE_ALPHA := 0.9
const LIFT := 0.2

enum Shape { RING, LANE }

var shape := Shape.RING
var center := Vector3.ZERO
var radius := 0.0
var dir := Vector3.FORWARD
var length := 0.0
var width := 0.0
var reach_up := 3.5
var terrain
var progress := 0.0

var _fill: Node3D


static func ring(parent: Node, terrain_ref, at: Vector3, ring_radius: float, reach := 3.5) -> Node3D:
	var node: Node3D = load("res://src/combat/telegraph.gd").new()
	node.shape = Shape.RING
	node.terrain = terrain_ref
	node.radius = ring_radius
	node.reach_up = reach
	node.center = Vector3(at.x, terrain_ref.height(at.x, at.z), at.z)
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
	node.center = Vector3(from.x, terrain_ref.height(from.x, from.z), from.z)
	parent.add_child(node)
	node._build()
	return node


# The hit test every attack uses. The height is measured from the ground under the
# point, so a ring on a slope still means what it shows.
func contains(point: Vector3) -> bool:
	var ground: float = terrain.height(point.x, point.z) if terrain != null else center.y
	var above := point.y - ground
	if above > reach_up or above < -2.0:
		return false
	var flat := Vector3(point.x - center.x, 0.0, point.z - center.z)
	if shape == Shape.RING:
		return flat.length() <= radius
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
	if shape == Shape.RING:
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
		var edge := TorusMesh.new()
		edge.inner_radius = maxf(0.05, radius - 0.35)
		edge.outer_radius = radius
		_mesh(edge, EDGE_ALPHA, Vector3.ZERO)
		var fill := CylinderMesh.new()
		fill.top_radius = 1.0
		fill.bottom_radius = 1.0
		fill.height = 0.06
		_fill = _mesh(fill, FILL_ALPHA, Vector3.ZERO)
	else:
		basis = Basis.looking_at(dir, Vector3.UP)
		var area := BoxMesh.new()
		area.size = Vector3(width, 0.04, length)
		_mesh(area, AREA_ALPHA, Vector3(0.0, 0.0, -length * 0.5))
		for side in [-1.0, 1.0]:
			var rail := BoxMesh.new()
			rail.size = Vector3(0.3, 0.08, length)
			_mesh(rail, EDGE_ALPHA, Vector3(side * width * 0.5, 0.0, -length * 0.5))
		# The fill grows from the attacker's end, so the lane reads as "coming this way".
		var holder := Node3D.new()
		add_child(holder)
		var fill := BoxMesh.new()
		fill.size = Vector3(width * 0.9, 0.06, length)
		var inner := MeshInstance3D.new()
		inner.mesh = fill
		inner.material_override = material(FILL_ALPHA)
		inner.position = Vector3(0.0, 0.0, -length * 0.5)
		inner.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(inner)
		_fill = holder
	set_progress(progress)


func _mesh(mesh: Mesh, alpha: float, offset: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material(alpha)
	instance.position = offset
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance


static func material(alpha: float) -> StandardMaterial3D:
	var mat := Palette.unshaded(Color(Palette.HAZARD, alpha))
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.render_priority = PRIORITY
	return mat
