extends RefCounted

# Read-only state synthesis for the Jev player on Cable Bench (JL-26; ball-lab's
# jev_state.gd is the reference). It turns a running stage into the protocol's `jev`
# block, pre-quantised to the corpus grid in tools/jev-player/protocol/PROTOCOL.md, and
# a `sim` block. It only reads gameplay nodes. The things it attaches are extra
# listeners: the player's `shockwave` (knocks) and each cableway's `struck` (hits on
# the ball). Nothing here reads the wall clock or a random number: `tick` is counted by
# the owner.
#
# Usage: `var view := JevState.new(stage, run)`, `view.attach()`, then `view.advance()`
# once per physics tick and `view.snapshot()` whenever a state is due. `run` is an
# optional `Scenarios.Run`; it supplies the objective and is fed every tick.
#
# Threats (stage-threat-rule 2, the coordinator's JL-26 ruling): a threat leaves the
# exported state only when the game has taken it out of play. A knocked Cable Bench foe
# keeps its HP and keeps chasing, so it stays a threat and a stomp, ram and evade
# target until it is dead or freed; only dead or freed foes are dropped, for every arm
# alike. Ball-lab keeps its own rule, since its dummies cannot die. `knocked` still
# records which foes the ball has knocked, for the result line.
#
# Speed gates (JL-21 review, F4). hit_kicker carries no requires_speed_ms: the east
# ledge needs about 26 m/s at the ramp, which no ball has at decision time, and the
# steering builds that speed itself on the run-up. It is offered on geometry the
# policy controls: the kicker's run-up lies on the ball's bench within range.

const Layout := preload("res://src/layout.gd")
const SpeedTier := preload("res://src/speed_tier.gd")
const Tuning := preload("res://src/tuning.gd")
const RunState := preload("res://src/run_state.gd")
const Foe := preload("res://src/foe.gd")
const Lobber := preload("res://src/lobber.gd")
const Projectile := preload("res://src/projectile.gd")
const Cableway := preload("res://src/cableway.gd")
const Forge := preload("res://src/forge.gd")
const Telemetry := preload("res://src/jev/telemetry.gd")

const STAGE_NAME := "cable-bench"
const THREAT_RANGE := 60.0
const MAX_THREATS := 3
# player_ball.gd emits 0.6 for a descending rebound and 1.0 for a fast-tier hit.
const STOMP_STRENGTH := 0.6
const RAM_STRENGTH := 1.0
# How far above a foe the ball must be for the foe to count as `below`.
const BELOW_MARGIN := 2.0
# A cableway load or a lobbed shot is a threat when it arrives within this long.
const HAZARD_WARN_S := 3.0
# A ball this far or nearer the cable's line is in its lane.
const CABLE_LANE := 10.0
# A lobber whose next shot is this close is telegraphing.
const LOB_TELL_S := 1.0
# Offer ranges. Provisional, not calibrated.
const STOMP_RANGE := 30.0
const RAM_RANGE := 40.0
const EVADE_RANGE := 10.0
const EVADE_HAZARD_S := 2.0
const SWEEP_RANGE := 40.0
const SWEEP_MIN := 3
# Scrap more than this above or below the ball is on another bench or a mesa top.
const SWEEP_DROP := 4.0
const CACHE_RANGE := 90.0
const KICKER_RANGE := 120.0
# The run-up starts this far back from layout.gd's kicker entry, along the siding.
const KICKER_RUNUP := 60.0
const RETREAT_HP_SHARE := 0.5

var stage
var run
var tick := 0
var tick_hz := 90
# Every shockwave seen since attach: {tick, strength, kind, enemy}. `enemy` is the name
# of the foe the wave was emitted on, or "". These are raw waves; knock_count() counts
# contact stretches.
var knocks: Array = []
# Names of the foes the ball has knocked by stomp or ram in this trial. Recorded only;
# it filters nothing.
var knocked := {}
var cableway_hits := 0
# Foe contact hits on the ball by foe kind, seen when a foe's contact cooldown restarts
# (foe.gd _touch_player): {kind: {"hits": n, "damage": d}}, and the first HIT_LOG of
# them as {tick, kind, damage, foe}.
var contact := {}
var hit_log: Array = []

const HIT_LOG := 200

var _attached := false
var _contact_clocks := {}
var _stretches: Array = []
var _collapsed_waves := 0


