extends SceneTree
# F6 2026-10-04: rewritten for the posture grammar. Each family Warden fights on posture; its
# family point opens only on a stagger (never after a pulse); the swarm keeps its guard rack
# (its burst is in warden_guard_posture_test); the others have no rack; mind_adapted never fires.

const Warden := preload("res://src/combat/warden.gd")
const Roster := preload("res://src/combat/roster.gd")

class LegacyGame extends "res://src/game.gd":
	func _chosen_table():
		return preload("res://tests/doubles/two_world_defs.gd").FirstWorld

var _game
var _combat
var _failures := 0
var _stage := 0
var _adapted := 0


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
	if _stage == 0:
		_combat = _game.ctx.spawner
		_game.ctx.calm = true
		_game.flow.force_warden = true
		if _game.events.has_signal("mind_adapted"):
			_game.events.connect("mind_adapted", func(_a = null, _b = null, _c = null): _adapted += 1)
		_game.flow.press_start()
		_game.flow.choose_class(1)
	_stage += 1
	if _stage > 3:
		_report("mind_adapted never fires", _adapted == 0, "%d mind_adapted" % _adapted)
		print("warden_family_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
		_game.free()
		quit(0 if _failures == 0 else 1)
		return true
	if _stage > 1:
		_game.flow.enter_stage(_stage, Vector3.ZERO, false)
	_game.run.set_max_hp(99999.0)
	_check(_game.flow.warden)
	return false


func _check(warden: Node3D) -> void:
	var family: String = warden.family
	# KF0 2026-10-10: Roster.warden_family is the by-world fallback; the double's rows name
	# their family, so the expected value is the running row's.
	var want := String(_game.flow.stage_def().get("warden_family", Roster.warden_family(_stage)))
	_report("stage %d family" % _stage, family == want and warden.fight() == "posture",
		"stage %d Warden is the %s family on %s" % [_stage, family, warden.fight()])
	warden.set_physics_process(false)
	warden._physics_process(Warden.GUARD_RESPAWN)
	_report("stage %d closed after a pulse cycle" % _stage, not warden.family_open() and warden.weak_points().is_empty(),
		"family_open %s, weak points %d" % [warden.family_open(), warden.weak_points().size()])
	if family == Roster.SWARM:
		var rack: bool = warden.guard != null and not warden.guard.alive().is_empty()
		# The rack's posture burst needs a real ram contact; warden_guard_posture_test covers it.
		_report("swarm keeps its rack", rack, "rack %s" % rack)
	else:
		_report("stage %d has no rack" % _stage, warden.guard == null, "guard %s" % [warden.guard])
	warden._posture.staggered = true
	var point: String = warden.family_point()
	_report("stage %d opens on a stagger" % _stage, warden.family_open() and warden.plating_for("runner", point) == 0.0
		and warden.weak_points().any(func(p): return p.id == point), "family point %s" % point)
	warden._posture.staggered = false
