extends RefCounted

var ctx
var combat


func setup(context, owner_combat) -> void:
	ctx = context
	combat = owner_combat


func pattern_level(id: String) -> int:
	if ctx.build != null and ctx.build.has_method("pattern_level"):
		return int(ctx.build.pattern_level(id))
	return ctx.run.parts.count(id) if ctx.run != null else 0


func punch_bonus() -> float:
	if ctx != null and ctx.build != null and ctx.build.has_method("punch_bonus"):
		return float(ctx.build.punch_bonus())
	return 0.0


func weapon_damage_mult() -> float:
	return float(ctx.tuning.mod("weapon_damage")) if ctx != null and ctx.tuning != null else 1.0


func scaled_damage(base: float) -> float:
	return (base + punch_bonus()) * weapon_damage_mult()


func flat_aim() -> Vector3:
	var forward: Vector3 = ctx.aim_forward()
	forward.y = 0.0
	return forward.normalized() if forward.length() > 0.01 else Vector3.FORWARD


static func enemy_girth(enemy: Node3D, fallback: float) -> float:
	var r = enemy.get("radius")
	return float(r) if r != null else fallback
