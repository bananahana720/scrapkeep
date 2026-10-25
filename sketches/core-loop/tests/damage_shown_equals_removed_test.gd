extends SceneTree

# Shown damage equals removed damage (red team probe445 on fcddfe10, made a test). For every
# spawnable world 1 and fleet kind, six hits (rams at 20, 45 and 90 m/s, a frost and an arc weapon
# bolt, a slam), with 0 and 12 Punch Rivets: the damage a listener reads inside enemy_struck
# (combat.resolve: the damage number, crit flash and hit-stop) equals the HP the hit removed, or the
# hit is marked absorbed and removed nothing; and would_crush never promises a kill the same strike
# does not land. crew_fitter, which no player hit hurts, was the one kind showing numbers (12 rows).
# smoke: timeout=300s

const Game := preload("res://src/game.gd")
const Roster := preload("res://src/combat/roster.gd")
const DamageNumbers := preload("res://src/presentation/damage_numbers.gd")
const T := preload("res://tests/support/t.gd")

var _t := T.new("damage_shown_equals_removed_test")
var _game
var _ticks := 0
var _bad: Array = []
var _rows := 0
var _fitter: Array = []


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _kinds() -> Array:
	var out := ["chaser", "lobber", "drill_crew"]
	for k in Roster.world_kinds(1):
		if not k in out:
			out.append(k)
	for k in ["mag_trapper", "hooker", "netcaster", "bola_thrower", "plated_brute", "deflector", "winch_drone",
			"gyro_jammer", "swatter", "ramp_flipper", "catch_trap", "crew_fitter", "miniboss", "vault"]:
		if not k in out:
			out.append(k)
	return out


func _spawn(kind: String, offset: float) -> Node3D:
	var terrain = _game.ctx.terrain
	var at: Vector3 = terrain.spawn_point(1) + Vector3(offset, 0.0, 18.0)
	var e: Node3D = _game.ctx.spawner.spawn_enemy(kind, terrain.drop_point(at.x, at.z, 1.5))
	e.set_process(false)
	e.set_physics_process(false)
	return e


func _set_rivets(n: int) -> void:
	_game.ctx.run.panels.clear()
	for i in n:
		_game.ctx.run.panels.append("punch_rivet")
	_game.ctx.build.recompute()


func _probe() -> void:
	_bad.clear()
	var hits := [["ram", 20.0, ""], ["ram", 45.0, ""], ["ram", 90.0, ""], ["frost", 30.0, "weapon"], ["arc", 30.0, "weapon"], ["slam", 40.0, ""]]
	var offset := -30.0
	for rivets in [0, 12]:
		_set_rivets(rivets)
		for kind in _kinds():
			for h in hits:
				offset += 3.0
				if offset > 30.0:
					offset = -30.0
				var e := _spawn(kind, offset)
				if e.get("hp") == null:
					e.queue_free()
					continue
				e.hp = 10000.0
				if "max_hp" in e:
					e.max_hp = 10000.0
				var shown := []
				var listen := func(enemy: Node3D, k: String, f: float):
					if enemy == e:
						shown.append(_game.combat.resolve(enemy, k, f))
				_game.ctx.events.enemy_struck.connect(listen)
				var before: float = float(e.hp)
				_game.combat.strike(e, h[0], h[1], "", h[2])
				_game.ctx.events.enemy_struck.disconnect(listen)
				var lost: float = before - float(e.hp) if is_instance_valid(e) else before
				var r: Dictionary = shown[0] if shown.size() > 0 else {}
				var dealt := float(r.get("dealt", -1.0))
				var absorbed := bool(r.get("absorbed", false))
				var mismatch := shown.size() > 0 and not absorbed and absf(dealt - lost) > 0.01
				var absorbed_bad := absorbed and lost > 0.01
				if is_instance_valid(e):
					e.queue_free()
				# would_crush vs the kill, at an HP just under what this hit removed
				var crush_bad := ""
				if lost > 0.5:
					var e2 := _spawn(kind, offset + 1.5)
					e2.hp = lost * 0.98
					var wc: bool = _game.combat.would_crush(e2, h[0], h[1])
					_game.combat.strike(e2, h[0], h[1], "", h[2])
					var killed: bool = not is_instance_valid(e2) or (e2.has_method("is_dead") and e2.is_dead())
					if wc and not killed:
						crush_bad = "WOULD_CRUSH_BUT_ALIVE"
					if is_instance_valid(e2) and not killed:
						e2.queue_free()
				var line := "%s rivets=%d %s %.0f %s: shown=%.2f lost=%.2f absorbed=%s crit=%s %s%s%s" % [kind, rivets, h[0], h[1], h[2],
					dealt, lost, absorbed, DamageNumbers.is_crit(r, 0.0) if not r.is_empty() else "-",
					"MISMATCH " if mismatch else "", "ABSORBED_BUT_LOST " if absorbed_bad else "", crush_bad]
				if mismatch or absorbed_bad or crush_bad != "":
					_bad.append(line)
				_rows += 1
				if kind == "crew_fitter":
					_fitter.append(absorbed and lost < 0.01)
	_set_rivets(0)


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_ticks += 1
	if _ticks == 1:
		_game.ctx.calm = true
		_game.flow.press_start()
		_game.flow.choose_class(0)
	elif _ticks == 20:
		_probe()
		_t.check("every hit read is shown as removed, or absorbed", _bad.is_empty() and _rows > 200,
			"%d rows, %d bad: %s" % [_rows, _bad.size(), _bad.slice(0, 6)])
		_t.check("every crew_fitter hit is absorbed and removes nothing", _fitter.size() == 12 and not _fitter.has(false),
			"%s" % [_fitter])
		_game.free()
		quit(_t.verdict())
		return true
	return false
