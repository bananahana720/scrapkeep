extends SceneTree

# Owner map point 4 (ruling ct, the ten-point map standard; map-audit section G): layouts are hand-built sub-regions
# whose pockets, sites, modifiers and live routes are drawn per run, repeatable per seed, never random terrain. Per
# world 1 park, RUNS run seeds each draw the stage's three per-run picks through the game's own code: the pockets
# (PocketDraw.stage_sites, with the stage's trade pocket and modifier passed as activities.gd passes them), the rogue
# site (RogueDirector.plan on the park's sites.json) and the stage modifier (StageModifier.pick). The (pockets, rogue
# site, modifier) sets must number at least SETS_MIN, the audit's pass line, and the same seed must draw the same set.
#
# Data only: no scene, no physics. The game seeds the pocket draw with ctx.rng.seed and the rogue with a draw from the
# stage stream (world.gd `_stage_seed`); here both come from the run seed (layout seed = the run seed, stage seed =
# hash of the run seed and the stage), a stand-in for the flow's streams. Live routes (swaps) are not read: no world 1
# map swaps a route per run today.
#
# Output: `MAPCHECK <stage> layout_sets <value> pass>=<line> PASS|FAIL`, plus `report INFO` lines naming the parts.
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
	var trade := TradePockets.stage_site(g, map, run, run_seed, pool)
	var pockets := []
	for spec in PocketDraw.stage_sites(g, map, run, run_seed, trade, prepared, modifier):
		pockets.append("%s@%d" % [spec.interior.id, int(spec.node)])
	pockets.sort()
	var rogue := RogueDirector.plan(hash([run_seed, stage, "stage_seed"]) ^ 0x706e, WORLD, sites_doc)
	var out := {"pockets": ",".join(pockets), "rogue": String(rogue.get("site", "none")), "modifier": String(modifier.get("id", "none"))}
	out["key"] = "%s|%s|%s" % [out["pockets"], out["rogue"], out["modifier"]]
	return out


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
			parts[p][d[p]] = int(parts[p].get(d[p], 0)) + 1
	var again := draw_set(g, map, map_id, stage, 1, prepared, pool, sites_doc)
	var first := draw_set(g, map, map_id, stage, 1, prepared, pool, sites_doc)
	t.check("%s: the same seed draws the same set" % map_id, again["key"] == first["key"], again["key"])
	var n := keys.size()
	print("MAPCHECK %s layout_sets %d pass>=%d %s" % [map_id, n, SETS_MIN, "PASS" if n >= SETS_MIN else "FAIL"])
	print("MAPCHECK %s variety_parts pockets=%d rogue=%d modifier=%d report INFO" % [map_id, parts["pockets"].size(), parts["rogue"].size(), parts["modifier"].size()])
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
