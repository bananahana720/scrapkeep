extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Codex := preload("res://src/core/codex.gd")

# The codex registry: idempotent declares, one discovery fact and one treasure burst
# per entry per run, the Found list, the developer log sharing the run_id, saving
# across instances, and no throw when storage is unwritable.

var _game
var _failures := 0
var _started := false
var _facts: Array = []
var _found_facts := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _physics_process(_delta: float) -> bool:
	if _game.flow == null or _started:
		return false
	_started = true
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	_game.events.synergy_discovered.connect(func(id, cat, first): _facts.append([id, cat, first]))
	_game.events.interaction_found.connect(func(_t): _found_facts += 1)
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_checks()
	print("spine_codex_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return false


func _checks() -> void:
	var codex = _game.codex
	var run = _game.run
	# Modules declare their own entries at setup, so every size check here is a delta.
	var base_all: int = codex.entries().size()
	var base_build: int = codex.entries("build").size()
	var base_world: int = codex.entries("world").size()
	var base_enemy: int = codex.entries("enemy").size()
	codex.declare({"id": "storm_lattice", "category": "build", "name": "Storm Lattice", "hint": "Chain Arc", "clue": "+ something that splits", "text": "Split bolts chain between targets."})
	codex.declare({"id": "storm_lattice", "category": "build", "name": "Storm Lattice", "hint": "Chain Arc", "clue": "+ something that splits", "text": "Split bolts chain between targets."})
	codex.declare({"id": "flood_zap", "category": "world", "name": "Live Wire", "hint": "Flood water", "clue": "+ an arc", "text": "Arc on flood water electrifies it."})
	codex.declare({"id": "test_enemy_trick", "category": "enemy", "name": "Test enemy trick"})
	codex.declare({"id": "mystery", "category": "dance"})
	var added := [codex.entries().size() - base_all, codex.entries("build").size() - base_build,
		codex.entries("world").size() - base_world, codex.entries("enemy").size() - base_enemy]
	_report("declare", added == [3, 1, 1, 1] and _game.ctx.codex == codex and not codex.entries().any(func(e): return e["id"] == "mystery"),
		"declaring storm_lattice twice, flood_zap, test_enemy_trick and an unknown category added %s (all, build, world, enemy)" % [added])

	var scrap_before: int = run.scrap
	var spot := Vector3(3.0, 20.0, 4.0)
	var first: bool = codex.mark_discovered("storm_lattice", spot)
	var again: bool = codex.mark_discovered("storm_lattice", spot)
	_report("discovery", first and not again and _facts.size() == 1 and _facts[0] == ["storm_lattice", "build", true]
			and run.scrap - scrap_before == 20 * run.stage and codex.known("storm_lattice"),
		"first call %s, repeat %s, %d fact(s) %s, burst gave %d scrap on stage %d"
			% [first, again, _facts.size(), _facts, run.scrap - scrap_before, run.stage])
	var lattice: Array = codex.entries("build").filter(func(e): return e["id"] == "storm_lattice")
	_report("completion", codex.completion("build") > 0.0 and lattice.size() == 1 and lattice[0]["known"] and not codex.entries("world").filter(func(e): return e["id"] == "flood_zap")[0]["known"],
		"build %.0f%%, world %.0f%%, storm_lattice known" % [codex.completion("build") * 100.0, codex.completion("world") * 100.0])

	var notes = _game.notes
	var cards: int = notes.render_page("build")
	var world_cards: int = notes.render_page("world")
	notes.show_page(1)
	var tabs: String = notes._title.text
	_report("codex page", notes.pages() == ["notes", "build", "world", "enemy", "found"] and cards == base_build + 1 and world_cards == base_world + 1
			and tabs.contains("[ Build %d%% ]" % int(codex.completion("build") * 100.0)),
		"pages %s; build shows %d card, world %d; tab row \"%s\"" % [notes.pages(), cards, world_cards, tabs.get_slice("  ·  ", 1)])

	var new_text: bool = codex.mark_found("frost then a ram shatters", "enemy")
	var old_text: bool = codex.mark_found("frost then a ram shatters", "enemy")
	_report("found", new_text and not old_text and _found_facts == 1 and codex.found() == ["frost then a ram shatters"] and codex.found_category("frost then a ram shatters") == "enemy",
		"found list %s, interaction_found fired %d time(s)" % [codex.found(), _found_facts])

	var log_path: String = _game.storage_dir.path_join(Codex.LOG_FILE)
	var lines := FileAccess.get_file_as_string(log_path).strip_edges().split("\n")
	var parsed = JSON.parse_string(lines[0]) if lines.size() > 0 else null
	_report("developer log", lines.size() == 2 and parsed is Dictionary and parsed["run_id"] == run.run_id and parsed["id"] == "storm_lattice"
			and parsed["category"] == "build" and parsed["participants"] == ["player"] and parsed.has("stage_ticks") and parsed.has("heft") and parsed.has("parts"),
		"%d line(s); first %s" % [lines.size(), lines[0] if lines.size() > 0 else "none"])

	var reload := Codex.new()
	root.add_child(reload)
	reload.setup(_game.events, run, null, _game.storage_dir)
	_report("saved", reload.known("storm_lattice") and reload.found() == ["frost then a ram shatters"],
		"a fresh codex on the same folder knows %s and found %s" % [reload.discovered(), reload.found()])
	reload.free()

	var burst_scrap: int = run.scrap
	_game.flow.retry_stage()
	var rewound: int = run.scrap
	_facts.clear()
	codex.mark_discovered("storm_lattice", spot)
	_report("retry rewinds", rewound < burst_scrap and _facts.size() == 1 and run.scrap - rewound == 20 * run.stage,
		"a retry took the scrap back to %d (from %d) and the rediscovery fired again (%d fact) with a %d scrap burst"
			% [rewound, burst_scrap, _facts.size(), run.scrap - rewound])

	_game.flow.new_run()
	_facts.clear()
	var scrap_new: int = run.scrap
	var third: bool = codex.mark_discovered("storm_lattice", spot)
	_report("next run", not third and _facts.size() == 1 and _facts[0][2] == false and run.scrap - scrap_new == 20,
		"a new run rediscovers it: first_time %s, %d fact(s), burst %d scrap" % [third, _facts.size(), run.scrap - scrap_new])

	var broken := Codex.new()
	root.add_child(broken)
	broken.setup(_game.events, run, null, "user://no/such/folder/deep")
	broken.declare({"id": "x", "category": "world"})
	var ok_call: bool = broken.mark_discovered("x")
	_report("unwritable storage", ok_call and broken.known("x") and broken.last_error != "",
		"writes to a missing folder kept the codex working in memory; last_error \"%s\"" % broken.last_error.left(60))
	broken.free()
