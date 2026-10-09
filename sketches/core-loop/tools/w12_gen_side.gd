extends SceneTree

# Probe P-GEN side-by-side: today's asset (left) and the generated trial GLB (right) at the same scale,
# the player ball between them as the mannequin, one camera at arena distance.
#   godot --path sketches/core-loop --script res://tools/w12_gen_side.gd -- --out=<abs dir> --subject=cart|beacon

const Tuning := preload("res://src/movement/tuning.gd")
const Beacon := preload("res://src/core/beacon.gd")
const CART_SCALE := 2.2
const CART_SOCKETS := [Vector3(-0.74, 0.3, -0.95), Vector3(0.74, 0.3, -0.95), Vector3(-0.74, 0.3, 0.95), Vector3(0.74, 0.3, 0.95)]


func _init() -> void:
	var out := ""
	var subject := "cart"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
		elif arg.begins_with("--subject="):
			subject = arg.substr(10)
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
	var trial: Node3D = (load("res://assets/models/trial_w12_%s.glb" % subject) as PackedScene).instantiate()
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
	var img := get_root().get_texture().get_image()
	img.save_png(out.path_join("%s_arena.png" % subject))
	cam.look_at_from_position(views[subject][0] * 0.45 + Vector3(0, 1, 0), views[subject][1])
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(out.path_join("%s_near.png" % subject))
	print("W12_GEN_SIDE ", subject, " ball_radius=", Tuning.RADIUS)
	quit(0)
