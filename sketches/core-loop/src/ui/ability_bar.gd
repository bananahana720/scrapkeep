extends Control

const EventKinds := preload("res://src/core/event_kinds.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")
const Palette := preload("res://src/core/palette.gd")
const Icons := preload("res://src/ui/icons.gd")
const Keycap := preload("res://src/ui/keycap.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")


const SLOT := UiTokens.TARGET
const GAP := float(UiTokens.GAP_M)
const KEY_GAP := float(UiTokens.GAP_XS)
const KEY_H := 20.0
const PIP := 3.0
const PIP_GAP := float(UiTokens.GAP_XS)
const PULSE_SECONDS := 0.18
const PULSE_SCALE := 0.12
const SWEEP_STEP := TAU / 64.0
const NUMBERED := 3
const CHIP_SCALE := 0.75
const CHIP_GAP := float(UiTokens.GAP_XL)
const GLYPH_SLIDE := 0.12
const GLYPH_H := 18.0
const GLYPH_GAP := float(UiTokens.GAP_S)
const UNDERLINE := 2.0
const SHAKE := 3.0
const SHAKE_TIME := 0.25
const SHAKE_HZ := 40.0
const BADGE := 18.0
const SET_PIECE_ALPHA := 0.4
const HAND := 2.0
const DASHES := 4
const POINT_W := 22.0
const POINT_H := 14.0
const POINT_GAP := float(UiTokens.GAP_S)
const POINT_BOB := 4.0
const POINT_HZ := 2.0

static var reduced_motion := false
var slots: Array = []
var tint := Color.WHITE
var motif := "ring"
var line_loaded := false:
	set(value):
		if value != line_loaded:
			line_loaded = value
			queue_redraw()
var set_piece := false:
	set(value):
		if value == set_piece:
			return
		set_piece = value
		self_modulate.a = SET_PIECE_ALPHA if value else 1.0
		_plates.visible = value
		_plates.queue_redraw()
var glyph_x := -1.0
var _glyph_from := 0.0
var _glyph_to := -1.0
var _glyph_t := GLYPH_SLIDE
var _refusals := {}
var _pointed := ""
var _clock := 0.0
var _hidden: Array[String] = []
var _pulses := {}
var _last_state := {}
var _shown: Array = []
var _was_pulsing := false
var _refund_pending := {}
var _refund_flashes := {}
var _refund_count := 0
var _plates := Plates.new()
var _sb_back := StyleBoxFlat.new()
var _sb_wash := StyleBoxFlat.new()
var _sb_frame := StyleBoxFlat.new()
var _sb_outer := StyleBoxFlat.new()
var _sb_cap := StyleBoxFlat.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plates.bar = self
	add_child(_plates)


class Plates:
	extends Control

	var bar

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		show_behind_parent = true
		visible = false

	func _draw() -> void:
		var rects: Dictionary = bar.slot_rects()
		for name in rects:
			var back := StyleBoxFlat.new()
			back.bg_color = Color(UiTokens.INK, UiTokens.PLATE_ALPHA)
			back.set_corner_radius_all(int(UiTokens.RADIUS * (rects[name] as Rect2).size.x / SLOT))
			draw_style_box(back, rects[name])


func plates_shown() -> bool:
	return _plates.visible


static func slot_reason(entry: Dictionary) -> String:
	if entry.get("state", "") != "cooling":
		return ""
	return "empty" if String(entry.get("refill", "time")) == "contact" else "clock"


func slot_words() -> Dictionary:
	var out := {}
	for entry in slots:
		var word := String(entry["state"])
		if slot_reason(entry) == "empty":
			word = "empty"
		if set_piece:
			word = "dimmed-for-set-piece"
		out[slot_name(entry)] = word
	return out


func pool_pips(entry: Dictionary) -> int:
	var pool := String(entry.get("pool", slot_name(entry)))
	for other in slots:
		if slot_name(other) == pool:
			return int(other["max_charges"])
	return int(entry["max_charges"])


