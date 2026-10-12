extends Node

# Rivet's kit beyond the gun (design-v3/pilots/rivet.md sections 2.3 and 3): Line Drive on slot 3
# and the three Foundry Cutter set pieces on Q, all landing in the Breach Skid. combat.gd
# registers line_row() in its Rivet block; ultimate.gd's Rivet rows call tech, peak and landing
# here. Every number is a Weapons.LINE_*, CUTTER_*, FULL_CUT_*, BREACH_*, PRISM_* or DRIVE_*
# constant. Everything Rivet does runs in a straight line and turns back into forward speed.

const AbilityState := preload("res://src/core/ability_state.gd")
const Ultimate := preload("res://src/combat/ultimate.gd")
const Weapons := preload("res://src/combat/weapons.gd")
const Augments := preload("res://src/movement/augments.gd")
const PlayerBall := preload("res://src/movement/player_ball.gd")
const RideRail := preload("res://src/world/ride_rail.gd")
const Palette := preload("res://src/core/palette.gd")

const SET_PIECES := ["foundry_cutter", "prism_cutter", "juggernaut_drive"]
const BEAM_PIECES := ["foundry_cutter", "prism_cutter"]
# Discoveries (section 8; CUSTOMIZE section 3 change 3): ten punches landed in one stage, thirty
# ignored holds and knocks in one run, one set piece landing on six machines, a beam cutting three.
const LINE_TRUE_PUNCHES := 10
const SHRUG_HITS := 30
const FULL_BREACH_HITS := 6
const CUTTER_CARD_CUTS := 3
# A pin this soon after a punch is that punch's pin (enemy_pinned names only the victim).
const PIN_WINDOW := 1.5
# The thrown-direction arrow the preview draws from a punched machine (section 2.3).
const ARROW_LENGTH := 6.0

var combat
var ctx
# Punches running down the cable: {target, force, mult, dir, left}.
var pulses: Array = []
# The haul in progress: {ride, anchor, seconds}, or {}.
var haul := {}
# What the last line cast did, for the audio row: {on, delay or seconds}.
var last_cue := {}
var last_punch := {}
var beam_shapes: Array = []
var _clock := 0.0
var _piece := ""
var _cut := {}
var _rammed := {}
var _shoulder := 0.0
var _excepted: Array = []
var _scar_left := 0.0
var _punches := 0
var _shrugs := 0
var _entry_shrugs := 0
var _cards := {}
var _card_frame := -1


static func line_row(owner) -> Dictionary:
	var kit = load("res://src/combat/rivet_kit.gd").new()
	kit.name = "RivetKit"
	owner.add_child(kit)
	kit.setup(owner)
	return {"on_body": kit.on_body, "on_world": kit.on_world, "geometry": kit.geometry}


func setup(owner) -> void:
	combat = owner
	ctx = owner.ctx
	process_physics_priority = 10
	ctx.events.run_started.connect(func(_pilot: String):
		_shrugs = 0
		_entry_shrugs = 0
		_punches = 0
		_cards.clear()
		_clear())
	ctx.events.stage_entered.connect(func(_stage: int, retry: bool):
		_shrugs = _entry_shrugs if retry else _shrugs
		_entry_shrugs = _shrugs
		_punches = 0
		_cards.clear()
		_clear())
	ctx.events.stage_content_cleared.connect(func(_reason: String): _clear())
	ctx.events.player_died.connect(_clear)
	ctx.events.ultimate_started.connect(func(id: String, _path: String, _from: Vector3, _to: Vector3, _seconds: float):
		_clear_piece()
		if id in SET_PIECES:
			_piece = id)
	ctx.events.ultimate_cancelled.connect(func(_id: String, _reason: String, _refund: bool): _clear_piece())
	ctx.events.enemy_pinned.connect(_on_pinned)
	ctx.events.cc_ignored.connect(_on_cc_ignored)
	ctx.events.synergy_discovered.connect(func(_id: String, _category: String, _first: bool):
		_card_frame = Engine.get_physics_frames())


func _rivet() -> bool:
	return ctx.player.class_def != null and ctx.player.class_def.id == "runner_gunner"


