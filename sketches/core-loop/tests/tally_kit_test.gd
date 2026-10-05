extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const Augments := preload("res://src/movement/augments.gd")
const Achievements := preload("res://src/core/achievements.gd")
const Weapons := preload("res://src/combat/weapons.gd")
const SpeedTier := preload("res://src/movement/speed_tier.gd")
const T := preload("res://tests/support/t.gd")

# Tally's program-card kit through the real game (calm, stage 1): the class row, pressure
# that time never refills, bay selection, Gather, an invalid aim, Link and its arc,
# Balance Due's speed scaling, the pressure restores, no Warden shatter from a card, the
# flywheel surge, plate return and the stamp landing.

var _t := T.new("tally_kit_test")
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
var _fails: Array = []


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
		quit(_t.verdict())
		return true
	var step: Array = _steps[_index]
	if _ticks == 0:
		(step[0] as Callable).call()
	elif step.size() > 3:
		(step[3] as Callable).call()
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
	_game.events.verb_failed.connect(func(verb: String, reason: String, _at: Vector3): _fails.append([verb, reason]))
	var tps := Engine.physics_ticks_per_second
	_steps = [
		[_noop, 1, _check_row],
		[_pressure_start, 1, _pressure_spend],
		[_noop, 5 * tps, _check_pressure],
		[_bay_start, 2, _check_bay],
		[_gather_start, 2, _gather_planted],
		[_noop, tps, _check_gather],
		# The camera takes a new pitch on the next tick, so each aimed press waits one step.
		[_invalid_start, 2, _invalid_press],
		[_noop, 2, _check_invalid],
		[_link_start, 2, _link_press],
		[_noop, 2, _check_link],
		[_balance_start, 2, _balance_press],
		[_noop, 2, _balance_rest],
		[_noop, tps, _balance_fast],
		[_noop, 1, _balance_fast_press],
		[_noop, 2, _check_balance],
		[_restore_start, 1, _check_contact_restores],
		# The spawn slope is not flat: the ball leaves the ground on bumps and the clock
		# pauses there, so the roll runs 2.6 s, under two restores' worth of time.
		[_roll_start, int(2.6 * tps), _check_roll, _keep_rolling],
		[_warden_start, 2, _check_warden],
		[_surge_start, 4, _noop, _keep_travel],
		[_surge_press, 2, _check_surge],
		[_plate_none_start, 3, _check_plate_none],
		[_plate_start, int(0.6 * tps), _plate_release],
		[_noop, 3, _check_plate],
		[_plate_expire_start, int(0.6 * tps), _plate_release],
		[_noop, 3, _check_plate_expired],
		[_noop, 1, _check_shift_burst],
		[_stamp_start, 1, _check_stamp],
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
	_combat._reset_cards()
	_combat._cooldown = 0.0
	_game.camera.snap(Vector3(0.0, 0.0, -1.0))
	_game.camera.pitch = 0.0


func _clear_enemies() -> void:
	for enemy in _game.get_tree().get_nodes_in_group("enemy"):
		enemy.remove_from_group("enemy")
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		enemy.queue_free()


func _spawn(kind: String, flat: Vector3) -> Node3D:
	var ground: float = _game.ctx.terrain.height(flat.x, flat.z)
	var enemy: Node3D = _combat.spawn_enemy(kind, Vector3(flat.x, ground + 1.5, flat.z))
	return enemy


func _tough(enemy: Node3D) -> Node3D:
	enemy.max_hp = 100000.0
	enemy.hp = 100000.0
	return enemy


func _ball_flat() -> Vector3:
	var b: Vector3 = _player.ball_position()
	return Vector3(b.x, 0.0, b.z)


func _aim_flat() -> Vector3:
	var dir: Vector3 = _game.ctx.aim_forward()
	dir.y = 0.0
	return dir.normalized() if dir.length_squared() > 0.0001 else Vector3.FORWARD


func _planar(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _charges() -> int:
	return _player.abilities.slot(AbilityState.WEAPON).charges


func _set_charges(n: int) -> void:
	_player.abilities.slot(AbilityState.WEAPON).charges = n


func _struck_by(id: int, kind: String, from := 0) -> Array:
	return _struck.slice(from).filter(func(s): return s[0] == id and s[1] == kind)


func _knock_toward(enemy: Node3D, toward: Vector3) -> float:
	var knock: Vector3 = _planar(enemy.get("_knock"))
	var inward := _planar(toward - enemy.global_position)
	if knock.length() < 0.01 or inward.length() < 0.01:
		return 0.0
	return knock.normalized().dot(inward.normalized())


# Pitches the camera so the aim ray meets `point` (the stage-1 spawn faces a rise).
func _aim_at(point: Vector3) -> void:
	var origin: Vector3 = _game.ctx.aim_origin()
	var flat := _planar(point - origin).length()
	_game.camera.pitch = atan2(point.y - origin.y, flat)


func _press_card(card_bay: int) -> void:
	_source.press = {"bay_pick": card_bay, "fire_pressed": true}


# --- a. the row --------------------------------------------------------------------------

func _check_row() -> void:
	var def: Resource = ClassDef.by_id("tally")
	var ids := [def.weapon_id, def.movement_id, def.special_id, def.smash_id]
	_t.eq("tally ability ids", ids, ["ledger_reader", "flywheel_surge", "plate_return", "stamp_slam"])
	_t.eq("tally species", def.species, "pack rat")
	var text := "%s %s %s %s %s %s %s %s %s %s %s" % [def.display_name, def.role, def.species, def.pitch, def.bible_home,
		def.synergy_hooks, ids, def.color, def.shape, def.motif, def.sound]
	_t.check("no placeholder in the row", not text.to_lower().contains("placeholder"), text)
	_t.check("every ability row exists", ids.all(func(id): return AbilityState.ABILITIES.has(id)), str(ids))
	_t.eq("tally is not a starter", def.starter, false)
	_t.eq("ledger_balanced unlocks tally", Achievements.reward_of("ledger_balanced"), {"pilot": "tally"})
	_t.check("tally is not pending", not Achievements.PENDING_PILOTS.has("tally"), str(Achievements.PENDING_PILOTS))
	var pilots: Array = ClassDef.all().map(func(d): return d.id)
	_t.eq("achievements validate", Achievements.validate(Achievements.ROWS, Achievements.bus_signals(), pilots,
		preload("res://src/core/cosmetics.gd").ids()), [])
	var paint: Dictionary = preload("res://src/core/cosmetics.gd").row("paint_tally_cream")
	_t.check("tally owns a starter paint", paint.get("pilot", "") == "tally" and paint.get("starter", false) == true, str(paint))


# --- b. pressure ---------------------------------------------------------------------------

func _pressure_start() -> void:
	_as_class("tally")


func _pressure_spend() -> void:
	var s = _player.abilities.slot(AbilityState.WEAPON)
	_t.check("pressure starts at three", s.max_charges == 3 and s.charges == 3, "max %d charges %d" % [s.max_charges, s.charges])
	_player.abilities.spend(AbilityState.WEAPON)


func _check_pressure() -> void:
	_t.eq("five idle seconds refill no pressure", _charges(), 2)
	_player.abilities.refill()
	_t.eq("a stage refill fills pressure", _charges(), 3)


# --- c. bays ----------------------------------------------------------------------------

func _bay_start() -> void:
	_as_class("tally")
	_source.press = {"bay_pick": 2}


func _check_bay() -> void:
	_t.eq("bay pick 2 selects Balance Due", _combat.bay, 2)
	_t.eq("the weapon slot shows the loaded card", _player.abilities.slot(AbilityState.WEAPON).icon, "ab_tally_balance")
	_t.eq("selecting costs no pressure", _charges(), 3)


# --- d. Gather ---------------------------------------------------------------------------

func _gather_start() -> void:
	_as_class("tally")
	_record = {"from": _struck.size()}
	_press_card(0)


func _gather_planted() -> void:
	_t.check("gather plants the plate", not _combat.plate.is_empty(), str(_combat.plate))
	_t.eq("gather costs one pressure", _charges(), 2)
	if _combat.plate.is_empty():
		return
	var at: Vector3 = _combat.plate["at"]
	var side := _aim_flat().cross(Vector3.UP).normalized()
	var a := _tough(_spawn("chaser", _planar(at) + side * 2.0))
	var b := _tough(_spawn("chaser", _planar(at) - side * 3.5))
	_record["a"] = a
	_record["b"] = b
	_record["a_id"] = a.get_instance_id()
	_record["b_id"] = b.get_instance_id()
	_record["a_d"] = _planar(a.global_position - at).length()
	_record["b_d"] = _planar(b.global_position - at).length()
	# A miniboss takes knocks (enemy.knock counts them) but is never ordinary, so Gather
	# must leave it alone; a Warden or a vault ignores knock and would prove nothing.
	var boss := _tough(_spawn("miniboss", _planar(at) + _aim_flat() * 2.5))
	_record["boss"] = boss
	_record["boss_knocks"] = int(boss.knocks)
	_record["from"] = _struck.size()


func _check_gather() -> void:
	if not _record.has("a"):
		_t.check("gather pulled", false, "no plate")
		return
	var at: Vector3 = _combat.plate["at"]
	for key in ["a", "b"]:
		var enemy: Node3D = _record[key]
		var d := _planar(enemy.global_position - at).length()
		_t.check("gather pulls chaser %s toward the plate" % key, d < float(_record[key + "_d"]),
			"%.2f m -> %.2f m" % [_record[key + "_d"], d])
		_t.check("gather does no damage to %s" % key, is_equal_approx(float(enemy.hp), 100000.0)
			and _struck.slice(_record["from"]).all(func(s): return s[0] != _record[key + "_id"]), "hp %.1f" % float(enemy.hp))
	var boss: Node3D = _record["boss"]
	_t.check("gather never knocks the miniboss", int(boss.knocks) == int(_record["boss_knocks"]),
		"knocks %d -> %d" % [_record["boss_knocks"], boss.knocks])


# --- e. an invalid aim -----------------------------------------------------------------

func _invalid_start() -> void:
	_as_class("tally")
	_game.camera.pitch = 1.2


func _invalid_press() -> void:
	_record = {"cooldown": _combat._cooldown}
	_press_card(2)


func _check_invalid() -> void:
	_t.eq("an aim at the sky spends nothing", _charges(), 3)
	_t.check("an aim at the sky starts no recovery", _combat._cooldown <= float(_record["cooldown"]),
		"cooldown %.2f" % _combat._cooldown)
	_game.camera.pitch = 0.0


# --- f. Link and its arc --------------------------------------------------------------

func _link_start() -> void:
	_as_class("tally")
	var aim := _aim_flat()
	_record = {}
	for i in 3:
		# 2 m apart, not 3: the stage-1 spawn faces a steep rise, and 3 m steps put the
		# third chaser past LINK_NEIGHBOUR_REACH in 3D.
		var enemy := _tough(_spawn("chaser", _ball_flat() + aim * (10.0 + 2.0 * i)))
		_record["c%d" % i] = enemy
		_record["c%d_id" % i] = enemy.get_instance_id()
	_aim_at((_record["c0"] as Node3D).global_position)


func _link_press() -> void:
	_press_card(1)


func _check_link() -> void:
	var ids: Array = _combat.link_group.get("ids", [])
	_t.check("link clips three", ids.size() == 3 and ids.has(_record["c0_id"]), "group %s" % [_combat.link_group])
	var from := _struck.size()
	_combat.strike(_record["c0"], "ram", 30.0)
	var arcs := [_struck_by(_record["c1_id"], "ledger", from).size(), _struck_by(_record["c2_id"], "ledger", from).size()]
	_t.eq("a direct hit arcs once to each other clip", arcs, [1, 1])
	_t.check("the group is spent", bool(_combat.link_group.get("spent", false)), str(_combat.link_group))
	from = _struck.size()
	_combat.strike(_record["c0"], "ram", 30.0)
	_t.eq("a second hit arcs nothing", _struck.slice(from).filter(func(s): return s[1] == "ledger").size(), 0)


# --- g. Balance Due -------------------------------------------------------------------

func _balance_start() -> void:
	_as_class("tally")
	var target := _tough(_spawn("chaser", _ball_flat() + _aim_flat() * 10.0))
	_record = {"t": target, "t_id": target.get_instance_id(), "from": _struck.size()}
	_aim_at(target.global_position)


func _balance_press() -> void:
	_record["from"] = _struck.size()
	_press_card(2)


func _balance_force(from: int) -> float:
	var hits := _struck_by(_record["t_id"], "ledger", from)
	return float(hits[0][2]) if not hits.is_empty() else -1.0


func _balance_rest() -> void:
	_record["a"] = _balance_force(_record["from"])


func _balance_fast() -> void:
	_player.abilities.refill()
	_record["from"] = _struck.size()
	var v := _aim_flat() * 30.0
	_player.body().linear_velocity = v
	_player.state.velocity = v
	_aim_at((_record["t"] as Node3D).global_position)


func _balance_fast_press() -> void:
	_record["speed"] = _player.planar_velocity().length()
	_press_card(2)


func _check_balance() -> void:
	var a: float = _record["a"]
	var b := _balance_force(_record["from"])
	var want: float = Weapons.BALANCE_PER_SPEED * 30.0 * _combat._damage_mod(Weapons.LEDGER_READER)
	_t.check("balance due grows with speed", a > 0.0 and b > a and absf((b - a) - want) <= want * 0.1,
		"at rest %.2f, at %.1f m/s %.2f, gain %.2f, want %.2f" % [a, _record["speed"], b, b - a, want])


# --- h. restores ------------------------------------------------------------------------

func _restore_start() -> void:
	_as_class("tally")
	_record = {"t": _tough(_spawn("chaser", _ball_flat() + _aim_flat() * 15.0))}


func _check_contact_restores() -> void:
	var target: Node3D = _record["t"]
	_set_charges(0)
	_combat.strike(target, "ram", 30.0)
	_t.eq("a ram restores one pressure", _charges(), 1)
	_set_charges(0)
	_combat._restored_frame = {}
	_combat.strike(target, "ram", 30.0)
	_combat.strike(target, "ram", 30.0)
	_t.eq("two rams in one frame restore one", _charges(), 1)
	_set_charges(0)
	_game.events.harpoon_smashed.emit(target, target.global_position, 20.0)
	_t.eq("a harpoon smash restores one", _charges(), 1)


func _roll_start() -> void:
	_as_class("tally")
	_set_charges(1)
	_combat._roll_clock = 0.0
	_keep_rolling()


func _keep_rolling() -> void:
	var speed: float = SpeedTier.MULTIPLES[SpeedTier.CRUISE] * _game.ctx.tuning.f("cruise") * 2.0
	var v: Vector3 = _player.body().linear_velocity
	var flat := -_aim_flat() * speed
	_player.body().linear_velocity = Vector3(flat.x, v.y, flat.z)
	_player.state.velocity = Vector3(flat.x, v.y, flat.z)


func _check_roll() -> void:
	_t.eq("rolling past PRESSURE_ROLL_S at cruise restores one", _charges(), 2)


# --- i. no Warden shatter from a card ----------------------------------------------------

func _warden_start() -> void:
	_as_class("tally")
	var warden: Node3D = _spawn("warden", _ball_flat() + _aim_flat() * 14.0)
	_record = {"w": warden, "from": _struck.size()}


func _check_warden() -> void:
	var warden: Node3D = _record["w"]
	var posture = warden.get("_posture")
	if posture == null:
		_t.check("warden spawned with posture", false, "no posture")
		return
	posture.staggered = true
	posture.stagger_left = 5.0
	posture.staggers += 1
	var before: int = warden.chunks_left()
	_combat._run_balance(warden.global_position, true)
	_t.eq("balance due never shatters a chunk", warden.chunks_left(), before)
	var cruise: float = _game.ctx.tuning.f("cruise")
	_t.check("balance due reached the warden", not _struck_by(warden.get_instance_id(), "ledger", _record["from"]).is_empty(), "no ledger strike")
	# The alpha Warden cells turn ram_shatters off (a smash breaks the core there); turn it on
	# for this one Warden so a plain tier-2 ram proves the harness can break an open core.
	posture.staggered = true
	posture.stagger_left = 5.0
	posture.ram_shatters = true
	_combat.strike(warden, "ram", SpeedTier.MULTIPLES[posture.shatter_tier] * cruise * 1.05)
	_t.check("a tier-2 ram on the same open core shatters", warden.chunks_left() < before,
		"chunks %d -> %d" % [before, warden.chunks_left()])


# --- j. the flywheel surge ----------------------------------------------------------------

func _surge_start() -> void:
	_as_class("tally")
	_clear_enemies()
	var travel := _aim_flat().cross(Vector3.UP).normalized()
	_record = {"travel": travel, "pressure": _charges()}
	_keep_travel()


func _keep_travel() -> void:
	var v: Vector3 = _player.body().linear_velocity
	var travel: Vector3 = _record["travel"] * 5.0
	_player.body().linear_velocity = Vector3(travel.x, v.y, travel.z)


func _surge_press() -> void:
	_dashed = 0
	_record["pressure"] = _charges()
	_source.press = {"movement_pressed": true}


func _check_surge() -> void:
	var floor_speed: float = _game.ctx.tuning.f("dash_impulse") * Augments.SURGE_SCALE
	var along := _planar(_player.state.velocity).dot(_record["travel"])
	_t.check("surge drives along the travel", along >= floor_speed * 0.95, "along %.1f, floor %.1f" % [along, floor_speed])
	_t.eq("surge publishes dashed once", _dashed, 1)
	_t.eq("surge costs no pressure", _charges(), _record["pressure"])
	_t.check("surge spends the movement slot", not _player.abilities.ready(AbilityState.MOVEMENT), "movement still ready")


# --- k. plate return ----------------------------------------------------------------------

func _plate_none_start() -> void:
	_as_class("tally")
	_source.press = {"special_pressed": true}
	_source.hold = {"special_held": true}


func _check_plate_none() -> void:
	_source.hold = {}
	var gauge = _player.abilities.gauge(AbilityState.SPECIAL)
	_t.check("no plate, no gauge", not gauge.charging and _player.abilities.ready(AbilityState.SPECIAL),
		"charging %s ready %s" % [gauge.charging, _player.abilities.ready(AbilityState.SPECIAL)])


func _plate_start() -> void:
	_as_class("tally")
	var aim := _aim_flat()
	var ground: Vector3 = _combat._floor_at(_player.ball_position() + aim * 6.0 + Vector3.UP)
	_combat.plate = {"at": ground, "until": _combat._clock + 4.0}
	var target := _tough(_spawn("chaser", _ball_flat() + aim * 3.0))
	_record = {"t": target, "t_id": target.get_instance_id(), "from": _struck.size(),
		"special_before": float(_combat._ledger["by_source"].get("special", 0.0))}
	_source.press = {"special_pressed": true}
	_source.hold = {"special_held": true}


func _plate_release() -> void:
	_source.hold = {}


func _check_plate() -> void:
	var target: Node3D = _record["t"]
	var gain := float(_combat._ledger["by_source"].get("special", 0.0)) - float(_record["special_before"])
	_t.check("plate return strikes the chaser as a special", not _struck_by(_record["t_id"], "ledger", _record["from"]).is_empty()
			and gain > 0.0 and _combat.last_burst.get("kind", "") == "plate_return",
		"ledger strikes %d, special gain %.2f, last burst %s" % [_struck_by(_record["t_id"], "ledger", _record["from"]).size(), gain,
			_combat.last_burst.get("kind", "")])
	_t.check("plate return pulls toward the ball", _knock_toward(target, _player.ball_position()) > 0.5,
		"knock dot %.2f" % _knock_toward(target, _player.ball_position()))
	_t.check("the plate is back in the reader", _combat.plate.is_empty(), str(_combat.plate))


# The plate expires while the gauge fills: the release spends nothing and returns nothing.
func _plate_expire_start() -> void:
	_plate_start()
	_combat.plate["until"] = _combat._clock + 0.2
	_combat.last_burst = {}


func _check_plate_expired() -> void:
	_t.check("an expired plate spends no special", _player.abilities.ready(AbilityState.SPECIAL)
			and _combat.last_burst.get("kind", "") != "plate_return" and _struck_by(_record["t_id"], "ledger", _record["from"]).is_empty(),
		"ready %s last burst %s strikes %d" % [_player.abilities.ready(AbilityState.SPECIAL), _combat.last_burst.get("kind", ""),
			_struck_by(_record["t_id"], "ledger", _record["from"]).size()])


# --- Shift from the keyboard path ----------------------------------------------------------

func _check_shift_burst() -> void:
	for id in ["tarn", "tally"]:
		_as_class(id)
		_fails.clear()
		_player.intent.clear()
		_player.intent.shift_pressed = true
		_player._read_shift()
		_t.check("%s: Shift sets movement_pressed" % id, _player.intent.movement_pressed, "movement_pressed false")
		_t.check("%s: Shift plays no fail cue" % id, _fails.is_empty(), str(_fails))
		_player.intent.clear()


# --- l. the stamp ------------------------------------------------------------------------

func _stamp_start() -> void:
	_as_class("tally")
	var aim := _aim_flat()
	var side := aim.cross(Vector3.UP).normalized()
	for flat in [aim * 3.0, side * 4.0, -side * 5.0]:
		_tough(_spawn("chaser", _ball_flat() + flat))


func _check_stamp() -> void:
	_t.eq("tally smash flavour", _player.kit.smash_flavour, "stamp")
	var at: Vector3 = _player.ball_position()
	_set_charges(0)
	_player._on_slammed(at, 30.0, 1.0)
	_t.eq("three stamped contacts refill pressure to the cap", _charges(), 3)
	_clear_enemies()
	_tough(_spawn("chaser", _ball_flat() + _aim_flat() * 3.0))
	_set_charges(0)
	_player._on_slammed(at, 30.0, 1.0)
	_t.eq("one stamped contact restores one, with no plain slam point on top", _charges(), 1)

