extends SceneTree

const T := preload("res://tests/support/t.gd")
const Palette := preload("res://src/core/palette.gd")
const Terrain := preload("res://src/world/terrain.gd")
const Contraptions := preload("res://src/world/contraptions.gd")
const Scenery := preload("res://src/presentation/highdraft_scenery.gd")
const SetDressing := preload("res://src/presentation/set_dressing.gd")
const Augments := preload("res://src/movement/augments.gd")
const AugmentKit := preload("res://src/movement/augment_kit.gd")
const Highdraft := preload("res://src/world/map_highdraft.gd")
const Game := preload("res://src/game.gd")
const Crown := preload("res://src/world/map_highdraft_crown.gd")
const RecipeProps := preload("res://src/presentation/recipe_props.gd")

# The Highdraft's dress: the game builds the real kit models (islands, bridges, ramps, barges,
# vents, air, net, anchors, props, sky) on the greybox the map and contraptions already built,
# and keeps that greybox visible when a GLB is missing. Evidence limit: headless structure and
# fit checks; no render, no light, no feel claim.

const DIR := "res://assets/models/highdraft/"

class ProbeTerrain extends "res://src/world/terrain.gd":
	func _init(map_script: GDScript) -> void:
		super({"DEFS": []})
		maps.append(map_script.new())
		_worlds.append(1)
		_roots.append(null)
		_heights.append(PackedFloat32Array())


class FakeEvents extends RefCounted:
	signal stage_entered(stage: int, retry: bool)


class FakeCtx extends RefCounted:
	var events := FakeEvents.new()
	var terrain
	var root = null
	var player = null


var _t := T.new("highdraft_scenery_test")


func _initialize() -> void:
	call_deferred("_run")


func _signature(mesh: Mesh) -> int:
	return hash((mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array))


func _glb_signature(file: String, node_name: String) -> int:
	var scene := (load(DIR + file) as PackedScene).instantiate()
	var sig := 0
	for view: MeshInstance3D in scene.find_children(node_name, "MeshInstance3D", true, false):
		sig = _signature(view.mesh)
		break
	scene.free()
	return sig


func _fresh(map_script: GDScript) -> Dictionary:
	var scene := Node3D.new()
	root.add_child(scene)
	var terrain := ProbeTerrain.new(map_script)
	terrain.build(scene)
	var stage_root: Node3D = terrain.geometry_root(1)
	var contraptions := Contraptions.new()
	stage_root.add_child(contraptions)
	contraptions.setup(terrain.map(), terrain.ground_callable(1), 14.0, 26.0)
	return {"scene": scene, "terrain": terrain, "root": stage_root, "contraptions": contraptions}


func _count(node: Node, kind: String) -> int:
	var n := 0
	for child in node.find_children("*", kind, true, false):
		n += 1
	return n


