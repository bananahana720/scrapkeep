extends Control

const Palette := preload("res://src/core/palette.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const EventJuice := preload("res://src/presentation/event_juice.gd")


const TYPES := ["kinetic", "frost", "arc"]
const HEAT_COLOUR := Color("ff7a29")
const ALL_TYPES := ["kinetic", "frost", "arc", "heat"]
const TEAMS := ["player", "monster", "neutral"]

const PLAYER_COLOURS := {"kinetic": Palette.COPPER, "frost": Palette.ANCIENT, "arc": Palette.ARC, "heat": HEAT_COLOUR}

const KIND_TYPES := {"arc": "arc", "frost": "frost", "heat": "heat", "burn": "heat", "thermal": "heat", "torch": "heat", "cinder": "heat"}

const GROUP := "damage_numbers"
const MERGE_WINDOW_S := 0.25
const LIFE_S := 0.9
const MAX_VISIBLE := 4
const FONT := 22
const CRIT_FONT := 30
const BIG_FROM := 40.0
const BIG_STEP := 6.0
const MEGA_FONT := 60
const RISE := 46.0
const OUTLINE_MIN := 6
const FADE_FROM := 0.6
const POP_WINDOW_S := 0.14
const POP_PEAK_T := 0.36
const POP_START_SCALE := 0.82
const CRIT_POP_PEAK := 1.38
const BIG_CRIT_POP_PEAK := 1.44
const BIG_POP_PEAK := 1.24
const CRIT_OUTLINE_EXTRA := 4
const CRIT_RIM_COLOUR := Palette.LEDGER_CREAM

var project: Callable
var keep_off: Callable
var reduced_motion := false

var _numbers: Array = []


static func all_types() -> Array:
	return ALL_TYPES.duplicate()


static func type_of_kind(kind: String) -> String:
	return KIND_TYPES.get(kind, "kinetic")


static func team_colours() -> Dictionary:
	var colour: Color = EventJuice.juice("player_hit")["color"]
	return {"monster": colour, "neutral": colour}


static func effect_colour(type: String, team: String, crit := false) -> Color:
	if team == "player":
		if crit:
			return EventJuice.juice("enemy_struck")["crit"]["color"]
		return PLAYER_COLOURS.get(type, Palette.COPPER)
	return team_colours().get(team, EventJuice.juice("player_hit")["color"])


static func team_of_source(source: String) -> String:
	return "neutral" if source == "" else "monster"


static func is_crit(result: Dictionary, body_plating: float) -> bool:
	var dealt := float(result.get("base_dealt", result.get("dealt", 0.0)))
	var weak := String(result.get("part", "")) != "" and float(result.get("plating", 0.0)) < body_plating
	return weak or dealt > float(result.get("punch", dealt)) * 1.01


static func outline_px(size: int) -> int:
	return maxi(OUTLINE_MIN, roundi(size * 0.3))


static func crit_outline_style(size: int, crit: bool) -> Dictionary:
	var base := outline_px(size)
	if not crit:
		return {"ink_px": base, "rim_px": 0, "rim_color": Color.TRANSPARENT}
	return {"ink_px": base + CRIT_OUTLINE_EXTRA, "rim_px": maxi(2, roundi(base * 0.5)), "rim_color": CRIT_RIM_COLOUR}


static func pop_scale(age: float, value: float, crit := false, still := false) -> float:
	if still or age < 0.0 or age >= POP_WINDOW_S:
		return 1.0
	var peak := 1.0
	if crit:
		peak = BIG_CRIT_POP_PEAK if value >= BIG_FROM else CRIT_POP_PEAK
	elif value >= BIG_FROM:
		peak = BIG_POP_PEAK
	if peak <= 1.0:
		return 1.0
	var u := clampf(age / POP_WINDOW_S, 0.0, 1.0)
	if u <= POP_PEAK_T:
		return lerpf(POP_START_SCALE, peak, ease(u / POP_PEAK_T, 0.35))
	var settle := (u - POP_PEAK_T) / (1.0 - POP_PEAK_T)
	var dip := -0.04 * (peak - 1.0) * sin(settle * PI) * (1.0 - settle)
	return maxf(1.0, lerpf(peak, 1.0, ease(settle, 0.5)) + dip)


static func font_size(value: float, crit := false) -> int:
	var size := float(CRIT_FONT if crit else FONT)
	if value > BIG_FROM:
		size += BIG_STEP * log(value / BIG_FROM) / log(2.0)
	return mini(MEGA_FONT, roundi(size))


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group(GROUP)


func add(key: String, value: float, at, type: String, team: String, crit := false) -> void:
	for number in _numbers:
		if number["key"] == key and number["type"] == type and number["team"] == team and number["since"] <= MERGE_WINDOW_S:
			number["value"] += value
			number["age"] = 0.0
			number["since"] = 0.0
			number["at"] = at
			number["crit"] = number["crit"] or crit
			number["color"] = effect_colour(type, team, number["crit"])
			return
	var fresh := {"key": key, "value": value, "at": at, "type": type, "team": team, "crit": crit,
		"color": effect_colour(type, team, crit), "age": 0.0, "since": 0.0, "shift": Vector2.ZERO}
	_numbers.append(fresh)
	var dealt := team == "player"
	while _numbers.filter(func(n): return (n["team"] == "player") == dealt).size() > MAX_VISIBLE:
		var least := -1
		for i in _numbers.size():
			var n: Dictionary = _numbers[i]
			if is_same(n, fresh) or (n["team"] == "player") != dealt:
				continue
			if least < 0 or n["value"] < _numbers[least]["value"] \
					or (n["value"] == _numbers[least]["value"] and n["age"] > _numbers[least]["age"]):
				least = i
		_numbers.remove_at(least)
	_make_room(fresh)


func _make_room(fresh: Dictionary) -> void:
	if _screen(fresh) == null:
		return
	var off: Dictionary = keep_off.call() if keep_off.is_valid() else {}
	var ring: Array = off.get("ring", [])
	var tags: Array = off.get("tags", [])
	var pushes := 0
	var lines := 0
	for pass_no in MAX_PUSHES + MAX_LINES:
		var start := start_rect(fresh)
		var rise := Rect2(start.position - Vector2(0.0, RISE), start.size + Vector2(0.0, RISE))
		var moved := false
		if pushes < MAX_PUSHES:
			for i in ring.size() + tags.size():
				var r: Rect2 = ring[i] if i < ring.size() else tags[i - ring.size()]
				var hit := (start if i < ring.size() else rise).intersects(r)
				if r.has_area() and hit:
					var right := r.end.x - start.position.x
					var left := r.position.x - start.end.x
					fresh["shift"].x += right if i < ring.size() or absf(right) <= absf(left) else left
					pushes += 1
					moved = true
					break
		if not moved and lines < MAX_LINES:
			var on_ring := pushes >= MAX_PUSHES and ring.any(func(r): return r.has_area() and r.intersects(start))
			if on_ring or path_rects(fresh).any(func(r): return r.intersects(start)):
				fresh["shift"].y -= start.size.y
				lines += 1
				moved = true
		if not moved:
			return


const MAX_LINES := 4
const MAX_PUSHES := 3


func start_rect(number: Dictionary) -> Rect2:
	var p = _screen(number)
	if p == null:
		return Rect2()
	var size := font_size(number["value"], number["crit"])
	var pad := float(outline_px(size))
	var wide := _text_width(number, size) + pad * 2.0
	return Rect2(Vector2(p.x - wide * 0.5, p.y - size - pad), Vector2(wide, size + pad * 2.0))


func step(delta: float) -> void:
	for number in _numbers:
		number["age"] += delta
		number["since"] += delta
	_numbers = _numbers.filter(func(n): return n["age"] < LIFE_S)
	queue_redraw()


func path_rects(except: Dictionary = {}) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for number in _numbers:
		if is_same(number, except):
			continue
		var p = _screen(number)
		if p == null:
			continue
		var size := font_size(number["value"], number["crit"])
		var pad := float(outline_px(size))
		var wide := _text_width(number, size) + pad * 2.0
		out.append(Rect2(Vector2(p.x - wide * 0.5, p.y - RISE - size - pad), Vector2(wide, RISE + size + pad * 2.0)))
	return out


func _text_width(number: Dictionary, size: int) -> float:
	return UiFonts.mono().get_string_size(str(maxi(1, roundi(number["value"]))), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


func visible_count() -> int:
	return _numbers.size()


func shown() -> Array:
	var out: Array = []
	for number in _numbers:
		out.append({"key": number["key"], "value": number["value"], "color": number["color"],
			"type": number["type"], "team": number["team"], "crit": number["crit"], "age": number["age"]})
	return out


func clear() -> void:
	_numbers.clear()
	queue_redraw()


func _screen(number: Dictionary) -> Variant:
	var at = number["at"]
	if at is Vector3:
		if not project.is_valid():
			return null
		at = project.call(at)
	return at + number.get("shift", Vector2.ZERO) if at != null else null


func _draw() -> void:
	for number in _numbers:
		var p = _screen(number)
		if p == null:
			continue
		var age: float = number["age"]
		var t: float = age / LIFE_S
		var colour: Color = number["color"]
		colour.a = 1.0 if t < FADE_FROM else 1.0 - (t - FADE_FROM) / (1.0 - FADE_FROM)
		var crit: bool = bool(number["crit"])
		var value: float = float(number["value"])
		var base_size := font_size(value, crit)
		var pop := pop_scale(age, value, crit, reduced_motion)
		var draw_size := clampi(roundi(float(base_size) * pop), 1, roundi(float(MEGA_FONT) * BIG_CRIT_POP_PEAK))
		var text := str(maxi(1, roundi(value)))
		var font := UiFonts.mono()
		var lift := float(draw_size - base_size) * 0.35
		var spot: Vector2 = p + Vector2(-_text_width(number, draw_size) * 0.5, -RISE * t + lift)
		var style := crit_outline_style(draw_size, crit)
		var ink := Palette.CHARCOAL
		ink.a = colour.a
		draw_string_outline(font, spot, text, HORIZONTAL_ALIGNMENT_LEFT, -1, draw_size, int(style["ink_px"]), ink)
		var rim_px := int(style["rim_px"])
		if rim_px > 0:
			var rim: Color = style["rim_color"]
			rim.a = colour.a
			draw_string_outline(font, spot, text, HORIZONTAL_ALIGNMENT_LEFT, -1, draw_size, rim_px, rim)
		draw_string(font, spot, text, HORIZONTAL_ALIGNMENT_LEFT, -1, draw_size, colour)
