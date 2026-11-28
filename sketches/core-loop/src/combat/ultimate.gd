extends Node

const UltimateMeter := preload("res://src/core/ultimate_meter.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const UpgradeTree := preload("res://src/core/upgrade_tree.gd")
const Augments := preload("res://src/movement/augments.gd")
const RideRail := preload("res://src/world/ride_rail.gd")
const Weapons := preload("res://src/combat/weapons.gd")
const Palette := preload("res://src/core/palette.gd")
const Stakes := preload("res://src/combat/stakes.gd")
const BallTuning := preload("res://src/movement/tuning.gd")

const IDLE := "idle"
const WINDUP := "windup"
const FLIGHT := "flight"
const RECOVER := "recover"

const WINDUP_SECONDS := 0.35
const PLANT_STOP_SECONDS := 0.15

var _plant_from := 0.0
const RECOVER_SECONDS := 0.25
const FLIGHT_SPEED := 18.0
const FLIGHT_MIN := 1.6
const FLIGHT_MAX := 3.2
const FLIGHT_NO_MUSIC := 2.4
const NO_MUSIC_BEATS := 7
const RAIL_SEARCH := 12.0
const HOP_HEIGHT := 8.0
const HOP_SECONDS := 1.6
const CORRIDOR := 3.0
const STEER_SPEED := 6.0
const VOLLEY_TARGETS := 3
const VOLLEY_RADIUS := 10.0
const VOLLEY_DAMAGE := 12.0
const VOLLEY_BIAS_DEG := 25.0
const LANDING_DAMAGE := 60.0
const LANDING_KNOCK := 26.0
const ENCORE_REACH := 30.0
const HEFT_MULT := [1.0, 1.15, 1.30, 1.45, 1.60]
const ARC_REACH := [40.0, 47.0, 55.0, 62.0, 70.0]
const LANDING_RADIUS := [6.0, 7.0, 8.0, 9.0, 10.0]
const DAMAGE_TAKEN := 0.2
const WARDEN_POSTURE_CAP := 70.0
const WARDEN_POSTURE_CAP_ORDINARY := 45.0
const WARDEN_VOLLEY := 0.5
const BOSS_MULT := 0.5
const CONTACT_GAP := 0.5
const BLOCKED := 2.5
const GRAVITY := 26.0

var ctx
var combat
var meter := UltimateMeter.new()
var beat_seconds := Callable()
var rail_query := Callable()
var _ult_rows := {
	"cable_run": {"tech": _sable_tech, "peak": _sable_peak, "landing": _sable_landing, "release": _sable_release},
	"ball_lightning": {"tech": _lightning_tech, "peak": _lightning_peak, "landing": _lightning_landing, "release": _sable_release},
	"outpost": {"tech": _sable_tech, "peak": _sable_peak, "landing": _outpost_landing, "release": _sable_release},
	"redjaw_rend": {"tech": func(beat, ball, aim, mult): return combat.get_node("TarnClaw").tech("redjaw_rend", beat, ball, aim, mult),
		"peak": func(at): combat.get_node("TarnClaw").peak("redjaw_rend", at),
		"landing": func(at, heft, chain): return combat.get_node("TarnClaw").landing("redjaw_rend", at, heft, chain)},
	"rake_run": {"tech": func(beat, ball, aim, mult): return combat.get_node("TarnClaw").tech("rake_run", beat, ball, aim, mult),
		"peak": func(at): combat.get_node("TarnClaw").peak("rake_run", at),
		"landing": func(at, heft, chain): return combat.get_node("TarnClaw").landing("rake_run", at, heft, chain)},
	"vice_leap": {"tech": func(beat, ball, aim, mult): return combat.get_node("TarnClaw").tech("vice_leap", beat, ball, aim, mult),
		"peak": func(at): combat.get_node("TarnClaw").peak("vice_leap", at),
		"landing": func(at, heft, chain): return combat.get_node("TarnClaw").landing("vice_leap", at, heft, chain)},
	"plate_return": {"target": func(ball, aim): return combat.tally_kit.tally_target("plate_return", ball, aim),
		"tech": func(beat, ball, aim, mult): return combat.tally_kit.tally_tech("plate_return", beat, ball, aim, mult),
		"peak": func(at): combat.tally_kit.tally_peak("plate_return", at),
		"landing": func(at, heft, chain): return combat.tally_kit.tally_landing("plate_return", at, heft, chain)},
	"plate_audit": {"target": func(ball, aim): return combat.tally_kit.tally_target("plate_audit", ball, aim),
		"tech": func(beat, ball, aim, mult): return combat.tally_kit.tally_tech("plate_audit", beat, ball, aim, mult),
		"peak": func(at): combat.tally_kit.tally_peak("plate_audit", at),
		"landing": func(at, heft, chain): return combat.tally_kit.tally_landing("plate_audit", at, heft, chain)},
	"plate_flywheel": {"target": func(ball, aim): return combat.tally_kit.tally_target("plate_flywheel", ball, aim),
		"tech": func(beat, ball, aim, mult): return combat.tally_kit.tally_tech("plate_flywheel", beat, ball, aim, mult),
		"peak": func(at): combat.tally_kit.tally_peak("plate_flywheel", at),
		"landing": func(at, heft, chain): return combat.tally_kit.tally_landing("plate_flywheel", at, heft, chain)},
	"cannon_fire_mission": {"tech": _cannon_tech, "peak": _cannon_peak, "landing": _cannon_landing},
	"cannon_creeping_barrage": {"tech": _cannon_tech, "peak": _cannon_peak, "landing": _cannon_landing},
	"cannon_plate_mortar": {"target": _cannon_mortar_target, "tech": _cannon_tech, "peak": _cannon_peak, "landing": _cannon_landing},
}
var last_plan := {}

var _phase := IDLE
var _left := 0.0
var _plan := {}
var _id := ""
var _leg := 0
var _ride
var _leg_time := 0.0
var _beat_len := 0.0
var _beat_clock := 0.0
var _beat := 0
var _beats := 0
var _peaked := false
var _offset := 0.0
var _expected := Vector3.ZERO
var _posture_spent := {}
var _record := {}
var _clock := 0.0
var _contact_at := {}
var _staggered := {}
var _chunks := {}
var _was_full := false
var _fill_since := 0.0
var _record_fill := 0.0
var _ult_buffer := 0.0


func setup(ctx_ref, combat_ref) -> void:
	ctx = ctx_ref
	combat = combat_ref
	var rivet = load("res://src/combat/rivet_kit.gd")
	for id in rivet.SHAPE_DISPATCH:
		_ult_rows[id] = rivet.ultimate_row(combat, id)
	stakes = Stakes.new()
	ctx.root.add_child(stakes)
	stakes.setup(ctx, combat, self)
	ctx.events.run_started.connect(func(_class_id: String): _sable_runs = 0)
	ctx.events.dismounted.connect(_outpost_depart)
	name = "Ultimate"
	ctx.player.abilities.meter = meter
	ctx.player.set_piece_phase = Callable(self, "phase")
	ctx.run.defend_hook = Callable(self, "defend")
	ctx.run.ride_hook = Callable(self, "active")
	var ev = ctx.events
	ev.ultimate_started.connect(_cannon_started)
	ev.enemy_struck.connect(_on_struck)
	ev.harpoon_smashed.connect(func(_enemy: Node3D, _at: Vector3, _speed: float): _feed("smash", ctx.player.chain.multiplier()))
	ev.line_state_changed.connect(func(state: String, target: Node3D, _at: Vector3, _cause: String):
		if state == "chain_link":
			_feed_link(target))
	ev.near_miss.connect(func(_kind: String, _at: Vector3): _feed("near_miss"))
	ev.enemy_killed.connect(func(_kind: String, _at: Vector3, _scrap: int): _feed("kill"))
	ev.posture_changed.connect(_on_posture)
	ev.boss_reeled.connect(func(_at: Vector3, _scrap: int): _feed("reel"))
	ev.run_started.connect(func(_class_id: String):
		_abort("stage")
		meter.reset()
		_was_full = false
		_fill_since = _clock
		_contact_at = {}
		_staggered = {}
		_chunks = {}
		_record = {}
		ctx.run.set_meta("ultimate_record", {}))
	ev.stage_entered.connect(_on_stage_entered)
	ev.boss_arena_entered.connect(_pour_brew)
	ev.stage_content_cleared.connect(func(_reason: String): _abort("stage"))
	ev.player_died.connect(func(): _abort("death"))
	ev.run_ended.connect(func(_won: bool): _abort("stage"))


func register(id: String, row: Dictionary) -> void:
	_ult_rows[id] = row


func phase() -> String:
	return _phase


func active() -> bool:
	return _phase != IDLE


func current_beat() -> int:
	return _beat


func active_id() -> String:
	return _id


func record() -> Dictionary:
	return _record


func leg_state() -> Dictionary:
	var legs: Array = _plan.get("legs", [])
	var has_leg := _leg >= 0 and _leg < legs.size()
	var leg: Dictionary = legs[_leg] if has_leg else {}
	var total_remaining := -float(_leg_time)
	for i in range(_leg, legs.size()):
		total_remaining += float(legs[i]["seconds"])
	return {
		"has_leg": has_leg,
		"index": _leg,
		"count": legs.size(),
		"is_last": has_leg and _leg == legs.size() - 1,
		"elapsed": _leg_time,
		"remaining": (float(leg["seconds"]) - float(_leg_time)) if has_leg else 0.0,
		"total_remaining": total_remaining,
		"to": leg["to"] if has_leg and leg.has("to") else null,
		"final_to": legs.back()["to"] if not legs.is_empty() and legs.back().has("to") else null,
		"beat_length": _beat_len,
		"mode": String(leg.get("mode", "")),
	}


func is_peak_beat(beat: int) -> bool:
	return not _peaked and beat >= ceili(_beats / 2.0)


func ride_heading(fallback := Vector3.FORWARD) -> Vector3:
	return _ride.heading if _ride != null else fallback


func flatten_ride_release() -> void:
	if _ride != null:
		_ride.mode = RideRail.LINE
		_ride.velocity = _ride.heading * _ride.release_speed


func _on_stage_entered(_stage: int, retry: bool) -> void:
	_outpost_encore = false
	_abort("stage")
	if retry:
		meter.restore_entry()
		_was_full = meter.full()
	else:
		meter.mark_entry()


func _pour_brew() -> void:
	var shop = ctx.build.get("shop") if ctx.build != null else null
	var points: float = shop.pour_brew() if shop != null else 0.0
	if points > 0.0:
		meter.refund(points)
		_check_full()


func _feed(source: String, amount := 1.0) -> void:
	if not _fills():
		return
	if meter.add(source, amount) > 0.0:
		_check_full()


func _feed_link(target: Node3D) -> void:
	var id := target.get_instance_id() if is_instance_valid(target) else 0
	if meter.chain_link(id, int(ctx.player.chain.combo), _fills()) > 0.0:
		_check_full()


func _fills() -> bool:
	if ctx.flow == null or not ctx.flow.in_play():
		return false
	return ctx.terrain == null or not ctx.terrain.has_method("in_bay") or not ctx.terrain.in_bay(ctx.player.ball_position())


func _check_full() -> void:
	var full := meter.full()
	if full and not _was_full:
		_record_fill = _clock - _fill_since
		ctx.events.ultimate_ready.emit(_ult_id())
	_was_full = full


func _on_struck(enemy: Node3D, kind: String, _force: float) -> void:
	if kind in ["stomp", "ram", "slam"]:
		var id := enemy.get_instance_id() if is_instance_valid(enemy) else 0
		if _clock - float(_contact_at.get(id, -INF)) < CONTACT_GAP:
			return
		_contact_at[id] = _clock
		_feed("contact")
	elif Weapons.BASE.has(kind):
		_feed("weapon")


func _on_posture(enemy: Node3D, _posture: float, staggered: bool) -> void:
	if not is_instance_valid(enemy):
		return
	var id := enemy.get_instance_id()
	if staggered and not bool(_staggered.get(id, false)):
		_feed("stagger")
	_staggered[id] = staggered
	if enemy.has_method("chunks_left"):
		var left: int = enemy.chunks_left()
		if _chunks.has(id) and left < int(_chunks[id]):
			_feed("shatter")
		_chunks[id] = left


func _ult_id() -> String:
	return String(ctx.player.abilities.ultimate_id)


func can_start() -> String:
	if active() or ctx.flow == null or not ctx.flow.in_play() or ctx.flow.state_name() == "launch" or ctx.player.frozen():
		return "busy"
	if ctx.terrain != null and ctx.terrain.has_method("in_bay") and ctx.terrain.in_bay(ctx.player.ball_position()):
		return "busy"
	if not meter.full():
		return "uncharged"
	return ""


func press(aim := {}) -> String:
	if _phase == WINDUP:
		recall()
		return ""
	var refusal := can_start()
	if refusal != "":
		ctx.events.verb_failed.emit("ultimate", refusal, ctx.player.ball_position())
		return refusal
	if aim.is_empty():
		aim = _live_aim()
	start(plan(ctx.player.ball_position(), aim))
	return ""


func _live_aim() -> Dictionary:
	return {"origin": ctx.aim_origin(), "forward": ctx.aim_forward(), "harpoon": ctx.player.kit.aim}


func heft_index() -> int:
	var c := 1
	if ctx.run != null and ctx.run.has_method("heft_class"):
		c = int(ctx.run.heft_class())
	return clampi(c - 1, 0, HEFT_MULT.size() - 1)


func _row() -> Dictionary:
	return AbilityState.ABILITIES.get(_ult_id(), {})


func knob(knob_name: String, fallback):
	if UpgradeTree.KNOBS.has(knob_name):
		return ctx.player.tree.knob(knob_name)
	return fallback


func plan(ball: Vector3, aim: Dictionary, paths: Array = []) -> Dictionary:
	var row := _row()
	var heft := heft_index()
	var reach: float = ARC_REACH[heft] + (10.0 if _ult_id() == "ball_lightning" else 0.0)
	var kit = ctx.player.kit
	var found := {}
	var custom: Dictionary = _ult_rows.get(_ult_id(), {})
	if custom.has("target"):
		found = (custom["target"] as Callable).call(ball, aim)
	var order: Array = paths if not paths.is_empty() else row.get("paths", ["line", "rail", "arc"])
	var harpoon: Dictionary = aim.get("harpoon", kit.aim)
	var point = _aim_point(aim, reach + RAIL_SEARCH)
	for path in order:
		if not found.is_empty():
			break
		if path == "line":
			if kit.hooked:
				found = {"path": "line", "to": kit.anchor, "target": kit.anchor_body if kit.on_body else null}
			elif harpoon.get("state", Augments.AIM_NONE) != Augments.AIM_NONE and harpoon.has("point") \
					and ball.distance_to(harpoon["point"]) <= ctx.player.grapple_range():
				found = {"path": "line", "to": harpoon["point"], "target": harpoon.get("body")}
		elif path == "rail" and rail_query.is_valid() and point != null:
			var rail: Dictionary = rail_query.call(point)
			if not rail.is_empty() and (rail["entry"] as Vector3).distance_to(point) <= RAIL_SEARCH:
				found = {"path": "rail", "to": rail.get("to", rail["entry"]), "entry": rail["entry"]}
		elif path == "arc" and point != null and _ground_hit(aim, reach) != null:
			found = {"path": "arc", "to": _ground_hit(aim, reach)}
	if found.is_empty():
		found = {"path": "hop", "to": ball}
	var mode: String = found["path"]
	var to: Vector3 = found["to"]
	var length := ball.distance_to(to)
	var beat := _beat_now()
	var flight := HOP_SECONDS if mode == "hop" else round_flight(length, beat)
	var fixed := int(row.get("beats", 0))
	var beats := _beats_in(flight, beat)
	if fixed > 0 and mode != "hop":
		beats = fixed
		flight = fixed * (beat if beat > 0.0 else FLIGHT_NO_MUSIC / NO_MUSIC_BEATS)
	var extra := int(knob("ult_beats", 0))
	if extra > 0:
		var each := flight / maxi(beats, 1)
		beats += extra
		flight += extra * each
	var legs := [{"mode": mode, "to": to, "beats": beats, "seconds": flight, "strike": true}]
	if mode == "rail":
		var first := maxi(1, beats / 3)
		var each := flight / maxi(beats, 1)
		legs = [{"mode": "arc", "to": found["entry"], "beats": first, "seconds": first * each, "strike": false},
			{"mode": "line", "to": to, "beats": beats - first, "seconds": (beats - first) * each, "strike": true}]
	return {"path": mode, "from": ball, "to": to, "target": found.get("target"), "beats": beats,
		"flight": flight, "seconds": windup_seconds() + flight, "legs": legs}


static func round_flight(length: float, beat: float) -> float:
	if beat <= 0.0:
		return FLIGHT_NO_MUSIC
	var raw := clampf(length / FLIGHT_SPEED, FLIGHT_MIN, FLIGHT_MAX)
	var beats := maxi(1, roundi(raw / beat))
	if beats * beat < FLIGHT_MIN - 0.0001:
		beats += 1
	if beats * beat > FLIGHT_MAX + 0.0001:
		beats -= 1
	return beats * beat


static func _beats_in(flight: float, beat: float) -> int:
	if beat <= 0.0:
		return NO_MUSIC_BEATS
	return maxi(1, roundi(flight / beat))


func _beat_now() -> float:
	return maxf(0.0, float(beat_seconds.call())) if beat_seconds.is_valid() else 0.0


func _aim_point(aim: Dictionary, reach: float):
	if not aim.has("origin") or not aim.has("forward"):
		return null
	var space := _space()
	if space == null:
		return null
	var from: Vector3 = aim["origin"]
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + (aim["forward"] as Vector3).normalized() * reach, Augments.WORLD_MASK))
	return hit["position"] if not hit.is_empty() else from + (aim["forward"] as Vector3).normalized() * reach


