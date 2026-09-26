extends Node

# A stand-in for wave 4's src/boss/boss.gd, so the spine tests can drive the boss flow
# seam: flow calls enter_arena, the double places the ball keeping its velocity, sets
# the flow seams and publishes the arena facts; defeat() publishes the win.

var ctx
var entries := 0
var entry_speeds: Array[float] = []


func setup(ctx_ref) -> void:
	ctx = ctx_ref
	name = "BossDouble"
	ctx.boss = self


func enter_arena(entry_velocity: Vector3) -> void:
	entries += 1
	ctx.flow.boss_active = true
	ctx.flow.boss_plating = 120.0
	var at: Vector3 = ctx.terrain.drop_point(0.0, 0.0, 14.0)
	ctx.player.reset_to(at, entry_velocity)
	ctx.player.body().global_position = at
	entry_speeds.append(Vector2(entry_velocity.x, entry_velocity.z).length())
	ctx.events.boss_arena_entered.emit()
	ctx.events.boss_phase_changed.emit(1, "Requisition")


# The arena's floor and landing spot, which flow's arena rescue reads.
func floor_y() -> float:
	return ctx.terrain.height(0.0, 0.0) - 5.0


func rescue_point() -> Vector3:
	return ctx.terrain.drop_point(0.0, 0.0, 3.0)


func defeat() -> void:
	ctx.events.boss_phase_changed.emit(3, "Eject")
	ctx.events.boss_defeated.emit()
