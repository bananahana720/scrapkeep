extends "res://tests/doubles/spawner_double_base.gd"

const CHASER_HP := 80.0

var delay_deaths := false
var _pending: Array[Node3D] = []


class DoubleEnemy:
	extends CharacterBody3D

	var kind := ""
	var hp := 1.0
	var max_hp := 1.0
	var plating := 0.0
	var dead := false
	var knocks := 0

	func is_dead() -> bool:
		return dead

	func knock(_direction: Vector3, _force: float) -> void:
		knocks += 1

	func flash() -> void:
		pass


func setup(ctx_ref) -> void:
	ctx = ctx_ref
	name = "SpawnerDouble"


func spawn_enemy(kind: String, at: Vector3, _affix_id := "") -> Node3D:
	var enemy := DoubleEnemy.new()
	enemy.kind = kind
	var def: Dictionary = ctx.flow.stage_def()
	match kind:
		"warden":
			enemy.max_hp = def["warden_hp"]
			enemy.plating = def["warden_plating"]
		_:
			enemy.max_hp = CHASER_HP
	enemy.hp = enemy.max_hp
	enemy.add_to_group("enemy")
	enemy.collision_layer = 0
	enemy.collision_mask = 0
	enemy.set_collision_layer_value(3, true)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 1.0
	capsule.height = 3.0
	shape.shape = capsule
	enemy.add_child(shape)
	ctx.root.add_child(enemy)
	enemy.global_position = at + Vector3.UP * 1.5
	ctx.events.enemy_spawned.emit(enemy, kind)
	return enemy


func strike(enemy: Node3D, kind: String, force: float) -> void:
	if not is_instance_valid(enemy) or enemy.dead:
		return
	var result := _strike_result(enemy, kind, force)
	strikes.append({"kind": kind, "force": force, "punch": result["punch"], "plating": result["plating"]})
	_emit_strike(enemy, kind, force, result)
	enemy.hp -= result["dealt"]
	if enemy.hp <= 0.0:
		enemy.dead = true
		if delay_deaths:
			_pending.append(enemy)
		else:
			_die(enemy)


func finish_pending() -> void:
	for enemy in _pending:
		if is_instance_valid(enemy):
			_die(enemy)
	_pending.clear()


func _die(enemy: Node3D) -> void:
	ctx.run.record_kill(enemy.kind, enemy.global_position, 0)
	enemy.queue_free()


func plating_of(enemy: Node3D) -> float:
	return enemy.plating if is_instance_valid(enemy) else 0.0
