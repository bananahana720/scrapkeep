extends RefCounted

const Palette := preload("res://src/core/palette.gd")

# One stage's shape as data plus a height function. The terrain builds the ground
# from sample(), and every other question (where you spawn, where the beacon stands,
# where an event's ring is, where the flood can rise) is answered from these fields,
# so the geometry and the events that use it cannot disagree.

var title := ""
var spawn := Vector2.ZERO
var heading := Vector3(0.0, 0.0, 1.0)
var beacon := Vector2.ZERO
var scrap_lines: Array = []
# The line scrap is laid along to the beat (scrap_field.gd lay_trail), with no gears and no fabricator hoops:
# {"points": PackedVector2Array, "spacing_m", "phrase", "rest", "gaps": [[from_m, to_m]] along the line where no piece
# stands}. Empty for a map with none.
var scrap_trail := {}
# The flood's bowl: centre (Vector2), radius, depth (m of water at full), plane_size
# (Vector2) and plane_centre (Vector2). Empty for a map with no basin.
var basin := {}
# Participatory event sites keyed by event id. Each holds what that event needs:
# "ring" (Vector2, the start ring), plus "route" (PackedVector2Array) for a surge run
# or a stampede, or "relay" (Vector2) for a hold.
var sites := {}
# Events this map carries whatever stage_defs' event_mix says: an event unique to a map.
var unique_events: Array[String] = []
# Where spawns and rescues stay: the playable floor inside the rim walls.
var play_rect := Rect2(-150.0, -150.0, 300.0, 300.0)
# The plated vault's spot: off the fall line, on a plinth, with a downhill way back.
var vault := Vector2.ZERO
# The beacon bowl's floor height; the Warden stands on it.
var beacon_floor := 0.0
# Spots where the ball leaving the ground counts as a kicker launch (codex): each is
# {"at": Vector2 lip, "dir": Vector2, "width": float}.
var kickers: Array = []
# Where the reward gates stand when the Warden breaks, each {"at": Vector2, "facing": Vector3}.
# Empty means the gates are placed ahead of the ball.
var gate_slots: Array = []
# Where the activity builders put their sites, each {"id": String, "at": Vector2}. Empty by default.
var activity_sites: Array = []
# The ground's visual dressing, one table per map (read by terrain.gd, scatter.gd, set_dressing.gd,
# dig_scenery.gd and highdraft_scenery.gd; presentation only, never a collider):
#   kit        scatter rows (src/world/scatter_rows.gd lists the fields): one MultiMesh per row
#   relief     {sub, amp, period, shade, seed}: the 1 m view mesh over the 2 m collider grid, empty for none
#   clear      metres kept bare round the spawn, the beacon and the vault
#   clusters, edge_share, spacing   the target preset's clutter clusters (set_dressing.gd)
#   apron      metres outside the play rect where the Dig's rim props stand (dig_scenery.gd)
#   mix        the Dig's rim prop counts per edge (dig_scenery.gd)
#   per_preset  Highdraft's props per island by size (highdraft_scenery.gd)
var scatter := {
	"kit": [], "relief": {}, "clear": {"spawn": 6.0, "beacon": 31.0, "vault": 11.0},
	"clusters": 110, "edge_share": 0.6, "spacing": 9.0, "apron": 8.0, "mix": {}, "per_preset": {},
}


# How far p is from the fall line, the straight run from the spawn to the beacon. The
# v2 route contract (world_route_test) reads this.
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


# [height, tint]. The tint is the ground's own reading of the feature it belongs to.
func sample(_x: float, _z: float) -> Array:
	return [0.0, Palette.SAND]


func material_at(_x: float, _z: float) -> String:
	return "sand"


func build_props(_parent: Node3D, _ground: Callable) -> void:
	pass


# A live terrain change's height at (x, z) over the ground, or -INF where it has none.
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


# A grapple post: a tall copper mast with an amber cap, the movement colour, so a hook
# point reads as one from across the stage.
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


# A pylon wall: a sheer concrete slab in the verdigris the ground uses for any face a
# pylon can bite, so the engineer can read a turret spot at a glance.
static func pylon_wall(parent: Node3D, foot: Vector3, length: float, height_m: float, turn: float) -> void:
	box(parent, Vector3(length, height_m, 1.6), foot + Vector3.UP * (height_m * 0.5 - 0.5),
		dressed_surface(Palette.VERDIGRIS, 0, Vector3(length, height_m, 1.6)), turn)


# Mesh-local metres keep arbitrary slabs and the moving bay's paint from stretching.
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
