extends Control

const Palette := preload("res://src/core/palette.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")
const LaunchCard := preload("res://src/ui/launch_card.gd")


const BONE := LaunchCard.BONE
const MAX_TUBES := 4
const MIN_TIMED := 3.0
const DIGIT_WINDOW := 9.0
const HOUSING := Vector2(48.0, 76.0)
const PITCH := 54.0
const HEIGHT := 84.0
const FLOOR := 12.0
const GLASS := Rect2(8.0, 6.0, 32.0, 56.0)
const BEZEL := 6.0
const DIGIT_HEIGHT := 30.0
const DIGIT_WIDTH := 16.0
const DIGIT_TOP := 12.0
const FILAMENT_SHARE := 0.22
const CATHODE_MIN_GLASS := 45.0
const DIAL_RADIUS := 11.0
const DIAL_PIVOT := Vector2(24.0, 73.0)
const RAIL_BAR := Rect2(0.0, 70.0, 0.0, 14.0)
const SLIDE_IN := 0.15
const RISE := 0.12
const RISE_PX := 24.0
const STRIKE := 0.4
const FADE_DIGIT := 0.15
const COOL := 0.25
const SINK := 0.18
const CLOSE := 0.2
const SLIDE_OUT := 0.2
const QUIVER_DEG := 1.5
const QUIVER_HZ := 7.0
const SET_PIECE_ALPHA := 0.4
const LAST_STEPS := [1.0, 0.8, 0.6]

const NIXIE_STROKES := [
	[[Vector2(1.0, 0.5), Vector2(0.97, 0.69), Vector2(0.89, 0.85), Vector2(0.75, 0.96), Vector2(0.5, 1.0), Vector2(0.25, 0.96),
		Vector2(0.11, 0.85), Vector2(0.03, 0.69), Vector2(0.0, 0.5), Vector2(0.03, 0.31), Vector2(0.11, 0.15), Vector2(0.25, 0.04),
		Vector2(0.5, 0.0), Vector2(0.75, 0.04), Vector2(0.89, 0.15), Vector2(0.97, 0.31), Vector2(1.0, 0.5)]],
	[[Vector2(0.22, 0.2), Vector2(0.55, 0.0), Vector2(0.55, 1.0)]],
	[[Vector2(0.04, 0.24), Vector2(0.16, 0.07), Vector2(0.38, 0.0), Vector2(0.62, 0.0), Vector2(0.84, 0.07), Vector2(0.96, 0.24),
		Vector2(0.92, 0.42), Vector2(0.0, 1.0), Vector2(1.0, 1.0)]],
	[[Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(0.45, 0.4), Vector2(0.7, 0.42), Vector2(0.9, 0.52), Vector2(1.0, 0.7),
		Vector2(0.92, 0.88), Vector2(0.72, 0.99), Vector2(0.42, 1.0), Vector2(0.18, 0.95), Vector2(0.0, 0.82)]],
	[[Vector2(0.72, 1.0), Vector2(0.72, 0.0), Vector2(0.0, 0.7), Vector2(1.0, 0.7)]],
	[[Vector2(0.95, 0.0), Vector2(0.12, 0.0), Vector2(0.05, 0.44), Vector2(0.3, 0.38), Vector2(0.6, 0.38), Vector2(0.85, 0.46),
		Vector2(1.0, 0.64), Vector2(0.95, 0.85), Vector2(0.76, 0.98), Vector2(0.45, 1.0), Vector2(0.18, 0.95), Vector2(0.0, 0.82)]],
	[[Vector2(0.85, 0.04), Vector2(0.6, 0.0), Vector2(0.35, 0.05), Vector2(0.14, 0.22), Vector2(0.02, 0.48), Vector2(0.0, 0.7),
		Vector2(0.08, 0.9), Vector2(0.3, 1.0), Vector2(0.62, 1.0), Vector2(0.88, 0.9), Vector2(0.98, 0.72), Vector2(0.9, 0.52),
		Vector2(0.68, 0.42), Vector2(0.38, 0.42), Vector2(0.14, 0.52), Vector2(0.02, 0.66)]],
	[[Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(0.35, 1.0)]],
	[[Vector2(0.9, 0.24), Vector2(0.78, 0.41), Vector2(0.5, 0.48), Vector2(0.22, 0.41), Vector2(0.1, 0.24), Vector2(0.22, 0.07),
		Vector2(0.5, 0.0), Vector2(0.78, 0.07), Vector2(0.9, 0.24)],
	[Vector2(1.0, 0.74), Vector2(0.85, 0.92), Vector2(0.5, 1.0), Vector2(0.15, 0.92), Vector2(0.0, 0.74), Vector2(0.15, 0.56),
		Vector2(0.5, 0.48), Vector2(0.85, 0.56), Vector2(1.0, 0.74)]],
	[[Vector2(0.15, 0.96), Vector2(0.4, 1.0), Vector2(0.65, 0.95), Vector2(0.86, 0.78), Vector2(0.98, 0.52), Vector2(1.0, 0.3),
		Vector2(0.92, 0.1), Vector2(0.7, 0.0), Vector2(0.38, 0.0), Vector2(0.12, 0.1), Vector2(0.02, 0.28), Vector2(0.1, 0.48),
		Vector2(0.32, 0.58), Vector2(0.62, 0.58), Vector2(0.86, 0.48), Vector2(0.98, 0.34)]],
]

