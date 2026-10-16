# smoke: solo timeout=180s
extends SceneTree

const Game := preload("res://src/game.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Weapons := preload("res://src/combat/weapons.gd")
const Run := preload("res://src/core/run_state.gd")
const Augments := preload("res://src/movement/augments.gd")
const T := preload("res://tests/support/t.gd")

# The stage-2 park Warden (the flume mounting, hung 12 m over the drum floor) breaks from the harpoon
# line (card FLUME-POSTURE, coordinator ruling FL1; design-v3/wardens/reactor.md:80). A ball latched on
# the mounted Warden pays posture by each line bolt's damage: the pilot-average base weapon bolt (the
# mean of the six pilots' rows in Weapons.BASE, computed here, not read from the driver) pays 1.5, or
# 3.0 while the relic charges, at the reference heft 1.5 (the second heft class's floor); a heavier ball's
# bolt pays its heft over 1.5 to the stage's posture curve (2.0) more. While the ball is engaged and latched the bar does not
# drain, as on the dam. Unlatched, a bolt keeps the generic rule (punch over plating 110, curve 2.0),
# and a ball that never hits leaves the bar at zero: the camper never breaks it.
#
# Red at 6d7c7a0c (measured 2026-10-16): the reference bolt paid 0.06 and the latched bar drained.

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
	_latch(w)
	await physics_frame

	# Pay per bolt, latched, reference heft.
	t.near("latched: the reference bolt pays 1.5", _pay(w, "runner", reference, false), 1.5, 0.01)
	t.near("latched: the reference bolt pays 3.0 while the relic charges", _pay(w, "runner", reference, true), 3.0, 0.02)
	var pays := []
	for weapon in _pilot_damage():
		var damage: float = _pilot_damage()[weapon]
		var pay := _pay(w, String(Weapons.STRIKE_KIND.get(weapon, "shot")), damage, false)
		pays.append("%s %.0f -> %.3f" % [weapon, damage, pay])
		t.near("latched: a %s bolt pays its damage share" % weapon, pay, 1.5 * damage / reference, 0.01)
	print("[report] per-pilot bolt pay at reference heft %.2f: %s" % [game.run.heft(), pays])

	# The bar holds while engaged and latched.
	w._posture.posture = HOLD_START
	w._posture.idle = 0.0
	for i in ceili(HOLD_SECONDS * Engine.physics_ticks_per_second):
		_latch(w)
		await physics_frame
	t.check("latched and engaged: the bar does not drain over %.0f s" % HOLD_SECONDS, w._posture.posture >= HOLD_START - 0.01
			and not w._posture.staggered, "posture %.2f from %.2f" % [w._posture.posture, HOLD_START])

	# Unlatched: the generic rule, and the bar drains.
	_unlatch()
	await physics_frame
	var loose := _pay(w, "runner", reference, false)
	t.check("unlatched: the reference bolt keeps the generic rule (under 0.2)", loose < 0.2, "pay %.3f" % loose)
	w._posture.posture = HOLD_START
	w._posture.idle = 0.0
	for i in ceili(HOLD_SECONDS * Engine.physics_ticks_per_second):
		await physics_frame
	t.check("unlatched: the bar drains", w._posture.posture < HOLD_START - 1.0, "posture %.2f" % w._posture.posture)

	# The camper: no hits, the bar never fills.
	w._posture.posture = 0.0
	var staggers: int = w._posture.staggers
	for i in ceili(CAMPER_SECONDS * Engine.physics_ticks_per_second):
		await physics_frame
	t.check("the camper never breaks it", w._posture.staggers == staggers and w._posture.posture == 0.0
			and w._posture.chunks == 4, "staggers %d, posture %.2f, chunks %d" % [w._posture.staggers - staggers,
			w._posture.posture, w._posture.chunks])

	# A heavier ball's bolt pays its heft share more (the grant lands the run at about heft 1.7).
	game.run.grant_start_mass((Run.HEFT_CLASS_AT[GROWN] - Run.HEFT_CLASS_AT[REFERENCE]) / Run.HEFT_PER_MASS)
	_latch(w)
	await physics_frame
	var heavy_heft: float = game.run.heft()
	var heavy_pay := _pay(w, "runner", reference, false)
	print("[report] heft %.2f: the reference bolt pays %.3f" % [heavy_heft, heavy_pay])
	t.check("latched, heavier: the ball is past the reference heft", heavy_heft > Run.HEFT_CLASS_AT[REFERENCE] + 0.1,
		"heft %.2f" % heavy_heft)
	t.eq("the stage's posture curve is the heft exponent", w._posture.curve, HEFT_CURVE)
	t.near("latched, heavier: the reference bolt pays 1.5 times its heft share", heavy_pay,
		1.5 * pow(heavy_heft / Run.HEFT_CLASS_AT[REFERENCE], HEFT_CURVE), 0.02)
	quit(t.verdict())


func _pilot_damage() -> Dictionary:
	var out := {}
	for def in ClassDef.all():
		out[def.weapon_id] = float(Weapons.BASE[def.weapon_id]["damage"])
	return out


func _reference_damage() -> float:
	var damages: Array = _pilot_damage().values()
	return damages.reduce(func(acc, d): return acc + d, 0.0) / damages.size()


# What one bolt of `damage` pays the bar now, without changing it.
func _pay(w, kind: String, damage: float, charging: bool) -> float:
	var was: bool = w._charging
	w._charging = charging
	var result: Dictionary = w.judge_hit(kind, damage, false, 0, "")
	w._charging = was
	return float(result.get("gain", 0.0))


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
