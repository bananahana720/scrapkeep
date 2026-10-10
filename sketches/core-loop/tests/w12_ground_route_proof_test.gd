extends SceneTree

# P-GROUND (copied from PROBE-NAV's route_proof_probe_test): bake a NavigationMesh from the
# collision shapes of stage 1 (Spillway) and stage 4 (Dig deep) and prove a walkable route from
# each spawn pad to its beacon. Ground scatter and relief are visual only, so the collision
# source count and the route must not move. `-- --blocked` drops a wall across the whole
# map in memory first, so the same assertion must fail (the control).

const Game := preload("res://src/game.gd")
const Tuning := preload("res://src/movement/tuning.gd")

const GOAL_TOLERANCE := 2.0
const WALL_Z := -90.0
const STAGES := [1, 4]

var _game
var _wait := 0
var _blocked := false
var _started := false


func _initialize() -> void:
	_blocked = OS.get_cmdline_user_args().has("--blocked")
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(_delta: float) -> bool:
	if _game.flow == null or _started:
		return false
	_wait += 1
	if _wait == 1:
		_game.ctx.terrain.use(4)
		_game.ctx.terrain.use(1)
		return false
	if _wait < 4:
		return false
	_started = true
	_run()
	return false


func _run() -> void:
	var ok := true
	for stage in STAGES:
		var passed: bool = await _prove(stage)
		ok = ok and passed
	print("w12_ground_route_proof_test: %s" % ("PASS" if ok else "FAIL"))
	_game.free()
	quit(0 if ok else 1)


func _prove(stage: int) -> bool:
	var terrain = _game.ctx.terrain
	var stage_root: Node3D = terrain.geometry_root(stage)
	var spawn: Vector3 = terrain.spawn_point(stage)
	var beacon: Vector3 = terrain.beacon_point(stage)

	if _blocked:
		var wall := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(500.0, 120.0, 4.0)
		cs.shape = box
		wall.add_child(cs)
		wall.position = Vector3(0.0, 40.0, WALL_Z)
		stage_root.add_child(wall)

	var nav := NavigationMesh.new()
	nav.agent_radius = Tuning.RADIUS
	nav.agent_height = 2.0
	nav.cell_size = 0.5
	nav.cell_height = 0.25
	nav.agent_max_slope = 60.0
	nav.agent_max_climb = 0.5
	nav.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	var data := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nav, data, stage_root)
	var coll_verts := data.get_vertices().size() / 3
	NavigationServer3D.bake_from_source_geometry_data(nav, data)
	var polys := nav.get_polygon_count()

	# Control for the parser: visual meshes (informational only).
	var vnav := NavigationMesh.new()
	vnav.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_MESH_INSTANCES
	var vdata := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(vnav, vdata, stage_root)
	var vis_verts := vdata.get_vertices().size() / 3

	var map := NavigationServer3D.map_create()
	NavigationServer3D.map_set_cell_size(map, nav.cell_size)
	NavigationServer3D.map_set_cell_height(map, nav.cell_height)
	NavigationServer3D.map_set_active(map, true)
	var region := NavigationServer3D.region_create()
	NavigationServer3D.region_set_map(region, map)
	NavigationServer3D.region_set_navigation_mesh(region, nav)
	NavigationServer3D.region_set_enabled(region, true)
	var it0 := NavigationServer3D.map_get_iteration_id(map)
	var frames := 0
	while (NavigationServer3D.map_get_iteration_id(map) == it0 or NavigationServer3D.map_get_closest_point(map, spawn) == Vector3.ZERO) and frames < 60:
		await physics_frame
		frames += 1
	var synced: bool = NavigationServer3D.map_get_iteration_id(map) != it0

	var a := NavigationServer3D.map_get_closest_point(map, spawn)
	var b := NavigationServer3D.map_get_closest_point(map, beacon)
	var path := NavigationServer3D.map_get_path(map, a, b, true)
	var length := 0.0
	for i in range(1, path.size()):
		length += path[i - 1].distance_to(path[i])
	var last_gap := path[path.size() - 1].distance_to(beacon) if path.size() > 0 else INF

	print("nav: stage=%d blocked=%s source_verts(collision)=%d source_verts(visual)=%d synced=%s (%d frames)" % [stage, _blocked, coll_verts, vis_verts, synced, frames])
	print("nav: polygons=%d path_points=%d path_length=%.1f m last_gap=%.2f m" % [polys, path.size(), length, last_gap])

	var ok := polys > 0 and path.size() > 0 and last_gap <= GOAL_TOLERANCE
	print("nav: stage=%d %s" % [stage, "PASS" if ok else "FAIL"])
	NavigationServer3D.free_rid(region)
	NavigationServer3D.free_rid(map)
	return ok
