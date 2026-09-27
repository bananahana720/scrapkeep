extends Label

const ScreenRegions := preload("res://src/ui/screen_regions.gd")

# A screen-space prompt attached to a point in the world, such as a reward gate's
# offer or a fabricator's price. The owner makes one, sets its text and colour and
# names its anchor; the HUD places every prompt inside the prompts band each frame
# (ScreenRegions), so a prompt never reaches the objective or the toasts however
# close or high its anchor is.

# The node the prompt follows, the offset above it, and how far away it still shows.
var anchor: Node3D
var offset := Vector3.ZERO
var reach := 60.0


func _init() -> void:
	add_to_group(ScreenRegions.PROMPT_GROUP)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	custom_minimum_size = Vector2(ScreenRegions.PROMPT_WIDTH, 0.0)
	add_theme_font_size_override("font_size", 18)
	add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	add_theme_constant_override("outline_size", 6)


func attach(anchor_node: Node3D, anchor_offset: Vector3, show_within: float) -> void:
	anchor = anchor_node
	offset = anchor_offset
	reach = show_within


func anchor_point() -> Vector3:
	return anchor.global_position + offset if is_instance_valid(anchor) and anchor.is_inside_tree() else Vector3.INF
