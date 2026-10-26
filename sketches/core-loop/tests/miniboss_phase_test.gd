extends SceneTree

const Game := preload("res://src/game.gd")
const Miniboss := preload("res://src/combat/miniboss.gd")
const WindupRows := preload("res://src/presentation/windup_rows.gd")

# Phase two of the stage miniboss (Andrew 19:02Z and 19:11Z 23 Oct; fight_phases.gd): the hit
# that takes it under FightPhases.MINI_TURN of its health turns it, once. The turn lasts the
# transition beat, takes no damage and drops any committed attack, and publishes
# fight_phase_changed. Then its wind-ups shorten by PHASE_TWO_WIND (the wind-up rows read the
# shorter leads, above the tell floor); its slam chains into its charge with no weak window,
# through a CUE_LEAD beat that sounds attack_cued and commits nothing; the cued charge's brace
# is the cued tell, so cue to hit is CUED_TOTAL; and the charge still vents.

var failures := 0
var game
var phases := []
var cues := []


func _initialize() -> void:
	game = Game.new()
	game.test_mode = true
	root.add_child(game)
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
	print("%s %s" % ["PASS" if ok else "FAIL", label])


func _run() -> void:
	game.ctx.calm = true
	game.events.fight_phase_changed.connect(func(id, phase, count): phases.append([id, phase, count]))
	game.events.attack_cued.connect(func(id, attack, seconds): cues.append([id, attack, seconds]))
	var boss = game.ctx.spawner.spawn_enemy("miniboss", Vector3(0, 40, 0))
	boss.set_physics_process(false)
	boss.live = func(): return true
	_check(boss.phase == 1 and is_equal_approx(boss.slam_crouch, Miniboss.SLAM_CROUCH)
		and is_equal_approx(boss.charge_brace, Miniboss.CHARGE_BRACE), "starts in phase 1 on the phase 1 wind-ups")
	boss.take_damage(boss.hp - boss.max_hp * 0.55)
	_check(boss.phase == 1 and phases.is_empty(), "above half health it stays in phase 1")
	boss._begin_attack(Vector3(0, 0, -10))
	_check(boss.telegraph() != null, "a slam is committed before the turn")
	boss.take_damage(boss.hp - boss.max_hp * 0.45)
	_check(boss.phase == 2 and boss.state == Miniboss.State.TURN and boss.telegraph() == null,
		"under half health it turns to phase 2, its committed slam dropped")
	_check(phases == [["miniboss", 2, FightPhases.MINI_MAX]], "the turn publishes fight_phase_changed %s" % [phases])
	var turning: float = boss.hp
	_check(boss.take_damage(50.0) == 0.0 and boss.hp == turning, "it takes no damage while it turns")
	boss._physics_process(FightPhases.TRANSITION_SECONDS * 0.5)
	_check(boss.state == Miniboss.State.TURN and boss.telegraph() == null, "still turning halfway through, nothing committed")
	boss._physics_process(FightPhases.TRANSITION_SECONDS * 0.5 + 0.001)
	_check(boss.state == Miniboss.State.STALK, "stalks after the %.1f s turn" % FightPhases.TRANSITION_SECONDS)
	_check(is_equal_approx(boss.slam_crouch, Miniboss.SLAM_CROUCH * Miniboss.PHASE_TWO_WIND)
		and is_equal_approx(boss.charge_brace, Miniboss.CHARGE_BRACE * Miniboss.PHASE_TWO_WIND),
		"phase 2 wind-ups: crouch %.3f s, brace %.3f s" % [boss.slam_crouch, boss.charge_brace])
	var slam_row := float(WindupRows.row("miniboss", boss, "E03").get("lead_seconds", 0.0))
	_check(is_equal_approx(slam_row, boss.slam_crouch + Miniboss.SLAM_LEAP) and slam_row >= ChallengeDials.TELL_FLOOR,
		"the slam's wind-up row reads the phase 2 lead %.3f s" % slam_row)
	boss._next_attack = 0
	boss._begin_attack(Vector3(0, 0, -10))
	_check(boss.state == Miniboss.State.SLAM_CROUCH and boss.telegraph() != null, "phase 2 slam committed")
	var windows: int = boss.weak_windows
	boss._land_slam()
	_check(boss.state == Miniboss.State.CUE and boss.telegraph() == null and boss.weak_windows == windows,
		"the slam is followed by a cue beat with no weak window and nothing committed")
	_check(cues == [["miniboss", "E04", FightPhases.CUED_TOTAL]], "the cue sounds attack_cued for the charge %s" % [cues])
	boss._physics_process(FightPhases.CUE_LEAD * 0.5)
	_check(boss.state == Miniboss.State.CUE and boss.telegraph() == null, "nothing is drawn during the cue")
	boss._physics_process(FightPhases.CUE_LEAD * 0.5 + 0.001)
	_check(boss.state == Miniboss.State.CHARGE_BRACE and boss.telegraph() != null, "the cue ends in a committed charge lane")
	var brace := float(WindupRows.row("miniboss", boss, "E04").get("lead_seconds", 0.0))
	_check(is_equal_approx(brace, FightPhases.CUED_WARN) and brace >= ChallengeDials.TELL_FLOOR,
		"the cued charge's drawn tell is %.2f s, cue to hit %.2f s" % [brace, FightPhases.CUE_LEAD + brace])
	boss._open_weak_window()
	_check(boss.state == Miniboss.State.WEAK and boss.weak_windows == windows + 1, "the charge still vents")
	_check(is_equal_approx(boss.charge_brace, Miniboss.CHARGE_BRACE * Miniboss.PHASE_TWO_WIND), "an uncued charge braces at the phase 2 wind-up again")
	boss.enter_phase(1)
	boss.take_damage(1.0)
	_check(boss.phase == 2 and phases.size() == 1, "it never turns twice or drops back a phase")
	for name in Miniboss.POSES:
		_check(Miniboss.POSES[name].keys() == Miniboss.POSES.stalk.keys(), "pose row %s has every field" % name)
	for st in [Miniboss.State.TURN, Miniboss.State.CUE]:
		boss.state = st
		boss._clock = 0.2
		boss._pose(0.016)
		_check(Miniboss.POSES.has(boss.state_name()), "%s poses from its row" % boss.state_name())
	boss._clear_telegraph()
	boss.free()
	print("miniboss_phase_test: %s" % ("PASS" if failures == 0 else "FAIL"))
	game.free()
	quit(0 if failures == 0 else 1)