func pip_fills(entry: Dictionary) -> Array[float]:
	var reason := slot_reason(entry)
	var max_charges: int = pool_pips(entry) if reason == "empty" else int(entry["max_charges"])
	var full: int = 0 if reason == "empty" else int(entry["charges"])
	var partial: float = clampf(float(entry.get("charge_frac", 0.0)), 0.0, 1.0)
	if reason == "empty" and partial <= 0.0:
		var pool := String(entry.get("pool", slot_name(entry)))
		for other in slots:
			if slot_name(other) == pool:
				partial = clampf(float(other.get("charge_frac", 0.0)), 0.0, 1.0)
				break
	var fills: Array[float] = []
	for c in max_charges:
		if c < full:
			fills.append(1.0)
		elif c == full and partial > 0.001:
			fills.append(partial)
		else:
			fills.append(0.0)
	return fills


static func bar_size(count := NUMBERED + 2) -> Vector2:
	var n := clampi(count, 1, NUMBERED)
	var chips := maxi(count - NUMBERED, 0)
	var width := n * SLOT + (n - 1) * GAP
	if chips > 0:
		width += CHIP_GAP + chips * SLOT * CHIP_SCALE + (chips - 1) * GAP * CHIP_SCALE
	return Vector2(width, SLOT + KEY_GAP + KEY_H + PIP_GAP + PIP * 2.0)


static func is_chip(entry: Dictionary) -> bool:
	return entry.get("group", "bar") == "chip"


static func slot_name(entry: Dictionary) -> String:
	return String(entry.get("slot", entry.get("id", "")))


func slot_rects() -> Dictionary:
	var out := {}
	var x := 0.0
	var prev := ""
	for entry in slots:
		var chip := is_chip(entry)
		if prev == "chip":
			x += GAP * CHIP_SCALE
		elif prev == "bar":
			x += CHIP_GAP if chip else GAP
		var side := SLOT * CHIP_SCALE if chip else SLOT
		out[slot_name(entry)] = Rect2(Vector2(x, (SLOT - side) * 0.5), Vector2(side, side))
		x += side
		prev = "chip" if chip else "bar"
	return out


func update_slots(list: Array, class_tint: Color, class_shape := "ring") -> void:
	var shape := class_shape if class_shape != "" else "ring"
	var changed := class_tint != tint or shape != motif or list != _shown
	tint = class_tint
	motif = shape
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
	if changed:
		_shown = list.duplicate(true)
		custom_minimum_size = bar_size(list.size())
		size = custom_minimum_size
		_plates.size = size
		if _plates.visible:
			_plates.queue_redraw()
		queue_redraw()


func _ring_ready() -> void:
	var hud := get_parent()
	var game = hud.get("game") if hud != null else null
	var presentation = game.get("presentation") if game != null else null
	var audio = presentation.get("audio") if presentation != null else null
	if audio != null and audio.has_method("play"):
		audio.play("ability_ready", 0.0, 1.0, "UI")


func hide_keys(glyphs: Array[String]) -> void:
	if glyphs == _hidden:
		return
	_hidden = glyphs.duplicate()
	queue_redraw()


var hidden_source := Callable()


func key_hidden(entry: Dictionary) -> bool:
	if hidden_source.is_valid():
		return entry["key"] in hidden_source.call()
	return entry["key"] in _hidden


func pulse_left(id: String) -> float:
	return _pulses.get(id, 0.0)


func cooldown_refunded(record: Dictionary) -> void:
	if record.get("kind", "") != "cooldown_refunded":
		return
	var slot := String(record.get("slot", ""))
	if not slots.any(func(entry): return slot_name(entry) == slot):
		return
	_refund_pending[slot] = int(_refund_pending.get(slot, 0)) + 1


func refund_flash_count() -> int:
	return _refund_count


func refund_flash_left(slot: String) -> float:
	return _refund_flashes.get(slot, 0.0)


func _step_refunds(delta: float) -> void:
	var was_flashing := not _refund_flashes.is_empty()
	var hud := get_parent()
	var game = hud.get("game") if hud != null else null
	if game != null and game.player != null:
		for record in game.player.abilities.drain_refunds():
			cooldown_refunded(record)
	for slot in _refund_flashes.keys():
		_refund_flashes[slot] = maxf(0.0, float(_refund_flashes[slot]) - delta)
		if _refund_flashes[slot] <= 0.0:
			_refund_flashes.erase(slot)
	for slot in _refund_pending.keys():
		if refund_flash_left(slot) > 0.0:
			continue
		_refund_flashes[slot] = PULSE_SECONDS
		_refund_count += 1
		_refund_pending[slot] -= 1
		if _refund_pending[slot] <= 0:
			_refund_pending.erase(slot)
	if not _refund_flashes.is_empty() or was_flashing:
		queue_redraw()


