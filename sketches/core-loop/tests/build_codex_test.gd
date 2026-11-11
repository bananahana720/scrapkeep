extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Synergies := preload("res://src/build/synergies.gd")

# Build against the real codex and cores (DEMO-SPEC, CONTRACTS):
#   - one build card per maker trick and the four callback cards are declared by the first
#     tick of play;
#   - a maker trick's first firing publishes synergy_discovered once (through the
#     codex), with the treasure burst; activating it publishes nothing, and a retry that
#     takes it back lets the next firing publish again;
#   - an element result publishes element_resolved, and its first firing publishes
#     interaction_found once (through the codex);
#   - a vault kill adds a rare part and a vault core; a won event adds its milestone
#     part here and exactly one event core, which world grants;
#   - gate offers follow run.gate_tier_bonus().

# 2026-10-04: the default table is the alpha ruleset (twelve parts, five synergies, class pick on); this test checks the full catalogue so it runs on the legacy FirstWorld table.
class LegacyGame extends "res://src/game.gd":
	func _chosen_table():
		return preload("res://tests/doubles/two_world_defs.gd").FirstWorld

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
	_game = LegacyGame.new()
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
				_second_win()
				_next()
		2:
			if _wait == 30:
				_check_cores()
				_check_gate_tier()
				_next()
		3:
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
	# One card per maker trick and v2 W4's four callback cards (Strike, Spare, Turkey, Too heavy for you).
	var want := Synergies.ROWS.keys().filter(func(id): return Synergies.in_play(id)).size() + 4
	var lattice: Array = cards.filter(func(c): return c["id"] == "storm_lattice")
	_report("build cards declared", cards.size() == want and _build.codex_declarations().size() == want
			and not lattice.is_empty() and String(lattice[0]["hint"]).begins_with("Two ") and String(lattice[0]["hint"]).ends_with(" parts"),
		"%d build entries in the codex after the first tick of play (want %d), e.g. %s" % [cards.size(), want, hints.slice(0, 2)])


# Storm Lattice's effect resolves at a shot; the first one of an activation is the discovery.
func _fire_lattice() -> void:
	var ball: Vector3 = _game.player.ball_position()
	_game.events.shot_fired.emit("arc_caster", ball, ball + Vector3(5, 0, 0))


func _check_discovery() -> void:
	var run = _game.run
	var scrap_before: int = run.scrap
	run.add_part("cross_split", "test")
	run.add_part("hairline_fracture", "test")
	var facts_armed: Array = _facts.duplicate()
	_fire_lattice()
	var burst: int = run.scrap - scrap_before
	var facts_first: Array = _facts.duplicate()
	_game.flow.retry_stage()
	var scrap_retry: int = run.scrap
	run.add_part("cross_split", "test")
	run.add_part("hairline_fracture", "test")
	_fire_lattice()
	var burst_again: int = run.scrap - scrap_retry
	# The retry took the synergy back with its burst, so the codex lets it fire and pay
	# again, and the run log keeps it (CONTRACTS, Codex).
	_report("synergy discovered through the codex", facts_armed.is_empty() and facts_first.size() == 1 and facts_first[0][0] == "storm_lattice"
			and facts_first[0][1] == "build" and burst == 20 * run.stage and _game.codex.known("storm_lattice")
			and _facts.size() == 2 and burst_again == burst and "storm_lattice" in _game.codex.discovered_this_run(),
		"Cross Split + Hairline Fracture (two Redjaw parts) published %s with a %d-scrap burst; after a retry and the same hand, %d fact(s) in total, a %d-scrap burst again, in the run's codex list %s"
			% [facts_first, burst, _facts.size(), burst_again, "storm_lattice" in _game.codex.discovered_this_run()])
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
	_state["won_before"] = run.events_won.size()
	_state["first_parts"] = run.parts.size()
	_win_through_world("surge_run")
	_state["cores_at_win"] = run.bonus_cores
	_state["first_part"] = run.parts.size() - _state["first_parts"]


# A won event through world's own publication, the path a live event takes: world
# records the milestone and grants the event's core at its ring in the same call.
func _win_through_world(event_id: String) -> void:
	var ball: Vector3 = _game.player.ball_position()
	_game.get_node("World")._publish([{"kind": "milestone", "id": event_id, "at": Vector2(ball.x, ball.z)}])


# 30 ticks is well past the 0.1 s build once waited before granting a second core.
func _second_win() -> void:
	_state["cores_before_second"] = _game.run.bonus_cores
	_win_through_world("hold_the_relay")
	_state["cores_at_second"] = _game.run.bonus_cores


func _check_cores() -> void:
	var run = _game.run
	var event_cores: Array = _cores.filter(func(c): return c[0] == "event")
	var wins: int = run.events_won.size() - _state["won_before"]
	_report("vault core and part", _state["vault_parts"] == 1 and _state["vault_cores"] == 1 and _cores[0] == ["vault", 1],
		"a vault kill added %d part and bonus core %d (%s)" % [_state["vault_parts"], _state["vault_cores"], _cores[0]])
	_report("event core from world", _state["cores_at_win"] == 2 and _state["first_part"] == 1 and _cores.size() >= 2 and _cores[1] == ["event", 2],
		"a won event: bonus core %d right at the win from world's grant %s, and build added %d milestone part"
			% [_state["cores_at_win"], _cores.slice(1, 2), _state["first_part"]])
	_report("one core per event win", wins == 2 and event_cores.size() == 2 and _state["cores_before_second"] == 2
			and _state["cores_at_second"] == 3 and run.bonus_cores == 3,
		"%d wins published %d event cores; bonus cores %d 30 ticks after the first win, %d at the second, %d 30 ticks later"
			% [wins, event_cores.size(), _state["cores_before_second"], _state["cores_at_second"], run.bonus_cores])


func _check_gate_tier() -> void:
	var run = _game.run
	_game.events.flow_changed.emit("gates")
	# A racked active the gate stream also rolls rides its own rarity; the cores move the part picks.
	var high: Array = _offers.filter(func(o): return not String(o["part_id"]).begins_with("active:")).map(func(o): return o["rarity"])
	_build.gates.close()
	_game.flow.retry_stage()
	_game.events.flow_changed.emit("gates")
	var low: Array = _offers.filter(func(o): return not String(o["part_id"]).begins_with("active:")).map(func(o): return o["rarity"])
	_build.gates.close()
	# The cobalt floor (item ladder, wave 20) lifts one gate of a 0-core pair to rare; the other stays common.
	_report("gate tier follows cores", high.all(func(r): return r in ["rare", "relic"])
			and low.count("common") == 1 and low.count("rare") == 1
			and high.size() == 2 and low.size() == 2 and run.gate_tier_bonus() == 0,
		"with 3 bonus cores the gates offered %s; after a retry to 0 cores, %s" % [high, low])
