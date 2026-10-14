# 2026-10-13 RED-COMBAT: 9000ca2 gives Sable Bank Shot; PC-RIVET gives Rivet
# Line Drive in 20d4273 (design-v3/pilots/rivet.md:76-84, :109). Keep the shared hook
# checks on the merged kit: delayed ram punch and the specified straight haul.
extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Augments := preload("res://src/movement/augments.gd")
const Weapons := preload("res://src/combat/weapons.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const T := preload("res://tests/support/t.gd")

# The line skill hook (design-v3/SKILL-BAR.md section 3), wave P-B unit B1, 2026-10-10.
# Rivet's slot 3 carries Line Drive. Scripted through a real Game's
# router, harpoon and combat: a cast with a line standing fires along it now; with none it
# loads, the next bite within 4.0 s carries it, a dry fire keeps the load, and the load
# expires between 3.99 and 4.01 s. A loaded bite adds exactly one chain link, the flavour
# none, and the flavour scales by the chain multiplier. Every step runs synchronously.
# Evidence limit: the rule, not a played fight.

const DT := 1.0 / 60.0
const FLAT_SHELF := Vector3(-45.0, 15.0, 6.0)

var _t := T.new("line_skill_hook_test")
var _game
var _player
var _combat
var _source := Intent.Scripted.new()
var _loaded: Array = []
var _fired: Array = []
var _expired: Array = []
var _fails: Array = []
var _struck: Array = []


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _sim(seconds: float) -> void:
	for i in roundi(seconds * Engine.physics_ticks_per_second):
		await physics_frame


func _never() -> bool:
	return false


func _enemy(dx: float) -> Node3D:
	var at: Vector3 = _game.ctx.terrain.drop_point(FLAT_SHELF.x + dx, FLAT_SHELF.z, 1.0)
	var enemy: Node3D = _combat.spawn_enemy("chaser", at)
	enemy.live = Callable(self, "_never")
	return enemy


func _tick(fields := {}, dt := DT):
	var intent = _player.intent
	intent.clear()
	for k in fields:
		intent.set(k, fields[k])
	_player._route_slots(dt)
	_combat._step_special(intent, dt)
	_combat._step_line(intent, dt)
	return intent


# Pick 3 and click on one tick: the line skill's cast.
func _cast() -> void:
	_tick({"slot_pick": 2, "fire_pressed": true, "fire_held": true})
	_tick({"fire_released": true})


func _bite(enemy: Node3D) -> void:
	_player.grapple_to(enemy.global_position, Vector3.UP, enemy)


func _wall() -> Vector3:
	var at: Vector3 = _player.ball_position() + Vector3(8.0, 3.0, 0.0)
	_player.grapple_to(at, Vector3.LEFT, null)
	return at


func _fresh() -> void:
	_tick()
	_player.kit.drop_line("reset")
	_player.kit.line_end = ""
	_player.kit.rewind_left = 0.0
	_player.chain.reset()
	_player.abilities.refill()
	_player.abilities.snap_back("test")
	_player._fire_latched = false
	_combat._line_load = {}
	_combat._bite_pending = false
	_combat.last_line = {}
	_combat.get_node("RivetKit").pulses.clear()
	_combat.get_node("RivetKit").haul.clear()
	_loaded.clear()
	_fired.clear()
	_expired.clear()
	_fails.clear()
	_struck.clear()


func _line_hits(enemy: Node3D) -> int:
	return _struck.filter(func(r): return r[0] == enemy.get_instance_id() and r[1] == "ram").size()


func _punch_arrives(enemy: Node3D) -> void:
	var kit = _combat.get_node("RivetKit")
	var delay: float = _player.ball_position().distance_to(enemy.global_position) / Weapons.LINE_PULSE_SPEED
	kit._step_pulses(maxf(0.0, delay - 0.0001))
	_t.eq("the cable pulse cannot hit before its travel time", _line_hits(enemy), 0)
	kit._step_pulses(0.0002)


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_player = _game.player
	_player.source = _source
	_game.flow.press_start()
	var pilot_index: int = _game.flow.classes.map(func(def): return def.id).find("runner_gunner")
	if not _t.check("setup: Rivet is explicitly selected", pilot_index >= 0):
		quit(_t.verdict())
		return
	_game.flow.choose_class(pilot_index)
	_combat = _game.combat
	await _sim(0.6)
	_combat.heft_override = 1.0
	_game.events.line_skill_loaded.connect(func(id: String, seconds: float): _loaded.append([id, seconds]))
	_game.events.line_skill_fired.connect(func(id: String, target: Node3D, _at: Vector3, on: String): _fired.append([id, target.get_instance_id() if target != null else 0, on]))
	_game.events.line_skill_expired.connect(func(id: String): _expired.append(id))
	_game.events.verb_failed.connect(func(verb: String, reason: String, _at: Vector3): _fails.append([verb, reason]))
	_game.events.enemy_struck.connect(func(enemy: Node3D, kind: String, _force: float): _struck.append([enemy.get_instance_id(), kind]))
	_player.set_physics_process(false)
	var a := _enemy(0.0)
	_t.eq("setup: Rivet's slot 3 is Line Drive", [_player.abilities.id_of("line"), _player.kit.on(Augments.GRAPPLE)],
		["line_drive", true])

	# 1. A line stands on a body: the cast fires now along it, and adds no chain link.
	_fresh()
	_bite(a)
	var links: int = _player.chain.links
	_cast()
	_t.eq("01 on a body line the cast fires now", [_fired, _loaded, _combat.line_load()], [[["line_drive", a.get_instance_id(), "body"]], [], {}])
	_t.eq("02 the on-line flavour adds no chain link", _player.chain.links, links)
	_punch_arrives(a)
	_t.eq("03 the flavour strikes the latched enemy once", _line_hits(a), 1)

	# 2. The cast spends slot 3 and its cooldown is 8 s.
	_t.check("04 the cast spends slot 3 on an 8 s cooldown",
		not _player.abilities.ready("line") and absf(_player.abilities.cooldown_of("line") - 8.0) < 0.001,
		"ready %s, cooldown %.2f" % [_player.abilities.ready("line"), _player.abilities.cooldown_of("line")])

	# 3. No line: the cast loads for 4 s and spends now.
	_fresh()
	_cast()
	_t.eq("05 with no line the cast loads", [_loaded, _fired, String(_combat.line_load().get("id", ""))], [[["line_drive", 4.0]], [], "line_drive"])
	_t.eq("06 the load spends slot 3 at the cast", _player.abilities.ready("line"), false)

	# 4. The next bite carries it, and the bite adds exactly one link.
	links = _player.chain.links
	_bite(a)
	_tick()
	_t.eq("07 the loaded bite fires the flavour on the body", [_fired, _combat.line_load()], [[["line_drive", a.get_instance_id(), "body"]], {}])
	_t.eq("08 a loaded bite adds exactly one chain link", _player.chain.links, links + 1)
	_punch_arrives(a)
	_t.eq("09 the flavour from a loaded bite strikes once", _line_hits(a), 1)

	# 5. A second cast while a load waits is refused.
	_fresh()
	_cast()
	_player.abilities.refill()
	_fails.clear()
	_tick({"slot_pick": 2})
	_t.eq("10 a pick while a load waits is refused (loaded)", [_fails, _player.abilities.selected], [[["select", "loaded"]], "weapon"])

	# 6. Expiry: still loaded at 3.99 s, gone at 4.01 s, nothing refunded.
	_fresh()
	_cast()
	for i in 398:
		_tick({}, 0.01)
	var at_399: bool = not _combat.line_load().is_empty()
	_tick({}, 0.02)
	_t.eq("11 the load holds at 3.99 s and expires at 4.01 s",
		[at_399, _combat.line_load(), _expired, _player.abilities.ready("line")], [true, {}, ["line_drive"], false])

	# 7. A dry fire keeps the load, and the next bite still carries it.
	_fresh()
	_cast()
	_player.kit.aim = {"state": Augments.AIM_NONE}
	_player._press_harpoon()
	var kept: bool = not _combat.line_load().is_empty() and not _player.kit.hooked
	_player.chain.miss_left = 0.0
	_bite(a)
	_tick()
	_t.check("12 a dry fire keeps the load", kept and _fired == [["line_drive", a.get_instance_id(), "body"]],
		"kept %s, fired %s" % [kept, _fired.size()])

	# 8. Line Drive replaces the reel burst with the specified straight haul.
	_fresh()
	_cast()
	var body: RigidBody3D = _player.body()
	body.set_velocity_now(Vector3.ZERO)
	var anchor := _wall()
	_tick()
	var haul: Dictionary = _combat.get_node("RivetKit").haul
	var toward: float = _player.state.velocity.dot((anchor - body.global_position).normalized())
	_t.check("13 a loaded world bite fires on the world", _fired.size() == 1 and _fired[0][2] == "world",
		"fired %s" % [_fired])
	_t.check("13 the world haul has a committed ride", not haul.is_empty())
	_t.check("13 a loaded world bite delivers the specified haul speed toward the anchor", toward >= Weapons.LINE_HAUL_SPEED - 0.0001,
		"fired %s, speed toward anchor %.2f" % [_fired, toward])
	_t.check("13 the world haul stops at the minimum rope distance", not haul.is_empty()
		and absf(haul["ride"].target.distance_to(anchor) - Augments.MIN_ROPE) < 0.0001)

	# 9. The flavour scales by the chain multiplier at the moment it fires.
	_fresh()
	for i in 3:
		_bite(a)
		_player.release_grapple()
	_bite(a)
	var mult: float = _player.chain.multiplier()
	_cast()
	_t.check("14 the flavour reads the chain multiplier", mult > 1.0 and absf(float(_combat.last_line.get("mult", 0.0)) - mult) < 0.0001,
		"chain x%.2f, flavour x%.2f" % [mult, float(_combat.last_line.get("mult", 0.0))])

	# 10. A plain bite with nothing loaded fires no flavour.
	_fresh()
	_bite(a)
	_tick()
	_t.eq("15 a plain bite fires no flavour", _fired, [])

	# 11. Death drops the load.
	_fresh()
	_cast()
	_game.events.player_died.emit()
	_t.eq("16 death drops the load", _combat.line_load(), {})

	quit(_t.verdict())
