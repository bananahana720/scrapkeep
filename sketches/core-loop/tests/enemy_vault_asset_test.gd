extends SceneTree

const Game := preload("res://src/game.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")
const GLB := "res://assets/models/world_one/enemy_vault.glb"
const BASE_LOGIC_SHA := "4174043cf7c1a73c91c45f58eaf3a47fd512bcbad3a09692ba7031a69b794c35"

var failures := 0
var game


func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
	print("%s -> %s" % [label, "PASS" if ok else "FAIL"])


func _finish() -> void:
	print("enemy_vault_asset_test: %s" % ("PASS" if failures == 0 else "FAIL"))
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
	_check(m.tris > 0 and m.tris <= 4000 and m.vertices <= 2500 and m.draws > 0 and m.draws <= 4, label + " D3 budget")
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
	_budget(scene, "asset")
	_named(scene, ["VaultBody", "VaultLamp", "VaultPlating"])
	scene.free()
	game = Game.new()
	game.test_mode = true
	root.add_child(game)
	game.ctx.calm = true
	var cache = game.ctx.spawner.spawn_enemy("vault", Vector3(0, 30, 0))
	cache.set_physics_process(false)
	var m := _budget(cache, "live")
	_check(m.draws <= 4, "four hatches share one D3 draw")
	_check(m.primitive == 0, "primitive cache no longer builds")
	var ring_mesh := cache.find_child("VaultHatches", true, false) as MeshInstance3D
	var ring_verts: PackedVector3Array = ring_mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] if ring_mesh != null else PackedVector3Array()
	_check(ring_mesh != null and ring_mesh.mesh.get_surface_count() == 1, "hatch rings are one surface")
	for side in 4:
		var ring := cache.find_child("VaultHatch%d" % side, true, false) as Node3D
		if ring == null:
			_check(false, "hatch %d exists" % side)
			continue
		var low := Vector3(INF, INF, INF)
		var high := -low
		for v in ring_verts:
			if v.distance_to(ring.position) <= 0.7:
				low = low.min(v)
				high = high.max(v)
		var ext := high - low
		var axis_i := 2 if side < 2 else 0
		var smallest := ext[axis_i] > 0.0
		for i in 3:
			if i != axis_i and ext[i] <= ext[axis_i] + 0.001:
				smallest = false
		_check(smallest, "hatch %d ring faces outward, wall-normal extent smallest (extent %s)" % [side, ext])
	var hatches := 0
	for side in 4:
		var hatch: Node = cache.find_child("VaultHatch%d" % side, true, false)
		hatches += 1 if hatch is Node3D else 0
	_check(hatches == 4, "four hatch rings wrap the cache")
	_check(cache.find_children("*", "Light3D", true, false).is_empty(), "vault has no per-instance light")
	var source := FileAccess.get_file_as_string("res://src/combat/vault.gd")
	var logic_start := source.find("func setup(")
	var logic_end := source.find("func _build_visual(", logic_start)
	_check(logic_start >= 0 and logic_end > logic_start
		and source.substr(logic_start, logic_end - logic_start).sha256_text() == BASE_LOGIC_SHA,
		"vault gameplay logic remains pinned")
	_check(cache.plating == game.ctx.spawner.warden_spec(game.ctx.flow.stage() + 1).plating,
		"vault uses next stage Warden plating")
	var plate := cache.find_child("VaultPlating", true, false) as MeshInstance3D
	var body := cache.find_child("VaultBody", true, false) as MeshInstance3D
	var lamp := cache.find_child("VaultLamp", true, false) as MeshInstance3D
	_check(body != null and plate != null and lamp != null, "GLB assembly retained")
	if plate != null:
		var mat := plate.material_override as StandardMaterial3D
		_check(mat != null and cache._tint_materials.size() == 1 and cache._tint_materials[0] == mat, "plating material registered per cache")
		if mat != null:
			cache.set_tint("")
			cache.set_tint("amber")
			_check(mat.emission_enabled and is_equal_approx(mat.emission_energy_multiplier, cache.PLATE_GLOW_LIVE), "live plating rim lights")
			cache.set_tint("slate")
			_check(mat.emission_enabled and is_equal_approx(mat.emission_energy_multiplier, cache.PLATE_GLOW_SLATE), "glancing plating rim lights")
			cache.set_tint("")
			_check(not mat.emission_enabled, "plating finish rests without glow")
			_check(mat.emission_texture != null and mat.emission_operator == BaseMaterial3D.EMISSION_OP_MULTIPLY, "existing rim emission mask")
		var uv = plate.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
		_check(uv != null and uv.size() > 0, "plating has face UVs for rim mask")
		if uv != null:
			var corners := {}
			var valid_uv := true
			for v in uv:
				corners[Vector2i(roundi(v.x * 3.0), roundi(v.y * 2.0))] = true
				valid_uv = valid_uv and v.x >= 0.0 and v.x <= 1.0 / 3.0 + 0.0001 and v.y >= 0.4999 and v.y <= 1.0001
			_check(valid_uv, "plating face stays within one rim atlas cell")
			_check(corners.size() == 4, "one rim cell covers each complete plate face")
	if body != null and lamp != null:
		_check(body.get_surface_override_material(0) == cache._material and cache._material.vertex_color_use_as_albedo, "body vertex paint and flash registered")
		var lm := lamp.get_active_material(0) as StandardMaterial3D
		_check(lm != null and lm.emission_enabled and lm.albedo_color == cache.Palette.AMBER
			and lm.emission == cache.Palette.AMBER and lm.emission_energy_multiplier > 0.0,
			"locked lamp reads as lit amber")
		var other = game.ctx.spawner.spawn_enemy("vault", Vector3(10, 30, 0))
		other.set_physics_process(false)
		var ob := other.find_child("VaultBody", true, false) as MeshInstance3D
		var op := other.find_child("VaultPlating", true, false) as MeshInstance3D
		_check(ob != null and op != null and ob.mesh == body.mesh and op.mesh == plate.mesh
			and other._material != cache._material and other._tint_materials[0] != cache._tint_materials[0], "cached meshes, private flash and plating state")
		other.free()
	var shapes: Array = cache.find_children("*", "CollisionShape3D", true, false)
	var box := shapes[0].shape as BoxShape3D if shapes.size() == 1 else null
	_check(box != null and box.size.is_equal_approx(Vector3(3.2, 2.6, 3.2))
		and shapes[0].transform.is_equal_approx(Transform3D.IDENTITY), "unchanged box collider")
	_check(cache.find_children("*", "CollisionObject3D", true, false).is_empty(), "no model physics bodies")
	_check(cache.hp == 400.0 and cache.scrap_value == 10 and cache.weight == 1000.0 and cache.radius == 1.7
		and cache.half_height == 1.3 and cache.collision_layer == 4 and cache.collision_mask == 1, "base gameplay values")
	var at: Vector3 = cache.global_position
	cache.knock(Vector3.ONE, 100.0)
	cache._physics_process(1.0)
	_check(cache.global_position == at and cache.velocity == Vector3.ZERO, "cache remains static")
	cache._die()
	_check(cache._opened and cache._lamp_material.emission_energy_multiplier == 0.0,
		"opening extinguishes the amber lamp")
	_check(cache._hatch_model != null and cache._hatch_model.position.y < 0.0
		and cache._hatch_model.mesh.get_surface_count() == 1
		and (cache._hatch_model.material_override as StandardMaterial3D).albedo_color == cache.Palette.CHARCOAL,
		"one shared charcoal hatch draw drops on open")
	_finish()