func _ground_hit(aim: Dictionary, reach: float):
	var space := _space()
	if space == null or not aim.has("origin"):
		return null
	var from: Vector3 = aim["origin"]
	var dir: Vector3 = (aim["forward"] as Vector3).normalized()
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + dir * (reach + 10.0), Augments.WORLD_MASK))
	if hit.is_empty() or (hit["normal"] as Vector3).y < 0.7:
		return null
	var at: Vector3 = hit["position"]
	if at.distance_to(ctx.player.ball_position()) > reach:
		return null
	return at


func _space() -> PhysicsDirectSpaceState3D:
	if ctx == null or ctx.root == null or not ctx.root.is_inside_tree():
		return null
	return ctx.root.get_world_3d().direct_space_state


func start(p: Dictionary) -> void:
	if p.is_empty() or not meter.spend():
		return
	_id = _ult_id()
	if _sable():
		stakes.begin()
		ctx.player.kit.mounted = false
		ctx.player.kit.slingshot.cancel()
		_lightning_peaks = 0
		_outpost_encore = false
		_outpost_second = false
	_plan = p
	last_plan = p
	_ult_buffer = 0.0
	meter.locked = true
	_was_full = false
	_phase = WINDUP
	_left = windup_seconds()
	_plant_from = ctx.player.planar_velocity().length()
	_leg = 0
	_ride = null
	_posture_spent = {}
	_peaked = false
	_offset = 0.0
	if ctx.player.kit.hooked:
		ctx.player.cut_line("ultimate")
	if ctx.spawner != null and ctx.spawner.fleet.holds.holding():
		combat.discover("set_piece_breakout", ctx.player.ball_position())
	_record = {"id": _id, "path": p["path"], "seconds": snappedf(float(p["seconds"]), 0.001), "heft_class": heft_index() + 1,
		"volley_hits": 0, "landing_hits": 0, "damage": 0.0, "bailed": false, "recalled": false,
		"fill_seconds": snappedf(_record_fill, 0.01)}
	if _sable():
		_record["stakes"] = 0
		_record["stakes_hooked"] = 0
	ctx.run.set_meta("ultimate_record", _record)
	_fill_since = _clock
	ctx.events.ultimate_started.emit(_id, String(p["path"]), p["from"], p["to"], float(p["seconds"]))
	_draw_path(p)


