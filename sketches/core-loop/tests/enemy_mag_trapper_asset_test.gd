extends SceneTree

const Game := preload("res://src/game.gd")

# C12 limits. The asset: 1,200 T / 3 D ceiling for the whole moving assembly (crew, cart and
# discs), opaque. The base contract: the trapper's collider, pit (radius, reach, lead), hold
# (drag, pull, rating), timing and damage-side numbers are the values mag_trapper.gd had
# before the dressing swap, and the stack tilts on the existing wind-up.
const CEILING_T := 1200
const CEILING_D := 3
const BASE_CONSTS := {
	"PIT_RADIUS": 4.5, "PIT_REACH": 1.4, "LEAD": 0.7, "DRAG": 2.4, "CENTRE_PULL": 2.5,
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
	_check(not m["alpha"], "asset has no alpha surface")
	scene.free()

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
	_check(live["tris"] <= CEILING_T and live["draws"] <= CEILING_D, "live assembly %d T / %d D within 1200 / 3" % [live["tris"], live["draws"]])
	_check(not live["alpha"], "live assembly has no alpha")

	# The stack tilts on the existing wind-up: WARN's own progress, hidden while LIVE.
	var stack: Node3D = trapper.find_child("MagStack", true, false)
	_check(stack != null, "the stack pivot MagStack exists")
	if stack != null:
		trapper.phase = 0
		trapper._pose()
		var rest := stack.rotation.x
		trapper.phase = 1
		trapper._t = 0.0
		trapper._pose()
		var start := stack.rotation.x
		trapper._t = trapper.warn_seconds * 0.5
		trapper._pose()
		var half := stack.rotation.x
		trapper._t = trapper.warn_seconds
		trapper._pose()
		var full := stack.rotation.x
		print("stack tilt: rest %.3f, wind-up 0 %.3f, half %.3f, full %.3f rad" % [rest, start, half, full])
		_check(absf(rest) < 0.01 and absf(start) < 0.01, "the stack is upright at rest and at the start of the wind-up")
		_check(full < -0.3 and half < -0.05 and full < half, "the stack tilts back on wind-up, deeper as the warning runs (%.2f rad at full)" % full)
		_check(stack.visible, "the stack shows during the warning")
		trapper.phase = 2
		trapper._pose()
		_check(not stack.visible and absf(stack.rotation.x) < 0.001, "the stack is hidden and upright while the pit is live")
	print("enemy_mag_trapper_asset_test: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
