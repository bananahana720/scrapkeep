extends SceneTree

# W47-C2: six Tier-1 common-part micro-mutations (SOUTHWEST-SONIC-MECHA-NORTHSTAR §4.3, REBASELINE §7).
# Checks table admission & Tier-1 budget integrity, then verifies each micro-mutation in live combat
# against a planted control without the part, plus attempt-boundary reset hygiene:
# 1. tread_plating:  +8% cruise + wall-carving refills Movement 25% faster
# 2. long_spool:     +30% harpoon range + grapple release grants 0.4 s air-steer surge
# 3. dash_vane:      +15% air dash + air-dashing through an enemy shell bats it back
# 4. loose_trigger:  +10% fire rate + landing a Skilled cadence window extends next window +25%
# 5. long_barrel:    +12% weapon range + hits past 20 m apply +15% knockback stagger
# 6. boost_coil:     -15% boost/dash CD + boosting through a Heft Destructible refreshes 50% CD

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Parts := preload("res://src/build/parts.gd")
const PartMutations := preload("res://src/build/part_mutations.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const Projectile := preload("res://src/combat/projectile.gd")
const WeaponDriver := preload("res://src/combat/weapon_driver.gd")
const Weapons := preload("res://src/combat/weapons.gd")
const T := preload("res://tests/support/t.gd")

const SIX := ["tread_plating", "long_spool", "dash_vane", "loose_trigger", "long_barrel", "boost_coil"]

var _t := T.new("parts_test")
var _game
var _combat
var _player
var _build
var _source := Intent.Scripted.new()


class StaggerSpy extends Node3D:
	var hp := 200.0
	var max_hp := 200.0
	var radius := 1.0
	var half_height := 1.0
	var weight := 1.0
	var plating := 0.0
	var knocks := 0
	var last_knock := 0.0
	var last_knock_dir := Vector3.ZERO
	var reacts: Array = []

	func is_dead() -> bool:
		return hp <= 0.0

	func take_damage(amount: float) -> float:
		var dealt := minf(hp, amount)
		hp -= dealt
		return dealt

	func knock(dir: Vector3, force: float) -> void:
		knocks += 1
		last_knock = force
		last_knock_dir = dir

	func react(kind: String, _dir: Vector3, _front: bool) -> void:
		reacts.append(kind)

	func flash() -> void:
		pass


func _initialize() -> void:
	_check_table()
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run.call_deferred()


func _sim(ticks: int) -> void:
	for _i in ticks:
		await physics_frame


func _set_parts(list: Array) -> void:
	_game.ctx.run.parts.assign(list)
	_build.effects.refresh(_game.ctx.run.parts)
	_combat.rebuild_patterns()


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_player = _game.player
	_player.source = _source
	_game.flow.press_start()
	_game.flow.choose_class(1) # Rivet (press cadence window on reload)
	await _sim(6)
	_combat = _game.ctx.spawner
	_build = _game.ctx.build

	await _check_tread_plating()
	await _check_long_spool()
	await _check_dash_vane()
	await _check_loose_trigger()
	await _check_long_barrel()
	await _check_boost_coil()
	await _check_reset_hygiene()

	_game.free()
	quit(_t.verdict())


func _check_table() -> void:
	var problems := PartMutations.micro_mutation_problems(Parts.CATALOGUE)
	_t.check("micro_mutation_problems", problems.is_empty(), "problems=%s" % [problems])
	_t.check("micro_mutation_count", PartMutations.MICRO_MUTATIONS.size() == 6,
		"size=%d" % PartMutations.MICRO_MUTATIONS.size())
	for pid in SIX:
		var cat: Dictionary = Parts.CATALOGUE.get(pid, {})
		_t.check("tier1_common_%s" % pid,
			String(cat.get("rarity", "")) == "common" and int(cat.get("tier", 0)) == 1,
			"rarity=%s tier=%s" % [cat.get("rarity", ""), cat.get("tier", "")])
		_t.check("has_micro_row_%s" % pid, not PartMutations.micro_mutation(pid).is_empty(), pid)
	_t.check("budget_tread", is_equal_approx(float(Parts.CATALOGUE["tread_plating"]["mods"]["cruise"]), 1.08), "cruise 1.08")
	_t.check("budget_spool", is_equal_approx(float(Parts.CATALOGUE["long_spool"]["mods"]["rope_range"]), 1.3), "rope_range 1.3")
	_t.check("budget_vane", is_equal_approx(float(Parts.CATALOGUE["dash_vane"]["mods"]["dash_impulse"]), 1.15), "dash_impulse 1.15")
	_t.check("budget_trigger", is_equal_approx(float(Parts.CATALOGUE["loose_trigger"]["mods"]["weapon_rate"]), 1.1), "weapon_rate 1.1")
	_t.check("budget_barrel", is_equal_approx(float(Parts.CATALOGUE["long_barrel"]["mods"]["weapon_range"]), 1.12), "weapon_range 1.12")
	_t.check("budget_coil", is_equal_approx(float(Parts.CATALOGUE["boost_coil"]["cooldown_scale"]), 0.85), "cooldown_scale 0.85")


func _check_tread_plating() -> void:
	# Control without tread_plating: boost_cooldown ticks at 1.0x while carving.
	_set_parts([])
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	_player.state.carving = true
	_player.state.boost_cooldown = 2.0
	_combat.micro_mutations.step_micro_mutations(dt * 10.0)
	var ctrl_cd: float = _player.state.boost_cooldown
	_t.check("tread_control_no_extra_refund", is_equal_approx(ctrl_cd, 2.0), "ctrl_cd=%.4f" % ctrl_cd)

	# With tread_plating: wall-carving refunds Movement & boost_cooldown 25% faster.
	_set_parts(["tread_plating"])
	_player.state.carving = true
	_player.state.boost_cooldown = 2.0
	_player.abilities.spend(AbilityState.MOVEMENT)
	var mv_before: float = _player.abilities.slot(AbilityState.MOVEMENT).recharge
	_combat.micro_mutations.step_micro_mutations(0.4)
	var mv_after: float = _player.abilities.slot(AbilityState.MOVEMENT).recharge
	_t.check("tread_boost_cd_25pct", is_equal_approx(_player.state.boost_cooldown, 1.9),
		"boost_cd=%.4f expected=1.9" % _player.state.boost_cooldown)
	_t.check("tread_move_slot_25pct", is_equal_approx(mv_after - mv_before, 0.1),
		"recharge_before=%.4f recharge_after=%.4f" % [mv_before, mv_after])
	# Not carving: no bonus refund.
	_player.state.carving = false
	_player.state.boost_cooldown = 2.0
	_combat.micro_mutations.step_micro_mutations(0.4)
	_t.check("tread_no_carve_no_refund", is_equal_approx(_player.state.boost_cooldown, 2.0),
		"cd=%.4f" % _player.state.boost_cooldown)


func _check_long_spool() -> void:
	# Control without long_spool: grapple_released grants no air-steer surge.
	_set_parts([])
	_combat.micro_mutations.reset(true)
	_game.ctx.events.grapple_released.emit()
	_t.check("spool_control_no_surge", is_equal_approx(_combat.micro_mutations.air_steer_surge_left(), 0.0),
		"surge=%.3f" % _combat.micro_mutations.air_steer_surge_left())

	# With long_spool: grapple_released grants 0.4 s air-steer surge.
	_set_parts(["long_spool"])
	_game.ctx.events.grapple_released.emit()
	_t.check("spool_surge_04s", is_equal_approx(_combat.micro_mutations.air_steer_surge_left(), 0.4),
		"surge=%.3f" % _combat.micro_mutations.air_steer_surge_left())
	# Surge counts down and expires cleanly after 0.4 s.
	_player.state.grounded = false
	_player.intent.move = Vector2(1.0, 0.0)
	_combat.micro_mutations.step_micro_mutations(0.2)
	_t.check("spool_surge_midway", _combat.micro_mutations.air_steer_surge_left() > 0.15 and _combat.micro_mutations.air_steer_surge_left() < 0.25,
		"mid=%.3f" % _combat.micro_mutations.air_steer_surge_left())
	_combat.micro_mutations.step_micro_mutations(0.25)
	_t.check("spool_surge_expired", is_equal_approx(_combat.micro_mutations.air_steer_surge_left(), 0.0),
		"after=%.3f" % _combat.micro_mutations.air_steer_surge_left())
	_player.intent.move = Vector2.ZERO


func _check_dash_vane() -> void:
	var ball_pos: Vector3 = _player.ball_position()
	# Place ball at rest (below CRUISE tier).
	_player.state.velocity = Vector3.ZERO
	_player.state.tier = 0
	_player.body().linear_velocity = Vector3.ZERO
	_player.state.grounded = false

	# Control without dash_vane: air-dashing below CRUISE does not bat shell.
	_set_parts([])
	_combat.micro_mutations.reset(true)
	var shell_ctrl := Projectile.new()
	_game.ctx.root.add_child(shell_ctrl)
	shell_ctrl.setup(_player, _combat.ground, _game.ctx.root, Callable(_game.ctx.flow, "in_play"),
		ball_pos + Vector3(0.5, 0.0, 0.0), ball_pos + Vector3(12.0, 0.0, 0.0), 1.5, null, false)
	shell_ctrl.global_position = ball_pos + Vector3(0.5, 0.0, 0.0)
	_game.ctx.events.dashed.emit(Vector3.RIGHT)
	_combat._bat_by_ball([shell_ctrl])
	_t.check("dash_vane_control_no_bat", not shell_ctrl.returned, "returned=%s" % shell_ctrl.returned)
	shell_ctrl.free()

	# With dash_vane: air-dashing through a shell below CRUISE bats it back.
	_set_parts(["dash_vane"])
	var shell_hit := Projectile.new()
	_game.ctx.root.add_child(shell_hit)
	shell_hit.setup(_player, _combat.ground, _game.ctx.root, Callable(_game.ctx.flow, "in_play"),
		ball_pos + Vector3(0.5, 0.0, 0.0), ball_pos + Vector3(12.0, 0.0, 0.0), 1.5, null, false)
	shell_hit.global_position = ball_pos + Vector3(0.5, 0.0, 0.0)
	_player.state.grounded = false
	_game.ctx.events.dashed.emit(Vector3.RIGHT)
	_combat._bat_by_ball([shell_hit])
	_t.check("dash_vane_bats_shell", shell_hit.returned, "returned=%s" % shell_hit.returned)
	shell_hit.free()


func _check_loose_trigger() -> void:
	# Pure math check for +25% window extension.
	var base_w := Vector2(0.40, 0.60)
	var ext_w: Vector2 = _combat.micro_mutations.extended_window(base_w, 0.25)
	_t.check("loose_trigger_math",
		is_equal_approx(ext_w.x, 0.40) and is_equal_approx(ext_w.y, 0.65),
		"base=%s ext=%s" % [base_w, ext_w])

	# Live check with Rivet active-reload skilled window.
	var weapon: String = _combat.active_weapon()
	var pat: Resource = _combat._patterns[weapon]
	var orig_w: Vector2 = pat.window_s
	var orig_span: float = orig_w.y - orig_w.x
	_t.check("rivet_has_window", orig_span > 0.0, "orig_w=%s" % orig_w)

	# Control without loose_trigger: hitting a Skilled window keeps base window span.
	_set_parts([])
	_combat.micro_mutations.reset(true)
	_combat.micro_mutations.step_cadence_micro(weapon, pat, [{"kind": WeaponDriver.SHOT_BEAT_3}])
	var ctrl_w: Vector2 = _combat.active_window_range()
	_t.check("loose_trigger_control_unextended",
		not _combat.micro_mutations.cadence_window_extended() and is_equal_approx(ctrl_w.y - ctrl_w.x, orig_span),
		"ext=%s ctrl_w=%s" % [_combat.micro_mutations.cadence_window_extended(), ctrl_w])

	# With loose_trigger: landing a Skilled cadence window extends next window by +25%.
	_set_parts(["loose_trigger"])
	_combat.micro_mutations.step_cadence_micro(weapon, pat, [{"kind": WeaponDriver.SHOT_BEAT_3}])
	var widened_w: Vector2 = _combat.active_window_range()
	_t.check("loose_trigger_extends_25pct",
		_combat.micro_mutations.cadence_window_extended() and is_equal_approx(widened_w.y - widened_w.x, orig_span * 1.25),
		"ext=%s widened_w=%s expected_span=%.4f" % [_combat.micro_mutations.cadence_window_extended(), widened_w, orig_span * 1.25])
	# Consecutive skilled hit stays at +25% (never compounds exponentially).
	_combat.micro_mutations.step_cadence_micro(weapon, pat, [{"kind": WeaponDriver.SHOT_BEAT_3}])
	var second_w: Vector2 = _combat.active_window_range()
	_t.check("loose_trigger_no_compound", is_equal_approx(second_w.y - second_w.x, orig_span * 1.25),
		"second_w=%s" % second_w)


func _check_long_barrel() -> void:
	var origin := Vector3.ZERO
	var far_pt := Vector3(0.0, 0.0, 25.0)
	var near_pt := Vector3(0.0, 0.0, 10.0)
	var base_knock := 10.0

	# Control without long_barrel: 25 m hit uses base knockback and no stagger react.
	_set_parts([])
	var spy_ctrl := StaggerSpy.new()
	_game.ctx.root.add_child(spy_ctrl)
	spy_ctrl.global_position = far_pt
	var bolt_ctrl := {
		"origin": origin, "fired_from": origin, "dir": Vector3(0.0, 0.0, 1.0), "travelled": 25.0,
		"damage": 10.0, "kind": "runner", "weapon_id": Weapons.RAPID_LASER, "knock": base_knock,
		"chain_jumps": 0, "color": Color.WHITE, "source": "weapon", "bits": 0, "spent": 0, "acts": 0,
	}
	_combat._on_bolt_hit(bolt_ctrl, spy_ctrl, far_pt)
	_t.check("long_barrel_control_base_knock",
		is_equal_approx(spy_ctrl.last_knock, base_knock) and not ("stagger" in spy_ctrl.reacts),
		"knock=%.2f reacts=%s" % [spy_ctrl.last_knock, spy_ctrl.reacts])
	spy_ctrl.free()

	# With long_barrel: 25 m hit (> 20 m) adds +15% knockback and stagger react.
	_set_parts(["long_barrel"])
	var spy_far := StaggerSpy.new()
	_game.ctx.root.add_child(spy_far)
	spy_far.global_position = far_pt
	_combat._on_bolt_hit(bolt_ctrl.duplicate(), spy_far, far_pt)
	_t.check("long_barrel_far_stagger",
		is_equal_approx(spy_far.last_knock, base_knock * 1.15) and ("stagger" in spy_far.reacts),
		"knock=%.2f expected=%.2f reacts=%s" % [spy_far.last_knock, base_knock * 1.15, spy_far.reacts])
	spy_far.free()

	# With long_barrel: 10 m hit (<= 20 m) stays at base knockback with no extra stagger.
	var spy_near := StaggerSpy.new()
	_game.ctx.root.add_child(spy_near)
	spy_near.global_position = near_pt
	var bolt_near := bolt_ctrl.duplicate()
	bolt_near["travelled"] = 10.0
	_combat._on_bolt_hit(bolt_near, spy_near, near_pt)
	_t.check("long_barrel_near_unchanged",
		is_equal_approx(spy_near.last_knock, base_knock) and not ("stagger" in spy_near.reacts),
		"knock=%.2f reacts=%s" % [spy_near.last_knock, spy_near.reacts])
	spy_near.free()


func _check_boost_coil() -> void:
	# Control without boost_coil: shattering a heft prop while boosting leaves boost_cooldown intact.
	_set_parts([])
	_combat.micro_mutations.reset(true)
	var full_cd: float = _player.tuning.boost_cooldown()
	_player.state.boost_cooldown = full_cd
	_game.ctx.events.boosted.emit(Vector3.FORWARD)
	_game.ctx.events.world_fact.emit("piece_shattered", _player.ball_position())
	_t.check("boost_coil_control_unchanged", is_equal_approx(_player.state.boost_cooldown, full_cd),
		"cd=%.3f full=%.3f" % [_player.state.boost_cooldown, full_cd])

	# With boost_coil: boosting through a heft prop refreshes 50% of boost & movement cooldown.
	_set_parts(["boost_coil"])
	full_cd = _player.tuning.boost_cooldown()
	_player.state.boost_cooldown = full_cd
	_game.ctx.events.boosted.emit(Vector3.FORWARD)
	_game.ctx.events.world_fact.emit("piece_shattered", _player.ball_position())
	_t.check("boost_coil_refreshes_50pct", is_equal_approx(_player.state.boost_cooldown, full_cd * 0.5),
		"cd=%.3f expected=%.3f" % [_player.state.boost_cooldown, full_cd * 0.5])
	# Second shatter from the same boost does not double-refresh to 0.
	_game.ctx.events.world_fact.emit("piece_shattered", _player.ball_position())
	_t.check("boost_coil_once_per_boost", is_equal_approx(_player.state.boost_cooldown, full_cd * 0.5),
		"cd_after_second=%.3f" % _player.state.boost_cooldown)


func _check_reset_hygiene() -> void:
	_set_parts(["long_spool", "loose_trigger", "dash_vane", "boost_coil"])
	_game.ctx.events.grapple_released.emit()
	_game.ctx.events.dashed.emit(Vector3.RIGHT)
	_combat.micro_mutations.step_cadence_micro(_combat.active_weapon(), _combat._patterns[_combat.active_weapon()],
		[{"kind": WeaponDriver.SHOT_BEAT_3}])
	_combat._start_attempt()
	_t.check("reset_clears_surge", is_equal_approx(_combat.micro_mutations.air_steer_surge_left(), 0.0), "surge=0")
	_t.check("reset_clears_cadence", not _combat.micro_mutations.cadence_window_extended(), "cadence=false")
	_t.check("reset_clears_dash_bat", is_equal_approx(_combat.micro_mutations.air_dash_bat_left, 0.0), "dash_bat=0")
	_t.check("reset_clears_boost_window", is_equal_approx(_combat.micro_mutations._boost_active_left, 0.0), "boost_win=0")
