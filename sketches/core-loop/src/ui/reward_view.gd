extends Control

const Palette := preload("res://src/core/palette.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")
const Icons := preload("res://src/ui/icons.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const ScreenRegions := preload("res://src/ui/screen_regions.gd")
const ScrapFrame := preload("res://src/ui/scrap_frame.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")
const Comfort := preload("res://src/core/comfort.gd")


const CARD := Vector2(360.0, 112.0)
const MARGIN := 18.0
const TOAST_COLUMN := 800.0
const CEREMONY_SCALE := 1.25
const CRATE := Vector2(220.0, 130.0)
const CRATE_SCALE := 1.4
const RAYS := 14
const BITS := 32


var now := 0
var card := {}
var ceremony := {}
var flashes: Array = []

var _cracks: Array = []
var _bits: Array = []


func _init() -> void:
	name = "RewardView"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false


func set_ceremony(state: Dictionary) -> void:
	ceremony = state
	_cracks.clear()
	_bits.clear()
	if state.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(state.get("seed", 1))
	for k in 7:
		var side := k % 4
		var at := Vector2(rng.randf_range(-CRATE.x * 0.45, CRATE.x * 0.45), -CRATE.y * 0.5 if side == 0 else CRATE.y * 0.5)
		if side >= 2:
			at = Vector2(-CRATE.x * 0.5 if side == 2 else CRATE.x * 0.5, rng.randf_range(-CRATE.y * 0.4, CRATE.y * 0.4))
		var heading := (-at).normalized().rotated(rng.randf_range(-0.6, 0.6))
		var path := PackedVector2Array([at])
		for s in 5:
			heading = heading.rotated(rng.randf_range(-0.7, 0.7))
			at += heading * rng.randf_range(12.0, 22.0)
			path.append(at)
		_cracks.append(path)
	for b in BITS:
		var angle := rng.randf_range(-PI, 0.0) if b % 3 != 0 else rng.randf_range(0.0, TAU)
		_bits.append({"v": Vector2.from_angle(angle) * rng.randf_range(260.0, 620.0), "size": rng.randf_range(5.0, 11.0),
			"spin": rng.randf_range(-9.0, 9.0), "class": b % 2 == 0})


func drawn_words() -> PackedStringArray:
	var words := PackedStringArray()
	if _card_alpha() > 0.0:
		for key in ["stamp", "name", "verb"]:
			if String(card.get(key, "")) != "":
				words.append(String(card[key]))
	return words


func busy() -> bool:
	return not card.is_empty() or not ceremony.is_empty() or not flashes.is_empty()


func _process(_delta: float) -> void:
	visible = busy()
	if visible:
		queue_redraw()


func _screen() -> Vector2:
	return get_viewport_rect().size if is_inside_tree() else Vector2(1600.0, 900.0)


func card_rest(screen: Vector2) -> Vector2:
	var band := ScreenRegions.rect("toasts", screen)
	var beside := MARGIN + CARD.x + MARGIN <= (screen.x - TOAST_COLUMN) * 0.5 and CARD.y <= band.size.y
	return Vector2(MARGIN, band.position.y if beside else band.end.y + MARGIN)


func _draw() -> void:
	var screen := _screen()
	if not ceremony.is_empty():
		_draw_ceremony(screen)
	elif not card.is_empty():
		var a := _card_alpha()
		if a > 0.0:
			var rest := card_rest(screen)
			var t := _seconds(card["start_ms"])
			var slide := _ease(clampf(t / float(card["in_s"]), 0.0, 1.0))
			var gone := _closing()
			var x := lerpf(-CARD.x - MARGIN, rest.x, slide) - (CARD.x + MARGIN) * _ease_in(gone)
			_draw_card(Transform2D(0.0, Vector2(x, rest.y)), t, a)
	for flash in flashes:
		_draw_flash(flash)


func _seconds(from_ms) -> float:
	return (now - int(from_ms)) / 1000.0


func _closing() -> float:
	var t := _seconds(card.get("start_ms", now))
	var out_from: float = float(card.get("in_s", 0.2)) + float(card.get("hold_s", 2.0))
	return clampf((t - out_from) / maxf(float(card.get("out_s", 0.25)), 0.01), 0.0, 1.0)


func _card_alpha() -> float:
	if card.is_empty():
		return 0.0
	if card.get("ceremony", false):
		var bt := _burst_seconds()
		return 0.0 if bt < 0.0 else clampf(bt / 0.2, 0.0, 1.0) * (1.0 - _ceremony_out())
	return 1.0 - _closing()


static func _ease(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3.0)


static func _ease_in(x: float) -> float:
	return x * x * x


func _draw_card(base: Transform2D, t: float, alpha: float) -> void:
	draw_set_transform_matrix(base)
	var tint: Color = card.get("tint", Palette.AMBER)
	var yours: Color = card.get("class_color", Palette.SAND)
	_plate(Rect2(Vector2.ZERO, CARD), tint, int(card.get("seed", 1)), alpha)
	var own := Vector2(48.0, 52.0)
	var pop := 1.0 + 0.25 * maxf(0.0, 1.0 - absf(t - float(card["in_s"])) / 0.12)
	_socket(own, 30.0 * pop, String(card["icon"]), tint, alpha, Color(card["heart"], alpha) if card.get("heart") is Color else Color(0, 0, 0, 0))
	if String(card.get("element_icon", "")) != "":
		var e := String(card["element_icon"])
		draw_texture_rect(Icons.texture(e), Rect2(own + Vector2(12.0, 10.0), Vector2(22.0, 22.0)), false, _faded(Icons.tint(e, Palette.SAND), alpha))
	var link := String(card.get("link", ""))
	var text_w := CARD.x - 92.0 - (52.0 if link != "" else 16.0)
	var name_size := UiTokens.LABEL if UiFonts.width(String(card["name"]), UiTokens.LABEL) <= text_w else UiTokens.BODY
	_text(Vector2(92.0, 40.0), String(card["name"]), name_size, _faded(UiTokens.TEXT, alpha), text_w)
	var verb := verb_fit(String(card["verb"]), text_w)
	var lines: Array = verb["lines"]
	for i in lines.size():
		_text(Vector2(92.0, (68.0 if lines.size() == 1 else 64.0) + 22.0 * i), lines[i], verb["size"], _faded(Palette.SAND, alpha * 0.9), text_w)
	if link != "":
		_draw_link(own, t, alpha, yours, tint, link == "lit")
	_stamp(base, Vector2(CARD.x - 8.0, -8.0), String(card.get("stamp", "")), tint, alpha)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_link(own: Vector2, t: float, alpha: float, yours: Color, tint: Color, lit: bool) -> void:
	var partner := Vector2(CARD.x - 30.0, 74.0)
	var path := PackedVector2Array([own + Vector2(0.0, 32.0), Vector2(own.x, CARD.y - 13.0), Vector2(partner.x, CARD.y - 13.0), partner + Vector2(0.0, 19.0)])
	var snap := clampf((t - float(card["in_s"])) / maxf(float(card.get("snap_s", 0.18)), 0.01), 0.0, 1.0) if lit else 1.0
	var shown := _partial(path, snap)
	if lit:
		draw_polyline(shown, _faded(Color(yours, 0.35), alpha), 7.0, true)
		draw_polyline(shown, _faded(yours.lerp(Color.WHITE, 0.3), alpha), 2.5, true)
		for i in range(1, shown.size() - 1):
			draw_line(shown[i] + Vector2(-4.0, -4.0), shown[i] + Vector2(4.0, 4.0), _faded(Palette.SAND, alpha), 2.0)
		if snap >= 1.0:
			var spark := clampf((t - float(card["in_s"]) - float(card.get("snap_s", 0.18))) / 0.3, 0.0, 1.0)
			draw_arc(partner, 20.0 + 16.0 * spark, 0.0, TAU, 24, _faded(Color(yours, 1.0 - spark), alpha), 2.0)
	else:
		for i in path.size() - 1:
			draw_dashed_line(path[i], path[i + 1], _faded(Color(Palette.SAND, 0.4), alpha), 2.0, 5.0)
	var icon := String(card.get("partner_icon", ""))
	var lit_partner := lit and snap >= 1.0
	if icon != "":
		_socket(partner, 18.0, icon, yours if lit_partner else Palette.SAND, alpha * (1.0 if lit_partner else 0.45))
	else:
		draw_circle(partner, 18.0, _faded(Color(Palette.CHARCOAL.darkened(0.3), 0.95), alpha))
		draw_arc(partner, 18.0, 0.0, TAU, 24, _faded(Color(Palette.SAND, 0.45), alpha), 2.0)
		draw_string(UiFonts.bold(), partner + Vector2(-5.5, 7.0), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.BODY, _faded(UiTokens.quiet(), alpha))


static func _partial(path: PackedVector2Array, fraction: float) -> PackedVector2Array:
	var total := 0.0
	for i in path.size() - 1:
		total += path[i].distance_to(path[i + 1])
	var left := total * fraction
	var out := PackedVector2Array([path[0]])
	for i in path.size() - 1:
		var step := path[i].distance_to(path[i + 1])
		if left >= step:
			out.append(path[i + 1])
			left -= step
			continue
		out.append(path[i].lerp(path[i + 1], left / maxf(step, 0.001)))
		break
	return out


func _plate(rect: Rect2, edge: Color, plate_seed: int, alpha: float) -> void:
	var box = ScrapFrame.plate(Palette.VERDIGRIS.lerp(edge, 0.35), plate_seed, Color(Palette.CHARCOAL, 0.94), 2.0,
		0.2 + 0.6 * ScrapFrame.quirk(plate_seed, 8))
	box.fade = alpha
	draw_style_box(box, rect)
	draw_rect(Rect2(rect.position + Vector2(5.0, 13.0), Vector2(5.0, rect.size.y - 26.0)), _faded(edge, alpha))


func _socket(centre: Vector2, radius: float, icon: String, tint: Color, alpha: float, heart := Color(0, 0, 0, 0)) -> void:
	draw_circle(centre, radius, _faded(Color(Palette.CHARCOAL.darkened(0.35), 0.96), alpha))
	draw_arc(centre, radius, 0.0, TAU, 32, _faded(tint, alpha), 2.5, true)
	var side := radius * 1.3
	if icon != "":
		draw_texture_rect(Icons.texture(icon), Rect2(centre - Vector2(side, side) * 0.5, Vector2(side, side)), false, _faded(Icons.tint(icon, tint), alpha))
	if heart.a > 0.0:
		var h := radius * 0.5
		draw_texture_rect(Icons.shape("diamond"), Rect2(centre - Vector2(h, h) * 0.5, Vector2(h, h)), false, heart)


func _stamp(base: Transform2D, at: Vector2, text: String, tint: Color, alpha: float) -> void:
	if text == "":
		return
	var font := UiFonts.mono()
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.CAPTION).x + 14.0
	draw_set_transform_matrix(base * Transform2D(-0.08, at))
	var r := Rect2(Vector2(-w, 0.0), Vector2(w, 20.0))
	draw_rect(r, _faded(tint, alpha))
	draw_rect(r, _faded(Palette.CHARCOAL, alpha), false, 1.5)
	draw_circle(Vector2(-w + 4.0, 10.0), 1.8, _faded(Palette.CHARCOAL, alpha))
	draw_string(font, Vector2(-w + 8.0, 15.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.CAPTION, _faded(Palette.CHARCOAL, alpha))
	draw_set_transform_matrix(base)


static func verb_fit(verb: String, width: float) -> Dictionary:
	if UiFonts.width(verb, UiTokens.BODY) <= width:
		return {"size": UiTokens.BODY, "lines": [verb]}
	for font_size in [UiTokens.BODY, UiTokens.CAPTION]:
		var lines := _two_lines(verb, width, font_size)
		if lines.all(func(line): return UiFonts.width(line, font_size) <= width):
			return {"size": font_size, "lines": lines}
	return {"size": UiTokens.CAPTION, "lines": _two_lines(verb, width, UiTokens.CAPTION)}


static func _two_lines(verb: String, width: float, font_size: int) -> Array:
	var words := verb.split(" ", false)
	var first := ""
	var i := 0
	while i < words.size():
		var next := words[i] if first == "" else first + " " + words[i]
		if first != "" and UiFonts.width(next, font_size) > width:
			break
		first = next
		i += 1
	var rest := " ".join(words.slice(i))
	return [first] if rest == "" else [first, rest]


func _text(at: Vector2, value: String, font_size: int, color: Color, width: float) -> void:
	var font := UiFonts.bold()
	draw_string_outline(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, 5, Color(Palette.CHARCOAL, color.a))
	draw_string(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, color)


static func _faded(color: Color, alpha: float) -> Color:
	return Color(color, color.a * alpha)


func _burst_seconds() -> float:
	var at := int(ceremony.get("burst_ms", -1))
	return -1.0 if at < 0 or now < at else (now - at) / 1000.0


func _ceremony_out() -> float:
	var at := int(ceremony.get("close_ms", -1))
	if at < 0 or now < at:
		return 0.0
	return clampf((now - at) / 1000.0 / maxf(float(ceremony.get("out_s", 0.25)), 0.01), 0.0, 1.0)


func _draw_ceremony(screen: Vector2) -> void:
	var t := _seconds(ceremony["start_ms"])
	var in_s := float(ceremony["in_s"])
	var fade := 1.0 - _ceremony_out()
	draw_rect(Rect2(Vector2.ZERO, screen), Color(Palette.CHARCOAL, 0.55 * clampf(t / in_s, 0.0, 1.0) * fade))
	var centre := Vector2(screen.x * 0.5, screen.y * 0.46)
	var bt := _burst_seconds()
	if bt < 0.0:
		_draw_crate(centre, t, clampf((t - in_s) / float(ceremony["build_s"]), 0.0, 1.0), clampf(t / in_s, 0.0, 1.0), 1.0)
		return
	_draw_burst(centre, bt, fade)
	var rise := 60.0 * (1.0 - _ease(clampf(bt / 0.35, 0.0, 1.0)))
	var at := centre - CARD * CEREMONY_SCALE * 0.5 + Vector2(0.0, -40.0 + rise)
	if not card.is_empty():
		_draw_card(Transform2D(0.0, Vector2.ONE * CEREMONY_SCALE, 0.0, at), bt, _card_alpha())
	_draw_hull(Vector2(centre.x, at.y + CARD.y * CEREMONY_SCALE + 44.0), bt, fade)


func _draw_crate(centre: Vector2, t: float, p: float, landed: float, alpha: float) -> void:
	var yours: Color = ceremony.get("class_color", Palette.SAND)
	var tint: Color = ceremony.get("tint", Palette.AMBER)
	var amp := (1.5 + 11.0 * p * p) * (0.0 if Comfort.reduced_motion else 1.0)
	var w := 30.0 + 55.0 * p
	var shake := Vector2(sin(t * w), cos(t * w * 1.37)) * amp
	var origin := centre + shake + Vector2(0.0, -_screen().y * 0.35 * (1.0 - _ease(landed)))
	for ring in 4:
		draw_circle(centre, (150.0 + 70.0 * ring) * (0.6 + 0.6 * p), Color(yours, (0.16 - 0.035 * ring) * p * alpha))
	draw_set_transform(origin, sin(t * w * 0.8) * 0.06 * p * (0.0 if Comfort.reduced_motion else 1.0), Vector2.ONE * CRATE_SCALE)
	var body := Rect2(-CRATE * 0.5, CRATE)
	draw_rect(body.grow(4.0), _faded(Color(Palette.CHARCOAL, 0.8), alpha))
	draw_rect(body, _faded(Palette.COPPER.darkened(0.4), alpha))
	for k in 3:
		var y := body.position.y + body.size.y * (k + 1) / 4.0
		draw_line(Vector2(body.position.x, y), Vector2(body.end.x, y), _faded(Color(Palette.CHARCOAL, 0.7), alpha), 3.0)
	for k in 5:
		var gy := body.position.y + 10.0 + k * 25.0
		draw_line(Vector2(body.position.x + 20.0 + k * 13.0, gy), Vector2(body.position.x + 60.0 + k * 13.0, gy + 1.0), _faded(Color(Palette.COPPER, 0.5), alpha), 1.5)
	for corner in [body.position, Vector2(body.end.x, body.position.y), body.end, Vector2(body.position.x, body.end.y)]:
		var sx := 1.0 if corner.x < 0.0 else -1.0
		var sy := 1.0 if corner.y < 0.0 else -1.0
		draw_colored_polygon(PackedVector2Array([corner, corner + Vector2(26.0 * sx, 0.0), corner + Vector2(26.0 * sx, 8.0 * sy),
			corner + Vector2(8.0 * sx, 8.0 * sy), corner + Vector2(8.0 * sx, 26.0 * sy), corner + Vector2(0.0, 26.0 * sy)]), _faded(Palette.VERDIGRIS, alpha))
		draw_circle(corner + Vector2(5.0 * sx, 5.0 * sy), 2.6, _faded(Palette.SAND, alpha))
	draw_texture_rect(Icons.shape("diamond"), Rect2(Vector2(-20.0, -14.0), Vector2(40.0, 40.0)), false, _faded(Color(tint, 0.85), alpha))
	var seam := Color(yours.lerp(Color.WHITE, 0.35), p * alpha)
	draw_line(Vector2(body.position.x, body.position.y), Vector2(body.end.x, body.position.y), Color(seam, seam.a * 0.35), 3.0 + 10.0 * p)
	var lid := Rect2(Vector2(-CRATE.x * 0.5 - 8.0, -CRATE.y * 0.5 - 26.0), Vector2(CRATE.x + 16.0, 24.0))
	draw_rect(lid, _faded(Palette.COPPER.darkened(0.15), alpha))
	draw_rect(lid, _faded(Palette.CHARCOAL, alpha), false, 2.0)
	draw_rect(Rect2(Vector2(-9.0, lid.end.y - 6.0), Vector2(18.0, 16.0)), _faded(Palette.SAND.darkened(0.2), alpha))
	var total := 0
	for crack in _cracks:
		total += (crack as PackedVector2Array).size() - 1
	var budget := int(round(p * total))
	for crack in _cracks:
		if budget <= 0:
			break
		var shown := (crack as PackedVector2Array).slice(0, mini(budget + 1, crack.size()))
		budget -= shown.size() - 1
		draw_polyline(shown, Color(seam, 0.3 * seam.a), 7.0, true)
		draw_polyline(shown, seam, 2.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_burst(centre: Vector2, bt: float, fade: float) -> void:
	var yours: Color = ceremony.get("class_color", Palette.SAND)
	var tint: Color = ceremony.get("tint", Palette.AMBER)
	var rays := clampf(1.0 - bt / (float(ceremony["hold_s"]) + 0.4), 0.0, 1.0) * fade
	for k in RAYS:
		var angle := k * TAU / RAYS + bt * 0.45
		var tip := 520.0
		draw_colored_polygon(PackedVector2Array([centre, centre + Vector2.from_angle(angle - 0.05) * tip, centre + Vector2.from_angle(angle + 0.05) * tip]),
			Color(yours if k % 2 == 0 else tint, FlashGuard.alpha(0.26) * rays))
	var f := clampf(bt / 0.3, 0.0, 1.0)
	draw_circle(centre, 40.0 + 320.0 * f, Color(yours.lerp(Color.WHITE, FlashGuard.whiten(0.6)), FlashGuard.alpha(0.75) * (1.0 - f)))
	if bt < 0.3:
		_draw_crate(centre, 0.0, 1.0, 1.0, 1.0 - bt / 0.3)
	if bt < 0.7:
		var lid_at := centre + Vector2(140.0 * bt, -95.0 * CRATE_SCALE - 620.0 * bt + 900.0 * bt * bt)
		draw_set_transform(lid_at, 3.0 * bt, Vector2.ONE * CRATE_SCALE)
		var lid := Rect2(Vector2(-CRATE.x * 0.5 - 8.0, -12.0), Vector2(CRATE.x + 16.0, 24.0))
		draw_rect(lid, Color(Palette.COPPER.darkened(0.15), 1.0 - bt / 0.7))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var life := 1.3
	if bt < life:
		for bit in _bits:
			var at: Vector2 = centre + bit["v"] * bt + Vector2(0.0, 520.0 * bt * bt)
			var s: float = bit["size"]
			draw_set_transform(at, float(bit["spin"]) * bt, Vector2.ONE)
			draw_rect(Rect2(Vector2(-s, -s) * 0.5, Vector2(s, s)), Color(yours if bit["class"] else tint, 1.0 - bt / life))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_hull(centre: Vector2, bt: float, fade: float) -> void:
	var hull: Array = ceremony.get("hull", [])
	if hull.is_empty():
		return
	var yours: Color = ceremony.get("class_color", Palette.SAND)
	var tint: Color = ceremony.get("tint", Palette.AMBER)
	var gap := 42.0
	var width := gap * hull.size() + 24.0
	var alpha := clampf((bt - 0.2) / 0.25, 0.0, 1.0) * fade
	if alpha <= 0.0:
		return
	_plate(Rect2(centre - Vector2(width * 0.5, 26.0), Vector2(width, 52.0)), Palette.VERDIGRIS, int(ceremony.get("seed", 1)) + 7, alpha)
	var seat := clampf((bt - 0.45) / 0.4, 0.0, 1.0)
	for i in hull.size():
		var slot := centre + Vector2(-width * 0.5 + 12.0 + gap * (i + 0.5), 0.0)
		var last := i == hull.size() - 1
		if not last:
			_socket(slot, 16.0, String(hull[i]), Palette.SAND, alpha * 0.8)
			continue
		draw_circle(slot, 16.0, Color(Palette.CHARCOAL.darkened(0.35), alpha))
		draw_arc(slot, 16.0, 0.0, TAU, 24, Color(yours, alpha * (0.4 + 0.6 * seat)), 2.5, true)
		var from := centre + Vector2(-CARD.x * CEREMONY_SCALE * 0.5 + 48.0 * CEREMONY_SCALE, -120.0)
		var glyph_at := from.lerp(slot, _ease(seat))
		var side := lerpf(48.0, 21.0, seat)
		var icon := String(hull[i])
		draw_texture_rect(Icons.texture(icon), Rect2(glyph_at - Vector2(side, side) * 0.5, Vector2(side, side)), false, _faded(Icons.tint(icon, tint), alpha))
		if seat >= 1.0:
			var ring := clampf((bt - 0.85) / 0.4, 0.0, 1.0)
			draw_arc(slot, 16.0 + 18.0 * ring, 0.0, TAU, 24, Color(yours, (1.0 - ring) * alpha), 3.0, true)


func _draw_flash(flash: Dictionary) -> void:
	var x := clampf(_seconds(flash["start_ms"]) / float(flash["life_s"]), 0.0, 1.0)
	var at: Vector2 = flash["at"]
	var yours: Color = flash["class_color"]
	draw_arc(at, 30.0 + 80.0 * _ease(x), 0.0, TAU, 32, Color(yours, FlashGuard.info(1.0 - x)), 5.0 * (1.0 - x) + 1.0, true)
	var pop := 1.0 + 0.35 * sin(minf(x / 0.35, 1.0) * PI)
	_socket(at, 24.0 * pop, String(flash["icon"]), flash["tint"], 1.0 - x * x)
