extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Parts := preload("res://src/build/parts.gd")
const PartDef := preload("res://src/build/part_def.gd")
const Synergies := preload("res://src/build/synergies.gd")

# Named synergies are tag pairs (DEMO-SPEC "Synergies"). Checks: there are about
# eight, every one is a pair of known tags whose shown ingredient carries the first
# tag, every one changes behaviour rather than a number, and each goes live exactly
# when its shown part is held with another part carrying its second tag; a different
# part with the first tag does not stand in for the shown one. The codex hint cards name one
# ingredient and clue the other. The first activation in a run is a discovery, and a
# retry does not repeat it. Offers carry "* completes X *" and "* ingredient: ??? *",
# which names the synergy once it is discovered. Every live synergy puts a ring on
# the ball.

var _game
var _build
var _failures := 0
var _ticks := 0


func _initialize() -> void:
	_game = Game.new()
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


func _check_cards() -> void:
	var cards: Array = _build.codex_declarations()
	var bad: Array = []
	for card in cards:
		for field in ["id", "category", "name", "hint", "clue", "text"]:
			if String(card.get(field, "")) == "":
				bad.append("%s missing %s" % [card.get("id", "?"), field])
		if card["category"] != "build" or not String(card["hint"]).begins_with(Parts.display_name(card["shown"])) \
				or not String(card["hint"]).ends_with(card["clue"]):
			bad.append("%s hint '%s'" % [card["id"], card["hint"]])
	var storm: Dictionary = cards.filter(func(c): return c["id"] == "storm_lattice")[0]
	_report("codex hint cards", bad.is_empty() and cards.size() == Synergies.ROWS.size(),
		"%d build cards, each with category, name, hint, clue and text; e.g. '%s'; problems %s" % [cards.size(), storm["hint"], bad])


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
	var discovered: Array = _build.discovered()
	_game.flow.retry_stage()
	var dropped: bool = _build.active_synergies().is_empty() and not _build.accretion.halo_visible("storm_lattice")
	var named: String = _build.offer_mark("chain_arc")
	run.add_part("cross_split", "test")
	run.add_part("chain_arc", "test")
	_report("discovery once per run", discovered == ["storm_lattice"] and _build.discovered() == ["storm_lattice"] and dropped,
		"first activation discovered %s; after a retry dropped it (%s) and it came back, discovered is still %s"
			% [discovered, dropped, _build.discovered()])
	_report("known ingredient is named", named == "* ingredient: Storm Lattice *",
		"after the discovery, Chain Arc on an empty build reads '%s'" % named)
	_game.flow.retry_stage()


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
