extends RefCounted

# The ground combat's enemies, telegraphs and shells stand on. On a stage it is the
# world's terrain. In the arena the stage terrain stays parked under the bowl, so when
# the boss module offers ground_height_at(point) its floor wins: a ring centres on the
# floor you are rolling on and a lobber aims at it. Everything else here only needs
# height and drop_point, the two terrain calls combat makes.

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


# The terrain's height at many (x, z) points, for a telegraph's paint. Empty in the arena (the boss
# floor reads the whole point) or over a terrain without the batch: the caller asks height_at per point.
func heights(points: PackedVector2Array) -> PackedFloat64Array:
	var boss = ctx.get("boss")
	if ctx.flow != null and ctx.flow.in_arena and is_instance_valid(boss) and boss.has_method("ground_height_at"):
		return PackedFloat64Array()
	if not ctx.terrain.has_method("heights"):
		return PackedFloat64Array()
	return ctx.terrain.heights(points)


func drop_point(x: float, z: float, clearance := 1.8) -> Vector3:
	return Vector3(x, height(x, z) + clearance, z)


# Whether a point stands in water: the flood's basin or a water floor on the stage map
# (terrain.material_at). An arena floor is never water.
func on_water(point: Vector3) -> bool:
	if ctx.flow != null and ctx.flow.in_arena:
		return false
	return String(ctx.terrain.material_at(point).get("material", "")) == "water"


# The stage's world, for the Highdraft's ring-outs (enemy.gd). An arena reads 0: its floor
# is the boss module's, so nothing there rings out.
func world() -> int:
	if ctx.flow != null and ctx.flow.in_arena:
		return 0
	return ctx.terrain.world()
