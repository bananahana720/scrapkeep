extends RefCounted

const RunLog := preload("res://src/core/run_log.gd")
const SpeedTier := preload("res://src/core/speed_tier.gd")

# The traversal detector on synthetic traces (design-v3/TRAVERSAL.md). Cruise 14 m/s, so
# tier 1 starts at 7.7 m/s and tier 2 at 16.1. One sample per tick at 90 ticks a second.

const TPS := 90
const CRUISE := 14.0
const FAST := 18.0
const SLOW := 4.5


func run(t) -> void:
	var braked := _tracker()
	_run(braked, FAST, 30, false)
	_ramp(braked, FAST, 0.0, 45, true)
	_run(braked, 0.0, 90, true)
	t.eq("a brake-held slowdown is not a dead stop", braked.dead_stops, 0)

	var wall := _tracker()
	_run(wall, FAST, 60, false)
	_run(wall, 8.0, 60, false)
	t.eq("a wall hit that halves planar speed counts once", wall.dead_stops, 1)

	var wall_then_crawl := _tracker()
	_run(wall_then_crawl, FAST, 60, false)
	_run(wall_then_crawl, 3.0, 90, false)
	t.eq("a hit into a crawl is still one stop, not two", wall_then_crawl.dead_stops, 1)

	var short := _tracker()
	_approach(short)
	_run(short, SLOW, 36, false)
	_run(short, FAST, 30, false)
	t.eq("0.4 s under tier 1 is not a dead stop", short.dead_stops, 0)

	var long := _tracker()
	_approach(long)
	_run(long, SLOW, 54, false)
	t.eq("0.6 s under tier 1 is a dead stop", long.dead_stops, 1)

	var mounted := _tracker()
	_approach(mounted)
	_run(mounted, SLOW, 90, false, true)
	t.eq("a mount is not a dead stop", mounted.dead_stops, 0)

	var standing := _tracker()
	_run(standing, 0.0, 90, false)
	t.eq("a standing start is not a dead stop", standing.dead_stops, 0)

	var staged := _tracker()
	_run(staged, FAST, 90, false)
	staged.restart()
	_run(staged, 0.0, 90, false)
	_run(staged, 3.0, 90, false)
	t.eq("a stage's standing start after restart is not a dead stop", staged.dead_stops, 0)
	var kept := _tracker()
	_run(kept, FAST, 60, false)
	_run(kept, 8.0, 60, false)
	kept.restart()
	t.eq("restart keeps the totals", [kept.dead_stops, kept.ticks], [1, 120])

	var share := _tracker()
	_run(share, FAST, 75, false)
	_run(share, 10.0, 25, false)
	t.near("flow share is the fraction of ticks at tier 2", share.flow_share(), 0.75)


func _tracker() -> RunLog.Traversal:
	return RunLog.Traversal.new(TPS, CRUISE)


func _run(tracker: RunLog.Traversal, speed: float, ticks: int, braking: bool, exempt := false) -> void:
	for i in ticks:
		tracker.step(SpeedTier.of(speed, CRUISE), speed, braking, exempt)


func _ramp(tracker: RunLog.Traversal, from: float, to: float, ticks: int, braking: bool) -> void:
	for i in ticks:
		var speed := lerpf(from, to, float(i + 1) / float(ticks))
		tracker.step(SpeedTier.of(speed, CRUISE), speed, braking, false)


# Down from a fast roll to just inside tier 1, slowly enough that the speed never falls
# under half of its peak within the last 0.1 s, so only the held crawl that follows can count.
func _approach(tracker: RunLog.Traversal) -> void:
	_run(tracker, FAST, 30, false)
	_ramp(tracker, FAST, 7.8, 90, false)