func _zone(label: String, map_script: GDScript) -> void:
	var f := _fresh(map_script)
	var terrain = f["terrain"]
	var map = terrain.map()
	var stage_root: Node3D = f["root"]
	var contraptions = f["contraptions"]
	var posts_before := _visible_post_meshes(stage_root)
	var cyl_before := _visible_cylinders(contraptions)
	var scenery := Scenery.build(stage_root, map, contraptions, terrain.ground_callable(1), null)
	# Islands: five skins on the real stone, fitted to the collider.
	var skins := scenery.find_children("IslandSkin_*", "MeshInstance3D", false, false)
	_t.eq("%s five island skins" % label, skins.size(), 5)
	var fit_ok := true
	var top_ok := true
	for view: MeshInstance3D in skins:
		var verts: PackedVector3Array = view.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		fit_ok = fit_ok and verts.size() > 100
		for v in verts:
			if v.y > terrain.height(v.x, v.z) + 0.2:
				fit_ok = false
		var best := -INF
		for v in verts:
			best = maxf(best, v.y)
		var id := String(view.name).trim_prefix("IslandSkin_")
		top_ok = top_ok and absf(best - (float(map._islands()[id]["top"]) + Scenery.ISLAND_LIFT)) < 0.01
	_t.check("%s island skins hug the ground (none over 0.2 m above it) and top out at top+lift" % label, fit_ok and top_ok)
	# Bridges and ramps: the GLB's own bay mesh.
	var bridge := scenery.get_node("BridgeSkins") as MultiMeshInstance3D
	_t.eq("%s bridge skins carry bridge_skin.glb" % label, _signature(bridge.multimesh.mesh), _glb_signature("bridge_skin.glb", "HardwareSkin"))
	var ramp := scenery.get_node("ReturnRampSkins") as MultiMeshInstance3D
	_t.eq("%s ramp skins carry return_ramp_skin.glb" % label, _signature(ramp.multimesh.mesh), _glb_signature("return_ramp_skin.glb", "HardwareSkin"))
	_t.eq("%s two return ramps skinned" % label, ramp.multimesh.instance_count >= 2, true)
	# Barges: the recipe views ride the tilting deck node, the greybox hides.
	# 2026-10-09 swap-wave 12-F: re-pinned from barge_skin.glb's HardwareSkin to the barge recipe (base and shells,
	# contraptions.gd _build_barge); the deck carries no mesh of its own and the box collider stays child 0.
	var barge_ok: bool = contraptions.barges.size() == 2
	for barge in contraptions.barges:
		barge_ok = barge_ok and _deck_recipe(barge["deck"])
		barge_ok = barge_ok and (barge["deck"] as Node).get_node_or_null("HighdraftWeatherSail") != null
		for child in (barge["body"] as Node).get_children():
			if child is MeshInstance3D and child != barge["deck"]:
				barge_ok = barge_ok and not child.visible
		barge_ok = barge_ok and (barge["body"] as Node).get_child(0) is CollisionShape3D
	_t.check("%s barges wear the barge recipe on the deck node and hide the greybox" % label, barge_ok)
	# Thermals: vent and air scenes, greybox cylinders hidden.
	var thermal_ok: bool = contraptions.thermals.size() == 3
	for spec in map.contraptions:
		if spec["kind"] == "thermal":
			var vent := scenery.get_node_or_null("Vent_%s" % spec["id"])
			var air := scenery.get_node_or_null("Air_%s" % spec["id"])
			thermal_ok = thermal_ok and vent != null and String(vent.scene_file_path).ends_with("thermal_vent.glb")
			thermal_ok = thermal_ok and air != null and String(air.scene_file_path).ends_with("thermal_air.glb")
			thermal_ok = thermal_ok and absf(air.scale.y - float(spec["height"]) / 40.0) < 0.001
	var cylinders_visible := _visible_cylinders(contraptions)
	_t.check("%s thermals wear vent and air models, thermal greybox hidden" % label, thermal_ok and cylinders_visible == cyl_before - 6, "%d cylinders visible" % cylinders_visible)
	# Net deck: tiles carry net_tile.glb and none lie on an island, bridge or ramp.
	var tile_sig := _glb_signature("net_tile.glb", "Weave")
	var tiles := 0
	var tiles_ok := true
	for chunk in scenery.get_node("NetDeck").find_children("Tiles_*", "MultiMeshInstance3D", true, false):
		tiles_ok = tiles_ok and _signature(chunk.multimesh.mesh) == tile_sig
		for placed: Transform3D in chunk.get_meta("placements"):
			var at: Vector3 = placed.origin
			tiles += 1
			tiles_ok = tiles_ok and float(map.sample(at.x, at.z)[0]) <= Highdraft.NET_H + 0.05
	_t.check("%s net deck: %d net_tile.glb tiles, none on solid ground" % [label, tiles], tiles_ok and tiles > 500)
	# Anchors: mast and eye per post, four collars each; the old shaft and cap hide.
	var anchors := scenery.find_children("AnchorEye_*", "Node3D", false, false)
	var collar_ok: bool = anchors.size() == map._posts().size()
	for eye in anchors:
		collar_ok = collar_ok and eye.get_child_count() >= 4 and String(eye.scene_file_path).ends_with("anchor_eye.glb")
	_t.check("%s %d anchor eyes with four collars each" % [label, anchors.size()], collar_ok)
	_t.eq("%s the posts' drawn shaft and cap hide (was %d visible)" % [label, posts_before], _visible_post_meshes(stage_root), 0)
	# Props: kit meshes, none inside a keep-out, and sails.
	var rows := Scenery._keepouts(map)
	var props := scenery.get_node("Props")
	var prop_count := 0
	var prop_ok := true
	var crate_sig := _glb_signature("prop_crate.glb", "Surface")
	var crate_seen := false
	for batch in props.get_children():
		var multi := batch as MultiMeshInstance3D
		prop_count += multi.multimesh.instance_count
		crate_seen = crate_seen or _signature(multi.multimesh.mesh) == crate_sig
		for placed: Transform3D in multi.get_meta("placements"):
			var at: Vector3 = placed.origin
			if SetDressing.blocked(rows, Vector2(at.x, at.z), 0.0) != "":
				prop_ok = false
	_t.check("%s %d props, none in a keep-out" % [label, prop_count], prop_ok and prop_count >= 8)
	_t.check("%s sails stand on at least three islands" % label, scenery.find_children("Sail_*", "Node3D", false, false).size() >= 3)
	var fans := scenery.find_children("Fan_*", "Node3D", false, false)
	var fan_ok := not fans.is_empty()
	for fan: Node3D in fans:
		var players := fan.find_children("*", "AnimationPlayer", true, false)
		fan_ok = fan_ok and SetDressing.blocked(rows, Vector2(fan.position.x, fan.position.z), 0.0) == "" \
			and not players.is_empty() and (players[0] as AnimationPlayer).is_playing()
	_t.check("%s %d yard fans spin, none in a keep-out" % [label, fans.size()], fan_ok)
	# Sky: cloud deck under Y -20 and 250 m out, mesas and landmarks well past the play bounds.
	var sky := scenery.get_node("Sky")
	var cloud_ok := true
	var clouds := sky.get_node("CloudDeck") as MultiMeshInstance3D
	for xf: Transform3D in clouds.get_meta("placements"):
		cloud_ok = cloud_ok and (xf * clouds.multimesh.mesh.get_aabb()).end.y <= -19.9 and Vector2(xf.origin.x, xf.origin.z).length() >= 250.0
	_t.check("%s cloud deck sits at or under Y -20, 250 m out" % label, cloud_ok)
	var far_ok := true
	var mesas := sky.get_node("DistantMesas") as MultiMeshInstance3D
	for xf: Transform3D in mesas.get_meta("placements"):
		var o: Vector3 = xf.origin
		far_ok = far_ok and Vector2(o.x, o.z).length() >= 400.0
	for landmark in ["Loom", "Blades", "CradleA", "CradleB"]:
		var view := sky.get_node(landmark) as Node3D
		far_ok = far_ok and Vector2(view.position.x, view.position.z).length() >= 400.0
	_t.check("%s mesas and landmarks stand 400 m out, past the 300 m play bounds" % label, far_ok)
	# Nothing here is a collider or a body.
	_t.eq("%s the dress adds no collision object" % label, _count(scenery, "CollisionObject3D"), 0)
	_t.eq("%s the dress adds no collision shape" % label, _count(scenery, "CollisionShape3D"), 0)
	f["scene"].free()


