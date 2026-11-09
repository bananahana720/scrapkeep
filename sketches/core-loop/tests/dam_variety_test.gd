extends SceneTree
# smoke: solo timeout=300s (a park game entering the dam for six run seeds, then the flume)

# Rule (ruling bu, 2026-11-09): the dam varies run to run with what was already built. It draws one
# pocket, as the flume does, and joins the same stage-modifier roll; and a camp pays a common part
# rolled from the pool, where the dam's always paid Hot Rivets and the flume's Loose Trigger.
# This plays the park table headless through the real flow and reads, per run seed on the dam: the
# drawn pocket that stands there (level ground under it, clear of Rivet's cage and the rogue sites),
# the modifier applied against the pick, and what the two world 1 camps pay over twelve runs.
# World 2 and 3 authored camps keep their named parts (ruling at). It does not judge how a pocket
# looks or plays: that is the sitting's.

const T := preload("res://tests/support/t.gd")
const Modifier := preload("res://src/world/events/stage_modifier.gd")
const PocketDraw := preload("res://src/world/pockets/pocket_draw.gd")
const Library := preload("res://src/world/pockets/pocket_library.gd")
const RogueDirector := preload("res://src/world/rogue_director.gd")
const Placement := preload("res://src/world/park/park_placement.gd")
const Map := preload("res://src/world/park/park_map.gd")
const Parts := preload("res://src/build/parts.gd")
const RUN_SEEDS := [1, 2, 3, 5, 8, 13]
const RUN_IDS := 12
# The ground the ball meets may differ from the graph's 8 m nodes by the 1 m render relief between them.
const GROUND_SLACK_M := 1.5

var t := T.new("dam_variety_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var Game = load("res://src/game.gd")
	var game = Game.new()
	game.test_mode = true
	game.table = "park"
	game.run_store_path = "user://dam-variety-test.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.run_store_path))
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	game.flow.press_start()
	game.flow.choose_class(0)
	await physics_frame
	game.world.set_physics_process(false)
	game.flow.set_physics_process(false)
	game.player.set_physics_process(false)
	game.player.set_frozen(true)
	game.camera.set_physics_process(false)
	game.presentation.process_mode = Node.PROCESS_MODE_DISABLED
	var acts = game.world.activities
	acts.set_physics_process(false)
	var map = game.ctx.terrain.map()
	t.eq("the run starts on the dam", String(map.park.map), "park_dam")
	var authored: int = Modifier.authored(map)
	var kinds := {}
	var spots := {}
	var modified := 0
	for s in RUN_SEEDS:
		game.run.run_seed = s
		game.run.pocket_draw_cache = {}
		game.flow.enter_stage(1, Vector3.ZERO, false)
		await physics_frame
		var expected := Modifier.pick(s, 1, authored)
		t.eq("seed %d: the dam applies the modifier its card shows" % s, acts.stage_modifier, expected)
		modified += int(not expected.is_empty())
		var drawn: Array = acts.sites.filter(func(site): return site.drawn)
		t.eq("seed %d: the dam builds the pockets it drew" % s, drawn.size(), game.run.pocket_draw_cache["1"].sites.size())
		t.check("seed %d: the dam draws at least one pocket and no more than its slots" % s,
			drawn.size() >= 1 and drawn.size() <= Modifier.slots(expected, 1, authored), "%d drawn" % drawn.size())
		for site in drawn:
			kinds[site.interior.id] = true
			var at := Vector2(site.global_position.x, site.global_position.z)
			spots[at] = true
			_stands_well(game, map, site, at, s)
	t.check("the dam's pocket changes from run to run", kinds.size() >= 3 and spots.size() >= 3, "%d kinds at %d spots over %d seeds" % [kinds.size(), spots.size(), RUN_SEEDS.size()])
	print("dam pockets over %d seeds: %s, %d with a modifier" % [RUN_SEEDS.size(), str(kinds.keys()), modified])
	_camp(game, acts, "dam", "hot_rivets")
	game.flow.enter_stage(2, Vector3.ZERO, false)
	await physics_frame
	_camp(game, acts, "flume", "loose_trigger")
	for later in ["park_pit", "park_sinkhole", "park_islands", "park_crown"]:
		var rows: Array = Map.new("res://src/world/park/%s.json" % later).park.activity_rows.filter(func(row): return row.activity == "enemy_camp")
		t.check("%s's authored camp keeps its named part" % later, rows.size() == 1 and String(rows[0].pay.get("named", "")) != "", str(rows))
	game.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://dam-variety-test.json"))
	quit(t.verdict())


# The built pocket's ground, by the terrain the ball rolls on, and its distance from what the door
# rules do not know about.
func _stands_well(game, map, site, at: Vector2, s: int) -> void:
	var half: float = Library.FOOTPRINTS[site.interior.footprint] * 0.5
	var low := INF
	var high := -INF
	for i in 9:
		for j in 9:
			var h: float = game.ctx.terrain.height(at.x + (i - 4) * half / 4.0, at.y + (j - 4) * half / 4.0)
			low = minf(low, h)
			high = maxf(high, h)
	t.check("seed %d: %s stands on level ground" % [s, site.interior.id], high - low <= PocketDraw.LEVEL_M + GROUND_SLACK_M, "at %s the ground rises %.1f m across its %d m" % [at, high - low, half * 2.0])
	var box := Rect2(at - Vector2.ONE * half, Vector2.ONE * half * 2.0)
	for row in map.park.get("rescue_rows", []):
		t.check("seed %d: %s stands clear of the rescue cage" % [s, site.interior.id], PocketDraw._box_distance(box, Vector2(row.at[0], row.at[1])) > Placement.RING_M)
	for rogue in RogueDirector.read_sites(String(map.park.map)).get("miniboss_sites", []):
		t.check("seed %d: %s stands outside rogue site %s" % [s, site.interior.id, rogue.id], PocketDraw._box_distance(box, Vector2(rogue.at[0], rogue.at[1])) > float(rogue.radius_m))


# The stage's authored camp: no named part, a common roll, and a different part on different runs.
func _camp(game, acts, label: String, was: String) -> void:
	var camps: Array = acts.sites.filter(func(site): return site.id == "enemy_camp" and not site.drawn)
	if not t.check("the %s has its authored camp" % label, camps.size() == 1, "%d camps" % camps.size()):
		return
	var camp = camps[0]
	t.eq("the %s camp pays the common roll" % label, acts.pay_table(camp), {"named": "", "rarities": ["common"]})
	var paid := {}
	var common := true
	var kept: String = game.run.run_id
	for id in RUN_IDS:
		game.run.run_id = "dam-variety-%d" % id
		var part: String = acts._roll(acts._luck_id(camp), acts.pay_table(camp).rarities)
		paid[part] = paid.get(part, 0) + 1
		common = common and part != "" and Parts.rarity_of(part) == "common"
	game.run.run_id = kept
	t.check("the %s camp pays a common part every run" % label, common, str(paid))
	t.check("the %s camp's part changes from run to run" % label, paid.size() >= 4, "%d parts over %d runs: %s" % [paid.size(), RUN_IDS, str(paid)])
	t.check("the %s camp no longer always pays %s" % [label, was], int(paid.get(was, 0)) < RUN_IDS, str(paid))
