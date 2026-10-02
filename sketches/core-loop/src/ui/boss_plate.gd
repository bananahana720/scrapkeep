extends Control

const BossPosture := preload("res://src/combat/boss_posture.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Icons := preload("res://src/ui/icons.gd")
const Roster := preload("res://src/combat/roster.gd")
const UiDraw := preload("res://src/ui/ui_draw.gd")

# The posture Warden's fight as one plate (LEGIBILITY section 4): its name, four health
# chunks, the guard bar and one state glyph. It draws itself and reads one Warden; it
# draws nothing for a Warden that is gone or fights on the plating rule. Every colour is a
# STATE_ROWS row or a role, and no number is drawn.

const SIZE := Vector2(420.0, 44.0)
const GLANCE_SECONDS := 0.6
const NAMES := {Roster.REACTOR: "Reactor Warden", Roster.SWARM: "Hive Warden", Roster.MIND: "Mind Warden"}
const NAME_FALLBACK := "Warden"
const TICKS := [0.25, 0.5, 0.75]
const FONT := 17
const MARGIN := 14.0
const NAME_WIDTH := 138.0
const PIP := 16.0
const PIP_GAP := 6.0
const BAR_HEIGHT := 12.0
const GLYPH := 26.0
const GAP := 10.0
const EMPTY_ALPHA := 0.35

var _warden: Node3D
var _events
var _glance_left := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = SIZE
	size = SIZE


func bind(warden: Node3D) -> void:
	unbind()
	_warden = warden
	_glance_left = 0.0
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
	queue_redraw()


# Whether the plate shows anything: a live Warden on the posture rule.
func active() -> bool:
	if _warden != null and not is_instance_valid(_warden):
		unbind()
	return is_instance_valid(_warden) and _warden.has_method("fight") and not _warden.is_dead() and _warden.fight() == "posture"


# The one thing the plate says in words: the name, two words or fewer. Nothing is drawn
# as a number.
func drawn_words() -> Array:
	return Array(plate_name().split(" ", false))


func plate_name() -> String:
	return String(NAMES.get(_warden.family, NAME_FALLBACK)) if active() else ""


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
	return EventKinds.state_color("chunk_shatter") if active() and _warden.staggered() else EventKinds.role_color("neutral")


func bar_color() -> Color:
	return EventKinds.state_color("open") if active() and _warden.staggered() else EventKinds.role_color("neutral")


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


func advance(delta: float) -> void:
	_glance_left = maxf(0.0, _glance_left - delta)


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
	UiDraw.panel(self, Rect2(Vector2.ZERO, size))
	var mid := size.y * 0.5
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
	var row := EventKinds.state_row(glyph_id())
	var rect := Rect2(Vector2(size.x - MARGIN - GLYPH, mid - GLYPH * 0.5), Vector2(GLYPH, GLYPH))
	draw_texture_rect(Icons.shape(String(row.get("shape", "none"))), rect, false, glyph_color())


func _draw_pip(rect: Rect2, pip: Dictionary, color: Color) -> void:
	if pip["filled"]:
		draw_rect(rect, color)
	else:
		draw_rect(rect, _fade(color, EMPTY_ALPHA), false, 2.0)
	if pip["cracked"]:
		var c := rect.get_center()
		var line := PackedVector2Array([c + Vector2(-3.0, -PIP * 0.5), c + Vector2(2.0, -2.0), c + Vector2(-2.0, 2.0), c + Vector2(3.0, PIP * 0.5)])
		# A dark backing keeps the neutral mark readable on a neutral filled pip.
		draw_polyline(line, UiDraw.OUTLINE, 4.5)
		draw_polyline(line, crack_color(), 2.5)
