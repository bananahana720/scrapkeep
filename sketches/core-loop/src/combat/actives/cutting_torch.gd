extends RefCounted

const Palette := preload("res://src/core/palette.gd")
const Hitscan := preload("res://src/combat/hitscan.gd")

# The Cutting Torch (Redjaw Workshops): a shipbreaker's plate torch on the ball's nose. The press
# winds up for WINDUP (the row's) with a guide line out along the aim, the outline of exactly the
# lane the beam will burn; then the beam lights for BEAM_SECONDS and sweeps after the aim at up to
# SWEEP radians a second. Damage lands only inside the lane drawn this tick, tested by combat's
# shared lane rule (Combat.in_line: flat, hull and forgiveness as every lane skill), and a wall
# stops the lane where it stops the drawing.
#
# It beats plating: every machine in the lane soaks heat at the torch's burn rate, and a cut
# lands when its heat reaches the machine's plating (combat's own plating rule, shred taken off),
# so every cut lands in full and plating only sets the size of each bite; heat over time is the
# same on any plate. A machine keeps its heat between burns until the stage clears, so a plate
# heavier than one burn delivers (a stage-3 miniboss, a last vault) is cut by the next burn, never
# shrugged off. That suits the Dig, the Plate world. A posture fighter (a Warden, a boss) is cut
# on the plain cadence and keeps its own rules. A press during a live burn ends it and winds up
# the next; the heat carries over.
#
# It stacks into a strong build: weapon damage mods and punch raise the burn, Spiral Wave fans out
# one more beam per level, and a full ultimate meter's overflow (the rack's bonus) burns longer.

const BEAM_SECONDS := 1.6
const BONUS_SECONDS := 0.25
const REACH := 14.0
const WIDTH := 0.9
const SWEEP := 3.5
# Heat a second while a machine sits in the lane; a cut lands at CUT_DAMAGE or the plating,
# whichever is more, so an unplated machine takes a cut every CUT_DAMAGE / BURN seconds.
const BURN := 60.0
const CUT_DAMAGE := 7.5
const FAN_DEG := 12.0
const LIFT := 0.5
const KNOCK := 0.0
const COLOR := Palette.HAZARD
const KIND := "torch"
const IMPACT := "runner"
const SOURCE := "special"
const LAYER := "active_cutting_torch_%d"

var ctx
var combat
var guiding := false
var beam_left := 0.0
var heading := Vector3.FORWARD
var cuts := 0
# The lanes drawn this tick, one per beam: {from, to, width}. What is drawn is what cuts.
var lanes: Array = []
var _beams := 1
var _burn := BURN
var _heat := {}


func setup(context, owner_combat) -> void:
	ctx = context
	combat = owner_combat


# A stage clear, a death or a new run: the burn, its drawing and every machine's heat go.
func clear() -> void:
	_heat.clear()
	_end()


# A Jam in the wind-up: the guide goes; heat already built stays.
func cancel() -> void:
	_end()


func _end() -> void:
	guiding = false
	beam_left = 0.0
	_erase()


func beams_for() -> int:
	return 1 + _pattern("spiral_wave")


# Heat a second, after the build: punch adds to a cut, weapon damage mods scale it.
func burn() -> float:
	var punch := 0.0
	if ctx.build != null and ctx.build.has_method("punch_bonus"):
		punch = float(ctx.build.punch_bonus())
	return BURN * (CUT_DAMAGE + punch) / CUT_DAMAGE * ctx.tuning.mod("weapon_damage")


func begin(_rack, _row: Dictionary) -> void:
	_beams = beams_for()
	heading = _aim()
	guiding = true
	_commit()


func fire(_rack, _row: Dictionary, bonus: int) -> int:
	if not guiding:
		_beams = beams_for()
		heading = _aim()
	guiding = false
	_burn = burn()
	beam_left = BEAM_SECONDS + BONUS_SECONDS * bonus
	_commit()
	return _beams


