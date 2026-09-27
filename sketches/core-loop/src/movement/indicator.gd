extends Node3D

# The player's own skill-shot geometry, drawn in the class colour and never in the
# hazard colour. Each layer holds one shape record, and the shape drawn is exactly the
# shape a release commits (RR-01, TH-03); the hit test's forgiveness lives in the rule
# that resolves the release, never in a bigger drawing.
#
# Shapes:
#   ring   {centre, radius, fill}            an area; fill > 0 adds the gauge sweep
#   line   {from, to, width}                 a lane on the ground
#   arc    {points}                          a lobbed path, landing ring separate
#   cone   {apex, dir, length, half_angle}   an eject or vault line
#   marks  {points, normal[]}                small rings on faces (the arc slam's tags)
# Every record also carries color.

const RING_SEGMENTS := 48
const LIFT := 0.12
const RENDER_PRIORITY := 3

var shapes := {}
# The last record each layer drew before it was cleared, so a test can compare what
# was on screen with what the release committed.
var last_shape := {}

var _mesh: MeshInstance3D
var _lines: ImmediateMesh


func _ready() -> void:
	top_level = true
	_lines = ImmediateMesh.new()
	_mesh = MeshInstance3D.new()
	_mesh.mesh = _lines
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.render_priority = RENDER_PRIORITY
	_mesh.material_override = mat
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)


func set_shape(layer: String, shape: Dictionary) -> void:
	shapes[layer] = shape
	last_shape[layer] = shape


func clear(layer: String) -> void:
	shapes.erase(layer)


func clear_all() -> void:
	shapes.clear()


func _process(_delta: float) -> void:
	if _lines == null:
		return
	_lines.clear_surfaces()
	if shapes.is_empty():
		return
	_lines.surface_begin(Mesh.PRIMITIVE_LINES)
	for layer in shapes:
		_draw(shapes[layer])
	_lines.surface_end()


func _draw(shape: Dictionary) -> void:
	var color: Color = shape.get("color", Color.WHITE)
	match String(shape.get("kind", "")):
		"ring":
			var centre: Vector3 = shape["centre"] + Vector3.UP * LIFT
			_circle(centre, shape["radius"], 1.0, color)
			var fill: float = shape.get("fill", 0.0)
			if fill > 0.0:
				_circle(centre, float(shape["radius"]) * 0.94, fill, Color(color, 0.8))
		"line":
			var from: Vector3 = shape["from"] + Vector3.UP * LIFT
			var to: Vector3 = shape["to"] + Vector3.UP * LIFT
			var along := to - from
			along.y = 0.0
			var side := along.cross(Vector3.UP).normalized() * float(shape["width"]) * 0.5
			for pair in [[from + side, to + side], [from - side, to - side], [from + side, from - side], [to + side, to - side]]:
				_segment(pair[0], pair[1], color)
		"arc":
			var points: Array = shape["points"]
			for i in range(1, points.size()):
				_segment(points[i - 1], points[i], color)
		"cone":
			var apex: Vector3 = shape["apex"]
			var dir: Vector3 = (shape["dir"] as Vector3).normalized()
			var length: float = shape["length"]
			var side := dir.cross(Vector3.UP)
			side = side.normalized() if side.length_squared() > 0.001 else Vector3.RIGHT
			var spread := tan(float(shape["half_angle"]))
			for edge in [dir, (dir + side * spread).normalized(), (dir - side * spread).normalized()]:
				_segment(apex, apex + edge * length, color)
		"marks":
			for point in shape["points"]:
				_circle(point, 0.6, 1.0, color)


func _circle(centre: Vector3, radius: float, sweep: float, color: Color) -> void:
	var count := maxi(2, int(RING_SEGMENTS * clampf(sweep, 0.0, 1.0)))
	var step := TAU * clampf(sweep, 0.0, 1.0) / float(count)
	for i in count:
		var a := step * float(i)
		var b := step * float(i + 1)
		_segment(centre + Vector3(sin(a), 0.0, cos(a)) * radius, centre + Vector3(sin(b), 0.0, cos(b)) * radius, color)


func _segment(a: Vector3, b: Vector3, color: Color) -> void:
	_lines.surface_set_color(color)
	_lines.surface_add_vertex(a)
	_lines.surface_set_color(color)
	_lines.surface_add_vertex(b)