func point_at(slot: String) -> void:
	if slot == _pointed:
		return
	_pointed = slot
	queue_redraw()


func pointer_rect() -> Rect2:
	var rects := slot_rects()
	if _pointed == "" or not rects.has(_pointed):
		return Rect2()
	var slot: Rect2 = rects[_pointed]
	return Rect2(Vector2(slot.get_center().x - POINT_W * 0.5, slot.position.y - POINT_GAP - POINT_H), Vector2(POINT_W, POINT_H))


func refuse(slot: String) -> void:
	_refusals[slot] = SHAKE_TIME
	queue_redraw()


func shake_offset(slot: String) -> Vector2:
	if reduced_motion or _refusals.get(slot, 0.0) <= 0.0:
		return Vector2.ZERO
	return Vector2(sin(_clock * TAU * SHAKE_HZ) * SHAKE, 0.0)


func flash_color(slot: String) -> Color:
	return Color(Palette.SLATE, FlashGuard.info(clampf(_refusals.get(slot, 0.0) / SHAKE_TIME, 0.0, 1.0)))


func badge_shown() -> bool:
	return line_loaded and slot_rects().has("line")


func selected_entry() -> Dictionary:
	for entry in slots:
		if entry.get("selected", false):
			return entry
	return {}


func underline_share() -> float:
	return float(selected_entry().get("select_left", 0.0))


func glyph_target() -> float:
	var rects := slot_rects()
	var entry := selected_entry()
	var name := slot_name(entry) if not entry.is_empty() else (slot_name(slots[0]) if not slots.is_empty() else "")
	return (rects[name] as Rect2).get_center().x if rects.has(name) else 0.0


func slot_look(entry: Dictionary) -> Dictionary:
	var state: String = entry["state"]
	var selected: bool = entry.get("selected", false)
	var active := state == "active"
	var ink: Color = tint if active else Color(UiTokens.TEXT, 0.5 if state == "unavailable" else 0.95)
	return {"cap_fill": UiTokens.TEXT if selected else Color(UiTokens.INK, UiTokens.PLATE_ALPHA),
		"cap_ink": UiTokens.INK if selected else ink, "lift": 3.0 if active else 0.0, "doubled": active,
		"glyph": selected}


func step(delta: float) -> void:
	_step_refunds(delta)
	_clock += delta
	for id in _pulses.keys():
		_pulses[id] = maxf(0.0, _pulses[id] - delta)
		if _pulses[id] <= 0.0:
			_pulses.erase(id)
	var refusing := not _refusals.is_empty()
	for slot in _refusals.keys():
		_refusals[slot] = _refusals[slot] - delta
		if _refusals[slot] <= 0.0:
			_refusals.erase(slot)
	var target := glyph_target()
	var gliding := _glyph_t < GLYPH_SLIDE
	if glyph_x < 0.0:
		glyph_x = target
		_glyph_to = target
	elif not is_equal_approx(target, _glyph_to):
		_glyph_from = glyph_x
		_glyph_to = target
		_glyph_t = 0.0
		gliding = true
	if _glyph_t < GLYPH_SLIDE:
		_glyph_t = minf(GLYPH_SLIDE, _glyph_t + delta)
		glyph_x = lerpf(_glyph_from, _glyph_to, smoothstep(0.0, 1.0, _glyph_t / GLYPH_SLIDE))
	if not _pulses.is_empty() or _was_pulsing or refusing or gliding or underline_share() > 0.0 \
			or (_pointed != "" and not reduced_motion):
		queue_redraw()
	_was_pulsing = not _pulses.is_empty()


func _process(delta: float) -> void:
	step(delta)


func drawn_words() -> PackedStringArray:
	var out := PackedStringArray()
	for entry in slots:
		if not key_hidden(entry):
			out.append_array(Keycap.words(entry["key"]))
	return out


func _draw() -> void:
	var rects := slot_rects()
	for entry in slots:
		var name := slot_name(entry)
		_draw_slot(entry, rects[name], CHIP_SCALE if is_chip(entry) else 1.0)
	if not slots.is_empty():
		_draw_glyph()
	_draw_pointer()


func _draw_pointer() -> void:
	var rect := pointer_rect()
	if not rect.has_area():
		return
	if not reduced_motion:
		rect.position.y -= POINT_BOB * 0.5 * (1.0 + sin(_clock * TAU * POINT_HZ))
	var tip := Vector2(rect.get_center().x, rect.end.y)
	var points := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), tip])
	draw_colored_polygon(points, tint)
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[0]]), UiTokens.INK, 1.5)


