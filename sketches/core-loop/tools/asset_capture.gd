extends SceneTree

const Cams := preload("res://tools/capture_cameras.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const BakeLook := preload("res://src/presentation/bake_look.gd")
const RecipeProps := preload("res://src/presentation/recipe_props.gd")
const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const PARK_MODELS := "res://assets/models/park/"

const VERSION := 1
const SEED := 280928
const MODES := ["lit", "subject-black", "assembly-black", "subject-context-depth"]
const GREY := Color(0.5, 0.5, 0.5)
const CLAY := Color(0.62, 0.6, 0.57)
const EPS := 1.0e-4
const SETTLE_PHYSICS_FRAMES := 120
const DRAW_FRAMES := 12
const SHEET_GAP := 4

var out := ""
var pair_mode := false
var modes: Array = ["lit"]
var camera_ids: Array = []
var subject_path := ""
var anchor_path := ""
var class_index := 0
var spawn_specs: Array = []
var glb_specs: Array = []
var call_specs: Array = []
var anchor_offset := Vector3.ZERO
var centre_override = null
var freeze_specs: Array = []
var hide_paths: Array = []
var clay_paths: Array = []
var exposure_override: float = -1.0
var aabb_arg = null
var isolate_path := ""
var isolate_rest := false
var base_dir := ""
var head_dir := ""
var game
var camera: Camera3D


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--pair":
			pair_mode = true
		elif arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--base="):
			base_dir = arg.trim_prefix("--base=")
		elif arg.begins_with("--head="):
			head_dir = arg.trim_prefix("--head=")
		elif arg.begins_with("--mode="):
			modes = Array(arg.trim_prefix("--mode=").split(",", false))
		elif arg.begins_with("--cameras="):
			camera_ids = Array(arg.trim_prefix("--cameras=").split(",", false))
		elif arg.begins_with("--subject="):
			subject_path = arg.trim_prefix("--subject=")
		elif arg.begins_with("--class="):
			class_index = int(arg.trim_prefix("--class="))
		elif arg.begins_with("--spawn="):
			spawn_specs.append(arg.trim_prefix("--spawn="))
		elif arg.begins_with("--glb="):
			glb_specs.append(arg.trim_prefix("--glb="))
		elif arg.begins_with("--call="):
			call_specs.append(arg.trim_prefix("--call="))
		elif arg.begins_with("--anchor="):
			anchor_path = arg.trim_prefix("--anchor=")
		elif arg.begins_with("--anchor-offset="):
			anchor_offset = _vec(arg.trim_prefix("--anchor-offset="))
		elif arg.begins_with("--centre="):
			centre_override = _vec(arg.trim_prefix("--centre="))
		elif arg.begins_with("--freeze="):
			freeze_specs.append(arg.trim_prefix("--freeze="))
		elif arg.begins_with("--hide="):
			hide_paths.append(arg.trim_prefix("--hide="))
		elif arg.begins_with("--clay="):
			clay_paths.append(arg.trim_prefix("--clay="))
		elif arg.begins_with("--exposure="):
			exposure_override = float(arg.trim_prefix("--exposure="))
		elif arg.begins_with("--aabb="):
			var box := arg.trim_prefix("--aabb=").split(",")
			aabb_arg = AABB(Vector3(float(box[0]), float(box[1]), float(box[2])), Vector3(float(box[3]), float(box[4]), float(box[5])))
		elif arg.begins_with("--isolate="):
			isolate_path = arg.trim_prefix("--isolate=")
		elif arg == "--isolate-rest":
			isolate_rest = true
	if pair_mode:
		if base_dir.is_empty() or head_dir.is_empty() or out.is_empty():
			printerr("pair needs --base, --head and --out")
			quit(2)
			return
		quit(pair(base_dir, head_dir, out))
		return
	if out.is_empty() or subject_path.is_empty() or DisplayServer.get_name() == "headless":
		printerr("capture needs --out, --subject and a native display")
		quit(2)
		return
	if camera_ids.is_empty():
		camera_ids = Cams.names()
	for id in camera_ids:
		if not Cams.names().has(id) and not Cams.is_bay(id) and not (Cams.is_ortho(id) and aabb_arg != null):
			printerr("unknown camera ", id)
			quit(2)
			return
	for mode in modes:
		if not MODES.has(mode):
			printerr("unknown mode ", mode)
			quit(2)
			return
	if anchor_path.is_empty():
		anchor_path = subject_path.get_slice(",", 0)
	root.size = Cams.SIZE
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	_run.call_deferred()


static func _vec(text: String) -> Vector3:
	var p := text.split(",")
	return Vector3(float(p[0]), float(p[1]), float(p[2]))


func _run() -> void:
	seed(SEED)
	game = Game.new()
	game.name = "Game"
	game.test_mode = true
	root.add_child(game)
	await process_frame
	game.ctx.calm = true
	game.flow.force_warden = true
	game.flow.press_start()
	game.flow.choose_class(class_index)
	game.run.set_max_hp(999999.0)
	for spec: String in spawn_specs:
		var kind := spec.get_slice("@", 0)
		var enemy: Node3D = game.combat.spawn_enemy(kind, _vec(spec.get_slice("@", 1)))
		enemy.name = "Spawn_" + kind
		print("spawned ", enemy.get_path())
	for spec: String in glb_specs:
		var placed := place_glb(game, spec)
		if placed == null:
			printerr("--glb scene missing or not a PackedScene: ", spec)
			quit(3)
			return
		print("placed ", placed.get_path())
	game.player.source = Intent.Scripted.new()
	for i in SETTLE_PHYSICS_FRAMES:
		await physics_frame
	for spec: String in call_specs:
		var call := parse_call(spec)
		var node := root.get_node_or_null(call["path"])
		if not call["ok"] or node == null or not node.has_method(call["method"]):
			printerr("--call target missing or args not a JSON array: ", spec)
			quit(2)
			return
		node.callv(call["method"], call["args"])
		print("called ", spec)
		for i in call["frames"]:
			await physics_frame
	freeze_tree(self)
	game.player.body().freeze = true
	for node in root.find_children("*", "CanvasLayer", true, false):
		node.visible = false
	var warden = game.flow.warden
	if warden != null:
		warden._look._badge.visible = false
	for label in root.find_children("*", "Label3D", true, false):
		label.visible = false
	camera = Camera3D.new()
	game.add_child(camera)
	camera.current = true
	camera.far = Cams.FAR
	camera.near = Cams.NEAR
	var subjects: Array = []
	for path in subject_path.split(",", false):
		var node := root.get_node_or_null(path)
		if node != null:
			subjects.append(node)
	var anchor := root.get_node_or_null(anchor_path) as Node3D
	if subjects.size() != subject_path.split(",", false).size() or anchor == null:
		printerr("subject or anchor path not found: ", subject_path, " ", anchor_path)
		quit(3)
		return
	var hides: Array = []
	for path in hide_paths:
		var node := root.get_node_or_null(path)
		if node == null:
			printerr("hide path not found: ", path)
			quit(3)
			return
		hides.append(node)
	var clay_nodes: Array = []
	for path in clay_paths:
		var node := root.get_node_or_null(path)
		if node == null:
			printerr("clay path not found: ", path)
			quit(3)
			return
		clay_nodes.append(node)
	if not isolate_path.is_empty():
		var isolated := root.get_node_or_null(isolate_path) as MeshInstance3D
		if isolated == null or aabb_arg == null:
			printerr("--isolate needs a mesh path and --aabb: ", isolate_path)
			quit(3)
			return
		if isolate_rest:
			var rest := MeshInstance3D.new()
			rest.name = isolated.name + "Rest"
			rest.mesh = filter_mesh(isolated.mesh, isolated.global_transform, aabb_arg, true)
			rest.transform = isolated.transform
			rest.layers = isolated.layers
			isolated.get_parent().add_child(rest)
		isolated.mesh = filter_mesh(isolated.mesh, isolated.global_transform, aabb_arg)
	var plan := {}
	var frozen_specs_seen := {}
	for id in camera_ids:
		await _stage(id)
		var records := apply_freeze(root, freeze_specs)
		if Cams.is_ortho(id):
			plan[id] = Cams.ortho_view(id, aabb_arg)
			frozen_specs_seen = records
			continue
		var centre: Vector3 = centre_override if centre_override != null else subject_centre(subjects)
		var ground := anchor.global_transform * anchor_offset
		var v := Cams.view(id, Transform3D(anchor.global_basis, ground), centre)
		v["anchor"] = ground
		v["centre"] = centre
		plan[id] = v
		frozen_specs_seen = records
	var env := _first_environment()
	var lit_exposure := lit_exposure_for(env.tonemap_exposure if env != null else 1.0, exposure_override)
	if env != null and exposure_override > 0.0:
		env.tonemap_exposure = lit_exposure
	for mode in modes:
		var exposure := lit_exposure
		if mode != "lit":
			exposure = 1.0
		var frames: Array = []
		var dir := out.path_join(mode)
		DirAccess.make_dir_recursive_absolute(dir)
		for id in camera_ids:
			var state := await prepare(root, root.get_viewport(), mode, subjects, hides, _stage.bind(id))
			var records := apply_freeze(root, freeze_specs)
			var clay_undo := apply_clay(clay_nodes) if mode == "lit" else []
			var v: Dictionary = plan[id]
			if Cams.is_ortho(id):
				Cams.aim_ortho(camera, v)
			else:
				Cams.aim(camera, v["eye"], v["target"], v["fov"])
			for i in DRAW_FRAMES:
				await RenderingServer.frame_post_draw
			for node in root.find_children("*", "CanvasItem", true, false):
				node.visible = false
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			var thumb := image.duplicate() as Image
			thumb.resize(Cams.THUMB.x, Cams.THUMB.y, Image.INTERPOLATE_TRILINEAR)
			var png := dir.path_join(id + ".png")
			var thumb_png := dir.path_join(id + ".thumb.png")
			if image.save_png(png) != OK or thumb.save_png(thumb_png) != OK:
				quit(3)
				return
			var frozen := snapshot(records)
			var ortho := Cams.is_ortho(id)
			frames.append({"id": id, "eye": _arr(v["eye"]), "target": _arr(v["target"]), "fov": 0.0 if ortho else v["fov"], "ortho_size": v["size"] if ortho else 0.0,
				"camera_basis": _basis(camera.global_transform.basis), "anchor": [] if Cams.is_look(id) or ortho else _arr(v["anchor"]), "centre": [] if Cams.is_look(id) or ortho else _arr(v["centre"]),
				"exposure": exposure, "frozen": frozen,
				"file": id + ".png", "sha256": FileAccess.get_sha256(png),
				"thumb": id + ".thumb.png", "thumb_sha256": FileAccess.get_sha256(thumb_png)})
			revert_clay(clay_undo)
			if mode != "lit":
				revert(state)
		var doc := {"tool": "asset_capture.gd", "version": VERSION, "seed": SEED, "size": [Cams.SIZE.x, Cams.SIZE.y],
			"thumb_size": [Cams.THUMB.x, Cams.THUMB.y], "adapter": RenderingServer.get_video_adapter_name(),
			"mode": mode, "class": class_index, "spawn": spawn_specs, "glb": glb_specs, "call": call_specs, "subject": subject_path, "anchor": anchor_path, "anchor_offset": _arr(anchor_offset),
			"hide": hide_paths, "clay": clay_paths, "aabb": [] if aabb_arg == null else _arr(aabb_arg.position) + _arr(aabb_arg.size), "isolate": isolate_path, "isolate_rest": isolate_rest, "freeze_specs": freeze_specs, "frozen_nodes": frozen_specs_seen,
			"paused": paused, "source_sha256": _hashes(), "frames": frames}
		var file := FileAccess.open(dir.path_join("frames.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(doc, "\t"))
		file.close()
	quit()


static func place_glb(parent: Node, spec: String) -> Node3D:
	var parts := spec.split("@")
	var packed := load(parts[0]) as PackedScene if ResourceLoader.exists(parts[0]) else null
	if packed == null or parts.size() < 2:
		return null
	var node := packed.instantiate() as Node3D
	node.name = "Glb_" + parts[0].get_file().get_basename()
	parent.add_child(node)
	node.global_position = _vec(parts[1])
	if parts.size() > 2:
		node.rotation_degrees.y = float(parts[2])
	if not parts[0].begins_with(PARK_MODELS):
		var hero := parent.find_child("HeroAssets", true, false)
		if hero != null and hero.has_method("paint"):
			hero.paint(node, {})
		BakeLook.dress(node)
		return node
	for view: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		if String(view.name).ends_with(ParkRecipes.COL_SUFFIX):
			view.get_parent().remove_child(view)
			view.free()
			continue
		if view.mesh == null:
			continue
		for i in view.mesh.get_surface_count():
			var original := view.mesh.surface_get_material(i)
			var slot := String(original.resource_name) if original != null else ""
			if RecipeProps.is_slot_role(slot):
				view.set_surface_override_material(i, RecipeProps.slot_material(slot))
	return node


func _stage(id: String) -> void:
	var terrain = game.ctx.terrain
	var ball: Vector3 = terrain.drop_point(-65, -130, 1.2)
	if id == "launch":
		ball = terrain.drop_point(-53.85, -39.07, 3.0)
	game.player.reset_to(ball)
	game.player._visual_root.global_position = ball
	var bay = game.world.bay
	if Cams.is_bay(id):
		var row: Dictionary = Cams.BAY[id]
		bay.visible = true
		bay._barge.visible = true
		bay._barge.position = Cams.BAY_HOME + row["barge"]
		if row["ball"] != null:
			game.player.reset_to(row["ball"])
			game.player._visual_root.global_position = row["ball"]
	elif id == "moss":
		bay.visible = true
		bay._barge.visible = true
		bay._barge.position = Vector3(50, 65, -90)
	else:
		bay.visible = false
	for i in 3:
		await RenderingServer.frame_post_draw


func _first_environment() -> Environment:
	for node in root.find_children("*", "WorldEnvironment", true, false):
		return (node as WorldEnvironment).environment
	return null


func _hashes() -> Dictionary:
	var result := {}
	for path in ["tools/asset_capture.gd", "tools/capture_cameras.gd", "src/presentation/hero_assets.gd", "src/presentation/recipe_props.gd", "src/presentation/material_slots.gd", "src/presentation/bake_look.gd", "src/presentation/spillway_scenery.gd", "src/world/terrain.gd", "src/core/palette.gd"]:
		result[path] = FileAccess.get_sha256("res://" + path)
	return result


static func _arr(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


static func _basis(b: Basis) -> Array:
	return [b.x.x, b.x.y, b.x.z, b.y.x, b.y.y, b.y.z, b.z.x, b.z.y, b.z.z]


static func _xform(t: Transform3D) -> Array:
	return _basis(t.basis) + _arr(t.origin)


static func black_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color.BLACK
	m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_fog = true
	m.disable_ambient_light = true
	m.disable_receive_shadows = true
	m.vertex_color_use_as_albedo = false
	m.emission_enabled = false
	return m


static func context_material() -> StandardMaterial3D:
	var m := black_material()
	m.albedo_color = GREY
	return m


static func filter_mesh(mesh: Mesh, xf: Transform3D, box: AABB, invert := false) -> ArrayMesh:
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var out_vertices := PackedVector3Array()
	var out_normals := PackedVector3Array()
	for i in range(0, indices.size(), 3):
		var centroid := (xf * vertices[indices[i]] + xf * vertices[indices[i + 1]] + xf * vertices[indices[i + 2]]) / 3.0
		if box.has_point(centroid) != invert:
			for e in 3:
				out_vertices.append(vertices[indices[i + e]])
				out_normals.append(normals[indices[i + e]])
	var kept := []
	kept.resize(Mesh.ARRAY_MAX)
	kept[Mesh.ARRAY_VERTEX] = out_vertices
	kept[Mesh.ARRAY_NORMAL] = out_normals
	var result := ArrayMesh.new()
	if out_vertices.size() > 0:
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, kept)
	return result


static func clay_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = CLAY
	m.roughness = 1.0
	m.metallic = 0.0
	m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	m.vertex_color_use_as_albedo = false
	m.emission_enabled = false
	return m


static func apply_clay(subtrees: Array) -> Array:
	var undo := []
	var material := clay_material()
	for subtree: Node in subtrees:
		var meshes: Array = subtree.find_children("*", "GeometryInstance3D", true, false)
		meshes.append(subtree)
		for found in meshes:
			var g := found as GeometryInstance3D
			if g != null and _is_mesh(g):
				undo.append([g, g.material_override])
				g.material_override = material
	return undo


static func revert_clay(undo: Array) -> void:
	for row in undo:
		if is_instance_valid(row[0]):
			(row[0] as GeometryInstance3D).material_override = row[1]


static func flat_environment() -> Environment:
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = GREY
	e.sky = null
	e.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	e.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	e.tonemap_exposure = 1.0
	e.fog_enabled = false
	e.volumetric_fog_enabled = false
	e.glow_enabled = false
	e.ssao_enabled = false
	e.ssil_enabled = false
	e.sdfgi_enabled = false
	e.ssr_enabled = false
	e.adjustment_enabled = false
	return e


static func _is_mesh(n: Node) -> bool:
	return n is MeshInstance3D or n is MultiMeshInstance3D


static func apply_mode(scene_root: Node, viewport: Viewport, mode: String, subjects: Array, hides: Array) -> Dictionary:
	var undo := {"nodes": [], "envs": [], "aa": [viewport.msaa_3d, viewport.screen_space_aa, viewport.use_taa], "black": [], "hidden": [], "context": []}
	var material := black_material()
	var context := context_material()
	var flat := flat_environment()
	for node in scene_root.find_children("*", "WorldEnvironment", true, false):
		var w := node as WorldEnvironment
		undo["envs"].append([w, w.environment, w.camera_attributes])
		w.environment = flat
		w.camera_attributes = null
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.use_taa = false
	for found in scene_root.find_children("*", "VisualInstance3D", true, false):
		var n := found as VisualInstance3D
		if not n.is_visible_in_tree() or n.layers == 0:
			continue
		var in_subject := false
		for subject: Node in subjects:
			if subject == n or subject.is_ancestor_of(n):
				in_subject = true
		var omitted := false
		for h: Node in hides:
			if h == n or h.is_ancestor_of(n):
				omitted = true
		var wanted := _is_mesh(n) and (mode == "assembly-black" or (in_subject and not omitted))
		var g := n as GeometryInstance3D
		undo["nodes"].append([n, n.visible, g.material_override if g != null else null, g.cast_shadow if g != null else 0])
		if mode == "subject-context-depth" and _is_mesh(n) and not wanted and not (in_subject and omitted):
			g.material_override = context
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			undo["context"].append(n)
		elif mode == "subject-context-depth" and _is_mesh(n) and wanted:
			g.material_override = material
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			undo["black"].append(n)
		elif wanted:
			g.material_override = material
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			undo["black"].append(n)
		else:
			n.visible = false
			undo["hidden"].append(n)
	return undo


static func prepare(scene_root: Node, viewport: Viewport, mode: String, subjects: Array, hides: Array, stage: Callable) -> Dictionary:
	await stage.call()
	if mode == "lit":
		return {}
	return apply_mode(scene_root, viewport, mode, subjects, hides)


static func lit_exposure_for(scene_exposure: float, override: float) -> float:
	return override if override > 0.0 else scene_exposure


static func parse_call(spec: String) -> Dictionary:
	var parts := spec.split(":", true, 3)
	var args = JSON.parse_string(parts[3]) if parts.size() > 3 else []
	return {
		"path": parts[0], "method": parts[1] if parts.size() > 1 else "",
		"frames": int(parts[2]) if parts.size() > 2 else 0, "args": args if args is Array else [],
		"ok": parts.size() > 1 and args is Array,
	}


static func freeze_tree(tree: SceneTree) -> void:
	tree.paused = true


static func revert(undo: Dictionary) -> void:
	for row in undo["nodes"]:
		var n: VisualInstance3D = row[0]
		if not is_instance_valid(n):
			continue
		n.visible = row[1]
		var g := n as GeometryInstance3D
		if g != null:
			g.material_override = row[2]
			g.cast_shadow = row[3]
	for row in undo["envs"]:
		row[0].environment = row[1]
		row[0].camera_attributes = row[2]
	var aa: Array = undo["aa"]
	var vp := Engine.get_main_loop().root as Viewport
	vp.msaa_3d = aa[0]
	vp.screen_space_aa = aa[1]
	vp.use_taa = aa[2]


static func apply_freeze(scene_root: Node, specs: Array) -> Dictionary:
	var records := {}
	for spec: String in specs:
		var path := spec
		var rec := {"spec": spec, "found": false}
		if "@" in spec:
			path = spec.get_slice("@", 0)
			var clip := spec.get_slice("@", 1)
			var player := scene_root.get_node_or_null(path) as AnimationPlayer
			if player != null:
				player.play(clip.get_slice(":", 0))
				player.seek(float(clip.get_slice(":", 1)), true)
				player.pause()
				rec["found"] = true
				rec["clip_time"] = player.current_animation_position
				rec["clip"] = player.current_animation
		else:
			path = spec.get_slice("=", 0)
			var node := scene_root.get_node_or_null(path) as Node3D
			if node != null:
				var value := spec.get_slice("=", 1)
				var deg := _vec(value.get_slice(":", 0))
				node.basis = Basis.from_euler(Vector3(deg_to_rad(deg.x), deg_to_rad(deg.y), deg_to_rad(deg.z)))
				if ":" in value:
					node.global_position = _vec(value.get_slice(":", 1))
				rec["found"] = true
		rec["path"] = path
		records[path] = rec
	for path in records:
		var node := scene_root.get_node_or_null(path) as Node3D
		if node != null:
			records[path]["local"] = _xform(node.transform)
			records[path]["global"] = _xform(node.global_transform)
	return records


static func snapshot(records: Dictionary) -> Dictionary:
	var result := {}
	var tree := Engine.get_main_loop() as SceneTree
	for path in records:
		var node := tree.root.get_node_or_null(path) as Node3D
		result[path] = _xform(node.global_transform) if node != null else []
	return result


static func subject_centre(subjects: Array) -> Vector3:
	var box := AABB()
	var first := true
	var nodes := []
	for subject: Node in subjects:
		nodes.append_array(subject.find_children("*", "VisualInstance3D", true, false))
		if subject is VisualInstance3D:
			nodes.append(subject)
	for found in nodes:
		var n := found as VisualInstance3D
		if not _is_mesh(n) or not n.is_visible_in_tree() or n.layers == 0:
			continue
		var b := n.global_transform * n.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box.get_center()


static func _close(a, b) -> bool:
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not _close(a[i], b[i]):
				return false
		return true
	if (a is float or a is int) and (b is float or b is int):
		return absf(float(a) - float(b)) <= EPS
	return a == b


static func compare(a: Dictionary, b: Dictionary) -> Dictionary:
	var errors: Array = []
	var notes: Array = []
	for key in ["mode", "class", "spawn", "call", "seed", "size", "freeze_specs", "hide", "anchor_offset", "aabb", "isolate"]:
		if not _close(a.get(key), b.get(key)):
			errors.append("%s differs: %s vs %s" % [key, a.get(key), b.get(key)])
	if not _close(a.get("glb", []), b.get("glb", [])):
		errors.append("glb differs: %s vs %s" % [a.get("glb", []), b.get("glb", [])])
	var fa := {}
	var fb := {}
	for f in a.get("frames", []):
		fa[f["id"]] = f
	for f in b.get("frames", []):
		fb[f["id"]] = f
	for id in fa:
		if not fb.has(id):
			errors.append("frame %s only in base" % id)
	for id in fb:
		if not fa.has(id):
			errors.append("frame %s only in head" % id)
	for id in fa:
		if not fb.has(id):
			continue
		var x: Dictionary = fa[id]
		var y: Dictionary = fb[id]
		for key in ["eye", "target", "fov", "ortho_size", "camera_basis", "anchor", "centre", "exposure"]:
			if not _close(x.get(key), y.get(key)):
				errors.append("%s: %s differs: %s vs %s" % [id, key, x.get(key), y.get(key)])
		var paths := {}
		for p in x.get("frozen", {}):
			paths[p] = true
		for p in y.get("frozen", {}):
			paths[p] = true
		for p in paths:
			var tx = x.get("frozen", {}).get(p, [])
			var ty = y.get("frozen", {}).get(p, [])
			if tx.is_empty() or ty.is_empty():
				notes.append("%s: frozen node %s present on one side only" % [id, p])
			elif not _close(tx, ty):
				errors.append("%s: frozen node %s differs: %s vs %s" % [id, p, tx, ty])
	return {"errors": errors, "notes": notes}


static func pair(base_dir: String, head_dir: String, out_dir: String) -> int:
	var report := {"base": base_dir, "head": head_dir, "modes": {}}
	var plans := []
	var refused := false
	for mode in MODES:
		var pa := base_dir.path_join(mode).path_join("frames.json")
		var pb := head_dir.path_join(mode).path_join("frames.json")
		if not FileAccess.file_exists(pa) or not FileAccess.file_exists(pb):
			continue
		var a: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(pa))
		var b: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(pb))
		var result := compare(a, b)
		report["modes"][mode] = {"errors": result["errors"], "notes": result["notes"], "sheet": ""}
		if not result["errors"].is_empty():
			refused = true
			printerr("REFUSED %s: %d mismatches, first: %s" % [mode, result["errors"].size(), result["errors"][0]])
		plans.append([mode, a, b])
	if plans.is_empty():
		printerr("REFUSED: no matching mode frames.json in both runs")
		return 4
	if refused:
		return 4
	DirAccess.make_dir_recursive_absolute(out_dir)
	for row in plans:
		var mode: String = row[0]
		var a: Dictionary = row[1]
		var b: Dictionary = row[2]
		var w := Cams.THUMB.x
		var h := Cams.THUMB.y
		var rows: int = a["frames"].size()
		var sheet := Image.create(w * 2 + SHEET_GAP, h * rows, false, Image.FORMAT_RGB8)
		sheet.fill(Color(0.1, 0.1, 0.1))
		for i in rows:
			var left := Image.load_from_file(base_dir.path_join(mode).path_join(a["frames"][i]["thumb"]))
			var right := Image.load_from_file(head_dir.path_join(mode).path_join(b["frames"][i]["thumb"]))
			left.convert(Image.FORMAT_RGB8)
			right.convert(Image.FORMAT_RGB8)
			sheet.blit_rect(left, Rect2i(0, 0, w, h), Vector2i(0, h * i))
			sheet.blit_rect(right, Rect2i(0, 0, w, h), Vector2i(w + SHEET_GAP, h * i))
		var path := out_dir.path_join("pair-%s.png" % mode)
		sheet.save_png(path)
		report["modes"][mode]["sheet"] = path
		report["modes"][mode]["rows"] = a["frames"].map(func(f): return f["id"])
	var file := FileAccess.open(out_dir.path_join("pair.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	return 0