func _draw_path(p: Dictionary) -> void:
	if combat == null or combat.effects == null:
		return
	var from: Vector3 = p["from"]
	for leg in p["legs"]:
		combat.effects.arc(from + Vector3.UP * 0.5, (leg["to"] as Vector3) + Vector3.UP * 0.5, Palette.ARC)
		from = leg["to"]


func windup_seconds() -> float:
	return float(AbilityState.ABILITIES.get(_ult_id(), {}).get("cast", WINDUP_SECONDS))


func winding_up() -> bool:
	return _phase == WINDUP


func plants() -> bool:
	return bool(AbilityState.ABILITIES.get(_ult_id(), {}).get("plant", false))


func _plant() -> void:
	var v: Vector3 = ctx.player.state.velocity
	var flat := Vector3(v.x, 0.0, v.z)
	var into := windup_seconds() - _left
	var cap := _plant_from * maxf(0.0, 1.0 - into / PLANT_STOP_SECONDS)
	if flat.length() <= cap + 0.001:
		return
	flat = flat.normalized() * cap if cap > 0.0 else Vector3.ZERO
	ctx.player.set_velocity_now(Vector3(flat.x, v.y, flat.z), "ultimate")


func recall() -> void:
	if _phase != WINDUP:
		return
	_ult_buffer = 0.0
	meter.locked = false
	meter.refund(UltimateMeter.CAP)
	_was_full = true
	_record["recalled"] = true
	_end("recall", true)


