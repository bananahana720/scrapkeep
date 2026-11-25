extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")

# The plating rule (DEMO-SPEC Rules): one resolve() behind strike(), punch_now(),
# plating_of(), would_crush() and the tint. A plating-30 dummy takes a cruise ram in
# full and chips a 14-damage bolt with exactly one deflection; punch_now() reads a ram
# at the ball's speed times heft; would_crush() predicts the kill in 20 of 20 contacts;
# and the amber/slate tint flips on the tick punch_now() crosses the plating.

const FAR := 70.0
const CONTACTS := 20

var _game
var _combat
var _source := Intent.Scripted.new()
var _failures := 0
var _step := 0
var _deflected := 0
var _bus_has_deflect := false
var _dummy: Node3D
var _crush_targets: Array = []
var _tint_dummy: Node3D
var _tint_before := ""
var _tint_punch_before := 0.0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(check: String, ok: bool, detail: String) -> void:
	print("[%s] %s -> %s" % [check, detail, "PASS" if ok else "FAIL"])
	if not ok:
		_failures += 1


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	match _step:
		0:
			_setup()
		1:
			_check_hits()
			_start_speed()
		2:
			pass
		3:
			_check_speed()
			_check_crush()
			_start_tint()
		4:
			_tint_before = _tint_dummy.tint_state
			_tint_punch_before = _combat.punch_now()
			# Crossing the line: a damage tier lifts the laser from 12 to 15 against plating 13.
			_game.run.add_part("damage_tier", "test")
		5:
			var after: String = _tint_dummy.tint_state
			var punch: float = _combat.punch_now()
			_report("tint", _tint_before == "slate" and after == "amber" and _tint_punch_before < 13.0 and punch >= 13.0,
				"plating 13: slate at punch %.2f, amber on the next tick at punch %.2f" % [_tint_punch_before, punch])
			return _finish()
	_step += 1
	return false


func _setup() -> void:
	_combat = _game.ctx.spawner
	_game.ctx.calm = true
	_game.player.source = _source
	_bus_has_deflect = _game.events.has_signal("strike_deflected")
	if _bus_has_deflect:
		_game.events.connect("strike_deflected", func(_e: Node3D, _k: String, _p: float, _pl: float): _deflected += 1)
	_game.flow.press_start()
	_game.flow.choose_class(1)
	_game.run.set_max_hp(99999.0)
	_dummy = _spawn_far(0.0)
	_dummy.plating = 30.0
	_dummy.hp = 1000.0
	_dummy.max_hp = 1000.0


func _spawn_far(angle: float) -> Node3D:
	var ctx = _game.ctx
	var at: Vector3 = ctx.terrain.spawn_point(1) + Vector3(cos(angle), 0.0, sin(angle)) * FAR
	return ctx.spawner.spawn_enemy("chaser", ctx.terrain.drop_point(at.x, at.z, 1.6))


func _check_hits() -> void:
	_combat.heft_override = 1.0
	var before: float = _dummy.hp
	var deflections_before: int = _combat.deflections
	_combat.strike(_dummy, "ram", 14.0)
	var ram_dealt := before - float(_dummy.hp)
	_report("ram_full", is_equal_approx(snappedf(ram_dealt, 0.001), 32.2) and _combat.deflections == deflections_before,
		"ram force 14 at heft 1 on plating 30: punch 32.2, dealt %.2f in full" % ram_dealt)
	before = _dummy.hp
	var bus_before := _deflected
	_combat.strike(_dummy, "arc", 14.0)
	var bolt_dealt := before - float(_dummy.hp)
	var counted: int = (_deflected - bus_before) if _bus_has_deflect else (_combat.deflections - deflections_before)
	_report("bolt_chip", is_equal_approx(snappedf(bolt_dealt, 0.001), 2.8) and counted == 1,
		"a 14-damage bolt on plating 30 dealt %.2f (20%% chip), deflections %d, counted on %s"
			% [bolt_dealt, counted, "the bus (strike_deflected)" if _bus_has_deflect else "combat.deflections (this spine has no strike_deflected yet)"])


# The ball rolling at 20 m/s; punch_now() is read on the next tick.
func _start_speed() -> void:
	_combat.heft_override = 2.0
	var ctx = _game.ctx
	var at: Vector3 = ctx.terrain.spawn_point(1)
	var heading: Vector3 = ctx.terrain.entry_heading(1)
	at.y = ctx.terrain.height(at.x, at.z) + 1.05
	_game.player.reset_to(at, heading * 20.0)
	_game.player.body().global_position = at


func _check_speed() -> void:
	var formula: float = _combat.punch_of("ram", 20.0)
	var speed: float = _game.player.planar_velocity().length()
	var live: float = _combat.punch_now()
	var expected: float = _combat.punch_of("ram", speed)
	_report("punch_now", absf(formula - 80.0) <= 0.1 and absf(live - expected) <= 0.1 and absf(live - 80.0) <= 1.5,
		"heft 2: ram punch at 20 m/s is %.2f (needs 80 +- 0.1); live punch_now %.2f at %.2f m/s planar, formula %.2f"
			% [formula, live, speed, expected])
	_combat.heft_override = 1.0


# Twenty unplated chasers, twenty contacts of mixed kind and force, each predicted
# before it lands.
func _check_crush() -> void:
	var matches := 0
	var kills := 0
	var kinds := ["ram", "stomp", "slam"]
	for i in CONTACTS:
		var target: Node3D = _spawn_far(TAU * i / CONTACTS)
		target.hp = 30.0 + 4.0 * (i % 5)
		target.max_hp = target.hp
		var kind: String = kinds[i % 3]
		var force := 2.0 + 1.6 * i
		var predicted: bool = _combat.would_crush(target, kind, force)
		_combat.strike(target, kind, force)
		var killed: bool = target.is_dead()
		if predicted == killed:
			matches += 1
		if killed:
			kills += 1
	_report("would_crush", matches == CONTACTS and kills > 0 and kills < CONTACTS,
		"would_crush matched the outcome in %d of %d contacts (%d kills, %d survivors)" % [matches, CONTACTS, kills, CONTACTS - kills])


func _start_tint() -> void:
	var ctx = _game.ctx
	var at: Vector3 = ctx.terrain.spawn_point(1)
	at.y = ctx.terrain.height(at.x, at.z) + 1.05
	_game.player.reset_to(at)
	_game.player.body().global_position = at
	_tint_dummy = _spawn_far(PI)
	# 13, not 8: Rivet's press round is 12 since E1-06 (PILOT-CADENCE.md section 3.1), so it must sit under the plating.
	_tint_dummy.plating = 13.0


func _finish() -> bool:
	var ok := _failures == 0
	print("combat_plating_test: %s" % ("PASS" if ok else "FAIL"))
	_game.free()
	quit(0 if ok else 1)
	return true
