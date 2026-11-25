extends SceneTree

const Game := preload("res://src/game.gd")
const Palette := preload("res://src/core/palette.gd")
const Harness := preload("res://tests/doubles/module_harness.gd")
const Dress := preload("res://src/presentation/arena_mind_dress.gd")
const WorldLook := preload("res://src/presentation/world_look.gd")
const T := preload("res://tests/support/t.gd")

var _t := T.new("arena_mind_dress_test")
var _game
var _before := {}
var _fixture_dir := ""


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("-fixture-dir="):
			_fixture_dir = arg.trim_prefix("-fixture-dir=")
	# The dressing is pinned with a smash-per-frame fight, not the fight's length: the PHASE_MIN_SECONDS hold
	# (mind.gd; tests/boss_phase_hold_test.gd) is multiplied out so the Mind falls inside the frame cap.
	ChallengeDials.set_overrides({"mind.phase_min_by_phase": [0.0, 0.0, 0.0, 0.0]})
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	Harness.boot(_game)
	_t.eq("arena scenery is absent at boot", _game.find_children(Dress.NODE_NAME, "Node3D", true, false).size(), 0)
	_game.ctx.events.boss_arena_entered.connect(func(): _before = _colliders(_game))
	if not _fixture_dir.is_empty():
		Dress.dir = _fixture_dir
	var saved := _enter()
	var mod = Harness.module(_game, 3)
	_check_colliders("dressing changes no gameplay collider or transform")
	var pad_shape := mod.pad.get_child(0) as CollisionShape3D
	_t.check("pad remains the original radius 36 height 2 cylinder", pad_shape.shape is CylinderShape3D
		and pad_shape.shape.radius == 36.0 and pad_shape.shape.height == 2.0
		and pad_shape.transform == Transform3D.IDENTITY and mod.pad.collision_layer == 1 and mod.pad.collision_mask == 0)
	var dress = mod.pad.get_node_or_null(Dress.NODE_NAME)
	_t.check("the real Mind fight has summit dressing", mod.active() and dress != null)
	if not _fixture_dir.is_empty():
		_fallback(mod, saved)
		_finish()
		return
	if dress == null:
		_finish()
		return
	_t.check("the crown remains over the summit", mod._dress != null and mod._dress.base.find_child("CrownFrame", true, false) != null
		and mod._dress.global_position.is_equal_approx(dress.global_position))
	_t.check("greybox floor mesh alone is hidden", not _floor(mod).visible and mod.pad.visible and not pad_shape.disabled)
	_t.eq("dressing adds no physics body", dress.find_children("*", "CollisionObject3D", true, false).size(), 0)
	_t.eq("dressing adds no collision shape", dress.find_children("*", "CollisionShape3D", true, false).size(), 0)
	_surface_checks(dress)
	_geometry_checks(dress)
	# 2026-10-17 (one day per run): the crown fight is the run's dusk; its painted panorama is graded
	# by the time-of-day sky shader with the Mind row's dusk grade.
	var fight_sky := _game.ctx.terrain.environment.sky.sky_material as ShaderMaterial
	_t.check("fight sky is a textured Highdraft panorama under the dusk grade", _game.ctx.terrain.environment.sky != saved["sky"]
		and fight_sky != null and fight_sky.get_shader_parameter("panorama") != null
		and fight_sky.get_shader_parameter("horizon_tint") == WorldLook.ARENAS.mind.grade.horizon)
	_t.eq("fight ambient is the dusk blue", _game.ctx.terrain.environment.ambient_light_color, Color("9097bd"))
	_t.check("fight sun has the dusk bearing", _sun().rotation_degrees.is_equal_approx(Vector3(-14.0, 60.0, 0.0)))
	var seen = Harness.counter(_game)
	var fight: Dictionary = await Harness.fight(_game, mod, 2000, seen)
	_t.check("the dressed real fight reaches defeat", fight["defeated"])
	_assert_environment("defeat restores", saved)
	mod.exit_arena()
	_assert_environment("exit after defeat stays restored", saved)

	saved = _enter()
	var old_dress = mod._arena_dress
	_game.flow._retry_arena()
	_t.check("retry removes the previous visual node immediately", not old_dress.is_inside_tree())
	_t.check("retry builds one summit", mod.pad.get_node_or_null(Dress.NODE_NAME) == mod._arena_dress)
	_t.eq("retry saves the pre-fight sky instead of the previous fight sky", mod._arena_dress._saved["sky"], saved["sky"])
	_check_colliders("retry preserves gameplay colliders")
	mod.exit_arena()
	_assert_environment("explicit arena exit restores", saved)

	saved = _enter()
	var restart_seen := {}
	# The module's earlier run_started handler releases the arena before this observer
	# and before stage 1 replaces the Highdraft environment.
	var observe := func(_class_id: String): restart_seen.merge(_environment())
	_game.ctx.events.run_started.connect(observe)
	_game.flow.new_run()
	_game.ctx.events.run_started.disconnect(observe)
	_t.check("run restart restores every saved value before stage entry", restart_seen == saved)
	_t.eq("new run frees the summit reference", mod._arena_dress, null)
	await physics_frame
	_t.eq("new run leaves no summit node", _game.find_children(Dress.NODE_NAME, "Node3D", true, false).size(), 0)

	# 2026-10-09 re-pin (wave 12 VX-LIGHT b089655): every stage entry applies its world look row
	# (world_look.gd, slot "world") and the Mind's look rides slot "arena" above it, so leaving the
	# arena for stage 5 lands on stage 5's world row, not on the values _enter() wrote by hand. The
	# reference is the same stage 6 to stage 5 move with no arena between; the sky stays the saved one.
	_game.flow.enter_stage(_game.ctx.stages.last_of(3), Vector3.ZERO, false)
	_game.flow.enter_stage(5, Vector3.ZERO, false)
	var stage_look := _environment()
	saved = _enter()
	var fight_look := _environment()
	_game.flow.enter_stage(5, Vector3.ZERO, false)
	var after_exit := _environment()
	# 2026-10-09: re-pinned for the HDRI sky rows (VX-WIRE). Stage 5 is world 3, whose row says
	# sky "hdri", so stage entry sets the one cached Palette.hdri_sky(); the hand-written sky that
	# _enter() writes is replaced by the row on stage entry, so the old saved["sky"] can never return.
	_t.check("stage exit restores sky", after_exit["sky"] == stage_look["sky"])
	_t.check("stage exit lands on the shared HDRI sky, not a rebuilt one", after_exit["sky"] == Palette.hdri_sky())
	_t.check("the fight does not keep the stage's HDRI sky (Mind arena builds its own)", fight_look["sky"] != Palette.hdri_sky())
	for key in ["ambient", "exposure", "saturation", "sun_color", "sun_rotation"]:
		_t.check("stage exit lands on stage 5's world look " + key, after_exit[key] == stage_look[key],
			"got %s, want %s, fight %s" % [after_exit[key], stage_look[key], fight_look[key]])
	_t.eq("stage exit releases the visual node", mod._arena_dress, null)

	# The broken-folder case is also run as an external fixture: the exact same dressing
	# requirement above must FAIL, while these fallback checks must still PASS.
	Dress.dir = "res://assets/models/highdraft/__arm_missing__/"
	saved = _enter()
	_fallback(mod, saved)
	Dress.dir = Dress.DIR
	mod.exit_arena()
	_finish()


