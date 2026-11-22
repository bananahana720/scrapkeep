extends SceneTree

const Game := preload("res://src/game.gd")
const Field := preload("res://src/build/scrap_field.gd")
const Palette := preload("res://src/core/palette.gd")
const GLB := "res://assets/models/world_one/scrap_pickups.glb"
const NAMES := ["BentPlate", "GearSegment", "PipeStub", "BoltCluster"]
const COG := "Cog"
const PanelShell := preload("res://src/build/panel_shell.gd")
# Re-pinned 2026-10-13 (IDENTITY-DET): a caught piece's swirl side now comes from the bot's sign or the
# field's catch serial instead of its object id; layout, magnet, collection, value and timing unchanged.
# Re-pinned 2026-10-16 (SCRAP-LEAK): drops fold the oldest loose piece past a cap into the newest; layout, magnet, collection, value and timing unchanged.
# Re-pinned 2026-10-24 (IL-01 grey panels, #398): step() and clear() also take and clear panel pickups and rib caches; layout, magnet, collection, value and timing unchanged.
# Re-pinned 2026-11-09 (ruling cd, scrap trail, #650): lay_trail and trail_spots lay a map's trail to the beat, and the fold passes over trail pieces; lay_out, magnet, collection, value and timing unchanged.
# Re-pinned 2026-11-11 (site markers, map audit unit 4): caches() also gives each rib cache's drop ground, kept from drop_panel; lay_out, magnet, collection, value and timing unchanged.
# Re-pinned 2026-11-12 (W1-21, models for the cog and the dropped panel): drop_panel draws the panel's kit plate and
# ground_plate builds it; lay_out, magnet, collection, value and timing unchanged.
# Re-pinned 2026-11-21 (W45 perf unit 1): step() writes no spin to an uncaught pickup past SPIN_RANGE (120 m);
# lay_out, magnet, collection, value, timing and every near spin unchanged.
# Re-pinned 2026-11-21 (W45 perf unit 4): step() skips length() sqrt on uncaught pickups past max(reach, SPIN_RANGE, COLLECT);
# lay_out, magnet, collection, recovery expiry, value, timing and near spins unchanged.
const LOGIC_SHA := "f6c021fc040f80aeca0eed3acae2bf3086567a285d802f6457d40de774d4e83d"

var failures: Array[String] = []
var game
var asset_meshes := {}


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, reason: String) -> void:
	if not ok:
		failures.append(reason)
		print("scrap assertion: " + reason)


func _asset() -> void:
	var packed := load(GLB) as PackedScene if ResourceLoader.exists(GLB) else null
	_check(packed != null, "GLB loads")
	if packed == null:
		return
	var scene := packed.instantiate()
	var names: Array[String] = []
	var total_tris := 0
	var total_vertices := 0
	for found in scene.find_children("*", "MeshInstance3D", true, false):
		var part := found as MeshInstance3D
		names.append(String(part.name))
		_check(Field._valid_pickup(part), String(part.name) + " identity origin, opaque vertex colours and prop budget")
		if not part.mesh is ArrayMesh or part.mesh.get_surface_count() != 1:
			continue
		asset_meshes[String(part.name)] = part.mesh
		var arrays := part.mesh.surface_get_arrays(0)
		var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices = arrays[Mesh.ARRAY_INDEX]
		var tris: int = (indices.size() if indices != null else vs.size()) / 3
		_check(tris > 12 and tris <= 270 and vs.size() <= 610, String(part.name) + " independent 270 T / 610 V / 1 D cap")
		var colors = arrays[Mesh.ARRAY_COLOR]
		_check(colors != null and colors.size() == vs.size(), String(part.name) + " exported colour attribute")
		total_tris += tris
		total_vertices += vs.size()
		print("scrap variant %s: %d T / %d V / 1 D" % [part.name, tris, vs.size()])
	var expected := NAMES.duplicate()
	expected.append(COG)
	expected.sort()
	names.sort()
	_check(names == expected, "exact four variant names and the cog")
	_check(total_tris <= 1350 and total_vertices <= 3050, "aggregate five-prop budget")
	_check(scene.find_children("*", "CollisionObject3D", true, false).is_empty(), "GLB contains no physics bodies")
	_check(scene.find_children("*", "CollisionShape3D", true, false).is_empty(), "GLB contains no collision shapes")
	print("scrap kit: %d T / %d V / %d D" % [total_tris, total_vertices, names.size()])
	scene.free()


