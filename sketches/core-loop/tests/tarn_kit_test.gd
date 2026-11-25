extends SceneTree

# 2026-10-11 (PC-TARN): case a reads six kit ids after Claw Drag and Redjaw Rend replace the placeholders.
# 2026-10-11 (PC-TARN ruling 3): loaded casts wait for a bite before line_skill_fired; expected 33 checks.

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const AugmentKit := preload("res://src/movement/augment_kit.gd")
const Augments := preload("res://src/movement/augments.gd")
const Achievements := preload("res://src/core/achievements.gd")
const Weapons := preload("res://src/combat/weapons.gd")
const T := preload("res://tests/support/t.gd")

# Tarn's claw kit through the real game (calm, stage 1): the class row, the fitted
# movement kit, the claw sweep's short reach, the claw pull, the clamp ring and its
# bonus on claw sweeps, and the rend landing's inward pull; a clamp that kills leaves no entry, and a new attempt clears the clamp and exposure maps.

var _t := T.new("tarn_kit_test")
var _game
var _combat
var _player
var _source := Intent.Scripted.new()
var _steps := []
var _index := 0
var _ticks := 0
var _booted := false
var _record := {}
var _struck: Array = []
var _shots: Array = []
var _dashed := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	if not _booted:
		_boot()
		return false
	if _index >= _steps.size():
		_t.eq("expected check count", _t.checks + 1, 33)
		quit(_t.verdict())
		return true
	var step: Array = _steps[_index]
	if _ticks == 0:
		(step[0] as Callable).call()
	_ticks += 1
	if _ticks >= int(step[1]):
		(step[2] as Callable).call()
		_index += 1
		_ticks = 0
	return false


func _boot() -> void:
	_booted = true
	_game.ctx.calm = true
	_game.player.source = _source
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_combat = _game.combat
	_player = _game.player
	_game.events.enemy_struck.connect(func(enemy: Node3D, kind: String, force: float): _struck.append([enemy.get_instance_id(), kind, force]))
	_game.events.shot_fired.connect(func(weapon_id: String, _from: Vector3, _to: Vector3): _shots.append(weapon_id))
	_game.events.dashed.connect(func(_dir: Vector3): _dashed += 1)
	_steps = [
		[_noop, 1, _check_row],
		[_noop, 1, _check_kit],
		[_reach_start, 54, _reach_release],
		[_noop, 20, _check_reach],
		[_noop, 1, _check_top_hit],
		# The press is set at the start of the step's first frame and the check runs at the start of the next, one game physics tick later.
		[_pull_start, 2, _pull_check],
		[_pull_again, 2, _check_pull_again],
		[_clamp_start, 81, _clamp_release],
		[_noop, 2, _check_clamp],
		[_bonus_start, 20, _bonus_release],
		[_noop, 72, _bonus_clamp],
		[_bonus_fire, 20, _bonus_release],
		[_noop, 20, _check_bonus],
		[_rend_start, 1, _check_rend],
		[_clamp_kill_start, 1, _check_clamp_kill],
		[_noop, 1, _check_attempt_clear],
		[_noop, 1, _check_line_event],
	]


func _noop() -> void:
	pass


func _as_class(id: String) -> void:
	var def: Resource = ClassDef.by_id(id)
	_game.run.class_def = def
	_player.fit_class(def)
	_clear_enemies()
	_source.hold = {}
	_source.press = {}
	var at: Vector3 = _game.ctx.terrain.spawn_point(1)
	_player.reset_to(at)
	_player.body().global_position = at
	_player.abilities.refill()
	_game.camera.snap(Vector3(0.0, 0.0, -1.0))
	_game.camera.pitch = 0.0


func _clear_enemies() -> void:
	for enemy in _game.get_tree().get_nodes_in_group("enemy"):
		enemy.remove_from_group("enemy")
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		enemy.queue_free()


