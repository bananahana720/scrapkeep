extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Pattern := preload("res://src/combat/pattern.gd")
const WeaponDriver := preload("res://src/combat/weapon_driver.gd")
const Weapons := preload("res://src/combat/weapons.gd")
const T := preload("res://tests/support/t.gd")

# E1-01 WeaponDriver extraction & Pattern cadence fields:
# 1. Pattern cadence fields default cleanly to hold_auto and clamp out-of-range inputs.
# 2. WeaponDriver hold_auto firing matches legacy cooldown arithmetic tick-for-tick.
# 3. Attempt boundaries reset trigger state; mount/ultimate interrupts preserve hold_auto
#    cooldown; state_snapshot() is read-only; no static var leaks across instances or runs.
# 4. Live Combat uses WeaponDriver with zero private reach-ins, resets on retry, and keeps
#    item_proc volleys completely isolated from WeaponDriver state.

const DT := 1.0 / 60.0

var _t := T.new("weapon_driver_test")
var _game
var _source := Intent.Scripted.new()
var _step := 0
var _ticks := 0
var _volleys_before := 0


func _initialize() -> void:
	_check_pattern_defaults_and_clamps()
	_check_hold_auto_equivalence()
	_check_press_release_and_card_recovery()
	_check_lifecycle_and_snapshot_isolation()
	_check_warm_batch_repeatability()
	_check_structural_boundaries()
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _check_pattern_defaults_and_clamps() -> void:
	var fresh: Resource = Pattern.new()
	_t.eq("default trigger is hold_auto", fresh.trigger, Pattern.TRIGGER_HOLD_AUTO)
	_t.near("default floor_s is 0", fresh.floor_s, 0.0)
	_t.eq("default beat_floors_s is empty", fresh.beat_floors_s, [])
	_t.eq("default mag is 0", fresh.mag, 0)
	_t.near("default reload_s is 0", fresh.reload_s, 0.0)
	_t.eq("default window_s is zero", fresh.window_s, Vector2.ZERO)
	_t.near("default window_mult is 1", fresh.window_mult, 1.0)
	_t.near("default charge_s is 0", fresh.charge_s, 0.0)
	_t.near("default charge_min is 0", fresh.charge_min, 0.0)
	_t.near("default tap_threshold_s is 0", fresh.tap_threshold_s, 0.0)
	_t.near("default recover_s is 0", fresh.recover_s, 0.0)
	_t.near("default beat_window_s is 0", fresh.beat_window_s, 0.0)
	_t.near("default refund is 0", fresh.refund, 0.0)
	_t.eq("default fan is false", fresh.fan, false)

	for wid in Weapons.ALL:
		var base: Resource = Weapons.base(wid)
		_t.eq("%s keeps hold_auto trigger" % wid, base.trigger, Pattern.TRIGGER_HOLD_AUTO)
		_t.near("%s base damage unchanged" % wid, base.damage, float(Weapons.BASE[wid]["damage"]))
		_t.near("%s base rate unchanged" % wid, base.rate, float(Weapons.BASE[wid]["rate"]))

	for mode in Pattern.TRIGGERS:
		var p: Resource = Pattern.make({"trigger": mode}).transformed([])
		_t.eq("valid trigger %s survives clamp" % mode, p.trigger, mode)

	var clamped: Resource = Pattern.make({
		"trigger": "unknown_trigger",
		"floor_s": -2.0,
		"beat_floors_s": [-1.0, 99.0],
		"mag": 999,
		"reload_s": 50.0,
		"window_s": Vector2(0.8, 0.3),
		"window_mult": 0.2,
		"charge_s": -1.5,
		"charge_min": 2.5,
		"tap_threshold_s": 5.0,
		"recover_s": 25.0,
		"beat_window_s": -0.5,
		"refund": 3.0,
		"fan": true,
	}).transformed([])
	_t.eq("unknown trigger clamps to hold_auto", clamped.trigger, Pattern.TRIGGER_HOLD_AUTO)
	_t.near("negative floor_s clamps to 0", clamped.floor_s, 0.0)
	_t.eq("beat_floors_s clamps each entry", clamped.beat_floors_s, [0.0, Pattern.MAX_FLOOR_S])
	_t.eq("mag clamps at MAX_MAG", clamped.mag, Pattern.MAX_MAG)
	_t.near("reload_s clamps at MAX_RELOAD_S", clamped.reload_s, Pattern.MAX_RELOAD_S)
	_t.eq("inverted window_s clamps close >= open", clamped.window_s, Vector2(0.8, 0.8))
	_t.near("low window_mult clamps to MIN_WINDOW_MULT", clamped.window_mult, Pattern.MIN_WINDOW_MULT)
	_t.near("negative charge_s clamps to 0", clamped.charge_s, 0.0)
	_t.near("high charge_min clamps to 1", clamped.charge_min, 1.0)
	_t.near("high tap_threshold_s clamps at MAX_TAP_THRESHOLD_S", clamped.tap_threshold_s, Pattern.MAX_TAP_THRESHOLD_S)
	_t.near("high recover_s clamps at MAX_RECOVER_S", clamped.recover_s, Pattern.MAX_RECOVER_S)
	_t.near("negative beat_window_s clamps to 0", clamped.beat_window_s, 0.0)
	_t.near("high refund clamps at MAX_REFUND", clamped.refund, Pattern.MAX_REFUND)
	_t.eq("fan preserves true", clamped.fan, true)

	var high_mult: Resource = Pattern.make({"window_mult": 99.0, "mag": -4, "window_s": [0.38, 0.54]}).transformed([])
	_t.near("high window_mult clamps at MAX_WINDOW_MULT", high_mult.window_mult, Pattern.MAX_WINDOW_MULT)
	_t.eq("negative mag clamps to 0", high_mult.mag, 0)
	_t.eq("array window_s coerces to Vector2", high_mult.window_s, Vector2(0.38, 0.54))

	var non_finite: Resource = Pattern.make({"floor_s": NAN, "reload_s": INF, "window_mult": NAN}).transformed([])
	_t.near("NAN floor_s clamps to 0", non_finite.floor_s, 0.0)
	_t.near("INF reload_s clamps to 0", non_finite.reload_s, 0.0)
	_t.near("NAN window_mult clamps to MIN_WINDOW_MULT", non_finite.window_mult, Pattern.MIN_WINDOW_MULT)

	var src: Resource = Pattern.make({"trigger": "beats", "beat_floors_s": [0.45, 0.55], "window_s": [0.30, 0.54]})
	var dup: Resource = src.copy()
	dup.beat_floors_s[0] = 0.99
	_t.near("copy isolates beat_floors_s array", src.beat_floors_s[0], 0.45)

	var op_pat: Resource = Pattern.make({"damage": 12.0, "beat_floors_s": [0.45, 0.55]})
	op_pat._apply({"set": {"trigger": "press", "mag": 12, "fan": true, "window_s": [0.38, 0.54]}, "mul": {"damage": 0.5, "beat_floors_s": 0.5}})
	op_pat._clamp()
	_t.eq("pattern _apply set+mul updates cadence fields",
		[op_pat.trigger, op_pat.mag, op_pat.fan, op_pat.window_s, op_pat.damage, op_pat.beat_floors_s],
		["press", 12, true, Vector2(0.38, 0.54), 6.0, [0.225, 0.275]])