const FILAMENTS := {
	"frost": {"ink": Palette.ICE, "strokes": [
		[Vector2(0.5, 1.0), Vector2(0.5, 0.55)],
		[Vector2(0.5, 0.55), Vector2(0.28, 0.3)],
		[Vector2(0.5, 0.55), Vector2(0.72, 0.3)],
		[Vector2(0.28, 0.3), Vector2(0.14, 0.0)],
		[Vector2(0.28, 0.3), Vector2(0.38, 0.0)],
		[Vector2(0.72, 0.3), Vector2(0.62, 0.0)],
		[Vector2(0.72, 0.3), Vector2(0.86, 0.0)]]},
	"heat": {"ink": Palette.AMBER, "cool": Palette.COPPER, "strokes": [
		[Vector2(0.1, 0.5), Vector2(0.16, 0.16), Vector2(0.24, 0.02), Vector2(0.3, 0.16), Vector2(0.26, 0.5), Vector2(0.22, 0.84),
			Vector2(0.3, 0.98), Vector2(0.38, 0.84), Vector2(0.4, 0.5), Vector2(0.42, 0.16), Vector2(0.5, 0.02), Vector2(0.58, 0.16),
			Vector2(0.6, 0.5), Vector2(0.62, 0.84), Vector2(0.7, 0.98), Vector2(0.78, 0.84), Vector2(0.74, 0.5), Vector2(0.7, 0.16),
			Vector2(0.76, 0.02), Vector2(0.84, 0.16), Vector2(0.9, 0.5)]]},
	"overdrive": {"ink": Palette.COPPER, "strokes": [
		[Vector2(0.2, 0.55), Vector2(0.5, 0.05), Vector2(0.8, 0.55)],
		[Vector2(0.2, 1.0), Vector2(0.5, 0.5), Vector2(0.8, 1.0)]]},
	"chain": {"ink": Palette.STEEL, "core": BONE, "strokes": [
		[Vector2(0.08, 0.1), Vector2(0.4, 0.1), Vector2(0.28, 0.55), Vector2(0.68, 0.45), Vector2(0.56, 0.9), Vector2(0.92, 0.9)]]},
	"guard": {"ink": BONE, "strokes": [
		[Vector2(0.5, 0.0), Vector2(0.72, 0.1), Vector2(0.8, 0.45), Vector2(0.72, 0.8), Vector2(0.5, 1.0), Vector2(0.28, 0.8),
			Vector2(0.2, 0.45), Vector2(0.28, 0.1), Vector2(0.5, 0.0)]]},
	"utility": {"ink": Palette.STEEL, "strokes": [
		[Vector2(0.2, 0.5), Vector2(0.8, 0.5)],
		[Vector2(0.5, 0.0), Vector2(0.5, 1.0)]]},
	"plain": {"ink": Palette.STEEL, "strokes": [[Vector2(0.15, 0.5), Vector2(0.85, 0.5)]]},
}
const KEYWORDS := [
	["frost", ["frost", "ice", "slow", "chill"]],
	["heat", ["heat", "fire", "burn"]],
	["overdrive", ["overdrive", "damage", "crit", "blast"]],
	["chain", ["chain", "arc", "charge", "shock", "spark"]],
	["guard", ["guard", "defense", "defence", "brace", "armor", "armour", "shield"]],
	["utility", ["utility", "drone"]],
]

