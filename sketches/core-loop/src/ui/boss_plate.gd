extends Control

const BossPosture := preload("res://src/combat/boss_posture.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Icons := preload("res://src/ui/icons.gd")
const Roster := preload("res://src/combat/roster.gd")
const UiDraw := preload("res://src/ui/ui_draw.gd")

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

const SIZE := Vector2(420.0, 44.0)
const GLANCE_SECONDS := 0.6
const TICKS := [0.25, 0.5, 0.75]
const FONT := 17
const MARGIN := 14.0
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
# Reduced motion (Game.set_reduced_motion keeps it current): the crack shows at once, no pop or shards.
static var reduced_motion := false

var _warden: Node3D
var _events
var _glance_left := 0.0
# The fight's phases (a FightPhases, or anything with phase and phases), or null.
var _phases
var _seen_phase := 0
var _turn_age := -1.0


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
	_fit()
	queue_redraw()


# Whether the plate shows anything: a live Warden on the posture rule.
func active() -> bool:
	if (_warden != null or _events != null) and not is_instance_valid(_warden):
		unbind()
	return is_instance_valid(_warden) and _warden.has_method("fight") and not _warden.is_dead() and _warden.fight() == "posture"


# The one thing the plate says in words: the name, two words or fewer. Nothing is drawn
# as a number.
func drawn_words() -> Array:
	return Array(plate_name().split(" ", false))


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
	if not active():
		return ""
	# A stub boss names its Warden after the world's boss row ("plate_name" meta); a stage
	# Warden names itself by family; any other posture body (Brindle's hull) is the boss
	# arena's own row.
	if _warden.has_meta("plate_name"):
		return String(_warden.get_meta("plate_name"))
	if _warden.get("family") == null:
		return String(EventKinds.hud("boss_arena_entered"))
	var variant = _warden.get("variant")
	return Roster.warden_name(String(_warden.family), String(variant) if variant != null else "")


# Four pips, the first ones filled for each chunk left; the last filled one shows the
# crack mark when the next opening shatters it on any contact.
func pips() -> Array:
	var list: Array = []
	if not active():
		return list
	var left: int = _warden.chunks_left()
	for i in BossPosture.CHUNKS:
		list.append({"filled": i < left, "cracked": i == left - 1 and _warden.chunk_cracked()})
	return list


# The bar's fill, 0 to 1: the guard, or the open core's time left while it is staggered.
func bar_fraction() -> float:
	if not active():
		return 0.0
	if _warden.staggered():
		return clampf(_warden.stagger_left() / BossPosture.STAGGER_SECONDS, 0.0, 1.0)
	return clampf(_warden.posture() / BossPosture.FULL, 0.0, 1.0)


# The crack mark is live only while the core is open, when the verb works on it; a cracked
# core that is closed takes no shatter, so its mark is neutral.
func crack_color() -> Color:
	return crack_color_for(active() and _warden.staggered())


# A banked fill belongs to the next phase, so it wears the phase diamonds' colour.
func bar_color() -> Color:
	if banking():
		return phase_color()
	return bar_color_for(active() and _warden.staggered())


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
# glance on this Warden, else the posture step.
func glyph_id() -> String:
	if not active():
		return ""
	if _warden.staggered():
		return "open"
	return "glancing" if _glance_left > 0.0 else "posture_step"


func glyph_color() -> Color:
	return EventKinds.state_color(glyph_id()) if active() else EventKinds.role_color("neutral")


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


# The plate grows by the diamonds' drop only while it sets them.
func _fit() -> void:
	var want := SIZE + (Vector2(0.0, PHASE_DROP) if _phases != null and phase_count() > 1 else Vector2.ZERO)
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
	UiDraw.panel(self, Rect2(Vector2.ZERO, SIZE))
	var mid := SIZE.y * 0.5
	if not name_held():
		UiDraw.text(self, MARGIN, mid, plate_name(), FONT, neutral)
	var x := MARGIN + NAME_WIDTH
	for pip in pips():
		_draw_pip(Rect2(Vector2(x, mid - PIP * 0.5), Vector2(PIP, PIP)), pip, neutral)
		x += PIP + PIP_GAP
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
	var row := EventKinds.state_row(glyph_id())
	var rect := Rect2(Vector2(size.x - MARGIN - GLYPH, mid - GLYPH * 0.5), Vector2(GLYPH, GLYPH))
	draw_texture_rect(Icons.shape(String(row.get("shape", "none"))), rect, false, glyph_color())
	_draw_phases()


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
	var x := (SIZE.x - span) * 0.5 + PHASE * 0.5
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