func _init(stage_ref, run_ref = null) -> void:
	stage = stage_ref
	run = run_ref
	tick_hz = Engine.physics_ticks_per_second


func attach() -> void:
	if _attached:
		return
	stage.player.shockwave.connect(_on_shockwave)
	for cableway in stage.cableways:
		cableway.struck.connect(_on_struck)
	_attached = true


func detach() -> void:
	if not _attached:
		return
	if stage.player.shockwave.is_connected(_on_shockwave):
		stage.player.shockwave.disconnect(_on_shockwave)
	for cableway in stage.cableways:
		if cableway.struck.is_connected(_on_struck):
			cableway.struck.disconnect(_on_struck)
	_attached = false


func advance() -> void:
	tick += 1
	_watch_contacts()
	if run != null:
		run.observe(self)


# A foe's contact cooldown only rises when it has just damaged the ball.
func _watch_contacts() -> void:
	for foe in foes():
		var name := String(foe.name)
		var clock: float = foe._contact_clock
		if clock > float(_contact_clocks.get(name, 0.0)):
			var kind := String(foe.kind)
			var entry: Dictionary = contact.get(kind, {"hits": 0, "damage": 0.0})
			entry["hits"] += 1
			entry["damage"] += foe.contact_damage
			contact[kind] = entry
			if hit_log.size() < HIT_LOG:
				hit_log.append({"tick": tick, "kind": kind, "damage": snappedf(foe.contact_damage, 0.01), "foe": name})
		_contact_clocks[name] = clock


func _on_shockwave(at: Vector3, strength: float) -> void:
	var kind := "other"
	if is_equal_approx(strength, STOMP_STRENGTH):
		kind = "stomp"
	elif is_equal_approx(strength, RAM_STRENGTH):
		kind = "ram"
	var enemy := _foe_at(at)
	knocks.append({"tick": tick, "strength": strength, "kind": kind, "enemy": enemy})
	if enemy != "" and kind != "other":
		knocked[enemy] = true


func _on_struck(body: Node) -> void:
	if body == stage.player:
		cableway_hits += 1


# The wave is emitted at the foe's own position, so the nearest foe is the one hit.
func _foe_at(at: Vector3) -> String:
	var best := ""
	var best_d := INF
	for foe in foes():
		var d: float = foe.global_position.distance_to(at)
		if d < best_d:
			best_d = d
			best = foe.name
	return best if best_d < 0.5 else ""


# --- facts read from the stage -----------------------------------------------------

func position() -> Vector3:
	return stage.player.ball_position()


func velocity() -> Vector3:
	return stage.player.state.velocity


func grounded() -> bool:
	return stage.player.state.grounded


func time_s() -> int:
	return int(floor(float(tick) / float(tick_hz)))


# Live foes in spawn order: dead (hp 0) and freed ones are out of play.
func foes() -> Array:
	var out := []
	if stage.director == null:
		return out
	for child in stage.director.get_children():
		if not (child is Foe) or child.is_queued_for_deletion() or child.hp <= 0.0:
			continue
		out.append(child)
	return out


func shots() -> Array:
	var out := []
	if stage.director == null:
		return out
	for child in stage.director.get_children():
		if child is Projectile and not child.is_queued_for_deletion():
			out.append(child)
	return out


func scrap_items() -> Array:
	return stage.scrap_field._items


func knock_count(kind: String) -> int:
	if _collapsed_waves != knocks.size():
		_stretches = collapse(knocks)
		_collapsed_waves = knocks.size()
	return _stretches.filter(func(knock): return knock["kind"] == kind).size()


# Telemetry.drain_knocks's rule: waves on one foe are one stretch while each follows
# the previous wave on that foe within KNOCK_GAP_TICKS.
static func collapse(waves: Array) -> Array:
	var out := []
	var last := {}
	var open := {}
	for wave in waves:
		var enemy: String = wave["enemy"]
		var at_tick: int = wave["tick"]
		var joins: bool = last.has(enemy) and at_tick - int(last[enemy]) <= Telemetry.KNOCK_GAP_TICKS
		last[enemy] = at_tick
		if joins:
			out[open[enemy]]["waves"] += 1
			continue
		open[enemy] = out.size()
		out.append({"tick": at_tick, "enemy": enemy, "kind": wave["kind"], "waves": 1})
	return out


