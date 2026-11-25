extends SceneTree

# It needs a real renderer: dressing multimeshes are filled with RenderingServer.multimesh_set_buffer, and the headless

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")

const MAX_TRIS := 60000
const MAX_INSTANCE_TRIS := 4000
const GROUND_STEP := 1.0
const GROUND_HALF := 800.0

var area := ""
var out_root := ""
var run_seed := 1
var game
var items: Array = []
var tris := PackedFloat32Array()
var ball_mask := 0
var shots_file := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--area="):
			area = a.trim_prefix("--area=")
		elif a.begins_with("--out="):
			out_root = a.trim_prefix("--out=")
		elif a.begins_with("--seed="):
			run_seed = int(a.trim_prefix("--seed="))
		elif a.begins_with("--shots="):
			shots_file = a.trim_prefix("--shots=")
	if not area in ["dam", "flume", "brindle", "camp"] or out_root == "":
		printerr("clip_dump: pass --area=dam|flume|brindle|camp --out=<absolute dir> [--seed=N] [--shots=<json>]")
		quit(2)
		return
	if DisplayServer.get_name() == "headless":
		printerr("clip_dump: needs a display (xvfb-run, opengl3): headless multimesh buffers read back empty")
		quit(2)
		return
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	seed(run_seed)
	game = Game.new()
	game.test_mode = true
	game._session_seed = run_seed
	if area != "camp":
		game.table = "park"
	game.ground_behind_menu = false
	root.add_child(game)
	while game.flow == null:
		await process_frame
	await _frames(5)
	game.ctx.calm = true
	game.player.source = Intent.Scripted.new()
	var stage := 0
	if area == "camp":
		game._screen_key(KEY_K)
		await _frames(30)
	else:
		game.flow.press_start()
		game.flow.choose_class(0)
		stage = 1 if area == "dam" else 2
		if stage != 1:
			game.flow.enter_stage(stage, Vector3.ZERO, false)
		var terrain = game.ctx.terrain
		var waited := 0
		while waited < 3000 and not (terrain.rows_ready(stage) and terrain.is_ready(stage) and game.presentation.set_dressing != null and game.presentation.set_dressing.get_child_count() > 0 and game.flow.state_name() == "stage"):
			await process_frame
			waited += 1
		if game.presentation.park_props != null:
			game.presentation.park_props.finish()
		await _frames(60)
		if area == "brindle":
			game.flow._finish_stage()
			await _frames(90)
	print("clip_dump: %s seed %d ready, flow %s" % [area, run_seed, game.flow.state_name()])
	game.player.body().freeze = true
	ball_mask = game.player.body().collision_mask
	if shots_file != "":
		await _shots()
		return
	var skip := {}
	skip[game.player.body().get_instance_id()] = true
	_walk(game, skip)
	var dir := out_root.path_join("%s-s%d" % [area, run_seed])
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(dir.path_join("tris.f32"), FileAccess.WRITE)
	f.store_buffer(tris.to_byte_array())
	f.close()
	var meta := {"area": area, "seed": run_seed, "stage": stage, "ball_mask": ball_mask, "ball": _v(game.player.ball_position()), "items": items}
	if stage > 0:
		meta["ground"] = _dump_ground(dir, stage)
	var j := FileAccess.open(dir.path_join("items.json"), FileAccess.WRITE)
	j.store_string(JSON.stringify(meta))
	j.close()
	print("clip_dump: %d items, %d triangles -> %s" % [items.size(), tris.size() / 9, dir])
	game.free()
	quit(0)


func _v(p: Vector3) -> Array:
	return [snappedf(p.x, 0.001), snappedf(p.y, 0.001), snappedf(p.z, 0.001)]


func _aabb(b: AABB) -> Array:
	return _v(b.position) + _v(b.end)


func _hints(n: Node) -> Dictionary:
	var h := {}
	var at: Node = n
	var depth := 0
	while at != null and at != game and depth < 12:
		if at.has_meta("dress_kind") and not h.has("dress_kind"):
			h["dress_kind"] = String(at.get_meta("dress_kind"))
		if at.scene_file_path != "" and not h.has("scene"):
			h["scene"] = at.scene_file_path
			h["scene_node"] = str(at.get_path())
		var nm := String(at.name)
		if (nm.begins_with("Park_") or nm.begins_with("Landmark_")) and not h.has("row"):
			h["row"] = nm
			h["row_node"] = str(at.get_path())
		at = at.get_parent()
		depth += 1
	return h


