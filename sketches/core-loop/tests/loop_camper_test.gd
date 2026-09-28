extends SceneTree

const Game := preload("res://src/game.gd")
const BotDriver := preload("res://tools/bot_driver.gd")

# The bowl camper cannot win (LOOP-REDESIGN section 4, the v3 fun lab's drop mode). The
# v2 skipper beelines to the Warden, fires at it and rams laps on the bowl floor. Under
# drop rules that must move the badge by nothing:
#   hold  CAMP_SECONDS of camping deal 0 to the Warden; the gun's banked share lapses
#         with every window nobody drops through.
#   full  the same camping never staggers the Warden, and the gun deals 0 outside a
#         stagger, so the camper opens nothing without a drop.
# The camper is given the HP to last the whole span, so the zero is measured over all of
# it. The full span is shorter to fit the smoke run's per-test limit; the bot runner
# measures 240 s of both (DESIGN-NOTES, v3 L1). The span runs at SCALE with the physics tick raised by the same factor, so every
# step is the game's own 1/90 s and the ball moves exactly as it does at 1x.
#
# Evidence limit: this proves the damage rule refuses a camper; it says nothing about
# how the fight feels.

const SEED := 3
const CAMP_SECONDS := {"hold": 240.0, "full": 80.0}
const SCALE := 4.0
# On a loaded machine the scaled span runs slower than 4x; the full span then ends at
# FULL_WALL_MS of wall time if it has camped FULL_MIN seconds, and says so.
const FULL_WALL_MS := 100000
const FULL_MIN := 30.0

var _game
var _driver
var _failures := 0
var _role := "hold"
var _sim := 0.0
var _done := false
var _base_tps := 90


func _initialize() -> void:
	_base_tps = Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = int(_base_tps * SCALE)
	Engine.max_physics_steps_per_frame = 64
	Engine.time_scale = SCALE
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _physics_process(delta: float) -> bool:
	if _done or _game.flow == null:
		return false
	if _driver == null:
		_game.tuning.set_option("loop_mode", "drop")
		_game.tuning.set_option("gun_role", _role)
		# Hit-stop sets time_scale back to 1; the span needs its scale held.
		_game.ctx._hit_stop = Callable()
		_driver = BotDriver.new(_game, "skipper", SEED)
		_driver.start()
		return false
	if _game.flow.state_name() in ["stage", "beacon"] and _game.run.max_hp < 9000.0:
		_game.run.set_max_hp(99999.0)
	_driver.tick(delta)
	if _game.flow.state_name() in ["stage", "beacon"]:
		_sim += delta
	var out_of_wall: bool = _role == "full" and Time.get_ticks_msec() > FULL_WALL_MS and _sim >= FULL_MIN
	if _sim >= CAMP_SECONDS[_role] or _driver.outcome == "died" or out_of_wall:
		return _judge()
	return false


func _judge() -> bool:
	var warden = _game.flow.warden
	var drop = warden.get("drop") if is_instance_valid(warden) else null
	if drop == null:
		_report(_role, false, "no drop rules on the stage 1 Warden in drop mode")
		return _finish()
	var d: Dictionary = drop.damage
	var summary := "%.0f s camping as %s (bot %s): Warden %.0f / %.0f HP, drop %.1f, gun %.1f, lapsed share %.1f, windows %d, drops %d, staggers %d, core misses %d" \
		% [_sim, _driver.class_id(), _driver.outcome if _driver.outcome != "" else "camping", warden.hp, warden.max_hp,
			d["drop"], d["gun"], d["banked_lost"], drop.windows, drop.drops_landed, drop.staggers, drop.misses]
	var lasted: bool = _sim >= CAMP_SECONDS[_role] - 0.5 or (_role == "full" and _sim >= FULL_MIN)
	if _role == "hold":
		_report("hold camper deals 0", lasted and warden.hp == warden.max_hp and drop.drops_landed == 0 and drop.windows >= 20, summary)
		_report("hold gun only holds", d["gun"] == 0.0 and (d["banked_lost"] > 0.0 or drop.held == 0.0),
			"the gun's banked share lapsed (%.1f) instead of landing" % d["banked_lost"])
		_role = "full"
		_game.tuning.set_option("gun_role", "full")
		_game.flow.retry_stage()
		# The bot calls a 240 s stage stalled and stops; the retry is a fresh stage.
		_driver.outcome = ""
		_sim = 0.0
		return false
	_report("full camper opens nothing", lasted and warden.hp == warden.max_hp and drop.staggers == 0
		and d["stagger_gun"] == 0.0 and d["gun"] == 0.0 and drop.windows >= 10, summary)
	return _finish()


func _finish() -> bool:
	_done = true
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = _base_tps
	print("loop_camper_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
	return true
