# 2026-10-12, W13 smoke triage: class c re-pin for ea699dc.
# freed pilot clip big_cheer -> unlock; PE-0 rescue action keeps the 2.1 m position pin.
extends SceneTree

const Game := preload("res://src/game.gd")
const Site := preload("res://src/world/rescue_site.gd")
const T := preload("res://tests/support/t.gd")
const Palette := preload("res://src/core/palette.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var t := T.new("rescue_state_read_test")
	var game := Game.new()
	game.test_mode = true
	game.table = "alpha"
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.ctx.calm = true
	game.flow.enter_stage(1, Vector3.ZERO, false)
	var cage = game.world.rescue.cage("rivet")
	var gate := cage.find_child("CageGate", true, false) as MeshInstance3D
	t.check("all imprisoning walls belong to the retracting gate", gate != null and gate.mesh.get_aabb().size.z >= 2.8)
	# A per-cage light is freed on every stage change; Godot 4.7.2's renderer then
	# segfaults on the next sealed boss entry (GPU only). The signal carries the glow.
	t.check("cage adds no dynamic light", cage.find_children("*", "Light3D", true, false).is_empty())
	t.check("model locked gate covers the cage face", _span_z(cage, gate)[1] >= 1.3 and _span_z(cage, gate)[0] <= -1.3, "z span %s" % [_span_z(cage, gate)])
	var locked_colour: Color = cage._signal.albedo_color
	var locked_position: Vector3 = cage._pilot.position
	cage.fire()
	cage.tick(Site.BREAK_SECONDS * 0.5)
	t.check("freeing lifts bars before rescue completes", cage._bars.position.y >= 0.3 and cage._bars.visible and not cage.spent)
	t.check("freeing changes latch colour", cage._signal.albedo_color != locked_colour)
	t.check("freeing raises pilot silhouette", cage._pilot.position.y >= locked_position.y + 0.15)
	t.check("freeing signal glows for active rescue", cage._signal.emission_energy_multiplier >= 1.5)
	cage.tick(Site.BREAK_SECONDS * 0.5)
	t.check("freed gate opens the exit and the locked bars are hidden", cage._open_walls.visible and not cage._bars.visible)
	# The pilot now eases out over FREE_MOVE instead of teleporting; step the tween to its end.
	t.check("freed pilot eases out rather than teleporting", cage._free_tween != null and cage._pilot.position.z < 2.1)
	cage._free_tween.custom_step(Site.FREE_MOVE + 0.1)
	t.check("freed pilot clears the frame", is_equal_approx(cage._pilot.position.z, 2.1) and cage._animator.assigned_animation == "unlock",
		"position %s pose %s" % [cage._pilot.position, cage._animator.assigned_animation])
	t.check("freed gate folds down toward the exit", cage._freed_wall != null and absf(cage._freed_wall.rotation.x) > deg_to_rad(60.0))
	var outer_top := Vector3.ZERO
	for mesh: MeshInstance3D in cage._freed_wall.find_children("*", "MeshInstance3D", true, false):
		if mesh.position.y > 2.9:
			outer_top = cage.to_local(mesh.global_position)
	t.check("folded wall points out through the exit face", outer_top.z > 3.9, "top edge %s" % outer_top)
	var gate_low := Vector3(INF, INF, INF)
	var gate_high := -gate_low
	for wall_mesh: MeshInstance3D in cage._freed_wall.find_children("*", "MeshInstance3D", true, false):
		var gate_bounds := wall_mesh.get_aabb()
		for x in [gate_bounds.position.x, gate_bounds.end.x]:
			for y in [gate_bounds.position.y, gate_bounds.end.y]:
				for z in [gate_bounds.position.z, gate_bounds.end.z]:
					var corner: Vector3 = cage.to_local(wall_mesh.global_transform * Vector3(x, y, z))
					gate_low = gate_low.min(corner)
					gate_high = gate_high.max(corner)
	t.check("folded gate rests beside the cage floor", gate_low.y >= -0.05 and gate_high.y <= 0.3,
		"gate Y %.2f..%.2f" % [gate_low.y, gate_high.y])
	t.check("freed signal keeps a completion glow", cage._signal.emission == Palette.ARC and cage._signal.emission_energy_multiplier >= 0.7 and cage._signal.emission_energy_multiplier <= 1.2)
	t.check("presentation adds no colliders", cage.find_children("*", "CollisionObject3D", true, false).is_empty())
	t.eq("rescue radius unchanged", Site.RING_RADIUS, 4.0)
	t.eq("rescue hold unchanged", Site.BREAK_SECONDS, 2.0)
	Site.model_path = "res://assets/models/world_one/does_not_exist.glb"
	game.world.rescue._done.clear()
	game.flow.enter_stage(1, Vector3.ZERO, false)
	var grey = game.world.rescue.cage("rivet")
	t.check("greybox build ran", grey != null and grey._model_gate == null and grey._latch == null)
	if grey != null:
		t.check("greybox locked gate sits on the cage face", absf(_span_z(grey, grey._freed_wall).reduce(func(a, b): return a + b) * 0.5 - 1.4) <= 0.1, "z span %s" % [_span_z(grey, grey._freed_wall)])
	Site.model_path = Site.MODEL
	game.free()
	quit(t.verdict())


func _span_z(space: Node3D, node: Node) -> Array:
	var low := Vector3(INF, INF, INF)
	var high := -low
	var meshes: Array = node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		meshes.append(node)
	for view: MeshInstance3D in meshes:
		var bounds := view.mesh.get_aabb()
		for x in [bounds.position.x, bounds.end.x]:
			for y in [bounds.position.y, bounds.end.y]:
				for z in [bounds.position.z, bounds.end.z]:
					var corner: Vector3 = space.to_local(view.global_transform * Vector3(x, y, z))
					low = low.min(corner)
					high = high.max(corner)
	return [low.z, high.z]
