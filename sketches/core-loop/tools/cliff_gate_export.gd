extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Scenery := preload("res://src/presentation/spillway_scenery.gd")
const Spillway := preload("res://src/world/map_spillway.gd")

var out := ""


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	if out.is_empty():
		printerr("needs --out")
		quit(2)
		return
	_run.call_deferred()


func _emit(buf: PackedFloat32Array, mesh: Mesh, xf: Transform3D) -> int:
	var count := 0
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx = arrays[Mesh.ARRAY_INDEX]
		var n: int = idx.size() if idx != null and idx.size() > 0 else v.size()
		for i in n:
			var p: Vector3 = xf * (v[idx[i]] if idx != null and idx.size() > 0 else v[i])
			buf.append(p.x)
			buf.append(p.y)
			buf.append(p.z)
		count += n / 3
	return count


func _write(path: String, buf: PackedFloat32Array) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(buf.to_byte_array())
	f.close()


func _run() -> void:
	seed(280928)
	var game = Game.new()
	game.name = "Game"
	game.test_mode = true
	root.add_child(game)
	await process_frame
	game.ctx.calm = true
	game.flow.force_warden = true
	game.flow.press_start()
	game.flow.choose_class(0)
	for i in 120:
		await physics_frame
	var terrain = game.ctx.terrain
	var ball: Vector3 = terrain.drop_point(-53.85, -39.07, 3.0)
	game.player.reset_to(ball)
	game.player._visual_root.global_position = ball
	game.world.bay.visible = false
	for i in 3:
		await process_frame
	DirAccess.make_dir_recursive_absolute(out)
	var scene := PackedFloat32Array()
	var groups := []
	for found in root.find_children("*", "VisualInstance3D", true, false):
		var n := found as VisualInstance3D
		if not n.is_visible_in_tree() or n.layers == 0 or n.name == "SandstoneShoulders" or not (n is MeshInstance3D or n is MultiMeshInstance3D):
			continue
		var count := 0
		if n is MeshInstance3D and n.mesh != null:
			count = _emit(scene, n.mesh, n.global_transform)
		elif n is MultiMeshInstance3D and n.multimesh != null and n.multimesh.mesh != null:
			for i in n.multimesh.instance_count:
				count += _emit(scene, n.multimesh.mesh, n.global_transform * n.multimesh.get_instance_transform(i))
		groups.append({"path": str(n.get_path()), "tris": count})
	var rocks: Array[Transform3D] = []
	for side in [-1.0, 1.0]:
		for i in 8:
			var z := -176.0 + i * 56.0
			for j in 3:
				Scenery._place(rocks, Vector3(side * (206 + j * 2), 31, z + j * 2), Vector3(0.5, 0.3, 0.7), j)
	var rock := Scenery._eroded_rock()
	var rock_count := 0
	for placement in rocks:
		rock_count += _emit(scene, Scenery._placed_rock(rock, placement), Transform3D.IDENTITY)
	groups.append({"path": "rocks", "tris": rock_count})
	_write(out.path_join("scene.f32"), scene)
	var units := PackedFloat32Array()
	var unit_rows := []
	var map := Spillway.new()
	var rim := Scenery.rim_plan(map)
	for c in rim:
		var m := Scenery.crown_mesh(c)
		unit_rows.append({"kind": "crown", "tris": _emit(units, m, Scenery.crown_transform(c))})
	var plan := Scenery.shoulder_plan()
	var env := []
	for h in plan:
		var m := Scenery.shoulder_mesh(h)
		unit_rows.append({"kind": "hull", "tris": _emit(units, m, Transform3D.IDENTITY)})
		var box := Scenery.shoulder_envelope(h)
		env.append([box.position.x, box.position.y, box.position.z, box.size.x, box.size.y, box.size.z])
	_write(out.path_join("units.f32"), units)
	var rim_rows := []
	for c in rim:
		var samples := []
		for xi in Scenery.footprint_steps(c["depth"]):
			for zi in Scenery.footprint_steps(c["width"]):
				var wx: float = c["x"] + (xi if c["yaw"] == 0.0 else -xi)
				var wz: float = c["z"] + (zi if c["yaw"] == 0.0 else -zi)
				samples.append([xi, zi, map.sample(wx, wz)[0]])
		rim_rows.append({"side": c["side"], "variant": c["variant"], "family": c["family"], "width": c["width"], "depth": c["depth"],
			"add": c["add"], "x": c["x"], "z": c["z"], "yaw": c["yaw"], "crest": c["crest"], "root": c["root"], "terrain": samples})
	var hull_rows := []
	for h in plan:
		var roots := []
		for r in h["roots"]:
			roots.append([r.x, r.y, r.z])
		hull_rows.append({"side": h["side"], "i": h["i"], "x": h["x"], "z": h["z"], "h": h["h"], "roots": roots})
	var hashes := {}
	for path in ["src/presentation/spillway_scenery.gd", "tools/capture_cameras.gd", "tools/asset_capture.gd", "src/world/terrain.gd", "tools/cliff_gate_export.gd"]:
		hashes[path] = FileAccess.get_sha256("res://" + path)
	var doc := {"groups": groups, "units": unit_rows, "rim": rim_rows, "hulls": hull_rows, "envelopes": env, "hashes": hashes}
	var file := FileAccess.open(out.path_join("meta.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(doc))
	file.close()
	print("exported ", scene.size() / 9, " scene triangles, ", units.size() / 9, " unit triangles")
	quit()
