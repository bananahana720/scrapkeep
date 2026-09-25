extends RefCounted

# Read-only state synthesis for the Jev player on Spillway Drop (JL-27; ball-lab's
# jev_state.gd is the reference). It turns a running stage into the protocol's `jev`
# block, pre-quantised to the corpus grid in tools/jev-player/protocol/PROTOCOL.md and
# worded like the corpus's spillway-drop cases, plus a `sim` block. It only reads
# gameplay nodes. The single thing it attaches is a second listener on the player's
# `enemy_struck` signal, which is how knocks and their enemy are seen. Nothing here
# reads the wall clock or a random number: `tick` is counted by the owner.
#
# Stage threat rule 2 (coordinator ruling, EV-0550; JL-27-A2): an enemy leaves the
# threats and the targets only when the game has taken it out of play, which in
# Spillway is death (take_damage frees the node). A knocked chaser survives and keeps
# hitting, so it stays; the same holds for every arm. The A1 rule (JL-21 review, F1)
# dropped any enemy struck this trial. `knocked` still records every struck enemy,
# for the knock counts and the diagnostics in `sim`.
#
# Usage: `var view := JevState.new(stage, run)`, `view.attach()`, then `view.advance()`
# once per physics tick and `view.snapshot()` whenever a state is due.

const Terrain := preload("res://src/terrain.gd")
const SpeedTier := preload("res://src/speed_tier.gd")
const FloodCycle := preload("res://src/flood_cycle.gd")
const Flood := preload("res://src/flood.gd")
const Lobber := preload("res://src/lobber.gd")
const Projectile := preload("res://src/projectile.gd")
const Geo := preload("res://src/jev/geo.gd")

const STAGE_NAME := "spillway-drop"
# The instrument epoch the scenario line and every A2 record carry.
const THREAT_RULE := "stage-threat-rule 2"
const THREAT_RANGE := 60.0
const MAX_THREATS := 3
const STOMP_STRENGTH := 0.6
const RAM_STRENGTH := 1.0
const BELOW_MARGIN := 2.0
# Offer ranges. Provisional, as in ball-lab; nothing here is calibrated.
const STOMP_RANGE := 30.0
const RAM_RANGE := 40.0
const EVADE_RANGE := 10.0
const CHUTE_RANGE := 90.0
const SCRAP_RANGE := 30.0
# retreat_regen is offered at or below this share of max HP with an enemy in range.
const RETREAT_HP := 0.75
# The flood is listed from this long before the water starts to rise until it drains.
const FLOOD_WINDOW_S := 15.0
const FLOOD_EFFECT := "heavy drag and a current toward the basin middle"
# A shell whose landing point falls this close to the ball's position is aimed at it.
const SHELL_REACH := Projectile.HIT_RADIUS + 1.5

var stage
var run
var tick := 0
var tick_hz := 90
# Every strike seen since attach: {tick, strength, kind, enemy}, `enemy` the struck
# node's instance id. These are raw waves; knock_count() counts contact stretches.
var knocks: Array = []
# Instance ids of every enemy struck this trial.
var knocked := {}

var _attached := false
var _stretches: Array = []
var _collapsed_waves := 0


func _init(stage_ref, run_ref = null) -> void:
	stage = stage_ref
	run = run_ref
	tick_hz = Engine.physics_ticks_per_second


func attach() -> void:
	if _attached:
		return
	stage.player.enemy_struck.connect(_on_struck)
	_attached = true


func detach() -> void:
	if not _attached:
		return
	if stage.player.enemy_struck.is_connected(_on_struck):
		stage.player.enemy_struck.disconnect(_on_struck)
	_attached = false


func advance() -> void:
	tick += 1
	if run != null:
		run.observe(self)


func _on_struck(enemy: Node3D, stomped: bool, _speed: float) -> void:
	var id := enemy.get_instance_id()
	knocks.append({"tick": tick, "strength": STOMP_STRENGTH if stomped else RAM_STRENGTH,
		"kind": "stomp" if stomped else "ram", "enemy": id})
	knocked[id] = true


# --- facts read from the stage ------------------------------------------------------

func position() -> Vector3:
	return stage.player.ball_position()


