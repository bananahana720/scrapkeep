extends RefCounted

const PhysicsLayers := preload("res://src/core/physics_layers.gd")
const Groups := preload("res://src/core/groups.gd")
const Augments := preload("res://src/movement/augments.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const Enemy := preload("res://src/combat/enemy.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const Hitscan := preload("res://src/combat/hitscan.gd")
const PlatedBrute := preload("res://src/combat/plated_brute.gd")
const SourceScan := preload("res://tests/support/source_scan.gd")


func run(t) -> void:
	t.eq("PhysicsLayers.NONE", PhysicsLayers.NONE, 0)
	t.eq("PhysicsLayers.WORLD_LAYER", PhysicsLayers.WORLD_LAYER, 1)
	t.eq("PhysicsLayers.BALL_LAYER", PhysicsLayers.BALL_LAYER, 2)
	t.eq("PhysicsLayers.ENEMY_LAYER", PhysicsLayers.ENEMY_LAYER, 3)
	t.eq("PhysicsLayers.STAKE_LAYER", PhysicsLayers.STAKE_LAYER, 8)
	t.eq("PhysicsLayers.WORLD_MASK", PhysicsLayers.WORLD_MASK, 1)
	t.eq("PhysicsLayers.BALL_MASK", PhysicsLayers.BALL_MASK, 2)
	t.eq("PhysicsLayers.ENEMY_MASK", PhysicsLayers.ENEMY_MASK, 4)
	t.eq("PhysicsLayers.STAKE_MASK", PhysicsLayers.STAKE_MASK, 128)
	t.eq("PhysicsLayers.WORLD_AND_ENEMIES_MASK", PhysicsLayers.WORLD_AND_ENEMIES_MASK, 5)

	t.eq("Augments.WORLD_MASK aliases PhysicsLayers", Augments.WORLD_MASK, PhysicsLayers.WORLD_MASK)
	t.eq("Augments.ENEMY_MASK aliases PhysicsLayers", Augments.ENEMY_MASK, PhysicsLayers.ENEMY_MASK)
	t.eq("Augments.STAKE_MASK aliases PhysicsLayers", Augments.STAKE_MASK, PhysicsLayers.STAKE_MASK)
	t.eq("Hitscan.WORLD aliases PhysicsLayers", Hitscan.WORLD, PhysicsLayers.WORLD_MASK)
	t.eq("Hitscan.WORLD_AND_ENEMIES aliases PhysicsLayers", Hitscan.WORLD_AND_ENEMIES, PhysicsLayers.WORLD_AND_ENEMIES_MASK)

	t.eq("Groups.ENEMY", Groups.ENEMY, "enemy")
	t.eq("Groups.ENEMY_SHOT", Groups.ENEMY_SHOT, "enemy_shot")
	t.eq("Groups.WORLD_TELEGRAPHS", Groups.WORLD_TELEGRAPHS, "world_telegraphs")
	t.eq("Groups.THREAT", Groups.THREAT, "threat")
	t.eq("Enemy.GROUP aliases Groups.ENEMY", Enemy.GROUP, Groups.ENEMY)
	t.eq("Threat.GROUP aliases Groups.THREAT", Threat.GROUP, Groups.THREAT)
	t.near("Tuning.GRAVITY", Tuning.GRAVITY, 26.0)
	t.near("Enemy.GRAVITY aliases Tuning.GRAVITY", Enemy.GRAVITY, Tuning.GRAVITY)
	t.near("PlatedBrute.FlungPlate.HURL_GRAVITY preserves 24.0", PlatedBrute.FlungPlate.HURL_GRAVITY, 24.0)

	var layer_dup_pattern := "(?m)^\\s*const\\s+(WORLD_LAYER|BALL_LAYER|WORLD_MASK)\\b"
	t.eq("no duplicate WORLD_LAYER/BALL_LAYER/WORLD_MASK in src/world",
		SourceScan.matching(t, ["res://src/world"], layer_dup_pattern), [])
	t.eq("no duplicate WORLD_LAYER/BALL_LAYER/WORLD_MASK in src/combat",
		SourceScan.matching(t, ["res://src/combat"], layer_dup_pattern), [])

	t.check("src/world/find_kit.gd is removed", not FileAccess.file_exists("res://src/world/find_kit.gd"))
	t.eq("no find_kit.gd references in src/world", SourceScan.matching(t, ["res://src/world"], "find_kit\\.gd"), [])

	var brute_src := SourceScan.text(t, "res://src/combat/plated_brute.gd")
	t.check("plated_brute.gd declares HURL_GRAVITY := 24.0",
		not SourceScan.search(t, brute_src, "(?m)^\\s*const\\s+HURL_GRAVITY\\s*:=\\s*24\\.0\\b").is_empty())
	t.check("plated_brute.gd no longer declares local GRAVITY",
		SourceScan.search(t, brute_src, "(?m)^\\s*const\\s+GRAVITY\\b").is_empty())

	var grav_owners := SourceScan.matching(t, ["res://src/combat"], "(?m)^\\s*const\\s+GRAVITY\\b")
	var bad_grav := grav_owners.filter(func(p: String) -> bool:
		return p != "res://src/combat/enemy.gd" and p != "res://src/combat/ultimate.gd")
	t.eq("only enemy.gd (and excluded ultimate.gd) declare const GRAVITY in src/combat", bad_grav, [])
