extends "res://src/combat/actives/active_base.gd"

const ActiveFx := preload("res://src/combat/actives/active_fx.gd")
const Palette := preload("res://src/core/palette.gd")

const ROCKETS := 4
const BASE_DAMAGE := 16.0
const SPLASH := 0.5
const BLAST_RADIUS := 3.0
const HIT_RADIUS := 1.4
const DEFAULT_GIRTH := 0.6
const LOCK_REACH := 42.0
const SEEK_REACH := 24.0
const LAUNCH_SPEED := 18.0
const MAX_SPEED := 40.0
const ACCEL := 46.0
const TURN := 5.0
const TURN_LATE := 11.0
const FUEL := 2.6
const KNOCK := 14.0
const CHAIN_RANGE := 8.0
const CHAIN_FALLOFF := 0.7
const COLOR := Palette.AMBER
const KIND := "rocket"
const SOURCE := "special"

var rockets: Array = []
var bursts := 0
var _generation := 0


func clear() -> void:
	rockets.clear()
	_generation += 1


func count_for(bonus: int) -> int:
	return ROCKETS + bonus + pattern_level("cross_split")


func damage() -> float:
	return scaled_damage(BASE_DAMAGE)


func fire(_rack, _row: Dictionary, bonus: int) -> int:
	var count := count_for(bonus)
	var ball: Vector3 = ctx.player.ball_position()
	var forward := flat_aim()
	var side := forward.cross(Vector3.UP).normalized()
	var targets: Array = combat.nearest_enemies(ball, LOCK_REACH, count)
	for target in targets:
		combat.effects.spark(target.global_position + Vector3.UP, ActiveFx.peak(COLOR))
	var dmg := damage()
	for i in count:
		var spread := 0.0 if count == 1 else lerpf(-1.0, 1.0, float(i) / float(count - 1))
		var dir := (forward + Vector3.UP * 0.7 + side * spread * 0.8).normalized()
		rockets.append({"pos": ball + Vector3.UP * 0.8 + side * spread * 0.6, "vel": dir * LAUNCH_SPEED,
			"target": targets[i % targets.size()] if not targets.is_empty() else null,
			"fuel": FUEL, "damage": dmg})
	return count


func step(delta: float) -> void:
	if rockets.is_empty():
		return
	var generation := _generation
	var flying: Array = []
	for rocket in rockets.duplicate():
		if not _fly(rocket, delta):
			flying.append(rocket)
		if _generation != generation:
			return
	rockets = flying


func _fly(rocket: Dictionary, delta: float) -> bool:
	var pos: Vector3 = rocket["pos"]
	var target = rocket["target"]
	if target == null or not is_instance_valid(target) or target.is_dead():
		target = combat._nearest(pos, SEEK_REACH, [])
		rocket["target"] = target
	var vel: Vector3 = rocket["vel"]
	var speed := minf(vel.length() + ACCEL * delta, MAX_SPEED)
	var heading := vel.normalized()
	if target != null:
		var want: Vector3 = (target.global_position + Vector3.UP * 0.6 - pos).normalized()
		var flown := 1.0 - float(rocket["fuel"]) / FUEL
		var turn := lerpf(TURN, TURN_LATE, flown) * delta
		var angle := heading.angle_to(want)
		heading = want if angle <= turn else heading.slerp(want, turn / angle).normalized()
	vel = heading * speed
	var next := pos + vel * delta
	combat.effects.arc(pos, next, ActiveFx.peak(COLOR))
	rocket["pos"] = next
	rocket["vel"] = vel
	rocket["fuel"] = float(rocket["fuel"]) - delta
	var struck = _contact(next)
	if struck != null or float(rocket["fuel"]) <= 0.0:
		_burst(rocket, struck)
		return true
	return false


func _contact(at: Vector3):
	for enemy in combat.get_tree().get_nodes_in_group(Groups.ENEMY):
		if not enemy.is_dead() and enemy.global_position.distance_to(at) <= HIT_RADIUS + enemy_girth(enemy, DEFAULT_GIRTH):
			return enemy
	return null


func _burst(rocket: Dictionary, struck) -> void:
	bursts += 1
	var at: Vector3 = rocket["pos"]
	var dmg: float = rocket["damage"]
	var push: Vector3 = rocket["vel"]
	combat.effects.ring(at, BLAST_RADIUS, ActiveFx.peak(COLOR))
	ctx.break_props(at, BLAST_RADIUS, "scrap_rocket")
	if struck != null:
		combat._hit(struck, KIND, dmg, push, KNOCK, "", SOURCE)
	for enemy in combat.nearest_enemies(at, BLAST_RADIUS, 16):
		if enemy != struck and not enemy.is_dead():
			combat._hit(enemy, KIND, dmg * SPLASH, enemy.global_position - at, KNOCK * 0.6, "", SOURCE)
	var jumps := pattern_level("chain_arc")
	if struck != null and jumps > 0:
		combat._chain(struck, at, {"damage": dmg, "chain_jumps": jumps, "chain_range": CHAIN_RANGE,
			"chain_falloff": CHAIN_FALLOFF, "color": ActiveFx.peak(COLOR), "kind": KIND, "knock": KNOCK, "source": SOURCE})