# --- the protocol blocks -----------------------------------------------------------

func snapshot() -> Dictionary:
	return {"jev": jev_block(), "sim": sim_block()}


func jev_block() -> Dictionary:
	var state := {
		"self": _self_block(),
		"stage": {"name": STAGE_NAME, "time_s": time_s(), "tier": int(stage.run.tier())},
		"threats": threats(),
		"objective": _objective_block(),
		"scrap": {"held": int(stage.run.scrap)},
		"buffs": buffs(),
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
		"air_actions": int(stage.player.state.air_actions),
		"tier": SpeedTier.label(stage.player.state.tier),
		"hp": stage.run.hp,
		"phase": stage.run.phase_name(),
		"stage_time": stage.run.stage_time,
		"foes": foes().size(),
		"knocked": knocked.size(),
		"knocks": {"stomp": knock_count("stomp"), "ram": knock_count("ram"), "other": knock_count("other")},
	}


func _self_block() -> Dictionary:
	var state = stage.player.state
	return {
		"speed_ms": tenth(velocity().length()),
		"speed_tier": SpeedTier.label(state.tier),
		"grounded": bool(state.grounded),
		"hp": whole(maxf(0.0, stage.run.hp)),
		"air_jump_available": state.air_actions > 0,
		"location": location(position()),
	}


func buffs() -> Array:
	var out := []
	for buff in stage.loadout.BUFFS:
		var n: int = stage.loadout.stacks(buff["key"])
		if n > 0:
			out.append("%s x%d" % [buff["label"], n])
	return out


# Threat entries with their nodes, most urgent first: loads and shots that arrive
# within HAZARD_WARN_S by arrival time, then live foes within THREAT_RANGE by distance,
# ties in spawn order.
func threat_entries() -> Array:
	var at := position()
	var v := velocity()
	var timed := []
	for cableway in stage.cableways:
		var entry := _cableway_entry(cableway, at)
		if not entry.is_empty():
			timed.append(entry)
	for shot in shots():
		var entry := _shot_entry(shot, at)
		if not entry.is_empty():
			timed.append(entry)
	timed.sort_custom(func(a, b): return a["time"] < b["time"])
	var near := []
	for foe in foes():
		var d: float = foe.global_position.distance_to(at)
		if d <= THREAT_RANGE:
			near.append(_foe_entry(foe, at, v, d))
	near.sort_custom(func(a, b): return a["d"] < b["d"])
	return (timed + near).slice(0, MAX_THREATS)


func threats() -> Array:
	return threat_entries().map(func(entry): return entry["export"])


func _foe_entry(foe, at: Vector3, v: Vector3, d: float) -> Dictionary:
	var offset: Vector3 = foe.global_position - at
	var relative: Vector3 = foe.velocity - v
	var export := {
		"kind": String(foe.kind),
		"distance_m": whole(d),
		"damage": whole(foe.contact_damage),
		# The gap is shrinking when the relative velocity points back along it.
		"closing": offset.dot(relative) < 0.0,
		"below": at.y - foe.global_position.y > BELOW_MARGIN,
	}
	if foe is Lobber:
		export["telegraphing"] = d <= Lobber.RANGE and foe._fire_clock <= LOB_TELL_S
	return {"kind": "foe", "node": foe, "d": d, "time": INF, "export": export}


# A load arrives when its travel along the cable reaches the ball's point on the line.
func _cableway_entry(cableway, at: Vector3) -> Dictionary:
	var from: Vector3 = cableway._from
	var to: Vector3 = cableway._to
	var dir := _flat(to - from)
	var length := dir.length()
	if length < 0.01:
		return {}
	dir /= length
	var along_ball := _flat(at - from).dot(dir)
	if along_ball < 0.0 or along_ball > length:
		return {}
	var lateral := (_flat(at - from) - dir * along_ball).length()
	if lateral > CABLE_LANE:
		return {}
	var ahead: float = along_ball - float(cableway._travelled)
	if ahead < 0.0:
		ahead += length
	var time: float = ahead / float(cableway.speed)
	if time > HAZARD_WARN_S:
		return {}
	var load: Vector3 = cableway.load_position()
	var warned: Vector3 = cableway.warned_position()
	var strike: float = Cableway.STRIKE_RADIUS + Tuning.RADIUS
	return {"kind": "cableway", "node": cableway, "d": load.distance_to(at), "time": time, "export": {
		"kind": "cableway",
		"distance_m": whole(load.distance_to(at)),
		"damage": whole(Cableway.STRIKE_DAMAGE),
		"impact_in_s": tenth(time),
		"closing": true,
		"on_current_line": lateral <= strike,
		"telegraphing": _flat(warned - at).length() <= strike,
	}}


