extends SceneTree
# F6 2026-10-04: the rows no longer carry warden_fight; every Warden fights on posture.
# KF0 2026-10-10: one Warden kind per world, so the variants are stage 2 meltdown, stage 4
# brood and stage 6 choir (PARK.md section 7); world 1 has two packs once rebound leaves.

const Game := preload("res://src/game.gd")
const AlphaDefs := preload("res://src/core/alpha_defs.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")
const Terrain := preload("res://src/world/terrain.gd")
const Roster := preload("res://src/combat/roster.gd")
const Director := preload("res://src/world/director.gd")

# The alpha table: three worlds of two zones each on the surviving maps, every Warden on
# the posture fight, Brindle as the boss. The row keys are every key a src/ reader
# pulls from a stage row (flow, world, combat, build, hud, objectives, audio, director,
# event director, vfx, game); a reader added later has to be added here and to the rows.

const ROW_KEYS := [
	"stage", "world", "music", "warden_family", "name", "map", "threat",
	"unlock_base", "ancient", "event_mix", "scrap_density", "kill_scrap",
	"beacon_seconds", "beacon_radius", "warden_plating", "warden_hp",
	"warden_lesson", "posture", "warden_hint", "packs", "elite", "warden_variant",
]

var _failures := 0


func _check(label: String, ok: bool, detail: String = "") -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _missing(row: Dictionary) -> Array:
	var out := []
	for key in ROW_KEYS:
		if not row.has(key):
			out.append(key)
	return out


func _initialize() -> void:
	var A = AlphaDefs
	_check("count", A.COUNT == 6 and A.DEFS.size() == A.COUNT and A.BOSS == "brindle", "COUNT %d rows %d BOSS %s" % [A.COUNT, A.DEFS.size(), A.BOSS])
	var want_world := [1, 1, 2, 2, 3, 3]
	for s in range(1, A.COUNT + 1):
		_check("world_of %d" % s, A.world_of(s) == want_world[s - 1], str(A.world_of(s)))
	_check("world_of(3) == 2", A.world_of(3) == 2, str(A.world_of(3)))
	_check("world_of(5) == 3", A.world_of(5) == 3, str(A.world_of(5)))
	_check("first_of 1", A.first_of(1) == 1, str(A.first_of(1)))
	_check("last_of 1", A.last_of(1) == 2, str(A.last_of(1)))
	_check("last_of last world", A.last_of(A.worlds().back()) == A.COUNT, str(A.last_of(A.worlds().back())))
	# Three worlds of two rows each: a row moved to another world fails here even when every world id still appears.
	var spans := []
	for w in A.worlds():
		spans.append([A.first_of(w), A.last_of(w)])
	_check("worlds", A.worlds() == [1, 2, 3] and spans == [[1, 2], [3, 4], [5, 6]], "%s spans %s" % [A.worlds(), spans])
	for s in range(1, A.COUNT + 1):
		_check("is_world_last %d" % s, A.is_world_last(s) == (s in [2, 4, 6]), "stage %d: %s" % [s, A.is_world_last(s)])
		_check("is_run_last %d" % s, A.is_run_last(s) == (s == 6), "stage %d: %s" % [s, A.is_run_last(s)])
	# Naming all six maps keeps a swapped or placeholder map from shipping without this list changing.
	var maps: Array = A.DEFS.map(func(row): return row["map"])
	_check("maps", maps == ["spillway", "reach", "dig", "dig_deep", "highdraft", "highdraft_crown"], str(maps))
	for i in A.DEFS.size():
		var row: Dictionary = A.DEFS[i]
		_check("row %d keys" % (i + 1), _missing(row).is_empty(), "missing %s" % str(_missing(row)))
		_check("row %d stage number" % (i + 1), int(row.get("stage", 0)) == i + 1, str(row.get("stage", 0)))
	_check("packs", A.packs().size() == 2 and not A.elite().is_empty(), "%d packs" % A.packs().size())
	# Every row's map builds from the table without error.
	var terrain = Terrain.new(AlphaDefs)
	_check("terrain maps", terrain.maps.size() == A.COUNT, "%d maps" % terrain.maps.size())
	for i in A.DEFS.size():
		var row: Dictionary = A.DEFS[i]
		_check("row %d placeholder name" % (i + 1), not String(row["name"]).contains("placeholder"), String(row["name"]))
		_check("row %d title" % (i + 1), String(terrain.maps[i].title) == String(row["name"]), "%s vs %s" % [terrain.maps[i].title, row["name"]])
		var want := {1: "meltdown", 3: "brood", 5: "choir"}.get(i, "") as String
		_check("row %d variant" % (i + 1), String(row["warden_variant"]) == want, String(row["warden_variant"]))
	for pair in [[2, 2], [3, 2], [4, 3], [5, 3]]:
		var world_kinds := Roster.world_kinds(pair[1])
		for pack in A.DEFS[pair[0]]["packs"]:
			for kind in pack["kinds"]:
				_check("row %d kind %s" % [pair[0] + 1, kind], (world_kinds.has(kind) or kind in Roster.SPECIALS) and Director.KIND_NAMES.has(kind),
					"world %d" % pair[1])
	# --table=alpha resolves through the game's selection; no choice stays the default.
	var game = Game.new()
	game.test_mode = true
	game.table = "alpha"
	_check("TABLES has alpha", Game.TABLES.get("alpha") == AlphaDefs, "registered")
	_check("alpha resolves", game._chosen_table() == AlphaDefs, "table alpha")
	game.table = ""
	_check("default unchanged", game._chosen_table() == StageDefs, "empty table")
	game.free()
	print("alpha_table_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
