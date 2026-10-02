extends Control

const AimStyle := preload("res://src/movement/aim_style.gd")
const Augments := preload("res://src/movement/augments.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")

const RING := 13.0
const DIAMOND := 15.0
const BRACKET := 17.0
const BRACKET_TICK := 8.0
const GAUGE_RING := 24.0
const GAUGE_WIDTH := 3.0
const HARPOON_RING := 19.0
const HARPOON_WIDTH := 2.5
const DRY_SHAKE := 3.0
const DRY_SHAKE_TIME := 0.25
const SHAKE_HZ := 40.0

# The reticle carries no words: its shape and colour are the aim state (AimStyle), and
# a grapple target in reach adds the right-mouse key glyph beside it (key_glyphs.gd).
# While a hold-gauge-release shot charges, a ring round it fills clockwise from twelve,
# linearly, in the class colour, and closes when the gauge is full.
var player
var camera: Camera3D
var gauge := 0.0
var gauge_color := Color.WHITE
# The inner ring is the harpoon's readiness: 1 when a press would bite, filling as the hook docks
# after a smash. It reads the kit's own rewind, so a kill that refunds it fills the ring at once.
var harpoon_fill := 1.0
var _shake_left := 0.0
var _shake_clock := 0.0


func setup(player_ref, camera_ref: Camera3D) -> void:
	player = player_ref
	camera = camera_ref
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if player.get("events") != null:
		player.events.line_state_changed.connect(_on_line_state)


# The only thing the reticle knows is the aim record the fire action also uses.
func reading() -> Dictionary:
	return player.kit.aim


func _process(delta: float) -> void:
	step(delta)
	queue_redraw()


func step(delta: float) -> void:
	_shake_left = maxf(0.0, _shake_left - delta)
	_shake_clock += delta
	harpoon_fill = harpoon_readiness()


func _on_line_state(state: String, _target: Node3D, _at: Vector3, _cause: String) -> void:
	if state == "dry_fire":
		_shake_left = DRY_SHAKE_TIME
		_shake_clock = 0.0


# One minus the rewind left over the rewind time, from the kit.
func harpoon_readiness() -> float:
	var total: float = player.tuning.f("harpoon_rewind") if player.get("tuning") != null else 0.0
	if total <= 0.0:
		return 1.0
	return clampf(1.0 - player.kit.rewind_left / total, 0.0, 1.0)


# How far a dry fire has pushed the reticle off the centre, in pixels: at most DRY_SHAKE.
func shake_offset() -> Vector2:
	if _shake_left <= 0.0:
		return Vector2.ZERO
	return Vector2(sin(_shake_clock * TAU * SHAKE_HZ) * DRY_SHAKE, 0.0)


# The aim found nothing in reach but the centre ray meets a surface beyond the line's reach.
func _out_of_range(aim: Dictionary) -> bool:
	if camera == null or not camera.is_inside_tree() or not player.kit.on(Augments.GRAPPLE):
		return false
	if aim.get("state", Augments.AIM_NONE) != Augments.AIM_NONE:
		return false
	var from := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from - camera.global_basis.z * Augments.AIM_CAST,
		Augments.WORLD_MASK | Augments.ENEMY_MASK)
	var hit: Dictionary = camera.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and (hit["position"] as Vector3).distance_to(player.ball_position()) > player.grapple_range()


func _draw() -> void:
	if player == null:
		return
	var aim := reading()
	var style := AimStyle.of(aim, _out_of_range(aim))
	var color: Color = style["color"]
	# The reticle marks the camera's centre ray, which is the viewport centre whatever
	# size layout gave this control.
	var centre := get_viewport_rect().size * 0.5 + shake_offset()
	if player.kit.on(Augments.GRAPPLE):
		var ready := EventKinds.line_color("locked")
		draw_arc(centre, HARPOON_RING, 0.0, TAU, 48, Color(ready, 0.25), HARPOON_WIDTH)
		draw_arc(centre, HARPOON_RING, -PI * 0.5, -PI * 0.5 + TAU * harpoon_fill, 48, ready, HARPOON_WIDTH)
	if gauge > 0.0:
		draw_arc(centre, GAUGE_RING, 0.0, TAU, 48, Color(0.0, 0.0, 0.0, 0.55), GAUGE_WIDTH + 2.0)
		draw_arc(centre, GAUGE_RING, -PI * 0.5, -PI * 0.5 + TAU * clampf(gauge, 0.0, 1.0), 48, gauge_color,
			GAUGE_WIDTH + (1.5 if gauge >= 1.0 else 0.0))
	match style["shape"]:
		"cross":
			draw_line(centre - Vector2(8.0, 0.0), centre + Vector2(8.0, 0.0), color, 2.0)
			draw_line(centre - Vector2(0.0, 8.0), centre + Vector2(0.0, 8.0), color, 2.0)
		"ring":
			draw_circle(centre, RING, Color(color, 0.3))
			draw_arc(centre, RING, 0.0, TAU, 40, color, 2.5)
			draw_circle(centre, 2.5, color)
		"hollow_ring":
			draw_arc(centre, RING, 0.0, TAU, 40, color, 2.5)
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
