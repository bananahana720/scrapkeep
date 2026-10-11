extends SceneTree

# SG9 run-start pick of three (W13-INTEGRATION-3.md, SG9; comps gunfire/heroes-and-ascensions.md:23).
# At run start each pilot is offered three small options from its own list, drawn from the run
# seed, with one reroll. The 200-start table prints per pilot; the checks below fail loud on a
# list that touches a movement knob, a pick that outlives its run, a draw the entrance save
# cannot replay, or a card that pauses the game.

const RunState := preload("res://src/core/run_state.gd")
const StartPicks := preload("res://src/core/start_picks.gd")
const StartPickCard := preload("res://src/ui/start_pick_card.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Parts := preload("res://src/build/parts.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const WordBudget := preload("res://src/ui/word_budget.gd")
const T := preload("res://tests/support/t.gd")

const STARTS := 200
# A tile name is a glance, not a sentence.
const NAME_WORDS := 3
# "Unchanged within noise": the pick may add at most this many microseconds to a run start,
# far under one 60 Hz frame (16,667 us), so no input frame is lost to it.
const NOISE_US := 500.0

var t: T
var events


func _initialize() -> void:
	t = T.new("start_pick_test")
	events = GameEvents.new()
	_lists()
	_starts_table()
	_no_persist()
	_replay()
	_reroll_rules()
	_card()
	events.free()
	quit(t.verdict())


# Every knob a mobility part moves, read from the catalogue itself, so a new mobility part
# widens the ban without an edit here.
func _movement_knobs() -> Dictionary:
	var knobs := {"cooldown_scale": true}
	for id in Parts.CATALOGUE:
		var row: Dictionary = Parts.CATALOGUE[id]
		if row.get("family", "") == "mobility" or row.get("icon", "") == "mobility":
			for key in (row.get("mods", {}) as Dictionary):
				knobs[key] = true
	return knobs


func _lists() -> void:
	var knobs := _movement_knobs()
	t.check("movement knobs found in the catalogue", knobs.size() >= 8, "%s" % [knobs.keys()])
	for def in ClassDef.all():
		var list: Array = StartPicks.list_for(def.id)
		t.check("%s has its own list of at least %d" % [def.id, StartPicks.OFFERED * (StartPicks.REROLLS + 1)],
			list.size() >= StartPicks.OFFERED * (StartPicks.REROLLS + 1), "%d rows" % list.size())
		var seen := {}
		for row in list:
			var id := String(row.get("id", ""))
			t.check("%s row %s id unique and named" % [def.id, id], id != "" and not seen.has(id)
				and String(row.get("name", "")) != "", "%s" % [row])
			seen[id] = true
			t.check("%s %s name at most %d words" % [def.id, id, NAME_WORDS],
				WordBudget.words_in(String(row.get("name", ""))) <= NAME_WORDS, String(row.get("name", "")))
			var kind := String(row.get("do", ""))
			t.check("%s %s kind known" % [def.id, id], kind in StartPicks.KINDS, kind)
			if kind == "part":
				var part := String(row.get("part", ""))
				var prow: Dictionary = Parts.CATALOGUE.get(part, {})
				t.check("%s %s part %s exists" % [def.id, id, part], not prow.is_empty())
				t.check("%s %s part is not mobility" % [def.id, id], prow.get("family", "") != "mobility"
					and prow.get("icon", "") != "mobility", "%s" % [prow.get("family", "")])
				var touched := []
				for key in (prow.get("mods", {}) as Dictionary):
					if knobs.has(key):
						touched.append(key)
				if prow.has("cooldown_scale"):
					touched.append("cooldown_scale")
				t.check("%s %s changes no movement knob" % [def.id, id], touched.is_empty(), "%s" % [touched])
				t.check("%s %s part fits the pilot" % [def.id, id], String(prow.get("class_id", def.id)) == def.id)


func _fresh(seed: int) -> RunState:
	var run := RunState.new(events, seed)
	return run


# 200 run starts per pilot: the draw cost against a no-pick baseline, and every option taken.
func _starts_table() -> void:
	var table := []
	for def in ClassDef.all():
		var taken_by_index := [0, 0, 0]
		var taken_ids := {}
		var rerolls := 0
		var bad_offers := 0
		var bad_effects := 0
		var base_us := 0.0
		var pick_us := 0.0
		for i in STARTS:
			# Baseline: a run start with the pick removed afterwards costs begin() alone.
			var a := _fresh(1000 + i)
			var t0 := Time.get_ticks_usec()
			a.begin(def)
			base_us += Time.get_ticks_usec() - t0
			var b := _fresh(1000 + i)
			t0 = Time.get_ticks_usec()
			b.begin(def)
			var options: Array = b.start_pick_options()
			pick_us += Time.get_ticks_usec() - t0
			var all_list: Array = StartPicks.ids_for(def.id)
			var well_formed := options.size() == StartPicks.OFFERED and _distinct(options)
			for id in options:
				well_formed = well_formed and id in all_list
			if not well_formed:
				bad_offers += 1
				continue
			if i % 4 == 3:
				if b.reroll_start_pick():
					rerolls += 1
				options = b.start_pick_options()
			var index := i % StartPicks.OFFERED
			var id := String(options[index])
			var cogs0 := b.cogs
			var cores0 := b.bonus_cores
			var parts0 := b.parts.size()
			if b.take_start_pick(index):
				taken_by_index[index] += 1
				taken_ids[id] = int(taken_ids.get(id, 0)) + 1
				var row := StartPicks.row(def.id, id)
				var applied := false
				match String(row["do"]):
					"part":
						applied = b.parts.size() == parts0 + 1 and b.parts[-1] == row["part"]
					"cogs":
						applied = b.cogs == cogs0 + int(row["amount"]) and b.parts.size() == parts0
					"core":
						applied = b.bonus_cores == cores0 + 1 and b.parts.size() == parts0
				if not applied or String(b.start_pick.get("taken", "")) != id:
					bad_effects += 1
		var list: Array = StartPicks.list_for(def.id)
		var mean_base := base_us / STARTS
		var mean_pick := pick_us / STARTS
		table.append("start-pick %s: %d starts, taken by slot %s, %d of %d rows taken, %d rerolls, begin %.1f us, begin+draw %.1f us"
			% [def.id, STARTS, taken_by_index, taken_ids.size(), list.size(), rerolls, mean_base, mean_pick])
		t.eq("%s every start offered three distinct rows of its own list" % def.id, bad_offers, 0)
		t.eq("%s every take applied exactly its row" % def.id, bad_effects, 0)
		t.check("%s each of the three slots taken at least once" % def.id, taken_by_index.min() >= 1, "%s" % [taken_by_index])
		t.check("%s every list row taken at least once in %d starts" % [def.id, STARTS], taken_ids.size() == list.size(),
			"%d of %d" % [taken_ids.size(), list.size()])
		t.check("%s rerolls happened" % def.id, rerolls > 0, str(rerolls))
		t.check("%s draw adds under %.0f us to a start" % [def.id, NOISE_US], is_finite(mean_pick)
			and mean_pick - mean_base < NOISE_US, "%.1f vs %.1f" % [mean_pick, mean_base])
	for line in table:
		print(line)


func _distinct(a: Array) -> bool:
	var seen := {}
	for x in a:
		if seen.has(x):
			return false
		seen[x] = true
	return true


# A pick lives in this run only: the next begin() puts back a fresh run, and the entrance
# doc of the new run carries none of it.
func _no_persist() -> void:
	for def in ClassDef.all():
		var fresh := _fresh(77)
		fresh.begin(def)
		var clean := _strip(fresh.to_entrance_doc())
		for index in StartPicks.OFFERED:
			var run := _fresh(77)
			run.begin(def)
			t.check("%s take slot %d" % [def.id, index], run.take_start_pick(index))
			run.begin(def)
			t.eq("%s slot %d gone after a new run" % [def.id, index], String(run.start_pick.get("taken", "")), "")
			t.eq("%s slot %d new run equals a fresh one" % [def.id, index], _strip(run.to_entrance_doc()), clean)


# run_id and seed differ between runs by design; start_pick options follow the seed, so the
# comparison keeps only whether a pick was taken and how many rerolls are left.
func _strip(doc: Dictionary) -> Dictionary:
	var out := doc.duplicate(true)
	out.erase("run_id")
	out.erase("seed")
	var sp: Dictionary = out.get("start_pick", {})
	out["start_pick"] = {"taken": sp.get("taken", ""), "rerolls_left": sp.get("rerolls_left", -1)}
	return out


# The three options come back from the seed alone, and from the zone's entrance save.
func _replay() -> void:
	for def in ClassDef.all():
		var a := _fresh(4242)
		a.begin(def)
		var first: Array = a.start_pick_options()
		t.eq("%s draw is a function of the seed" % def.id, StartPicks.draw(def.id, a.run_seed, 0), first)
		var other := _fresh(4243)
		other.begin(def)
		var doc = JSON.parse_string(JSON.stringify(a.to_entrance_doc()))
		var b := RunState.new(events, 9)
		b.begin(def)
		t.check("%s entrance doc applies" % def.id, b.from_entrance_doc(doc), RunState.validate_entrance_doc(doc))
		t.eq("%s replay from the entrance save shows the same three" % def.id, b.start_pick_options(), first)
		# A retry rewinds to the stage-start checkpoint: a pick taken after it comes back as the
		# same open offer, and taking it again pays once.
		a.snapshot(Vector3.ZERO, Vector3.ZERO, 0.0)
		var parts0 := a.parts.size()
		var cogs0 := a.cogs
		a.take_start_pick(0)
		a.restore()
		t.eq("%s retry reopens the same three" % def.id, a.start_pick_options(), first)
		t.eq("%s retry reopens the pick" % def.id, String(a.start_pick.get("taken", "")), "")
		t.check("%s retry rolls the pick's effect back" % def.id, a.parts.size() == parts0 and a.cogs == cogs0)
		# A rerolled offer is the one the save keeps.
		var c := _fresh(4242)
		c.begin(def)
		c.reroll_start_pick()
		var second: Array = c.start_pick_options()
		var doc2 = JSON.parse_string(JSON.stringify(c.to_entrance_doc()))
		var d := RunState.new(events, 9)
		d.begin(def)
		d.from_entrance_doc(doc2)
		t.eq("%s replay keeps the rerolled three" % def.id, d.start_pick_options(), second)
		t.eq("%s replay keeps the reroll spent" % def.id, int(d.start_pick.get("rerolls_left", -1)), 0)
	# An entrance doc from before SG9 still loads, with no pick offered.
	var old := _fresh(5)
	old.begin(ClassDef.all()[0])
	var legacy: Dictionary = old.to_entrance_doc()
	legacy.erase("start_pick")
	var e := _fresh(6)
	e.begin(ClassDef.all()[0])
	t.check("pre-SG9 doc applies", e.from_entrance_doc(legacy))
	t.eq("pre-SG9 doc offers nothing", e.start_pick_options(), [])
	var bad := legacy.duplicate(true)
	bad["start_pick"] = "three"
	t.check("wrong-typed start_pick rejected", RunState.validate_entrance_doc(bad).contains("start_pick"),
		RunState.validate_entrance_doc(bad))


func _reroll_rules() -> void:
	var def: Resource = ClassDef.all()[0]
	var run := _fresh(31)
	run.begin(def)
	var first: Array = run.start_pick_options()
	t.check("one reroll allowed", run.reroll_start_pick())
	var second: Array = run.start_pick_options()
	var overlap := 0
	for id in second:
		if id in first:
			overlap += 1
	t.eq("the reroll shows three new options", overlap, 0)
	t.check("a second reroll refused", not run.reroll_start_pick())
	t.eq("refused reroll changes nothing", run.start_pick_options(), second)
	t.check("out-of-range take refused", not run.take_start_pick(3) and not run.take_start_pick(-1))
	t.check("take slot 2", run.take_start_pick(2))
	t.check("a second take refused", not run.take_start_pick(0))
	var run2 := _fresh(32)
	run2.begin(def)
	run2.take_start_pick(1)
	t.check("reroll after a take refused", not run2.reroll_start_pick())
	var dead := _fresh(33)
	dead.begin(def)
	dead.over = true
	t.check("no take on an ended run", not dead.take_start_pick(0))


# The card draws three tiles and never pauses or blocks input.
func _card() -> void:
	var def: Resource = ClassDef.all()[1]
	var run := _fresh(51)
	run.begin(def)
	var card := StartPickCard.new()
	root.add_child(card)
	card.show_picks(run)
	t.eq("card shows three tiles", card.tiles().size(), StartPicks.OFFERED)
	t.check("card visible", card.showing())
	t.check("card does not pause the tree", not paused)
	t.eq("card ignores the mouse", card.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	t.check("card takes no input", not card.is_processing_input() and not card.is_processing_unhandled_input())
	var words := 0
	for w in card.drawn_words():
		words += WordBudget.words_in(w)
	t.check("card at most %d words" % (NAME_WORDS * StartPicks.OFFERED), words > 0
		and words <= NAME_WORDS * StartPicks.OFFERED, str(words))
	for tile in card.tiles():
		t.check("tile %s has icon and key" % [tile], String(tile.get("icon", "")) != "" and String(tile.get("key", "")) != "")
	t.eq("card shows the reroll left", card.rerolls_left(), 1)
	run.take_start_pick(0)
	card.show_picks(run)
	t.check("card hides once the pick is taken", not card.showing())
	card.queue_free()
