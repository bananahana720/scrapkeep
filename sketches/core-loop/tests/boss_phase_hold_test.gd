# smoke: bots timeout=900s (five simulated boss fights per boss, three of them held 60 s or more: 5 min wall on a quiet box, 390 s alone on a cloud box on 2026-10-22, so the 360 s solo ceiling no longer fits; bot tier, as alpha_posture_bands_test)
extends SceneTree

const Game := preload("res://src/game.gd")
const Harness := preload("res://tests/doubles/module_harness.gd")
const T := preload("res://tests/support/t.gd")

# The phase-minimum hold (PHASE_MIN_SECONDS in waking.gd and mind.gd times the dial <boss>.phase_min_by_phase, stub_boss.gd hold_active), on the
# Waking (world 2) and the Mind (world 3). Brindle's PHASE_MIN_SECONDS semantics: a chunk lost before its
# phase has lasted the minimum holds the phase, and the Warden's bar fills only to its cap (hits still land,
# none staggers), until the minimum has passed; then the next hit staggers. A zero multiplier holds nothing. Hits are the module harness's TARGET smash, one per HIT_EVERY frames.
#
# Evidence limit: TARGET calls, not ball contacts or a graded bot band. The "information-only grading"
# check is that a held fight still ends in a win and no boss telegraph comes earlier than without the hold.

const FIGHT_CAP := 60 * 240
# One hit every this many frames, so a fight without a hold lasts long enough to telegraph attacks.
const HIT_EVERY := 30
# The planted control stops once it has sat this many frames in a hold, with no hit to fill the bar.
const IDLE_HELD_FRAMES := 300
const BOSSES := {2: "waking", 3: "mind"}
const Waking := preload("res://src/boss/waking.gd")
const Mind := preload("res://src/boss/mind.gd")
const Warden := preload("res://src/combat/warden.gd")

var _t := T.new("boss_phase_hold_test")


func _initialize() -> void:
	_run()


func _run() -> void:
	for world in BOSSES:
		var boss: String = BOSSES[world]
		var hold: float = (Waking.PHASE_MIN_SECONDS if world == 2 else Mind.PHASE_MIN_SECONDS)[0]
		var key := boss + ".phase_min_by_phase"
		var runs := {}
		for name in ["default", "zero", "monster", "rising", "idle"]:
			ChallengeDials.reset()
			# Weak points off whatever the Waking ships on: a TARGET smash is no hatch contact, so the rule only
			# shifts chunk times; the hold with weak points on is boss_weak_points_test's.
			var dials := {boss + ".weak_points": 0.0}
			match name:
				"zero": dials[key] = [0.0, 0.0, 0.0, 0.0]
			ChallengeDials.set_overrides(dials)
			var threshold := NAN
			if name in ["default", "rising", "idle"]:
				threshold = INF
			elif name == "monster":
				threshold = -1.0
			runs[name] = await _fight(world, threshold, name == "rising", name == "idle")
		ChallengeDials.reset()
		_check(boss, hold, runs)
	ChallengeDials.reset()
	quit(_t.verdict())


# Compares later chunk-loss clocks within tol seconds (pair with exact loss_frames equality).
# Wave 45 P2 (0b3624907) wired posture_changed into Juice hit-stops: breaking chunk 1 earlier in
# rising adds those slowed 0.05/90 deltas to stub_boss.clock at a different magnitude (~0.67 s vs
# ~2.00 s), producing a 1-ULP IEEE-754 sum-order mismatch even on identical break frames, and
# Juice's wall-clock STOP_GAP_MS gate (SimClock.ticks=false, so game.gd keeps tick-counted stops)
# can admit or skip a 3-tick shatter stop (0.032 s) under load without moving any break frame.
func _losses_close(a: Array, b: Array, tol: float) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if absf(float(a[i]) - float(b[i])) > tol:
			return false
	return true