func _class() -> int:
	return clampi(int(ctx.run.heft_class()), 1, 5)


func _alive(enemy) -> bool:
	return is_instance_valid(enemy) and not (enemy.has_method("is_dead") and enemy.is_dead())


func _warden(enemy: Node3D) -> bool:
	return enemy.has_method("_apply_posture") and enemy.has_method("staggered")


func _boss(enemy: Node3D) -> bool:
	return combat._target_class(enemy) == "boss"


func _enemies() -> Array:
	return get_tree().get_nodes_in_group("enemy").filter(func(enemy): return _alive(enemy))


func _knob(name: String, fallback):
	return combat.ultimate._knob(name, fallback) if combat.ultimate != null else fallback


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


# The ram force whose punch is `punch` now: punch_of("ram", f) is linear in f, so this inverts
# it exactly (heft, the sprint and the winch scale included).
func ram_force(punch: float) -> float:
	var base: float = combat.punch_of("ram", 0.0)
	var per: float = combat.punch_of("ram", 1.0) - base
	return (punch - base) / per if per > 0.0001 else 0.0


# The slam force whose punch is `punch` (the slam row has no base term).
func slam_force(punch: float) -> float:
	var per: float = combat.punch_of("slam", 1.0)
	return punch / per if per > 0.0001 else 0.0


# --- Line Drive -----------------------------------------------------------------------

# The committed throw direction: along the cable, away from the ball.
func punch_dir(target: Node3D) -> Vector3:
	var d := _flat(target.global_position - ctx.player.ball_position())
	return d.normalized() if d.length() > 0.01 else _flat(combat._flat_aim()).normalized()


# The punch's ram force: max(floor, share x the ball's planar speed).
func punch_force() -> float:
	return maxf(Weapons.LINE_PUNCH_FLOOR, Weapons.LINE_PUNCH_SHARE * ctx.player.planar_velocity().length())


func haul_stop(anchor: Vector3) -> Vector3:
	var ball: Vector3 = ctx.player.ball_position()
	var d := anchor - ball
	return anchor - d.normalized() * Augments.MIN_ROPE if d.length() > Augments.MIN_ROPE else ball


# The preview a tap draws from the pick to the click: on a body the 6 m throw arrow from the
# machine down the cable, on a world anchor the rod to the arrival point 2.5 m short.
func geometry(_fraction: float) -> Dictionary:
	var kit = ctx.player.kit
	var ball: Vector3 = ctx.player.ball_position()
	if kit.hooked and kit.on_body and is_instance_valid(kit.anchor_body):
		var at: Vector3 = kit.anchor_body.global_position
		var to: Vector3 = at + punch_dir(kit.anchor_body) * ARROW_LENGTH
		return ctx.player.yours({"kind": "line", "from": at, "to": to, "full_to": to, "width": 1.0, "fill": 1.0})
	var anchor: Vector3 = kit.anchor if kit.hooked else ball + combat._flat_aim() * ctx.player.grapple_range()
	var stop := haul_stop(anchor)
	return ctx.player.yours({"kind": "line", "from": ball, "to": stop, "full_to": stop, "width": 1.0, "fill": 1.0})


func on_body(target: Node3D, _fraction: float, mult: float) -> void:
	if not _alive(target):
		return
	var delay: float = ctx.player.ball_position().distance_to(target.global_position) / Weapons.LINE_PULSE_SPEED
	pulses.append({"target": target, "force": punch_force(), "mult": mult, "dir": punch_dir(target), "left": delay})
	last_cue = {"on": "body", "delay": delay}
	combat.effects.arc(ctx.player.ball_position() + Vector3.UP * 0.5, target.global_position + Vector3.UP * 0.5, ctx.player.class_color())


