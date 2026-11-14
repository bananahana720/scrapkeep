extends SceneTree
# smoke: solo timeout=420s (six park graphs prepared, then a park game entering stages 1 to 6)

# Rule (SI3, W13-INTEGRATION-3.md SI3): at most one stage modifier per stage, picked from the run seed
# and stage alone, shown on the stage card before the stage starts and equal to the one the pocket
# draw applies. A count row keeps the drawn count within the cap, Far Haul keeps every drawn pocket on
# the farthest few anchors, a sight row only scales the beacon, no row touches handling over 600
# stepped ticks, and a draw with no modifier is byte-identical to the draw before SI3.
# The dam (stage 1) rolls like every other stage since ruling bu (2026-11-09): it draws one pocket,
# as the flume does, so a row has a draw to act on.

const T := preload("res://tests/support/t.gd")
const Modifier := preload("res://src/world/events/stage_modifier.gd")
const PocketDraw := preload("res://src/world/pockets/pocket_draw.gd")
const Graph := preload("res://src/world/park/park_graph.gd")
const Map := preload("res://src/world/park/park_map.gd")
const Park := preload("res://src/core/park_defs.gd")
const Trade := preload("res://src/world/trade_pockets.gd")
const ActivityView := preload("res://src/world/activity_view.gd")
const LaunchCard := preload("res://src/ui/launch_card.gd")
const UiDraw := preload("res://src/ui/ui_draw.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const Rules := preload("res://src/movement/ball_rules.gd")
const BallState := preload("res://src/movement/ball_state.gd")

# SHA-256 of var_to_bytes(draw(...)) for run seeds 0 to 3 per stage, with no modifier, captured before SI3
# (stages 2-3 on main cf63e622; stages 4-6 re-captured on stage/alpha-w17 27e15952, whose parks changed). A draw with no modifier must still produce exactly these bytes.
# 2026-10-19, Gate lane: stage 2 re-captured after #126's flume park rewrite (04eb0d00), and stages 5 and 6
# re-captured because #139's pins already missed the stage it landed on (ecf6f629 draws these same bytes).
# Stage 6 re-captured again after #170's crown park change (3b7a26f0), on 240520a3.
# 2026-10-23, World: stage 4 re-captured after #350 moved two park_sinkhole anchor posts and rebaked its graph
# (B12 2b04b3f3; its parent a777720a still draws d2f652ab..., B12 and f7dbb78c draw fc4abcc4...).
# 2026-10-23, World: stage 4 re-captured after the wash elbow easing reshaped lava_channel_12, 13 and 21 and rebaked
# park_sinkhole (fc4abcc4... -> 4b43cd95...; every other check line unchanged).
# 2026-10-23, World: stage 4 re-captured after the second wash elbow easing (lava_channel_14 and lava_channel_20
# shortened) and the park_sinkhole rebake (4b43cd95... -> e6afadaa...; every other check line unchanged).
# 2026-10-24, flume pass two: stage 2 re-captured after #432's flume rows and rebake, with its card 2 extras standing
# beside the draw (209b49bf... -> 2422257f...; every other check line unchanged).
# 2026-11-09, ruling bu (the dam joins the roll, camps pay from the pool): every stage re-captured. Stage 1 is
# new. Stage 2 moved with world 1's level-ground rule (pocket_draw.gd TIDY). Stages 3 to 6 moved only in the
# drawn camps' pay: with the old pay ({named hot_rivets, common and rare}) put back on each drawn camp, the four
# hashes were the pins they replace (6b2244ea..., e6afadaa..., d89a37e5..., 01459ce0...), so no site moved.
# 2026-11-13, two library rows: PR 924 (W1-17) assigned sump_vault to the flume's trestle_cache, so on stages 2 and 4,
# whose draws held it, its interior carries the assignment (sites unchanged, measured on 1ec89600: stages 1, 3, 5, 6
# kept their pins). PR 925 (W1-76) added incline_vault, a small secret assigned to the dam, which every other park
# may draw; the draw picks among the rooms it can afford, so all six stages moved (3f989714... -> 37c6a9b6..., 36c277f7...
# -> 6a062ee3..., c428c12b... -> 55d86bc8..., de3a6b7c... -> 09e28c2c..., 5b1da6fc... -> 70807e39..., 17825245... ->
# ee063c31...).
const GOLDEN := {
	1: "37c6a9b642914fa639033a4c22cdfe0fbdd86952e1451f5c6f6a2883fb0cbb31",
	2: "6a062ee367b7523c7260c9e5c742929d66b7383cf1e0d84c38a6d313d0eb8651",
	3: "55d86bc8cf198a63c7a692c8c29f5e4efe58b7aa99312e02c345f42de7c22f7b",
	4: "09e28c2ca5f2f22a286ee5e4495eab8d1e3d3724483816f053be9cccc4bcb99b",
	5: "70807e398a40a6dfd76baa8a6fa437b864ba47603fc390402cec108c8325a12d",
	6: "ee063c318b2053d8272dec36f194458c6f703435d78acd905878ac3f7b06bd7f",
}
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
	for stage in range(1, Park.COUNT + 1):
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
		# The memo voice never costs the read: the line still ends on what the stage does, the right way round.
		var effect := "edges."
		if row.has("count_scale"):
			effect = "More pockets." if float(row.count_scale) > 1.0 else "Fewer pockets."
		elif row.has("sight_scale"):
			effect = "Beacons read far." if float(row.sight_scale) > 1.0 else "Beacons read near."
		t.check("%s line ends on what the stage does" % row.id, String(row.line).ends_with(effect), String(row.line))
		# The card draws its line unwrapped, so the longest it can carry (a cursed run's line beside
		# the stage's) has to sit inside the 1600-wide view with a margin.
		var pair: String = Modifier.caption(Modifier.CURSE) + "  /  " + Modifier.caption(row)
		var pair_w: float = UiDraw.width(pair, LaunchCard.LINE_FONT)
		t.check("%s line fits the card beside the cursed line" % row.id, pair_w <= 1600.0 * 0.85, "%.0f px: %s" % [pair_w, pair])
	t.check("the cursed line fits the card too", String(Modifier.CURSE.line).split(" ", false).size() <= 8)
	# W1-75: a stage with no modifier carries a nominal Foreman memo, never a blank card. Each fits
	# beside the cursed line, names no condition (no "Word:" before it), and the seed picks it.
	var nominal := {}
	for line in Modifier.NOMINAL:
		t.check("nominal memo '%s' fits in 8 words" % line, String(line).split(" ", false).size() <= 8)
		t.check("nominal memo '%s' names no condition" % line, not Modifier.ROWS.any(func(r): return String(line).begins_with(String(r.word))))
		var with_curse: String = Modifier.caption(Modifier.CURSE) + "  /  " + String(line)
		t.check("nominal memo '%s' fits beside the cursed line" % line, UiDraw.width(with_curse, LaunchCard.LINE_FONT) <= 1600.0 * 0.85)
	for seed_n in 64:
		for stage in range(1, 7):
			nominal[Modifier.memo(seed_n, stage, {})] = true
	t.check("every nominal memo comes from the list", nominal.keys().all(func(m): return Modifier.NOMINAL.has(m)), str(nominal.keys()))
	t.eq("64 seeds over six stages show every nominal memo", nominal.size(), Modifier.NOMINAL.size())
	t.check("the same seed and stage keep the same memo", Modifier.memo(7, 2, {}) == Modifier.memo(7, 2, {}))
	t.check("a rolled modifier's memo is its caption", Modifier.memo(7, 2, Modifier.ROWS[0]) == Modifier.caption(Modifier.ROWS[0]))
	t.eq("row ids are unique", ids.size(), Modifier.ROWS.size())
	t.check("world-effect overlays name WORLD-FX.md kinds", Modifier.ROWS.all(func(row): return String(row.get("fx", "")) in ["", "plenty", "scarce", "hidden"]))
	var planted := {"id": "slick", "word": "Slick", "line": "x", "friction": 0.1}
	t.check("planted handling key is rejected", not Modifier.valid(planted))


# 2,000 run seeds per stage, three authored sites as every park map has.
func _picks() -> void:
	var seen := {}
	var hits := 0
	var rolls := 0
	var deterministic := true
	var in_cap := true
	var dam_hits := 0
	for stage in range(1, Park.COUNT + 1):
		for s in PICK_SEEDS:
			var row := Modifier.pick(s, stage, 3)
			deterministic = deterministic and row == Modifier.pick(s, stage, 3)
			# The dam has four authored sites, one over stage 1's count: it rolls all the same.
			if stage == 1 and not Modifier.pick(s, stage, 4).is_empty():
				dam_hits += 1
			rolls += 1
			if row.is_empty():
				continue
			hits += 1
			seen[row.id] = true
			var n := Modifier.slots(row, stage, 3)
			in_cap = in_cap and n >= 1 and n + 3 <= Modifier.CAP and n <= Modifier.max_slots(stage, 3)
			if row.has("count_scale"):
				in_cap = in_cap and n != Modifier.base_slots(stage, 3)
	t.eq("the dam's four authored sites still leave it one drawn pocket", Modifier.base_slots(1, 4), Modifier.MIN_DRAWN)
	t.check("the dam rolls a modifier at the same rate", absf(float(dam_hits) / PICK_SEEDS - Modifier.CHANCE) <= 0.04, "%d of %d" % [dam_hits, PICK_SEEDS])
	t.check("stages 2 to 6 keep their drawn counts", range(2, Park.COUNT + 1).all(func(stage): return Modifier.base_slots(stage, 3) == mini(Modifier.CAP, stage + 2) - 3))
	t.check("same seed and stage pick the same row", deterministic)
	t.check("drawn count stays inside the cap of 8 with every row", in_cap)
	var rate := float(hits) / rolls
	t.check("modifier rate near %.2f on stages 1 to 6" % Modifier.CHANCE, absf(rate - Modifier.CHANCE) <= 0.04, "rate %.3f over %d" % [rate, rolls])
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
	var authored: int = Modifier.authored(map)
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
	var golden := HashingContext.new()
	golden.start(HashingContext.HASH_SHA256)
	for s in 4:
		var run = Run.new()
		run.stage = stage
		run.run_seed = s
		golden.update(var_to_bytes(_draw(prepared, map, stage, s, Trade.stage_site(graph, map, run, 78000, trade_pool))))
	t.eq("stage %d: no-modifier draw matches main's bytes before SI3" % stage, golden.finish().hex_encode(), GOLDEN[stage])
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


# A park game enters stages 1 to 6 for three run seeds. On every entry the activities' applied row
# equals the pick, the stage card shows its memo (the caption, or a nominal Foreman line when none
# rolled), and the card shown at launch for the next stage in the world carries the same memo. A retry keeps the row.
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
	var world_ok := true
	var world_cards := 0
	for s in RUN_SEEDS:
		game.run.run_seed = s
		game.run.pocket_draw_cache = {}
		for stage in range(1, Park.COUNT + 1):
			var expected := Modifier.pick(s, stage, 3)
			hud.launch_card.visible = false
			hud._world_card_at = -1
			game.flow.enter_stage(stage, Vector3.ZERO, false)
			await physics_frame
			# A new world shows its world card first and the stage card a beat later.
			if hud.launch_card.title != game.ctx.stages.of(stage)["name"]:
				world_ok = world_ok and hud.launch_card.line == Modifier.memo(s, stage, expected)
				world_cards += 1
				for frame in 600:
					if hud.launch_card.title == game.ctx.stages.of(stage)["name"]:
						break
					await process_frame
			entries += 1
			var card_line: String = hud.launch_card.line if hud.launch_card.showing() else "<no card>"
			var ok: bool = acts.stage_modifier == expected and card_line == Modifier.memo(s, stage, acts.stage_modifier)
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
				launch_ok = launch_ok and hud.launch_card.line == Modifier.memo(s, next, Modifier.pick(s, next, 3))
	t.eq("every stage entry shows the applied modifier on its card", shown_ok, entries)
	t.check("the runtime saw modifiers applied", applied > 0, "%d of %d entries" % [applied, entries])
	t.check("the launch card for the next stage carries its modifier", launch_ok)
	t.check("sight rows scale the drawn beacons", drawn_ok)
	t.check("a new world's card carries its first stage's modifier from entry", world_ok and world_cards > 0, "%d world cards" % world_cards)
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
	await _curse(game)
	game.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://stage-modifier-test.json"))


# Taking a curse pocket's deal turns the run cursed: its card goes up at once, the build clock's
# tags carry "curse" for the music, and later stage cards carry the cursed line. A retry rewinds
# the stage's trade memory, so a curse taken in the retried stage is undone with it.
func _curse(game) -> void:
	var run = game.run
	var hud = game.hud
	t.check("a fresh run is not cursed", not run.cursed() and not game.build.clock.tags().has(Modifier.CURSE.id))
	var offer := {"stage": run.stage, "family": "risk", "interior_id": "curse_counter", "curse": true, "sacrifice": false}
	run.trade_memory.seen.append(offer)
	t.check("seeing a curse offer does not curse the run", not run.cursed())
	run.trade_memory.decisions[str(run.stage)] = true
	hud.launch_card.visible = false
	await process_frame
	await physics_frame
	t.check("taking the deal curses the run", run.cursed())
	t.check("the Cursed Run card goes up when the deal is taken", hud.launch_card.showing() and hud.launch_card.title == Modifier.CURSE.word,
		"card '%s'" % hud.launch_card.title)
	t.check("the build clock's tags carry curse for the music", game.build.clock.tags().has(Modifier.CURSE.id), str(game.build.clock.tags()))
	hud.launch_card.visible = false
	hud._card_for_stage(6)
	t.check("a later stage card carries the cursed line", hud.launch_card.line.begins_with(Modifier.caption(Modifier.CURSE)), "line '%s'" % hud.launch_card.line)
	game.flow.retry_stage()
	await physics_frame
	t.check("a retry rewinds a curse taken in that stage", not run.cursed() and not game.build.clock.tags().has(Modifier.CURSE.id))
