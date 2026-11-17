extends RefCounted

const DamageDoor := preload("res://src/combat/damage_door.gd")
const SiltBoil := preload("res://src/combat/silt_boil.gd")

# World 1's hazards hit enemies as well as the ball (W44, ruling cu). A hazard that damages the ball strikes
# every enemy whose feet are inside the same committed area it tests the ball against, once per activation,
# with the knock the silt boils give (silt_boil.gd _erupt): the flash comes with take_damage, the toss shows it
# moved. A kill drops what any kill drops: take_damage ends in enemy.died, which combat files with
# record_kill (assumption: no ruling sets hazard kills apart). Set pieces (the Warden, the vault, boss pieces)
# are never struck, as the silt spares them. Only the Spillway's parks: worlds 2 and 3 are parked (ruling at).
#
# One plant for the pinned test (tests/hazards_hit_everyone_test.gd): SCRAPKEEP_PLANT_HAZARD=skip_enemies
# makes every hazard pass over enemies, so that test must go red.

const PARKS := ["park_dam", "park_flume"]
const PLANT_ENV := "SCRAPKEEP_PLANT_HAZARD"


static func applies(park: Dictionary) -> bool:
	return PARKS.has(String(park.get("map", "")))


static func planted(name: String) -> bool:
	return OS.get_environment(PLANT_ENV).split(",").has(name)


# Strikes each live enemy whose feet inside() accepts and whose instance id is not in struck (then added), with
# damage tagged source and a knock of toss along away(feet) (Vector3.UP when it returns zero). Returns how many.
static func strike(tree: SceneTree, inside: Callable, source: String, damage: float, toss: float, struck: Dictionary,
		away := Callable()) -> int:
	if tree == null or planted("skip_enemies"):
		return 0
	var count := 0
	for enemy in tree.get_nodes_in_group("enemy"):
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
			enemy.take_damage(damage)
	return count
