extends Node

const AbilityState := preload("res://src/core/ability_state.gd")
const Ultimate := preload("res://src/combat/ultimate.gd")

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
			_stop_drag())
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


# A held body (tow, hurl, drag target) leaves the claw the moment it leaves the tree, so a
# freed enemy is never carried into the next physics step.
func _hold(enemy: Node3D) -> void:
	var drop := _release.bind(enemy)
	if not enemy.tree_exiting.is_connected(drop):
		enemy.tree_exiting.connect(drop, CONNECT_ONE_SHOT)


func _release(enemy: Node3D) -> void:
	tow.erase(enemy)
	hurls = hurls.filter(func(h): return h["enemy"] != enemy)
	if not drag.is_empty() and drag["target"] == enemy:
		_stop_drag()


func _enemies() -> Array:
	return get_tree().get_nodes_in_group("enemy").filter(func(enemy): return _alive(enemy))


func _mark(enemy: Node3D, seconds: float) -> void:
	if _alive(enemy) and not _protected(enemy):
		combat._clamped[enemy.get_instance_id()] = combat._clock + seconds


# knock() supplies weight compensation. Retain vertical momentum instead of adding its
# default hop on every sustained pull tick (enemy.gd's knock lifts by force * 0.2).
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
		return
	drag = {"target": target, "from": target.global_position, "mult": mult, "bite": BITE_SECONDS, "time": 0.0, "world": false}
	_hold(target)
	ctx.player.indicator.set_shape("tarn_drag", geometry(1.0))


func on_world(anchor: Vector3, _fraction: float, mult: float) -> void:
	_stop_drag()
	drag = {"target": null, "from": anchor, "at": anchor, "mult": mult, "bite": BITE_SECONDS, "time": 0.0, "world": true, "hit": {}}
	ctx.player.indicator.set_shape("tarn_drag", _corridor(anchor, _arrival(anchor), SLAB_HALF_WIDTH))


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
	# Framework cards take their own tick. A pilot's card follows on a later physics tick.
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
		# Stop within reach without teleporting through collision. Remove the controlled
		# planar knock on arrival; a cut instead leaves the body's momentum intact.
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
		# A thrown body follows its committed arc through collision, never a teleport.
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
	_clear_piece()
	for rec in _rakes:
		ctx.player.indicator.clear(rec["layer"])
	_rakes.clear()
