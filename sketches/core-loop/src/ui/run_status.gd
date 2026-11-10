extends Control

const EventKinds := preload("res://src/core/event_kinds.gd")
const Icons := preload("res://src/ui/icons.gd")
const UiDraw := preload("res://src/ui/ui_draw.gd")

# The run at a glance, top left: one pip per stage of the current world (cleared, current, still ahead) and
# the Fleet's tag for that world's boss arena, then the difficulty under them as rising steps
# and their word, the lowest step always lit and one more for each threat tier the director
# can raise. The run clock is not shown in play.
#
# The difficulty was a filled, notched bar in the threat colour. A filled red bar in a status
# corner is a health bar in every other game: of six blind readers of one still (10 Nov 2026)
# six named it as their health and none the real bar. Drawn as steps (a level, like a signal
# meter) none of nine did, and all nine found the health bar.

const PIP := 18.0
const PIP_STEP := 24.0
const ROW_GAP := 8.0
const BAR_X := 28.0
const THREAT_TIERS := 2
const STEP := Vector2(22.0, 13.0)
const STEP_GAP := 5.0
# How tall a step's low (left) edge is against its high one's place on the ramp, so the
# first step is a wedge with a foot and not a point.
const STEP_FOOT := 0.35
# The steps' own word, in the threat colour, the word the "Threat rising" toast uses. With no
# word one blind reader of nine guessed threat (most said signal, heat or speed); with it
# three of three read "how dangerous things are".
const THREAT_WORD := "THREAT"
const WORD_FONT := 13
const WORD_GAP := 2.0
const PLATE_WIDTH := 150.0
const PLATE_PAD := 6.0

var stage := 1
var stages := 3
var has_boss := false
var in_arena := false
var threat := 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(maxf(PLATE_WIDTH, word_left() + UiDraw.width(THREAT_WORD, WORD_FONT)), PIP + ROW_GAP + 9.0)
	size = custom_minimum_size


func set_status(stage_now: int, stage_count: int, boss_exists: bool, arena: bool, threat_tier: int) -> void:
	stage = stage_now
	stages = stage_count
	has_boss = boss_exists
	in_arena = arena
	threat = threat_tier
	queue_redraw()


func _draw() -> void:
	UiDraw.panel(self, Rect2(Vector2(-PLATE_PAD, -PLATE_PAD), Vector2(size.x, size.y) + Vector2(PLATE_PAD, PLATE_PAD) * 2.0))
	var cleared_color := EventKinds.color("stage_cleared")
	var current_color := EventKinds.color("stage_entered")
	var diamond := Icons.shape("diamond")
	for i in stages:
		var at := Vector2(i * PIP_STEP, 0.0)
		var rect := Rect2(at, Vector2(PIP, PIP))
		var n := i + 1
		if n < stage or in_arena:
			draw_texture_rect(diamond, rect, false, cleared_color)
		elif n == stage:
			draw_texture_rect(diamond, rect, false, current_color)
			draw_arc(rect.get_center(), PIP * 0.72, 0.0, TAU, 20, Color(current_color, 0.8), 1.5)
		else:
			draw_texture_rect(diamond, rect, false, Color(current_color, 0.25))
	if has_boss:
		var boss_color := EventKinds.color("boss_arena_entered")
		draw_texture_rect(Icons.texture("fac_fleet"), Rect2(Vector2(stages * PIP_STEP, -2.0), Vector2(PIP + 4.0, PIP + 4.0)), false,
			Icons.tint("fac_fleet", boss_color if in_arena else Color(boss_color, 0.3)))

	var threat_color := EventKinds.color("threat_rose")
	var foot := size.y - 1.0
	draw_texture_rect(Icons.texture("res_difficulty"), Rect2(Vector2(4.0, foot - 12.0), Vector2(14.0, 14.0)), false, Icons.tint("res_difficulty", threat_color))
	for i in steps():
		var step := step_points(i, Vector2(BAR_X, foot))
		var ring := PackedVector2Array(step)
		ring.append(step[0])
		draw_colored_polygon(step, threat_color if i < steps_lit() else UiDraw.TRACK)
		draw_polyline(ring, UiDraw.OUTLINE, 1.5, true)
	UiDraw.text(self, word_left(), foot - STEP.y * 0.5, THREAT_WORD, WORD_FONT, threat_color)


static func word_left() -> float:
	return BAR_X + steps() * (STEP.x + STEP_GAP) + WORD_GAP


func drawn_words() -> PackedStringArray:
	return PackedStringArray([THREAT_WORD])


static func steps() -> int:
	return THREAT_TIERS + 1


# The lowest step is the run's own difficulty; each threat tier lights one more.
func steps_lit() -> int:
	return clampi(threat, 0, THREAT_TIERS) + 1


# Step `i` of the ramp, its foot's left end at `origin` plus the steps before it: foot left,
# top left, top right, foot right. Each step starts a little under where the last one ended.
static func step_points(i: int, origin: Vector2) -> PackedVector2Array:
	var left := origin.x + i * (STEP.x + STEP_GAP)
	var low := STEP.y * (i + STEP_FOOT) / steps()
	var high := STEP.y * (i + 1.0) / steps()
	return PackedVector2Array([Vector2(left, origin.y), Vector2(left, origin.y - low), Vector2(left + STEP.x, origin.y - high), Vector2(left + STEP.x, origin.y)])
