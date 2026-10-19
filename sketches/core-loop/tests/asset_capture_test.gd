extends SceneTree

# tools/asset_capture.gd: black modes, frozen state, camera table and the pair refusal, on a small scene.
const Cap := preload("res://tools/asset_capture.gd")
const Cams := preload("res://tools/capture_cameras.gd")
const MaterialSlots := preload("res://src/presentation/material_slots.gd")
const TMP := "user://asset_capture_test"
const T := preload("res://tests/support/t.gd")

var _t := T.new("asset_capture_test")


class Spinner extends Node3D:
	func _process(delta: float) -> void:
		rotate_y(delta * 3.0)


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	_t.check(label, ok)


func _mesh(name: String, at: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.name = name
	m.mesh = BoxMesh.new()
	m.position = at
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(Image.create_empty(4, 4, false, Image.FORMAT_RGB8))
	mat.emission_enabled = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.material_override = mat
	return m


func _uses_black(m: GeometryInstance3D) -> bool:
	var mat := m.material_override as StandardMaterial3D
	return mat != null and mat.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED \
		and mat.albedo_color == Color.BLACK and mat.albedo_texture == null \
		and mat.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and not mat.emission_enabled \
		and not mat.vertex_color_use_as_albedo


func _run() -> void:
	var scene := Node3D.new()
	scene.name = "Scene"
	root.add_child(scene)
	var subject := Node3D.new()
	subject.name = "Subject"
	scene.add_child(subject)
	var part_a := _mesh("PartA", Vector3(0, 1, 0))
	var part_b := _mesh("PartB", Vector3(2, 1, 0))
	var glass := _mesh("Glass", Vector3(0, 2, 0))
	var unseen := _mesh("Unseen", Vector3(4, 1, 0))
	unseen.layers = 0
	for n in [part_a, part_b, glass, unseen]:
		subject.add_child(n)
	var ground := _mesh("Ground", Vector3(0, -1, 0))
	scene.add_child(ground)
	var sign := Label3D.new()
	sign.text = "label"
	subject.add_child(sign)
	var lamp := DirectionalLight3D.new()
	scene.add_child(lamp)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	env.fog_enabled = true
	env.volumetric_fog_enabled = true
	env.glow_enabled = true
	env.ssao_enabled = true
	env.tonemap_exposure = 1.7
	world.environment = env
	world.camera_attributes = CameraAttributesPractical.new()
	scene.add_child(world)
	await process_frame

	DirAccess.remove_absolute(TMP.path_join("sheet_moved").path_join("pair-lit.png"))
	# subject-black: subject meshes black, everything else hidden, effects off.
	var undo := Cap.apply_mode(scene, root, "subject-black", [subject], [glass])
	_check(_uses_black(part_a) and _uses_black(part_b) and part_a.visible and part_b.visible, "subject-black: every visible subject mesh has the opaque unshaded black override")
	_check(not ground.visible and not sign.visible and not lamp.visible, "subject-black: non-subject mesh, label and light are hidden")
	_check(not glass.visible, "subject-black: a --hide subtree is omitted")
	_check(unseen.layers == 0 and unseen.material_override != null and not _uses_black(unseen), "subject-black: a mesh with no render layers is left alone")
	var flat := world.environment
	_check(flat != env and not flat.fog_enabled and not flat.volumetric_fog_enabled and not flat.glow_enabled and not flat.ssao_enabled and flat.sky == null and flat.background_mode == Environment.BG_COLOR, "subject-black: fog, sky, glow and ssao off, flat colour background")
	_check(world.camera_attributes == null and flat.tonemap_exposure == 1.0 and flat.ambient_light_source == Environment.AMBIENT_SOURCE_DISABLED, "subject-black: no camera attributes, exposure 1, no ambient light")
	_check(root.msaa_3d == Viewport.MSAA_DISABLED and root.screen_space_aa == Viewport.SCREEN_SPACE_AA_DISABLED, "subject-black: anti-aliasing off so the frame holds two values")
	Cap.revert(undo)
	_check(ground.visible and sign.visible and lamp.visible and glass.visible and world.environment == env and part_a.material_override.albedo_texture != null, "revert restores the lit scene")

	# a node the stage step shows after the mode was chosen still gets the mode (the moss bay).
	var bay := Node3D.new()
	bay.visible = false
	var bay_hull := _mesh("BayHull", Vector3(8, 1, 0))
	var bay_lamp := OmniLight3D.new()
	bay.add_child(bay_hull)
	bay.add_child(bay_lamp)
	scene.add_child(bay)
	var show_bay := func() -> void:
		bay.visible = true
		await process_frame
	for mode in ["subject-black", "assembly-black"]:
		undo = await Cap.prepare(scene, root, mode, [subject], [], show_bay)
		_check(bay.visible and not bay_lamp.visible and (_uses_black(bay_hull) if mode == "assembly-black" else not bay_hull.visible), "%s: a node shown by the stage step is blacked or hidden, not left lit" % mode)
		Cap.revert(undo)
		bay.visible = false
	scene.remove_child(bay)
	bay.free()

	# assembly-black: every visible mesh black.
	undo = Cap.apply_mode(scene, root, "assembly-black", [subject], [])
	_check(_uses_black(part_a) and _uses_black(part_b) and _uses_black(glass) and _uses_black(ground) and not lamp.visible and not sign.visible, "assembly-black: every visible mesh is black, non-mesh visuals hidden")
	Cap.revert(undo)

	# frozen state: an animated node stops at the recorded transform.
	var spinner := Spinner.new()
	spinner.name = "Spinner"
	scene.add_child(spinner)
	var specs := ["/root/Scene/Spinner=0,90,0:1,2,3", "/root/Scene/Absent=0,0,0"]
	await process_frame
	var before := spinner.rotation.y
	await process_frame
	await process_frame
	_check(not is_equal_approx(before, spinner.rotation.y), "control: the unfrozen spinner moves")
	_check(not paused, "control: the tree is not paused before the tool freezes it")
	Cap.freeze_tree(self)
	_check(paused, "freeze_tree pauses the tree")
	var records := Cap.apply_freeze(root, specs)
	var first := Cap.snapshot(records)
	for i in 5:
		await process_frame
	var second := Cap.snapshot(records)
	_check(first == second and not first["/root/Scene/Spinner"].is_empty(), "frozen node has the same transform in two frames")
	_check(is_equal_approx(spinner.rotation_degrees.y, 90.0) and spinner.global_position.is_equal_approx(Vector3(1, 2, 3)) and records["/root/Scene/Spinner"]["found"] and not records["/root/Scene/Absent"]["found"], "freeze applies the explicit rotation and position and records a missing node as not found")
	paused = false

	# camera table.
	var anchor := Transform3D(Basis(Vector3.UP, 0.7), Vector3(10, 5, 20))
	var centre := Vector3(10, 7, 20)
	for id in ["asset-front30", "asset-side30", "asset-rear30", "asset-use6"]:
		var v := Cams.view(id, anchor, centre)
		var dist := 6.0 if id == "asset-use6" else 30.0
		var flat_d := Vector2(v["eye"].x - anchor.origin.x, v["eye"].z - anchor.origin.z).length()
		_check(absf(flat_d - dist) < 1e-3 and absf(v["eye"].y - anchor.origin.y - 3.0) < 1e-4 and v["fov"] == 65.0 and v["target"] == centre, "camera %s: %.0f m from the anchor, 3 m above, FOV 65, aimed at the centre" % [id, dist])
	var fovs := {}
	for id in ["overview", "launch", "warden", "moss", "pilot"]:
		fovs[id] = Cams.view(id)["fov"]
	_check(fovs == {"overview": 65.0, "launch": 62.0, "warden": 56.0, "moss": 58.0, "pilot": 39.0}, "the five look views keep the sheet's FOVs")
	_check(Cams.view("asset-front30", anchor, centre)["eye"] != Cams.view("asset-rear30", anchor, centre)["eye"], "front and rear cameras sit on opposite sides")
	var recorded := {
		"approach-in": [Vector3(68.0, 70.2, -92.0), Vector3(49.0, 69.2, -90.0)],
		"approach-out": [Vector3(42.0, 70.2, -79.0), Vector3(49.5, 68.5, -89.5)],
		"approach-leave": [Vector3(54.0, 70.5, -86.5), Vector3(70.0, 68.5, -90.0)],
		"dock-1": [Vector3(48.0, 74.0, -64.0), Vector3(40.0, 68.0, -90.0)],
	}
	var bay_ok := true
	for id in recorded:
		var v := Cams.view(id)
		bay_ok = bay_ok and v["eye"].is_equal_approx(recorded[id][0]) and v["target"].is_equal_approx(recorded[id][1]) and v["fov"] == 62.0
	_check(bay_ok, "bay views match the round-2 moss frames")
	_check(not Cams.names().any(func(id): return Cams.is_bay(id)), "bay views stay out of the default camera set")
	_check(Cams.BAY["dock-0"]["barge"] != Cams.BAY["dock-2"]["barge"], "dock views stage different barge positions")

	# pair: matching runs pair, mismatched cameras or frozen state are refused.
	DirAccess.make_dir_recursive_absolute(TMP)
	var doc := _doc()
	var same := _write_run("same_a", doc)
	var same_b := _write_run("same_b", doc)
	var out := TMP.path_join("sheet_ok")
	_check(Cap.compare(doc, doc.duplicate(true))["errors"].is_empty(), "compare: identical documents have no errors")
	_check(Cap.pair(same, same_b, out) == 0 and FileAccess.file_exists(out.path_join("pair-lit.png")), "pair: matching runs write a sheet")
	var sheet := Image.load_from_file(out.path_join("pair-lit.png"))
	_check(sheet.get_width() == Cams.THUMB.x * 2 + Cap.SHEET_GAP and sheet.get_height() == Cams.THUMB.y * 2, "pair: sheet is base and head thumbnails side by side, one row per camera")
	var moved := doc.duplicate(true)
	moved["frames"][1]["eye"][0] += 0.5
	_check(not Cap.compare(doc, moved)["errors"].is_empty() and Cap.pair(same, _write_run("moved", moved), TMP.path_join("sheet_moved")) == 4 and not FileAccess.file_exists(TMP.path_join("sheet_moved").path_join("pair-lit.png")), "pair: a moved camera is refused and writes no sheet")
	var fov := doc.duplicate(true)
	fov["frames"][0]["fov"] = 60.0
	_check(not Cap.compare(doc, fov)["errors"].is_empty(), "compare: a different FOV is refused")
	var exposure := doc.duplicate(true)
	exposure["frames"][0]["exposure"] = 1.3
	_check(not Cap.compare(doc, exposure)["errors"].is_empty(), "compare: a different exposure is refused")
	var pilot := doc.duplicate(true)
	pilot["class"] = int(doc.get("class", 0)) + 1
	_check(not Cap.compare(doc, pilot)["errors"].is_empty(), "compare: a different pilot class is refused")
	var spawned := doc.duplicate(true)
	spawned["spawn"] = ["lobber@0,0,0"]
	_check(not Cap.compare(doc, spawned)["errors"].is_empty(), "compare: a different enemy spawn is refused")
	var called := doc.duplicate(true)
	called["call"] = ["/root/Game/Spawn_lobber:flash:2"]
	_check(not Cap.compare(doc, called)["errors"].is_empty(), "compare: a different staged event call is refused")
	var placed := doc.duplicate(true)
	placed["glb"] = ["res://assets/models/warden_kit_mind.glb@0,50,0@30"]
	_check(not Cap.compare(doc, placed)["errors"].is_empty(), "compare: a different --glb placement is refused")
	var older := doc.duplicate(true)
	older.erase("glb")
	var empty := doc.duplicate(true)
	empty["glb"] = []
	_check(Cap.compare(older, empty)["errors"].is_empty(), "compare: a document without glb pairs with an empty glb list")
	var root_node := Node3D.new()
	root.add_child(root_node)
	var glb := Cap.place_glb(root_node, "res://assets/models/warden_kit_mind.glb@1,2,3@90")
	_check(glb != null and glb.name == "Glb_warden_kit_mind" and glb.global_position.is_equal_approx(Vector3(1, 2, 3))
		and is_equal_approx(glb.rotation_degrees.y, 90.0) and glb.find_child("WeakPoint", true, false) != null, "place_glb instances the model at the point and yaw")
	_check(Cap.place_glb(root_node, "res://assets/models/no_such_model.glb@0,0,0") == null, "place_glb refuses a missing scene")
	var kit := Cap.place_glb(root_node, "res://assets/models/park/anchor_hoodoo_a.glb@0,0,0")
	var views: Array = kit.find_children("*", "MeshInstance3D", true, false) if kit != null else []
	_check(views.size() == 1 and not String(views[0].name).ends_with("-col")
		and kit.find_children("*", "StaticBody3D", true, false).is_empty(), "place_glb draws a park recipe's body without its -col mesh or collider")
	var enamel: Material = views[0].get_surface_override_material(0) if views.size() == 1 else null
	_check(enamel != null and enamel.resource_path == String(MaterialSlots.row("enamel")["path"]), "place_glb dresses a park recipe's enamel slot with the shared slot resource")
	root_node.queue_free()
	var parsed := Cap.parse_call('/root/Game/Spawn_plated_brute:on_struck:2:["x","y",{"full":true}]')
	_check(parsed["ok"] and parsed["path"] == "/root/Game/Spawn_plated_brute" and parsed["method"] == "on_struck"
		and parsed["frames"] == 2 and parsed["args"] == ["x", "y", {"full": true}], "parse_call keeps a JSON argument list that holds colons")
	var bare := Cap.parse_call("/root/Game/Spawn_lobber:flash")
	_check(bare["ok"] and bare["frames"] == 0 and bare["args"] == [], "parse_call defaults to no frames and no arguments")
	_check(not Cap.parse_call("/root/Game/Spawn_lobber:flash:2:{\"a\":1}")["ok"], "parse_call refuses arguments that are not a JSON array")
	var frozen := doc.duplicate(true)
	frozen["frames"][0]["frozen"]["/root/Scene/Spinner"][3] = 0.25
	_check(not Cap.compare(doc, frozen)["errors"].is_empty() and Cap.pair(same, _write_run("frozen", frozen), TMP.path_join("sheet_frozen")) == 4, "pair: a different frozen node transform is refused")
	var specs_differ := doc.duplicate(true)
	specs_differ["freeze_specs"] = ["/root/Scene/Spinner=0,45,0"]
	_check(not Cap.compare(doc, specs_differ)["errors"].is_empty(), "compare: different freeze specs are refused")
	var wrong_mode := doc.duplicate(true)
	wrong_mode["mode"] = "subject-black"
	_check(not Cap.compare(doc, wrong_mode)["errors"].is_empty(), "compare: different modes are refused")
	var missing := doc.duplicate(true)
	missing["frames"][0]["frozen"]["/root/Scene/Spinner"] = []
	var missing_result := Cap.compare(doc, missing)
	_check(missing_result["errors"].is_empty() and not missing_result["notes"].is_empty(), "compare: a node present on one side only is a note, not a refusal")
	# subject-context-depth: subject black, other meshes flat grey but still drawn (depth), lights hidden.
	undo = Cap.apply_mode(scene, root, "subject-context-depth", [subject], [glass])
	var grey := ground.material_override as StandardMaterial3D
	_check(_uses_black(part_a) and _uses_black(part_b), "subject-context-depth: subject meshes black")
	_check(ground.visible and grey != null and grey.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED and grey.albedo_color == Cap.GREY \
		and grey.albedo_texture == null and grey.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and not grey.no_depth_test and not grey.emission_enabled, "subject-context-depth: context mesh is opaque unshaded background grey with depth test on")
	_check(not lamp.visible and not sign.visible and not glass.visible, "subject-context-depth: lights and labels hidden, a --hide subtree omitted")
	Cap.revert(undo)
	_check(ground.material_override.albedo_texture != null and part_a.material_override.albedo_texture != null, "subject-context-depth: revert restores the lit materials")
	_check(Cap.MODES.has("subject-context-depth") and Cap.MODES.slice(0, 3) == ["lit", "subject-black", "assembly-black"], "modes: the three original modes keep their place")

	# clay: a lit override on one subtree, flat neutral and shaded, every other mesh left alone.
	var clay_undo := Cap.apply_clay([subject])
	var clay := part_a.material_override as StandardMaterial3D
	_check(clay != null and clay.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL and clay.albedo_color == Cap.CLAY and clay.albedo_texture == null \
		and clay.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and not clay.emission_enabled and not clay.vertex_color_use_as_albedo and part_b.material_override == clay and glass.material_override == clay, "clay: every mesh under the subtree takes one flat neutral shaded material")
	_check(ground.material_override.albedo_texture != null, "clay: a mesh outside the subtree keeps its material")
	Cap.revert_clay(clay_undo)
	_check(part_a.material_override.albedo_texture != null and glass.material_override.albedo_texture != null, "clay: revert restores the materials")

	# --exposure: overrides the scene's lit exposure; absent (-1) keeps it.
	_check(is_equal_approx(Cap.lit_exposure_for(1.1, 1.0), 1.0) and is_equal_approx(Cap.lit_exposure_for(1.1, -1.0), 1.1), "exposure: the override replaces the scene value; without it the scene value stays")

	# Orthographic family camera and the isolate filter.
	var box := AABB(Vector3(-175, -20, 60), Vector3(16, 40, 120))
	var front := Cams.ortho_view("ortho-front", box)
	var side := Cams.ortho_view("ortho-side", box)
	var top := Cams.ortho_view("ortho-top", box)
	var box_centre := box.get_center()
	_check(front["eye"].is_equal_approx(box_centre + Vector3(250, 0, 0)) and side["eye"].is_equal_approx(box_centre + Vector3(0, 0, 250)) and top["eye"].is_equal_approx(box_centre + Vector3(0, 250, 0)) and top["up"] == Vector3(0, 0, 1), "ortho: front 250 m toward the arena along X, side +Z, top +Y with up +Z")
	_check(is_equal_approx(front["size"], 120.0 * 1.1) and Cams.ortho_view("ortho-front", AABB(Vector3(190, 0, 0), Vector3(16, 40, 120)))["eye"].x < 190.0, "ortho: span is the largest extent times 1.10; an east box looks from -X")
	var camera := Camera3D.new()
	root.add_child(camera)
	Cams.aim_ortho(camera, top)
	_check(camera.projection == Camera3D.PROJECTION_ORTHOGONAL and is_equal_approx(camera.size, top["size"]) and is_equal_approx(camera.near, 0.05) and is_equal_approx(camera.far, 1800.0) and camera.keep_aspect == Camera3D.KEEP_HEIGHT, "ortho: orthogonal, vertical span, near 0.05, far 1800")
	_check((-camera.global_transform.basis.z).is_equal_approx(Vector3.DOWN) and camera.global_transform.basis.y.is_equal_approx(Vector3(0, 0, 1)), "ortho: top camera looks down with +Z up")
	Cams.aim(camera, Vector3(0, 5, 5), Vector3.ZERO, 62.0)
	_check(camera.projection == Camera3D.PROJECTION_PERSPECTIVE, "aim restores a perspective projection after an orthographic frame")
	camera.free()
	_check(not Cams.names().any(func(n): return Cams.is_ortho(n)), "ortho cameras are not part of the default camera set")
	var two := ArrayMesh.new()
	var quad := PackedVector3Array([Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(50, 0, 0), Vector3(51, 0, 0), Vector3(50, 1, 0)])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = quad
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 3, 4, 5])
	two.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var kept := Cap.filter_mesh(two, Transform3D(Basis.IDENTITY, Vector3(1, 0, 0)), AABB(Vector3(0, -1, -1), Vector3(5, 3, 2)))
	var kept_vertices: PackedVector3Array = kept.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	_check(kept_vertices.size() == 3 and kept_vertices[0] == Vector3(0, 0, 0), "filter_mesh keeps only the triangles whose centroid is inside the world box")
	var rest := Cap.filter_mesh(two, Transform3D(Basis.IDENTITY, Vector3(1, 0, 0)), AABB(Vector3(0, -1, -1), Vector3(5, 3, 2)), true)
	var rest_vertices: PackedVector3Array = rest.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	_check(rest_vertices.size() == 3 and rest_vertices[0] == Vector3(50, 0, 0), "filter_mesh with invert keeps exactly the triangles outside the box (the isolate-rest context)")
	_check(Cap.filter_mesh(two, Transform3D.IDENTITY, AABB(Vector3(200, 0, 0), Vector3(1, 1, 1))).get_surface_count() == 0, "filter_mesh returns an empty mesh when nothing is inside")

	quit(_t.verdict())


