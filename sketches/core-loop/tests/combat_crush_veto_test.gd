extends SceneTree

const Game := preload("res://src/game.gd")

# The crush veto: an enemy that cannot die at its current HP says so through
# crushable(), and would_crush() never lets the spine pass the ball through it. The
# double stands in for Brindle's stunned hull (plating 0, HP held at a phase floor).
# A plain unplated enemy with the same HP and the same ram is the control.

const FLOOR_HP := 240.0
const RAM_FORCE := 200.0


class HullDouble extends "res://src/combat/enemy.gd":
	func crushable() -> bool:
		return false


var _game
var _combat
var _failures := 0


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
	_combat = _game.ctx.spawner
	_game.ctx.calm = true
	_game.flow.press_start()
	_game.flow.choose_class(1)
	_combat.heft_override = 1.0
	var hull := _unplated(HullDouble.new())
	var plain := _unplated(load("res://src/combat/enemy.gd").new())
	var punch: float = _combat.punch_of("ram", RAM_FORCE)
	var dealt: float = _combat.resolve(hull, "ram", RAM_FORCE)["dealt"]
	_report("control", _combat.would_crush(plain, "ram", RAM_FORCE),
		"an unplated crushable enemy at hp %.0f: a ram of punch %.1f crushes" % [FLOOR_HP, punch])
	_report("veto", dealt >= FLOOR_HP and not _combat.would_crush(hull, "ram", RAM_FORCE),
		"crushable() false at plating 0, hp %.0f, dealt %.1f: would_crush %s" % [FLOOR_HP, dealt, _combat.would_crush(hull, "ram", RAM_FORCE)])
	hull.free()
	plain.free()
	var ok := _failures == 0
	print("combat_crush_veto_test: %s" % ("PASS" if ok else "FAIL"))
	_game.free()
	quit(0 if ok else 1)
	return true


func _unplated(enemy: Node3D) -> Node3D:
	enemy.plating = 0.0
	enemy.hp = FLOOR_HP
	enemy.max_hp = 2400.0
	return enemy
