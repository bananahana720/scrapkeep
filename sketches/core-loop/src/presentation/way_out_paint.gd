extends MeshInstance3D

const Palette := preload("res://src/core/palette.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")


const START_M := 1.9
const SPACING_M := 1.7
const HALF_SPAN_M := 0.75
const SWEEP_M := 0.6
const STROKE_M := 0.26
const KEYLINE_M := 0.08
const MARCH_MPS := 3.4
const FADE := 0.5
const BAR_PAST_M := 0.7
const BAR_HALF_M := 1.9
const BAR_THICK_M := 0.34
const LIFT_M := 0.22
const PRIORITY := Threat.LINE_PRIORITY + 1

var ball: Callable
var ground: Callable
var _watch
var _mesh := ImmediateMesh.new()
var _clock := 0.0


func _init() -> void:
	name = "WayOutPaint"
	top_level = true
	mesh = _mesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 16.0
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.render_priority = PRIORITY
	material_override = mat
	visible = false


func setup(watch, ball_ref: Callable, ground_ref: Callable) -> void:
	_watch = watch
	ball = ball_ref
	ground = ground_ref


func _process(delta: float) -> void:
	if _watch == null or not ball.is_valid():
		paint({}, Vector3.ZERO)
		return
	_clock += delta
	paint(_watch.escape(), ball.call())


func paint(escape: Dictionary, at: Vector3) -> void:
	var dir: Vector3 = escape.get("dir", Vector3.ZERO)
	if dir.length_squared() <= 0.0:
		if visible:
			visible = false
			_mesh.clear_surfaces()
		return
	visible = true
	_mesh.clear_surfaces()
	var strokes := strokes_for(at, dir, float(escape.get("metres", 0.0)), _clock)
	var fills: Array = []
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for stroke in strokes:
		var keyline := _corners(stroke["from"], stroke["to"], stroke["width"] + KEYLINE_M * 2.0, KEYLINE_M)
		var heights: Array[float] = []
		for p in keyline:
			heights.append(_height(p) + LIFT_M)
		_tri(keyline, heights, Color(Palette.CHARCOAL, stroke["alpha"]))
		fills.append([_corners(stroke["from"], stroke["to"], stroke["width"], 0.0), heights, Color(Palette.SAND, stroke["alpha"])])
	for fill in fills:
		_tri(fill[0], fill[1], fill[2])
	_mesh.surface_end()


static func strokes_for(at: Vector3, dir: Vector3, metres: float, clock: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var way := Vector3(dir.x, 0.0, dir.z).normalized()
	var side := Vector3(-way.z, 0.0, way.x)
	var foot := Vector3(at.x, 0.0, at.z)
	var shift := fposmod(clock * MARCH_MPS, SPACING_M)
	var reach := START_M - SPACING_M + shift
	while reach <= metres:
		if reach >= START_M:
			var fade_in := clampf((reach - START_M) / (SPACING_M * FADE), 0.0, 1.0)
			var fade_out := clampf((metres - reach) / (SPACING_M * FADE), 0.0, 1.0)
			var alpha := minf(fade_in, fade_out)
			if alpha > 0.0:
				var tip := foot + way * reach
				for arm in [side, -side]:
					out.append({"from": tip - way * SWEEP_M + arm * HALF_SPAN_M, "to": tip, "width": STROKE_M, "alpha": alpha})
		reach += SPACING_M
	var bar := foot + way * (maxf(metres, 0.0) + BAR_PAST_M)
	out.append({"from": bar - side * BAR_HALF_M, "to": bar + side * BAR_HALF_M, "width": BAR_THICK_M, "alpha": 1.0})
	return out


static func _corners(from: Vector3, to: Vector3, width: float, cap: float) -> Array[Vector3]:
	var along := (to - from).normalized()
	from -= along * cap
	to += along * cap
	var across := Vector3(-along.z, 0.0, along.x) * width * 0.5
	return [from - across, from + across, to + across, to - across]


func _tri(corners: Array[Vector3], heights: Array[float], color: Color) -> void:
	for index in [0, 1, 2, 0, 2, 3]:
		var p: Vector3 = corners[index]
		_mesh.surface_set_color(color)
		_mesh.surface_add_vertex(Vector3(p.x, heights[index], p.z))


func _height(p: Vector3) -> float:
	if ground.is_valid():
		return float(ground.call(p.x, p.z))
	return ball.call().y if ball.is_valid() else 0.0