func _check_hold_auto_equivalence() -> void:
	for wid in [Weapons.RAPID_LASER, Weapons.ARC_CASTER, Weapons.CLAW_SWEEP, Weapons.CANNON_LANE]:
		var p: Resource = Weapons.base(wid)
		var rate: float = float(p.rate)
		var drv := WeaponDriver.new()
		var legacy_cd := 0.0
		var drv_ticks: Array = []
		var legacy_ticks: Array = []
		var max_cd_diff := 0.0
		for tick in 120:
			var intent := Intent.new()
			# Hold for 50 ticks, release for 20 ticks, hold again for 50 ticks.
			intent.fire_held = tick < 50 or tick >= 70
			intent.fire_pressed = tick == 0 or tick == 70
			intent.fire_released = tick == 50
			var shots: Array = drv.step(DT, intent, wid, p, rate)
			if not shots.is_empty():
				drv_ticks.append(tick)
			legacy_cd -= DT
			if intent.fire_held and legacy_cd <= 0.0:
				legacy_ticks.append(tick)
				legacy_cd += 1.0 / rate
			if not intent.fire_held:
				legacy_cd = maxf(legacy_cd, 0.0)
			max_cd_diff = maxf(max_cd_diff, absf(drv.cooldown_s() - legacy_cd))
		_t.eq("%s hold_auto firing ticks match legacy exactly" % wid, drv_ticks, legacy_ticks)
		_t.check("%s hold_auto cooldown matches legacy" % wid, max_cd_diff <= 0.000001, "max diff %.8f" % max_cd_diff)


