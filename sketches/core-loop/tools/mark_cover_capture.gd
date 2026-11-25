extends SceneTree
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Telegraph := preload("res://src/combat/telegraph.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const Density := preload("res://src/presentation/density.gd")

const SIZE := Vector2i(1280, 720)
const STAGE := 2
const OPEN_SAND := 45.0
const POSE_AHEAD := 7.0
const LANE_LENGTH := 30.0
const LANE_WIDTH := 3.0
const LANE_REACH := 2.2
const RING_RADIUS := 3.0
const PENDING := 0.6
const CHANGED := 24
const COVER_LINE := 0.25
const SETTLE := 12
const BASES := 4


class FloorAt:
	var y := 0.0

	func height(_x: float, _z: float) -> float:
		return y


var out := ""
var plant := ""
var game
var recs: Array = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--plant="):
			plant = a.trim_prefix("--plant=")
	if DisplayServer.get_name() == "headless" or out == "":
		printerr("needs a display and --out")
		quit(2)
		return
	root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _shot() -> Image:
	for i in SETTLE:
		await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _run() -> void:
	seed(131113)
	game = Game.new()
	game.test_mode = true
	game.table = Game.LAUNCH_TABLE
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	game.ctx.calm = true
	game.flow.press_start()
	game.flow.choose_class(1)
	game.run.set_max_hp(999999.0)
	game.player.source = Intent.Scripted.new()
	DirAccess.make_dir_recursive_absolute(out)
	game.flow.enter_stage(STAGE, Vector3.ZERO, false)
	await _frames(60)
	var cam0: Camera3D = game.camera.cam
	var ahead0: Vector3 = -cam0.global_transform.basis.z
	ahead0.y = 0.0
	var start: Vector3 = game.player.ball_position() + ahead0.normalized() * OPEN_SAND
	game.player.reset_to(game.ctx.terrain.drop_point(start.x, start.z, 1.2))
	await _frames(90)
	game.player.body().freeze = true
	await _frames(120)
	var cam: Camera3D = game.camera.cam
	var ball: Vector3 = game.player.ball_position()
	var fwd: Vector3 = -cam.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var floor_at := FloorAt.new()
	var foot: Vector3 = ball + fwd * POSE_AHEAD
	floor_at.y = game.ctx.terrain.height(foot.x, foot.z)
	var crew_at := Vector3(ball.x, floor_at.y, ball.z) + fwd * POSE_AHEAD
	var crew = game.ctx.spawner.spawn_enemy("swatter", crew_at + Vector3.UP * 1.2)
	await _frames(4)
	paused = true
	crew.global_position = crew_at + Vector3.UP * 1.2
	for body in [crew, game.player.body()]:
		for view: GeometryInstance3D in body.find_children("*", "GeometryInstance3D", true, false):
			view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for n in root.find_children("*", "CanvasLayer", true, false):
		n.visible = false
	var plain: Array = []
	for k in BASES:
		plain.append(await _shot())
	var again := await _shot()
	crew.visible = false
	var no_crew: Array = [await _shot(), await _shot()]
	crew.visible = true
	game.player.body().visible = false
	var no_ball: Array = [await _shot(), await _shot()]
	game.player.body().visible = true
	var crew_mask := _mask(plain[0], no_crew)
	var ball_mask := _mask(plain[0], no_ball)
	var noise := {"screen": _changed(again, plain, PackedByteArray()), "body": _changed(again, plain, crew_mask), "ball": _changed(again, plain, ball_mask)}
	print("crew px %d, ball px %d, noise %s" % [_count(crew_mask), _count(ball_mask), noise])
	for look in ["haze", "clear", "edges", "tape"]:
		Threat.set_look(look)
		for pose in ["lane-pending", "lane-live", "ring-pending"]:
			var mark: Node3D
			if pose.begins_with("lane"):
				mark = Telegraph.lane(game, floor_at, Threat.Type.LANE, crew_at, -fwd, LANE_LENGTH, LANE_WIDTH, LANE_REACH)
				mark.set_progress(1.0 if pose == "lane-live" else PENDING)
			else:
				mark = Telegraph.ring(game, floor_at, Threat.Type.INSTANT, crew_at, RING_RADIUS)
				mark.set_progress(PENDING)
			Density.publish_fill_scale(1.0)
			var slab: MeshInstance3D = null
			if plant == "cover":
				slab = _slab(cam, crew_at)
			var image := await _shot()
			image.save_png(out.path_join("cover-%s-%s.png" % [pose, look]))
			if slab != null:
				slab.free()
			mark.free()
			var beside := await _shot()
			var control: float = _changed(beside, plain, crew_mask)
			var body: float = _changed(image, plain, crew_mask)
			var cover := score(body, control)
			var rec := {"look": look, "pose": pose, "body": body, "control_body": control, "cover": cover, "line": COVER_LINE,
				"pass": cover <= COVER_LINE, "ball": _changed(image, plain, ball_mask),
				"screen": _changed(image, plain, PackedByteArray()), "png": out.path_join("cover-%s-%s.png" % [pose, look])}
			recs.append(rec)
			print("cover ", rec)
	var worst := 0.0
	var all_pass := not recs.is_empty() and _count(crew_mask) > 0
	for rec in recs:
		worst = maxf(worst, rec["cover"])
		all_pass = all_pass and rec["pass"]
	var head: Array = []
	OS.execute("git", ["rev-parse", "HEAD"], head)
	var f := FileAccess.open(out.path_join("frames.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"tool": "mark_cover_capture.gd", "head": String(head[0]).strip_edges() if head.size() > 0 else "",
		"plant": plant, "adapter": RenderingServer.get_video_adapter_name(), "size": [SIZE.x, SIZE.y], "changed": CHANGED,
		"line": COVER_LINE, "worst_cover": worst, "verdict": "pass" if all_pass else "fail",
		"crew_px": _count(crew_mask), "ball_px": _count(ball_mask), "noise_first": noise, "poses": recs}, "\t"))
	f.close()
	print("mark_cover_capture: plant=%s worst cover %.3f line %.2f -> %s" % [plant, worst, COVER_LINE, "pass" if all_pass else "fail"])
	quit(0 if all_pass else 1)


