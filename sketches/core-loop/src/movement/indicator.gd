extends Node3D

const Palette := preload("res://src/core/palette.gd")


const LIFT := 0.12
const RENDER_PRIORITY := 3
const SEGMENTS := 48
const FILL_ALPHA := 0.15
const EDGE := 0.12
const EXTENT := 0.06
const KEYLINE := 0.08
const DASH := 0.9
const GAP := 0.6
const BREATHE := 0.5
const COLLAPSE := 0.12
const TICK_STEP_DEG := 30.0
const TICK_LEN := 0.45
const AIM_FILL := 1.2
const AIM_ROOT := Vector2(0.3, 0.15)
const LENS_CLEAR := 1.5
const LENS_FULL := 4.0
const LAST_SHAPE_CAP := 64

var shapes := {}
var last_shape := {}
var _collapsing := {}

var _mesh: MeshInstance3D
var _tris: ImmediateMesh
var _materials: Array = []
var _k := 1.0
var _anchor := Vector3.ZERO
var _dirty := false
var _rebuild_count := 0


func _ready() -> void:
	top_level = true
	_tris = ImmediateMesh.new()
	_mesh = MeshInstance3D.new()
	_mesh.mesh = _tris
	_materials = [material(false), material(true)]
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)


# Palette vertex colors are sRGB; without vertex_color_is_srgb Forward+ reads them as linear light.
static func material(aim: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = true
	mat.render_priority = RENDER_PRIORITY
	if aim:
		mat.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
		mat.distance_fade_min_distance = LENS_CLEAR
		mat.distance_fade_max_distance = LENS_FULL
	return mat


static func is_aim(shape: Dictionary) -> bool:
	return bool(shape.get("aim", false))


# ImmediateMesh errors if a surface ends with zero vertices.
static func draws(shape: Dictionary) -> bool:
	match String(shape.get("kind", "")):
		"ring", "line", "cone":
			return true
		"marks":
			return not (shape["points"] as Array).is_empty()
		"arc":
			var count := (shape["points"] as Array).size()
			return count >= 2 or (count == 1 and bool(shape.get("blocked", false)))
	return false


func set_shape(layer: String, shape: Dictionary) -> void:
	shapes[layer] = shape
	if last_shape.has(layer):
		last_shape.erase(layer)
	last_shape[layer] = shape
	while last_shape.size() > LAST_SHAPE_CAP:
		last_shape.erase(last_shape.keys()[0])
	_collapsing.erase(layer)
	_dirty = true


func clear(layer: String) -> void:
	if shapes.erase(layer):
		_dirty = true


func clear_all() -> void:
	if not shapes.is_empty() or not _collapsing.is_empty():
		_dirty = true
	shapes.clear()
	_collapsing.clear()
	last_shape.clear()


func collapse(layer: String) -> void:
	if shapes.has(layer):
		_collapsing[layer] = {"shape": shapes[layer], "t": 0.0}
		shapes.erase(layer)
		_dirty = true


func collapse_all() -> void:
	for layer in shapes.keys():
		collapse(layer)


func collapsing(layer: String) -> bool:
	return _collapsing.has(layer)


static func style(shape: Dictionary, now: float) -> Dictionary:
	if shape.get("blocked", false):
		return {"edge": Palette.SAND, "fill": Color(Palette.SAND, 0.0), "dashed": true, "cross": true}
	var color: Color = shape.get("color", Color.WHITE)
	var fill_alpha := FILL_ALPHA
	if float(shape.get("fill", 0.0)) >= 1.0:
		fill_alpha *= 1.0 + 0.8 * (0.5 + 0.5 * sin(TAU * now / BREATHE))
	var kind := String(shape.get("kind", ""))
	return {"edge": color, "fill": Color(color, fill_alpha), "dashed": kind == "arc" or kind == "cone", "cross": false}


static func cone_fill(shape: Dictionary, fill: Color) -> Dictionary:
	if not is_aim(shape):
		return {"from": 0.0, "reach": 1.0, "far": fill}
	var length := maxf(float(shape.get("length", AIM_FILL)), 0.01)
	var from := minf(1.0, float(shape.get("clear", 0.0)) / length)
	return {"from": from, "reach": minf(1.0, from + AIM_FILL / length), "far": Color(fill, 0.0)}


static func cone_tips(shape: Dictionary) -> Array:
	var apex: Vector3 = shape["apex"]
	var dir: Vector3 = (shape["dir"] as Vector3).normalized()
	var length: float = shape["length"]
	if is_aim(shape):
		return [apex + dir * length]
	var side := _cone_side(dir)
	var spread := tan(float(shape["half_angle"]))
	return [apex + (dir + side * spread).normalized() * length, apex + (dir - side * spread).normalized() * length, apex + dir * length]


static func _cone_side(dir: Vector3) -> Vector3:
	var side := dir.cross(Vector3.UP)
	return side.normalized() if side.length_squared() > 0.001 else Vector3.RIGHT


func _has_breathing() -> bool:
	for shape in shapes.values():
		if not bool(shape.get("blocked", false)) and float(shape.get("fill", 0.0)) >= 1.0:
			return true
	return false


func _process(delta: float) -> void:
	if _tris == null:
		return
	if not _collapsing.is_empty():
		_dirty = true
		for layer in _collapsing.keys():
			_collapsing[layer]["t"] += delta
			if _collapsing[layer]["t"] >= COLLAPSE:
				_collapsing.erase(layer)
	if not _dirty and not _has_breathing():
		return
	_dirty = false
	_rebuild_count += 1
	_tris.clear_surfaces()
	if shapes.is_empty() and _collapsing.is_empty():
		return
	var now := Time.get_ticks_msec() / 1000.0
	var drawn := [[], []]
	for layer in shapes:
		if draws(shapes[layer]):
			drawn[int(is_aim(shapes[layer]))].append([shapes[layer], 1.0])
	for layer in _collapsing:
		var entry: Dictionary = _collapsing[layer]
		if draws(entry["shape"]):
			drawn[int(is_aim(entry["shape"]))].append([entry["shape"], 1.0 - clampf(entry["t"] / COLLAPSE, 0.0, 1.0)])
	for i in drawn.size():
		if drawn[i].is_empty():
			continue
		_tris.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _materials[i])
		for item in drawn[i]:
			_k = item[1]
			_draw(item[0], now)
		_tris.surface_end()


