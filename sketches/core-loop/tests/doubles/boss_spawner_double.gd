extends "res://tests/doubles/spawner_double_base.gd"

const CONTACT_KINDS := Combat.CONTACT_KINDS

var punch_override := -1.0
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


func _strike_part(enemy: Node3D, kind: String, part: String) -> String:
	if part == "" and kind in CONTACT_KINDS and enemy.has_method("contact_part"):
		return enemy.contact_part(ctx.player.ball_position(), kind)
	return part


func _strike_plating(enemy: Node3D, kind: String, part: String) -> float:
	return enemy.plating_for(kind, part) if enemy.has_method("plating_for") else 0.0


func resolve(enemy: Node3D, kind: String, force: float, part := "") -> Dictionary:
	return _strike_result(enemy, kind, force, part)


func punch_now() -> float:
	if punch_override >= 0.0:
		return punch_override
	return super()


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
