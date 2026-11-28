extends Node3D

const Palette := preload("res://src/core/palette.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const SpeedTier := preload("res://src/core/speed_tier.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const Augments := preload("res://src/movement/augments.gd")
const UiFonts := preload("res://src/core/ui_fonts.gd")
const UiTokens := preload("res://src/core/ui_tokens.gd")
const DevInspect := preload("res://src/dev/dev_inspect.gd")

const LAYERS := ["bounds", "telegraphs", "vel"]
const PERF_MODES := ["auto", "on", "off"]
const FAR_BOX := 100000.0
const XRAY_ALPHA := 0.35
const XRAY_PRIORITY := Threat.LINE_PRIORITY + 4
const SOLID_PRIORITY := XRAY_PRIORITY + 1
const VERTEX_BUDGET := 12000
const ENEMY_REACH := 60.0
const GROUND_LIFT := 0.12
const BALL_SEGMENTS := 32
const ENEMY_SEGMENTS := 16
const ARC_SEGMENTS := 48
const DISC_RADIUS := 0.3
const DASH_PX := 10.0
const GAP_PX := 6.0
const DOT_PX := 2.5
const DOT_GAP_PX := 6.0
const MIN_PIECE := 0.02
const VEL_SCALE := 0.25
const AIM_REACH := 40.0
const OUT_PX := 2.0
const IN_PX := 4.0
const UNDER_PX := 1.0
const PERF_LAYER := 89
const SPARK_SIZE := Vector2(120.0, 18.0)
const SPARK_TOP_MS := 50.0
const BUDGET_MS := 16.7
const SLOW_MS := 33.3
const MARGIN := 16.0

var game
var console
var _layers := {"bounds": false, "telegraphs": false, "vel": false}
var _perf_mode := "off"
var _hud_visible := true
var _hide_3d := false
var _hide_perf := false
var _mesh: ImmediateMesh
var _view: MeshInstance3D
var _xray: StandardMaterial3D
var _solid: StandardMaterial3D
var _perf_layer: CanvasLayer
var _perf_plate: PanelContainer
var _perf_text: Label
var _spark: Control
var _standalone_inspect: DevInspect
var _reads: Array = []
var _solid_v := PackedVector3Array()
var _solid_c := PackedColorArray()
var _xray_v := PackedVector3Array()
var _xray_c := PackedColorArray()
var _cam: Camera3D
var _cam_pos := Vector3.ZERO
var _cam_fwd := Vector3.FORWARD
var _ortho := false
var _vp_height := 1.0
var _scale := 1.0


func setup(game_ref, console_ref) -> void:
	game = game_ref
	console = console_ref
	name = "DevOverlay"
	top_level = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	_xray = _material(true, XRAY_PRIORITY)
	_solid = _material(false, SOLID_PRIORITY)
	_mesh = ImmediateMesh.new()
	_view = MeshInstance3D.new()
	_view.name = "DevOverlayLines"
	_view.mesh = _mesh
	_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_view.custom_aabb = AABB(Vector3.ONE * -FAR_BOX, Vector3.ONE * FAR_BOX * 2.0)
	_view.visible = false
	add_child(_view)
	_build_perf()
	if console == null:
		_perf_source()
	_sync_perf()


func register(commands) -> void:
	var run := func(args: Array[String]):
		if args.size() >= 2 and args[0].to_lower() == "perf":
			return set_perf_mode(args[1])
		return set_mode(" ".join(args))
	var use := "[off|bounds|telegraphs|vel|perf|all|+layer|-layer] | perf <auto|on|off>"
	commands.add("overlay", use, "draw collider, telegraph, velocity and frame-time layers over the world", run)
	if not commands.has("debug"):
		commands.add("debug", use, "the overlay command under a second name", run)


func set_mode(spec: String) -> String:
	var words := spec.strip_edges().to_lower().split(" ", false)
	for word in words:
		match word:
			"off", "none":
				for key in LAYERS:
					_layers[key] = false
				_perf_mode = "off"
			"all", "on":
				for key in LAYERS:
					_layers[key] = true
				if _perf_mode == "off":
					_perf_mode = "auto"
			"perf":
				for key in LAYERS:
					_layers[key] = false
				if _perf_mode == "off":
					_perf_mode = "auto"
			"+perf":
				if _perf_mode == "off":
					_perf_mode = "auto"
			"-perf":
				_perf_mode = "off"
			_:
				var lead := word.left(1)
				var key := word.trim_prefix("+").trim_prefix("-")
				if not key in LAYERS:
					return "!no overlay layer '%s' (%s, perf, all, off)" % [word, ", ".join(LAYERS)]
				if lead == "+":
					_layers[key] = true
				elif lead == "-":
					_layers[key] = false
				else:
					for other in LAYERS:
						_layers[other] = other == key
	_sync_perf()
	if not any_3d_active():
		_clear_mesh()
	return describe()


func set_perf_mode(mode: String) -> String:
	mode = mode.to_lower()
	if not mode in PERF_MODES:
		return "!perf takes %s" % ", ".join(PERF_MODES)
	_perf_mode = mode
	_sync_perf()
	return describe()


func describe() -> String:
	var on: Array[String] = []
	for key in LAYERS:
		if _layers[key]:
			on.append(key)
	return "overlay %s  perf %s" % [" ".join(on) if not on.is_empty() else "off", _perf_mode]


func active_layers() -> Dictionary:
	return {"bounds": _layers.bounds, "telegraphs": _layers.telegraphs, "vel": _layers.vel, "perf": _perf_mode}


func any_3d_active() -> bool:
	return _layers.bounds or _layers.telegraphs or _layers.vel


func any_active() -> bool:
	return any_3d_active() or _perf_mode != "off"


func perf_visible() -> bool:
	return is_instance_valid(_perf_plate) and _perf_plate.visible


func hud_shown(visible: bool) -> void:
	_hud_visible = visible
	_sync_perf()


func set_capture_hide(hide_3d: bool, hide_perf: bool) -> void:
	_hide_3d = hide_3d
	_hide_perf = hide_perf
	_sync_perf()
	redraw()


func reads() -> Array:
	return _reads.duplicate(true)


func vertex_count() -> int:
	return _solid_v.size() + _xray_v.size()


static func telegraph_style(inside: bool, live: bool, hostile: bool) -> Dictionary:
	if not hostile:
		return {"colour": Palette.STEEL, "px": OUT_PX, "pattern": "dot", "under": 0.0}
	var pattern := "solid" if live else "dash"
	if inside:
		return {"colour": Palette.LEDGER_CREAM, "px": IN_PX, "pattern": pattern, "under": IN_PX + UNDER_PX * 2.0}
	return {"colour": Palette.ARC, "px": OUT_PX, "pattern": pattern, "under": 0.0}


static func speed_colour(fraction: float) -> Color:
	if fraction >= 1.0:
		return Palette.ANCIENT
	if fraction >= SpeedTier.MULTIPLES[SpeedTier.FAST] / SpeedTier.MULTIPLES[SpeedTier.BLAZING]:
		return Palette.AMBER
	return Palette.STEEL


func _process(_delta: float) -> void:
	_sample_frame()
	redraw()


func redraw() -> void:
	_reads.clear()
	_solid_v.clear()
	_solid_c.clear()
	_xray_v.clear()
	_xray_c.clear()
	if not any_3d_active() or _hide_3d or not _frame_camera():
		_clear_mesh()
		return
	var player = game.player if game != null else null
	if player == null or not is_instance_valid(player):
		_clear_mesh()
		return
	var shown: Vector3 = player.shown_position()
	var enemies := _nearby(shown) if _layers.bounds or _layers.vel else []
	if _layers.telegraphs:
		_draw_telegraphs(player, shown)
	if _layers.vel:
		_draw_ball_motion(player, shown)
	if _layers.bounds:
		_draw_ball_bounds(shown)
	for enemy in enemies:
		if _layers.bounds and not _draw_capsule(enemy):
			break
		if _layers.vel and not _draw_enemy_motion(enemy):
			break
	_emit()


func _frame_camera() -> bool:
	_cam = get_viewport().get_camera_3d() if is_inside_tree() else null
	if _cam == null:
		return false
	_cam_pos = _cam.global_position
	_cam_fwd = -_cam.global_basis.z
	_ortho = _cam.projection == Camera3D.PROJECTION_ORTHOGONAL
	_vp_height = maxf(get_viewport().get_visible_rect().size.y, 1.0)
	var look = console.look if console != null and "look" in console else null
	_scale = maxf(1.0, float(look.value("pixel"))) if look != null else 1.0
	return true


func _nearby(ball: Vector3) -> Array:
	var found: Array = []
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or not (enemy is Node3D):
			continue
		var far: float = enemy.global_position.distance_to(ball)
		if far <= ENEMY_REACH:
			found.append([far, enemy])
	found.sort_custom(func(a, b): return a[0] < b[0])
	return found.map(func(pair): return pair[1])


func _draw_telegraphs(player, shown: Vector3) -> void:
	var ball: Vector3 = player.ball_position()
	var under_ball := false
	for tele in get_tree().get_nodes_in_group("telegraph"):
		if not is_instance_valid(tele) or tele.is_queued_for_deletion() or not tele.has_method("descriptor") or not tele.has_method("contains"):
			continue
		var d: Dictionary = tele.descriptor()
		var inside: bool = tele.contains(ball)
		var hostile: bool = tele.is_hostile() if tele.has_method("is_hostile") else true
		var live := bool(d.get("live", float(d.get("progress", 0.0)) >= 1.0))
		var style := telegraph_style(inside, live, hostile)
		var outline := _outline(d)
		if float(style.under) > 0.0:
			for line in outline:
				_line(line, Palette.CHARCOAL, float(style.under), style.pattern)
		for line in outline:
			_line(line, style.colour, float(style.px), style.pattern)
		under_ball = under_ball or (inside and hostile)
		_reads.append({"inside": inside, "live": live, "hostile": hostile, "colour": style.colour, "px": float(style.px),
			"pattern": style.pattern, "form": String(d.get("form", ""))})
	if under_ball:
		_disc(shown - Vector3.UP * (Tuning.RADIUS - GROUND_LIFT), DISC_RADIUS, Palette.LEDGER_CREAM)


func _outline(d: Dictionary) -> Array:
	var centre: Vector3 = d.get("centre", Vector3.ZERO)
	var base := centre + Vector3.UP * GROUND_LIFT
	var aerial := bool(d.get("aerial", false))
	var heights := [0.0, float(d.get("reach", 0.0))] if aerial else [0.0]
	var lines: Array = []
	match String(d.get("form", "")):
		"radial":
			var r_in := float(d.get("r_in", 0.0))
			var r_out := float(d.get("r_out", 0.0))
			var a0 := float(d.get("a0", 0.0))
			var a1 := float(d.get("a1", TAU))
			var whole := a1 - a0 >= TAU - 0.001
			for h in heights:
				var at: Vector3 = base + Vector3.UP * h
				lines.append(_arc(at, r_out, a0, a1))
				if r_in > 0.01:
					lines.append(_arc(at, r_in, a0, a1))
				if not whole:
					for a in [a0, a1]:
						lines.append(PackedVector3Array([at + _flat(a) * r_in, at + _flat(a) * r_out]))
			if aerial:
				for i in 4:
					var a := a0 + (a1 - a0) * (float(i) / 4.0 if whole else float(i) / 3.0)
					lines.append(PackedVector3Array([base + _flat(a) * r_out, base + _flat(a) * r_out + Vector3.UP * heights[1]]))
			var front := float(d.get("front", -1.0))
			if front >= 0.0 and front <= r_out:
				lines.append(_arc(base, front, a0, a1))
		"lane":
			var dir: Vector3 = d.get("dir", Vector3.FORWARD)
			dir = Vector3(dir.x, 0.0, dir.z).normalized() if Vector3(dir.x, 0.0, dir.z).length() > 0.001 else Vector3.FORWARD
			var side := Vector3(-dir.z, 0.0, dir.x) * float(d.get("half_width", 0.5))
			var back := base - dir * float(d.get("back", 0.0))
			var ahead := base + dir * float(d.get("length", 0.0))
			for h in heights:
				var up: Vector3 = Vector3.UP * h
				lines.append(PackedVector3Array([back - side + up, ahead - side + up, ahead + side + up, back + side + up, back - side + up]))
	return lines


func _draw_ball_bounds(shown: Vector3) -> void:
	var r := Tuning.RADIUS
	for pair in [[Vector3.RIGHT, Vector3.UP], [Vector3.RIGHT, Vector3.BACK], [Vector3.UP, Vector3.BACK]]:
		_line(_circle(shown, pair[0], pair[1], r, BALL_SEGMENTS), Palette.STEEL, 1.5)


func _draw_capsule(enemy: Node3D) -> bool:
	var radius := float(enemy.get("radius")) if "radius" in enemy else 1.0
	var height := radius * 2.0
	var at := enemy.global_position + Vector3.UP * radius
	for child in enemy.get_children():
		if not (child is CollisionShape3D) or child.disabled or child.shape == null:
			continue
		var shape: Shape3D = child.shape
		if shape is CapsuleShape3D:
			radius = shape.radius
			height = shape.height
		elif shape is SphereShape3D:
			radius = shape.radius
			height = radius * 2.0
		elif shape is CylinderShape3D:
			radius = shape.radius
			height = shape.height
		elif shape is BoxShape3D:
			radius = maxf(shape.size.x, shape.size.z) * 0.5
			height = shape.size.y
		at = child.global_position
		break
	var half := maxf(height * 0.5 - radius, height * 0.25)
	var low := at - Vector3.UP * half
	var high := at + Vector3.UP * half
	var fits := _line(_circle(low, Vector3.RIGHT, Vector3.BACK, radius, ENEMY_SEGMENTS), Palette.STEEL, 1.5)
	fits = fits and _line(_circle(high, Vector3.RIGHT, Vector3.BACK, radius, ENEMY_SEGMENTS), Palette.STEEL, 1.5)
	for side in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		fits = fits and _segment(low + side * radius, high + side * radius, Palette.STEEL, 1.5)
	return fits


func _draw_ball_motion(player, shown: Vector3) -> void:
	if player.state != null:
		var velocity: Vector3 = player.state.velocity
		var cruise: float = game.tuning.f("cruise") if game.tuning != null else 1.0
		if velocity.length() > 0.05:
			_arrow(shown, shown + velocity * VEL_SCALE, speed_colour(SpeedTier.fraction(velocity.length(), cruise)), 3.0)
	if game.camera == null or not game.camera.has_method("aim_origin"):
		return
	var origin: Vector3 = game.camera.aim_origin()
	var end: Vector3 = origin + game.camera.aim_forward() * AIM_REACH
	if player.kit != null:
		var aim: Dictionary = player.kit.aim
		if int(aim.get("state", Augments.AIM_NONE)) != Augments.AIM_NONE:
			end = aim.get("point", end)
	_line(PackedVector3Array([origin, end]), Palette.SAND, 1.5, "dash")


func _draw_enemy_motion(enemy: Node3D) -> bool:
	var at := enemy.global_position + Vector3.UP
	var fits := true
	if "velocity" in enemy:
		var velocity: Vector3 = enemy.velocity
		if velocity.length() > 0.1:
			fits = _arrow(at, at + velocity * VEL_SCALE, Palette.RUST, 2.0)
	if fits and enemy.has_method("telegraph"):
		var tele = enemy.telegraph()
		if tele != null and is_instance_valid(tele) and tele.has_method("threat_at"):
			fits = _segment(at, tele.threat_at() + Vector3.UP * GROUND_LIFT, Palette.RUST, 1.0)
	return fits


func _arrow(from: Vector3, to: Vector3, colour: Color, px: float) -> bool:
	var along := to - from
	var span := along.length()
	if span < 0.01:
		return true
	var dir := along / span
	var view := _view_dir((from + to) * 0.5)
	var side := dir.cross(view)
	side = side.normalized() if side.length_squared() > 0.000001 else Vector3.RIGHT
	var head := minf(span * 0.3, 0.6)
	var fits := _segment(from, to, colour, px)
	fits = fits and _segment(to, to - dir * head + side * head * 0.5, colour, px)
	return fits and _segment(to, to - dir * head - side * head * 0.5, colour, px)


func _line(points: PackedVector3Array, colour: Color, px: float, pattern := "solid") -> bool:
	if points.size() < 2:
		return true
	if pattern == "solid":
		for i in points.size() - 1:
			if not _segment(points[i], points[i + 1], colour, px):
				return false
		return true
	var unit := _world_px(points[0]) * _scale
	var on := maxf((DASH_PX if pattern == "dash" else DOT_PX) * unit, MIN_PIECE)
	var off := maxf((GAP_PX if pattern == "dash" else DOT_GAP_PX) * unit, MIN_PIECE)
	var drawing := true
	var left := on
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var span := a.distance_to(b)
		var t := 0.0
		while t < span:
			var take := minf(left, span - t)
			if drawing and not _segment(a.lerp(b, t / span), a.lerp(b, (t + take) / span), colour, px):
				return false
			t += take
			left -= take
			if left <= 0.00001:
				drawing = not drawing
				left = on if drawing else off
	return true


func _segment(a: Vector3, b: Vector3, colour: Color, px: float) -> bool:
	if vertex_count() + 12 > VERTEX_BUDGET:
		return false
	var mid := (a + b) * 0.5
	var side := (b - a).cross(_view_dir(mid))
	if side.length_squared() < 0.0000001:
		return true
	side = side.normalized()
	var wa := side * px * _scale * _world_px(a) * 0.5
	var wb := side * px * _scale * _world_px(b) * 0.5
	_tri(a - wa, a + wa, b + wb, colour)
	_tri(a - wa, b + wb, b - wb, colour)
	return true


func _disc(centre: Vector3, radius: float, colour: Color) -> void:
	var steps := 20
	for i in steps:
		if vertex_count() + 6 > VERTEX_BUDGET:
			return
		_tri(centre, centre + _flat(TAU * i / steps) * radius, centre + _flat(TAU * (i + 1) / steps) * radius, colour)


func _tri(a: Vector3, b: Vector3, c: Vector3, colour: Color) -> void:
	var faint := Color(colour, colour.a * XRAY_ALPHA)
	for p in [a, b, c]:
		_solid_v.append(p)
		_solid_c.append(colour)
		_xray_v.append(p)
		_xray_c.append(faint)


func _emit() -> void:
	_mesh.clear_surfaces()
	if _solid_v.is_empty():
		_view.visible = false
		return
	for bucket in [[_xray_v, _xray_c, _xray], [_solid_v, _solid_c, _solid]]:
		var points: PackedVector3Array = bucket[0]
		var colours: PackedColorArray = bucket[1]
		_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, bucket[2])
		for i in points.size():
			_mesh.surface_set_color(colours[i])
			_mesh.surface_add_vertex(points[i])
		_mesh.surface_end()
	_view.visible = true