func on_world(anchor: Vector3, _fraction: float, _mult: float) -> void:
	var player = ctx.player
	var ball: Vector3 = player.ball_position()
	var stop := haul_stop(anchor)
	var d := stop - ball
	if d.length() < 0.05:
		player.kit.drop_line("let_go")
		return
	var speed := maxf(player.state.velocity.length(), Weapons.LINE_HAUL_SPEED)
	var ride = RideRail.new()
	ride.kind = "rivet_haul"
	ride.mode = RideRail.LINE
	ride.origin = ball
	ride.target = stop
	ride.velocity = d.normalized() * speed
	ride.flight = d.length() / speed + RideRail.LET_GO
	ride.release_speed = speed
	ride.heading = _flat(d).normalized() if _flat(d).length() > 0.01 else Vector3.FORWARD
	ride.active = true
	haul = {"ride": ride, "anchor": anchor, "seconds": ride.flight}
	last_cue = {"on": "world", "seconds": ride.flight}
	# Crowd control slides off for the haul plus the grace; damage still lands (the sprint's rule).
	player.grant_immunity(ride.flight + Weapons.LINE_HAUL_GRACE)
	player.body().set_velocity_now(ride.velocity)
	player.indicator.set_shape("rivet_haul", player.yours({"kind": "line", "from": ball, "to": stop, "full_to": stop, "width": 1.0, "fill": 1.0}))


func _step_pulses(delta: float) -> void:
	for rec in pulses.duplicate():
		rec["left"] = float(rec["left"]) - delta
		if float(rec["left"]) > 0.0:
			continue
		pulses.erase(rec)
		var target: Node3D = rec["target"]
		var kit = ctx.player.kit
		# The pulse runs down the cable: a line cut before it arrives carries nothing.
		if not _alive(target) or not kit.hooked or not kit.on_body or kit.anchor_body != target:
			continue
		_punch(target, float(rec["force"]), float(rec["mult"]), rec["dir"])


# The punch lands: a ram through punch_of("ram", f) x the chain multiplier, knock 34 along the
# cable with the overdrive impact's lift. A Warden's closed guard takes posture only, capped; an
# open core takes one ram contact and never shatters; a boss takes half and is not moved.
func _punch(target: Node3D, force: float, mult: float, dir: Vector3) -> void:
	var punch: float = combat.punch_of("ram", force) * mult
	if _warden(target):
		var result: Dictionary = target.judge_hit("ram", punch, false, 0)
		result["shatter"] = false
		if not target.staggered():
			result["gain"] = minf(float(result.get("gain", 0.0)), Weapons.LINE_WARDEN_POSTURE)
			result["crack"] = false
			combat.effects.spark(target.global_position + Vector3.UP, Palette.SLATE)
		target._apply_posture(result)
	elif _boss(target):
		combat.strike(target, "ram", ram_force(punch * Ultimate.BOSS_MULT), "", "special")
	else:
		combat._hit(target, "ram", ram_force(punch), dir, Weapons.LINE_PUNCH_KNOCK, "", "special", "overdrive")
	last_punch = {"id": target.get_instance_id(), "clock": _clock, "punch": punch, "dir": dir}
	_punches += 1
	if _punches == LINE_TRUE_PUNCHES:
		_discover("rivet_line_true", "loaded_line", target.global_position)


func _on_pinned(victim: Node3D, _damage: float) -> void:
	if last_punch.is_empty() or _clock - float(last_punch["clock"]) > PIN_WINDOW:
		return
	if is_instance_valid(victim) and victim.get_instance_id() != int(last_punch["id"]):
		_discover("rivet_line_drive", "loaded_line", victim.global_position)


func _step_haul(_delta: float) -> void:
	if haul.is_empty():
		return
	var kit = ctx.player.kit
	if not kit.hooked or kit.on_body:
		_end_haul(false)
		return
	var ride = haul["ride"]
	var v = ride.step(_delta)
	if v != null:
		ctx.player.body().set_velocity_now(v)
		return
	_end_haul(true)


# Arrival: the line lets go 2.5 m short and the ball keeps the haul's speed (a ride never cuts it).
func _end_haul(arrived: bool) -> void:
	if arrived:
		ctx.player.body().set_velocity_now(haul["ride"].velocity)
		ctx.player.kit.drop_line("let_go")
	haul = {}
	ctx.player.indicator.clear("rivet_haul")


