extends "res://src/foe.gd"

const Projectile := preload("res://src/projectile.gd")

const RANGE := 75.0
const FIRE_INTERVAL := 3.2
const FLIGHT := 1.7
const SHOT_DAMAGE := 12.0

var _fire_clock := 1.4


# It never moves, so the only way it threatens you is by punishing a player who
# stands still to fight. Lead the shot at where you are, not where you are going.
func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if target == null or run == null or not run.live():
		return
	_fire_clock -= delta
	if _fire_clock > 0.0:
		return
	_fire_clock = FIRE_INTERVAL
	var to: Vector3 = target.ball_position()
	if global_position.distance_to(to) > RANGE:
		return
	var shot := Projectile.new()
	get_parent().add_child(shot)
	shot.setup(global_position + Vector3.UP * 2.2, to, FLIGHT, SHOT_DAMAGE * (1.0 + 0.18 * (run.tier() - 1)), target, run)
