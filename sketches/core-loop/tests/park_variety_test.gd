extends SceneTree

# Owner map point 4 (ruling ct, the ten-point map standard; map-audit section G): layouts are hand-built sub-regions
# whose pockets, sites, modifiers and live routes are drawn per run, repeatable per seed, never random terrain. Per
# world 1 park, RUNS run seeds each draw the stage's three per-run picks through the game's own code: the pockets
# (PocketDraw.stage_sites, with the stage's trade pocket and modifier passed as activities.gd passes them), the rogue
# site (RogueDirector.plan on the park's sites.json) and the stage modifier (StageModifier.pick). The (pockets, rogue
# site, modifier) sets must number at least SETS_MIN, the audit's pass line, and the same seed must draw the same set.
# The sets alone are almost all pocket placement, so each drawn part other than the pockets must also show at least
# PART_MIN values: rogue_sites_drawn and modifiers_drawn. A pocket is told apart by its interior and its exact graph
# node; the audit's wording gives no rule for when two nearby nodes are one place, so neighbouring nodes count apart.
#
# Data only: no scene, no physics. The layout seed is the game's session constant (game.gd SEED, set as ctx.rng.seed
# and passed by activities.gd to the trade and pocket draws, which mix in the run seed and the stage themselves). The
# rogue's stage seed is the stage stream's first draw after Flow.seed_stage_stream mixes the run seed and the stage
# into it, as world.gd draws `_stage_seed` on entry; in the game other draws may come first, so this is a stand-in.
# Live routes, in the standard's words, are not drawn per run on any map today: no world 1 map swaps a route per run,
# so nothing about them is read here.
#
# Output: `MAPCHECK <stage> <measure> <value> pass>=<line> PASS|FAIL` for layout_sets, rogue_sites_drawn and
# modifiers_drawn, plus a `report INFO` line naming the pocket count.
#
# Planted: modifier chance 0, one rogue site and one fixed pocket draw (every run the same seed) give 1 set and fail.