func step(delta: float) -> void:
	if not guiding and beam_left <= 0.0:
		return
	_turn(delta)
	_commit()
	if guiding:
		return
	_cut(delta)
	beam_left -= delta
	if beam_left <= 0.0:
		_end()


func _turn(delta: float) -> void:
	var want := _aim()
	var angle := heading.angle_to(want)
	var turn := SWEEP * delta
	heading = want if angle <= turn else heading.slerp(want, turn / angle).normalized()


# Lays this tick's lanes and draws them: the guide as an outline, the beam filled.
func _commit() -> void:
	var from: Vector3 = ctx.player.ball_position()
	lanes.clear()
	for i in _beams:
		var offset := 0.0 if _beams == 1 else lerpf(-0.5, 0.5, float(i) / float(_beams - 1)) * deg_to_rad(FAN_DEG) * float(_beams - 1)
		var dir := heading.rotated(Vector3.UP, offset)
		var lane := {"kind": "line", "from": from, "to": _reach(from, dir), "width": WIDTH, "fill": 0.0 if guiding else 1.0}
		lanes.append(lane)
		ctx.player.indicator.set_shape(LAYER % i, ctx.player.yours(lane.duplicate()))
		if not guiding:
			combat.effects.arc(from + Vector3.UP * LIFT, lane["to"] + Vector3.UP * LIFT, COLOR)


func _reach(from: Vector3, dir: Vector3) -> Vector3:
	var to := from + dir * REACH
	var space: PhysicsDirectSpaceState3D = combat.get_viewport().get_world_3d().direct_space_state
	var cover := space.intersect_ray(PhysicsRayQueryParameters3D.create(from + Vector3.UP * LIFT, to + Vector3.UP * LIFT, Hitscan.WORLD))
	return Vector3(cover["position"].x, from.y, cover["position"].z) if not cover.is_empty() else to


func _cut(delta: float) -> void:
	for enemy in combat.get_tree().get_nodes_in_group("enemy"):
		if enemy.is_dead() or not _in_lanes(enemy):
			continue
		var id: int = enemy.get_instance_id()
		var heat: float = float(_heat.get(id, 0.0)) + _burn * delta
		var bite := maxf(CUT_DAMAGE * _burn / BURN, _plate(enemy))
		if heat >= bite:
			cuts += 1
			combat.effects.spark(enemy.global_position + Vector3.UP, COLOR)
			combat._hit(enemy, KIND, heat, enemy.global_position - ctx.player.ball_position(), KNOCK, "", SOURCE, IMPACT)
			heat = 0.0
		_heat[id] = heat


func _in_lanes(enemy: Node3D) -> bool:
	var hull: float = combat._hull(enemy)
	for lane in lanes:
		if combat.in_line(lane["from"], lane["to"], lane["width"], enemy.global_position, hull):
			return true
	return false


# The plating a torch cut meets now, by the same rule combat.resolve() applies; 0 for a posture
# fighter, which judges its own hits.
func _plate(enemy: Node3D) -> float:
	if enemy.has_method("fight") and enemy.fight() == "posture":
		return 0.0
	if enemy.has_method("plating_for"):
		return maxf(0.0, enemy.plating_for(KIND, "") - combat.shred_of(enemy))
	return 0.0


func _aim() -> Vector3:
	var forward: Vector3 = ctx.aim_forward()
	forward.y = 0.0
	return forward.normalized() if forward.length() > 0.01 else Vector3.FORWARD


func _erase() -> void:
	lanes.clear()
	if ctx == null or ctx.player == null or ctx.player.indicator == null:
		return
	for i in _beams:
		ctx.player.indicator.clear(LAYER % i)


func _pattern(id: String) -> int:
	if ctx.build != null and ctx.build.has_method("pattern_level"):
		return int(ctx.build.pattern_level(id))
	return ctx.run.parts.count(id) if ctx.run != null else 0
