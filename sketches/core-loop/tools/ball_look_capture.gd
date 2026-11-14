extends SceneTree

const PilotGlance := preload("res://src/presentation/pilot_glance.gd")
const Accretion := preload("res://src/build/accretion.gd")
const PanelShell := preload("res://src/build/panel_shell.gd")
const Panels := preload("res://src/build/panels.gd")
const HeroAssets := preload("res://src/presentation/hero_assets.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Palette := preload("res://src/core/palette.gd")
const BallLooks := preload("res://src/presentation/ball_looks.gd")
const Game := preload("res://src/game.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const Intent := preload("res://src/movement/intent.gd")

# Stills and counts of one ball look on a bare sand stage, so looks compare frame for frame:
# the chase view at rest (7.5 m, 65 degree lens) and at speed (10.5 m, 80 degrees), both at the
# play camera's pitch, a three-quarter hero view, and the rest chase view again with the rolling
# part turned through three spins. Needs a rendered display:
#
#   xvfb-run -a -s "-screen 0 1920x1080x24" $GODOT_BIN --rendering-driver opengl3 --path sketches/core-loop \
#     --script res://tools/ball_look_capture.gd -- --out=<absolute dir> [--ball-look=<id>] [--pilot=<class id>] [--heft=<1 to 5>] [--paint=<hex>] [--load=<panel plates>] [--outfit=<cosmetic id>] [--glance=1] [--game=1 [--ui=1] [--pitch=<camera pitch, radians>]]
#
# --ball-look is the game's own launch switch (tuning.gd), so the stage and the game share it.
# --heft fits that heft class, --paint an equipped paint, and --load a late run's ball: scrap
# chunks and that many panel plates riding it; --outfit mounts an outfit on the pilot and
# --glance=1 holds the pilot's glance back at the camera. Each adds its own suffix to the file names.
# --game=1 boots the park table instead of the stage and takes the play camera's own picture
# with the ball at rest and after two seconds of rolling: <look>-game_rest.png and -game_roll.png.
#
# Writes <out>/<look>-<pilot>-<shot>.png and <out>/<look>-<pilot>.json: triangles and surfaces of
# the ball alone (meshes under it that draw), how many of those surfaces are see-through, and the
# renderer's own draw calls and primitives for the ball's frame less the empty stage's.

const SIZE := Vector2i(1920, 1080)
const GAME_SIZE := Vector2i(1280, 720)
const PITCH := 0.30
const SHOTS := {
	"chase_rest": {"arm": 7.5, "fov": 65.0, "spin": Vector3.ZERO},
	"chase_fast": {"arm": 10.5, "fov": 80.0, "spin": Vector3.ZERO},
	"spin_a": {"arm": 7.5, "fov": 65.0, "spin": Vector3(0.9, 0.0, 0.0)},
	"spin_b": {"arm": 7.5, "fov": 65.0, "spin": Vector3(1.9, 0.4, 0.3)},
	"spin_c": {"arm": 7.5, "fov": 65.0, "spin": Vector3(2.9, 0.2, 1.1)},
	"hero": {"hero": true, "fov": 30.0, "spin": Vector3(0.5, 0.3, 0.0)},
	"side": {"side": true, "fov": 30.0, "spin": Vector3(0.5, 0.3, 0.0)},
}

var _out := ""
var _look := ""
var _pilot := "pylon_engineer"
var _in_game := false
var _keep_ui := false
var _pitch := NAN
var _heft := 1
var _paint := ""
var _load := 0
var _outfit := ""
var _glance := false
var _label := ""


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--ball-look="):
			_look = arg.trim_prefix("--ball-look=")
			if _look == BallLooks.TODAY:
				_look = ""
		elif arg.begins_with("--outfit="):
			_outfit = arg.trim_prefix("--outfit=")
		elif arg == "--glance=1":
			_glance = true
		elif arg.begins_with("--paint="):
			_paint = arg.trim_prefix("--paint=")
		elif arg.begins_with("--load="):
			_load = int(arg.trim_prefix("--load="))
		elif arg.begins_with("--heft="):
			_heft = int(arg.trim_prefix("--heft="))
		elif arg == "--game=1":
			_in_game = true
		elif arg == "--ui=1":
			_keep_ui = true
		elif arg.begins_with("--pitch="):
			_pitch = float(arg.trim_prefix("--pitch="))
		elif arg.begins_with("--pilot="):
			_pilot = arg.trim_prefix("--pilot=")
	if _out == "":
		push_error("ball_look_capture: --out=<absolute dir> is required")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	if _in_game:
		_play.call_deferred()
	else:
		_run.call_deferred()


func _run() -> void:
	root.size = SIZE
	var cam := Camera3D.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Palette.SAND.darkened(0.25)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Palette.SAND
	env.ambient_light_energy = 0.7
	cam.environment = env
	root.add_child(cam)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, 150.0, 0.0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	root.add_child(sun)
	var floor_view := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60.0, 60.0)
	floor_view.mesh = plane
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Palette.SAND.darkened(0.12)
	floor_mat.roughness = 1.0
	floor_view.material_override = floor_mat
	root.add_child(floor_view)
	# The empty stage's own cost, taken off the ball's frame below.
	cam.position = Vector3(0.0, 3.0, 7.5)
	cam.look_at(Vector3(0.0, 1.0, 0.0))
	var empty := await _renderer_counts()

	var painter := HeroAssets.new()
	root.add_child(painter)
	# The stage's painter reads the look from a tuning of its own, as the game's painter does.
	var tuning := Tuning.new()
	tuning.apply_args(PackedStringArray(["--ball-look=%s" % (_look if _look != "" else BallLooks.TODAY)]))
	painter.ctx = {"tuning": tuning}
	var def = ClassDef.by_id(_pilot)
	var ball := Node3D.new()
	ball.name = "Ball"
	ball.position = Vector3(0.0, 1.0, 0.0)
	root.add_child(ball)
	var rolling := Node3D.new()
	ball.add_child(rolling)
	var tints := {"class": def.color}
	if _paint != "":
		tints["paint"] = Color(_paint)
	var shell: Dictionary = painter.fit_shell_into(rolling, _pilot, "", _heft, tints, ball)
	if shell.is_empty():
		push_error("ball_look_capture: no shell for look '%s' pilot '%s'" % [_look, _pilot])
		quit(3)
		return
	var fitted: Dictionary = painter.fit_pilot_into(shell.pod, _pilot, def.color)
	if fitted.is_empty():
		push_error("ball_look_capture: no pilot model for '%s'" % _pilot)
		quit(3)
		return
	var animator = fitted.get("animator")
	if animator is AnimationPlayer and animator.has_animation("idle_loop"):
		animator.play("idle_loop")
		animator.advance(0.0)
	if _outfit != "":
		painter.fit_outfit(fitted.pilot, _outfit, tints)
	if _glance:
		# The top of the glance back at the chase camera, held for the stills.
		var glance = PilotGlance.seat(fitted.pilot)
		if glance != null:
			glance.turn = 1.0
	if _load > 0:
		# A late run's ball: scrap chunks and panel plates ride the roll node, as build.gd adds them.
		var roll := Node3D.new()
		rolling.add_child(roll)
		var scrap := Accretion.new()
		roll.add_child(scrap)
		scrap.setup()
		scrap.set_lattice(true)
		scrap.show_build(400.0, [], [], _heft)
		var plates := PanelShell.new()
		roll.add_child(plates)
		var held := []
		for i in _load:
			held.append(Panels.ids()[i % Panels.ids().size()])
		plates.show_panels(held, 7)
		await process_frame
		BallLooks.ride(painter.ball_look(), roll)
	_label = "%s-%s%s%s%s" % [_look if _look != "" else "today", _pilot, "-h%d" % _heft if _heft > 1 else "",
		"-paint" if _paint != "" else "", "-load%d" % _load if _load > 0 else ""]
	_label += ("-" + _outfit if _outfit != "" else "") + ("-glance" if _glance else "")
	var report := {"look": _look if _look != "" else "today", "pilot": _pilot, "shots": {}}
	report.merge(_mesh_counts(ball))
	for shot_name in SHOTS:
		var shot: Dictionary = SHOTS[shot_name]
		rolling.rotation = shot.spin
		cam.fov = shot.fov
		var centre := ball.position
		if shot.has("hero"):
			cam.position = centre + Vector3(sin(deg_to_rad(30.0)), sin(deg_to_rad(20.0)), -cos(deg_to_rad(30.0))).normalized() * 5.2
		elif shot.has("side"):
			cam.position = centre + Vector3(1.0, 0.25, 0.25).normalized() * 5.2
		else:
			# The ball faces -Z; the chase camera sits behind on +Z, lifted by the play pitch.
			cam.position = centre + Vector3(0.0, sin(PITCH), cos(PITCH)) * float(shot.arm)
		cam.look_at(centre)
		var counts := await _renderer_counts()
		root.get_texture().get_image().save_png("%s/%s-%s.png" % [_out, _label, shot_name])
		report.shots[shot_name] = {
			"draw_calls": counts.draw_calls - empty.draw_calls,
			"primitives": counts.primitives - empty.primitives,
		}
	report["pilot_seen"] = await _pilot_seen(cam, ball, rolling, shell, fitted.pilot)
	var file := FileAccess.open("%s/%s.json" % [_out, _label], FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("BALL_LOOK ", JSON.stringify(report))
	quit(0)


func _renderer_counts() -> Dictionary:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	return {
		"draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
	}


# Triangles and surfaces of every mesh under the ball that draws, and how many surfaces blend.
func _mesh_counts(ball: Node) -> Dictionary:
	var triangles := 0
	var surfaces := 0
	var see_through := 0
	for node in ball.find_children("*", "MeshInstance3D", true, false):
		var view := node as MeshInstance3D
		if view.mesh == null or not view.is_visible_in_tree() or view.layers == 0:
			continue
		for s in view.mesh.get_surface_count():
			surfaces += 1
			var arrays := view.mesh.surface_get_arrays(s)
			var index = arrays[Mesh.ARRAY_INDEX]
			triangles += (index.size() if index != null and index.size() > 0 else arrays[Mesh.ARRAY_VERTEX].size()) / 3
			var mat := view.get_active_material(s)
			if mat is BaseMaterial3D and mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				see_through += 1
			elif mat is ShaderMaterial and mat.shader != null and mat.shader.code.contains("ALPHA"):
				see_through += 1
	return {"triangles": triangles, "surfaces": surfaces, "see_through_surfaces": see_through}


# How much of the pilot the chase camera sees. The pilot is drawn flat magenta; each of SPINS
# turns of the rolling part is drawn with the shell and without it, at rest and at speed, and
# the share is magenta pixels with over magenta pixels without. Glass in front counts as seen
# (it tints the magenta a little); the report says how tall the pilot stands in pixels.
const SPINS := 24

func _pilot_seen(cam: Camera3D, ball: Node3D, rolling: Node3D, shell: Dictionary, pilot: Node3D) -> Dictionary:
	var flat := StandardMaterial3D.new()
	flat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flat.albedo_color = Color(1.0, 0.0, 1.0)
	for view in pilot.find_children("*", "MeshInstance3D", true, false):
		view.material_override = flat
	var others: Array = []
	for view in ball.find_children("*", "GeometryInstance3D", true, false):
		if not pilot.is_ancestor_of(view) and view.layers != 0:
			others.append(view)
	var out := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261113
	var spins: Array = [Vector3.ZERO]
	for i in SPINS - 1:
		spins.append(Vector3(rng.randf_range(0.0, TAU), rng.randf_range(0.0, TAU), rng.randf_range(0.0, TAU)))
	for eye in [["rest", 7.5, 65.0], ["fast", 10.5, 80.0]]:
		cam.fov = eye[2]
		cam.position = ball.position + Vector3(0.0, sin(PITCH), cos(PITCH)) * float(eye[1])
		cam.look_at(ball.position)
		var layers: Array = others.map(func(view): return view.layers)
		for view in others:
			view.layers = 0
		var alone := await _magenta()
		for i in others.size():
			others[i].layers = layers[i]
		var shares: Array = []
		for spin in spins:
			rolling.rotation = spin
			var seen := await _magenta()
			shares.append(float(seen.count) / maxf(1.0, float(alone.count)))
		shares.sort()
		out[eye[0]] = {"pilot_pixels": alone.count, "pilot_height_px": alone.height,
			"seen_median": snappedf(shares[shares.size() / 2], 0.001), "seen_worst": snappedf(shares[0], 0.001),
			"seen_rest_pose": 0.0}
		rolling.rotation = Vector3.ZERO
		out[eye[0]]["seen_rest_pose"] = snappedf(float((await _magenta()).count) / maxf(1.0, float(alone.count)), 0.001)
		# The measured frame itself, so a reader can see what stands before the pilot.
		root.get_texture().get_image().save_png("%s/%s-seen_%s.png" % [_out, _label, eye[0]])
	return out


func _magenta() -> Dictionary:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var count := 0
	var top := image.get_height()
	var bottom := -1
	for y in range(image.get_height() / 5, image.get_height() * 4 / 5):
		for x in range(image.get_width() / 3, image.get_width() * 2 / 3):
			var c := image.get_pixel(x, y)
			if c.r > 0.7 and c.b > 0.7 and c.g < 0.45:
				count += 1
				top = mini(top, y)
				bottom = maxi(bottom, y)
	return {"count": count, "height": maxi(0, bottom - top + 1)}


# The look in the running game: the park table, the game's own fit and play camera.
func _play() -> void:
	root.size = GAME_SIZE
	root.content_scale_size = GAME_SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	seed(280928)
	var game := Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	while game.flow == null:
		await process_frame
	await process_frame
	game.ctx.calm = true
	game.flow.press_start()
	game.flow.choose_class(1)
	game.run.set_max_hp(999999.0)
	var hands := Intent.Scripted.new()
	game.player.source = hands
	for i in 900:
		await process_frame
		if i % 60 == 0:
			print("BALL_LOOK_GAME frame ", i, " in_play ", game.flow.in_play())
		if game.ctx.terrain.is_ready(1) and game.flow.in_play() and i > 240:
			break
	if not _keep_ui:
		game.presentation.hide_ui()
	if not is_nan(_pitch):
		game.camera.pitch = _pitch
	var label := _look if _look != "" else "today"
	var worn := String(game.tuning.option("ball_look"))
	var shell: Node = game.player.find_child("HeroCore", true, false)
	for i in 30:
		await process_frame
	root.get_texture().get_image().save_png("%s/%s-game_rest.png" % [_out, _label])
	hands.hold = {"move": Vector2(0.0, 1.0)}
	for i in 180:
		await process_frame
	root.get_texture().get_image().save_png("%s/%s-game_roll.png" % [_out, _label])
	print("BALL_LOOK_GAME ", JSON.stringify({"asked": label, "tuning": worn, "shell_fitted": shell != null,
		"shell_scene": String(shell.scene_file_path) if shell != null else ""}))
	quit(0)
