extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")

# M0's drops_to_break against a real drop-mode landing: Rivet (skid smash) comes off the
# line onto the open stage 1 core, and the landing's skid smash then strikes the Warden
# SLAM twice (player_ball.gd's shockwave, then its skid push). The ledger must count one
# drop, one per warden_drop_landed, however many strikes the landing made.
#
# Evidence limit: the flight is real physics from a placed start (warden_impact_test's
# drop case), and the smash is player_ball.gd's own landing handler called at the core's
# top on the contact tick, not a slam the augment state machine landed by itself.

const OUT := 58.0
const WAIT := 1.6
const SETTLE := 0.25

var _game
var _failures := 0
var _warden
var _drop
var _phase := "boot"
var _clock := 0.0
var _contacts := 0
var _landed := 0
var _slam_strikes := 0
var _landing_verdict := "none"


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _physics_process(delta: float) -> bool:
	if _game.flow == null:
		return false
	_clock += delta
	match _phase:
		"boot":
			_game.ctx.calm = true
			_game.flow.force_warden = true
			_game.player.source = Intent.Scripted.new()
			_game.tuning.set_option("loop_mode", "drop")
			_game.tuning.set_option("gun_role", "hold")
			_game.flow.press_start()
			_game.flow.choose_class(1)
			_game.events.warden_drop_landed.connect(func(_at: Vector3, _s: float, _l: int, _n: int): _landed += 1)
			_game.events.enemy_struck.connect(func(enemy: Node3D, kind: String, _force: float):
				if enemy == _warden and kind == "slam":
					_slam_strikes += 1)
			_to("settle")
		"settle":
			if _clock > 0.3:
				_game.run.set_max_hp(99999.0)
				_game.ctx.spawner.heft_override = 1.0
				_warden = _game.flow.warden
				_drop = _warden.get("drop") if is_instance_valid(_warden) else null
				var flavour: String = _game.player.kit.smash_flavour
				_report("setup", _drop != null and flavour == "skid",
					"stage 1 Warden carries drop rules (%s); the class's smash flavour is '%s' (needs skid)"
						% ["yes" if _drop != null else "no", flavour])
				if _drop == null:
					return _finish()
				_game.player.reset_to(_ground(OUT))
				_to("out")
		"out":
			_hold_cycle()
			if _clock > 0.05:
				_to("place")
		"place":
			_hold_cycle()
			if _warden._open_left <= 0.0:
				_warden._open(_warden.CORE_WINDOW)
			_warden.hp = _warden.max_hp
			_drop._rearm = 0.0
			_drop._dropped = false
			_contacts = _drop.contacts
			_game.player.reset_to(_top() + Vector3(-6.0, 4.5, 0.0), Vector3(20.0, -16.0, 0.0))
			_to("fly")
		"fly":
			_hold_cycle()
			if _drop.contacts > _contacts:
				_landing_verdict = String(_drop.last_contact.get("verdict", "none"))
				_game.player._on_slammed(_top(), 30.0, 1.0)
				_to("after")
			elif _clock > WAIT:
				_report("contact", false, "the ball never reached the core in %.1f s" % WAIT)
				return _finish()
		"after":
			_hold_cycle()
			if _clock >= SETTLE:
				_judge()
				return _finish()
	return false


func _judge() -> void:
	var combat = _game.ctx.spawner
	_report("skid landing", _landing_verdict == "drop" and _landed == 1 and _drop.drops_landed == 1 and _slam_strikes >= 2,
		"the landing judged '%s', then its skid smash: %d warden_drop_landed, %d SLAM strike(s) on the Warden (needs drop, 1, >= 2)"
			% [_landing_verdict, _landed, _slam_strikes])
	_game.events.beacon_unsealed.emit(1)
	var ledger: Dictionary = combat.delivered_damage()
	_report("drops_to_break", ledger["drops_to_break"].get("1", -1) == 1,
		"the break snapshotted drops_to_break %s and warden_slam_hits %s (needs one drop)"
			% [ledger["drops_to_break"], ledger["warden_slam_hits"]])
	_report("drop source", float(ledger["by_source"].get("drop_or_slam", 0.0)) > 0.0,
		"the drop's HP landed under by_source.drop_or_slam (%.1f)" % [float(ledger["by_source"].get("drop_or_slam", 0.0))])


func _ground(out: float) -> Vector3:
	return _game.ctx.terrain.drop_point(_warden.global_position.x + out, _warden.global_position.z, 1.5)


func _top() -> Vector3:
	return _warden.global_position + Vector3.UP * _warden.HALF_HEIGHT


func _hold_cycle() -> void:
	_warden._pulse_clock = 0.0
	_warden._charging = false


func _to(phase: String) -> void:
	_phase = phase
	_clock = 0.0


func _finish() -> bool:
	print("combat_drop_ledger_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
	return true