const BODY := Palette.CHARCOAL
const EDGE := Palette.STEEL
const TRIM := Palette.COPPER
const BOLT := BONE
const NEEDLE := BONE
const GLOW := Palette.AMBER
const GLASS_WARM := Color("2a2420")

var _tubes: Array[Dictionary] = []
var _anchor := Vector2.ZERO
var _in_age := -1.0
var _out_age := -1.0
var _clock := 0.0
var _drawn := []
var set_piece := false:
	set(value):
		if value != set_piece:
			set_piece = value
			self_modulate.a = SET_PIECE_ALPHA if value else 1.0
			_refresh()
var screen_scale := -1.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	visible = false
	set_process(false)


func place(outer_bottom_right: Vector2) -> void:
	_anchor = outer_bottom_right
	_fit()


func set_rows(rows: Array) -> void:
	var live := {}
	var order: Array[String] = []
	for source in rows:
		if not (source is Dictionary) or not wants_tube(source):
			continue
		var row := read_row(source)
		var id: String = row["id"]
		if id == "" or live.has(id) or live.size() >= MAX_TUBES:
			continue
		live[id] = row
		order.append(id)
	for tube in _tubes:
		var id: String = tube["id"]
		if not live.has(id):
			if tube["end_age"] < 0.0:
				tube["end_age"] = 0.0
			continue
		var row: Dictionary = live[id]
		var left: float = row["left"]
		var count: int = row["count"]
		if tube["end_age"] >= 0.0:
			tube["age"] = 0.0
			tube["strike"] = 0.0
		elif left > float(tube["left"]) + 0.25 or count > int(tube["count"]):
			tube["strike"] = 0.0
		tube["end_age"] = -1.0
		_take(tube, row)
		live.erase(id)
	for id in order:
		if not live.has(id):
			continue
		if not _make_room():
			break
		var tube: Dictionary = {"id": id, "age": 0.0, "strike": 0.0, "end_age": -1.0, "r": -1.0}
		_take(tube, live[id])
		_tubes.append(tube)
	if not _tubes.is_empty() and not visible:
		_in_age = 0.0
		visible = true
	if not _tubes.is_empty():
		_out_age = -1.0
		set_process(true)
	elif visible and _out_age < 0.0:
		_out_age = 0.0
	_ease_sockets(0.0)
	_refresh()


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	if not visible:
		set_process(false)
		return
	_clock += delta
	if _in_age >= 0.0:
		_in_age += delta
		if _in_age >= SLIDE_IN or _still():
			_in_age = -1.0
	var kept: Array[Dictionary] = []
	for tube in _tubes:
		tube["age"] += delta
		if tube["strike"] >= 0.0:
			tube["strike"] += delta
			if tube["strike"] >= STRIKE:
				tube["strike"] = -1.0
		if tube["end_age"] >= 0.0:
			tube["end_age"] += delta
			if tube["end_age"] >= _retract_time():
				continue
		kept.append(tube)
	_tubes = kept
	if _tubes.is_empty():
		if _out_age < 0.0:
			_out_age = 0.0
		else:
			_out_age += delta
		if _still() or _out_age >= SLIDE_OUT:
			_hide()
			return
	_ease_sockets(delta)
	_refresh()


func clear() -> void:
	if visible or not _tubes.is_empty():
		_hide()


func showing() -> bool:
	return visible


func piece_rect() -> Rect2:
	return Rect2(position, size) if visible else Rect2()


func full_rect() -> Rect2:
	var full := Vector2(PITCH * MAX_TUBES, HEIGHT)
	return Rect2(_anchor - full, full)


func housing_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for tube in _tubes:
		out.push_front(Rect2(position + Vector2(_housing_x(tube), 0.0), HOUSING))
	return out


func shown_digits() -> Array[int]:
	var out: Array[int] = []
	for tube in _tubes:
		out.push_front(digit_of(tube["left"], tube["total"], tube["count"]))
	return out


func shown_filaments() -> Array[String]:
	var out: Array[String] = []
	for tube in _tubes:
		out.push_front(tube["filament"])
	return out


func shown_needles() -> Array[float]:
	var out: Array[float] = []
	for tube in _tubes:
		out.push_front(_needle_at(tube))
	return out


static func wants_tube(row: Dictionary) -> bool:
	var seen := read_row(row)
	return seen["count"] >= 0 or seen["total"] >= MIN_TIMED


