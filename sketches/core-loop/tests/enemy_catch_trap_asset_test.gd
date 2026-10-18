extends SceneTree

const Game := preload("res://src/game.gd")
const Palette := preload("res://src/core/palette.gd")
const GLB := "res://assets/models/world_one/enemy_catch_trap.glb"
const BASE_CONSTS := {"CUP_RADIUS": 2.6, "LEAD": 0.8, "HOLD": 1.4, "STOP": 14.0, "CENTRE": 10.0, "HP": 35.0}
const BASE_SOURCE := [
	"_set_health(HP * threat)", "scrap_value = 4", "weight = 1.0", "warn_seconds = 1.0",
	"live_seconds = 2.0", "rest_seconds = 4.0", "attack_range = 24.0",
	"_ball() + target.planar_velocity() * LEAD", "_commit_ring(Threat.Type.INSTANT, aim, CUP_RADIUS, 2.2)",
	"_cup.top_level = true", "_cup.global_position = ring.center + Vector3.UP * 0.4",
	"caught_live == 0 and ring.contains(ball) and player.state.grounded and _catch(HOLD)",
	"cupped += 1", "to_centre.y = 0.0", "_pull(-player.planar_velocity() * STOP + to_centre * CENTRE)",
	"_cup.top_level = false", "_cup.position = Vector3(0.0, CREW_HALF + 0.5, -0.3)",
]
const BASE_GAMEPLAY_HASHES := {
	"_configure": "1d871d84fb16dd86048d54c35fd17c13eece94a7251439c62010b86c23ca1755",
	"_commit": "947bb63e39d83a55156ccce4f7ee91779ab8e4d092777c73cbfb4b683fb83a04",
	"_live": "1cf301eefcb62d666c420af47e93fbaa83d54ce8f7ae93fd88e1f0829a6893c8",
	"_on_end": "0ee422774dc49e296a739bba2f110bbb13bec44a826ec673afdfcc15b662f8a6",
}
var failures := 0
var game
var fixture_root: Node3D

class FixtureTarget extends RefCounted:
	func ball_position() -> Vector3:
		return Vector3(8, 0, 0)
	func planar_velocity() -> Vector3:
		return Vector3(1, 0, 0)

class FixtureGround extends RefCounted:
	func height(_x: float, _z: float) -> float:
		return 0.0


func _initialize() -> void:
	if "--full-game" in OS.get_cmdline_user_args():
		game = Game.new()
		game.test_mode = true
		root.add_child(game)
	else:
		fixture_root = Node3D.new()
		root.add_child(fixture_root)
	_run.call_deferred()


func _spawn(at: Vector3) -> Node3D:
	if game != null:
		return game.ctx.spawner.spawn_enemy("catch_trap", at)
	var enemy := load("res://src/combat/catch_trap.gd").new() as Node3D
	fixture_root.add_child(enemy)
	enemy.position = at
	enemy.setup(FixtureTarget.new(), FixtureGround.new(), fixture_root, Callable(), 1.0, {"kind": "catch_trap"})
	return enemy


func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
	print("%s %s" % ["PASS" if ok else "FAIL", label])


func _mat_of(mi: MeshInstance3D, s: int) -> Material:
	if mi.material_override != null:
		return mi.material_override
	var mat := mi.get_surface_override_material(s)
	return mat if mat != null else mi.mesh.surface_get_material(s)


func _measure(node: Node) -> Dictionary:
	var tris := 0
	var draws := 0
	var alpha := false
	for m in node.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			draws += 1
			var a := mi.mesh.surface_get_arrays(s)
			var ix = a[Mesh.ARRAY_INDEX]
			tris += (ix.size() if ix != null else a[Mesh.ARRAY_VERTEX].size()) / 3
			var mat := _mat_of(mi, s) as BaseMaterial3D
			alpha = alpha or (mat != null and (mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or mat.albedo_color.a < 0.999))
			var colors = a[Mesh.ARRAY_COLOR]
			if colors != null:
				for c: Color in colors:
					alpha = alpha or c.a < 0.999
	return {"tris": tris, "draws": draws, "alpha": alpha}


