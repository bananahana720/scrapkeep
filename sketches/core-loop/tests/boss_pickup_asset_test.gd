extends SceneTree

const Game := preload("res://src/game.gd")
const Boss := preload("res://src/boss/boss.gd")
const Palette := preload("res://src/core/palette.gd")
const ScrapField := preload("res://src/build/scrap_field.gd")
const GLB := "res://assets/models/bosses/boss_pickup.glb"
const BASE_LOGIC_SHA := "99a176876c1ba7481d6fdf281f7497d708a11e00b796a04da2631062d574e2f1"

var failures := 0
var game


func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
	print("%s -> %s" % [label, "PASS" if ok else "FAIL"])


func _finish() -> void:
	print("boss_pickup_asset_test: %s" % ("PASS" if failures == 0 else "FAIL"))
	if game != null:
		game.free()
	quit(0 if failures == 0 else 1)


func _measure(node: Node3D) -> Dictionary:
	var tris := 0
	var vertices := 0
	var draws := 0
	var primitive := 0
	var opaque := true
	var low := Vector3(INF, INF, INF)
	var high := -low
	var meshes := node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		meshes.append(node)
	for found in meshes:
		var mi := found as MeshInstance3D
		if mi.mesh == null:
			opaque = false
			continue
		if mi.mesh is PrimitiveMesh:
			primitive += 1
		var xf := mi.transform
		var ancestor := mi.get_parent()
		while ancestor != node and ancestor is Node3D:
			xf = ancestor.transform * xf
			ancestor = ancestor.get_parent()
		if mi == node:
			xf = Transform3D.IDENTITY
		for s in mi.mesh.get_surface_count():
			draws += 1
			var arrays := mi.mesh.surface_get_arrays(s)
			var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var ix = arrays[Mesh.ARRAY_INDEX]
			vertices += vs.size()
			tris += (ix.size() if ix != null else vs.size()) / 3
			for v in vs:
				var p: Vector3 = xf * v
				low = low.min(p)
				high = high.max(p)
			var mat := mi.get_surface_override_material(s) as BaseMaterial3D
			if mat == null:
				mat = mi.material_override as BaseMaterial3D
			if mat == null:
				mat = mi.mesh.surface_get_material(s) as BaseMaterial3D
			opaque = opaque and mat != null
			if mat != null:
				opaque = opaque and mat.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and mat.albedo_color.a >= 0.999
			if arrays[Mesh.ARRAY_COLOR] != null:
				for c in arrays[Mesh.ARRAY_COLOR] as PackedColorArray:
					opaque = opaque and c.a >= 0.999
	return {"tris": tris, "vertices": vertices, "draws": draws, "primitive": primitive,
		"opaque": opaque, "low": low, "high": high}


func _budget(node: Node3D, label: String) -> Dictionary:
	var m := _measure(node)
	print("%s: %d T / %d V / %d D" % [label, m.tris, m.vertices, m.draws])
	_check(m.tris > 0 and m.tris <= 1100 and m.vertices <= 2100 and m.draws > 0 and m.draws <= 3, label + " D3 budget")
	_check(m.opaque, label + " opaque materials")
	return m


func _named(node: Node, expected: Array) -> void:
	var names := []
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		names.append(String(mi.name))
	names.sort()
	_check(names == expected, "exact named mesh parts")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed := load(GLB) as PackedScene if ResourceLoader.exists(GLB) else null
	_check(packed != null, "GLB loads")
	if packed == null:
		_finish()
		return
	var scene := packed.instantiate()
	var asset := _budget(scene, "asset")
	_check(asset.tris <= 270 and asset.vertices <= 610 and asset.draws == 1, "single draw prop budget")
	_named(scene, ["ScrapChunk"])
	_check(asset.low.x >= -0.351 and asset.low.y >= -0.351 and asset.low.z >= -0.351
		and asset.high.x <= 0.351 and asset.high.y <= 0.351 and asset.high.z <= 0.351, "scrap inside existing 0.7 m cube")
	scene.free()
	game = Game.new()
	game.test_mode = true
	root.add_child(game)
	game.ctx.calm = true
	var boss = game.ctx.boss
	var arena := Node3D.new()
	game.add_child(arena)
	boss.arena = arena
	boss.clock = 0.25
	var at := Vector3(3, 4, 5)
	boss._spawn_pickup(at, 7, "spill")
	var pickup: MeshInstance3D = boss._pickups[0].node
	var live := _budget(pickup, "live")
	_check(pickup.name == "ScrapChunk" and live.primitive == 0, "primitive pickup no longer builds")
	_check(live.draws == 1, "single live draw")
	_check(pickup.find_children("*", "CollisionObject3D", true, false).is_empty()
		and pickup.find_children("*", "CollisionShape3D", true, false).is_empty(), "pickup has no collider")
	_check(pickup.global_position == at and pickup.rotation.is_equal_approx(Vector3(0.6, 0.75, 0.3)), "base placement and spin")
	var record: Dictionary = boss._pickups[0]
	_check(record.value == 7 and record.at == at and record.age == 0.0 and record.source == "spill", "unchanged scrap value and collection record")
	var field := ScrapField.new()
	field.setup()
	var mat := pickup.material_override as StandardMaterial3D
	_check(mat != null and mat.albedo_color.is_equal_approx(field._material.albedo_color)
		and mat.albedo_color.is_equal_approx(Palette.ARC) and mat.emission_enabled, "matches normal enemy scrap field mint")
	field.free()
	boss._spawn_pickup(at + Vector3.RIGHT, 9, "returned")
	var other: MeshInstance3D = boss._pickups[1].node
	_check(other.mesh == pickup.mesh, "pickup mesh cached across drops")
	var initial_yaw := pickup.rotation.y
	boss._step_trail(Vector3(200, 200, 200))
	_check(is_equal_approx(pickup.rotation.y - initial_yaw, boss._delta * 2.5), "base pickup spin rate")
	var source := FileAccess.get_file_as_string("res://src/boss/boss.gd")
	var start := source.find("func _spawn_pickup")
	var mesh_start := source.find("\tvar node := MeshInstance3D.new()", start)
	var mesh_end := source.find("\tnode.material_override =", mesh_start)
	var logic := source.substr(0, mesh_start) + source.substr(mesh_end)
	_check(logic.sha256_text() == BASE_LOGIC_SHA, "entire boss source outside mesh construction unchanged")
	_finish()