func _step_preview() -> void:
	var player = ctx.player
	var kit = player.kit
	if _rivet() and haul.is_empty() and player.abilities.selected == AbilityState.LINE and kit.hooked \
			and player.abilities.id_of(AbilityState.LINE) == "line_drive":
		player.indicator.set_shape("rivet_line", geometry(1.0))
	else:
		player.indicator.clear("rivet_line")


func _on_cc_ignored(_kind: String) -> void:
	if not _rivet():
		return
	_shrugs += 1
	if _shrugs == SHRUG_HITS:
		_discover("rivet_shrugged", "", ctx.player.ball_position())


# --- Foundry Cutter and its variants --------------------------------------------------

func _heading() -> Vector3:
	var ult = combat.ultimate
	if ult != null and ult._ride != null:
		return ult._ride.heading
	return combat._flat_aim()


# The lens faces forward: the aim's yaw is clamped CUTTER_CLAMP_DEG off the travel heading.
func beam_dir(aim: Vector3, heading := Vector3.ZERO) -> Vector3:
	var h := _flat(heading if heading != Vector3.ZERO else _heading()).normalized()
	var flat := _flat(aim)
	if flat.length() < 0.001:
		return h
	var angle := h.signed_angle_to(flat.normalized(), Vector3.UP)
	var limit := deg_to_rad(Weapons.CUTTER_CLAMP_DEG)
	return h.rotated(Vector3.UP, clampf(angle, -limit, limit))


func beam_width(id: String) -> float:
	if id == "prism_cutter":
		return Weapons.PRISM_WIDTH + Weapons.PRISM_WIDTH_STEP * float(_class() - 1)
	return float(Weapons.CUTTER_WIDTH[_class() - 1])


# Machines on the beam, nearest first.
func _on_beam(from: Vector3, dir: Vector3, length: float, width: float) -> Array:
	var to := from + dir * length
	var picks: Array = []
	for enemy in _enemies():
		if combat.in_line(from, to, width, enemy.global_position, combat._hull(enemy)):
			picks.append([_flat(enemy.global_position - from).length(), enemy])
	picks.sort_custom(func(a, b): return a[0] < b[0])
	return picks.map(func(p): return p[1])


func _draw_beam(index: int, from: Vector3, dir: Vector3, length: float, width: float) -> void:
	var to := from + dir * length
	var shape: Dictionary = ctx.player.yours({"kind": "line", "from": from, "to": to, "full_to": to, "width": width, "fill": 1.0})
	beam_shapes.append(shape)
	ctx.player.indicator.set_shape("rivet_beam_%d" % index, shape)
	combat.effects.arc(from + Vector3.UP * 0.5, to + Vector3.UP * 0.5, ctx.player.class_color())


func _clear_beams() -> void:
	for i in Weapons.PRISM_BEAMS:
		ctx.player.indicator.clear("rivet_beam_%d" % i)
	beam_shapes = []


# One beam or wave hit. A Warden fills posture as gun bolts do, at half, under the set piece's
# cap; a boss takes half; a machine is cut with no knock.
func _beam_hit(enemy: Node3D, damage: float, from: Vector3) -> void:
	_cut[enemy.get_instance_id()] = true
	if _warden(enemy):
		combat._ult_hit(enemy, "runner", damage, from, false)
	elif _boss(enemy):
		combat.strike(enemy, "runner", damage * Ultimate.BOSS_MULT, "", "special")
	else:
		combat._hit(enemy, "runner", damage, enemy.global_position - from, 0.0, "", "special")


func _peak_beat(beat: int) -> bool:
	var ult = combat.ultimate
	return not ult._peaked and beat >= ceili(ult._beats / 2.0)


