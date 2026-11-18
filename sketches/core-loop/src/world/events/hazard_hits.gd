extends RefCounted

const DamageDoor := preload("res://src/combat/damage_door.gd")
const SiltBoil := preload("res://src/combat/silt_boil.gd")

# World 1's hazards hit enemies as well as the ball (W44, ruling cu). A hazard that damages the ball strikes
# every enemy whose feet are inside the same committed area it tests the ball against, once per activation,
# with the knock the silt boils give (silt_boil.gd _erupt): the flash comes with take_damage, the toss shows it
# moved. A kill drops what any kill drops: take_damage ends in enemy.died, which combat files with
# record_kill as a hazard's own kind of kill: it drops and counts, but fires no on-kill item or tree effect (Gate assumption, no ruling covers it). Set pieces (the Warden, the vault, boss pieces)
# are never struck, as the silt spares them. The stage dial hazard.hits_enemies_by_stage (ChallengeDials) turns
# it on: world 1's two stages; worlds 2 and 3 are parked (ruling at). The same dial turns on the storm's seek and
# the flood's tax (natural.gd), the pressure that pays for the easier fights.
#
# Plants for the pinned test only (tests/hazards_hit_everyone_test.gd), which fills plants from its own
# environment; the game never sets it and reads no environment here. skip_enemies makes every hazard pass over
# enemies; storm_seek.gd reads no_tell and seek_rolling. The test must go red under each.
static var plants: Array[String] = []
# Set on an enemy for the length of a hazard's hit: a kill it lands is credited as a hazard's (run_state.gd
# TRIGGERLESS_SOURCES), so it drops and counts but fires no on-kill item or tree effect.
const STRUCK := "hazard_struck"


# Whether the run's stage (run.stage, 1-based; 0 or unknown is off) has hazards that hit everyone.
static func applies(stage: int) -> bool:
	return ChallengeDials.by_stage_or("hazard.hits_enemies_by_stage", stage, 0.0) > 0.0


# A world whose context has no run (a test double) is off.
static func applies_to(run) -> bool:
	var stage = run.get("stage") if run != null else null
	return stage != null and applies(int(stage))


static func planted(name: String) -> bool:
	return plants.has(name)


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
			enemy.set_meta(STRUCK, true)
			enemy.take_damage(damage)
			if is_instance_valid(enemy):
				enemy.remove_meta(STRUCK)
	return count
