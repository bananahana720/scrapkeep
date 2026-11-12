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

# id: what the effect is, its unit, where its number lives, and which worlds carry it.
#   const    a constant on `owner` that holds the ceiling
#   read     a named reader below, when the ceiling is a sum the owner computes
#   worlds   "all"; "water" for the worlds whose water throws a wake (WorldFx.WAKE_WORLDS); or
#            a world_fx set id (Specs.WORLD_SETS values) for one world's own pools
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
	"bursts": {"unit": "nodes", "owner": "res://src/presentation/vfx.gd",
		"const": "POOL", "worlds": "all", "what": "event glyphs: rings, stars, bursts, squares"},
	"sparkles": {"unit": "nodes", "owner": "res://src/presentation/vfx.gd",
		"const": "SPARKLE_POOL", "worlds": "all", "what": "scrap sparkles"},
	"machine_words": {"unit": "nodes", "owner": "res://src/presentation/machine_fx.gd",
		"const": "WORD_POOL", "worlds": "all", "what": "KRNK, EJECT and the other machine words"},
	"landmark_beam": {"unit": "draws", "owner": "res://src/presentation/landmark_beam.gd",
		"read": "beam_layers", "worlds": "all", "what": "the ancient beam's core and veil cylinders"},
	"still_quads": {"unit": "draws", "owner": "res://src/presentation/world_fx/world_fx_specs.gd",
		"read": "still_quads", "worlds": "all", "what": "still quads a set carries (the dam spray's rainbow); counted in every world as an upper bound"},
	"water_mist": {"unit": "draws", "owner": "res://src/presentation/spillway_scenery.gd",
		"read": "one", "worlds": "water", "what": "the falls' mist cards, batched into one mesh per park"},
}

# The landmark beam builds these layers (landmark_beam.gd _build); fx_budget_test builds a beam
# and counts its meshes, so this stays true.
const BEAM_LAYERS := 2


# A row's ceiling, read from its owner now.
static func ceiling(id: String) -> int:
	var row: Dictionary = ROWS[id]
	if row.has("const"):
		return int((load(row.owner) as GDScript).get_script_constant_map()[row.const])
	match String(row.read):
		"library_owner":
			return FxLibrary.ceiling(String(row.worlds))
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


# A world's worst case: every ceiling it carries at once, summed per unit.
static func worst_case(world: int) -> Dictionary:
	var out := {"particles": 0, "nodes": 0, "draws": 0}
	for id in ROWS:
		if in_world(id, world):
			out[ROWS[id].unit] += ceiling(id)
	return out
