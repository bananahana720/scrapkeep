extends RefCounted

# Read-only state synthesis for the Jev player (plan section 2, "Ball-lab state is
# synthesised read-only"). It turns a running lab into the protocol's `jev` block,
# pre-quantised to the corpus grid in tools/jev-player/protocol/PROTOCOL.md, and a
# `sim` block. It only reads gameplay nodes. The single thing it attaches is a second
# listener on the player's `shockwave` signal, which is how knocks are seen. Nothing
# here reads the wall clock or a random number: `tick` is counted by the owner.
#
# Usage: `var view := JevState.new(lab, run)`, `view.attach()`, then `view.advance()`
# once per physics tick and `view.snapshot()` whenever a state is due. `run` is an
# optional `Scenarios.Run`; it supplies the objective and is fed every tick.

const Field := preload("res://src/field.gd")
const SpeedTier := preload("res://src/speed_tier.gd")
const Tuning := preload("res://src/tuning.gd")
const JevAgent := preload("res://src/jev/jev_agent.gd")
const Telemetry := preload("res://src/jev/telemetry.gd")

const STAGE_NAME := "ball-lab"
# The sketch has no threat escalation, so the stage stays at the lowest corpus tier.
const STAGE_TIER := 1
const THREAT_KIND := "chaser"
const THREAT_RANGE := 60.0
const MAX_THREATS := 3
# player_ball.gd emits 0.6 for a descending rebound and 1.0 for a fast-tier hit.
const STOMP_STRENGTH := 0.6
const RAM_STRENGTH := 1.0
# How far above a dummy the ball must be for the dummy to count as `below`.
const BELOW_MARGIN := 2.0
# Offer ranges. Provisional: JL-21 calibrated only the kicker's lip speed below.
const STOMP_RANGE := 30.0
const RAM_RANGE := 40.0
const EVADE_RANGE := 10.0
const KICKER_RANGE := 60.0
# The slowest speed at the steep kicker's lip that lands on the bench with no input
# and no air jump, in both physics modes: kicker-gap@v swept 14-28 m/s (JL-21,
# artifacts/local/tasks/JL-21/runs/lip-probe*). Kinematic cleared from 16.6 m/s and
# fell short at 16.3; rigid cleared from 17.2 and fell short at 16.9.
const KICKER_LIP_SPEED := 17.2

var lab
var run
var tick := 0
var tick_hz := 90
# Every shockwave seen since attach: {tick, strength, kind, enemy}. `enemy` is the
# index into lab.enemies of the dummy the wave was emitted on, or -1. These are raw
# waves; knock_count() counts contact stretches.
var knocks: Array = []

var _attached := false
var _stretches: Array = []
var _collapsed_waves := 0


func _init(lab_ref, run_ref = null) -> void:
	lab = lab_ref
	run = run_ref
	tick_hz = Engine.physics_ticks_per_second


func attach() -> void:
	if _attached:
		return
	lab.player.shockwave.connect(_on_shockwave)
	_attached = true


func detach() -> void:
	if not _attached:
		return
	if lab.player.shockwave.is_connected(_on_shockwave):
		lab.player.shockwave.disconnect(_on_shockwave)
	_attached = false


# The owner calls this once per physics tick. Knocks are stamped with the tick in
# force when their signal fires.
func advance() -> void:
	tick += 1
	if run != null:
		run.observe(self)


func _on_shockwave(at: Vector3, strength: float) -> void:
	var kind := "other"
	if is_equal_approx(strength, STOMP_STRENGTH):
		kind = "stomp"
	elif is_equal_approx(strength, RAM_STRENGTH):
		kind = "ram"
	knocks.append({"tick": tick, "strength": strength, "kind": kind, "enemy": _enemy_at(at)})


# The wave is emitted at the dummy's own position, so the nearest dummy is the one hit.
func _enemy_at(at: Vector3) -> int:
	var best := -1
	var best_d := INF
	for i in lab.enemies.size():
		var d: float = lab.enemies[i].global_position.distance_to(at)
		if d < best_d:
			best_d = d
			best = i
	return best if best_d < 0.5 else -1


# --- facts read from the lab ------------------------------------------------------

func position() -> Vector3:
	return lab.player.ball_position()


func velocity() -> Vector3:
	return lab.player.state.velocity