func _enter() -> Dictionary:
	_game.flow.enter_stage(_game.ctx.stages.last_of(3), Vector3.ZERO, false)
	var env: Environment = _game.ctx.terrain.environment
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.sky = sky
	env.ambient_light_color = Color(0.21, 0.34, 0.46)
	env.tonemap_exposure = 0.91
	env.adjustment_saturation = 0.87
	_sun().light_color = Color(0.73, 0.83, 0.93)
	_sun().rotation = Vector3(-0.71, 0.82, 0.11)
	var saved := _environment()
	_game.flow.enter_boss(Vector3(7.0, 0.0, -9.0))
	return saved


func _floor(mod) -> MeshInstance3D:
	for child in mod.pad.get_children():
		if child is MeshInstance3D:
			return child
	return null


func _fallback(mod, saved: Dictionary) -> void:
	_t.eq("missing kit adds no dressing node", mod.pad.get_node_or_null(Dress.NODE_NAME), null)
	_t.check("missing kit keeps the old greybox floor", _floor(mod).visible and _floor(mod).material_override == null
		and _floor(mod).mesh is CylinderMesh and _floor(mod).mesh.top_radius == 36.0)
	_check_colliders("missing kit preserves every gameplay collider")
	_assert_environment("missing kit keeps the current lighting", saved)
	print("arena_mind_greybox_fallback: PASS" if _floor(mod).visible and _colliders(_game) == _before and _environment() == saved else "arena_mind_greybox_fallback: FAIL")


