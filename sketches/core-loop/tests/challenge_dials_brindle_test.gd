# Brindle's arena through the spine; the mobs damage wire on the real combat
extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")
const Rules := preload("res://src/boss/boss_rules.gd")
const Hazard := preload("res://src/boss/hazard.gd")
const T := preload("res://tests/support/t.gd")

# The difficulty dials on the real Brindle (boss.gd) and on combat's enemy-hit door. Each wire
# point is read at its use site, so removing one turns a check here red: the hazard damage of the
# slag and the charge, the committed warn of the crane, slag and charge (never under Hazard.MIN_WARN
# at tell_mult 0.1, and the slag's next-attack time built on that same warn), the wall and clash stun
# windows, the crane and rest periods, the combo, and mobs.damage_mult (warden, vault and the Mind's
# hand excluded).
#
# Evidence limit: hazards and hits are driven through the boss's own methods, not by a ball dodging.

var _t := T.new("challenge_dials_brindle_test")
var _game
var _boss
var _hits: Array = []


func _initialize() -> void:
	ChallengeDials.reset()
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	await physics_frame
	_game.ctx.spawner = _game.combat
	_boss = _game.boss
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	Harness.start_run(_game)
	Harness.enter(_game, Vector3(18.0, 0.0, 0.0))
	await physics_frame
	await physics_frame
	_game.run.max_hp = 100000.0
	_game.run.hp = 100000.0
	_game.ctx.events.player_hit.connect(func(amount: float, source: String): _hits.append([source, amount]))
	_t.check("Brindle is the active boss", _boss != null and _boss.active())
	var ball: Vector3 = _game.player.ball_position()
	var fake := Node.new()

	# Damage: the slag and charge hits, by phase.
	_boss.phase = 2
	for mult in [1.0, 2.0]:
		ChallengeDials.set_overrides({"brindle.damage_mult": mult, "brindle.damage_by_phase": [1.0, 1.5, 1.0, 1.0]})
		_hits.clear()
		_boss._slag_hit(fake, ball)
		_t.near("slag hit x%.0f in phase 2" % mult, _last("brindle_slag"), Rules.SLAG_DAMAGE * mult * 1.5)
	_boss.phase = 3
	_hits.clear()
	_boss._charge_hit(fake, ball)
	_t.near("charge hit in phase 3 (damage_mult 2)", _last("brindle_charge"), Rules.CHARGE_DAMAGE * 2.0)
	fake.free()

	# Tell: the committed hazards never drop under Hazard.MIN_WARN at tell_mult 0.1, and the slag's
	# next attack is scheduled on that same warn.
	# The phase ratchet's reprise is off here: it reschedules the next ring (fight_phases_test).
	ChallengeDials.set_overrides({"brindle.tell_mult": 0.1, "brindle.follow_ups_by_phase": [0.0, 0.0, 0.0, 0.0]})
	_boss._enter_phase(1)
	_boss._commit_crane(0, ball)
	var crane = _boss._cranes[0].get("hazard")
	_t.check("crane warn stays >= MIN_WARN at tell_mult 0.1", crane != null and crane.warn_seconds >= Hazard.MIN_WARN - 1e-6,
			str(crane.warn_seconds if crane != null else -1.0))
	_boss._cancel_hazards()
	_boss._enter_phase(2)
	_boss.clock = 50.0
	_boss._phases.tick(_boss.clock)
	_boss._next_attack = 0.0
	_boss._step_furnace(1.0 / 90.0)
	var slag = _boss.hazards.back() if not _boss.hazards.is_empty() else null
	_t.check("slag warn stays >= MIN_WARN at tell_mult 0.1", slag != null and slag.warn_seconds >= Hazard.MIN_WARN - 1e-6,
			str(slag.warn_seconds if slag != null else -1.0))
	if slag != null:
		# The shipped Furnace period (brindle.period_by_phase) scales the gap; the warn and live do not.
		var want: float = slag.warn_seconds + Rules.SLAG_LIVE + ChallengeDials.period("brindle", Rules.SLAG_GAP, 2)
		_t.near("next slag is scheduled on the hazard's own warn", _boss._next_attack - _boss.clock, want, 0.02)
	_boss._cancel_hazards()
	_boss._enter_phase(3)
	_boss._commit_charge()
	var charge = _boss._charge.get("hazard")
	_t.check("charge warn stays >= MIN_WARN at tell_mult 0.1", charge != null and charge.warn_seconds >= Hazard.MIN_WARN - 1e-6,
			str(charge.warn_seconds if charge != null else -1.0))

	# Punish: a wall stun lasts WALL_STUN x punish_mult; a clash, CLASH_STUN x punish_mult.
	ChallengeDials.set_overrides({"brindle.punish_mult": 2.0})
	_boss._charge["state"] = "run"
	_boss._charge["into_wall"] = true
	_boss._charge["travelled"] = _boss._charge["length"]
	_boss._run_charge(1.0 / 90.0, ball)
	_t.check("wall stun enters", _boss._charge.get("state", "") == "stun", str(_boss._charge.get("state")))
	_t.near("wall stun is WALL_STUN x2", float(_boss._charge.get("timer", -1.0)), Rules.WALL_STUN * 2.0)
	_boss._cancel_hazards()
	_boss._enter_phase(3)
	_boss._charge = {"state": "run", "hazard": null, "from": Vector3.ZERO, "heading": Vector3.RIGHT, "length": 1.0, "into_wall": false, "travelled": 0.0}
	_boss.on_struck(_boss.ship.hull_target() if _boss.ship.has_method("hull_target") else _boss.ship.hull, "ram", "", {"punch": 1.0e9, "plating": 0.0})
	_t.near("clash stun is CLASH_STUN x2", float(_boss._charge.get("timer", -1.0)), Rules.CLASH_STUN * 2.0)

	# Period and combo: the rest before a charge, and a combo follow-up a warning gap after the lead.
	ChallengeDials.set_overrides({"brindle.period_mult": 2.0})
	_t.near("charge rest x2", _boss._rest_time(), Rules.CHARGE_REST * 2.0 * ChallengeDials.by_phase("brindle.period_by_phase", 3))
	ChallengeDials.set_overrides({"brindle.combo": 2.0, "brindle.punish_mult": 1.0})
	_boss._combo_left = -1
	_t.near("lead owes a follow-up: next in a warning gap", _boss._paced(3.4), ChallengeDials.WARN_GAP)
	_t.near("second step still owes one", _boss._paced(3.4), ChallengeDials.WARN_GAP)
	_t.near("then the normal period resumes", _boss._paced(3.4), 3.4)
	_boss._combo_left = 2
	_boss._stun(1.0)
	_t.eq("a stun drops the owed combo", _boss._combo_left, -1)

	# Mobs: combat's enemy-hit door multiplies after damage_scale(); warden, vault and the hand are not.
	# The stage list is held at identity so the global mult is what is read (the dam ships x2 by stage).
	ChallengeDials.set_overrides({"mobs.damage_mult": 2.0, "mobs.damage_by_stage": ChallengeDials.ONES6})
	for source in ["chaser", "warden", "vault", "mind_hand"]:
		_hits.clear()
		_game.combat._on_player_hit(10.0, Vector3.ZERO, source)
		var want_amount := 20.0 if source == "chaser" else 10.0
		_t.near("%s hit with mobs.damage_mult 2" % source, _last(source), want_amount)
	ChallengeDials.reset()
	_game.free()
	quit(_t.verdict())


func _last(source: String) -> float:
	for i in range(_hits.size() - 1, -1, -1):
		if _hits[i][0] == source:
			return float(_hits[i][1])
	return -1.0