func grounded() -> bool:
	return lab.player.state.grounded


func enemy_positions() -> Array:
	var out := []
	for enemy in lab.enemies:
		out.append(enemy.global_position)
	return out


func time_s() -> int:
	return int(floor(float(tick) / float(tick_hz)))


# Knocks of `kind` as contact stretches, the count events.ndjson and the run summary
# report (EV-0509; JL-13 review, N5).
func knock_count(kind: String) -> int:
	return _contact_stretches().filter(func(knock): return knock["kind"] == kind).size()


# The dummies knocked since attach, one trial's worth in jev_run.gd: the enemy index
# of every contact stretch, in the order first knocked.
func knocked_enemies() -> Array:
	var out := []
	for stretch in _contact_stretches():
		if stretch["enemy"] >= 0 and not out.has(stretch["enemy"]):
			out.append(stretch["enemy"])
	return out


func _contact_stretches() -> Array:
	if _collapsed_waves != knocks.size():
		_stretches = collapse(knocks)
		_collapsed_waves = knocks.size()
	return _stretches


# Telemetry.drain_knocks's rule: waves on one dummy are one stretch while each follows
# the previous wave on that dummy within KNOCK_GAP_TICKS. jev_agent_test.gd checks
# that the two agree.
static func collapse(waves: Array) -> Array:
	var out := []
	var last := {}
	var open := {}
	for wave in waves:
		var enemy: int = wave["enemy"]
		var tick: int = wave["tick"]
		var joins: bool = last.has(enemy) and tick - int(last[enemy]) <= Telemetry.KNOCK_GAP_TICKS
		last[enemy] = tick
		if joins:
			out[open[enemy]]["waves"] += 1
			continue
		open[enemy] = out.size()
		out.append({"tick": tick, "enemy": enemy, "kind": wave["kind"], "waves": 1})
	return out


# --- the protocol blocks -----------------------------------------------------------

func snapshot() -> Dictionary:
	return {"jev": jev_block(), "sim": sim_block()}


func jev_block() -> Dictionary:
	var state := {
		"self": _self_block(),
		"stage": {"name": STAGE_NAME, "time_s": time_s(), "tier": STAGE_TIER},
		"threats": threats(),
		"objective": _objective_block(),
	}
	return {"state": state, "options": options(state)}


# Godot's own view of the moment: full-precision numbers, never shown to Jev.
func sim_block() -> Dictionary:
	var at := position()
	var v := velocity()
	return {
		"pos": [at.x, at.y, at.z],
		"vel": [v.x, v.y, v.z],
		"tick": tick,
		"mode": lab.player.mode_name(),
		"grounded": grounded(),
		"air_actions": int(lab.player.state.air_actions),
		"tier": SpeedTier.label(lab.player.state.tier),
		"knocks": {"stomp": knock_count("stomp"), "ram": knock_count("ram"), "other": knock_count("other")},
		# Which dummies the threats are, and which are knocked: unhashed, for tests.
		"threat_ids": threat_indices(),
		"knocked": knocked_enemies(),
	}


func _self_block() -> Dictionary:
	var state = lab.player.state
	return {
		"speed_ms": tenth(velocity().length()),
		"speed_tier": SpeedTier.label(state.tier),
		"grounded": bool(state.grounded),
		"air_jump_available": state.air_actions > 0,
		"location": location(position()),
	}


# The nearest three dummies within 60 m, nearest first; ties keep lab order. With a
# Run attached, a dummy knocked this trial (a contact stretch on it, knock_count()'s
# rule) is left out for every arm: in the game a hit enemy is gone, while enemy.gd's
# dummy gets up and chases, which kept the scripted ladder stomping it (JL-21 review,
# F1). Without a Run nothing is left out.
func threats() -> Array:
	var at := position()
	var v := velocity()
	var out := []
	for i in threat_indices():
		var enemy = lab.enemies[i]
		var offset: Vector3 = enemy.global_position - at
		var relative: Vector3 = enemy.velocity - v
		out.append({
			"kind": THREAT_KIND,
			"distance_m": whole(enemy.global_position.distance_to(at)),
			# The gap is shrinking when the relative velocity points back along it.
			"closing": offset.dot(relative) < 0.0,
			"below": at.y - enemy.global_position.y > BELOW_MARGIN,
		})
	return out


