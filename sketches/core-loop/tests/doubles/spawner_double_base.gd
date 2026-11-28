extends Node

const Combat := preload("res://src/combat/combat.gd")
const SpeedTier := preload("res://src/core/speed_tier.gd")

const STRIKE_DAMAGE := Combat.STRIKE_DAMAGE
const CHIP := Combat.CHIP
const CRUISE_TIER := SpeedTier.CRUISE

var ctx
var strikes: Array[Dictionary] = []


func punch_of(kind: String, force: float) -> float:
	if STRIKE_DAMAGE.has(kind):
		var row: Array = STRIKE_DAMAGE[kind]
		return (row[0] + force * row[1]) * ctx.run.heft()
	return force


func _strike_part(_enemy: Node3D, _kind: String, part: String) -> String:
	return part


func _strike_plating(enemy: Node3D, _kind: String, _part: String) -> float:
	return plating_of(enemy)


func _strike_result(enemy: Node3D, kind: String, force: float, part := "") -> Dictionary:
	part = _strike_part(enemy, kind, part)
	var punch := punch_of(kind, force)
	var plating := _strike_plating(enemy, kind, part)
	var full := punch >= plating
	var mult: float = enemy.hit_mult(kind, part) if full and enemy.has_method("hit_mult") else 1.0
	return {"punch": punch, "plating": plating, "full": full, "dealt": punch * mult if full else punch * CHIP, "part": part}


func _emit_strike(enemy: Node3D, kind: String, force: float, result: Dictionary) -> void:
	ctx.events.enemy_struck.emit(enemy, kind, force)
	if not result["full"]:
		ctx.events.strike_deflected.emit(enemy, kind, result["punch"], result["plating"])


func punch_now() -> float:
	if ctx.player.speed_tier() < CRUISE_TIER:
		return 0.0
	return punch_of("ram", ctx.player.planar_velocity().length())


func plating_of(enemy: Node3D) -> float:
	if not is_instance_valid(enemy) or not enemy.has_method("plating_now"):
		return 0.0
	return enemy.plating_now()


func integrity_of(enemy: Node3D) -> float:
	if not is_instance_valid(enemy):
		return 1.0
	return clampf(float(enemy.get("hp")) / maxf(0.001, float(enemy.get("max_hp"))), 0.0, 1.0)


func would_crush(enemy: Node3D, kind: String, force: float) -> bool:
	if not is_instance_valid(enemy) or (enemy.has_method("is_dead") and enemy.is_dead()):
		return false
	var result := _strike_result(enemy, kind, force)
	return result["plating"] <= 0.0 and result["dealt"] >= float(enemy.get("hp"))
