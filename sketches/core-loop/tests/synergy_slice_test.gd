extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Parts := preload("res://src/build/parts.gd")
const Synergies := preload("res://src/build/synergies.gd")
const SpawnerDouble := preload("res://tests/doubles/spine_spawner_double.gd")

# The slice table keeps ten maker tricks (the five named synergies and the five former
# three-part sets); a trick outside it is never live, offered, haloed or carded. Every trick
# with a transformer announces itself when armed and publishes cause_fired
# from the one place its effect resolves; the first firing of an activation is its
# discovery. FIRING_SITES is the table of row id to the function that emits for it, and
# each row is driven through its real trigger with the table filter off (the default table is
# the alpha ruleset since 2026-10-04): a row with no case
# here, or whose trigger never produces cause_fired, fails.

const KEPT := ["wrecking_ball", "tesla_pylon", "pinwheel", "shrapnel_bloom", "lightning_rod",
	"ballast_rig", "shatter_crew", "live_wire", "hair_trigger", "storm_front"]
# Linked Spiral logs a find on each shot instead of cause_fired (build_behaviour_test drives it).
const FIND_ONLY := ["linked_spiral"]
const FIRING_SITES := {
	"storm_lattice": "build.gd _on_shot_fired",
	"thermal_shock": "build.gd _on_element_resolved",
	"lightning_rod": "build.gd _lightning_rod",
	"tesla_pylon": "build.gd _step_synergies (tesla clock)",
	"wrecking_ball": "build.gd _synergy_hit via _step_synergies (rams)",
	"shrapnel_bloom": "build.gd _synergy_hit via _step_synergies (kills)",
	"glacier_hull": "build.gd _synergy_hit via _step_synergies (landings)",
	"pinwheel": "build.gd _synergy_hit via _step_synergies (blade ring)",
}
const NEAR := 1.0
const WAIT_FRAMES := 90
const WARMUP := 12

var _game
var _build
var _double
var _phase := "slice"
var _ticks := 0
var _failures := 0
var _queue: Array = []
var _case: Dictionary = {}
var _waited := 0
var _fired: Array = []
var _armed: Array = []
var _discovered: Array = []
var _enemies: Array = []
var _water_y := 0.0
var _pin_at := Vector3.ZERO


func _initialize() -> void:
	_start_game("slice")


func _start_game(table: String) -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = table
	root.add_child(_game)
	_ticks = 0
	_build = null


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


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
		_double = SpawnerDouble.new()
		_game.add_child(_double)
		_double.setup(_game.ctx)
		_game.ctx.spawner = _double
		_game.events.cause_fired.connect(func(id: String, body: Node3D, at: Vector3): _fired.append({"id": id, "body": body, "at": at}))
		_game.events.cause_armed.connect(func(id: String): _armed.append(id))
		_game.events.synergy_discovered.connect(func(id: String, _category: String, _first: bool): _discovered.append(id))
		return false
	if _ticks < WARMUP:
		return false
	if _ticks == WARMUP:
		if _phase == "slice":
			_slice_cuts()
			_queue = KEPT.filter(func(id): return FIRING_SITES.has(id))
		else:
			# 2026-10-04: the default table now takes the alpha ruleset (it keeps five synergies), so the
			# control for "every row fires" runs with the synergy filter off, the unfiltered rule.
			Synergies.set_table(null)  # the codex cards were declared under the alpha filter, so only the live rule is checked
			_default_cuts()
			_queue = FIRING_SITES.keys()
		return false
	return _drive()


# Two parts of the trick's maker wake it: the pair its callout names, else two class-neutral pieces.
func _hand(id: String) -> Array:
	var call := Synergies.callout(id)
	if not call.is_empty():
		return [call["a"], call["b"]]
	var out: Array = []
	for part_id in Parts.ids():
		if out.size() < 2 and Parts.maker_of(part_id) == Synergies.ROWS[id]["maker"] and Parts.def(part_id).class_id == "":
			out.append(part_id)
	return out


func _hold(parts: Array) -> void:
	_game.run.parts.clear()
	for part_id in parts:
		_game.run.parts.append(part_id)
	_build.recompute()