func _clear_mesh() -> void:
	if _mesh != null:
		_mesh.clear_surfaces()
	if is_instance_valid(_view):
		_view.visible = false


func _view_dir(at: Vector3) -> Vector3:
	if _ortho:
		return -_cam_fwd
	var back := _cam_pos - at
	return back.normalized() if back.length_squared() > 0.000001 else -_cam_fwd


func _world_px(at: Vector3) -> float:
	if _cam == null:
		return 0.01
	if _ortho:
		return _cam.size / _vp_height
	var depth := maxf((at - _cam_pos).dot(_cam_fwd), 0.05)
	return 2.0 * depth * tan(deg_to_rad(_cam.fov) * 0.5) / _vp_height


func _arc(centre: Vector3, radius: float, a0: float, a1: float) -> PackedVector3Array:
	var steps := clampi(ceili((a1 - a0) / TAU * ARC_SEGMENTS), 6, ARC_SEGMENTS)
	var points := PackedVector3Array()
	for i in steps + 1:
		points.append(centre + _flat(lerpf(a0, a1, float(i) / steps)) * radius)
	return points


static func _circle(centre: Vector3, axis_a: Vector3, axis_b: Vector3, radius: float, steps: int) -> PackedVector3Array:
	var points := PackedVector3Array()
	for i in steps + 1:
		var a := TAU * i / steps
		points.append(centre + (axis_a * cos(a) + axis_b * sin(a)) * radius)
	return points


