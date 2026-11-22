extends Node3D

# The long-range stand-in for a park's hero landmark (LANDMARK-CARDS.md port note P7). The chase camera's far plane is
# 700 m (chase_camera.gd) and every drop-in is 1.17 to 1.43 km from its landmark, so the landmark's own views are clipped
# from the drop-in whatever their visibility ranges. Once any part of the landmark would stand past FAR_SHARE of the far
# plane, its far view (<recipe>_far.glb) draws in its place, scaled about the eye by k = far x FAR_SHARE / (distance +
# radius): every vertex stays on the ray it had, so it covers the same pixels, and its farthest point stays inside the
# far plane. The landmark's own views hide while it shows. The same method as landmark_beam.gd's impostor; it is a child
# of the landmark node, so it follows the landmark's transform.

const FAR_SHARE := 0.8

# The farthest far-view vertex from the landmark's origin, in metres.
var radius := 0.0
# The scaled copy of the far view (top_level, so the impostor moves it alone) and the landmark's own views.
var stand_in: Node3D
var own_views: Array = []


# A stand-in under landmark built from far_scene (an instantiated <recipe>_far.glb, kept by the caller); views are the
# landmark's own drawn nodes, hidden while the stand-in shows.
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


# The scale the stand-in takes for an eye with far plane far: 1 while the whole landmark stands inside FAR_SHARE of it.
func scale_for(eye: Vector3, far: float) -> float:
	return reach_scale(global_position, radius, eye, far)


# The stand-in's world transform for that eye: the landmark's own, scaled about the eye by scale_for.
func impostor(eye: Vector3, far: float) -> Transform3D:
	return about_eye(global_transform, radius, eye, far)


# The method for any far stand-in (the landmark's, the smoke column's): the scale for a thing at origin reaching radius
# from it, 1 while all of it stands inside FAR_SHARE of the far plane.
static func reach_scale(origin: Vector3, reach_radius: float, eye: Vector3, far: float) -> float:
	var reach := far * FAR_SHARE
	var span := origin.distance_to(eye) + reach_radius
	return 1.0 if span <= reach else reach / span


# own scaled about the eye by reach_scale: every vertex stays on its ray from the eye, so the thing covers the same
# pixels, and its farthest point stays inside the far plane.
static func about_eye(own: Transform3D, reach_radius: float, eye: Vector3, far: float) -> Transform3D:
	var k := reach_scale(own.origin, reach_radius, eye, far)
	return Transform3D(own.basis.scaled(Vector3.ONE * k), eye + (own.origin - eye) * k)


# Shows the stand-in (and hides the landmark's views) when the landmark reaches past FAR_SHARE; returns whether it shows.
func show_for(eye: Vector3, far: float) -> bool:
	var on := scale_for(eye, far) < 1.0
	stand_in.visible = on
	if on:
		stand_in.global_transform = impostor(eye, far)
	for view in own_views:
		if is_instance_valid(view):
			(view as Node3D).visible = not on
	return on
