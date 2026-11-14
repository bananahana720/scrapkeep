extends SceneTree
# How much an attack warning hides the play (Andrew, 13 Nov 2026: "the attack indicators are way too
# obstructive ... they do the reverse effect of trying to provide the player a way to read an enemy's
# attack"). In stage 2 the ball is frozen under the game's own chase camera, HUD hidden, and a swatter
# stands POSE_AHEAD metres ahead. Two poses, each in every telegraph look (Threat.LOOKS but classic):
#   lane  a 3 m lane from the crew back through the ball and past the lens, reach 2.2 (a sweep), so the
#         camera stands inside its fence, as on the wave 40 fight film; pending at 0.6, then live
#   ring  a 3 m INSTANT ring round the crew, reach 3.5, pending at 0.6
# Per pose it renders the frame with the marks, without them, and without them and the crew (then
# the ball), and counts pixels whose largest 8-bit channel moved by at least CHANGED:
#   body   share of the crew's pixels the marks change (the crew mask: marks-off frames with and
#          without the crew; its shadow is turned off for the capture)
#   ball   the same for the ball
#   screen share of the whole frame the marks change
#   noise  the same three counts between two marks-off frames, the floor each number sits on
# The crew's and the ball's shadows are turned off, so a mask holds the body alone.
# Needs a display:
#   xvfb-run -a -s "-screen 0 1280x720x24" $GODOT_BIN --path sketches/core-loop --resolution 1280x720 \
#     --script res://tools/mark_cover_capture.gd -- --out=<abs dir>
# The density governor's fill scale is held at 1, so fills draw at full strength (the worst case).
# On the PC run it without xvfb. Writes <out>/cover-<pose>-<look>.png (marks on) and cover.json.
# Evidence limit: llvmpipe in the cloud renders GL Compatibility; the PC's Forward+ judges.
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Telegraph := preload("res://src/combat/telegraph.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const Density := preload("res://src/presentation/density.gd")

const SIZE := Vector2i(1280, 720)
# Stage 2's pale morning floor, the haze pose capture's first place.
const STAGE := 2
const OPEN_SAND := 45.0
const POSE_AHEAD := 7.0
const LANE_LENGTH := 30.0
const LANE_WIDTH := 3.0
const LANE_REACH := 2.2
const RING_RADIUS := 3.0
const PENDING := 0.6
const CHANGED := 24
const SETTLE := 12
const BASES := 4


class FloorAt:
	var y := 0.0

	func height(_x: float, _z: float) -> float:
		return y


var out := ""
var game
var recs: Array = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
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
	# Off the launch pad onto open sand ahead, where the ball sits on the floor the crew stands on.
	var cam0: Camera3D = game.camera.cam
	var ahead0: Vector3 = -cam0.global_transform.basis.z
	ahead0.y = 0.0
	var start: Vector3 = game.player.ball_position() + ahead0.normalized() * OPEN_SAND
	game.player.reset_to(game.ctx.terrain.drop_point(start.x, start.z, 1.2))
	await _frames(90)
	game.player.body().freeze = true
	# The chase camera eases in behind the frozen ball before the pose is read from it.
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
	# The ball and the crew animate while paused (shader time), so every comparison is against
	# BASES frames: a pixel counts only when it differs from all of them.
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
			# Fills at full strength: the density governor's scale is whatever the paused frame left.
			Density.publish_fill_scale(1.0)
			var image := await _shot()
			image.save_png(out.path_join("cover-%s-%s.png" % [pose, look]))
			var rec := {"look": look, "pose": pose, "body": _changed(image, plain, crew_mask), "ball": _changed(image, plain, ball_mask),
				"screen": _changed(image, plain, PackedByteArray()), "noise": noise}
			recs.append(rec)
			print("cover ", rec)
			mark.free()
	var head: Array = []
	OS.execute("git", ["rev-parse", "HEAD"], head)
	var f := FileAccess.open(out.path_join("cover.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"tool": "mark_cover_capture.gd", "head": String(head[0]).strip_edges() if head.size() > 0 else "",
		"adapter": RenderingServer.get_video_adapter_name(), "size": [SIZE.x, SIZE.y], "changed": CHANGED,
		"crew_px": _count(crew_mask), "ball_px": _count(ball_mask), "poses": recs}, "\t"))
	f.close()
	quit(0)


# 1 where `a` differs from every frame in `bases` by at least CHANGED in some channel.
func _mask(a: Image, bases: Array) -> PackedByteArray:
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


func _count(mask: PackedByteArray) -> int:
	var n := 0
	for v in mask:
		n += v
	return n


# Share of the pixels in `within` (all pixels when empty) where `a` differs from every base.
func _changed(a: Image, bases: Array, within: PackedByteArray) -> float:
	var diff := _mask(a, bases)
	var hit := 0
	var total := 0
	for i in diff.size():
		if within.is_empty() or within[i] == 1:
			total += 1
			hit += diff[i]
	return float(hit) / total if total > 0 else -1.0
