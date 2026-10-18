extends SceneTree

const Game := preload("res://src/game.gd")
const Palette := preload("res://src/core/palette.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")

# C14 limits. The asset: 1,200 T / 3 D ceiling for the whole moving assembly (body plus harpoon),
# opaque, inside the envelope the base gun, post and hazard tip stood in (post x 0.9, gun 1.5 m long
# from z -0.35), widened for the anchor crown and the longer harpoon with its whole pose travel.
# The base contract: the hooker's collider, hitbox, lane, tether, timing and rating are the values
# hooker.gd had before the dressing swap, and the anchor (the tether endpoint) is 3.1 m above the origin.
const CEILING_T := 6800  # polished 2026-10-18 (tools/blender/POLISH.md); was 1200
const CEILING_D := 3
const X_MIN := -1.0
const X_MAX := 1.6
const Z_MIN := -1.2
const Z_MAX := 2.7
const Y_BOTTOM := -1.1
const Y_TOP := 4.0
const BASE_CONSTS := {
	"LANE_LENGTH": 24.0, "LANE_WIDTH": 2.4, "POST_HEIGHT": 4.2, "SPRING": 5.0, "RADIAL_DAMP": 3.0, "REEL": 2.5,
	"MIN_ROPE": 3.0, "SNAP_SPEED": 19.0, "RATING_BASE": 2.2, "RATING_PER_THREAT": 0.5, "HP": 55.0,
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
	var worst_r := 0.0
	var worst_y := 0.0
	for m in node.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
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
			var basis_to_node: Transform3D = node.global_transform.affine_inverse() * mi.global_transform
			for v in vs:
				var p: Vector3 = basis_to_node * v
				worst_r = maxf(worst_r, Vector2(p.x, p.z).length())
				worst_y = maxf(worst_y, absf(p.y))
	return {"tris": tris, "draws": draws, "alpha": alpha, "r": worst_r, "y": worst_y}


func _bounds(node: Node, only_named := "") -> Dictionary:
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for m in node.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null or (only_named != "" and mi.name != only_named):
			continue
		for s in mi.mesh.get_surface_count():
			var vs: PackedVector3Array = mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			for v in vs:
				var p: Vector3 = node.global_transform.affine_inverse() * (mi.global_transform * v)
				lo = lo.min(p)
				hi = hi.max(p)
	return {"lo": lo, "hi": hi}


func _run() -> void:
	var packed := load("res://assets/models/world_one/enemy_hooker.glb") as PackedScene
	_check(packed != null, "enemy_hooker.glb loads")
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
	var hooker: Node3D = game.ctx.spawner.spawn_enemy("hooker", Vector3(0, 30, 0))
	await process_frame
	_check(hooker != null, "a hooker spawns")
	if hooker == null:
		quit(1)
		return
	var shapes := hooker.find_children("*", "CollisionShape3D", true, false)
	_check(shapes.size() == 1, "one collision shape on the hooker (%d)" % shapes.size())
	var cap := (shapes[0] as CollisionShape3D).shape as CapsuleShape3D if shapes.size() > 0 else null
	_check(cap != null and is_equal_approx(cap.radius, 0.8) and is_equal_approx(cap.height, 2.2), "collider is the base capsule r 0.8 h 2.2")
	_check(shapes.size() > 0 and (shapes[0] as Node3D).position == Vector3.ZERO, "collider sits at the origin")
	_check(hooker.find_children("*", "Area3D", true, false).is_empty() and hooker.find_children("*", "CollisionObject3D", true, false).is_empty(),
		"the dressing adds no collision object")
	_check(hooker.radius == 0.8 and hooker.half_height == 1.1 and hooker.weight == 1.5, "radius 0.8, half-height 1.1 and weight 1.5 unchanged")
	_check(hooker.warn_seconds == 1.0 and hooker.live_seconds == 2.2 and hooker.rest_seconds == 4.0 and hooker.attack_range == 22.0
		and hooker.keep_near == 12.0 and hooker.scrap_value == 4 and is_equal_approx(hooker.rating, 2.2),
		"warn 1.0, live 2.2, rest 4.0, range 22, keep_near 12, scrap 4 and rating 2.2 unchanged")
	var consts: Dictionary = (hooker.get_script() as Script).get_script_constant_map()
	var same := true
	for key in BASE_CONSTS:
		if not consts.has(key) or not is_equal_approx(float(consts[key]), float(BASE_CONSTS[key])):
			same = false
			print("  constant %s is %s, base %s" % [key, consts.get(key), BASE_CONSTS[key]])
	_check(same, "lane, tether (spring, damp, reel, snap speed, rope), rating and health constants equal base")
	var anchor_offset: Vector3 = hooker.anchor() - hooker.global_position
	_check(anchor_offset.is_equal_approx(Vector3(0.0, 3.1, 0.0)), "the anchor (tether endpoint) is 3.1 m above the origin")

	var live := _measure(hooker)
	print("live assembly: %d T, %d D" % [live["tris"], live["draws"]])
	_check(hooker.find_child("HookerBody", true, false) != null and hooker.find_child("HookerHarpoon", true, false) != null,
		"the live Hooker carries its HookerBody dressing and HookerHarpoon")
	_check(live["draws"] > 0 and live["tris"] > 0, "the live measure saw meshes (%d T, %d D)" % [live["tris"], live["draws"]])
	_check(live["tris"] <= CEILING_T and live["draws"] <= CEILING_D, "live assembly %d T / %d D within %d / 3" % [live["tris"], live["draws"], CEILING_T])
	_check(not live["alpha"], "live assembly has no alpha")
	_check_envelope(hooker, "live rest")
	_check_pose(hooker)
	_check_paint(hooker)
	print("enemy_hooker_asset_test: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _check_envelope(node: Node3D, label: String) -> void:
	var b := _bounds(node)
	var lo: Vector3 = b["lo"]
	var hi: Vector3 = b["hi"]
	print("%s bounds: x %.3f..%.3f, y %.3f..%.3f, z %.3f..%.3f" % [label, lo.x, hi.x, lo.y, hi.y, lo.z, hi.z])
	_check(lo.x >= X_MIN - 0.001 and hi.x <= X_MAX + 0.001 and lo.z >= Z_MIN - 0.001 and hi.z <= Z_MAX + 0.001,
		"%s inside the footprint x %.1f..%.1f, z %.1f..%.1f" % [label, X_MIN, X_MAX, Z_MIN, Z_MAX])
	_check(lo.y >= Y_BOTTOM - 0.001 and hi.y <= Y_TOP + 0.001, "%s between y %.1f and %.1f" % [label, Y_BOTTOM, Y_TOP])
	_check(hi.y >= 3.6, "the anchor crown still stands tall (top %.2f >= 3.6)" % hi.y)
	_check(label != "live rest" or hi.z >= 2.3, "%s the harpoon reaches forward (z max %.2f >= 2.3)" % [label, hi.z])


# The pose reads the existing attack state only: warn cocks the harpoon back along its own axis,
# live lunges it forward, roam settles it. The anchor and the tether endpoint never move.
func _check_pose(hooker: Node3D) -> void:
	var harpoon := hooker.find_child("HookerHarpoon", true, false) as Node3D
	var body := hooker.find_child("Body", true, false) as Node3D
	var rest: Vector3 = harpoon.position
	var body_rest: Transform3D = body.transform
	var anchor_rest: Vector3 = hooker.anchor() - hooker.global_position
	_check(rest.is_equal_approx(Vector3(0.9, 3.1, 0.0)) and body_rest.is_equal_approx(Transform3D.IDENTITY),
		"the harpoon cradle sits at the anchor head (0.9, 3.1, 0) and the body at the origin")
	hooker.phase = hooker.Phase.WARN
	hooker._t = hooker.warn_seconds * 0.5
	hooker._pose()
	var cocked: Vector3 = harpoon.position
	_check(cocked.z < rest.z - 0.1 and is_equal_approx(cocked.x, rest.x) and is_equal_approx(cocked.y, rest.y), "warn: the harpoon cocks back along its axis (z %.2f from %.2f)" % [cocked.z, rest.z])
	_check_envelope(hooker, "warn pose")
	hooker._t = hooker.warn_seconds
	hooker._pose()
	_check_envelope(hooker, "warn end pose")
	hooker.phase = hooker.Phase.LIVE
	hooker._pose()
	_check(harpoon.position.z > rest.z + 0.1 and is_equal_approx(harpoon.position.x, rest.x) and is_equal_approx(harpoon.position.y, rest.y), "live: the harpoon lunges forward (z %.2f from %.2f)" % [harpoon.position.z, rest.z])
	_check_envelope(hooker, "live pose")
	_check((hooker.anchor() - hooker.global_position).is_equal_approx(anchor_rest) and body.transform.is_equal_approx(body_rest),
		"posing moves neither the anchor (tether endpoint) nor the post and body")
	hooker.phase = hooker.Phase.ROAM
	for i in 150:
		hooker._pose()
	_check(harpoon.position.is_equal_approx(rest), "roam: the harpoon settles back to rest")


# The resting body is Fleet oxide (RUST); a hit flashes through the existing event
# (enemy.flash() sets _flash, _update_flash lerps _base_color toward cream with neutral emission:
# amber means the world is paying, so a hit carries no colour of its own).
func _check_paint(hooker: Node3D) -> void:
	var body := hooker.find_child("Body", true, false) as MeshInstance3D
	var mat: StandardMaterial3D = null
	for s in body.mesh.get_surface_count():
		var o := body.get_surface_override_material(s) as StandardMaterial3D
		if o != null and o == hooker._material:
			mat = o
	_check(mat != null, "the body's paint surface is the enemy's flashing material")
	_check(hooker._base_color.is_equal_approx(Palette.RUST) and hooker._material.albedo_color.is_equal_approx(Palette.RUST),
		"resting state: the body is Fleet oxide (RUST)")
	hooker.flash()
	hooker._update_flash(0.0)
	var want: Color = Palette.RUST.lerp(Color(1.0, 1.0, 0.85), 1.0)
	_check(hooker._material.albedo_color.is_equal_approx(want) and hooker._material.emission_enabled, "hit state: the existing flash lerps the body toward cream")
	_check(hooker._material.emission.is_equal_approx(EventKinds.role_color("neutral")),
		"hit state: the flash glows neutral, not amber (%s)" % hooker._material.emission.to_html(false))
	for i in 20:
		hooker._update_flash(0.1)
	_check(hooker._material.albedo_color.is_equal_approx(Palette.RUST) and not hooker._material.emission_enabled, "recovery state: the body returns to oxide")