static func _flat(angle: float) -> Vector3:
	return Vector3(cos(angle), 0.0, sin(angle))


static func _material(xray: bool, priority: int) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = xray
	mat.disable_fog = true
	mat.disable_receive_shadows = true
	mat.render_priority = priority
	return mat


func _build_perf() -> void:
	_perf_layer = CanvasLayer.new()
	_perf_layer.name = "DevPerf"
	_perf_layer.layer = PERF_LAYER
	add_child(_perf_layer)
	_perf_plate = PanelContainer.new()
	_perf_plate.name = "PerfStrip"
	_perf_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color(Palette.CHARCOAL, 0.72)
	box.set_corner_radius_all(UiTokens.RADIUS)
	box.content_margin_left = UiTokens.GAP_S
	box.content_margin_right = UiTokens.GAP_S
	box.content_margin_top = UiTokens.GAP_XS
	box.content_margin_bottom = UiTokens.GAP_XS
	_perf_plate.add_theme_stylebox_override("panel", box)
	_perf_plate.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_perf_plate.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_perf_plate.offset_right = -MARGIN
	_perf_plate.offset_top = MARGIN
	_perf_layer.add_child(_perf_plate)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", UiTokens.GAP_S)
	_perf_plate.add_child(row)
	_spark = Control.new()
	_spark.custom_minimum_size = SPARK_SIZE
	_spark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spark.draw.connect(_draw_spark)
	row.add_child(_spark)
	_perf_text = Label.new()
	_perf_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_perf_text.add_theme_font_override("font", UiFonts.mono())
	_perf_text.add_theme_font_size_override("font_size", UiTokens.CAPTION)
	_perf_text.add_theme_color_override("font_color", Palette.LEDGER_CREAM)
	row.add_child(_perf_text)


