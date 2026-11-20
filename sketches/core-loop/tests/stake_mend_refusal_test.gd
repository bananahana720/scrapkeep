extends SceneTree

const HullMark := preload("res://src/world/hull_mark.gd")
const RunState := preload("res://src/core/run_state.gd")
const Ward := preload("res://src/world/stake_devices.gd")

# The mend ward refuses, and charges nothing, when a heal would restore no health and lift
# no mark; a marked hull and a hurt hull still mend.

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _run() -> void:
	var tier := 1
	# Full, unmarked hull: refused, nothing changes.
	var run := RunState.new()
	run.bonus_cores = 3
	var o := Ward.make_offer("healing_ward", tier, "cores", run, RandomNumberGenerator.new())
	var open := Ward.can_take(o, run)
	var r := Ward.take(o, run, Vector3.ZERO)
	_check("full hull refused", not open and not bool(r.get("ok", true)) and int(r.get("charged", -1)) == 0
		and run.bonus_cores == 3 and run.hp == run.max_hp and HullMark.held(run) == 0.0,
		"can_take %s, result %s, cores %d, hp %.1f/%.1f" % [open, r, run.bonus_cores, run.hp, run.max_hp])

	# Marked hull sitting at its lowered ceiling: allowed, ends full and unmarked, charged the cost.
	run = RunState.new()
	HullMark.stake(run, 30.0)
	run.hp = run.max_hp
	run.bonus_cores = 3
	var marked_max := run.max_hp
	o = Ward.make_offer("healing_ward", tier, "cores", run, RandomNumberGenerator.new())
	open = Ward.can_take(o, run)
	r = Ward.take(o, run, Vector3.ZERO)
	_check("marked hull mends", open and bool(r.get("ok", false)) and int(r.get("charged", -1)) == int(o["cost"])
		and run.bonus_cores == 3 - int(o["cost"]) and HullMark.held(run) == 0.0
		and run.max_hp > marked_max and is_equal_approx(run.hp, run.max_hp),
		"can_take %s, result %s, cores %d, hp %.1f/%.1f, mark %.1f" % [open, r, run.bonus_cores, run.hp, run.max_hp, HullMark.held(run)])

	# Hull below its ceiling: allowed as before.
	run = RunState.new()
	run.hp = run.max_hp - 40.0
	run.bonus_cores = 3
	var hurt := run.hp
	o = Ward.make_offer("healing_ward", tier, "cores", run, RandomNumberGenerator.new())
	open = Ward.can_take(o, run)
	r = Ward.take(o, run, Vector3.ZERO)
	_check("hurt hull mends", open and bool(r.get("ok", false)) and run.hp > hurt and run.bonus_cores == 3 - int(o["cost"]),
		"can_take %s, result %s, cores %d, hp %.1f -> %.1f" % [open, r, run.bonus_cores, hurt, run.hp])

	print("stake_mend_refusal_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