func _visible_cylinders(contraptions: Node) -> int:
	var n := 0
	for child in contraptions.get_children():
		if child is MeshInstance3D and (child.mesh is CylinderMesh or child.mesh is ArrayMesh) and child.visible:
			n += 1
	return n


func _visible_post_meshes(stage_root: Node3D) -> int:
	var n := 0
	for child in stage_root.get_children():
		if child is StaticBody3D:
			for part in child.get_children():
				if part is MeshInstance3D and part.visible and part.mesh is CylinderMesh:
					n += 1
		elif child is MeshInstance3D and child.mesh is SphereMesh and child.visible:
			n += 1
	return n


func _fallback() -> void:
	Scenery.dir = "res://assets/models/highdraft_missing/"
	var f := _fresh(Highdraft)
	var map = f["terrain"].map()
	var contraptions = f["contraptions"]
	var stage_root: Node3D = f["root"]
	var posts := _visible_post_meshes(stage_root)
	var cylinders_before := _visible_cylinders(contraptions)
	var scenery := Scenery.build(stage_root, map, contraptions, f["terrain"].ground_callable(1), null)
	Scenery.dir = Scenery.DIR
	_t.eq("fallback: no island skin without the GLB", scenery.find_children("IslandSkin_*", "MeshInstance3D", false, false).size(), 0)
	# 2026-10-09 swap-wave 12-F: the barge's picture is the recipe contraptions builds, not the Highdraft kit, so a
	# missing kit leaves it on the deck and only the kit's sail is absent.
	var deck_ok := true
	for barge in contraptions.barges:
		deck_ok = deck_ok and _deck_recipe(barge["deck"])
		deck_ok = deck_ok and (barge["deck"] as Node).get_node_or_null("HighdraftWeatherSail") == null
	_t.check("fallback: barge keeps its recipe deck and has no kit sail", deck_ok)
	_t.eq("fallback: thermal column and grate stay visible", _visible_cylinders(contraptions), cylinders_before)
	_t.check("fallback: there were thermal cylinders to keep", cylinders_before >= 6)
	_t.eq("fallback: post shaft and cap stay visible", _visible_post_meshes(stage_root), posts)
	_t.eq("fallback: no anchor eye, vent or net", scenery.find_children("AnchorEye_*", "Node3D", false, false).size() \
		+ scenery.find_children("Vent_*", "Node3D", false, false).size() + scenery.find_children("NetDeck", "Node3D", false, false).size(), 0)
	f["scene"].free()


