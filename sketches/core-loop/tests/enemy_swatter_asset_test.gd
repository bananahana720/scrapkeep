extends SceneTree

const Game := preload("res://src/game.gd")
const Palette := preload("res://src/core/palette.gd")
const GLB := "res://assets/models/world_one/enemy_swatter.glb"
const SOURCE := "res://src/combat/swatter.gd"
const BASE_CONSTS := {"SWEEP_RADIUS": 7.5, "SWEEP_HALF_DEG": 55.0, "PADDLE_REACH": 1.6,
	"BAT": 0.35, "KNOCK": 16.0, "HP": 45.0}
# 2026-10-22 (Systems B plate_press): _on_broken, the paddle_ride codex hook (discover only, no gameplay line).
# 2026-11-24 W46-ANIM-VFX-FLAIR: eased swing/return pose (SWING_S, RETURN_S, _return_t, _on_end) and
# presentation VFX bursts in _go_live; gameplay logic, constants and telegraph invariants unchanged.
const BASE_NONVISUAL := "extends \"res://src/combat/counter.gd\"\nconst FxLibrary := preload(\"res://src/presentation/fx_library.gd\")\nconst SWEEP_RADIUS := 7.5\nconst SWEEP_HALF_DEG := 55.0\nconst PADDLE_REACH := 1.6\nconst BAT := 0.35\nconst KNOCK := 16.0\nconst HP := 45.0\nconst SWING_S := 0.09\nconst RETURN_S := 0.28\nvar swats := 0\nvar _paddle: Node3D\nvar _sweep_dir := Vector3.RIGHT\nvar _swung := false\nvar _return_t := 0.0\nfunc _configure(threat: float) -> void:\n\t_set_health(HP * threat)\n\tscrap_value = 4\n\tweight = 1.6\n\twalk_speed = 4.2\n\tkeep_near = 3.0\n\tkeep_far = 26.0\n\tattack_range = 7.0\n\twarn_seconds = 0.8\n\tlive_seconds = BAT + 0.05\n\trest_seconds = 2.4\nfunc _commit(to_ball: Vector3) -> Node3D:\n\t_facing(to_ball)\n\t_swung = false\n\t_return_t = 0.0\n\tvar heading := to_ball.normalized() if to_ball.length() > 0.1 else Vector3.FORWARD\n\t_sweep_dir = heading.cross(Vector3.UP) * (1.0 if _strafe > 0.0 else -1.0)\n\t_clear_telegraph()\n\t_telegraph = Telegraph.wedge(world_root, terrain, Threat.Type.INSTANT, global_position, heading, SWEEP_RADIUS, SWEEP_HALF_DEG, PADDLE_REACH)\n\treturn _telegraph\nfunc _go_live() -> void:\n\t_swung = true\n\tswats += 1\n\tif world_root != null and is_inside_tree():\n\t\tvar tip := _paddle.to_global(Vector3(0.0, 0.3, 3.2)) if is_instance_valid(_paddle) else global_position + _sweep_dir * 2.5 + Vector3.UP * 0.9\n\t\tFxLibrary.burst(world_root, \"brass_spark\", tip, 10)\n\t\tFxLibrary.burst(world_root, \"steam_puff\", tip, 5)\n\tvar wedge := telegraph()\n\tif wedge == null or not wedge.contains(_real_ball()):\n\t\tbroken_by = \"missed\"\n\t\treturn\n\tvar step := get_physics_process_delta_time()\n\t_catch(BAT, _sweep_dir * KNOCK / step)\nfunc _on_end() -> void:\n\t_return_t = RETURN_S if EnemyMotion.motion_scale > 0.0 else 0.0\nfunc _on_broken(method: String) -> void:\n\tif method == \"boost\" and fleet != null:\n\t\tfleet.discover(\"paddle_ride\", _real_ball())\nfunc _live(_delta: float) -> bool:\n\treturn _holding()\nfunc _pose() -> void:\n\tif _paddle == null:\n\t\treturn\n\tvar swing := 0.0\n\tif phase == Phase.WARN:\n\t\tvar u := clampf(_t / warn_seconds, 0.0, 1.0)\n\t\tswing = -0.65 * (u * u * (3.0 - 2.0 * u))\n\telif phase == Phase.LIVE:\n\t\tvar u := clampf(_t / SWING_S, 0.0, 1.0)\n\t\tvar eased := 1.0 - pow(1.0 - u, 3.0)\n\t\tswing = lerpf(-0.65, 1.25, eased)\n\telif _return_t > 0.0:\n\t\t_return_t = maxf(0.0, _return_t - get_physics_process_delta_time())\n\t\tvar r := _return_t / RETURN_S\n\t\tswing = 1.25 * (r * r) * cos((1.0 - r) * PI * 0.65 * EnemyMotion.motion_scale)\n\t_paddle.rotation.y = swing * (1.0 if _strafe > 0.0 else -1.0)"
# 2026-11-24 W46-ANIM-VFX-FLAIR: source bodies re-pinned for eased pose & VFX hooks in _commit/_go_live/_pose.
const BASE_METHODS := {
	"_configure": "func _configure(threat: float) -> void:\n\t_set_health(HP * threat)\n\tscrap_value = 4\n\tweight = 1.6\n\twalk_speed = 4.2\n\tkeep_near = 3.0\n\tkeep_far = 26.0\n\tattack_range = 7.0\n\twarn_seconds = 0.8\n\tlive_seconds = BAT + 0.05\n\trest_seconds = 2.4",
	"_commit": "func _commit(to_ball: Vector3) -> Node3D:\n\t_facing(to_ball)\n\t_swung = false\n\t_return_t = 0.0\n\tvar heading := to_ball.normalized() if to_ball.length() > 0.1 else Vector3.FORWARD\n\t_sweep_dir = heading.cross(Vector3.UP) * (1.0 if _strafe > 0.0 else -1.0)\n\t_clear_telegraph()\n\t_telegraph = Telegraph.wedge(world_root, terrain, Threat.Type.INSTANT, global_position, heading, SWEEP_RADIUS, SWEEP_HALF_DEG, PADDLE_REACH)\n\treturn _telegraph",
	"_go_live": "func _go_live() -> void:\n\t_swung = true\n\tswats += 1\n\tif world_root != null and is_inside_tree():\n\t\tvar tip := _paddle.to_global(Vector3(0.0, 0.3, 3.2)) if is_instance_valid(_paddle) else global_position + _sweep_dir * 2.5 + Vector3.UP * 0.9\n\t\tFxLibrary.burst(world_root, \"brass_spark\", tip, 10)\n\t\tFxLibrary.burst(world_root, \"steam_puff\", tip, 5)\n\tvar wedge := telegraph()\n\tif wedge == null or not wedge.contains(_real_ball()):\n\t\tbroken_by = \"missed\"\n\t\treturn\n\tvar step := get_physics_process_delta_time()\n\t_catch(BAT, _sweep_dir * KNOCK / step)",
	"_live": "func _live(_delta: float) -> bool:\n\treturn _holding()",
	"_pose": "func _pose() -> void:\n\tif _paddle == null:\n\t\treturn\n\tvar swing := 0.0\n\tif phase == Phase.WARN:\n\t\tvar u := clampf(_t / warn_seconds, 0.0, 1.0)\n\t\tswing = -0.65 * (u * u * (3.0 - 2.0 * u))\n\telif phase == Phase.LIVE:\n\t\tvar u := clampf(_t / SWING_S, 0.0, 1.0)\n\t\tvar eased := 1.0 - pow(1.0 - u, 3.0)\n\t\tswing = lerpf(-0.65, 1.25, eased)\n\telif _return_t > 0.0:\n\t\t_return_t = maxf(0.0, _return_t - get_physics_process_delta_time())\n\t\tvar r := _return_t / RETURN_S\n\t\tswing = 1.25 * (r * r) * cos((1.0 - r) * PI * 0.65 * EnemyMotion.motion_scale)\n\t_paddle.rotation.y = swing * (1.0 if _strafe > 0.0 else -1.0)",
}
var failures := 0
var game


