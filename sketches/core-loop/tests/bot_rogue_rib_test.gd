extends SceneTree

const BotDriver := preload("res://tools/bot_driver.gd")
const T := preload("res://tests/support/t.gd")

# The explorer's rogue and rib cache hands (bot_driver.gd, --explore-by) and the stage note's
# content rows the world 1 pacing check reads (rogues_beaten, rib_caches_taken).
# (a) the default driver never takes either goal, so its runs stay as they were;
# (b) under --explore-by a woken rogue is fought, a sleeping one is rolled to at its site, and a
#     beaten one is let go;
# (c) a rib cache goes first only within RIB_NEAR, at any distance after, and is given up at its cap;
# (d) the note counts a cache taken only when it leaves the ground near the ball, and a rogue
#     beaten once;
# (f) the note names the pockets the stage drew, once, by library id, and not the stage's own sites;
# (e) a rogue killed and freed between two scans still counts beaten (red team, f7af1604: the
#     note missed 3 of 7 flume and dam rogue kills the events log recorded).

const EXPECTED_CHECKS := 21

var _t := T.new("bot_rogue_rib_test")


class SpyRun extends RefCounted:
	var stage := 2
	var stage_time := 10.0


class SpyPlayer extends RefCounted:
	var at := Vector3.ZERO

	func ball_position() -> Vector3:
		return at


class SpyTerrain extends RefCounted:
	func drop_point(x: float, z: float, _clearance: float) -> Vector3:
		return Vector3(x, 0.0, z)


class SpyCtx extends RefCounted:
	var terrain := SpyTerrain.new()


class SpyRogue extends Node3D:
	var kind := "rogue_crane"
	var dead := false

	func is_dead() -> bool:
		return dead


class SpySite extends RefCounted:
	var id := ""
	var drawn := false
	var interior := {}

	func _init(site_id: String, is_drawn: bool, pocket := "") -> void:
		id = site_id
		drawn = is_drawn
		interior = {"id": pocket} if pocket != "" else {}


class SpyActivities extends RefCounted:
	var sites: Array = []


class SpyWorld extends RefCounted:
	var rogue: Node3D = null
	var rogue_plan := {}
	var activities = null


class SpyScrap extends RefCounted:
	var rows: Array = []

	func caches() -> Array:
		return rows


class SpyBuild extends RefCounted:
	var scrap := SpyScrap.new()


class SpyGame extends RefCounted:
	var bot_driven := false
	var run := SpyRun.new()
	var player := SpyPlayer.new()
	var ctx := SpyCtx.new()
	var world := SpyWorld.new()
	var build := SpyBuild.new()


class Driver extends BotDriver:
	var fought: Node3D = null
	var steered := Vector3.INF

	func _fight(target: Node3D, _delta: float) -> void:
		fought = target

	func _act(steer: Vector3, _aim, _delta: float, _fight_target: Node3D = null, _evade := true) -> void:
		steered = steer

	func _graph_path(_from: Vector3, _to: Vector3) -> Array[Vector3]:
		return []

	func _nearest_enemy() -> Node3D:
		return null


func _initialize() -> void:
	_default_driver()
	_rogue()
	_rogue_freed()
	_ribs()
	_note_rows()
	_t.eq("expected check count", _t.checks + 1, EXPECTED_CHECKS)
	quit(_t.verdict())


func _driver(explore: bool) -> Array:
	var spy := SpyGame.new()
	var driver := Driver.new(spy, "completionist", 3)
	if explore:
		driver.engage_by = 520.0
	driver._note = {"rogue_woke_s": null, "rogue_beaten_s": null, "rogues_beaten": 0, "rib_caches_placed": 0, "rib_caches_taken": 0}
	return [spy, driver]


func _cache(at: Vector3) -> Dictionary:
	var item := Node3D.new()
	root.add_child(item)
	return {"at": at, "id": "grey", "item": item}


func _default_driver() -> void:
	var pair := _driver(false)
	var spy: SpyGame = pair[0]
	var driver: Driver = pair[1]
	var rogue := SpyRogue.new()
	root.add_child(rogue)
	spy.world.rogue = rogue
	spy.world.rogue_plan = {"at": Vector2(100, 0)}
	spy.build.scrap.rows = [_cache(Vector3(5, 0, 0))]
	driver._content_scan()
	_t.check("default: a woken rogue is not fought", not driver._rogue_fight(0.1))
	_t.check("default: the rogue site is not rolled to", not driver._rogue_goal(0.1))
	_t.check("default: a near rib cache is not taken", not driver._rib_goal(0.1, BotDriver.RIB_NEAR))
	rogue.queue_free()


