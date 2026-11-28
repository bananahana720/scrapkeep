extends RefCounted

const DamageDoor := preload("res://src/combat/damage_door.gd")
const Groups := preload("res://src/core/groups.gd")
const SiltBoil := preload("res://src/combat/silt_boil.gd")

static var plants: Array[String] = []


static func reset_for_tests() -> void:
	plants.clear()
const STRUCK := "hazard_struck"


static func applies(stage: int) -> bool:
	return ChallengeDials.by_stage_or("hazard.hits_enemies_by_stage", stage, 0.0) > 0.0


static func applies_to(run) -> bool:
	var stage = run.get("stage") if run != null else null
	return stage != null and applies(int(stage))


static func planted(name: String) -> bool:
	return plants.has(name)


static func strike(tree: SceneTree, inside: Callable, source: String, damage: float, toss: float, struck: Dictionary,
		away := Callable()) -> int:
	if tree == null or planted("skip_enemies"):
		return 0
	var count := 0
	for enemy in tree.get_nodes_in_group(Groups.ENEMY):
		if DamageDoor.dead(enemy) or SiltBoil.set_piece(enemy) or struck.has(enemy.get_instance_id()):
			continue
		var feet: Vector3 = enemy.global_position - Vector3.UP * float(enemy.get("half_height") if enemy.get("half_height") != null else 0.0)
		if not inside.call(feet):
			continue
		struck[enemy.get_instance_id()] = true
		count += 1
		var push: Vector3 = away.call(feet) if away.is_valid() else Vector3.ZERO
		if enemy.has_method("knock"):
			enemy.knock(push if push.length_squared() > 0.0001 else Vector3.UP, toss)
		if enemy.has_method("take_damage"):
			enemy.set("last_damage_source", source)
			enemy.set_meta(STRUCK, true)
			enemy.take_damage(damage)
			if is_instance_valid(enemy):
				enemy.remove_meta(STRUCK)
	return count
