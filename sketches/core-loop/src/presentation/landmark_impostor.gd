extends Node3D

const FAR_SHARE := 0.8

var radius := 0.0
var stand_in: Node3D
var own_views: Array = []


static func make(landmark: Node3D, far_scene: Node, views: Array = []) -> Node3D:
	var impostor := new()
	impostor.name = "LandmarkImpostor"
	impostor.own_views = views
	landmark.add_child(impostor)
	impostor._build(far_scene)
	return impostor


func _build(far_scene: Node) -> void:
	stand_in = Node3D.new()
	stand_in.name = "StandIn"
	stand_in.top_level = true
	stand_in.visible = false
	add_child(stand_in)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	var stack: Array = [[far_scene, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var item: Array = stack.pop_back()
		var node: Node = item[0]
		var at: Transform3D = item[1]
		if node is Node3D and node != far_scene:
			at = at * (node as Node3D).transform
		for child in node.get_children():
			stack.append([child, at])
		if node is MeshInstance3D and not String(node.name).ends_with("-col") and (node as MeshInstance3D).mesh != null:
			var view := MeshInstance3D.new()
			view.name = node.name
			view.mesh = (node as MeshInstance3D).mesh
			view.transform = at
			view.material_override = material
			view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			stand_in.add_child(view)
			for v: Vector3 in view.mesh.get_faces():
				radius = maxf(radius, (at * v).length())


func _process(_delta: float) -> void:
	var viewport := get_viewport()
	var camera := viewport.get_camera_3d() if viewport != null else null
	if camera != null and stand_in != null:
		show_for(camera.global_position, camera.far)


func scale_for(eye: Vector3, far: float) -> float:
	return reach_scale(global_position, radius, eye, far)


func impostor(eye: Vector3, far: float) -> Transform3D:
	return about_eye(global_transform, radius, eye, far)


static func reach_scale(origin: Vector3, reach_radius: float, eye: Vector3, far: float) -> float:
	var reach := far * FAR_SHARE
	var span := origin.distance_to(eye) + reach_radius
	return 1.0 if span <= reach else reach / span


static func about_eye(own: Transform3D, reach_radius: float, eye: Vector3, far: float) -> Transform3D:
	var k := reach_scale(own.origin, reach_radius, eye, far)
	return Transform3D(own.basis.scaled(Vector3.ONE * k), eye + (own.origin - eye) * k)


func show_for(eye: Vector3, far: float) -> bool:
	var on := scale_for(eye, far) < 1.0
	stand_in.visible = on
	if on:
		stand_in.global_transform = impostor(eye, far)
	for view in own_views:
		if is_instance_valid(view):
			(view as Node3D).visible = not on
	return on