func tech(id: String, beat: int, ball: Vector3, aim: Vector3, heft: float) -> int:
	_clear_beams()
	if id == "juggernaut_drive":
		return _bow_wave(ball)
	# The middle beat is the peak's alone: it cuts there, once.
	if _peak_beat(beat):
		return 0
	var extra := int(_knob("ult_volley", 0))
	var hits := 0
	if id == "prism_cutter":
		var centre := beam_dir(aim)
		for i in Weapons.PRISM_BEAMS:
			var dir := centre.rotated(Vector3.UP, deg_to_rad(Weapons.PRISM_SPREAD_DEG * float(i - 1)))
			_draw_beam(i, ball, dir, Weapons.PRISM_LENGTH, beam_width(id))
			for enemy in _on_beam(ball, dir, Weapons.PRISM_LENGTH, beam_width(id)).slice(0, Weapons.PRISM_PIERCE + extra):
				_beam_hit(enemy, Weapons.PRISM_DAMAGE * heft, ball)
				hits += 1
		return hits
	var d := beam_dir(aim)
	_draw_beam(0, ball, d, Weapons.CUTTER_LENGTH, beam_width(id))
	for enemy in _on_beam(ball, d, Weapons.CUTTER_LENGTH, beam_width(id)).slice(0, Weapons.CUTTER_PIERCE + extra):
		_beam_hit(enemy, Weapons.CUTTER_DAMAGE * heft, ball)
		hits += 1
	return hits


# Juggernaut Drive's beat: a chevron bow wave throws machines beside the path ahead outward.
func _bow_wave(ball: Vector3) -> int:
	var heading := _flat(_heading()).normalized()
	var side := Vector3(-heading.z, 0.0, heading.x)
	var thrown := 0
	for enemy in _enemies():
		if _warden(enemy) or _boss(enemy):
			continue
		var to := _flat(enemy.global_position - ball)
		var ahead := to.dot(heading)
		var lateral := to.dot(side)
		if ahead < 0.0 or ahead > Weapons.DRIVE_WAVE_AHEAD or absf(lateral) < Weapons.DRIVE_WAVE_NEAR or absf(lateral) > Weapons.DRIVE_WAVE_FAR:
			continue
		var falloff := 1.0 - (absf(lateral) - Weapons.DRIVE_WAVE_NEAR) / (Weapons.DRIVE_WAVE_FAR - Weapons.DRIVE_WAVE_NEAR)
		enemy.knock(side * signf(lateral) + Vector3.UP * 0.3, Weapons.DRIVE_WAVE_KNOCK * falloff)
		enemy.flash()
		thrown += 1
	return thrown


func peak(id: String, at: Vector3) -> void:
	var heft: float = Ultimate.HEFT_MULT[_class() - 1]
	var hits := 0
	if id == "juggernaut_drive":
		var ult = combat.ultimate
		_shoulder = ult._beat_len if ult._beat_len > 0.0 else 0.35
		return
	if id == "prism_cutter":
		var d := beam_dir(ctx.aim_forward())
		_draw_beam(0, at, d, Weapons.CUTTER_LENGTH, Weapons.PRISM_FOCUS_WIDTH)
		for enemy in _on_beam(at, d, Weapons.CUTTER_LENGTH, Weapons.PRISM_FOCUS_WIDTH).slice(0, Weapons.PRISM_FOCUS_PIERCE):
			_beam_hit(enemy, Weapons.PRISM_FOCUS_DAMAGE * heft, at)
			hits += 1
	else:
		hits = full_cut(at, beam_dir(ctx.aim_forward()), heft)
	if combat.ultimate != null and not combat.ultimate._record.is_empty():
		combat.ultimate._record["volley_hits"] = int(combat.ultimate._record.get("volley_hits", 0)) + hits


# Full Cut: the beam widens and sweeps FULL_CUT_DEG, half to each side of the aim, out to
# FULL_CUT_REACH; every machine it crosses takes FULL_CUT_DAMAGE x heft once, no pierce cap.
func full_cut(at: Vector3, dir: Vector3, heft: float) -> int:
	var half := deg_to_rad(Weapons.FULL_CUT_DEG * 0.5)
	var hits := 0
	for enemy in _enemies():
		var to := _flat(enemy.global_position - at)
		var reach: float = to.length() - combat._hull(enemy)
		if reach > Weapons.FULL_CUT_REACH:
			continue
		var edge := 0.0 if to.length() < 0.01 else atan2(Weapons.FULL_CUT_WIDTH * 0.5 + combat._hull(enemy), to.length())
		if to.length() > 0.01 and absf(dir.signed_angle_to(to.normalized(), Vector3.UP)) > half + edge:
			continue
		_beam_hit(enemy, Weapons.FULL_CUT_DAMAGE * heft, at)
		hits += 1
	ctx.player.indicator.set_shape("rivet_scar", ctx.player.yours({"kind": "cone", "apex": at, "dir": dir,
		"length": Weapons.FULL_CUT_REACH, "half_angle": half}))
	_scar_left = Weapons.FULL_CUT_SCAR
	return hits