func _slice_cuts() -> void:
	var hand := _hand("storm_lattice")
	_hold(hand)
	var cards: Array = _game.ctx.codex.entries("build").map(func(e): return e["id"])
	_hold([hand[1]])
	var completes: String = _build.offer_mark(hand[0])
	_hold([])
	var ingredient: String = _build.offer_mark(hand[0])
	_hold(hand)
	_report("slice cuts storm_lattice", not "storm_lattice" in _build.active_synergies() and not _build.has_transformer("storm_lattice")
			and not _build.accretion.halo_visible("storm_lattice") and not "storm_lattice" in cards
			and completes != "* completes Storm Lattice *" and ingredient == "" and not "storm_lattice" in _armed,
		"holding %s is not live (%s), not carded (cards %s), offers read '%s' and '%s', armed %s" % [hand, _build.active_synergies(), cards, completes, ingredient, _armed])
	_hold(_hand("linked_spiral"))
	_report("slice drops linked spiral", not "linked_spiral" in _build.active_synergies() and not _build.has_transformer("linked_spiral"),
		"two Waking parts give tricks %s" % [_build.active_synergies()])
	var kept_cards := cards.filter(func(id): return Synergies.ROWS.has(id))
	kept_cards.sort()
	var want := KEPT.duplicate()
	want.sort()
	_report("slice codex cards", kept_cards == want, "build cards for synergies %s, want %s" % [kept_cards, want])
	_hold([])


func _default_cuts() -> void:
	var hand := _hand("storm_lattice")
	_hold(hand)
	var cards: Array = _game.ctx.codex.entries("build").map(func(e): return e["id"])
	_report("unfiltered keeps storm_lattice", "storm_lattice" in _build.active_synergies(),
		"the same parts %s with no table filter give %s and the card is there %s" % [hand, _build.active_synergies(), "storm_lattice" in cards])
	_hold([hand[1]])
	var completes: String = _build.offer_mark(hand[0])
	_hold([])
	var ingredient: String = _build.offer_mark(hand[0])
	_report("unfiltered offers storm_lattice", completes.begins_with("* completes ") and "storm_lattice" in Synergies.of_maker("redjaw") and ingredient == "",
		"with no table filter %s reads '%s' with its partner held and '%s' with nothing held" % [hand[0], completes, ingredient])
	_hold([])


func _drive() -> bool:
	if _case.is_empty():
		if _queue.is_empty():
			return _next_game()
		_begin(_queue.pop_front())
		return false
	_waited += 1
	var id: String = _case["id"]
	var hits := _fired.filter(func(f): return f["id"] == id)
	if _case.get("again", false):
		if hits.size() <= _case["before"] and _waited < WAIT_FRAMES:
			return false
		_finish(id, hits)
		return false
	if hits.is_empty() and _waited < WAIT_FRAMES:
		_hold_state(id)
		return false
	_finish(id, hits)
	return false


func _hold_state(id: String) -> void:
	if id == "pinwheel":
		_game.player.reset_to(_pin_at, Vector3(0, 0, _game.tuning.f("cruise") * 1.5))


func _begin(id: String) -> void:
	for enemy in _enemies:
		if is_instance_valid(enemy):
			enemy.free()
	_enemies.clear()
	_fired.clear()
	_game.player.kit.mounted = false
	_hold(_hand(id))
	_waited = 0
	_case = {"id": id, "found_before": _discovered.count(id), "live": id in _build.active_synergies()}
	var ball: Vector3 = _game.player.ball_position()
	match id:
		"wrecking_ball":
			var rammed := _spawn(ball + Vector3(4, 0, 0))
			_spawn(ball + Vector3(7, 0, 0))
			_game.events.enemy_struck.emit(rammed, "ram", 5.0)
		"shrapnel_bloom":
			_spawn(ball + Vector3(3, 0, 0))
			_game.run.record_kill("chaser", ball + Vector3(-2, 0, 0), 0)
		"pinwheel":
			_spawn(ball + Vector3(2, 0, 0))
			_pin_at = ball
			_hold_state(id)
		"tesla_pylon":
			_spawn(ball + Vector3(4, 0, 0))
			_game.player.kit.mounted = true
		"lightning_rod":
			_spawn(ball + Vector3(4, 0, 0))
			_build.scrap.drop(ball, 1, _game.ctx.rng)
		"glacier_hull":
			_spawn(ball + Vector3(3, 0, 0))
			_game.events.landed.emit(12.0)
		"storm_lattice":
			_game.events.shot_fired.emit("arc_caster", ball, ball + Vector3(5, 0, 0))
		"thermal_shock":
			_water_y = ball.y - 0.5
			_build.register_material("water", func(_p: Vector3) -> Dictionary: return {"surface_y": _water_y})
			_build.apply_element("frost", ball, "test")
			_game.events.slammed.emit(ball, 1.0, 1.0)