func velocity() -> Vector3:
	return stage.player.state.velocity


func grounded() -> bool:
	return stage.player.state.grounded


func hp() -> float:
	return stage.run.hp


func alive() -> bool:
	return stage.run.alive()


func submersion() -> float:
	return stage.flood.submersion(position())


func flood_phase() -> int:
	return stage.flood.cycle.phase


func hatch_open() -> bool:
	return stage.flood.cycle.hatch_revealed()


func knocked_count() -> int:
	return knocked.size()


func scrap_held() -> int:
	return stage.run.scrap


func time_s() -> int:
	return int(floor(float(tick) / float(tick_hz)))


# This stage's live enemies in spawn order, knocked ones included. The group spans the
# scene tree, so a test with two stages keeps only its own.
func enemies() -> Array:
	var out := []
	for node in stage.get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(node) and not node.is_queued_for_deletion() and stage.is_ancestor_of(node):
			out.append(node)
	return out


# The enemies still in play, which under stage threat rule 2 is every live one,
# knocked or not: the threats, the offers and the agent's targets all read this.
func live_targets() -> Array:
	return enemies()


func shells() -> Array:
	var out := []
	for node in stage.get_children():
		if node.get_script() == Projectile and not node.is_queued_for_deletion():
			out.append(node)
	return out


func knock_count(kind: String) -> int:
	if _collapsed_waves != knocks.size():
		_stretches = collapse(knocks)
		_collapsed_waves = knocks.size()
	return _stretches.filter(func(knock): return knock["kind"] == kind).size()


# Telemetry.drain_knocks's rule: strikes on one enemy are one stretch while each follows
# the previous strike on that enemy within KNOCK_GAP_TICKS (30).
static func collapse(waves: Array) -> Array:
	var out := []
	var last := {}
	var open := {}
	for wave in waves:
		var enemy: int = wave["enemy"]
		var at: int = wave["tick"]
		var joins: bool = last.has(enemy) and at - int(last[enemy]) <= 30
		last[enemy] = at
		if joins:
			out[open[enemy]]["waves"] += 1
			continue
		open[enemy] = out.size()
		out.append({"tick": at, "enemy": enemy, "kind": wave["kind"], "waves": 1})
	return out


# --- the protocol blocks -----------------------------------------------------------

func snapshot() -> Dictionary:
	return {"jev": jev_block(), "sim": sim_block()}


func jev_block() -> Dictionary:
	var state := {
		"self": _self_block(),
		"stage": {"name": STAGE_NAME, "time_s": time_s(), "tier": stage.director.effective_tier() + 1},
		"threats": threats(),
		"objective": _objective_block(),
		"scrap": {"held": scrap_held()},
	}
	return {"state": state, "options": options(state)}


func sim_block() -> Dictionary:
	var at := position()
	var v := velocity()
	return {
		"pos": [at.x, at.y, at.z],
		"vel": [v.x, v.y, v.z],
		"tick": tick,
		"mode": stage.player.mode_name(),
		"grounded": grounded(),
		"hp": hp(),
		"scrap": scrap_held(),
		"flood": FloodCycle.PHASE_NAMES[flood_phase()],
		"submersion": submersion(),
		"corridor": Geo.corridor_at(at),
		"enemies": enemies().size(),
		"knocked": knocked_count(),
		"knocks": {"stomp": knock_count("stomp"), "ram": knock_count("ram")},
		# Diagnostics for comparing the threat rules: the nearest enemy never struck
		# and the nearest struck one this trial. -1 when there is none.
		"nearest_unknocked_m": _nearest(enemies().filter(func(e): return not knocked.has(e.get_instance_id())), at),
		"nearest_knocked_m": _nearest(enemies().filter(func(e): return knocked.has(e.get_instance_id())), at),
	}


static func _nearest(nodes: Array, at: Vector3) -> float:
	var best := -1.0
	for node in nodes:
		var d: float = node.global_position.distance_to(at)
		if best < 0.0 or d < best:
			best = d
	return best


