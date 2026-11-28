# smoke: solo timeout=180s
extends SceneTree

const Game := preload("res://src/game.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Weapons := preload("res://src/combat/weapons.gd")
const Run := preload("res://src/core/run_state.gd")
const Augments := preload("res://src/movement/augments.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const BossPosture := preload("res://src/combat/boss_posture.gd")
const WardenReactor := preload("res://src/combat/warden_reactor.gd")
const T:= preload("res://tests/support/t.gd")

# The stage-2 park Warden (the flume mounting, hung 12 m over the drum floor) breaks from the harpoon
# line (card FLUME-POSTURE, coordinator ruling FL1; design-v3/wardens/reactor.md:80). A ball latched on
# the mounted Warden pays posture by each line bolt's damage: the pilot-average base weapon bolt (the
# mean of the six pilots' rows in Weapons.BASE, computed here, not read from the driver) pays the stage
# row's other_base, or its other_base_charging while the relic charges (the stock 1.5 and 3.0), times
# the driver's LINE_PAY since 11 Nov 2026, at the reference heft 1.5 (the second heft class's floor); a heavier ball's
# bolt pays its heft over 1.5 to the stage's posture curve (2.0) more. While the ball is engaged and latched the bar does not
# drain, as on the dam. Unlatched, a bolt keeps the generic rule (punch over plating 110, curve 2.0),
# and a ball that never hits leaves the bar at zero: the camper never breaks it.
#
# Ruling FL3 (2026-10-16): the pay is also divided by the pilot's base weapon damage per second and
# multiplied by Rivet's, so at the reference heft every pilot's base kit fills the bar at Rivet's FL1
# rate (7.07 posture per second at the stock pay), and a damage part still raises it in proportion.
#
# Red at 6d7c7a0c (measured 2026-10-16): the reference bolt paid 0.06 and the latched bar drained.
# Red at 390d9d4e for the FL3 checks: posture per second followed each weapon's damage per second.

# Run.HEFT_CLASS_AT indexes: the reference heft, then the grown ball.
const REFERENCE := 1
const GROWN := 2
const HEFT_CURVE := 2.0
const HOLD_SECONDS := 6.0
const HOLD_START := 50.0
const CAMPER_SECONDS := 12.0

var t := T.new("flume_line_posture_test")
var game


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	game = Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	game.ctx.calm = true
	game.flow.force_warden = true
	game.flow.press_start()
	game.flow.choose_class(0)
	game.run.grant_start_mass((Run.HEFT_CLASS_AT[REFERENCE] - Run.HEFT_CLASS_AT[0]) / Run.HEFT_PER_MASS)
	game.flow.enter_stage(2, Vector3.ZERO, false)
	game.player.set_frozen(true)
	for i in 5:
		await physics_frame
	var w = game.flow.warden
	if not t.check("stage 2 stands the mounted flume Warden", is_instance_valid(w) and w.family == "reactor"
			and w.mounting == "flume" and bool(w.spec.get("park_landmark", false)),
			"warden %s" % [w]):
		quit(t.verdict())
		return
	var reference := _reference_damage()
	print("[report] reference damage %.4f (mean of the six pilots' base weapon damage %s); heft %.2f" % [reference,
		_pilot_damage().values(), game.run.heft()])
	game.flow._engage()
	await physics_frame
	# The objective plate names the line fight on the real Warden in one row (core/objectives.gd),
	# and the mark on the relic says which step is next: latch on, then shoot from the line. A shut
	# clamp or a yard lock would hold the plate; calm stands neither.
	var plate := ["line_fight", "Hook, shoot, smash core"]
	t.eq("unlatched: the mounting reads the flume", w.mount_driver.plate_reading(w), {"mount": "flume"})
	t.eq("unlatched: the plate names the line fight", [game.hud.objective_reading()["id"], game.hud.objective_reading()["words"]], plate)
	t.eq("unlatched: the mark on the relic says to hook it", _mark_tags(), ["HOOK"])
	t.eq("unlatched: the row's first step is live", game.hud.objective_reading()["step"], 0)
	_latch(w)
	await physics_frame
	t.eq("latched: the plate keeps its row", [game.hud.objective_reading()["id"], game.hud.objective_reading()["words"]], plate)
	t.eq("latched: the mark says to shoot", _mark_tags(), ["SHOOT"])
	t.eq("latched: the row's second step is live", game.hud.objective_reading()["step"], 1)

	# Pay per bolt, latched, reference heft, Rivet's pilot (FL1's numbers, which FL3 keeps for Rivet).
	var rivet = _def("runner_gunner")
	# The pay is the stage's stock pay times the line fight's share, never more than the stock pay.
	var pay_base := BossPosture.OTHER_BASE * WardenReactor.LINE_PAY
	var pay_charging := BossPosture.OTHER_BASE_CHARGING * WardenReactor.LINE_PAY
	t.eq("the stage row keeps the stock bolt pay", [w._posture.other_base, w._posture.other_base_charging],
		[BossPosture.OTHER_BASE, BossPosture.OTHER_BASE_CHARGING])
	t.check("a line bolt keeps no more than the stock pay", WardenReactor.LINE_PAY > 0.0 and WardenReactor.LINE_PAY <= 1.0,
		"share %.2f" % WardenReactor.LINE_PAY)
	t.near("latched, Rivet: the reference bolt pays %.3f" % pay_base, _pay(w, "runner", reference, false, rivet), pay_base, 0.01)
	t.near("latched, Rivet: the reference bolt pays %.3f while the relic charges" % pay_charging, _pay(w, "runner", reference, true, rivet), pay_charging, 0.02)
	var rivet_rate := _fire_rate("rapid_laser")
	var rivet_dmg := Weapons.base_damage("rapid_laser")
	var rivet_per_s := _pay(w, "runner", rivet_dmg, false, rivet) * rivet_rate
	var rivet_want := pay_base * rivet_dmg / reference * rivet_rate
	t.near("latched, Rivet: the base kit fills %.3f posture per second, as under FL1" % rivet_per_s, rivet_per_s,
		rivet_want, 0.01)

	# FL3 + PILOT-CADENCE §2.5: at the reference heft, every pilot's careless base kit fills
	# the bar at Rivet's posture per second.
	var pays := []
	for def in ClassDef.all():
		var dmg := Weapons.base_damage(def.weapon_id)
		var pay := _pay(w, String(Weapons.STRIKE_KIND.get(def.weapon_id, "shot")), dmg, false, def)
		var per_s := pay * _fire_rate(def.weapon_id)
		pays.append("%s %s %.0f x %.2f/s -> %.3f a bolt, %.3f/s" % [def.id, def.weapon_id, dmg, _fire_rate(def.weapon_id), pay, per_s])
		t.check("latched, %s: the base kit fills the bar within 1 percent of Rivet's posture per second" % def.id,
			absf(per_s - rivet_per_s) <= 0.01 * rivet_per_s, "%.3f/s against %.3f/s" % [per_s, rivet_per_s])
	print("[report] per-pilot pay at reference heft %.2f: %s" % [game.run.heft(), pays])
	# BL1: Tally's reader spends pressure that time never refills, so latched (airborne, no rolling refill)
	# she fires one card per PRESSURE_ROLL_S at best (measured 0.50 a second on the park table, seed 1).
	# Red at cac3f3de: her bolt was paid by the row's 2.5 a second and filled 1.41 a second.
	var tally = _def("tally")
	var tally_per_s := _pay(w, String(Weapons.STRIKE_KIND.get(tally.weapon_id, "shot")), Weapons.base_damage(tally.weapon_id), false, tally) \
		/ Weapons.PRESSURE_ROLL_S
	t.near("latched, Tally: one card per %.1f s fills %.2f posture per second" % [Weapons.PRESSURE_ROLL_S, rivet_per_s],
		tally_per_s, rivet_want, 0.01 * rivet_want)

	# A planted +50 percent weapon-damage part raises the pilot's posture per second by 50 percent.
	var pilot = game.run.class_def
	var rate := _fire_rate(pilot.weapon_id)
	var kind := String(Weapons.STRIKE_KIND.get(pilot.weapon_id, "shot"))
	var plain := _pay(w, kind, float(game.combat.punch_now()), false, pilot) * rate
	game.ctx.tuning.set_mod("weapon_damage", 1.5)
	var planted_damage := float(game.combat.punch_now())
	var planted := _pay(w, kind, planted_damage, false, pilot) * rate
	game.ctx.tuning.set_mod("weapon_damage", 1.0)
	print("[report] %s with a +50%% damage part: bolt %.1f, %.3f/s against %.3f/s" % [pilot.id, planted_damage, planted, plain])
	t.near("a +50 percent damage part raises posture per second by 50 percent", planted / plain if plain > 0.0 else 0.0, 1.5, 0.015)

	# The bar holds while engaged and latched.
	w._posture.posture = HOLD_START
	w._posture.idle = 0.0
	for i in ceili(HOLD_SECONDS * Engine.physics_ticks_per_second):
		_latch(w)
		await physics_frame
	t.check("latched and engaged: the bar does not drain over %.0f s" % HOLD_SECONDS, w.posture() >= HOLD_START - 0.01
			and not w._posture.staggered, "posture %.2f from %.2f" % [w.posture(), HOLD_START])

	# Unlatched: the generic rule, and the bar drains.
	_unlatch()
	await physics_frame
	var loose := _pay(w, "runner", reference, false, rivet)
	t.check("unlatched: the reference bolt keeps the generic rule (under 0.2)", loose < 0.2, "pay %.3f" % loose)
	w._posture.posture = HOLD_START
	w._posture.idle = 0.0
	for i in ceili(HOLD_SECONDS * Engine.physics_ticks_per_second):
		await physics_frame
	t.check("unlatched: the bar drains", w.posture() < HOLD_START - 1.0, "posture %.2f" % w.posture())

	# The camper: no hits, the bar never fills.
	w._posture.posture = 0.0
	var staggers: int = w._posture.staggers
	for i in ceili(CAMPER_SECONDS * Engine.physics_ticks_per_second):
		await physics_frame
	t.check("the camper never breaks it", w._posture.staggers == staggers and w.posture() == 0.0
			and w._posture.chunks == 4, "staggers %d, posture %.2f, chunks %d" % [w._posture.staggers - staggers,
			w.posture(), w._posture.chunks])

	# A heavier ball's bolt pays its heft share more (the grant lands the run at about heft 1.7).
	game.run.grant_start_mass((Run.HEFT_CLASS_AT[GROWN] - Run.HEFT_CLASS_AT[REFERENCE]) / Run.HEFT_PER_MASS)
	_latch(w)
	await physics_frame
	var heavy_heft: float = game.run.heft()
	var heavy_pay := _pay(w, "runner", reference, false, rivet)
	print("[report] heft %.2f: the reference bolt pays %.3f" % [heavy_heft, heavy_pay])
	t.check("latched, heavier: the ball is past the reference heft", heavy_heft > Run.HEFT_CLASS_AT[REFERENCE] + 0.1,
		"heft %.2f" % heavy_heft)
	t.eq("the stage's posture curve is the heft exponent", w._posture.curve, HEFT_CURVE)
	t.near("latched, heavier: the reference bolt pays %.3f times its heft share" % pay_base, heavy_pay,
		pay_base * pow(heavy_heft / Run.HEFT_CLASS_AT[REFERENCE], HEFT_CURVE), 0.02)
	quit(t.verdict())


func _pilot_damage() -> Dictionary:
	var out := {}
	for def in ClassDef.all():
		out[def.weapon_id] = Weapons.base_damage(def.weapon_id)
	return out


static func _fire_rate(weapon: String) -> float:
	if AbilityState.ABILITIES.get(weapon, {}).has("pressure"):
		return 1.0 / Weapons.PRESSURE_ROLL_S
	var dmg: float = Weapons.base_damage(weapon)
	return WardenReactor.base_dps(weapon) / dmg if dmg > 0.0 else 0.0


func _reference_damage() -> float:
	var damages: Array = _pilot_damage().values()
	return damages.reduce(func(acc, d): return acc + d, 0.0) / damages.size()


# What one bolt of `damage` pays the bar now, without changing it.
# The bolt is judged as `pilot`'s: the run's class is swapped for the judge only.
func _pay(w, kind: String, damage: float, charging: bool, pilot) -> float:
	var was: bool = w._charging
	var was_pilot = game.run.class_def
	w._charging = charging
	game.run.class_def = pilot
	var result: Dictionary = w.judge_hit(kind, damage, false, 0, "")
	game.run.class_def = was_pilot
	w._charging = was
	return float(result.get("gain", 0.0))


func _def(id: String):
	for def in ClassDef.all():
		if def.id == id:
			return def
	return null


# The tags of the marks the HUD's markers point at now, the Warden's own plain marker left out:
# the mark on the relic stands in for it.
func _mark_tags() -> Array:
	var markers = game.hud.edge_markers
	var goal: Dictionary = game.hud.objective_reading()
	markers.objective_id = goal["id"]
	markers.objective_icon = goal["icon"]
	markers.engaged = true
	var targets: Array = markers.targets().filter(func(target): return target["kind"] == "warden_engaged")
	return targets.map(func(target): return target.get("tag", "(the Warden's plain marker)"))


func _latch(w) -> void:
	var kit = game.player.kit
	kit.hooked = true
	kit.on_body = true
	kit.anchor_body = w
	kit.line_state = Augments.LINE_LATCHED
	kit.anchor = w.hardpoint_at(0)


func _unlatch() -> void:
	var kit = game.player.kit
	kit.hooked = false
	kit.on_body = false
	kit.anchor_body = null
	kit.line_state = Augments.LINE_IDLE
