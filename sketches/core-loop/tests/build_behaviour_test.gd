extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Synergies := preload("res://src/build/synergies.gd")

# Every maker trick (two parts of one maker) that build runs does something you can count, live, through the
# real bus and spawner: Shrapnel Bloom, Wrecking Ball, Lightning Rod, Tesla Pylon,
# Pinwheel and Glacier Hull each land strikes on nearby enemies. Shrapnel stays under
# its per-second cap however many kills arrive at once. Accidental interactions are
# found once, with a plain description: a slam on your own ice shatters it (frost then
# kinetic), and a spiral carrying chain links its arcs on the first shot. Storm
# Lattice is combat's to draw; Thermal Shock is covered by build_synergy_test.

# 2026-10-04: the default table is the alpha ruleset (twelve parts, five synergies, class pick on); this test checks the full catalogue so it runs on the legacy FirstWorld table.
class LegacyGame extends "res://src/game.gd":
	func _chosen_table():
		return preload("res://tests/doubles/two_world_defs.gd").FirstWorld

var _game
var _build
var _source := Intent.Scripted.new()
var _failures := 0
var _ticks := 0
var _step := -1
var _wait := 0
var _struck := {}
var _scenarios: Array = []
var _surface := 0.0
var _water_centre := Vector3.ZERO
var _gap := 0.0


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
		_game.player.source = _source
		_game.flow.press_start()
		_game.flow.choose_class(0)
		_build = _game.ctx.get_meta("build")
		_game.events.enemy_struck.connect(func(_e: Node3D, kind: String, _f: float): _struck[kind] = _struck.get(kind, 0) + 1)
		_scenarios = [
			["shrapnel bloom", ["cross_split", "pin_setter"], _set_shrapnel, 3, _check_shrapnel],
			["shrapnel cap", ["cross_split", "pin_setter"], _set_shrapnel_flood, 2, _check_shrapnel_cap],
			["wrecking ball", ["double_feed", "hot_rivets"], _set_wreck, 3, _check_wreck],
			["lightning rod", ["arc_coil", "drop_weight"], _set_rod, 6, _check_rod],
			["tesla pylon", ["focus_lens", "live_line"], _set_tesla, 50, _check_tesla],
			["pinwheel", ["loose_trigger", "long_barrel"], _set_pinwheel, 12, _check_pinwheel],
			["glacier hull", ["slag_rounds", "rivet_plating"], _set_glacier, 3, _check_glacier],
			["frost then kinetic", [], _set_kinetic, 3, _check_kinetic],
			["linked spiral", ["spiral_wave", "echo_locator"], _set_spiral, 2, _check_spiral],
		]
		return false
	if _ticks < 12:
		return false
	if _step < 0 or _wait >= _scenarios[_step][3]:
		if _step >= 0:
			_scenarios[_step][4].call()
		_step += 1
		if _step >= _scenarios.size():
			return _finish()
		_begin(_scenarios[_step])
		return false
	_wait += 1
	if _scenarios[_step][0] == "pinwheel":
		_game.player.set_velocity_now(Vector3(0.0, _game.player.state.velocity.y, 30.0))
	return false


# Back to a clean stage start, a quiet ball on the flat top shelf, and a fresh hand.
func _begin(scenario: Array) -> void:
	_game.player.release_grapple()
	_game.flow.retry_stage()
	_source.hold = {}
	var at: Vector3 = _game.ctx.terrain.drop_point(-62.0, -80.0, 1.05)
	_game.player.reset_to(at)
	_game.player.body().global_position = at
	for part_id in scenario[1]:
		_game.run.add_part(part_id, "test")
	_struck.clear()
	_wait = 0
	scenario[2].call()


func _ball() -> Vector3:
	return _game.player.ball_position()


func _spawn(offset: Vector3) -> Node3D:
	var spot: Vector3 = _ball() + offset
	return _game.ctx.spawner.spawn_enemy("chaser", _game.ctx.terrain.drop_point(spot.x, spot.z, 2.4))


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _set_shrapnel() -> void:
	var a := _spawn(Vector3(20.0, 0.0, 0.0))
	var b := _spawn(Vector3(21.5, 0.0, 0.0))
	var at: Vector3 = (a.global_position + b.global_position) * 0.5
	_gap = a.global_position.distance_to(b.global_position)
	_game.run.record_kill("chaser", at, 0)


func _check_shrapnel() -> void:
	_report("shrapnel bloom", _build.has_transformer("shrapnel_bloom") and _synergy_hits() >= 2,
		"Cross Split + Pin Setter (Redjaw): one kill between two enemies %.1f m apart burst into shrapnel that struck %d of them"
			% [_gap, _synergy_hits()])


func _set_shrapnel_flood() -> void:
	for i in 4:
		_spawn(Vector3(20.0 + 2.0 * i, 0.0, 4.0))
	var at: Vector3 = _ball() + Vector3(23.0, 0.0, 4.0)
	for i in 20:
		_game.run.record_kill("chaser", at, 0)