func _doc() -> Dictionary:
	var spin := [1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0]
	var frames := []
	for id in ["asset-front30", "asset-use6"]:
		frames.append({"id": id, "eye": [1.0, 2.0, 3.0], "target": [0.0, 1.0, 0.0], "fov": 65.0, "camera_basis": [1, 0, 0, 0, 1, 0, 0, 0, 1],
			"anchor": [0.0, 0.0, 0.0], "centre": [0.0, 1.0, 0.0], "exposure": 1.0, "frozen": {"/root/Scene/Spinner": spin.duplicate()},
			"thumb": id + ".thumb.png"})
	return {"mode": "lit", "seed": 280928, "size": [1920, 1080], "freeze_specs": ["/root/Scene/Spinner=0,90,0"], "hide": [], "anchor_offset": [0.0, 0.0, 0.0], "frames": frames}


func _write_run(name: String, doc: Dictionary) -> String:
	var dir := TMP.path_join(name)
	DirAccess.make_dir_recursive_absolute(dir.path_join(doc["mode"]))
	for f in doc["frames"]:
		var img := Image.create(Cams.THUMB.x, Cams.THUMB.y, false, Image.FORMAT_RGB8)
		img.fill(Color(0.5, 0.5, 0.5))
		img.save_png(dir.path_join(doc["mode"]).path_join(f["thumb"]))
	var file := FileAccess.open(dir.path_join(doc["mode"]).path_join("frames.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(doc))
	file.close()
	return dir
