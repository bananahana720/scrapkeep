extends SceneTree

const Game := preload("res://src/game.gd")
const Palette := preload("res://src/core/palette.gd")

# C15 limits. The asset: 1,200 T / 3 D ceiling for the whole intact assembly (body plus the one
# plate group), opaque. The body stands inside the 0.8 m collider footprint and the 2.2 m
# capsule's height; the plate group stays within the base pads' reach (1.8 m) and under 1.3 m,
# above the collider floor. The base contract: the brute's collider, plate count, plate hit
# points, slam and timing constants are the values plated_brute.gd had before the dressing swap.
# The three crack strokes (PlateCrack, 12 T each, drawn only in amber) are base gameplay read,
# not counted, and hide with the plate group.
const CEILING_T := 5500  # polished 2026-10-18 (tools/blender/POLISH.md); was 1200
const CEILING_D := 3
const LIVE_CEILING_D := 3
# Plate group share of the 1,200 T ceiling: 416 T with the six trim strips (12 T each) that carry the amber cue.
const PLATE_T := 1300  # polished plates (bevelled, unsmoothed); was 450
const CREW_R := 0.8
const PLATE_REACH := 1.8
const Y_BOTTOM := -1.1
const BASE_CONSTS := {
	"PLATING_SCALE": 0.6, "SLAM_RADIUS": 6.0, "SLAM_RANGE": 6.5, "SLAM_DAMAGE": 12.0, "SLAM_SHOVE": 9.0, "HP": 110.0,
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


# Triangles, surfaces (colour-pass draws) and alpha of the meshes that render, the crack skipped.
func _measure(node: Node, visible_only := false) -> Dictionary:
	var tris := 0
	var draws := 0
	var alpha := false
	for m in node.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null or _in_crack(mi, node) or (visible_only and not mi.is_visible_in_tree()):
			continue
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
	return {"tris": tris, "draws": draws, "alpha": alpha}


func _in_crack(mi: Node, top: Node) -> bool:
	var n := mi
	while n != null and n != top:
		if n.name == "PlateCrack":
			return true
		n = n.get_parent()
	return false


func _extent(mi: MeshInstance3D, node: Node3D) -> Dictionary:
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	var r := 0.0
	for s in mi.mesh.get_surface_count():
		for v in mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array:
			var p: Vector3 = node.global_transform.affine_inverse() * (mi.global_transform * v)
			lo = lo.min(p)
			hi = hi.max(p)
			r = maxf(r, Vector2(p.x, p.z).length())
	return {"lo": lo, "hi": hi, "r": r}


func _run() -> void:
	var packed := load("res://assets/models/world_one/enemy_plated_brute.glb") as PackedScene
	_check(packed != null, "enemy_plated_brute.glb loads")
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
	_check_rig(scene)
	scene.free()

	game.ctx.calm = true
	var brute: Node3D = game.ctx.spawner.spawn_enemy("plated_brute", Vector3(0, 30, 0))
	await process_frame
	_check(brute != null, "a plated brute spawns")
	if brute == null:
		quit(1)
		return
	var shapes := brute.find_children("*", "CollisionShape3D", true, false)
	_check(shapes.size() == 1, "one collision shape on the brute (%d)" % shapes.size())
	var cap := (shapes[0] as CollisionShape3D).shape as CapsuleShape3D if shapes.size() > 0 else null
	_check(cap != null and is_equal_approx(cap.radius, 0.8) and is_equal_approx(cap.height, 2.2), "collider is the base capsule r 0.8, h 2.2")
	_check(shapes.size() > 0 and (shapes[0] as Node3D).position == Vector3.ZERO, "collider sits at the origin")
	_check(brute.find_children("*", "Area3D", true, false).is_empty() and brute.find_children("*", "CollisionObject3D", true, false).is_empty(),
		"the dressing adds no collision object")
	_check(brute.radius == 0.8 and brute.half_height == 1.1 and is_equal_approx(brute.weight, 3.0), "radius 0.8, half-height 1.1 and weight 3 unchanged")
	_check(is_equal_approx(brute.warn_seconds, 1.1) and is_equal_approx(brute.live_seconds, 0.15) and is_equal_approx(brute.rest_seconds, 2.8)
		and is_equal_approx(brute.attack_range, 6.5) and is_equal_approx(brute.keep_near, 3.0) and is_equal_approx(brute.walk_speed, 3.2)
		and brute.scrap_value == 8 and not brute.interruptible,
		"warn 1.1, live 0.15, rest 2.8, range 6.5, keep-near 3, walk 3.2, scrap 8 and uninterruptible unchanged")
	_check(brute.plates == 1 and brute.plates_popped == 0 and is_equal_approx(brute.plating, float(brute.spec.get("plating", 24.0))) and is_equal_approx(brute.hp, 110.0),
		"one plate, plating from the spec (default 24) and 110 health unchanged")
	var consts: Dictionary = (brute.get_script() as Script).get_script_constant_map()
	var same := true
	for key in BASE_CONSTS:
		if not consts.has(key) or not is_equal_approx(float(consts[key]), float(BASE_CONSTS[key])):
			same = false
			print("  constant %s is %s, base %s" % [key, consts.get(key), BASE_CONSTS[key]])
	_check(same, "plating scale, slam radius, range, damage, shove and health constants equal base")

	var live := _measure(brute)
	# Measured at the Unit LN base b3d0703 with the same crack-excluding counter.
	print("LN live assembly before: 1044 T, 4 D; after: %d T, %d D" % [live["tris"], live["draws"]])
	print("live assembly intact: %d T, %d D" % [live["tris"], live["draws"]])
	_check(live["draws"] > 0 and live["tris"] > 0, "the live measure saw meshes (%d T, %d D)" % [live["tris"], live["draws"]])
	_check(live["tris"] <= CEILING_T and live["draws"] <= LIVE_CEILING_D, "live assembly %d T / %d D within %d / 3" % [live["tris"], live["draws"], CEILING_T])
	_check(brute.find_child("BruteArmLinks", true, false) == null, "the live body needs no separate arm link mesh")
	_check(not live["alpha"], "live assembly has no alpha")
	_check_shape(brute)
	_check_paint(brute)
	_check_strip(brute)
	print("enemy_plated_brute_asset_test: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _check_shape(brute: Node3D) -> void:
	var body := brute.find_child("BruteBody", true, false) as MeshInstance3D
	var plates := brute.find_child("BrutePlates", true, false) as MeshInstance3D
	_check(body != null and plates != null, "the live brute has BruteBody and BrutePlates")
	if body == null or plates == null:
		return
	var e := _extent(body, brute)
	var lo: Vector3 = e["lo"]
	var hi: Vector3 = e["hi"]
	print("body bounds: y %.3f..%.3f, radius %.3f" % [lo.y, hi.y, e["r"]])
	_check(e["r"] <= CREW_R + 0.001, "the body stands inside the 0.8 m collider footprint")
	_check(lo.y >= Y_BOTTOM - 0.001, "the body stands on the collider floor (y %.3f)" % lo.y)
	_check(hi.y <= 2.3, "the body stays under 2.3 m (top %.2f)" % hi.y)
	var p := _extent(plates, brute)
	var plo: Vector3 = p["lo"]
	var phi: Vector3 = p["hi"]
	print("plate bounds: y %.3f..%.3f, reach %.3f" % [plo.y, phi.y, p["r"]])
	_check(p["r"] <= PLATE_REACH, "the plate group reaches %.3f m <= %.1f" % [p["r"], PLATE_REACH])
	_check(plo.y >= Y_BOTTOM - 0.001 and phi.y <= 1.3, "the plate group stays between the floor and 1.3 m")
	_check(phi.z > 1.3, "the slab stands proud of the body at the front (z %.2f)" % phi.z)


# The resting body is Fleet oxide (RUST); the hit flashes through the existing event
# (enemy.flash() sets _flash, _update_flash lerps _material from _base_color).
func _check_paint(brute: Node3D) -> void:
	var body := brute.find_child("BruteBody", true, false) as MeshInstance3D
	# Find the glb's fleet_paint slot on its own, so the flashing material is pinned to that surface.
	var scene := (load("res://assets/models/world_one/enemy_plated_brute.glb") as PackedScene).instantiate()
	var source := scene.find_child("BruteBody", true, false) as MeshInstance3D
	var slot := -1
	for s in source.mesh.get_surface_count():
		if source.mesh.surface_get_material(s).resource_name == "fleet_paint":
			slot = s
	scene.free()
	var mat: StandardMaterial3D = body.get_surface_override_material(slot) as StandardMaterial3D if slot >= 0 else null
	var found: bool = mat != null and mat == brute._material and mat.albedo_color.is_equal_approx(Palette.RUST)
	_check(found, "the glb's fleet_paint surface (%d) is the Fleet oxide colour (RUST) on the enemy's own material" % slot)
	brute.flash()
	brute._update_flash(0.0)
	var hit: Color = brute._material.albedo_color
	_check(not hit.is_equal_approx(Palette.RUST) and brute._material.emission_enabled, "a hit flashes the body through the existing event")
	for i in 20:
		brute._update_flash(0.1)
	_check(brute._material.albedo_color.is_equal_approx(Palette.RUST) and not brute._material.emission_enabled, "the body returns to oxide after the flash")
	var second: Node3D = game.ctx.spawner.spawn_enemy("plated_brute", Vector3(20, 30, 0))
	second.flash()
	second._update_flash(0.0)
	brute._update_flash(0.0)
	_check(second._material != brute._material and brute._material.albedo_color.is_equal_approx(Palette.RUST),
		"a second brute's flash leaves this one's body unlit")


# The armour is one group: it renders while plates > 0 and none of it renders once a full hit pops it.
func _check_strip(brute: Node3D) -> void:
	var plates := brute.find_child("BrutePlates", true, false) as MeshInstance3D
	brute.on_struck("x", "y", {"full": false})
	_check(brute.plates == 1 and plates.is_visible_in_tree(), "a hit that is not full leaves the plate group standing")
	var before := _measure(brute, true)
	brute.on_struck("x", "y", {"full": true})
	var after := _measure(brute, true)
	print("live assembly stripped: %d T, %d D (intact %d T, %d D)" % [after["tris"], after["draws"], before["tris"], before["draws"]])
	_check(brute.plates == 0 and brute.plates_popped == 1, "a full result strips the plate: plates 0, popped 1")
	var rendering := 0
	for mi in brute.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).mesh == plates.mesh and (mi as MeshInstance3D).is_visible_in_tree():
			rendering += 1
	for mi in plates.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).is_visible_in_tree():
			rendering += 1
	_check(rendering == 0 and not plates.is_visible_in_tree(), "no part of the plate group renders after the strip")
	var group: int = before["tris"] - after["tris"]
	_check(group > 0 and group <= PLATE_T, "the plate group is %d T <= %d" % [group, PLATE_T])
	_check(after["tris"] < before["tris"] and after["draws"] < before["draws"], "the stripped brute has visibly less mass (%d T against %d T)" % [after["tris"], before["tris"]])
	brute.on_struck("x", "y", {"full": true})
	_check(brute.plates == 0 and brute.plates_popped == 1, "with no plate left a full result strips nothing more")
	_check(is_equal_approx(brute.take_damage(10.0), 0.0), "the popped plate still takes the first hit whole")