func _initialize() -> void:
	game = Game.new()
	game.test_mode = true
	root.add_child(game)
	_run.call_deferred()


func _check(ok: bool, id: String, label: String) -> void:
	if not ok:
		failures += 1
	print("%s [%s] %s" % ["PASS" if ok else "FAIL", id, label])


func _mat(mi: MeshInstance3D, s: int) -> Material:
	if mi.material_override != null:
		return mi.material_override
	var mat := mi.get_surface_override_material(s)
	return mat if mat != null else mi.mesh.surface_get_material(s)


# Count every mesh, including hidden duplicates. D is colour-pass surface submissions, not
# renderer telemetry. Material and vertex alpha are checked independently of visibility.
func _measure(node: Node) -> Dictionary:
	var tris := 0
	var draws := 0
	var vertices := 0
	var opaque := true
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var a := mi.mesh.surface_get_arrays(s)
			var idx = a[Mesh.ARRAY_INDEX]
			var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			tris += (idx.size() if idx != null else vs.size()) / 3
			vertices += vs.size()
			draws += 1
			var mat := _mat(mi, s) as BaseMaterial3D
			opaque = opaque and mat != null
			if mat != null:
				opaque = opaque and mat.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and is_equal_approx(mat.albedo_color.a, 1.0)
			var colors = a[Mesh.ARRAY_COLOR]
			if colors != null:
				for c: Color in colors:
					opaque = opaque and is_equal_approx(c.a, 1.0)
	return {"tris": tris, "draws": draws, "vertices": vertices, "opaque": opaque}


