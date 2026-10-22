extends SceneTree

const Game := preload("res://src/game.gd")
const Harness := preload("res://tests/doubles/module_harness.gd")
const T := preload("res://tests/support/t.gd")

# The phase-minimum hold (PHASE_MIN_SECONDS in waking.gd and mind.gd times the dial <boss>.phase_min_by_phase, stub_boss.gd hold_active), on the
# Waking (world 2) and the Mind (world 3). Brindle's PHASE_MIN_SECONDS semantics: a chunk lost before its
# phase has lasted the minimum holds the phase, and the Warden takes no posture, until the minimum has
# passed. A zero multiplier holds nothing. Hits are the module harness's TARGET smash, one per HIT_EVERY frames.
#
# Evidence limit: TARGET calls, not ball contacts or a graded bot band. The "information-only grading"
# check is that a held fight still ends in a win and no boss telegraph comes earlier than without the hold.

const FIGHT_CAP := 60 * 240
# One hit every this many frames, so a fight without a hold lasts long enough to telegraph attacks.
const HIT_EVERY := 30
const BOSSES := {2: "waking", 3: "mind"}
const Waking := preload("res://src/boss/waking.gd")
const Mind := preload("res://src/boss/mind.gd")

var _t := T.new("boss_phase_hold_test")


func _initialize() -> void:
	_run()


func _run() -> void:
	for world in BOSSES:
		var boss: String = BOSSES[world]
		var hold: float = (Waking.PHASE_MIN_SECONDS if world == 2 else Mind.PHASE_MIN_SECONDS)[0]
		var key := boss + ".phase_min_by_phase"
		var runs := {}
		for name in ["default", "identity", "zero", "half", "ordinary", "monster"]:
			ChallengeDials.reset()
			match name:
				"identity": ChallengeDials.set_overrides({key: [1.0, 1.0, 1.0, 1.0]})
				"zero": ChallengeDials.set_overrides({key: [0.0, 0.0, 0.0, 0.0]})
				"half": ChallengeDials.set_overrides({key: [0.5, 0.5, 0.5, 0.5]})
			var threshold := NAN
			if name == "ordinary":
				threshold = INF
			elif name == "monster":
				threshold = -1.0
			runs[name] = await _fight(world, threshold)
		ChallengeDials.reset()
		_check(boss, hold, runs)
	ChallengeDials.reset()
	quit(_t.verdict())


