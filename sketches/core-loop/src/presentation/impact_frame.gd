extends Control

const Palette := preload("res://src/core/palette.gd")
const FlashGuard := preload("res://src/core/flash_guard.gd")

const FRAMES := 3
const HEAT_COLOR := Color(1.0, 0.5, 0.12)
const INK := Palette.INK_DEEP

const LINES := 56
const BAND := 0.2
const WEDGE_WIDTH_MIN := 5.0
const WEDGE_WIDTH_MAX := 16.0
const YIELD_MARGIN_PX := WEDGE_WIDTH_MAX
const MAX_RECTS := 64
# Godot FRAGCOORD varies with window origin/scale under canvas_items; varying VERTEX stays in Control px.
const YIELD_SHADER := """
shader_type canvas_item;
uniform vec4 rects[64];
uniform int rect_count = 0;
uniform float margin = 0.0;
varying vec2 local;

void vertex() {
	local = VERTEX;
}

void fragment() {
	for (int i = 0; i < rect_count; i++) {
		vec4 r = rects[i];
		if (local.x > r.x - margin && local.x < r.x + r.z + margin && local.y > r.y - margin && local.y < r.y + r.w + margin) {
			discard;
		}
	}
}
"""
var _focus := Vector2.ZERO
var _strength := 0.0
var _heat := 0.0
var _left := 0
var _seed := 0
var rect_source := Callable()
var _rects: Array[Rect2] = []
var _uniform_rects := PackedVector4Array()
var _material: ShaderMaterial
var drawn := 0
var overflow_hides := 0
var _overflowed := false
var rect_calls := 0
var rect_usec := 0
var rect_usec_max := 0
var shape_calls := 0
var shape_usec := 0
var shape_usec_max := 0
var _drawn_size := Vector2.ZERO

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_ensure_material()

func _ensure_material() -> void:
	if _material != null:
		return
	var shader := Shader.new()
	shader.code = YIELD_SHADER
	_uniform_rects.resize(MAX_RECTS)
	_material = ShaderMaterial.new()
	_material.shader = shader
	_material.set_shader_parameter("margin", YIELD_MARGIN_PX)
	_material.set_shader_parameter("rect_count", 0)
	_material.set_shader_parameter("rects", _uniform_rects)
	material = _material

func fire(focus: Vector2, strength: float, seed_value: int, heat_value := 0.0) -> void:
	_focus = focus
	_strength = strength
	_heat = heat_value
	_left = FRAMES
	_seed = seed_value
	position = Vector2.ZERO
	size = get_viewport_rect().size
	visible = true
	_refresh_rects()
	queue_redraw()

func hide_now() -> void:
	_left = 0
	visible = false

func active() -> bool:
	return _left > 0

func _process(_delta: float) -> void:
	if _left <= 0:
		return
	_left -= 1
	if _left <= 0:
		visible = false
	else:
		_refresh_rects()
		if get_viewport_rect().size != _drawn_size:
			size = get_viewport_rect().size
			queue_redraw()

func _refresh_rects() -> void:
	var began := Time.get_ticks_usec()
	apply_rects(rect_source.call() if rect_source.is_valid() and is_inside_tree() else ([] as Array[Rect2]))
	var cost := Time.get_ticks_usec() - began
	rect_calls += 1
	rect_usec += cost
	rect_usec_max = maxi(rect_usec_max, cost)

func apply_rects(found: Array) -> void:
	_ensure_material()
	var was_overflowed := _overflowed
	_overflowed = found.size() > MAX_RECTS
	if _overflowed:
		overflow_hides += 1
		_rects = []
		_material.set_shader_parameter("rect_count", 0)
		visible = false
		return
	if _left > 0:
		visible = true
		if was_overflowed:
			queue_redraw()
	_rects.assign(found)
	for k in found.size():
		var r: Rect2 = found[k]
		_uniform_rects[k] = Vector4(r.position.x, r.position.y, r.size.x, r.size.y)
	_material.set_shader_parameter("rects", _uniform_rects)
	_material.set_shader_parameter("rect_count", found.size())