func _moving(n: Node) -> bool:
	var at: Node = n
	while at != null and at != game:
		if at is RigidBody3D or at is CharacterBody3D or at is VehicleBody3D:
			return true
		if at.is_in_group("enemies") or at.is_in_group("enemy"):
			return true
		at = at.get_parent()
	return false


func _material_hint(gi: GeometryInstance3D, mesh: Mesh) -> String:
	var m: Material = gi.material_override
	if m == null and mesh != null and mesh.get_surface_count() > 0:
		m = mesh.surface_get_material(0)
		if gi is MeshInstance3D and (gi as MeshInstance3D).get_surface_override_material(0) != null:
			m = (gi as MeshInstance3D).get_surface_override_material(0)
	if m is ShaderMaterial and m.shader != null:
		return "shader:" + m.shader.resource_path.get_file()
	if m is BaseMaterial3D:
		return "alpha" if m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED else "opaque"
	return ""


func _add_faces(faces: PackedVector3Array, xf: Transform3D) -> int:
	var start := tris.size()
	tris.resize(start + faces.size() * 3)
	var k := start
	for p in faces:
		var w := xf * p
		tris[k] = w.x
		tris[k + 1] = w.y
		tris[k + 2] = w.z
		k += 3
	return faces.size() / 3


func _walk(n: Node, skip: Dictionary) -> void:
	if skip.has(n.get_instance_id()) or n is CanvasItem or n is CanvasLayer:
		return
	if n is CharacterBody3D or n is RigidBody3D:
		return
	var drawn := not n is Node3D or (n as Node3D).is_visible_in_tree()
	if n is VisualInstance3D and (n as VisualInstance3D).layers == 0:
		drawn = false
	if n is MeshInstance3D and drawn:
		_mesh_item(n)
	elif n is MultiMeshInstance3D and drawn:
		_multimesh_items(n)
	if n is CollisionObject3D:
		_body_items(n)
	for c in n.get_children():
		_walk(c, skip)


func _mesh_item(mi: MeshInstance3D) -> void:
	if mi.mesh == null or mi.visibility_range_begin > 0.0 or _moving(mi):
		return
	var faces := mi.mesh.get_faces()
	var row := {"t": "mesh", "path": str(mi.get_path()), "mesh": mi.mesh.resource_path, "mat": _material_hint(mi, mi.mesh),
		"aabb": _aabb(mi.global_transform * mi.mesh.get_aabb()), "o": _v(mi.global_position), "vis_end": mi.visibility_range_end, "shadow_only": mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY}
	row.merge(_hints(mi))
	row["t0"] = tris.size() / 9
	row["n"] = 0 if faces.size() / 3 > MAX_TRIS else _add_faces(faces, mi.global_transform)
	items.append(row)


func _multimesh_items(mmi: MultiMeshInstance3D) -> void:
	var mm := mmi.multimesh
	if mm == null or mm.mesh == null or mmi.visibility_range_begin > 0.0 or _moving(mmi):
		return
	var count := mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count
	var faces := mm.mesh.get_faces()
	var keep_tris := faces.size() / 3 <= MAX_INSTANCE_TRIS
	var hints := _hints(mmi)
	var mat := _material_hint(mmi, mm.mesh)
	var local_aabb := mm.mesh.get_aabb()
	var buf := RenderingServer.multimesh_get_buffer(mm.get_rid())
	var stride := 12 + (4 if mm.use_colors else 0) + (4 if mm.use_custom_data else 0)
	var from_server := buf.size() >= count * stride
	for i in count:
		var b := i * stride
		var local := mm.get_instance_transform(i)
		if from_server:
			local = Transform3D(Basis(Vector3(buf[b], buf[b + 4], buf[b + 8]), Vector3(buf[b + 1], buf[b + 5], buf[b + 9]), Vector3(buf[b + 2], buf[b + 6], buf[b + 10])), Vector3(buf[b + 3], buf[b + 7], buf[b + 11]))
		var xf: Transform3D = mmi.global_transform * local
		if xf.basis.determinant() == 0.0:
			continue
		var row := {"t": "mm", "path": str(mmi.get_path()), "i": i, "mesh": mm.mesh.resource_path, "mat": mat, "aabb": _aabb(xf * local_aabb), "o": _v(xf.origin),
			"vis_end": mmi.visibility_range_end, "shadow_only": mmi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY}
		row.merge(hints)
		row["t0"] = tris.size() / 9
		row["n"] = _add_faces(faces, xf) if keep_tris else 0
		items.append(row)