# A shot lands at its ground marker when its flight is over.
func _shot_entry(shot, at: Vector3) -> Dictionary:
	var left: float = float(shot._life) - 2.0
	if left <= 0.0 or left > HAZARD_WARN_S or shot._marker == null:
		return {}
	var lands: Vector3 = shot._marker.global_position
	var gap := _flat(lands - at).length()
	return {"kind": "lob", "node": shot, "d": gap, "time": left, "point": lands, "export": {
		"kind": "lob",
		"distance_m": whole(gap),
		"damage": whole(shot.damage),
		"arc_lands_in_s": tenth(left),
		"targets_current_position": gap <= Projectile.HIT_RADIUS + Tuning.RADIUS,
	}}


func objective() -> Dictionary:
	if run != null:
		return run.objective(self)
	return {"kind": "forge", "point": Layout.drop_at(Layout.FORGE, Tuning.RADIUS)}


func _objective_block() -> Dictionary:
	var goal := objective()
	var block := {"kind": goal["kind"], "distance_m": whole(position().distance_to(goal["point"]))}
	if goal["kind"] in ["forge", "exit"]:
		block["inside_ring"] = stage.forge.in_zone(position())
		block["charge_started"] = stage.run.phase in [RunState.Phase.CHARGING, RunState.Phase.READY, RunState.Phase.CLEAR]
	return block


# Every intent Cable Bench can execute. An option is offered when its target is in
# range; decide.mjs's precondition gate then removes what the ball cannot do right now,
# so stomp and ram are offered here even when the air jump is spent or the tier is too
# low.
func options(state: Dictionary) -> Array:
	var objective_block: Dictionary = state["objective"]
	var out := [{"id": "push_objective", "why": "Roll the switchback line to the %s %d m away" % [
		objective_block["kind"], objective_block["distance_m"]]}]
	var at := position()
	var near_scrap := scrap_near(at).size()
	if near_scrap >= SWEEP_MIN:
		out.append({"id": "sweep_scrap", "why": "Sweep the %d scrap within %d m" % [near_scrap, int(SWEEP_RANGE)]})
	var cache = cache_offer(at)
	if cache != null:
		out.append({"id": "take_cache", "why": "Open the %s cache %d m away for %d scrap" % [
			cache.label, whole(_flat(cache.global_position - at).length()), cache.cost()]})
	var kicker := kicker_offer(at)
	if kicker >= 0:
		var mesa: Dictionary = Layout.MESAS[kicker]
		out.append({"id": "hit_kicker", "why": "Run up the %s kicker %d m away onto the ledge" % [
			mesa["name"], whole(_flat(kicker_runup(kicker) - at).length())]})
	var foe_threats := threat_entries().filter(func(entry): return entry["kind"] == "foe")
	if not foe_threats.is_empty():
		var nearest: Dictionary = foe_threats[0]["export"]
		if nearest["distance_m"] <= STOMP_RANGE:
			out.append({"id": "stomp_target", "why": "Jump and land on the %s %d m away" % [nearest["kind"], nearest["distance_m"]]})
		if nearest["distance_m"] <= RAM_RANGE:
			out.append({"id": "ram_target", "why": "Hit the %s %d m away at fast-tier speed" % [nearest["kind"], nearest["distance_m"]]})
	var hazard = evade_threat()
	if hazard != null:
		out.append({"id": "evade_hazard", "why": "Break off from the %s %d m away" % [hazard["export"]["kind"], whole(hazard["d"])]})
	if stage.run.hp < stage.run.hp_max * RETREAT_HP_SHARE:
		out.append({"id": "retreat_regen", "why": "Back off and let %d HP regenerate" % whole(stage.run.hp_max - stage.run.hp)})
	if objective_block["kind"] == "forge" and objective_block.get("inside_ring", false) \
			and stage.run.phase == RunState.Phase.RUNNING:
		out.append({"id": "start_exit", "why": "Start the %d s forge charge; the tier clock keeps running" % int(stage.run.charge_seconds)})
	return out