static func _yields(point: Vector2, rects: Array, count: int, margin: float) -> bool:
	for k in mini(count, rects.size()):
		var r: Rect2 = rects[k]
		if point.x > r.position.x - margin and point.x < r.end.x + margin and point.y > r.position.y - margin and point.y < r.end.y + margin:
			return true
	return false

func _draw() -> void:
	drawn = 0
	if _overflowed:
		return
	var began := Time.get_ticks_usec()
	_drawn_size = get_viewport_rect().size
	for shape in _shapes(_drawn_size):
		drawn += 1
		if shape.has("colors"):
			draw_polygon(shape["poly"], shape["colors"])
		else:
			draw_colored_polygon(shape["poly"], shape["color"])
	var cost := Time.get_ticks_usec() - began
	shape_calls += 1
	shape_usec += cost
	shape_usec_max = maxi(shape_usec_max, cost)

func _shapes(rect: Vector2) -> Array:
	var out := []
	var band := minf(rect.x, rect.y) * BAND
	var focus := _focus.clamp(Vector2.ZERO, rect)
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	if _heat > 0.0:
		_wash_shapes(out, rect, band)
	for i in int(LINES * _strength):
		var angle := TAU * (float(i) + rng.randf() * 0.8) / float(LINES * _strength)
		var dir := Vector2(cos(angle), sin(angle))
		var exit := INF
		if dir.x > 0.001:
			exit = minf(exit, (rect.x - focus.x) / dir.x)
		elif dir.x < -0.001:
			exit = minf(exit, -focus.x / dir.x)
		if dir.y > 0.001:
			exit = minf(exit, (rect.y - focus.y) / dir.y)
		elif dir.y < -0.001:
			exit = minf(exit, -focus.y / dir.y)
		if exit == INF or exit < 1.0:
			continue
		var inner := maxf(0.0, exit - band * rng.randf_range(0.5, 1.0))
		var width := rng.randf_range(WEDGE_WIDTH_MIN, WEDGE_WIDTH_MAX) * (0.6 + 0.4 * _strength)
		var side := Vector2(-dir.y, dir.x) * width
		var tip := focus + dir * inner
		var outer := focus + dir * (exit + width * 2.0)
		var accent := i % (3 if _heat > 0.0 else 7) == 0
		var ink := INK
		ink.a = 0.75 + 0.2 * _heat
		if accent:
			ink = Color(1, 1, 1, 0.5).lerp(Color(HEAT_COLOR.r, HEAT_COLOR.g, HEAT_COLOR.b, 0.9), _heat)
			ink.a = FlashGuard.alpha(ink.a)
		out.append({"poly": PackedVector2Array([tip, outer + side, outer - side]), "color": ink})
	return out

func _wash_shapes(out: Array, rect: Vector2, band: float) -> void:
	var dark := Color(INK.r, INK.g, INK.b, 0.8 * _heat)
	var hot := Color(HEAT_COLOR.r, HEAT_COLOR.g, HEAT_COLOR.b, FlashGuard.alpha(0.4 * _heat))
	var clear := Color(hot.r, hot.g, hot.b, 0.0)
	_ring_shapes(out, rect, 0.0, band * 0.6, dark, hot)
	_ring_shapes(out, rect, band * 0.6, band, hot, clear)

func _ring_shapes(out: Array, rect: Vector2, outer: float, inner: float, from: Color, to: Color) -> void:
	var o := [Vector2(outer, outer), Vector2(rect.x - outer, outer), rect - Vector2(outer, outer), Vector2(outer, rect.y - outer)]
	var i := [Vector2(inner, inner), Vector2(rect.x - inner, inner), rect - Vector2(inner, inner), Vector2(inner, rect.y - inner)]
	var colors := PackedColorArray([from, from, to, to])
	for k in 4:
		var n := (k + 1) % 4
		out.append({"poly": PackedVector2Array([o[k], o[n], i[n], i[k]]), "colors": colors})
