extends SceneTree

const Game := preload("res://src/game.gd")
const AlphaDefs := preload("res://src/core/alpha_defs.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")
const Terrain := preload("res://src/world/terrain.gd")

# The alpha table: world one as the Spillway then the Cable Reach, both Wardens on the
# posture fight, Brindle as the world boss. The row keys are every key a src/ reader
# pulls from a stage row (flow, world, combat, build, hud, objectives, audio, director,
# event director, vfx, game); a reader added later has to be added here and to the rows.

const ROW_KEYS := [
	"stage", "world", "music", "warden_family", "name", "map", "threat",
	"unlock_base", "ancient", "event_mix", "scrap_density", "kill_scrap",
	"beacon_seconds", "beacon_radius", "warden_plating", "warden_hp",
	"warden_lesson", "warden_fight", "posture", "warden_hint",
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
	_check("count", A.COUNT == 2 and A.DEFS.size() == 2 and A.BOSS == "brindle", "COUNT %d BOSS %s" % [A.COUNT, A.BOSS])
	for s in [1, 2]:
		_check("world_of %d" % s, A.world_of(s) == 1, str(A.world_of(s)))
	_check("first_of 1", A.first_of(1) == 1, str(A.first_of(1)))
	_check("last_of 1", A.last_of(1) == 2, str(A.last_of(1)))
	_check("worlds", A.worlds() == [1], str(A.worlds()))
	_check("is_world_last 1", not A.is_world_last(1), "stage 1")
	_check("is_world_last 2", A.is_world_last(2), "stage 2")
	_check("is_run_last 1", not A.is_run_last(1), "stage 1")
	_check("is_run_last 2", A.is_run_last(2), "stage 2")
	_check("maps", A.of(1)["map"] == "spillway" and A.of(2)["map"] == "reach", "%s %s" % [A.of(1)["map"], A.of(2)["map"]])
	for i in A.DEFS.size():
		var row: Dictionary = A.DEFS[i]
		_check("row %d keys" % (i + 1), _missing(row).is_empty(), "missing %s" % str(_missing(row)))
		_check("row %d warden_fight" % (i + 1), row.get("warden_fight", "") == "posture", str(row.get("warden_fight", "")))
		_check("row %d stage number" % (i + 1), int(row.get("stage", 0)) == i + 1, str(row.get("stage", 0)))
	_check("packs", A.packs().size() == 3 and not A.elite().is_empty(), "%d packs" % A.packs().size())
	# Both maps build from the table without error.
	var terrain = Terrain.new(AlphaDefs)
	_check("terrain maps", terrain.maps.size() == 2, "%d maps" % terrain.maps.size())
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
