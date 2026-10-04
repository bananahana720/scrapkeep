extends SceneTree
# F6 2026-10-04: the Warden has no vent caps; the seam is checked on its posture body.

const Game := preload("res://src/game.gd")
const StageDefs := preload("res://tests/doubles/two_world_defs.gd").FirstWorld

# Presentation gates hit-stop on ctx.spawner.resolve(enemy, kind, force), called from
# its enemy_struck handler before the damage lands. That query must return the plating
# the strike actually meets. A body stomp on a Warden II reads its stage plating inside
# the handler, and the answer matches the same query made before the strike.

const FORCE := 12.0

class LegacyGame extends "res://src/game.gd":
	func _chosen_table():
		return preload("res://tests/doubles/two_world_defs.gd").FirstWorld

var _game
var _combat
var _failures := 0
var _seen: Array = []


func _initialize() -> void:
	_game = LegacyGame.new()
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
	_game.flow.enter_stage(2, Vector3.ZERO, false)
	_game.run.set_max_hp(99999.0)
	_combat.heft_override = 1.0
	var ctx = _game.ctx
	var warden: Node3D = ctx.spawner.spawn_enemy("warden", ctx.terrain.beacon_point(2))
	_game.events.enemy_struck.connect(func(enemy: Node3D, kind: String, force: float):
		var r: Dictionary = _combat.resolve(enemy, kind, force)
		_seen.append({"plating": r["plating"], "full": r["full"]}))
	var before: Dictionary = _combat.resolve(warden, "stomp", FORCE)
	_combat.strike(warden, "stomp", FORCE)
	var body: Dictionary = _seen[0] if _seen.size() > 0 else {"plating": -1.0, "full": false}
	_report("fight", warden.fight() == "posture", "the Warden fights %s" % warden.fight())
	_report("body", warden.plating == StageDefs.of(2)["warden_plating"] and body["plating"] == before["plating"] and body["full"] == before["full"],
		"a body stomp on Warden II: resolve in enemy_struck reads plating %.2f, full %s; before the strike %.2f, %s"
			% [body["plating"], body["full"], before["plating"], before["full"]])
	var ok := _failures == 0
	print("combat_resolve_part_test: %s" % ("PASS" if ok else "FAIL"))
	_game.free()
	quit(0 if ok else 1)
	return true