func _draws(field, recovery := false) -> Dictionary:
	var variants := {}
	for item in field._items:
		if field._cogs.has(item):
			continue
		var variant: String = item.get_meta("scrap_variant", "")
		_check(NAMES.has(variant), "real spawn has a named GLB variant, never a fallback box")
		_check(item.mesh is ArrayMesh and not item.mesh is PrimitiveMesh, "real spawn draws GLB geometry")
		var material := item.material_override as ShaderMaterial
		_check(material != null and material.shader.resource_path == "res://assets/shaders/pickup.gdshader"
			and material.shader.code.contains("ALBEDO = COLOR.rgb;")
			and not material.shader.code.contains("ALPHA"), "real spawn enables opaque vertex-colour albedo")
		if material != null:
			var color := Palette.AMBER if recovery else Palette.ARC
			_check(material.resource_name == "field" and material.get_shader_parameter("glow_color") == color
				and is_equal_approx(material.get_shader_parameter("face_energy"), 0.06)
				and is_equal_approx(material.get_shader_parameter("rim_energy"), 1.25)
				and is_equal_approx(material.get_shader_parameter("emission_ceiling"), 1.35), "palette glow confined to bounded rim")
		_check(item.find_children("*", "CollisionObject3D", true, false).is_empty(), "no pickup physics bodies")
		if not asset_meshes.has(variant):
			continue
		var asset: Mesh = asset_meshes[variant]
		if not recovery:
			_check(item.mesh == asset, "real spawn uses exact imported shared mesh")
		else:
			_check(item.mesh.get_aabb().size.is_equal_approx(asset.get_aabb().size * 1.75), "recovery retains 1.4 / 0.8 size ratio")
			var original := asset.surface_get_arrays(0)
			var enlarged: Array = item.mesh.surface_get_arrays(0)
			_check(enlarged[Mesh.ARRAY_INDEX] == original[Mesh.ARRAY_INDEX]
				and enlarged[Mesh.ARRAY_COLOR] == original[Mesh.ARRAY_COLOR], "recovery retains GLB topology and vertex colours")
			var original_vertices: PackedVector3Array = original[Mesh.ARRAY_VERTEX]
			var enlarged_vertices: PackedVector3Array = enlarged[Mesh.ARRAY_VERTEX]
			_check(original_vertices.size() == enlarged_vertices.size(), "recovery retains GLB vertex count")
			if original_vertices.size() == enlarged_vertices.size():
				for i in original_vertices.size():
					_check(enlarged_vertices[i].is_equal_approx(original_vertices[i] * 1.75), "recovery draws enlarged GLB vertices")
		if variants.has(variant):
			_check(variants[variant] == item.mesh, "instances share variant mesh")
		variants[variant] = item.mesh
	return variants