func _draw_slot(entry: Dictionary, rect: Rect2, scale: float) -> void:
	var name := slot_name(entry)
	var state: String = entry["state"]
	var look := slot_look(entry)
	var color: Color = tint if state == "active" else EventKinds.UI_ROWS.get("ability_" + state, {}).get("color", UiTokens.TEXT)
	var shake := shake_offset(name)
	rect.position += shake
	var key_centre := Vector2(rect.get_center().x, SLOT + KEY_GAP + KEY_H * 0.5)
	var left := pulse_left(entry["id"])
	if left > 0.0:
		rect = rect.grow(rect.size.x * PULSE_SCALE * 0.5 * sin(PI * (1.0 - left / PULSE_SECONDS)))
	if look["doubled"]:
		rect = rect.grow(2.0)
	rect.position.y -= look["lift"]
	var radius := int(UiTokens.RADIUS * scale)
	_sb_back.bg_color = Color(UiTokens.INK, UiTokens.PLATE_ALPHA) if state != "unavailable" else Color(Palette.VERDIGRIS, 0.5)
	_sb_back.set_corner_radius_all(radius)
	draw_style_box(_sb_back, rect)

	var reason := slot_reason(entry)
	if reason == "clock":
		_draw_sweep(rect, float(entry["cooldown_frac"]))
	var icon_alpha: float = {"ready": 1.0, "active": 1.0, "cooling": 0.6 if reason == "clock" else 0.4, "unavailable": 0.28}[state]
	var icon: String = entry["icon"]
	draw_texture_rect(Icons.texture(icon), rect.grow(-rect.size.x * 0.17), false, Icons.tint(icon, Color(tint, icon_alpha)))
	if reason == "clock":
		_draw_hand(rect, float(entry["cooldown_frac"]))
	if state == "unavailable":
		var inset := 8.0 * scale
		draw_line(rect.position + Vector2(inset, rect.size.y - inset), rect.end - Vector2(inset, rect.size.y - inset), Color(color, 0.9), 3.0)
	var flash := flash_color(name)
	if flash.a > 0.0:
		_sb_wash.bg_color = Color(flash, flash.a * 0.55)
		_sb_wash.set_corner_radius_all(radius)
		draw_style_box(_sb_wash, rect)

	var frame_color: Color = tint if left > 0.0 else (Color(flash, 1.0) if flash.a > 0.0 else color)
	if reason == "empty":
		_draw_dashed(rect, frame_color)
	else:
		_sb_frame.draw_center = false
		_sb_frame.border_color = frame_color
		_sb_frame.set_border_width_all({"ready": 3, "active": 3, "cooling": 1, "unavailable": 1}[state])
		_sb_frame.set_corner_radius_all(radius)
		draw_style_box(_sb_frame, rect)
	var refund_left := refund_flash_left(name)
	if refund_left > 0.0:
		var row: Dictionary = EventKinds.UI_ROWS["cooldown_refunded"]
		var refund_color := Color(row["color"], refund_left / PULSE_SECONDS)
		draw_texture_rect(Icons.shape(row["shape"]), rect.grow(-rect.size.x * 0.2), false, refund_color)
	if look["doubled"]:
		_sb_outer.draw_center = false
		_sb_outer.border_color = Color(color, 0.55)
		_sb_outer.set_border_width_all(2)
		_sb_outer.set_corner_radius_all(radius + 3)
		draw_style_box(_sb_outer, rect.grow(5.0))

	if left > 0.0:
		var t := 1.0 - left / PULSE_SECONDS
		var reach := rect.size.x * (0.7 + 0.5 * t)
		draw_texture_rect(Icons.shape(motif), Rect2(rect.get_center() - Vector2(reach, reach) * 0.5, Vector2(reach, reach)), false, Color(tint, 0.6 * (1.0 - t)))
	if name == "line" and line_loaded:
		var badge := Rect2(Vector2(rect.end.x - BADGE * 0.6, rect.position.y - BADGE * 0.4), Vector2(BADGE, BADGE))
		draw_circle(badge.get_center(), BADGE * 0.55, Color(UiTokens.INK, UiTokens.PLATE_ALPHA))
		draw_texture_rect(Icons.texture(Icons.REEL), badge, false, Icons.tint(Icons.REEL, tint))
	if not key_hidden(entry):
		_draw_cap(key_centre + Vector2(shake.x, 0.0), entry["key"], look, KEY_H * scale)
	var fills := pip_fills(entry)
	var max_charges := fills.size()
	if max_charges > 1 or reason == "empty":
		var step_x := PIP * 3.0
		var y := SLOT + KEY_GAP + KEY_H + PIP_GAP + PIP
		var tex: Texture2D = Icons.shape(motif)
		var ts: Vector2 = tex.get_size() if tex != null else Vector2.ZERO
		for c in max_charges:
			var at := Vector2(key_centre.x + (c - (max_charges - 1) * 0.5) * step_x, y)
			var pip := Rect2(at - Vector2(PIP, PIP) * 1.3, Vector2(PIP, PIP) * 2.6)
			var fill := fills[c]
			if fill >= 0.999:
				draw_texture_rect(tex, pip, false, tint)
			else:
				draw_texture_rect(tex, pip, false, Color(tint, 0.25))
				if fill > 0.01 and ts.x > 0.0 and ts.y > 0.0:
					var fill_h := pip.size.y * fill
					var dst := Rect2(Vector2(pip.position.x, pip.end.y - fill_h), Vector2(pip.size.x, fill_h))
					var src_h := ts.y * fill
					var src := Rect2(Vector2(0.0, ts.y - src_h), Vector2(ts.x, src_h))
					draw_texture_rect_region(tex, dst, src, tint)


