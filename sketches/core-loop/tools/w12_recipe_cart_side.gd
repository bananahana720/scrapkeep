extends SceneTree

# Wave 12 RECIPE-CART side-by-side, after tools/w12_gen2_side.gd on wt/w12-gen (same ground, light, ball and
# arena/near cameras): today's cart on the left, the ore cart built by tools/blender/ore_cart.py on the right,
# the ball between them, and the FLUX concept picture beside each frame on a sheet. Both carts take their
# materials through dig_scenery.gd's SLOTS table (GLB material name = slot key) and their tyres at the body's
# wheel sockets, the runtime route. The ore cart's sockets are read from its own GLB nodes.
#   godot --path sketches/core-loop --script res://tools/w12_recipe_cart_side.gd -- --out=<abs dir>
#     --body=<abs ore_cart_body.glb> --wheel=<abs ore_cart_wheel.glb> --ref=<abs png> [--tag=<name>]
#     [--detail1=<abs ore_cart_detail1.glb> [--detail2=<abs ore_cart_detail2.glb>]] [--mode=side|ranges]
# Wave 12 DETAIL-CART: each detail GLB is an additive shell at the body's origin and scale, its own draw, dropped by
# distance through LAYER_RANGE (VISIBILITY_RANGE_FADE_SELF). mode=side shoots each camera with every layer, without the
# last layer and base only; mode=ranges shoots the stack from the hero direction at RANGE_DISTANCES and the toggles.

const Tuning := preload("res://src/movement/tuning.gd")
const DigScenery := preload("res://src/presentation/dig_scenery.gd")
const CART_SCALE := 2.2
const TODAY_SOCKETS := [Vector3(-0.74, 0.3, -0.95), Vector3(0.74, 0.3, -0.95), Vector3(-0.74, 0.3, 0.95), Vector3(0.74, 0.3, 0.95)]
const GAP := 9.0
# Camera rows: name -> [eye, target], relative to the scene origin or to one cart ("hero_*").
const ARENA := [Vector3(0, 9, 30), Vector3(0, 1.5, 0)]
const HERO := [Vector3(7.5, 5.5, -5.0), Vector3(0, 1.9, -1.2)]
# Detail layer drop-out, one row per layer: [visibility_range_end, visibility_range_end_margin] in metres.
const LAYER_RANGE := [[40.0, 4.0], [15.0, 3.0]]
const RANGE_DISTANCES := [8.0, 20.0, 45.0]


func _slots(node: Node, side: String) -> void:
	for view: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		if view.mesh == null or view.mesh.get_surface_count() == 0:
			continue
		var source := view.mesh.surface_get_material(0)
		var slot := String(source.resource_name) if source != null else ""
		var hit: bool = DigScenery.SLOTS.has(slot)
		if hit:
			view.material_override = load(DigScenery.SLOTS[slot])
		var arrays := view.mesh.surface_get_arrays(0)
		var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		print("W12_RC_SLOT side=", side, " node=", view.name, " slot=", slot, " applied=", hit,
			" vertex_colours=", arrays[Mesh.ARRAY_COLOR] != null, " tris=", index.size() / 3,
			" verts=", (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())


func _glb(path: String) -> Node3D:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(path, state) != OK:
		push_error("w12_recipe_cart_side: cannot read %s" % path)
		return null
	return doc.generate_scene(state)


func _ball(root: Node, at: Vector3) -> void:
	var ball := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = Tuning.RADIUS
	sphere.height = Tuning.RADIUS * 2.0
	ball.mesh = sphere
	ball.position = at + Vector3(0, Tuning.RADIUS, 0)
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color("e6d9b8")
	ball.material_override = bm
	root.add_child(ball)


func _shot(cam: Camera3D, eye: Vector3, target: Vector3, path: String) -> Image:
	cam.look_at_from_position(eye, target)
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := get_root().get_texture().get_image()
	img.save_png(path)
	return img


func _sheet(images: Array, path: String, height: int) -> void:
	var width := 0
	var scaled: Array[Image] = []
	for source: Image in images:
		var img := source.duplicate() as Image
		img.convert(Image.FORMAT_RGBA8)
		img.resize(int(round(float(img.get_width()) * height / img.get_height())), height, Image.INTERPOLATE_LANCZOS)
		scaled.append(img)
		width += img.get_width()
	var sheet := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var x := 0
	for img in scaled:
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(x, 0))
		x += img.get_width()
	sheet.save_png(path)


