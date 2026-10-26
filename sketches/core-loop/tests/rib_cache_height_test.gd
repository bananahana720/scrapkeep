extends SceneTree

const Game := preload("res://src/game.gd")
const Panels := preload("res://src/build/panels.gd")
const T := preload("res://tests/support/t.gd")

# Rib cache panels stand at a readable height over whatever surface is under them, on the real
# Spillway (park table, calm): stage 1 park_dam and stage 2 park_flume. Each panel sits
# CACHE_LIFT above the first surface a ray finds straight below it. Red team on f7af1604: the
# flume's crew_ledges graph node is at y 76.5 under a deck at 77.5, so a lift from the node y
# left the panel 0.2 m above the deck. Every spot the stage's pool can draw (POOL_DRAWS seeds)
# has a surface in the placement ray's window, so none falls back to its node y.
# smoke: solo timeout=240s

const WAIT_TICKS := 600
const CACHE_LIFT := 1.2
const LIFT_SLACK := 0.15
const POOL_DRAWS := 40

var _t := T.new("rib_cache_height_test")
var _game


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "park"
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.flow.force_warden = false
	_game.flow.press_start()
	_game.flow.choose_class(1)
	await _stage(1)
	_game.flow.enter_stage(2, Vector3.ZERO, false)
	await _stage(2)
	_game.free()
	quit(_t.verdict())


func _stage(stage: int) -> void:
	var scrap = _game.build.scrap
	for i in WAIT_TICKS:
		await physics_frame
		if scrap.cache_count() > 0:
			break
	var map_id := String(_game.ctx.terrain.map().park.get("map", ""))
	var caches: Array = scrap.caches()
	_t.eq("stage %d (%s): three caches wait" % [stage, map_id], caches.size(), Panels.RIB_CACHES)
	var space: PhysicsDirectSpaceState3D = _game.get_world_3d().direct_space_state
	for c in caches:
		var at: Vector3 = c["at"]
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * 20.0, 1))
		var lift: float = at.y - float(hit["position"].y) if not hit.is_empty() else INF
		_t.check("stage %d cache at (%.0f, %.1f, %.0f) stands %.1f m over the surface below" % [stage, at.x, at.y, at.z, CACHE_LIFT],
			absf(lift - CACHE_LIFT) <= LIFT_SLACK, "%.2f m" % lift)
	var director = _game.ctx.root.get_node("World").director
	var spots := {}
	for seed in POOL_DRAWS:
		for at in director.rib_cache_spots(Panels.RIB_CACHES, seed):
			spots["%.0f,%.0f" % [at.x, at.z]] = at
	var missed := []
	for key in spots:
		if _game.build._cache_ground(spots[key]) == null:
			missed.append(key)
	_t.check("stage %d: every pool spot (%d) finds its surface" % [stage, spots.size()], missed.is_empty(), str(missed))
	print("stage %d placement waited %d ticks" % [stage, _game.build._caches_wait])
