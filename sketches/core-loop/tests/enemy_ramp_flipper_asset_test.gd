# 2026-10-12, W13 smoke triage: class c re-pin for 5b903a3, bbe53ec, 17429d6.
# counter.gd SHA256 56b1e9fd180b0c5c06ba67013011c12a26d6f6f1989cb6c140620334b06f0cca -> 5e3d17ed123286ed2c22808f3051a76d450e56697828d7277cef3b8f0af7c554; merged pack stagger, rename and shared-recovery changes.
extends SceneTree

const Palette := preload("res://src/core/palette.gd")
const GLB := "res://assets/models/world_one/enemy_ramp_flipper.glb"
# 2026-10-23 w19 Spillway roster: the sluice flap's speed ride (RIDE_KICK, RIDE_TIER, _ride) and its
# codex discovery, design-v3/SPILLWAY-ROSTER.md; was f81182dc.
# 2026-11-24 W46-ANIM-VFX-FLAIR: eased deploy/kick/fold plate pose (DEPLOY_S, KICK_S, FOLD_S, _fold_t)
# and presentation VFX bursts in _commit/_go_live; gameplay mechanics unchanged; was 494ee927.
# 2026-11-24 W47-E3: Catapult Double-Snap secondary (0.65 s double-ratchet steeper kicker when
# approaching >= FAST; Jump on double-snap = +12 m/s forward boost + instant Blazing tier); was 7a672f2f.
const BASE_MECHANIC_SHA := "6940664f8514936d98b1330839fcf283143385a43d4b817df1701328898a6156"
const BASE_CONSTS := {"PLATE_RADIUS": 3.6, "LEAD": .9, "TILT": .35, "FLING_UP": 30.0,
	"FLING_SIDE": 22.0, "RIDE_UP": 9.0, "HP": 45.0}
const BASE_VALUES := {"radius": .8, "half_height": 1.1, "weight": 1.2, "scrap_value": 4,
	"warn_seconds": 1.0, "live_seconds": .4, "rest_seconds": 3.0, "attack_range": 26.0,
	"walk_speed": 3.8, "keep_near": 9.0, "keep_far": 23.4, "first_rest": 1.5,
	"hp": 45.0, "max_hp": 45.0, "plating": 0.0}
var failures := 0
var arena: Node3D
var target: Node3D


class FlatGround extends RefCounted:
	func height(_x: float, _z: float) -> float:
		return 0.0


class Target extends Node3D:
	func ball_position() -> Vector3:
		return Vector3(8, 0, 0)

	func planar_velocity() -> Vector3:
		return Vector3.ZERO


func _initialize() -> void:
	arena = Node3D.new()
	root.add_child(arena)
	target = Target.new()
	arena.add_child(target)
	_run.call_deferred()


func _spawn(at: Vector3) -> Node3D:
	var enemy: Node3D = load("res://src/combat/ramp_flipper.gd").new()
	arena.add_child(enemy)
	enemy.position = at
	enemy.setup(target, FlatGround.new(), arena, Callable(), 1.0, {"kind": "ramp_flipper"})
	enemy.set_physics_process(false)
	return enemy


func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
	print("%s %s" % ["PASS" if ok else "FAIL", label])


func _mat(mi: MeshInstance3D, s: int) -> Material:
	# Whole-mesh override has priority over surface overrides in Godot.
	if mi.material_override != null:
		return mi.material_override
	var mat := mi.get_surface_override_material(s)
	return mat if mat != null else mi.mesh.surface_get_material(s)


func _measure(node: Node) -> Dictionary:
	var result := {"tris": 0, "draws": 0, "vertices": 0, "opaque": true, "lights": 0}
	for m in node.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var a := mi.mesh.surface_get_arrays(s)
			var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var idx = a[Mesh.ARRAY_INDEX]
			result.tris += int((idx.size() if idx != null else vs.size()) / 3)
			result.vertices += vs.size()
			result.draws += 1
			var mat := _mat(mi, s) as BaseMaterial3D
			result.opaque = result.opaque and mat != null and mat.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and mat.albedo_color.a == 1.0
			var colors = a[Mesh.ARRAY_COLOR]
			if colors != null:
				for c: Color in colors:
					result.opaque = result.opaque and c.a == 1.0
	result.lights = node.find_children("*", "Light3D", true, false).size()
	return result