const T := preload("res://tests/support/t.gd")
const ParkGraph := preload("res://src/world/park/park_graph.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const PocketDraw := preload("res://src/world/pockets/pocket_draw.gd")
const TradePockets := preload("res://src/world/trade_pockets.gd")
const StageModifier := preload("res://src/world/events/stage_modifier.gd")
const RogueDirector := preload("res://src/world/rogue_director.gd")
const RunState := preload("res://src/core/run_state.gd")

const STAGES := {"park_dam": 1, "park_flume": 2}
const WORLD := 1
const RUNS := 50
const SETS_MIN := 10
const PART_MIN := 2
# game.gd SEED: ctx.rng.seed for the whole session, the layout seed of every draw.
const LAYOUT_SEED := 20260926
# The value a set carries for a part the run did not draw; it is never counted as a drawn rogue site or modifier.
const NONE := "none"

var t := T.new("park_variety_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for map_id in STAGES:
		_stage(map_id, int(STAGES[map_id]))
	quit(t.verdict())


# One run seed's set: {"pockets": "...", "rogue": "...", "modifier": "...", "key": "..."}.
static func draw_set(g, map, map_id: String, stage: int, run_seed: int, prepared: Dictionary, pool, sites_doc: Dictionary, plant := false) -> Dictionary:
	var run = RunState.new()
	run.stage = stage
	run.run_seed = run_seed
	var modifier := {} if plant else StageModifier.pick(run_seed, stage, StageModifier.authored(map))
	var trade := TradePockets.stage_site(g, map, run, LAYOUT_SEED, pool)
	var pockets := []
	for spec in PocketDraw.stage_sites(g, map, run, LAYOUT_SEED, trade, prepared, modifier):
		pockets.append("%s@%d" % [spec.interior.id, int(spec.node)])
	pockets.sort()
	var rogue := RogueDirector.plan(stage_seed(run_seed, stage) ^ 0x706e, WORLD, sites_doc)
	var out := {"pockets": ",".join(pockets), "rogue": String(rogue.get("site", NONE)), "modifier": String(modifier.get("id", NONE))}
	out["key"] = "%s|%s|%s" % [out["pockets"], out["rogue"], out["modifier"]]
	return out


# Flow.seed_stage_stream's mix of the session seed, the run seed and the stage, then world.gd's draw of _stage_seed.
static func stage_seed(run_seed: int, stage: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = LAYOUT_SEED
	var mixed := RandomNumberGenerator.new()
	mixed.seed = hash([LAYOUT_SEED, run_seed, stage, "stage"])
	rng.state = mixed.state
	return rng.randi()


func _stage(map_id: String, stage: int) -> void:
	var map := ParkMap.new("res://src/world/park/%s.json" % map_id)
	var g = ParkGraph.read("res://assets/park/%s/graph.bin" % map_id)
	var sites_doc := RogueDirector.read_sites(map_id)
	if not t.check("%s inputs load" % map_id, map.ok and g != null and not sites_doc.is_empty(), "map, graph, sites.json"):
		return
	var prepared: Dictionary = PocketDraw.prepare(g, map)
	var pool := TradePockets.candidates(g, map)
	var keys := {}
	var parts := {"pockets": {}, "rogue": {}, "modifier": {}}
	for s in RUNS:
		var d := draw_set(g, map, map_id, stage, s + 1, prepared, pool, sites_doc)
		keys[d["key"]] = true
		for p in parts:
			# A run that draws no rogue site or no modifier adds a set, not a drawn value.
			if d[p] != NONE:
				parts[p][d[p]] = int(parts[p].get(d[p], 0)) + 1
	var again := draw_set(g, map, map_id, stage, 1, prepared, pool, sites_doc)
	var first := draw_set(g, map, map_id, stage, 1, prepared, pool, sites_doc)
	t.check("%s: the same seed draws the same set" % map_id, again["key"] == first["key"], again["key"])
	var n := keys.size()
	print("MAPCHECK %s layout_sets %d pass>=%d %s" % [map_id, n, SETS_MIN, "PASS" if n >= SETS_MIN else "FAIL"])
	for part in [["rogue", "rogue_sites_drawn"], ["modifier", "modifiers_drawn"]]:
		var k: int = parts[part[0]].size()
		print("MAPCHECK %s %s %d pass>=%d %s" % [map_id, part[1], k, PART_MIN, "PASS" if k >= PART_MIN else "FAIL"])
		t.check("%s: %s >= %d" % [map_id, part[1], PART_MIN], k >= PART_MIN, "%d" % k)
	print("MAPCHECK %s variety_parts pockets=%d (exact interior and node) report INFO" % [map_id, parts["pockets"].size()])
	t.check("%s: %d run seeds draw >= %d distinct (pockets, rogue site, modifier) sets" % [map_id, RUNS, SETS_MIN], n >= SETS_MIN, "%d sets" % n)
	if stage == 1:
		_planted(g, map, map_id, stage, prepared, pool, sites_doc)


func _planted(g, map, map_id: String, stage: int, prepared: Dictionary, pool, sites_doc: Dictionary) -> void:
	var one := sites_doc.duplicate(true)
	one["miniboss_sites"] = [sites_doc["miniboss_sites"][0]]
	var keys := {}
	for s in RUNS:
		# Every run draws its pockets from one seed: the draw ignores the run, as a one-entry library would.
		var d := draw_set(g, map, map_id, stage, 1, prepared, pool, one, true)
		keys[d["key"]] = true
	var n := keys.size()
	print("PLANTED one_site_no_modifier_fixed_pockets layout_sets %d pass>=%d %s" % [n, SETS_MIN, "PASS" if n >= SETS_MIN else "FAIL"])
	t.check("planted: no modifier, one rogue site and a fixed pocket draw give one set and fail", n == 1 and n < SETS_MIN, "%d sets" % n)
