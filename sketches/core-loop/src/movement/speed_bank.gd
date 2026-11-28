extends RefCounted

const Tuning := preload("res://src/movement/tuning.gd")
const Rules := preload("res://src/movement/ball_rules.gd")
const Augments := preload("res://src/movement/augments.gd")

enum BankMove { NONE, JUMP, SLIDE, SLIDE_FLIGHT }

var state := {}
var chosen := BankMove.NONE
var _airborne := false
var _jumped := false
var _move_held := false
var _brake_held := false
var _rest_ticks := 0
var _rest_braked := false


func clear() -> void:
	state = {}
	_airborne = false
	_jumped = false
	chosen = BankMove.NONE


func reset_inputs() -> void:
	_move_held = false
	_brake_held = false
	_rest_ticks = 0
	_rest_braked = false


func note_jump(air: bool) -> void:
	if not air:
		_jumped = true
	chosen = BankMove.JUMP
	_airborne = false


func tick(player, delta: float) -> void:
	var landed := false
	var jumped := _jumped
	_jumped = false
	var moving: bool = player.intent.move.length_squared() >= 0.02
	var roll_start := moving and not _move_held
	var slide_start: bool = player.intent.brake_held and not _brake_held
	_move_held = moving
	_brake_held = player.intent.brake_held
	var cruise: float = player.tuning.f("cruise")
	if player.frozen() or player.kit.hooked or Augments.holding(player.kit) or player.in_set_piece():
		clear()
		_rest_ticks = 0
		_rest_braked = false
		return
	var floored: bool = player.state.grounded and player.state.contact_normal.y > Tuning.MAX_SLOPE_DOT
	var planar: Vector3 = player.planar_velocity()
	var speed := planar.length()
	var free_rest := _rest_ticks > 0 and not _rest_braked
	if floored and speed <= Tuning.BANK_REST * cruise:
		_rest_ticks += 1
		_rest_braked = _rest_braked or player.intent.brake_held
	else:
		_rest_ticks = 0
		_rest_braked = false
	var probe_grounded := false
	var probe: ShapeCast3D = player.body().probe()
	for i in probe.get_collision_count():
		if probe.get_collision_normal(i).y > Tuning.MAX_SLOPE_DOT:
			probe_grounded = true
	if chosen != BankMove.NONE:
		if not probe_grounded:
			_airborne = true
		elif _airborne:
			landed = true
			chosen = BankMove.NONE
			_airborne = false
	if chosen == BankMove.SLIDE:
		if not floored:
			chosen = BankMove.SLIDE_FLIGHT
		elif not player.intent.brake_held or speed <= Tuning.BANK_REST * cruise:
			chosen = BankMove.NONE
	if slide_start and floored and speed >= Tuning.BANK_ARM * cruise:
		chosen = BankMove.SLIDE
		_airborne = false
	roll_start = roll_start and free_rest and floored and not player.intent.brake_held and speed <= Tuning.BANK_REST * cruise
	if not state.is_empty() and jumped:
		var row: Dictionary = state["row"]
		var u: float = state["t"] / float(row["decay_s"])
		if u >= 1.0 - Tuning.BANK_WINDOW:
			_push(player, planar, maxf(0.0, float(row["ratio"]) * cruise - speed))
		else:
			_push(player, planar, -minf(float(state["bonus"]), maxf(0.0, speed - cruise)))
		state = {}
		return
	if state.is_empty():
		if not floored or not (roll_start or (landed and speed >= Tuning.BANK_ARM * cruise)):
			return
		var row := Tuning.bank_row(player.class_def.id if player.class_def != null else "")
		var bonus := float(row["ratio"]) * cruise - speed
		if bonus <= 0.0:
			return
		if roll_start:
			var heading := Rules.wish_direction(player.intent, player.drive_basis, player.state)
			var target := Vector3(heading.x, 0.0, heading.z).normalized() * float(row["ratio"]) * cruise
			var push := target - planar
			_push(player, push, push.length())
		else:
			_push(player, planar, bonus)
		var banked := minf(bonus, (float(row["ratio"]) - 1.0) * cruise)
		state = {"row": row, "t": 0.0, "bonus0": banked, "bonus": banked}
		return
	if not floored:
		return
	var row: Dictionary = state["row"]
	state["t"] += delta
	var left: float = float(state["bonus0"]) * Tuning.bank_share(row, state["t"] / float(row["decay_s"]))
	var give_back: float = float(state["bonus"]) - left
	state["bonus"] = left
	_push(player, planar, -minf(give_back, maxf(0.0, speed - (cruise + left))))
	if state["t"] >= float(row["decay_s"]):
		clear()


func _push(player, planar: Vector3, dv: float) -> void:
	if absf(dv) < 0.0001 or planar.length_squared() < 0.0001:
		return
	var push := planar.normalized() * dv
	var rigid = player.body()
	rigid.apply_central_impulse(push * rigid.mass)
	var axis := Rules.roll_axis(push, player.state.contact_normal if player.state.grounded else Vector3.UP)
	if axis != Vector3.ZERO:
		rigid.angular_velocity += axis / Tuning.RADIUS
	player.state.velocity += push