static func read_row(row: Dictionary) -> Dictionary:
	var count := int(row.get("count", -1))
	if count < 0:
		var digit: bool = bool(row["show_digit"]) if row.has("show_digit") \
			else str(row.get("kind", "")) == "count" or int(row.get("stacks", 0)) > 1
		if digit:
			count = int(row.get("stacks", 0))
	return {"id": str(row.get("id", "")), "filament": filament_of(row), "count": count,
		"left": float(row.get("left_s", row.get("seconds_left", 0.0))),
		"total": float(row.get("duration_s", row.get("seconds_total", 0.0)))}


static func filament_of(row: Dictionary) -> String:
	var named := str(row.get("filament", "")).to_lower()
	if FILAMENTS.has(named):
		return named
	for text in [named, str(row.get("icon", "")).to_lower(), str(row.get("id", "")).to_lower()]:
		for entry in KEYWORDS:
			for word in entry[1]:
				if text.contains(word):
					return entry[0]
	return "plain"


static func digit_of(left: float, total: float, count: int) -> int:
	if count >= 0:
		return mini(count, 9)
	if total >= MIN_TIMED and left > 0.0 and left <= DIGIT_WINDOW:
		return clampi(ceili(left), 1, 9)
	return -1


static func brightness_of(left: float, count: int) -> float:
	if count >= 0 or left > 3.0:
		return 1.0
	return LAST_STEPS[clampi(3 - ceili(left), 0, 2)]


static func fill_of(left: float, total: float) -> float:
	if total < MIN_TIMED:
		return -1.0
	return clampf(left / total, 0.0, 1.0)


static func needle_deg(fill: float) -> float:
	return 180.0 * (1.0 - clampf(fill, 0.0, 1.0))


static func topology(shape: String) -> Array:
	var strokes: Array = FILAMENTS[shape]["strokes"]
	var ends := {}
	var loops := 0
	var corners := 0
	var turns := 0
	for stroke in strokes:
		var points: Array = stroke
		if (points[0] as Vector2).is_equal_approx(points[-1]):
			loops += 1
		for p in [points[0], points[-1]]:
			var key := "%.2f,%.2f" % [p.x, p.y]
			ends[key] = int(ends.get(key, 0)) + 1
		var winding := 0.0
		for i in range(1, points.size() - 1):
			var bend: float = (points[i] - points[i - 1]).angle_to(points[i + 1] - points[i])
			winding += bend
			if absf(bend) > deg_to_rad(100.0):
				corners += 1
		turns += int(absf(winding) / TAU)
	var branches := 0
	for key in ends:
		if ends[key] >= 3:
			branches += 1
	return [strokes.size(), branches, loops, corners, turns]


static func inks() -> Array[Color]:
	var out: Array[Color] = [BODY, EDGE, TRIM, BOLT, NEEDLE, GLOW, GLASS_WARM, core_ink()]
	for shape in FILAMENTS:
		for key in ["ink", "cool", "core"]:
			if FILAMENTS[shape].has(key):
				out.append(FILAMENTS[shape][key])
	return out


static func core_ink() -> Color:
	return GLOW.lerp(Palette.LEDGER_CREAM, 0.5)


static func digit_px(window_height: float) -> float:
	return DIGIT_HEIGHT * window_height / 900.0


static func cathodes_shown(scale: float) -> bool:
	return GLASS.size.y * scale >= CATHODE_MIN_GLASS


func _take(tube: Dictionary, row: Dictionary) -> void:
	for key in ["filament", "left", "total", "count"]:
		tube[key] = row[key]


func _make_room() -> bool:
	if _tubes.size() < MAX_TUBES:
		return true
	for i in _tubes.size():
		if _tubes[i]["end_age"] >= 0.0:
			_tubes.remove_at(i)
			return true
	return false


func _still() -> bool:
	return UiTokens.reduced_motion


func _retract_time() -> float:
	return FADE_DIGIT + COOL if _still() else FADE_DIGIT + COOL + SINK


func _ease_sockets(delta: float) -> void:
	for i in _tubes.size():
		var tube: Dictionary = _tubes[i]
		var want: float = PITCH * i
		if tube["r"] < 0.0 or _still():
			tube["r"] = want
		else:
			tube["r"] = move_toward(tube["r"], want, PITCH * delta / CLOSE)
	_fit()


func _fit() -> void:
	var reach := PITCH
	for tube in _tubes:
		reach = maxf(reach, tube["r"] + PITCH)
	size = Vector2(minf(reach, PITCH * MAX_TUBES), HEIGHT)
	position = _anchor - size


