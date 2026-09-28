extends SceneTree

const Game := preload("res://src/game.gd")
const BotDriver := preload("res://tools/bot_driver.gd")
const LoopMode := preload("res://src/core/loop_mode.gd")

# The v3 fun lab's laps mode on stage 1 (LOOP-REDESIGN section 1 C, section 7): the
# bell, the course and the Warden's sleep. The camper (the skipper bot) rings the bell
# and rams the sleeping Warden for CAMP_SECONDS without waking or denting it. Then, on a
# retry, the ball rides the real return lift (its banked speed comes back and it rolls
# on through the shelf's ring) and is set on each ring in turn: three laps wake the
# Warden, a fourth strips a third of its plating, a skipped ring does not count, and the
# director steps and announces once per lap. Last, v2 after a retry: no course, no sleep.
#
# Evidence limit: placing the ball on a ring proves the rules and the wiring, not that a
# lap is fun or fair to drive; the bot runs in DESIGN-NOTES measure the laps themselves.

const CAMP_SECONDS := 20.0
const LIFT_SECONDS := 9.0
const RING_TICKS := 3

var _game
var _failures := 0
var _phase := "boot"
var _wait := 0
var _driver
var _seen := {}
var _rises: Array[int] = []
var _rise_frames: Array[int] = []
var _lap_frames: Array[int] = []
var _stripped: Array[float] = []
var _warden_struck := 0
var _plan: Array = []
var _ride_seen := false
var _release_speed := -1.0
var _lift_entry := 0.0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _count(kind: String) -> int:
	return int(_seen.get(kind, 0))


func _bump(kind: String) -> void:
	_seen[kind] = _count(kind) + 1


func _listen() -> void:
	var bus = _game.events
	bus.lap_bell_rung.connect(func(_at: Vector3): _bump("lap_bell_rung"))
	bus.warden_engaged.connect(func(_stage: int): _bump("warden_engaged"))
	bus.lap_completed.connect(func(_lap: int, _required: int, _s: float):
		_bump("lap_completed")
		_lap_frames.append(Engine.get_physics_frames()))
	bus.lap_ring_passed.connect(func(index: int, _n: int, _at: Vector3): _bump("ring_%d" % index))
	bus.threat_rose.connect(func(tier: int):
		_rises.append(tier)
		_rise_frames.append(Engine.get_physics_frames()))
	bus.warden_stripped.connect(func(plating: float, _at: Vector3): _stripped.append(plating))
	bus.enemy_struck.connect(func(enemy: Node3D, _k: String, _f: float):
		if enemy == _game.flow.warden:
			_warden_struck += 1)


func _place(p: Vector2, velocity := Vector3.ZERO) -> void:
	var at: Vector3 = _game.ctx.terrain.drop_point(p.x, p.y, 1.0)
	_game.player.reset_to(at, velocity)
	_game.player.body().global_position = at


func _ring(i: int) -> Vector2:
	var r: Vector3 = _game.world.course.rings[i]
	return Vector2(r.x, r.z)


