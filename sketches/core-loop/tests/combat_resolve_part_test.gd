extends SceneTree

const Game := preload("res://src/game.gd")
const StageDefs := preload("res://tests/doubles/two_world_defs.gd").FirstWorld

# Presentation gates hit-stop on ctx.spawner.resolve(enemy, kind, force), called from
# its enemy_struck handler before the damage lands. That query must return the plating
# the strike actually meets, weak point included, even when the strike named its part
# (a Brindle cap, a bolt on the magnet) rather than finding it from the ball. A stomp on
# a Warden II vent cap reads plating 0 inside the handler; a body stomp reads the body
# plating less the shred the cap stomp left.

const FORCE := 12.0

# Plating seam coverage uses the legacy table rather than posture rows.
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
	warden.hp = 99999.0
	warden.max_hp = 99999.0
	_game.events.enemy_struck.connect(func(enemy: Node3D, kind: String, force: float):
		var r: Dictionary = _combat.resolve(enemy, kind, force)
		_seen.append({"plating": r["plating"], "full": r["full"]}))
	var ball_to_cap: float = _game.player.ball_position().distance_to(warden.cap_points()[0])
	_combat.strike(warden, "stomp", FORCE, "cap")
	var body_plating: float = warden.plating - _combat.shred_of(warden)
	_combat.strike(warden, "stomp", FORCE)
	var cap: Dictionary = _seen[0] if _seen.size() > 0 else {"plating": -1.0, "full": false}
	var body: Dictionary = _seen[1] if _seen.size() > 1 else {"plating": -1.0, "full": false}
	_report("cap", cap["plating"] == 0.0 and cap["full"],
		"a stomp that named the vent cap (ball %.0f m from it): resolve in enemy_struck reads plating %.0f, full %s" % [ball_to_cap, cap["plating"], cap["full"]])
	_report("body", warden.plating == StageDefs.of(2)["warden_plating"] and is_equal_approx(body["plating"], body_plating) and not body["full"],
		"a body stomp on Warden II: resolve in enemy_struck reads plating %.2f (plating %.0f less shred %.2f), full %s"
			% [body["plating"], warden.plating, warden.plating - body_plating, body["full"]])
	var ok := _failures == 0
	print("combat_resolve_part_test: %s" % ("PASS" if ok else "FAIL"))
	_game.free()
	quit(0 if ok else 1)
	return true