func bail() -> void:
	if _phase != FLIGHT:
		return
	_record["bailed"] = true
	if _sable():
		stakes.arm()
	_end("bail", false)


func _abort(reason: String) -> void:
	_outpost_encore = false
	_ult_buffer = 0.0
	if _phase == IDLE:
		return
	if _phase == RECOVER:
		_phase = IDLE
		meter.locked = false
		return
	_end(reason, false)


func _end(reason: String, refunded: bool) -> void:
	_phase = IDLE
	_ride = null
	meter.locked = false
	ctx.run.set_meta("ultimate_record", _record)
	ctx.events.ultimate_cancelled.emit(_id, reason, refunded)


func _physics_process(delta: float) -> void:
	if ctx == null or ctx.run.class_def == null:
		return
	step(delta)


func _ult_bufferable() -> bool:
	if ctx.flow == null or not ctx.flow.in_play() or ctx.player.frozen():
		return false
	if ctx.flow.state_name() == "launch":
		return meter.full()
	if ctx.terrain != null and ctx.terrain.has_method("in_bay") and ctx.terrain.in_bay(ctx.player.ball_position()):
		return false
	return not meter.full() and UltimateMeter.CAP - meter.value <= 5.0


func step(delta: float) -> void:
	_clock += delta
	var player = ctx.player
	var intent = player.intent
	if intent.cancel_pressed:
		_ult_buffer = 0.0
	if _phase == IDLE:
		if _fills():
			meter.tick(delta, player.speed_tier())
			_check_full()
		var had_buffer := _ult_buffer > 0.0
		if had_buffer:
			_ult_buffer = maxf(0.0, _ult_buffer - delta)
		if intent.ultimate_pressed:
			if can_start() == "":
				_ult_buffer = 0.0
				press()
			elif _ult_bufferable():
				_ult_buffer = BallTuning.ACTION_BUFFER_S
			else:
				press()
		elif had_buffer:
			if can_start() == "":
				_ult_buffer = 0.0
				press()
			elif _ult_buffer <= 0.0 and ctx.flow != null and ctx.flow.in_play():
				press()
		return
	if _ult_buffer > 0.0:
		_ult_buffer = maxf(0.0, _ult_buffer - delta)
	if intent.ultimate_pressed:
		if _phase == WINDUP:
			recall()
			return
		if _phase == RECOVER and _left <= BallTuning.ACTION_BUFFER_S + 0.0001:
			_ult_buffer = BallTuning.ACTION_BUFFER_S
		else:
			ctx.events.verb_failed.emit("ultimate", "busy", player.ball_position())
	match _phase:
		WINDUP:
			_left -= delta
			if plants():
				_plant()
			if _left <= 0.0:
				_begin_flight()
		FLIGHT:
			if intent.jump_pressed:
				bail()
				return
			_fly(delta)
		RECOVER:
			_left -= delta
			if _left <= 0.0:
				_phase = IDLE
				meter.locked = false
				if _ult_buffer > 0.0 and can_start() == "":
					_ult_buffer = 0.0
					press()