func _reset_counts() -> void:
	_seen = {}
	_rises.clear()
	_rise_frames.clear()
	_lap_frames.clear()
	_stripped.clear()
	_warden_struck = 0


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_wait += 1
	var tps := Engine.physics_ticks_per_second
	var flow = _game.flow
	match _phase:
		"boot":
			LoopMode.apply_args(_game.tuning, PackedStringArray(["--loop=laps"]))
			_listen()
			_driver = BotDriver.new(_game, "skipper", 1)
			_driver.start()
			_phase = "camp"
			_wait = 0
		"camp":
			_driver.tick(1.0 / tps)
			if _wait < int(CAMP_SECONDS * tps):
				return false
			_driver.source.hold = {}
			var w = flow.warden
			_check("camper cannot wake it", _count("lap_bell_rung") == 1 and _warden_struck > 0 and w.dormant and w.hp == w.max_hp
				and flow.laps == 0 and _count("warden_engaged") == 0 and _game.world.director.laps == 0,
				"%.0f s camping: bell %d, %d strikes on the Warden, hp %.0f / %.0f, asleep %s, laps %d, wake cues %d"
				% [CAMP_SECONDS, _count("lap_bell_rung"), _warden_struck, w.hp, w.max_hp, w.dormant, flow.laps, _count("warden_engaged")])
			_check("objective", flow.lap_objective(true) == "Lap the course: 0/3" and flow.objective_text().contains("0 of 3")
				and _game.hud.objective_reading()["words"] == "Lap the course: 0/3",
				"HUD '%s'; line '%s'" % [_game.hud.objective_reading()["words"], flow.objective_text()])
			flow.retry_stage()
			_reset_counts()
			_phase = "bell"
			_wait = 0
		"bell":
			if _wait == 2:
				var w = flow.warden
				var hp: float = w.hp
				_game.ctx.spawner.strike(w, "ram", 80.0)
				_check("asleep takes nothing", w.dormant and w.hp == hp and _game.ctx.spawner.shred_of(w) == 0.0
					and flow.lap_objective(true) == "Ring the Warden's bell" and _game.beacon.notches_lit() == 0,
					"a hard ram on the sleeping Warden: hp %.0f -> %.0f, shred %.1f; objective '%s'"
					% [hp, w.hp, _game.ctx.spawner.shred_of(w), flow.lap_objective(true)])
				var mast: Vector3 = _game.ctx.terrain.beacon_point(1)
				_place(Vector2(mast.x + 12.0, mast.z))
			if _wait < int(1.5 * tps):
				return false
			_check("bell", _count("lap_bell_rung") == 1 and _game.world.course.bell_rung, "rolling into the ring rings the bell once")
			var lift: Vector2 = _game.ctx.terrain.map().return_at
			var mast: Vector3 = _game.ctx.terrain.beacon_point(1)
			var toward := (lift - Vector2(mast.x, mast.z)).normalized()
			_lift_entry = 20.0
			_place(lift - toward * 13.0, Vector3(toward.x, 0.0, toward.y) * _lift_entry)
			_phase = "lift"
			_wait = 0
		"lift":
			var riding: bool = _game.world.ride != null
			if riding:
				_ride_seen = true
			elif _ride_seen and _release_speed < 0.0:
				_release_speed = _game.player.planar_velocity().length()
			if _count("ring_1") == 0 and _wait < int(LIFT_SECONDS * tps):
				return false
			var floor_speed: float = _game.ctx.terrain.map().contraptions[0]["floor"]
			_check("lift keeps speed", _ride_seen and _release_speed >= floor_speed * 0.95 and _count("ring_0") == 1 and _count("ring_1") == 1,
				"into the lift at %.0f m/s, out at %.1f m/s (floor %.0f), then through the shelf ring unsteered: rings 0 %d, 1 %d"
				% [_lift_entry, _release_speed, floor_speed, _count("ring_0"), _count("ring_1")])
			_plan = [2, 3, 4, 0, 1, 2, 3, 4, 0, 1, 2, 3, 4]
			_phase = "laps"
			_wait = 0
		"laps":
			if _wait < RING_TICKS:
				return false
			_wait = 0
			if not _plan.is_empty():
				_place(_ring(_plan.pop_front()))
				return false
			var w = flow.warden
			_check("three laps wake it", _count("lap_completed") == 3 and flow.laps == 3 and not w.dormant and _count("warden_engaged") == 1
				and _game.beacon.notches_lit() == 3 and _game.ctx.spawner.plating_of(w) == 45.0,
				"laps %d, asleep %s, wake cues %d, notches lit %d, plating %.0f (unshredded)"
				% [flow.laps, w.dormant, _count("warden_engaged"), _game.beacon.notches_lit(), _game.ctx.spawner.plating_of(w)])
			var hp: float = w.hp
			_game.ctx.spawner.strike(w, "ram", 80.0)
			_check("awake takes hits", w.hp < hp and not flow.lap_dormant()
				and not flow.objective_text().contains("of 3"), "the same ram awake: hp %.0f -> %.0f; objective '%s'" % [hp, w.hp, flow.objective_text()])
			_place(_ring(0))
			_phase = "skip"
		"skip":
			if _wait < RING_TICKS:
				return false
			_place(_ring(2))
			_phase = "skipped"
			_wait = 0
		"skipped":
			if _wait < RING_TICKS:
				return false
			_check("rings in order", _game.world.course.next_ring == 1 and _count("ring_2") == 3,
				"ring 0 then ring 2: the course still wants ring 1 (next %d)" % _game.world.course.next_ring)
			_plan = [1, 2, 3, 4]
			_phase = "extra"
			_wait = 0
		"extra":
			if _wait < RING_TICKS:
				return false
			_wait = 0
			if not _plan.is_empty():
				_place(_ring(_plan.pop_front()))
				return false
			var w = flow.warden
			_check("an extra lap strips", flow.laps == 4 and w.plating == 30.0 and _stripped == [30.0] and _game.beacon.notches_lit() == 3,
				"lap 4: plating %.0f of 45, warden_stripped %s" % [w.plating, _stripped])
			var director = _game.world.director
			var announced := _lap_frames.filter(func(f: int): return f in _rise_frames)
			_check("director steps per lap", director.laps == 4 and _lap_frames.size() == 4 and announced.size() == 4
				and director.reinforcement_weight() > 0.0 and director.level() == director.effective_tier() + 4,
				"director laps %d, level %d (tier %d), threat_rose %s, %d of %d laps announced on their own tick, pack share %.2f"
				% [director.laps, director.level(), director.effective_tier(), _rises, announced.size(), _lap_frames.size(), director.reinforcement_weight()])
			_game.tuning.set_option(LoopMode.LOOP_KEY, "v2")
			flow.retry_stage()
			_reset_counts()
			_phase = "v2"
			_wait = 0
		"v2":
			if _wait < 3:
				return false
			var w = flow.warden
			var hp: float = w.hp
			_game.ctx.spawner.strike(w, "ram", 80.0)
			var course_gone: bool = _game.world.course == null
			_check("v2 untouched", course_gone and not w.dormant and flow.laps_required == 0 and w.hp < hp and _game.beacon.notches_lit() == 0
				and _game.world.director.laps == 0 and _game.hud.objective_reading()["words"] != flow.lap_objective(true),
				"after a flip to v2 and a retry: course %s, asleep %s, lap gate %d, a ram lands (hp %.0f -> %.0f), HUD '%s'"
				% ["gone" if course_gone else "standing", w.dormant, flow.laps_required, hp, w.hp, _game.hud.objective_reading()["words"]])
			var mast: Vector3 = _game.ctx.terrain.beacon_point(1)
			_place(Vector2(mast.x + 12.0, mast.z))
			_phase = "v2_bell"
			_wait = 0
		"v2_bell":
			if _wait < 10:
				return false
			_check("v2 no bell", _count("lap_bell_rung") == 0 and _count("warden_engaged") == 1,
				"v2 ring entry wakes nothing new: bell %d, warden_engaged %d (the v2 engage)" % [_count("lap_bell_rung"), _count("warden_engaged")])
			print("loop_laps_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
			quit(0 if _failures == 0 else 1)
			return true
	return false
