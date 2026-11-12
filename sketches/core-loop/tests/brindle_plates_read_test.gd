extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")

# Brindle's armour plates (W1-48, visual-assets-audit.md finding 7). Two pins:
#
# 1. The plating tint replaces only the plate's slab surface. The bands, rivets, brass tag
#    and scrapes sit on a second surface the tint leaves alone, so a plate is never a
#    blank slab of slate or amber.
# 2. A hit lifts the plates in their own tint. The old flash drew every plate near white
#    under steady fire (PC film 0124), so slate and amber, the plating read, looked the same.
#
# Evidence limit: materials and vertex colours are read through the nodes, not pixels. The
# look itself is judged from stills (the PR) and a PC still under fire.

var _game
var _failures := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


# The darkest and brightest vertex colours on a surface, by luminance, plus whether any is
# brass-like (red and green well above blue).
func _colours(mesh: Mesh, surface: int) -> Dictionary:
	var colours: PackedColorArray = mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR]
	var lo := 9.0
	var brass := false
	for c in colours:
		lo = minf(lo, c.get_luminance())
		brass = brass or (c.r > c.b * 2.0 and c.g > c.b * 1.5 and c.r > 0.3)
	return {"count": colours.size(), "darkest": lo, "brass": brass}


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	await physics_frame
	_game.ctx.spawner = _game.combat
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	Harness.start_run(_game)
	Harness.enter(_game, Vector3(18.0, 0.0, 0.0))
	for _i in 30:
		await process_frame
	var ship = _game.boss.ship
	if ship.model == null:
		_report("the model dresses the ship", false, "no BrindleModel")
		quit(1)
		return
	var hull = ship.hull
	var plates: Array = []
	for i in 4:
		plates.append(ship.model.find_child("Armour%d" % i, true, false) as MeshInstance3D)
	for i in plates.size():
		var panel: MeshInstance3D = plates[i]
		var tinted: Material = panel.get_surface_override_material(0)
		var kept: Material = panel.get_surface_override_material(1) if panel.mesh.get_surface_count() > 1 else null
		var detail := _colours(panel.mesh, 1) if panel.mesh.get_surface_count() > 1 else {}
		_report("plate %d keeps its fittings under the tint" % i,
			tinted != null and hull._tint_materials.has(tinted) and panel.mesh.get_surface_count() >= 2 and kept == null
			and int(detail.get("count", 0)) >= 200 and float(detail.get("darkest", 1.0)) < 0.1 and bool(detail.get("brass", false)),
			"surfaces %d, slab tinted %s, fittings %s" % [panel.mesh.get_surface_count(), tinted != null, detail])
	for state in ["slate", "amber"]:
		# Combat's tint loop re-tints the hull every frame, so the hit is read in one step.
		hull.set_tint(state)
		hull.flash()
		hull._process(0.01)
		var mat := (plates[0] as MeshInstance3D).get_surface_override_material(0) as StandardMaterial3D
		var lit: Color = mat.albedo_color + mat.emission * mat.emission_energy_multiplier
		var hue_kept := mat.emission.is_equal_approx(mat.albedo_color)
		var reads := (lit.b > lit.r) if state == "slate" else (lit.r > lit.b * 1.5)
		_report("a hit keeps the %s read" % state, mat.emission_enabled and hue_kept and mat.emission_energy_multiplier <= 1.0 and reads,
			"albedo %s, emission %s x %.2f, lit %s" % [mat.albedo_color.to_html(false), mat.emission.to_html(false),
				mat.emission_energy_multiplier, lit.to_html(false)])
		for _i in 20:
			await process_frame
	print("brindle_plates_read_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
