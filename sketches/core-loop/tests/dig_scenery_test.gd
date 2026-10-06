extends SceneTree

# Rule (src/presentation/dig_scenery.gd, unit WDG): the Dig builds its real scenery from the
# dig_stone and dig_mechanical GLBs: cut faces, rubble, struts, the zone's landmark and lamp
# lines as batches whose meshes ARE the GLB meshes, each breach cover wearing the drum skin
# from the manifest while its collider, meta and break stay as they were, and the stone beds as
# the ground material that survives a preset change. Every instance stands outside the play rect
# plus 8 m. With the GLB directories broken the game builds the fallback (the box covers, the
# default ground) and still loads. Evidence limit: headless build and scene-tree reads; no
# render, camera or feel claim.

const DigTable := preload("res://tests/doubles/dig_table_defs.gd")
const Scenery := preload("res://src/presentation/dig_scenery.gd")
const DigMap := preload("res://src/world/map_dig.gd")
const DeepMap := preload("res://src/world/map_dig_deep.gd")
const Preset := preload("res://src/presentation/graphics_preset.gd")
const Game := preload("res://src/game.gd")
const T := preload("res://tests/support/t.gd")

const STONE := "res://assets/models/dig_stone/"
const MECH := "res://assets/models/dig_mechanical/"


class DigGame extends "res://src/game.gd":
	func _chosen_table():
		return DigTable


# Terrain takes only registered maps (terrain.gd _init), so these fill their own row.
class OneMapTerrain extends "res://src/world/terrain.gd":
	func _init(map_script: Script) -> void:
		super({"DEFS": []})
		maps.append(map_script.new())
		_worlds.append(1)
		_roots.append(null)
		_heights.append(PackedFloat32Array())


var t := T.new("dig_scenery_test")


func _initialize() -> void:
	_run.call_deferred()


func _signatures(path: String) -> Array:
	var out := []
	var packed := load(path) as PackedScene
	if packed == null:
		return out
	var scene := packed.instantiate()
	for view: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		var arrays := view.mesh.surface_get_arrays(0)
		out.append([hash(arrays[Mesh.ARRAY_VERTEX]), hash(arrays[Mesh.ARRAY_INDEX])])
	scene.free()
	return out


func _signature(mesh: Mesh) -> Array:
	var arrays := mesh.surface_get_arrays(0)
	return [hash(arrays[Mesh.ARRAY_VERTEX]), hash(arrays[Mesh.ARRAY_INDEX])]


# True when some batch under the node draws a mesh of this GLB.
func _batched(scenery: Node, path: String) -> bool:
	var sigs := _signatures(path)
	if sigs.is_empty():
		return false
	for view: MultiMeshInstance3D in scenery.find_children("*", "MultiMeshInstance3D", true, false):
		if sigs.has(_signature(view.multimesh.mesh)):
			return true
	return false


func _outside_apron(scenery: Node, rect: Rect2) -> bool:
	var keep := rect.grow(Scenery.APRON)
	var any := false
	for view: MultiMeshInstance3D in scenery.find_children("*", "MultiMeshInstance3D", true, false):
		for o: Vector3 in view.get_meta("origins"):
			any = true
			if keep.has_point(Vector2(o.x, o.z)):
				return false
	return any


func _cover_skinned(cover: Node, wedge_file: String) -> bool:
	var skin := cover.find_child("BreachSkin", false, false)
	if skin == null or skin.get_child_count() != 15:
		return false
	var sigs := _signatures(MECH + wedge_file)
	for view in skin.get_children():
		if sigs.has(_signature((view as MeshInstance3D).mesh)):
			return true
	return false


