extends "res://src/combat/ultimate.gd"

const Sticky := preload("res://src/combat/sticky.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Groups := preload("res://src/core/groups.gd")
const Devices := preload("res://src/core/devices.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")

const IDS := ["windhover", "air_raid", "minelayer"]
const CABLE_SPEED := 60.0
const CABLE_DAMAGE := 28.0
const CABLE_RADIUS := 4.0
const BODY_FUSE := 2.0
const WALL_FUSE := 6.0
const HOVER_HEIGHT := 14.0
const HOVER_RADIUS := 15.0
const MINE_CAP := Devices.KEST_MINE_CAP
const MINE_FUSE := Devices.ROWS[Devices.KEST_MINE]["lifetime"]
const MINE_REACH := 2.0
const NOTES := [62, 57, 53]
const LOG_CAP := 2048

var payloads
var cable := {}
var _loaded_cable := false
var _cable_burst := false
var _cast := {}
var _groups: Array = []
var _heavy := {}
var _mines: Array = []
var _rolls: Array = []
var roll_log: Array = []
var volley_log: Array = []
var _half_clock := 0.0
var _total_beat := 0
var _encored := false
var _banked_speed := 0.0
var _exit_heading := Vector3.FORWARD
var _landed_at := -INF
var _last_throw := -INF
var _cards_pending := {}
var _last_discovery_frame := -1


static func line_row(combat_ref) -> Dictionary:
	return {"on_body": func(body: Node3D, fraction: float, mult: float): combat_ref.ultimate.cable_body(body, fraction, mult),
		"on_world": func(at: Vector3, fraction: float, mult: float): combat_ref.ultimate.cable_world(at, fraction, mult),
		"geometry": func(fraction: float): return combat_ref.ultimate.cable_geometry(fraction)}


func setup(ctx_ref, combat_ref) -> void:
	super.setup(ctx_ref, combat_ref)
	register_kest()


func register_kest() -> void:
	payloads = Sticky.new()
	payloads.name = "KestPayloads"
	add_child(payloads)
	for id in IDS:
		register(id, {"tech": tech, "peak": peak, "landing": landing})
	ctx.events.line_skill_loaded.connect(func(id: String, _seconds: float):
		if id == "cable_charge":
			_loaded_cable = true)
	ctx.events.line_skill_expired.connect(func(id: String):
		if id == "cable_charge":
			_loaded_cable = false)
	ctx.events.line_skill_fired.connect(func(id: String, _body: Node3D, at: Vector3, _on: String):
		if id == "cable_charge":
			_queue_discover("kest_cable_charge", at, "loaded_line" if cable.get("_loaded", false) else ""))
	ctx.events.ultimate_landed.connect(func(id: String, at: Vector3, _hits: int, _damage: float):
		if id == "windhover":
			_queue_discover("kest_windhover", at, "set_piece"))
	ctx.events.line_state_changed.connect(func(state: String, _body: Node3D, _at: Vector3, _cause: String):
		if state in ["let_go", "broke"]:
			_end_cable())
	ctx.events.harpoon_smashed.connect(func(_body: Node3D, _at: Vector3, _speed: float): _end_cable())
	ctx.events.rocket_jumped.connect(func(at: Vector3, _speed: float):
		if _cable_burst:
			_queue_discover("kest_blast_vault", at))
	ctx.events.synergy_discovered.connect(func(_id: String, _category: String, _first: bool):
		_last_discovery_frame = Engine.get_physics_frames())
	ctx.events.world_entered.connect(homecoming)
	ctx.events.stage_content_cleared.connect(func(_reason: String): clear_payloads())
	ctx.events.run_ended.connect(func(_won: bool): clear_payloads())
	ctx.events.player_died.connect(clear_payloads)
	ctx.events.run_started.connect(func(_class_id: String):
		clear_payloads()
		_cards_pending = {})


static func targets_for_class(heft_class: int) -> int:
	return 4 if heft_class >= 4 else 3


static func minis_per_throw(heft_class: int) -> int:
	return targets_for_class(heft_class)


func volley_targets() -> int:
	if _ult_id() not in IDS:
		return super.volley_targets()
	return targets_for_class(heft_index() + 1) + int(knob("ult_volley", 0))


func homecoming(world: int) -> void:
	if world == 3 and ctx.run.class_def != null and ctx.run.class_def.id == "demolitions_caster":
		_queue_discover("kest_homecoming", ctx.player.ball_position())


func _queue_discover(id: String, at: Vector3, framework := "") -> void:
	if not combat.discovered.has(id) and not _cards_pending.has(id):
		_cards_pending[id] = {"at": at, "frame": Engine.get_physics_frames(), "framework": framework}


func flush_discoveries() -> void:
	var frame := Engine.get_physics_frames()
	if frame <= _last_discovery_frame:
		return
	for id in _cards_pending.keys():
		var row: Dictionary = _cards_pending[id]
		if frame <= int(row["frame"]) or (row["framework"] != "" and not ctx.codex.known(row["framework"])):
			continue
		_cards_pending.erase(id)
		combat.discover(id, row["at"])
		break


func clear_payloads() -> void:
	if payloads != null:
		for charge in payloads.charges:
			combat.devices.remove(int(charge.get("device_id", 0)))
		payloads.clear()
	cable = {}
	_loaded_cable = false
	_groups = []
	_heavy = {}
	_mines = []
	_rolls = []
	roll_log.clear()
	volley_log.clear()
	_cast = {}
	ctx.player.indicator.clear("kest_caught")
	ctx.player.indicator.clear("kest_cable")


func cable_body(body: Node3D, _fraction: float, _mult: float) -> void:
	_cable(ctx.player.kit.anchor, body)


func cable_world(at: Vector3, _fraction: float, _mult: float) -> void:
	_cable(at, null)


func _cable(at: Vector3, rider: Node3D) -> void:
	_end_cable()
	var loaded := _loaded_cable
	_loaded_cable = false
	var travel: float = 0.0 if loaded else ctx.player.ball_position().distance_to(at) / CABLE_SPEED
	cable = payloads.drop(ctx.player.ball_position() if travel > 0.0 else at,
		CABLE_DAMAGE, CABLE_RADIUS, INF, INF)
	cable["_source"] = "line"
	cable["_loaded"] = loaded
	cable["_cable"] = true
	cable["_travel"] = travel
	cable["_duration"] = travel
	cable["_anchor"] = at
	cable["_body"] = rider
	cable["_start"] = ctx.player.ball_position()
	cable["_fuse"] = BODY_FUSE if rider != null else WALL_FUSE
	_sound("cable_kest_fizz", false, pow(2.0, float(maxi(ctx.player.chain.combo - 1, 0)) / 12.0))
	if travel <= 0.0:
		_set_cable()
	if rider == null:
		ctx.player.refresh_air_draw()
		if at.y > ctx.player.ball_position().y + 1.0:
			ctx.player.apply_spire_vault(at)
	combat.refresh_kest_fuse_trace()
	ctx.player.indicator.set_shape("kest_cable", cable_geometry(1.0))


func _set_cable() -> void:
	cable["pos"] = cable["_anchor"]
	cable["rider"] = cable["_body"]
	cable["damage"] = CABLE_DAMAGE * ctx.player.chain.multiplier()
	cable["born"] = combat.clock_now()
	cable["fuse"] = cable["_fuse"]
	cable["_set"] = true
	_sound("cable_kest_set")


func cable_geometry(_fraction: float) -> Dictionary:
	var at: Vector3 = ctx.player.kit.anchor if ctx.player.kit.hooked else ctx.player.ball_position()
	return ctx.player.yours({"kind": "ring", "centre": at, "radius": CABLE_RADIUS, "fill": 1.0})


func _end_cable() -> void:
	if cable.is_empty():
		return
	var c := cable
	var was_world: bool = c.get("_body") == null
	var anchor_pt: Vector3 = c.get("_anchor", Vector3.ZERO)
	cable = {}
	ctx.player.indicator.clear("kest_cable")
	var rocket_before: float = combat.rocket_left()
	if payloads.charges.has(c):
		if not c.get("_set", false):
			c["pos"] = c["_anchor"]
			c["damage"] = CABLE_DAMAGE * ctx.player.chain.multiplier()
		_detonate_payload(_take_payload(c))
	if was_world and ctx != null and ctx.player != null:
		ctx.player.refresh_air_draw()
		if combat.rocket_left() <= rocket_before and not ctx.player.state.grounded:
			ctx.player.apply_spire_vault(anchor_pt)


func plan(ball: Vector3, aim: Dictionary, paths: Array = []) -> Dictionary:
	var id := _ult_id()
	if id not in IDS:
		return super.plan(ball, aim, paths)
	var p := super.plan(ball, aim, paths)
	if ctx.player.kit.hooked and id != "minelayer":
		p["path"] = "arc"
		p["to"] = ctx.player.kit.anchor
		p["target"] = ctx.player.kit.anchor_body if ctx.player.kit.on_body else null
		var seconds := round_flight(ball.distance_to(p["to"]), _beat_now())
		var count := _beats_in(seconds, _beat_now())
		var each := seconds / count
		count += int(knob("ult_beats", 0))
		p["beats"] = count
		p["flight"] = count * each
		p["seconds"] = windup_seconds() + p["flight"]
		p["legs"] = [{"mode": "arc", "to": p["to"], "beats": count, "seconds": count * each, "strike": true}]
	if id == "windhover" and p["path"] != "hop":
		var b: Vector3 = p["to"]
		var h := b + Vector3.UP * HOVER_HEIGHT
		var each := float(p["flight"]) / int(p["beats"])
		var arc_beats := maxi(1, int(p["beats"]) - 1)
		p["path"] = "arc"
		p["hover"] = h
		p["legs"] = [{"mode": "arc", "to": h, "beats": arc_beats, "seconds": arc_beats * each, "strike": false},
			{"mode": "hold", "to": h, "beats": 2, "seconds": 2 * each, "strike": false},
			{"mode": "line", "to": b, "beats": 1, "seconds": each, "strike": true}]
		p["beats"] = arc_beats + 3
		p["flight"] = (arc_beats + 3) * each
		p["seconds"] = windup_seconds() + p["flight"]
	return p


func start(p: Dictionary) -> void:
	if _ult_id() not in IDS:
		super.start(p)
		return
	if not meter.full() or p.is_empty():
		return
	_groups = []
	_heavy = {}
	_mines = []
	_cast = {"id": _ult_id(), "targets": {}, "landed": false, "posture": {}}
	_total_beat = 0
	_encored = false
	_banked_speed = ctx.player.planar_velocity().length()
	var heading: Vector3 = p["to"] - p["from"]
	heading.y = 0.0
	_exit_heading = heading.normalized() if heading.length() > 0.01 else Vector3.FORWARD
	super.start(p)
	_cast["posture"] = _posture_spent
	_hold_cloak()


func _carrier(from: Vector3, leg: Dictionary):
	if String(leg["mode"]) != "hold":
		return super._carrier(from, leg)
	var hold := leg.duplicate()
	hold["mode"] = "line"
	return super._carrier(from, hold)


func _begin_flight() -> void:
	super._begin_flight()
	_half_clock = 0.0


func _fly(delta: float) -> void:
	if _id not in IDS:
		super._fly(delta)
		return
	var player = ctx.player
	var ball: Vector3 = player.ball_position()
	if _leg_time > 0.1 and ball.distance_to(_expected) > BLOCKED:
		_land(ball)
		return
	_leg_time += delta
	_beat_clock += delta
	_half_clock += delta
	var leg: Dictionary = _plan["legs"][_leg]
	if _id == "minelayer":
		while _half_clock >= _beat_len * 0.5:
			_half_clock -= _beat_len * 0.5
			_drop_mines(ball, HEFT_MULT[heft_index()])
	while _beat_clock >= _beat_len and _beat < _beats:
		_beat_clock -= _beat_len
		_beat += 1
		_total_beat += 1
		if _id != "windhover" or String(leg["mode"]) != "line":
			_volley()
		var peak_now: bool = String(leg["mode"]) == "hold" if _id == "windhover" and _plan.has("hover") else _beat >= ceili(_beats / 2.0)
		if not _peaked and peak_now:
			_peaked = true
			_peak(ball)
	var v = _ride.step(delta)
	if v == null:
		_land(_ride.target)
		return
	var side := Vector3(-_ride.heading.z, 0.0, _ride.heading.x)
	var want: float = clampf(_offset + float(player.intent.move.x) * STEER_SPEED * delta, -CORRIDOR, CORRIDOR)
	var steer: float = (want - _offset) / delta if delta > 0.0 else 0.0
	_offset = want
	_expected = _ride.point_at(_ride.time) + side * _offset
	player.set_velocity_now(v + side * steer, "ultimate")


func _land(at: Vector3) -> void:
	if _id not in IDS:
		super._land(at)
		return
	var legs: Array = _plan["legs"]
	var leg: Dictionary = legs[_leg]
	_leg += 1
	if bool(leg.get("strike", true)):
		_strike(at)
		if _leg == legs.size() and not _encored and bool(knob("ult_encore", false)):
			var next = _encore_target(at)
			if next != null:
				_encored = true
				var mode := "line" if _id == "minelayer" else "arc"
				legs.append({"mode": mode, "to": next, "beats": 4, "seconds": 4 * _beat_len, "strike": true})
	if _leg < legs.size():
		ctx.player.body().global_position = at
		_offset = 0.0
		_begin_flight()
		return
	_ride = null
	ctx.player.set_velocity_now(_exit_heading * _banked_speed, "ultimate")
	_phase = RECOVER
	_left = RECOVER_SECONDS
	ctx.run.set_meta("ultimate_record", _record)
	combat.cloak_left = Weapons.CLOAK_SECONDS
	ctx.player.kit.cloaked = true
	_landed_at = _clock


func _draw_path(p: Dictionary) -> void:
	if _ult_id() not in IDS:
		super._draw_path(p)
		return
	var from: Vector3 = p["from"]
	for leg in p["legs"]:
		var ride = _carrier(from, leg)
		if String(leg["mode"]) == "hold":
			combat.effects.ring(leg["to"], 1.0, Palette.ARC)
		else:
			for i in 16:
				combat.effects.arc(ride.point_at(ride.flight * i / 16.0), ride.point_at(ride.flight * (i + 1) / 16.0), Palette.ARC)
		from = leg["to"]
	combat.effects.ring(p["to"], landing_radius() + (1.0 if _ult_id() == "windhover" else 0.0), Palette.ARC)


func tech(_beat_number: int, ball: Vector3, aim: Vector3, heft_mult: float) -> int:
	_last_throw = _clock
	if _id == "minelayer":
		return 0
	if _id == "air_raid":
		var spot := _throw_point(ball)
		var group: Array = []
		var count := minis_per_throw(heft_index() + 1) + int(knob("ult_volley", 0))
		for i in count:
			var angle := TAU * i / count
			group.append(_drop(spot + Vector3(cos(angle), 0.0, sin(angle)) * 3.0, 12.0 * heft_mult, 2.5))
		_groups.append(group)
		_sound("raid_kest_tick")
		return 0
	var picks: Array = []
	var b: Vector3 = _plan["to"]
	for enemy in get_tree().get_nodes_in_group(Groups.ENEMY):
		if not is_instance_valid(enemy) or enemy.is_dead() or enemy.global_position.distance_to(b) > HOVER_RADIUS:
			continue
		var to: Vector3 = enemy.global_position - ball
		var bias := 0.0 if aim.length() > 0.01 and to.length() > 0.01 and aim.angle_to(to) <= deg_to_rad(VOLLEY_BIAS_DEG) else 100.0
		picks.append([bias + to.length(), enemy])
	picks.sort_custom(func(a, other): return a[0] < other[0])
	var targets: Array = picks.slice(0, volley_targets())
	if targets.is_empty():
		_shell(ball, b, heft_mult)
	for pick in targets:
		_shell(ball, pick[1].global_position, heft_mult)
	if volley_log.size() >= LOG_CAP:
		volley_log.pop_front()
	volley_log.append({"beat": _total_beat, "targets": targets.size(), "centre": b})
	_sound("tick_kest_%d" % NOTES[posmod(_total_beat - 1, NOTES.size())])
	return 0


func _shell(ball: Vector3, at: Vector3, mult: float) -> void:
	var charge: Dictionary = payloads.throw(ball, at, 12.0 * mult, 3.0, 0.6, false, Sticky.CONTACT_REACH, combat.clock_now())
	_tag(charge)
	combat.effects.ring(at, 3.0, ClassDef.KEST_COLOR)


func _throw_point(ball: Vector3) -> Vector3:
	var track: Vector3 = combat.floor_at(ball)
	var aim = _ground_hit(_live_aim(), ARC_REACH[heft_index()])
	if aim == null:
		return track
	var flat: Vector3 = aim - track
	flat.y = 0.0
	return combat.floor_at(track + flat.limit_length(12.0))


func _tag(charge: Dictionary) -> void:
	charge["_source"] = "ultimate"
	charge["_kest_cast"] = _cast
	charge["proc_coeff"] = 0.25


func _drop(at: Vector3, damage: float, radius: float) -> Dictionary:
	var kind := Devices.KEST_MINE if _id == "minelayer" else Devices.KEST_RAID
	var placed: Dictionary = combat.devices.deploy(kind, at)
	for id in placed["evicted"]:
		for old in payloads.charges.duplicate():
			if int(old.get("device_id", 0)) != int(id):
				continue
			if kind == Devices.KEST_MINE:
				_detonate_payload(_take_payload(old))
			else:
				_take_payload(old)
	if int(placed["id"]) == 0:
		return {}
	var c: Dictionary = payloads.drop(at, damage, radius, INF, INF, MINE_REACH, combat.clock_now())
	c["device_id"] = int(placed["id"])
	var node: Node3D = c["node"]
	node.tree_exiting.connect(func():
		combat.devices.remove(int(c["device_id"]))
		payloads.charges.erase(c))
	_tag(c)
	c["_inert"] = true
	return c


func _drop_mines(ball: Vector3, mult: float) -> void:
	var count := 2 if int(knob("ult_volley", 0)) > 0 else 1
	for i in count:
		var at: Vector3 = combat.floor_at(ball) + Vector3(1.5 * (i - 0.5) if count == 2 else 0.0, 0.0, 0.0)
		_mines.append(_drop(at, 10.0 * mult, 2.5))
		_bound_mines()
	_sound("raid_kest_tick")


func _bound_mines() -> void:
	_mines = _mines.filter(func(c): return payloads.charges.has(c))
	while _mines.size() > MINE_CAP:
		var oldest: Dictionary = _mines.pop_front()
		oldest["_inert"] = false
		_detonate_payload(_take_payload(oldest))


func peak(at: Vector3) -> void:
	_hold_cloak()
	combat.effects.ring(at, 3.0, ClassDef.KEST_COLOR)
	if _id != "windhover":
		_heavy = _drop(_throw_point(at) if _id == "air_raid" else combat.floor_at(at), 30.0 * HEFT_MULT[heft_index()], 5.0)
		if _id == "minelayer":
			_mines.append(_heavy)
			_bound_mines()


func landing(at: Vector3, heft_mult: float, chain_mult: float) -> Array:
	var radius := landing_radius() + (1.0 if _id == "windhover" else 0.0)
	var damage := LANDING_DAMAGE * heft_mult * chain_mult * (1.25 if _id == "windhover" else 1.0)
	var hits := 0
	var dealt := 0.0
	_cast["landed"] = true
	combat.effects.ring(at, radius, ClassDef.KEST_COLOR)
	ctx.break_props(at, radius, "ultimate")
	for enemy in get_tree().get_nodes_in_group(Groups.ENEMY):
		if not is_instance_valid(enemy) or enemy.is_dead() or enemy.global_position.distance_to(at) > radius:
			continue
		_note_target(enemy, _cast)
		dealt += combat.ult_hit(enemy, "ultimate", damage, at, true)
		hits += 1
	if _id == "minelayer":
		for c in _mines:
			if payloads.charges.has(c) and c.get("_inert", false):
				c["_inert"] = false
				c["arm"] = 0.0
				c["fuse"] = MINE_FUSE
	if _id == "air_raid":
		if payloads.charges.has(_heavy):
			_heavy["_inert"] = false
			_detonate_payload(_take_payload(_heavy))
		var eighth := _beat_len * 0.5
		var first := (floorf(RECOVER_SECONDS / eighth) + 1.0) * eighth
		for i in _groups.size():
			_rolls.append({"at": _clock + first + i * eighth, "group": _groups[_groups.size() - i - 1], "index": _groups.size() - i - 1})
		_groups = []
	_check_grant(_cast, at)
	return [hits, dealt]


func _note_target(enemy: Node3D, cast: Dictionary) -> void:
	if cast.is_empty():
		return
	cast["targets"][enemy.get_instance_id()] = true
	_check_grant(cast, enemy.global_position)


func _check_grant(cast: Dictionary, at: Vector3) -> void:
	if cast.get("id", "") == "windhover" and cast.get("landed", false) and cast["targets"].size() >= 8 and ctx.codex.known("set_piece"):
		_queue_discover("kest_tick_tick_boom", at, "set_piece")


func blast_hit(charge: Dictionary, enemy: Node3D, damage: float, at: Vector3) -> float:
	var cast: Dictionary = charge["_kest_cast"]
	_note_target(enemy, cast)
	var held := _posture_spent
	_posture_spent = cast["posture"]
	var dealt: float = combat.ult_hit(enemy, "sticky", damage, at, false)
	_posture_spent = held
	if cast == _cast:
		_record["volley_hits"] = int(_record.get("volley_hits", 0)) + 1
		_record["damage"] = float(_record.get("damage", 0.0)) + dealt
	return dealt


func _detonate_payload(charge: Dictionary) -> void:
	_cable_burst = charge.get("_cable", false) and charge.get("_body") == null
	combat._detonate(charge)
	_cable_burst = false
	if charge.get("_cable", false):
		cable = {}
		ctx.player.indicator.clear("kest_cable")
		_sound("cable_kest_blast")


func _hold_cloak() -> void:
	combat._start_cloak()
	combat.cloak_left = INF
	ctx.player.kit.cloaked = true


func _end(reason: String, refunded: bool) -> void:
	if _id in IDS:
		for c in payloads.charges.duplicate():
			if c.get("_inert", false):
				_take_payload(c)
		_groups = []
		_mines = []
		combat.cloak_left = Weapons.CLOAK_SECONDS
	super._end(reason, refunded)


func step(delta: float) -> void:
	if payloads != null:
		flush_discoveries()
		if ctx.flow.in_play():
			_step_payloads(delta)
		var gauge = ctx.player.abilities.gauge("special")
		if gauge == null or not gauge.charging:
			ctx.player.indicator.clear("kest_caught")
	super.step(delta)


func _step_payloads(delta: float) -> void:
	if cable.is_empty() and _rolls.is_empty() and payloads.is_idle() \
			and not (_id == "windhover" and _cast.get("landed", false)):
		return
	if not cable.is_empty() and payloads.charges.has(cable):
		if not ctx.player.kit.hooked:
			_end_cable()
		elif not cable.get("_set", false):
			cable["_travel"] = maxf(0.0, float(cable["_travel"]) - delta)
			cable["pos"] = (cable["_start"] as Vector3).lerp(cable["_anchor"], 1.0 - float(cable["_travel"]) / maxf(0.0001, cable["_duration"]))
			if float(cable["_travel"]) <= 0.00001:
				_set_cable()
	for roll in _rolls.duplicate():
		if _clock + delta < float(roll["at"]) - 0.00001:
			continue
		for c in roll["group"]:
			if payloads.charges.has(c):
				c["_inert"] = false
				_detonate_payload(_take_payload(c))
		if roll_log.size() >= LOG_CAP:
			roll_log.pop_front()
		roll_log.append({"at": roll["at"], "index": roll["index"]})
		var audio = ctx.root.presentation.audio if ctx.root.get("presentation") != null else null
		if audio != null:
			audio.kest_roll(NOTES[posmod(roll_log.size() - 1, NOTES.size())])
		_rolls.erase(roll)
	if not payloads.is_idle():
		for c in payloads.step(delta, _space(), get_tree().get_nodes_in_group(Groups.ENEMY)):
			combat.devices.remove(int(c.get("device_id", 0)))
			_detonate_payload(c)
	if _id == "windhover" and _cast.get("landed", false):
		_check_grant(_cast, ctx.player.ball_position())


func caught_charges() -> Array:
	return payloads.charges if payloads != null else []


func take_charge(c: Dictionary) -> Dictionary:
	if c == cable:
		cable = {}
		ctx.player.indicator.clear("kest_cable")
	return _take_payload(c)


func _take_payload(charge: Dictionary) -> Dictionary:
	combat.devices.remove(int(charge.get("device_id", 0)))
	return payloads.take(charge)


func kest_cage_state() -> Dictionary:
	var riding := active() and _id in IDS
	var ready := meter.full()
	var gliding: bool = ctx.player.kit.gliding
	var bands := volley_targets()
	var age := _clock - _last_throw
	var recovering := _clock - _landed_at
	var loaded: bool = not combat.line_load().is_empty() and not ready and not riding
	var glow := 1.0 if riding else (0.8 + 0.2 * sin(_clock * TAU) if ready else (1.0 if FlashGuard.blink(posmod(int(_clock * 4.0), 2) == 0) else 0.0) if loaded else 0.2)
	if ctx.player.kit.cloaked and not riding:
		glow = 0.0
	return {"heft_class": heft_index() + 1, "vent_angle": PI * 0.5 if gliding or riding else (PI / 6.0 if ready else 0.0),
		"fuse_glow": glow, "fuse_boost": ready or riding,
		"fuse_blink": loaded, "smoke": ctx.player.kit.cloaked,
		"mortar_pitch": PI / 4.0 if riding else (PI / 9.0 if ready else 0.0),
		"mortar_recoil": 0.08 * maxf(0.0, 1.0 - age / 0.12), "satchel_bands": bands,
		"lit_count": maxi(0, bands - posmod(_total_beat, bands)) if riding else (bands if ready else roundi(bands * clampf(recovering / 0.4, 0.0, 1.0)) if recovering < 0.4 else 0)}


func _sound(sound: String, grid := true, pitch := 1.0) -> void:
	var audio = ctx.root.presentation.audio if ctx.root.get("presentation") != null else null
	if audio == null:
		return
	var kind := "line_skill_fired" if sound.begins_with("cable_") else "ultimate_peak"
	audio.kest_cue(kind, sound, "beat" if grid else "now", pitch)
