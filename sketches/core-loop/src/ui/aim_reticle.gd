extends Control

const Augments := preload("res://src/movement/augments.gd")
const AimStyle := preload("res://src/movement/aim_style.gd")

const RING := 13.0
const DIAMOND := 15.0

# The reticle carries no words: its shape and colour are the aim state (AimStyle), and
# a grapple target in reach adds the right-mouse key glyph beside it (key_glyphs.gd).
var player
var camera: Camera3D


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
	match style["shape"]:
		"cross":
			draw_line(centre - Vector2(8.0, 0.0), centre + Vector2(8.0, 0.0), color, 2.0)
			draw_line(centre - Vector2(0.0, 8.0), centre + Vector2(0.0, 8.0), color, 2.0)
		"ring":
			draw_arc(centre, RING, 0.0, TAU, 40, color, 2.5)
			draw_circle(centre, 2.5, color)
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
