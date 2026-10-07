extends SceneTree

const T := preload("res://tests/support/t.gd")
const Contraptions := preload("res://src/world/contraptions.gd")
const Scenery := preload("res://src/presentation/highdraft_scenery.gd")
const Highdraft := preload("res://src/world/map_highdraft.gd")
const Crown := preload("res://src/world/map_highdraft_crown.gd")

# The Highdraft kit's GLBs keep their colour in vertex colours, and Godot imports their
# materials white with vertex colour off. GPU captures on 2026-10-07 showed every prop,
# anchor and sky piece flat white while the mesh-hash tests passed. This test reads the
# material each built surface actually draws with.

class ProbeTerrain extends "res://src/world/terrain.gd":
	func _init(map_script: GDScript) -> void:
		super({"DEFS": []})
		maps.append(map_script.new())
		_worlds.append(1)
		_roots.append(null)
		_heights.append(PackedFloat32Array())


var _t := T.new("highdraft_materials_test")


func _initialize() -> void:
	call_deferred("_run")


func _coloured(mesh: Mesh, surface: int) -> bool:
	# Greybox primitives have no vertex colours and are not kit pieces.
	if not (mesh is ArrayMesh):
		return false
	return ((mesh as ArrayMesh).surface_get_format(surface) & Mesh.ARRAY_FORMAT_COLOR) != 0


func _draws_colour(material: Material) -> bool:
	if material == null or not (material is BaseMaterial3D):
		return true
	var base := material as BaseMaterial3D
	return base.vertex_color_use_as_albedo or base.albedo_texture != null


func _zone(label: String, map_script: GDScript) -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var terrain := ProbeTerrain.new(map_script)
	terrain.build(scene)
	var stage_root: Node3D = terrain.geometry_root(1)
	var contraptions := Contraptions.new()
	stage_root.add_child(contraptions)
	contraptions.setup(terrain.map(), terrain.ground_callable(1), 14.0, 26.0)
	var scenery := Scenery.build(stage_root, terrain.map(), contraptions, terrain.ground_callable(1), null)
	var checked := 0
	var white: Array[String] = []
	for view: MeshInstance3D in stage_root.find_children("*", "MeshInstance3D", true, false):
		if view.mesh == null or not (scenery.is_ancestor_of(view) or String(view.name).begins_with("Highdraft")):
			continue
		for i in view.mesh.get_surface_count():
			if _coloured(view.mesh, i):
				checked += 1
				if not _draws_colour(view.get_active_material(i)):
					white.append(String(scenery.get_path_to(view)) if scenery.is_ancestor_of(view) else String(view.name))
	for multi: MultiMeshInstance3D in scenery.find_children("*", "MultiMeshInstance3D", true, false):
		var mesh := multi.multimesh.mesh if multi.multimesh != null else null
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			if _coloured(mesh, i):
				checked += 1
				var material := multi.material_override if multi.material_override != null else mesh.surface_get_material(i)
				if not _draws_colour(material):
					white.append(String(multi.name))
	_t.check("%s checks a real number of vertex-coloured surfaces" % label, checked >= 20, "checked %d" % checked)
	_t.check("%s draws no vertex-coloured surface with a white material" % label, white.is_empty(), "%d white: %s" % [white.size(), ", ".join(white.slice(0, 8))])
	scene.queue_free()


func _run() -> void:
	_zone("Highdraft", Highdraft)
	_zone("Crown", Crown)
	await process_frame
	quit(_t.verdict())