func _sync_perf() -> void:
	if not is_instance_valid(_perf_plate):
		return
	var wanted := _perf_mode == "on" or (_perf_mode == "auto" and _hud_visible)
	_perf_plate.visible = wanted and not _hide_perf


func _perf_source() -> DevInspect:
	if is_instance_valid(console) and "inspect" in console and is_instance_valid(console.inspect):
		return console.inspect
	if not is_instance_valid(_standalone_inspect):
		_standalone_inspect = DevInspect.new()
		add_child(_standalone_inspect)
		_standalone_inspect.setup(game, null)
	return _standalone_inspect


func _sample_frame() -> void:
	if not perf_visible():
		return
	var src := _perf_source()
	var ring := src.frame_ms_ring()
	var worst := 0.0
	for ms in ring:
		worst = maxf(worst, ms)
	var tele := get_tree().get_nodes_in_group("telegraph").size()
	var foes := get_tree().get_nodes_in_group("enemy").size()
	_perf_text.text = "%d fps | %.1f ms | %d draws | %d/%d" % [Engine.get_frames_per_second(), worst,
		src.latest_draws(), foes, tele]
	_spark.queue_redraw()


func _draw_spark() -> void:
	var size := _spark.size
	for pair in [[BUDGET_MS, Palette.AMBER], [SLOW_MS, Palette.HAZARD]]:
		var y := size.y * (1.0 - float(pair[0]) / SPARK_TOP_MS)
		_spark.draw_line(Vector2(0.0, y), Vector2(size.x, y), pair[1], 1.0)
	var ring := _perf_source().frame_ms_ring()
	if ring.size() < 2:
		return
	var cap := DevInspect.PERF_RING_CAP
	var points := PackedVector2Array()
	var step := size.x / float(cap - 1)
	var start := cap - ring.size()
	for i in ring.size():
		var y := size.y * (1.0 - clampf(ring[i] / SPARK_TOP_MS, 0.0, 1.0))
		points.append(Vector2((start + i) * step, y))
	_spark.draw_polyline(points, Palette.LEDGER_CREAM, 1.0)
