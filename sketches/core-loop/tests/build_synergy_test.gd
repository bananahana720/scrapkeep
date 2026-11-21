extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Parts := preload("res://src/build/parts.gd")
const PartDef := preload("res://src/build/part_def.gd")
const Synergies := preload("res://src/build/synergies.gd")
const MakerSets := preload("res://src/build/maker_sets.gd")
const AlphaDefs := preload("res://src/core/alpha_defs.gd")
const Bindings := preload("res://src/core/bindings.gd")
const WordBudget := preload("res://src/ui/word_budget.gd")

# Maker tricks (synergies.gd; systems audit pass D fold, 11 Nov 2026): the build's one set rule
# is the maker. Checks: every trick names a known maker and changes behaviour rather than a
# number, every maker carries at least one; each trick is off with one piece of its maker and
# awake with two distinct pieces, and a copy of the same piece is not a second one. Every callout
# names two parts of the trick's maker that wake it together, and three words. The codex cards
# say what wakes each trick. The first firing in a run is a discovery (waking discovers nothing),
# and a retry does not add it to the discovered list twice. Offers carry "* completes X *" once
# one piece is held. Every awake trick puts a ring on the ball. Every part on the alpha table
# names the verb it touches and a maker, and each wave 11 part (the ones with a pitch) has a
# three-word pitch and changes exactly one number.

# 2026-10-04: the default table is the alpha ruleset (twelve parts, five synergies, class pick on); this test checks the full catalogue so it runs on the legacy FirstWorld table.
class LegacyGame extends "res://src/game.gd":
	func _chosen_table():
		return preload("res://tests/doubles/two_world_defs.gd").FirstWorld

var _game
var _build
var _failures := 0
var _ticks := 0


