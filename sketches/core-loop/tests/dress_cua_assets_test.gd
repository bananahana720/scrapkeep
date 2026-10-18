extends SceneTree

const BASE := "res://assets/cosmetics/"
const TRAILS := [
	["trail_salt_skip", "ChalkPuff", "fade_shrink", 0.35, Vector2(0.09, 0.09), "e9ecea"],
	["trail_ink_stitch", "FlatStamp", "fade", 0.25, Vector2(0.12, 0.07), "2b3a4a"],
	["trail_plum_curl", "CrescentPuff", "rotate_fade", 0.35, Vector2(0.13, 0.10), "8a3f6e"],
	["trail_forge_chips", "Chip", "tumble_fade", 0.25, Vector2(0.045, 0.045), "3a6fb0"],
	["trail_moth_tuft", "PairedTuft", "expand_fade", 0.40, Vector2(0.15, 0.09), "a39cb3"],
	["trail_rose_wash", "WashPuff", "flatten_fade", 0.35, Vector2(0.16, 0.08), "d68ab0"],
	["trail_sable_cable", "CableDash", "fade", 0.35, Vector2(0.03, 0.12), "3f8f6a"],
	["trail_rivet_swarf", "Swarf", "tumble_fade", 0.30, Vector2(0.07, 0.05), "ae7240"],
	["trail_kest_fuse_smoke", "SmokeWisp", "expand_fade", 0.40, Vector2(0.07, 0.16), "8c8577"],
	["trail_tarn_claw_marks", "ClawPair", "fade", 0.40, Vector2(0.40, 0.06), "d2c5a5"],
	["trail_tally_punch_tape", "TapeStrip", "fade", 0.35, Vector2(0.05, 0.14), "f7f1e3"],
	["trail_cannon_recital", "RecitalMarks", "fade", 0.45, Vector2(0.30, 0.07), "6fb3a6"],
	["trail_any_downbeat", "BeatTick", "fade", 0.30, Vector2(0.10, 0.025), "8a5a3a"],
]
const DECALS := ["fern", "patch", "snail_shell", "thimble", "mushroom", "paw", "seashell", "moth", "sable_spool", "curtain_call"]
const DECAL_SIZES := [Vector2(0.44, 0.55), Vector2(0.44, 0.34), Vector2(0.44, 0.42), Vector2(0.36, 0.42), Vector2(0.44, 0.40), Vector2(0.42, 0.42), Vector2(0.46, 0.42), Vector2(0.50, 0.34), Vector2(0.44, 0.44), Vector2(0.44, 0.37)]
const PAINTS := ["night", "forge", "plum", "salt", "dusk", "moth"]
const TINTS := ["2b3a4a", "3a6fb0", "8a3f6e", "e9ecea", "d68ab0", "a39cb3"]
const RESERVED := [Color("8bf0d3"), Color("ff5a3c"), Color("e5a044"), Color("d9b44a")]
var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("CUA check -> FAIL: " + label)


func colour_ok(c: Color) -> bool:
	for banned in RESERVED:
		if Vector3(c.r-banned.r, c.g-banned.g, c.b-banned.b).length() < 0.20:
			return false
	return true


func nodes_of(node: Node, kind: String, out: Array) -> void:
	if node.is_class(kind):
		out.append(node)
	for child in node.get_children():
		nodes_of(child, kind, out)


func image_checked(path: String, size: Vector2i, max_alpha: float = 1.0) -> Image:
	var image := Image.new()
	var err := image.load_png_from_buffer(FileAccess.get_file_as_bytes(path))
	check(err == OK, path + " PNG load")
	if err != OK:
		return image
	check(image.get_size() == size, path + " dimensions")
	check(size.x <= 2048 and size.y <= 2048, path + " texture ceiling")
	var occupied := 0
	var pixels_ok := true
	var alpha_ok := true
	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x, y)
			if c.a > 0:
				occupied += 1
				pixels_ok = pixels_ok and colour_ok(c)
			alpha_ok = alpha_ok and c.a <= max_alpha + 0.00001
	check(occupied > 0, path + " nonempty visible pixels")
	check(pixels_ok, path + " no mint/hazard/amber/brass pixels")
	check(alpha_ok, path + " low alpha")
	return image


