extends Control

const Augments := preload("res://src/augments.gd")
const AimStyle := preload("res://src/aim_style.gd")

const RING := 13.0
const DIAMOND := 15.0

var player
var camera: Camera3D

var _word: Label


func setup(player_ref, camera_ref: Camera3D) -> void:
	player = player_ref
	camera = camera_ref
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_word = Label.new()
	_word.add_theme_font_size_override("font_size", 15)
	_word.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	_word.add_theme_constant_override("outline_size", 5)
	add_child(_word)


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
	var word: String = style["word"]
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
	if word != "":
		var reach: float = (aim["point"] as Vector3).distance_to(player.ball_position())
		_word.text = "%s  %.0f m" % [word, reach]
	else:
		_word.text = ""
	_word.add_theme_color_override("font_color", color)
	_word.position = centre + Vector2(-_word.size.x * 0.5, RING + 10.0)
