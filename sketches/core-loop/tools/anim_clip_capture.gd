extends SceneTree


var _player: AnimationPlayer
var _steps: Array = []
var _left := 0.0


func _initialize() -> void:
	var glb := ""
	var seq := ""
	var distance := 18.0
	var height := 0.35
	var yaw := 35.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--glb="): glb = a.trim_prefix("--glb=")
		elif a.begins_with("--seq="): seq = a.trim_prefix("--seq=")
		elif a.begins_with("--distance="): distance = float(a.trim_prefix("--distance="))
		elif a.begins_with("--height="): height = float(a.trim_prefix("--height="))
		elif a.begins_with("--yaw="): yaw = float(a.trim_prefix("--yaw="))
	if glb.is_empty() or seq.is_empty() or not ResourceLoader.exists(glb):
		printerr("anim_clip_capture: needs --glb=<existing res path> and --seq=clip[@blend]:seconds,...")
		quit(2)
		return
	var model := (load(glb) as PackedScene).instantiate() as Node3D
	root.add_child(model)
	_player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _player == null:
		printerr("anim_clip_capture: %s has no AnimationPlayer" % glb)
		quit(2)
		return
	for part in seq.split(",", false):
		var head := part.get_slice(":", 0)
		var step := {"clip": head.get_slice("@", 0), "blend": float(head.get_slice("@", 1)) if "@" in head else 0.0,
			"seconds": float(part.get_slice(":", 1))}
		if not _player.has_animation(step.clip) or step.seconds <= 0.0:
			printerr("anim_clip_capture: bad step '%s' (clips: %s)" % [part, ", ".join(_player.get_animation_list())])
			quit(2)
			return
		_steps.append(step)
	var bounds := _bounds(model)
	var centre := bounds.get_center()
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(distance * 4.0, distance * 4.0)
	floor_mesh.mesh = plane
	floor_mesh.position = Vector3(centre.x, bounds.position.y, centre.z)
	root.add_child(floor_mesh)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	sun.shadow_enabled = true
	root.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.6, 0.66)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.62, 0.66)
	root.add_child(env)
	var camera := Camera3D.new()
	var dir := Vector3(sin(deg_to_rad(yaw)), height, cos(deg_to_rad(yaw))).normalized()
	camera.look_at_from_position(centre + dir * distance, centre)
	root.add_child(camera)
	camera.current = true
	_next()


func _process(delta: float) -> bool:
	_left -= delta
	if _left <= 0.0:
		_next()
	return false


func _next() -> void:
	if _steps.is_empty():
		quit(0)
		return
	var step: Dictionary = _steps.pop_front()
	_player.play(step.clip, step.blend)
	_left += step.seconds
	print("anim_clip_capture: %s blend %.2f for %.2f s" % [step.clip, step.blend, step.seconds])


func _to_model(node: Node3D, model: Node) -> Transform3D:
	var t := node.transform
	var up := node.get_parent()
	while up != null and up != model.get_parent():
		if up is Node3D:
			t = (up as Node3D).transform * t
		up = up.get_parent()
	return t


func _bounds(node: Node) -> AABB:
	var box := AABB()
	var first := true
	for found in node.find_children("*", "VisualInstance3D", true, false):
		var vis := found as VisualInstance3D
		var b := _to_model(vis, node) * vis.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box