func _spawn(kind: String, flat: Vector3) -> Node3D:
	var ground: float = _game.ctx.terrain.height(flat.x, flat.z)
	return _combat.spawn_enemy(kind, Vector3(flat.x, ground + 1.5, flat.z))


func _ball_flat() -> Vector3:
	var b: Vector3 = _player.ball_position()
	return Vector3(b.x, 0.0, b.z)


func _aim_flat() -> Vector3:
	var dir: Vector3 = _game.ctx.aim_forward()
	dir.y = 0.0
	return dir.normalized() if dir.length_squared() > 0.0001 else Vector3.FORWARD


func _planar(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


# Planar knock the enemy is carrying right now, pointed at `toward`: > 0 means inward.
# Read instead of velocity, which a chaser already points at the ball on its own.
func _knock_toward(enemy: Node3D, toward: Vector3) -> float:
	var knock: Vector3 = _planar(enemy.get("_knock"))
	var inward := _planar(toward - enemy.global_position)
	if knock.length() < 0.01 or inward.length() < 0.01:
		return 0.0
	return knock.normalized().dot(inward.normalized())


func _struck_by(id: int, kind: String, from := 0) -> Array:
	return _struck.slice(from).filter(func(s): return s[0] == id and s[1] == kind)


# --- a. the row --------------------------------------------------------------------

func _check_row() -> void:
	var def: Resource = ClassDef.by_id("tarn")
	var ids := [def.weapon_id, def.movement_id, def.special_id, def.smash_id, def.line_id, def.ultimate_id]
	_t.eq("tarn ability ids", ids, ["claw_sweep", "claw_pull", "clamp", "rend_slam", "claw_drag", "redjaw_rend"])
	_t.eq("tarn species", def.species, "tiger")
	var text := "%s %s %s %s %s %s %s %s %s %s %s" % [def.display_name, def.role, def.species, def.pitch, def.bible_home,
		def.synergy_hooks, ids, def.color, def.shape, def.motif, def.sound]
	_t.check("no placeholder in the row", not text.to_lower().contains("placeholder") and not ids.has("line_reel") and not ids.has("ult_default"), text)
	_t.check("every ability row exists", ids.all(func(id): return AbilityState.ABILITIES.has(id)), str(ids))
	_t.eq("tarn is not a starter", def.starter, false)
	_t.eq("brindle_routed unlocks tarn", Achievements.ROWS["brindle_routed"]["reward"].get("pilot", ""), "tarn")


# --- b. the fitted movement kit --------------------------------------------------------

func _check_kit() -> void:
	var kit := AugmentKit.new()
	kit.fit("claw_pull", "rend_slam")
	var on := []
	for spec in Augments.SPECS:
		if kit.on(spec["key"]):
			on.append(spec["key"])
	on.sort()
	_t.eq("claw pull kit fits exactly", on, ["claw_pull", "grapple", "slam"])
	_t.eq("rend flavour", kit.smash_flavour, "rend")


# --- c. the sweep's reach ------------------------------------------------------------------

func _reach_start() -> void:
	_as_class("tarn")
	var aim := _aim_flat()
	_record = {"near": _spawn("chaser", _ball_flat() + aim * 4.0), "far": _spawn("chaser", _ball_flat() + aim * 9.0)}
	_note_ids()
	_record["near_hp"] = float(_record["near"].hp)
	_record["far_hp"] = float(_record["far"].hp)
	_struck.clear()
	_shots.clear()
	_source.press = {"fire_pressed": true}
	_source.hold = {"fire_held": true}


func _reach_release() -> void:
	_source.hold = {}


func _check_reach() -> void:
	var near = _record["near"]
	var far = _record["far"]
	var near_hp: float = float(near.hp) if is_instance_valid(near) else 0.0
	_t.check("sweep lands close", near_hp < _record["near_hp"] and not _struck_by(_record["near_id"], "claw").is_empty(),
		"the 4 m chaser went %.1f -> %.1f with %d claw strikes" % [_record["near_hp"], near_hp, _struck_by(_record["near_id"], "claw").size()])
	_t.check("sweep names its weapon", not _shots.is_empty() and _shots.all(func(w): return w == "claw_sweep"), str(_shots))
	var far_hp: float = float(far.hp) if is_instance_valid(far) else -1.0
	_t.check("sweep is short", is_equal_approx(far_hp, _record["far_hp"]) and _struck_by(_record["far_id"], "claw").is_empty(),
		"the 9 m chaser kept %.1f of %.1f" % [far_hp, _record["far_hp"]])


# --- d. per-hit damage ---------------------------------------------------------------

func _check_top_hit() -> void:
	# Re-cut E2-01 (PILOT-CADENCE §1 & §3.4): Tarn's beat 3 standstill (43.0) keeps the
	# heaviest single baseline hit across Weapons.ALL (exceeding Cannon's 42.0 rail).
	var claw := Weapons.max_base_hit(Weapons.CLAW_SWEEP)
	var top := claw > 42.0
	for id in Weapons.ALL:
		if id != Weapons.CLAW_SWEEP and Weapons.max_base_hit(id) >= claw:
			top = false
	_t.check("claw_sweep has the highest per-hit damage of all weapons in Weapons.ALL", top,
		"claw %.1f vs %s" % [claw, Weapons.ALL.map(func(id): return Weapons.max_base_hit(id))])


# --- e. the claw pull ---------------------------------------------------------------------

func _pull_start() -> void:
	_as_class("tarn")
	_dashed = 0
	_source.press = {"movement_pressed": true}


func _pull_check() -> void:
	var floor_speed: float = _game.ctx.tuning.f("dash_impulse") * Augments.CLAW_PULL_SCALE
	var along := _planar(_player.state.velocity).dot(_aim_flat())
	_record = {"cooling": not _player.abilities.ready(AbilityState.MOVEMENT), "dashed": _dashed, "v": _player.state.velocity}
	_t.check("claw pull is fast", along >= floor_speed * 0.95,
		"planar speed along the aim %.1f, floor %.1f" % [along, floor_speed])
	_t.check("claw pull spends the slot", _record["cooling"], "movement ready %s" % _player.abilities.ready(AbilityState.MOVEMENT))
	_t.eq("claw pull publishes dashed once", _dashed, 1)


func _pull_again() -> void:
	_source.press = {"movement_pressed": true}


func _check_pull_again() -> void:
	_t.check("a second press while cooling does nothing", _dashed == 1 and not _player.abilities.ready(AbilityState.MOVEMENT),
		"dashed %d" % _dashed)


# --- f. the clamp -----------------------------------------------------------------------

func _clamp_start() -> void:
	_as_class("tarn")
	var aim := _aim_flat()
	_record = {"near": _spawn("chaser", _ball_flat() + aim * 3.0), "far": _spawn("chaser", _ball_flat() + aim * 10.0)}
	_note_ids()
	_record["near"].hp = 1000.0
	_record["near_hp"] = 1000.0
	_record["far_hp"] = float(_record["far"].hp)
	_record["special_before"] = float(_combat._ledger["by_source"].get("special", 0.0))
	_struck.clear()
	_combat._clamped = {}
	_source.press = {"special_pressed": true}
	_source.hold = {"special_held": true}


func _clamp_release() -> void:
	_source.hold = {}


func _check_clamp() -> void:
	var near = _record["near"]
	var far = _record["far"]
	var special_gain := float(_combat._ledger["by_source"].get("special", 0.0)) - float(_record["special_before"])
	var near_lost: float = float(_record["near_hp"]) - float(near.hp)
	# The special ledger's gain is exactly the near chaser's loss: the clamp's damage, as source special, landed on it.
	_t.check("clamp catches the near chaser", not _struck_by(_record["near_id"], "claw").is_empty() and special_gain > 0.0
			and absf(special_gain - near_lost) < 0.01 and _combat.last_burst.get("kind", "") == "clamp",
		"claw strikes %d, special ledger gain %.2f, near chaser lost %.2f, last burst %s" % [_struck_by(_record["near_id"], "claw").size(),
			special_gain, near_lost, _combat.last_burst.get("kind", "")])
	_t.check("clamp drags inward", _knock_toward(near, _player.ball_position()) > 0.5,
		"knock dot toward the ball %.2f" % _knock_toward(near, _player.ball_position()))
	_t.check("clamp leaves the far chaser", _struck_by(_record["far_id"], "claw").is_empty() and is_equal_approx(float(far.hp), _record["far_hp"]),
		"far strikes %d, hp %.1f" % [_struck_by(_record["far_id"], "claw").size(), float(far.hp)])
	_t.check("clamp state holds the near chaser", _combat._clamped.has(near.get_instance_id()), str(_combat._clamped.keys()))


# --- g. the clamp bonus on sweeps -----------------------------------------------------

func _bonus_start() -> void:
	_as_class("tarn")
	_combat._clamped = {}
	var target: Node3D = _spawn("chaser", _ball_flat() + _aim_flat() * 4.0)
	target.hp = 100000.0
	target.max_hp = 100000.0
	_record = {"target": target, "from": _struck.size()}
	_note_ids()
	_source.press = {"fire_pressed": true}
	_source.hold = {"fire_held": true}


func _bonus_release() -> void:
	_source.hold = {}


func _first_sweep(from: int) -> float:
	for s in _struck_by(_record["target_id"], "claw", from):
		return float(s[2])
	return -1.0


func _bonus_clamp() -> void:
	_record["a"] = _first_sweep(_record["from"])
	_combat._fire_clamp(1.0, _combat._clamp_geometry(1.0))
	_record["from"] = _struck.size()


func _bonus_fire() -> void:
	_source.press = {"fire_pressed": true}
	_source.hold = {"fire_held": true}


func _check_bonus() -> void:
	var a: float = _record["a"]
	var b := _first_sweep(_record["from"])
	var ratio := b / a if a > 0.0 else -1.0
	_t.near("clamped sweep bonus", ratio, Weapons.CLAMP_BONUS, 0.05)
	print("  sweep unclamped %.2f, clamped %.2f" % [a, b])


# --- h. the rend landing -------------------------------------------------------------

func _rend_start() -> void:
	_as_class("tarn")
	var aim := _aim_flat()
	var side := aim.cross(Vector3.UP).normalized()
	_record = {"a": _spawn("chaser", _ball_flat() + aim * 3.0), "b": _spawn("chaser", _ball_flat() + side * 7.0),
		"c": _spawn("chaser", _ball_flat() - aim * 12.0)}
	_note_ids()
	_record["c_hp"] = float(_record["c"].hp)


func _check_rend() -> void:
	var at: Vector3 = _player.ball_position()
	var c: Node3D = _record["c"]
	_record["c_from"] = _struck.size()
	_t.eq("tarn smash flavour", _player.kit.smash_flavour, "rend")
	_player._on_slammed(at, 30.0, 1.0)
	for key in ["a", "b"]:
		var enemy: Node3D = _record[key]
		_t.check("rend pulls %s inward" % key, _knock_toward(enemy, at) > 0.9,
			"knock dot toward the landing %.2f at %.1f m" % [_knock_toward(enemy, at), _planar(enemy.global_position - at).length()])
	_t.check("rend leaves the 12 m chaser", _planar(c.get("_knock")).length() < 0.01 and is_equal_approx(float(c.hp), _record["c_hp"])
			and _struck.slice(_record["c_from"]).all(func(s): return s[0] != _record["c_id"]),
		"knock %s, hp %.1f" % [c.get("_knock"), float(c.hp)])


# --- i. a clamp that kills, and the attempt reset ---------------------------------------

func _clamp_kill_start() -> void:
	_as_class("tarn")
	var aim := _aim_flat()
	var k := _spawn("chaser", _ball_flat() + aim * 3.0)
	k.hp = 1.0
	var s := _spawn("chaser", _ball_flat() - aim * 3.0)
	s.hp = 1000.0
	s.max_hp = 1000.0
	_record = {"k": k, "s": s}
	_note_ids()
	_combat._clamped = {}
	_record["from"] = _struck.size()


func _check_clamp_kill() -> void:
	_combat._fire_clamp(1.0, _combat._clamp_geometry(1.0))
	var k = _record["k"]
	var k_id: int = _record["k_id"]
	var s_id: int = _record["s_id"]
	var keys := str(_combat._clamped.keys())
	var dead: bool = not is_instance_valid(k) or k.is_dead()
	_t.check("a clamp kill leaves no clamp entry", not _struck_by(k_id, "claw", _record["from"]).is_empty() and dead
			and not _combat._clamped.has(k_id),
		"killed id %d, survivor id %d, clamped keys %s, dead %s" % [k_id, s_id, keys, str(dead)])
	_t.check("a clamp survivor stays clamped", _combat._clamped.has(s_id) and float(_combat._clamped.get(s_id, -INF)) > _combat._clock,
		"killed id %d, survivor id %d, clamped keys %s" % [k_id, s_id, keys])


func _check_attempt_clear() -> void:
	_combat._clamped[123] = _combat._clock + 5.0
	_combat._exposed[123] = {"until": _combat._clock + 5.0, "verb": "ram"}
	_combat._start_attempt()
	_t.check("an attempt clears the clamp and exposure maps", _combat._clamped.is_empty() and _combat._exposed.is_empty(),
		"clamped %d, exposed %d" % [_combat._clamped.size(), _combat._exposed.size()])


func _check_line_event() -> void:
	_as_class("tarn")
	_player.kit.drop_line("test")
	_player.kit.rewind_left = 0.0
	_combat._line_load = {}
	_combat._bite_pending = false
	var casts := []
	var fired := []
	var cast_listener := func(slot: String, id: String, _at: Vector3): casts.append([slot, id])
	var fire_listener := func(id: String, target: Node3D, at: Vector3, on: String):
		fired.append([id, target.get_instance_id() if target != null else 0, at, on, not _combat.get_node("TarnClaw").drag.is_empty()])
	_game.events.slot_cast.connect(cast_listener)
	_game.events.line_skill_fired.connect(fire_listener)
	_player.intent.clear()
	_player.intent.slot_pick = 2
	_player.intent.fire_pressed = true
	_player.intent.fire_held = true
	_player._route_slots(0.0)
	_combat._step_line(_player.intent, 0.0)
	_t.check("loading Claw Drag casts line without firing", casts == [["line", "claw_drag"]]
		and fired.is_empty() and not _combat.line_load().is_empty(), "casts %s, fired %s" % [casts, fired])
	_player.intent.clear()
	_combat._step_line(_player.intent, 3.99)
	_t.check("waiting load emits no line fire", fired.is_empty() and not _combat.line_load().is_empty())
	var target := _spawn("chaser", _ball_flat() + _aim_flat() * 20.0)
	var at: Vector3 = target.global_position
	_player.grapple_to(at, Vector3.UP, target)
	_combat._step_line(_player.intent, 0.0)
	_t.eq("bite fires Claw Drag after its callback starts the drag", fired, [["claw_drag", target.get_instance_id(), at, "body", true]])
	_combat._step_line(_player.intent, 0.0)
	_t.check("the consumed load fires once", fired.size() == 1 and _combat.line_load().is_empty())
	_game.events.slot_cast.disconnect(cast_listener)
	_game.events.line_skill_fired.disconnect(fire_listener)


# Strikes are kept by instance id, so a chaser the sweep kills can still be counted.
func _note_ids() -> void:
	for key in _record.keys():
		if _record[key] is Node3D:
			_record[key + "_id"] = (_record[key] as Node3D).get_instance_id()