func _check_shrapnel_cap() -> void:
	var cap: int = int(_build.SHRAPNEL_PER_SECOND) * _build.SHRAPNEL_TARGETS
	_report("shrapnel stays capped", _synergy_hits() > 0 and _synergy_hits() <= cap,
		"20 kills in one tick produced %d shrapnel strikes (cap %d: %d bursts a second x %d targets)"
			% [_synergy_hits(), cap, int(_build.SHRAPNEL_PER_SECOND), _build.SHRAPNEL_TARGETS])


func _set_wreck() -> void:
	var a := _spawn(Vector3(20.0, 0.0, 0.0))
	_spawn(Vector3(23.0, 0.0, 2.0))
	_game.ctx.spawner.strike(a, "ram", 20.0)


func _check_wreck() -> void:
	_report("wrecking ball", _build.has_transformer("wrecking_ball") and _struck.get("ram", 0) == 1 and _synergy_hits() >= 1,
		"Double Feed + Hot Rivets: one ram sent a shockwave that struck %d other enemies" % _synergy_hits())


func _set_rod() -> void:
	_spawn(Vector3(8.0, 0.0, 0.0))
	_build.scrap.drop(_ball(), 3, RandomNumberGenerator.new())


func _check_rod() -> void:
	_report("lightning rod", _build.has_transformer("lightning_rod") and _struck.get("arc", 0) >= 1,
		"Arc Coil + Drop Weight (Moss): picking up scrap sparked %d arcs at the nearest enemy" % _struck.get("arc", 0))


func _set_tesla() -> void:
	_spawn(Vector3(8.0, 0.0, 0.0))
	_spawn(Vector3(-8.0, 0.0, 0.0))
	_game.player.grapple_to(_ball() + Vector3(0.0, 9.0, 0.0))


func _check_tesla() -> void:
	var hooked: bool = _game.player.kit.hooked
	_game.player.release_grapple()
	_report("tesla pylon", _build.has_transformer("tesla_pylon") and hooked and _struck.get("arc", 0) >= 2,
		"Focus Lens + Live Line (Mind-glass), hooked for 0.55 s: arcs leapt to nearby enemies %d times" % _struck.get("arc", 0))


func _set_pinwheel() -> void:
	_spawn(Vector3(3.0, 0.0, 5.0))
	_game.player.set_velocity_now(Vector3(0.0, 0.0, 30.0))


func _check_pinwheel() -> void:
	_report("pinwheel", _build.has_transformer("pinwheel") and _synergy_hits() >= 1,
		"Loose Trigger + Long Barrel (Highdraft) at 30 m/s: the blade ring cut %d enemies it passed" % _synergy_hits())


func _set_glacier() -> void:
	_spawn(Vector3(3.0, 0.0, 0.0))
	_game.events.landed.emit(12.0)


func _check_glacier() -> void:
	_report("glacier hull", _build.has_transformer("glacier_hull") and _synergy_hits() >= 1,
		"Slag Rounds + Rivet Plating (Fleet): a 12 m/s landing cracked a frost ring that struck %d enemies" % _synergy_hits())


func _water(point: Vector3) -> Dictionary:
	if Vector2(point.x - _water_centre.x, point.z - _water_centre.z).length() <= 20.0:
		return {"surface_y": _surface}
	return {}


func _set_kinetic() -> void:
	_water_centre = _ball()
	_surface = _ball().y + 3.0
	_build.register_material("water", _water)
	_build.apply_element("frost", _ball() + Vector3(0.0, 3.5, 0.0), "test")
	_game.events.slammed.emit(_ball() + Vector3(0.0, 3.5, 0.0), 1.0, 1.0)


func _check_kinetic() -> void:
	var found: Array = _build.found()
	var shattered := found.any(func(line): return String(line).begins_with("Frost, then a heavy hit"))
	var froze := found.any(func(line): return String(line).begins_with("Frost on water"))
	_build.field.clear_providers()
	_report("frost then kinetic shatters", shattered and froze and _build.field.slab_count() == 0,
		"a slam on fresh ice with no parts shattered it (%d slabs left); found list %s"
			% [_build.field.slab_count(), found])


func _set_spiral() -> void:
	_game.events.shot_fired.emit("rapid_laser", _ball(), _ball() + Vector3(0.0, 0.0, 20.0))
	_game.events.shot_fired.emit("rapid_laser", _ball(), _ball() + Vector3(0.0, 0.0, 20.0))


func _check_spiral() -> void:
	var found: Array = _build.found()
	var linked := found.filter(func(line): return String(line).begins_with("A spiral carrying chain"))
	_report("spiral carrying chain", _build.has_transformer("linked_spiral") and linked.size() == 1,
		"Spiral Wave + Echo Locator (Waking): two shots logged the unnamed find once: %s" % [linked])


func _finish() -> bool:
	print("build_behaviour_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true


# Synergy hits under their own strike kind. Any "slam" here would be a synergy borrowing
# the landing verb (FIXWAVE build [C]), so it counts as -1 and fails the check.
func _synergy_hits() -> int:
	return -1 if _struck.has("slam") else _struck.get("synergy", 0)
