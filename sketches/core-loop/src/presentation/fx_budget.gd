extends RefCounted

# One effect budget (BACKLOG.md FX-21): every effect ceiling in the game, one row each, read from
# the module that owns it, and one call that sums a world's worst case. The table records the
# ceilings; it sets none. A row's number stays where it is tuned and pinned (world_fx_test,
# fx_library_test, machine_fx_test); fx_budget_test checks the table still reads them all.
#
# Units are kept apart because they cost differently: "particles" are live GPU particles at the
# high preset, "nodes" are pooled glyph and word nodes, "draws" are transparent meshes (each a
# draw call and its overdraw). What each unit costs in frame time is a PC measurement (4080,
# idle card), not a cloud one: cloud reads overstate shader cost 2 to 3 times.

const Specs := preload("res://src/presentation/world_fx/world_fx_specs.gd")
const Kit := preload("res://src/presentation/world_fx/world_fx_kit.gd")
const WorldFx := preload("res://src/presentation/world_fx/world_fx.gd")
const FxLibrary := preload("res://src/presentation/fx_library.gd")
const Vfx := preload("res://src/presentation/vfx.gd")
const PlayerFx := preload("res://src/presentation/player_fx.gd")

# id: what the effect is, its unit, where its number lives, and which worlds carry it.
#   const    a constant on `owner` that holds the ceiling
#   read     a named reader below, when the ceiling is a sum the owner computes
#   worlds   "all"; "water" for the worlds with standing water (WorldFx.WAKE_WORLDS, the worlds whose
#            water throws a wake); or a world_fx set id (Specs.WORLD_SETS values) for one world's own pools
#   per      the ceiling is per placed thing (a thermal column), so worst_case lists it, not sums it
const ROWS := {
	"world_air": {"unit": "particles", "owner": "res://src/presentation/world_fx/world_fx_specs.gd",
		"const": "AMBIENT_CEILING", "worlds": "all", "what": "a world's ambient air plus its worst overlay"},
	"anchors": {"unit": "particles", "owner": "res://src/presentation/world_fx/world_fx_specs.gd",
		"const": "ANCHOR_CEILING", "worlds": "all", "what": "the six costliest anchored sets standing together"},
	"hits_and_kills": {"unit": "particles", "owner": "res://src/presentation/fx_library.gd",
		"const": "CEILING", "worlds": "all", "what": "the player's hit, crit, kill and ball pools (owner vfx)"},
	"machines": {"unit": "particles", "owner": "res://src/presentation/fx_library.gd",
		"const": "MACHINE_CEILING", "worlds": "all", "what": "what enemies and bosses throw off (owner machine)"},
	"dig_pools": {"unit": "particles", "owner": "res://src/presentation/fx_library.gd",
		"read": "library_owner", "worlds": "dig", "what": "dig_fx.gd's own library pools"},
	"highdraft_pools": {"unit": "particles", "owner": "res://src/presentation/fx_library.gd",
		"read": "library_owner", "worlds": "highdraft", "what": "highdraft_fx.gd's own library pools"},
	"player_layer": {"unit": "particles", "owner": "res://src/presentation/player_fx.gd",
		"read": "player_ceiling", "worlds": "all", "what": "the player's flecks, embers, carve sparks, growth columns and boons"},
	"kill_bursts": {"unit": "particles", "owner": "res://src/presentation/vfx.gd",
		"read": "vfx_bursts", "worlds": "all", "what": "kill pop, debris, dust and part fountains (Vfx.BURSTS)"},
	"sparkles": {"unit": "particles", "owner": "res://src/presentation/vfx.gd",
		"read": "sparkles", "worlds": "all", "what": "scrap sparkles: SPARKLE_POOL emitters of up to SPARKLE_MAX each"},
	"hook_bursts": {"unit": "particles", "owner": "res://src/presentation/world_fx/world_fx.gd",
		"read": "hook_bursts", "worlds": "all", "what": "world hook bursts (splash, relay, secret): BURST_POOL per effect"},
	"glyphs": {"unit": "nodes", "owner": "res://src/presentation/vfx.gd",
		"const": "POOL", "worlds": "all", "what": "event glyphs: rings, stars, bursts, squares"},
	"player_words": {"unit": "nodes", "owner": "res://src/presentation/player_fx.gd",
		"const": "WORD_POOL", "worlds": "all", "what": "the player's sound words"},
	"machine_words": {"unit": "nodes", "owner": "res://src/presentation/machine_fx.gd",
		"const": "WORD_POOL", "worlds": "all", "what": "KRNK, EJECT and the other machine words"},
	"landmark_beam": {"unit": "draws", "owner": "res://src/presentation/landmark_beam.gd",
		"read": "beam_layers", "worlds": "all", "what": "the ancient beam's core and veil cylinders"},
	"still_quads": {"unit": "draws", "owner": "res://src/presentation/world_fx/world_fx_specs.gd",
		"read": "still_quads", "worlds": "all", "what": "still quads a set carries (the dam spray's rainbow); counted in every world as an upper bound"},
	"water_mist": {"unit": "draws", "owner": "res://src/presentation/spillway_scenery.gd",
		"read": "one", "worlds": "water", "what": "the falls' mist cards, batched into one mesh per scenery build"},
	"thermal_column": {"unit": "draws", "owner": "res://src/presentation/highdraft_fx.gd",
		"read": "thermal_views", "worlds": "highdraft", "per": "thermal column", "what": "a thermal's motes and streaks multimeshes"},
}

