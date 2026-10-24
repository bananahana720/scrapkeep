extends SceneTree

# Boom Tender No. 22 asset contract (tools/blender/world_one/enemy_boom_tender.py), static: the
# loader (src/combat/boom_tender.gd) reads meshes by node name, the fleet_paint surface is the flash
# surface, vertex colours are the albedo, and it lays the one float five times plus a small buoy.
# Three meshes of one surface each: the enemy budget class's 3 draws (assets/asset_budgets.json).
# Godot axes: forward is -Z, the origin is the ground under the hull centre.

const PATH := "res://assets/models/world_one/enemy_boom_tender.glb"
const CEILING_T := 10000
const CEILING_D := 3
const MESHES := ["TenderHull", "TenderReel", "BoomFloat"]
# Pivots: the reel axle runs across the hull width; the one float sits at float 0's place, 0.9 m
# long, just past the hull front (boom_tender.gd FLOAT_OUT lays the rest 1.3 m apart).
const PIVOTS := {"TenderHull": Vector3.ZERO, "TenderReel": Vector3(0, 1.5, 0.5), "BoomFloat": Vector3(0, 0.85, -2.07)}
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
	print("%s %s" % ["PASS" if ok else "FAIL", label])


func _run() -> void:
	var packed := load(PATH) as PackedScene
	_check(packed != null, "enemy_boom_tender.glb loads")
	if packed == null:
		quit(1)
		return
	var scene := packed.instantiate() as Node3D
	root.add_child(scene)
	var tris := 0
	var draws := 0
	var opaque := true
	var coloured := true
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	var found := {}
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		found[String(mi.name)] = mi
		for s in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(s)
			var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var idx = arrays[Mesh.ARRAY_INDEX]
			tris += (idx.size() if idx != null else vs.size()) / 3
			draws += 1
			coloured = coloured and arrays[Mesh.ARRAY_COLOR] != null and (arrays[Mesh.ARRAY_COLOR] as PackedColorArray).size() == vs.size()
			var mat := mi.mesh.surface_get_material(s)
			opaque = opaque and mat is BaseMaterial3D and (mat as BaseMaterial3D).transparency == BaseMaterial3D.TRANSPARENCY_DISABLED
			var to_scene: Transform3D = scene.global_transform.affine_inverse() * mi.global_transform
			for v in vs:
				var p: Vector3 = to_scene * v
				lo = lo.min(p)
				hi = hi.max(p)
	print("asset: %d T, %d D, bounds x %.2f..%.2f y %.2f..%.2f z %.2f..%.2f" % [tris, draws, lo.x, hi.x, lo.y, hi.y, lo.z, hi.z])
	_check(tris > 0 and tris <= CEILING_T, "asset triangles %d <= %d" % [tris, CEILING_T])
	_check(draws <= CEILING_D, "asset draws %d <= %d" % [draws, CEILING_D])
	_check(opaque, "every surface is opaque")
	_check(coloured, "every surface carries vertex colours (the albedo)")
	for name in MESHES:
		var mi := found.get(name) as MeshInstance3D
		_check(mi != null and mi.mesh is ArrayMesh, "mesh %s present" % name)
		if mi == null:
			continue
		var at: Vector3 = (scene.global_transform.affine_inverse() * mi.global_transform).origin
		_check(at.is_equal_approx(PIVOTS[name]) or at.distance_to(PIVOTS[name]) < 0.005,
			"%s origin at its pivot %s (%s)" % [name, PIVOTS[name], at])
	_check(found.size() == MESHES.size(), "exactly the %d named meshes (%d)" % [MESHES.size(), found.size()])
	var hull := found.get("TenderHull") as MeshInstance3D
	var flash := -1
	if hull != null:
		for s in hull.mesh.get_surface_count():
			var mat := hull.mesh.surface_get_material(s)
			if mat != null and mat.resource_name == "fleet_paint":
				flash = s
	_check(flash >= 0, "TenderHull carries the fleet_paint (flash) surface")
	for name in MESHES:
		if name == "TenderHull" or not found.has(name):
			continue
		var mi := found[name] as MeshInstance3D
		var has := false
		for s in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(s)
			has = has or (mat != null and mat.resource_name == "fleet_paint")
		_check(not has, "%s does not carry fleet_paint (the flash is the hull's)" % name)
	_check(absf(lo.y) < 0.01, "ground at the origin (y min %.3f)" % lo.y)
	_check(absf(hi.y - 2.3) < 0.03, "reel top 2.3 m above ground (%.3f)" % hi.y)
	_check(absf(hi.x - 1.2) < 0.06 and absf(lo.x + 1.2) < 0.06, "2.4 m wide (x %.2f..%.2f)" % [lo.x, hi.x])
	_check(absf(hi.z - 1.6) < 0.03, "hull stern at z 1.6 (3.2 m hull about the origin, %.3f)" % hi.z)
	_check(absf(lo.z + 2.72) < 0.03, "the float's cable stub ends half a gap past it (z min %.3f)" % lo.z)
	var reel_mi := found.get("TenderReel") as MeshInstance3D
	if reel_mi != null:
		var aabb := reel_mi.mesh.get_aabb()
		_check(absf(aabb.size.y - 1.6) < 0.03 and absf(aabb.size.z - 1.6) < 0.03,
			"reel is 1.6 m across with its axle along X (aabb %s)" % aabb.size)
	scene.free()
	print("enemy_boom_tender_asset_test: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
