extends RefCounted

const Specs := preload("res://src/presentation/world_fx/world_fx_specs.gd")
const Kit := preload("res://src/presentation/world_fx/world_fx_kit.gd")
const WorldFx := preload("res://src/presentation/world_fx/world_fx.gd")
const FxLibrary := preload("res://src/presentation/fx_library.gd")
const Vfx := preload("res://src/presentation/vfx.gd")
const PlayerFx := preload("res://src/presentation/player_fx.gd")

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
		"const": "SPARKLE_CEILING", "worlds": "all", "what": "scrap sparkles: SPARKLE_POOL emitters of up to SPARKLE_MAX each"},
	"hook_bursts": {"unit": "particles", "owner": "res://src/presentation/world_fx/world_fx.gd",
		"read": "hook_bursts", "worlds": "all", "what": "world hook bursts (splash, relay, secret): BURST_POOL per effect"},
	"glyphs": {"unit": "nodes", "owner": "res://src/presentation/vfx.gd",
		"const": "POOL", "worlds": "all", "what": "event glyphs: rings, stars, bursts, squares"},
	"player_words": {"unit": "nodes", "owner": "res://src/presentation/player_fx.gd",
		"const": "WORD_POOL", "worlds": "all", "what": "the player's sound words"},
	"machine_words": {"unit": "nodes", "owner": "res://src/presentation/machine_fx.gd",
		"const": "WORD_POOL", "worlds": "all", "what": "KRNK, EJECT and the other machine words"},
	"landmark_beam": {"unit": "draws", "owner": "res://src/presentation/landmark_beam.gd",
		"const": "BEAM_LAYERS", "worlds": "all", "what": "the ancient beam's core and veil cylinders"},
	"still_quads": {"unit": "draws", "owner": "res://src/presentation/world_fx/world_fx_specs.gd",
		"read": "still_quads", "worlds": "all", "what": "still quads a set carries (the dam spray's rainbow); counted in every world as an upper bound"},
	"water_mist": {"unit": "draws", "owner": "res://src/presentation/spillway_scenery.gd",
		"read": "one", "worlds": "water", "what": "the falls' mist cards, batched into one mesh per scenery build"},
	"sable_charge": {"unit": "particles", "owner": "res://src/presentation/charge_halo.gd",
		"const": "SPARKS", "more": {"draws": "DRAWS"}, "worlds": "all",
		"what": "Sable's charge sparks; the halo and its release rings are DRAWS (owner player_fx)"},
	"rivet_fire": {"unit": "draws", "owner": "res://src/presentation/player_fx.gd",
		"const": "RIVET_DRAWS", "more": {"nodes": "CASINGS"}, "worlds": "all",
		"what": "Rivet's muzzle flashes and spent casings, one MultiMesh each; CASINGS alive at most"},
	"thermal_column": {"unit": "draws", "owner": "res://src/presentation/highdraft_fx.gd",
		"read": "thermal_views", "worlds": "highdraft", "per": "thermal column", "what": "a thermal's motes and streaks multimeshes"},
}

const THERMAL_VIEWS := 2


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
			return Vfx.burst_ceiling()
		"hook_bursts":
			var n := 0
			for hook in Specs.HOOKS:
				for fx_id in Specs.HOOKS[hook].effects:
					n += WorldFx.BURST_POOL * int(Specs.SPECS[fx_id]["max"])
			return n
		"thermal_views":
			return THERMAL_VIEWS
		"still_quads":
			var n := 0
			for set_id in Specs.EXTRAS:
				n += (Specs.EXTRAS[set_id] as Array).size()
			return n
		"one":
			return 1
	return 0


static func ceilings(id: String) -> Dictionary:
	var row: Dictionary = ROWS[id]
	var out := {String(row.unit): ceiling(id)}
	var map: Dictionary = (load(row.owner) as GDScript).get_script_constant_map() if row.has("more") else {}
	for unit in row.get("more", {}):
		out[unit] = int(out.get(unit, 0)) + int(map[row.more[unit]])
	return out


static func in_world(id: String, world: int) -> bool:
	var scope := String(ROWS[id].worlds)
	match scope:
		"all":
			return true
		"water":
			return world in WorldFx.WAKE_WORLDS
	return String(Specs.WORLD_SETS.get(world, "")) == scope


static func worst_case(world: int) -> Dictionary:
	var out := {"particles": 0, "nodes": 0, "draws": 0}
	for id in ROWS:
		if in_world(id, world) and not ROWS[id].has("per"):
			var cost := ceilings(id)
			for unit in cost:
				out[unit] += int(cost[unit])
	return out


static func per_thing(world: int) -> Dictionary:
	var out := {}
	for id in ROWS:
		if in_world(id, world) and ROWS[id].has("per"):
			out[id] = "%d %s per %s" % [ceiling(id), ROWS[id].unit, ROWS[id].per]
	return out