func _hook_and_environment() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var terrain := ProbeTerrain.new(Highdraft)
	terrain.build(scene)
	var ctx := FakeCtx.new()
	ctx.terrain = terrain
	terrain.environment.sky = Palette.hdri_sky()
	var before: Sky = terrain.environment.sky
	var ambient: Color = terrain.environment.ambient_light_color
	Scenery.hook(ctx)
	ctx.events.stage_entered.emit(1, false)
	var stage_root: Node3D = terrain.geometry_root(1)
	_t.check("hook: stage entry builds the Highdraft dress once", stage_root.get_node_or_null(Scenery.NODE_NAME) != null)
	ctx.events.stage_entered.emit(1, true)
	_t.eq("hook: a retry does not build it twice", stage_root.find_children(Scenery.NODE_NAME, "Node3D", false, false).size(), 1)
	var env: Environment = terrain.environment
	# 2026-10-09: re-pinned for the HDRI sky rows (VX-WIRE). World row 3 says sky "hdri", so
	# apply_environment leaves the sky to the row (Palette.hdri_sky); the painted sky is used only
	# when the row says "own" (highdraft_scenery.gd apply_environment).
	# 2026-10-17 (one day per run): the shared HDRI sky's material is the time-of-day sky shader.
	_t.check("hook: the environment keeps the shared HDRI sky when the row says hdri", env.sky == before and env.sky.sky_material is ShaderMaterial)
	_t.check("hook: the painted sky path for an own row still builds a panorama", Scenery._sky_material() is PanoramaSkyMaterial)
	_t.check("hook: ambient shifts to the sky cream", env.ambient_light_color.is_equal_approx(Scenery.LOOK["ambient"]) and not ambient.is_equal_approx(env.ambient_light_color))
	Scenery.restore_environment(terrain)
	_t.check("restore: the shared sky and ambient come back", env.sky == before and env.ambient_light_color.is_equal_approx(ambient))
	var source := FileAccess.get_file_as_string("res://src/game.gd")
	_t.check("game.gd hooks the Highdraft dress", source.contains("highdraft_scenery.gd\").hook(ctx)"))
	# hook() binds ctx into a connection on ctx.events; dropping the bus ends that cycle so the
	# terrain, its environment and the shared HDRI sky are freed before the engine exits.
	ctx.events = null
	scene.free()


# The real game: entering stage 5 builds the dress through the hook, on the world's own
# contraptions, and leaving for another world's stage hands the shared sky back.
func _game_integration() -> void:
	var game := Game.new()
	game.test_mode = true
	root.add_child(game)
	for tick in 600:
		if game.flow != null:
			break
		await physics_frame
	_t.check("game: flow came up", game.flow != null)
	if game.flow == null:
		game.free()
		return
	var env: Environment = game.ctx.terrain.environment
	var shared: Sky = env.sky
	game.flow.enter_stage(5, Vector3.ZERO, false)
	await physics_frame
	var stage_root: Node3D = game.ctx.terrain.geometry_root(5)
	var scenery := stage_root.get_node_or_null(Scenery.NODE_NAME)
	_t.check("game: stage 5 entry builds the Highdraft dress", scenery != null)
	var contraptions = game.world.contraptions.get(5)
	# 2026-10-09 swap-wave 12-F: re-pinned from the HighdraftBargeSkin node to the barge recipe views.
	var skinned := 0
	if contraptions != null:
		for barge in contraptions.barges:
			if _deck_recipe(barge["deck"]):
				skinned += 1
	_t.eq("game: both barges wear the recipe", skinned, 2)
	# 2026-10-09: re-pinned for the HDRI sky rows (VX-WIRE). Stages 5 and 1 (worlds 3 and 1) both
	# say "hdri": the one cached Palette.hdri_sky() is set on entry and stays across the move.
	_t.check("game: the cached HDRI sky is up", env.sky == Palette.hdri_sky())
	game.flow.enter_stage(1, Vector3.ZERO, false)
	await physics_frame
	_t.check("game: stage 1 keeps the same cached HDRI sky", env.sky == Palette.hdri_sky())
	_t.check("game: the startup sky was replaced by the HDRI row", shared != Palette.hdri_sky())
	game.free()


