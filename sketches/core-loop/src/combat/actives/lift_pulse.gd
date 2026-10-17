extends RefCounted

const Palette := preload("res://src/core/palette.gd")

# The Lift Pulse (Highdraft Roosts): a cargo lift fan turned sideways. A fire commits one cone
# along the aim, draws it (a shimmer ring round the fan and the cone's edges: the tell) and shoves
# every machine inside it straight away from the ball. The knock grows with each heft class, so
# light pilots push chasers and a heavy ball throws heavies off an island edge ("Ring-outs",
# 17 Oct). Damage is small: the island edge does the killing (that rule lives with the enemies).
# Only machines inside the drawn cone are hit.
#
# It stacks into a strong build: weapon damage mods and punch scale the hit, Spiral Wave widens
# the cone, Cross Split adds an echo pulse per level through the same cone, Chain Arc jumps from
# each machine the first pulse hits, and a full ultimate meter's overflow pieces each add knock.

const RANGE := 10.0
# Degrees either side of the aim.
const HALF_ANGLE := 35.0
const SPREAD_PER_LEVEL := 10.0
const MAX_HALF_ANGLE := 75.0
# A machine this far above or below the ball is on another level and out of the cone.
const HEIGHT_BAND := 3.0
const BASE_DAMAGE := 6.0
const KNOCK := 18.0
const KNOCK_PER_CLASS := 12.0
# Share of extra knock each banked overflow piece adds.
const BONUS_KNOCK := 0.2
const ECHO_GAP := 0.2
const ECHO_SHARE := 0.6
const FAN_RADIUS := 1.6
# The cone's edges are drawn as short strokes so the arcs barely jitter: a shimmer, not a bolt.
const EDGE_STEP := 1.25
const CHAIN_RANGE := 8.0
const CHAIN_FALLOFF := 0.7
const COLOR := Palette.ARC
const KIND := "lift_pulse"
const IMPACT := "ram"
const SOURCE := "special"

var ctx
var combat
# Committed pulses still to land: {"cone", "at" (seconds until it lands), "share"}.
var echoes: Array = []
var pulses := 0
var last_cone := {}


func setup(context, owner_combat) -> void:
	ctx = context
	combat = owner_combat


func clear() -> void:
	echoes.clear()


func damage() -> float:
	var punch := 0.0
	if ctx.build != null and ctx.build.has_method("punch_bonus"):
		punch = float(ctx.build.punch_bonus())
	return (BASE_DAMAGE + punch) * ctx.tuning.mod("weapon_damage")


func knock_for(bonus: int) -> float:
	var heft_class := 1
	if ctx.run != null and ctx.run.has_method("heft_class"):
		heft_class = int(ctx.run.heft_class())
	return (KNOCK + KNOCK_PER_CLASS * float(maxi(heft_class, 1) - 1)) * (1.0 + BONUS_KNOCK * float(bonus))


func half_angle() -> float:
	return minf(HALF_ANGLE + SPREAD_PER_LEVEL * float(_pattern("spiral_wave")), MAX_HALF_ANGLE)


# The cone a fire commits: the fan at the ball, facing the flat aim. Drawing and hitting both read it.
func cone(bonus: int) -> Dictionary:
	var forward: Vector3 = ctx.aim_forward()
	forward.y = 0.0
	forward = forward.normalized() if forward.length() > 0.01 else Vector3.FORWARD
	return {"origin": ctx.player.ball_position(), "forward": forward, "range": RANGE,
		"half_angle": half_angle(), "knock": knock_for(bonus), "damage": damage()}


static func inside(shape: Dictionary, at: Vector3) -> bool:
	var origin: Vector3 = shape["origin"]
	if absf(at.y - origin.y) > HEIGHT_BAND:
		return false
	var flat := Vector3(at.x - origin.x, 0.0, at.z - origin.z)
	if flat.length() > float(shape["range"]):
		return false
	if flat.length() < 0.01:
		return true
	return rad_to_deg(flat.angle_to(shape["forward"])) <= float(shape["half_angle"])


func fire(_rack, _row: Dictionary, bonus: int) -> int:
	var shape := cone(bonus)
	last_cone = shape
	var echo_count := _pattern("cross_split")
	for i in echo_count:
		echoes.append({"cone": shape, "at": ECHO_GAP * float(i + 1), "share": ECHO_SHARE})
	var struck := _pulse(shape, 1.0)
	var jumps := _pattern("chain_arc")
	if jumps > 0:
		for enemy in struck:
			if is_instance_valid(enemy) and not enemy.is_dead():
				combat._chain(enemy, enemy.global_position, {"damage": float(shape["damage"]), "chain_jumps": jumps,
					"chain_range": CHAIN_RANGE, "chain_falloff": CHAIN_FALLOFF, "color": COLOR, "kind": KIND,
					"knock": float(shape["knock"]) * 0.3, "source": SOURCE})
	return 1 + echo_count


func step(delta: float) -> void:
	if echoes.is_empty():
		return
	var waiting: Array = []
	for echo in echoes:
		echo["at"] = float(echo["at"]) - delta
		if float(echo["at"]) <= 0.0:
			_pulse(echo["cone"], float(echo["share"]))
		else:
			waiting.append(echo)
	echoes = waiting


# One pulse through a committed cone: draw it, then shove every live machine inside it.
func _pulse(shape: Dictionary, share: float) -> Array:
	pulses += 1
	_draw(shape)
	var origin: Vector3 = shape["origin"]
	var struck: Array = []
	for enemy in combat.get_tree().get_nodes_in_group("enemy"):
		if enemy.is_dead() or not inside(shape, enemy.global_position):
			continue
		var away: Vector3 = enemy.global_position - origin
		away.y = 0.0
		if away.length() < 0.01:
			away = shape["forward"]
		combat._hit(enemy, KIND, float(shape["damage"]) * share, away, float(shape["knock"]) * share, "", SOURCE, IMPACT)
		struck.append(enemy)
	return struck


func _draw(shape: Dictionary) -> void:
	var origin: Vector3 = shape["origin"]
	var forward: Vector3 = shape["forward"]
	var reach: float = shape["range"]
	var half := deg_to_rad(float(shape["half_angle"]))
	combat.effects.ring(origin, FAN_RADIUS, COLOR)
	var lift := Vector3.UP * 0.4
	for side in [-1.0, 1.0]:
		var edge := forward.rotated(Vector3.UP, half * side)
		var steps := ceili(reach / EDGE_STEP)
		for i in steps:
			combat.effects.arc(origin + lift + edge * reach * float(i) / steps, origin + lift + edge * reach * float(i + 1) / steps, COLOR)
	var arc_steps := maxi(2, ceili(reach * half * 2.0 / EDGE_STEP))
	for i in arc_steps:
		var a := forward.rotated(Vector3.UP, lerpf(-half, half, float(i) / arc_steps))
		var b := forward.rotated(Vector3.UP, lerpf(-half, half, float(i + 1) / arc_steps))
		combat.effects.arc(origin + lift + a * reach, origin + lift + b * reach, COLOR)


func _pattern(id: String) -> int:
	if ctx.build != null and ctx.build.has_method("pattern_level"):
		return int(ctx.build.pattern_level(id))
	return ctx.run.parts.count(id) if ctx.run != null else 0