func _initialize() -> void:
	_game = LegacyGame.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_ticks += 1
	if _ticks == 1:
		_game.ctx.calm = true
		_game.player.source = Intent.Scripted.new()
		_game.flow.press_start()
		_game.flow.choose_class(1)
		_build = _game.ctx.get_meta("build")
		return false
	if _ticks < 12:
		return false
	_check_table()
	_check_callouts()
	_check_alpha_parts()
	_check_cards()
	_check_each_goes_live()
	_check_marks_and_discovery()
	_check_thermal_shock()
	print("build_synergy_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


# Two distinct class-neutral parts of a maker, for building a test hand; fewer when it has fewer.
func _pieces(maker: String) -> Array:
	var out: Array = []
	for part_id in Parts.ids():
		if out.size() < 2 and Parts.maker_of(part_id) == maker and Parts.def(part_id).class_id == "":
			out.append(part_id)
	return out


func _check_table() -> void:
	var bad: Array = []
	for key in Synergies.ROWS:
		var row: Dictionary = Synergies.ROWS[key]
		if not MakerSets.SETS.has(row["maker"]):
			bad.append("%s maker %s" % [key, row["maker"]])
		if row.get("transformers", []).is_empty() and row.get("elements", {}).is_empty():
			bad.append("%s changes no behaviour" % key)
		for tag in row["tags"]:
			if not tag in PartDef.TAGS:
				bad.append("%s glyph tag %s" % [key, tag])
	for maker in MakerSets.SETS:
		if Synergies.of_maker(maker).is_empty():
			bad.append("%s carries no trick" % maker)
	_report("trick table", bad.is_empty() and Synergies.ROWS.has("storm_lattice") and Synergies.ROWS.has("thermal_shock"),
		"%d tricks over %d makers; problems %s" % [Synergies.ROWS.size(), MakerSets.SETS.size(), bad])


# has_callout: a callout names two distinct parts of the trick's maker that wake it together,
# and exactly three words. Element-only tricks (told when they wake) carry none.
func _check_callouts() -> void:
	var bad: Array = []
	var walked := 0
	for key in Synergies.ROWS:
		var call := Synergies.callout(key)
		if call.is_empty():
			if not Synergies.told_on_wake(key):
				bad.append("%s has transformers but no callout" % key)
			continue
		walked += 1
		var a := String(call.get("a", ""))
		var b := String(call.get("b", ""))
		var maker: String = Synergies.ROWS[key]["maker"]
		if a == b or not Parts.has(a) or not Parts.has(b) or Parts.maker_of(a) != maker or Parts.maker_of(b) != maker:
			bad.append("%s callout %s + %s" % [key, a, b])
		elif not key in Synergies.active(Parts.maker_counts([a, b])):
			bad.append("%s not woken by its callout" % key)
		if WordBudget.words_in(String(call.get("words", ""))) != 3:
			bad.append("%s words '%s'" % [key, call.get("words", "")])
	_report("has_callout", bad.is_empty() and walked > 0,
		"%d callouts walked, each two parts of the trick's maker that wake it and three words; problems %s" % [walked, bad])


# The numbers a part changes: tuning knobs, punch, cooldown, health, magnet, scrap, charges,
# pattern levels. An element trigger alone is not a number.
func _numbers(part_id: String) -> Array:
	var d: Resource = Parts.def(part_id)
	var out: Array = d.mods.keys()
	if d.punch > 0.0:
		out.append("punch")
	if d.cooldown_scale != 1.0:
		out.append("cooldown")
	if d.max_hp_bonus > 0.0:
		out.append("max_hp")
	if d.magnet != 1.0:
		out.append("magnet")
	if d.kill_scrap != 1.0:
		out.append("kill_scrap")
	for slot in d.charges:
		out.append("charges:" + String(slot))
	for pattern in d.patterns:
		out.append("pattern:" + String(pattern))
	# 2026-10-15 PC-POOL re-pin: drop_weight's one number is an effect (pin_bonus), counted as one.
	if not d.effect.is_empty():
		out.append("effect:" + String(d.effect.get("do", "")))
	return out


func _check_alpha_parts() -> void:
	var bad: Array = []
	var families := {}
	var added: Array = []
	for part_id in AlphaDefs.PARTS:
		var row: Dictionary = Parts.row(part_id)
		var verb := String(row.get("touches", ""))
		if row.is_empty() or not Bindings.VERBS.has(verb) or verb in ["look", "interact"]:
			bad.append("%s touches '%s'" % [part_id, verb])
		if not MakerSets.SETS.has(Parts.maker_of(part_id)):
			bad.append("%s names no maker" % part_id)
		families[verb] = families.get(verb, 0) + 1
		if not row.has("pitch"):
			continue
		added.append(part_id)
		var numbers := _numbers(part_id)
		if WordBudget.words_in(String(row["pitch"])) != 3 or numbers.size() != 1:
			bad.append("%s pitch '%s' numbers %s" % [part_id, row["pitch"], numbers])
		var d: Resource = Parts.def(part_id)
		if d.mods.has("weapon_damage") or d.punch > 0.0:
			bad.append("%s is a damage part" % part_id)
	var distinct := {}
	for part_id in AlphaDefs.PARTS:
		distinct[part_id] = true
	# 2026-10-11 (alpha wave 13 SG5): load_dividend; was 18 parts and 18 distinct ids.
	# 2026-10-15 (wave 14 SQ19b): 45 parts (kit commons, four shelf parts, Tally's winch_pawl, the
	# seventh part with a pitch); was 19 parts, 19 distinct ids and 6 with a pitch.
	# 2026-10-27 (wave 20 cobalt rung): 49 parts, adding four catalogue rares; was 45 and 45.
	# 2026-11-21 (wave 45 U7): 71 parts, adding 5 verb items (backwash, barbed_reel, faultline_cap, second_bell, long_leash); was 66 and 66.
	# 2026-11-21 (wave 45 U6): 66 parts, adding Slag Pike and Halo Rig; was 64 and 64.
	# 2026-11-21 (wave 45 B1): 64 parts, adding Fan Spread, Helix Drill and 13 authored items.gd rows (shared movement rows kept out per BIBLE.md:537; cobalt ceiling per ruling bn); was 49 and 49.
	# 2026-11-12 (W1-64): Spare Cell gains a kill refill, two numbers, so it leaves the pitch parts; was 7.
	_report("alpha parts", bad.is_empty() and AlphaDefs.PARTS.size() == 71 and distinct.size() == 71 and added.size() == 6,
		"%d parts by verb %s, %d with a pitch %s; problems %s" % [AlphaDefs.PARTS.size(), families, added.size(), added, bad])


# The trick cards, plus v2 W4's callback cards (Strike, Spare, Turkey and Moss's "Too heavy
# for you"), which name no maker.
func _check_cards() -> void:
	var all: Array = _build.codex_declarations()
	var cards: Array = all.filter(func(c): return c.has("maker"))
	var callbacks: Array = all.filter(func(c): return not c.has("maker"))
	var bad: Array = []
	for card in all:
		for field in ["id", "category", "name", "hint", "text"]:
			if String(card.get(field, "")) == "":
				bad.append("%s missing %s" % [card.get("id", "?"), field])
		if card["category"] != "build":
			bad.append("%s category %s" % [card["id"], card["category"]])
	for card in cards:
		if card["hint"] != "Two %s parts" % MakerSets.SETS[card["maker"]]["name"]:
			bad.append("%s hint '%s'" % [card["id"], card["hint"]])
	var storm: Dictionary = cards.filter(func(c): return c["id"] == "storm_lattice")[0]
	_report("codex trick cards", bad.is_empty() and cards.size() == Synergies.ROWS.size() and callbacks.size() == 4,
		"%d trick cards and %d callback cards, each with category, name, hint and text; e.g. '%s'; problems %s"
			% [cards.size(), callbacks.size(), storm["hint"], bad])


func _check_each_goes_live() -> void:
	var wrong: Array = []
	for key in Synergies.ROWS:
		var pieces := _pieces(Synergies.ROWS[key]["maker"])
		if pieces.size() < 2:
			wrong.append("%s: fewer than two neutral pieces %s" % [key, pieces])
			continue
		var alone := Synergies.active(Parts.maker_counts([pieces[0]]))
		var copy := Synergies.active(Parts.maker_counts([pieces[0], pieces[0]]))
		var both := Synergies.active(Parts.maker_counts(pieces))
		if key in alone or key in copy or not key in both:
			wrong.append("%s: one %s, a copy %s, two %s" % [key, alone, copy, both])
	_report("each trick wakes on two pieces of its maker", wrong.is_empty(),
		"every trick is off with one piece or two copies of it, and awake with two distinct pieces; wrong %s" % [wrong])


func _check_marks_and_discovery() -> void:
	var run = _game.run
	var mark_before: String = _build.offer_mark("pin_setter")
	run.add_part("synergy_lens", "test")
	_build.recompute()
	var lens_starts: String = _build.offer_mark("pin_setter")
	run.parts.erase("synergy_lens")
	_build.recompute()
	_report("lens names the trick a first piece starts", lens_starts == "* starts Shrapnel Bloom *",
		"holding the lens and nothing of Redjaw, Pin Setter reads '%s'" % lens_starts)
	run.add_part("cross_split", "test")
	var completes: String = _build.offer_mark("pin_setter")
	var ring_before: bool = _build.accretion.halo_visible("storm_lattice")
	run.add_part("pin_setter", "test")
	var live: bool = "storm_lattice" in _build.active_synergies() and _build.has_transformer("storm_lattice") \
		and _build.pattern_level("chain_arc") == 1
	_report("offer marks", mark_before == "" and completes == "* completes Shrapnel Bloom *",
		"with nothing held, Pin Setter reads '%s'; holding Cross Split it reads '%s'" % [mark_before, completes])
	_report("storm lattice", live and not ring_before and _build.accretion.halo_visible("storm_lattice"),
		"Cross Split + Pin Setter (Redjaw): tricks %s, transformer storm_lattice %s, patterns %s; its ring appeared on the ball"
			% [_build.active_synergies(), _build.has_transformer("storm_lattice"), _build.patterns()])
	var armed_discovered: Array = _build.discovered()
	_fire_lattice()
	var discovered: Array = _build.discovered()
	_game.flow.retry_stage()
	var dropped: bool = _build.active_synergies().is_empty() and not _build.accretion.halo_visible("storm_lattice")
	run.add_part("cross_split", "test")
	run.add_part("pin_setter", "test")
	_fire_lattice()
	_report("discovery once per run", armed_discovered.is_empty() and discovered == ["storm_lattice"] and _build.discovered() == ["storm_lattice"] and dropped,
		"first activation discovered %s; after a retry dropped it (%s) and it came back, discovered is still %s"
			% [discovered, dropped, _build.discovered()])
	_game.flow.retry_stage()


# Storm Lattice's effect resolves at a shot; the first one of an activation is the discovery.
func _fire_lattice() -> void:
	var ball: Vector3 = _game.player.ball_position()
	_game.events.shot_fired.emit("arc_caster", ball, ball + Vector3(5, 0, 0))


func _check_thermal_shock() -> void:
	var run = _game.run
	run.add_part("spiral_wave", "test")
	var before: Array = _build.sheet.elements_for("slam")
	run.add_part("echo_locator", "test")
	var after: Array = _build.sheet.elements_for("slam")
	_report("thermal shock", not "thermal_shock" in _build.sheet.synergies or before.is_empty()
			and "arc" in after and "frost" in after
			and "thermal_shock" in _build.active_synergies() and is_equal_approx(_build.field.shatter_scale, 2.0)
			and _build.accretion.halo_visible("thermal_shock"),
		"slam elements %s with Spiral Wave alone, %s with Echo Locator too (Waking); shatter x%.1f; live %s"
			% [before, after, _build.field.shatter_scale, _build.active_synergies()])