func _run() -> void:
	var doc = JSON.parse_string(FileAccess.get_file_as_string(BASE + "cua_manifest.json"))
	check(doc is Dictionary, "manifest exists and parses")
	if not doc is Dictionary:
		finish()
		return
	check(doc.get("trails", []).size() == TRAILS.size() and doc.get("decals", []).size() == DECALS.size() and doc.get("paints", []).size() == PAINTS.size(), "29 required items")
	for entry in doc.get("files", []):
		var path := BASE + String(entry.get("path", ""))
		check(FileAccess.file_exists(path), path + " exists")
		if FileAccess.file_exists(path):
			check(FileAccess.get_file_as_bytes(path).size() == int(entry.bytes), path + " byte size")
			check(FileAccess.get_sha256(path) == entry.sha256, path + " SHA256")
	var atlas := image_checked(BASE + "textures/trail_atlas.png", Vector2i(512, 512), 36.0 / 255.0)
	image_checked(BASE + "textures/decal_atlas.png", Vector2i(1024, 1024))
	var greatest_alpha := 0.0
	for y in atlas.get_height():
		for x in atlas.get_width():
			greatest_alpha = maxf(greatest_alpha, atlas.get_pixel(x, y).a)
	# A straight maximum-density wake has at most two cards per point; bends and
	# stationary overlap require the consumer's zero-alpha threat-footprint rule.
	var retained := pow(1.0 - greatest_alpha, 2)
	check(greatest_alpha > 0.0 and retained >= 0.73, "densest straight wake retains >=73% threat contrast")
	print("CUA readability: max alpha %.6f; two-card contrast retained %.6f" % [greatest_alpha, retained])
	for row in TRAILS:
		trail_checked(row, atlas)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cua-break="):
			var rule := arg.trim_prefix("--cua-break=")
			if rule == "reserved-pixel":
				var altered := atlas.duplicate() as Image
				altered.set_pixel(50, 50, Color(0.545098, 0.941176, 0.827451, 0.14))
				var path := "user://cua-reserved-pixel.png"
				altered.save_png(path)
				print("CUA scratch rule: reserved-pixel")
				image_checked(path, Vector2i(512, 512), 36.0 / 255.0)
				continue
			var scratch := broken_scratch_scene(rule)
			check(scratch != null, "negative scratch GLB loads")
			if scratch != null:
				trail_checked(TRAILS[0], atlas, scratch)
	for i in DECALS.size():
		var id := "decal_" + String(DECALS[i])
		var texture = load(BASE + "decals/" + id + ".tres")
		check(texture is AtlasTexture, id + " AtlasTexture loads")
		if texture is AtlasTexture:
			check(texture.resource_name == "DecalMask", id + " named DecalMask")
			check(texture.region == Rect2(i % 4 * 256, i / 4 * 256, 256, 256), id + " atlas region")
		var mask := image_checked(BASE + "decals/" + id + "_mask.png", Vector2i(256, 256))
		if not mask.is_empty():
			var low := Vector2i(256, 256)
			var high := Vector2i(-1, -1)
			for y in 256:
				for x in 256:
					if mask.get_pixel(x, y).a > 0.5:
						low = low.min(Vector2i(x, y))
						high = high.max(Vector2i(x, y))
			var entry: Dictionary = doc.decals[i]
			var extent := high - low + Vector2i.ONE
			var stored: Array = entry.mask_bounds_px
			check(Vector4i(int(stored[0]), int(stored[1]), int(stored[2]), int(stored[3])) == Vector4i(low.x, low.y, extent.x, extent.y), id + " measured visible mask bounds")
			var physical := Vector2(extent) * Vector2(entry.tile_size_m[0], entry.tile_size_m[1]) / 256.0
			check(physical.is_equal_approx(DECAL_SIZES[i]), id + " specified visible mark metres")
			if id == "decal_paw":
				check(mask_components(mask, true) == 5, id + " pad and four separate toes")
			if id == "decal_snail_shell":
				check(mask_components(mask, true) == 1, id + " continuous spiral")
			if id == "decal_thimble":
				check(mask_components(mask, false) == 4, id + " exactly three dimple voids plus exterior")
			var edge_clear := true
			for k in 256:
				edge_clear = edge_clear and mask.get_pixel(k, 0).a == 0 and mask.get_pixel(k, 255).a == 0
				edge_clear = edge_clear and mask.get_pixel(0, k).a == 0 and mask.get_pixel(255, k).a == 0
			check(edge_clear, id + " transparent mask gutter")
	for i in PAINTS.size():
		var id := "companion_paint_" + String(PAINTS[i])
		var mat = load(BASE + "paints/" + id + ".tres")
		check(mat is StandardMaterial3D, id + " material loads")
		if mat is StandardMaterial3D:
			check(mat.resource_name == "paint", id + " enamel slot only")
			check(mat.albedo_color.is_equal_approx(Color(TINTS[i])), id + " approved tint")
			check(colour_ok(mat.albedo_color), id + " colour exclusion")
			check(not mat.emission_enabled and is_equal_approx(mat.roughness, 0.8), id + " matte nonemissive")
			check(mat.vertex_color_use_as_albedo, id + " existing vertex wear retained")
	var caps: Dictionary = doc.get("trail_contract", {})
	check(caps.get("max_cards") == 24 and caps.get("max_wake_m") == 1.8, "card/distance caps")
	check(caps.get("inherit_shell_spin") == false and caps.get("max_lifetime_s") == 0.45, "grounded nonrolling lifetime contract")
	check(doc.get("paint_contract", {}).get("extra_clips") == 0, "paints add no clips")
	print("CUA budgets: one card 2 T / 4 V / 1 surface; 24 selected 48 T / 96 V / 1 batched draw; decals/paints +0 geometry")
	finish()


