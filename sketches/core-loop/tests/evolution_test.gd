extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Parts := preload("res://src/build/parts.gd")
const ItemGen := preload("res://src/build/item_gen.gd")
const Synergies := preload("res://src/build/synergies.gd")

# Seven evolutions: part pairs (Synergies.EVOLUTIONS) that become an Evolved part, the top rung
# of the ladder. Since the systems audit fold (11 Nov 2026) an evolution is its own rule, apart
# from the maker tricks. Holding one ingredient does nothing; holding both gains the Evolved part
# once, announced as part_gained with source "evolution" at rarity evolved; the Evolved effect is
# measurable; the part list holds it, so a restore keeps it; a missing ingredient puts it
# dormant; and no pool or roll ever offers an Evolved part.

const CASES := [
	{"into": "breaker_drive", "parts": ["double_feed", "hot_rivets"]},
	{"into": "bladestorm_rotor", "parts": ["spiral_wave", "loose_trigger"]},
	{"into": "storm_mast", "parts": ["focus_lens", "live_line"]},
	{"into": "grounding_spike", "parts": ["arc_coil", "drop_weight"]},
	{"into": "grapeshot_press", "parts": ["cross_split", "pin_setter"]},
	{"into": "hoar_barrel", "parts": ["frost_barb", "rime_rounds"]},
	{"into": "fault_hammer", "parts": ["echo_locator", "brace_frame"]},
]

var _game
var _build
var _failures := 0
var _ticks := 0
var _gained: Array = []


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
		_game.events.part_gained.connect(func(part_id: String, source: String): _gained.append([part_id, source]))
		return false
	if _ticks < 12:
		return false
	_check_table()
	for c in CASES:
		_check_case(c)
	_check_never_rolls()
	print("evolution_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _check_table() -> void:
	var ids: Array = Synergies.EVOLUTIONS.keys()
	var kept := ids.size() == CASES.size()
	var rows_ok := true
	for c in CASES:
		var d: Resource = Parts.def(c["into"])
		rows_ok = rows_ok and d != null and d.rarity == "evolved" and ItemGen.RARITY["evolved"]["weight"] == 0.0 \
			and not d.percentage_only() and Synergies.EVOLUTIONS.get(c["into"], []) == c["parts"] \
			and Parts.has(c["into"]) and not c["into"] in Parts.ids()
	_report("table", kept and rows_ok, "evolutions %s, each from its pair, rows rarity evolved, weight 0, outside ids(); ok %s" % [ids, rows_ok])


func _fresh() -> void:
	var run = _game.run
	run.parts.clear()
	_build.recompute()
	_gained.clear()


func _evolved_gains(into: String) -> Array:
	return _gained.filter(func(g): return g[0] == into)


func _check_case(c: Dictionary) -> void:
	var run = _game.run
	var into: String = c["into"]
	_fresh()
	run.add_part(c["parts"][0], "test")
	_report(into + " one ingredient", not into in run.parts and _evolved_gains(into).is_empty(),
		"holding %s alone: parts %s" % [c["parts"][0], run.parts])
	var before: float = _build.weapon_mod("weapon_damage") * _build.weapon_mod("weapon_rate") + float(_build.pattern_level("spiral_wave"))
	var punch_before: float = _build.punch_bonus()
	run.add_part(c["parts"][1], "test")
	var gains := _evolved_gains(into)
	var d: Resource = Parts.def(into)
	_report(into + " gained once", run.parts.count(into) == 1 and gains.size() == 1 and gains[0][1] == "evolution" and d.rarity == "evolved",
		"gains %s, held %d, rarity %s" % [gains, run.parts.count(into), d.rarity])
	var after: float = _build.weapon_mod("weapon_damage") * _build.weapon_mod("weapon_rate") + float(_build.pattern_level("spiral_wave"))
	_report(into + " effect measurable", after > before + 0.1 or _build.punch_bonus() > punch_before + 1.0,
		"knob product plus spiral level %.3f to %.3f, punch %.1f to %.1f" % [before, after, punch_before, _build.punch_bonus()])
	run.add_part("rivet_plating", "test")
	_report(into + " not granted twice", run.parts.count(into) == 1 and _evolved_gains(into).size() == 1, "after another part, held %d" % run.parts.count(into))
	# A restore puts the part list back, and the sheet derived from it with the evolved state.
	run.snapshot(Vector3.ZERO, Vector3.ZERO, 0.0)
	var sheet_before: Dictionary = {"mods": _build.sheet.mods.duplicate(), "patterns": _build.sheet.patterns.duplicate(), "punch": _build.sheet.punch}
	run.add_part("magnet_spool", "test")
	run.restore()
	_build.recompute()
	var sheet_after: Dictionary = {"mods": _build.sheet.mods, "patterns": _build.sheet.patterns, "punch": _build.sheet.punch}
	_report(into + " retry keeps it", run.parts.count(into) == 1 and sheet_before == sheet_after and _evolved_gains(into).size() == 1,
		"after restore and recompute held %d, sheet equal %s, still one evolution gain" % [run.parts.count(into), sheet_before == sheet_after])
	# Rule: an Evolved part stays in the list but is dormant while an ingredient is missing;
	# regaining the ingredient wakes it without a second grant.
	run.parts.erase(c["parts"][1])
	_build.recompute()
	var dormant: bool = _build.sheet.punch < sheet_before["punch"] + 0.01 and into in run.parts
	var dormant_knobs: float = _build.weapon_mod("weapon_damage") * _build.weapon_mod("weapon_rate") + float(_build.pattern_level("spiral_wave"))
	var dormant_effect_lower: bool = dormant_knobs < after - 0.01 or _build.punch_bonus() < punch_before + 1.0
	run.add_part(c["parts"][1], "test")
	_report(into + " dropped ingredient", dormant and dormant_effect_lower and run.parts.count(into) == 1,
		"dormant %s (effect lower %s); regained: held %d" % [dormant, dormant_effect_lower, run.parts.count(into)])


func _check_never_rolls() -> void:
	var lists: Array = [["common"], ["rare"], ["relic"], ["evolved"], ["evolution"], ItemGen.RARITIES, Parts.gate_rarities(0), Parts.gate_rarities(1), Parts.gate_rarities(2)]
	var evolved_ids: Array = CASES.map(func(c): return c["into"])
	var leaked: Array = []
	var draws := 0
	var saved = Synergies.table
	for table in [saved, null]:
		Synergies.table = table
		for rarities in lists:
			for cls in ["sable", "rivet", "kest"]:
				for id in Parts.offer_pool(cls, rarities):
					if id in evolved_ids:
						leaked.append("pool %s" % id)
				for seed in 40:
					var rng := RandomNumberGenerator.new()
					rng.seed = seed * 7919 + 13
					var held: Array = ["double_feed", "hot_rivets", "spiral_wave", "loose_trigger", "focus_lens", "live_line", "arc_coil", "drop_weight", "cross_split", "pin_setter", "frost_barb", "rime_rounds", "echo_locator", "brace_frame"] if seed % 2 == 0 else []
					for id in Parts.roll(rng, rarities, cls, held, 3):
						draws += 1
						if id in evolved_ids:
							leaked.append("roll %s" % id)
					for stage in [1, 2, 3]:
						for id in Parts.roll_gate(rng, rarities, cls, held, 2, stage):
							draws += 1
							if id in evolved_ids:
								leaked.append("gate %s" % id)
	Synergies.table = saved
	_report("evolved never rolls", leaked.is_empty() and draws > 1000, "%d draws over %d rarity lists, both tables, three classes; leaked %s" % [draws, lists.size(), leaked.slice(0, 5)])