func _housing_x(tube: Dictionary) -> float:
	return size.x - tube["r"] - PITCH + (PITCH - HOUSING.x) * 0.5


func _hide() -> void:
	_tubes.clear()
	_in_age = -1.0
	_out_age = -1.0
	visible = false
	set_process(false)
	_drawn = []
	_fit()


func _screen_scale() -> float:
	if screen_scale > 0.0:
		return screen_scale
	return get_viewport().get_final_transform().get_scale().y if is_inside_tree() else 1.0


func _refresh() -> void:
	var sig := [_slide_x(), self_modulate.a, size.x]
	for tube in _tubes:
		var fill := fill_of(tube["left"], tube["total"])
		sig.append([tube["id"], roundi(tube["r"]), roundi(_rise(tube)), digit_of(tube["left"], tube["total"], tube["count"]),
			roundi(fill * GLASS.size.y), roundi(_needle_at(tube)), snappedf(_tube_light(tube), 0.05), snappedf(_digit_light(tube), 0.05)])
	if sig != _drawn:
		_drawn = sig
		queue_redraw()


func _slide_x() -> float:
	if _still():
		return 0.0
	if _in_age >= 0.0:
		return roundf(size.x * (1.0 - ease(minf(1.0, _in_age / SLIDE_IN), 0.4)))
	if _out_age >= 0.0:
		return roundf(size.x * minf(1.0, _out_age / SLIDE_OUT))
	return 0.0


func _rise(tube: Dictionary) -> float:
	if _still():
		return 0.0
	if tube["end_age"] >= FADE_DIGIT + COOL:
		return RISE_PX * minf(1.0, (tube["end_age"] - FADE_DIGIT - COOL) / SINK)
	if tube["end_age"] < 0.0 and tube["age"] < RISE:
		return RISE_PX * (1.0 - ease(tube["age"] / RISE, 0.4))
	return 0.0


func _tube_light(tube: Dictionary) -> float:
	if tube["end_age"] >= 0.0:
		return clampf(1.0 - (tube["end_age"] - FADE_DIGIT) / COOL, 0.0, 1.0)
	return 1.0


func _digit_light(tube: Dictionary) -> float:
	if tube["end_age"] >= 0.0:
		return clampf(1.0 - tube["end_age"] / FADE_DIGIT, 0.0, 1.0)
	var flare: float = 0.25 * (1.0 - tube["strike"] / STRIKE) if tube["strike"] >= 0.0 else 0.0
	return brightness_of(tube["left"], tube["count"]) + flare


func _needle_at(tube: Dictionary) -> float:
	var fill := fill_of(tube["left"], tube["total"])
	if fill < 0.0:
		return -1.0
	var deg := needle_deg(fill)
	if not _still() and tube["end_age"] < 0.0:
		deg = clampf(deg + QUIVER_DEG * sin(_clock * TAU * QUIVER_HZ + float(absi(str(tube["id"]).hash()) % 97)), 0.0, 180.0)
	return deg


func _draw() -> void:
	var slide := _slide_x()
	draw_rect(Rect2(slide, RAIL_BAR.position.y, size.x, RAIL_BAR.size.y), BODY)
	draw_line(Vector2(slide, RAIL_BAR.position.y + 0.5), Vector2(slide + size.x, RAIL_BAR.position.y + 0.5), EDGE, 1.0)
	for bx in [slide + 3.0, slide + size.x - 3.0]:
		draw_circle(Vector2(bx, RAIL_BAR.end.y - 5.0), 1.6, BOLT)
	var cathodes := cathodes_shown(_screen_scale())
	for tube in _tubes:
		_draw_housing(tube, Vector2(slide + _housing_x(tube), _rise(tube)), cathodes)


