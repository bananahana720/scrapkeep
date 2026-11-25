extends RefCounted

const Palette := preload("res://src/core/palette.gd")


var title := ""
var spawn := Vector2.ZERO
var heading := Vector3(0.0, 0.0, 1.0)
var beacon := Vector2.ZERO
var scrap_lines: Array = []
var scrap_trail := {}
var basin := {}
var sites := {}
var unique_events: Array[String] = []
var play_rect := Rect2(-150.0, -150.0, 300.0, 300.0)
var vault := Vector2.ZERO
var beacon_floor := 0.0
var kickers: Array = []
var gate_slots: Array = []
var activity_sites: Array = []
var scatter := {
	"kit": [], "relief": {}, "clear": {"spawn": 6.0, "beacon": 31.0, "vault": 11.0},
	"clusters": 110, "edge_share": 0.6, "spacing": 9.0, "apron": 8.0, "mix": {}, "per_preset": {},
}


func off_line(p: Vector2) -> float:
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p, spawn, beacon))


func near_kicker_lip(p: Vector2) -> bool:
	for k in kickers:
		var rel: Vector2 = p - (k["at"] as Vector2)
		var dir: Vector2 = k["dir"]
		var u := rel.dot(dir)
		var v := absf(rel.dot(Vector2(-dir.y, dir.x)))
		if u > -6.0 and u < 4.0 and v < float(k["width"]) * 0.5 + 1.0:
			return true
	return false


func sample(_x: float, _z: float) -> Array:
	return [0.0, Palette.SAND]


func material_at(_x: float, _z: float) -> String:
	return "sand"


func build_props(_parent: Node3D, _ground: Callable) -> void:
	pass


func overlay_height(_id: String, _x: float, _z: float, _ground: float) -> float:
	return -INF


static func box(parent: Node3D, size: Vector3, origin: Vector3, mat: Material, turn := 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = origin
	body.rotation.y = turn
	var mesh := MeshInstance3D.new()
	var shape_mesh := BoxMesh.new()
	shape_mesh.size = size
	mesh.mesh = shape_mesh
	mesh.material_override = mat
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	body.add_child(mesh)
	parent.add_child(body)
	return body


static func cylinder(parent: Node3D, radius: float, height_m: float, origin: Vector3, mat: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = origin
	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = height_m
	mesh.mesh = cyl
	mesh.material_override = mat
	var shape := CollisionShape3D.new()
	var cyl_shape := CylinderShape3D.new()
	cyl_shape.radius = radius
	cyl_shape.height = height_m
	shape.shape = cyl_shape
	body.add_child(shape)
	body.add_child(mesh)
	parent.add_child(body)
	return body


static func grapple_post(parent: Node3D, foot: Vector3, height_m: float) -> void:
	cylinder(parent, 0.9, height_m, foot + Vector3.UP * height_m * 0.5, Palette.solid(Palette.COPPER))
	var cap := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 1.4
	ball.height = 2.8
	cap.mesh = ball
	cap.material_override = Palette.solid(Palette.AMBER, 1.2)
	cap.position = foot + Vector3.UP * (height_m + 0.6)
	parent.add_child(cap)


static func pylon_wall(parent: Node3D, foot: Vector3, length: float, height_m: float, turn: float) -> void:
	box(parent, Vector3(length, height_m, 1.6), foot + Vector3.UP * (height_m * 0.5 - 0.5),
		dressed_surface(Palette.VERDIGRIS, 0, Vector3(length, height_m, 1.6)), turn)


const SURFACE_SHADER_PATH := "res://assets/materials/gpw_workshop.gdshader"
static var surface_shader_path := SURFACE_SHADER_PATH
static var _surface_materials := {}
static var _surface_warnings := {}


static func reset_for_tests() -> void:
	surface_shader_path = SURFACE_SHADER_PATH
	_surface_materials.clear()
	_surface_warnings.clear()


static func dressed_surface(color: Color, kind := 1, size := Vector3.ZERO,
		fallback_color := Palette.CHARCOAL, original: Material = null) -> Material:
	var key := surface_shader_path + ":" + color.to_html() + ":" + str(kind) + ":" + str(size) + ":" + fallback_color.to_html() + ":" + (str(original.get_instance_id()) if original != null else "auto")
	if _surface_materials.has(key):
		return _surface_materials[key]
	var shader: Shader
	if ResourceLoader.exists(surface_shader_path, "Shader"):
		shader = load(surface_shader_path) as Shader
	if shader == null or shader.code.is_empty():
		if not _surface_warnings.has(surface_shader_path):
			_surface_warnings[surface_shader_path] = true
			push_warning("gpw: missing workshop shader " + surface_shader_path + "; using original surface fallback")
		var fallback: Material = original
		if fallback == null:
			fallback = Palette.solid(color) if kind == 1 else Palette.striped(color, fallback_color)
		_surface_materials[key] = fallback
		return fallback
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.resource_name = "gpw_" + str(kind)
	mat.set_shader_parameter("base_color", color)
	mat.set_shader_parameter("surface_kind", kind)
	mat.set_shader_parameter("half_extents", size * 0.5)
	mat.set_shader_parameter("chip_width", 0.065)
	_surface_materials[key] = mat
	return mat