func _draw_cap(at: Vector2, key: String, look: Dictionary, height: float) -> void:
	if not look["glyph"] or Keycap.is_mouse(key):
		Keycap.draw(self, at, key, look["cap_ink"], height)
		return
	var cap := Keycap.size_of(key, height)
	_sb_cap.bg_color = look["cap_fill"]
	_sb_cap.border_color = look["cap_fill"]
	_sb_cap.set_border_width_all(2)
	_sb_cap.border_width_bottom = 4
	_sb_cap.set_corner_radius_all(int(cap.y * 0.2))
	draw_style_box(_sb_cap, Rect2(at - cap * 0.5, cap))
	var fs := Keycap.font_size(height)
	var text := Keycap.label(key)
	var font := UiFonts.bold()
	var baseline := at.y + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5 - 1.0
	draw_string(font, Vector2(at.x - UiFonts.width(text, fs) * 0.5, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, look["cap_ink"])


func _draw_glyph() -> void:
	var x := glyph_x if glyph_x >= 0.0 else glyph_target()
	var w := GLYPH_H * 0.8
	var top := -GLYPH_GAP - GLYPH_H - UNDERLINE - 2.0
	var rect := Rect2(Vector2(x - w * 0.5, top), Vector2(w, GLYPH_H))
	draw_texture_rect(Icons.texture("key_lmb"), rect, false, Icons.tint("key_lmb", UiTokens.TEXT))
	var share := underline_share()
	if share > 0.0:
		var y := rect.end.y + 2.0 + UNDERLINE * 0.5
		draw_line(Vector2(x - w * 0.5, y), Vector2(x - w * 0.5 + w * share, y), UiTokens.TEXT, UNDERLINE)


func _draw_sweep(rect: Rect2, frac: float) -> void:
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


func _draw_hand(rect: Rect2, frac: float) -> void:
	if frac < 1.0 / 360.0:
		return
	var centre := rect.get_center()
	var angle := -PI * 0.5 + (1.0 - frac) * TAU
	draw_line(centre, centre + Vector2(cos(angle), sin(angle)) * (rect.size.x * 0.5 - HAND * 2.0), UiTokens.TEXT, HAND)
	draw_circle(centre, HAND * 1.5, UiTokens.TEXT)


func _draw_dashed(rect: Rect2, color: Color) -> void:
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		for d in DASHES:
			var t0 := (d + 0.2) / DASHES
			var t1 := (d + 0.8) / DASHES
			draw_line(a.lerp(b, t0), a.lerp(b, t1), color, 2.0)


static func _edge(centre: Vector2, half: Vector2, angle: float) -> Vector2:
	var dir := Vector2(cos(angle), sin(angle))
	var reach := minf(half.x / maxf(absf(dir.x), 0.0001), half.y / maxf(absf(dir.y), 0.0001))
	return centre + dir * reach
