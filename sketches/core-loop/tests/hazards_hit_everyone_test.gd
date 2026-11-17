extends SceneTree

const Director := preload("res://src/world/event_director.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const Natural := preload("res://src/world/events/natural.gd")
const StormSeek := preload("res://src/world/events/storm_seek.gd")
const HazardHits := preload("res://src/world/events/hazard_hits.gd")
const T := preload("res://tests/support/t.gd")

# W44, hazards hit everyone (ruling cu). The Spillway's storm (the dam's dome lightning row as authored: a 3 s tell,
# 20 s live, a 6 m strike, 8 damage) and its rising flood, on a fixture park named park_dam, with stand-in enemies:
#   stalled  a ball parked away from the dome: every sought strike tells for at least 0.6 s on one spot, lands there,
#            costs the ball the row's damage and strikes the enemy beside it; the first comes within the bound
#            (the stall window, then a tick); the dome itself strikes the enemy standing in its circle.
#   escape   a ball that rolls off as the tell starts: the strike lands on the old spot and misses it.
#   rolling  a ball orbiting tight at twice cruise: never sought (ruling cu: rolling and turning stays free).
#   flood    the enemy in the risen water is swept; a ball sitting slow in it pays no tax for 3 s, then pays.
# Too little data is a miss: each scenario must see the strikes or taxes it reads, or the check fails.
# Plants (HazardHits.PLANT_ENV): skip_enemies, no_tell and seek_rolling must each turn this test red.

const DT := 0.1
const CRUISE := 14.0
const DOME := {"id": "dome_lightning", "kind": "lightning", "family": "natural", "site": "domes",
	"trigger": {"on": "clock_tier", "value": 1}, "weight": 1.0,
	"telegraph": {"lead_s": 3.0, "form": "lightning_charge", "on_bar": false}, "live_s": 20.0,
	"effect": {"strike_m": 6.0, "damage": 8.0}, "route_change": {"closes": [], "opens": []},
	"hold_clear_m": 0.0, "cooldown_s": 60.0, "once": true, "music_cue": {"telegraph": "riser_natural", "land": "stinger_lightning"}}
const POOL := {"id": "plunge_pool_flood", "kind": "flood_fill", "family": "natural", "site": "domes",
	"trigger": {"on": "clock_tier", "value": 1}, "weight": 1.0,
	"telegraph": {"lead_s": 6.0, "form": "flood_rising", "on_bar": false}, "live_s": 35.0,
	"effect": {"depth_m": 1.2, "fill_s": 10.0, "material": "water"}, "route_change": {"closes": [], "opens": []},
	"hold_clear_m": 0.0, "cooldown_s": 90.0, "once": true, "music_cue": {"telegraph": "riser_natural", "land": "drop_flood_horn"}}
# Pinned from the first green run on this branch (Mac, Godot 4.7.2): sought strikes on the parked ball in one storm.
const STALLED_STRIKES := 2


class Tuning:
	extends RefCounted
	func f(_key: String) -> float:
		return CRUISE

class Player:
	extends RefCounted
	var state := {"velocity": Vector3.ZERO}
	var tuning := Tuning.new()
	var at := Vector3.ZERO
	var velocity := Vector3.ZERO
	func ball_position() -> Vector3:
		return at
	func planar_velocity() -> Vector3:
		return Vector3(velocity.x, 0.0, velocity.z)
	func set_velocity_now(v: Vector3, _cause := "") -> void:
		state.velocity = v

class Run:
	extends RefCounted
	var mass := 200
	var stage := 1
	var losses: Array = []
	var clock := 0.0
	func lose_scrap(amount: int, _at: Vector3, cause: String) -> int:
		var lost := mini(amount, mass)
		mass -= lost
		losses.append({"amount": lost, "cause": cause, "t": clock})
		return lost

class Context:
	extends RefCounted
	var player := Player.new()
	var run := Run.new()
	var root: Node3D
	var events: Node = null
	var spawner = null

class Terrain:
	extends RefCounted
	var maps: Array = []
	var stage := 1
	var flood = null
	var overlays: Array[String] = []
	var geometry: Node3D
	func geometry_root(_stage: int) -> Node3D:
		return geometry
	func map():
		return maps[stage - 1]
	func height(_x: float, _z: float) -> float:
		return 0.0

class World:
	extends Node3D
	var ctx := Context.new()
	var terrain := Terrain.new()
	var events
	var flood = null
	var terrain_view = null

class Enemy:
	extends Node3D
	var kind := "chaser"
	var half_height := 1.0
	var hp := 1000.0
	var hits: Array = []
	var knocks := 0
	var last_damage_source := ""
	func take_damage(amount: float) -> float:
		hp -= amount
		hits.append(last_damage_source)
		return amount
	func knock(_direction: Vector3, _force: float) -> void:
		knocks += 1
	func is_dead() -> bool:
		return hp <= 0.0

var t := T.new("hazards_hit_everyone_test")


func _initialize() -> void:
	_run.call_deferred()


func _fixture(row: Dictionary) -> Array:
	var w := World.new()
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


func _enemy(w: Node3D, at: Vector3) -> Enemy:
	var e := Enemy.new()
	w.add_child(e)
	e.add_to_group("enemy")
	e.global_position = at + Vector3.UP * e.half_height
	return e


# One tick: the ball's read (natural.gd _physics_process), then the director.
func _tick(w, handler, clock: float) -> void:
	w.ctx.run.clock = clock
	handler._physics_process(DT)
	w.events.advance(DT, w.ctx.player.at, w.ctx.player.velocity, {"clock_tier": 1, "grounded": true})


func _run() -> void:
	t.check("world 1's stages have hazards that hit enemies", HazardHits.applies(1) and HazardHits.applies(2))
	t.check("a parked world's stage does not", not HazardHits.applies(3))
	t.check("a run with no stage does not", not HazardHits.applies_to(null))
	_stalled()
	_escape()
	_rolling()
	_flood()
	quit(t.verdict())


# Ticks until the storm ends; returns each strike as {tell_s, told_at, at, t} and the first tell's time.
func _storm(w, handler, mover := Callable()) -> Dictionary:
	var strikes := []
	var first_tell := -1.0
	var live_at := -1.0
	var told_at := Vector3.INF
	var tells := 0
	for i in 400:
		var clock := i * DT
		if mover.is_valid():
			mover.call(clock, handler)
		_tick(w, handler, clock)
		var state = handler.active.get("dome_lightning")
		if live_at < 0.0 and state != null and state.phase == "live":
			live_at = clock
		if handler.seek.tells > tells:
			tells = handler.seek.tells
			told_at = handler.seek.pending().centre if handler.seek.pending() != null else Vector3.INF
			if first_tell < 0.0:
				first_tell = clock
		if handler.seek.strikes > strikes.size():
			strikes.append({"tell_s": handler.seek.last_tell_s, "told_at": told_at, "at": handler.seek.last_at, "t": clock})
		if live_at >= 0.0 and state == null:
			break
	return {"strikes": strikes, "first_tell": first_tell, "live_at": live_at, "tells": tells}


func _stalled() -> void:
	var fx := _fixture(DOME)
	var w = fx[0]
	var handler = fx[1]
	w.ctx.player.at = Vector3(30, 1.2, 0)
	var beside := _enemy(w, Vector3(33, 0, 0))
	var in_dome := _enemy(w, Vector3(2, 0, 0))
	var far := _enemy(w, Vector3(60, 0, 0))
	var read := _storm(w, handler)
	var strikes: Array = read.strikes
	t.check("stalled: the storm went live", read.live_at >= 0.0)
	if not t.check("stalled: the parked ball was sought (no strikes is a miss)", strikes.size() > 0, str(read)):
		return
	t.eq("stalled: sought strikes in one storm (pinned)", strikes.size(), STALLED_STRIKES)
	t.eq("stalled: every tell struck", read.tells, strikes.size())
	var bound: float = maxf(read.live_at, StormSeek.SiltBoil.LOOP_WINDOW) + StormSeek.SLOW_S + 2.0 * DT
	t.check("stalled: the first tell came within the bound", read.first_tell >= 0.0 and read.first_tell <= bound,
		"first tell %.1f s, bound %.1f s" % [read.first_tell, bound])
	for s in strikes:
		t.check("stalled: tell of at least 0.6 s", float(s.tell_s) >= 0.6, "tell %.2f s" % float(s.tell_s))
		t.check("stalled: struck where it told", (s.at as Vector3).distance_to(s.told_at) < 0.001, str(s))
	var hits: Array = w.ctx.run.losses.filter(func(l): return l.cause == "lightning")
	t.eq("stalled: each strike cost the ball the row's damage", hits.size(), strikes.size())
	t.check("stalled: the enemy beside the ball was struck", beside.hits.size() >= 1 and beside.hits.has("lightning"), str(beside.hits))
	t.check("stalled: the enemy in the dome's circle was struck", in_dome.hits.has("lightning"), str(in_dome.hits))
	t.check("stalled: an enemy struck once per dome activation", in_dome.hits.size() == 1, str(in_dome.hits))
	t.eq("stalled: an enemy outside every circle was not", far.hits.size(), 0)
	t.check("stalled: a struck enemy is thrown", beside.knocks >= 1 and in_dome.knocks == 1)
	w.free()


func _escape() -> void:
	var fx := _fixture(DOME)
	var w = fx[0]
	var handler = fx[1]
	w.ctx.player.at = Vector3(30, 1.2, 0)
	var mover := func(_clock: float, h) -> void:
		if h.seek.pending() != null:
			w.ctx.player.at = Vector3(45, 1.2, 0)
			w.ctx.player.velocity = Vector3(CRUISE * 2.0, 0, 0)
	var read := _storm(w, handler, mover)
	if not t.check("escape: a tell started (none is a miss)", read.tells >= 1, str(read)):
		return
	t.check("escape: it struck on the old spot", read.strikes.size() >= 1 and (read.strikes[0].at as Vector3).distance_to(Vector3(30, 0, 0)) < 0.001, str(read.strikes))
	t.eq("escape: the ball that rolled off was not hit", w.ctx.run.losses.size(), 0)
	w.free()


func _rolling() -> void:
	var fx := _fixture(DOME)
	var w = fx[0]
	var handler = fx[1]
	var speed := CRUISE * 2.0
	var radius := 8.0
	var mover := func(clock: float, _h) -> void:
		var a := clock * speed / radius
		w.ctx.player.at = Vector3(30.0 + cos(a) * radius, 1.2, sin(a) * radius)
		w.ctx.player.velocity = Vector3(-sin(a), 0.0, cos(a)) * speed
	var read := _storm(w, handler, mover)
	t.check("rolling: the storm went live (else nothing was read)", read.live_at >= 0.0)
	t.eq("rolling: a ball orbiting tight at twice cruise is never sought", read.tells, 0)
	t.eq("rolling: and never hit", w.ctx.run.losses.size(), 0)
	w.free()


func _flood() -> void:
	var fx := _fixture(POOL)
	var w = fx[0]
	var handler = fx[1]
	# The water holds its rise while the ball is in the basin (event_director.gd _park_step_live), so the ball
	# waits outside, then rolls in once the pool is full and sits there.
	w.ctx.player.at = Vector3(40, 1.2, 0)
	var wader := _enemy(w, Vector3(4, 0, 2))
	var entered_at := -1.0
	var full_at := -1.0
	var seen := false
	for i in 900:
		var clock := i * DT
		_tick(w, handler, clock)
		var state = handler.active.get("plunge_pool_flood")
		seen = seen or state != null
		if full_at < 0.0 and state != null and float(state.depth_m) >= float(POOL.effect.depth_m) - 0.001:
			full_at = clock
		# A second after full, so the director's rise clock has reached fill_s too (it reads the last tick's sum).
		if entered_at < 0.0 and full_at >= 0.0 and clock >= full_at + 1.0:
			entered_at = clock
			w.ctx.player.at = Vector3(0, 1.2, 0)
		if seen and state == null:
			break
	var taxes: Array = w.ctx.run.losses.filter(func(l): return l.cause == "flood")
	t.check("flood: the pool filled (else nothing was read)", entered_at >= 0.0)
	t.check("flood: the enemy in the water was swept", wader.hits.has("flood_fill") and wader.knocks >= 1, str(wader.hits))
	if t.check("flood: the ball sitting slow in it was taxed (none is a miss)", taxes.size() >= 1):
		t.check("flood: no tax before 3 s sitting in the water", float(taxes[0].t) - entered_at >= Natural.FLOOD_TAX_AFTER_S - DT,
			"first tax %.1f s, entered at %.1f s" % [float(taxes[0].t), entered_at])
	w.free()
