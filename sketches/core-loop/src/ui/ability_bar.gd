extends Control

const EventKinds := preload("res://src/core/event_kinds.gd")
const Palette := preload("res://src/core/palette.gd")
const Icons := preload("res://src/ui/icons.gd")
const Keycap := preload("res://src/ui/keycap.gd")

# The bottom-centre ability bar: one slot per published ability slot (ability_slots.gd),
# key glyph under each, charge pips under the key. Each state reads by more than colour:
# ready is a bright solid frame, cooling is a petrol wedge that uncovers the icon
# clockwise from twelve over a dimmed icon, active is a doubled frame and a lifted slot,
# unavailable is a faded icon struck through. A slot whose cooldown ends swells once,
# with a rim flash and its class shape flaring in the class colour. State colours come
# from event_kinds' v2 W1 UI rows; the icon's accent is the class colour
# (VISUAL-LANGUAGE.md section 7).

const SLOT := 56.0
const GAP := 14.0
const KEY_GAP := 5.0
const KEY_H := 20.0
const PIP := 3.0
const PIP_GAP := 4.0
const PULSE_SECONDS := 0.18
const PULSE_SCALE := 0.12
const SWEEP_STEP := TAU / 64.0

var slots: Array = []
var tint := Color.WHITE
# The class row's shape (ring, chevron, burst): the ready swell and the charge pips wear
# it, so the bar speaks in the class's motif.
var motif := "ring"
var _pulses := {}
var _last_state := {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


static func bar_size(count: int) -> Vector2:
	var n := maxi(count, 1)
	return Vector2(n * SLOT + (n - 1) * GAP, SLOT + KEY_GAP + KEY_H + PIP_GAP + PIP * 2.0)


func update_slots(list: Array, class_tint: Color, class_shape := "ring") -> void:
	tint = class_tint
	motif = class_shape if class_shape != "" else "ring"
	var swelled := false
	for entry in list:
		var id: String = entry["id"]
		if entry["state"] == "ready" and _last_state.get(id, "ready") == "cooling":
			_pulses[id] = PULSE_SECONDS
			swelled = true
		_last_state[id] = entry["state"]
	if swelled:
		_ring_ready()
	slots = list
	custom_minimum_size = bar_size(list.size())
	size = custom_minimum_size


# The swell's sound: ability_ready's row resolves to the class's ready pulse, the
# motif's first note, so the bar is where the class tune is first heard. The bar sits
# in the HUD, whose game reaches the audio director.
func _ring_ready() -> void:
	var hud := get_parent()
	var game = hud.get("game") if hud != null else null
	var presentation = game.get("presentation") if game != null else null
	var audio = presentation.get("audio") if presentation != null else null
	if audio != null and audio.has_method("play"):
		audio.play("ability_ready", 0.0, 1.0, "UI")


func pulse_left(id: String) -> float:
	return _pulses.get(id, 0.0)


func _process(delta: float) -> void:
	for id in _pulses.keys():
		_pulses[id] = maxf(0.0, _pulses[id] - delta)
		if _pulses[id] <= 0.0:
			_pulses.erase(id)
	queue_redraw()


func drawn_words() -> PackedStringArray:
	var out := PackedStringArray()
	for entry in slots:
		out.append_array(Keycap.words(entry["key"]))
	return out


func _draw() -> void:
	for i in slots.size():
		_draw_slot(slots[i], Rect2(Vector2(i * (SLOT + GAP), 0.0), Vector2(SLOT, SLOT)))


func _draw_slot(entry: Dictionary, rect: Rect2) -> void:
	var state: String = entry["state"]
	var color: Color = tint if state == "active" else EventKinds.UI_ROWS.get("ability_" + state, {}).get("color", Palette.SAND)
	var key_centre := Vector2(rect.get_center().x, SLOT + KEY_GAP + KEY_H * 0.5)
	var left := pulse_left(entry["id"])
	if left > 0.0:
		rect = rect.grow(SLOT * PULSE_SCALE * 0.5 * sin(PI * (1.0 - left / PULSE_SECONDS)))
	if state == "active":
		rect = rect.grow(2.0)
		rect.position.y -= 3.0
	var back := StyleBoxFlat.new()
	back.bg_color = Color(Palette.CHARCOAL, 0.88) if state != "unavailable" else Color(Palette.VERDIGRIS, 0.5)
	back.set_corner_radius_all(9)
	draw_style_box(back, rect)

	var icon_alpha: float = {"ready": 1.0, "active": 1.0, "cooling": 0.4, "unavailable": 0.28}[state]
	var icon: String = entry["icon"]
	draw_texture_rect(Icons.texture(icon), rect.grow(-rect.size.x * 0.17), false, Icons.tint(icon, Color(tint, icon_alpha)))

	if state == "cooling":
		_draw_sweep(rect, float(entry["cooldown_frac"]))
	if state == "unavailable":
		draw_line(rect.position + Vector2(8.0, rect.size.y - 8.0), rect.end - Vector2(8.0, rect.size.y - 8.0), Color(color, 0.9), 3.0)

	var frame := StyleBoxFlat.new()
	frame.draw_center = false
	frame.border_color = tint if left > 0.0 else color
	frame.set_border_width_all({"ready": 3, "active": 3, "cooling": 1, "unavailable": 1}[state])
	frame.set_corner_radius_all(9)
	draw_style_box(frame, rect)
	if state == "active":
		var outer := StyleBoxFlat.new()
		outer.draw_center = false
		outer.border_color = Color(color, 0.55)
		outer.set_border_width_all(2)
		outer.set_corner_radius_all(12)
		draw_style_box(outer, rect.grow(5.0))

	var key_color := tint if state == "active" else Color(Palette.SAND, 0.5 if state == "unavailable" else 0.95)
	if left > 0.0:
		var t := 1.0 - left / PULSE_SECONDS
		var reach := rect.size.x * (0.7 + 0.5 * t)
		draw_texture_rect(Icons.shape(motif), Rect2(rect.get_center() - Vector2(reach, reach) * 0.5, Vector2(reach, reach)), false, Color(tint, 0.6 * (1.0 - t)))
	Keycap.draw(self, key_centre, entry["key"], key_color, KEY_H)
	var max_charges: int = entry["max_charges"]
	if max_charges > 1:
		var step := PIP * 3.0
		var y := SLOT + KEY_GAP + KEY_H + PIP_GAP + PIP
		for c in max_charges:
			var at := Vector2(key_centre.x + (c - (max_charges - 1) * 0.5) * step, y)
			var pip := Rect2(at - Vector2(PIP, PIP) * 1.3, Vector2(PIP, PIP) * 2.6)
			draw_texture_rect(Icons.shape(motif), pip, false, tint if c < int(entry["charges"]) else Color(tint, 0.25))


# The remaining cooldown as a petrol wedge: it covers the part of the slot still to come
# back, so the icon is uncovered clockwise from twelve, linearly, as the ability returns.
func _draw_sweep(rect: Rect2, frac: float) -> void:
	# A sliver under one degree has no area to triangulate, and a full wedge's first and
	# last edge points coincide, so both ends are handled without building a polygon.
	if frac < 1.0 / 360.0:
		return
	if frac >= 1.0 - 1.0 / 360.0:
		draw_rect(rect, Color(Palette.VERDIGRIS, 0.8))
		return
	var centre := rect.get_center()
	var half := rect.size * 0.5
	var stop := -PI * 0.5 + TAU
	var points := PackedVector2Array([centre])
	var angle := -PI * 0.5 + (1.0 - frac) * TAU
	while angle < stop:
		points.append(_edge(centre, half, angle))
		angle += SWEEP_STEP
	var last := _edge(centre, half, stop)
	if points[points.size() - 1].distance_to(last) > 0.01:
		points.append(last)
	if points.size() >= 3:
		draw_colored_polygon(points, Color(Palette.VERDIGRIS, 0.8))


static func _edge(centre: Vector2, half: Vector2, angle: float) -> Vector2:
	var dir := Vector2(cos(angle), sin(angle))
	var reach := minf(half.x / maxf(absf(dir.x), 0.0001), half.y / maxf(absf(dir.y), 0.0001))
	return centre + dir * reach