func _begin_flight() -> void:
	_phase = FLIGHT
	var leg: Dictionary = _plan["legs"][_leg]
	_beats = int(leg["beats"])
	_beat_len = float(leg["seconds"]) / maxi(_beats, 1)
	_beat = 0
	_beat_clock = 0.0
	_ride = _carrier(ctx.player.ball_position(), leg)
	_leg_time = 0.0
	_expected = ctx.player.ball_position()
	ctx.player.set_velocity_now(_ride.velocity_at(0.0), "ultimate")


func _carrier(from: Vector3, leg: Dictionary):
	var to: Vector3 = leg["to"]
	var seconds: float = maxf(0.2, float(leg["seconds"]))
	var ride = RideRail.new()
	ride.kind = "ultimate"
	ride.origin = from
	ride.target = to
	ride.flight = seconds
	ride.active = true
	var flat := Vector3(to.x - from.x, 0.0, to.z - from.z)
	ride.heading = flat.normalized() if flat.length() > 0.01 else Vector3.FORWARD
	ride.release_speed = ctx.player.planar_velocity().length()
	if String(leg["mode"]) == "line":
		ride.mode = RideRail.LINE
		ride.velocity = (to - from) / seconds
	else:
		ride.mode = RideRail.ARC
		var g := GRAVITY
		if String(leg["mode"]) == "hop":
			g = 8.0 * HOP_HEIGHT / (seconds * seconds)
		if _id.begins_with("cannon_"):
			g = minf(g, 8.0 * Weapons.APEX_CAP / (seconds * seconds))
		ride.gravity = g
		ride.velocity = flat / seconds + Vector3.UP * ((to.y - from.y + 0.5 * g * seconds * seconds) / seconds)
	return ride


func _fly(delta: float) -> void:
	var player = ctx.player
	var ball: Vector3 = player.ball_position()
	if _leg_time > 0.1 and ball.distance_to(_expected) > BLOCKED:
		_land(ball)
		return
	_leg_time += delta
	_beat_clock += delta
	var beat_tolerance := 0.00001 if _sable() else 0.0
	while _beat_clock + beat_tolerance >= _beat_len and _beat < _beats:
		_beat_clock -= _beat_len
		_beat += 1
		_volley()
		if is_peak_beat(_beat):
			_peaked = true
			_peak(player.ball_position())
	var v = null
	if _sable() or _id.begins_with("cannon_"):
		_ride.time += delta
		if _ride.time < _ride.flight:
			v = _ride.velocity_at(_ride.time)
	else:
		v = _ride.step(delta)
	if v == null:
		_land(_ride.target)
		return
	var side := Vector3(-_ride.heading.z, 0.0, _ride.heading.x)
	var want: float = clampf(_offset + float(player.intent.move.x) * STEER_SPEED * delta, -CORRIDOR, CORRIDOR)
	var steer: float = (want - _offset) / delta if delta > 0.0 else 0.0
	_offset = want
	_expected = _ride.point_at(_ride.time) + side * _offset
	player.set_velocity_now(v + side * steer, "ultimate")


func _peak(at: Vector3) -> void:
	var row: Dictionary = _ult_rows.get(_id, {})
	if row.has("peak"):
		(row["peak"] as Callable).call(at)
	ctx.events.ultimate_peak.emit(_id, at)


func _volley() -> void:
	var row: Dictionary = _ult_rows.get(_id, {})
	if not row.has("tech"):
		return
	var hits: int = int((row["tech"] as Callable).call(_beat, ctx.player.ball_position(), ctx.aim_forward(), HEFT_MULT[heft_index()]))
	_record["volley_hits"] = int(_record.get("volley_hits", 0)) + hits


