extends SceneTree

const Game := preload("res://src/game.gd")
const Cosmetics := preload("res://src/core/cosmetics.gd")
const Customize := preload("res://src/ui/customize_page.gd")
const Intent := preload("res://src/movement/intent.gd")
const T := preload("res://tests/support/t.gd")

var _t := T.new("customization_presentation_test")
var _game


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run.call_deferred()


func _frames(n := 3) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	while _game.flow == null:
		await process_frame
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	_game.flow.press_start()
	_game.flow.choose_class(0)
	await _frames(10)
	var hero = _game.presentation.hero_assets
	var view = hero.get_node_or_null("CosmeticPresentation")
	_t.check("CUS-6 cosmetics node installed in run", view != null)
	if view == null:
		_game.free()
		quit(_t.verdict())
		return
	view.set_process(false)
	var profile = _game.ctx.profile
	var pilot: String = _game.player.class_def.id
	var gameplay_before: String = JSON.stringify(_game.run.summary())
	var ball_mass: float = _game.player.body().mass
	var rec: Dictionary = hero.shell_of(_game.player)
	var core_mesh: MeshInstance3D = view._meshes(rec["core"])[0]
	var glass: Material = core_mesh.get_active_material(0)
	var pod_materials := _materials(view, rec["pod"])
	for slot in ["paint", "trail", "decal", "companion_paint"]:
		var id: String = {"paint": "paint_any_night", "trail": "trail_salt_skip", "decal": "decal_fern", "companion_paint": "companion_paint_night"}[slot]
		profile.unlock_cosmetic(id)
		_t.check("equip " + slot, Customize.equip(profile, Cosmetics.owner_for(pilot, slot), slot, id))
	hero._process(0.016)
	rec = hero.shell_of(_game.player)
	core_mesh = view._meshes(rec["core"])[0]
	pod_materials = _materials(view, rec["pod"])
	view._process(0.016)
	var decal := core_mesh.get_active_material(0) as ShaderMaterial
	_t.check("CUS-6 decal composed on rolling shell", decal != null and decal.resource_name == "DecalMask" and decal.get_shader_parameter("decal_mask") == load("res://assets/cosmetics/decals/decal_fern_mask.png"))
	_t.eq("decal adds no geometry or draw", core_mesh.mesh.get_surface_count(), 1)
	_t.check("decal leaves pod and pilot materials alone", _materials(view, rec["pod"]) == pod_materials)
	_t.check("CUS-6 today's paint still tints shell enamel", _has_paint(view, rec["pod"], Cosmetics.row("paint_any_night")["tint"]))
	_t.eq("cosmetics leave run summary unchanged", JSON.stringify(_game.run.summary()), gameplay_before)
	_t.eq("cosmetics leave physics mass unchanged", _game.player.body().mass, ball_mass)

	var body = _game.presentation.get_node("CompanionBody")
	_t.eq("seat real SPIL-9 for run", body.seat_for_capture("primer_coil", "ram_prow"), "")
	await _frames(5)
	var companion_meshes: Array = view._meshes(body._model)
	var source_mesh: Mesh = companion_meshes[0].mesh
	view._process(0.016)
	var painted := 0
	var hull_vertices := 0
	var other_vertices := 0
	var changed_rgb := 0
	for mesh in companion_meshes:
		for surface in mesh.mesh.get_surface_count():
			var mat := mesh.get_active_material(surface) as ShaderMaterial
			if mat == null or mat.resource_name != "CompanionPaint":
				continue
			painted += 1
			_t.eq("CUS-6 real paint material tint on SPIL-9", mat.get_shader_parameter("paint_tint"), (load("res://assets/cosmetics/paints/companion_paint_night.tres") as StandardMaterial3D).albedo_color)
			var colors: PackedColorArray = mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR]
			var originals: PackedColorArray = source_mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR]
			for i in colors.size():
				if colors[i].a > 0.99:
					hull_vertices += 1
				else:
					other_vertices += 1
				if not Vector3(colors[i].r, colors[i].g, colors[i].b).is_equal_approx(Vector3(originals[i].r, originals[i].g, originals[i].b)):
					changed_rgb += 1
	_t.check("CUS-6 companion enamel has selected material", painted > 0)
	_t.check("only Hull and Deck receive paint", hull_vertices > 0 and other_vertices > 0, "hull %d, other %d" % [hull_vertices, other_vertices])
	_t.eq("companion RGB stays baked before tint", changed_rgb, 0)

	var player = _game.player
	player.state.grounded = true
	player.state.velocity = Vector3(0, 0, -12)
	view._process(0.04)
	_t.check("CUS-6 moving ball emits delivered trail", view.trail.visible and view._cards.size() > 0)
	if not view._cards.is_empty():
		var card: Node3D = view._cards[0]["node"]
		_t.check("trail shows real GLB card mesh", not view._meshes(card).is_empty() and view._meshes(card)[0].mesh is ArrayMesh)
		_t.check("trail follows ball at floor height", absf(card.global_position.y - (player.shown_position().y - 1.0 + 0.04)) < 0.001)
		_t.check("trail is independent of rolling shell", view.trail.get_parent() == view and not rec["core"].is_ancestor_of(card))
	for i in 40:
		view._process(0.031)
	_t.check("trail cap enforced", view._cards.size() > 0 and view._cards.size() <= 24)
	player.state.grounded = false
	view._process(0.04)
	_t.eq("airborne ball suppresses cosmetic trail", view._cards.size(), 0)
	player.state.grounded = true
	player.state.velocity = Vector3.ZERO
	view._process(0.04)
	_t.eq("stationary ball suppresses cosmetic trail", view._cards.size(), 0)
	player.state.velocity = Vector3(0, 0, -12)
	view._process(0.04)
	player.body().global_position += Vector3(20, 0, 0)
	view._process(0.001)
	_t.eq("distant samples never persist", view._cards.size(), 0)

	view.assets = {}
	view._process(0.04)
	_t.eq("CUS-5 missing trail clears nodes", view._cards.size(), 0)
	_t.check("CUS-5 missing decal restores glass", core_mesh.get_active_material(0) == glass)
	_t.check("CUS-5 missing companion paint restores mesh", companion_meshes[0].mesh == source_mesh)
	view._process(0.04)
	_t.eq("CUS-5 one warning per absent asset in play", view.resolver._warned.size(), 3)
	_game.free()
	quit(_t.verdict())


func _materials(view, node: Node) -> Array:
	var out := []
	for mesh in view._meshes(node):
		for surface in mesh.mesh.get_surface_count():
			out.append(mesh.get_active_material(surface))
	return out


func _has_paint(view, node: Node, tint: Color) -> bool:
	for mat in _materials(view, node):
		if mat is StandardMaterial3D and mat.resource_name == "paint":
			return mat.albedo_color.is_equal_approx(Color(tint.r * 1.2, tint.g * 1.2, tint.b * 1.2))
	return false