func _points(node: Node3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	var meshes: Array = [node] if node is MeshInstance3D else node.find_children("*", "MeshInstance3D", true, false)
	for mi: MeshInstance3D in meshes:
		if mi.mesh == null:
			continue
		var xf := node.global_transform.affine_inverse() * mi.global_transform
		for s in mi.mesh.get_surface_count():
			for v: Vector3 in mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
				out.append(xf * v)
	return out


func _bounds(pts: PackedVector3Array) -> AABB:
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for p in pts:
		lo = lo.min(p)
		hi = hi.max(p)
	return AABB(lo, hi - lo)


func _triangles(mi: MeshInstance3D) -> Array:
	var out := []
	for s in mi.mesh.get_surface_count():
		var a := mi.mesh.surface_get_arrays(s)
		var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var idx = a[Mesh.ARRAY_INDEX]
		var n: int = idx.size() if idx != null else vs.size()
		for i in range(0, n, 3):
			out.append([vs[idx[i] if idx != null else i], vs[idx[i + 1] if idx != null else i + 1], vs[idx[i + 2] if idx != null else i + 2]])
	return out


func _hit(tris: Array, y: float, z: float) -> bool:
	for t in tris:
		if Geometry3D.ray_intersects_triangle(Vector3(-1, y, z), Vector3.RIGHT, t[0], t[1], t[2]) != null:
			return true
	return false


func _method(source: String, name: String) -> String:
	var start := source.find("func " + name + "(")
	if start < 0:
		return ""
	var end := source.find("\n\nfunc ", start + 1)
	return source.substr(start, (end - start) if end >= 0 else -1).strip_edges()


# Only the construction block (including _parts) and its one cache declaration may change.
# Pin every other executable line, including source literals hidden by runtime clamping.
func _nonvisual(source: String) -> String:
	var start := source.find("func _build_tool(")
	var end := source.find("func _commit(")
	if start < 0 or end < start:
		return ""
	var kept := source.substr(0, start) + source.substr(end)
	var lines := PackedStringArray()
	for line in kept.split("\n"):
		var s := line.strip_edges()
		if s.is_empty() or s.begins_with("#") or s == "static var _shared: Array = []":
			continue
		lines.append(line)
	return "\n".join(lines)


func _run() -> void:
	var packed := load(GLB) as PackedScene
	_check(packed != null, "load", "enemy_swatter.glb imports")
	if packed == null:
		quit(1)
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	var m := _measure(scene)
	print("IMPORTED %d V / %d T / %d D" % [m.vertices, m.tris, m.draws])
	_check(m.tris > 0 and m.tris <= 3300, "asset-tris", "imported triangles <= 3300 (polished; was 1200)")
	_check(m.draws == 3, "asset-draws", "imported body two surfaces and paddle one surface")
	_check(m.opaque, "asset-alpha", "imported materials and vertex colours opaque")
	game.ctx.calm = true
	var unit = game.ctx.spawner.spawn_enemy("swatter", Vector3(0, 30, 0))
	unit.set_physics_process(false)
	var second = game.ctx.spawner.spawn_enemy("swatter", Vector3(20, 30, 0))
	second.set_physics_process(false)
	var live := _measure(unit)
	print("LIVE %d V / %d T / %d D" % [live.vertices, live.tris, live.draws])
	_check(live.tris > 0 and live.tris <= 3300, "live-tris", "full live assembly <= 3300 T, including hidden meshes")
	_check(live.draws > 0 and live.draws <= 3, "live-draws", "full live assembly <= 3 colour-pass surfaces")
	_check(live.opaque, "live-alpha", "full live assembly has no material or vertex alpha")
	_check(scene.find_children("*", "Light3D", true, false).is_empty() and unit.find_children("*", "Light3D", true, false).is_empty(),
		"lights", "imported and live assembly add zero lights")
	_check_base(unit)
	var body := unit.find_child("SwatterBody", true, false) as MeshInstance3D
	var paddle := unit.find_child("SwatterPaddle", true, false) as MeshInstance3D
	_check(body != null and paddle != null and unit.find_children("*", "MeshInstance3D", true, false).size() == 2,
		"assembly", "exactly the imported body and moving paddle; no primitive crew remains")
	if body != null and paddle != null:
		_check_geometry(unit, body, paddle)
		_check_paint(unit, body, paddle, scene)
		var body2 := second.find_child("SwatterBody", true, false) as MeshInstance3D
		var paddle2 := second.find_child("SwatterPaddle", true, false) as MeshInstance3D
		_check(body2 != null and paddle2 != null and body.mesh == body2.mesh and paddle.mesh == paddle2.mesh
			and unit._material != second._material, "cache", "two spawns share cached meshes, each owns its flashing material")
		if paddle2 != null:
			_check(paddle.mesh.surface_get_material(0) == paddle2.mesh.surface_get_material(0), "paint-shared", "vertex paint material shared across spawns")
	_check_hazard(unit)
	scene.free()
	game.free()
	print("enemy_swatter_asset_test: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(0 if failures == 0 else 1)


func _check_base(unit: Node3D) -> void:
	var shapes := unit.find_children("*", "CollisionShape3D", true, false)
	var cap := (shapes[0] as CollisionShape3D).shape as CapsuleShape3D if shapes.size() == 1 else null
	_check(cap != null and is_equal_approx(cap.radius, 0.8) and is_equal_approx(cap.height, 2.2)
		and (shapes[0] as Node3D).transform == Transform3D.IDENTITY, "collider", "one base capsule r 0.8 h 2.2 at identity")
	_check(unit.find_children("*", "CollisionObject3D", true, false).is_empty() and unit.collision_layer == 4
		and unit.collision_mask == 1 and is_equal_approx(unit.floor_max_angle, deg_to_rad(60)), "collision-flags", "base layer 4, mask 1, floor 60 degrees; no added collision objects")
	var values := {"radius": 0.8, "half_height": 1.1, "weight": 1.6, "walk_speed": 4.2,
		"keep_near": 3.0, "keep_far": 6.3, "attack_range": 7.0, "warn_seconds": 0.8,
		"live_seconds": 0.4, "rest_seconds": 2.4, "first_rest": 1.5, "scrap_value": 4}
	for key in values:
		_check(is_equal_approx(float(unit.get(key)), float(values[key])), "runtime-" + key, "base runtime %s = %s" % [key, values[key]])
	_check(unit.interruptible and is_equal_approx(unit.hp, unit.max_hp) and is_equal_approx(unit.max_hp / game.ctx.spawner._threat(), 45.0),
		"health", "base health 45 times threat and interruptible")
	var consts: Dictionary = unit.get_script().get_script_constant_map()
	var source := FileAccess.get_file_as_string(SOURCE)
	_check(_nonvisual(source) == BASE_NONVISUAL, "source-boundary", "every nonvisual executable line equals base, including all source constants and existing state/clock")
	for key in BASE_CONSTS:
		_check(consts.has(key) and is_equal_approx(float(consts[key]), float(BASE_CONSTS[key])), "const-" + key, "base constant %s = %s" % [key, BASE_CONSTS[key]])
	for key in BASE_METHODS:
		_check(_method(source, key) == BASE_METHODS[key], "source-" + key, "method %s equals base source, including unclamped literals" % key)


func _check_geometry(unit: Node3D, body: MeshInstance3D, paddle: MeshInstance3D) -> void:
	var crew_pts := _points(body)
	var radius := 0.0
	for p in crew_pts:
		radius = maxf(radius, Vector2(p.x, p.z).length())
	var crew_bounds := _bounds(crew_pts)
	print("CREW radius %.4f bounds %s" % [radius, crew_bounds])
	_check(body.transform == Transform3D.IDENTITY and radius <= 0.8 + 0.001 and crew_bounds.position.y >= -1.101
		and crew_bounds.end.y <= 1.821, "crew-footprint", "crew remains inside the base r 0.8 XZ collider footprint and base vertical envelope, ear tip y 1.82")
	_check(unit._paddle == paddle and paddle.position.is_equal_approx(Vector3(0, -0.6, 0))
		and paddle.scale.is_equal_approx(Vector3.ONE), "pivot", "one rigid paddle at the base pivot (0, -0.6, 0), scale one")
	var pts := _points(paddle)
	var bounds := _bounds(pts)
	var envelope := true
	for p in pts:
		var shaft := absf(p.x) <= 0.101 and absf(p.y) <= 0.101 and p.z >= 0.149 and p.z <= 5.651
		var blade := absf(p.x) <= 0.153 and p.y >= -0.301 and p.y <= 0.701 and p.z >= 4.599 and p.z <= 6.201
		var strip := absf(p.x) <= 0.161 and p.y >= 0.529 and p.y <= 0.711 and p.z >= 4.589 and p.z <= 6.211
		envelope = envelope and (shaft or blade or strip)
	print("TOOL LOCAL bounds %s" % bounds)
	_check(envelope and pts.size() > 0, "tool-envelope", "every tool vertex inside base shaft/blade/strip envelopes; no decorative extra reach")
	var corners := 0
	for x in [-0.1, 0.1]:
		for y in [-0.1, 0.1]:
			for z in [0.15, 5.65]:
				for p in pts:
					if p.distance_to(Vector3(x, y, z)) < 0.001:
						corners += 1
						break
	_check(corners == 8, "shaft", "5.5 m shaft at local centre (0, 0, 2.9), all eight corners retained")
	var blade_pts := PackedVector3Array()
	for p in pts:
		if absf(absf(p.x) - 0.15) < 0.0002:
			blade_pts.append(p)
	var blade_bounds := _bounds(blade_pts)
	print("BLADE bounds %s" % blade_bounds)
	# Godot's default mesh compression quantizes these vertices by about 0.1 mm.
	_check(blade_pts.size() > 0 and blade_bounds.position.distance_to(Vector3(-0.15, -0.3, 4.6)) < 0.0005
		and blade_bounds.size.distance_to(Vector3(0.3, 1.0, 1.6)) < 0.0005, "blade", "1.6 m by 1.0 m broad blade at local centre (0, 0.2, 5.4), thickness 0.3 m")
	var tris := _triangles(paddle)
	var covered := 0
	for y in [-0.15, 0.2, 0.55]:
		for z in [4.75, 5.0, 5.4, 5.75, 6.05]:
			covered += 1 if _hit(tris, y, z) else 0
	var connected := 0
	for i in 56:
		connected += 1 if _hit(tris, 0.0, 0.16 + i * 0.109) else 0
	_check(covered == 15 and connected == 56, "plane", "15 broad-face rays and 56 shaft-to-blade rays hit the continuous sweeping plane")
	var reach := 0.0
	for p in pts:
		reach = maxf(reach, Vector2(p.x, p.z).length())
	print("SWEEP visual vertex radius %.5f m; immutable hazard radius 7.50000 m" % reach)
	_check(reach <= 6.213 and reach >= 6.20, "reach", "base visual tip envelope retained, inside the unchanged 7.5 m hazard")
	var max_swept := 0.0
	for strafe in [-1.0, 1.0]:
		unit._strafe = strafe
		for sample in [[0, 0.0, 0.0], [1, 0.0, 0.0], [1, 0.4, -0.325], [1, 0.8, -0.65], [1, 1.6, -0.65], [2, 0.09, 1.25], [0, 0.0, 0.0]]:
			unit.phase = sample[0]
			unit._t = sample[1]
			unit._pose()
			_check(is_equal_approx(paddle.rotation.y, float(sample[2]) * strafe), "pose", "phase %d t %.2f strafe %.0f angle %.3f" % [sample[0], sample[1], strafe, paddle.rotation.y])
			for p in pts:
				var world_local: Vector3 = paddle.transform * p
				max_swept = maxf(max_swept, Vector2(world_local.x, world_local.z).length())
	_check(is_equal_approx(max_swept, reach), "rigid-sweep", "shaft and paddle sweep rigidly about the same existing pivot for both handednesses")


func _check_paint(unit: Node3D, body: MeshInstance3D, paddle: MeshInstance3D, scene: Node3D) -> void:
	var named := -1
	var found := 0
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			if mi.mesh.surface_get_material(i).resource_name == "fleet_paint":
				found += 1
				if mi.name.begins_with("SwatterBody"):
					named = i
	_check(found == 1 and named >= 0, "body-slot", "GLB itself names exactly one fleet_paint surface, on SwatterBody")
	var correct := body.material_override == null
	for s in body.mesh.get_surface_count():
		correct = correct and ((_mat(body, s) == unit._material) == (s == named))
	_check(correct and _mat(paddle, 0) != unit._material, "flash-slot", "enemy-owned flashing material only on GLB body slot, paddle never flashes")
	var paint_ok := true
	for mi in [body, paddle]:
		for s in mi.mesh.get_surface_count():
			if mi == body and s == named:
				continue
			var mat := _mat(mi, s) as StandardMaterial3D
			paint_ok = paint_ok and mat != null and mat.vertex_color_use_as_albedo and mat.albedo_color.is_equal_approx(Color.WHITE)
			paint_ok = paint_ok and not mat.emission_enabled and is_equal_approx(mat.roughness, 0.8)
	_check(paint_ok, "vertex-paint", "nonbody surfaces use rough vertex paint without a wash or whole-tool glow")
	_check(unit._base_color.is_equal_approx(Palette.RUST) and unit._material.albedo_color.is_equal_approx(Palette.RUST),
		"oxide", "resting body uses Fleet oxide RUST")
	unit.flash()
	unit._update_flash(0.0)
	_check(unit._material.albedo_color.is_equal_approx(Palette.RUST.lerp(Color(1, 1, 0.85), 1.0))
		and unit._material.emission_enabled, "flash", "existing hit flash reaches the actual body surface")
	for i in 20:
		unit._update_flash(0.1)
	_check(unit._material.albedo_color.is_equal_approx(Palette.RUST) and not unit._material.emission_enabled,
		"flash-recover", "flash settles back to oxide without resting glow")


func _check_hazard(unit: Node3D) -> void:
	unit._strafe = 1.0
	var tele: Node3D = unit._commit(Vector3(0, 0, 1))
	_check(tele != null, "telegraph", "existing commit still creates a wedge")
	if tele == null:
		return
	_check(is_equal_approx(tele.radius, 7.5) and is_equal_approx(tele.half_angle, deg_to_rad(55))
		and is_equal_approx(tele.reach_up, 1.6), "hazard", "actual committed wedge radius 7.5 m, half-angle 55 degrees, height 1.6 m")
	var inside: Vector3 = tele.center + tele.dir * 7.49
	var outside: Vector3 = tele.center + tele.dir * 7.51
	inside.y = unit.terrain.height(inside.x, inside.z) + 0.5
	outside.y = unit.terrain.height(outside.x, outside.z) + 0.5
	_check(tele.contains(inside) and not tele.contains(outside), "hazard-boundary", "7.49 m on heading inside; 7.51 m outside the unchanged swept hazard")