# The Breach Skid reach: 1.5 x the class landing radius, plus ult_radius.
func breach_reach() -> float:
	return Weapons.BREACH_REACH_SCALE * float(Ultimate.LANDING_RADIUS[_class() - 1]) + float(_knob("ult_radius", 0.0))


func in_breach(at: Vector3, heading: Vector3, enemy: Node3D) -> bool:
	var to := _flat(enemy.global_position - at)
	if to.length() <= Weapons.BREACH_INNER:
		return true
	if to.length() - combat._hull(enemy) > breach_reach():
		return false
	return to.normalized().dot(heading) >= PlayerBall.SKID_CONE


# The Breach Skid: no plant. A forward cone along the path's heading hits for 60 x heft x chain,
# throws machines forward (x ult_pins) so they pin, exits flat at the banked speed and hands back
# a sprint charge. It counts as a slam for a burrower's marker and a drill crew's rig.
func landing(id: String, at: Vector3, heft: float, chain: float) -> Array:
	var heading := _flat(_heading()).normalized()
	var reach := breach_reach()
	var pins: float = float(_knob("ult_pins", 1.0))
	var hits := 0
	var dealt := 0.0
	for enemy in _enemies():
		if not in_breach(at, heading, enemy):
			continue
		var damage: float = Ultimate.LANDING_DAMAGE * heft * chain
		if _warden(enemy) or _boss(enemy):
			dealt += combat._ult_hit(enemy, "slam", damage, at, true)
		else:
			if enemy.has_method("_on_slammed"):
				enemy._on_slammed(at, 1.0, 1.0)
			var falloff := clampf(1.0 - _flat(enemy.global_position - at).length() / reach, 0.0, 1.0)
			combat._hit(enemy, "slam", slam_force(damage), heading, Ultimate.LANDING_KNOCK * falloff * pins, "", "special", "slam")
			dealt += damage
		hits += 1
	ctx.player.indicator.set_shape("rivet_breach", ctx.player.yours({"kind": "cone", "apex": at, "dir": heading,
		"length": reach, "half_angle": acos(PlayerBall.SKID_CONE)}))
	_scar_left = maxf(_scar_left, Weapons.FULL_CUT_SCAR)
	# Exit flat along the heading at the banked speed: the ride's release keeps its speed and
	# loses the fall (A2-CRITIC: no floor; the speed gift is Sable's alone).
	var ride = combat.ultimate._ride if combat.ultimate != null else null
	if ride != null:
		ride.mode = RideRail.LINE
		ride.velocity = ride.heading * ride.release_speed
	ctx.player.abilities.grant(AbilityState.MOVEMENT, Weapons.BREACH_SPRINT)
	if id == "juggernaut_drive":
		ctx.player.grant_immunity(Ultimate.RECOVER_SECONDS + Weapons.DRIVE_IMMUNE)
	if hits >= FULL_BREACH_HITS:
		_discover("rivet_full_breach", "set_piece", at)
	if id in BEAM_PIECES and _cut.size() >= CUTTER_CARD_CUTS:
		_discover("rivet_foundry_cutter", "set_piece", at)
	_clear_piece()
	return [hits, dealt]