# Counts the owners build in code, not as constants; fx_budget_test checks each against its owner:
# the beam's layers by building a beam, the sparkle cap and the thermal views by reading the source.
const BEAM_LAYERS := 2
const SPARKLE_MAX := 20
const THERMAL_VIEWS := 2


# A row's ceiling, read from its owner now.
static func ceiling(id: String) -> int:
	var row: Dictionary = ROWS[id]
	if row.has("const"):
		return int((load(row.owner) as GDScript).get_script_constant_map()[row.const])
	match String(row.read):
		"library_owner":
			return FxLibrary.ceiling(String(row.worlds))
		"player_ceiling":
			return PlayerFx.ceiling()
		"vfx_bursts":
			var n := 0
			for kind in Vfx.BURSTS:
				n += int(Vfx.BURSTS[kind].pool) * int(Vfx.BURSTS[kind].max)
			return n
		"sparkles":
			return Vfx.SPARKLE_POOL * SPARKLE_MAX
		"hook_bursts":
			var n := 0
			for hook in Specs.HOOKS:
				for fx_id in Specs.HOOKS[hook].effects:
					n += WorldFx.BURST_POOL * int(Specs.SPECS[fx_id]["max"])
			return n
		"thermal_views":
			return THERMAL_VIEWS
		"beam_layers":
			return BEAM_LAYERS
		"still_quads":
			var n := 0
			for set_id in Specs.EXTRAS:
				n += (Specs.EXTRAS[set_id] as Array).size()
			return n
		"one":
			return 1
	return 0


static func in_world(id: String, world: int) -> bool:
	var scope := String(ROWS[id].worlds)
	match scope:
		"all":
			return true
		"water":
			return world in WorldFx.WAKE_WORLDS
	return String(Specs.WORLD_SETS.get(world, "")) == scope


# A world's worst case: every ceiling it carries at once, summed per unit. A per-thing row (a thermal
# column) is not summed; per_thing(world) lists those, since how many stand is the park's data.
static func worst_case(world: int) -> Dictionary:
	var out := {"particles": 0, "nodes": 0, "draws": 0}
	for id in ROWS:
		if in_world(id, world) and not ROWS[id].has("per"):
			out[ROWS[id].unit] += ceiling(id)
	return out


static func per_thing(world: int) -> Dictionary:
	var out := {}
	for id in ROWS:
		if in_world(id, world) and ROWS[id].has("per"):
			out[id] = "%d %s per %s" % [ceiling(id), ROWS[id].unit, ROWS[id].per]
	return out
