extends SceneTree

# Rule: a seated Ram Prow shoves a rammed foe out of its wind-up whatever its weight, once
# per foe per PROW_STAGGER s, and leaves posture fighters alone. A seated Brace Spring is
# armed by a ram that deals damage; the next weapon volley inside SPRING_WINDOW deals
# SPRING_MULT and disarms it. Item procs neither take nor spend it. Owned but unseated
# pieces do nothing, a new attempt or a new run clears both, and a kill drops the foe's entry.

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Companion := preload("res://src/core/companion.gd")
const Combat := preload("res://src/combat/combat.gd")
const Chaser := preload("res://src/combat/chaser.gd")
const T := preload("res://tests/support/t.gd")

const RAM := 20.0

var _t := T.new("companion_ram_test")
var _game
var _ticks := 0
var _spawned: Array = []
var _weapon := ""
# The wind-up pair struck on one tick and read two ticks later.
var _seated_chaser: Node3D
var _unseated_chaser: Node3D
var _unseated_knocks := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_ticks += 1
	if _ticks == 1:
		_setup()
		return false
	if _ticks < 12:
		return false
	if _ticks == 12:
		_check_guard()
		_strike_windups()
		return false
	if _ticks < 14:
		return false
	_read_windups()
	_check_heavy()
	_check_once_per_window()
	_check_posture()
	_check_spring_pays_once()
	_check_spring_window()
	_check_item_proc()
	_check_deflected()
	_check_mixed_pair()
	_check_reset()
	_check_death_prune()
	_check_run_reset()
	quit(_t.verdict())
	return true


func _setup() -> void:
	var ctx = _game.ctx
	ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.run.set_max_hp(99999.0)
	var spawn: Vector3 = ctx.terrain.spawn_point(1)
	var anchor := Vector3(spawn.x, ctx.terrain.height(spawn.x, spawn.z) + 1.05, spawn.z)
	_game.player.reset_to(anchor)
	_game.player.body().global_position = anchor


func _spawner():
	return _game.ctx.spawner


func _spawn(kind: String, offset: Vector3) -> Node3D:
	var spot: Vector3 = _game.player.ball_position() + offset
	var e: Node3D = _spawner().spawn_enemy(kind, _game.ctx.terrain.drop_point(spot.x, spot.z, 2.4))
	_spawned.append(e)
	if e != null and e.get("hp") != null and kind == "chaser":
		e.hp = 99999.0
		e.max_hp = 99999.0
	return e


func _clear() -> void:
	for e in _spawned:
		if is_instance_valid(e):
			e.remove_from_group("enemy")
			e.queue_free()
	_spawned.clear()


# Seats `pair` from a real Companion; `extra` pieces are owned but left unseated.
func _seat(pair: Array, extra: Array = []) -> void:
	var c := Companion.new()
	for id in pair + extra:
		c.acquire(id)
	_t.eq("assemble %s" % [pair], c.assemble(pair), "")
	var doc: Dictionary = c.to_dict()
	for id in pair:
		_t.check("seated %s" % id, (doc["sockets"] as Array).has(id))
	for id in extra:
		_t.check("owned %s unseated" % id, (doc["owned"] as Array).has(id) and not (doc["sockets"] as Array).has(id))
	_game.ctx.run.companion = doc
	# A spring armed by an earlier check would leak into this one.
	_spawner()._spring_until = -1.0


func _windup(e: Node3D) -> void:
	e._begin_windup(e._flat_to_ball())


func _check_guard() -> void:
	_weapon = _spawner().active_weapon()
	_t.check("guard: active weapon has a pattern", _spawner()._patterns.has(_weapon), _weapon)


func _strike_windups() -> void:
	_seat(["ram_prow", "escape_vent"])
	_seated_chaser = _spawn("chaser", Vector3(0, 0, -4))
	_windup(_seated_chaser)
	_t.eq("interrupt: chaser winding up", _seated_chaser.state_name(), "windup")
	_spawner().strike(_seated_chaser, "ram", RAM)
	_t.check("interrupt: prow staggered", _spawner().prow_staggered(_seated_chaser))

	_seat(["ram_spring", "escape_vent"], ["ram_prow"])
	_unseated_chaser = _spawn("chaser", Vector3(0, 0, 4))
	_windup(_unseated_chaser)
	_unseated_knocks = _unseated_chaser.knocks
	_spawner().strike(_unseated_chaser, "ram", RAM)
	_t.check("control: unseated prow not staggered", not _spawner().prow_staggered(_unseated_chaser))


func _read_windups() -> void:
	_t.check("interrupt: wind-up broken", _seated_chaser.state_name() != "windup", _seated_chaser.state_name())
	_t.eq("control: still winding up", _unseated_chaser.state_name(), "windup")
	_t.eq("control: knocks unchanged", _unseated_chaser.knocks, _unseated_knocks)
	_clear()


func _check_heavy() -> void:
	_seat(["ram_prow", "escape_vent"])
	var e := _spawn("chaser", Vector3(0, 0, -4))
	e.weight = 3.0
	_spawner().strike(e, "ram", RAM)
	_t.check("heavy: knocked past INTERRUPT", e._knocked_speed() >= Chaser.INTERRUPT, str(e._knocked_speed()))
	_clear()


