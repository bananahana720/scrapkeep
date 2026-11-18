extends SceneTree

const Game := preload("res://src/game.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")
const T := preload("res://tests/support/t.gd")
const Palette := preload("res://src/core/palette.gd")

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
		var rig := arena.find_children("*", "MeshInstance3D", true, false).filter(func(n): return n.get_meta("bowl_surface", "") in ["Mast", "Crossbar"])
		t.eq("the bowl has eight rig parts, masts and booms", rig.size(), 8)
		t.check("the masts and booms are the crane kit, not a cylinder and a box", rig.all(func(v): return not v.mesh is PrimitiveMesh))
		var nozzles := arena.find_children("VentNozzle_*", "MeshInstance3D", false, false)
		t.check("each rim vent has its nozzle model", nozzles.size() == 4 and nozzles.all(func(v): return not v.mesh is PrimitiveMesh), "%d nozzles" % nozzles.size())
		for view: MeshInstance3D in rig:
			# The masts and booms are weathered steel so they stand out from the copper ramps (pull request 1129).
			t.check("rig part is mast steel, not copper and not hazard striped", view.material_override is BaseMaterial3D
				and not view.material_override.get_meta("greybox_checker", false)
				and view.material_override.albedo_color == Palette.MAST_STEEL and Palette.MAST_STEEL != Palette.COPPER, String(view.name))
	game.free()
	quit(t.verdict())
