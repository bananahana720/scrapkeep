extends Node

const AbilityState := preload("res://src/core/ability_state.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Ultimate := preload("res://src/combat/ultimate.gd")
const Weapons := preload("res://src/combat/weapons.gd")

const DRAG_SPEED := 30.0
const BITE_SECONDS := 0.1
const DRAG_REACH := 3.0
const DRAG_DAMAGE := 14.0
const DRAG_MARK := 2.5
const BODY_HALF_WIDTH := 1.0
const SLAB_HALF_WIDTH := 1.2
const SLAB_DAMAGE := 16.0
const SNATCH_DAMAGE := 12.0
const CHEW_DAMAGE := 4.0
const SNATCH_RADIUS := 10.0
const PEAK_DAMAGE := 18.0
const LANDING_PULL := 20.8
const SET_PIECES := ["redjaw_rend", "rake_run", "vice_leap"]

var combat
var ctx
var drag := {}
var tow: Array = []
var hurls: Array = []
var rake_shapes: Array = []
var seized := {}
var clamp_hurls: Array = []
var last_clamp_hurl := {}
var beat3_lunge := {}
var last_beat3_lunge := {}
var pendulum_guard := {}
var last_armor_block := {}
var _rakes: Array = []
var _vice := {}
var _dragged := {}
var _holds := 0
var _entry_holds := 0
var _cards := {}
var _card_frame := -1
var _piece := ""
var _previous := Vector3.ZERO
var _last_beat := 0


static func line_row(owner) -> Dictionary:
	var claw = load("res://src/combat/tarn_claw.gd").new()
	claw.name = "TarnClaw"
	owner.add_child(claw)
	claw.setup(owner)
	return {"on_body": claw.on_body, "on_world": claw.on_world, "geometry": claw.geometry}


func setup(owner) -> void:
	combat = owner
	ctx = owner.ctx
	process_physics_priority = 10
	ctx.events.run_started.connect(func(_pilot: String):
		_holds = 0
		_entry_holds = 0
		_dragged.clear()
		_cards.clear()
		_clear())
	ctx.events.stage_entered.connect(func(_stage: int, retry: bool):
		_holds = _entry_holds if retry else _holds
		_entry_holds = _holds
		_dragged.clear()
		_cards.clear()
		_clear())
	ctx.events.stage_content_cleared.connect(func(_reason: String): _clear())
	ctx.events.player_died.connect(_clear)
	ctx.events.line_state_changed.connect(func(_state: String, _target: Node3D, _at: Vector3, _cause: String):
		if not drag.is_empty() and not _line_matches():
			_stop_drag()
		if not pendulum_guard.is_empty() and not _pendulum_matches():
			_stop_pendulum_guard())
	ctx.events.ultimate_started.connect(func(id: String, _path: String, from: Vector3, _to: Vector3, _seconds: float):
		if id in SET_PIECES:
			_clear_piece()
			_piece = id
			_previous = from
			_last_beat = 0)
	ctx.events.ultimate_cancelled.connect(func(_id: String, _reason: String, _refund: bool): _clear_piece())
	ctx.events.hold_broken.connect(_hold_broken)
	ctx.events.synergy_discovered.connect(func(_id: String, _category: String, _first: bool):
		_card_frame = Engine.get_physics_frames())


static func tow_limit(heft_class: int) -> float:
	return 1.0 + 0.5 * clampi(heft_class, 1, 5)


func _class() -> int:
	return int(ctx.run.heft_class())


func _alive(enemy) -> bool:
	return is_instance_valid(enemy) and not (enemy.has_method("is_dead") and enemy.is_dead())


func _protected(enemy: Node3D) -> bool:
	return enemy.has_method("_apply_posture") or combat._target_class(enemy) == "boss"


func _movable(enemy) -> bool:
	return _alive(enemy) and not _protected(enemy) and enemy.get("weight") != null and float(enemy.weight) <= tow_limit(_class())


func _hold(enemy: Node3D) -> void:
	var drop := _release.bind(enemy)
	if not enemy.tree_exiting.is_connected(drop):
		enemy.tree_exiting.connect(drop, CONNECT_ONE_SHOT)


func _release(enemy: Node3D) -> void:
	tow.erase(enemy)
	hurls = hurls.filter(func(h): return h["enemy"] != enemy)
	clamp_hurls = clamp_hurls.filter(func(h): return h["enemy"] != enemy)
	if not seized.is_empty() and seized.get("enemy") == enemy:
		seized = {}
	if not drag.is_empty() and drag["target"] == enemy:
		_stop_drag()
	if not pendulum_guard.is_empty() and pendulum_guard.get("anchor_body") == enemy:
		_stop_pendulum_guard()


func _enemies() -> Array:
	return get_tree().get_nodes_in_group("enemy").filter(func(enemy): return _alive(enemy))


func _mark(enemy: Node3D, seconds: float) -> void:
	if _alive(enemy) and not _protected(enemy):
		combat._clamped[enemy.get_instance_id()] = combat._clock + seconds


func _pull(enemy: Node3D, toward: Vector3, speed: float) -> void:
	var vertical: float = enemy._knock.y
	enemy._knock = Vector3(0.0, vertical, 0.0)
	enemy.knock(toward - enemy.global_position, speed * float(enemy.weight))
	var push: Vector3 = enemy._knock
	push.y = vertical
	enemy._knock = push


func _arrival(target: Vector3) -> Vector3:
	var ball: Vector3 = ctx.player.ball_position()
	var toward := target - ball
	toward.y = 0.0
	return ball + toward.normalized() * DRAG_REACH


func _corridor(from: Vector3, to: Vector3, half_width: float) -> Dictionary:
	return ctx.player.yours({"kind": "line", "from": from, "to": to, "full_to": to, "width": half_width * 2.0, "fill": 1.0})


func geometry(_fraction: float) -> Dictionary:
	var kit = ctx.player.kit
	var ball: Vector3 = ctx.player.ball_position()
	var at: Vector3 = kit.anchor if kit.hooked else ball + combat._flat_aim() * ctx.player.grapple_range()
	return _corridor(at, _arrival(at), BODY_HALF_WIDTH if kit.on_body else SLAB_HALF_WIDTH)


func on_body(target: Node3D, _fraction: float, mult: float) -> void:
	_stop_drag()
	if not _alive(target):
		return
	if not _movable(target):
		if _protected(target):
			combat.strike(target, "claw", DRAG_DAMAGE * mult, "", "special")
		else:
			combat._hit(target, "claw", DRAG_DAMAGE * mult, Vector3.ZERO, 0.0, "", "special")
			_mark(target, DRAG_MARK)
		combat._reel_burst(target.global_position, 1.0, mult)
		_start_pendulum_guard(target, target.global_position, false)
		return
	drag = {"target": target, "from": target.global_position, "mult": mult, "bite": BITE_SECONDS, "time": 0.0, "world": false}
	_hold(target)
	ctx.player.indicator.set_shape("tarn_drag", geometry(1.0))


func on_world(anchor: Vector3, _fraction: float, mult: float) -> void:
	_stop_drag()
	drag = {"target": null, "from": anchor, "at": anchor, "mult": mult, "bite": BITE_SECONDS, "time": 0.0, "world": true, "hit": {}}
	ctx.player.indicator.set_shape("tarn_drag", _corridor(anchor, _arrival(anchor), SLAB_HALF_WIDTH))
	_start_pendulum_guard(null, anchor, true)


func _line_matches() -> bool:
	var kit = ctx.player.kit
	if not kit.hooked:
		return false
	return not kit.on_body if drag["world"] else kit.on_body and is_instance_valid(kit.anchor_body) and kit.anchor_body == drag["target"]


func _stop_drag() -> void:
	drag = {}
	if ctx != null:
		ctx.player.indicator.clear("tarn_drag")


func _physics_process(delta: float) -> void:
	if ctx == null or ctx.flow == null or not ctx.flow.in_play():
		return
	step(delta)


func step(delta: float) -> void:
	_step_drag(delta)
	_step_pendulum_guard(delta)
	_step_clamp_hurl(delta)
	_step_beat3_lunge(delta)
	_step_piece(delta)
	for id in _cards.keys():
		var entry: Dictionary = _cards[id]
		var codex = combat._codex()
		var frame := Engine.get_physics_frames()
		if frame > _card_frame and frame > int(entry["queued"]) and codex != null and codex.known(entry["after"]):
			combat._discover(id, entry["at"])
			_cards.erase(id)
			_card_frame = frame
			break


func _discover(id: String, after: String, at: Vector3) -> void:
	_cards[id] = {"after": after, "at": at, "queued": Engine.get_physics_frames()}


func _step_drag(delta: float) -> void:
	if drag.is_empty():
		return
	if not _line_matches() or (not drag["world"] and not _movable(drag["target"])):
		_stop_drag()
		return
	drag["time"] += delta
	if float(drag["time"]) > 1.5 + BITE_SECONDS:
		_stop_drag()
		return
	if float(drag["bite"]) > 0.0:
		drag["bite"] -= delta
		return
	var mult: float = drag["mult"]
	if drag["world"]:
		var shape := _corridor(drag["from"], _arrival(drag["from"]), SLAB_HALF_WIDTH)
		ctx.player.indicator.set_shape("tarn_drag", shape)
		var at: Vector3 = drag["at"]
		var next := at.move_toward(shape["to"], DRAG_SPEED * delta)
		for enemy in _enemies():
			var id: int = enemy.get_instance_id()
			if not drag["hit"].has(id) and in_strip(shape, enemy.global_position) and _segment_gap(at, next, enemy.global_position) <= SLAB_HALF_WIDTH:
				drag["hit"][id] = true
				if _protected(enemy):
					combat.strike(enemy, "claw", SLAB_DAMAGE * mult, "", "special")
				else:
					combat._hit(enemy, "claw", SLAB_DAMAGE * mult, ctx.player.ball_position() - enemy.global_position, 14.0, "", "special")
		drag["at"] = next
		ctx.player.indicator.set_shape("tarn_drag", _corridor(next, shape["to"], SLAB_HALF_WIDTH))
		if next.distance_to(shape["to"]) < 0.05:
			_stop_drag()
		return
	var target: Node3D = drag["target"]
	var to := _arrival(target.global_position)
	ctx.player.indicator.set_shape("tarn_drag", _corridor(target.global_position, to, BODY_HALF_WIDTH))
	var flat := to - target.global_position
	flat.y = 0.0
	if flat.length() <= DRAG_SPEED * delta + 0.1:
		var push: Vector3 = target._knock
		target._knock = Vector3(0.0, push.y, 0.0)
		combat._hit(target, "claw", DRAG_DAMAGE * mult, flat, 0.0, "", "special")
		_mark(target, DRAG_MARK)
		_discover("tarn_claw_drag", "loaded_line", target.global_position)
		_dragged[target.get_instance_id()] = true
		if _dragged.size() >= 10:
			_discover("tarn_dragged", "loaded_line", target.global_position)
		_stop_drag()
		return
	_pull(target, to, DRAG_SPEED)
	for other in _enemies():
		if other != target and not _protected(other) and _segment_gap(target.global_position, target.global_position + flat.normalized() * DRAG_SPEED * delta, other.global_position) <= BODY_HALF_WIDTH:
			other.knock(other.global_position - target.global_position, 10.0)


static func _segment_gap(a: Vector3, b: Vector3, p: Vector3) -> float:
	var ab := Vector3(b.x - a.x, 0.0, b.z - a.z)
	var ap := Vector3(p.x - a.x, 0.0, p.z - a.z)
	var t := clampf(ap.dot(ab) / ab.length_squared(), 0.0, 1.0) if ab.length_squared() > 0.0001 else 0.0
	return (ap - ab * t).length()


static func in_strip(shape: Dictionary, point: Vector3) -> bool:
	var a: Vector3 = shape["from"]
	var b: Vector3 = shape["to"]
	var ab := Vector3(b.x - a.x, 0.0, b.z - a.z)
	var ap := Vector3(point.x - a.x, 0.0, point.z - a.z)
	if ab.length_squared() < 0.0001:
		return false
	var along := ap.dot(ab) / ab.length_squared()
	return along >= 0.0 and along <= 1.0 and _segment_gap(a, b, point) <= float(shape["width"]) * 0.5


func tech(id: String, beat: int, ball: Vector3, aim: Vector3, heft: float) -> int:
	var hits := 0
	if id == "rake_run":
		rake_shapes = strips(_previous, ball, 3.0 + 1.5 * float(combat.ultimate._knob("ult_volley", 0)))
		for shape in rake_shapes:
			_draw_rake(shape)
		for enemy in _enemies():
			if rake_shapes.any(func(shape): return in_strip(shape, enemy.global_position)):
				_hit_piece(enemy, 10.0 * heft, ball, false)
				if not _protected(enemy):
					_pull(enemy, ball, 6.0)
					_mark(enemy, 1.5)
				hits += 1
	else:
		var side := Vector3(-aim.z, 0.0, aim.x).normalized()
		if beat % 2 == 0:
			side = -side
		var picks: Array = []
		for enemy in _enemies():
			var to: Vector3 = enemy.global_position - ball
			if to.length() > SNATCH_RADIUS or to.dot(side) < -0.001 or tow.has(enemy) or hurls.any(func(h): return h["enemy"] == enemy):
				continue
			var biased := to.length() > 0.01 and aim.length() > 0.01 and aim.angle_to(to) <= deg_to_rad(25.0)
			picks.append([(0.0 if biased else 100.0) + to.length(), enemy])
		picks.sort_custom(func(a, b): return a[0] < b[0])
		for pick in picks.slice(0, 2 + int(combat.ultimate._knob("ult_volley", 0))):
			var enemy: Node3D = pick[1]
			_hit_piece(enemy, SNATCH_DAMAGE * heft, ball, false)
			hits += 1
			if _movable(enemy):
				if id == "redjaw_rend" and tow.size() < 2 + _class():
					tow.append(enemy)
					_hold(enemy)
					if enemy.has_method("open_ring_out"):
						enemy.open_ring_out()
				elif id == "vice_leap":
					var ult = combat.ultimate
					var left := maxf(0.05, float(ult._plan["legs"][ult._leg]["seconds"]) - float(ult._leg_time))
					if enemy.has_method("open_ring_out"):
						enemy.open_ring_out()
					hurls.append({"enemy": enemy, "from": enemy.global_position, "to": ult._plan["legs"][ult._leg]["to"], "time": 0.0, "seconds": left})
					_hold(enemy)
		for enemy in tow.duplicate():
			if _alive(enemy):
				_hit_piece(enemy, CHEW_DAMAGE * heft, ball, false)
	_previous = ball
	_last_beat = beat
	return hits


static func strips(from: Vector3, to: Vector3, width: float) -> Array:
	var dir := Vector3(to.x - from.x, 0.0, to.z - from.z).normalized()
	var side := Vector3(-dir.z, 0.0, dir.x)
	var shapes: Array = []
	for sign_value in [-1.0, 1.0]:
		var offset: Vector3 = side * sign_value * (0.5 + width * 0.5)
		shapes.append({"kind": "line", "from": from + offset, "to": to + offset, "full_to": to + offset, "width": width, "fill": 1.0})
	return shapes


func _draw_rake(shape: Dictionary) -> void:
	var layer := "tarn_rake_%d" % _rakes.size()
	_rakes.append({"shape": shape, "layer": layer, "left": 2.0})
	ctx.player.indicator.set_shape(layer, ctx.player.yours(shape))


func peak(id: String, at: Vector3) -> void:
	var heft: float = Ultimate.HEFT_MULT[_class() - 1]
	if id == "rake_run":
		var dir: Vector3 = combat._flat_aim()
		rake_shapes = []
		for angle in [-20.0, 20.0]:
			var shape := _corridor(at, at + dir.rotated(Vector3.UP, deg_to_rad(angle)) * 10.0, 0.75)
			rake_shapes.append(shape)
			_draw_rake(shape)
		for enemy in _enemies():
			if rake_shapes.any(func(shape): return in_strip(shape, enemy.global_position)):
				_hit_piece(enemy, 24.0 * heft, at, false)
	elif id == "vice_leap":
		_vice = {"at": combat.ultimate._plan["legs"][combat.ultimate._leg]["to"], "radius": combat.ultimate.landing_radius() + 2.0, "clock": 0.0}
		ctx.player.indicator.set_shape("tarn_vice", ctx.player.yours({"kind": "ring", "centre": _vice["at"], "radius": _vice["radius"], "full_radius": _vice["radius"], "fill": 1.0}))
	else:
		combat.effects.ring(at, 5.0, ctx.player.class_color())
		for enemy in _enemies():
			if not tow.has(enemy) and enemy.global_position.distance_to(at) <= 5.0:
				_hit_piece(enemy, PEAK_DAMAGE * heft, at, false)
				if not _protected(enemy):
					enemy.knock(enemy.global_position - at, 14.0)


func _hit_piece(enemy: Node3D, damage: float, at: Vector3, landing_hit: bool) -> float:
	if enemy.has_method("_apply_posture"):
		return combat._ult_hit(enemy, "claw", damage, at, landing_hit)
	if combat._target_class(enemy) == "boss":
		combat.strike(enemy, "claw", damage * Ultimate.BOSS_MULT, "", "special")
		return damage * Ultimate.BOSS_MULT
	combat._hit(enemy, "claw", damage, at - enemy.global_position, LANDING_PULL if landing_hit else 0.0, "", "special", "slam" if landing_hit else "")
	return damage


func landing(id: String, at: Vector3, heft: float, chain: float) -> Array:
	var radius: float = combat.ultimate.landing_radius() + (2.0 if id == "vice_leap" else 0.0)
	var carried: Array = tow.duplicate() if id == "redjaw_rend" else hurls.map(func(h): return h["enemy"])
	var had_tow := carried.any(func(enemy): return _alive(enemy))
	var hits := 0
	var damage := 0.0
	combat.effects.ring(at, radius, ctx.player.class_color())
	ctx.break_props(at, radius, "ultimate")
	for enemy in _enemies():
		if enemy.global_position.distance_to(at) > radius:
			continue
		var amount := Ultimate.LANDING_DAMAGE * heft * chain * (1.25 if carried.has(enemy) else 1.0)
		damage += _hit_piece(enemy, amount, at, true)
		_mark(enemy, 4.0 if id == "vice_leap" else 3.0)
		hits += 1
	if id == "redjaw_rend" and had_tow:
		_discover("tarn_redjaw_rend", "set_piece", at)
	if id == "rake_run":
		combat._boost(3.0)
	_clear_piece()
	return [hits, damage]


func _step_piece(delta: float) -> void:
	for rec in _rakes.duplicate():
		rec["left"] -= delta
		if float(rec["left"]) <= 0.0:
			ctx.player.indicator.clear(rec["layer"])
			_rakes.erase(rec)
	if _piece == "" or combat.ultimate == null or combat.ultimate.phase() != "flight":
		return
	var ball: Vector3 = ctx.player.ball_position()
	var heading: Vector3 = combat.ultimate._ride.heading if combat.ultimate._ride != null else combat._flat_aim()
	var side := Vector3(-heading.z, 0.0, heading.x)
	for i in range(tow.size() - 1, -1, -1):
		var enemy = tow[i]
		if not _movable(enemy):
			tow.remove_at(i)
			continue
		var target := ball - heading * 3.0 + side * (0.75 if i % 2 == 0 else -0.75)
		var distance: float = enemy.global_position.distance_to(target)
		_pull(enemy, target, minf(90.0, distance / maxf(delta, 0.001)))
		enemy.velocity = (target - enemy.global_position).limit_length(90.0 * delta) / maxf(delta, 0.001)
		enemy.move_and_slide()
		enemy._knock = Vector3.ZERO
		for other in _enemies():
			if other != enemy and not tow.has(other) and not _protected(other) and other.global_position.distance_to(enemy.global_position) <= 1.5:
				other.knock(other.global_position - enemy.global_position, 10.0)
	for h in hurls.duplicate():
		var enemy = h["enemy"]
		if not _movable(enemy):
			hurls.erase(h)
			continue
		h["time"] = minf(float(h["seconds"]), float(h["time"]) + delta)
		var f := float(h["time"]) / float(h["seconds"])
		var next: Vector3 = (h["from"] as Vector3).lerp(h["to"], f) + Vector3.UP * sin(PI * f) * 3.0
		enemy.velocity = (next - enemy.global_position) / maxf(delta, 0.001)
		enemy.move_and_slide()
		enemy._knock = Vector3.ZERO
	if not _vice.is_empty():
		_vice["clock"] += delta
		if float(_vice["clock"]) >= 0.2:
			_vice["clock"] = fmod(float(_vice["clock"]), 0.2)
			for enemy in _enemies():
				if not _protected(enemy) and enemy.global_position.distance_to(_vice["at"]) <= float(_vice["radius"]):
					_pull(enemy, _vice["at"], 6.0)


func _hold_broken(_kind: String, method: String) -> void:
	if method != "ultimate" or ctx.player.class_def == null or ctx.player.class_def.id != "tarn" or ctx.player.abilities.ultimate_id != "redjaw_rend":
		return
	_holds += 1
	if _holds >= 3:
		_discover("tarn_hold_still", "set_piece_breakout", ctx.player.ball_position())


func _clear_piece() -> void:
	tow.clear()
	hurls.clear()
	_vice = {}
	_piece = ""
	if ctx != null:
		ctx.player.indicator.clear("tarn_vice")


func _clear() -> void:
	_stop_drag()
	_stop_pendulum_guard()
	seized = {}
	clamp_hurls.clear()
	last_clamp_hurl = {}
	beat3_lunge = {}
	last_beat3_lunge = {}
	last_armor_block = {}
	_clear_piece()
	for rec in _rakes:
		ctx.player.indicator.clear(rec["layer"])
	_rakes.clear()


func _seizable(enemy) -> bool:
	if not _alive(enemy) or _protected(enemy):
		return false
	var w = enemy.get("weight")
	if w == null:
		return false
	return float(w) <= maxf(Weapons.CLAMP_HURL_MAX_WEIGHT, tow_limit(_class()))


func try_seize(candidates: Array) -> Node3D:
	if not seized.is_empty():
		_launch_seized()
	var ball: Vector3 = ctx.player.ball_position()
	var best: Node3D = null
	var best_d := INF
	for enemy in candidates:
		if not _seizable(enemy):
			continue
		var d: float = (enemy as Node3D).global_position.distance_to(ball)
		if d < best_d:
			best_d = d
			best = enemy
	if best == null:
		return null
	seized = {
		"enemy": best,
		"left": Weapons.CLAMP_SEIZE_SECONDS,
		"elapsed": 0.0,
		"heft": _class(),
		"claw_material": "worn_steel",
	}
	_hold(best)
	return best


func _launch_seized() -> Dictionary:
	if seized.is_empty():
		return {}
	var enemy = seized.get("enemy")
	var heft_at_seize: int = int(seized.get("heft", _class()))
	seized = {}
	if not _alive(enemy):
		return {}
	var aim: Vector3 = combat._flat_aim()
	if aim.length_squared() < 0.0001:
		aim = Vector3.FORWARD
	var weight: float = maxf(1.0, float(enemy.get("weight")) if enemy.get("weight") != null else 1.0)
	if enemy.has_method("open_ring_out"):
		enemy.open_ring_out()
	if enemy.has_method("knock"):
		enemy._knock = Vector3.ZERO
		enemy.knock(aim + Vector3.UP * 0.12, Weapons.CLAMP_HURL_SPEED * weight)
	var rec := {
		"enemy": enemy,
		"dir": aim,
		"speed": Weapons.CLAMP_HURL_SPEED,
		"left": Weapons.CLAMP_HURL_FLIGHT_SECONDS,
		"heft": heft_at_seize,
		"hit": {},
		"bowled": 0,
		"walls_broken": [],
		"claw_material": "worn_steel",
	}
	clamp_hurls.append(rec)
	_hold(enemy)
	last_clamp_hurl = {
		"enemy_id": enemy.get_instance_id(),
		"dir": aim,
		"speed": Weapons.CLAMP_HURL_SPEED,
		"heft": heft_at_seize,
		"bowled": 0,
		"walls_broken": [],
		"claw_material": "worn_steel",
	}
	combat.effects.spark(enemy.global_position + Vector3.UP * 0.6, ClassDef.TARN_COLOR)
	return last_clamp_hurl


func _step_clamp_hurl(delta: float) -> void:
	if not seized.is_empty():
		var held = seized.get("enemy")
		if not _alive(held):
			seized = {}
		else:
			seized["elapsed"] = float(seized["elapsed"]) + delta
			seized["left"] = float(seized["left"]) - delta
			if float(seized["left"]) <= 0.0:
				_launch_seized()
			elif float(seized["elapsed"]) >= 0.06:
				var aim: Vector3 = combat._flat_aim()
				var hold_pos: Vector3 = ctx.player.ball_position() + aim * Weapons.CLAMP_HURL_HOLD_OFFSET
				hold_pos.y = held.global_position.y
				held.global_position = held.global_position.move_toward(hold_pos, 22.0 * delta)
	if clamp_hurls.is_empty():
		return
	var live_enemies := _enemies()
	var dmg: float = Weapons.CLAMP_HURL_BOWL_DAMAGE * combat._damage_mod(Weapons.CLAW_SWEEP)
	for h in clamp_hurls.duplicate():
		var enemy = h["enemy"]
		if not _alive(enemy):
			clamp_hurls.erase(h)
			continue
		h["left"] = float(h["left"]) - delta
		var dir: Vector3 = h["dir"]
		var speed: float = float(h["speed"])
		var prev_pos: Vector3 = enemy.global_position
		var step_dt: float = maxf(delta, 0.001)
		var lookahead: Vector3 = prev_pos + dir * (speed * step_dt + Weapons.CLAMP_HURL_WALL_RADIUS * 0.5)
		if ctx.destructibles != null and is_instance_valid(ctx.destructibles) and ctx.destructibles.has_method("on_hurled_enemy"):
			var broken: Array[String] = ctx.destructibles.on_hurled_enemy(
				prev_pos, lookahead, int(h["heft"]), Weapons.CLAMP_HURL_WALL_RADIUS, "tarn_hurl")
			if not broken.is_empty():
				for bid in broken:
					if not (h["walls_broken"] as Array).has(bid):
						(h["walls_broken"] as Array).append(bid)
				last_clamp_hurl["walls_broken"] = (h["walls_broken"] as Array).duplicate()
		enemy.velocity = Vector3(dir.x * speed, enemy.velocity.y, dir.z * speed)
		enemy.move_and_slide()
		var after_pos: Vector3 = enemy.global_position
		var sweep_end: Vector3 = after_pos if after_pos.distance_squared_to(prev_pos) > 0.0001 else lookahead
		for other in live_enemies:
			if other == enemy or not _alive(other):
				continue
			var oid: int = other.get_instance_id()
			if (h["hit"] as Dictionary).has(oid):
				continue
			if _segment_gap(prev_pos, sweep_end, other.global_position) <= Weapons.CLAMP_HURL_BOWL_RADIUS:
				(h["hit"] as Dictionary)[oid] = true
				h["bowled"] = int(h["bowled"]) + 1
				last_clamp_hurl["bowled"] = int(h["bowled"])
				if _protected(other):
					combat.strike(other, "claw", dmg, "", "special")
				else:
					combat._hit(other, "claw", dmg, dir + Vector3.UP * 0.25, Weapons.CLAMP_HURL_BOWL_KNOCK, "", "special", "clamp")
				combat.flung.emit(other)
		if float(h["left"]) <= 0.0:
			clamp_hurls.erase(h)


func trigger_beat3_lunge(aim_dir: Vector3) -> Dictionary:
	var flat := Vector3(aim_dir.x, 0.0, aim_dir.z)
	var dir: Vector3 = flat.normalized() if flat.length_squared() > 0.0001 else combat._flat_aim()
	var lunge_speed := Weapons.TARN_BEAT3_LUNGE_M / maxf(Weapons.TARN_BEAT3_LUNGE_S, 0.01)
	var current: Vector3 = ctx.player.state.velocity
	var keep_speed := maxf(Vector2(current.x, current.z).length(), lunge_speed)
	ctx.player.grant_immunity(Weapons.TARN_BEAT3_ARMOR_S)
	ctx.player.set_velocity_now(Vector3(dir.x * keep_speed, current.y, dir.z * keep_speed), "tarn_lunge")
	beat3_lunge = {
		"dir": dir,
		"left": Weapons.TARN_BEAT3_LUNGE_S,
		"armor_left": Weapons.TARN_BEAT3_ARMOR_S,
		"speed": keep_speed,
		"start": ctx.player.ball_position(),
		"moved": 0.0,
		"unstoppable": true,
		"claw_material": "worn_steel",
	}
	last_beat3_lunge = {
		"dir": dir,
		"target_m": Weapons.TARN_BEAT3_LUNGE_M,
		"armor_s": Weapons.TARN_BEAT3_ARMOR_S,
		"unstoppable": true,
		"moved": 0.0,
		"claw_material": "worn_steel",
	}
	combat.effects.ring(ctx.player.ball_position(), 2.4, ClassDef.TARN_COLOR)
	return last_beat3_lunge


func _step_beat3_lunge(delta: float) -> void:
	if beat3_lunge.is_empty():
		return
	var dir: Vector3 = beat3_lunge["dir"]
	if float(beat3_lunge["left"]) > 0.0:
		beat3_lunge["left"] = maxf(0.0, float(beat3_lunge["left"]) - delta)
		var speed: float = float(beat3_lunge["speed"])
		var cur: Vector3 = ctx.player.state.velocity
		ctx.player.set_velocity_now(Vector3(dir.x * speed, cur.y, dir.z * speed), "tarn_lunge")
		var start_pos: Vector3 = beat3_lunge["start"]
		var rel: Vector3 = ctx.player.ball_position() - start_pos
		rel.y = 0.0
		beat3_lunge["moved"] = maxf(float(beat3_lunge["moved"]), rel.dot(dir))
		last_beat3_lunge["moved"] = float(beat3_lunge["moved"])
	beat3_lunge["armor_left"] = maxf(0.0, float(beat3_lunge["armor_left"]) - delta)
	if float(beat3_lunge["left"]) <= 0.0 and float(beat3_lunge["armor_left"]) <= 0.0:
		beat3_lunge = {}


func _start_pendulum_guard(anchor_body: Node3D, anchor_pos: Vector3, is_world: bool) -> void:
	var ball: Vector3 = ctx.player.ball_position()
	var to_anchor := anchor_pos - ball
	to_anchor.y = 0.0
	var facing: Vector3 = to_anchor.normalized() if to_anchor.length_squared() > 0.0001 else combat._flat_aim()
	pendulum_guard = {
		"active": true,
		"anchor_body": anchor_body,
		"anchor": anchor_pos,
		"world": is_world,
		"facing": facing,
		"shield_mult": Weapons.TARN_FRONTAL_ARMOR_MULT,
		"claw_material": "worn_steel",
	}


func _stop_pendulum_guard() -> void:
	pendulum_guard = {}


func _pendulum_matches() -> bool:
	if pendulum_guard.is_empty():
		return false
	var kit = ctx.player.kit
	if not kit.hooked:
		return false
	if bool(pendulum_guard["world"]):
		return not kit.on_body
	var body = pendulum_guard.get("anchor_body")
	return kit.on_body and is_instance_valid(kit.anchor_body) and kit.anchor_body == body and _alive(body)


func _step_pendulum_guard(delta: float) -> void:
	if pendulum_guard.is_empty():
		return
	if not _pendulum_matches():
		_stop_pendulum_guard()
		return
	var anchor_pos: Vector3 = (pendulum_guard["anchor_body"] as Node3D).global_position if not bool(pendulum_guard["world"]) else ctx.player.kit.anchor
	pendulum_guard["anchor"] = anchor_pos
	var ball: Vector3 = ctx.player.ball_position()
	var to_anchor := anchor_pos - ball
	to_anchor.y = 0.0
	var facing: Vector3 = to_anchor.normalized() if to_anchor.length_squared() > 0.0001 else combat._flat_aim()
	pendulum_guard["facing"] = facing
	var strafe_input: float = float(ctx.player.intent.move.x) if ctx.player.intent != null else 0.0
	if absf(strafe_input) > 0.05:
		var tangent := Vector3(-facing.z, 0.0, facing.x) * signf(strafe_input)
		var desired := tangent * Weapons.TARN_PENDULUM_STRAFE_SPEED
		var cur_flat := Vector3(ctx.player.state.velocity.x, 0.0, ctx.player.state.velocity.z)
		var delta_v := desired - cur_flat.project(tangent)
		ctx.player.add_external_accel(delta_v / maxf(delta, 0.016))


func frontal_armor_scale(shove: Vector3) -> float:
	var guard_dir := Vector3.ZERO
	var guard_source := ""
	if not beat3_lunge.is_empty() and float(beat3_lunge.get("armor_left", 0.0)) > 0.0:
		guard_dir = beat3_lunge["dir"]
		guard_source = "beat3_lunge"
	elif not pendulum_guard.is_empty() and _pendulum_matches():
		guard_dir = pendulum_guard["facing"]
		guard_source = "pendulum_guard"
	if guard_source == "":
		return 1.0
	var incoming := Vector3(-shove.x, 0.0, -shove.z)
	if incoming.length_squared() > 0.0001 and incoming.normalized().dot(guard_dir) < 0.0:
		return 1.0
	last_armor_block = {
		"source": guard_source,
		"mult": Weapons.TARN_FRONTAL_ARMOR_MULT,
		"facing": guard_dir,
		"claw_material": "worn_steel",
	}
	combat.effects.spark(ctx.player.ball_position() + guard_dir * 1.1, ClassDef.TARN_COLOR)
	return Weapons.TARN_FRONTAL_ARMOR_MULT