func _land(at: Vector3) -> void:
	var legs: Array = _plan["legs"]
	var leg: Dictionary = legs[_leg]
	_leg += 1
	if _leg == legs.size() and knob("ult_encore", false) and (not _sable() or (_leg == 1 and _id != "outpost")) and not (_id.begins_with("cannon_") and _cannon_encore):
		var next = _encore_target(at)
		if next != null:
			legs.append({"mode": "arc", "to": next, "beats": 2 if _sable() else _beats, "seconds": (2 if _sable() else _beats) * _beat_len, "strike": true})
	if bool(leg.get("strike", true)):
		_strike(at)
	if _leg < legs.size():
		_begin_flight()
		return
	var release: Vector3 = _ride.release_velocity() if _ride != null else Vector3.ZERO
	var row: Dictionary = _ult_rows.get(_id, {})
	if row.has("release"):
		release = row["release"].call(at, release)
	_ride = null
	ctx.player.set_velocity_now(release, "ultimate")
	_phase = RECOVER
	_left = RECOVER_SECONDS
	ctx.run.set_meta("ultimate_record", _record)


func _strike(at: Vector3) -> void:
	var chain_links: int = ctx.player.chain.combo
	var mult: float = ctx.player.pay_chain(at)
	var row: Dictionary = _ult_rows.get(_id, {})
	var result: Array = [0, 0.0]
	if row.has("landing"):
		result = (row["landing"] as Callable).call(at, HEFT_MULT[heft_index()], mult)
	if result.size() < 3:
		report_landing(_record, _id, at, result)
	if _id == "cable_run" and _leg >= (_plan.get("legs", []) as Array).size():
		_sable_runs += 1
		if ctx.codex != null and ctx.codex.known("set_piece"):
			combat.discover("cable_run", at)
		if _sable_runs >= 3:
			combat.discover("sable_cable_runs", at)
	combat.discover("set_piece", at)
	if chain_links >= 3:
		combat.discover("set_piece_cash_in", at)


func report_landing(record: Dictionary, id: String, at: Vector3, result: Array) -> void:
	record["landing_hits"] = int(record.get("landing_hits", 0)) + int(result[0])
	record["damage"] = snappedf(float(record.get("damage", 0.0)) + float(result[1]), 0.01)
	if float(result[1]) > 0.0:
		preload("res://src/build/consumables.gd").echo_ultimate(ctx, combat, float(result[1]), at, landing_radius())
	ctx.events.ultimate_landed.emit(id, at, int(result[0]), float(result[1]))


func _encore_target(at: Vector3):
	var best = null
	var gap := ENCORE_REACH
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy) or (enemy.has_method("is_dead") and enemy.is_dead()):
			continue
		var d: float = enemy.global_position.distance_to(at)
		if d > 1.0 and d <= gap:
			gap = d
			best = enemy.global_position
	return best


func landing_radius() -> float:
	return LANDING_RADIUS[heft_index()] + float(knob("ult_radius", 0.0))


func volley_targets() -> int:
	return VOLLEY_TARGETS + int(knob("ult_volley", 0))


func defend(amount: float, hp: float) -> float:
	if not active():
		return amount
	return clampf(amount * DAMAGE_TAKEN, 0.0, maxf(0.0, hp - 1.0))


static func warden_cap(monster: bool) -> float:
	return WARDEN_POSTURE_CAP if monster else WARDEN_POSTURE_CAP_ORDINARY


static func cap_for_warden(warden: Node) -> float:
	return warden_cap(warden.monster_build() if warden.has_method("monster_build") else false)


func warden_posture(warden: Node3D, result: Dictionary) -> void:
	var id := warden.get_instance_id()
	var spent := float(_posture_spent.get(id, 0.0))
	var gain := minf(float(result.get("gain", 0.0)), maxf(0.0, cap_for_warden(warden) - spent))
	result["gain"] = gain
	result["shatter"] = false
	result["crack"] = false
	_posture_spent[id] = spent + gain
	warden.apply_posture_hit(result)


var stakes
var _sable_runs := 0
var _lightning_peaks := 0
var _outpost_encore := false
var _outpost_at := Vector3.ZERO
var _outpost_second := false
var _outpost_until := 0.0


func _sable() -> bool:
	return _id in ["cable_run", "ball_lightning", "outpost"]


func _sable_tech(beat: int, ball: Vector3, _aim: Vector3, heft_mult: float) -> int:
	return stakes.beat(beat, ball, heft_mult)


func _sable_peak(_at: Vector3) -> void:
	_record["volley_hits"] = int(_record.get("volley_hits", 0)) + stakes.relay()


func _sable_damage(at: Vector3, radius: float, damage: float, limit := 64, landing := true) -> Array:
	combat.effects.ring(at, radius, Palette.ARC)
	var hits := 0
	var dealt := 0.0
	for enemy in combat.nearest_enemies(at, radius, limit):
		dealt += combat.ult_hit(enemy, "arc", damage, at, landing)
		hits += 1
	return [hits, dealt]


func _landing_damage(at: Vector3, radius: float, damage: float) -> Array:
	ctx.break_props(at, radius, "ultimate")
	return _sable_damage(at, radius, damage)


func _sable_landing(at: Vector3, heft_mult: float, chain_mult: float) -> Array:
	stakes.plant(at)
	stakes.arm()
	return _landing_damage(at, landing_radius(), LANDING_DAMAGE * heft_mult * chain_mult * (0.5 if _leg > 1 else 1.0))


func _lightning_tech(beat: int, ball: Vector3, _aim: Vector3, heft_mult: float) -> int:
	var space := _space()
	if space == null:
		return 0
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(ball, ball + Vector3.DOWN * 40.0, Augments.WORLD_MASK))
	if hit.is_empty():
		return 0
	stakes._note("rain", beat)
	return int(_sable_damage(hit["position"], 6.0, 12.0 * heft_mult, volley_targets(), false)[0])


func _lightning_peak(at: Vector3) -> void:
	_lightning_peaks += 1
	var burst := Weapons.burst(20.0)
	var result := _sable_damage(at, float(burst["radius"]) + float(knob("ult_radius", 0.0)),
		float(burst["damage"]) * HEFT_MULT[heft_index()], int(burst["targets"]) + int(knob("ult_volley", 0)), false)
	_record["volley_hits"] = int(_record.get("volley_hits", 0)) + int(result[0])


