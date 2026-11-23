# smoke: bots timeout=1720s (in-process hand cases, then 32 capped bot runs in child processes, 16 at a time)
# 2026-10-12, W13 smoke triage: PASS in 674.124 s alone; 1.5x rounded up to 10 s is 1020 s, beyond the 360 s ordinary cap.
# 2026-10-24, w18 shard 5 on 3d466be2: PASS in 1146.0 s solo on a 4-core cloud box; 1.5x rounded up to 10 s is 1720 s,
# under the 1800 s bot ceiling. Only the cap changes.
extends SceneTree

const Game := preload("res://src/game.gd")
const BotDriver := preload("res://tools/bot_driver.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const UltimateMeter := preload("res://src/core/ultimate_meter.gd")
const Augments := preload("res://src/movement/augments.gd")
const T := preload("res://tests/support/t.gd")
const Weapons := preload("res://src/combat/weapons.gd")

# The bot's skill-bar adapter (SKILL-BAR.md section 8, unit B4 in section 10).
#
# Hand cases, on one real game in this process:
#   - The driver's source never names special_*, line_* or bay_pick: a scan of its text, and
#     every key it sends over SCAN_TICKS of a skipper run.
#   - _cast(2) sends the pick and the click on one tick and the router turns them into the
#     special's press; a slot already picked gets the click alone (a second pick is the undo);
#     a cast that did not commit sends 1 on the release tick; a cooling slot is not cast.
#   - The traversal pilot sends the pick through its press gate and the click CAST_GAP later,
#     one verb in press_ticks; the gate keeps slot_pick's int (0 is slot 1, not false).
#   - Q goes at a full meter with ULT_CROWD enemies within ULT_CROWD_RADIUS and not with one fewer;
#     while the set piece runs the hands send neither Space nor Q and cast nothing.
#
# Fill bands (section 4, "target fill times, checked by bots in B4"), over seeds 1 to 16 on the
# default table: the completionist's median first fill is at least COMPLETIONIST_FLOOR_S and at
# most COMPLETIONIST_MEDIAN_S of play, the camper's at least CAMPER_MEDIAN_S. A run that never fills counts as its play seconds, which
# for the camper is at least the band only when it played that long. Runs are capped, so a
# completionist that has not filled by its cap counts above the band. Where a run fired a set
# piece, its run log row carries fill_seconds.
const SCAN_TICKS := 1800
const SEEDS := 16
const COMPLETIONIST_MEDIAN_S := 90.0
# 2026-10-11 (wave 13 B4 fix round): the floor under the completionist's median, section 4's
# chaining-player floor; the band was one-sided before.
const COMPLETIONIST_FLOOR_S := 45.0
const CAMPER_MEDIAN_S := 180.0
# Ticks per capped run: the completionist past its band, the camper past its own.
const COMPLETIONIST_TICKS := 9000
const CAMPER_TICKS := 16650
const PARALLEL := 16
const DT := 1.0 / 90.0

var _t := T.new("bot_skill_bar_test")
var _game
var _driver
var _scan_ticks := 0
var _scan_bad := {}
var _phase := "boot"
var _pending: Array[Dictionary] = []
var _active: Array[Dictionary] = []
var _done: Array[Dictionary] = []
var _folder := ""


func _initialize() -> void:
	_folder = ProjectSettings.globalize_path("res://../../artifacts/local/bots/skill-bar")
	var suffix := 0
	while DirAccess.dir_exists_absolute(_folder + "-%d" % suffix):
		suffix += 1
	_folder += "-%d" % suffix
	DirAccess.make_dir_recursive_absolute(_folder)
	# Campers first: they run longest.
	for policy in ["camper", "completionist"]:
		for s in range(1, SEEDS + 1):
			_pending.append({"id": "%s-%d" % [policy, s], "policy": policy, "seed": s,
				"ticks": CAMPER_TICKS if policy == "camper" else COMPLETIONIST_TICKS})
	_scan_source()
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(delta: float) -> bool:
	match _phase:
		"boot":
			if _game.flow == null:
				return false
			_driver = BotDriver.new(_game, "skipper", 1)
			_driver.start()
			_phase = "scan"
		"scan":
			# The bot sends before the game's nodes read, as in tools/bot_run.gd.
			_driver.tick(delta)
			_scan_keys(_driver.source)
			_scan_ticks += 1
			if _scan_ticks >= SCAN_TICKS or _driver.outcome != "":
				_t.check("a skipper run's keys never name special_*, line_* or bay_pick", _scan_bad.is_empty(),
					"%d ticks scanned, outcome '%s', bad keys %s" % [_scan_ticks, _driver.outcome, _scan_bad.keys()])
				_phase = "hands"
		"hands":
			_hand_cases()
			_game.free()
			_game = null
			Engine.time_scale = 1.0
			if OS.get_cmdline_user_args().has("--hand-only"):
				_finish()
				return true
			_launch()
			_phase = "children"
		"children":
			# Every child is capped by --ticks; the smoke runner's timeout bounds the whole test.
			_reap()
			_launch()
			if not _active.is_empty() or not _pending.is_empty():
				return false
			_bands()
			_finish()
			return true
	return false


func _finish() -> void:
	quit(_t.verdict())


# --- the keys -----------------------------------------------------------------------------

static func _bad_key(key: String) -> bool:
	return key.begins_with("special_") or key.begins_with("line_") or key == "bay_pick"


func _scan_keys(source) -> void:
	for table in [source.hold, source.press]:
		for key in table:
			if _bad_key(String(key)):
				_scan_bad[key] = true


# The driver may read line state (kit.line_state) but never write a router output or the retired bay.
func _scan_source() -> void:
	var text := FileAccess.get_file_as_string("res://tools/bot_driver.gd")
	var found := []
	var writes := RegEx.create_from_string("\\[\"(special_[a-z]+|line_(pressed|held|released)|bay_pick)\"\\]")
	for m in writes.search_all(text):
		found.append(m.get_string(1))
	_t.check("bot_driver.gd writes no special_*, line_* or bay_pick key", found.is_empty(), "found %s" % [found])


# --- hand cases ---------------------------------------------------------------------------

func _fresh(policy: String):
	var driver := BotDriver.new(_game, policy, 1)
	driver.game.player.source = driver.source
	return driver


# The driver's constant, read through the script so a driver without it fails a check, not the parse.
static func _const(name: String, fallback):
	return (BotDriver as Script).get_script_constant_map().get(name, fallback)


func _has(driver, method: String) -> bool:
	return driver.has_method(method)


func _hand_cases() -> void:
	var player = _game.player
	var abilities = player.abilities
	var driver = _fresh("skipper")
	if not _has(driver, "_cast") or not _has(driver, "_cast_hands") or not _has(driver, "_ultimate_hands") or not _has(driver, "_set_piece_hands"):
		_t.check("the driver has the skill-bar hands (_cast, _cast_hands, _ultimate_hands, _set_piece_hands)", false, "missing")
		return
	_game.ctx.calm = true
	abilities.refill()
	abilities.snap_back("test")
	# 1. Pick and click on one tick reach the router as the special's press.
	# 2026-10-11 (wave 13 B4 fix round): re-pinned from "click up" to "click down". A mouse
	# reports a click as pressed and held on the tick it goes down; the tap lets it up on the
	# release tick (case 03). The click-up press stalled demolitions seed 4 at Brindle.
	driver.source.hold = {}
	driver.source.press = {}
	var cast_ok: bool = driver._cast(2)
	driver._cast_hands()
	var press: Dictionary = driver.source.press.duplicate()
	_t.check("01 _cast(2) on a ready slot sends slot_pick 1 and fire_pressed on one tick, click down",
		cast_ok and press.get("slot_pick", -1) == 1 and press.get("fire_pressed", false) == true and driver.source.hold.get("fire_held", false),
		"cast %s press %s hold %s" % [cast_ok, press, driver.source.hold])
	driver.source.poll(player.intent)
	player._route_slots(DT)
	_t.check("02 the router turns the pick and click into special_pressed and keeps it off the weapon",
		player.intent.special_pressed and not player.intent.fire_pressed, "special_pressed %s fire_pressed %s selected %s" % [
			player.intent.special_pressed, player.intent.fire_pressed, abilities.selected])
	# 3. With slot 2 still picked (no combat tick ran, so no cast committed), the release tick sends 1.
	driver._cast_hands()
	_t.check("03 a cast that did not commit sends 1 and lets the click up on the release tick", driver.source.press.get("slot_pick", -1) == 0
		and driver._cast_phase == "" and not driver.source.hold.get("fire_held", false),
		"press %s hold %s phase '%s'" % [driver.source.press, driver.source.hold, driver._cast_phase])
	driver.source.poll(player.intent)
	player._route_slots(DT)
	_t.eq("04 the 1 sends the pick home", abilities.selected, AbilityState.WEAPON)
	# 5. A slot already picked gets the click alone.
	abilities.select(AbilityState.SPECIAL)
	driver.source.press = {}
	driver._cast(2)
	driver._cast_hands()
	_t.check("05 a picked slot gets the click and no second pick (the undo)", not driver.source.press.has("slot_pick") and driver.source.press.get("fire_pressed", false),
		"press %s" % [driver.source.press])
	driver._cast_phase = ""
	abilities.snap_back("test")
	# 6. A cooling slot is not cast.
	abilities.spend(AbilityState.LINE)
	driver.source.press = {}
	_t.check("06 a cooling slot 3 is not cast", not driver._cast(3) and driver.source.press.is_empty(), "state %s" % abilities.state_of(AbilityState.LINE))
	abilities.refill()
	# 7. A held cast keeps the click down, then lets it up.
	driver.source.hold = {}
	driver._cast(3, 2.0 * DT)
	driver._cast_hands()
	var held_first: bool = driver.source.hold.get("fire_held", false)
	driver._cast_hands()
	driver._cast_hands()
	var held_after: bool = driver.source.hold.get("fire_held", false)
	driver._cast_hands()
	_t.check("07 a held cast picks 3, holds the click for its seconds, then lets it up", held_first and held_after
		and driver.source.press.get("slot_pick", -1) == 2 and not driver.source.hold.get("fire_held", false),
		"held first %s, after %s, press %s, hold %s" % [held_first, held_after, driver.source.press, driver.source.hold])
	driver._cast_phase = ""
	abilities.snap_back("test")
	_traversal_cases()
	_cadence_fire_cases()
	_ultimate_cases()


func _traversal_cases() -> void:
	var driver = _fresh("traversal")
	driver.source.press = {}
	driver.source.hold = {}
	driver._cast(2)
	driver._cast_hands()
	_t.check("08 the traversal pilot's cast sends the pick alone", driver.source.press.get("slot_pick", -1) == 1 and not driver.source.press.has("fire_pressed")
		and driver._cast_phase == "sent", "press %s phase '%s'" % [driver.source.press, driver._cast_phase])
	driver.ticks = 1000
	driver._last_press_tick = -1000000
	driver.press_ticks.clear()
	driver.source.press = {"slot_pick": 1}
	driver._gate_presses()
	_t.check("09 the press gate keeps slot_pick's int", typeof(driver.source.press.get("slot_pick")) == TYPE_INT and driver.source.press["slot_pick"] == 1,
		"press %s" % [driver.source.press])
	driver._traverse_click(true)
	var gap := int(ceil(float(_const("CAST_GAP", 0.1)) * Engine.physics_ticks_per_second))
	driver.source.press = {}
	driver.ticks = 1000 + gap - 1
	driver._traverse_click(false)
	var early: bool = driver.source.press.has("fire_pressed")
	driver.ticks = 1000 + gap
	driver._traverse_click(false)
	_t.check("10 the click follows the pick by CAST_GAP, outside the gate, one verb", not early and driver.source.press.get("fire_pressed", false)
		and driver.press_ticks.size() == 1, "early %s press %s press_ticks %s gap %d ticks" % [early, driver.source.press, driver.press_ticks, gap])
	driver.source.press = {"slot_pick": 0}
	driver._last_press_tick = -1000000
	driver._gate_presses()
	_t.check("11 slot_pick 0 (slot 1) passes the gate as a press", driver.source.press.get("slot_pick", -1) == 0, "press %s" % [driver.source.press])


# E1-06b: Rivet's press and Sable's tap-charge turn the bot's held fire into presses. The traversal
# pilot never fires (its cast clicks go out after the press gate) and the completionist's chain move
# fires nothing; a skipper tick on the same trigger is the control that the hand is armed.
func _cadence_fire_cases() -> void:
	var drv = _game.combat.weapon_driver
	var ball: Vector3 = _game.player.ball_position()
	var ahead: Vector3 = ball + Vector3.FORWARD * 20.0
	for wid in [Weapons.RAPID_LASER, Weapons.ARC_CASTER]:
		drv.reset(Weapons.base(wid))
		var skipper = _fresh("skipper")
		skipper.source.hold = {"fire_held": true}
		skipper.source.press = {}
		skipper._cadence_fire_hand()
		_t.check("c1 %s control: a skipper tick turns held fire into a press" % wid, skipper.source.press.get("fire_pressed", false),
			"trigger %s press %s" % [drv.state_snapshot()["trigger"], skipper.source.press])
		var traverse = _fresh("traversal")
		traverse.source.hold = {}
		traverse.source.press = {}
		traverse._drive(ahead, null, DT)
		_t.check("c2 %s: a traversal drive tick sends no fire_pressed or fire_released" % wid,
			not traverse.source.press.has("fire_pressed") and not traverse.source.press.has("fire_released"),
			"press %s hold %s" % [traverse.source.press, traverse.source.hold])
		var chain = _fresh("completionist")
		chain._chain_phase = "takeoff"
		chain.source.hold = {}
		chain.source.press = {}
		chain._act(ahead, null, DT)
		_t.check("c3 %s: the completionist's chain move sends no fire" % wid,
			not chain.source.press.has("fire_pressed") and not chain.source.press.has("fire_released")
			and not chain.source.hold.has("fire_held"), "press %s hold %s" % [chain.source.press, chain.source.hold])
		chain._chain_phase = ""
	drv.reset(_game.combat.pattern(_game.combat.active_weapon()))


func _ultimate_cases() -> void:
	var player = _game.player
	var ult = _game.combat.ultimate
	var driver = _fresh("skipper")
	ult.meter.refund(UltimateMeter.CAP)
	# The stage's own enemies leave the count, so the crowd is exactly the staged bodies.
	for node in get_nodes_in_group("enemy"):
		node.remove_from_group("enemy")
	var near := []
	for i in int(_const("ULT_CROWD", 3)):
		var body := StaticBody3D.new()
		body.collision_layer = Augments.ENEMY_MASK
		body.add_to_group("enemy")
		root.add_child(body)
		near.append(body)
	# The crowd rule alone. The earlier cases cast beside the stage Warden, whose open core is the other reason Q
	# goes (_core_open): its posture can stand staggered here. The ball stands out of the core's reach first.
	var warden = _game.flow.warden
	if is_instance_valid(warden):
		var away: Vector3 = player.ball_position() - warden.global_position
		away.y = 0.0
		if away.length() < 0.1:
			away = Vector3.RIGHT
		var clear: Vector3 = warden.global_position + away.normalized() * (float(_const("ULT_CORE_REACH", 45.0)) + 15.0)
		player.reset_to(_game.ctx.terrain.drop_point(clear.x, clear.z, 1.05))
	var ball: Vector3 = player.ball_position()
	for i in near.size():
		near[i].global_position = ball + Vector3(6.0 + 2.0 * i, 0.0, 0.0)
	# One of the crowd outside the radius: one fewer than ULT_CROWD.
	near[0].global_position = ball + Vector3(float(_const("ULT_CROWD_RADIUS", 20.0)) + 5.0, 0.0, 0.0)
	driver.source.press = {}
	driver._ultimate_hands(null)
	var short_crowd: bool = driver.source.press.has("ultimate_pressed")
	near[0].global_position = ball + Vector3(4.0, 0.0, 0.0)
	driver._ultimate_hands(null)
	_t.check("12 Q goes at a full meter with ULT_CROWD enemies near, not with one fewer",
		not short_crowd and driver.source.press.get("ultimate_pressed", false), "state %s, short crowd %s, press %s" % [
			player.abilities.ultimate()["state"], short_crowd, driver.source.press])
	# 13. The set piece up: no Space, no Q, no cast.
	var refusal: String = ult.press()
	driver.source.press = {"jump_pressed": true, "ultimate_pressed": true}
	driver._set_piece_hands()
	var cast_in_flight: bool = driver._cast(2)
	driver._ult_wait = 0.0
	driver._ultimate_hands(null)
	_t.check("13 while the set piece runs the hands send neither Space nor Q and cast nothing",
		ult.phase() != "idle" and driver.source.press.is_empty() and not cast_in_flight, "Q refusal '%s', phase %s, press %s, cast %s" % [
			refusal, ult.phase(), driver.source.press, cast_in_flight])
	for body in near:
		body.free()


# --- fill bands ---------------------------------------------------------------------------

func _launch() -> void:
	while _active.size() < PARALLEL and not _pending.is_empty():
		var trial: Dictionary = _pending.pop_front()
		var folder: String = _folder.path_join(trial["id"])
		DirAccess.make_dir_recursive_absolute(folder)
		var previous := {}
		for kind in ["DATA", "CONFIG", "CACHE"]:
			var key: String = "XDG_%s_HOME" % kind
			previous[key] = OS.get_environment(key)
			OS.set_environment(key, folder.path_join(kind.to_lower()))
		var args := PackedStringArray(["--headless", "--quiet", "--fixed-fps", "90", "--path",
			ProjectSettings.globalize_path("res://"), "--log-file", folder.path_join("engine.log"),
			"--script", "res://tools/bot_run.gd", "--",
			"--out=" + folder, "--policy=" + trial["policy"], "--seeds=%d" % trial["seed"], "--ticks=%d" % trial["ticks"]])
		trial["pid"] = OS.create_process(OS.get_executable_path(), args)
		for key in previous:
			if previous[key].is_empty():
				OS.unset_environment(key)
			else:
				OS.set_environment(key, previous[key])
		trial["folder"] = folder
		_active.append(trial)


func _reap() -> void:
	for index in range(_active.size() - 1, -1, -1):
		var trial: Dictionary = _active[index]
		if OS.is_process_running(trial["pid"]):
			continue
		trial["bot"] = _last_row(trial["folder"].path_join("bots.ndjson"))
		trial["run"] = _last_row(trial["folder"].path_join("runs.ndjson"))
		var log := FileAccess.get_file_as_string(trial["folder"].path_join("engine.log"))
		trial["errors"] = "SCRIPT ERROR" in log
		_done.append(trial)
		_active.remove_at(index)


static func _last_row(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var rows := FileAccess.get_file_as_string(path).split("\n", false)
	if rows.is_empty():
		return {}
	var row = JSON.parse_string(rows[-1])
	return row if row is Dictionary else {}


# The first fill, or the play seconds of a run whose meter never filled.
static func _first_fill(bot: Dictionary) -> float:
	var fills: Array = bot.get("ult_fill_s", [])
	if not fills.is_empty():
		return float(fills[0])
	return float(bot.get("play_s", 0.0))


static func _median(values: Array) -> float:
	if values.is_empty():
		return NAN
	var sorted := values.duplicate()
	sorted.sort()
	var n := sorted.size()
	return float(sorted[n / 2]) if n % 2 == 1 else (float(sorted[n / 2 - 1]) + float(sorted[n / 2])) * 0.5


func _bands() -> void:
	var by := {"camper": [], "completionist": []}
	var logged := 0
	var fired := 0
	var lines := []
	var errors := []
	for trial in _done:
		var bot: Dictionary = trial["bot"]
		if bot.is_empty() or trial["errors"]:
			errors.append(trial["id"])
			continue
		var fill := _first_fill(bot)
		(by[trial["policy"]] as Array).append(fill)
		# 2026-10-11 (wave 13 B4 fix round): each row names the meter's points by source at the first
		# fill and over the run, so a red band says which source drove it (SKILL-BAR section 4).
		lines.append("%s %s: first fill %.1f s (%s), play %.1f s, fills %s, set pieces %d, casts %s, outcome %s, first-fill sources %s, run sources %s" % [trial["id"], bot.get("class", ""),
			fill, "filled" if not (bot.get("ult_fill_s", []) as Array).is_empty() else "never", float(bot.get("play_s", 0.0)),
			bot.get("ult_fill_s", []), int(bot.get("ultimates", 0)), bot.get("slot_casts", {}), bot.get("outcome", ""),
			bot.get("ult_sources_first_fill", {}), bot.get("ult_sources", {})])
		if int(bot.get("ultimates", 0)) > 0:
			fired += 1
			var rows: Array = (trial["run"] as Dictionary).get("ultimates", [])
			if not rows.is_empty() and rows.all(func(r): return r is Dictionary and r.has("fill_seconds") and float(r["fill_seconds"]) > 0.0):
				logged += 1
	lines.sort()
	for line in lines:
		print(line)
	_t.check("every capped run left a bot record and no script error", errors.is_empty(), "missing or erroring: %s" % [errors])
	var comp: Array = by["completionist"]
	var camp: Array = by["camper"]
	_t.check("the completionist's median first fill over %d seeds is at most %.0f s of play" % [SEEDS, COMPLETIONIST_MEDIAN_S],
		comp.size() == SEEDS and _median(comp) <= COMPLETIONIST_MEDIAN_S, "median %.1f s over %d runs: %s" % [_median(comp), comp.size(), comp])
	# 2026-10-11 (wave 13 B4 fix round, SKILL-BAR section 4 "a chaining player 45 to 60 s"): the
	# completionist band gets a floor, so a meter that fills in seconds cannot pass it.
	_t.check("the completionist's median first fill over %d seeds is at least %.0f s of play" % [SEEDS, COMPLETIONIST_FLOOR_S],
		comp.size() == SEEDS and _median(comp) >= COMPLETIONIST_FLOOR_S, "median %.1f s over %d runs: %s" % [_median(comp), comp.size(), comp])
	_t.check("the camper's median first fill over %d seeds is at least %.0f s of play" % [SEEDS, CAMPER_MEDIAN_S],
		camp.size() == SEEDS and _median(camp) >= CAMPER_MEDIAN_S, "median %.1f s over %d runs: %s" % [_median(camp), camp.size(), camp])
	_t.check("every run that fired a set piece logged fill_seconds in its run log row", fired > 0 and logged == fired,
		"%d of %d runs that fired one" % [logged, fired])