func _vertices(mi: MeshInstance3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	for s in mi.mesh.get_surface_count():
		out.append_array(mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX])
	return out


func _mechanic_source(source: String) -> String:
	# Exclude only the three permitted mesh-wiring functions, the cache and comments. Every other
	# executable line is pinned to base 38a1526, including literals beneath inherited clamps.
	var lines := PackedStringArray()
	var skip := false
	for line in source.split("\n"):
		if not line.strip_edges().is_empty() and line == line.lstrip(" \t") and not line.begins_with("#"):
			skip = line.begins_with("func _build_tool(") or line.begins_with("static func _parts(") or line.begins_with("static func reset_for_tests(")
		if skip or line.begins_with("static var _shared") or line.strip_edges().is_empty() or line.strip_edges().begins_with("#"):
			continue
		lines.append(line)
	return "\n".join(lines)


func _base(enemy: Node3D) -> void:
	var source := FileAccess.get_file_as_string("res://src/combat/ramp_flipper.gd")
	_check(_mechanic_source(source).sha256_text() == BASE_MECHANIC_SHA, "base source literals and all non-mesh code unchanged")
	# Shared combat files are not pinned here; the merge-time fence owns shared-file changes (2026-10-13, ENEMY-PINS).
	var constants: Dictionary = enemy.get_script().get_script_constant_map()
	for key in BASE_CONSTS:
		_check(constants.has(key) and is_equal_approx(float(constants[key]), BASE_CONSTS[key]), "base constant %s = %s" % [key, BASE_CONSTS[key]])
	for key in BASE_VALUES:
		_check(is_equal_approx(float(enemy.get(key)), float(BASE_VALUES[key])), "base runtime %s = %s" % [key, BASE_VALUES[key]])
	_check(enemy.collision_layer == 4 and enemy.collision_mask == 1 and is_equal_approx(enemy.floor_max_angle, deg_to_rad(60)), "base collision layers and floor angle unchanged")
	var shapes := enemy.find_children("*", "CollisionShape3D", true, false)
	var cap: CapsuleShape3D = shapes[0].shape as CapsuleShape3D if shapes.size() == 1 else null
	_check(cap != null and is_equal_approx(cap.radius, .8) and is_equal_approx(cap.height, 2.2)
		and shapes[0].position == Vector3.ZERO and shapes[0].scale == Vector3.ONE and not shapes[0].disabled,
		"one base capsule radius .8 height 2.2 at origin")
	_check(enemy.find_children("*", "CollisionObject3D", true, false).is_empty(), "no new ramp collider or collision object")


func _footprint(body: MeshInstance3D, plate: MeshInstance3D) -> void:
	var inside := true
	for v in _vertices(body):
		var p: Vector3 = body.transform * v
		inside = inside and Vector2(p.x, p.z).length() <= .801 and p.y >= -1.101 and p.y <= 1.751
	_check(inside, "crew/cart inside collider planar radius .8 and base crew height envelope")
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for v in _vertices(plate):
		lo = lo.min(v)
		hi = hi.max(v)
	print("plate bounds: %s .. %s" % [lo, hi])
	_check(lo.x >= -2.881 and hi.x <= 2.881 and lo.z >= -2.881 and hi.z <= 2.881 and lo.y >= -.091 and hi.y <= .091,
		"plate inside base 5.76 square / .18 thick visual footprint")
	_check(is_equal_approx(hi.x - lo.x, 5.76) and is_equal_approx(hi.z - lo.z, 5.76)
		and is_equal_approx(hi.y - lo.y, .18), "plate retains full base width depth and thickness")
	_check(plate.position.is_equal_approx(Vector3(0, 1.5, -.4)) and plate.scale.is_equal_approx(Vector3.ONE * .4)
		and plate.rotation.is_zero_approx() and not plate.top_level, "base carried plate transform unchanged")