func trail_checked(row: Array, atlas: Image, scratch: Node = null) -> void:
	var id: String = row[0]
	var path := BASE + "trails/" + id + ".glb"
	var scene: Node = scratch
	if scene == null:
		var packed = load(path)
		check(packed is PackedScene, id + " GLB import")
		if not packed is PackedScene:
			return
		scene = packed.instantiate()
	root.add_child(scene)
	check(scene.name == "BallTrail" or scene.find_child("BallTrail", true, false) != null, id + " REQUIRED NODE BallTrail")
	var particle := scene.find_child(row[1], true, false) as MeshInstance3D
	check(particle != null, id + " REQUIRED NODE " + String(row[1]))
	var players := []
	nodes_of(scene, "AnimationPlayer", players)
	var animator: AnimationPlayer = players[0] if players.size() == 1 else null
	check(animator != null, id + " animation player")
	check(animator != null and animator.has_animation(row[2]), id + " REQUIRED CLIP " + String(row[2]))
	if animator != null:
		if animator.has_animation(row[2]):
			var clip := animator.get_animation(row[2])
			check(absf(clip.length - float(row[3])) < 0.009, id + " specified duration")
			check(clip.get_track_count() >= 1, id + " nonempty animated clip")
			animator.play(row[2])
	var mesh_nodes := []
	nodes_of(scene, "MeshInstance3D", mesh_nodes)
	check(mesh_nodes.size() == 1, id + " one quad mesh")
	if particle != null and particle.mesh != null:
		var mesh := particle.mesh
		check(mesh.get_surface_count() == 1, id + " one submitted surface")
		var arrays := mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		check(verts.size() == 4 and indices.size() == 6, id + " 2 T / 4 V actual imported geometry")
		check(indices.size() / 3 * 24 <= 48 and verts.size() * 24 <= 96, id + " strict selected trail budget")
		var selected := MultiMesh.new()
		selected.transform_format = MultiMesh.TRANSFORM_3D
		selected.mesh = mesh
		selected.instance_count = 24
		for card in 24:
			selected.set_instance_transform(card, Transform3D(Basis.IDENTITY, Vector3(0, 0.04, card * 1.63 / 23.0)))
		var batch := MultiMeshInstance3D.new()
		batch.multimesh = selected
		scene.add_child(batch)
		check(selected.instance_count == 24 and selected.mesh.get_surface_count() == 1, id + " 24 selected cards in one MultiMesh surface")
		var bounds := mesh.get_aabb()
		var size: Vector2 = row[4]
		check(absf(bounds.size.x - size.x) < 0.0001 and absf(bounds.size.z - size.y) < 0.0001, id + " specified card size")
		var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		check(colours.size() == 4, id + " tint vertices present")
		for c in colours:
			check(colour_ok(c.linear_to_srgb()), id + " vertex tint excludes reserved colours")
			var expected: Color = Color(row[5]).srgb_to_linear()
			check(Vector3(c.r-expected.r, c.g-expected.g, c.b-expected.b).length() < 0.006, id + " approved vertex tint")
		var mat := mesh.surface_get_material(0) as StandardMaterial3D
		check(mat != null, id + " imported material")
		if mat != null:
			check(mat.resource_name == "fx_neutral" and not mat.emission_enabled, id + " neutral nonemissive material slot")
			check(mat.transparency in [BaseMaterial3D.TRANSPARENCY_ALPHA, BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS], id + " alpha blend, mode " + str(mat.transparency))
			check(not mat.no_depth_test, id + " depth tested")
			check(mat.albedo_texture != null, id + " atlas bound")
		if animator != null and animator.has_animation(row[2]):
			for sample in 21:
				animator.seek(float(row[3]) * sample / 20.0, true)
				var b := particle.global_transform * bounds
				check(b.size.x <= 0.45 and b.size.z <= 0.45 and b.size.y <= 0.25, id + " clip-extreme size limits")
			animator.seek(float(row[3]), true)
			check(particle.scale.x <= 0.002 and particle.scale.z <= 0.002, id + " clip ends invisible")
		check(not atlas.is_empty(), id + " source atlas checked")
	scene.free()


