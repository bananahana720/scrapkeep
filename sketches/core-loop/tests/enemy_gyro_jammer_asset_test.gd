# 2026-10-12, W13 smoke triage: class c re-pin for 5b903a3, bbe53ec, 17429d6.
# counter.gd SHA256 56b1e9fd180b0c5c06ba67013011c12a26d6f6f1989cb6c140620334b06f0cca -> 5e3d17ed123286ed2c22808f3051a76d450e56697828d7277cef3b8f0af7c554; merged pack stagger, rename and shared-recovery changes.
extends SceneTree

const Game := preload("res://src/game.gd")
const Gyro := preload("res://src/combat/gyro_jammer.gd")
const Palette := preload("res://src/core/palette.gd")
const GLB := "res://assets/models/world_one/enemy_gyro_jammer.glb"
const BASE_CONSTS := {"FIELD_RADIUS": 7.0, "DRIFT": 11.0, "DRIFT_HZ": 0.7, "HP": 40.0}
const BASE_CONFIGURE := """func _configure(threat: float) -> void:
	_set_health(HP * threat)
	scrap_value = 4
	weight = 1.0
	warn_seconds = 1.0
	live_seconds = 3.0
	rest_seconds = 3.8
	attack_range = 20.0"""
# Re-pinned 2026-10-13: _go_live takes its drift phase from position (IDENTITY-DET, 24af02f1), on purpose.
const BASE_GAMEPLAY := """func _commit(_to_ball: Vector3) -> Node3D:
	return _commit_ring(Threat.Type.INSTANT, _ball(), FIELD_RADIUS, 4.0)


func _go_live() -> void:
	# The drift phase comes from where the jammer stands, never from its runtime identity.
	var p := global_position
	_phase0 = fposmod(p.x * 0.37 + p.z * 0.61, TAU)


func _live(_delta: float) -> bool:
	var field := telegraph()
	if field == null:
		return false
	var player = _player()
	if not field.contains(_real_ball()):
		if _holding():
			_release("left")
		return true
	if not _holding() and not _catch():
		return true
	var v: Vector3 = player.planar_velocity()
	var across := v.cross(Vector3.UP).normalized() if v.length() > 1.0 else Vector3.RIGHT
	_pull(across * DRIFT * sin(_phase0 + _t * TAU * DRIFT_HZ))
	return true


func _pose() -> void:
	if _aerial != null:
		_aerial.rotation.y += 0.3 if phase == Phase.LIVE else 0.05"""
const BASE_RUNTIME := {
	"hp": 40.0, "max_hp": 40.0, "plating": 0.0, "scrap_value": 4, "weight": 1.0,
	"walk_speed": 3.8, "keep_near": 9.0, "keep_far": 18.0, "attack_range": 20.0,
	"warn_seconds": 1.0, "live_seconds": 3.0, "rest_seconds": 3.8, "first_rest": 1.5,
	"interruptible": true, "radius": 0.8, "half_height": 1.1, "collision_layer": 4, "collision_mask": 1,
}
var failures := 0
var game
var fixture_root: Node3D


func _initialize() -> void:
	# Scratch mutants can exercise the same counter.setup/build path without
	# generating the whole terrain. The default run uses the game's real spawner.
	if "--asset-fixture" in OS.get_cmdline_user_args():
		fixture_root = Node3D.new()
		root.add_child(fixture_root)
	else:
		game = Game.new()
		game.test_mode = true
		root.add_child(game)
	_run.call_deferred()


func _spawn(at: Vector3) -> Node3D:
	if game != null:
		return game.ctx.spawner.spawn_enemy("gyro_jammer", at)
	var jammer := Gyro.new()
	fixture_root.add_child(jammer)
	jammer.position = at
	jammer.setup(null, null, fixture_root, Callable(), 1.0, {"kind": "gyro_jammer"})
	return jammer


func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
	print("%s %s" % ["PASS" if ok else "FAIL", label])


func _mat_of(mi: MeshInstance3D, s: int) -> Material:
	var mat := mi.get_surface_override_material(s)
	if mat == null:
		mat = mi.material_override
	if mat == null:
		mat = mi.mesh.surface_get_material(s)
	return mat