func _points(mi: MeshInstance3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	for s in mi.mesh.get_surface_count():
		for v: Vector3 in mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			out.append(v)
	return out


func _triangles(mi: MeshInstance3D) -> Array:
	var out := []
	for s in mi.mesh.get_surface_count():
		var a := mi.mesh.surface_get_arrays(s)
		var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var ix = a[Mesh.ARRAY_INDEX]
		var n: int = ix.size() if ix != null else vs.size()
		for i in range(0, n, 3):
			out.append([vs[ix[i] if ix != null else i], vs[ix[i + 1] if ix != null else i + 1], vs[ix[i + 2] if ix != null else i + 2]])
	return out


func _check_base(enemy: Node3D) -> void:
	var shapes := enemy.find_children("*", "CollisionShape3D", true, false)
	var cap := (shapes[0] as CollisionShape3D).shape as CapsuleShape3D if not shapes.is_empty() else null
	_check(shapes.size() == 1 and cap != null and is_equal_approx(cap.radius, 0.8) and is_equal_approx(cap.height, 2.2)
		and (shapes[0] as Node3D).transform == Transform3D.IDENTITY, "base collider: one capsule r 0.8 h 2.2 at origin")
	_check(enemy.find_children("*", "CollisionObject3D", true, false).is_empty(), "dressing adds no collision object")
	_check(enemy.collision_layer == 4 and enemy.collision_mask == 1 and is_equal_approx(enemy.floor_max_angle, deg_to_rad(60.0)), "base collision layers and floor angle")
	var values := {"radius": 0.8, "half_height": 1.1, "weight": 1.0, "hp": 35.0, "max_hp": 35.0, "scrap_value": 4,
		"warn_seconds": 1.0, "live_seconds": 2.0, "rest_seconds": 4.0, "attack_range": 24.0,
		"walk_speed": 3.8, "keep_near": 9.0, "keep_far": 21.6, "first_rest": 1.5, "plating": 0.0}
	for key in values:
		_check(is_equal_approx(float(enemy.get(key)), float(values[key])), "base runtime %s = %s" % [key, values[key]])
	_check(enemy.interruptible, "base interruptible")
	var consts: Dictionary = enemy.get_script().get_script_constant_map()
	for key in BASE_CONSTS:
		_check(consts.has(key) and is_equal_approx(float(consts[key]), float(BASE_CONSTS[key])), "base constant %s = %s" % [key, BASE_CONSTS[key]])
	var source := FileAccess.get_file_as_string("res://src/combat/catch_trap.gd")
	for literal: String in BASE_SOURCE:
		_check(source.contains(literal), "base source literal: %s" % literal)
	for method in BASE_GAMEPLAY_HASHES:
		var start := source.find("func " + method + "(")
		var body := source.substr(start).get_slice("\n\n\n", 0).strip_edges() if start >= 0 else ""
		_check(body.sha256_text() == BASE_GAMEPLAY_HASHES[method], "base gameplay method unchanged: %s" % method)
	var parent_source := FileAccess.get_file_as_string("res://src/combat/counter.gd")
	for literal: String in ["var walk_speed := 3.8", "var keep_near := 9.0", "var keep_far := 24.0", "var first_rest := 1.5",
		"keep_far = minf(keep_far, attack_range * 0.9)", "const CREW_RADIUS := 0.8", "const CREW_HALF := 1.1"]:
		_check(parent_source.contains(literal), "base inherited source literal: %s" % literal)


func _check_paint(enemy: Node3D, scene: Node3D) -> void:
	var named := -1
	var body_name := ""
	var found := 0
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh := (node as MeshInstance3D).mesh
		for i in mesh.get_surface_count():
			var slot := mesh.surface_get_material(i).resource_name
			_check(slot == "fleet_paint" or slot == "paint", "glb uses approved slot %s" % slot)
			if slot == "fleet_paint":
				named = i
				body_name = node.name
				found += 1
	_check(found == 1, "glb names exactly one fleet_paint surface")
	var body := enemy.find_child(body_name, true, false) as MeshInstance3D
	_check(body != null, "live body corresponds to the glb body node")
	if body == null:
		return
	for node in enemy.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var mat := _mat_of(mi, s)
			_check((mat == enemy._material) == (mi == body and s == named), "flash binding %s surface %d matches glb body slot %d" % [mi.name, s, named])
			if mi != body or s != named:
				_check(mat is BaseMaterial3D and mat.vertex_color_use_as_albedo and is_equal_approx(mat.roughness, 0.8)
					and not mat.emission_enabled, "vertex paint roughness 0.8, no resting emission")
	_check(enemy._base_color.is_equal_approx(Palette.RUST) and enemy._material.albedo_color.is_equal_approx(Palette.RUST), "resting crew is Fleet oxide")
	enemy.flash()
	enemy._update_flash(0.0)
	_check(enemy._material.emission_enabled and enemy._material.albedo_color.is_equal_approx(Palette.RUST.lerp(Color(1, 1, 0.85), 1.0)), "existing body flash responds")
	enemy._update_flash(1.0)
	_check(not enemy._material.emission_enabled and enemy._material.albedo_color.is_equal_approx(Palette.RUST), "body flash recovers")


func _check_footprint(enemy: Node3D) -> void:
	var reach := 0.0
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for node in enemy.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var xf := enemy.global_transform.affine_inverse() * mi.global_transform
		for v in _points(mi):
			var p := xf * v
			reach = maxf(reach, Vector2(p.x, p.z).length())
			lo = lo.min(p)
			hi = hi.max(p)
	print("bounds: %s .. %s; radial footprint %.4f m" % [lo, hi, reach])
	_check(reach <= 0.801, "carried assembly inside collider footprint r 0.8")
	_check(lo.y >= -1.101 and hi.y <= 2.001, "carried assembly within base vertical envelope")


# Clip a triangle against the eighteen inward half-spaces of the open well.
# The 6 mm inset excludes the cup skin and floor; a crossing triangle is caught
# even if all its vertices lie outside the well (a cap or crossbar, for example).
func _clip(poly: Array, normal: Vector3, limit: float) -> Array:
	var result := []
	if poly.is_empty():
		return result
	var a: Vector3 = poly[-1]
	var da := normal.dot(a) - limit
	for v in poly:
		var b: Vector3 = v
		var db := normal.dot(b) - limit
		if (da <= 0) != (db <= 0):
			result.append(a.lerp(b, da / (da - db)))
		if db <= 0:
			result.append(b)
		a = b
		da = db
	return result


func _check_cup(cup: MeshInstance3D) -> void:
	var pts := _points(cup)
	var top := 0.0
	var base := 0.0
	for p in pts:
		if absf(p.y - 0.4) < 0.001:
			top = maxf(top, Vector2(p.x, p.z).length())
		if absf(p.y + 0.4) < 0.001:
			base = maxf(base, Vector2(p.x, p.z).length())
	print("cup: outer mouth r %.4f m, outer base r %.4f m (source maxima 1.2 / 0.7)" % [top, base])
	_check(top > 0.47 and top <= 1.201 and base > 0.29 and base <= 0.701, "visual cup no larger than source radii 1.2 / 0.7")
	var tris := _triangles(cup)
	var open := true
	var floor_hits := 0
	for x in [-0.16, -0.08, 0.0, 0.08, 0.16]:
		for z in [-0.16, -0.08, 0.0, 0.08, 0.16]:
			var nearest := -INF
			for t in tris:
				var hit = Geometry3D.ray_intersects_triangle(Vector3(x, 0.7, z), Vector3.DOWN, t[0], t[1], t[2])
				if hit != null:
					nearest = maxf(nearest, hit.y)
			open = open and absf(nearest + 0.28) < 0.002
			if absf(nearest + 0.28) < 0.002:
				floor_hits += 1
	print("cup open probe: %d / 25 rays first meet recessed floor y -0.28" % floor_hits)
	_check(open, "cup open: 25 mouth rays first hit the recessed floor")
	var lip_hit := false
	for t in tris:
		var hit = Geometry3D.ray_intersects_triangle(Vector3(-0.45, 0.7, 0), Vector3.DOWN, t[0], t[1], t[2])
		lip_hit = lip_hit or (hit != null and absf(hit.y - 0.4) < 0.002)
	_check(lip_hit, "open probe control: solid lip exists at y 0.4")
	var occupied := 0
	var apothem := cos(PI / 16.0)
	var slope := (0.42 - 0.24) / 0.68 * apothem
	for t in tris:
		var poly: Array = _clip(t, Vector3.DOWN, 0.274)
		poly = _clip(poly, Vector3.UP, 0.394)
		for k in 16:
			var a := (k + 0.5) * TAU / 16.0
			poly = _clip(poly, Vector3(cos(a), -slope, sin(a)), 0.24 * apothem + 0.28 * slope - 0.006)
		if poly.size() >= 3:
			var area := 0.0
			for i in range(1, poly.size() - 1):
				area += (poly[i] - poly[0]).cross(poly[i + 1] - poly[0]).length()
			if area > 0.000001:
				occupied += 1
	print("cup interior: %d triangles intersect the inset empty well" % occupied)
	_check(occupied == 0, "cup interior empty: no triangle crosses the well")
	var release_n := 0
	var release_lo := INF
	var release_hi := -INF
	for p in pts:
		if p.x >= 0.439 and p.z >= -0.09 and p.z <= 0.01:
			release_n += 1
			release_lo = minf(release_lo, p.y)
			release_hi = maxf(release_hi, p.y)
	_check(release_n >= 16 and release_lo <= -0.189 and release_hi >= 0.309, "release mechanism: external paddle, pivot and latch span y -0.19..0.31")
	var visible := 0
	for y in [-0.10, 0.10, 0.27]:
		var nearest := -INF
		for t in tris:
			var hit = Geometry3D.ray_intersects_triangle(Vector3(0.8, y, -0.04), Vector3.LEFT, t[0], t[1], t[2])
			if hit != null:
				nearest = maxf(nearest, hit.x)
		if nearest >= 0.47:
			visible += 1
	_check(visible == 3, "release mechanism visible from side at three heights")


func _check_deployment(enemy: Node3D, cup: MeshInstance3D) -> void:
	_check(not cup.top_level and cup.position.is_equal_approx(Vector3(0, 1.6, -0.3)), "carried cup keeps the base attachment")
	var material := _mat_of(cup, 0)
	var mesh := cup.mesh
	var ring: Node3D = enemy._commit(Vector3.FORWARD)
	_check(ring != null and is_equal_approx(ring.radius, 2.6), "committed gameplay ring remains r 2.6")
	_check(cup.top_level and cup.global_position.is_equal_approx(ring.center + Vector3.UP * 0.4), "deployed cup keeps the committed ring transform")
	_check(cup.mesh == mesh and _mat_of(cup, 0) == material, "deployed cup retains the entire shared release assembly")
	var m := _measure(enemy)
	_check(m.tris <= 3600 and m.draws <= 3 and not m.alpha, "deployed full assembly stays within budget and opaque")
	enemy._on_end()
	_check(not cup.top_level and cup.position.is_equal_approx(Vector3(0, 1.6, -0.3)), "recovered cup returns to base attachment")
	enemy._clear_telegraph()
	var other: Node3D = _spawn(Vector3(3, 30, 0))
	other.set_physics_process(false)
	var other_cup := other.get("_cup") as MeshInstance3D
	_check(other_cup != null and other_cup.mesh == cup.mesh and _mat_of(other_cup, 0) == material
		and other._material != enemy._material, "cache shares cup mesh/paint but body flash belongs to each enemy")


func _run() -> void:
	if game != null:
		game.ctx.calm = true
	print("fixture: %s" % ("full Game combat spawner" if game != null else "isolated live CatchTrap.setup with flat ground and fixed target"))
	var enemy: Node3D = _spawn(Vector3(0, 30, 0))
	enemy.set_physics_process(false)
	_check_base(enemy)
	var m := _measure(enemy)
	print("live assembly: %d T / %d D" % [m.tris, m.draws])
	_check(m.tris > 0 and m.tris <= 3600, "live triangle ceiling 3600 (polished; was 1200)")
	_check(m.draws > 0 and m.draws <= 3, "live draw ceiling 3")
	_check(not m.alpha, "live assembly opaque including vertex alpha")
	var packed := load(GLB) as PackedScene
	_check(packed != null, "glb loads")
	if packed != null:
		var scene := packed.instantiate() as Node3D
		root.add_child(scene)
		var asset := _measure(scene)
		_check(asset.tris > 0 and asset.tris <= 3600 and asset.draws <= 3 and not asset.alpha, "glb triangle/draw/alpha limits")
		_check_paint(enemy, scene)
		scene.free()
	_check(enemy.find_children("*", "Light3D", true, false).is_empty(), "no added lights")
	_check_footprint(enemy)
	var cup := enemy.get("_cup") as MeshInstance3D
	_check(cup != null and cup.name == "CatchCup", "live cup is the glb CatchCup mesh")
	if cup != null and cup.name == "CatchCup":
		_check_cup(cup)
		_check_deployment(enemy, cup)
	print("enemy_catch_trap_asset_test: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