func _check(boss: String, hold: float, runs: Dictionary) -> void:
	var base: Dictionary = runs["zero"]
	var held: Dictionary = runs["default"]
	_t.check("%s: the constant is %.0f s and the dial default is the identity" % [boss, hold], hold > 0.0
			and ChallengeDials.value(boss + ".phase_min_by_phase") == [1.0, 1.0, 1.0, 1.0], "hold %.1f" % hold)
	_t.check("%s zero multiplier: nothing held, fight won, chunks lost early" % [boss], base["won"] and base["held_frames"] == 0
			and base["losses"].size() >= 3 and base["losses"][1] < hold, "held %d, %s" % [base["held_frames"], str(base["losses"])])
	_t.check("%s default: fight won and a chunk lost early is held" % boss, held["won"] and held["held_frames"] > 0,
			"won %s, held frames %d" % [held["won"], held["held_frames"]])
	_t.check("%s held: posture gains up to the cap and no stagger starts" % boss, held["posture_while_held"] > 0.0
			and held["posture_while_held"] <= Warden.HOLD_CAP and held["capped_frames"] > 0 and held["staggered_while_held"] == 0,
			"max posture while held %.2f, capped frames %d, staggered frames %d" % [held["posture_while_held"], held["capped_frames"], held["staggered_while_held"]])
	_t.check("%s held: the bar reads 99, full" % boss, held["signature_at_cap"] == 99, "signature %s" % str(held["signature_at_cap"]))
	_t.check("%s held: the first hit after the hold staggers, none before" % boss, held["release_checked"] and held["release_staggers"]
			and held["auto_stagger"] == 0, "checked %s, staggers %s, automatic %d" % [held["release_checked"], held["release_staggers"], held["auto_stagger"]])
	_t.check("%s held: hold seconds recorded, binding seconds within them" % boss, held["hold_s"] > 0.0 and held["hold_bound_s"] > 0.0
			and held["hold_bound_s"] <= held["hold_s"] + 0.001, "hold %.2f, bound %.2f" % [held["hold_s"], held["hold_bound_s"]])
	var idle: Dictionary = runs["idle"]
	_t.check("%s planted control: held with the bar never capped, binding seconds are 0" % boss, idle["held_frames"] > 0
			and idle["capped_frames"] == 0 and idle["hold_s"] > 0.0 and idle["hold_bound_s"] == 0.0,
			"held frames %d, capped %d, hold %.2f, bound %.2f" % [idle["held_frames"], idle["capped_frames"], idle["hold_s"], idle["hold_bound_s"]])
	var words: String = String(held["capped_text"]).to_lower()
	_t.check("%s capped objective says the bar is full, never immune, nope or no effect" % boss, words.contains("bar is full")
			and not words.contains("immune") and not words.contains("nope") and not words.contains("no effect"), String(held["capped_text"]))
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
	var ordinary: Dictionary = held
	var monster: Dictionary = runs["monster"]
	_t.check("%s ordinary fixture is held" % boss, ordinary["held_frames"] > 0 and ordinary["losses"][1] >= hold - 0.1,
			"held frames %d, losses %s" % [ordinary["held_frames"], str(ordinary["losses"])])
	var rising: Dictionary = runs["rising"]
	_t.check("%s heft rising over the threshold mid-fight stays held" % boss, rising["held_frames"] > 0 and rising["losses"][1] >= hold - 0.1
			and rising["loss_frames"].slice(1) == ordinary["loss_frames"].slice(1)
			and _losses_close(rising["losses"].slice(1), ordinary["losses"].slice(1), 0.1),
			"held frames %d, frames %s vs %s, %s vs %s" % [rising["held_frames"], str(rising["loss_frames"]), str(ordinary["loss_frames"]), str(rising["losses"]), str(ordinary["losses"])])
	# (The first chunk can fall sooner: the live monster lift on posture gain is #222's and unchanged.)
	_t.check("%s monster fixture is never held" % boss, monster["held_frames"] == 0 and monster["won"],
			"held frames %d, won %s" % [monster["held_frames"], monster["won"]])
	_t.check("%s monster fixture: hold and binding seconds are 0" % boss, monster["hold_s"] == 0.0 and monster["hold_bound_s"] == 0.0,
			"hold %.2f, bound %.2f" % [monster["hold_s"], monster["hold_bound_s"]])
	_t.check("%s monster fixture's posture lands at once" % boss, monster["losses"].size() >= 3 and monster["losses"][1] < hold,
			str(monster["losses"]))
	_t.check("%s monster fixture breaks faster than ordinary" % boss, monster["end"] < ordinary["end"],
			"%.2f vs %.2f" % [monster["end"], ordinary["end"]])


