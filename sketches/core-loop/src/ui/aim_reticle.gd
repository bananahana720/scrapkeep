extends Control

const AimStyle := preload("res://src/movement/aim_style.gd")

const RING := 13.0
const DIAMOND := 15.0
const BRACKET := 17.0
const BRACKET_TICK := 8.0
const GAUGE_RING := 24.0
const GAUGE_WIDTH := 3.0

# The reticle carries no words: its shape and colour are the aim state (AimStyle), and
# a grapple target in reach adds the right-mouse key glyph beside it (key_glyphs.gd).
# While a hold-gauge-release shot charges, a ring round it fills clockwise from twelve,
# linearly, in the class colour, and closes when the gauge is full.
var player
var camera: Camera3D
var gauge := 0.0
var gauge_color := Color.WHITE


func setup(player_ref, camera_ref: Camera3D) -> void:
	player = player_ref
	camera = camera_ref
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


# The only thing the reticle knows is the aim record the fire action also uses.
func reading() -> Dictionary:
	return player.kit.aim


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if player == null:
		return
	var aim := reading()
	var style := AimStyle.of(aim)
	var color: Color = style["color"]
	# The reticle marks the camera's centre ray, which is the viewport centre whatever
	# size layout gave this control.
	var centre := get_viewport_rect().size * 0.5
	if gauge > 0.0:
		draw_arc(centre, GAUGE_RING, 0.0, TAU, 48, Color(0.0, 0.0, 0.0, 0.55), GAUGE_WIDTH + 2.0)
		draw_arc(centre, GAUGE_RING, -PI * 0.5, -PI * 0.5 + TAU * clampf(gauge, 0.0, 1.0), 48, gauge_color,
			GAUGE_WIDTH + (1.5 if gauge >= 1.0 else 0.0))
	match style["shape"]:
		"cross":
			draw_line(centre - Vector2(8.0, 0.0), centre + Vector2(8.0, 0.0), color, 2.0)
			draw_line(centre - Vector2(0.0, 8.0), centre + Vector2(0.0, 8.0), color, 2.0)
		"ring":
			draw_arc(centre, RING, 0.0, TAU, 40, color, 2.5)
			draw_circle(centre, 2.5, color)
		"brackets":
			# An enemy the harpoon would bite: four corner ticks at the body, and the same snap line
			# as the magnet. The shape, not the colour, says a body.
			var at := centre
			if camera != null and not camera.is_position_behind(aim["point"]):
				at = camera.unproject_position(aim["point"])
			draw_line(centre, at, Color(color, 0.6), 1.5)
			draw_circle(centre, 2.0, color)
			for corner in [Vector2(1.0, 1.0), Vector2(-1.0, 1.0), Vector2(1.0, -1.0), Vector2(-1.0, -1.0)]:
				var tip: Vector2 = at + corner * BRACKET
				draw_line(tip, tip - Vector2(corner.x * BRACKET_TICK, 0.0), color, 2.5)
				draw_line(tip, tip - Vector2(0.0, corner.y * BRACKET_TICK), color, 2.5)
		"diamond":
			var at := centre
			if camera != null and not camera.is_position_behind(aim["point"]):
				at = camera.unproject_position(aim["point"])
			# The snap line shows the magnet pulling the hook off your aim onto the target.
			draw_line(centre, at, Color(color, 0.6), 1.5)
			draw_circle(centre, 2.0, color)
			var points := PackedVector2Array([
				at + Vector2(0.0, -DIAMOND), at + Vector2(DIAMOND, 0.0),
				at + Vector2(0.0, DIAMOND), at + Vector2(-DIAMOND, 0.0), at + Vector2(0.0, -DIAMOND)])
			draw_polyline(points, color, 2.5)
