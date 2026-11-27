extends SceneTree

const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ModuleHarness := preload("res://tests/doubles/module_harness.gd")
const ParkRecipes := preload("res://src/world/park/park_recipes.gd")

const NEAR_M := 40.0
const OLD_LOD_TINT := Color(0.72, 0.68, 0.62, 1.0)
const TINT_STEP := 2.0 / 255.0

var t := T.new("world_lod_and_boss_regression_test")


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for _i in n:
		await physics_frame


func _row(path: String, id: String) -> Dictionary:
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	for row: Dictionary in data["park_rows"]:
		if String(row.get("id", "")) == id:
			return row
	return {}


func _check_post_batches(path: String, id: String) -> Mesh:
	var row := _row(path, id)
	if not t.check("%s row is in %s" % [id, path.get_file()], not row.is_empty()):
		return null
	var holder := Node3D.new()
	root.add_child(holder)
	var flat := func(_x: float, _z: float) -> float: return 0.0
	var node: Node3D = ParkRecipes.place_row(row, holder, flat)
	var near: Array = []
	var lods: Array = []
	for child in node.get_children():
		if child is MultiMeshInstance3D and String(child.name).begins_with("PostsLod"):
			lods.append(child)
		elif child is MultiMeshInstance3D and String(child.name).begins_with("Posts"):
			near.append(child)
	var draws := ParkRecipes.anchor_draws(row, ParkRecipes.anchor_posts(row), flat, node.transform, true)
	var cells := ParkRecipes.anchor_post_cells(draws)
	var post_box: AABB = (near[0] as MultiMeshInstance3D).multimesh.mesh.get_aabb() if not near.is_empty() else AABB()
	var drawn := 0
	var worst := 0.0
	var tight := ""
	for cell: Vector2i in cells:
		var cell_xfs: Array = cells[cell]
		var view_name := "Posts" if cell == cells.keys()[0] else "Posts_%d_%d" % [cell.x, cell.y]
		var view := node.get_node_or_null(view_name) as MultiMeshInstance3D
		if view == null or view.multimesh.instance_count != cell_xfs.size():
			tight = "cell %s has no matching batch" % cell
			continue
		drawn += cell_xfs.size()
		var box := AABB()
		for k in cell_xfs.size():
			var piece: AABB = cell_xfs[k] * post_box
			box = piece if k == 0 else box.merge(piece)
		var centre := box.get_center()
		for xf: Transform3D in cell_xfs:
			var at: Vector3 = xf * post_box.get_center()
			var reach := Vector2(at.x - centre.x, at.z - centre.z).length() + NEAR_M
			worst = maxf(worst, reach)
			if reach > view.visibility_range_end - view.visibility_range_end_margin:
				tight = "%s needs %.1f m, end %.1f" % [view.name, reach, view.visibility_range_end]
	t.check("%s splits into more than one post batch" % id, near.size() > 1 and lods.size() == near.size(), "near %d lod %d" % [near.size(), lods.size()])
	t.eq("%s batches draw every post once" % id, drawn, int(node.get_meta("anchor_posts", -1)))
	t.check("%s every post within %.0f m of the camera stays inside its batch's near range" % [id, NEAR_M], tight == "" and worst > NEAR_M, tight if tight != "" else "worst %.1f m" % worst)
	var lod_never_vanishes := not lods.is_empty()
	for view: MultiMeshInstance3D in lods:
		lod_never_vanishes = lod_never_vanishes and view.visibility_range_end == 0.0 and view.visibility_range_begin > 0.0
	t.check("%s far posts never vanish while their colliders stay" % id, lod_never_vanishes)
	var source: Mesh = (near[0] as MultiMeshInstance3D).multimesh.mesh if not near.is_empty() else null
	var lod: Mesh = (lods[0] as MultiMeshInstance3D).multimesh.mesh if not lods.is_empty() else null
	if source != null and lod != null:
		_check_lod_mesh(id, source, lod)
	holder.free()
	return source


func _key(v: Vector3) -> String:
	return "%d,%d,%d" % [roundi(v.x * 1000.0), roundi(v.y * 1000.0), roundi(v.z * 1000.0)]


func _source_tint(source: Mesh) -> Color:
	var colors = source.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	if colors is PackedColorArray and not colors.is_empty():
		var sum := Color(0.0, 0.0, 0.0, 0.0)
		for c: Color in colors:
			sum += c
		return sum / float(colors.size())
	var material := source.surface_get_material(0) as BaseMaterial3D
	return material.albedo_color if material != null else ParkRecipes.GREYBOX_TINT


