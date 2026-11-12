extends SceneTree

const Director := preload("res://src/world/director.gd")
const RunClock := preload("res://src/build/run_clock.gd")
const T := preload("res://tests/support/t.gd")

# Wave 37 unit D3 (ruling cu): the difficulty clock climbs a third tier on world 1, at 135 s. Staying longer
# means a bigger crowd, shorter gaps between arrivals and a larger lobber share, and the rise is announced as
# the first two are. Later worlds keep two tiers. The run clock the HUD draws reads the same count. The
# director is stepped headless at a fixed h, as world_director_test steps it.

const H := 1.0 / 90.0
const TWO_EVERYWHERE := {"mobs.clock_tiers_by_stage": [2.0, 2.0, 2.0, 2.0, 2.0, 2.0]}

var _t := T.new("clock_third_tier_test")


func _initialize() -> void:
	ChallengeDials.reset()
	_dial()
	_director()
	_planted()
	_run_clock()
	ChallengeDials.reset()
	quit(_t.verdict())


func _dial() -> void:
	_t.eq("01 world 1 ships three clock tiers, later worlds two", ChallengeDials.value("mobs.clock_tiers_by_stage"), [3.0, 3.0, 2.0, 2.0, 2.0, 2.0])
	_t.eq("02 the dam's last tier is 3", Director.clock_tiers(1), 3)
	_t.eq("03 the flume's last tier is 3", Director.clock_tiers(2), 3)
	_t.eq("04 the Dig's last tier is the base 2", Director.clock_tiers(3), Director.MAX_TIME_TIERS)
	_t.eq("05 a director with no stage row keeps the base 2", Director.clock_tiers(0), Director.MAX_TIME_TIERS)


# One stage stepped for `seconds`: {"rises": [[tier, at seconds]...], "tier", "cap", "interval", "lobbers"}.
func _stage(stage: int, seconds: float) -> Dictionary:
	var d := Director.new(37)
	d.set_run_tier_reader(func(): return 0)
	d.dial_stage = stage
	var rises: Array = []
	var t := 0.0
	while t < seconds:
		d.advance(H, 0)
		t += H
		for rise in d.take_threat_rises():
			rises.append([rise, snappedf(t, 0.1)])
	return {"rises": rises, "tier": d.tier(), "cap": d.cap(), "interval": d.interval(), "lobbers": d.lobber_share()}


func _director() -> void:
	var early := _stage(1, 134.0)
	var late := _stage(1, 140.0)
	_t.eq("06 at 134 s the dam's clock is still on tier 2", early.tier, 2)
	_t.eq("07 at 140 s it is on tier 3", late.tier, 3)
	_t.eq("08 the three rises are announced, the third at 135 s", late.rises, [[1, 45.0], [2, 90.0], [3, 135.0]])
	_t.check("09 the third tier adds crowd", late.cap > early.cap, "cap %d then %d" % [early.cap, late.cap])
	_t.check("10 and shortens the gap between arrivals", late.interval < early.interval, "interval %.2f s then %.2f s" % [early.interval, late.interval])
	_t.check("11 and raises the lobber share", late.lobbers > early.lobbers, "share %.2f then %.2f" % [early.lobbers, late.lobbers])
	var long := _stage(1, 400.0)
	_t.eq("12 the clock stops at tier 3 however long the stay", [long.tier, long.rises.size()], [3, 3])
	var dig := _stage(3, 400.0)
	_t.eq("13 the Dig's clock stops at tier 2, two rises", [dig.tier, dig.rises.size()], [2, 2])


# The planted case: the dial at two tiers everywhere is the game before this unit; the same 140 s on the dam
# must stop at tier 2 with two rises, or checks 07 and 08 say nothing about the dial.
func _planted() -> void:
	ChallengeDials.set_overrides(TWO_EVERYWHERE)
	var base := _stage(1, 140.0)
	ChallengeDials.set_overrides({})
	_t.eq("14 planted: at two tiers the dam stops at tier 2", base.tier, 2)
	_t.eq("15 planted: and announces two rises", base.rises, [[1, 45.0], [2, 90.0]])


func _run_clock() -> void:
	var clock := RunClock.new()
	clock.begin_run({})
	_t.eq("16 the run clock's last tier on the dam is the director's", clock.tiers(), Director.clock_tiers(1))
	clock.advance(90.0, 90.0, true)
	_t.near("17 at 90 s the dam's bar is two thirds full", clock.difficulty_fraction(), 2.0 / 3.0, 0.0001)
	_t.eq("18 and reads tier 2 of 3", [clock.difficulty_tier(), int(clock.record().difficulty.tiers)], [2, 3])
	clock.advance(50.0, 140.0, true)
	_t.eq("19 at 140 s it reads tier 3, bar full", [clock.difficulty_tier(), clock.difficulty_fraction()], [3, 1.0])
	clock.enter_stage(3)
	clock.advance(90.0, 230.0, true)
	_t.eq("20 the Dig's bar is full at 90 s, tier 2 of 2", [clock.difficulty_tier(), clock.difficulty_fraction(), int(clock.record().difficulty.tiers)], [2, 1.0, 2])
	_t.eq("21 the tick is the director's", RunClock.DIFFICULTY_TICK, Director.TIER_SECONDS)
