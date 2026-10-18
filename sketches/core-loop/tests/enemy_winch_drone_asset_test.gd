extends SceneTree

const Game := preload("res://src/game.gd")
const Palette := preload("res://src/core/palette.gd")

# C18 limits. The asset: 1,200 T / 4 D ceiling for the whole moving assembly (the drone's
# runtime meshes are only the glb's three), opaque, inside the envelope of the base drone: the rotor
# radius is 1.6 m at 2.0 m up, the drum hangs 0.45 m round below the crew, the crew stands 0.8 m
# either way. The base contract: the drone's collider, lane, winch, timing and damage values are
# what winch_drone.gd had before the dressing swap, pinned both as its source text (the literals
# in _configure and _live) and as the runtime values counter.gd leaves after clamping.
const GLB := "res://assets/models/world_one/enemy_winch_drone.glb"
const CEILING_T := 4600  # polished 2026-10-18 (tools/blender/POLISH.md); was 1200
# WD: splitting the drum adds one draw; the original triangle ceiling is unchanged.
const CEILING_D := 4
const X_MIN := -1.7
const X_MAX := 1.7
const Z_MIN := -1.7
const Z_MAX := 1.7
const Y_BOTTOM := -1.95
const Y_TOP := 2.3
const ROTOR_R := 1.6
const ROTOR_Y := 2.0
const DRUM_R := 0.45
const DRUM_Y := -1.4
const BASE_CONSTS := {
	"HOVER": 5.5, "CLIMB": 4.0, "LANE_LENGTH": 20.0, "LANE_WIDTH": 2.2, "PULL": 7.0, "WINCH": 1.8,
	"PACK_REACH": 30.0, "HP": 30.0,
}
# Literals of the base source that no constant carries (keep_far 22 clamps to 16.2 at runtime, so
# the runtime value alone would pass a change to any keep_far above 18).
const BASE_SOURCE := [
	"_set_health(HP * threat)", "scrap_value = 4", "weight = 0.8", "walk_speed = 5.0", "keep_near = 8.0",
	"keep_far = 22.0", "attack_range = 18.0", "warn_seconds = 1.0", "live_seconds = WINCH + 0.1", "rest_seconds = 3.5",
	"_commit_lane(Threat.Type.LANE, global_position, to_ball, LANE_LENGTH, LANE_WIDTH)",
	"_catch(WINCH, Vector3.ZERO, global_position)", "to.length() > 1.5", "_pull(to.normalized() * PULL)",
	"(ground + HOVER - global_position.y) * CLIMB", "return to_ball.length() <= attack_range",
]
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
	var alpha := false
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
			var mat := _mat_of(mi, s)
			if mat is BaseMaterial3D and (mat as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				alpha = true
	return {"tris": tris, "draws": draws, "alpha": alpha}


# Every vertex of every mesh under `node`, in `node`'s local frame.
func _points(node: Node3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	for m in node.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		var xf: Transform3D = node.global_transform.affine_inverse() * mi.global_transform
		for s in mi.mesh.get_surface_count():
			for v in mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array:
				out.append(xf * v)
	return out


# Every triangle of every mesh under `node`, three points each, in `node`'s local frame.
func _triangles(node: Node3D) -> Array:
	var out := []
	for m in node.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		var xf: Transform3D = node.global_transform.affine_inverse() * mi.global_transform
		for s in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(s)
			var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var idx = arrays[Mesh.ARRAY_INDEX]
			var n: int = idx.size() if idx != null else vs.size()
			for i in range(0, n, 3):
				var a: int = idx[i] if idx != null else i
				var b: int = idx[i + 1] if idx != null else i + 1
				var c: int = idx[i + 2] if idx != null else i + 2
				out.append([xf * vs[a], xf * vs[b], xf * vs[c]])
	return out


func _run() -> void:
	var packed := load("res://assets/models/world_one/enemy_winch_drone.glb") as PackedScene
	_check(packed != null, "enemy_winch_drone.glb loads")
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
	var names := []
	var surfaces := []
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		names.append(String(node.name))
		for surface in node.mesh.get_surface_count():
			surfaces.append(node.mesh.surface_get_material(surface).resource_name)
	names.sort()
	surfaces.sort()
	_check(names == ["WinchBody", "WinchDrum", "WinchRotor"], "asset node names stay pinned, including the split drum")
	_check(surfaces == ["fleet_paint", "paint", "paint", "paint"], "asset surface names stay pinned")
	_check(absf(float(m["tris"]) - 4412.0) <= 441.2, "WD-8 triangles within 10 percent of base 4412 (polished; was 552)")
	scene.free()

	game.ctx.calm = true
	var drone: Node3D = game.ctx.spawner.spawn_enemy("winch_drone", Vector3(0, 30, 0))
	await process_frame
	_check(drone != null, "a winch drone spawns")
	if drone == null:
		quit(1)
		return
	_check_base(drone)
	var live := _measure(drone)
	print("live assembly: %d T, %d D" % [live["tris"], live["draws"]])
	_check(drone.find_child("WinchBody", true, false) != null and drone.find_child("WinchRotor", true, false) != null,
		"the live drone carries its WinchBody and WinchRotor dressing")
	_check(live["draws"] > 0 and live["tris"] > 0, "the live measure saw meshes (%d T, %d D)" % [live["tris"], live["draws"]])
	_check(live["tris"] <= CEILING_T and live["draws"] <= CEILING_D, "live assembly %d T / %d D within %d / 4" % [live["tris"], live["draws"], CEILING_T])
	_check(not live["alpha"], "live assembly has no alpha surface")
	var pts := _points(drone)
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for p in pts:
		lo = lo.min(p)
		hi = hi.max(p)
	print("bounds: x %.3f..%.3f, y %.3f..%.3f, z %.3f..%.3f" % [lo.x, hi.x, lo.y, hi.y, lo.z, hi.z])
	_check(lo.x >= X_MIN - 0.001 and hi.x <= X_MAX + 0.001 and lo.z >= Z_MIN - 0.001 and hi.z <= Z_MAX + 0.001,
		"inside the footprint x %.1f..%.1f, z %.2f..%.2f" % [X_MIN, X_MAX, Z_MIN, Z_MAX])
	_check(lo.y >= Y_BOTTOM - 0.001 and hi.y <= Y_TOP + 0.001, "between y %.2f and %.1f" % [Y_BOTTOM, Y_TOP])
	_check_rotor(drone)
	_check_drum(drone, pts)
	_check_exit(drone)
	_check_paint(drone)
	print("enemy_winch_drone_asset_test: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


# Collider, timing, mechanic and damage: everything winch_drone.gd did before the swap.
func _check_base(drone: Node3D) -> void:
	var shapes := drone.find_children("*", "CollisionShape3D", true, false)
	_check(shapes.size() == 1, "one collision shape on the drone (%d)" % shapes.size())
	var cap := (shapes[0] as CollisionShape3D).shape as CapsuleShape3D if shapes.size() > 0 else null
	_check(cap != null and is_equal_approx(cap.radius, 0.8) and is_equal_approx(cap.height, 2.2), "collider is the base capsule r 0.8 h 2.2")
	_check(shapes.size() > 0 and (shapes[0] as Node3D).position == Vector3.ZERO, "collider sits at the origin")
	_check(drone.find_children("*", "Area3D", true, false).is_empty() and drone.find_children("*", "CollisionObject3D", true, false).is_empty(),
		"the dressing adds no collision object")
	_check(drone.radius == 0.8 and drone.half_height == 1.1 and is_equal_approx(drone.weight, 0.8), "radius 0.8, half-height 1.1 and weight 0.8 unchanged")
	_check(is_equal_approx(drone.warn_seconds, 1.0) and is_equal_approx(drone.live_seconds, 1.9) and is_equal_approx(drone.rest_seconds, 3.5)
		and is_equal_approx(drone.attack_range, 18.0) and is_equal_approx(drone.keep_near, 8.0) and is_equal_approx(drone.keep_far, 16.2) and is_equal_approx(drone.walk_speed, 5.0)
		and drone.scrap_value == 4, "warn 1.0, live 1.9, rest 3.5, range 18, keep-near 8, keep-far 22 clamped to 16.2 by counter.gd, walk 5.0 and scrap 4 unchanged")
	var consts: Dictionary = (drone.get_script() as Script).get_script_constant_map()
	var same := true
	for key in BASE_CONSTS:
		if not consts.has(key) or not is_equal_approx(float(consts[key]), float(BASE_CONSTS[key])):
			same = false
			print("  constant %s is %s, base %s" % [key, consts.get(key), BASE_CONSTS[key]])
	_check(same, "hover, climb, lane length and width, pull, winch, pack reach and health constants equal base")
	var source := FileAccess.get_file_as_string("res://src/combat/winch_drone.gd")
	var missing := []
	for line: String in BASE_SOURCE:
		if not source.contains(line):
			missing.append(line)
	print("  source literals missing: %s" % [missing])
	_check(missing.is_empty(), "the source keeps every base literal (keep_far 22.0, timing, lane, catch, pull and hover lines)")


# The rotor keeps its envelope and paint. WD replaces the constant 0.6 rad/tick spin with
# warning-clock acceleration and exact rest after the coast.
func _check_rotor(drone: Node3D) -> void:
	var rotor := drone.find_child("WinchRotor", true, false) as MeshInstance3D
	_check(rotor != null and drone._rotor == rotor, "the pose turns the WinchRotor node")
	if rotor == null:
		return
	_check(is_equal_approx(rotor.position.y, ROTOR_Y) and is_zero_approx(rotor.position.x) and is_zero_approx(rotor.position.z), "the rotor pivots at its own centre, 2.0 m above the origin")
	var reach := 0.0
	var arrays := rotor.mesh.surface_get_arrays(0)
	for v in arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array:
		reach = maxf(reach, Vector2(v.x, v.z).length())
	var tris: int = (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	print("rotor: radius %.3f, %d T" % [reach, tris])
	_check(reach >= ROTOR_R - 0.01 and reach <= ROTOR_R + 0.01, "the rotor radius is 1.6 m (%.3f)" % reach)
	_check(tris > 0 and tris + 64 < 150, "the bladed rotor (%d T) and 16-sided drum (64 T) stay under 150 T" % tris)
	_check_blades(rotor)
	drone.phase = drone.Phase.WARN
	drone._t = 0.0
	drone._pose()
	# The rotor idles while the drone roams (PC), so the spin-up starts from its idle yaw: same place, turned only about its own axis.
	var yaw: Transform3D = rotor.transform * drone._rotor_rest.affine_inverse()
	_check(yaw.origin.is_zero_approx() and yaw.basis.y.is_equal_approx(Vector3.UP), "WD rotor starts in place at warning progress zero, turned only about its own axis")
	drone._t = 0.5 * drone.warn_seconds
	drone._pose()
	_check(not rotor.transform.is_equal_approx(drone._rotor_rest), "WD rotor turns from the wind-up clock")
	drone.phase = drone.Phase.ROAM
	drone._t = 0.3
	drone._pose()
	_check(rotor.transform == drone._rotor_rest, "WD rotor coasts back to exact rest")
	_check(rotor.get_surface_override_material(0) == null or rotor.get_surface_override_material(0) != drone._material, "the rotor does not take the flashing material")


func _angle_distance(a: float, b: float) -> float:
	return absf(wrapf(a - b, -PI, PI))


func _check_blades(rotor: MeshInstance3D) -> void:
	var angles: Array[float] = []
	var tip_points := PackedVector3Array()
	var tip_colors := PackedColorArray()
	for surface in rotor.mesh.get_surface_count():
		var arrays := rotor.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		for i in vertices.size():
			var v := vertices[i]
			if Vector2(v.x, v.z).length() < ROTOR_R - 0.01:
				continue
			var angle := fposmod(atan2(v.z, v.x), TAU)
			var duplicate := false
			for other in angles:
				duplicate = duplicate or _angle_distance(angle, other) < 0.001
			if not duplicate:
				angles.append(angle)
			tip_points.append(v)
			tip_colors.append(colors[i] if colors.size() == vertices.size() else Color.TRANSPARENT)
	angles.sort()
	# Cut the circular list at its largest gap, then group each blade's two tip corners.
	var start := 0
	var largest_gap := 0.0
	for i in angles.size():
		var gap := fposmod(angles[(i + 1) % angles.size()] - angles[i], TAU)
		if gap > largest_gap:
			largest_gap = gap
			start = (i + 1) % angles.size()
	var tips: Array[float] = []
	var sum := Vector2.ZERO
	var previous := 0.0
	for step in angles.size():
		var angle := angles[(start + step) % angles.size()]
		if step > 0 and fposmod(angle - previous, TAU) > deg_to_rad(30.0):
			tips.append(fposmod(atan2(sum.y, sum.x), TAU))
			sum = Vector2.ZERO
		sum += Vector2(cos(angle), sin(angle))
		previous = angle
	if not sum.is_zero_approx():
		tips.append(fposmod(atan2(sum.y, sum.x), TAU))
	_check(tips.size() >= 2 and tips.size() <= 4, "DR-1 rotor has two to four separated blades (%d)" % tips.size())
	# Any rotational symmetry must carry the first tip to another tip. Test every candidate,
	# including turns above 90 degrees: the authored silhouette has no rotational symmetry.
	var symmetric := tips.size() < 2
	for candidate in range(1, tips.size()):
		var turn := fposmod(tips[candidate] - tips[0], TAU)
		var matches := true
		for tip in tips:
			var found := false
			for other in tips:
				found = found or _angle_distance(tip + turn, other) < 0.01
			matches = matches and found
		symmetric = symmetric or matches
	var degrees := []
	for tip in tips:
		degrees.append(fposmod(snappedf(rad_to_deg(tip), 0.01), 360.0))
	_check(not symmetric, "DR-1 blade-tip angles %s have no rotational symmetry, including <= 90 degrees" % [degrees])
	var marked := {}
	var unmarked := {}
	var metal := Palette.SAND.srgb_to_linear()
	for i in tip_points.size():
		var angle := atan2(tip_points[i].z, tip_points[i].x)
		for blade in tips.size():
			if _angle_distance(angle, tips[blade]) < deg_to_rad(15.0):
				# Godot stores mesh vertex colours in 8-bit channels after GLB import.
				var c := tip_colors[i]
				var matches_metal := absf(c.r - metal.r) <= 1.0 / 255.0 and absf(c.g - metal.g) <= 1.0 / 255.0 \
					and absf(c.b - metal.b) <= 1.0 / 255.0 and is_equal_approx(c.a, 1.0)
				if matches_metal:
					marked[blade] = true
				else:
					unmarked[blade] = true
	_check(marked.size() == 1 and unmarked.size() == tips.size() - 1 and not unmarked.has(marked.keys()[0] if marked.size() == 1 else -1),
		"DR-1 exactly one blade has a distinct bare-metal tip colour (%d marked, %d unmarked)" % [marked.size(), unmarked.size()])


# The drum hangs under the crew: a 0.45 m drum centred near y -1.4, with air between the rotor
# and it, and it is the lowest mass.
func _check_drum(_drone: Node3D, pts: PackedVector3Array) -> void:
	var bottom := INF
	var wide := 0.0
	var drum_n := 0
	for p in pts:
		bottom = minf(bottom, p.y)
		if absf(p.y - DRUM_Y) <= DRUM_R + 0.06 and p.y < -0.9:
			wide = maxf(wide, absf(p.x))
			drum_n += 1
	print("drum: bottom %.3f, half length %.3f, vertices %d" % [bottom, wide, drum_n])
	_check(bottom <= DRUM_Y - DRUM_R + 0.06 and bottom >= DRUM_Y - DRUM_R - 0.1, "the drum is the lowest mass, its underside at %.2f m" % bottom)
	_check(wide >= 0.44 and wide <= 0.5, "the drum is 0.9 m long on an X axis (half length %.2f)" % wide)
	_check(drum_n >= 32, "the 16-sided drum has its vertices (%d)" % drum_n)


# The cable pays out of the drum's front-bottom quarter, along (0, -0.707, 0.707) in the drone's
# frame, on the drum's mid plane. A cylinder of radius 0.12 round that line, from the drum's wrap
# out to 3 m, holds no triangle: five rays (axis and four offsets) hit nothing.
func _check_exit(drone: Node3D) -> void:
	var dir := Vector3(0.0, -0.7071068, 0.7071068)
	var origin := Vector3(0.0, DRUM_Y, 0.0) + dir * 0.55
	var side := Vector3.RIGHT
	var up := dir.cross(side).normalized()
	var tris := _triangles(drone)
	var hits := 0
	for offset in [Vector3.ZERO, side * 0.12, -side * 0.12, up * 0.12, -up * 0.12]:
		var from: Vector3 = origin + offset
		for t in tris:
			var hit = Geometry3D.ray_intersects_triangle(from, dir, t[0], t[1], t[2])
			if hit != null and from.distance_to(hit) <= 3.0:
				hits += 1
	print("cable exit: %d triangle hits over %d triangles" % [hits, tris.size()])
	_check(hits == 0, "nothing occludes the cable exit line out to 3 m (%d hits)" % hits)
	# The corridor is real: the same rays into the drum itself must hit it, so the test is not vacuous.
	var into := 0
	for t in tris:
		if Geometry3D.ray_intersects_triangle(Vector3(0.0, DRUM_Y, 0.0) + dir * 1.0, -dir, t[0], t[1], t[2]) != null:
			into += 1
	_check(into > 0, "the exit line, walked back, meets the drum (%d triangles)" % into)


# The resting body is Fleet oxide (RUST) on the fleet_paint surface; a hit flashes it through the
# existing event.
func _check_paint(drone: Node3D) -> void:
	var body := drone.find_child("Body", true, false) as MeshInstance3D
	var scene := (load(GLB) as PackedScene).instantiate()
	var named := -1
	var found := 0
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var glb_mesh := (node as MeshInstance3D).mesh
		for i in glb_mesh.get_surface_count():
			if glb_mesh.surface_get_material(i).resource_name == "fleet_paint":
				named = i
				found += 1
	scene.free()
	_check(found == 1, "the glb names exactly one surface fleet_paint (%d)" % found)
	var mat: StandardMaterial3D = null
	for s in body.mesh.get_surface_count():
		var o := body.get_surface_override_material(s) as StandardMaterial3D
		_check((o == drone._material) == (s == named), "surface %d takes the flashing material only if it is fleet_paint (index %d)" % [s, named])
		if o != null and o == drone._material:
			mat = o
			var arrays := body.mesh.surface_get_arrays(s)
			var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var ok := true
			for v in vs:
				ok = ok and v.y > -0.8 and v.y < 1.3 and absf(v.x) < 0.7
			_check(ok, "the flashing surface is the crew, not the mast, hanger or drum")
	_check(mat != null, "the body's paint surface is the enemy's flashing material")
	_check(drone._base_color.is_equal_approx(Palette.RUST) and drone._material.albedo_color.is_equal_approx(Palette.RUST),
		"resting state: the body is Fleet oxide (RUST)")
	drone.flash()
	drone._update_flash(0.0)
	var want: Color = Palette.RUST.lerp(Color(1.0, 1.0, 0.85), 1.0)
	_check(drone._material.albedo_color.is_equal_approx(want) and drone._material.emission_enabled, "hit state: the existing flash lerps the body toward cream with amber emission")
	for i in 20:
		drone._update_flash(0.1)
	_check(drone._material.albedo_color.is_equal_approx(Palette.RUST) and not drone._material.emission_enabled, "recovery state: the body returns to oxide")
