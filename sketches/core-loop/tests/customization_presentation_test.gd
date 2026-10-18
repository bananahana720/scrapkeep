# 2026-10-12 FIXTURE-ADAPT: eb9cbd7 made the shell three-surface; a967dd8 moved decals to the seat-back plate.
# 2026-10-12 R3: CUSTOMIZE.md:29 says "never the tumbling Core lattice"; :458 requires panel/ring fallback.
extends SceneTree

const Game := preload("res://src/game.gd")
const Cosmetics := preload("res://src/core/cosmetics.gd")
const Customize := preload("res://src/ui/customize_page.gd")
const Intent := preload("res://src/movement/intent.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const CosmeticPresentation := preload("res://src/presentation/cosmetic_presentation.gd")
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
	var pod_materials := _materials(view, rec["pod"])
	for slot in ["paint", "trail", "decal", "companion_paint"]:
		var id: String = {"paint": "paint_any_night", "trail": "trail_salt_skip", "decal": "decal_fern", "companion_paint": "companion_paint_night"}[slot]
		profile.unlock_cosmetic(id)
		_t.check("equip " + slot, Customize.equip(profile, Cosmetics.owner_for(pilot, slot), slot, id))
	hero._process(0.016)
	rec = hero.shell_of(_game.player)
	core_mesh = view._meshes(rec["core"])[0]
	pod_materials = _materials(view, rec["pod"])
	var core_materials := []
	for mesh in view._meshes(rec["core"]):
		for surface in mesh.mesh.get_surface_count():
			core_materials.append({"mesh": mesh, "surface": surface, "material": mesh.get_active_material(surface)})
	var core_surfaces: int = core_mesh.mesh.get_surface_count()
	_t.eq("Hoberman shell main mesh has three surfaces", core_surfaces, 3)
	view._process(0.016)
	var ring: MeshInstance3D = rec["pod"].get_node("WeaponRing")
	var ring_paint := -1
	for surface in ring.mesh.get_surface_count():
		if ring.mesh.surface_get_material(surface).resource_name == "paint":
			ring_paint = surface
	var decal := ring.get_active_material(ring_paint) as ShaderMaterial
	_t.check("CUS-6 missing plate uses the ring paint surface", decal != null and decal.resource_name == "DecalMask" and decal.get_shader_parameter("decal_mask") == load("res://assets/cosmetics/decals/decal_fern_mask.png"))
	_t.eq("decal adds no geometry or draw", core_mesh.mesh.get_surface_count(), core_surfaces)
	_check_core("CUS-6 every Core surface keeps its original material", core_materials)
	_check_fallback(view, rec["pod"], pod_materials, decal)
	_t.check("CUS-6 today's paint still tints shell enamel", _has_paint(view, rec["pod"], Cosmetics.row("paint_any_night")["tint"]))
	_t.eq("cosmetics leave run summary unchanged", JSON.stringify(_game.run.summary()), gameplay_before)
	_t.eq("cosmetics leave physics mass unchanged", _game.player.body().mass, ball_mass)
	# The delivered plate is an empty mount; a mesh probe exercises its per-surface material contract.
	view._decal["key"] = "-"
	view._process(0.016)
	_t.check("B5 a refit reuses the cached decal material", ring.get_active_material(ring_paint) == decal)
	var plate_mount: Node3D = rec["pod"].find_child("DecalPlate", true, false)
	if not _t.check("Hoberman shell supplies the seat-back DecalPlate mount", plate_mount != null):
		_game.free()
		quit(_t.verdict())
		return
	var plate := MeshInstance3D.new()
	plate.name = "DecalSurfaceProbe"
	plate.mesh = core_mesh.mesh.duplicate()
	plate_mount.add_child(plate)
	view._decal["key"] = "-"
	view._process(0.016)
	var plate_mat := plate.get_active_material(0) as ShaderMaterial
	_t.check("B5 decal lands on DecalPlate when it exists", plate_mat != null and plate_mat.resource_name == "DecalMask" and plate_mat.get_shader_parameter("decal_mask") == load("res://assets/cosmetics/decals/decal_fern_mask.png"))
	for surface in core_mesh.mesh.get_surface_count():
		_t.check("B5 plate decal surface %d" % surface, plate.get_active_material(surface) == plate_mat)
	_check_core("B5 with a plate, Core keeps every original material", core_materials)
	_t.check("B5 with a plate, every pod surface is restored", _materials(view, rec["pod"]).slice(0, pod_materials.size()) == pod_materials)
	view._decal["key"] = "-"
	view._process(0.016)
	for surface in plate.mesh.get_surface_count():
		_t.check("B5 a plate refit reuses surface %d material" % surface, plate.get_active_material(surface) == plate_mat)
	plate_mount.remove_child(plate)
	plate.free()
	view._decal["key"] = "-"
	view._process(0.016)
	_check_core("B5 without a plate, Core keeps every original material", core_materials)
	_check_fallback(view, rec["pod"], pod_materials, decal)
	_t.check("B5 missing plate reuses the ring material", ring.get_active_material(ring_paint) == decal)
	_check_pilot_fallbacks(view, hero, view.effective(pilot, "decal"))
	# The test seam plants the worn decal as pending: effective() falls back to the default.
	var worn_decal: String = view.CosmeticWear.worn(hero.profile, Cosmetics.owner_for(pilot, "decal"), "decal")
	_t.check("a worn decal resolves before the plant", worn_decal != "" and not view.effective(pilot, "decal").is_empty(), worn_decal)
	Cosmetics._test_pending = [worn_decal]
	_t.eq("a planted pending worn decal resolves to the default", view.effective(pilot, "decal"), {})
	Cosmetics._test_pending = []
	_t.check("the cleared decal resolves again", not view.effective(pilot, "decal").is_empty())

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
	# Cards are pooled: a rolling ball reuses at most 24 nodes instead of instancing per sample.
	var seen := {}
	for i in 80:
		view._process(0.031)
		for card in view._cards:
			seen[(card["node"] as Node).get_instance_id()] = true
	_t.check("trail reuses at most 24 card nodes over 80 frames", seen.size() > 0 and seen.size() <= 24, "%d distinct card nodes" % seen.size())
	player.state.grounded = false
	view._process(0.04)
	_t.eq("airborne ball suppresses cosmetic trail", view._cards.size(), 0)
	# B5: between a set piece's start and its landing the trail draws along the flight at ball height.
	view.set_piece = true
	view._trail_clock = 1.0
	view._process(0.04)
	_t.check("B5 a set piece's flight draws the trail", view._cards.size() > 0)
	if not view._cards.is_empty():
		_t.check("B5 set-piece cards ride at the ball's height", absf((view._cards[-1]["node"] as Node3D).global_position.y - player.shown_position().y) < 0.001)
	view.set_piece = false
	view._process(0.04)
	_t.eq("B5 the landing ends the airborne trail", view._cards.size(), 0)
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
	_check_core("CUS-5 missing decal restores every original material", core_materials)
	_t.check("CUS-5 missing decal restores every pod surface", _materials(view, rec["pod"]) == pod_materials)
	_t.check("CUS-5 missing companion paint restores mesh", companion_meshes[0].mesh == source_mesh)
	view._process(0.04)
	_t.eq("CUS-5 one warning per absent asset in play", view.resolver._warned.size(), 3)
	_game.free()
	quit(_t.verdict())


func _materials(view, node: Node) -> Array:
	var out := []
	for mesh in view._meshes(node):
		if mesh.name == "DecalSurfaceProbe":
			continue
		for surface in mesh.mesh.get_surface_count():
			out.append(mesh.get_active_material(surface))
	return out


func _has_paint(view, node: Node, tint: Color) -> bool:
	for mat in _materials(view, node):
		if mat is ShaderMaterial and mat.resource_name == "paint":
			return (mat.get_shader_parameter("paint_tint") as Color).is_equal_approx(Color(tint.r * 1.2, tint.g * 1.2, tint.b * 1.2))
	return false


func _check_core(label: String, originals: Array) -> void:
	for saved in originals:
		var mesh: MeshInstance3D = saved["mesh"]
		var surface: int = saved["surface"]
		var original: Material = saved["material"]
		_t.check("%s %s surface %d" % [label, mesh.name, surface], mesh.get_active_material(surface) == original)


func _check_fallback(view, pod: Node, originals: Array, decal: Material) -> void:
	var index := 0
	var eligible := 0
	for mesh in view._meshes(pod):
		for surface in mesh.mesh.get_surface_count():
			var original: Material = originals[index]
			var placement: bool = mesh.name == "WeaponRing" or (mesh.name == "Pod" and String(mesh.get_parent().name) in ["HeftC2", "HeftC3", "HeftC4", "HeftC5"])
			var takes_decal: bool = placement and mesh.mesh.surface_get_material(surface).resource_name == "paint"
			var want: Material = decal if takes_decal else original
			_t.check("fallback %s surface %d only panel/ring paint changes" % [mesh.name, surface], mesh.get_active_material(surface) == want)
			eligible += 1 if takes_decal else 0
			index += 1
	_t.check("delivered shell has eligible ring paint", eligible > 0)


func _check_pilot_fallbacks(view, hero, row: Dictionary) -> void:
	for def in ClassDef.all():
		var holder := Node3D.new()
		root.add_child(holder)
		var shell: Dictionary = hero.fit_shell_into(holder, def.id, "", 5, {})
		var cosmetic := CosmeticPresentation.new()
		var originals := []
		for mesh in view._meshes(shell["core"]):
			for surface in mesh.mesh.get_surface_count():
				originals.append({"mesh": mesh, "surface": surface, "material": mesh.get_active_material(surface)})
		var pod_originals := _materials(view, shell["pod"])
		var ring: MeshInstance3D = shell["pod"].get_node("WeaponRing")
		var paint_surface := -1
		for surface in ring.mesh.get_surface_count():
			if ring.mesh.surface_get_material(surface).resource_name == "paint":
				paint_surface = surface
		_t.check("%s has identifiable ring paint" % def.id, paint_surface >= 0)
		cosmetic._apply_decal(shell, row)
		var decal := ring.get_active_material(paint_surface) as ShaderMaterial
		_t.check("%s real missing plate reaches ring" % def.id, decal != null and decal.resource_name == "DecalMask")
		_check_core("%s Core unchanged" % def.id, originals)
		_check_fallback(view, shell["pod"], pod_originals, decal)
		cosmetic._decal["key"] = "-"
		cosmetic._apply_decal(shell, row)
		_t.check("%s cached ring refit" % def.id, ring.get_active_material(paint_surface) == decal)
		cosmetic._apply_decal(shell, {})
		_check_core("%s Core restored" % def.id, originals)
		_t.check("%s every pod surface restored" % def.id, _materials(view, shell["pod"]) == pod_originals)
		cosmetic.free()
		holder.free()
