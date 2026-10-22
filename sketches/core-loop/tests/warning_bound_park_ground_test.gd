extends SceneTree

# The cached warning box on the REAL park ground (lighting L7, #297). The box takes its y range
# from the meshes the painter built (WarningBound), so marks that draw later on ground the build
# did not sample (a fill ring's inner edge, a sweep's spoke, chevrons, a lane's run strip) must
# still land inside it where the ground is steep. This builds the park table's terrain
# (Terrain.new(ParkDefs), what the game launches), picks spots on each stage by relief, places
# every telegraph and hazard form there, steps them through progress and age, and holds the box
# to the merged meshes (a hazard's box grows with its repaints; only a driven telegraph is built whole). Spots: the steepest by local relief (separated), a few fixed-stride
# ones and the spawn. Prints the worst slack per form. No wall-clock reads.
const T := preload("res://tests/support/t.gd")
const PlayerFx := preload("res://src/presentation/player_fx.gd")
const Telegraph := preload("res://src/combat/telegraph.gd")
const Hazard := preload("res://src/boss/hazard.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const Terrain := preload("res://src/world/terrain.gd")
const ParkDefs := preload("res://src/core/park_defs.gd")

const TOLERANCE := 1.0e-3
const STAGES := [2, 4, 5, 6]
# A spot's relief is the height range over its 3 x 3 neighbourhood at SCAN_STEP_M, the heightfield's
# cell (terrain.gd STEP) doubled, so a spot with a cliff in reach scores high.
const SCAN_STEP_M := 4.0
const SCAN_HALF_M := 180.0
const STEEPEST := 3
const SPACING_M := 40.0
const STRIDE_SPOTS := 3

var t := T.new("warning_bound_park_ground_test")
var _world: Node3D
var _terrain
var _worst := {}
var _cases := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# The terrain's Terrain3D nodes look for an active camera and log an error without one.
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.current = true
	var holder := Node3D.new()
	root.add_child(holder)
	_terrain = Terrain.new(ParkDefs)
	_terrain.build(holder)
	_world = Node3D.new()
	root.add_child(_world)
	for stage in STAGES:
		_terrain.use(stage)
		await process_frame
		var spots := _spots(stage)
		for spot in spots:
			_place(stage, spot)
	for form in _worst:
		print("park_ground worst slack %s: %.4f m (%s)" % [form, _worst[form][0], _worst[form][1]])
	print("warning_bound_park_ground: %d cases" % _cases)
	_world.free()
	quit(t.verdict())


func _height(x: float, z: float) -> float:
	return _terrain.height(x, z)


# [x, z, relief, label] spots: the steepest by relief at least SPACING_M apart, fixed-stride
# ones, and the stage spawn.
func _spots(stage: int) -> Array:
	var scored: Array = []
	var x := -SCAN_HALF_M
	while x <= SCAN_HALF_M:
		var z := -SCAN_HALF_M
		while z <= SCAN_HALF_M:
			var lo := INF
			var hi := -INF
			for dx in [-1.0, 0.0, 1.0]:
				for dz in [-1.0, 0.0, 1.0]:
					var h := _height(x + dx * SCAN_STEP_M, z + dz * SCAN_STEP_M)
					lo = minf(lo, h)
					hi = maxf(hi, h)
			scored.append([x, z, hi - lo])
			z += SCAN_STEP_M
		x += SCAN_STEP_M
	scored.sort_custom(func(a, b) -> bool: return a[2] > b[2])
	var out: Array = []
	for s in scored:
		if out.size() >= STEEPEST:
			break
		var apart := true
		for o in out:
			apart = apart and Vector2(o[0] - s[0], o[1] - s[1]).length() >= SPACING_M
		if apart:
			out.append([s[0], s[1], s[2], "steep"])
	for k in STRIDE_SPOTS:
		var s: Array = scored[(scored.size() / (STRIDE_SPOTS + 1)) * (k + 1)]
		out.append([s[0], s[1], s[2], "stride"])
	var spawn: Vector2 = _terrain.map_for(stage).spawn
	out.append([spawn.x, spawn.y, 0.0, "spawn"])
	print("park_ground stage %d spots: %s" % [stage, str(out.map(func(s): return "%s(%.0f,%.0f relief %.1f)" % [s[3], s[0], s[1], s[2]]))])
	return out


func _place(stage: int, spot: Array) -> void:
	var at := Vector3(spot[0], _height(spot[0], spot[1]), spot[1])
	var tag := "s%d %s(%.0f,%.0f)" % [stage, spot[3], spot[0], spot[1]]
	var heading := Vector3(0.6, 0.0, 0.8)
	var builds := {
		"ring INSTANT": func() -> Node3D: return Telegraph.ring(_world, _terrain, Threat.Type.INSTANT, at, 6.0),
		"ring INSTANT big": func() -> Node3D: return Telegraph.ring(_world, _terrain, Threat.Type.INSTANT, at, 20.0),
		"ring PROJECTILE flight": func() -> Node3D:
			var ring: Node3D = Telegraph.ring(_world, _terrain, Threat.Type.PROJECTILE, at, 3.0)
			ring.set_flight(at + Vector3(-30.0, 14.0, 22.0), 9.0)
			return ring,
		"ring WAVE": func() -> Node3D: return Telegraph.wave(_world, _terrain, at, 18.0, 12.0, 1.0),
		"lane LANE": func() -> Node3D: return Telegraph.lane(_world, _terrain, Threat.Type.LANE, at, heading, 24.0, 4.0),
		"lane INSTANT": func() -> Node3D: return Telegraph.lane(_world, _terrain, Threat.Type.INSTANT, at, heading, 10.0, 8.0),
		"wedge LANE": func() -> Node3D: return Telegraph.wedge(_world, _terrain, Threat.Type.LANE, at, heading, 22.0, 35.0),
	}
	for label in builds:
		var node: Node3D = builds[label].call()
		var steps: Array = [0.0, 0.5, 1.0]
		if node.type == Threat.Type.WAVE:
			steps = [0.0, 0.5, 1.0, 1.0 + 0.5 * node.radius / node.speed, 1.0 + node.radius / node.speed]
		for p in steps:
			if node.type == Threat.Type.WAVE:
				node.age = p * node.warn_seconds
				node.step(0.0)
			else:
				node.set_progress(p)
			_contained(node, label, "%s %s p=%.2f" % [tag, label, p])
		node.free()
	var specs := {
		"hazard sector WAVE": func(h: Node3D) -> void: h.commit_sector("p_sw", Threat.Type.WAVE, at, Vector2(3.0, 28.0), 0.4, 2.2, 3.5, 1.0, 2.0),
		"hazard sector INSTANT": func(h: Node3D) -> void: h.commit_sector("p_si", Threat.Type.INSTANT, at, Vector2(2.0, 15.0), 1.0, 2.0, 3.0, 1.0, 1.0),
		"hazard annulus INSTANT": func(h: Node3D) -> void: h.commit_annulus("p_a", Threat.Type.INSTANT, at, Vector2(6.0, 14.0), 3.5, 1.0, 1.0),
		"hazard annulus big": func(h: Node3D) -> void: h.commit_annulus("p_ab", Threat.Type.INSTANT, at, Vector2(0.0, 36.0), 3.0, 1.0, 1.0),
		"hazard lane LANE": func(h: Node3D) -> void: h.commit_lane("p_l", Threat.Type.LANE, at, heading, 2.0, 30.0, 3.0, 3.0, 1.0, 1.0),
		"hazard lane INSTANT": func(h: Node3D) -> void: h.commit_lane("p_li", Threat.Type.INSTANT, at, heading, 0.0, 12.0, 6.0, 3.0, 1.0, 1.0),
	}
	for label in specs:
		var hazard := Hazard.new()
		hazard.ground = func(point: Vector3) -> float: return _height(point.x, point.z)
		specs[label].call(hazard)
		_world.add_child(hazard)
		var warn: float = hazard.warn_seconds
		var live: float = hazard.live_seconds
		var done_age := 0.0
		for age in [0.0, warn * 0.5, warn, warn + live * 0.5, warn + live * 0.99]:
			hazard.step(age - done_age)
			done_age = age
			_contained(hazard, label, "%s %s age=%.2f" % [tag, label, age])
		hazard.free()


func _contained(node: Node3D, form: String, label: String) -> void:
	var bound: AABB = node.screen_bound_box()
	var merged := [AABB(), false]
	PlayerFx._merge_meshes(node, merged)
	var mesh: AABB = merged[0] if merged[1] else AABB()
	_cases += 1
	if bound.size == Vector3.ZERO or mesh.size == Vector3.ZERO:
		t.check("contained: %s" % label, false, "box %s, meshes %s" % [bound, mesh])
		return
	var lo := mesh.position - bound.position
	var hi := bound.end - mesh.end
	var slack := minf(minf(lo.x, lo.y), minf(minf(lo.z, hi.x), minf(hi.y, hi.z)))
	if not _worst.has(form) or slack < _worst[form][0]:
		_worst[form] = [slack, label]
	t.check("contained: %s" % label, bound.grow(TOLERANCE).encloses(mesh), "slack %.4f m" % slack)