func _body_items(body: CollisionObject3D) -> void:
	if body is Area3D or _moving(body) or body.collision_layer & ball_mask == 0:
		return
	for owner_id in body.get_shape_owners():
		if body.is_shape_owner_disabled(owner_id):
			continue
		var xf := body.global_transform * body.shape_owner_get_transform(owner_id)
		var holder = body.shape_owner_get_owner(owner_id)
		var hidden := holder is Node3D and not (holder as Node3D).is_visible_in_tree()
		for k in body.shape_owner_get_shape_count(owner_id):
			_shape_item(body, body.shape_owner_get_shape(owner_id, k), xf, owner_id, hidden)


func _shape_item(body: CollisionObject3D, shape: Shape3D, xf: Transform3D, owner_id: int, hidden: bool) -> void:
	var row := {"t": "col", "path": "%s#%d" % [str(body.get_path()), owner_id], "shape": shape.get_class(), "layer": body.collision_layer,
		"hidden": hidden}
	row.merge(_hints(body))
	if shape is HeightMapShape3D or shape is WorldBoundaryShape3D:
		row["terrain"] = true
		row["t0"] = tris.size() / 9
		row["n"] = 0
		row["aabb"] = []
		items.append(row)
		return
	var faces: PackedVector3Array
	if shape is ConcavePolygonShape3D:
		faces = (shape as ConcavePolygonShape3D).get_faces()
	else:
		faces = shape.get_debug_mesh().get_faces()
	var b := AABB()
	if faces.size() > 0:
		b = AABB(xf * faces[0], Vector3.ZERO)
		for p in faces:
			b = b.expand(xf * p)
	row["aabb"] = _aabb(b)
	row["t0"] = tris.size() / 9
	row["n"] = 0 if faces.size() / 3 > MAX_TRIS else _add_faces(faces, xf)
	if row["n"] == 0 and faces.size() > 0:
		row["big"] = faces.size() / 3
	items.append(row)


func _shots() -> void:
	var list = JSON.parse_string(FileAccess.get_file_as_string(shots_file))
	var dir := out_root.path_join("shots-%s-s%d" % [area, run_seed])
	DirAccess.make_dir_recursive_absolute(dir)
	game.presentation.hide_ui()
	var cam := Camera3D.new()
	cam.fov = 60.0
	cam.far = 900.0
	game.add_child(cam)
	cam.make_current()
	for terrain in game.find_children("*", "Terrain3D", true, false):
		terrain.set_camera(cam)
	game.player.body().global_position = Vector3(0, -500, 0)
	for shot in list:
		var at := Vector3(shot["at"][0], shot["at"][1], shot["at"][2])
		var dist := maxf(4.0, 2.2 * float(shot.get("r", 2.0)))
		for side in ["a", "b"]:
			var yaw := deg_to_rad(-135.0 if side == "a" else 45.0)
			var pitch := deg_to_rad(35.0)
			var eye := at + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * dist
			cam.global_position = eye
			cam.look_at(at, Vector3.UP)
			await _frames(4)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(dir.path_join("%s-%s.png" % [shot["id"], side]))
	print("clip_dump: %d shots -> %s" % [list.size(), dir])
	game.free()
	quit(0)


func _dump_ground(dir: String, stage: int) -> Dictionary:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for row in items:
		var a: Array = row.get("aabb", [])
		if a.size() == 6 and absf(a[0]) < GROUND_HALF * 2.0:
			lo = Vector2(minf(lo.x, a[0]), minf(lo.y, a[2]))
			hi = Vector2(maxf(hi.x, a[3]), maxf(hi.y, a[5]))
	lo = (lo - Vector2.ONE * 4.0).clamp(Vector2.ONE * -GROUND_HALF, Vector2.ONE * GROUND_HALF).floor()
	hi = (hi + Vector2.ONE * 4.0).clamp(Vector2.ONE * -GROUND_HALF, Vector2.ONE * GROUND_HALF).ceil()
	var nx := int((hi.x - lo.x) / GROUND_STEP) + 1
	var nz := int((hi.y - lo.y) / GROUND_STEP) + 1
	var g := PackedFloat32Array()
	g.resize(nx * nz)
	var terrain = game.ctx.terrain
	for k in nz:
		for i in nx:
			g[k * nx + i] = terrain.floor_height(lo.x + i * GROUND_STEP, lo.y + k * GROUND_STEP)
	var f := FileAccess.open(dir.path_join("ground.f32"), FileAccess.WRITE)
	f.store_buffer(g.to_byte_array())
	f.close()
	return {"x0": lo.x, "z0": lo.y, "step": GROUND_STEP, "nx": nx, "nz": nz, "stage": stage}