func _anchor_reads() -> void:
	var updater := Scenery.Updater.new()
	var kit := AugmentKit.new()
	var row := {"foot": Vector3(10.0, 28.0, 5.0), "height": 16.0}
	_t.eq("anchor: idle with no aim", updater._anchor_state(row, kit), "idle")
	kit.aim = {"state": Augments.AIM_REACH, "point": Vector3(10.4, 35.0, 5.2), "normal": Vector3.UP}
	_t.eq("anchor: ready when the press would bite this post", updater._anchor_state(row, kit), "ready")
	kit.aim = {"state": Augments.AIM_REACH, "point": Vector3(30.0, 35.0, 5.0), "normal": Vector3.UP}
	_t.eq("anchor: idle when the aim bites elsewhere", updater._anchor_state(row, kit), "idle")
	kit.line_state = Augments.LINE_LATCHED
	kit.anchor = Vector3(10.0, 44.6, 5.0)
	_t.eq("anchor: attached when the line holds this eye", updater._anchor_state(row, kit), "attached")
	updater.free()


# The cloud deck image is baked on a worker started by hook(); its bytes, mipmaps included,
# match the main-thread loop it replaced.
func _cloud_deck() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 7_310_032
	noise.frequency = 0.012
	noise.fractal_octaves = 3
	var want := noise.get_seamless_image(256, 256)
	want.convert(Image.FORMAT_RGB8)
	var cream: Color = Scenery.LOOK["cloud"]
	var shade := cream.lerp(Scenery.LOOK["fill"], 0.6)
	for y in want.get_height():
		for x in want.get_width():
			want.set_pixel(x, y, shade.lerp(cream, smoothstep(0.3, 0.7, want.get_pixel(x, y).r)))
	want.generate_mipmaps()
	Scenery._cloud = null
	Scenery.hook(FakeCtx.new())
	_t.check("cloud: hook starts the deck bake on a worker", Scenery._cloud_task >= 0)
	var got: Image = Scenery._cloud_material().albedo_texture.get_image()
	_t.check("cloud: the worker image equals the old main-thread loop byte for byte",
		got.get_format() == want.get_format() and got.has_mipmaps() and got.get_data() == want.get_data(),
		"%d bytes" % got.get_data().size())
	_t.check("cloud: the material is cached and the task claimed", Scenery._cloud_material() == Scenery._cloud and Scenery._cloud_task == -1)


func _run() -> void:
	_zone("highdraft", Highdraft)
	_zone("crown", Crown)
	_fallback()
	_hook_and_environment()
	_anchor_reads()
	_cloud_deck()
	await _game_integration()
	var code := _t.verdict()
	quit(code)


# The barge recipe's meshes (base and shells, recipe_props.gd ROWS "barge"), each one visible on a deck that draws
# no mesh of its own.
func _deck_recipe(deck: MeshInstance3D) -> bool:
	var probe := Node3D.new()
	var want: Array = []
	for view in RecipeProps.base("barge", probe, Transform3D.IDENTITY) + RecipeProps.shells("barge", probe, Transform3D.IDENTITY):
		want.append((view as MeshInstance3D).mesh)
	probe.free()
	var have: Array = []
	for child in deck.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).visible:
			have.append((child as MeshInstance3D).mesh)
	return deck.mesh == null and deck.visible and not want.is_empty() and have.size() == want.size() \
		and want.all(func(m): return have.has(m))