func mask_components(image: Image, solid: bool) -> int:
	var visited := PackedByteArray()
	visited.resize(256 * 256)
	var count := 0
	for y in 256:
		for x in 256:
			var idx := y * 256 + x
			if visited[idx] != 0 or (image.get_pixel(x, y).a > 0.5) != solid:
				continue
			count += 1
			var queue: Array[Vector2i] = [Vector2i(x, y)]
			visited[idx] = 1
			var cursor := 0
			while cursor < queue.size():
				var at := queue[cursor]
				cursor += 1
				for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var next: Vector2i = at + direction
					if next.x < 0 or next.y < 0 or next.x >= 256 or next.y >= 256:
						continue
					var slot := next.y * 256 + next.x
					if visited[slot] == 0 and (image.get_pixel(next.x, next.y).a > 0.5) == solid:
						visited[slot] = 1
						queue.append(next)
	return count


func broken_scratch_scene(rule: String) -> Node:
	check(rule in ["missing-node", "missing-clip"], "known scratch mutation")
	var bytes := FileAccess.get_file_as_bytes(BASE + "trails/trail_salt_skip.glb")
	var length := bytes.decode_u32(12)
	var gltf: Dictionary = JSON.parse_string(bytes.slice(20, 20 + length).get_string_from_utf8())
	if rule == "missing-node":
		for node in gltf.nodes:
			if node.get("name") == "ChalkPuff":
				node.name = "RemovedChalkPuff"
	elif rule == "missing-clip":
		gltf.animations = []
	var body := JSON.stringify(gltf).to_utf8_buffer()
	while body.size() % 4 != 0:
		body.append(32)
	var tail := bytes.slice(20 + length)
	var changed := bytes.slice(0, 12)
	changed.encode_u32(8, 20 + body.size() + tail.size())
	var header := PackedByteArray()
	header.resize(8)
	header.encode_u32(0, body.size())
	header.encode_u32(4, 0x4e4f534a)
	changed.append_array(header)
	changed.append_array(body)
	changed.append_array(tail)
	var temp := "user://cua-negative/"
	DirAccess.make_dir_recursive_absolute(temp + "trails")
	DirAccess.make_dir_recursive_absolute(temp + "textures")
	var atlas := FileAccess.open(temp + "textures/trail_atlas.png", FileAccess.WRITE)
	atlas.store_buffer(FileAccess.get_file_as_bytes(BASE + "textures/trail_atlas.png"))
	atlas.close()
	var glb_path := temp + "trails/broken.glb"
	var glb := FileAccess.open(glb_path, FileAccess.WRITE)
	glb.store_buffer(changed)
	glb.close()
	var state := GLTFState.new()
	var document := GLTFDocument.new()
	var err := document.append_from_file(ProjectSettings.globalize_path(glb_path), state)
	check(err == OK, "mutated scratch GLB parses")
	if err != OK:
		return null
	print("CUA scratch rule: " + rule)
	return document.generate_scene(state)


func finish() -> void:
	print("CUA checks: %d; failures: %d" % [checks, failures])
	print("dress_cua_assets_test: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
