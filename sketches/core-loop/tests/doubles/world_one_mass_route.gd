extends RefCounted

# The Mass-R fixture (BUILD-SYSTEMS.md, "Mass becomes the pilot's action", Rivet row): one
# fixed route, the same speed and the same two contacts at every mass. Rivet already turns
# heft into punch in combat.gd punch_of(); this fixture reads that one contribution and
# nothing here multiplies mass into damage. It also drives a real turn, so a test can show
# handling does not move with mass.

const Intent := preload("res://src/movement/intent.gd")

# Raw mass at the proposed saturation points: none, half, and heft IV (run_state.gd).
const MASSES := [0.0, 450.0, 990.0]
# Planar speed of the ram and the smash, held identical at every mass (m/s).
const SPEED := 30.0
# The turn probe: forward speed, physics frames of side input.
const TURN_SPEED := 14.0
const TURN_FRAMES := 30
# Frames the ball is held at the start pose first, so no row inherits the last row's motion.
const SETTLE_FRAMES := 5
const CLASS_INDEX := 1  # Rivet


# A bare target: no plating, no hit multiplier, so dealt is the punch itself.
class Dummy:
	extends Node3D
	var hp := 1.0e9

	func take_damage(amount: float, _source := "") -> float:
		hp -= amount
		return amount

	func is_dead() -> bool:
		return false


# One row per mass. Needs a started Rivet run on `game` and an awaitable tree.
func measure(game, mass: float):
	game.run.mass = mass
	var combat = game.combat
	var kit = game.player.kit
	var dummy := Dummy.new()
	game.add_child(dummy)
	kit.sprinting = true
	var ram: Dictionary = combat.resolve(dummy, "ram", SPEED)
	var before: float = dummy.hp
	combat.strike(dummy, "ram", SPEED)
	var ram_delivered: float = before - dummy.hp
	kit.sprinting = false
	var smash: Dictionary = combat.resolve(dummy, "slam", SPEED)
	dummy.queue_free()
	var heading = await _turn(game)
	return {"mass": mass, "heft": combat.heft(), "ram_dealt": float(ram["dealt"]), "ram_delivered": ram_delivered,
		"smash_dealt": float(smash["dealt"]), "heading": heading}


# Roll at TURN_SPEED, hold a sideways input for TURN_FRAMES, return the velocity heading
# (radians) so equal handling reads as equal headings.
func _turn(game):
	var ctx = game.ctx
	var spawn: Vector3 = ctx.terrain.spawn_point(1)
	var at: Vector3 = ctx.terrain.drop_point(spawn.x, spawn.z, 1.05)
	game.player.source = Intent.Scripted.new()
	game.player.reset_to(at, Vector3(0.0, 0.0, -TURN_SPEED))
	for _i in SETTLE_FRAMES:
		await game.get_tree().physics_frame
		game.player.reset_to(at, Vector3(0.0, 0.0, -TURN_SPEED))
	var source := Intent.Scripted.new()
	source.hold = {"move": Vector2(1.0, 0.0)}
	game.player.source = source
	for _i in TURN_FRAMES:
		await game.get_tree().physics_frame
	var v: Vector3 = game.player.planar_velocity()
	game.player.source = Intent.Scripted.new()
	return atan2(v.x, -v.z)