func _spawn(at: Vector3) -> Node3D:
	var enemy: Node3D = _double.spawn_enemy("chaser", at)
	_enemies.append(enemy)
	return enemy


func _finish(id: String, hits: Array) -> void:
	if _case.get("again", false) and _case.get("retry", false):
		_report("a live synergy is found again after a retry", hits.size() > _case["before"] and _discovered.count(id) == 2 and _armed.count(id) == 1 and id in _game.codex.discovered_this_run(),
			"held at the stage start, fired, retried, fired again: %d more cause_fired; synergy_discovered total %d, cause_armed total %d, in the run's codex list %s" % [hits.size() - _case["before"], _discovered.count(id), _armed.count(id), id in _game.codex.discovered_this_run()])
		_case = {}
		return
	if _case.get("again", false):
		_report("second firing is not a discovery", hits.size() > _case["before"] and _discovered.count(id) == 1 and _armed.count(id) == 1,
			"a second firing added %d cause_fired; synergy_discovered total %d, cause_armed total %d" % [hits.size() - _case["before"], _discovered.count(id), _armed.count(id)])
		if _case.get("retry", false):
			_case = {}
			return
		_case = {"id": id, "again": true, "retry": true, "before": hits.size()}
		_waited = 0
		_game.run.snapshot(_game.player.ball_position(), Vector3.ZERO, 0.0)
		_game.flow.retry_stage()
		_retrigger()
		return
	var ball: Vector3 = _game.player.ball_position()
	var first: Dictionary = hits[0] if not hits.is_empty() else {}
	var body: Node3D = first.get("body")
	var anchor: Vector3 = ball
	if body != null and is_instance_valid(body):
		anchor = body.global_position
	var near: bool = not first.is_empty() and (first["at"] as Vector3).distance_to(anchor) <= NEAR
	var no_body := id in ["storm_lattice", "thermal_shock"]
	_report("%s fires" % id, _case["live"] and not first.is_empty() and near and (body == null) == no_body,
		"live %s, cause_fired %s at %s against %s (anchor %s), site %s" % [_case["live"], not first.is_empty(), first.get("at"), body, anchor, FIRING_SITES.get(id, "NONE")])
	_report("%s armed, then discovered at its first firing" % id, _armed.count(id) == 1 and _case["found_before"] == 0 and _discovered.count(id) == 1,
		"cause_armed %d, synergy_discovered %d before the firing and %d after" % [_armed.count(id), _case["found_before"], _discovered.count(id)])
	if id == "wrecking_ball":
		_case = {"id": id, "again": true, "before": hits.size()}
		_waited = 0
		_retrigger()
		return
	_case = {}


func _retrigger() -> void:
	var ball: Vector3 = _game.player.ball_position()
	var rammed := _spawn(ball + Vector3(4, 0, 0))
	_spawn(ball + Vector3(7, 0, 0))
	_game.events.enemy_struck.emit(rammed, "ram", 5.0)


func _next_game() -> bool:
	for enemy in _enemies:
		if is_instance_valid(enemy):
			enemy.free()
	_enemies.clear()
	if _phase == "slice":
		_game.free()
		_report("a freed slice game resets the table filter", Synergies.table == null,
			"after the slice game is freed the synergy table filter is %s" % [Synergies.table])
		_phase = "default"
		_fired.clear()
		_armed.clear()
		_discovered.clear()
		_start_game("")
		return false
	var missing: Array = []
	var firing: Array = Synergies.ROWS.keys().filter(func(id): return not Synergies.told_on_wake(id) and not id in FIND_ONLY)
	for id in firing:
		if not FIRING_SITES.has(id):
			missing.append(id)
	_report("every row has an emitter", missing.is_empty() and FIRING_SITES.size() == firing.size(),
		"%d rows, %d firing sites, rows without one %s" % [Synergies.ROWS.size(), FIRING_SITES.size(), missing])
	_game.free()
	print("synergy_slice_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
	return true