func _slab(cam: Camera3D, at: Vector3) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(4.0, 4.0)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.9, 0.1, 0.1)
	material.no_depth_test = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = material
	var view := MeshInstance3D.new()
	view.mesh = quad
	root.add_child(view)
	view.global_position = at + Vector3.UP * 1.2 + (cam.global_position - at).normalized() * 0.5
	view.look_at(cam.global_position)
	return view


static func _mask(a: Image, bases: Array) -> PackedByteArray:
	var da := a.get_data()
	var dbs: Array = bases.map(func(b: Image): return b.get_data())
	var step := 4 if a.get_format() == Image.FORMAT_RGBA8 else 3
	var mask := PackedByteArray()
	mask.resize(da.size() / step)
	for i in mask.size():
		var k := i * step
		var apart := 1
		for db: PackedByteArray in dbs:
			if absi(da[k] - db[k]) < CHANGED and absi(da[k + 1] - db[k + 1]) < CHANGED and absi(da[k + 2] - db[k + 2]) < CHANGED:
				apart = 0
				break
		mask[i] = apart
	return mask


static func _count(mask: PackedByteArray) -> int:
	var n := 0
	for v in mask:
		n += v
	return n


static func _changed(a: Image, bases: Array, within: PackedByteArray) -> float:
	var diff := _mask(a, bases)
	var hit := 0
	var total := 0
	for i in diff.size():
		if within.is_empty() or within[i] == 1:
			total += 1
			hit += diff[i]
	return float(hit) / total if total > 0 else -1.0


static func score(body: float, control: float) -> float:
	if body < 0.0:
		return 1.0
	return maxf(0.0, body - maxf(0.0, control))