func _rogue() -> void:
	var pair := _driver(true)
	var spy: SpyGame = pair[0]
	var driver: Driver = pair[1]
	spy.world.rogue_plan = {"at": Vector2(200, 50)}
	_t.check("a sleeping rogue is not fought", not driver._rogue_fight(0.1))
	_t.check("its site is rolled to", driver._rogue_goal(0.1) and driver.steered == Vector3(200, 0, 50))
	var rogue := SpyRogue.new()
	root.add_child(rogue)
	spy.world.rogue = rogue
	spy.world.rogue_plan = {}
	driver._content_scan()
	_t.eq("the wake is noted", driver._note["rogue_woke_s"], 10.0)
	_t.check("a woken rogue is fought", driver._rogue_fight(0.1) and driver.fought == rogue)
	rogue.dead = true
	spy.run.stage_time = 30.0
	driver._content_scan()
	driver._content_scan()
	_t.eq("a beaten rogue counts once", driver._note["rogues_beaten"], 1)
	_t.check("a beaten rogue is let go", not driver._rogue_fight(0.1))
	rogue.queue_free()


# The real kill path: _die marks the rogue dead and queue_free frees it at frame end, so a scan
# on the next tick finds world.rogue already freed and never sees is_dead().
func _rogue_freed() -> void:
	var pair := _driver(true)
	var spy: SpyGame = pair[0]
	var driver: Driver = pair[1]
	var rogue := SpyRogue.new()
	root.add_child(rogue)
	spy.world.rogue = rogue
	driver._content_scan()
	_t.eq("freed: the wake is noted", driver._note["rogue_woke_s"], 10.0)
	rogue.free()
	spy.run.stage_time = 25.0
	driver._content_scan()
	_t.eq("freed: a rogue freed between scans counts beaten", driver._note["rogues_beaten"], 1)
	_t.eq("freed: at the scan that found it gone", driver._note["rogue_beaten_s"], 25.0)


func _ribs() -> void:
	var pair := _driver(true)
	var spy: SpyGame = pair[0]
	var driver: Driver = pair[1]
	spy.build.scrap.rows = [_cache(Vector3(400, 0, 0)), _cache(Vector3(0, 0, 200))]
	_t.check("no cache within RIB_NEAR: the lit sites come first", not driver._rib_goal(0.1, BotDriver.RIB_NEAR))
	_t.check("after them, the nearest cache at any distance", driver._rib_goal(0.1, INF) and driver.steered == Vector3(0, 0, 200))
	var cap: float = BotDriver.RIB_SECONDS + 200.0 / BotDriver.ACTIVITY_TRAVEL_SPEED
	driver._rib_goal(cap, INF)
	_t.check("a cache past its cap is given up for the next", driver._rib_goal(0.1, INF) and driver.steered == Vector3(400, 0, 0))


func _note_rows() -> void:
	var pair := _driver(true)
	var spy: SpyGame = pair[0]
	var driver: Driver = pair[1]
	var near := _cache(Vector3(3, 0, 0))
	var far := _cache(Vector3(200, 0, 0))
	spy.build.scrap.rows = [near, far]
	driver._content_scan()
	_t.eq("both caches are noted placed", driver._note["rib_caches_placed"], 2)
	spy.build.scrap.rows = []
	driver._content_scan()
	_t.eq("only the one under the ball counts taken", driver._note["rib_caches_taken"], 1)
	_t.check("no pockets are named before the world has its sites", not driver._note.has("pockets_drawn"))
	spy.world.activities = SpyActivities.new()
	spy.world.activities.sites = [SpySite.new("cracked_cache", false), SpySite.new("cracked_cache", true, "rim_vault"),
		SpySite.new("enemy_camp", true, "dome_camp")]
	driver._content_scan()
	_t.eq("the drawn pockets are named by library id, the stage's own cache is not", driver._note["pockets_drawn"], ["rim_vault", "dome_camp"])
	spy.world.activities.sites = []
	driver._content_scan()
	_t.eq("read once a stage: a later scan keeps the first reading", driver._note["pockets_drawn"], ["rim_vault", "dome_camp"])
