extends SceneTree
# F6 2026-10-04: posture grammar. A Warden builds no shred, a vault still sheds, and the posture hull builds none.

const BRINDLE_HITS := 20

class LegacyGame extends "res://src/game.gd":
	func _chosen_table():
		return preload("res://tests/doubles/two_world_defs.gd").FirstWorld

var _game
var _combat
var _failures := 0
var _wait := 0

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
	_wait += 1
	if _wait == 1:
		_combat = _game.ctx.spawner
		_game.ctx.calm = true
		_game.flow.press_start()
		_game.flow.choose_class(1)
		_game.flow.force_warden = true
		_game.flow.enter_stage(3, Vector3.ZERO, false)
		_game.run.set_max_hp(99999.0)
		_check_warden_and_vault()
		_game.flow.enter_boss(Vector3.ZERO)
	elif _wait == 11:
		_check_brindle()
		print("combat_shred_test: %s" % ("PASS" if _failures == 0 else "FAIL"))
		_game.free()
		quit(0 if _failures == 0 else 1)
		return true
	return false

func _check_warden_and_vault() -> void:
	var warden: Node3D = _game.flow.warden
	for i in 40:
		_combat.strike(warden, "runner", 20.0)
	_combat.strike(warden, "synergy", 60.0)
	_report("warden", warden.fight() == "posture" and _combat.shred_of(warden) == 0.0 and _combat.plating_of(warden) == warden.plating,
		"a posture Warden after 40 runner hits and a synergy strike: shred %.1f (needs 0), plating_of %.1f of %.1f"
			% [_combat.shred_of(warden), _combat.plating_of(warden), warden.plating])
	var at: Vector3 = _game.ctx.terrain.beacon_point(3) + Vector3(30.0, 0.0, 30.0)
	var vault: Node3D = _combat.spawn_enemy("vault", at)
	var base: float = vault.plating
	for i in 10:
		_combat.strike(vault, "runner", 20.0)

	var shred: float = _combat.shred_of(vault)
	_report("vault", shred > 0.0 and absf(_combat.plating_of(vault) - (base - shred)) < 0.001,
		"ten 20-damage hits on a stage-3 vault (plating %.0f) shredded %.1f, plating_of %.1f" % [base, shred, _combat.plating_of(vault)])
	vault.free()

func _check_brindle() -> void:
	var boss = _game.ctx.get("boss")
	if boss == null or boss.ship == null or not is_instance_valid(boss.ship.hull):
		_report("brindle", false, "no real boss hull after enter_boss")
		return
	var hull: Node3D = boss.ship.hull
	var base: float = hull.plating_now()
	for i in BRINDLE_HITS:
		_combat.strike(hull, "runner", 16.0)
	_report("brindle", _combat.shred_of(hull) == 0.0 and absf(_combat.plating_of(hull) - base) < 0.001,
		"boss hull (plating %.0f) after %d hits: shred %.1f, plating_of %.1f" % [base, BRINDLE_HITS, _combat.shred_of(hull), _combat.plating_of(hull)])
	var magnet: Node3D = boss.ship.magnets[0]
	for i in BRINDLE_HITS:
		_combat.strike(magnet, "runner", 16.0)
	_report("brindle_weak", _combat.resolve(magnet, "runner", 16.0)["plating"] == 0.0, "the crane magnet, a weak point, meets a weapon at plating 0")
