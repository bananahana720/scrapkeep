extends SceneTree

const RunState := preload("res://src/core/run_state.gd")
const T := preload("res://tests/support/t.gd")

class ClockRun:
	extends RunState
	var clock := 1000.0

	func _unix_time() -> float:
		return clock


func _initialize() -> void:
	var t := T.new("bot_run_seed_test")
	var a := _begin(42, 1000.0)
	var b := _begin(42, 9000.0)
	t.eq("seed override fixes the run identity", a.run_id, "bot-42")
	t.eq("different clocks retain the run identity", b.run_id, a.run_id)
	t.eq("different clocks retain the run seed", b.run_seed, a.run_seed)
	t.eq("run seed is derived from the overridden identity", a.run_seed, hash("bot-42"))
	var c := _begin(43, 1000.0)
	t.check("different bot seeds give different identities and luck", c.run_id != a.run_id and c.run_seed != a.run_seed)
	var normal := _begin(null, 1000.0)
	var later := _begin(null, 9000.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 123
	var suffix := rng.randi() % 1000000
	t.eq("unset override preserves clock and private RNG identity", normal.run_id, "%d-%06d" % [1000, suffix])
	t.eq("unset override reads the current clock", later.run_id, "%d-%06d" % [9000, suffix])
	t.eq("normal run seed still hashes the clock identity", normal.run_seed, hash(normal.run_id))
	var zero := _begin(0, 9000.0)
	t.eq("zero is a valid override", zero.run_id, "bot-0")
	quit(t.verdict())


func _begin(override_seed, clock: float) -> ClockRun:
	var run := ClockRun.new(null, 123)
	run.clock = clock
	if "run_seed_override" in run:
		run.set("run_seed_override", override_seed)
	run.begin(Resource.new())
	return run