func _measure(node: Node) -> Dictionary:
	var tris := 0
	var draws := 0
	var vertices := 0
	var alpha := false
	var emission := false
	for m in node.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			draws += 1
			var arrays := mi.mesh.surface_get_arrays(s)
			var idx = arrays[Mesh.ARRAY_INDEX]
			var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			vertices += vs.size()
			tris += (idx.size() if idx != null else vs.size()) / 3
			var mat := _mat_of(mi, s) as BaseMaterial3D
			if mat != null:
				alpha = alpha or mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or mat.albedo_color.a < 0.999
				emission = emission or mat.emission_enabled
			if arrays[Mesh.ARRAY_COLOR] != null:
				for c in arrays[Mesh.ARRAY_COLOR] as PackedColorArray:
					alpha = alpha or c.a < 0.999
	return {"tris": tris, "draws": draws, "vertices": vertices, "alpha": alpha, "emission": emission}


func _points(node: Node3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	for m in node.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var xf: Transform3D = node.global_transform.affine_inverse() * mi.global_transform
		for s in mi.mesh.get_surface_count():
			for v in mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array:
				out.append(xf * v)
	return out


func _run() -> void:
	var packed := load(GLB) as PackedScene
	_check(packed != null, "glb loads")
	if packed == null:
		quit(1)
		return
	var scene := packed.instantiate()
	var asset := _measure(scene)
	print("asset: %d V, %d T, %d D" % [asset.vertices, asset.tris, asset.draws])
	_check(asset.tris > 0 and asset.tris <= 5000, "asset triangle ceiling")
	_check(asset.draws > 0 and asset.draws <= 3, "asset draw ceiling")
	_check(not asset.alpha, "asset opaque")
	_check(not asset.emission, "asset has no persistent emission")
	scene.free()
	if game != null:
		game.ctx.calm = true
	print("assembly method: " + ("real game spawner" if game != null else "counter.setup scratch fixture"))
	var jammer = _spawn(Vector3(0, 30, 0))
	jammer.set_physics_process(false)
	_check_base(jammer)
	var live := _measure(jammer)
	print("live assembly: %d V, %d T, %d D" % [live.vertices, live.tris, live.draws])
	_check(live.tris > 0 and live.tris <= 5000, "live triangle ceiling")
	_check(live.draws > 0 and live.draws <= 3, "live draw ceiling")
	_check(not live.alpha, "live opaque")
	_check(not live.emission, "live has no persistent emission")
	_check(jammer.find_children("*", "Light3D", true, false).is_empty(), "no added lights")
	var aerial := jammer.find_child("GyroAerial", true, false) as MeshInstance3D
	var body := jammer.find_child("GyroBody", true, false) as MeshInstance3D
	_check(body != null and aerial != null and jammer._aerial == aerial and jammer._crew == null,
		"glb replaces crew and drives aerial")
	_check_bounds(jammer)
	if aerial != null:
		_check_rings(aerial)
		_check_pose(jammer, aerial)
	if body != null:
		_check_paint(jammer, body)
		_check_cache(jammer, body, aerial)
	print("enemy_gyro_jammer_asset_test: %s" % ("PASS" if failures == 0 else "FAIL"))
	if game != null:
		game.free()
	else:
		fixture_root.free()
	quit(0 if failures == 0 else 1)


func _check_base(jammer: Node3D) -> void:
	var shapes := jammer.find_children("*", "CollisionShape3D", true, false)
	var cap := (shapes[0] as CollisionShape3D).shape as CapsuleShape3D if shapes.size() == 1 else null
	_check(cap != null and is_equal_approx(cap.radius, 0.8) and is_equal_approx(cap.height, 2.2)
		and (shapes[0] as Node3D).transform.is_equal_approx(Transform3D.IDENTITY), "base capsule and transform")
	_check(jammer.find_children("*", "CollisionObject3D", true, false).is_empty(), "no dressing collider")
	for key in BASE_RUNTIME:
		var value = jammer.get(key)
		_check(value != null and is_equal_approx(float(value), float(BASE_RUNTIME[key])), "base runtime " + key)
	var consts: Dictionary = (jammer.get_script() as Script).get_script_constant_map()
	for key in BASE_CONSTS:
		_check(consts.has(key) and is_equal_approx(float(consts[key]), BASE_CONSTS[key]), "base constant " + key)
	var source := FileAccess.get_file_as_string("res://src/combat/gyro_jammer.gd")
	var config := source.get_slice("func _configure", 1).get_slice("\n\n", 0)
	_check("func _configure" + config == BASE_CONFIGURE, "base configure source literals")
	_check("func _commit" + source.get_slice("func _commit", 1).strip_edges() == BASE_GAMEPLAY,
		"base gameplay and pose source literals")
	# Shared combat files are not pinned here; the merge-time fence owns shared-file changes (2026-10-13, ENEMY-PINS).
	for key in BASE_CONSTS:
		_check(source.split("\n").has("const %s := %.1f" % [key, BASE_CONSTS[key]]), "base constant source " + key)


func _check_bounds(jammer: Node3D) -> void:
	var aerial := jammer.find_child("GyroAerial", true, false) as MeshInstance3D
	var saved := aerial.transform if aerial != null else Transform3D.IDENTITY
	var reach := 0.0
	var bottom := INF
	var top := -INF
	for k in 32:
		if aerial != null:
			aerial.rotation.y = TAU * k / 32
		for p in _points(jammer):
			reach = maxf(reach, Vector2(p.x, p.z).length())
			bottom = minf(bottom, p.y)
			top = maxf(top, p.y)
	if aerial != null:
		aerial.transform = saved
	print("sweep bounds: radial %.4f, y %.4f..%.4f (32 yaw samples)" % [reach, bottom, top])
	_check(reach <= 0.801, "inside radius 0.8 collider footprint through spin")
	_check(bottom >= -1.101 and top <= 4.301, "base ground and aerial height envelope")
	if aerial != null:
		# All rotating vertices lie in a horizontal disc centred at the pivot. This
		# analytic bound covers every yaw angle between the samples too.
		var local_reach := 0.0
		for v in aerial.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array:
			var p: Vector3 = aerial.basis * v
			local_reach = maxf(local_reach, Vector2(p.x, p.z).length())
		var swept: float = Vector2(aerial.position.x, aerial.position.z).length() + local_reach
		print("analytic aerial sweep radius %.4f" % swept)
		_check(swept <= 0.801, "continuous aerial sweep fits collider footprint")


# Weld duplicated colour/normal seam vertices to 1e-5 m, then flood triangle-edge
# connectivity. A real hoop is one closed shell; names/metadata cannot supply it.
func _components(mesh: Mesh) -> Array:
	var points: Array[Vector3] = []
	var by_pos := {}
	var edges: Array = []
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var ids := PackedInt32Array()
		for v in vs:
			var key := Vector3i(roundi(v.x * 100000), roundi(v.y * 100000), roundi(v.z * 100000))
			if not by_pos.has(key):
				by_pos[key] = points.size()
				points.append(v)
				edges.append({})
			ids.append(by_pos[key])
		var ix: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for i in range(0, ix.size(), 3):
			for j in 3:
				var a := ids[ix[i + j]]
				var b := ids[ix[i + (j + 1) % 3]]
				edges[a][b] = true
				edges[b][a] = true
	var seen := {}
	var groups := []
	for start in points.size():
		if seen.has(start):
			continue
		var group: Array[Vector3] = []
		var pending := [start]
		seen[start] = true
		while not pending.is_empty():
			var at: int = pending.pop_back()
			group.append(points[at])
			for next in edges[at]:
				if not seen.has(next):
					seen[next] = true
					pending.append(next)
		groups.append(group)
	return groups


func _check_rings(aerial: MeshInstance3D) -> void:
	var groups := _components(aerial.mesh)
	_check(groups.size() == 3, "three connected hoop shells")
	if groups.size() != 3:
		return
	var rings := []
	for group in groups:
		var center := Vector3.ZERO
		for p: Vector3 in group:
			center += p
		center /= group.size()
		var covariance := Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)
		var outer := 0.0
		var inner := INF
		for p: Vector3 in group:
			var v := p - center
			covariance.x += v * v.x
			covariance.y += v * v.y
			covariance.z += v * v.z
			outer = maxf(outer, v.length())
			inner = minf(inner, v.length())
		var normal := Vector3(1.0, 0.7, 0.4).normalized()
		if absf(covariance.determinant()) > 0.00000001:
			var inv := covariance.inverse()
			for i in 20:
				normal = (inv * normal).normalized()
		var thickness := 0.0
		for p: Vector3 in group:
			thickness = maxf(thickness, absf((p - center).dot(normal)))
		var tilt := rad_to_deg(acos(clampf(absf(normal.dot(Vector3.UP)), 0.0, 1.0)))
		print("hoop: %d welded V, center %s, outer %.4f, inner %.4f, half-thickness %.4f, tilt %.2f deg" % [group.size(), center, outer, inner, thickness, tilt])
		_check(group.size() == 64 and thickness <= 0.036 and inner >= outer - 0.071,
			"hoop is an open 16x4 thin tube")
		_check(tilt >= 25.0, "hoop plane tilted at least 25 degrees from horizontal")
		rings.append({"center": center, "outer": outer, "inner": inner, "normal": normal})
	rings.sort_custom(func(a, b): return a.outer > b.outer)
	for i in 3:
		_check(absf(rings[i].outer - [0.55, 0.43, 0.31][i]) <= 0.001, "hoop outer radius " + str(i))
		_check(rings[i].center.distance_to(Vector3(0, 0.95, 0)) <= 0.005, "hoop shares nested center " + str(i))
		if i > 0:
			_check(rings[i].outer < rings[i - 1].inner - 0.025, "nested hoop radial clearance " + str(i))
	for i in 3:
		for j in range(i + 1, 3):
			var angle := rad_to_deg(acos(clampf(absf(rings[i].normal.dot(rings[j].normal)), 0.0, 1.0)))
			print("hoop plane separation %d/%d: %.2f deg" % [i, j, angle])
			_check(angle >= 25.0, "distinct hoop planes %d/%d" % [i, j])


