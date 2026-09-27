extends Node

# A stand-in for wave 4's src/boss/boss.gd, so the spine tests can drive the boss flow
# seam: flow calls enter_arena, the double lays its own floor, places the ball keeping
# its velocity, sets the flow seams and publishes the arena facts; defeat() publishes
# the win. The stage maps are parked in the arena (CONTRACTS, stand-down), so the
# double brings a flat world-layer floor at the stage ground's height under the arena
# spot and takes it away on the next stage_entered.

const FLOOR_SIZE := Vector3(240.0, 2.0, 240.0)

var ctx
var entries := 0
var entry_speeds: Array[float] = []
var arena_floor: StaticBody3D


func setup(ctx_ref) -> void:
	ctx = ctx_ref
	name = "BossDouble"
	ctx.boss = self
	ctx.events.stage_entered.connect(func(_stage: int, _retry: bool): _remove_floor())


func enter_arena(entry_velocity: Vector3) -> void:
	entries += 1
	ctx.flow.boss_active = true
	ctx.flow.boss_plating = 120.0
	_lay_floor()
	var at: Vector3 = ctx.terrain.drop_point(0.0, 0.0, 14.0)
	ctx.player.reset_to(at, entry_velocity)
	ctx.player.body().global_position = at
	entry_speeds.append(Vector2(entry_velocity.x, entry_velocity.z).length())
	ctx.events.boss_arena_entered.emit()
	ctx.events.boss_phase_changed.emit(1, "Requisition")


# The arena's floor and landing spot, which flow's arena rescue reads.
func floor_y() -> float:
	return _floor_top() - 5.0


func rescue_point() -> Vector3:
	return Vector3(0.0, _floor_top() + 3.0, 0.0)


func defeat() -> void:
	ctx.events.boss_phase_changed.emit(3, "Eject")
	ctx.events.boss_defeated.emit()


func _floor_top() -> float:
	return ctx.terrain.height(0.0, 0.0)


func _lay_floor() -> void:
	if is_instance_valid(arena_floor):
		return
	arena_floor = StaticBody3D.new()
	arena_floor.name = "BossDoubleFloor"
	arena_floor.collision_layer = 1
	arena_floor.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = FLOOR_SIZE
	shape.shape = box
	arena_floor.add_child(shape)
	ctx.root.add_child(arena_floor)
	arena_floor.global_position = Vector3(0.0, _floor_top() - FLOOR_SIZE.y * 0.5, 0.0)


func _remove_floor() -> void:
	if is_instance_valid(arena_floor):
		arena_floor.collision_layer = 0
		arena_floor.queue_free()
	arena_floor = null
