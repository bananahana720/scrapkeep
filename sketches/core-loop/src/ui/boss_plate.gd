extends Control

const BossPosture := preload("res://src/combat/boss_posture.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Icons := preload("res://src/ui/icons.gd")
const Roster := preload("res://src/combat/roster.gd")
const UiDraw := preload("res://src/ui/ui_draw.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const ScrapFrame := preload("res://src/ui/scrap_frame.gd")

# The posture Warden's fight as one plate (LEGIBILITY section 4): its name, four health
# chunks, the guard bar and one state glyph. It draws itself and reads one posture body (a
# Warden, or Brindle's hull); it draws nothing for one that is gone or fights on the plating rule. Every colour is a
# STATE_ROWS row or a role, and no number is drawn.
#
# A fight with phases (combat/fight_phases.gd, Andrew 23 Oct) also sets one diamond per phase
# in the plate's bottom rim: the live phase lit in the phase row's brass, spent phases
# cracked and dim, phases to come dark. At each turn the spent diamond cracks with a pop and
# two shards over the transition beat, and the next one lights. A fight without phases shows
# no diamonds, so a stage Warden's plate is unchanged.
#
# The plate is drawn in the hand of whoever made what it shows (LEGIBILITY section 14.3, ruling
# ek): Brindle's hull in the Fleet's brass bezel on iron oxide, and a rogue machine in a Rogue's
# stencil ticks on near black with its crew number stencilled in the Rogue face and no words: no
# pips, its health on the bar, the open glyph while it is vented. A Warden keeps the HUD panel.

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
# How far the phase diamonds hang below the panel: half a diamond, so they sit on the rim.
const PHASE_DROP := PHASE * 0.5
# The crack plays over the opening of the transition beat: the pop, then the shards fade.
const CRACK_SECONDS := 0.9
const CRACK_POP := 0.5
const LIGHT_SECONDS := 0.4
# A Warden's plate is in no maker's hand yet: it keeps the HUD panel it has always worn.
const NO_HAND := -1
# The serial that fixes a hand frame's quirks, so the plate looks the same on every redraw.
const SERIAL := 46
# A Rogue's crew number is stencilled one step up from the name.
const STENCIL := UiTokens.LABEL
# Reduced motion (Game.set_reduced_motion keeps it current): the crack shows at once, no pop or shards.
static var reduced_motion := false

var _warden: Node3D
var _events
var _glance_left := 0.0
# The fight's phases (a FightPhases, or anything with phase and phases), or null.
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


# Whether the plate shows anything: a live Warden on the posture rule, or a live rogue machine.
func active() -> bool:
	if (_warden != null or _events != null) and not is_instance_valid(_warden):
		unbind()
	if not is_instance_valid(_warden):
		return false
	var fights: bool = rogue() or (_warden.has_method("fight") and _warden.fight() == "posture")
	return fights and not _warden.is_dead()


# The hand the plate is drawn in: the Fleet's for Brindle's hull, a Rogue's for a rogue machine,
# else NO_HAND.
func hand() -> int:
	if rogue():
		return UiTokens.Hand.ROGUE
	if is_instance_valid(_warden) and _fleet_body():
		return UiTokens.Hand.FLEET
	return NO_HAND


# Whether the bound body is a rogue machine: one whose row carries a crew number.
func rogue() -> bool:
	return crew() != ""


# The rogue machine's crew number (Rogue.ROWS "crew"), the one mark its plate stencils; "" for any
# other body.
func crew() -> String:
	if not is_instance_valid(_warden):
		return ""
	var row = _warden.get("row")
	return String(row.get("crew", "")) if row is Dictionary else ""


# The one thing the plate says in words: the name, two words or fewer, and none on a Rogue's.
func drawn_words() -> Array:
	return Array(plate_name().split(" ", false))


# The one number the plate draws: a Rogue's crew number; "" on every other plate.
func drawn_number() -> String:
	return crew() if active() else ""


# Whether the plate keeps its name off while the arrival card says it (one voice at a time). The
# name is still plate_name(); only the drawing waits. The HUD above the plate owns the game.
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


# The bound body's name, whether or not its posture fight is live yet (the plate's width is set at bind).
func _name() -> String:
	# A rogue machine has no name on its plate, only its number. A stub boss names its Warden
	# after the world's boss row ("plate_name" meta); a stage Warden names itself by family; any
	# other posture body (Brindle's hull) is the boss arena's own row.
	if rogue():
		return ""
	if _warden.has_meta("plate_name"):
		return String(_warden.get_meta("plate_name"))
	if _fleet_body():
		return String(EventKinds.hud("boss_arena_entered"))
	var variant = _warden.get("variant")
	return Roster.warden_name(String(_warden.family), String(variant) if variant != null else "")


# Brindle's hull: a posture body that is neither a stage Warden (no family) nor a stub boss's.
func _fleet_body() -> bool:
	return not rogue() and not _warden.has_meta("plate_name") and _warden.get("family") == null


# Four pips, the first ones filled for each chunk left; the last filled one shows the
# crack mark when the next opening shatters it on any contact.
func pips() -> Array:
	var list: Array = []
	if not active() or rogue():
		return list
	var left: int = _warden.chunks_left()
	for i in BossPosture.CHUNKS:
		list.append({"filled": i < left, "cracked": i == left - 1 and _warden.chunk_cracked()})
	return list


# The bar's fill, 0 to 1: the guard, or the open core's time left while it is staggered; a
# rogue machine's health.
func bar_fraction() -> float:
	if not active():
		return 0.0
	if rogue():
		return clampf(float(_warden.hp) / maxf(float(_warden.max_hp), 1.0), 0.0, 1.0)
	if _warden.staggered():
		return clampf(_warden.stagger_left() / BossPosture.STAGGER_SECONDS, 0.0, 1.0)
	return clampf(_warden.posture() / BossPosture.FULL, 0.0, 1.0)


# The crack mark is live only while the core is open, when the verb works on it; a cracked
# core that is closed takes no shatter, so its mark is neutral.
func crack_color() -> Color:
	return crack_color_for(active() and _open())


# A banked fill belongs to the next phase, so it wears the phase diamonds' colour.
func bar_color() -> Color:
	if banking():
		return phase_color()
	return bar_color_for(active() and _open())


# Whether the core is open to the verb: a Warden or hull staggered, a rogue machine vented.
func _open() -> bool:
	return _warden.is_weak() if rogue() else _warden.staggered()


# Whether the bar shows hits banked toward the next phase: a hull boss's held phase.
func banking() -> bool:
	return active() and _warden.has_method("banking") and _warden.banking()


# Where the bank stops on the bar, 0 to 1; 0 when nothing banks.
func bank_cap() -> float:
	return clampf(_warden.bank_cap(), 0.0, 1.0) if banking() and _warden.has_method("bank_cap") else 0.0


# The same colours for a given open state, read by every other drawing of the fight (the
# ring on the ground round the Warden), so no second copy of the rule can drift.
static func crack_color_for(open: bool) -> Color:
	return EventKinds.state_color("chunk_shatter") if open else EventKinds.role_color("neutral")


static func bar_color_for(open: bool) -> Color:
	return EventKinds.state_color("open") if open else EventKinds.role_color("neutral")


# A pip's colour: the neutral role filled, the same colour at EMPTY_ALPHA when lost.
static func pip_color(filled: bool) -> Color:
	var neutral := EventKinds.role_color("neutral")
	return neutral if filled else _fade(neutral, EMPTY_ALPHA)


# The dark backing under a crack mark.
static func crack_backing() -> Color:
	return UiDraw.OUTLINE


# The state row the glyph shows: open while staggered, glancing for GLANCE_SECONDS after a
# glance on this Warden, else the posture step. A rogue machine shows the open glyph while it is
# vented and no glyph between.
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


# The phase count and the live phase; 1 and 0 for a fight without phases.
func phase_count() -> int:
	return int(_phases.phases) if _phases != null else 1


func phase() -> int:
	return int(_phases.phase) if _phases != null else 0


# Whether the plate sets phase diamonds: a fight of two or more phases.
func phased() -> bool:
	return active() and phase_count() > 1


# One diamond per phase: "spent" (cracked), "live" or "ahead"; empty for a fight without phases.
func phase_pips() -> Array:
	var list: Array = []
	if not phased():
		return list
	var now := phase()
	for i in phase_count():
		list.append("spent" if i + 1 < now else ("live" if i + 1 == now else "ahead"))
	return list


# Seconds since the last turn while its crack still plays, else -1.
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


# The width the name takes before the pips: NAME_WIDTH, or the name and a GAP when the name is longer
# ("Meltdown Warden" ran under its pips at NAME_WIDTH, PF-34).
func name_width() -> float:
	if rogue():
		return _stencil_face().get_string_size(crew(), HORIZONTAL_ALIGNMENT_LEFT, -1, STENCIL).x + GAP
	return maxf(NAME_WIDTH, UiDraw.width(_name(), FONT) + GAP) if is_instance_valid(_warden) else NAME_WIDTH


static func _stencil_face() -> Font:
	return UiFonts.face(UiTokens.Hand.ROGUE, true)


# The plate's size before any phase row: SIZE, wider by what this Warden's name needs, so the bar keeps its length.
# A Rogue's plate is narrower by its number's room and the pips it does not set.
func rest_size() -> Vector2:
	var pips_room := 0.0 if not rogue() else BossPosture.CHUNKS * (PIP + PIP_GAP) - PIP_GAP + GAP
	return SIZE + Vector2(name_width() - NAME_WIDTH - pips_room, 0.0)


# The plate grows by the diamonds' drop only while it sets them.
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
	var frame := Rect2(Vector2.ZERO, Vector2(size.x, SIZE.y))
	if which == NO_HAND:
		UiDraw.panel(self, frame)
	else:
		draw_style_box(frame_box(), frame)
	var mid := SIZE.y * 0.5
	if which == UiTokens.Hand.ROGUE:
		_hand_text(which, MARGIN, mid, crew())
	elif which == UiTokens.Hand.FLEET:
		if not name_held():
			_hand_text(which, MARGIN, mid, plate_name())
	elif not name_held():
		UiDraw.text(self, MARGIN, mid, plate_name(), FONT, neutral)
	var x := MARGIN + name_width()
	var drawn_pips := pips()
	for pip in drawn_pips:
		_draw_pip(Rect2(Vector2(x, mid - PIP * 0.5), Vector2(PIP, PIP)), pip, neutral)
		x += PIP + PIP_GAP
	if not drawn_pips.is_empty():
		x += GAP - PIP_GAP
	var bar := Rect2(Vector2(x, mid - BAR_HEIGHT * 0.5), Vector2(size.x - MARGIN - GLYPH - GAP - x, BAR_HEIGHT))
	UiDraw.bar(self, bar, bar_fraction(), bar_color())
	for tick in TICKS:
		var tx: float = bar.position.x + bar.size.x * tick
		draw_line(Vector2(tx, bar.position.y), Vector2(tx, bar.end.y), UiDraw.OUTLINE, 2.0)
	var cap := bank_cap()
	if cap > 0.0:
		# The bank's stop: a post in the phase colour, standing proud of the bar.
		var cx: float = bar.position.x + bar.size.x * cap
		draw_line(Vector2(cx, bar.position.y - BANK_POST), Vector2(cx, bar.end.y + BANK_POST), crack_backing(), 5.0)
		draw_line(Vector2(cx, bar.position.y - BANK_POST), Vector2(cx, bar.end.y + BANK_POST), phase_color(), 2.0)
	if glyph_id() != "":
		var row := EventKinds.state_row(glyph_id())
		var rect := Rect2(Vector2(size.x - MARGIN - GLYPH, mid - GLYPH * 0.5), Vector2(GLYPH, GLYPH))
		draw_texture_rect(Icons.shape(String(row.get("shape", "none"))), rect, false, glyph_color())
	_draw_phases()


# The hand frame under the plate's marks, or null for a Warden's HUD panel.
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


# A hand's mark in its own ink, its left edge at x and its middle at y, with the HUD's outline: a Rogue's
# stencilled number, or a name in the hand's words face.
func _hand_text(which: int, x: float, y: float, value: String) -> void:
	var stencil := which == UiTokens.Hand.ROGUE
	var font := _stencil_face() if stencil else UiFonts.face(which)
	var font_size := STENCIL if stencil else FONT
	var color: Color = UiTokens.HANDS[which].ink
	var at := Vector2(x, y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5)
	draw_string_outline(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 6, UiDraw.OUTLINE)
	draw_string(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


# The live phase's colour: the boss_phase_changed row's brass.
static func phase_color() -> Color:
	return EventKinds.color("boss_phase_changed")


# Diamond i's drawn scale: the spent one pops while it cracks, the newly lit one grows in;
# 1 at rest and always 1 under reduced motion.
func diamond_scale(i: int) -> float:
	if reduced_motion or _turn_age < 0.0:
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
		if just_spent and not reduced_motion:
			# Two shards fly off and fade over the crack.
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
		# A dark backing keeps the neutral mark readable on a neutral filled pip.
		draw_polyline(line, crack_backing(), 4.5)
		draw_polyline(line, crack_color(), 2.5)