func _self_block() -> Dictionary:
	var state = stage.player.state
	return {
		"speed_ms": tenth(velocity().length()),
		"speed_tier": SpeedTier.label(state.tier),
		"grounded": bool(state.grounded),
		"hp": whole(maxf(0.0, hp())),
		"air_jump_available": state.air_actions > 0,
		"location": Geo.location(position()),
	}


# The flood first when it is listed, then the nearest enemies and shells within 60 m,
# nearest first, three in all. An enemy leaves only when the game removes it.
func threats() -> Array:
	var out := []
	var flood := flood_threat()
	if not flood.is_empty():
		out.append(flood)
	var at := position()
	var v := velocity()
	var found := []
	var order := 0
	for enemy in live_targets():
		var d: float = enemy.global_position.distance_to(at)
		if d <= THREAT_RANGE:
			found.append({"node": enemy, "d": d, "order": order, "shell": false})
		order += 1
	for shell in shells():
		var d: float = shell.position.distance_to(at)
		if d <= THREAT_RANGE:
			found.append({"node": shell, "d": d, "order": order, "shell": true})
		order += 1
	found.sort_custom(func(a, b): return a["d"] < b["d"] or (a["d"] == b["d"] and a["order"] < b["order"]))
	for entry in found:
		if out.size() >= MAX_THREATS:
			break
		out.append(_shell_threat(entry["node"], entry["d"], at) if entry["shell"] else _enemy_threat(entry["node"], entry["d"], at, v))
	return out


func _enemy_threat(enemy, d: float, at: Vector3, v: Vector3) -> Dictionary:
	if enemy.get_script() == Lobber:
		var charging: bool = enemy._clock >= Lobber.CYCLE - Lobber.TELEGRAPH and d <= Lobber.SHOT_RANGE
		return {"kind": "lobber", "distance_m": whole(d), "telegraphing": charging,
			"damage": whole(Projectile.DAMAGE)}
	var offset: Vector3 = enemy.global_position - at
	var relative: Vector3 = enemy.velocity - v
	return {
		"kind": "miniboss" if enemy.miniboss else "chaser",
		"distance_m": whole(d),
		"closing": offset.dot(relative) < 0.0,
		"below": at.y - enemy.global_position.y > BELOW_MARGIN,
		"damage": whole(enemy.contact_damage),
	}


# A shell in flight: when it comes down to the ball's height, and whether it lands on
# the ball's current position.
func _shell_threat(shell, d: float, at: Vector3) -> Dictionary:
	var p: Vector3 = shell.position
	var vel: Vector3 = shell.velocity
	var g := Projectile.GRAVITY
	var drop := p.y - at.y
	var disc := vel.y * vel.y + 2.0 * g * drop
	var t := (vel.y + sqrt(disc)) / g if disc >= 0.0 else 0.0
	var lands := Vector2(p.x + vel.x * t, p.z + vel.z * t)
	return {
		"kind": "lobber_shell",
		"distance_m": whole(d),
		"arc_lands_in_s": tenth(t),
		"targets_current_position": lands.distance_to(Vector2(at.x, at.z)) <= SHELL_REACH,
		"damage": whole(Projectile.DAMAGE),
	}


# The flood from FLOOD_WINDOW_S before the water rises until it has drained. It targets
# the ball's position when the water there would reach the ball: at the full flood while
# the water is due or up, at the current level while it drains.
func flood_threat() -> Dictionary:
	var cycle = stage.flood.cycle
	var rises := -1.0
	match cycle.phase:
		FloodCycle.DRY:
			rises = FloodCycle.DURATIONS[FloodCycle.DRY] - cycle.elapsed + FloodCycle.DURATIONS[FloodCycle.WARNING]
			if rises > FLOOD_WINDOW_S:
				return {}
		FloodCycle.WARNING:
			rises = FloodCycle.DURATIONS[FloodCycle.WARNING] - cycle.elapsed
		FloodCycle.RISING, FloodCycle.HIGH:
			rises = 0.0
	var at := position()
	var aimed: bool = Geo.wet_at_full(at) if cycle.phase != FloodCycle.FALLING else submersion() > 0.0
	var out := {"kind": "flood", "effect": FLOOD_EFFECT, "targets_current_position": aimed}
	if rises >= 0.0:
		out["water_rises_in_s"] = tenth(rises)
	return out


