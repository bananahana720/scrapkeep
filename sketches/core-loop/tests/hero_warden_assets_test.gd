extends SceneTree

const Game := preload("res://src/game.gd")
const Warden := preload("res://src/combat/warden.gd")

var game
var ticks := 0
var failures := 0
var prior_base: Node3D
var prior_id := 0
var dead_ids: Array[int] = []


func _initialize() -> void:
	game = Game.new()
	game.test_mode = true
	root.add_child(game)


func check(label: String, ok: bool) -> void:
	print("[%s] %s" % [label, "PASS" if ok else "FAIL"])
	if not ok:
		failures += 1


func _physics_process(_delta: float) -> bool:
	if game.flow == null:
		return false
	ticks += 1
	if ticks == 1:
		game.ctx.calm = true
		game.flow.force_warden = true
		game.flow.press_start()
		game.flow.choose_class(0)
	if ticks in [5, 15, 25]:
		check_family()
	if ticks in [10, 20]:
		game.flow.enter_stage(2 if ticks == 10 else 3, Vector3.ZERO, false)
	if ticks == 30:
		var hook = game.presentation.hero_assets
		var warden = game.flow.warden
		var rec: Dictionary = hook.warden_of(warden)
		for id in dead_ids:
			check("dead Warden record cleaned", not hook._wardens.has(id))
		var preserved: Array = rec.hidden.duplicate()
		hook.get_parent().remove_child(hook)
		hook.queue_free()
		for entry in preserved:
			check("restore placeholder layers and shadow", entry.mesh.layers == entry.layers and entry.mesh.cast_shadow == entry.shadow)
	if ticks == 32:
		check("restored hero freed", not is_instance_valid(prior_base))
		print("hero_warden_assets_test: %s" % ("PASS" if failures == 0 else "FAIL"))
		quit(0 if failures == 0 else 1)
	return false


