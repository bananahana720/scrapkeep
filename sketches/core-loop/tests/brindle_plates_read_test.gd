extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")
const InkOutline := preload("res://src/presentation/ink_outline.gd")
const Palette := preload("res://src/core/palette.gd")

# Brindle's armour plates (W1-48, visual-assets-audit.md finding 7). Three pins:
#
# 1. The plating tint replaces only the plate's slab surface. The bands, rivets, brass tag
#    and scrapes sit on a second surface the tint leaves alone (even when InkOutline wraps
#    it in an inked twin override), so a plate is never a blank slab of slate or amber.
# 2. A hit lifts the plates in their own tint. The old flash drew every plate near white
#    under steady fire (PC film 0124), so slate and amber, the plating read, looked the same.
# 3. A vent cap has no tint, so its hit stays a white pop, and an open cap's hazard glow
#    comes back after the hit (it used to go dark on the first hit).
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


# Surface 1 carries the plate's fittings (bands, rivets, brass tag, scrapes). InkOutline may
# attach a Warden ink pass through a surface-1 override twin of the mesh's material, so the
# invariant is that surface 1 is never a hull tint material and keeps its base vertex-colour
# material properties intact.
func _fittings_untinted(panel: MeshInstance3D, hull) -> bool:
	if panel == null or panel.mesh == null or panel.mesh.get_surface_count() < 2:
		return false
	var base := panel.mesh.surface_get_material(1) as StandardMaterial3D
	var active := panel.get_active_material(1) as StandardMaterial3D
	if base == null or active == null or hull._tint_materials.has(active):
		return false
	var override: Material = panel.get_surface_override_material(1)
	if override != null:
		if hull._tint_materials.has(override):
			return false
		if InkOutline.strip(override) != base or override.next_pass == null or override.next_pass.get_meta("ink_role", "") != "boss":
			return false
	return (active.vertex_color_use_as_albedo and active.vertex_color_use_as_albedo == base.vertex_color_use_as_albedo
		and active.albedo_color.is_equal_approx(Color.WHITE) and active.albedo_color.is_equal_approx(base.albedo_color)
		and is_equal_approx(active.roughness, base.roughness) and is_equal_approx(active.metallic, base.metallic)
		and not active.emission_enabled and active.emission_enabled == base.emission_enabled)


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
		var kept_ok := _fittings_untinted(panel, hull)
		var kept: Material = panel.get_active_material(1) if panel.mesh.get_surface_count() > 1 else null
		var ink_role := str(kept.next_pass.get_meta("ink_role", "")) if kept != null and kept.next_pass != null else ""
		var detail := _colours(panel.mesh, 1) if panel.mesh.get_surface_count() > 1 else {}
		_report("plate %d keeps its fittings under the tint" % i,
			tinted != null and hull._tint_materials.has(tinted) and kept_ok
			and int(detail.get("count", 0)) >= 200 and float(detail.get("darkest", 1.0)) < 0.1 and bool(detail.get("brass", false)),
			"surfaces %d, slab tinted %s, fittings untinted %s, ink %s, fittings %s" % [panel.mesh.get_surface_count(),
				tinted != null, kept_ok, ink_role if ink_role != "" else "none", detail])
	var fittings_under_tint_ok := true
	for state in ["slate", "amber"]:
		# Combat's tint loop re-tints the hull every frame, so the hit is read in one step.
		hull.set_tint(state)
		hull.flash()
		hull._process(0.01)
		var mat := (plates[0] as MeshInstance3D).get_surface_override_material(0) as StandardMaterial3D
		var lit: Color = mat.albedo_color + mat.emission * mat.emission_energy_multiplier
		var hue_kept := mat.emission.is_equal_approx(mat.albedo_color)
		var reads := (lit.b > lit.r) if state == "slate" else (lit.r > lit.b * 1.5)
		_report("a hit keeps the %s read" % state, mat.emission_enabled and hue_kept and mat.emission_energy_multiplier > 0.0
			and mat.emission_energy_multiplier <= 1.0 and reads,
			"albedo %s, emission %s x %.2f, lit %s" % [mat.albedo_color.to_html(false), mat.emission.to_html(false),
				mat.emission_energy_multiplier, lit.to_html(false)])
		for panel: MeshInstance3D in plates:
			fittings_under_tint_ok = fittings_under_tint_ok and _fittings_untinted(panel, hull)
		for _i in 20:
			await process_frame
	_report("fittings stay untinted under slate/amber tint and flash", fittings_under_tint_ok,
		"all 4 plates untinted %s" % fittings_under_tint_ok)
	# Negative verification: overwriting surface 1 with a hull tint material must fail the fittings check.
	var probe: MeshInstance3D = plates[0]
	var saved_fittings: Material = probe.get_surface_override_material(1)
	probe.set_surface_override_material(1, hull._tint_materials[0])
	var caught := not _fittings_untinted(probe, hull)
	probe.set_surface_override_material(1, saved_fittings)
	var restored := _fittings_untinted(probe, hull)
	_report("overwriting fittings with a tint material fails the check", caught and restored,
		"caught %s, restored %s" % [caught, restored])
	# Reduce flashes keeps a smaller lift in the same hue.
	FlashGuard.on = true
	hull.set_tint("slate")
	hull.flash()
	hull._process(0.01)
	var calm := (plates[0] as MeshInstance3D).get_surface_override_material(0) as StandardMaterial3D
	_report("reduce flashes keeps a hit in the tint", calm.emission_enabled and calm.emission.is_equal_approx(calm.albedo_color)
		and calm.emission_energy_multiplier > 0.0 and calm.emission_energy_multiplier < 0.7, "energy %.2f" % calm.emission_energy_multiplier)
	FlashGuard.on = false
	hull._process(1.0)
	var cap = ship.caps[0]
	ship.open_caps(true)
	var cap_mat := cap._tint_materials[0] as StandardMaterial3D
	cap.flash()
	cap._process(0.01)
	var popped := cap_mat.emission_enabled and cap_mat.emission == Color.WHITE and cap_mat.emission_energy_multiplier >= 1.0
	cap._process(1.0)
	var back := cap_mat.emission_enabled and cap_mat.emission == Palette.HAZARD and is_equal_approx(cap_mat.emission_energy_multiplier, 1.2)
	_report("a cap pops white and an open cap keeps its glow", popped and back,
		"popped %s, after %s x %.2f on %s" % [popped, cap_mat.emission.to_html(false), cap_mat.emission_energy_multiplier, cap_mat.emission_enabled])
	ship.open_caps(false)
	_report("a shut cap goes dark", not cap_mat.emission_enabled, "emission %s" % cap_mat.emission_enabled)
	print("brindle_plates_read_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