func _check_press_release_and_card_recovery() -> void:
	var drv := WeaponDriver.new()
	var p: Resource = Weapons.base(Weapons.LEDGER_READER)
	var held_no_press := Intent.new()
	held_no_press.fire_held = true
	_t.eq("card weapon does not fire on hold without press", drv.step(DT, held_no_press, Weapons.LEDGER_READER, p, 0.0).size(), 0)
	_t.near("hold duration tracks continuous hold", float(drv.state_snapshot()["hold"]), DT)

	var press := Intent.new()
	press.fire_pressed = true
	var shots: Array = drv.step(DT, press, Weapons.LEDGER_READER, p, 0.0)
	_t.eq("card weapon emits press shot when ready", shots.size(), 1)
	_t.near("refused card press leaves cooldown at 0", drv.cooldown_s(), 0.0)

	drv.commit_recovery(Weapons.CARD_RECOVERY)
	_t.near("commit_recovery charges CARD_RECOVERY", drv.cooldown_s(), Weapons.CARD_RECOVERY)
	_t.eq("press during recovery is blocked", drv.step(DT, press, Weapons.LEDGER_READER, p, 0.0).size(), 0)

	var release := Intent.new()
	release.fire_released = true
	drv.step(DT, release, Weapons.LEDGER_READER, p, 0.0)
	_t.eq("release clears held state", drv.state_snapshot()["held"], false)
	_t.near("release clears hold duration", float(drv.state_snapshot()["hold"]), 0.0)


func _check_lifecycle_and_snapshot_isolation() -> void:
	var drv := WeaponDriver.new()
	var p: Resource = Weapons.base(Weapons.ARC_CASTER)
	var hold := Intent.new()
	hold.fire_held = true
	drv.step(DT, hold, Weapons.ARC_CASTER, p, p.rate)
	var cd_before := drv.cooldown_s()
	_t.check("cooldown armed after hold_auto shot", cd_before > 0.0, "%.3f" % cd_before)

	drv.interrupt(WeaponDriver.INTERRUPT_MOUNT)
	_t.near("mount interrupt preserves spark floor cooldown", drv.cooldown_s(), cd_before)
	drv.interrupt(WeaponDriver.INTERRUPT_ULTIMATE)
	_t.near("ultimate interrupt preserves cooldown", drv.cooldown_s(), cd_before)

	var snap: Dictionary = drv.state_snapshot()
	snap["cooldown"] = 999.0
	snap["weapon"] = "mutated"
	snap["chamber"] = 99
	var snap2: Dictionary = drv.state_snapshot()
	_t.eq("mutating state_snapshot does not mutate driver",
		[snap2["weapon"], snap2["chamber"], snap2["cooldown"] < 1.0],
		[Weapons.ARC_CASTER, 0, true])

	drv.reset(p)
	var rested: Dictionary = drv.state_snapshot()
	_t.eq("reset returns driver to rest",
		[rested["ready"], rested["cooldown"], rested["held"], rested["hold"], rested["reloading"],
			rested["charge"], rested["beat"], rested["window"], rested["painted"]],
		[true, 0.0, false, 0.0, false, 0.0, 0, WeaponDriver.WINDOW_IDLE, false])