func _show(layers: Array[Node3D], count: int) -> void:
	for i in layers.size():
		layers[i].visible = i < count


func _bbox(cam: Camera3D, ore: Node3D, tag: String) -> void:
	var box := AABB()
	var first := true
	for view: MeshInstance3D in ore.find_children("*", "MeshInstance3D", true, false):
		var world := view.global_transform * view.get_aabb()
		box = world if first else box.merge(world)
		first = false
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for k in 8:
		var p := cam.unproject_position(box.get_endpoint(k))
		lo = lo.min(p)
		hi = hi.max(p)
	print("W12_DC_BBOX ", tag, " ", int(floor(lo.x)), " ", int(floor(lo.y)), " ", int(ceil(hi.x)), " ", int(ceil(hi.y)),
		" eye_to_origin=", snappedf(cam.global_position.distance_to(ore.global_position), 0.01))


func _detail(cam: Camera3D, ore: Node3D, layers: Array[Node3D], ref: Image, out: String, tag: String, mode: String) -> void:
	var n := layers.size()
	if mode == "ranges":
		var target := ore.position + HERO[1]
		var dir := (HERO[0] - HERO[1]).normalized()
		var frames: Array = []
		_show(layers, n)
		for d: float in RANGE_DISTANCES:
			var name := "%s_range_full_%dm" % [tag, int(d)]
			frames.append(await _shot(cam, target + dir * d, target, out.path_join(name + ".png")))
			_bbox(cam, ore, name)
		var far: float = RANGE_DISTANCES[2]
		_show(layers, 0)
		frames.append(await _shot(cam, target + dir * far, target, out.path_join("%s_range_base_%dm.png" % [tag, int(far)])))
		_bbox(cam, ore, "%s_range_base_%dm" % [tag, int(far)])
		var mid: float = RANGE_DISTANCES[1]
		for i in n:
			_show(layers, n)
			layers[i].visible = false
			var name := "%s_range_no_d%d_%dm" % [tag, i + 1, int(mid)]
			await _shot(cam, target + dir * mid, target, out.path_join(name + ".png"))
			_bbox(cam, ore, name)
		_show(layers, n)
		_sheet(frames, out.path_join("%s_sheet_ranges.png" % tag), 540)
		return
	var views := {
		"arena": [ARENA[0], ARENA[1]],
		"near": [ARENA[0] * 0.45 + Vector3(0, 1, 0), ARENA[1]],
		"hero": [ore.position + HERO[0], ore.position + HERO[1]],
	}
	for view: String in views:
		var shots: Array = [ref]
		var counts := [n, n - 1, 0] if n > 1 else [n, 0]
		var names := ["full", "minus", "base"] if n > 1 else ["full", "base"]
		for k in counts.size():
			_show(layers, counts[k])
			shots.append(await _shot(cam, views[view][0], views[view][1], out.path_join("%s_%s_%s.png" % [tag, view, names[k]])))
		_show(layers, n)
		_sheet(shots, out.path_join("%s_sheet_%s.png" % [tag, view]), 540)


