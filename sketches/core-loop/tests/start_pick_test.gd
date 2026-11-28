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
const WordBudget := preload("res://src/core/word_budget.gd")
const T := preload("res://tests/support/t.gd")

const STARTS := 200
# A tile name is a glance, not a sentence.
const NAME_WORDS := 3
# "Unchanged within noise": the offer is ready in the same frame begin() runs in, and the card
# pauses nothing, so the first input lands on the same tick as with no pick. Tests may not read
# the wall clock (lint L1), so the cost is counted in frames and paused ticks, both zero.
const NOISE_FRAMES := 0

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
	var part_info := func(id: String) -> Dictionary: return {"name": Parts.display_name(id), "icon": Parts.icon_of(id), "effect": String(Parts.row(id).get("verb", ""))}
	for def in ClassDef.all():
		var list: Array = StartPicks.list_for(def.id, part_info)
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
			var effect_words := WordBudget.words_in(String(row.get("effect", "")))
			t.check("%s %s says what it does in at most %d words" % [def.id, id, StartPicks.EFFECT_WORDS],
				effect_words >= 1 and effect_words <= StartPicks.EFFECT_WORDS and String(row["effect"]) != String(row["name"]), String(row.get("effect", "")))
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
		var frames_added := 0
		for i in STARTS:
			# begin() draws the offer; the frames between it and an offer ready to show are the
			# delay the pick adds before the first input. The no-pick baseline adds none.
			var b := _fresh(1000 + i)
			var f0 := Engine.get_process_frames() + Engine.get_physics_frames()
			b.begin(def)
			# flow._begin_run: begin(def), then enter_stage(1) (flow.gd:249-255).
			b.enter_stage(1)
			var options: Array = b.start_pick_options()
			frames_added += Engine.get_process_frames() + Engine.get_physics_frames() - f0
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
						# The stage entry already ran, so the core is still there to spend.
						applied = cores0 == 0 and b.bonus_cores == 1 and b.parts.size() == parts0
				if not applied or String(b.start_pick.get("taken", "")) != id:
					bad_effects += 1
		var list: Array = StartPicks.list_for(def.id)
		table.append("start-pick %s: %d starts, taken by slot %s, %d of %d rows taken, %d rerolls, frames added before first input %d"
			% [def.id, STARTS, taken_by_index, taken_ids.size(), list.size(), rerolls, frames_added])
		t.eq("%s every start offered three distinct rows of its own list" % def.id, bad_offers, 0)
		t.eq("%s every take applied exactly its row" % def.id, bad_effects, 0)
		t.check("%s each of the three slots taken at least once" % def.id, taken_by_index.min() >= 1, "%s" % [taken_by_index])
		t.check("%s every list row taken at least once in %d starts" % [def.id, STARTS], taken_ids.size() == list.size(),
			"%d of %d" % [taken_ids.size(), list.size()])
		t.check("%s rerolls happened" % def.id, rerolls > 0, str(rerolls))
		t.eq("%s the pick adds no frame before the first input" % def.id, frames_added, NOISE_FRAMES)
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
# doc of the new run carries none of it. Every row of every pilot's list is forced into slot 0
# and taken, so a row the seed's first draw never offers is covered too.
func _no_persist() -> void:
	var total := 0
	for def in ClassDef.all():
		var fresh := _fresh(77)
		fresh.begin(def)
		var clean := _strip(fresh.to_entrance_doc())
		var ids: Array = StartPicks.ids_for(def.id)
		var exercised := 0
		for id in ids:
			var run := _fresh(77)
			run.begin(def)
			run.enter_stage(1)
			run.start_pick["options"] = [id, "", ""]
			t.check("%s take %s" % [def.id, id], run.take_start_pick(0))
			exercised += 1
			run.begin(def)
			t.eq("%s %s gone after a new run" % [def.id, id], String(run.start_pick.get("taken", "")), "")
			t.eq("%s %s new run equals a fresh one" % [def.id, id], _strip(run.to_entrance_doc()), clean)
			# The entrance doc is not the whole run: a field outside it that begin() does not
			# reset could carry a pick into the next run, so every script field is compared.
			var drift := _state_drift(run, fresh)
			t.check("%s %s no run field survives into the next run" % [def.id, id], drift.is_empty(), "%s" % [drift])
		t.check("%s no-persist covered every list row" % def.id, ids.size() > 0 and exercised == ids.size(),
			"%d of %d" % [exercised, ids.size()])
		total += exercised
	print("start-pick no-persist: %d rows exercised across %d pilots" % [total, ClassDef.all().size()])


