extends Control

const EventKinds := preload("res://src/core/event_kinds.gd")
const Icons := preload("res://src/ui/icons.gd")
const UiDraw := preload("res://src/ui/ui_draw.gd")

# The run at a glance, top left: one pip per stage (cleared, current, still ahead) and
# the Fleet's tag for Brindle's arena, then the run clock in mono digits with the
# difficulty as a notched bar under it, one notch per threat tier the director can
# raise. Time is the self-challenge Andrew plays against.

const PIP := 18.0
const PIP_STEP := 24.0
const ICON := 22.0
const FONT := 20
const ROW_GAP := 8.0
const DIFFICULTY_BAR := Vector2(96.0, 7.0)
const THREAT_TIERS := 2
const PLATE_PAD := 6.0

var stage := 1
var stages := 3
var has_boss := false
var in_arena := false
var seconds := 0.0
var threat := 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(150.0, PIP + ROW_GAP + ICON + ROW_GAP * 0.5 + DIFFICULTY_BAR.y + 2.0)
	size = custom_minimum_size


func set_status(stage_now: int, stage_count: int, boss_exists: bool, arena: bool, run_seconds: float, threat_tier: int) -> void:
	stage = stage_now
	stages = stage_count
	has_boss = boss_exists
	in_arena = arena
	seconds = run_seconds
	threat = threat_tier
	queue_redraw()


func time_text() -> String:
	return "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]


func drawn_words() -> PackedStringArray:
	return PackedStringArray([time_text()])


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

	var y := PIP + ROW_GAP + ICON * 0.5
	var timer_color: Color = EventKinds.UI_ROWS["run_timer"]["color"]
	draw_texture_rect(Icons.texture("res_timer"), Rect2(Vector2(0.0, y - ICON * 0.5), Vector2(ICON, ICON)), false, Icons.tint("res_timer", timer_color))
	UiDraw.text(self, ICON + 6.0, y, time_text(), FONT, timer_color, true)
	var threat_color := EventKinds.color("threat_rose")
	var bar := Rect2(Vector2(ICON + 6.0, y + ICON * 0.5 + ROW_GAP * 0.5), DIFFICULTY_BAR)
	draw_texture_rect(Icons.texture("res_difficulty"), Rect2(Vector2(4.0, bar.position.y - 3.0), Vector2(14.0, 14.0)), false, Icons.tint("res_difficulty", threat_color))
	UiDraw.bar(self, bar, float(threat) / THREAT_TIERS, threat_color)
	for i in range(1, THREAT_TIERS):
		var notch := bar.position.x + bar.size.x * i / THREAT_TIERS
		draw_line(Vector2(notch, bar.position.y - 2.0), Vector2(notch, bar.end.y + 2.0), UiDraw.OUTLINE, 2.0)
