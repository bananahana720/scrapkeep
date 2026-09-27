extends SceneTree

const Game := preload("res://src/game.gd")

# A build synergy's strike (kind "synergy") is resolved as the damage given: its punch
# is its force, with no contact row and no second heft, and it always meets body
# plating, never a weak point, even if a caller names one. The double opens any named
# part to plating 0, so only the rule keeps a synergy off it.

const BODY := 60.0
const FORCE := 30.0


class PartDouble extends "res://src/combat/enemy.gd":
	func plating_for(_kind: String, part: String) -> float:
		return 0.0 if part != "" else plating_now()


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
	_combat.heft_override = 2.0
	var target := PartDouble.new()
	target.plating = BODY
	target.hp = 1000.0
	target.max_hp = 1000.0
	var named: Dictionary = _combat.resolve(target, "synergy", FORCE, "weak")
	_report("punch", named["punch"] == FORCE,
		"a synergy of force %.0f at heft 2 has punch %.1f (the force as given)" % [FORCE, named["punch"]])
	_report("body_plating", named["part"] == "" and named["plating"] == BODY and not named["full"],
		"a synergy that named a weak point met part '%s' at plating %.0f, full %s" % [named["part"], named["plating"], named["full"]])
	target.free()
	var ok := _failures == 0
	print("combat_synergy_kind_test: %s" % ("PASS" if ok else "FAIL"))
	_game.free()
	quit(0 if ok else 1)
	return true
