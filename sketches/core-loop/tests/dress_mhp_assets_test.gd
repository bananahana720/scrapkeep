extends SceneTree

# BUILD-SPEC.md Props: whole-file caps, including every mesh and pose.
# Override only for a disposable broken-rule copy, never for shipping assets.
const DIRECTORY := "res://assets/models/highdraft/"
# 2026-10-18 polish (tools/blender/POLISH.md): was 270 / 610; prop class cap is 2000 / 4600.
const MAX_TRIANGLES := 1100
const MAX_VERTICES := 900
const MAX_SURFACES := 1
const PARTS := {
	"spool": ["Flange", "Barrel", "Feet"],
	"bearing": ["Foot", "SplitHousing", "InnerRing"],
	"fan": ["Bell", "Guards", "Blades", "Bracket"],
	"crate": ["Box", "Straps"],
	"pot": ["Tank", "Feet", "Hose"],
	"clamp": ["Stem", "Sockets"],
	"ballast": ["BeddedWedge"],
	"lamp_body": ["Cage", "Bracket"],
	"lamp_glass": ["Lens"],
	"sail": ["Mast", "Triangle", "BraceRods"],
	"bench": ["Top", "Feet", "Brace"],
}
const SOCKETS := {
	"spool": {"axle": Vector3(0, 1.4, 0), "line_out": Vector3(0, 1.4, -1.1)},
	"bearing": {"load_axis": Vector3(0, 0.9, 0)},
	"fan": {"hang": Vector3.ZERO, "rotor": Vector3(0, -1.8, 0)},
	"crate": {"carry_l": Vector3(-1, 0.8, 0), "carry_r": Vector3(1, 0.8, 0)},
	"pot": {"hose_out": Vector3(0.7, 1.6, 0)},
	"clamp": {"line_l": Vector3(-0.55, 1.3, 0), "line_r": Vector3(0.55, 1.3, 0)},
	"ballast": {"strap_a": Vector3(-0.6, 0.6, 0), "strap_b": Vector3(0.6, 0.6, 0)},
	"lamp_body": {"wall_mount": Vector3(0, 0.3, 0.3)},
	"lamp_glass": {"wall_mount": Vector3(0, 0.3, 0.3)},
	"sail": {"hinge": Vector3(0, 1.5, 0)},
	"bench": {"tool_rest": Vector3(0, 1.325, 0)},
}
const CLIPS := {"fan": {"spin_loop": 4.0}, "sail": {"fold": 0.5, "wind_loop": 3.0}}
var failures := 0
var checked := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
	print("%s %s -> %s" % ["PASS" if ok else "FAIL", label, "PASS" if ok else "FAIL"])