func _check_lod_mesh(id: String, source: Mesh, lod: Mesh) -> void:
	var arrays := lod.surface_get_arrays(0)
	var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var ns: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs = arrays[Mesh.ARRAY_TEX_UV]
	var cols = arrays[Mesh.ARRAY_COLOR]
	var ix = arrays[Mesh.ARRAY_INDEX]
	var count: int = ix.size() if ix != null and not (ix as PackedInt32Array).is_empty() else vs.size()
	var back := 0
	var edges := {}
	for k in range(0, count, 3):
		var i := [k, k + 1, k + 2]
		if ix != null and not (ix as PackedInt32Array).is_empty():
			i = [ix[k], ix[k + 1], ix[k + 2]]
		var a: Vector3 = vs[i[0]]
		var b: Vector3 = vs[i[1]]
		var c: Vector3 = vs[i[2]]
		if (b - a).cross(c - a).dot(ns[i[0]] + ns[i[1]] + ns[i[2]]) >= 0.0:
			back += 1
		var keys := [_key(a), _key(b), _key(c)]
		for e in 3:
			var u: String = keys[e]
			var v: String = keys[(e + 1) % 3]
			var edge := u + "|" + v if u < v else v + "|" + u
			edges[edge] = int(edges.get(edge, 0)) + 1
	var open := edges.values().filter(func(n: int) -> bool: return n != 2).size()
	t.eq("%s LOD post has no back-facing triangle" % id, back, 0)
	t.check("%s LOD post is a closed shell" % id, count >= 36 and open == 0, "tris %d, edges not shared by two %d" % [count / 3, open])
	var uv_ok := uvs is PackedVector2Array and (uvs as PackedVector2Array).size() == vs.size() \
		and Array(uvs).any(func(p: Vector2) -> bool: return p != Vector2.ZERO)
	t.check("%s LOD post carries UVs" % id, uv_ok)
	var want := _source_tint(source)
	var tint_ok := cols is PackedColorArray and (cols as PackedColorArray).size() == vs.size()
	if tint_ok:
		for col: Color in cols:
			tint_ok = tint_ok and absf(col.r - want.r) < TINT_STEP and absf(col.g - want.g) < TINT_STEP and absf(col.b - want.b) < TINT_STEP
	t.check("%s LOD post takes the source post's colour" % id, tint_ok and not want.is_equal_approx(OLD_LOD_TINT),
		"want %s got %s" % [want, (cols as PackedColorArray)[0] if cols is PackedColorArray and not (cols as PackedColorArray).is_empty() else null])
	t.check("%s LOD post keeps the source surface material" % id,
		source.surface_get_material(0) == null or lod.surface_get_material(0) == source.surface_get_material(0))


func _check_conduit(game, stage: int) -> void:
	game.flow.enter_stage(stage, Vector3.ZERO, false)
	await _frames(8)
	var stage_root: Node3D = game.ctx.terrain.geometry_root(stage)
	var conduits := stage_root.find_children("CommandConduitMesh", "MeshInstance3D", true, false) if stage_root != null else []
	var all_open := not conduits.is_empty()
	for conduit: MeshInstance3D in conduits:
		all_open = all_open and conduit.visibility_range_end == 0.0
	t.check("stage %d green wire never culls with distance" % stage, all_open, "%d conduits" % conduits.size())


func _omni_count() -> int:
	return root.find_children("*", "OmniLight3D", true, false).size()


func _check_waking(game) -> void:
	ModuleHarness.enter_world(game, 2)
	await _frames(6)
	var mod = ModuleHarness.module(game, 2)
	var dress = mod._arena_dress
	if not t.check("the Waking dress builds", dress != null):
		return
	var probe: Vector3 = mod.pad.global_position + Vector3.UP * 6.0
	var lamps: Array = dress.find_children("LampPool*", "OmniLight3D", true, false)
	var lit := lamps.filter(func(l: OmniLight3D) -> bool: return l.global_position.distance_to(probe) < l.distance_fade_begin)
	t.check("the Waking centre keeps at least 10 wall lamps unfaded", lamps.size() == 32 and lit.size() >= 10, "%d of %d" % [lit.size(), lamps.size()])
	var rims: Array = mod.pad.find_children("RimPool*", "OmniLight3D", true, false)
	var rim_lit := rims.filter(func(l: OmniLight3D) -> bool: return l.global_position.distance_to(probe) < l.distance_fade_begin)
	t.check("the Waking centre keeps its pad rim pools unfaded", not rims.is_empty() and rim_lit.size() == rims.size(), "%d of %d" % [rim_lit.size(), rims.size()])
	game.flow.retry_stage()
	await _frames(4)
	var before := _omni_count()
	for _i in 10:
		game.flow.retry_stage()
		await _frames(3)
	t.eq("ten Waking retries add no omni light", _omni_count(), before)
	mod.exit_arena()
	await _frames(4)


func _check_mind_replay(game) -> void:
	var stage: int = game.ctx.stages.last_of(3)
	ModuleHarness.enter_world(game, 3)
	await _frames(6)
	var stage_root: Node3D = game.ctx.terrain.geometry_root(stage)
	t.check("the Mind arena hides its stage", stage_root != null and not stage_root.is_visible_in_tree())
	game.ctx.run.damage(1.0e9, "test")
	await _frames(4)
	var replayed: bool = game.flow.replay_stage(stage)
	await _frames(6)
	stage_root = game.ctx.terrain.geometry_root(stage)
	t.check("dead then replay shows the Mind's stage again", replayed and stage_root != null and stage_root.visible,
		"replayed %s visible %s" % [replayed, stage_root.visible if stage_root != null else null])


func _run() -> void:
	_check_post_batches("res://src/world/park/park_dam.json", "hoodoo_13")
	_check_post_batches("res://src/world/park/park_sinkhole.json", "spatter_field")
	var game := Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	game.ctx.calm = true
	game.player.source = Intent.Scripted.new()
	ModuleHarness.boot(game)
	await _frames(6)
	await _check_conduit(game, 3)
	await _check_conduit(game, 4)
	await _check_waking(game)
	await _check_mind_replay(game)
	game.queue_free()
	await _frames(2)
	quit(t.verdict())
