extends RefCounted

const PhysicsLayers := preload("res://src/core/physics_layers.gd")
const Groups := preload("res://src/core/groups.gd")
const Augments := preload("res://src/movement/augments.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const Enemy := preload("res://src/combat/enemy.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const Hitscan := preload("res://src/combat/hitscan.gd")
const PlatedBrute := preload("res://src/combat/plated_brute.gd")


func _gd_files(root: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(root)
	if dir == null:
		return out
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.begins_with("."):
			name = dir.get_next()
			continue
		var full := root.path_join(name)
		if dir.current_is_dir():
			out.append_array(_gd_files(full))
		elif name.ends_with(".gd"):
			out.append(full)
		name = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out


func _matching_files(root: String, pattern: String) -> Array[String]:
	var re := RegEx.new()
	re.compile(pattern)
	var out: Array[String] = []
	for path in _gd_files(root):
		if re.search(FileAccess.get_file_as_string(path)) != null:
			out.append(path)
	return out


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
		_matching_files("res://src/world", layer_dup_pattern), [])
	t.eq("no duplicate WORLD_LAYER/BALL_LAYER/WORLD_MASK in src/combat",
		_matching_files("res://src/combat", layer_dup_pattern), [])

	t.check("src/world/find_kit.gd is removed", not FileAccess.file_exists("res://src/world/find_kit.gd"))
	t.eq("no find_kit.gd references in src/world", _matching_files("res://src/world", "find_kit\\.gd"), [])

	var brute_src := FileAccess.get_file_as_string("res://src/combat/plated_brute.gd")
	var hurl_re := RegEx.new()
	hurl_re.compile("(?m)^\\s*const\\s+HURL_GRAVITY\\s*:=\\s*24\\.0\\b")
	var raw_grav_re := RegEx.new()
	raw_grav_re.compile("(?m)^\\s*const\\s+GRAVITY\\b")
	t.check("plated_brute.gd declares HURL_GRAVITY := 24.0", hurl_re.search(brute_src) != null)
	t.check("plated_brute.gd no longer declares local GRAVITY", raw_grav_re.search(brute_src) == null)

	var grav_owners := _matching_files("res://src/combat", "(?m)^\\s*const\\s+GRAVITY\\b")
	var bad_grav := grav_owners.filter(func(p: String) -> bool:
		return p != "res://src/combat/enemy.gd" and p != "res://src/combat/ultimate.gd")
	t.eq("only enemy.gd (and excluded ultimate.gd) declare const GRAVITY in src/combat", bad_grav, [])
