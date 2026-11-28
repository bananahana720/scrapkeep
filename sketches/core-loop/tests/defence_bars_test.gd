extends SceneTree
# SG7 (W13-INTEGRATION-3.md, comps/gunfire/enemies-and-bosses.md "three-defence-bars"): armour,
# shield and health are three bar classes with one rule each, so a bar's look predicts how to
# attack it. Every check reads tests/support/defence_bars.gd; no table is copied here.

const DefenceBars := preload("res://tests/support/defence_bars.gd")
const Palette := preload("res://src/core/palette.gd")
const T := preload("res://tests/support/t.gd")

# The colour law's floor between two meaning colours (LEGIBILITY section 1).
const MIN_GAP := 35.0

# The colour law's meaning rows (LEGIBILITY section 1), read from palette.gd. A class may wear a
# meaning colour only on the row the table assigns it: a shield says "not yet", which is SLATE.
const EventKinds := preload("res://src/core/event_kinds.gd")
const MEANING_ROWS := ["HAZARD", "live", "AMBER", "SLATE", "RUST"]
const ASSIGNED_MEANING := {"shield": "SLATE"}

var _t := T.new("defence_bars_test")


func _initialize() -> void:
	_run()
	quit(_t.verdict())


func _run() -> void:
	_classes()
	_rules()
	_states()
	_colours()
	_blind_read()


func _classes() -> void:
	_t.eq("three classes, in order", DefenceBars.CLASS_IDS, ["armour", "shield", "health"])
	for id in DefenceBars.CLASS_IDS:
		var row: Dictionary = DefenceBars.CLASSES.get(id, {})
		for field in DefenceBars.CLASS_FIELDS:
			_t.check(id + " has field " + field, row.has(field), "row keys %s" % [row.keys()])
		_t.check(id + " has no stray field", row.size() == DefenceBars.CLASS_FIELDS.size(), "%d fields" % row.size())


func _rules() -> void:
	# Armour breaks at zero and does not regenerate.
	var armour := DefenceBars.Pool.new("armour", 40.0)
	armour.hit(40.0)
	_t.check("armour breaks at zero", armour.value == 0.0 and armour.broken, "value %.1f broken %s" % [armour.value, armour.broken])
	armour.tick(600.0)
	_t.check("armour never regenerates", armour.value == 0.0 and armour.broken, "value %.1f after 600 s" % armour.value)
	var chipped := DefenceBars.Pool.new("armour", 40.0)
	chipped.hit(10.0)
	chipped.tick(600.0)
	_t.near("chipped armour keeps its loss", chipped.value, 30.0)
	_t.check("chipped armour is not broken", not chipped.broken, "broken %s" % chipped.broken)

	# Shield regenerates after a declared delay, and any hit restarts the delay.
	var delay: float = DefenceBars.SHIELD_REGEN_DELAY
	var shield := DefenceBars.Pool.new("shield", 100.0)
	shield.hit(60.0)
	shield.tick(delay - 0.01)
	_t.near("shield holds inside the delay", shield.value, 40.0)
	shield.tick(0.02)
	_t.check("shield starts regenerating after the delay", shield.value > 40.0, "value %.2f" % shield.value)
	shield.tick(60.0)
	_t.near("shield regenerates to full and stops", shield.value, 100.0)
	var shield2 := DefenceBars.Pool.new("shield", 100.0)
	shield2.hit(50.0)
	shield2.tick(delay - 0.5)
	shield2.hit(10.0)
	shield2.tick(delay - 0.5)
	_t.near("a new hit restarts the shield delay", shield2.value, 40.0)
	var shield3 := DefenceBars.Pool.new("shield", 100.0)
	shield3.hit(100.0)
	_t.check("shield at zero is down, not broken for good", shield3.value == 0.0 and not shield3.broken, "value %.1f broken %s" % [shield3.value, shield3.broken])
	shield3.tick(delay + 600.0)
	_t.near("a downed shield comes back", shield3.value, 100.0)

	# Health is health: no regeneration, no break state.
	var health := DefenceBars.Pool.new("health", 80.0)
	health.hit(30.0)
	health.tick(600.0)
	_t.near("health does not regenerate", health.value, 50.0)
	_t.check("health has no broken state", not health.broken, "broken %s" % health.broken)
	health.hit(500.0)
	_t.check("health floors at zero", health.value == 0.0, "value %.1f" % health.value)

	# One regen rule per class, and the class table names it.
	var rules := {}
	for id in DefenceBars.CLASS_IDS:
		rules[DefenceBars.CLASSES[id]["regen"]] = id
	_t.eq("armour rule", DefenceBars.CLASSES["armour"]["regen"], "none")
	_t.eq("shield rule", DefenceBars.CLASSES["shield"]["regen"], "after_delay")
	_t.eq("health rule", DefenceBars.CLASSES["health"]["regen"], "none")
	_t.check("armour and health differ by the break rule", DefenceBars.CLASSES["armour"]["breaks"] and not DefenceBars.CLASSES["health"]["breaks"], "armour breaks, health does not")
	_t.check("the shield delay is positive and finite", delay > 0.0 and is_finite(delay), "delay %s" % delay)


