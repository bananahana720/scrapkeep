extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Parts := preload("res://src/build/parts.gd")
const PartDef := preload("res://src/build/part_def.gd")
const Synergies := preload("res://src/build/synergies.gd")
const AlphaDefs := preload("res://src/core/alpha_defs.gd")
const Bindings := preload("res://src/core/bindings.gd")
const WordBudget := preload("res://src/ui/word_budget.gd")

# Named synergies are tag pairs (DEMO-SPEC "Synergies"). Checks: there are about
# eight, every one is a pair of known tags whose shown ingredient carries the first
# tag, every one changes behaviour rather than a number, and each goes live exactly
# when its shown part is held with another part carrying its second tag; a different
# part with the first tag does not stand in for the shown one. The codex hint cards name
# one ingredient and clue the other. The first firing in a run is a discovery (going live
# discovers nothing), and a retry does not add it to the build's discovered list twice. Offers carry "* completes X *" and
# "* ingredient: ??? *", which names the synergy once it is discovered. Every live
# synergy puts a ring on the ball. Every row has a callout (has_callout): two valid part ids,
# a the shown part and b a part carrying the second tag, and exactly three words. Every part on
# the alpha table names the verb it touches, and each wave 11 part (the ones with a pitch) has a
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


# A part other than skip that carries tag, for building a test hand.
func _carrier(tag: String, skip: String) -> String:
	for part_id in Parts.ids():
		if part_id != skip and tag in Parts.tags_of(part_id) and Parts.def(part_id).class_id == "":
			return part_id
	return ""


func _check_table() -> void:
	var bad: Array = []
	for key in Synergies.ROWS:
		var row: Dictionary = Synergies.ROWS[key]
		var tags: Array = row["tags"]
		if tags.size() != 2 or tags[0] == tags[1] or not tags[0] in PartDef.TAGS or not tags[1] in PartDef.TAGS:
			bad.append("%s tags %s" % [key, tags])
		if not tags[0] in Parts.tags_of(row["shown"]):
			bad.append("%s shown %s lacks %s" % [key, row["shown"], tags[0]])
		if row.has("mods") or (row.get("transformers", []).is_empty() and row.get("elements", {}).is_empty()):
			bad.append("%s is a bare number" % key)
	var n := Synergies.ROWS.size()
	_report("synergy table", bad.is_empty() and n >= 7 and n <= 10 and Synergies.ROWS.has("storm_lattice")
			and Synergies.ROWS.has("thermal_shock"),
		"%d named synergies, each a pair of known tags with a behaviour and no bare percentage; problems %s" % [n, bad])


# has_callout: a row's callout names two real parts that make it live together (a is the shown
# part, b carries the second tag) and exactly three words.
func _check_callouts() -> void:
	var bad: Array = []
	for key in Synergies.ROWS:
		var row: Dictionary = Synergies.ROWS[key]
		var call := Synergies.callout(key)
		var a := String(call.get("a", ""))
		var b := String(call.get("b", ""))
		var words := String(call.get("words", ""))
		if call.is_empty():
			bad.append("%s has no callout" % key)
			continue
		if not Parts.rows().has(a) or not Parts.rows().has(b) or a == b:
			bad.append("%s parts %s and %s" % [key, a, b])
			continue
		if a != row["shown"] or not row["tags"][1] in Parts.tags_of(b) or not key in Synergies.active([a, b], Parts.tag_sets([a, b])):
			bad.append("%s: %s + %s does not make it live" % [key, a, b])
		if WordBudget.words_in(words) != 3:
			bad.append("%s words '%s'" % [key, words])
	_report("has_callout", bad.is_empty() and Synergies.ROWS.size() > 0,
		"%d rows walked, each with two valid parts that bring it live and three words; problems %s" % [Synergies.ROWS.size(), bad])


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
	_report("alpha parts", bad.is_empty() and AlphaDefs.PARTS.size() == 49 and distinct.size() == 49 and added.size() == 7,
		"%d parts by verb %s, %d with a pitch %s; problems %s" % [AlphaDefs.PARTS.size(), families, added.size(), added, bad])


