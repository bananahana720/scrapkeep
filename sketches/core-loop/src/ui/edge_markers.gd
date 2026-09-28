extends Control

const EventKinds := preload("res://src/core/event_kinds.gd")
const Icons := preload("res://src/ui/icons.gd")
const ScreenRegions := preload("res://src/ui/screen_regions.gd")

# Edge markers: while the Warden (or the beacon, once it has no Warden) or an open
# reward gate is off screen, a chevron on the edge of the play view points at it, with
# its objective icon behind. Closer targets draw bigger. No words: the icon and the
# colour are the target's own event_kinds row.

const SIDE_INSET := 0.035
const BAND_CLEARANCE := 16.0
const MIN_SIZE := 13.0
const MAX_SIZE := 30.0
const NEAR := 25.0
const FAR := 180.0

var game
var gate_points: Array[Vector3] = []
var _shown: Array[Dictionary] = []


func setup(game_ref) -> void:
	game = game_ref
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.events.reward_offered.connect(func(offers: Array):
		gate_points.clear()
		for offer in offers:
			gate_points.append(offer["at"]))
	game.events.flow_changed.connect(func(state: String):
		if state != "gates":
			gate_points.clear())


# What the markers point at now: {at, kind, icon}, kind naming the event_kinds row.
func targets() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var flow = game.flow
	match flow.state_name():
		"stage", "beacon":
			if flow.sealed and is_instance_valid(flow.warden):
				out.append({"at": flow.warden.global_position, "kind": "warden_engaged", "icon": "obj_warden"})
			elif game.beacon != null:
				out.append({"at": game.beacon.global_position, "kind": "beacon_charge_changed", "icon": "obj_beacon"})
		"gates":
			for at in gate_points:
				out.append({"at": at, "kind": "reward_offered", "icon": "obj_gate"})
	return out


# The play view markers stay inside: clear of the top, toast and bottom bands.
static func view_rect(size: Vector2) -> Rect2:
	var top := ScreenRegions.rect("toasts", size).end.y + BAND_CLEARANCE
	var bottom := ScreenRegions.rect("bottom", size).position.y - BAND_CLEARANCE
	var inset := size.x * SIDE_INSET
	return Rect2(inset, top, size.x - 2.0 * inset, bottom - top)


# One record per off-screen target: {at (screen), dir, size, color, icon}.
func markers(size: Vector2) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if game == null or not game.flow.in_play():
		return out
	var cam: Camera3D = game.camera.cam
	var view := view_rect(size)
	var screen := Rect2(Vector2.ZERO, size)
	var centre := size * 0.5
	var ball: Vector3 = game.player.ball_position()
	for target in targets():
		var at: Vector3 = target["at"]
		var behind := cam.is_position_behind(at)
		var projected := cam.unproject_position(at) if not behind else Vector2.ZERO
		if not behind and screen.has_point(projected):
			continue
		var dir: Vector2
		if behind:
			var local := cam.global_transform.affine_inverse() * at
			dir = Vector2(local.x, -local.y)
			if dir.length() < 0.001:
				dir = Vector2.DOWN
		else:
			dir = projected - centre
		dir = dir.normalized()
		var near := clampf((ball.distance_to(at) - NEAR) / (FAR - NEAR), 0.0, 1.0)
		out.append({"at": _on_edge(view, centre, dir), "dir": dir, "size": lerpf(MAX_SIZE, MIN_SIZE, near),
			"color": EventKinds.color(target["kind"]), "icon": target["icon"]})
	return out


static func _on_edge(view: Rect2, centre: Vector2, dir: Vector2) -> Vector2:
	var reach := INF
	if dir.x > 0.0001:
		reach = minf(reach, (view.end.x - centre.x) / dir.x)
	elif dir.x < -0.0001:
		reach = minf(reach, (view.position.x - centre.x) / dir.x)
	if dir.y > 0.0001:
		reach = minf(reach, (view.end.y - centre.y) / dir.y)
	elif dir.y < -0.0001:
		reach = minf(reach, (view.position.y - centre.y) / dir.y)
	return centre + dir * reach


func _process(_delta: float) -> void:
	if game == null:
		return
	var now := markers(get_viewport_rect().size)
	if now != _shown:
		_shown = now
		queue_redraw()


func _draw() -> void:
	for marker in _shown:
		var at: Vector2 = marker["at"]
		var dir: Vector2 = marker["dir"]
		var s: float = marker["size"]
		var color: Color = marker["color"]
		var side := Vector2(-dir.y, dir.x)
		var tip := at
		var chevron := PackedVector2Array([tip, tip - dir * s + side * s * 0.8, tip - dir * s * 0.55,
			tip - dir * s - side * s * 0.8])
		draw_colored_polygon(chevron, color)
		draw_polyline(PackedVector2Array([chevron[0], chevron[1], chevron[2], chevron[3], chevron[0]]), Color(0.0, 0.0, 0.0, 0.7), 1.5)
		var icon_at := tip - dir * s * 1.9
		draw_texture_rect(Icons.texture(marker["icon"]), Rect2(icon_at - Vector2(s, s) * 0.5, Vector2(s, s)), false, Icons.tint(marker["icon"], color))