func _surface_checks(dress: Node3D) -> void:
	var surfaces := 0
	var views: Array = dress.find_children("*", "GeometryInstance3D", true, false)
	for view in views:
		var mesh: Mesh = view.mesh if view is MeshInstance3D else view.multimesh.mesh
		for i in mesh.get_surface_count():
			surfaces += 1
			var material := mesh.surface_get_material(i) as BaseMaterial3D
			_t.check("surface retains vertex colours or an explicit texture: " + String(view.name), material != null
				and (material.vertex_color_use_as_albedo or material.albedo_texture != null))
			_t.check("scenery has no emission: " + String(view.name), material != null and not material.emission_enabled)
			var arrays := mesh.surface_get_arrays(i)
			_t.check("surface keeps authored colours: " + String(view.name), arrays[Mesh.ARRAY_COLOR] != null
				and arrays[Mesh.ARRAY_COLOR].size() == arrays[Mesh.ARRAY_VERTEX].size())
	# W49-MAPS: the five reused Highdraft parts, the Sky-Deck's edge posts and its inlay sheet.
	_t.eq("the summit kit uses seven surfaces", surfaces, 7)
	# Malformed surface materials are a normal loader rejection, never a null dereference.
	var null_mat := ArrayMesh.new()
	null_mat.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, (BoxMesh.new() as Mesh).surface_get_arrays(0))
	_t.eq("materialless mesh rejects safely", dress._rebuild_mesh(null_mat), null)
	var unknown := StandardMaterial3D.new()
	unknown.resource_name = "unknown_slot"
	null_mat.surface_set_material(0, unknown)
	_t.eq("unknown material slot rejects safely", dress._rebuild_mesh(null_mat), null)


func _geometry_checks(dress: Node3D) -> void:
	for label in ["SummitIsland", "EdgeFascia", "UndersideRibs", "CloudDeck", "DistantMesas", "EdgePosts", "DeckInlays"]:
		_t.check("required summit piece " + label, dress.get_node_or_null(label) != null)
	var island := dress.get_node("SummitIsland") as MeshInstance3D
	var bounds: AABB = island.transform * island.mesh.get_aabb()
	_t.near("summit spans the unchanged fighting diameter", bounds.size.x, 72.0)
	_t.near("summit has the unchanged fighting depth", bounds.size.z, 72.0)
	_t.near("stone top stays below the telegraph drawing", bounds.end.y, 0.02)
	_t.check("keels make the island read below its edge", bounds.position.y <= -15.0)
	var rim := dress.get_node("EdgeFascia") as MultiMeshInstance3D
	var rim_inside := true
	var rim_flat := true
	var fascia_exposed := false
	var rim_arrays := rim.multimesh.mesh.surface_get_arrays(0)
	for placed: Transform3D in rim.get_meta("placements"):
		for point: Vector3 in rim_arrays[Mesh.ARRAY_VERTEX]:
			var at: Vector3 = placed * point
			rim_inside = rim_inside and (at.y < 0.0 or Vector2(at.x, at.z).length() <= 36.0)
			rim_flat = rim_flat and at.y <= 0.03
			fascia_exposed = fascia_exposed or (at.y < -0.5 and Vector2(at.x, at.z).length() > 36.05)
	_t.check("fascia implies no walkable surface beyond the collider", rim_inside)
	_t.check("fascia leaves the whole fight top flat", rim_flat)
	_t.check("lower fascia stands outside the opaque stone wall", fascia_exposed)
	var clouds := dress.get_node("CloudDeck") as MultiMeshInstance3D
	_t.eq("cloud banks surround the summit", clouds.multimesh.instance_count, 36)
	_t.check("cloud banks stay below and outside combat", _sky_clear(clouds, true))
	var mesas := dress.get_node("DistantMesas") as MultiMeshInstance3D
	_t.eq("seven far mesas surround the summit", mesas.multimesh.instance_count, 7)
	_t.check("mesas remain beyond the fight and its buffer", _sky_clear(mesas, false))
	_deck_checks(dress)


