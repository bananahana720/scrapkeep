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
	t.check("all imprisoning walls belong to the retracting gate", gate.mesh.get_aabb().size.z >= 2.8)
	# A per-cage light is freed on every stage change; Godot 4.7.2's renderer then
	# segfaults on the next sealed boss entry (GPU only). The signal carries the glow.
	t.check("cage adds no dynamic light", cage.find_children("*", "Light3D", true, false).is_empty())
	var locked_colour: Color = cage._signal.albedo_color
	var locked_position: Vector3 = cage._pilot.position
	cage.fire()
	cage.tick(Site.BREAK_SECONDS * 0.5)
	t.check("freeing lifts bars before rescue completes", cage._bars.position.y >= 0.3 and cage._bars.visible and not cage.spent)
	t.check("freeing changes latch colour", cage._signal.albedo_color != locked_colour)
	t.check("freeing raises pilot silhouette", cage._pilot.position.y >= locked_position.y + 0.15)
	t.check("freeing signal glows for active rescue", cage._signal.emission_energy_multiplier >= 1.5)
	cage.tick(Site.BREAK_SECONDS * 0.5)
	t.check("freed gate is actually hidden in the tree", not gate.is_visible_in_tree() and not cage._bars.visible)
	t.check("freed pilot stands beyond the remaining frame", cage._pilot.position.z >= 1.7 and cage._animator.assigned_animation == "big_cheer")
	t.check("freed signal keeps a completion glow", cage._signal.emission == Palette.ARC and cage._signal.emission_energy_multiplier >= 0.7 and cage._signal.emission_energy_multiplier <= 1.2)
	t.check("presentation adds no colliders", cage.find_children("*", "CollisionObject3D", true, false).is_empty())
	t.eq("rescue radius unchanged", Site.RING_RADIUS, 4.0)
	t.eq("rescue hold unchanged", Site.BREAK_SECONDS, 2.0)
	game.free()
	quit(t.verdict())
