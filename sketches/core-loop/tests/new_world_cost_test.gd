extends SceneTree

# How many places in the game's code name a world, a stage's map or a world boss outright,
# outside the stage and world tables that own those facts. Each one is a place a new world
# or stage has to be written into by hand (BACKLOG.md "World 1 and scaling backlog", SG-01).
#
# PINS is a ratchet, one count per file. The test fails when a file gains a site (move the
# fact into a world or stage row instead, or raise the pin and say why in the commit), and
# when a file loses one (lower the pin, so the number stays true). The total it prints is
# the yardstick the scaling rows SG-02 to SG-08 bring down.
#
# What counts as a site, on code (comments are skipped):
#   world_cmp       a world number compared with a world literal: world == 1, world_id <= 2
#                   (a "has a world" guard such as world > 0 or world >= 1 is not a site)
#   world_list      a loop over the world numbers written out: in [1, 2, 3]
#   world_match     a match on a world number
#   world_map       a world number keyed to a map or theme: {1: "spillway", 2: "dig"}
#   boss_cmp        a world boss id compared with a literal: == "mind"
#   map_id          a park map id, or the legacy "spillway" and "gorge", written as a string
#   legacy_map_cmp  a legacy map id compared, or listed to compare: == "dig", in ["dig", "dig_deep"]
#                   (these ids are also quest and key names, so only a comparison counts)

const T := preload("res://tests/support/t.gd")

const ROOT := "res://src"
# The tables whose job is to hold these facts.
const HOMES := ["res://src/core/worlds.gd", "res://src/core/alpha_defs.gd", "res://src/core/park_defs.gd",
	"res://src/core/slice_defs.gd", "res://src/core/stage_defs.gd"]
const PATTERNS := {
	"world_cmp": "\\b_?world(_id|_index|_n)?\\s*((==|!=|<=|>)\\s*[1-9]|(>=|<)\\s*[2-9])\\b",
	"world_list": "in\\s*\\[\\s*1\\s*,\\s*2\\s*,\\s*3\\s*\\]",
	"world_match": "\\bmatch\\s+\\w*world\\w*\\s*:",
	"world_map": "\\b[1-9]\\s*:\\s*\"(spillway|reach|dig|highdraft)\"",
	"boss_cmp": "(==|!=)\\s*\"(mind|brindle|waking)\"|\"(mind|brindle|waking)\"\\s*(==|!=)",
	"map_id": "\"(park_dam|park_flume|park_pit|park_sinkhole|park_islands|park_crown|spillway|gorge)\"",
	"legacy_map_cmp": "(==|!=)\\s*\"(reach|dig|dig_deep|highdraft|highdraft_crown)\"|\"(reach|dig|dig_deep|highdraft|highdraft_crown)\"\\s*(==|!=|in\\b)|\\[\\s*\"(reach|dig|dig_deep|highdraft|highdraft_crown)\"\\s*,",
}
# Counted on stage/alpha-w39 de79a4e6, 12 Nov 2026: 109 sites in 32 files. SG-04 took park_schema.gd out (103 in 31).
const PINS := {
	"res://src/build/parts.gd": 1,
	"res://src/combat/kest_kit.gd": 1,
	"res://src/core/ambient_kinds.gd": 22,
	"res://src/core/flow.gd": 2,
	"res://src/core/secrets.gd": 8,
	"res://src/game.gd": 1,
	"res://src/presentation/dig_scenery.gd": 3,
	"res://src/presentation/harmony.gd": 1,
	"res://src/presentation/hero_assets.gd": 3,
	"res://src/presentation/machine_fx.gd": 3,
	"res://src/presentation/music_engine.gd": 1,
	"res://src/presentation/music_rows.gd": 2,
	"res://src/presentation/park_props.gd": 6,
	"res://src/presentation/phase_music.gd": 2,
	"res://src/presentation/title_intro_player.gd": 4,
	"res://src/presentation/title_intros.gd": 1,
	"res://src/presentation/world_fx/world_fx_specs.gd": 15,
	"res://src/presentation/world_look.gd": 1,
	"res://src/ui/comic_page.gd": 1,
	"res://src/ui/ending_sequence.gd": 9,
	"res://src/ui/screens.gd": 1,
	"res://src/world/breather_rows.gd": 2,
	"res://src/world/director.gd": 1,
	"res://src/world/events/natural.gd": 2,
	"res://src/world/interactables.gd": 1,
	"res://src/world/lock_rows.gd": 2,
	"res://src/world/park/park_terrain.gd": 1,
	"res://src/world/pockets/pocket_draw.gd": 2,
	"res://src/world/pylon_bite.gd": 1,
	"res://src/world/scatter.gd": 1,
	"res://src/world/terrain.gd": 2,
}

var _t := T.new("new_world_cost_test")
var _res := {}


func _initialize() -> void:
	for kind in PATTERNS:
		var re := RegEx.new()
		re.compile(PATTERNS[kind])
		_res[kind] = re
	var counts := {}
	var kinds := {}
	for path in _scripts(ROOT):
		if path in HOMES:
			continue
		var found := _count(path)
		var n := 0
		for kind in found:
			n += int(found[kind])
			kinds[kind] = int(kinds.get(kind, 0)) + int(found[kind])
		if n > 0:
			counts[path] = n
	var total := 0
	for path in counts:
		total += int(counts[path])
	var pinned := 0
	for path in PINS:
		pinned += int(PINS[path])
	print("world sites: %d in %d files %s (pinned %d)" % [total, counts.size(), kinds, pinned])
	var grew: Array = []
	var shrank: Array = []
	for path in counts:
		var want := int(PINS.get(path, 0))
		if int(counts[path]) > want:
			grew.append("%s %d > %d" % [path, counts[path], want])
		elif int(counts[path]) < want:
			shrank.append("%s %d < %d" % [path, counts[path], want])
	for path in PINS:
		if not counts.has(path):
			shrank.append("%s 0 < %d" % [path, PINS[path]])
	_t.check("no new world site", grew.is_empty(),
		"a file names a world, map or boss outright more often than its pin: %s" % [grew])
	_t.check("every pin is current", shrank.is_empty(),
		"a file lost a site, so lower its pin: %s" % [shrank])
	_t.check("the scan finds the known sites", total > 0 and _res.size() == PATTERNS.size(), "%d sites" % total)
	quit(_t.verdict())


func _scripts(dir_path: String) -> Array:
	var out: Array = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for sub in dir.get_directories():
		out.append_array(_scripts(dir_path.path_join(sub)))
	for file in dir.get_files():
		if file.ends_with(".gd"):
			out.append(dir_path.path_join(file))
	out.sort()
	return out


func _count(path: String) -> Dictionary:
	var found := {}
	var text := FileAccess.get_file_as_string(path)
	for line in text.split("\n"):
		var code := line
		if code.strip_edges().begins_with("#"):
			continue
		var hash_at := code.find("#")
		if hash_at >= 0:
			code = code.substr(0, hash_at)
		for kind in _res:
			var n: int = (_res[kind] as RegEx).search_all(code).size()
			if n > 0:
				found[kind] = int(found.get(kind, 0)) + n
	return found