# Pin names and skin bindings, never file bytes. The rig adds no mesh/surface.
func _check_rig(scene: Node) -> void:
	var rig := scene.find_child("Skeleton3D", true, false) as Skeleton3D
	var body := scene.find_child("BruteBody", true, false) as MeshInstance3D
	var plate := scene.find_child("BrutePlates", true, false) as MeshInstance3D
	_check(rig != null and body != null and plate != null, "named body, plate and wind-up skeleton exist")
	if rig == null or body == null or plate == null:
		return
	var names := []
	for index in rig.get_bone_count():
		names.append(rig.get_bone_name(index))
	_check(names == ["BruteFeet", "BruteRear", "SlamPadLeft", "SlamPadRight"], "joint nodes pinned: %s" % [names])
	var slots := []
	for mesh in [body.mesh, plate.mesh]:
		for surface in mesh.get_surface_count():
			slots.append(mesh.surface_get_material(surface).resource_name)
	_check(slots == ["fleet_paint", "paint", "bare_metal"], "surface names pinned: %s" % [slots])
	_check(body.skin != null and body.skin.get_bind_count() == 4 and body.get_node(body.skeleton) == rig,
		"body skin binds the four joints to its skeleton")
	var weighted := [0, 0, 0, 0]
	var normalized := true
	var blended := [0, 0]
	for surface in body.mesh.get_surface_count():
		var arrays := body.mesh.surface_get_arrays(surface)
		var joints: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		for vertex in weights.size() / 4:
			var total := 0.0
			for slot in 4:
				total += weights[vertex * 4 + slot]
				if weights[vertex * 4 + slot] > 0.0:
					weighted[joints[vertex * 4 + slot]] += 1
					if weights[vertex * 4 + slot] < 1.0 and joints[vertex * 4 + slot] in [2, 3]:
						blended[joints[vertex * 4 + slot] - 2] += 1
			normalized = normalized and absf(total - 1.0) < 0.0001
	_check(normalized and not weighted.has(0) and blended[0] > 0 and blended[1] > 0,
		"each part has normalized skin weights, both arms blend torso to pad: weighted %s; blended %s" % [weighted, blended])
	_check(is_equal_approx(float(_measure(scene)["tris"]), 5308.0), "5308 polished triangles (arms and sleeves stay unsubdivided so the pad and shoulder rings are exact at rest; 4888 before the W1-24 stoplog-grab head, cast number and HIRED)")
