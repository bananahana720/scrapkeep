extends Node

const Combat := preload("res://src/combat/combat.gd")
const SpeedTier := preload("res://src/movement/speed_tier.gd")

const STRIKE_DAMAGE := Combat.STRIKE_DAMAGE
const CONTACT_KINDS := Combat.CONTACT_KINDS
const CHIP := Combat.CHIP
const CRUISE_TIER := SpeedTier.CRUISE

var ctx
var punch_override := -1.0
var strikes: Array[Dictionary] = []


func punch_of(kind: String, force: float) -> float:
	if STRIKE_DAMAGE.has(kind):
		var row: Array = STRIKE_DAMAGE[kind]
		return (row[0] + force * row[1]) * ctx.run.heft()
	return force


func resolve(enemy: Node3D, kind: String, force: float, part := "") -> Dictionary:
	if part == "" and kind in CONTACT_KINDS and enemy.has_method("contact_part"):
		part = enemy.contact_part(ctx.player.ball_position(), kind)
	var punch := punch_of(kind, force)
	var plating: float = enemy.plating_for(kind, part) if enemy.has_method("plating_for") else _fallback_plating(enemy)
	var full := punch >= plating
	var mult: float = enemy.hit_mult(kind, part) if full and enemy.has_method("hit_mult") else 1.0
	return {"punch": punch, "plating": plating, "full": full, "dealt": punch * mult if full else punch * CHIP, "part": part}


func _fallback_plating(_enemy: Node3D) -> float:
	return 0.0


func _emit_strike(enemy: Node3D, kind: String, force: float, result: Dictionary) -> void:
	ctx.events.enemy_struck.emit(enemy, kind, force)
	if not result["full"]:
		ctx.events.strike_deflected.emit(enemy, kind, result["punch"], result["plating"])


func punch_now() -> float:
	if punch_override >= 0.0:
		return punch_override
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
	var result := resolve(enemy, kind, force)
	return result["plating"] <= 0.0 and result["dealt"] >= float(enemy.get("hp"))