func _run() -> void:
	# (1) The live game, one-stage Dig: scenery hooked, real meshes, covers skinned.
	var game := DigGame.new()
	game.test_mode = true
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	game.flow.press_start()
	game.flow.choose_class(0)
	var waited := 0
	while not game.flow.in_stage() and waited < 120:
		waited += 1
		await physics_frame
	var stage_root: Node3D = game.ctx.terrain.geometry_root(1)
	var scenery := stage_root.get_node_or_null("DigScenery")
	t.check("(1) game hooks DigScenery on the Dig stage", scenery != null, str(scenery))
	if scenery != null:
		t.check("(1) cut face is the GLB mesh", _batched(scenery, STONE + "cut_face_long.glb"), "cut_face_long")
		t.check("(1) rubble is the GLB mesh", _batched(scenery, STONE + "rubble_cluster.glb"), "rubble_cluster")
		t.check("(1) strut is the GLB mesh", _batched(scenery, MECH + "strut_tall.glb") or _batched(scenery, MECH + "strut_bent.glb"), "strut")
		t.check("(1) zone A impeller vane is the GLB mesh", _batched(scenery, MECH + "impeller_vane.glb"), "impeller_vane")
		t.check("(1) lamp rail is the GLB mesh", _batched(scenery, MECH + "lamp_straight_module.glb"), "lamp_straight_module")
		t.check("(1) no intake in zone A", not _batched(scenery, MECH + "intake_petal.glb"), "intake_petal")
		t.check("(1) every instance outside the play rect plus 8 m", _outside_apron(scenery, game.ctx.terrain.map().play_rect), "apron")
		t.check("(1) lamp lines carry lights", scenery.find_children("LampLight*", "OmniLight3D", true, false).size() > 0, "lights")
		var colliders := scenery.find_children("*", "CollisionObject3D", true, false)
		t.check("(1) scenery adds no collider", colliders.is_empty(), str(colliders.size()))
	var m = game.ctx.terrain.map()
	var plate: Dictionary = m.breach_plates[0]
	var cover := stage_root.find_child("BreachPlate_%s" % plate["id"], true, false) as StaticBody3D
	var other := stage_root.find_child("BreachPlate_plate_rim", true, false) as StaticBody3D
	t.check("(2) 12x12 cover wears the 12x12 drum", cover != null and _cover_skinned(cover, "breach_wedge_a_12x12.glb"), "plate_east")
	t.check("(2) 14x10 cover wears the 14x10 drum", other != null and _cover_skinned(other, "breach_wedge_a_14x10.glb"), "plate_rim")
	var boxes_hidden := true
	var collider_kept := false
	for child in cover.get_children():
		if child is MeshInstance3D and child.mesh is BoxMesh:
			boxes_hidden = boxes_hidden and not child.visible
		if child is CollisionShape3D and child.shape is BoxShape3D:
			collider_kept = true
	t.check("(2) cover box mesh hidden, collider kept", boxes_hidden and collider_kept, "hidden %s collider %s" % [boxes_hidden, collider_kept])
	var skin := cover.find_child("BreachSkin", false, false)
	var mint := 0
	if skin != null:
		for view in skin.get_children():
			if String(view.name).begins_with("tab_"):
				mint += 1 if view.get_instance_shader_parameter("state_tint") == Scenery.MINT else 0
	t.eq("(2) four mint tabs, no other state", mint, 4)
	# (3) The break stays the game's: height drops, the cover parks and its skin leaves with it.
	var c: Vector2 = (plate["rect"] as Rect2).get_center()
	var home: Vector3 = cover.get_meta("home")
	var skin_shown: bool = skin != null and skin.is_visible_in_tree()
	t.check("(3) cover at home before the break", cover.position == home and skin_shown, str(cover.position))
	game.world._on_slammed(Vector3(c.x, 13.0, c.y), 20.0, 1.0)
	t.check("(3) floor drops to drop_to", is_equal_approx(game.ctx.terrain.height(c.x, c.y), plate["drop_to"]), str(game.ctx.terrain.height(c.x, c.y)))
	t.check("(3) cover parked, skin gone with it", cover.position.y < -300.0 and skin != null and not skin.is_visible_in_tree(), str(cover.position))
	# (4) The ground material is the stone beds and survives a preset change.
	var ground_view: MeshInstance3D = stage_root.get_node("Ground").find_children("*", "MeshInstance3D", true, false)[0]
	var stone := load("res://assets/materials/dig_stone/stone.tres")
	t.check("(4) ground wears the stone material", ground_view.material_override == stone, str(ground_view.material_override))
	var before: String = Preset.current
	Preset.apply("low" if before != "low" else "high")
	t.check("(4) stone survives a preset change", ground_view.material_override == stone, str(ground_view.material_override))
	Preset.apply("target")
	t.check("(4) the target preset keeps its own ground", ground_view.material_override != stone and ground_view.material_override.resource_name == "target_ground", str(ground_view.material_override))
	Preset.apply(before)
	t.check("(4) beds return after the target preset", ground_view.material_override == stone, str(ground_view.material_override))
	game.free()

	# (5) Zone B on its own terrain: the intake, sparse machines, its two plates skinned.
	var world := Node3D.new()
	root.add_child(world)
	var deep := OneMapTerrain.new(DeepMap)
	deep.build(world)
	deep.use(1)
	var deep_root: Node3D = deep.geometry_root(1)
	var deep_scenery := Scenery.build(deep_root, deep.map(), "dig_deep")
	t.check("(5) zone B intake petal is the GLB mesh", _batched(deep_scenery, MECH + "intake_petal.glb"), "intake_petal")
	t.check("(5) zone B scooped cut face is the GLB mesh", _batched(deep_scenery, STONE + "cut_face_scoop.glb"), "cut_face_scoop")
	t.check("(5) no impeller in zone B", not _batched(deep_scenery, MECH + "impeller_vane.glb"), "impeller_vane")
	t.check("(5) every instance outside the play rect plus 8 m", _outside_apron(deep_scenery, deep.map().play_rect), "apron")
	var skinned := 0
	for p in deep.map().breach_plates:
		var body := deep_root.find_child("BreachPlate_%s" % p["id"], true, false)
		skinned += 1 if body != null and body.find_child("BreachSkin", false, false) != null else 0
	t.eq("(5) all five zone B covers skinned", skinned, 5)

	# (6) The fallback: with the GLB directories broken the box covers and default ground stay.
	var keep_stone := Scenery.stone_dir
	var keep_mech := Scenery.mech_dir
	Scenery.stone_dir = "res://assets/models/no_such_stone/"
	Scenery.mech_dir = "res://assets/models/no_such_mech/"
	var bare := Node3D.new()
	root.add_child(bare)
	var terrain := OneMapTerrain.new(DigMap)
	terrain.build(bare)
	terrain.use(1)
	var bare_root: Node3D = terrain.geometry_root(1)
	var bare_scenery := Scenery.build(bare_root, terrain.map(), "dig")
	Scenery.stone_dir = keep_stone
	Scenery.mech_dir = keep_mech
	t.check("(6) no batches without the GLBs", bare_scenery.find_children("*", "MultiMeshInstance3D", true, false).is_empty(), "batches")
	var fallback := true
	var bare_cover := bare_root.find_child("BreachPlate_plate_east", true, false)
	for child in bare_cover.get_children():
		if child is MeshInstance3D and child.mesh is BoxMesh:
			fallback = fallback and child.visible
	t.check("(6) cover keeps its visible box", fallback and bare_cover.find_child("BreachSkin", false, false) == null, "box")
	t.check("(6) no daylight shaft on a bare cover", bare_cover.find_child("DaylightShaft", false, false) == null, "shaft")
	quit(t.verdict())
