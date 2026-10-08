extends SceneTree

const Game := preload("res://src/game.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")
const T := preload("res://tests/support/t.gd")

var t := T.new("arena_vx8_test")
var game


func _initialize() -> void:
	game = Game.new()
	game.test_mode = true
	root.add_child(game)
	_run.call_deferred()


func _run() -> void:
	while game.flow == null:
		await physics_frame
	game.ctx.calm = true
	Harness.start_run(game)
	Harness.enter(game, Vector3(18, 0, 0))
	await physics_frame
	var arena: Node3D = game.boss.arena
	t.check("Brindle bowl enters", arena != null)
	if arena != null:
		var ramps := arena.find_children("*", "MeshInstance3D", true, false).filter(func(n): return n.get_meta("bowl_surface", "") in ["Ramp", "Kicker"])
		t.eq("all four ramps and kickers use the copper family without hazard checker", ramps.size(), 4)
		for view: MeshInstance3D in ramps:
			t.check("bowl ramp is not hazard striped", not (view.material_override is BaseMaterial3D and view.material_override.get_meta("greybox_checker", false)), String(view.name))
		var crossbar: MeshInstance3D
		for child in arena.get_children():
			if child is MeshInstance3D and child.get_meta("bowl_surface", "") == "Crossbar":
				crossbar = child
		t.check("rig panel uses the copper material row", crossbar != null and crossbar.material_override.resource_name == "bowl_crane_masts")
	game.free()
	quit(t.verdict())