func _states() -> void:
	_t.check("defence states exist", DefenceBars.STATES.size() >= 3, "%d states" % DefenceBars.STATES.size())
	var used := {}
	for state in DefenceBars.STATES:
		var id: String = DefenceBars.STATES[state]
		_t.check("state " + state + " maps to one known class", DefenceBars.CLASS_IDS.has(id), "class '%s'" % id)
		_t.eq("bar_class(" + state + ")", DefenceBars.bar_class(state), id)
		used[id] = true
	_t.eq("every class has a state", used.size(), DefenceBars.CLASS_IDS.size())
	_t.eq("an unknown state has no class", DefenceBars.bar_class("no_such_state"), "")


func _colours() -> void:
	var palette_rows := {}
	for name in ["SAND", "SANDSTONE", "RUST", "COPPER", "CHARCOAL", "VERDIGRIS", "AMBER", "ARC", "ANCIENT", "CABLE", "HAZARD", "BRASS", "LEDGER", "SLATE"]:
		palette_rows[name] = Palette.new().get_script().get_script_constant_map()[name]
	var seen := {}
	var patterns := {}
	for id in DefenceBars.CLASS_IDS:
		var row: Dictionary = DefenceBars.CLASSES[id]
		var row_name: String = row["palette"]
		_t.check(id + " names an existing palette row", palette_rows.has(row_name), "row '%s'" % row_name)
		var colour: Color = DefenceBars.colour_of(id)
		_t.check(id + " colour is that palette row", palette_rows.has(row_name) and colour == palette_rows[row_name], colour.to_html(false))
		var assigned: String = ASSIGNED_MEANING.get(id, "")
		for meaning in MEANING_ROWS:
			if meaning == assigned:
				continue
			var meaning_colour: Color = Palette.live() if meaning == "live" else palette_rows[meaning]
			_t.check(id + " does not borrow the colour-law row " + meaning, colour != meaning_colour, "%s wears %s" % [id, row_name])
		if assigned != "":
			_t.check(id + " wears its assigned colour-law row " + assigned, colour == palette_rows[assigned], "%s wears %s" % [id, row_name])
		var weak_point: Color = EventKinds.ROWS["weak_point_opened"]["color"]
		_t.check(id + " is not the weak_point_opened colour", colour != weak_point, "%s wears %s" % [id, row_name])
		_t.check("no second class uses " + row_name, not seen.has(row_name), "seen %s" % [seen.keys()])
		seen[row_name] = true
		patterns[row["pattern"]] = true
	_t.eq("each class has its own pattern cue", patterns.size(), DefenceBars.CLASS_IDS.size())
	for i in DefenceBars.CLASS_IDS.size():
		for j in range(i + 1, DefenceBars.CLASS_IDS.size()):
			var a: String = DefenceBars.CLASS_IDS[i]
			var b: String = DefenceBars.CLASS_IDS[j]
			var gap := DefenceBars.cie76(DefenceBars.colour_of(a), DefenceBars.colour_of(b))
			print("defence_bars_test: gap %s/%s = %.1f CIE76" % [a, b, gap])
			_t.check("%s and %s are %.0f apart or more" % [a, b, MIN_GAP], gap >= MIN_GAP, "%.1f" % gap)


func _blind_read() -> void:
	# Modeled colour read at the 150 m haze start value (DefenceBars.HAZE_MIX). No rendered frame
	# is read here; the rendered 150 m still belongs to the SG-LOOK legibility unit.
	var frame := DefenceBars.fixture_frame()
	_t.check("the fixture frame holds two bars of each class", frame.size() >= DefenceBars.CLASS_IDS.size() * 2, "%d bars" % frame.size())
	var covered := {}
	var wrong := 0
	for bar in frame:
		covered[bar["class"]] = true
		var named := DefenceBars.blind_read(bar["seen"])
		if named != bar["class"]:
			wrong += 1
			print("defence_bars_test: bar %s seen %s read as '%s'" % [bar["class"], bar["seen"].to_html(false), named])
	_t.eq("the fixture covers every class", covered.size(), DefenceBars.CLASS_IDS.size())
	_t.eq("the modeled colour read at the haze start value names every bar's class", wrong, 0)
	# Control: a colour that belongs to no class is not named (the read can fail).
	_t.eq("a hazard-coloured bar names no class", DefenceBars.blind_read(Palette.HAZARD), "")