func _paint(enemy: Node3D, body: MeshInstance3D, plate: MeshInstance3D, raw: Node3D) -> void:
	var raw_body := raw.find_child("RampBody", true, false) as MeshInstance3D
	var slot := -1
	var count := 0
	for node in raw.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = node.mesh
		for s in mesh.get_surface_count():
			if mesh.surface_get_material(s).resource_name == "fleet_paint":
				count += 1
				if node == raw_body:
					slot = s
	_check(count == 1 and slot >= 0, "GLB itself names exactly one fleet_paint surface on RampBody")
	var correct := slot >= 0 and body.material_override == null
	for s in body.mesh.get_surface_count():
		correct = correct and ((_mat(body, s) == enemy._material) == (s == slot))
	for s in plate.mesh.get_surface_count():
		correct = correct and _mat(plate, s) != enemy._material
	_check(correct, "enemy flashing material only on GLB body slot; plate never flashes")
	var painted := true
	for mi in [body, plate]:
		for s in mi.mesh.get_surface_count():
			if mi == body and s == slot:
				continue
			var mat := _mat(mi, s) as StandardMaterial3D
			painted = painted and mat != null and mat.vertex_color_use_as_albedo and is_equal_approx(mat.roughness, .8)
	_check(painted, "other surfaces use opaque vertex-colour paint roughness .8")
	_check(enemy._base_color.is_equal_approx(Palette.RUST) and enemy._material.albedo_color.is_equal_approx(Palette.RUST), "resting body Fleet oxide")
	enemy.flash()
	enemy._update_flash(0.0)
	_check(_mat(body, slot) == enemy._material and enemy._material.albedo_color.is_equal_approx(Palette.RUST.lerp(Color(1, 1, .85), 1.0))
		and enemy._material.emission_enabled, "existing hit flash reaches GLB body")
	for i in 20:
		enemy._update_flash(.1)
	_check(enemy._material.albedo_color.is_equal_approx(Palette.RUST) and not enemy._material.emission_enabled, "existing hit flash recovers to oxide")


func _pose(enemy: Node3D, plate: MeshInstance3D) -> void:
	var ring: Node3D = enemy._commit(Vector3.ZERO)
	_check(ring != null and plate.top_level and plate.scale.is_equal_approx(Vector3.ONE)
		and plate.global_position.is_equal_approx(ring.center + Vector3.UP * .1), "commit deploys plate at existing ring centre plus .1 at scale 1")
	if ring == null:
		return
	var sides := [Vector3.RIGHT, Vector3.BACK, Vector3(1, 0, 1).normalized()]
	for side: Vector3 in sides:
		enemy._side = side
		var axis := side.cross(Vector3.UP).normalized()
		var normal_loaded := Vector3.ZERO
		var normal_released := Vector3.ZERO
		for state in [[1, 0.0, 0.0], [1, .5, .14], [1, 1.0, .28], [1, 2.0, .28], [2, .09, .65]]:
			enemy.set("phase", state[0])
			enemy.set("_t", state[1])
			enemy._pose()
			var want := Basis(axis, state[2])
			_check(plate.basis.orthonormalized().is_equal_approx(want), "state pose phase %d clock %.2f side %s angle %.3f" % [state[0], state[1], side, state[2]])
			if state[0] == 1 and state[1] == 1.0:
				normal_loaded = plate.basis.orthonormalized().y
			if state[0] == 2:
				normal_released = plate.basis.orthonormalized().y
		var rise := 0.0
		var in_sweep := true
		for v in _vertices(plate):
			var loaded := Basis(axis, .28) * v
			var released := Basis(axis, .65) * v
			rise = maxf(rise, absf(released.y - loaded.y))
			# Convex base-box support in each rotated axis bounds the entire moving mesh.
			for angle in [.0, .14, .28, .65]:
				var rot := Basis(axis, angle)
				var point := rot * v
				var limit := rot.x.abs() * 2.88 + rot.y.abs() * .09 + rot.z.abs() * 2.88
				in_sweep = in_sweep and point.abs().x <= limit.x + .001 and point.abs().y <= limit.y + .001 and point.abs().z <= limit.z + .001
		print("loaded/released side %s: normal delta %.3f rad, max vertex height delta %.3f m" % [side, normal_loaded.angle_to(normal_released), rise])
		_check(normal_loaded.angle_to(normal_released) >= .35 and rise >= .91,
			"loaded versus released: >= .35 rad normal change and >= .91 m deck edge travel")
		_check(in_sweep, "moving plate stays inside rotated base box sweep")
		enemy._pose()
		var once := plate.basis
		enemy._pose()
		_check(plate.basis.is_equal_approx(once), "same state and clock produce same pose without accumulation")
	enemy._on_end()
	_check(not plate.top_level and plate.position.is_equal_approx(Vector3(0, 1.5, -.4))
		and plate.rotation.is_zero_approx() and plate.scale.is_equal_approx(Vector3.ONE * .4), "recover restores base carried pose")
	_check(enemy.find_children("*", "CollisionShape3D", true, false).size() == 1
		and enemy.find_children("*", "CollisionObject3D", true, false).is_empty(), "deployed and recovered plate add no collider")
	enemy._clear_telegraph()


