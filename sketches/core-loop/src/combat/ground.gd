extends RefCounted

var ctx


func _init(ctx_ref) -> void:
	ctx = ctx_ref


func height_at(point: Vector3) -> float:
	var boss = ctx.get("boss")
	if ctx.flow != null and ctx.flow.in_arena and is_instance_valid(boss) and boss.has_method("ground_height_at"):
		return boss.ground_height_at(point)
	return ctx.terrain.height(point.x, point.z)


func height(x: float, z: float) -> float:
	return height_at(Vector3(x, 0.0, z))


func heights(points: PackedVector2Array) -> PackedFloat64Array:
	var boss = ctx.get("boss")
	if ctx.flow != null and ctx.flow.in_arena and is_instance_valid(boss) and boss.has_method("ground_height_at"):
		return PackedFloat64Array()
	if not ctx.terrain.has_method("heights"):
		return PackedFloat64Array()
	return ctx.terrain.heights(points)


func drop_point(x: float, z: float, clearance := 1.8) -> Vector3:
	return Vector3(x, height(x, z) + clearance, z)


func on_water(point: Vector3) -> bool:
	if ctx.flow != null and ctx.flow.in_arena:
		return false
	return String(ctx.terrain.material_at(point).get("material", "")) == "water"


func world() -> int:
	if ctx.flow != null and ctx.flow.in_arena:
		return 0
	return ctx.terrain.world()