func _origin(shape: Dictionary) -> Vector3:
	match String(shape.get("kind", "")):
		"ring":
			return shape["centre"]
		"line":
			return shape["from"]
		"cone":
			return shape["apex"]
		"arc", "marks":
			return shape["points"][0] if not (shape["points"] as Array).is_empty() else Vector3.ZERO
	return Vector3.ZERO


func _p(point: Vector3) -> Vector3:
	return _anchor + (point - _anchor) * _k + Vector3.UP * LIFT


func _draw(shape: Dictionary, now: float) -> void:
	_anchor = _origin(shape)
	var look := style(shape, now)
	var edge: Color = look["edge"]
	var fill: Color = look["fill"]
	var dashed: bool = look["dashed"]
	var ticks := String(shape.get("ticks", "")) if not shape.get("blocked", false) else ""
	match String(shape.get("kind", "")):
		"ring":
			var centre: Vector3 = shape["centre"]
			var radius: float = shape["radius"]
			_disc(centre, radius, fill)
			if shape.has("full_radius") and float(shape["full_radius"]) > radius + 0.05:
				_circle(centre, shape["full_radius"], EXTENT, edge, true, 1.0)
			_circle(centre, radius, EDGE, edge, dashed, 1.0)
			var sweep: float = shape.get("fill", 0.0)
			if sweep > 0.0 and not shape.get("blocked", false):
				_circle(centre, radius * 0.92, EDGE, Color(edge, 0.85), false, sweep)
			_ring_ticks(centre, radius, ticks, edge)
			if look["cross"]:
				_cross(centre)
		"line":
			var from: Vector3 = shape["from"]
			var to: Vector3 = shape["to"]
			var width: float = shape["width"]
			if shape.has("full_to"):
				_lane_outline(from, shape["full_to"], width, EXTENT, edge, true)
			_lane_fill(from, to, width, fill)
			_lane_outline(from, to, width, EDGE, edge, dashed)
			_lane_ticks(from, to, width, ticks, edge)
			if look["cross"]:
				_cross(to)
		"arc":
			var points: Array = shape["points"]
			for i in range(1, points.size()):
				if i % 2 == 1:
					_ribbon(points[i - 1], points[i], EDGE, edge, true)
			if look["cross"] and not points.is_empty():
				_cross(points[-1])
		"cone":
			var apex: Vector3 = shape["apex"]
			var dir: Vector3 = (shape["dir"] as Vector3).normalized()
			var length: float = shape["length"]
			var side := _cone_side(dir)
			var spread := tan(float(shape["half_angle"]))
			var left := apex + (dir + side * spread).normalized() * length
			var right := apex + (dir - side * spread).normalized() * length
			var body := cone_fill(shape, fill)
			var near := [apex.lerp(left, body["from"]), apex.lerp(right, body["from"])]
			var far := [apex.lerp(left, body["reach"]), apex.lerp(right, body["reach"])]
			if is_aim(shape):
				var foot := apex + dir * length * float(body["from"])
				var tip := apex + dir * length * float(body["reach"])
				near = [foot + side * AIM_ROOT.x, foot - side * AIM_ROOT.x]
				far = [tip + side * AIM_ROOT.y, tip - side * AIM_ROOT.y]
			for corner in [[near[0], fill], [far[0], body["far"]], [far[1], body["far"]], [near[0], fill], [far[1], body["far"]], [near[1], fill]]:
				_tris.surface_set_color(corner[1])
				_tris.surface_add_vertex(_p(corner[0]))
			for tip in cone_tips(shape):
				_dashed(apex.lerp(tip, body["from"]), tip, EDGE, edge)
		"marks":
			for point in shape["points"]:
				_anchor = point
				_circle(point, 0.6, EDGE, edge, false, 1.0)


