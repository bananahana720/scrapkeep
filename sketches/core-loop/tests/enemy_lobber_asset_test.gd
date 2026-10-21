extends SceneTree

const Game := preload("res://src/game.gd")
const Palette := preload("res://src/core/palette.gd")

# C11 triangle/envelope limits. WL splits the existing tube, raising the draw ceiling
# from 3 to 5 while retaining 840 triangles and both original material slots.
# The asset: 1,200 T / 5 D ceiling for the whole moving assembly (body plus loading
# bulb), opaque, the cart inside the 2.4 x 4 x 2.4 m collider box, the mortar tube inside the base
# tube's reach (top at most 5.0 m), the bulb the base 0.9 m sphere at y 2.6. The base contract: the
# lobber's collider, hitbox, aim, timing and damage are the values lobber.gd had before the dressing swap.
const CEILING_T := 7100  # polished 2026-10-18 (tools/blender/POLISH.md); was 1200
const CEILING_D := 5
const BASE_TRIANGLES := 6720  # polished; was 840
const HALF_XZ := 1.2
const Y_BOTTOM := -2.0
const Y_TOP := 5.0
const BULB_R := 0.9
const BULB_Y := 2.6
const BASE_CONSTS := {
	"CYCLE": 3.6, "TELEGRAPH": 1.3, "FLIGHT": 1.9, "SHOT_RANGE": 75.0, "LEAD": 0.5, "HP": 26.0, "SCRAP": 4,
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
	var packed := load("res://assets/models/world_one/enemy_lobber.glb") as PackedScene
	_check(packed != null, "enemy_lobber.glb loads")
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
	_check(absf(float(m["tris"]) / BASE_TRIANGLES - 1.0) <= 0.1, "WL-8 triangle count within 10 percent of %d" % BASE_TRIANGLES)
	_check_parts(scene)
	_check_envelope(scene, "asset")
	scene.free()

	game.ctx.calm = true
	var lobber: Node3D = game.ctx.spawner.spawn_enemy("lobber", Vector3(0, 30, 0))
	await process_frame
	_check(lobber != null, "a lobber spawns")
	if lobber == null:
		quit(1)
		return
	var shapes := lobber.find_children("*", "CollisionShape3D", true, false)
	_check(shapes.size() == 1, "one collision shape on the lobber (%d)" % shapes.size())
	var box := (shapes[0] as CollisionShape3D).shape as BoxShape3D if shapes.size() > 0 else null
	_check(box != null and box.size.is_equal_approx(Vector3(2.4, 4.0, 2.4)), "collider is the base box 2.4 x 4 x 2.4")
	_check(shapes.size() > 0 and (shapes[0] as Node3D).position == Vector3.ZERO, "collider sits at the origin")
	_check(lobber.find_children("*", "Area3D", true, false).is_empty() and lobber.find_children("*", "CollisionObject3D", true, false).is_empty(),
		"the dressing adds no collision object")
	_check(lobber.radius == 1.3 and lobber.half_height == 2.0 and lobber.weight == 3.0, "radius 1.3, half-height 2 and weight 3 unchanged")
	_check(is_equal_approx(lobber.muzzle_point().y - lobber.global_position.y, 2.6), "muzzle point is 2.6 m above the origin")
	var consts: Dictionary = (lobber.get_script() as Script).get_script_constant_map()
	var same := true
	for key in BASE_CONSTS:
		if not consts.has(key) or not is_equal_approx(float(consts[key]), float(BASE_CONSTS[key])):
			same = false
			print("  constant %s is %s, base %s" % [key, consts.get(key), BASE_CONSTS[key]])
	_check(same, "aim (lead 0.5, range 75), telegraph, flight, cycle, health and scrap constants equal base")

	var live := _measure(lobber)
	print("live assembly: %d T, %d D" % [live["tris"], live["draws"]])
	_check(lobber.find_child("LobberBody", true, false) != null, "the live Lobber carries its LobberBody dressing")
	_check(live["draws"] > 0 and live["tris"] > 0, "the live measure saw meshes (%d T, %d D)" % [live["tris"], live["draws"]])
	_check(live["tris"] <= CEILING_T and live["draws"] <= CEILING_D, "live assembly %d T / %d D within %d / 5" % [live["tris"], live["draws"], CEILING_T])
	_check(not live["alpha"], "live assembly has no alpha")
	_check_envelope(lobber, "live assembly")
	_check_paint(lobber)
	print("enemy_lobber_asset_test: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _check_parts(scene: Node3D) -> void:
	var slots := {
		"LobberBody": ["fleet_paint", "rubber"],
		"LobberBarrel": ["fleet_paint", "rubber"],
		"LobberBulb": ["requisition_tag"],
	}
	for part in slots:
		var node := scene.find_child(part, true, false) as MeshInstance3D
		var got := []
		if node != null:
			for surface in node.mesh.get_surface_count():
				got.append(node.mesh.surface_get_material(surface).resource_name)
		got.sort()
		_check(node != null and got == slots[part], "WL-8 %s node and surfaces %s" % [part, got])


func _check_envelope(node: Node3D, label: String) -> void:
	var b := _bounds(node)
	var lo: Vector3 = b["lo"]
	var hi: Vector3 = b["hi"]
	print("%s bounds: x %.3f..%.3f, y %.3f..%.3f, z %.3f..%.3f" % [label, lo.x, hi.x, lo.y, hi.y, lo.z, hi.z])
	_check(maxf(absf(lo.x), absf(hi.x)) <= HALF_XZ + 0.001 and maxf(absf(lo.z), absf(hi.z)) <= HALF_XZ + 0.001,
		"%s inside the 2.4 m collider footprint" % label)
	_check(lo.y >= Y_BOTTOM - 0.001 and hi.y <= Y_TOP + 0.001, "%s between y %.1f and %.1f" % [label, Y_BOTTOM, Y_TOP])
	_check(hi.y >= 4.6, "the mortar still stands overhead (top %.2f >= 4.6)" % hi.y)
	var bulb := node.find_child("LobberBulb", true, false) as Node3D
	_check(bulb != null, "%s has its LobberBulb node" % label)
	if bulb == null:
		return
	var rel: Vector3 = node.global_transform.affine_inverse() * bulb.global_position
	_check(is_equal_approx(rel.y, BULB_Y) and absf(rel.x) < 0.001 and absf(rel.z) < 0.001, "%s bulb centre at y %.2f" % [label, BULB_Y])
	var reach := 0.0
	for s in (bulb as MeshInstance3D).mesh.get_surface_count():
		for v in (bulb as MeshInstance3D).mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array:
			reach = maxf(reach, v.length())
	_check(reach <= BULB_R + 0.001, "%s bulb radius %.3f <= %.1f" % [label, reach, BULB_R])


# C11 correction: the resting body is Fleet oxide (the Chaser's RUST); the hit flash and the event
# colour (_base_color, the only Lobber colour read outside lobber.gd is enemy.gd's flash lerp and
# _apply_rest_look, which lobber.gd overrides) stay verdigris.
func _check_paint(lobber: Node3D) -> void:
	var body := lobber.find_child("LobberBody", true, false)
	var mat: StandardMaterial3D = null
	for mi in body.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).get_surface_override_material(0) as StandardMaterial3D
		if m != null and m.albedo_color.is_equal_approx(Palette.RUST):
			mat = m
	_check(mat != null, "the resting body surface is the Fleet oxide colour (RUST)")
	_check(lobber._base_color == Palette.VERDIGRIS, "the event/UI colour _base_color is still verdigris")
	_check(lobber._material.albedo_color.is_equal_approx(Palette.RUST), "resting state: body albedo is oxide")
	lobber.flash()
	lobber._update_flash(0.0)
	var hit: Color = lobber._material.albedo_color
	var want: Color = Palette.VERDIGRIS.lerp(Color(1.0, 1.0, 0.85), 1.0)
	_check(hit.is_equal_approx(want) and lobber._material.emission_enabled, "hit state: the flash lerps from verdigris toward cream with amber emission")
	lobber._flash = 0.3
	lobber._update_flash(0.0)
	_check(lobber._material.albedo_color.is_equal_approx(Palette.VERDIGRIS.lerp(Color(1.0, 1.0, 0.85), lobber._flash)), "mid-flash colour still derives from verdigris")
	for i in 20:
		lobber._update_flash(0.1)
	_check(lobber._material.albedo_color.is_equal_approx(Palette.RUST) and not lobber._material.emission_enabled, "recovery state: the body returns to oxide with the flash emission off")
	_check(lobber._base_color == Palette.VERDIGRIS, "the event colour is unchanged after recovery")