# Lab indices of the dummies threats() reports, in its order.
func threat_indices() -> Array:
	var at := position()
	var knocked := knocked_enemies() if run != null else []
	var found := []
	for i in lab.enemies.size():
		if knocked.has(i):
			continue
		var d: float = lab.enemies[i].global_position.distance_to(at)
		if d <= THREAT_RANGE:
			found.append({"index": i, "d": d})
	found.sort_custom(func(a, b): return a["d"] < b["d"] or (a["d"] == b["d"] and a["index"] < b["index"]))
	return found.slice(0, MAX_THREATS).map(func(entry): return entry["index"])


func objective() -> Dictionary:
	if run != null:
		return run.objective(self)
	return {"kind": "waypoint", "point": Field.drop_point(Field.PAD_CENTER.x, Field.PAD_CENTER.y, Tuning.RADIUS)}


func _objective_block() -> Dictionary:
	var goal := objective()
	return {"kind": goal["kind"], "distance_m": whole(position().distance_to(goal["point"]))}


# Every intent ball-lab can execute: push, kicker, stomp, ram and evade (no HP, so no
# retreat_regen). An option is offered when its target is in range; decide.mjs's
# precondition gate then removes what the ball cannot do right now, so stomp and ram
# are offered here even when the air jump is spent or the tier is too low.
func options(state: Dictionary) -> Array:
	var out := [{"id": "push_objective", "why": "Roll the fastest line to the %s %d m away" % [
		state["objective"]["kind"].replace("_", " "), state["objective"]["distance_m"]]}]
	var at := position()
	var lip := kicker_lip()
	var to_lip := Vector2(at.x, at.z).distance_to(Vector2(lip.x, lip.z))
	if to_lip <= KICKER_RANGE and location(at) != "bench":
		out.append({
			"id": "hit_kicker",
			"why": "Take the steep kicker %d m away across the gap onto the bench" % whole(to_lip),
			"requires_speed_ms": KICKER_LIP_SPEED,
		})
	var threats_seen: Array = state["threats"]
	if not threats_seen.is_empty():
		var nearest: Dictionary = threats_seen[0]
		if nearest["distance_m"] <= STOMP_RANGE:
			out.append({"id": "stomp_target", "why": "Jump and land on the chaser %d m away" % nearest["distance_m"]})
		if nearest["distance_m"] <= RAM_RANGE:
			out.append({"id": "ram_target", "why": "Hit the chaser %d m away at fast-tier speed" % nearest["distance_m"]})
		for threat in threats_seen:
			if threat["closing"] and threat["distance_m"] <= EVADE_RANGE:
				out.append({"id": "evade_hazard", "why": "Break off from the chaser closing %d m away" % threat["distance_m"]})
				break
	return out


# The steep kicker's lip, the top far edge it launches from: jev_agent.gd's frame,
# which jev_agent_test.gd checks against the built box (JL-10 review, N3).
static func kicker_lip() -> Vector3:
	return JevAgent.kicker_frame()["lip"]


static func kicker_half_width() -> float:
	return JevAgent.KICKER_SIZE.x * 0.5


# A coarse place name from field.gd's layout, for Jev's `location`.
static func location(at: Vector3) -> String:
	var flat := Vector2(at.x, at.z)
	var bench := flat - Field.BENCH_CENTER
	if absf(bench.x) <= Field.BENCH_HALF.x and absf(bench.y) <= Field.BENCH_HALF.y and at.y >= Field.BENCH_TOP:
		return "bench"
	if absf(at.x - Field.RUN_X) <= 26.0 and at.z <= Field.PIPE_END_Z:
		return "downhill run" if at.z < Field.RUN_BOT_Z else "halfpipe"
	if flat.distance_to(Field.PAD_CENTER) <= 26.0:
		return "pad"
	var bank := flat.distance_to(Field.BANK_CENTER)
	if bank >= 20.0 and bank <= 62.0:
		return "banked turn"
	return "field"


# Corpus quantisation: tenths for speeds, whole numbers for distances. Rounding by
# division keeps the double the one JSON's shortest form parses back to.
static func tenth(value: float) -> float:
	return maxf(0.0, round(value * 10.0) / 10.0)


static func whole(value: float) -> int:
	return int(round(value))
