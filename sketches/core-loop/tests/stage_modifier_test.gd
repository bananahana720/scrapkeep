extends SceneTree
# smoke: solo timeout=420s (six park graphs prepared, then a park game entering stages 2 to 6)

# Rule (SI3, W13-INTEGRATION-3.md SI3): at most one stage modifier per stage, picked from the run seed
# and stage alone, shown on the stage card before the stage starts and equal to the one the pocket
# draw applies. A count row keeps the drawn count within the cap, Far Haul keeps every drawn pocket on
# the farthest few anchors, a sight row only scales the beacon, no row touches handling over 600
# stepped ticks, and a draw with no modifier is byte-identical to the draw before SI3.

const T := preload("res://tests/support/t.gd")
const Modifier := preload("res://src/world/events/stage_modifier.gd")
const PocketDraw := preload("res://src/world/pockets/pocket_draw.gd")
const Graph := preload("res://src/world/park/park_graph.gd")
const Map := preload("res://src/world/park/park_map.gd")
const Park := preload("res://src/core/park_defs.gd")
const Trade := preload("res://src/world/trade_pockets.gd")
const ActivityView := preload("res://src/world/activity_view.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const Rules := preload("res://src/movement/ball_rules.gd")
const BallState := preload("res://src/movement/ball_state.gd")

const PICK_SEEDS := 2000
const DRAW_SEEDS := 16
const RUN_SEEDS := [3, 11, 29]
const H := 0.05
const TICKS := 600

var t := T.new("stage_modifier_test")


class Intent extends RefCounted:
	var brake_held := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if "--runtime-only" in OS.get_cmdline_user_args():
		await _runtime()
		quit(t.verdict())
		return
	_rows()
	_picks()
	for stage in range(2, Park.COUNT + 1):
		_draws(stage)
	_handling()
	await _runtime()
	quit(t.verdict())


func _rows() -> void:
	var ids := {}
	for row in Modifier.ROWS:
		ids[row.id] = true
		t.check("%s carries only allowed effect keys" % row.id, Modifier.valid(row))
		t.check("%s caption fits the card (at most 8 words in its line)" % row.id, String(row.line).split(" ", false).size() <= 8)
	t.eq("row ids are unique", ids.size(), Modifier.ROWS.size())
	var planted := {"id": "slick", "word": "Slick", "line": "x", "friction": 0.1}
	t.check("planted handling key is rejected", not Modifier.valid(planted))


# 2,000 run seeds per stage, three authored sites as every park map has.
func _picks() -> void:
	var seen := {}
	var hits := 0
	var rolls := 0
	var deterministic := true
	var in_cap := true
	var stage_one_clear := true
	for stage in range(1, Park.COUNT + 1):
		for s in PICK_SEEDS:
			var row := Modifier.pick(s, stage, 3)
			deterministic = deterministic and row == Modifier.pick(s, stage, 3)
			if stage == 1:
				stage_one_clear = stage_one_clear and row.is_empty()
				continue
			rolls += 1
			if row.is_empty():
				continue
			hits += 1
			seen[row.id] = true
			var n := Modifier.slots(row, stage, 3)
			in_cap = in_cap and n >= 1 and n + 3 <= Modifier.CAP and n <= Modifier.max_slots(stage, 3)
			if row.has("count_scale"):
				in_cap = in_cap and n != Modifier.base_slots(stage, 3)
	t.check("stage 1 never has a modifier", stage_one_clear)
	t.check("same seed and stage pick the same row", deterministic)
	t.check("drawn count stays inside the cap of 8 with every row", in_cap)
	var rate := float(hits) / rolls
	t.check("modifier rate near %.2f on stages 2 to 6" % Modifier.CHANCE, absf(rate - Modifier.CHANCE) <= 0.04, "rate %.3f over %d" % [rate, rolls])
	t.eq("every row is picked somewhere", seen.size(), Modifier.ROWS.size())


func _row(id: String) -> Dictionary:
	for row in Modifier.ROWS:
		if row.id == id:
			return row
	return {}


func _draw(prepared: Dictionary, map, stage: int, s: int, trade: Dictionary, modifier := {}) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([78000, s, stage, "pocket_draw"])
	return PocketDraw.draw(prepared, map, stage, rng, trade, [], modifier)


func _draws(stage: int) -> void:
	var map = Map.new("res://src/world/park/%s.json" % Park.of(stage).map)
	var graph = Graph.read("res://assets/park/%s/graph.bin" % map.park.map)
	if not t.check(map.park.map + " graph loads", graph != null):
		return
	var prepared: Dictionary = PocketDraw.prepare(graph, map)
	var trade_pool := Trade.candidates(graph, map)
	var authored: int = map.activity_sites.size()
	var Run = load("res://src/core/run_state.gd")
	var identical := true
	var sight_same := true
	var counts := {"base": 0, "surplus": 0, "lean": 0}
	var cap_ok := true
	var far_ok := true
	var far_sum := 0.0
	var far_n := 0
	var base_sum := 0.0
	var base_n := 0
	var docs_ok := true
	var far_set := {}
	for spot in Modifier.far_anchors(prepared):
		far_set[spot.node] = true
	for s in DRAW_SEEDS:
		var run = Run.new()
		run.stage = stage
		run.run_seed = s
		var trade := Trade.stage_site(graph, map, run, 78000, trade_pool)
		var before := _draw(prepared, map, stage, s, trade)
		var off := _draw(prepared, map, stage, s, trade, {})
		identical = identical and var_to_bytes(before) == var_to_bytes(off)
		for id in ["floodlit", "blackout"]:
			sight_same = sight_same and var_to_bytes(_draw(prepared, map, stage, s, trade, _row(id))) == var_to_bytes(before)
		counts.base += before.sites.size()
		for spec in before.sites:
			base_sum += prepared.from_line[spec.node]
			base_n += 1
		for id in ["surplus", "lean"]:
			var row := _row(id)
			var drawn := _draw(prepared, map, stage, s, trade, row)
			counts[id] += drawn.sites.size()
			cap_ok = cap_ok and drawn.sites.size() <= Modifier.slots(row, stage, authored) and drawn.sites.size() + authored <= Modifier.CAP
			var cached = Run.new()
			cached.stage = stage
			cached.run_seed = s
			PocketDraw.stage_sites(graph, map, cached, 78000, trade, prepared, row)
			var doc: Dictionary = JSON.parse_string(JSON.stringify(PocketDraw.to_doc(cached.pocket_draw_cache)))
			docs_ok = docs_ok and PocketDraw.validate_doc(doc, stage) == ""
		var far := _draw(prepared, map, stage, s, trade, _row("far_haul"))
		for spec in far.sites:
			far_ok = far_ok and far_set.has(spec.node)
			far_sum += prepared.from_line[spec.node]
			far_n += 1
	var label := "stage %d %s" % [stage, map.park.map]
	t.check(label + ": no modifier draws byte-identically to the draw before SI3", identical)
	t.check(label + ": sight rows leave the draw byte-identical", sight_same)
	t.check(label + ": count rows stay within their slots and the cap", cap_ok)
	t.check(label + ": saved draws with count rows validate", docs_ok)
	if Modifier.slots(_row("surplus"), stage, authored) > Modifier.base_slots(stage, authored):
		t.check(label + ": Surplus Yard draws more pockets", counts.surplus > counts.base, "%d against %d over %d seeds" % [counts.surplus, counts.base, DRAW_SEEDS])
	if Modifier.slots(_row("lean"), stage, authored) < Modifier.base_slots(stage, authored):
		t.check(label + ": Lean Haul draws fewer pockets", counts.lean < counts.base, "%d against %d" % [counts.lean, counts.base])
	t.check(label + ": Far Haul pockets sit only on the farthest anchors", far_ok and far_n > 0, "%d pockets, %d far anchors of %d" % [far_n, far_set.size(), prepared.anchors.size()])
	if base_n > 0 and far_n > 0:
		t.check(label + ": Far Haul pockets sit farther off the line", far_sum / far_n > base_sum / base_n, "mean %.0f m against %.0f m" % [far_sum / far_n, base_sum / base_n])
	print("%s: pockets over %d seeds base %d, surplus %d, lean %d, far %d" % [label, DRAW_SEEDS, counts.base, counts.surplus, counts.lean, far_n])


func _snapshot(tuning) -> Dictionary:
	var out := {}
	for spec in Tuning.SPECS:
		out[spec.key] = tuning.f(spec.key)
	return out


# The ball stepped 600 ticks beside each row's application (a beacon view scaled and the dam's draw
# re-run with the row) matches the run with no row, and the movement tuning is unchanged.
func _handling() -> void:
	var map = Map.new("res://src/world/park/%s.json" % Park.of(2).map)
	var graph = Graph.read("res://assets/park/%s/graph.bin" % map.park.map)
	var prepared: Dictionary = PocketDraw.prepare(graph, map) if graph != null else {}
	var off := _step({}, map, prepared)
	for row in Modifier.ROWS:
		var on := _step(row, map, prepared)
		t.check("%s changes no handling over %d ticks" % [row.id, TICKS], on.trace == off.trace and on.tuning_same,
			"off %s on %s" % [str(off.trace.back()), str(on.trace.back())])


func _step(row: Dictionary, map, prepared: Dictionary) -> Dictionary:
	var tuning = Tuning.new()
	var before := _snapshot(tuning)
	var ball := BallState.new()
	ball.velocity = Vector3(12.0, 0.0, 4.0)
	ball.grounded = true
	var intent := Intent.new()
	var view := ActivityView.new()
	view.build("cracked_cache", 10.0)
	var pos := Vector3.ZERO
	var trace := []
	for i in TICKS:
		if i == 1 and not row.is_empty():
			view.set_sight(float(row.get("sight_scale", 1.0)))
			if not prepared.is_empty():
				_draw(prepared, map, 2, 0, {}, row)
		ball.velocity += Rules.resistance(ball, tuning, intent, H)
		pos += ball.velocity * H
		trace.append([ball.velocity, pos])
	view.free()
	return {"trace": trace, "tuning_same": _snapshot(tuning) == before}


# A park game enters stages 2 to 6 for three run seeds. On every entry the activities' applied row
# equals the pick, the stage card shows its caption (no line when there is none), and the card
# shown at launch for the next stage in the world carries the same caption. A retry keeps the row.
func _runtime() -> void:
	var Game = load("res://src/game.gd")
	var game = Game.new()
	game.test_mode = true
	game.table = "park"
	game.run_store_path = "user://stage-modifier-test.json"
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
	var hud = game.hud
	var entries := 0
	var shown_ok := 0
	var applied := 0
	var launch_ok := true
	var drawn_ok := true
	for s in RUN_SEEDS:
		game.run.run_seed = s
		game.run.pocket_draw_cache = {}
		for stage in range(2, Park.COUNT + 1):
			var expected := Modifier.pick(s, stage, 3)
			hud.launch_card.visible = false
			hud._world_card_at = -1
			game.flow.enter_stage(stage, Vector3.ZERO, false)
			await physics_frame
			# A new world shows its world card first and the stage card a beat later.
			if hud.launch_card.title != game.ctx.stages.of(stage)["name"]:
				await create_timer(hud.WORLD_CARD_BEAT + 0.3).timeout
			entries += 1
			var card_line: String = hud.launch_card.line if hud.launch_card.showing() else "<no card>"
			var ok: bool = acts.stage_modifier == expected and card_line == Modifier.caption(acts.stage_modifier)
			shown_ok += int(ok)
			if not ok:
				print("seed %d stage %d: applied %s, expected %s, card %s / %s" % [s, stage, str(acts.stage_modifier.get("id", "")), str(expected.get("id", "")), hud.launch_card.title, card_line])
			if not expected.is_empty():
				applied += 1
				if expected.has("sight_scale"):
					for site in acts.sites.filter(func(x): return x.drawn):
						drawn_ok = drawn_ok and is_equal_approx(site.view.word_reach, ActivityView.WORD_REACH * float(expected.sight_scale))
			var next := stage + 1
			if next <= game.ctx.stages.last_of(game.ctx.stages.world_of(stage)):
				hud.launch_card.visible = false
				hud._on_launched(Vector3.ZERO)
				launch_ok = launch_ok and hud.launch_card.line == Modifier.caption(Modifier.pick(s, next, 3))
	t.eq("every stage entry shows the applied modifier on its card", shown_ok, entries)
	t.check("the runtime saw modifiers applied", applied > 0, "%d of %d entries" % [applied, entries])
	t.check("the launch card for the next stage carries its modifier", launch_ok)
	t.check("sight rows scale the drawn beacons", drawn_ok)
	# Seed 29 stage 5 draws Floodlit (printed by the loop above when it differs).
	game.run.run_seed = 29
	game.run.pocket_draw_cache = {}
	game.flow.enter_stage(5, Vector3.ZERO, false)
	await physics_frame
	var kept: Dictionary = acts.stage_modifier.duplicate(true)
	t.check("the retry case has a modifier", not kept.is_empty())
	game.flow.retry_stage()
	await physics_frame
	t.eq("a retry keeps the stage's modifier", acts.stage_modifier, kept)
	game.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://stage-modifier-test.json"))
