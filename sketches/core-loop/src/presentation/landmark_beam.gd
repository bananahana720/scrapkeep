extends Node3D

# The ancient beam (design-v3/PARK.md section 4 `light`, LANDMARK-CARDS.md port note P2): one uranium-glass column that
# keeps a park's hero landmark readable from the drop-in, the same on every stage and at every LOD. It is a child of the
# landmark node, stands vertical from its bottom (the GLB's beam_root, or the proxy's) to TOP_ABOVE_M over the sight
# point, is unshaded, ignores fog and casts no shadow. The chase camera's far plane is 700 m (chase_camera.gd) and every
# drop-in is 1.17 to 1.43 km from its landmark, so past FAR_SHARE of the far plane the column is drawn as its impostor:
# scaled toward the camera by far / distance, which projects to the same pixels while staying inside the far plane.
# Its bottom never sits inside the fight: at least CLEAR_ABOVE_M over the Warden's anchor, so the Warden's own window
# beam stays the only beam in the bowl (LOOP-REDESIGN.md section 2, "It is open now").

const Palette := preload("res://src/core/palette.gd")

const CORE_RADIUS_M := 3.0
const CORE_ALPHA := 0.85
const VEIL_RADIUS_M := 9.0
const VEIL_ALPHA := 0.18
const TOP_ABOVE_M := 300.0
const CLEAR_ABOVE_M := 30.0
const FAR_SHARE := 0.9
const SIDES := 16

# The column in world space when it is not an impostor, and its view (top_level, so the impostor moves it alone).
var bottom := Vector3.ZERO
var top_y := 0.0
var column: Node3D


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
		var color := Palette.ANCIENT
		color.a = layer[2]
		var material := Palette.unshaded(color)
		material.disable_fog = true
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
