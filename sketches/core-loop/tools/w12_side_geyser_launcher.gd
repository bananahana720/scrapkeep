extends SceneTree


const Tuning := preload("res://src/movement/tuning.gd")
const DigScenery := preload("res://src/presentation/dig_scenery.gd")
const Beacon := preload("res://src/core/beacon.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Contraptions := preload("res://src/world/contraptions.gd")
const GEYSER_SPEC := {"kind": "launcher", "id": "geyser", "style": "geyser", "radius": 3.5, "floor": 16.0, "min_flight": 2.2, "charge": 3.0}
const MOUTH_LIFT := 1.0
const TODAY_COLUMN_SCALE := 0.2
const CART_SCALE := 2.2
const TODAY_SOCKETS := [Vector3(-0.74, 0.3, -0.95), Vector3(0.74, 0.3, -0.95), Vector3(-0.74, 0.3, 0.95), Vector3(0.74, 0.3, 0.95)]
const VIEWS := {
	"cart": {"gap": 9.0, "arena": [Vector3(0, 9, 30), Vector3(0, 1.5, 0)], "hero": [Vector3(7.5, 5.5, -5.0), Vector3(0, 1.9, -1.2)]},
	"beacon": {"gap": 16.0, "arena": [Vector3(0, 16, 62), Vector3(0, 9, 0)], "hero": [Vector3(14, 12, 24), Vector3(0, 10, 0)]},
	"geyser_launcher": {"gap": 10.0, "arena": [Vector3(0, 12, 36), Vector3(0, 1, 0)], "hero": [Vector3(4.5, 5.6, 6.4), Vector3(0, 0.2, 0)]},
}
const LAYER_RANGE := {"cart": [[40.0, 4.0], [15.0, 3.0]], "beacon": [[60.0, 8.0], [35.0, 5.0]], "geyser_launcher": [[40.0, 10.0], [24.0, 4.0]]}
const RANGE_DISTANCES := {"cart": [8.0, 20.0, 45.0], "beacon": [10.0, 30.0, 70.0], "geyser_launcher": [8.0, 20.0, 55.0]}
const TOGGLE_DISTANCE := {"cart": 20.0, "beacon": 45.0, "geyser_launcher": 32.0}
const FADE_DISTANCES := {"cart": [], "beacon": [56.0, 60.0, 62.0, 64.0, 66.0, 67.0, 68.0, 69.0],
	"geyser_launcher": [29.0, 30.0, 31.0, 32.0, 33.0, 34.0, 35.0, 36.0, 37.0, 38.0, 39.0, 40.0, 41.0, 42.0, 43.0, 44.0, 45.0, 46.0, 47.0, 48.0, 49.0, 50.0, 51.0, 52.0]}


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


func _ball(root: Node, at: Vector3) -> MeshInstance3D:
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
	return ball


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


func _bbox(cam: Camera3D, subject: Node3D, layers: Array[Node3D], tag: String) -> void:
	var box := AABB()
	var first := true
	for view: MeshInstance3D in subject.find_children("*", "MeshInstance3D", true, false):
		var world := view.global_transform * view.get_aabb()
		box = world if first else box.merge(world)
		first = false
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for k in 8:
		var p := cam.unproject_position(box.get_endpoint(k))
		lo = lo.min(p)
		hi = hi.max(p)
	var px := Vector2(get_root().size) / get_root().get_visible_rect().size
	lo *= px
	hi *= px
	var to_layers := ""
	for layer in layers:
		for view: MeshInstance3D in layer.find_children("*", "MeshInstance3D", true, false):
			var centre := (view.global_transform * view.get_aabb()).get_center()
			to_layers += " %s_centre=%.2f" % [layer.name, cam.global_position.distance_to(centre)]
	print("W12_DC_BBOX ", tag, " ", int(floor(lo.x)), " ", int(floor(lo.y)), " ", int(ceil(hi.x)), " ", int(ceil(hi.y)),
		" eye_to_origin=", snappedf(cam.global_position.distance_to(subject.global_position), 0.01), to_layers)


func _layers(fresh: Node3D, args: Dictionary, subject: String) -> Array[Node3D]:
	var layers: Array[Node3D] = []
	var rows: Array = LAYER_RANGE[subject]
	for i in 2:
		var key := "detail%d" % (i + 1)
		if args[key] == "":
			break
		var shell := _glb(args[key])
		if shell == null:
			return []
		shell.name = key
		shell.scale = Vector3.ONE * (CART_SCALE if subject == "cart" else 1.0)
		fresh.add_child(shell)
		for view: GeometryInstance3D in shell.find_children("*", "GeometryInstance3D", true, false):
			view.visibility_range_end = rows[i][0]
			view.visibility_range_end_margin = rows[i][1]
			view.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		print("W12_DC_LAYER ", subject, " ", key, " end=", rows[i][0], " margin=", rows[i][1])
		layers.append(shell)
	return layers


func _detail(cam: Camera3D, fresh: Node3D, layers: Array[Node3D], ref: Image, out: String, tag: String, mode: String, subject: String) -> void:
	var n := layers.size()
	var view: Dictionary = VIEWS[subject]
	var hero: Array = view["hero"]
	var arena: Array = view["arena"]
	if mode == "ranges":
		var target: Vector3 = fresh.position + hero[1]
		var dir: Vector3 = (hero[0] - hero[1]).normalized()
		var distances: Array = RANGE_DISTANCES[subject]
		var frames: Array = []
		var fades: Array = []
		for d: float in FADE_DISTANCES[subject]:
			for k in [n, 0]:
				_show(layers, k)
				var name := "%s_fade_%s_%dm" % [tag, "full" if k == n else "base", int(d)]
				var img: Image = await _shot(cam, target + dir * d, target, out.path_join(name + ".png"))
				_bbox(cam, fresh, layers, name)
				if k == n:
					fades.append(img)
		_show(layers, n)
		for d: float in distances:
			var name := "%s_range_full_%dm" % [tag, int(d)]
			frames.append(await _shot(cam, target + dir * d, target, out.path_join(name + ".png")))
			_bbox(cam, fresh, layers, name)
		var far: float = distances[distances.size() - 1]
		_show(layers, 0)
		frames.append(await _shot(cam, target + dir * far, target, out.path_join("%s_range_base_%dm.png" % [tag, int(far)])))
		_bbox(cam, fresh, layers, "%s_range_base_%dm" % [tag, int(far)])
		var mid: float = TOGGLE_DISTANCE[subject]
		_show(layers, n)
		await _shot(cam, target + dir * mid, target, out.path_join("%s_toggle_full_%dm.png" % [tag, int(mid)]))
		_bbox(cam, fresh, layers, "%s_toggle_full_%dm" % [tag, int(mid)])
		for i in n:
			_show(layers, n)
			layers[i].visible = false
			var name := "%s_range_no_d%d_%dm" % [tag, i + 1, int(mid)]
			await _shot(cam, target + dir * mid, target, out.path_join(name + ".png"))
			_bbox(cam, fresh, layers, name)
		_show(layers, n)
		_sheet(frames, out.path_join("%s_sheet_ranges.png" % tag), 540)
		if not fades.is_empty():
			_sheet(fades, out.path_join("%s_sheet_fade.png" % tag), 540)
		return
	var views := {
		"arena": [arena[0], arena[1]],
		"near": [arena[0] * 0.45 + Vector3(0, 1, 0), arena[1]],
		"hero": [fresh.position + hero[0], fresh.position + hero[1]],
	}
	for v: String in views:
		var shots: Array = [ref]
		var counts := [n, n - 1, 0] if n > 1 else [n, 0]
		var names := ["full", "minus", "base"] if n > 1 else ["full", "base"]
		for k in counts.size():
			_show(layers, counts[k])
			shots.append(await _shot(cam, views[v][0], views[v][1], out.path_join("%s_%s_%s.png" % [tag, v, names[k]])))
		_show(layers, n)
		_sheet(shots, out.path_join("%s_sheet_%s.png" % [tag, v]), 540)


func _init() -> void:
	var args := {"out": "", "body": "", "wheel": "", "lens": "", "ref": "", "tag": "ore_cart", "subject": "cart", "grate": "", "fittings": "",
		"detail1": "", "detail2": "", "mode": "side"}
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

	var subject: String = args["subject"]
	var view: Dictionary = VIEWS[subject]
	var gap: float = view["gap"]
	var today := Node3D.new()
	today.position = Vector3(-gap, 0, 0)
	root.add_child(today)
	var fresh := Node3D.new()
	fresh.position = Vector3(gap, 0, 0)
	root.add_child(fresh)
	var sockets := -1
	match subject:
		"cart":
			sockets = _cart(today, fresh, args)
		"beacon":
			sockets = _beacon(today, fresh, args)
		"geyser_launcher":
			sockets = _geyser_launcher(today, fresh, args)
	if sockets < 0:
		quit(1)
		return
	var layers := _layers(fresh, args, subject)
	if args["detail1"] != "" and layers.is_empty():
		quit(1)
		return
	_slots(today, "today")
	_slots(fresh, subject)
	if subject == "beacon":
		_state(fresh, "beacon_open")
	if subject == "geyser_launcher":
		_role(fresh, "amber")
	var scatter: Array[MeshInstance3D] = [_ball(root, Vector3(0, 0, 4.0)), _ball(root, Vector3(gap + 4.0, 0, 6.0)),
		_ball(root, Vector3(-gap + 4.0, 0, 6.0))]

	var ref := Image.load_from_file(args["ref"])
	var cam := Camera3D.new()
	cam.fov = 60.0
	root.add_child(cam)
	cam.current = true
	if not layers.is_empty():
		await _detail(cam, fresh, layers, ref, out, tag, args["mode"], subject)
		print("W12_RC_SIDE ", subject, " ", tag, " sockets=", sockets, " layers=", layers.size(), " ball_radius=", Tuning.RADIUS)
		quit(0)
		return
	var arena_cam: Array = view["arena"]
	var hero: Array = view["hero"]
	var arena: Image = await _shot(cam, arena_cam[0], arena_cam[1], out.path_join("%s_arena.png" % tag))
	var near: Image = await _shot(cam, arena_cam[0] * 0.45 + Vector3(0, 1, 0), arena_cam[1], out.path_join("%s_near.png" % tag))
	var hero_new: Image = await _shot(cam, fresh.position + hero[0], fresh.position + hero[1], out.path_join("%s_hero_new.png" % tag))
	var hero_today: Image = await _shot(cam, today.position + hero[0], today.position + hero[1], out.path_join("%s_hero_today.png" % tag))
	var heroes := [ref, hero_new, hero_today]
	if subject == "geyser_launcher":
		for stray in scatter:
			stray.visible = false
		var probe := _ball(root, fresh.position - Vector3(0, MOUTH_LIFT, 0))
		var seated: Image = await _shot(cam, fresh.position + hero[0], fresh.position + hero[1], out.path_join("%s_hero_seated.png" % tag))
		print("W12_FIX_BALL seated centre=", probe.position, " mouth=", fresh.position)
		probe.position = fresh.position + Vector3(-7.5, 0, 0)
		var approach: Image = await _shot(cam, fresh.position + hero[0], fresh.position + hero[1], out.path_join("%s_hero_approach.png" % tag))
		print("W12_FIX_BALL approach centre=", probe.position, " mouth=", fresh.position)
		_sheet([ref, seated, approach], out.path_join("%s_sheet_balls.png" % tag), 540)
		probe.visible = false
		for stray in scatter:
			stray.visible = true
	if subject == "beacon":
		_state(fresh, "beacon_sealed")
		var sealed: Image = await _shot(cam, fresh.position + hero[0], fresh.position + hero[1], out.path_join("%s_hero_sealed.png" % tag))
		heroes.insert(2, sealed)
	_sheet([ref, arena], out.path_join("%s_sheet_arena.png" % tag), 540)
	_sheet([ref, near], out.path_join("%s_sheet_near.png" % tag), 540)
	_sheet(heroes, out.path_join("%s_sheet_hero.png" % tag), 540)
	print("W12_RC_SIDE ", subject, " ", tag, " sockets=", sockets, " ball_radius=", Tuning.RADIUS)
	quit(0)


func _cart(today: Node3D, fresh: Node3D, args: Dictionary) -> int:
	var body: Node3D = (load("res://assets/models/dig_mechanical/cart_body.glb") as PackedScene).instantiate()
	body.scale = Vector3.ONE * CART_SCALE
	today.add_child(body)
	for socket in TODAY_SOCKETS:
		var wheel: Node3D = (load("res://assets/models/dig_mechanical/cart_wheel.glb") as PackedScene).instantiate()
		wheel.position = socket * CART_SCALE
		wheel.scale = Vector3.ONE * CART_SCALE
		today.add_child(wheel)
	var ore_body := _glb(args["body"])
	if ore_body == null:
		return -1
	ore_body.scale = Vector3.ONE * CART_SCALE
	fresh.add_child(ore_body)
	var sockets := 0
	for socket: Node3D in ore_body.find_children("socket_wheel_*", "Node3D", true, false):
		var wheel := _glb(args["wheel"])
		if wheel == null:
			return -1
		wheel.position = _local(socket, ore_body) * CART_SCALE
		wheel.scale = Vector3.ONE * CART_SCALE
		fresh.add_child(wheel)
		sockets += 1
	return sockets


func _beacon(today: Node3D, fresh: Node3D, args: Dictionary) -> int:
	var old := Beacon.new()
	old.sealed = false
	today.add_child(old)
	old.setup()
	var frame := _glb(args["body"])
	if frame == null:
		return -1
	fresh.add_child(frame)
	var sockets := 0
	for socket: Node3D in frame.find_children("socket_lens", "Node3D", true, false):
		var lens := _glb(args["lens"])
		if lens == null:
			return -1
		lens.position = _local(socket, frame)
		fresh.add_child(lens)
		sockets += 1
	return sockets


func _local(socket: Node3D, top: Node3D) -> Vector3:
	var at := Vector3.ZERO
	var node: Node = socket
	while node != top:
		at = (node as Node3D).transform * at
		node = node.get_parent()
	return at


func _state(node: Node, id: String) -> void:
	for view: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		if view.material_override is ShaderMaterial and String(view.material_override.resource_name) == "steel":
			view.set_instance_shader_parameter("state_tint", EventKinds.state_color(id))
			print("W12_RC_STATE node=", view.name, " state=", id, " tint=", EventKinds.state_color(id).to_html(false))


func _geyser_launcher(today: Node3D, fresh: Node3D, args: Dictionary) -> int:
	var holder := GDScript.new()
	holder.source_code = "extends RefCounted\nvar contraptions: Array = []\n"
	holder.reload()
	var map = holder.new()
	var spec: Dictionary = GEYSER_SPEC.duplicate()
	spec["at"] = Vector2.ZERO
	spec["target"] = Vector3(0, 0, 60)
	map.contraptions = [spec]
	var c = Contraptions.new()
	today.add_child(c)
	c.setup(map, func(x: float, z: float, lift: float) -> Vector3: return Vector3(x, lift, z), 14.0, 26.0)
	c.set_process(false)
	c.set_physics_process(false)
	(c.launchers[0]["arm"] as Node3D).scale = Vector3(1.0, TODAY_COLUMN_SCALE, 1.0)
	fresh.position.y = MOUTH_LIFT
	var parts := 0
	for key in ["body", "grate", "fittings"]:
		var part := _glb(args[key])
		if part == null:
			return -1
		fresh.add_child(part)
		parts += 1
	return parts


func _role(node: Node, role: String) -> void:
	for view: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		if view.material_override is ShaderMaterial and String(view.material_override.resource_name) == "steel":
			view.set_instance_shader_parameter("state_tint", EventKinds.role_color(role))
			print("W12_RC_STATE node=", view.name, " role=", role, " tint=", EventKinds.role_color(role).to_html(false))