# W49-MAPS Crown Sky-Deck (rubric B6): the inlays lie flush under the telegraph drawing (hazard.gd DRAW_LIFT 0.08)
# inside the fight circle, in muted copper and iron: never HAZARD-bright, never the Kindness purple, never lit. The
# posts stand wholly outside the 36 m collider so no ball rolls through one.
func _deck_checks(dress: Node3D) -> void:
	var inlays := dress.get_node("DeckInlays") as MeshInstance3D
	var arrays := inlays.mesh.surface_get_arrays(0)
	var flush := true
	var inside := true
	for point: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
		flush = flush and point.y > 0.02 and point.y < 0.08
		inside = inside and Vector2(point.x, point.z).length() <= 36.0
	_t.check("inlays lie between the stone top and the telegraph drawing", flush)
	_t.check("inlays stay inside the fight circle", inside)
	var muted := true
	for c: Color in arrays[Mesh.ARRAY_COLOR]:
		var hue := c.h * 360.0
		var purple := c.s > 0.2 and hue >= 300.0 and hue <= 330.0
		var near_hazard := c.s > 0.5 and c.v > 0.7 and (hue < 25.0 or hue > 350.0)
		muted = muted and c.v <= 0.55 and c.s <= 0.6 and not purple and not near_hazard
	_t.check("inlays are muted copper and iron, not HAZARD or Kindness", muted)
	var material := inlays.mesh.surface_get_material(0) as BaseMaterial3D
	_t.check("inlays carry no emission", material != null and not material.emission_enabled)
	var posts := dress.get_node("EdgePosts") as MultiMeshInstance3D
	var post_points := posts.multimesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var outside := true
	for placed: Transform3D in posts.get_meta("placements"):
		for point: Vector3 in post_points:
			var at: Vector3 = placed * point
			outside = outside and Vector2(at.x, at.z).length() > 36.0
	_t.eq("posts ring the open deck edge", posts.multimesh.instance_count, Dress.POST_COUNT)
	_t.check("every post stands outside the 36 m collider", outside)


func _sky_clear(view: MultiMeshInstance3D, clouds: bool) -> bool:
	var arrays := view.multimesh.mesh.surface_get_arrays(0)
	for placed: Transform3D in view.get_meta("placements"):
		for point: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
			var at: Vector3 = placed * point
			if Vector2(at.x, at.z).length() < (56.0 if clouds else 336.0) \
				or (clouds and (at.y > -50.0 or view.to_global(at).y > -20.0)):
				return false
	return true


func _colliders(parent: Node) -> Dictionary:
	var shapes := {}
	for shape: CollisionShape3D in parent.find_children("*", "CollisionShape3D", true, false):
		if shape.is_queued_for_deletion() or shape.get_parent().is_queued_for_deletion():
			continue
		var owner = shape.get_parent()
		var data := {"transform": shape.global_transform, "local": shape.transform, "disabled": shape.disabled,
			"shape": shape.shape, "layer": owner.collision_layer, "mask": owner.collision_mask}
		shapes[shape.get_instance_id()] = data
	return shapes


func _sun() -> DirectionalLight3D:
	for light: DirectionalLight3D in _game.find_children("*", "DirectionalLight3D", true, false):
		if light.name != "SkyFill":
			return light
	return null


func _environment() -> Dictionary:
	var env: Environment = _game.ctx.terrain.environment
	return {"sky": env.sky, "ambient": env.ambient_light_color, "exposure": env.tonemap_exposure,
		"saturation": env.adjustment_saturation, "sun_color": _sun().light_color, "sun_rotation": _sun().rotation}


func _assert_environment(label: String, saved: Dictionary) -> void:
	var now := _environment()
	for key in saved:
		_t.check(label + " " + key, now[key] == saved[key])


func _check_colliders(label: String) -> void:
	var after := _colliders(_game)
	_t.check(label, after == _before, "%d before, %d after; compare shape identity, local/global transforms, enabled state and layers" % [_before.size(), after.size()])


func _finish() -> void:
	Dress.dir = Dress.DIR
	_game.free()
	quit(_t.verdict())
