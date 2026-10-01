extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")

# A drop landed with a natural smash (Rivet, brake held in the air onto the open core)
# must not be followed by the landing's own skid push striking the Warden again: inside
# the drop's rearm the rule answers floor and the Warden clanks (strike_deflected). Every
# other enemy in reach still takes the shockwave, and so does a plain chaser the ball lands on.

const OUT := 58.0
const WAIT := 1.6
const SETTLE := 0.5
const START := Vector3(-1.2, 3.0, 0.0)
const START_VELOCITY := Vector3(20.0, -16.0, 0.0)

var _game
var _source
var _failures := 0
var _warden
var _drop
var _bystander
var _plain
var _phase := "boot"
var _clock := 0.0
var _contacts := 0
var _landed := 0
var _warden_strikes: Array[String] = []
var _warden_deflects := 0
var _bystander_slams := 0
var _plain_slams := 0
var _smashed := 0


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
			_source = Intent.Scripted.new()
			_game.player.source = _source
			_game.tuning.set_option("loop_mode", "drop")
			_game.tuning.set_option("gun_role", "hold")
			_game.flow.press_start()
			_game.flow.choose_class(1)
			_game.events.warden_drop_landed.connect(func(_at: Vector3, _s: float, _l: int, _n: int): _landed += 1)
			_game.events.skid_smashed.connect(func(_at: Vector3, _hits: int): _smashed += 1)
			_game.events.strike_deflected.connect(func(enemy: Node3D, _k: String, _p: float, _pl: float):
				if enemy == _warden:
					_warden_deflects += 1)
			_game.events.enemy_struck.connect(func(enemy: Node3D, kind: String, _force: float):
				if enemy == _warden:
					_warden_strikes.append(kind)
				elif enemy == _bystander and kind == "slam":
					_bystander_slams += 1
				elif enemy == _plain and kind == "slam":
					_plain_slams += 1)
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
			var spot: Vector3 = _warden.global_position + Vector3(3.0, 0.0, 5.0)
			_bystander = _game.ctx.spawner.spawn_enemy("chaser", _game.ctx.terrain.drop_point(spot.x, spot.z, 1.8))
			_source.hold = {}
			_game.player.reset_to(_top() + START, START_VELOCITY)
			_to("fly")
		"fly":
			_hold_cycle()
			if _clock > 0.03 and not _game.player.state.grounded:
				_source.hold = {"brake_held": true}
			if _landed > 0:
				_to("after")
			elif _clock > WAIT:
				_report("contact", false, "the ball never landed a drop in %.1f s" % WAIT)
				return _finish()
		"after":
			_hold_cycle()
			if _clock >= SETTLE:
				_judge()
				_to("plain_place")
		"plain_place":
			_hold_cycle()
			var at: Vector3 = _ground(30.0)
			_plain = _game.ctx.spawner.spawn_enemy("chaser", at)
			_source.hold = {}
			_game.player.reset_to(at + Vector3(0.0, 6.0, 0.0), Vector3(0.0, -8.0, 0.0))
			_to("plain_fly")
		"plain_fly":
			_hold_cycle()
			if _clock > 0.03 and not _game.player.state.grounded:
				_source.hold = {"brake_held": true}
			if _clock > 1.2:
				_judge_plain()
				return _finish()
	return false


func _judge() -> void:
	_report("natural landing", _landed == 1 and _smashed == 1,
		"the held-brake slam landed %d drop(s) and %d skid smash(es) (needs 1 and 1); the Warden took %s"
			% [_landed, _smashed, _warden_strikes])
	_report("no clank", _warden_deflects == 0,
		"%d strike_deflected on the Warden after the landed drop (needs 0)" % _warden_deflects)
	_report("shockwave elsewhere", _bystander_slams >= 1,
		"an enemy in reach took %d SLAM strike(s) from the landing (needs >= 1)" % _bystander_slams)


func _judge_plain() -> void:
	_report("plain landing", _plain_slams >= 1,
		"a chaser with no drop rule that the held-brake slam landed on took %d SLAM strike(s) (needs >= 1)" % _plain_slams)


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
	if is_instance_valid(_bystander):
		_bystander.queue_free()
	if is_instance_valid(_plain):
		_plain.queue_free()
	print("combat_slam_landing_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
	return true