func check_family() -> void:
	var hook = game.presentation.hero_assets
	var warden = game.flow.warden
	var rec: Dictionary = hook.warden_of(warden)
	check("automatic attach " + warden.family, not rec.is_empty())
	if rec.is_empty():
		return
	if prior_id != 0:
		check("stage cleanup", not is_instance_valid(prior_base) and not hook._wardens.has(prior_id))
	prior_base = rec.base
	prior_id = warden.get_instance_id()
	hook._dress_warden(warden)
	check("idempotent attachment", hook.warden_of(warden).base == rec.base and warden.find_children("HeroWarden", "", false, false).size() == 1)
	var shapes: Array = warden.find_children("*", "CollisionShape3D", true, false)
	check("original collider only", shapes.size() == 1 and is_equal_approx(shapes[0].shape.radius, Warden.RADIUS) and is_equal_approx(shapes[0].shape.height, Warden.HALF_HEIGHT * 2.0))
	check("mount meets kit", rec.base.get_node("Tower/KitMount").global_position.distance_to(rec.kit.global_position) < 0.0001)
	for angle in [0.0, 0.7, -2.4]:
		warden._look._jaws.rotation.y = angle
		hook._update_warden(rec)
		check("world weak point " + str(angle), rec.weak.global_position.distance_to(warden.family_point_at()) < 0.0001)
	check_geometry(rec.base, rec.base)
	var authored: Node3D = hook._warden_scene(hook.WARDEN_BASE)
	check("jaw meshes and hinges unchanged", authored.get_node("JawL").mesh == rec.base.get_node("JawL").mesh and authored.get_node("JawR").transform == rec.base.get_node("JawR").transform)
	var tower: MeshInstance3D = rec.base.get_node("Tower")
	var low_unchanged := true
	var joint_distance := INF
	for surface in tower.mesh.get_surface_count():
		var old_arrays: Array = authored.get_node("Tower").mesh.surface_get_arrays(surface)
		var new_arrays: Array = tower.mesh.surface_get_arrays(surface)
		for i in new_arrays[Mesh.ARRAY_VERTEX].size():
			var old_v: Vector3 = old_arrays[Mesh.ARRAY_VERTEX][i]
			var new_v: Vector3 = new_arrays[Mesh.ARRAY_VERTEX][i]
			if old_v.y <= 2.2:
				low_unchanged = low_unchanged and old_v == new_v
			joint_distance = minf(joint_distance, (new_v + tower.position).distance_to(rec.kit.position))
	check("lower tower unchanged", low_unchanged)
	check("tower geometry reaches kit joint", joint_distance < 0.5)
	authored.free()
	for entry in rec.hidden:
		check("placeholder hidden without deletion", is_instance_valid(entry.mesh) and entry.mesh.layers == 0 and entry.mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	check("badge remains", warden._look._badge.visible)
	if warden.lesson == "caps":
		check("lesson caps remain", warden._look.cap_material() == warden._cap_material and warden.cap_points().size() == 3)
	if warden.lesson == "magnet":
		warden.magnet_state = Warden.Magnet.TUG
		warden._magnet_time = 0.3
		warden._look.update(0.0)
		check("magnet cue remains", warden._look._arm.layers != 0 and warden._look._head.visible)
		check("mind icon remains", is_instance_valid(warden._kit._icon) and warden._kit._icon.get_parent() == warden._kit._lens)
	var other := Warden.new()
	game.add_child(other)
	other.position = warden.position + Vector3(20, 0, 0)
	other.setup(game.player, game.ctx.terrain, game, func(): return true, 1.0, {"family": warden.family, "stage": warden.stage, "lesson": warden.lesson})
	hook._dress_warden(other)
	var second: Dictionary = hook.warden_of(other)
	check("independent materials", rec.materials.ancient_light != second.materials.ancient_light and rec.materials.ancient_enamel != second.materials.ancient_enamel and rec.materials.ancient_light_jaw != second.materials.ancient_light_jaw)
	check("independent tower mesh", rec.base.get_node("Tower").mesh != second.base.get_node("Tower").mesh)
	warden._open_left = 2.0
	warden._brace_left = 2.0
	warden._kit.update(0.0)
	hook._update_warden(rec)
	check("weak point opening", rec.weak.scale.is_equal_approx(Vector3.ONE * 1.3) and rec.materials.ancient_light.emission_energy_multiplier == warden._kit.SEAM_OPEN)
	check("other stays closed", second.weak.scale.is_equal_approx(Vector3.ONE) and is_equal_approx(second.materials.ancient_light.emission_energy_multiplier, other._kit.SEAM_DIM))
	warden.set_tint("amber")
	hook._update_warden(rec)
	check("plating rim and crack", rec.materials.ancient_light_jaw.emission == warden.rim_color and rec.cracks[0].visible)
	warden.shred = warden.plating * 0.8
	warden._look.update(0.0)
	hook._update_warden(rec)
	check("shred follows source", rec.seams[0].node.visible == rec.seams[0].source.visible)
	warden.flash()
	warden._update_flash(0.01)
	hook._update_warden(rec)
	check("damage flash isolated", rec.materials.ancient_enamel.emission_enabled and not second.materials.ancient_enamel.emission_enabled)
	var point: Vector3 = warden.family_point_at()
	check("open weak point hit contract", warden.plating_for("runner", warden.family_point()) == 0.0 and warden.weak_points().any(func(p): return p.id == warden.family_point() and p.at == point))
	warden._open_left = 0.0
	warden._brace_left = 0.0
	warden._kit.update(0.0)
	hook._update_warden(rec)
	check("weak point recloses", rec.weak.scale.is_equal_approx(Vector3.ONE))
	dead_ids.append(other.get_instance_id())
	other._die()


func check_geometry(node: Node3D, base: Node3D) -> void:
	check("finite nonsingular " + node.name, node.transform.is_finite() and absf(node.transform.basis.determinant()) > 0.0001)
	if node is MeshInstance3D:
		var low_ok := true
		var finite := true
		var lower_max := 0.0
		for surface in node.mesh.get_surface_count():
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			for v in arrays[Mesh.ARRAY_VERTEX]:
				var at: Vector3 = base.to_local(node.to_global(v))
				finite = finite and at.is_finite()
				if at.y <= 2.0:
					lower_max = maxf(lower_max, Vector2(at.x, at.z).length())
					low_ok = low_ok and Vector2(at.x, at.z).length() <= 2.8001
			for normal in arrays[Mesh.ARRAY_NORMAL]:
				finite = finite and normal.is_finite() and normal.length() > 0.99
		check("finite vertices and normals " + node.name, finite)
		if not low_ok: print("LOWER_RADIUS ", node.name, " ", lower_max)
		check("lower collider envelope " + node.name, low_ok)
	for child in node.get_children():
		if child is Node3D:
			check_geometry(child, base)