# The synergy hint cards, plus v2 W4's callback cards (Strike, Spare, Turkey and Moss's
# "Too heavy for you"), which have no shown ingredient.
func _check_cards() -> void:
	var all: Array = _build.codex_declarations()
	var cards: Array = all.filter(func(c): return c.has("shown"))
	var callbacks: Array = all.filter(func(c): return not c.has("shown"))
	var bad: Array = []
	for card in all:
		for field in ["id", "category", "name", "hint", "clue", "text"]:
			if String(card.get(field, "")) == "":
				bad.append("%s missing %s" % [card.get("id", "?"), field])
		if card["category"] != "build":
			bad.append("%s category %s" % [card["id"], card["category"]])
	for card in cards:
		if not String(card["hint"]).begins_with(Parts.display_name(card["shown"])) \
				or not String(card["hint"]).ends_with(card["clue"]):
			bad.append("%s hint '%s'" % [card["id"], card["hint"]])
	var storm: Dictionary = cards.filter(func(c): return c["id"] == "storm_lattice")[0]
	_report("codex hint cards", bad.is_empty() and cards.size() == Synergies.ROWS.size() and callbacks.size() == 4,
		"%d synergy cards and %d callback cards, each with category, name, hint, clue and text; e.g. '%s'; problems %s"
			% [cards.size(), callbacks.size(), storm["hint"], bad])


func _check_each_goes_live() -> void:
	var wrong: Array = []
	for key in Synergies.ROWS:
		var row: Dictionary = Synergies.ROWS[key]
		var shown: String = row["shown"]
		var other := _carrier(row["tags"][1], shown)
		var alone := Synergies.active([shown], Parts.tag_sets([shown]))
		var both := Synergies.active([shown, other], Parts.tag_sets([shown, other]))
		var stand_in := _carrier(row["tags"][0], shown)
		var without: Array = []
		if stand_in != "" and stand_in != other:
			without = Synergies.active([stand_in, other], Parts.tag_sets([stand_in, other]))
		if key in alone or not key in both or other == "" or key in without:
			wrong.append("%s: alone %s, with %s %s, %s + %s %s" % [key, alone, other, both, stand_in, other, without])
	_report("each synergy goes live on its card", wrong.is_empty(),
		"every named synergy is off with its shown part alone, live once a second part brings the other tag, and off when another part with the first tag stands in; wrong %s" % [wrong])


func _check_marks_and_discovery() -> void:
	var run = _game.run
	var ingredient_before: String = _build.offer_mark("chain_arc")
	run.add_part("cross_split", "test")
	var completes: String = _build.offer_mark("chain_arc")
	var ring_before: bool = _build.accretion.halo_visible("storm_lattice")
	run.add_part("chain_arc", "test")
	var live: bool = "storm_lattice" in _build.active_synergies() and _build.has_transformer("storm_lattice") \
		and _build.pattern_level("chain_arc") == 2
	_report("offer marks", ingredient_before == "* ingredient: ??? *" and completes == "* completes Storm Lattice *",
		"with nothing held, Chain Arc reads '%s'; holding Cross Split it reads '%s'" % [ingredient_before, completes])
	_report("storm lattice", live and not ring_before and _build.accretion.halo_visible("storm_lattice"),
		"Cross Split + Chain Arc: synergies %s, transformer storm_lattice %s, patterns %s; its ring appeared on the ball"
			% [_build.active_synergies(), _build.has_transformer("storm_lattice"), _build.patterns()])
	var armed_discovered: Array = _build.discovered()
	_fire_lattice()
	var discovered: Array = _build.discovered()
	_game.flow.retry_stage()
	var dropped: bool = _build.active_synergies().is_empty() and not _build.accretion.halo_visible("storm_lattice")
	var named: String = _build.offer_mark("chain_arc")
	run.add_part("cross_split", "test")
	run.add_part("chain_arc", "test")
	_fire_lattice()
	_report("discovery once per run", armed_discovered.is_empty() and discovered == ["storm_lattice"] and _build.discovered() == ["storm_lattice"] and dropped,
		"first activation discovered %s; after a retry dropped it (%s) and it came back, discovered is still %s"
			% [discovered, dropped, _build.discovered()])
	_report("known ingredient is named", named == "* ingredient: Storm Lattice *",
		"after the discovery, Chain Arc on an empty build reads '%s'" % named)
	_game.flow.retry_stage()


# Storm Lattice's effect resolves at a shot; the first one of an activation is the discovery.
func _fire_lattice() -> void:
	var ball: Vector3 = _game.player.ball_position()
	_game.events.shot_fired.emit("arc_caster", ball, ball + Vector3(5, 0, 0))


func _check_thermal_shock() -> void:
	var run = _game.run
	run.add_part("arc_coil", "test")
	var before: Array = _build.sheet.elements_for("slam")
	run.add_part("frost_vane", "test")
	var after: Array = _build.sheet.elements_for("slam")
	_report("thermal shock", before == ["arc"] and after == ["arc", "frost"]
			and "thermal_shock" in _build.active_synergies() and is_equal_approx(_build.field.shatter_scale, 2.0)
			and _build.accretion.halo_visible("thermal_shock"),
		"slam elements %s with Arc Coil alone, %s with Frost Vane too; shatter x%.1f; live %s"
			% [before, after, _build.field.shatter_scale, _build.active_synergies()])
