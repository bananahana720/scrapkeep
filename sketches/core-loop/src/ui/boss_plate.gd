extends Control

const BossPosture := preload("res://src/core/boss_posture.gd")
const UiTokens := preload("res://src/core/ui_tokens.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Icons := preload("res://src/ui/icons.gd")
const Roster := preload("res://src/combat/roster.gd")
const UiDraw := preload("res://src/ui/ui_draw.gd")
const UiFonts := preload("res://src/core/ui_fonts.gd")
const ScrapFrame := preload("res://src/ui/scrap_frame.gd")
const Comfort := preload("res://src/core/comfort.gd")


const SIZE := Vector2(420.0, 44.0)
const GLANCE_SECONDS := 0.6
const TICKS := [0.25, 0.5, 0.75]
const FONT := UiTokens.BODY
const MARGIN := float(UiTokens.GAP_L)
const NAME_WIDTH := 138.0
const PIP := 16.0
const PIP_GAP := 6.0
const BAR_HEIGHT := 12.0
const BANK_POST := 4.0
const GLYPH := 26.0
const GAP := 10.0
const EMPTY_ALPHA := 0.35
const PHASE := 18.0
const PHASE_GAP := 16.0
const PHASE_DROP := PHASE * 0.5
const CRACK_SECONDS := 0.9
const CRACK_POP := 0.5
const LIGHT_SECONDS := 0.4
const NO_HAND := -1
const SERIAL := 46
const STENCIL := UiTokens.LABEL

var _warden: Node3D
var _events
var _glance_left := 0.0
var _phases
var _seen_phase := 0
var _turn_age := -1.0
var _frame: StyleBox
var _frame_hand := NO_HAND


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = SIZE
	size = SIZE


func bind(warden: Node3D, phases = null) -> void:
	unbind()
	_warden = warden
	_glance_left = 0.0
	_phases = phases
	_seen_phase = phase()
	_turn_age = -1.0
	_fit()
	var fleet = warden.get("fleet") if is_instance_valid(warden) else null
	if fleet != null:
		_events = fleet.events()
		_events.strike_deflected.connect(_on_deflected)
	queue_redraw()


func unbind() -> void:
	if _events != null and is_instance_valid(_events) and _events.strike_deflected.is_connected(_on_deflected):
		_events.strike_deflected.disconnect(_on_deflected)
	_events = null
	_warden = null
	_glance_left = 0.0
	_phases = null
	_seen_phase = 0
	_turn_age = -1.0
	_frame = null
	_frame_hand = NO_HAND
	_fit()
	queue_redraw()


func active() -> bool:
	if (_warden != null or _events != null) and not is_instance_valid(_warden):
		unbind()
	if not is_instance_valid(_warden):
		return false
	var fights: bool = rogue() or (_warden.has_method("fight") and _warden.fight() == "posture")
	return fights and not _warden.is_dead()


func hand() -> int:
	if not is_instance_valid(_warden):
		return NO_HAND
	if rogue():
		return UiTokens.Hand.ROGUE
	return UiTokens.Hand.FLEET if _fleet_body() else UiTokens.Hand.OLD_WORKS


func rogue() -> bool:
	return crew() != ""


func crew() -> String:
	if not is_instance_valid(_warden):
		return ""
	var row = _warden.get("row")
	return String(row.get("crew", "")) if row is Dictionary else ""


func drawn_words() -> Array:
	return Array(plate_name().split(" ", false))


func drawn_number() -> String:
	return crew() if active() else ""


func name_held() -> bool:
	var node := get_parent()
	while node != null:
		var game = node.get("game")
		if game != null:
			var presentation = game.get("presentation")
			return presentation != null and presentation.names_boss()
		node = node.get_parent()
	return false


func plate_name() -> String:
	return _name() if active() else ""


func _name() -> String:
	if rogue():
		return ""
	if _warden.has_meta("plate_name"):
		var tagged := String(_warden.get_meta("plate_name"))
		if not tagged.is_empty():
			return tagged
	if _fleet_body():
		return String(EventKinds.hud("boss_arena_entered"))
	var variant = _warden.get("variant")
	return Roster.warden_name(String(_warden.family), String(variant) if variant != null else "")


func _fleet_body() -> bool:
	return not rogue() and not _warden.has_meta("plate_name") and _warden.get("family") == null


func pips() -> Array:
	var list: Array = []
	if not active() or rogue():
		return list
	var left: int = _warden.chunks_left()
	for i in BossPosture.CHUNKS:
		list.append({"filled": i < left, "cracked": i == left - 1 and _warden.chunk_cracked()})
	return list


func bar_fraction() -> float:
	if not active():
		return 0.0
	if rogue():
		return clampf(float(_warden.hp) / maxf(float(_warden.max_hp), 1.0), 0.0, 1.0)
	if _warden.staggered():
		return clampf(_warden.stagger_left() / BossPosture.STAGGER_SECONDS, 0.0, 1.0)
	return clampf(_warden.posture() / BossPosture.FULL, 0.0, 1.0)


func crack_color() -> Color:
	return crack_color_for(active() and _open())


func bar_color() -> Color:
	if banking():
		return phase_color()
	return bar_color_for(active() and _open())


func _open() -> bool:
	return _warden.is_weak() if rogue() else _warden.staggered()


func banking() -> bool:
	return active() and _warden.has_method("banking") and _warden.banking()


func bank_cap() -> float:
	return clampf(_warden.bank_cap(), 0.0, 1.0) if banking() and _warden.has_method("bank_cap") else 0.0


static func crack_color_for(open: bool) -> Color:
	return EventKinds.state_color("chunk_shatter") if open else EventKinds.role_color("neutral")


static func bar_color_for(open: bool) -> Color:
	return EventKinds.state_color("open") if open else EventKinds.role_color("neutral")


static func pip_color(filled: bool) -> Color:
	var neutral := EventKinds.role_color("neutral")
	return neutral if filled else _fade(neutral, EMPTY_ALPHA)


static func crack_backing() -> Color:
	return UiDraw.OUTLINE


func glyph_id() -> String:
	if not active():
		return ""
	if _open():
		return "open"
	if rogue():
		return ""
	return "glancing" if _glance_left > 0.0 else "posture_step"


func glyph_color() -> Color:
	return EventKinds.state_color(glyph_id()) if glyph_id() != "" else EventKinds.role_color("neutral")


func phase_count() -> int:
	return int(_phases.phases) if _phases != null else 1


func phase() -> int:
	return int(_phases.phase) if _phases != null else 0


func phased() -> bool:
	return active() and phase_count() > 1


func phase_pips() -> Array:
	var list: Array = []
	if not phased():
		return list
	var now := phase()
	for i in phase_count():
		list.append("spent" if i + 1 < now else ("live" if i + 1 == now else "ahead"))
	return list


func turn_age() -> float:
	return _turn_age


func advance(delta: float) -> void:
	_glance_left = maxf(0.0, _glance_left - delta)
	if _turn_age >= 0.0:
		_turn_age += delta
		if _turn_age >= CRACK_SECONDS:
			_turn_age = -1.0
	var now := phase()
	if now > _seen_phase and now >= 2:
		_turn_age = 0.0
	_seen_phase = now


func name_width() -> float:
	if rogue():
		return _stencil_face().get_string_size(crew(), HORIZONTAL_ALIGNMENT_LEFT, -1, STENCIL).x + GAP
	if not is_instance_valid(_warden):
		return NAME_WIDTH
	return maxf(NAME_WIDTH, UiFonts.face(hand()).get_string_size(_name(), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT).x + GAP)


static func _stencil_face() -> Font:
	return UiFonts.face(UiTokens.Hand.ROGUE, true)


func rest_size() -> Vector2:
	var pips_room := 0.0 if not rogue() else BossPosture.CHUNKS * (PIP + PIP_GAP) - PIP_GAP + GAP
	return SIZE + Vector2(name_width() - NAME_WIDTH - pips_room + stamp_room(), 0.0)


func stamp_room() -> float:
	return maxf(0.0, ScrapFrame.stamp_reach() + GAP - MARGIN) if hand() == UiTokens.Hand.FLEET else 0.0


func _fit() -> void:
	var want := rest_size() + (Vector2(0.0, PHASE_DROP) if _phases != null and phase_count() > 1 else Vector2.ZERO)
	custom_minimum_size = want
	size = want


func _on_deflected(enemy: Node3D, _kind: String, _punch: float, _plating: float) -> void:
	if enemy == _warden:
		_glance_left = GLANCE_SECONDS


func _process(delta: float) -> void:
	advance(delta)
	active()
	queue_redraw()


func _exit_tree() -> void:
	unbind()


static func _fade(color: Color, alpha: float) -> Color:
	var out := color
	out.a = alpha
	return out


func _draw() -> void:
	if not active():
		return
	var neutral := EventKinds.role_color("neutral")
	var which := hand()
	draw_style_box(frame_box(), Rect2(Vector2.ZERO, Vector2(size.x, SIZE.y)))
	var mid := SIZE.y * 0.5
	if which == UiTokens.Hand.ROGUE:
		_hand_text(which, MARGIN, mid, crew())
	else:
		_hand_text(which, MARGIN, mid, plate_name())
	var x := MARGIN + name_width()
	var right := size.x - MARGIN - stamp_room()
	var drawn_pips := pips()
	for pip in drawn_pips:
		_draw_pip(Rect2(Vector2(x, mid - PIP * 0.5), Vector2(PIP, PIP)), pip, neutral)
		x += PIP + PIP_GAP
	if not drawn_pips.is_empty():
		x += GAP - PIP_GAP
	var bar := Rect2(Vector2(x, mid - BAR_HEIGHT * 0.5), Vector2(right - GLYPH - GAP - x, BAR_HEIGHT))
	UiDraw.bar(self, bar, bar_fraction(), bar_color())
	for tick in TICKS:
		var tx: float = bar.position.x + bar.size.x * tick
		draw_line(Vector2(tx, bar.position.y), Vector2(tx, bar.end.y), UiDraw.OUTLINE, 2.0)
	var cap := bank_cap()
	if cap > 0.0:
		var cx: float = bar.position.x + bar.size.x * cap
		draw_line(Vector2(cx, bar.position.y - BANK_POST), Vector2(cx, bar.end.y + BANK_POST), crack_backing(), 5.0)
		draw_line(Vector2(cx, bar.position.y - BANK_POST), Vector2(cx, bar.end.y + BANK_POST), phase_color(), 2.0)
	if glyph_id() != "":
		var row := EventKinds.state_row(glyph_id())
		var rect := Rect2(Vector2(right - GLYPH, mid - GLYPH * 0.5), Vector2(GLYPH, GLYPH))
		draw_texture_rect(Icons.shape(String(row.get("shape", "none"))), rect, false, glyph_color())
	_draw_phases()


func frame_box() -> StyleBox:
	var which := hand()
	if which == NO_HAND:
		_frame = null
		_frame_hand = NO_HAND
		return null
	if _frame == null or _frame_hand != which:
		_frame = ScrapFrame.hand_plate(which, SERIAL)
		_frame_hand = which
	return _frame


func _hand_text(which: int, x: float, y: float, value: String) -> void:
	var stencil := which == UiTokens.Hand.ROGUE
	var font := _stencil_face() if stencil else UiFonts.face(which)
	var font_size := STENCIL if stencil else FONT
	var color: Color = UiTokens.HANDS[which].ink
	var at := Vector2(x, y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5)
	draw_string_outline(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 6, UiDraw.OUTLINE)
	draw_string(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


static func phase_color() -> Color:
	return EventKinds.color("boss_phase_changed")


func diamond_scale(i: int) -> float:
	if Comfort.reduced_motion or _turn_age < 0.0:
		return 1.0
	if i == phase() - 2:
		return 1.0 + CRACK_POP * sin(PI * clampf(_turn_age / CRACK_SECONDS * 3.0, 0.0, 1.0))
	if i == phase() - 1:
		return clampf(_turn_age / LIGHT_SECONDS, 0.25, 1.0)
	return 1.0


func _draw_phases() -> void:
	var pips := phase_pips()
	if pips.is_empty():
		return
	var span := pips.size() * PHASE + (pips.size() - 1) * PHASE_GAP
	var x := (size.x - span) * 0.5 + PHASE * 0.5
	var neutral := EventKinds.role_color("neutral")
	var cracking := _turn_age >= 0.0
	var t := _turn_age / CRACK_SECONDS if cracking else 1.0
	for i in pips.size():
		var c := Vector2(x + i * (PHASE + PHASE_GAP), SIZE.y)
		var state: String = pips[i]
		var just_spent := cracking and i == phase() - 2
		var half := PHASE * 0.5 * diamond_scale(i)
		var shape := PackedVector2Array([c + Vector2(0.0, -half), c + Vector2(half, 0.0), c + Vector2(0.0, half), c + Vector2(-half, 0.0)])
		var ring := shape.duplicate()
		ring.append(shape[0])
		match state:
			"live":
				draw_colored_polygon(shape, phase_color())
				draw_polyline(ring, crack_backing(), 2.0)
			"spent":
				draw_colored_polygon(shape, crack_backing())
				draw_polyline(ring, _fade(neutral, EMPTY_ALPHA), 2.0)
				var crack := PackedVector2Array([c + Vector2(-1.5, -half), c + Vector2(1.5, -1.0), c + Vector2(-1.5, 1.0), c + Vector2(1.5, half)])
				draw_polyline(crack, crack_backing(), 3.5)
				draw_polyline(crack, phase_color() if just_spent else neutral, 1.5)
			_:
				draw_colored_polygon(shape, crack_backing())
				draw_polyline(ring, neutral, 2.0)
		if just_spent and not Comfort.reduced_motion:
			var shard_color := _fade(phase_color(), 1.0 - t)
			for side in [-1.0, 1.0]:
				var at := c + Vector2(side * (half + 10.0 * t), -6.0 * t + 14.0 * t * t)
				draw_colored_polygon(PackedVector2Array([at + Vector2(0.0, -3.0), at + Vector2(side * 3.0, 1.0), at + Vector2(-side * 1.0, 2.0)]), shard_color)


func _draw_pip(rect: Rect2, pip: Dictionary, _color: Color) -> void:
	if pip["filled"]:
		draw_rect(rect, pip_color(true))
	else:
		draw_rect(rect, pip_color(false), false, 2.0)
	if pip["cracked"]:
		var c := rect.get_center()
		var line := PackedVector2Array([c + Vector2(-3.0, -PIP * 0.5), c + Vector2(2.0, -2.0), c + Vector2(-2.0, 2.0), c + Vector2(3.0, PIP * 0.5)])
		draw_polyline(line, crack_backing(), 4.5)
		draw_polyline(line, crack_color(), 2.5)
