extends SceneTree

# Rule: a seated conductive-primer piece lets a weapon hit prime a foe for 3 s; the next
# ram, slam or special on it consumes the prime. Coil scales that hit by 1.5; Mesh shares
# 0.4 of it to the two nearest live foes within 6 m without a strike. Items never prime.

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Companion := preload("res://src/core/companion.gd")
const T := preload("res://tests/support/t.gd")

const FORCE := 5.0

var _t := T.new("companion_primer_test")
var _game
var _ticks := 0
var _spawned: Array = []


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_ticks += 1
	if _ticks == 1:
		_game.ctx.calm = true
		_game.player.source = Intent.Scripted.new()
		_game.flow.press_start()
		_game.flow.choose_class(0)
		return false
	if _ticks < 12:
		return false
	_check_seated()
	_check_no_companion()
	_check_coil()
	_check_mesh()
	_check_posture()
	_check_run_reset()
	_check_death_prune()
	_check_attempt_reset()
	quit(_t.verdict())
	return true


func _spawner():
	return _game.ctx.spawner


func _spawn(offset: Vector3) -> Node3D:
	var spot: Vector3 = _game.player.ball_position() + offset
	var e: Node3D = _spawner().spawn_enemy("chaser", _game.ctx.terrain.drop_point(spot.x, spot.z, 2.4))
	_spawned.append(e)
	return e


# Removes every earlier foe at once so neighbour searches see only this check's foes.
func _clear() -> void:
	for e in _spawned:
		if is_instance_valid(e):
			e.remove_from_group("enemy")
			e.queue_free()
	_spawned.clear()


func _seat(piece: String) -> void:
	var c := Companion.new()
	c.acquire(piece)
	c.acquire("ram_prow")
	_t.eq("assemble %s" % piece, c.assemble([piece, "ram_prow"]), "")
	_game.ctx.run.companion = c.to_dict()


func _base(e: Node3D, kind: String) -> float:
	return float(_spawner().resolve(e, kind, FORCE)["dealt"])


# Strikes and returns the HP the target lost.
func _hit(e: Node3D, kind: String, source := "") -> float:
	var before := float(e.hp)
	_spawner().strike(e, kind, FORCE, "", source)
	return before - float(e.hp)


func _check_seated() -> void:
	_t.eq("seated empty doc", Companion.seated({}, Companion.CONDUCTIVE_PRIMER), "")
	_t.eq("seated malformed sockets", Companion.seated({"sockets": 3}, Companion.CONDUCTIVE_PRIMER), "")
	_t.eq("seated non-string entries", Companion.seated({"sockets": [3, null]}, Companion.CONDUCTIVE_PRIMER), "")
	var c := Companion.new()
	c.acquire("primer_coil")
	_t.eq("owned but unseated", Companion.seated(c.to_dict(), Companion.CONDUCTIVE_PRIMER), "")
	c.acquire("ram_prow")
	c.assemble(["primer_coil", "ram_prow"])
	_t.eq("seated coil", Companion.seated(c.to_dict(), Companion.CONDUCTIVE_PRIMER), "primer_coil")
	var m := Companion.new()
	m.acquire("primer_mesh")
	m.acquire("ram_prow")
	m.assemble(["ram_prow", "primer_mesh"])
	_t.eq("seated mesh", Companion.seated(m.to_dict(), Companion.CONDUCTIVE_PRIMER), "primer_mesh")
	_t.eq("validate clean", Companion.validate(), [])


func _check_no_companion() -> void:
	_game.ctx.run.companion = {}
	var e := _spawn(Vector3(4, 0, 0))
	_hit(e, "runner", "weapon")
	_t.check("no companion: weapon does not prime", not _spawner().primed(e))
	var base := _base(e, "ram")
	_t.near("no companion: ram removes base", _hit(e, "ram"), base, 0.01)
	_t.check("no companion: foe alive", float(e.hp) > 0.0, "hp %s" % e.hp)
	_clear()


func _check_coil() -> void:
	_seat("primer_coil")
	var e := _spawn(Vector3(4, 0, 0))
	var e2 := _spawn(Vector3(-4, 0, 0))
	_hit(e, "runner", "weapon")
	_t.check("coil: weapon primes", _spawner().primed(e))
	_hit(e2, "synergy")
	_t.check("coil: synergy strike does not prime", not _spawner().primed(e2))
	var base := _base(e, "ram")
	_t.near("coil: ram on primed foe x1.5", _hit(e, "ram"), base * Companion.PRIMER_COIL_MULT, 0.01)
	_t.check("coil: ram consumed the prime", not _spawner().primed(e))
	var base2 := _base(e, "ram")
	_t.near("coil: second ram removes base", _hit(e, "ram"), base2, 0.01)
	_t.check("coil: foe alive after rams", float(e.hp) > 0.0, "hp %s" % e.hp)
	_clear()

	var s := _spawn(Vector3(4, 0, 0))
	_hit(s, "runner", "weapon")
	var sbase := _base(s, "runner")
	_t.near("coil: special on primed foe x1.5", _hit(s, "runner", "special"), sbase * Companion.PRIMER_COIL_MULT, 0.01)
	_t.check("coil: special consumed the prime", not _spawner().primed(s))
	_clear()

	var x := _spawn(Vector3(4, 0, 0))
	_hit(x, "runner", "weapon")
	_spawner()._clock += Companion.PRIMER_SECONDS + 0.1
	_t.check("coil: prime expired", not _spawner().primed(x))
	_t.near("coil: ram after expiry removes base", _hit(x, "ram"), _base(x, "ram"), 0.01)
	_clear()

	var w := _spawn(Vector3(4, 0, 0))
	_hit(w, "runner", "weapon")
	var wbase := _base(w, "runner")
	_t.near("coil: weapon on primed foe removes base", _hit(w, "runner", "weapon"), wbase, 0.01)
	_t.check("coil: weapon keeps the prime", _spawner().primed(w))
	_clear()