func _run() -> void:
	var directory := OS.get_environment("SCRAPKEEP_MHP_ASSET_DIR")
	if directory.is_empty():
		directory = ProjectSettings.globalize_path(DIRECTORY)
	for key: String in PARTS:
		_inspect(key, directory.path_join("prop_%s.glb" % key))
	_check(checked == 11, "all eleven required GLBs loaded, got %d" % checked)
	print("dress_mhp_assets_test: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _inspect(key: String, path: String) -> void:
	_check(FileAccess.file_exists(path), "%s required GLB exists" % key)
	if not FileAccess.file_exists(path):
		return
	var state := GLTFState.new()
	var document := GLTFDocument.new()
	var error := document.append_from_file(path, state)
	_check(error == OK, "%s GLB parses" % key)
	if error != OK:
		return
	var scene := document.generate_scene(state) as Node3D
	_check(scene != null, "%s generates a Godot scene" % key)
	if scene == null:
		return
	checked += 1
	root.add_child(scene)
	var json: Dictionary = state.json
	var raw_triangles := 0
	var raw_vertices := 0
	var raw_surfaces := 0
	var accessors: Array = json.get("accessors", [])
	for mesh: Dictionary in json.get("meshes", []):
		for primitive: Dictionary in mesh.get("primitives", []):
			_check(int(primitive.get("mode", 4)) == 4, "%s triangle primitive" % key)
			var positions := int(primitive.get("attributes", {}).get("POSITION", -1))
			_check(positions >= 0, "%s POSITION accessor exists" % key)
			if positions >= 0:
				raw_vertices += int(accessors[positions].get("count", 0))
			var indices := int(primitive.get("indices", -1))
			raw_triangles += int(accessors[indices].get("count", 0)) / 3 if indices >= 0 else int(accessors[positions].get("count", 0)) / 3
			raw_surfaces += 1
	var triangles := 0
	var vertices := 0
	var surfaces := 0
	var box := AABB()
	var first := true
	var meshes := scene.find_children("*", "MeshInstance3D", true, false)
	_check(meshes.size() == 1, "%s merged single mesh" % key)
	for mesh: MeshInstance3D in meshes:
		for surface in mesh.mesh.get_surface_count():
			surfaces += 1
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var pos: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			vertices += pos.size()
			triangles += idx.size() / 3 if not idx.is_empty() else pos.size() / 3
			var material := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			var slot := "glass" if key == "lamp_glass" else "paint"
			_check(material != null and material.resource_name == slot and not material.emission_enabled,
				"%s existing %s family, no emission" % [key, slot])
			if material != null:
				var roughness := 0.35 if key == "lamp_glass" else (0.95 if key == "ballast" else 0.8)
				_check(absf(material.roughness - roughness) < 0.005,
					"%s family roughness" % key)
				_check(material.albedo_texture == null, "%s no new surface atlas" % key)
				if key != "lamp_glass":
					_check(arrays[Mesh.ARRAY_COLOR] != null and arrays[Mesh.ARRAY_COLOR].size() == pos.size(),
						"%s one surface retains vertex tints" % key)
			for v in pos:
				var world: Vector3 = mesh.global_transform * v
				box = AABB(world, Vector3.ZERO) if first else box.expand(world)
				first = false
	_check(raw_triangles > 0 and raw_triangles <= MAX_TRIANGLES and triangles == raw_triangles,
		"%s triangles %d raw / %d imported <= %d" % [key, raw_triangles, triangles, MAX_TRIANGLES])
	_check(raw_vertices > 0 and raw_vertices <= MAX_VERTICES and vertices <= MAX_VERTICES,
		"%s vertices %d raw / %d imported <= %d" % [key, raw_vertices, vertices, MAX_VERTICES])
	_check(raw_surfaces == MAX_SURFACES and surfaces == MAX_SURFACES and json.get("materials", []).size() == 1,
		"%s surfaces %d raw / %d imported, one material" % [key, raw_surfaces, surfaces])
	print("MHP_BUDGET %s T=%d V=%d surfaces=%d materials=%d bytes=%d bounds=%s" %
		[key, raw_triangles, raw_vertices, raw_surfaces, json.get("materials", []).size(), FileAccess.get_file_as_bytes(path).size(), box])
	var names := {}
	for node: Dictionary in json.get("nodes", []):
		var name: String = node.get("name", "")
		_check(not names.has(name), "%s unique node %s" % [key, name])
		names[name] = node
	for part: String in PARTS[key]:
		_check(names.has(part) and scene.find_child(part, true, false) != null, "%s named part %s retained" % [key, part])
	for socket: String in SOCKETS[key]:
		var node := scene.find_child(socket, true, false) as Node3D
		var wanted: Vector3 = SOCKETS[key][socket]
		_check(node != null and node.global_position.distance_to(wanted) < 0.001,
			"%s socket %s at %s" % [key, socket, wanted])
	var asset_root := scene.find_child("prop_" + key, true, false) as Node3D
	if asset_root == null and str(scene.name) == "prop_" + key:
		asset_root = scene
	_check(asset_root != null and asset_root.transform.is_equal_approx(Transform3D.IDENTITY), "%s identity origin and pivot" % key)
	_check(scene.find_children("*", "CollisionObject3D", true, false).is_empty(), "%s no authored collision" % key)
	if key == "fan":
		_check(absf(box.end.y) < 0.001 and box.position.y < -3.2, "fan top suspension origin")
	elif key not in ["lamp_glass", "sail"]:
		_check(absf(box.position.y) < 0.001, "%s bottom at Y=0" % key)
	if key == "clamp":
		_check(box.size.x <= 1.601 and box.size.y <= 1.501 and box.size.z <= 0.601,
			"clamp inside 1.6 x 1.5 x 0.6 m envelope")
	if CLIPS.has(key):
		var player := scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
		_check(player != null and json.get("skins", []).size() == 1, "%s one rigid skin with animation player" % key)
		if player != null:
			for clip: String in CLIPS[key]:
				_check(player.has_animation(clip), "%s clip %s exists" % [key, clip])
				if player.has_animation(clip):
					var animation := player.get_animation(clip)
					_check(absf(animation.length - float(CLIPS[key][clip])) < 0.002,
						"%s %s length %.3f seconds" % [key, clip, animation.length])
		for animation: Dictionary in json.get("animations", []):
			for channel: Dictionary in animation.get("channels", []):
				var target: Dictionary = channel.get("target", {})
				var node: Dictionary = json.nodes[int(target.get("node", 0))]
				_check(node.get("name", "") in ["Motion", "Static"], "%s no root motion" % key)
	else:
		_check(json.get("animations", []).is_empty() and json.get("skins", []).is_empty(), "%s static rest pose" % key)
	scene.free()
