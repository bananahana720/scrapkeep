extends Control

const EventKinds := preload("res://src/core/event_kinds.gd")
const UiDraw := preload("res://src/ui/ui_draw.gd")
const Parts := preload("res://src/build/parts.gd")

# The name of a part just gained, riding above the ball for SHOW_SECONDS of simulated time
# in the amber role colour: the first NAME_WORDS words of its name, so a pickup is read
# where the eye already is and needs no toast. A second pickup replaces the first.

const SHOW_SECONDS := 1.2
const NAME_WORDS := 2
const FONT := 20
const FADE := 0.25
const LIFT := Vector2(0.0, -64.0)

var text := ""
var left := 0.0
var _at := Vector2.ZERO


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


# The words shown for a part id: the first two words of its name.
static func name_of(part_id: String) -> String:
	var named := String(Parts.token(part_id).get("name", part_id.replace("_", " ").capitalize()))
	var words: PackedStringArray = named.split(" ", false)
	return " ".join(words.slice(0, NAME_WORDS))


func show_part(part_id: String) -> void:
	text = name_of(part_id)
	left = SHOW_SECONDS
	visible = true
	queue_redraw()


# Simulated seconds, from the HUD's physics tick.
func step(delta: float) -> void:
	if left <= 0.0:
		return
	left = maxf(0.0, left - delta)
	if left == 0.0:
		text = ""
		visible = false
	queue_redraw()


# Where the ball is on screen; the name rides above it.
func follow(ball_screen: Vector2) -> void:
	var at := (ball_screen + LIFT).round()
	if at != _at:
		_at = at
		queue_redraw()


func drawn_words() -> PackedStringArray:
	return PackedStringArray([text]) if left > 0.0 else PackedStringArray()


func _draw() -> void:
	if left <= 0.0:
		return
	var color := EventKinds.role_color("amber")
	color.a = clampf(left / FADE, 0.0, 1.0)
	var width := UiDraw.width(text, FONT)
	UiDraw.text(self, _at.x - width * 0.5, _at.y, text, FONT, color)