func _lightning_landing(at: Vector3, heft_mult: float, chain_mult: float) -> Array:
	ctx.player._tag_faces(at)
	ctx.player.state.air_actions = 1
	return _landing_damage(at, landing_radius() + 3.0, LANDING_DAMAGE * heft_mult * chain_mult * (0.5 if _leg > 1 else 1.0))


func _outpost_landing(at: Vector3, heft_mult: float, chain_mult: float) -> Array:
	if _outpost_second:
		return _landing_damage(at, landing_radius(), LANDING_DAMAGE * heft_mult * chain_mult * 0.5)
	stakes.plant(at)
	stakes.arm()
	stakes.start_sentries(_beat_len, heft_mult)
	var speed := _sable_flight_speed()
	var burst := Weapons.burst(speed)
	var result := _sable_damage(at, float(burst["radius"]) + float(knob("ult_radius", 0.0)),
		float(burst["damage"]) * heft_mult * chain_mult, int(burst["targets"]))
	combat.last_burst = burst.duplicate()
	combat.last_burst["at"] = at
	combat.last_burst["hit"] = int(result[0])
	combat.last_burst["kind"] = "turret"
	ctx.events.special_used.emit("detonation_gauge", at)
	_outpost_at = at
	_outpost_until = _clock + Stakes.SENTRY_SECONDS
	_outpost_encore = bool(knob("ult_encore", false))
	return result


func _sable_normal(at: Vector3) -> Vector3:
	var space := _space()
	if space != null:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.5, at + Vector3.DOWN * 3.0, Augments.WORLD_MASK))
		if not hit.is_empty():
			return hit["normal"]
		var from: Vector3 = _plan.get("from", at + Vector3.UP)
		var direction := (at - from).normalized()
		hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(at - direction * 2.0, at + direction * 2.0, Augments.WORLD_MASK))
		if not hit.is_empty():
			return hit["normal"]
	return Vector3.UP


func _sable_flight_speed() -> float:
	return _ride.velocity.length() if _ride != null else FLIGHT_SPEED


func _sable_release(at: Vector3, release: Vector3) -> Vector3:
	var player = ctx.player
	if _id == "ball_lightning":
		return Vector3(release.x, 8.0, release.z)
	var normal := _sable_normal(at)
	var speed := _sable_flight_speed()
	if _id == "outpost" and not _outpost_second:
		Augments.mount_outpost(player.kit, player.state, at, normal, speed)
		ctx.events.mounted.emit(at, speed)
		return Vector3.ZERO
	var blazing: float = player.tuning.f("cruise") * 1.9 + 0.5
	var exit := clampf((speed * 0.85 + 6.0) * 1.3, blazing, 45.0)
	exit += Augments.mass_spend(player.kit, exit)
	var launch := Augments.mount_exit_direction(normal, player.drive_basis) * exit
	ctx.events.dismounted.emit(launch)
	return launch


func _outpost_depart(velocity: Vector3) -> void:
	if not _outpost_encore or _clock > _outpost_until or velocity.length() < 0.1:
		return
	if _phase != IDLE and _phase != RECOVER:
		return
	if ctx.flow == null or not ctx.flow.in_play() or ctx.player.frozen():
		return
	_outpost_encore = false
	var target = _encore_target(_outpost_at)
	if target == null:
		return
	_outpost_second = true
	_id = "outpost"
	meter.locked = true
	_leg = 0
	_peaked = true
	_offset = 0.0
	var seconds := 2.0 * _beat_len
	_plan = {"from": ctx.player.ball_position(), "to": target, "path": "arc",
		"legs": [{"mode": "arc", "to": target, "beats": 2, "seconds": seconds, "strike": true}]}
	_draw_path(_plan)
	_begin_flight()


var _cannon_id := ""
var _cannon_due := -1.0
var _cannon_calls := 0
var _cannon_cursor := 0
var _cannon_budget := {}
var _cannon_peak_done := false
var _cannon_encore := false
var _cannon_record := {}


func _cannon_started(id: String, _path: String, _from: Vector3, _to: Vector3, _seconds: float) -> void:
	if not id.begins_with("cannon_"):
		return
	_cannon_id = id
	_cannon_due = -1.0
	_cannon_calls = 0
	_cannon_cursor = 0
	_cannon_budget = _posture_spent
	_cannon_peak_done = false
	_cannon_encore = false
	_cannon_record = _record
	_cannon_record["zones"] = 0
	_cannon_record["zone_hits"] = 0


func _cannon_mortar_target(_ball: Vector3, aim: Dictionary) -> Dictionary:
	var ground = _ground_hit(aim, ARC_REACH[heft_index()] * Weapons.MORTAR_REACH)
	return {"path": "arc", "to": ground} if ground != null else {"path": "hop", "to": ctx.player.ball_position()}


func _cannon_projection(ball: Vector3) -> Vector3:
	if _ride != null and _ride.mode == RideRail.ARC:
		var t := clampf(_ride.time, 0.0, _ride.flight)
		ball.y -= 0.5 * _ride.gravity * t * (_ride.flight - t)
	return ball


func _cannon_target(centre: Vector3, aim: Vector3, reach: float) -> Vector3:
	var found := centre + Vector3(aim.x, 0.0, aim.z).normalized() * 8.0
	var best := reach
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy) or (enemy.has_method("is_dead") and enemy.is_dead()):
			continue
		var to: Vector3 = enemy.global_position - centre
		var flat := Vector3(to.x, 0.0, to.z)
		var sight: Vector3 = enemy.global_position - ctx.player.ball_position()
		if flat.length() <= best and (aim.length() < 0.01 or sight.length() < 0.01 or aim.angle_to(sight) <= deg_to_rad(VOLLEY_BIAS_DEG)):
			best = flat.length()
			found = enemy.global_position
	return found


