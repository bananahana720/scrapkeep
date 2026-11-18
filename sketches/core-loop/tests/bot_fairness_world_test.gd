extends SceneTree

const H := preload("res://tests/hazards_hit_everyone_test.gd")
const BotFairness := preload("res://tools/bot_fairness.gd")
const Director := preload("res://src/world/event_director.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const Natural := preload("res://src/world/events/natural.gd")
const HazardHits := preload("res://src/world/events/hazard_hits.gd")
const T := preload("res://tests/support/t.gd")

# The bot fairness record on the world path (tools/bot_fairness.gd loss(), the events' telegraphs(ball)): a storm that seeks a
# parked ball and a flood that taxes one, on the fixture park of hazards_hit_everyone_test.gd, with every theft the run
# stand-in records handed to the recorder the way the bot driver does from scrap_lost. A sought strike under its full ring and a
# flood tax under water that has stood read telegraphed; the same storm with the storm_seek no_tell plant (a ring that strikes
# the moment it is committed) reads untelegraphed. Without telegraphs() the recorder would read none of these.

const DT := 0.1

var _t := T.new("bot_fairness_world_test")


class FairGame:
	extends Node
	var flow := Flow.new()
	var run := Run.new()
	var player: H.Player

	class Flow:
		extends RefCounted
		func in_stage() -> bool:
			return true
		func state_name() -> String:
			return "stage"

	class Run:
		extends RefCounted
		var stage := 1
		func alive() -> bool:
			return true


func _initialize() -> void:
	_run.call_deferred()


func _fixture(row: Dictionary) -> Array:
	var w := H.World.new()
	root.add_child(w)
	w.ctx.root = w
	var map := ParkMap.new()
	map.park = {"map": "park_dam", "park_rows": [{"id": "domes", "at": [0, 0], "y": 0, "size": [20, 2, 10], "yaw_deg": 0}],
		"event_rows": [row], "weather_rows": [], "routes": [{"id": "main", "from": "drop_in", "to": "landmark"}],
		"spawn": {"at": [200, 200]}, "landmark": {"beacon": [-200, 200]}}
	w.terrain.maps = [map]
	w.terrain.geometry = w
	w.events = Director.new(823, {}, map, 14.0, Callable(w.terrain, "height"))
	var handler = Natural.new()
	w.add_child(handler)
	handler.setup(w)
	w.events.register_family("natural", Callable(handler, "handle"))
	return [w, handler]


# Plays the fixture for up to `ticks`, the ball at `ball`, handing each new theft to a recorder. mover(clock, w) may move the ball.
func _play(row: Dictionary, ball: Vector3, ticks: int, mover := Callable(), enemy_at := Vector3.INF) -> Dictionary:
	var fx := _fixture(row)
	var w = fx[0]
	var handler = fx[1]
	w.ctx.player.at = ball
	if enemy_at != Vector3.INF:
		var e := H.Enemy.new()
		w.add_child(e)
		e.add_to_group("enemy")
		e.global_position = enemy_at
	var game := FairGame.new()
	game.player = w.ctx.player
	root.add_child(game)
	var fair := BotFairness.new()
	fair.setup(game, Callable())
	var seen := 0
	var started := false
	for i in ticks:
		var clock := i * DT
		if mover.is_valid():
			mover.call(clock, w)
		# The recorder's tick reads the world before the director steps it, as the driver's does.
		fair.tick(DT)
		w.ctx.run.clock = clock
		handler._physics_process(DT)
		w.events.advance(DT, w.ctx.player.at, w.ctx.player.velocity, {"clock_tier": 1, "grounded": true})
		var losses: Array = w.ctx.run.losses
		while seen < losses.size():
			fair.loss(String(losses[seen].cause), float(losses[seen].amount))
			seen += 1
		started = started or handler.active.size() > 0
		if started and handler.active.is_empty():
			break
	var out := {"record": fair.record(false), "losses": w.ctx.run.losses.duplicate()}
	w.free()
	game.free()
	return out


func _run() -> void:
	var cfg := BotFairness.config()
	_t.check("the world causes are listed", "lightning" in cfg.get("worldCauses", []) and "flood" in cfg.get("worldCauses", []))
	_storm("a sought strike under its full ring", false)
	_storm("a sought strike under a ring with no tell (storm_seek no_tell plant)", true)
	_flood()
	_first_hit()
	quit(_t.verdict())


func _storm(label: String, no_tell: bool) -> void:
	HazardHits.plants.clear()
	if no_tell:
		HazardHits.plants.append("no_tell")
	# The ball parks outside the dome's 6 m circle, so only the sought ring can have told it.
	var read := _play(H.DOME, Vector3(30, 1.2, 0), 400)
	HazardHits.plants.clear()
	var thefts: Array = read.losses.filter(func(l): return l.cause == "lightning")
	if not _t.check("%s: the storm sought the parked ball (no theft is a miss)" % label, thefts.size() > 0, str(read.record.get("scrap_sources"))):
		return
	var scrap: Dictionary = read.record.scrap
	var want := "untelegraphed" if no_tell else "telegraphed"
	var other := "telegraphed" if no_tell else "untelegraphed"
	_t.check("%s: its scrap reads %s" % [label, want], float(scrap[want]) > 0.0 and float(scrap[other]) == 0.0, str(scrap))
	_t.check("%s: pooled share %s the line" % [label, "under" if no_tell else "on"], (float(read.record.pooled_share) < float(BotFairness.config()["telegraphShare"])) == no_tell, str(read.record.get("pooled_share")))
	_t.check("%s: no hull was lost, so the hull share stays unmeasured" % label, read.record.telegraph_share == null)
	_t.check("%s: the parked ball's thefts land in the slow scrap" % label, float(read.record.slow_scrap) > 0.0 and float(read.record.fast_scrap) == 0.0, "slow %s, fast %s" % [read.record.slow_scrap, read.record.fast_scrap])


func _flood() -> void:
	# The ball waits outside the basin until the pool is full, then rolls in and sits (as hazards_hit_everyone_test does).
	var state := {"entered": false, "full_at": -1.0}
	var mover := func(clock: float, w) -> void:
		var handler = w.get_children().filter(func(c): return c is Natural)[0]
		var s = handler.active.get("plunge_pool_flood")
		if state.full_at < 0.0 and s != null and float(s.depth_m) >= float(H.POOL.effect.depth_m) - 0.001:
			state.full_at = clock
		if not state.entered and state.full_at >= 0.0 and clock >= state.full_at + 1.0:
			state.entered = true
			w.ctx.player.at = Vector3(0, 1.2, 0)
	var read := _play(H.POOL, Vector3(40, 1.2, 0), 900, mover)
	var taxes: Array = read.losses.filter(func(l): return l.cause == "flood")
	if not _t.check("flood: the ball sitting in the water was taxed (none is a miss)", taxes.size() > 0):
		return
	var scrap: Dictionary = read.record.scrap
	_t.check("flood: the tax under water that has stood reads telegraphed", float(scrap.telegraphed) > 0.0 and float(scrap.untelegraphed) == 0.0, str(scrap))


# F3: a theft before any pack has been met changes nothing (it must not open the stage as a hit-opened contact and so drop it
# from the median); a theft after contact is the stage's first hit, so it pulls first_hit_s earlier.
func _first_hit() -> void:
	HazardHits.plants.clear()
	var alone := _play(H.DOME, Vector3(30, 1.2, 0), 400)
	var seg = alone.record.first_hit.get("s1")
	_t.check("first hit: thefts happened with no pack met", alone.losses.size() > 0)
	_t.check("first hit: a theft before contact opens nothing", seg != null and not seg.contact and not seg.hit and not seg.opened_by_hit, str(seg))
	var met := _play(H.DOME, Vector3(30, 1.2, 0), 400, Callable(), Vector3(45, 0, 0))
	var seg2 = met.record.first_hit.get("s1")
	_t.check("first hit: after contact the first theft is the first hit, later than contact", seg2 != null and seg2.contact and seg2.hit and not seg2.opened_by_hit and seg2.first_hit_s != null and float(seg2.first_hit_s) > 0.0, str(seg2))
