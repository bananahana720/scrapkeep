extends Node3D

# The ancient beam (design-v3/PARK.md section 4 `light`, LANDMARK-CARDS.md port note P2): one uranium-glass column that
# keeps a park's hero landmark readable from the drop-in, the same on every stage and at every LOD. It is a child of the
# landmark node, stands vertical from its bottom (the GLB's beam_root, or the proxy's) to TOP_ABOVE_M over the sight
# point, is unshaded, ignores fog and casts no shadow. The chase camera's far plane is 700 m (chase_camera.gd) and every
# drop-in is 1.17 to 1.43 km from its landmark, so past FAR_SHARE of the far plane the column is drawn as its impostor:
# scaled toward the camera by far / distance, which projects to the same pixels while staying inside the far plane. The
# share leaves room for the column's top, which stands farther from the eye than its foot.
# Its bottom never sits inside the fight: at least CLEAR_ABOVE_M over the Warden's anchor, so the Warden's own window
# beam stays the only beam in the bowl (LOOP-REDESIGN.md section 2, "It is open now").

const Palette := preload("res://src/core/palette.gd")

const CORE_RADIUS_M := 3.0
const CORE_ALPHA := 0.85
const VEIL_RADIUS_M := 9.0
const VEIL_ALPHA := 0.18
const TOP_ABOVE_M := 300.0
const CLEAR_ABOVE_M := 30.0
const FAR_SHARE := 0.8
const SIDES := 16
# Near the column it must read as light, not a wall (PF-28): full alpha from FAR_FULL_M out, eased down to NEAR_SHARE of it
# at NEAR_M and inside. 220 m is where the column is a signpost, 60 m where it fills the view; 0.3 keeps it visible.
const FAR_FULL_M := 220.0
const NEAR_M := 60.0
const NEAR_SHARE := 0.3
const Shade := preload("res://src/presentation/landmark_beam.gdshader")

# The column in world space when it is not an impostor, and its view (top_level, so the impostor moves it alone).
var bottom := Vector3.ZERO
var top_y := 0.0
var column: Node3D
var _layers: Array[ShaderMaterial] = []
var _alphas: Array[float] = []


# A beam under parent from bottom (world) up to sight_top_y + TOP_ABOVE_M, lifted to anchor_y + CLEAR_ABOVE_M.
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


# The alpha a layer of base layer_alpha holds for an eye distance_m (horizontal) from the axis: the one rule for nearness.
static func near_alpha(layer_alpha: float, distance_m: float) -> float:
	var t := clampf((distance_m - NEAR_M) / (FAR_FULL_M - NEAR_M), 0.0, 1.0)
	return layer_alpha * lerpf(NEAR_SHARE, 1.0, t * t * (3.0 - 2.0 * t))


# Sets each layer's drawn alpha and edge softness for an eye; far away it holds today's values and a hard edge.
func fade_for(eye: Vector3) -> void:
	var distance := Vector2(bottom.x - eye.x, bottom.z - eye.z).length()
	for i in _layers.size():
		var alpha := near_alpha(_alphas[i], distance)
		_layers[i].set_shader_parameter("layer_alpha", alpha)
		_layers[i].set_shader_parameter("edge", 1.0 - (alpha / _alphas[i] - NEAR_SHARE) / (1.0 - NEAR_SHARE))


# The column's transform for a camera at eye with far plane far: as built inside FAR_SHARE of it, else scaled about the
# eye by (far x FAR_SHARE) / distance to the column's axis, so it projects the same and stays drawn.
func impostor(eye: Vector3, far: float) -> Transform3D:
	var base := Transform3D(Basis.IDENTITY, bottom)
	var reach := far * FAR_SHARE
	var distance := Vector2(bottom.x - eye.x, bottom.z - eye.z).length()
	if distance <= reach or distance <= 0.0:
		return base
	var k := reach / distance
	return Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * k), eye + (bottom - eye) * k)