func _cannon_call(family: String, at: Vector3, target: Vector3, due: float, heft: float, options := {}) -> bool:
	var cap := Weapons.CALL_CAP if _cannon_peak_done else Weapons.CALL_CAP - 4
	if _cannon_calls >= cap:
		return false
	var floor = combat.cannon.cannon_floor(at)
	if floor == null:
		return false
	var overrides := {"warn": maxf(0.0, due - combat.clock_now()), "live_at": due,
		"budget": _cannon_budget, "record": _cannon_record}
	overrides.merge(options, true)
	combat.cannon.commit_cannon(family, target, floor, Weapons.ZONE_REACH, Weapons.ZONE_DAMAGE * heft,
		"special", family == "plate", overrides)
	_cannon_calls += 1
	_cannon_record["zones"] = int(_cannon_record.get("zones", 0)) + 1
	var audio = combat.cannon.cannon_audio()
	if audio != null:
		audio.cannon_family(family, false, "cannon_call")
	return true


func _cannon_tech(beat: int, ball: Vector3, aim: Vector3, heft: float) -> int:
	if beat >= _beats:
		return 0
	if _cannon_due < 0.0:
		_cannon_due = combat.clock_now() + maxf(0.0, float(_plan["legs"][_leg]["seconds"]) - _leg_time)
	var centre := _cannon_projection(ball)
	var middle := ceili(_beats / 2.0)
	if _cannon_id == "cannon_fire_mission":
		if beat == middle:
			return 0
		var family: String = preload("res://src/boss/mind_attacks.gd").FAMILIES[_cannon_cursor % 4]
		_cannon_cursor += 1
		_cannon_call(family, centre, _cannon_target(centre, aim, Weapons.ZONE_REACH), _cannon_due, heft)
	elif _cannon_id == "cannon_creeping_barrage":
		var velocity: Vector3 = _ride.velocity_at(_ride.time) if _ride != null else ctx.player.planar_velocity()
		velocity.y = 0.0
		var ahead := centre + velocity * Weapons.CREEP_AHEAD_BEATS * _beat_len
		var side := Vector3.UP.cross(velocity.normalized())
		if side.length() < 0.01:
			side = Vector3.RIGHT
		for i in 1 + int(knob("ult_volley", 0)):
			var at := ahead + velocity.normalized() * 6.0 * i
			_cannon_call("lane", at - side * 12.2, at + side * 12.2, combat.clock_now() + _beat_len, heft)
	else:
		for i in 1 + int(knob("ult_volley", 0)):
			var target := _cannon_target(centre, aim, 16.0)
			if i > 0:
				target = centre * 2.0 - target
			_cannon_call("plate", centre, target, combat.clock_now() + _beat_len, heft)
	return 0


func _cannon_peak(_at: Vector3) -> void:
	_cannon_peak_done = true
	var heft: float = HEFT_MULT[heft_index()]
	var at: Vector3 = _plan["legs"][_leg]["to"]
	if _cannon_id == "cannon_fire_mission":
		for family in preload("res://src/boss/mind_attacks.gd").FAMILIES:
			_cannon_call(family, at, _cannon_target(at, ctx.aim_forward(), Weapons.ZONE_REACH), _cannon_due, heft)
	elif _cannon_id == "cannon_creeping_barrage":
		var ball := _cannon_projection(ctx.player.ball_position())
		_cannon_call("split_lane", ball, ball + _ride.heading * 10.0, combat.clock_now() + _beat_len, heft)
	else:
		var target := _cannon_target(at, ctx.aim_forward(), 16.0)
		var radius := Vector2(target.x - at.x, target.z - at.z).length()
		var half := preload("res://src/boss/mind_attacks.gd").RUSH_HALF_BAND + float(knob("ult_radius", 0.0))
		_cannon_call("rush", at, target, _cannon_due, heft, {"band": Vector2(maxf(0.0, radius - half), minf(Weapons.ZONE_REACH, radius + half))})


func _cannon_landing(at: Vector3, heft: float, chain: float) -> Array:
	combat.cannon.step_cannon(0.0)
	var mortar := _cannon_id == "cannon_plate_mortar"
	var hits := 0
	var damage := 0.0
	var scale := 0.5 if _cannon_encore else 1.0
	combat.effects.ring(at, landing_radius(), Palette.ANCIENT)
	ctx.break_props(at, landing_radius(), "ultimate")
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy) or (enemy.has_method("is_dead") and enemy.is_dead()) or enemy.global_position.distance_to(at) > landing_radius():
			continue
		damage += combat.cannon_set_piece_hit(enemy, LANDING_DAMAGE * heft * chain * scale, at, true, mortar, _cannon_budget)
		hits += 1
	var discovery := _cannon_id
	if ctx.codex != null and ctx.codex.known("set_piece"):
		match discovery:
			"cannon_fire_mission":
				combat.discover("cannon_fire_mission", at)
			"cannon_creeping_barrage":
				combat.discover("cannon_creeping_barrage", at)
			"cannon_plate_mortar":
				combat.discover("cannon_plate_mortar", at)
	if _cannon_id == "cannon_fire_mission" and hits >= 8:
		combat.discover("cannon_time_on_target", at)
	if _cannon_id == "cannon_creeping_barrage":
		var heading: Vector3 = _ride.heading if _ride != null else Vector3.FORWARD
		_cannon_call("lane", at, at + heading * 24.4, combat.clock_now() + _beat_len, heft)
	if _leg < _plan["legs"].size():
		var leg: Dictionary = _plan["legs"][_leg]
		leg["mode"] = "line" if _cannon_id == "cannon_creeping_barrage" else "arc"
		leg["beats"] = 4
		leg["seconds"] = 4.0 * _beat_len
		_cannon_encore = true
		_cannon_due = -1.0
		_cannon_calls = 0
		_cannon_peak_done = false
		_peaked = false
	return [hits, damage]