func _check_once_per_window() -> void:
	_seat(["ram_prow", "escape_vent"])
	var e := _spawn("chaser", Vector3(0, 0, -4))
	var before: int = e.knocks
	_spawner().strike(e, "ram", RAM)
	_spawner()._clock += 0.1
	_spawner().strike(e, "ram", RAM)
	_t.eq("window: two rams 0.1 s apart knock once", e.knocks - before, 1)
	_spawner()._clock += Combat.PROW_STAGGER
	_spawner().strike(e, "ram", RAM)
	_t.eq("window: a ram after the window knocks again", e.knocks - before, 2)
	_clear()


func _check_posture() -> void:
	_seat(["ram_prow", "escape_vent"])
	var w: Node3D = _spawn("warden", Vector3(8, 0, 0))
	if w == null or not w.has_method("staggered"):
		print("[posture] warden spawn has no staggered() headless; check skipped")
		_clear()
		return
	_spawner().strike(w, "ram", RAM)
	_t.check("posture: warden not prow-staggered", not _spawner().prow_staggered(w))
	_clear()


func _new_bolt_damages(source := "weapon") -> Array:
	_spawner().bolts.clear()
	_spawner()._fire(_weapon, source)
	var out := []
	for bolt in _spawner().bolts._bolts:
		out.append(float(bolt["damage"]))
	_spawner().bolts.clear()
	return out


func _arm() -> Node3D:
	var e := _spawn("chaser", Vector3(0, 0, -4))
	_spawner().strike(e, "ram", RAM)
	return e


func _check_spring_pays_once() -> void:
	_seat(["ram_spring", "escape_vent"])
	var baseline := _new_bolt_damages()
	_t.check("spring: baseline volley has bolts", not baseline.is_empty())
	_t.check("spring: baseline unsprung", not bool(_spawner().last_shot.get("sprung", true)))
	_arm()
	_t.check("spring: landed ram arms", _spawner().spring_armed())
	var sprung := _new_bolt_damages()
	_t.check("spring: next shot sprung", bool(_spawner().last_shot.get("sprung", false)))
	_t.eq("spring: same bolt count", sprung.size(), baseline.size())
	for i in sprung.size():
		_t.near("spring: bolt %d x%s" % [i, Combat.SPRING_MULT], sprung[i], baseline[0] * Combat.SPRING_MULT, 1e-4)
	_t.check("spring: disarmed after paying", not _spawner().spring_armed())
	var after := _new_bolt_damages()
	_t.check("spring: following shot unsprung", not bool(_spawner().last_shot.get("sprung", true)))
	_t.near("spring: following shot at baseline", after[0], baseline[0], 1e-4)
	_clear()


func _check_spring_window() -> void:
	_seat(["ram_spring", "escape_vent"])
	_arm()
	_spawner()._clock += Combat.SPRING_WINDOW + 0.1
	_new_bolt_damages()
	_t.check("window: shot after SPRING_WINDOW unsprung", not bool(_spawner().last_shot.get("sprung", true)))
	_clear()


func _check_item_proc() -> void:
	_seat(["ram_spring", "escape_vent"])
	_arm()
	_new_bolt_damages("item_proc")
	_t.check("item proc: not sprung", not bool(_spawner().last_shot.get("sprung", true)))
	_t.check("item proc: spring still armed", _spawner().spring_armed())
	_spawner()._spring_until = -1.0
	_clear()


func _check_deflected() -> void:
	_seat(["ram_spring", "escape_vent"])
	var e := _spawn("chaser", Vector3(0, 0, -4))
	_spawner().heft_override = 0.0
	var dealt: float = _spawner().resolve(e, "ram", RAM)["dealt"]
	_spawner().strike(e, "ram", RAM)
	_spawner().heft_override = -1.0
	_t.near("deflected: ram dealt 0", dealt, 0.0, 0.0)
	_t.check("deflected: zero-damage ram does not arm", not _spawner().spring_armed())
	_clear()


func _check_mixed_pair() -> void:
	_seat(["ram_prow", "primer_coil"])
	var e := _spawn("chaser", Vector3(0, 0, -4))
	var before: int = e.knocks
	_spawner().strike(e, "ram", RAM)
	_t.check("mixed: prow staggers", _spawner().prow_staggered(e))
	_t.eq("mixed: prow knocks once", e.knocks - before, 1)
	_t.check("mixed: spring not armed", not _spawner().spring_armed())
	_clear()


func _check_reset() -> void:
	_seat(["ram_spring", "escape_vent"])
	_arm()
	_t.check("reset: armed before the attempt", _spawner().spring_armed())
	_spawner()._start_attempt()
	_t.check("reset: new attempt disarms", not _spawner().spring_armed())


func _check_death_prune() -> void:
	_seat(["ram_prow", "escape_vent"])
	var e := _spawn("chaser", Vector3(0, 0, -4))
	var id := e.get_instance_id()
	_spawner().strike(e, "ram", RAM)
	_t.check("death: prow stagger recorded", _spawner()._prow_until.has(id))
	e.take_damage(float(e.hp) + 1.0)
	_t.check("death: the kill erases the stagger", e.is_dead() and not _spawner()._prow_until.has(id))
	_clear()


func _check_run_reset() -> void:
	_seat(["ram_prow", "escape_vent"])
	var e := _spawn("chaser", Vector3(0, 0, -4))
	_spawner().strike(e, "ram", RAM)
	_t.check("run: staggered before run_started", _spawner().prow_staggered(e))
	_game.events.run_started.emit("rivet")
	_t.check("run: run_started clears the stagger", not _spawner().prow_staggered(e) and _spawner()._prow_until.is_empty())
	_clear()