func _run() -> void:
	var packed := load(GLB) as PackedScene
	_check(packed != null, "GLB loads")
	if packed == null:
		quit(1)
		return
	var raw := packed.instantiate() as Node3D
	root.add_child(raw)
	var named_body := raw.find_child("RampBody", true, false) as MeshInstance3D
	var named_plate := raw.find_child("RampPlate", true, false) as MeshInstance3D
	var body_slots := 0
	if named_body != null:
		for s in named_body.mesh.get_surface_count():
			if named_body.mesh.surface_get_material(s).resource_name == "fleet_paint":
				body_slots += 1
	_check(named_body != null and named_plate != null and body_slots == 1, "GLB preflight has body plate and one body fleet_paint slot")
	if named_body == null or named_plate == null or body_slots != 1:
		raw.free()
		quit(1)
		return
	var enemy := _spawn(Vector3(0, 30, 0))
	var live := _measure(enemy)
	print("live assembly: %d V / %d T / %d D" % [live.vertices, live.tris, live.draws])
	# A scratch base revert reports the original full assembly before failing the new budget.
	_check(live.tris > 0 and live.tris <= 4400, "live full assembly <= 4400 triangles (polished; was 1200)")
	_check(live.draws > 0 and live.draws <= 3, "live full assembly <= 3 colour surfaces/draws")
	_check(live.opaque and live.lights == 0, "live full assembly opaque with zero lights")
	_base(enemy)
	var asset := _measure(raw)
	print("asset: %d V / %d T / %d D" % [asset.vertices, asset.tris, asset.draws])
	_check(asset.tris > 0 and asset.tris <= 4400 and asset.draws == 3 and asset.vertices <= 8400, "GLB assembly within 8400 V / 4400 T / 3 D (polished)")
	_check(asset.opaque and asset.lights == 0, "GLB opaque with zero lights")
	var body := enemy.find_child("RampBody", true, false) as MeshInstance3D
	var plate := enemy.find_child("RampPlate", true, false) as MeshInstance3D
	_check(body != null and plate != null and enemy._plate == plate and enemy._crew == null
		and enemy.find_children("*", "MeshInstance3D", true, false).size() == 2, "live assembly contains only GLB body and moving plate")
	if body != null and plate != null:
		_footprint(body, plate)
		_paint(enemy, body, plate, raw)
		_pose(enemy, plate)
		var second := _spawn(Vector3(10, 30, 0))
		var b2 := second.find_child("RampBody", true, false) as MeshInstance3D
		var p2 := second.find_child("RampPlate", true, false) as MeshInstance3D
		_check(b2 != null and p2 != null and b2.mesh == body.mesh and p2.mesh == plate.mesh
			and second._material != enemy._material, "static cache shares GLB meshes; enemy flash materials remain distinct")
	raw.free()
	print("enemy_ramp_flipper_asset_test: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(0 if failures == 0 else 1)