func _check(boss: String, hold: float, runs: Dictionary) -> void:
	var base: Dictionary = runs["zero"]
	var held: Dictionary = runs["default"]
	_t.check("%s: the constant is %.0f s and the dial default is the identity" % [boss, hold], hold > 0.0
			and ChallengeDials.value(boss + ".phase_min_by_phase") == [1.0, 1.0, 1.0, 1.0], "hold %.1f" % hold)
	_t.check("%s zero multiplier: nothing held, fight won, chunks lost early" % [boss], base["won"] and base["held_frames"] == 0
			and base["losses"].size() >= 3 and base["losses"][1] < hold, "held %d, %s" % [base["held_frames"], str(base["losses"])])
	_t.check("%s default: fight won and a chunk lost early is held" % boss, held["won"] and held["held_frames"] > 0,
			"won %s, held frames %d" % [held["won"], held["held_frames"]])
	_t.eq("%s identity multiplier matches the constant" % boss, runs["identity"]["losses"], held["losses"])
	_t.check("%s half multiplier holds half as long" % boss, runs["half"]["losses"].size() >= 3
			and runs["half"]["losses"][1] >= hold * 0.5 - 0.1 and runs["half"]["losses"][1] < hold - 0.1, str(runs["half"]["losses"]))
	_t.check("%s held: no posture while held" % boss, held["posture_while_held"] == 0.0,
			"max posture while held %.2f" % held["posture_while_held"])
	_t.check("%s held: no chunk lost while held" % boss, held["lost_while_held"] == 0, "%d lost" % held["lost_while_held"])
	_t.check("%s held: phase does not advance while held" % boss, held["phase_moved_while_held"] == 0,
			"%d phase moves" % held["phase_moved_while_held"])
	var losses: Array = held["losses"]
	var ok := losses.size() >= 3
	for i in range(1, losses.size()):
		# Chunk i+1 may only be lost once the phase before it has lasted the minimum since it began.
		ok = ok and losses[i] >= hold * i - 0.1
	_t.check("%s held: chunk k lost no sooner than k phases of %.0f s" % [boss, hold], ok, str(losses))
	_t.check("%s held: fight ends later than without the hold" % boss, held["end"] > base["end"], "%.2f vs %.2f" % [held["end"], base["end"]])
	var later := true
	for i in mini(base["telegraphs"].size(), held["telegraphs"].size()):
		later = later and held["telegraphs"][i] >= base["telegraphs"][i] - 0.001
	_t.check("%s held: no telegraph comes sooner" % boss, later, "%s vs %s" % [str(held["telegraphs"]), str(base["telegraphs"])])
	# An ordinary build (threshold out of reach) is held; a monster build (heft above the threshold) is never
	# held and its posture lands at once.
	var ordinary: Dictionary = runs["ordinary"]
	var monster: Dictionary = runs["monster"]
	_t.check("%s ordinary fixture is held" % boss, ordinary["held_frames"] > 0 and ordinary["losses"][1] >= hold - 0.1,
			"held frames %d, losses %s" % [ordinary["held_frames"], str(ordinary["losses"])])
	_t.check("%s monster fixture is never held" % boss, monster["held_frames"] == 0 and monster["won"],
			"held frames %d, won %s" % [monster["held_frames"], monster["won"]])
	_t.check("%s monster fixture's posture lands at once" % boss, monster["losses"].size() >= 3 and monster["losses"][1] < hold,
			str(monster["losses"]))
	_t.check("%s monster fixture breaks faster than ordinary" % boss, monster["end"] < ordinary["end"],
			"%.2f vs %.2f" % [monster["end"], ordinary["end"]])


func _fight(world: int, threshold := NAN) -> Dictionary:
	var game = Game.new()
	game.test_mode = true
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	Harness.boot(game)
	var seen = Harness.counter(game)
	Harness.enter_world(game, world)
	var mod = Harness.module(game, world)
	if not is_nan(threshold):
		mod.warden.spec["monster_heft"] = threshold
	var out := {"won": false, "losses": [], "telegraphs": [], "held_frames": 0, "posture_while_held": 0.0,
			"lost_while_held": 0, "phase_moved_while_held": 0, "end": 0.0}
	game.ctx.events.boss_attack_telegraphed.connect(func(_id: String, _s: float): out["telegraphs"].append(mod.clock))
	var chunks: int = mod.warden.chunks_left()
	var phase_before: int = mod.phase if "phase" in mod else 0
	var frames := 0
	while Harness._alive(Harness.target(mod)) and frames < FIGHT_CAP:
		var held_before: bool = mod.hold_active()
		if frames % HIT_EVERY == 0:
			Harness.hit(mod)
		frames += 1
		await physics_frame
		if not mod.active() or not is_instance_valid(mod.warden):
			break
		var now: int = mod.warden.chunks_left()
		if now < chunks:
			out["losses"].append(mod.clock)
			if held_before:
				out["lost_while_held"] += 1
		chunks = now
		if mod.hold_active():
			out["held_frames"] += 1
			out["posture_while_held"] = maxf(out["posture_while_held"], mod.warden.posture())
			if "phase" in mod and mod.phase != phase_before:
				out["phase_moved_while_held"] += 1
		if "phase" in mod:
			phase_before = mod.phase
	out["won"] = seen.defeated == 1
	out["end"] = mod.clock
	game.free()
	await physics_frame
	return out