# Script fields that legitimately differ between two runs: the id stream and what it draws
# (run_id, run_seed), and the offer drawn from that seed.
const RUN_SPECIFIC := {"run_id": true, "run_seed": true, "start_pick": true, "_id_rng": true}


func _state_drift(run: RunState, fresh: RunState) -> Array:
	var drift := []
	var compared := 0
	for prop in run.get_property_list():
		if not (int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var name := String(prop["name"])
		if RUN_SPECIFIC.has(name):
			continue
		compared += 1
		var a = run.get(name)
		var b = fresh.get(name)
		if typeof(a) != typeof(b) or a != b:
			drift.append("%s: %s vs fresh %s" % [name, a, b])
	# A property list that came back empty would pass vacuously.
	if compared < 30:
		drift.append("only %d script fields compared" % compared)
	return drift


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
		a.enter_stage(1)
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
		# flow's resume path calls enter_stage(run.stage) after from_entrance_doc (flow.gd:315-321).
		d.enter_stage(d.stage)
		t.check("%s replayed offer can be taken after the stage entry" % def.id, d.take_start_pick(0))
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
	t.check("take refused before enter_stage(1)", not run.take_start_pick(0))
	t.eq("refused early take leaves the offer open", String(run.start_pick.get("taken", "")), "")
	run.enter_stage(1)
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
	run2.enter_stage(1)
	run2.take_start_pick(1)
	t.check("reroll after a take refused", not run2.reroll_start_pick())
	var dead := _fresh(33)
	dead.begin(def)
	dead.enter_stage(1)
	dead.over = true
	t.check("no take on an ended run", not dead.take_start_pick(0))
	# A pick left untaken in stage 1 closes with it: the entrance doc still carries the offer,
	# but stage 2 refuses it, whether reached live or through the doc.
	var late := _fresh(34)
	late.begin(def)
	late.enter_stage(1)
	late.enter_stage(2)
	t.check("untaken pick refused in stage 2", not late.take_start_pick(0))
	t.check("reroll refused in stage 2", not late.reroll_start_pick())
	var late_doc = JSON.parse_string(JSON.stringify(late.to_entrance_doc()))
	var loaded := _fresh(35)
	loaded.begin(def)
	t.check("stage 2 doc applies", loaded.from_entrance_doc(late_doc))
	loaded.enter_stage(loaded.stage)
	t.check("untaken pick refused after loading a stage 2 doc", not loaded.take_start_pick(0))
	# Every core kind: taking the Bonus Core after the stage entry leaves exactly one core.
	for d in ClassDef.all():
		for id in StartPicks.ids_for(d.id):
			if String(StartPicks.row(d.id, id).get("do", "")) != "core":
				continue
			var c := _fresh(36)
			c.begin(d)
			c.enter_stage(1)
			c.start_pick["options"] = [id, "", ""]
			t.check("%s %s taken" % [d.id, id], c.take_start_pick(0))
			t.eq("%s %s leaves one core after the stage entry" % [d.id, id], c.bonus_cores, 1)


# The card draws three tiles and never pauses or blocks input.
func _card() -> void:
	var def: Resource = ClassDef.all()[1]
	var run := _fresh(51)
	run.begin(def)
	run.enter_stage(1)
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
	var card_words := (NAME_WORDS + StartPicks.EFFECT_WORDS) * StartPicks.OFFERED
	t.check("card at most %d words: a name and an effect line a tile" % card_words, words > 0 and words <= card_words, str(words))
	for tile in card.tiles():
		t.check("tile %s has icon and key" % [tile], String(tile.get("icon", "")) != "" and String(tile.get("key", "")) != "")
		t.check("tile %s says what it does" % [tile.get("id", "")], String(tile.get("effect", "")) != "" and String(tile["effect"]) in card.drawn_words(), String(tile.get("effect", "")))
	t.eq("card shows the reroll left", card.rerolls_left(), 1)
	run.take_start_pick(0)
	card.show_picks(run)
	t.check("card hides once the pick is taken", not card.showing())
	var later := _fresh(52)
	later.begin(def)
	later.enter_stage(1)
	later.enter_stage(2)
	card.show_picks(later)
	t.check("card hides past stage 1", not card.showing())
	card.queue_free()
