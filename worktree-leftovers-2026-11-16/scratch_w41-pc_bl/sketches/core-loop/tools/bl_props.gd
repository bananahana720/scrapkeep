extends SceneTree
# SCRATCH ONLY (PC lane job BL, 14 Nov 2026): never for the repo's tests or a game branch.
# PR 1022 set pieces where the game places them: one close still, then the same line of sight at 40, 70, 110
# and 160 m (play field of view and a narrow lens) so the lod switch can be read.
#   ... --script res://tools/bl_props.gd -- --out=<abs dir> --tag=<tripo|authored> --stage=<1|2> --kind=<prefix> [--models=tripo]
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const SIZE := Vector2i(1920, 1080)

var out := ""
var tag := ""
var kind := ""
var stage := 1
var game

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--tag="):
			tag = arg.trim_prefix("--tag=")
		elif arg.begins_with("--kind="):
			kind = arg.trim_prefix("--kind=")
		elif arg.begins_with("--stage="):
			stage = int(arg.trim_prefix("--stage="))
	if out.is_empty() or tag.is_empty() or kind.is_empty():
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	_run.call_deferred()

func _save(name: String) -> void:
	for i in 4:
		await process_frame
	root.get_texture().get_image().save_png("%s/%s-%s-%s.png" % [out, kind, tag, name])
	print("STILL ", kind, "-", tag, "-", name)

func _hide_ui() -> void:
	if game.get("presentation") != null:
		game.presentation.hide_ui()
	for c in root.find_children("*", "CanvasLayer", true, false):
		c.visible = false

func _cam(at: Vector3, look: Vector3, fov: float) -> Camera3D:
	var c := Camera3D.new()
	c.fov = fov
	c.far = 2000.0
	root.add_child(c)
	c.global_position = at
	c.look_at(look, Vector3.UP)
	c.make_current()
	for t in root.find_children("*", "Terrain3D", true, false):
		t.set_camera(c)
	return c

func _found() -> Array:
	var found := []
	for n in root.find_children("*", "GeometryInstance3D", true, false):
		var name := String(n.name).to_lower()
		if n is MultiMeshInstance3D and name.begins_with(kind) and (n as MultiMeshInstance3D).multimesh != null:
			var mm: MultiMesh = (n as MultiMeshInstance3D).multimesh
			for i in mm.instance_count:
				found.append((n as Node3D).global_transform * mm.get_instance_transform(i).origin)
		elif n is MeshInstance3D and name.begins_with(kind):
			found.append((n as Node3D).global_position)
		elif n.has_meta("dress_member_kinds") and n.has_meta("dress_member_pos"):
			var kinds: Array = n.get_meta("dress_member_kinds")
			var pos: Array = n.get_meta("dress_member_pos")
			for i in mini(kinds.size(), pos.size()):
				if String(kinds[i]).begins_with(kind):
					var p = pos[i]
					found.append((n as Node3D).global_transform * (p if p is Vector3 else Vector3(p[0], p[1], p[2])))
	var unique := []
	for p in found:
		if not unique.any(func(q): return (q as Vector3).distance_to(p) < 1.0):
			unique.append(p)
	return unique

func _run() -> void:
	seed(1)
	game = Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	while game.flow == null:
		await process_frame
	await process_frame
	game.player.source = Intent.Scripted.new()
	game.flow.press_start()
	game.flow.choose_class(0)
	game.run.set_max_hp(99999.0)
	if stage != 1:
		game.flow.enter_stage(stage, Vector3.ZERO, false)
	for i in 600:
		await process_frame
		if game.ctx.terrain.is_ready(stage) and game.flow.in_play() and i > 200:
			break
	game.ctx.calm = true
	game.player.body().freeze = true
	for e in get_nodes_in_group("enemy"):
		e.free()
	_hide_ui()
	var props := _found()
	print("STILL ", kind, " found ", props.size())
	if props.is_empty():
		quit(3)
		return
	var ball: Vector3 = game.player.ball_position()
	props.sort_custom(func(a, b): return (a as Vector3).distance_to(ball) < (b as Vector3).distance_to(ball))
	var p: Vector3 = props[0]
	print("STILL ", kind, " at ", p)
	# Look at it from the side that faces the ball, a little off axis.
	var dir := (ball - p)
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.1 else Vector3.FORWARD
	dir = dir.rotated(Vector3.UP, 0.5)
	var look := p + Vector3.UP * 2.0
	var ground := func(q: Vector3) -> float: return game.ctx.terrain.height(q.x, q.z)
	var close_at: Vector3 = p + dir * 11.0
	close_at.y = maxf(ground.call(close_at), p.y) + 4.0
	_cam(close_at, look, 55.0)
	await _save("close")
	for d in [40, 70, 110, 160]:
		var at: Vector3 = p + dir * float(d)
		at.y = maxf(ground.call(at), p.y) + 6.0 + float(d) * 0.04
		var c := _cam(at, look, 70.0)
		await _save("far%d-play" % d)
		c.fov = 70.0 * 10.0 / float(d)
		await _save("far%d-lens" % d)
	quit(0)
