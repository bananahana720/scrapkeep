extends SceneTree

const Game := preload("res://src/game.gd")
const SpeedTier := preload("res://src/core/speed_tier.gd")

# A target that only a ram can beat says so through tint_verb() == "ram", and the tint
# then compares its plating with ram_punch_now(), not with punch_now(). The double is
# Brindle charging at plating 150. The build fires 160-damage bolts and the ball rolls
# below cruise, so punch_now() is 160 but a ram has no punch: the charging hull reads
# slate, and the same hull not charging reads amber.

const PLATING := 150.0
const BOLT := 160.0


class ChargeDouble extends "res://src/combat/enemy.gd":
	var charging := true

	func tint_verb() -> String:
		return "ram" if charging else ""


var _game
var _combat
var _failures := 0
var _step := 0
var _hull: Node3D


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
			_park()
		2:
			var ram: float = _combat.ram_punch_now() if _combat.has_method("ram_punch_now") else -1.0
			_report("ram_punch_now", ram == 0.0 and _game.player.speed_tier() < SpeedTier.CRUISE,
				"below cruise (tier %d): ram_punch_now %.1f, punch_now %.1f" % [_game.player.speed_tier(), ram, _combat.punch_now()])
			_report("charging", _combat.punch_now() >= BOLT and _hull.tint_state == "slate",
				"charging at plating %.0f with %.0f bolts and no ram: tint %s" % [PLATING, BOLT, _hull.tint_state])
			_hull.charging = false
		3:
			_report("not_charging", _hull.tint_state == "amber",
				"the same hull not charging, bolts %.0f against plating %.0f: tint %s" % [BOLT, PLATING, _hull.tint_state])
			return _finish()
	_step += 1
	return false


func _setup() -> void:
	_combat = _game.ctx.spawner
	_game.ctx.calm = true
	_game.flow.press_start()
	_game.flow.choose_class(1)
	_game.run.set_max_hp(99999.0)
	_combat.heft_override = 1.0
	var weapon: String = _combat.active_weapon()
	_combat._patterns[weapon].damage = BOLT
	var ctx = _game.ctx
	_hull = ChargeDouble.new()
	ctx.root.add_child(_hull)
	_hull._setup_common(ctx.player, ctx.terrain, ctx.root, Callable(ctx.flow, "in_play"))
	_hull.global_position = ctx.terrain.spawn_point(1) + Vector3(0.0, 0.0, 70.0)
	_hull.plating = PLATING
	_hull.hp = 5000.0
	_hull.max_hp = 5000.0


func _park() -> void:
	var ctx = _game.ctx
	var at: Vector3 = ctx.terrain.spawn_point(1)
	at.y = ctx.terrain.height(at.x, at.z) + 1.05
	_game.player.reset_to(at)
	_game.player.body().global_position = at


func _finish() -> bool:
	var ok := _failures == 0
	print("combat_ram_tint_test: %s" % ("PASS" if ok else "FAIL"))
	_game.free()
	quit(0 if ok else 1)
	return true