func _check_pose(jammer: Node3D, aerial: MeshInstance3D) -> void:
	_check(aerial.position.is_equal_approx(Vector3(0, 2.6, -0.2)), "base aerial pivot")
	var saved := aerial.transform
	var saved_phase: int = jammer.phase
	for phase in 3:
		jammer.phase = phase
		var before := aerial.rotation.y
		var clock: float = jammer._t
		jammer._pose()
		_check(is_equal_approx(aerial.rotation.y - before, 0.3 if phase == 2 else 0.05)
			and is_equal_approx(jammer._t, clock), "existing phase spin " + str(phase))
	aerial.transform = saved
	jammer.phase = saved_phase


func _check_paint(jammer: Node3D, body: MeshInstance3D) -> void:
	var scene := (load(GLB) as PackedScene).instantiate()
	var slots := {}
	var fleet := []
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var slot := mi.mesh.surface_get_material(s).resource_name
			slots[str(mi.name) + ":" + str(s)] = slot
			if slot == "fleet_paint":
				fleet.append([mi.name, s])
	scene.free()
	_check(fleet.size() == 1 and fleet[0][0] == "GyroBody", "glb names one crew fleet_paint slot")
	for node in jammer.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var key := str(mi.name) + ":" + str(s)
			var slot: String = slots.get(key, "missing")
			var mat := _mat_of(mi, s) as BaseMaterial3D
			_check(slot in ["fleet_paint", "paint"] and mat != null and
				(mat == jammer._material) == (slot == "fleet_paint"), "flash on glb slot " + key)
			if slot == "paint":
				_check(mat != null and mat.vertex_color_use_as_albedo, "vertex paint " + key)
	_check(jammer._base_color.is_equal_approx(Palette.RUST) and jammer._material.albedo_color.is_equal_approx(Palette.RUST), "resting oxide body")
	jammer.flash()
	jammer._update_flash(0.0)
	_check(jammer._material.albedo_color.is_equal_approx(Color(1, 1, 0.85)) and jammer._material.emission_enabled, "existing hit flash")
	for i in 20:
		jammer._update_flash(0.1)
	_check(jammer._material.albedo_color.is_equal_approx(Palette.RUST) and not jammer._material.emission_enabled, "flash settles to oxide")


func _check_cache(jammer: Node3D, body: MeshInstance3D, aerial: MeshInstance3D) -> void:
	var other = _spawn(Vector3(5, 30, 0))
	other.set_physics_process(false)
	var other_body := other.find_child("GyroBody", true, false) as MeshInstance3D
	var other_aerial := other.find_child("GyroAerial", true, false) as MeshInstance3D
	_check(other_body != null and other_aerial != null and aerial != null and body.mesh == other_body.mesh
		and aerial.mesh == other_aerial.mesh, "instances share cached glb meshes")
	_check(jammer._material != other._material, "instances own separate flash materials")
	other.free()
