extends SceneTree


const ROGUES := {
	"gate_crane": {"prefix": "GateCrane", "bones": ["CraneBody", "CraneJib", "CraneHook", "CraneLeaf",
		"CranePlateLeft", "CranePlateRight", "CraneGovernor"]},
	"haul_skip": {"prefix": "HaulSkip", "bones": ["SkipBody", "SkipBucket", "SkipWheel0", "SkipWheel1",
		"SkipWheel2", "SkipWheel3", "SkipPlateLeft", "SkipPlateRight", "SkipGovernor"]},
	"cable_tender": {"prefix": "CableTender", "bones": ["TenderBody", "TenderSpool", "TenderBoom",
		"TenderHarpoon", "TenderPlateLeft", "TenderPlateRight", "TenderGovernor"]},
}
var failures := 0


func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
	print("%s %s" % ["PASS" if ok else "FAIL", label])


func _initialize() -> void:
	for kind in ROGUES:
		_run(kind, ROGUES[kind])
	print("rogue_glb_check: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _run(kind: String, spec: Dictionary) -> void:
	var path := "res://assets/models/rogues/%s.glb" % kind
	var packed := load(path) as PackedScene if ResourceLoader.exists(path) else null
	_check(packed != null, kind + " GLB loads")
	if packed == null:
		return
	var asset := packed.instantiate()
	var tris := 0
	var vertices := 0
	var draws := 0
	var opaque := true
	for child in asset.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(s)
			vertices += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			tris += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
			draws += 1
			var material := mi.mesh.surface_get_material(s)
			opaque = opaque and material is BaseMaterial3D and material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED
	print("%s: %d T / %d V / %d D" % [kind, tris, vertices, draws])
	_check(tris > 0 and tris <= 8800 and vertices <= 4900 and draws == 3, kind + " fits shared enemy budget")
	_check(opaque, kind + " opaque")
	var rig := asset.find_child("Skeleton3D", true, false) as Skeleton3D
	_check(rig != null, kind + " has a pose skeleton")
	if rig != null:
		for name in spec.bones:
			_check(rig.find_bone(name) >= 0, kind + " bone " + name)
	var prefix: String = spec.prefix
	for part in ["Hull", "Armour", "Core"]:
		var mi := asset.find_child(prefix + part, true, false) as MeshInstance3D
		_check(mi != null and mi.mesh is ArrayMesh, kind + " mesh " + prefix + part)
		if mi == null or part == "Core" or rig == null:
			continue
		_check(mi.skin != null and mi.get_node_or_null(mi.skeleton) == rig, prefix + part + " skin binds to skeleton")
		var arrays := mi.mesh.surface_get_arrays(0)
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var rigid := weights.size() == bones.size() and weights.size() > 0
		var used := {}
		for v in weights.size() / 4:
			var bound := 0
			var total := 0.0
			for i in 4:
				var w := weights[v * 4 + i]
				total += w
				if w > 0.001:
					bound += 1
					used[mi.skin.get_bind_name(bones[v * 4 + i])] = true
			rigid = rigid and bound == 1 and is_equal_approx(total, 1.0)
		_check(rigid, prefix + part + " rigid one-bone weights")
		print("  %s drives %s" % [prefix + part, ", ".join(used.keys())])
	asset.free()