func _fight(world: int, threshold := NAN, rising := false, idle := false) -> Dictionary:
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
		mod.latch_monster()
	var out := {"won": false, "losses": [], "loss_frames": [], "telegraphs": [], "held_frames": 0, "posture_while_held": 0.0,
			"lost_while_held": 0, "phase_moved_while_held": 0, "end": 0.0, "capped_frames": 0, "staggered_while_held": 0,
			"signature_at_cap": -1, "release_checked": false, "release_staggers": false, "auto_stagger": 0, "hold_s": 0.0,
			"hold_bound_s": 0.0, "capped_text": ""}
	# Armed when a hold ends with the bar at the cap; the next hit must stagger it.
	var release_armed := false
	var was_held := false
	var was_capped := false
	game.ctx.events.boss_attack_telegraphed.connect(func(_id: String, _s: float): out["telegraphs"].append(mod.clock))
	var chunks: int = mod.warden.chunks_left()
	var phase_before: int = mod.phase if "phase" in mod else 0
	var frames := 0
	while Harness._alive(Harness.target(mod)) and frames < FIGHT_CAP:
		if rising and frames == 60:
			# Heft climbs over the threshold a second into the fight: the live predicate turns true, the latch does not.
			mod.warden.spec["monster_heft"] = -1.0
		var held_before: bool = mod.hold_active()
		var hit_now := frames % HIT_EVERY == 0 and not (idle and held_before)
		if hit_now:
			Harness.hit(mod)
			if release_armed and not held_before:
				out["release_checked"] = true
				out["release_staggers"] = mod.warden.staggered()
				release_armed = false
		frames += 1
		await physics_frame
		if not mod.active() or not is_instance_valid(mod.warden):
			break
		var now: int = mod.warden.chunks_left()
		if now < chunks:
			out["losses"].append(mod.clock)
			out["loss_frames"].append(frames)
			if held_before:
				out["lost_while_held"] += 1
		chunks = now
		var held_now: bool = mod.hold_active()
		if was_held and not held_now and was_capped and not out["release_checked"]:
			release_armed = true
		if not hit_now and mod.warden.staggered() and held_before:
			out["auto_stagger"] += 1
		if idle and out["held_frames"] >= IDLE_HELD_FRAMES:
			break
		if held_now:
			out["held_frames"] += 1
			out["posture_while_held"] = maxf(out["posture_while_held"], mod.warden.posture())
			if mod.warden.staggered():
				out["staggered_while_held"] += 1
			was_capped = mod.hold_capped()
			if was_capped:
				out["capped_frames"] += 1
				out["signature_at_cap"] = mod.warden._posture_signature()[0]
				if out["capped_text"] == "":
					out["capped_text"] = mod.objective_text()
			if "phase" in mod and mod.phase != phase_before:
				out["phase_moved_while_held"] += 1
		was_held = held_now
		if "phase" in mod:
			phase_before = mod.phase
	out["won"] = seen.defeated == 1
	out["end"] = mod.clock
	out["hold_s"] = mod.hold_s
	out["hold_bound_s"] = mod.hold_bound_s
	game.free()
	await physics_frame
	return out