func objective() -> Dictionary:
	return run.objective(self)


func _objective_block() -> Dictionary:
	var goal := objective()
	return {"kind": goal["kind"], "distance_m": whole(position().distance_to(goal["point"]))}


# Every intent the port can execute: push, chute, scrap, stomp, ram, evade and retreat.
# take_cache and start_exit need the E key, which the input seam (intent.gd) does not
# carry, so they are never offered. decide.mjs's gate then removes what the ball cannot
# do right now, so stomp and ram are offered here even when the air jump is spent or the
# tier is too low. Nothing offered here carries requires_speed_ms (JL-21 review, F4).
func options(state: Dictionary) -> Array:
	var at := position()
	var goal := objective()
	var target: Vector3 = goal["point"]
	var climbing := Geo.shelf_at(target.z) > Geo.shelf_at(at.z)
	var push_line := "bypass ramp up" if climbing else "direct line"
	var out := [{"id": "push_objective", "why": "Take the %s to the %s %d m away" % [
		push_line, _objective_words(goal["kind"]), state["objective"]["distance_m"]]}]
	var chute := Geo.chute_for(at, target)
	if chute >= 0:
		var near := Geo.near_end(chute, climbing)
		var d := Vector2(at.x, at.z).distance_to(near)
		if d <= CHUTE_RANGE or Geo.in_channel(at, chute):
			out.append({"id": "hit_kicker", "why": "Commit to the %s %d m away, %s to the %s" % [
				Geo.CHUTE_NAMES[chute], whole(d), "up" if climbing else "down",
				Geo.SHELF_NAMES[Geo.shelf_at(at.z) + (1 if climbing else -1)]]})
	var scrap := _scrap_near(at)
	if scrap["count"] > 0:
		out.append({"id": "sweep_scrap", "why": "%d scrap within %d m, the nearest %d m away" % [
			scrap["count"], int(SCRAP_RANGE), whole(scrap["nearest"])]})
	var seen: Array = state["threats"]
	var nearest := {}
	var evade := ""
	for threat in seen:
		match threat["kind"]:
			"flood":
				if threat["targets_current_position"]:
					evade = "Climb out of the flood's reach before the water drags you"
			"lobber_shell":
				if threat["targets_current_position"] and evade == "":
					evade = "Swerve off the spot the lobber's shell lands on in %.1f s" % threat["arc_lands_in_s"]
			_:
				if nearest.is_empty():
					nearest = threat
				if threat.get("closing", false) and threat["distance_m"] <= EVADE_RANGE and evade == "":
					evade = "Break off from the %s closing %d m away" % [threat["kind"], threat["distance_m"]]
	if not nearest.is_empty():
		if nearest["distance_m"] <= STOMP_RANGE:
			out.append({"id": "stomp_target", "why": "Jump and land on the %s %d m away" % [nearest["kind"], nearest["distance_m"]]})
		if nearest["distance_m"] <= RAM_RANGE:
			out.append({"id": "ram_target", "why": "Hit the %s %d m away above the fast tier" % [nearest["kind"], nearest["distance_m"]]})
		if hp() <= stage.run.max_hp * RETREAT_HP:
			out.append({"id": "retreat_regen", "why": "Back off from contact at %d HP and let it regenerate" % whole(hp())})
	if evade != "":
		out.append({"id": "evade_hazard", "why": evade})
	return out


func _scrap_near(at: Vector3) -> Dictionary:
	var count := 0
	var nearest := INF
	var field = stage.scrap
	for i in field.count():
		var d: float = at.distance_to(field.item_position(i))
		if d <= SCRAP_RANGE:
			count += 1
			nearest = minf(nearest, d)
	return {"count": count, "nearest": nearest}


static func _objective_words(kind: String) -> String:
	match kind:
		"reach_shelf":
			return "mid shelf"
		"reach_hatch":
			return "maintenance hatch"
	return kind.replace("_", " ")


static func tenth(value: float) -> float:
	return maxf(0.0, round(value * 10.0) / 10.0)


static func whole(value: float) -> int:
	return int(round(value))
