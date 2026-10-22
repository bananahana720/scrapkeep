extends SceneTree

const Game := preload("res://src/game.gd")
const Harness := preload("res://tests/doubles/module_harness.gd")
const T := preload("res://tests/support/t.gd")

# The phase-minimum hold (challenge dial <boss>.phase_min_by_phase, stub_boss.gd hold_active), on the
# Waking (world 2) and the Mind (world 3). Brindle's PHASE_MIN_SECONDS semantics: a chunk lost before its
# phase has lasted the minimum holds the phase, and the Warden takes no posture, until the minimum has
# passed. Default zeros hold nothing. Hits are the module harness's TARGET smash, one per HIT_EVERY frames.
#
# Evidence limit: TARGET calls, not ball contacts or a graded bot band. The "information-only grading"
# check is that a held fight still ends in a win and no boss telegraph comes earlier than without the hold.

const HOLD := 4.0
const FIGHT_CAP := 60 * 120
# One hit every this many frames, so the default fight lasts long enough to telegraph attacks.
const HIT_EVERY := 30
const BOSSES := {2: "waking", 3: "mind"}

var _t := T.new("boss_phase_hold_test")


func _initialize() -> void:
	_run()


func _run() -> void:
	for world in BOSSES:
		var boss: String = BOSSES[world]
		ChallengeDials.reset()
		var base: Dictionary = await _fight(world, null)
		ChallengeDials.reset()
		var held: Dictionary = await _fight(world, [HOLD, HOLD, HOLD, HOLD], boss)
		ChallengeDials.reset()
		_check(boss, base, held)
		# The same dial: an ordinary build (threshold out of reach) is held, a monster build (heft above
		# the threshold) is never held and its posture lands at once.
		ChallengeDials.reset()
		var ordinary: Dictionary = await _fight(world, [HOLD, HOLD, HOLD, HOLD], boss, INF)
		ChallengeDials.reset()
		var monster: Dictionary = await _fight(world, [HOLD, HOLD, HOLD, HOLD], boss, -1.0)
		ChallengeDials.reset()
		_t.check("%s ordinary fixture at the dial is held" % boss, ordinary["held_frames"] > 0 and ordinary["losses"][1] >= HOLD - 0.1,
				"held frames %d, losses %s" % [ordinary["held_frames"], str(ordinary["losses"])])
		_t.check("%s monster fixture at the dial is never held" % boss, monster["held_frames"] == 0 and monster["won"],
				"held frames %d, won %s" % [monster["held_frames"], monster["won"]])
		_t.check("%s monster fixture's posture lands at once" % boss, monster["losses"].size() >= 3 and monster["losses"][1] < HOLD,
				str(monster["losses"]))
		_t.check("%s monster fixture breaks faster than ordinary" % boss, monster["end"] < ordinary["end"],
				"%.2f vs %.2f" % [monster["end"], ordinary["end"]])
	ChallengeDials.reset()
	quit(_t.verdict())


func _check(boss: String, base: Dictionary, held: Dictionary) -> void:
	_t.check("%s default: three chunks lost, fight won" % boss, base["won"] and base["held_frames"] == 0,
			"won %s, held frames %d" % [base["won"], base["held_frames"]])
	_t.check("%s default: no hold shown, chunks lost before %.1f s" % [boss, HOLD],
			base["losses"].size() >= 3 and base["losses"][1] < HOLD, str(base["losses"]))
	_t.check("%s held: fight still won" % boss, held["won"], "won %s" % held["won"])
	_t.check("%s held: a chunk lost early is held" % boss, held["held_frames"] > 0, "held frames %d" % held["held_frames"])
	_t.check("%s held: no posture while held" % boss, held["posture_while_held"] == 0.0,
			"max posture while held %.2f" % held["posture_while_held"])
	_t.check("%s held: no chunk lost while held" % boss, held["lost_while_held"] == 0, "%d lost" % held["lost_while_held"])
	_t.check("%s held: phase does not advance while held" % boss, held["phase_moved_while_held"] == 0,
			"%d phase moves" % held["phase_moved_while_held"])
	var losses: Array = held["losses"]
	var ok := losses.size() >= 3
	for i in range(1, losses.size()):
		# Chunk i+1 may only be lost once the phase before it has lasted HOLD since it began.
		ok = ok and losses[i] >= HOLD * i - 0.1
	_t.check("%s held: chunk k lost no sooner than k phases of %.0f s" % [boss, HOLD], ok, str(losses))
	_t.check("%s held: fight ends later than default" % boss, held["end"] > base["end"], "%.2f vs %.2f" % [held["end"], base["end"]])
	var later := true
	for i in mini(base["telegraphs"].size(), held["telegraphs"].size()):
		later = later and held["telegraphs"][i] >= base["telegraphs"][i] - 0.001
	_t.check("%s held: no telegraph comes sooner" % boss, later, "%s vs %s" % [str(held["telegraphs"]), str(base["telegraphs"])])


func _fight(world: int, mins, boss := "", threshold := NAN) -> Dictionary:
	var game = Game.new()
	game.test_mode = true
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	Harness.boot(game)
	if mins != null:
		ChallengeDials.set_overrides({boss + ".phase_min_by_phase": mins})
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