func _triangle(a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	for v in [a, b, c]:
		_tris.surface_set_color(color)
		_tris.surface_add_vertex(_p(v))


func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	_triangle(a, b, c, color)
	_triangle(a, c, d, color)


func _disc(centre: Vector3, radius: float, color: Color) -> void:
	if color.a <= 0.0:
		return
	for i in SEGMENTS:
		var a := TAU * float(i) / float(SEGMENTS)
		var b := TAU * float(i + 1) / float(SEGMENTS)
		_triangle(centre, centre + _around(a) * radius, centre + _around(b) * radius, color)


static func _around(angle: float) -> Vector3:
	return Vector3(sin(angle), 0.0, -cos(angle))


func _ribbon(a: Vector3, b: Vector3, width: float, color: Color, keyline := true) -> void:
	var along := b - a
	var flat := Vector3(along.x, 0.0, along.z)
	var side := flat.cross(Vector3.UP).normalized() if flat.length_squared() > 0.0001 else Vector3.RIGHT
	if keyline:
		_strip(a, b, side, width * 0.5 + KEYLINE, Palette.CHARCOAL)
	_strip(a, b, side, width * 0.5, color)
	_cap(a, width * 0.5, color)
	_cap(b, width * 0.5, color)


func _strip(a: Vector3, b: Vector3, side: Vector3, half: float, color: Color) -> void:
	_quad(a + side * half, b + side * half, b - side * half, a - side * half, color)


func _cap(at: Vector3, radius: float, color: Color) -> void:
	for i in 8:
		var a := TAU * float(i) / 8.0
		var b := TAU * float(i + 1) / 8.0
		_triangle(at, at + _around(a) * radius, at + _around(b) * radius, color)


func _dashed(a: Vector3, b: Vector3, width: float, color: Color) -> void:
	var length := a.distance_to(b)
	var t := 0.0
	while t < length:
		var end := minf(length, t + DASH)
		_ribbon(a.lerp(b, t / length), a.lerp(b, end / length), width, color)
		t = end + GAP


func _circle(centre: Vector3, radius: float, width: float, color: Color, dashed: bool, sweep: float) -> void:
	var count := maxi(2, int(SEGMENTS * clampf(sweep, 0.0, 1.0)))
	var step := TAU * clampf(sweep, 0.0, 1.0) / float(count)
	for i in count:
		if dashed and i % 2 == 1:
			continue
		var a := centre + _around(step * float(i)) * radius
		var b := centre + _around(step * float(i + 1)) * radius
		_ribbon(a, b, width, color)


func _lane_fill(from: Vector3, to: Vector3, width: float, color: Color) -> void:
	var side := _lane_side(from, to) * width * 0.5
	_quad(from + side, to + side, to - side, from - side, color)


func _lane_outline(from: Vector3, to: Vector3, width: float, stroke: float, color: Color, dashed: bool) -> void:
	var side := _lane_side(from, to) * width * 0.5
	for pair in [[from + side, to + side], [to - side, from - side], [from - side, from + side], [to + side, to - side]]:
		if dashed:
			_dashed(pair[0], pair[1], stroke, color)
		else:
			_ribbon(pair[0], pair[1], stroke, color)


static func _lane_side(from: Vector3, to: Vector3) -> Vector3:
	var along := to - from
	along.y = 0.0
	return along.cross(Vector3.UP).normalized() if along.length_squared() > 0.0001 else Vector3.RIGHT


func _ring_ticks(centre: Vector3, radius: float, ticks: String, color: Color) -> void:
	if ticks == "":
		return
	var count := int(360.0 / TICK_STEP_DEG)
	for i in count:
		var out := _around(deg_to_rad(TICK_STEP_DEG * float(i)))
		_tick(centre + out * radius, out, ticks, color)


func _lane_ticks(from: Vector3, to: Vector3, width: float, ticks: String, color: Color) -> void:
	if ticks == "":
		return
	var side := _lane_side(from, to)
	var length := from.distance_to(to)
	var d := 1.0
	while d < length:
		var at := from.lerp(to, d / length)
		_tick(at + side * width * 0.5, side, ticks, color)
		_tick(at - side * width * 0.5, -side, ticks, color)
		d += 2.0


func _tick(at: Vector3, out: Vector3, ticks: String, color: Color) -> void:
	match ticks:
		"ring":
			_cap(at + out * TICK_LEN * 0.5, 0.14, color)
		"square":
			var mid := at + out * TICK_LEN * 0.5
			var half := out * TICK_LEN * 0.3
			var side := out.cross(Vector3.UP).normalized() * TICK_LEN * 0.3
			_ribbon(mid - half - side, mid - half + side, EXTENT, color, false)
			_ribbon(mid - half + side, mid + half + side, EXTENT, color, false)
			_ribbon(mid + half + side, mid + half - side, EXTENT, color, false)
			_ribbon(mid + half - side, mid - half - side, EXTENT, color, false)
		"chevron":
			var across := out.cross(Vector3.UP).normalized() * TICK_LEN * 0.5
			var tip := at + out * TICK_LEN
			_ribbon(at + across, tip, EXTENT, color, false)
			_ribbon(at - across, tip, EXTENT, color, false)
		"lane":
			var rail := out.cross(Vector3.UP).normalized() * TICK_LEN * 0.2
			_ribbon(at + rail, at + rail + out * TICK_LEN, EXTENT, color, false)
			_ribbon(at - rail, at - rail + out * TICK_LEN, EXTENT, color, false)
		"burst":
			_ribbon(at, at + out * TICK_LEN, EXTENT, color, false)
		"cross":
			var mid := at + out * TICK_LEN * 0.5
			var rake := out * TICK_LEN * 0.35
			var slant := out.cross(Vector3.UP).normalized() * TICK_LEN * 0.35
			_ribbon(mid - rake - slant, mid + rake + slant, EXTENT, color, false)
			_ribbon(mid - rake + slant, mid + rake - slant, EXTENT, color, false)


func _cross(at: Vector3) -> void:
	var a := Vector3(0.6, 0.0, 0.6)
	var b := Vector3(0.6, 0.0, -0.6)
	_ribbon(at - a, at + a, EDGE * 1.5, Palette.CHARCOAL, false)
	_ribbon(at - b, at + b, EDGE * 1.5, Palette.CHARCOAL, false)