# W1-21: a cog is the kit's Cog model under a bone rim glow, and a dropped panel is its own kit plate lying flat,
# never a Godot primitive.
func _cogs_and_panels(field) -> void:
	field.clear()
	field.drop_cogs(Vector3.ZERO, 5)
	_check(field.cog_count() == 5 and field.cog_value() == 5, "cog count and value unchanged")
	for item in field._items:
		_check(item.mesh == asset_meshes.get(COG), "a cog draws the kit's Cog mesh")
		_check(not item.mesh is PrimitiveMesh, "a cog is no primitive")
		var material := item.material_override as ShaderMaterial
		_check(material != null and material.get_shader_parameter("glow_color") == Palette.SAND, "a cog glows bone, not brass")
	field.clear()
	field.drop_panel(Vector3.ZERO, "fin_plate")
	field.drop_panel(Vector3(4, 0, 0), "no_such_panel", false, true)
	_check(field.panel_count() == 2 and field.cache_count() == 1, "panel and cache counts unchanged")
	for item in field._items:
		_check(not item.mesh is PrimitiveMesh and item.material_override == null, "a dropped panel draws its kit plate with its own materials")
	var fin: Mesh = field._items[0].mesh
	var source := PanelShell.plate_mesh("fin")
	_check(fin.get_surface_count() == source.get_surface_count()
		and fin.get_aabb().size.is_equal_approx(source.get_aabb().size * Field.GROUND_PLATE), "the fin plate, GROUND_PLATE times larger")
	_check(field._items[1].mesh == Field.ground_plate("hull_tile"), "an unknown panel lies down as the tile plate")
	field.clear()


func _run() -> void:
	_asset()
	game = Game.new()
	game.test_mode = true
	game.table = "alpha"
	root.add_child(game)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.ctx.calm = true
	game.flow.press_start()
	game.flow.choose_class(0)
	var field = game.ctx.build.scrap
	_check(field.get_parent() == game and field.name == "Scrap", "real Build.setup field path")
	var stage_rng := RandomNumberGenerator.new()
	stage_rng.seed = 18421
	for stage in range(1, 7):
		game.flow.enter_stage(stage, Vector3.ZERO, false)
		field.drop(Vector3.ZERO, 4, stage_rng)
		_check(field.count() >= 4, "stage %d real enemy-drop path spawns scrap" % stage)
		_draws(field)
	game.flow.enter_stage(1, Vector3.ZERO, false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 76183
	field.lay_out(game.ctx.terrain, game.ctx.terrain.scrap_lines(1), 1.0, rng)
	var first: Array = []
	for item in field._items:
		first.append([item.position, item.get_meta("scrap_variant", "cog")])
	rng.seed = 76183
	field.lay_out(game.ctx.terrain, game.ctx.terrain.scrap_lines(1), 1.0, rng)
	var second: Array = []
	for item in field._items:
		second.append([item.position, item.get_meta("scrap_variant", "cog")])
	_check(first == second, "retry retains seeded positions and variants")
	field.clear()
	var state: int = rng.state
	for i in 200:
		field._add(Vector3(i * 1.37, 1.4, i * .41))
	var variants := _draws(field)
	_check(variants.size() == 4 and field.count() == 200, "200 real pickups share four meshes")
	_check(rng.state == state, "visual spawn consumes no RNG")
	print("scrap 200 pickups: 200 base-pass draws / %d shared meshes / 1 shared material" % variants.size())
	field.clear()
	field.drop_line(Vector3.ZERO, Vector3.FORWARD, 40.0, 10, rng)
	_check(field.count() == 10, "drop_line value/count unchanged")
	_draws(field)
	field.drop(Vector3.ONE, 3, rng)
	_check(field.count() == 13, "enemy drop value/count unchanged")
	_draws(field)
	field.clear()
	field.drop_recovery(null, Vector3.ZERO, Vector3.FORWARD, 19, 6, rng)
	_check(field.recovery_count() == 6 and field.recovery_value() == 19, "recovery count and value unchanged")
	_draws(field, true)
	field.step(Vector3(1000, 0, 1000), 0.0, .1)
	_draws(field, true)
	_cogs_and_panels(field)
	var source := FileAccess.get_file_as_string("res://src/build/scrap_field.gd")
	var start := source.find("func lay_out(")
	var end := source.find("func _add(at:")
	_check(start >= 0 and end > start and source.substr(start, end - start).sha256_text() == LOGIC_SHA,
		"all layout, magnet, collection, value, timing, spin and seeded gameplay source unchanged")
	game.free()
	print("scrap_pickup_asset_test: %s" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
