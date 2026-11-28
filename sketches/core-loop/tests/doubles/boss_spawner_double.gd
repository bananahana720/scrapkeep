extends "res://tests/doubles/spawner_double_base.gd"

var spawned: Array[Node3D] = []


class Marker:
	extends Node3D

	var kind := "lobber"
	var hp := 26.0
	var max_hp := 26.0
	var plating := 0.0
	var radius := 1.0
	var half_height := 1.0
	var terrain

	func is_dead() -> bool:
		return false

	func knock(_direction: Vector3, _force: float) -> void:
		pass

	func flash() -> void:
		pass

	func take_damage(amount: float) -> float:
		hp -= amount
		return amount


func setup(ctx_ref) -> void:
	ctx = ctx_ref
	name = "BossSpawnerDouble"


func spawn_enemy(kind: String, at: Vector3, _affix_id := "") -> Node3D:
	if kind != "lobber":
		return null
	var marker := Marker.new()
	marker.add_to_group("enemy")
	ctx.root.add_child(marker)
	marker.global_position = at
	spawned.append(marker)
	ctx.events.enemy_spawned.emit(marker, kind)
	return marker


func force_for(kind: String, punch: float) -> float:
	var row: Array = STRIKE_DAMAGE[kind]
	return (punch / ctx.run.heft() - row[0]) / row[1]


func strike(enemy: Node3D, kind: String, force: float, part := "") -> void:
	if not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
		return
	if enemy.has_method("is_dead") and enemy.is_dead():
		return
	var result := resolve(enemy, kind, force, part)
	strikes.append({"enemy": enemy, "kind": kind, "force": force, "result": result})
	_emit_strike(enemy, kind, force, result)
	if enemy.has_method("on_struck"):
		enemy.on_struck(kind, result["part"], result)
	enemy.take_damage(result["dealt"])