func _init() -> void:
	var args := {"out": "", "body": "", "wheel": "", "ref": "", "tag": "ore_cart", "detail1": "", "detail2": "", "mode": "side"}
	for arg in OS.get_cmdline_user_args():
		var kv := arg.trim_prefix("--").split("=", true, 1)
		if kv.size() == 2 and args.has(kv[0]):
			args[kv[0]] = kv[1]
	var out: String = args["out"]
	var tag: String = args["tag"]
	DirAccess.make_dir_recursive_absolute(out)
	var root := Node3D.new()
	get_root().add_child(root)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("9fb0b8")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.55, 0.58)
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.shadow_enabled = true
	root.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(400, 400)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("c6a274")
	ground.material_override = gm
	root.add_child(ground)

	var today := Node3D.new()
	today.position = Vector3(-GAP, 0, 0)
	root.add_child(today)
	var body: Node3D = (load("res://assets/models/dig_mechanical/cart_body.glb") as PackedScene).instantiate()
	body.scale = Vector3.ONE * CART_SCALE
	today.add_child(body)
	for socket in TODAY_SOCKETS:
		var wheel: Node3D = (load("res://assets/models/dig_mechanical/cart_wheel.glb") as PackedScene).instantiate()
		wheel.position = socket * CART_SCALE
		wheel.scale = Vector3.ONE * CART_SCALE
		today.add_child(wheel)

	var ore := Node3D.new()
	ore.position = Vector3(GAP, 0, 0)
	root.add_child(ore)
	var ore_body := _glb(args["body"])
	if ore_body == null:
		quit(1)
		return
	ore_body.scale = Vector3.ONE * CART_SCALE
	ore.add_child(ore_body)
	var sockets := 0
	for socket: Node3D in ore_body.find_children("socket_wheel_*", "Node3D", true, false):
		var wheel := _glb(args["wheel"])
		if wheel == null:
			quit(1)
			return
		var at := Vector3.ZERO
		var node: Node = socket
		while node != ore_body:
			at = (node as Node3D).transform * at
			node = node.get_parent()
		wheel.position = at * CART_SCALE
		wheel.scale = Vector3.ONE * CART_SCALE
		ore.add_child(wheel)
		sockets += 1
	var layers: Array[Node3D] = []
	for i in 2:
		var key := "detail%d" % (i + 1)
		if args[key] == "":
			break
		var shell := _glb(args[key])
		if shell == null:
			quit(1)
			return
		shell.scale = Vector3.ONE * CART_SCALE
		ore.add_child(shell)
		for view: GeometryInstance3D in shell.find_children("*", "GeometryInstance3D", true, false):
			view.visibility_range_end = LAYER_RANGE[i][0]
			view.visibility_range_end_margin = LAYER_RANGE[i][1]
			view.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		layers.append(shell)
	_slots(today, "today")
	_slots(ore, "ore_cart")
	_ball(root, Vector3(0, 0, 4.0))
	_ball(root, Vector3(GAP + 4.0, 0, 6.0))
	_ball(root, Vector3(-GAP + 4.0, 0, 6.0))

	var ref := Image.load_from_file(args["ref"])
	var cam := Camera3D.new()
	cam.fov = 60.0
	root.add_child(cam)
	cam.current = true
	if not layers.is_empty():
		await _detail(cam, ore, layers, ref, out, tag, args["mode"])
		print("W12_RC_SIDE ", tag, " sockets=", sockets, " layers=", layers.size(), " ball_radius=", Tuning.RADIUS, " scale=", CART_SCALE)
		quit(0)
		return
	var arena: Image = await _shot(cam, ARENA[0], ARENA[1], out.path_join("%s_arena.png" % tag))
	var near: Image = await _shot(cam, ARENA[0] * 0.45 + Vector3(0, 1, 0), ARENA[1], out.path_join("%s_near.png" % tag))
	var hero_new: Image = await _shot(cam, ore.position + HERO[0], ore.position + HERO[1], out.path_join("%s_hero_new.png" % tag))
	var hero_today: Image = await _shot(cam, today.position + HERO[0], today.position + HERO[1], out.path_join("%s_hero_today.png" % tag))
	_sheet([ref, arena], out.path_join("%s_sheet_arena.png" % tag), 540)
	_sheet([ref, near], out.path_join("%s_sheet_near.png" % tag), 540)
	_sheet([ref, hero_new, hero_today], out.path_join("%s_sheet_hero.png" % tag), 540)
	print("W12_RC_SIDE ", tag, " sockets=", sockets, " ball_radius=", Tuning.RADIUS, " scale=", CART_SCALE)
	quit(0)
