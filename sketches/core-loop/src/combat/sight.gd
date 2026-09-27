extends RefCounted

const Weapons := preload("res://src/combat/weapons.gd")

# What one enemy sees of the player. Enemies read their target only through
# ball_position(), planar_velocity(), add_external_accel() and crowd_control(), so this
# stands in for the player. While Kest's dust cloak is up, an enemy farther than
# CLOAK_SIGHT of its acquisition range sees only the smoke where the cloak began, and
# fights that.

const REACH := {"chaser": 40.0, "lobber": 75.0, "miniboss": 40.0}
const DEFAULT_REACH := 40.0

var player
var combat
var reach := DEFAULT_REACH
var _enemy: WeakRef


func _init(player_ref, combat_ref, enemy: Node3D, kind: String) -> void:
	player = player_ref
	combat = combat_ref
	reach = REACH.get(kind, DEFAULT_REACH)
	_enemy = weakref(enemy)


func sees() -> bool:
	if combat.cloak_left <= 0.0:
		return true
	var enemy = _enemy.get_ref()
	if enemy == null:
		return true
	# Ghost takes the share to nothing, so no enemy sees through the cloak.
	var share: float = combat.cloak_sight() if combat.has_method("cloak_sight") else Weapons.CLOAK_SIGHT
	return enemy.global_position.distance_to(player.ball_position()) <= reach * share


func ball_position() -> Vector3:
	return player.ball_position() if sees() else combat.cloak_at


func planar_velocity() -> Vector3:
	return player.planar_velocity() if sees() else Vector3.ZERO


func add_external_accel(accel: Vector3) -> void:
	player.add_external_accel(accel)


func crowd_control(kind: String, shove := Vector3.ZERO, interrupts := true) -> bool:
	return player.crowd_control(kind, shove, interrupts)
