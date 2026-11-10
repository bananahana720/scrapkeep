extends SceneTree

const T := preload("res://tests/support/t.gd")
const SetDressing := preload("res://src/presentation/set_dressing.gd")

# A quitting game tells its set-dressing worker to stop (set_dressing.gd _exit_tree), so quit never
# waits for a plan nobody will take: 2.9 s of a 14 s headless game test on a 4-core box before
# this (2026-11-09). No game boots here: plan() is pure over a made-up ground and map.
#   - a plan with no flag and a plan with a lowered flag are the same buffers (play is unchanged);
#   - a flag raised before the draw returns without a ground read;
#   - a flag raised part-way stops the draw within one loop step, well short of the full count.

const MAP := {
	"play_rect": Rect2(-120.0, -120.0, 240.0, 240.0),
	"scatter": {"spacing": 6.0, "edge_share": 0.5, "clusters": 12},
	"structures": [Vector2(10.0, 10.0), Vector2(-40.0, 25.0), Vector2(60.0, -70.0)],
}
const FLAGS := {"props": true, "dust": true, "streaks": true}
const SEED := 20261109

var _reads := 0
var _raise_at := -1
var _flag: Array = [false]


# Gentle rolling ground with one steep ridge, so slope tests pass and fail on both sides.
func _ground(x: float, z: float, lift: float) -> Vector3:
	_reads += 1
	if _raise_at >= 0 and _reads >= _raise_at:
		_flag[0] = true
	var ridge := 9.0 / (1.0 + pow((x - 30.0) / 2.0, 2.0))
	return Vector3(x, sin(x * 0.05) * 0.6 + cos(z * 0.04) * 0.5 + ridge + lift, z)


func _plan(stop: Array) -> Dictionary:
	_reads = 0
	return SetDressing.plan(MAP, [], _ground, SEED, FLAGS, stop)


func _initialize() -> void:
	var t := T.new("set_dressing_stop_test")
	_reads = 0
	var plain: Dictionary = SetDressing.plan(MAP, [], _ground, SEED, FLAGS)
	var full_reads := _reads
	t.check("the plain plan draws rock, dust and streaks", plain.has("rock") and plain.has("dust") and plain.has("streaks") and plain.has("clutter"),
		"keys %s, %d ground reads" % [plain.keys(), full_reads])
	var lowered := _plan([false])
	t.check("a lowered flag changes nothing", lowered == plain and _reads == full_reads, "%d reads against %d" % [_reads, full_reads])
	var early := _plan([true])
	t.check("a flag raised before the draw reads no ground", _reads == 0 and not early.has("rock"), "%d reads, keys %s" % [_reads, early.keys()])
	_flag = [false]
	_raise_at = full_reads / 4
	var cut := _plan(_flag)
	var after := _reads - _raise_at
	_raise_at = -1
	# One loop step reads the ground at most about 100 times (a rock's slope and its 24 flat probes).
	t.check("a flag raised part-way stops within one loop step", after <= 200 and _reads < full_reads / 2,
		"%d reads after the flag at %d, full plan %d" % [after, full_reads / 4, full_reads])
	t.check("a stopped plan is partial, so it is never dressed", not cut.has("streaks"), "keys %s" % [cut.keys()])
	quit(t.verdict())
