extends SceneTree

const Game := preload("res://src/game.gd")
const Palette := preload("res://src/core/palette.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")

# C12's original 1,200 triangle / four-draw limit gains two draws when WG splits
# the top disc's paint and core surfaces. Triangle and opacity bounds stay fixed.
# Collider, pit, hold, timing and damage-side values remain the pre-dressing contract.
const CEILING_T := 5200  # polished 2026-10-18 (tools/blender/POLISH.md); was 1200
const CEILING_D := 6 # Independent top disc adds two surfaces; geometry stays unchanged.
# The live assembly adds MagTopLink, the mast from the stack to the lifted disc (PC): one more draw than the asset.
const LIVE_CEILING_D := 7
const CORE_EMISSION := 0.6
const BASE_CONSTS := {
	"PIT_RADIUS": 4.5, "PIT_REACH": 1.4, "LEAD": 0.7, "CENTRE_PULL": 2.5,
	"RATING_BASE": 1.6, "RATING_PER_THREAT": 0.4, "HP": 50.0,
}
const BASE_LIVE := {
	"warn_seconds": 1.1, "live_seconds": 3.0, "rest_seconds": 3.5, "attack_range": 26.0,
	"weight": 1.2, "scrap_value": 4, "radius": 0.8, "half_height": 1.1,
}
var failures := 0
var game


func _initialize() -> void:
	game = Game.new()
	game.test_mode = true
	root.add_child(game)
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
	print("%s %s" % ["PASS" if ok else "FAIL", label])


