extends SceneTree

const Game := preload("res://src/game.gd")
const Launch := preload("res://src/world/launch.gd")

# Every default zone as built in the real scene: each spawn and beacon stands on solid,
# level ground that the physics world agrees with; the Reach has different
# ground from the Spillway; each opens on a landing hill that falls
# away along its entry heading; each carries the momentum kit (pylon faces, grapple
# posts); and every event ring sits on ground inside the playable floor.

const PROBE_UP := 40.0
const GRID := 20.0
const DISTINCT_METRES := 5.0
const HILL_DROP := 15.0
const MIN_PYLON_CELLS := 150
const MIN_POSTS := 2

var _game
var _failures := 0
var _stage := 0
var _wait := 0
var _grids := {}


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	if _stage == 0:
		_stage = 1
		_game.ctx.terrain.use(_stage)
		_wait = 0
		return false
	_wait += 1
	if _wait < 3:
		return false
	_check_stage(_stage)
	_stage += 1
	if _stage > _game.ctx.stages.COUNT:
		_check_distinct()
		print("world_stages_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
		_game.free()
		quit(0 if _failures == 0 else 1)
		return true
	_game.ctx.terrain.use(_stage)
	_wait = 0
	return false


func _probe(x: float, z: float, from_y: float) -> Dictionary:
	var space: PhysicsDirectSpaceState3D = _game.get_world_3d().direct_space_state
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, from_y, z), Vector3(x, from_y - 200.0, z), 1))


func _check_stage(stage: int) -> void:
	var terrain = _game.ctx.terrain
	var map = terrain.map()
	var spawn: Vector3 = terrain.spawn_point(stage)
	var hit := _probe(spawn.x, spawn.z, spawn.y + PROBE_UP)
	var ground_y := spawn.y - 2.0
	var dry: bool = map.basin.is_empty() or Vector2(spawn.x, spawn.z).distance_to(map.basin["centre"]) > map.basin["radius"]
	var solid: bool = not hit.is_empty() and absf(hit["position"].y - ground_y) < 0.3 and hit["normal"].y > 0.95
	_report("stage %d spawn" % stage, solid and dry,
		"%s spawn (%.0f, %.1f, %.0f): collider %s at %.2f m, normal y %.3f, dry of the basin %s"
			% [map.title, spawn.x, spawn.y, spawn.z, "hit" if not hit.is_empty() else "missing",
				hit.get("position", Vector3.INF).y, hit.get("normal", Vector3.ZERO).y, dry])

	var beacon: Vector3 = terrain.beacon_point(stage)
	var bhit := _probe(beacon.x, beacon.z, beacon.y + PROBE_UP)
	_report("stage %d beacon" % stage, not bhit.is_empty() and absf(bhit["position"].y - beacon.y) < 0.3,
		"beacon at (%.0f, %.1f, %.0f) stands on the collider (hit %.2f m)" % [beacon.x, beacon.y, beacon.z, bhit.get("position", Vector3.INF).y])

	var heading: Vector3 = terrain.entry_heading(stage)
	var falls := true
	var last: float = terrain.height(spawn.x, spawn.z)
	for d in [16.0, 28.0, 40.0, 52.0, 64.0]:
		var p: Vector3 = spawn + heading * d
		var h: float = terrain.height(p.x, p.z)
		if h > last + 0.2:
			falls = false
		last = h
	var drop: float = terrain.height(spawn.x, spawn.z) - last
	# The Spillway is the opening map: it has no landing hill and no momentum kit wherever its row sits.
	var opening: bool = String(_game.ctx.stages.of(stage)["map"]) == String(_game.ctx.stages.of(1)["map"])
	if not opening:
		_report("stage %d landing hill" % stage, falls and drop >= HILL_DROP,
			"the ground falls %.1f m over the 64 m ahead of the spawn along the entry heading, never rising: %s" % [drop, falls])
		var entry := spawn + Vector3.UP * 14.0
		var lands := true
		var detail := []
		for speed in [14.0, 22.0, 34.0]:
			var velocity: Vector3 = heading * speed + Vector3.UP * (Launch.LIFT - 26.0 * 0.6)
			var at: Vector3 = _game.world.launch.mark_landing(entry, velocity, Callable(terrain, "height"))
			var ahead: Vector3 = at + heading * 3.0
			var downhill: bool = terrain.height(ahead.x, ahead.z) < terrain.height(at.x, at.z)
			lands = lands and downhill
			detail.append("%.0f m/s lands %.0f m out %s" % [speed, Vector2(at.x - spawn.x, at.z - spawn.z).length(), "downhill" if downhill else "on flat or rising ground"])
		_game.world.launch.clear_landing()
		_report("stage %d landing downhill" % stage, lands, ", ".join(detail))

	var root: Node3D = terrain.geometry_root(stage)
	var posts := 0
	var walls := 0
	for body in root.find_children("*", "StaticBody3D", true, false):
		for shape_node in body.get_children():
			if shape_node is CollisionShape3D:
				if shape_node.shape is CylinderShape3D and shape_node.shape.height >= 18.0:
					posts += 1
				elif shape_node.shape is BoxShape3D and shape_node.shape.size.y >= 6.0 and shape_node.shape.size.z <= 2.0:
					walls += 1
	var pylon_cells := 0
	var r: Rect2 = map.play_rect
	var grid := []
	var x := r.position.x
	while x <= r.end.x:
		var z := r.position.y
		while z <= r.end.y:
			var h: float = terrain.height(x, z)
			var gx: float = terrain.height(x + 2.0, z) - h
			var gz: float = terrain.height(x, z + 2.0) - h
			if Vector3(-gx, 2.0, -gz).normalized().y < 0.866:
				pylon_cells += 1
			z += 2.0
		x += 2.0
	for gxi in range(-7, 8):
		for gzi in range(-7, 8):
			grid.append(terrain.height(gxi * GRID, gzi * GRID))
	_grids[stage] = grid
	if not opening:
		_report("stage %d momentum kit" % stage, pylon_cells >= MIN_PYLON_CELLS and posts >= MIN_POSTS and walls >= MIN_POSTS,
			"%d ground cells steep enough for a pylon, %d grapple posts, %d pylon walls" % [pylon_cells, posts, walls])

	var off_ground: Array[String] = []
	for id in map.sites:
		var ring: Vector2 = map.sites[id]["ring"]
		var rh := _probe(ring.x, ring.y, 200.0)
		if rh.is_empty() or not r.has_point(ring):
			off_ground.append(id)
	_report("stage %d event sites" % stage, off_ground.is_empty() and not map.sites.is_empty(),
		"rings for %s sit on the collider inside the playable floor; off ground %s" % [map.sites.keys(), off_ground])


func _check_distinct() -> void:
	# World one's two zones. The Reach extends the Gorge's heightmap, so a gorge row next to a
	# reach row differs by under a metre on this grid and is not compared here.
	var pairs := [[1, 2]]
	var detail := []
	var ok := true
	for p in pairs:
		var a: Array = _grids[p[0]]
		var b: Array = _grids[p[1]]
		var total := 0.0
		for i in a.size():
			total += absf(a[i] - b[i])
		var mean := total / a.size()
		ok = ok and mean >= DISTINCT_METRES
		detail.append("stages %d and %d differ by %.1f m on average" % [p[0], p[1], mean])
	var t = _game.ctx.terrain
	var apart: float = t.spawn_point(1).distance_to(t.spawn_point(2))
	_report("distinct stages", ok and apart > 25.0,
		"%s over a %d m grid; zones 1 and 2 enter %.0f m apart" % ["; ".join(detail), int(GRID), apart])


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])