# The most urgent threat to break off from: a load or shot about to arrive on the ball,
# else a foe closing inside EVADE_RANGE. Null when there is none.
func evade_threat():
	for entry in threat_entries():
		var export: Dictionary = entry["export"]
		if entry["kind"] == "foe":
			if export["closing"] and entry["d"] <= EVADE_RANGE:
				return entry
		elif entry["time"] <= EVADE_HAZARD_S and (export.get("on_current_line", false)
				or export.get("targets_current_position", false)):
			return entry
	return null


# Scrap on the ball's own level within SWEEP_RANGE, nearest first.
func scrap_near(at: Vector3) -> Array:
	var found := []
	for item in scrap_items():
		var p: Vector3 = item.position
		if absf(p.y - at.y) > SWEEP_DROP:
			continue
		var d := _flat(p - at).length()
		if d <= SWEEP_RANGE:
			found.append({"item": item, "d": d})
	found.sort_custom(func(a, b): return a["d"] < b["d"])
	return found.map(func(entry): return entry["item"])


# The nearest cache the ball can open by driving: unopened, affordable now, and on the
# ball's level within CACHE_RANGE, or on the mesa top the ball is on. The secret cache
# is left out: its gap faces the bench-2 cliff lip and this steering cannot make it.
func cache_offer(at: Vector3):
	var mesa := mesa_under(at)
	var level := Layout.level_of(at.z)
	var best = null
	var best_d := INF
	for cache in stage.caches:
		if cache.opened or not cache.affordable() or cache.label == "secret":
			continue
		var index := mesa_index(cache.label)
		var d := _flat(cache.global_position - at).length()
		if index >= 0:
			if index != mesa:
				continue
		elif mesa >= 0 or Layout.level_of(cache.global_position.z) != level or d > CACHE_RANGE:
			continue
		if d < best_d:
			best_d = d
			best = cache
	return best


# The mesa whose kicker run-up is on the ball's bench within KICKER_RANGE, or -1. Not
# offered from a mesa top.
func kicker_offer(at: Vector3) -> int:
	if mesa_under(at) >= 0:
		return -1
	var level := Layout.level_of(at.z)
	var best := -1
	var best_d := INF
	for i in Layout.MESAS.size():
		var runup := kicker_runup(i)
		if Layout.level_of(runup.z) != level:
			continue
		var d := _flat(runup - at).length()
		if d <= KICKER_RANGE and d < best_d:
			best_d = d
			best = i
	return best


static func kicker_runup(index: int) -> Vector3:
	var entry := Layout.kicker_entry(index)
	var back := _flat(Layout.kicker_run_direction(index)).normalized()
	var p := entry - back * KICKER_RUNUP
	return Layout.drop_point(p.x, p.z, Tuning.RADIUS)


static func mesa_index(label: String) -> int:
	for i in Layout.MESAS.size():
		if Layout.MESAS[i]["name"] == label:
			return i
	return -1


# The mesa whose top the ball is on, or -1.
static func mesa_under(at: Vector3) -> int:
	for i in Layout.MESAS.size():
		var centre: Vector2 = Layout.MESAS[i]["centre"]
		if Vector2(at.x, at.z).distance_to(centre) <= Layout.MESA_RADIUS + 1.0 \
				and at.y >= Layout.mesa_top(i) - 1.5:
			return i
	return -1


# A coarse place name from layout.gd, for Jev's `location`.
static func location(at: Vector3) -> String:
	var mesa := mesa_under(at)
	if mesa >= 0:
		return Layout.MESAS[mesa]["name"]
	var level := Layout.level_of(at.z)
	if level >= Layout.CLIFF_Z.size():
		return "forge apron"
	var cliff: float = Layout.CLIFF_Z[level]
	if absf(at.x - Layout.ROAD_X[level]) <= Layout.ROAD_HALF and at.z <= cliff + Layout.ROAD_RUN:
		return "road %d" % (level + 1)
	if absf(at.z - Layout.SIDING_Z[level]) <= Layout.SIDING_HALF:
		return "siding %d" % level
	return "bench %d" % level


static func tenth(value: float) -> float:
	return maxf(0.0, round(value * 10.0) / 10.0)


static func whole(value: float) -> int:
	return int(round(value))


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