# Juggernaut Drive's flight: every machine whose hull passes within the corridor of the ball's
# centre is rammed once, knock half outward and half forward; machines never stop the ball.
func _step_piece(delta: float) -> void:
	_shoulder = maxf(0.0, _shoulder - delta)
	if _scar_left > 0.0:
		_scar_left -= delta
		if _scar_left <= 0.0:
			ctx.player.indicator.clear("rivet_scar")
			ctx.player.indicator.clear("rivet_breach")
	if _piece != "juggernaut_drive" or combat.ultimate == null or combat.ultimate.phase() != Ultimate.FLIGHT:
		return
	drive_step(ctx.player.ball_position())


func drive_reach() -> float:
	if _shoulder > 0.0:
		return Weapons.DRIVE_SHOULDER_REACH
	return Weapons.DRIVE_REACH + float(_knob("ult_volley", 0))


func drive_step(ball: Vector3) -> int:
	var heading := _flat(_heading()).normalized()
	var heft: float = Ultimate.HEFT_MULT[_class() - 1]
	var body: PhysicsBody3D = ctx.player.body()
	var rams := 0
	for enemy in _enemies():
		var to := _flat(enemy.global_position - ball)
		if enemy is PhysicsBody3D and not _excepted.has(enemy) and to.length() < Weapons.DRIVE_WAVE_AHEAD * 2.0:
			body.add_collision_exception_with(enemy)
			_excepted.append(enemy)
		var id: int = enemy.get_instance_id()
		if _rammed.has(id) or to.length() - combat._hull(enemy) > drive_reach():
			continue
		_rammed[id] = true
		var damage: float = Weapons.DRIVE_DAMAGE * heft * Weapons.DRIVE_RAM_MULT * (Weapons.DRIVE_SHOULDER_MULT if _shoulder > 0.0 else 1.0)
		var side := Vector3(-heading.z, 0.0, heading.x)
		var outward := side * (1.0 if to.dot(side) >= 0.0 else -1.0)
		if _warden(enemy):
			combat.strike(enemy, "ram", ram_force(damage), "", "special")
		elif _boss(enemy):
			combat.strike(enemy, "ram", ram_force(damage * Ultimate.BOSS_MULT), "", "special")
		else:
			combat._hit(enemy, "ram", ram_force(damage), (outward + heading).normalized(), Weapons.DRIVE_KNOCK * float(_knob("ult_pins", 1.0)), "", "special", "overdrive")
		rams += 1
	return rams


func _release_exceptions() -> void:
	var body = ctx.player.body() if ctx != null and ctx.player != null else null
	for enemy in _excepted:
		if body != null and is_instance_valid(enemy):
			body.remove_collision_exception_with(enemy)
	_excepted.clear()


# --- Discoveries ----------------------------------------------------------------------

# A pilot card takes a later physics tick than the framework card it extends (B6's rule); ""
# extends none and waits only for the next tick.
func _discover(id: String, after: String, at: Vector3) -> void:
	_cards[id] = {"after": after, "at": at, "queued": Engine.get_physics_frames()}


func _step_cards() -> void:
	for id in _cards.keys():
		var entry: Dictionary = _cards[id]
		var codex = combat._codex()
		var frame := Engine.get_physics_frames()
		var known: bool = String(entry["after"]) == "" or (codex != null and codex.known(entry["after"]))
		if frame > _card_frame and frame > int(entry["queued"]) and known:
			combat._discover(id, entry["at"])
			_cards.erase(id)
			_card_frame = frame
			break


# --- The tick -------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if ctx == null or ctx.flow == null or not ctx.flow.in_play():
		return
	step(delta)


func step(delta: float) -> void:
	_clock += delta
	_step_pulses(delta)
	_step_haul(delta)
	_step_preview()
	_step_piece(delta)
	_step_cards()


func _clear_piece() -> void:
	_piece = ""
	_cut = {}
	_rammed = {}
	_shoulder = 0.0
	_release_exceptions()
	if ctx != null:
		_clear_beams()


func _clear() -> void:
	pulses.clear()
	if not haul.is_empty():
		_end_haul(false)
	last_punch = {}
	_clear_piece()
	_scar_left = 0.0
	if ctx != null:
		for layer in ["rivet_line", "rivet_haul", "rivet_scar", "rivet_breach"]:
			ctx.player.indicator.clear(layer)