func _measure(node: Node) -> Dictionary:
	var tris := 0
	var draws := 0
	var alpha := false
	var meshes := 0
	for m in node.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		meshes += 1
		for s in mi.mesh.get_surface_count():
			draws += 1
			var arrays := mi.mesh.surface_get_arrays(s)
			var idx = arrays[Mesh.ARRAY_INDEX]
			var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			tris += (idx.size() if idx != null else vs.size()) / 3
			var mat := mi.get_surface_override_material(s)
			if mat == null:
				mat = mi.material_override
			if mat == null:
				mat = mi.mesh.surface_get_material(s)
			if mat is BaseMaterial3D and (mat as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				alpha = true
	return {"tris": tris, "draws": draws, "alpha": alpha, "meshes": meshes}


func _run() -> void:
	var packed := load("res://assets/models/world_one/enemy_mag_trapper.glb") as PackedScene
	_check(packed != null, "enemy_mag_trapper.glb loads")
	if packed == null:
		quit(1)
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	var m := _measure(scene)
	print("asset: %d T, %d D" % [m["tris"], m["draws"]])
	_check(m["tris"] <= CEILING_T and m["tris"] > 0, "asset triangles %d <= %d" % [m["tris"], CEILING_T])
	_check(m["draws"] <= CEILING_D, "asset draws %d <= %d" % [m["draws"], CEILING_D])
	_check(m["tris"] >= 4872 * 0.9 and m["tris"] <= 4872 * 1.1, "WG-8 triangles within 10 percent of baseline 4872 (polished; was 760)")
	for node_name in ["MagTrapperBody", "MagDiscs", "MagTopDisc"]:
		var part := scene.find_child(node_name, true, false) as MeshInstance3D
		_check(part != null, "named asset node " + node_name)
		if part != null:
			var slots := []
			for i in part.mesh.get_surface_count():
				slots.append(part.mesh.surface_get_material(i).resource_name)
			slots.sort()
			_check(slots == (["fleet_paint", "paint"] if node_name == "MagTrapperBody" else ["class_accent", "paint"]), "named surfaces " + node_name)
	var asset_stack := scene.find_child("MagStack", true, false)
	var asset_top := scene.find_child("MagTopDisc", true, false)
	_check(asset_stack != null and asset_top != null and asset_stack.is_ancestor_of(asset_top), "top disc below preserved MagStack")
	_check(not m["alpha"], "asset has no alpha surface")
	scene.free()
	if failures > 0:
		print("enemy_mag_trapper_asset_test: FAIL (asset contract)")
		quit(1)
		return

	game.ctx.calm = true
	var trapper: Node3D = game.ctx.spawner.spawn_enemy("mag_trapper", Vector3(0, 30, 0))
	await process_frame
	_check(trapper != null, "a mag trapper spawns")
	if trapper == null:
		quit(1)
		return
	trapper.set_physics_process(false)
	var shapes := trapper.find_children("*", "CollisionShape3D", true, false)
	_check(shapes.size() == 1, "one collision shape on the trapper (%d)" % shapes.size())
	var capsule := (shapes[0] as CollisionShape3D).shape as CapsuleShape3D if shapes.size() > 0 else null
	_check(capsule != null and is_equal_approx(capsule.radius, 0.8) and is_equal_approx(capsule.height, 2.2),
		"collider is the base capsule, radius 0.8 height 2.2")
	_check(trapper.find_children("*", "Area3D", true, false).is_empty() and trapper.find_children("*", "CollisionObject3D", true, false).is_empty(),
		"the dressing adds no collision object")
	var consts: Dictionary = (trapper.get_script() as Script).get_script_constant_map()
	var same := true
	for key in BASE_CONSTS:
		if not consts.has(key) or not is_equal_approx(float(consts[key]), float(BASE_CONSTS[key])):
			same = false
			print("  constant %s is %s, base %s" % [key, consts.get(key), BASE_CONSTS[key]])
	_check(same, "pit (4.5 / 1.4 / lead 0.7), hold and rating constants equal base")
	same = true
	for key in BASE_LIVE:
		if not is_equal_approx(float(trapper.get(key)), float(BASE_LIVE[key])):
			same = false
			print("  %s is %s, base %s" % [key, trapper.get(key), BASE_LIVE[key]])
	_check(same, "warn 1.1 / live 3.0 / rest 3.5, range 26, weight, scrap, radius and half-height equal base")

	var live := _measure(trapper)
	print("live assembly: %d T, %d D, %d meshes" % [live["tris"], live["draws"], live["meshes"]])
	_check(trapper.find_child("MagTrapperBody", true, false) != null, "the live trapper carries its MagTrapperBody dressing")
	_check(live["meshes"] > 0 and live["tris"] > 0, "the live measurement saw meshes (the check runs)")
	_check(live["tris"] <= CEILING_T and live["draws"] <= LIVE_CEILING_D, "live assembly %d T / %d D within %d / 7" % [live["tris"], live["draws"], CEILING_T])
	_check(not live["alpha"], "live assembly has no alpha")

	# The hazard cores glow at 0.6, read from the live material; a hit through the existing
	# event (enemy.flash()) changes the disc-bearing material's colour for the flash window,
	# then the rest look returns.
	var discs: MeshInstance3D = trapper.find_child("MagDiscs", true, false)
	_check(discs != null and discs.mesh.get_surface_count() == 2, "MagDiscs has two surfaces (discs, cores)")
	if discs != null:
		var core_energy := -1.0
		var disc_mat: StandardMaterial3D = null
		for i in discs.mesh.get_surface_count():
			var mat := discs.get_active_material(i) as StandardMaterial3D
			if mat != null and mat.emission_enabled and mat.emission.is_equal_approx(Palette.HAZARD):
				core_energy = mat.emission_energy_multiplier
			elif mat != null and mat.vertex_color_use_as_albedo:
				disc_mat = mat
		_check(is_equal_approx(core_energy, CORE_EMISSION), "hazard-core surface emission is 0.6 (live %.2f)" % core_energy)
		_check(disc_mat != null, "the disc surface is its own vertex-colour material")
		if disc_mat != null:
			var rest_colour := disc_mat.albedo_color
			_check(not disc_mat.emission_enabled, "discs do not glow at rest")
			trapper.flash()
			trapper._update_flash(0.02)
			_check(disc_mat.albedo_color != rest_colour and disc_mat.emission_enabled and disc_mat.emission_energy_multiplier > 1.0,
				"a hit flashes the disc material (emission %.2f)" % disc_mat.emission_energy_multiplier)
			_check(disc_mat.emission.is_equal_approx(EventKinds.role_color("neutral")),
				"the disc flash glows neutral, not amber (%s)" % disc_mat.emission.to_html(false))
			trapper._update_flash(1.0)
			_check(disc_mat.albedo_color == rest_colour and not disc_mat.emission_enabled, "the disc material restores after the flash window")
			var other: Node3D = game.ctx.spawner.spawn_enemy("mag_trapper", Vector3(20, 30, 0))
			other.set_physics_process(false)
			var other_mat := (other.find_child("MagDiscs", true, false) as MeshInstance3D).get_active_material(0) as StandardMaterial3D
			var other_disc: StandardMaterial3D = other_mat if other_mat.vertex_color_use_as_albedo else (other.find_child("MagDiscs", true, false) as MeshInstance3D).get_active_material(1) as StandardMaterial3D
			trapper.flash()
			trapper._update_flash(0.02)
			_check(other_disc != disc_mat and not other_disc.emission_enabled, "a hit on one trapper leaves another's discs alone")

	# E05 e05_stack_hoist retains two discs while the top disc is thrown.
	var stack: Node3D = trapper.find_child("MagStack", true, false)
	var top: Node3D = trapper.find_child("MagTopDisc", true, false)
	_check(stack != null and top != null, "MagStack and independent MagTopDisc exist")
	if stack != null and top != null:
		trapper.phase = 1
		trapper._t = trapper.warn_seconds
		trapper._pose()
		_check(top.visible and stack.transform.basis == Basis.IDENTITY, "top disc hoists while the remaining stack stays upright")
		trapper.phase = 2
		trapper._t = 0.0
		trapper._pose()
		_check(not top.visible and stack.visible and discs.visible, "only the thrown top disc hides while the pit is live")
		trapper.phase = 0
		trapper._pose()
		_check(top.visible, "stack is whole again at rest")
	print("enemy_mag_trapper_asset_test: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