func _check_warm_batch_repeatability() -> void:
	var p: Resource = Weapons.base(Weapons.RAPID_LASER)
	var a := WeaponDriver.new()
	var b := WeaponDriver.new()
	var hold := Intent.new()
	hold.fire_held = true
	var seq_a: Array = []
	var seq_b: Array = []
	for tick in 40:
		if not a.step(DT, hold, Weapons.RAPID_LASER, p, p.rate).is_empty():
			seq_a.append(tick)
		if tick % 2 == 0 and not b.step(DT, hold, Weapons.RAPID_LASER, p, p.rate).is_empty():
			seq_b.append(tick)
	# A fresh instance run after both must match a's exact sequence (no static leaks).
	var c := WeaponDriver.new()
	var seq_c: Array = []
	for tick in 40:
		if not c.step(DT, hold, Weapons.RAPID_LASER, p, p.rate).is_empty():
			seq_c.append(tick)
	_t.eq("independent drivers stay isolated and repeatable", seq_c, seq_a)
	_t.check("second driver stepped differently produced different count", seq_b.size() < seq_a.size(),
		"a=%d b=%d" % [seq_a.size(), seq_b.size()])


func _check_structural_boundaries() -> void:
	var driver_src := FileAccess.get_file_as_string("res://src/combat/weapon_driver.gd")
	_t.check("weapon_driver.gd has zero static vars", not driver_src.contains("static var "), "")
	var combat_src := FileAccess.get_file_as_string("res://src/combat/combat.gd")
	_t.check("combat.gd never reaches into weapon_driver private members", not combat_src.contains("weapon_driver._"), "")


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	var combat = _game.ctx.spawner
	match _step:
		0:
			_game.ctx.calm = true
			_game.player.source = _source
			_game.flow.press_start()
			_game.flow.choose_class(1)
			_game.camera.pitch = 0.2
			_volleys_before = combat.volleys
			_source.hold = {"fire_held": true}
			_step = 1
			_ticks = 0
		1:
			_ticks += 1
			if _ticks < 12:
				return false
			var snap: Dictionary = combat.weapon_driver.state_snapshot()
			_t.check("live hold_auto fires volleys through WeaponDriver", combat.volleys > _volleys_before,
				"volleys %d -> %d" % [_volleys_before, combat.volleys])
			_t.eq("live snapshot names active weapon and trigger",
				[snap["weapon"], snap["trigger"], snap["held"]],
				[Weapons.RAPID_LASER, Pattern.TRIGGER_HOLD_AUTO, true])
			# Release fire, hold a known cooldown, and prove a proc volley bypasses WeaponDriver.
			_source.hold = {}
			combat.weapon_driver.set_cooldown_s(0.42)
			var snap_before_proc: Dictionary = combat.weapon_driver.state_snapshot()
			var cd_before_proc: float = combat.weapon_driver.cooldown_s()
			var volleys_pre_proc: int = combat.volleys
			combat._proc_volley(1.0)
			_t.eq("proc volley fires without touching WeaponDriver",
				[combat.volleys, combat.weapon_driver.cooldown_s(), combat.weapon_driver.state_snapshot()],
				[volleys_pre_proc + 1, cd_before_proc, snap_before_proc])
			# Attempt boundary (stage retry) resets WeaponDriver to rest.
			_game.flow.retry_stage()
			_step = 2
		2:
			var after_retry: Dictionary = combat.weapon_driver.state_snapshot()
			_t.eq("attempt boundary resets WeaponDriver to rest",
				[after_retry["ready"], after_retry["cooldown"], after_retry["held"]],
				[true, 0.0, false])
			_game.free()
			quit(_t.verdict())
			return true
	return false
