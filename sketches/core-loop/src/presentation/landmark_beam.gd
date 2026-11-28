extends Node3D

const Palette := preload("res://src/core/palette.gd")

const CORE_RADIUS_M := 3.0
const CORE_ALPHA := 0.85
const VEIL_RADIUS_M := 9.0
const VEIL_ALPHA := 0.18
const TOP_ABOVE_M := 300.0
const CLEAR_ABOVE_M := 30.0
const FAR_SHARE := 0.8
const SIDES := 16
const BEAM_LAYERS := 2
const FAR_FULL_M := 220.0
const NEAR_M := 60.0
const NEAR_SHARE := 0.3
const Shade := preload("res://src/presentation/landmark_beam.gdshader")

var bottom := Vector3.ZERO
var top_y := 0.0
var column: Node3D
var _layers: Array[ShaderMaterial] = []
var _alphas: Array[float] = []


static func make(parent: Node3D, from: Vector3, sight_top_y: float, anchor_y: float) -> Node3D:
	var beam := new()
	beam.name = "AncientBeam"
	beam.bottom = Vector3(from.x, maxf(from.y, anchor_y + CLEAR_ABOVE_M), from.z)
	beam.top_y = sight_top_y + TOP_ABOVE_M
	parent.add_child(beam)
	beam._build()
	return beam


func height() -> float:
	return top_y - bottom.y


func _build() -> void:
	column = Node3D.new()
	column.name = "Column"
	column.top_level = true
	add_child(column)
	column.global_transform = Transform3D(Basis.IDENTITY, bottom)
	for layer: Array in [["Core", CORE_RADIUS_M, CORE_ALPHA], ["Veil", VEIL_RADIUS_M, VEIL_ALPHA]]:
		var mesh := CylinderMesh.new()
		mesh.top_radius = layer[1]
		mesh.bottom_radius = layer[1]
		mesh.height = height()
		mesh.radial_segments = SIDES
		mesh.rings = 1
		mesh.cap_top = false
		mesh.cap_bottom = false
		var view := MeshInstance3D.new()
		view.name = layer[0]
		view.mesh = mesh
		var material := ShaderMaterial.new()
		material.shader = Shade
		material.set_shader_parameter("tint", Color(Palette.ANCIENT, 1.0))
		material.set_shader_parameter("layer_alpha", layer[2])
		_layers.append(material)
		_alphas.append(layer[2])
		view.material_override = material
		view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		view.position.y = height() * 0.5
		column.add_child(view)


func _process(_delta: float) -> void:
	var viewport := get_viewport()
	var camera := viewport.get_camera_3d() if viewport != null else null
	if camera == null or column == null:
		return
	column.global_transform = impostor(camera.global_position, camera.far)
	fade_for(camera.global_position)


static func near_alpha(layer_alpha: float, distance_m: float) -> float:
	var t := clampf((distance_m - NEAR_M) / (FAR_FULL_M - NEAR_M), 0.0, 1.0)
	return layer_alpha * lerpf(NEAR_SHARE, 1.0, t * t * (3.0 - 2.0 * t))


func fade_for(eye: Vector3) -> void:
	var distance := Vector2(bottom.x - eye.x, bottom.z - eye.z).length()
	for i in _layers.size():
		var alpha := near_alpha(_alphas[i], distance)
		_layers[i].set_shader_parameter("layer_alpha", alpha)
		_layers[i].set_shader_parameter("edge", 1.0 - (alpha / _alphas[i] - NEAR_SHARE) / (1.0 - NEAR_SHARE))


func impostor(eye: Vector3, far: float) -> Transform3D:
	var base := Transform3D(Basis.IDENTITY, bottom)
	var reach := far * FAR_SHARE
	var distance := Vector2(bottom.x - eye.x, bottom.z - eye.z).length()
	if distance <= reach or distance <= 0.0:
		return base
	var k := reach / distance
	return Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * k), eye + (bottom - eye) * k)
