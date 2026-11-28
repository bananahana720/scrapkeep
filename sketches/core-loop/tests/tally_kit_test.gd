extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const Augments := preload("res://src/movement/augments.gd")
const Achievements := preload("res://src/core/achievements.gd")
const Weapons := preload("res://src/combat/weapons.gd")
const SpeedTier := preload("res://src/core/speed_tier.gd")
const Audio := preload("res://src/presentation/audio.gd")
const Bank := preload("res://src/presentation/sfx_bank.gd")
const Synth := preload("res://src/presentation/synth.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const Rows := preload("res://src/presentation/rows.gd")
const Hitscan := preload("res://src/combat/hitscan.gd")
const T := preload("res://tests/support/t.gd")

# Tally's kit through the real game (calm, stage 1): the class row, pressure that time never
# refills, the bar, Gather Plate, an invalid aim, a dry slot-1 press, the ledger clip, Balance
# Due's speed scaling, the pressure restores, no Warden shatter from a card or an arc, the
# flywheel surge and the stamp landing.
# Re-pinned 2026-10-10 for the skill bar (design-v3/SKILL-BAR.md section 1, wave P-B unit B1).
# Re-pinned 2026-10-11 for wave P-C unit PC-TALLY (design-v3/pilots/tally.md sections 2, 9, 10):
# Gather Plate leaves the pressure pool for its own 6.0 s cooldown, the ledger clip (slot 3)
# pays 1 pressure per clip on its own 8.0 s cooldown, a dry slot-1 press answers
# verb_failed("fire", "cooling"), pressing slot 3 with no line only loads (line_skill_loaded
# once, no line_skill_fired) and the bite fires it exactly once, the bite inside 4.0 s clips and
# the load expires by 4.01 s, a world latch plants a clip post that clips the first 3 passers
# within 4 m plus the reel burst, the arc pays the chain multiplier stored at the cast, an arc
# fills a Warden's posture and never takes a chunk, a boss takes half, and the surge pays 1
# pressure to the cap (A2-CRITIC). The bay, plate-return and echo cases retired: Plate Return is
# Q now (tests/tally_set_piece_test.gd). Measured 2026-10-11 on 4ae242b plus this unit:
# 83 checks including the count assertion (was 59 checks, no count assertion). A gather pick
# inside its cooldown is refused as verb_failed("select", "cooling") by the router.
# Re-pinned 2026-10-12 (PC-TALLY fix round): Balance Due now strikes through _ledger_hit, so a
# boss takes half of it as tally.md:377 asks; one new check. Measured 84 checks (was 83).
# 2026-10-12 (PC-TALLY round 3): four owned bank recipes and their admitted levels/keys.
# 2026-10-12 (PC-TALLY round 3): direct notes isolate the background bank transposition.
# 2026-10-12 (PC-TALLY round 5, coordinator ruling): four real-input plate counts and
# four event/aim waits raise the measured count from 93 to 101.
# 2026-10-12 (PC-TALLY round 6): readiness observes without steering, 101 to 102.
# 2026-10-12 (PC-TALLY round 6): wait begins before setup, 102 to 103.
const EXPECTED_CHECKS := 103

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
var _loaded: Array = []
var _fired: Array = []
var _expired: Array = []
var _aim_frame := -1
var _wait_start_frame := -1


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
		_t.eq("expected check count", _t.checks + 1, EXPECTED_CHECKS)
		quit(_t.verdict())
		return true
	var step: Array = _steps[_index]
	var waiting: bool = step[1] is Callable
	var started_wait := false
	if waiting:
		if _ticks == 0:
			_wait_start_frame = Engine.get_physics_frames()
			(step[0] as Callable).call()
			_ticks = 1
			started_wait = true
		if Engine.get_physics_frames() >= _wait_start_frame + 2 * Engine.physics_ticks_per_second:
			_t.check(String(step[4]), false, _balance_state())
			quit(_t.verdict())
			return true
	if Engine.get_process_frames() <= _aim_frame:
		return false
	var complete: bool
	if waiting:
		if not started_wait and step.size() > 3:
			(step[3] as Callable).call()
		complete = (step[1] as Callable).call()
		if not complete:
			return false
		_t.check(String(step[4]), true, _balance_state())
	else:
		if _ticks == 0:
			(step[0] as Callable).call()
		elif step.size() > 3:
			(step[3] as Callable).call()
		_ticks += 1
		complete = _ticks >= int(step[1])
	if complete:
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
	_game.events.line_skill_loaded.connect(func(id: String, seconds: float): _loaded.append([id, seconds]))
	_game.events.line_skill_fired.connect(func(id: String, _target: Node3D, _at: Vector3, on: String): _fired.append([id, on]))
	_game.events.line_skill_expired.connect(func(id: String): _expired.append(id))
	_check_cues()
	var tps := Engine.physics_ticks_per_second
	# Gather Plate casts in 0.3 s (FIELDS-AND-CASTS section 4), so its plate lands that much later.
	var cast := int(ceil(AbilityState.ABILITIES["gather_plate"]["cast"] * tps))
	_steps = [
		[_noop, 1, _check_row],
		[_pressure_start, 1, _pressure_spend],
		[_noop, 5 * tps, _check_pressure],
		[_bar_start, 2, _check_bar],
		[_noop, 1, _check_cooldowns],
		[_gather_start, 2 + cast, _gather_planted],
		[_noop, tps, _check_gather],
		[_noop, 1, _gather_again_press],
		[_noop, 2, _check_gather_again],
		# The camera takes a new pitch on the next tick, so each aimed press waits one step.
		[_invalid_start, 2, _invalid_press],
		[_noop, 2, _check_invalid],
		[_invalid_tap_start, 2, _invalid_tap_press],
		[_noop, 2, _check_invalid_tap],
		[_dry_start, 2, _dry_press],
		[_noop, 2, _check_dry],
		[_link_start, 2, _link_press],
		[_noop, 2, _link_bite],
		[_noop, 2, _check_link],
		[_clip_start, 1, _check_clip_direct],
		[_post_start, 1, _check_post],
		[_load_start, 1, _check_load_timing],
		[_warden_arc_start, 1, _check_warden_arc],
		[_balance_start, _balance_aim_ready, _balance_press, _noop, "stationary Balance Due has a ready enemy aim"],
		[_noop, _balance_shot_arrived, _balance_rest, _noop, "stationary Balance Due publishes shot_fired once"],
		[_balance_fast, _balance_aim_ready, _balance_fast_press, _noop, "moving Balance Due has a ready enemy aim"],
		[_noop, _balance_shot_arrived, _check_balance, _noop, "moving Balance Due publishes shot_fired once"],
		[_restore_start, 1, _check_contact_restores],
		# The spawn slope is not flat: the ball leaves the ground on bumps and the clock
		# pauses there, so the roll runs 2.6 s, under two restores' worth of time.
		[_roll_start, int(2.6 * tps), _check_roll, _keep_rolling],
		[_warden_start, 2, _check_warden],
		[_surge_start, 4, _noop, _keep_travel],
		[_surge_press, 2, _check_surge],
		[_surge_cap_start, 4, _noop, _keep_travel],
		[_surge_press, 2, _check_surge_cap],
		[_noop, 1, _check_shift_burst],
		[_stamp_start, 1, _check_stamp],
	]


func _check_cues() -> void:
	var audio := Audio.new()
	audio.setup(_game.ctx)
	audio.bake_now()
	audio.engine.key = 3
	for cue in ["tally_plate", "tally_clip", "tally_stroke", "tally_settle"]:
		var row: Dictionary = Audio.TALLY_CUES[cue]
		var sound := String(row["sound"])
		_t.check(cue + " resolves to its own bank recipe", sound == cue.trim_prefix("tally_") + "_tally" and Bank.has_recipe(sound)
			and not Bank.samples(sound).is_empty() and Bank.samples(sound) != Bank.samples("cog_tick"))
		audio.cue_log.clear()
		audio._tally_cue(cue, 0)
		var notes: Array = audio.cue_log.filter(func(n): return n[1] == sound and n[2] == "now")
		_t.check(cue + " admitted at trim plus priority in the live key", notes.size() == 1
			and is_equal_approx(float(notes[0][5]), Bank.trim_db(sound) + Audio.PRIORITY_DB[Rows.priority(String(row["kind"]))])
			and is_equal_approx(float(notes[0][4]), Harmony.ratio(audio.live_key())), str(notes))
	var clean := Bank.tally_recipe("clip_tally", 62)
	var old_transpose := Synth.score_transpose
	Synth.score_transpose = 3
	var shifted := Bank.tally_recipe("clip_tally", 62)
	var restored := Synth.score_transpose
	Synth.score_transpose = old_transpose
	_t.check("direct Tally notes isolate and restore the background bank transpose", clean == shifted and restored == 3)
	audio.free()


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
	_player.kit.drop_line("reset")
	_player.kit.rewind_left = 0.0
	_player.chain.reset()
	_player.abilities.refill()
	_combat.tally_kit.reset()
	_combat._line_load = {}
	_combat._bite_pending = false
	_combat._cooldown = 0.0
	_game.camera.snap(Vector3(0.0, 0.0, -1.0))
	_stage_pitch(0.0)


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


# A scripted body that stands still for direct calls: no AI, no physics.
func _still(enemy: Node3D) -> Node3D:
	_tough(enemy)
	enemy.set_physics_process(false)
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


func _arc_force(enemy: Node3D, from: int) -> float:
	var hits := _struck_by(enemy.get_instance_id(), "ledger", from)
	return float(hits[0][2]) if not hits.is_empty() else -1.0


# A process frame lets the camera apply pitch; Balance Due also waits for its enemy ray.
func _stage_pitch(value: float) -> void:
	_game.camera.pitch = value
	_aim_frame = Engine.get_process_frames()


# Pitch about the spring-arm pivot: rotating the lens moves its old aim origin.
func _aim_at(point: Vector3) -> void:
	var origin: Vector3 = _game.camera.global_position
	var flat := _planar(point - origin).length()
	_stage_pitch(atan2(point.y - origin.y, flat))


# Bar presses: slot 1 is a click at home; slot 2 (index 1) and slot 3 (index 2) pick, then click.
func _press_slot(index: int) -> void:
	if index == 0:
		_source.press = {"fire_pressed": true}
		return
	_source.press = {"slot_pick": index, "fire_pressed": true}


# Three still chasers in a row ahead, 2 m apart (the spawn faces a rise, so 3 m steps put the
# third past LINK_NEIGHBOUR_REACH in 3D), and a fourth outside the clip ring.
func _clip_row() -> Array:
	var aim := _aim_flat()
	var row: Array = []
	for i in 3:
		row.append(_still(_spawn("chaser", _ball_flat() + aim * (10.0 + 2.0 * i))))
	return row


# --- a. the row --------------------------------------------------------------------------

func _check_row() -> void:
	var def: Resource = ClassDef.by_id("tally")
	var ids := [def.weapon_id, def.movement_id, def.special_id, def.smash_id, def.line_id, def.ultimate_id]
	_t.eq("tally ability ids", ids, ["ledger_reader", "flywheel_surge", "gather_plate", "stamp_slam", "link_clips", "plate_return"])
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
	_t.check("the PLATE_RETURN_ gauge constants retired", not (Weapons as Script).get_script_constant_map().keys().any(
		func(k): return String(k).begins_with("PLATE_RETURN_")))


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


# --- c. the bar ----------------------------------------------------------------------------

func _bar_start() -> void:
	_as_class("tally")
	_source.press = {"slot_pick": 1}


func _check_bar() -> void:
	var ab = _player.abilities
	_t.eq("the bar: balance due on 1, gather plate on 2, ledger clip on 3, plate return on Q",
		[ab.cap(AbilityState.WEAPON, "cards", []), ab.id_of(AbilityState.SPECIAL), ab.id_of(AbilityState.LINE), ab.ultimate_id],
		[["balance_due"], "gather_plate", "link_clips", "plate_return"])
	_t.eq("slots 2 and 3 pay from their own charge, not slot 1's pressure",
		[ab.pool_of(AbilityState.SPECIAL), ab.pool_of(AbilityState.LINE)], [AbilityState.SPECIAL, AbilityState.LINE])
	_t.eq("the weapon slot shows balance due", ab.slot(AbilityState.WEAPON).icon, "ab_tally_balance")
	_t.eq("slot icons: gather and the ledger line", [ab.slot(AbilityState.SPECIAL).icon, ab.slot(AbilityState.LINE).icon],
		["ab_tally_gather", "ab_tally_line"])
	_t.eq("2 picks gather and costs no pressure", [ab.selected, _charges()], [AbilityState.SPECIAL, 3])


# Gather Plate refuses a pick for 6.0 s after a cast; the ledger clip for 8.0 s.
func _check_cooldowns() -> void:
	var ab = _player.abilities
	_t.eq("cooldowns 6.0 and 8.0", [ab.cooldown_of(AbilityState.SPECIAL), ab.cooldown_of(AbilityState.LINE)], [6.0, 8.0])
	ab.refill()
	ab.spend(AbilityState.SPECIAL)
	ab.spend(AbilityState.LINE)
	ab.tick(5.99)
	var mid := [ab.ready(AbilityState.SPECIAL), ab.ready(AbilityState.LINE)]
	ab.tick(0.02)
	var six := [ab.ready(AbilityState.SPECIAL), ab.ready(AbilityState.LINE)]
	ab.tick(2.0)
	var eight := [ab.ready(AbilityState.SPECIAL), ab.ready(AbilityState.LINE)]
	_t.eq("gather back at 6.0 s, the clip at 8.0 s", [mid, six, eight], [[false, false], [true, false], [true, true]])
	_t.eq("neither cast spent pressure", _charges(), 3)
	ab.refill()


# --- d. Gather ---------------------------------------------------------------------------

func _gather_start() -> void:
	_as_class("tally")
	_record = {"from": _struck.size(), "cue_from": _game.presentation.audio.cue_log_total}
	_press_slot(1)


func _gather_planted() -> void:
	_check_plate_cues("Gather Plate admits exactly one plate cue", 1)
	_t.check("gather plants the plate", not _combat.tally_kit.plate.is_empty(), str(_combat.tally_kit.plate))
	_t.eq("gather costs no pressure", _charges(), 3)
	_t.eq("gather spends slot 2's own charge", _player.abilities.ready(AbilityState.SPECIAL), false)
	_t.eq("the gather tap snaps the pick home", _player.abilities.selected, AbilityState.WEAPON)
	if _combat.tally_kit.plate.is_empty():
		return
	var at: Vector3 = _combat.tally_kit.plate["at"]
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
	var at: Vector3 = _combat.tally_kit.plate["at"]
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


# A second tap inside the 6 s cooldown: refused, the first plate stays.
func _gather_again_press() -> void:
	_record["cue_from"] = _game.presentation.audio.cue_log_total
	_fails.clear()
	_record["plate"] = _combat.tally_kit.plate.duplicate()
	_press_slot(1)


func _check_gather_again() -> void:
	_check_plate_cues("a cooling Gather Plate pick admits no plate cue", 0)
	# The pick is refused, so the click stays on slot 1 (Balance Due may fire there).
	_t.eq("a gather pick inside its cooldown is refused (cooling) and keeps the plate",
		[_fails.has(["select", "cooling"]), _combat.tally_kit.plate.get("until"), _player.abilities.selected],
		[true, _record["plate"].get("until"), AbilityState.WEAPON])


# --- e. an invalid aim -----------------------------------------------------------------

func _invalid_start() -> void:
	_as_class("tally")
	_stage_pitch(1.2)


func _invalid_press() -> void:
	_record = {"cooldown": _combat._cooldown}
	_press_slot(0)


func _check_invalid() -> void:
	_t.eq("an aim at the sky spends nothing", _charges(), 3)
	_t.check("an aim at the sky starts no recovery", _combat._cooldown <= float(_record["cooldown"]),
		"cooldown %.2f" % _combat._cooldown)
	_stage_pitch(0.0)


# A gather tap at the sky: refused, nothing spent, the pick kept.
func _invalid_tap_start() -> void:
	_as_class("tally")
	_stage_pitch(1.2)


func _invalid_tap_press() -> void:
	_record["cue_from"] = _game.presentation.audio.cue_log_total
	_fails.clear()
	_press_slot(1)


func _check_invalid_tap() -> void:
	_check_plate_cues("an invalid Gather Plate aim admits no plate cue", 0)
	_t.eq("a gather tap at the sky spends nothing and answers no_target",
		[_charges(), _fails.has(["fire", "no_target"]), _player.abilities.selected, _combat.tally_kit.plate.is_empty(),
			_player.abilities.ready(AbilityState.SPECIAL)],
		[3, true, AbilityState.SPECIAL, true, true])
	_stage_pitch(0.0)


# --- f. a dry slot-1 press ------------------------------------------------------------------

func _dry_start() -> void:
	_as_class("tally")
	var target := _tough(_spawn("chaser", _ball_flat() + _aim_flat() * 10.0))
	_record = {"t": target}
	_aim_at(target.global_position)


func _dry_press() -> void:
	_fails.clear()
	_set_charges(0)
	_record["from"] = _struck.size()
	_press_slot(0)


func _check_dry() -> void:
	var target: Node3D = _record["t"]
	_t.eq("a dry slot-1 press answers cooling, strikes nothing and spends nothing",
		[_fails.has(["fire", "cooling"]), _struck_by(target.get_instance_id(), "ledger", _record["from"]).size(), _charges()],
		[true, 0, 0])


# --- g. the ledger clip through the router ----------------------------------------------------

func _link_start() -> void:
	_as_class("tally")
	_record = {}
	var row := _clip_row()
	for i in 3:
		_record["c%d" % i] = row[i]
		_record["c%d_id" % i] = row[i].get_instance_id()
	_aim_at((_record["c0"] as Node3D).global_position)
	_loaded.clear()
	_fired.clear()


func _link_press() -> void:
	_record["cue_from"] = _game.presentation.audio.cue_log_total
	_set_charges(0)
	_press_slot(2)


# 3 then click with no line loads the clip; the next bite on c0 fires it.
func _link_bite() -> void:
	_check_plate_cues("loading Ledger Clip admits no plate cue", 0)
	_record["loaded"] = _loaded.duplicate()
	_record["fired_at_load"] = _fired.size()
	_record["pressure"] = _charges()
	_record["line_ready"] = _player.abilities.ready(AbilityState.LINE)
	var c0: Node3D = _record["c0"]
	_player.grapple_to(c0.global_position, Vector3.UP, c0)


func _check_link() -> void:
	_t.eq("3 then click only loads: line_skill_loaded once, nothing fired, no pressure",
		[_record["loaded"], _record["fired_at_load"], _record["pressure"]], [[["link_clips", 4.0]], 0, 0])
	_t.eq("the load spends slot 3's own charge", _record["line_ready"], false)
	_t.eq("the bite fires line_skill_fired exactly once, on the body", _fired, [["link_clips", "body"]])
	_player.release_grapple()
	var ids: Array = _combat.tally_kit.link_group.get("ids", [])
	_t.check("the ledger clip clips three", ids.size() == 3 and ids.has(_record["c0_id"]), "group %s" % [_combat.tally_kit.link_group])
	_t.eq("three clips pay three pressure", _charges(), 3)
	var from := _struck.size()
	_combat.strike(_record["c0"], "ram", 30.0)
	var arcs := [_struck_by(_record["c1_id"], "ledger", from).size(), _struck_by(_record["c2_id"], "ledger", from).size()]
	_t.eq("a direct hit arcs once to each other clip", arcs, [1, 1])
	_t.check("the group is spent", bool(_combat.tally_kit.link_group.get("spent", false)), str(_combat.tally_kit.link_group))
	from = _struck.size()
	_combat.strike(_record["c0"], "ram", 30.0)
	_t.eq("a second hit arcs nothing", _struck.slice(from).filter(func(s): return s[1] == "ledger").size(), 0)


# --- h. the clip, called directly: the cap and the stored chain multiplier --------------------

func _clip_start() -> void:
	_as_class("tally")
	_record = {"row": _clip_row()}


func _clip_once(combo: int, charges: int) -> float:
	var row: Array = _record["row"]
	_player.kit.drop_line("reset")
	_player.grapple_to(row[0].global_position, Vector3.UP, row[0])
	_player.chain.combo = combo
	_set_charges(charges)
	_combat._fire_line_skill("link_clips", 1.0)
	_player.release_grapple()
	var from := _struck.size()
	_combat.strike(row[0], "ram", 30.0)
	return _arc_force(row[1], from)


func _check_clip_direct() -> void:
	var plain := _clip_once(1, 2)
	_t.eq("three clips from 2 pressure stop at the cap", _charges(), 3)
	_t.near("the group stores the multiplier at the cast", float(_combat.tally_kit.link_group.get("mult", 0.0)), 1.0)
	var linked := _clip_once(3, 0)
	_t.near("a chain of 3 stores x1.6", float(_combat.tally_kit.link_group.get("mult", 0.0)), 1.6)
	_t.check("the arc pays the stored multiplier", plain > 0.0 and absf(linked / plain - 1.6) < 0.01,
		"plain %.2f linked %.2f" % [plain, linked])
	_player.chain.combo = 1
	_combat.tally_kit._link_from(_record["row"][0])
	_player.chain.reset()
	var from := _struck.size()
	_combat.strike(_record["row"][0], "ram", 30.0)
	_t.near("an arc never falls under the floor", _arc_force(_record["row"][1], from),
		maxf(Weapons.LINK_ARC_MIN, 30.0 * Weapons.LINK_ARC_SHARE))


# --- i. the clip post on a world latch -------------------------------------------------------

func _post_start() -> void:
	_as_class("tally")


func _check_post() -> void:
	var aim := _aim_flat()
	var side := aim.cross(Vector3.UP).normalized()
	var anchor: Vector3 = _combat.floor_at(_player.ball_position() + aim * 12.0 + Vector3.UP * 4.0)
	_player.grapple_to(anchor, Vector3.UP, null)
	var body: RigidBody3D = _player.body()
	body.linear_velocity = Vector3.ZERO
	_set_charges(0)
	_fired.clear()
	_combat._fire_line_skill("link_clips", 1.0)
	var burst := body.linear_velocity.dot((anchor - body.global_position).normalized())
	_t.near("a world latch adds the reel burst toward the anchor", burst, _combat.REEL_BURST, 0.1)
	_t.eq("a world latch plants the clip post", [_fired, _combat.tally_kit.clip_post.is_empty()], [[["link_clips", "world"]], false])
	var inside: Array = []
	for offset in [side * 1.0, -side * 1.5, aim * 1.0, -aim * 2.0]:
		inside.append(_still(_spawn("chaser", _planar(anchor) + offset)))
	var outside := _still(_spawn("chaser", _planar(anchor) + side * 8.0))
	_combat.tally_kit._step_clip_post()
	var ids: Array = _combat.tally_kit.link_group.get("ids", [])
	_t.eq("the post clips the first three passers and pays three", [ids.size(), _charges()], [Weapons.CLIP_POST_MAX, 3])
	_t.check("the post never clips outside its ring", not ids.has(outside.get_instance_id()))
	_t.check("a full post closes", _combat.tally_kit.clip_post.is_empty(), str(_combat.tally_kit.clip_post))
	# A fresh post that runs out its 4 s clips nothing after.
	_clear_enemies()
	_combat.tally_kit.link_clips_world(anchor, 1.0, 1.0)
	_combat._clock += Weapons.CLIP_POST_SECONDS + 0.01
	var late := _still(_spawn("chaser", _planar(anchor) + side * 1.0))
	_combat.tally_kit._step_clip_post()
	_t.check("a post past 4 s clips nothing", not (_combat.tally_kit.link_group.get("ids", []) as Array).has(late.get_instance_id())
		and _combat.tally_kit.clip_post.is_empty())
	_player.kit.drop_line("reset")


# --- j. the load: a bite inside 4.0 s clips; the load expires by 4.01 s ----------------------

func _load_start() -> void:
	_as_class("tally")
	_record = {"row": _clip_row()}


func _check_load_timing() -> void:
	var intent = _player.intent
	intent.clear()
	_loaded.clear()
	_fired.clear()
	_expired.clear()
	_combat._cast_line("link_clips", 1.0)
	_t.near("the load lasts 4.0 s", float(_combat.line_load().get("left", 0.0)), 4.0)
	_combat._step_line(intent, 3.99)
	var row: Array = _record["row"]
	_player.grapple_to(row[0].global_position, Vector3.UP, row[0])
	_combat._step_line(intent, 0.0)
	_t.eq("a bite at 3.99 s clips", [_fired, (_combat.tally_kit.link_group.get("ids", []) as Array).size()], [[["link_clips", "body"]], 3])
	_player.kit.drop_line("reset")
	_player.abilities.refill()
	_fired.clear()
	_combat._cast_line("link_clips", 1.0)
	_combat._step_line(intent, 4.01)
	_t.eq("the load expires by 4.01 s", [_combat.line_load().is_empty(), _expired, _fired], [true, ["link_clips"], []])


# --- k. arcs and a Warden: posture only, never a chunk; a boss takes half ------------------------

func _warden_arc_start() -> void:
	_as_class("tally")
	var aim := _aim_flat()
	_record = {"c": _still(_spawn("chaser", _ball_flat() + aim * 10.0)),
		"w": _spawn("warden", _ball_flat() + aim * 14.0),
		"d": _still(_spawn("chaser", _ball_flat() + aim * 12.0))}


func _group(enemies: Array) -> void:
	_combat.tally_kit.link_group = {"ids": enemies.map(func(e): return e.get_instance_id()), "until": _combat._clock + 4.0,
		"spent": false, "mult": 1.0}


func _check_warden_arc() -> void:
	var c: Node3D = _record["c"]
	var w: Node3D = _record["w"]
	var posture = w.get("_posture")
	if posture == null:
		_t.check("warden spawned with posture", false, "no posture")
		return
	var before: float = w.posture()
	_group([c, w])
	var from := _struck.size()
	_combat.strike(c, "ram", 30.0)
	_t.check("an arc fills a closed Warden's posture", w.posture() > before, "posture %.2f -> %.2f" % [before, w.posture()])
	posture.staggered = true
	posture.stagger_left = 5.0
	posture.ram_shatters = true
	var chunks: int = w.chunks_left()
	_group([c, w])
	_combat.strike(c, "ram", 30.0)
	_t.eq("an arc never takes a chunk from an open core", w.chunks_left(), chunks)
	_t.check("both arcs reached the warden", _struck_by(w.get_instance_id(), "ledger", from).size() >= 1)
	# A boss takes half of every Tally source.
	var boss := _boss(_player.ball_position() + _aim_flat() * 16.0)
	var d: Node3D = _record["d"]
	_group([c, d])
	from = _struck.size()
	_combat.strike(c, "ram", 30.0)
	var plain := _arc_force(d, from)
	_group([c, boss])
	from = _struck.size()
	var hp_before: float = float(boss.hp)
	_combat.strike(c, "ram", 30.0)
	var boss_took := hp_before - float(boss.hp)
	_t.check("an arc on a boss deals half", plain > 0.0 and absf(boss_took - plain * 0.5) <= plain * 0.05,
		"plain %.2f boss %.2f" % [plain, boss_took])
	# Balance Due on a boss deals half of its plain damage (tally.md:377).
	_set_charges(1)
	hp_before = float(boss.hp)
	var cast: bool = _combat.tally_kit.run_balance(boss.global_position, true)
	var due: float = float(_combat.tally_kit.last_card.get("damage", 0.0))
	boss_took = hp_before - float(boss.hp)
	_t.check("Balance Due on a boss deals half", cast and due > 0.0 and absf(boss_took - due * 0.5) <= due * 0.05,
		"due %.2f boss %.2f" % [due, boss_took])


# A boss piece as the set-piece tests build one: a plain enemy whose kind the roster calls a boss.
func _boss(at: Vector3) -> Node3D:
	var enemy: Node3D = preload("res://src/combat/enemy.gd").new()
	enemy.kind = "brindle_hull"
	enemy.weight = 1.0
	enemy.hp = 10000.0
	enemy.max_hp = 10000.0
	_game.add_child(enemy)
	enemy.add_to_group("enemy")
	enemy.global_position = at
	enemy.set_physics_process(false)
	return enemy


# --- l. Balance Due -------------------------------------------------------------------

func _balance_start() -> void:
	_t.eq("Balance Due wait starts before setup", _wait_start_frame, Engine.get_physics_frames())
	_as_class("tally")
	var target := _still(_spawn("chaser", _ball_flat() + _aim_flat() * 10.0))
	_record = {"t": target, "t_id": target.get_instance_id(), "from": _struck.size()}
	var before := [false, _game.camera.pitch, _aim_frame]
	var cooldown: float = _combat._cooldown
	_combat._cooldown = 1.0
	var ready := _balance_aim_ready()
	_t.eq("Balance Due readiness observes without steering", [ready, _game.camera.pitch, _aim_frame], before)
	_combat._cooldown = cooldown
	_aim_at(target.global_position)


func _balance_press() -> void:
	_record["shots_from"] = _shots.size()
	_record["fails_from"] = _fails.size()
	_record["from"] = _struck.size()
	_press_slot(0)


func _balance_force(from: int) -> float:
	var hits := _struck_by(_record["t_id"], "ledger", from)
	return float(hits[0][2]) if not hits.is_empty() else -1.0


func _balance_rest() -> void:
	_record["a"] = _balance_force(_record["from"])
	_t.eq("balance due spends one pressure", _charges(), 2)


func _balance_fast() -> void:
	_player.abilities.refill()
	_combat.weapon_driver.reset()
	_record["from"] = _struck.size()
	_aim_at((_record["t"] as Node3D).global_position)


func _balance_fast_press() -> void:
	_record["shots_from"] = _shots.size()
	_record["fails_from"] = _fails.size()
	var v := _aim_flat() * 30.0
	_player.body().linear_velocity = v
	_player.state.velocity = v
	_record["speed"] = _player.planar_velocity().length()
	_press_slot(0)


func _check_balance() -> void:
	# Re-cut E2-02 (PILOT-CADENCE.md §3.5): Balance Due scales as min(22.0, 8.0 + planar_speed),
	# reaching full 22.0 weight at 14 m/s cruise (gain 14.0 from standstill 8.0, capped at 22.0).
	var a: float = _record["a"]
	var b := _balance_force(_record["from"])
	var want: float = (Weapons.STAMP_MAX - Weapons.STAMP_BASE) * _combat.damage_mod(Weapons.LEDGER_READER)
	_t.check("balance due grows with speed", a > 0.0 and b > a and absf((b - a) - want) <= want * 0.1,
		"at rest %.2f, at %.1f m/s %.2f, gain %.2f, want %.2f" % [a, _record["speed"], b, b - a, want])


# --- m. restores ------------------------------------------------------------------------

func _restore_start() -> void:
	_as_class("tally")
	_record = {"t": _tough(_spawn("chaser", _ball_flat() + _aim_flat() * 15.0))}


func _check_contact_restores() -> void:
	var target: Node3D = _record["t"]
	_set_charges(0)
	_combat.strike(target, "ram", 30.0)
	_t.eq("a ram restores one pressure", _charges(), 1)
	_set_charges(0)
	_combat.tally_kit._restored_frame = {}
	_combat.strike(target, "ram", 30.0)
	_combat.strike(target, "ram", 30.0)
	_t.eq("two rams in one frame restore one", _charges(), 1)
	_set_charges(0)
	_game.events.harpoon_smashed.emit(target, target.global_position, 20.0)
	_t.eq("a harpoon smash restores one", _charges(), 1)


func _roll_start() -> void:
	_as_class("tally")
	_set_charges(1)
	_combat.tally_kit._roll_clock = 0.0
	_keep_rolling()


func _keep_rolling() -> void:
	var speed: float = SpeedTier.MULTIPLES[SpeedTier.CRUISE] * _game.ctx.tuning.f("cruise") * 2.0
	var v: Vector3 = _player.body().linear_velocity
	var flat := -_aim_flat() * speed
	_player.body().linear_velocity = Vector3(flat.x, v.y, flat.z)
	_player.state.velocity = Vector3(flat.x, v.y, flat.z)


func _check_roll() -> void:
	_t.eq("rolling past PRESSURE_ROLL_S at cruise restores one", _charges(), 2)


# --- n. no Warden shatter from a card ----------------------------------------------------

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
	_combat.tally_kit.run_balance(warden.global_position, true)
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


# --- o. the flywheel surge ----------------------------------------------------------------

func _surge_start() -> void:
	_as_class("tally")
	_clear_enemies()
	var travel := _aim_flat().cross(Vector3.UP).normalized()
	_record = {"travel": travel}
	_set_charges(1)
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
	_t.eq("surge pays one pressure", _charges(), int(_record["pressure"]) + Weapons.SURGE_PRESSURE)
	_t.check("surge spends the movement slot", not _player.abilities.ready(AbilityState.MOVEMENT), "movement still ready")


func _surge_cap_start() -> void:
	_surge_start()
	_set_charges(3)


func _check_surge_cap() -> void:
	_t.eq("a surge on full pressure stays at the cap", [_dashed, _charges()], [1, 3])


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


# --- p. the stamp ------------------------------------------------------------------------

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


func _check_plate_cues(label: String, expected: int) -> void:
	var cues: Array = _game.presentation.audio.cues_since(_record["cue_from"])
	var admitted := cues.filter(func(n): return n[1] == "plate_tally" and n[2] == "now")
	_t.eq(label, admitted.size(), expected)


func _balance_aim_ready() -> bool:
	var space: PhysicsDirectSpaceState3D = _game.get_world_3d().direct_space_state
	var sight := Hitscan.aim(space, _game.ctx.aim_origin(), _game.ctx.aim_forward(),
		_player.ball_position(), Weapons.CARD_REACH + _combat.AIM_SLACK)
	var aim: Dictionary = _combat.tally_kit.card_aim()
	if bool(sight["on_enemy"]) and bool(aim["valid"]) and _player.abilities.selected == AbilityState.WEAPON \
			and _player.abilities.ready(AbilityState.WEAPON) and _combat._cooldown <= 0.0:
		return true
	return false


func _balance_shot_arrived() -> bool:
	return _shots.slice(_record["shots_from"]) == ["balance_due"]


func _balance_state() -> String:
	return str({"wait_start": _wait_start_frame, "physics_frame": Engine.get_physics_frames(),
		"deadline": _wait_start_frame + 2 * Engine.physics_ticks_per_second,
		"aim": _combat.tally_kit.card_aim(), "selected": _player.abilities.selected,
		"ready": _player.abilities.ready(AbilityState.WEAPON), "charges": _charges(),
		"cooldown": _combat._cooldown, "forward": _game.ctx.aim_forward(),
		"shots": _shots.slice(_record.get("shots_from", _shots.size())),
		"refusals": _fails.slice(_record.get("fails_from", _fails.size()))})
