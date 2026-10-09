extends SceneTree

# Probe P-GEN-2 side-by-side, after w12_gen_side.gd (same cameras, ground, light and ball): today's asset
# on the left, a trial GLB loaded at runtime from an absolute path on the right. Both sides take their
# materials through dig_scenery.gd's SLOTS table (GLB material name = slot key), the runtime route.
#   godot --path sketches/core-loop --script res://tools/w12_gen2_side.gd -- --out=<abs dir> --subject=cart|beacon --trial=<abs glb> --tag=<name>

const Tuning := preload("res://src/movement/tuning.gd")
const Beacon := preload("res://src/core/beacon.gd")
const DigScenery := preload("res://src/presentation/dig_scenery.gd")
const CART_SCALE := 2.2
const CART_SOCKETS := [Vector3(-0.74, 0.3, -0.95), Vector3(0.74, 0.3, -0.95), Vector3(-0.74, 0.3, 0.95), Vector3(0.74, 0.3, 0.95)]


func _slots(node: Node, side: String) -> void:
	for view: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		if view.mesh == null or view.mesh.get_surface_count() == 0:
			continue
		var source := view.mesh.surface_get_material(0)
		var slot := String(source.resource_name) if source != null else ""
		var hit: bool = DigScenery.SLOTS.has(slot)
		if hit:
			view.material_override = load(DigScenery.SLOTS[slot])
		var colours := view.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR] != null
		print("W12_GEN2_SLOT side=", side, " node=", view.name, " slot=", slot, " applied=", hit, " vertex_colours=", colours,
			" tris=", view.mesh.surface_get_array_index_len(0) / 3)


func _init() -> void:
	var out := ""
	var subject := "cart"
	var trial_path := ""
	var tag := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
		elif arg.begins_with("--subject="):
			subject = arg.substr(10)
		elif arg.begins_with("--trial="):
			trial_path = arg.substr(8)
		elif arg.begins_with("--tag="):
			tag = arg.substr(6)
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
	var gap := 9.0 if subject == "cart" else 16.0
	var current := Node3D.new()
	current.position = Vector3(-gap, 0, 0)
	root.add_child(current)
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(trial_path, state)
	if err != OK:
		push_error("w12_gen2_side: cannot read %s (%d)" % [trial_path, err])
		quit(1)
		return
	var trial: Node3D = doc.generate_scene(state)
	trial.position = Vector3(gap, 0, 0)
	root.add_child(trial)
	if subject == "cart":
		var body: Node3D = (load("res://assets/models/dig_mechanical/cart_body.glb") as PackedScene).instantiate()
		body.scale = Vector3.ONE * CART_SCALE
		current.add_child(body)
		for socket in CART_SOCKETS:
			var wheel: Node3D = (load("res://assets/models/dig_mechanical/cart_wheel.glb") as PackedScene).instantiate()
			wheel.position = socket * CART_SCALE
			wheel.scale = Vector3.ONE * CART_SCALE
			current.add_child(wheel)
		trial.scale = Vector3.ONE * CART_SCALE
	else:
		var beacon := Beacon.new()
		current.add_child(beacon)
		beacon.setup()
	_slots(current, "today")
	_slots(trial, "trial")
	var ball := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = Tuning.RADIUS
	sphere.height = Tuning.RADIUS * 2.0
	ball.mesh = sphere
	ball.position = Vector3(0, Tuning.RADIUS, 4.0)
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color("e6d9b8")
	ball.material_override = bm
	root.add_child(ball)
	var cam := Camera3D.new()
	cam.fov = 60.0
	root.add_child(cam)
	var views := {"cart": [Vector3(0, 9, 30), Vector3(0, 1.5, 0)], "beacon": [Vector3(0, 16, 62), Vector3(0, 9, 0)]}
	cam.look_at_from_position(views[subject][0], views[subject][1])
	cam.current = true
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(out.path_join("%s_arena.png" % tag))
	cam.look_at_from_position(views[subject][0] * 0.45 + Vector3(0, 1, 0), views[subject][1])
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(out.path_join("%s_near.png" % tag))
	print("W12_GEN2_SIDE ", subject, " ", tag, " ball_radius=", Tuning.RADIUS)
	quit(0)
