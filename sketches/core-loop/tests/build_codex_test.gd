extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")

# Build against the real codex and cores (DEMO-SPEC, CONTRACTS):
#   - the eight build hint cards are declared by the first tick of play;
#   - a named synergy's first activation publishes synergy_discovered once (through the
#     codex), with the treasure burst, and a retry does not repeat it;
#   - an element result publishes element_resolved, and its first firing publishes
#     interaction_found once (through the codex);
#   - a vault kill adds a rare part and a vault core; a won event adds an event core,
#     unless world already granted one;
#   - gate offers follow run.gate_tier_bonus().

var _game
var _build
var _failures := 0
var _ticks := 0
var _phase := 0
var _wait := 0
var _facts: Array = []
var _found_facts: Array = []
var _elements: Array = []
var _cores: Array = []
var _offers: Array = []
var _state := {}


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _water(point: Vector3) -> Dictionary:
	var centre: Vector3 = _state["water"]
	if Vector2(point.x - centre.x, point.z - centre.z).length() <= 15.0:
		return {"surface_y": centre.y + 3.0}
	return {}


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_ticks += 1
	if _ticks == 1:
		_game.ctx.calm = true
		_game.player.source = Intent.Scripted.new()
		var events = _game.events
		events.synergy_discovered.connect(func(id, cat, first): _facts.append([id, cat, first]))
		events.interaction_found.connect(func(text): _found_facts.append(text))
		events.element_resolved.connect(func(e, m, b, _at): _elements.append([e, m, b]))
		events.core_gained.connect(func(source, _at, count): _cores.append([source, count]))
		events.reward_offered.connect(func(offers): _offers = offers)
		_game.flow.press_start()
		_game.flow.choose_class(0)
		_build = _game.ctx.build
		return false
	if _ticks < 12:
		return false
	_wait += 1
	match _phase:
		0:
			_check_declared()
			_check_discovery()
			_check_elements()
			_start_cores()
			_next()
		1:
			if _wait == 30:
				_check_cores()
				_check_gate_tier()
				_next()
		2:
			print("build_codex_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
			_game.free()
			quit(0 if _failures == 0 else 1)
			return true
	return false


func _next() -> void:
	_phase += 1
	_wait = 0


func _check_declared() -> void:
	var cards: Array = _game.codex.entries("build")
	var hints: Array = cards.map(func(c): return c["hint"])
	_report("build cards declared", cards.size() == 8 and _build.codex_declarations().size() == 8 and "Chain Arc + something that splits" in hints,
		"%d build entries in the codex after the first tick of play, e.g. %s" % [cards.size(), hints.slice(0, 2)])


func _check_discovery() -> void:
	var run = _game.run
	var scrap_before: int = run.scrap
	run.add_part("cross_split", "test")
	run.add_part("chain_arc", "test")
	var burst: int = run.scrap - scrap_before
	var facts_first: Array = _facts.duplicate()
	_game.flow.retry_stage()
	run.add_part("cross_split", "test")
	run.add_part("chain_arc", "test")
	_report("synergy discovered through the codex", facts_first.size() == 1 and facts_first[0][0] == "storm_lattice"
			and facts_first[0][1] == "build" and _facts.size() == 1 and burst == 20 * run.stage and _game.codex.known("storm_lattice"),
		"Cross Split + Chain Arc published %s with a %d-scrap burst; after a retry and the same hand, %d fact(s) in total"
			% [facts_first, burst, _facts.size()])
	_game.flow.retry_stage()


func _check_elements() -> void:
	_state["water"] = _game.player.ball_position()
	_build.register_material("water", _water)
	var above: Vector3 = _game.player.ball_position() + Vector3(4.0, 3.5, 4.0)
	_build.apply_element("frost", above, "test")
	_build.apply_element("frost", above + Vector3(9.0, 0.0, 0.0), "test")
	var freezes: int = _elements.filter(func(e): return e == ["frost", "water", "create_surface"]).size()
	var found_frost: Array = _found_facts.filter(func(t): return String(t).begins_with("Frost on water"))
	_report("element_resolved and interaction_found", freezes == 2 and found_frost.size() == 1
			and _game.codex.found_category(found_frost[0]) == "build",
		"two freezes published element_resolved %d times and interaction_found %d time(s): %s"
			% [freezes, found_frost.size(), found_frost])
	_build.field.clear_providers()
	_build.field.clear()


func _start_cores() -> void:
	var run = _game.run
	_state["parts_before"] = run.parts.size()
	run.record_kill("vault", _game.player.ball_position() + Vector3(5.0, 0.0, 0.0), 0)
	_state["vault_parts"] = run.parts.size() - _state["parts_before"]
	_state["vault_cores"] = run.bonus_cores
	run.record_milestone("surge_run")
	_state["cores_at_win"] = run.bonus_cores


func _check_cores() -> void:
	var run = _game.run
	var after_solo: int = run.bonus_cores
	# World grants the event core itself, in the same moment as the win.
	run.add_core("event", _game.player.ball_position())
	run.record_milestone("hold_the_relay")
	_state["world_core"] = run.bonus_cores
	for i in 20:
		_build._step_event_cores()
	_report("vault core and part", _state["vault_parts"] == 1 and _state["vault_cores"] == 1 and _cores[0] == ["vault", 1],
		"a vault kill added %d part and bonus core %d (%s)" % [_state["vault_parts"], _state["vault_cores"], _cores[0]])
	_report("event core", _state["cores_at_win"] == 1 and after_solo == 2 and _cores.size() >= 2 and _cores[1] == ["event", 2],
		"a won event with no world grant: %d core right at the win, %d a moment later (%s)"
			% [_state["cores_at_win"], after_solo, _cores.slice(0, 2)])
	_report("no double event core", run.bonus_cores == 3 and _state["world_core"] == 3,
		"when world granted the event core itself, build added none: bonus cores %d" % run.bonus_cores)


func _check_gate_tier() -> void:
	var run = _game.run
	_game.events.flow_changed.emit("gates")
	var high: Array = _offers.map(func(o): return o["rarity"])
	_build.gates.close()
	_game.flow.retry_stage()
	_game.events.flow_changed.emit("gates")
	var low: Array = _offers.map(func(o): return o["rarity"])
	_build.gates.close()
	_report("gate tier follows cores", high.all(func(r): return r in ["rare", "rare_plus"]) and low.all(func(r): return r in ["common", "uncommon"])
			and high.size() == 2 and low.size() == 2 and run.gate_tier_bonus() == 0,
		"with 3 bonus cores the gates offered %s; after a retry to 0 cores, %s" % [high, low])