func _draw_housing(tube: Dictionary, at: Vector2, cathodes: bool) -> void:
	var light := _tube_light(tube)
	var spec: Dictionary = FILAMENTS[tube["filament"]]
	var glass := Rect2(at + GLASS.position, GLASS.size)
	draw_rect(Rect2(at, HOUSING), BODY)
	draw_line(at + Vector2(0.0, 0.5), at + Vector2(HOUSING.x, 0.5), EDGE, 1.0)
	var top := Color(BODY, 0.85)
	var low := Color(GLASS_WARM, 0.7)
	draw_polygon(PackedVector2Array([glass.position, Vector2(glass.end.x, glass.position.y), glass.end, Vector2(glass.position.x, glass.end.y)]),
		PackedColorArray([top, top, low, low]))
	var fill := fill_of(tube["left"], tube["total"])
	var ink: Color = spec["ink"]
	if spec.has("cool") and fill >= 0.0:
		ink = (spec["cool"] as Color).lerp(spec["ink"], fill)
	if fill > 0.0:
		var h := roundf(glass.size.y * fill)
		var wash := Rect2(glass.position.x, glass.end.y - h, glass.size.x, h)
		draw_rect(wash, Color(ink, 0.16 * light))
		draw_line(Vector2(wash.position.x, wash.position.y + 0.75), Vector2(wash.end.x, wash.position.y + 0.75), Color(ink, 0.5 * light), 1.5)
	if cathodes:
		for d in 10:
			_draw_digit(d, at, Color(EDGE, 0.09), 1.0)
	var digit := digit_of(tube["left"], tube["total"], tube["count"])
	var lit := _digit_light(tube)
	if digit >= 0 and lit > 0.0:
		_draw_digit(digit, at, Color(GLOW, minf(1.0, 0.18 * lit)), 6.0)
		_draw_digit(digit, at, Color(GLOW, minf(1.0, 0.45 * lit)), 3.0)
		_draw_digit(digit, at, Color(core_ink(), minf(1.0, lit)), 1.6)
	var band := glass.size.y * FILAMENT_SHARE
	var fil := Rect2(glass.position.x + 4.0, glass.end.y - band - 1.0, glass.size.x - 8.0, band - 1.0)
	var wire := ink.lerp(EDGE.darkened(0.6), 1.0 - light)
	for stroke in spec["strokes"]:
		var pts := PackedVector2Array()
		for p in stroke:
			pts.append(fil.position + Vector2(p.x * fil.size.x, p.y * fil.size.y))
		draw_polyline(pts, Color(wire, 0.3 * maxf(light, 0.3)), 3.0, true)
		draw_polyline(pts, wire, 1.4, true)
		if spec.has("core"):
			draw_polyline(pts, Color(spec["core"], 0.9 * light), 0.7, true)
	draw_rect(Rect2(glass.position + Vector2(2.0, 2.0), Vector2(glass.size.x * 0.22 - 3.0, glass.size.y * 0.7)), Color(BONE, 0.07))
	draw_rect(Rect2(at, Vector2(HOUSING.x, BEZEL)), BODY)
	draw_line(at + Vector2(0.0, BEZEL - 0.5), at + Vector2(HOUSING.x, BEZEL - 0.5), TRIM, 1.0)
	draw_rect(Rect2(at + Vector2(0.0, BEZEL), Vector2(GLASS.position.x - 1.0, GLASS.size.y)), BODY)
	draw_rect(Rect2(at + Vector2(GLASS.end.x + 1.0, BEZEL), Vector2(HOUSING.x - GLASS.end.x - 1.0, GLASS.size.y)), BODY)
	for sx in [3.5, HOUSING.x - 3.5]:
		var screw := at + Vector2(sx, GLASS.position.y + GLASS.size.y * 0.5)
		draw_circle(screw, 2.0, BOLT)
		draw_line(screw - Vector2(1.4, 0.0), screw + Vector2(1.4, 0.0), BODY, 0.8)
	var needle := _needle_at(tube)
	if needle >= 0.0:
		var pivot := at + DIAL_PIVOT
		draw_arc(pivot, DIAL_RADIUS, PI, TAU, 12, Color(EDGE, 0.45), 1.0, true)
		var tip := pivot + Vector2(cos(deg_to_rad(-needle)), sin(deg_to_rad(-needle))) * DIAL_RADIUS
		draw_line(pivot, tip, Color(NEEDLE, maxf(0.35, light)), 1.5, true)
		draw_circle(pivot, 2.0, TRIM)


func _draw_digit(digit: int, at: Vector2, color: Color, width: float) -> void:
	var box := Rect2(at + Vector2((HOUSING.x - DIGIT_WIDTH) * 0.5, DIGIT_TOP), Vector2(DIGIT_WIDTH, DIGIT_HEIGHT))
	for stroke in NIXIE_STROKES[digit]:
		var pts := PackedVector2Array()
		for p in stroke:
			pts.append(box.position + Vector2(p.x * box.size.x, p.y * box.size.y))
		draw_polyline(pts, color, width, true)
