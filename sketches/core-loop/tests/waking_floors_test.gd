extends SceneTree

const Floors := preload("res://src/boss/waking_floors.gd")
const Rules := preload("res://src/boss/boss_rules.gd")
const Posture := preload("res://src/core/boss_posture.gd")
const T := preload("res://tests/support/t.gd")

# The Waking's floor rule (src/boss/waking_floors.gd) on its own, no Game: one floor per
# phase, all live at start; chunks 1..floors drop one floor each, highest first; the
# last chunk is defeat and drops nothing; a repeated or lower count never raises a floor;
# over 200 seeded chunk sequences the live set only shrinks and the ball's floor height
# never rises; the floor count follows the phase names it is given.
#
# Evidence limit: the rule only. No map lays these overlays yet, and the fight's wiring
# (waking.gd) is not exercised.

const SEQUENCES := 200
const STEPS := 12
const GROUND := 0.0

var _t := T.new("waking_floors_test")


func _initialize() -> void:
	_start()
	_drops()
	_defeat()
	_never_rise()
	_monotone()
	_tracks_names()
	quit(_t.verdict())


func _start() -> void:
	var f := Floors.new()
	_t.eq("floor_count is the phase count", f.floor_count(), Rules.PHASE_NAMES.size())
	_t.eq("one overlay per floor", f.overlays().size(), f.floor_count())
	var ids := {}
	var all_live := true
	for o in f.overlays():
		ids[o["id"]] = true
		all_live = all_live and o["live"]
	_t.eq("overlay ids unique", ids.size(), f.floor_count())
	_t.check("all floors live at start", all_live and f.live_floors().size() == f.floor_count())
	_t.eq("start on the top floor", f.current_floor(), 1)
	_t.check("not defeated at start", not f.defeated())


func _drops() -> void:
	var f := Floors.new()
	for k in range(1, f.floor_count() + 1):
		var before := _heights(f)
		f.chunks_shattered(k)
		var after := _heights(f)
		_t.eq("chunk %d leaves %d live floors" % [k, f.floor_count() - k], f.live_floors().size(), f.floor_count() - k)
		_t.check("chunk %d drops floor %d, the highest live" % [k, k], not f.live_floors().has(k) and is_inf(after[k - 1]) and after[k - 1] < 0.0, "overlay_height %s" % after[k - 1])
		var others := true
		for j in range(after.size()):
			if j != k - 1 and after[j] != before[j]:
				others = false
		_t.check("chunk %d leaves the other floors unchanged" % k, others, "before %s after %s" % [before, after])
	_t.eq("pit after the last floor", f.current_floor(), 0)


func _defeat() -> void:
	var f := Floors.new()
	f.chunks_shattered(f.floor_count())
	var before := f.live_floors()
	_t.check("not defeated before the last chunk", not f.defeated())
	f.on_posture(0)
	_t.check("chunk %d sets defeated" % Posture.CHUNKS, f.defeated())
	_t.eq("defeat drops no floor", f.live_floors(), before)


func _never_rise() -> void:
	var f := Floors.new()
	f.chunks_shattered(2)
	var live := f.live_floors()
	var repeated := f.chunks_shattered(2)
	_t.eq("a repeated count keeps the floors", f.live_floors(), live)
	_t.check("a repeated count is accepted as no change", repeated)
	var lower := f.chunks_shattered(1)
	_t.eq("a lower count keeps the floors", f.live_floors(), live)
	_t.check("a lower count is refused and counted", not lower and f.ignored == 1, "returned %s, ignored %d" % [lower, f.ignored])
	f.on_posture(Posture.CHUNKS)
	_t.eq("a full chunk bar later keeps the floors", f.live_floors(), live)


func _monotone() -> void:
	var grew := 0
	var rose := 0
	var unordered := 0
	var f0 := Floors.new()
	for k in range(1, f0.floor_count() + 1):
		var below := f0.floor_height(k + 1) if k < f0.floor_count() else 0.0
		if not f0.floor_height(k) > below:
			unordered += 1
	_t.eq("heights strictly increase from the pit upward", unordered, 0)
	for s in SEQUENCES:
		var rng := RandomNumberGenerator.new()
		rng.seed = 7919 + s
		var f := Floors.new()
		var live := f.live_floors()
		var height := _ball_height(f)
		for i in STEPS:
			if rng.randi() % 2 == 0:
				f.chunks_shattered(rng.randi_range(0, Posture.CHUNKS))
			else:
				f.on_posture(rng.randi_range(0, Posture.CHUNKS))
			var now := f.live_floors()
			for k in now:
				if not live.has(k):
					grew += 1
			var h := _ball_height(f)
			if h > height:
				rose += 1
			live = now
			height = h
	_t.eq("live floor set never grows over %d sequences" % SEQUENCES, grew, 0)
	_t.eq("ball floor height never rises over %d sequences" % SEQUENCES, rose, 0)


func _tracks_names() -> void:
	for n in [1, 2, 5]:
		var names := []
		for i in n:
			names.append("Tier%d" % i)
		var f := Floors.new(names, n + 1)
		_t.eq("floor_count tracks %d injected names" % n, f.floor_count(), n)
		_t.eq("overlays track %d injected names" % n, f.overlays().size(), n)


func _heights(f) -> Array:
	var out := []
	for o in f.overlays():
		out.append(f.overlay_height(o["id"], GROUND))
	return out


# What a map's terrain.height gives under the ball: the ground raised to the highest live
# overlay.
func _ball_height(f) -> float:
	var h := GROUND
	for o in f.overlays():
		h = maxf(h, f.overlay_height(o["id"], GROUND))
	return h
