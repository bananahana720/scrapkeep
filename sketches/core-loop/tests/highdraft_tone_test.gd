extends SceneTree

const T := preload("res://tests/support/t.gd")
const Scenery := preload("res://src/presentation/highdraft_scenery.gd")
const Highdraft := preload("res://src/world/map_highdraft.gd")
const MindDress := preload("res://src/presentation/arena_mind_dress.gd")
const Palette := preload("res://src/core/palette.gd")
const Preset := preload("res://src/presentation/graphics_preset.gd")
const WorldLook := preload("res://src/presentation/world_look.gd")
var t := T.new("highdraft_tone_test")

class ProbeTerrain extends "res://src/world/terrain.gd":
	func _init() -> void:
		super({"DEFS": []})
		maps.append(Highdraft.new())
		_worlds.append(1)
		_roots.append(null)
		_heights.append(PackedFloat32Array())

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var terrain := ProbeTerrain.new()
	terrain.build(scene)
	var stage: Node3D = terrain.geometry_root(1)
	var scenery := Scenery.build(stage, terrain.map(), null, terrain.ground_callable(1))
	var tile: MultiMeshInstance3D = scenery.get_node("NetDeck").find_children("Tiles_*", "MultiMeshInstance3D", true, false)[0]
	var net := tile.material_override as ShaderMaterial
	t.check("net cord uses the bone weave and fades below a pixel", net != null and net.get_shader_parameter("cord_tint") == Palette.SAND and net.get_shader_parameter("fade_end") == 0.5)
	var ground: MeshInstance3D = scenery.get_node("IslandRelief")
	var ground_mat := ground.material_override as ShaderMaterial
	t.check("catch floor has coarse filtered weave instead of a tan slab", ground_mat != null and ground_mat.get_shader_parameter("net_pitch") == 4.0)
	var stable := true
	for preset in ["low", "target", "high"]:
		Preset.apply(preset)
		stable = stable and ground.material_override == ground_mat
	t.check("preset changes retain the filtered catch floor", stable and ground_mat != null and ground_mat.get_shader_parameter("net_pitch") == 4.0)
	var skin: MeshInstance3D = scenery.find_children("IslandSkin_*", "MeshInstance3D", false, false)[0]
	var arrays := skin.mesh.surface_get_arrays(0)
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
	t.check("fitted island rim retains every authored stone colour", colors.size() == (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() and colors.size() > 100)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var top := skin.mesh.get_aabb().end.y
	var top_count := 0
	var upward := true
	for i in range(0, indices.size(), 3):
		var a := indices[i]
		var b := indices[i + 1]
		var c := indices[i + 2]
		var face := (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a])
		if minf(vertices[a].y, minf(vertices[b].y, vertices[c].y)) > top - 0.005 and face.length_squared() > 0.01:
			top_count += 1
			upward = upward and (normals[a].y + normals[b].y + normals[c].y) / 3.0 > 0.5
	t.check("fitted stone top normals face the sky", upward and top_count > 10, "%d nondegenerate top faces" % top_count)
	var bridge: MultiMeshInstance3D = scenery.get_node("BridgeSkins")
	var steel := bridge.multimesh.mesh.surface_get_material(0) as BaseMaterial3D
	t.check("textured traversal skins multiply the sheet vertex tint", steel != null and steel.vertex_color_use_as_albedo)
	var mesa: MultiMeshInstance3D = scenery.get_node("Sky/DistantMesas")
	t.check("distant mesas darken at the foot and blend toward cool sky with height", _aerial_gradient(mesa.multimesh.mesh))
	var dress := MindDress.new()
	var kit := dress._load_kit()
	t.check("crown background shares aerial perspective", _aerial_gradient(kit["Mesa"]))
	var crate := Scenery._mesh("prop_crate.glb", "Surface")
	var prop := crate.surface_get_material(0) as BaseMaterial3D
	t.check("petrol props keep the M2 paint under bright fill", prop != null and prop.vertex_color_use_as_albedo and prop.albedo_color == Color("53686d").lerp(Color.WHITE, 0.3) and is_equal_approx(prop.roughness, 0.9))
	dress.free()
	scene.free()
	quit(t.verdict())

func _aerial_gradient(mesh: Mesh) -> bool:
	var scene := (load("res://assets/models/highdraft/sky_mesa.glb") as PackedScene).instantiate()
	var source: Mesh = (scene.find_child("MesaHull", true, false) as MeshInstance3D).mesh
	var arrays := mesh.surface_get_arrays(0)
	var original := source.surface_get_arrays(0)
	var vertices: PackedVector3Array = original[Mesh.ARRAY_VERTEX]
	var before: PackedColorArray = original[Mesh.ARRAY_COLOR]
	var after: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var bounds := source.get_aabb()
	var ok := after.size() == before.size() and after.size() > 0
	var greatest_error := 0.0
	for i in mini(before.size(), after.size()):
		var height := clampf((vertices[i].y - bounds.position.y) / maxf(bounds.size.y, 0.01), 0.0, 1.0)
		var sky := (WorldLook.ROWS[3]["haze"] as Color).lerp(WorldLook.ROWS[3]["fill_color"], height).srgb_to_linear()
		var value := lerpf(0.5, 1.05, height)
		var expected := before[i].lerp(sky, lerpf(0.55, 0.4, height)) * Color(value, value, value)
		var error := Vector3(after[i].r - expected.r, after[i].g - expected.g, after[i].b - expected.b).abs()
		greatest_error = maxf(greatest_error, maxf(error.x, maxf(error.y, error.z)))
		ok = ok and maxf(error.x, maxf(error.y, error.z)) <= 1.0 / 255.0 + 0.00001
	var material := mesh.surface_get_material(0) as BaseMaterial3D
	ok = ok and material != null and material.vertex_color_use_as_albedo and not material.emission_enabled
	scene.free()
	print("aerial colours: vertices=%d maximum quantization error=%.5f" % [after.size(), greatest_error])
	return ok