func _check_mesh() -> void:
	_seat("primer_mesh")
	var a := _spawn(Vector3(4, 0, 0))
	var origin: Vector3 = a.global_position - _game.player.ball_position()
	var b := _spawn(origin + Vector3(3, 0, 0))
	var c := _spawn(origin + Vector3(0, 0, 4))
	var far5 := _spawn(origin + Vector3(-5, 0, 0))
	var d := _spawn(origin + Vector3(0, 0, -9))
	_hit(a, "runner", "weapon")
	_hit(b, "runner", "weapon")
	var hp := {}
	for n in [a, b, c, far5, d]:
		hp[n] = float(n.hp)
	var base := _base(a, "ram")
	var struck := [0]
	var count := func(_e: Node3D, _k: String, _f: float): struck[0] += 1
	_game.events.enemy_struck.connect(count)
	_spawner().strike(a, "ram", FORCE)
	_game.events.enemy_struck.disconnect(count)
	_t.near("mesh: ram on A removes base", hp[a] - float(a.hp), base, 0.01)
	_t.near("mesh: B takes 0.4 share", hp[b] - float(b.hp), base * Companion.PRIMER_MESH_SHARE, 0.01)
	_t.near("mesh: C takes 0.4 share", hp[c] - float(c.hp), base * Companion.PRIMER_MESH_SHARE, 0.01)
	_t.near("mesh: third-nearest unchanged", hp[far5] - float(far5.hp), 0.0, 0.0001)
	_t.near("mesh: out-of-range unchanged", hp[d] - float(d.hp), 0.0, 0.0001)
	_t.check("mesh: B still primed", _spawner().primed(b))
	_t.check("mesh: A prime consumed", not _spawner().primed(a))
	_t.eq("mesh: one enemy_struck for the ram", struck[0], 1)
	var by_action: Dictionary = _spawner().delivered_damage()["by_action"]
	_t.check("mesh: delivered primer_mesh", float(by_action.get("primer_mesh", 0.0)) > 0.0, str(by_action.get("primer_mesh", 0.0)))
	_clear()


func _check_posture() -> void:
	_seat("primer_coil")
	var spot: Vector3 = _game.player.ball_position() + Vector3(8, 0, 0)
	var w: Node3D = _spawner().spawn_enemy("warden", _game.ctx.terrain.drop_point(spot.x, spot.z, 2.4))
	_spawned.append(w)
	if w == null or not w.has_method("fight") or w.fight() != "posture":
		print("[posture] warden spawn is not a posture fighter headless; check skipped")
		_clear()
		return
	_spawner().strike(w, "runner", FORCE, "", "weapon")
	_t.check("posture: warden never primed", not _spawner().primed(w))
	_clear()


func _check_run_reset() -> void:
	_seat("primer_coil")
	var e := _spawn(Vector3(4, 0, 0))
	_hit(e, "runner", "weapon")
	_t.check("reset: primed before run_started", _spawner().primed(e))
	_game.events.run_started.emit("rivet")
	_t.check("reset: run_started clears the prime", not _spawner().primed(e))
	_clear()


func _check_death_prune() -> void:
	_seat("primer_coil")
	var e := _spawn(Vector3(4, 0, 0))
	var id := e.get_instance_id()
	_hit(e, "runner", "weapon")
	_t.check("death: primed before the kill", _spawner()._primed.has(id))
	_spawner().strike(e, "runner", 100000.0, "", "weapon")
	_t.check("death: the weapon strike killed it", e.is_dead())
	_t.check("death: the kill erases the prime", not _spawner()._primed.has(id))
	_clear()


func _check_attempt_reset() -> void:
	_seat("primer_coil")
	var e := _spawn(Vector3(4, 0, 0))
	_hit(e, "runner", "weapon")
	_t.check("attempt: primed before the attempt", _spawner().primed(e))
	_spawner()._start_attempt()
	_t.check("attempt: a new attempt clears the prime", not _spawner().primed(e) and _spawner()._primed.is_empty())
	_clear()
