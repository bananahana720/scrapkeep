extends Control

const SpeedTier := preload("res://src/movement/speed_tier.gd")
const UiDraw := preload("res://src/ui/ui_draw.gd")

# The speed tier as chevrons: none lit at walk, one at cruise, two fast, three blazing,
# each tier in its own SpeedTier colour, so speed reads by count before colour.

const CHEVRON := 24.0
const STEP := 16.0
const SLOTS := 3

var tier := 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(CHEVRON + STEP * (SLOTS - 1), CHEVRON)
	size = custom_minimum_size


func set_tier(value: int) -> void:
	if value != tier:
		tier = value
		queue_redraw()


func _draw() -> void:
	var lit: Color = SpeedTier.COLORS[clampi(tier, 0, SpeedTier.COLORS.size() - 1)]
	for i in SLOTS:
		var tint := lit if i < tier else Color(0.8, 0.82, 0.85, 0.22)
		var x := i * STEP + CHEVRON * 0.3
		var arm := PackedVector2Array([Vector2(x, CHEVRON * 0.15), Vector2(x + CHEVRON * 0.4, CHEVRON * 0.5), Vector2(x, CHEVRON * 0.85)])
		draw_polyline(arm, UiDraw.OUTLINE, 7.0)
		draw_polyline(arm, tint, 4.0)
