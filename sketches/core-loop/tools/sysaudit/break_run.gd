extends "res://tools/bot_run.gd"

const Parts := preload("res://src/build/parts.gd")
const StageModifier := preload("res://src/world/events/stage_modifier.gd")

# Systems audit pass F (docs/systems-audit/break-it/): a bot run that tries to break world 1, with
# a watch that writes one row a break. Wraps bot_run; the run, the policy and its bots.ndjson row
# are bot_run's. One seed per process (bot_run forks children that run bot_run.gd itself):
#
#   godot --headless --fixed-fps 90 --path sketches/core-loop --script res://tools/sysaudit/break_run.gd \
#     -- --out=<abs dir> --policy=skipper --seeds=<n> --table=park --until=6 --qa-log=1 --break=spam
#
# --break picks the attack (each is seeded from the run seed, so a row's command replays it):
#   spam   on top of the policy's own input, mashes every key a pad or keyboard has: jump, the go verb
#          (Sable's boost, Rivet's sprint, Kest's blink), interact, fire, harpoon press and release, cancel,
#          slot picks, the ultimate, the racked active, short holds of each, a random stick now and
#          then, and pause pressed and lifted a few ticks later. It keeps mashing through launches,
#          cards and the boss, so an input taken in the wrong state (a sequence break) shows up.
#          --spam-until=<s> stops the mash at that run second: a stall that clears once the mash stops
#          was the bot's hands, not a broken game.
#   quit   quits the game at seeded moments without a save, as a closed window or a crash does, and
#          continues from the title's Continue (flow.resume_run) in a fresh Game. The row checks
#          the resumed run is the saved entrance and never more: cogs, parts, cores, the death save, hull.
#          --quit-in=<state>:<s> quits once after s seconds in a flow state (beacon is the Warden
#          fight, gates the open gates after a break, launch the flight, boss the boss arena).
#   stack  stacks every buff with every debuff: a random legal build of 6 to 14 parts (item_fuzz's
#          draft), a curse deal taken, scrap wear on (the default), and the hull set to 15% at each
#          new stage. Stage modifiers are the run seed's own; a "modifier" row names each stage's.
# Every mode watches each tick and writes break-<seed>.ndjson:
#   nonfinite  ball position or velocity, hull or max hull not a finite number
#   hull_over  hull above max hull
#   undying    hull at or below zero in play for over UNDYING_S without the run ending
#   speed      ball speed over SPEED_CAP m/s
#   abyss      ball below ABYSS_Y or over FAR_M from the origin (the fall rescue is play_watch's "fell")
#   negative   scrap, cogs or bonus cores below zero
#   surge      cogs or scrap up by more than SURGE_* within one game second
#   frozen     the flow sat in one state outside play (title, cards, summary) for FROZEN_S of ticks
#   paused     the tree left paused for PAUSED_S of ticks after the bot lifted its pause
#   resume     (quit) the continued run differs from the saved entrance, or holds more than it
#   resurrect  (quit) a run that ended (death or the summary) still offers a Continue; a "terminal"
#              row records each check
# and a "summary" row at the end with the peaks and the counts by kind. bot_run's qa-<seed>.ndjson
# (--qa-log=1) has stuck, hung, wedged and fell.

const UNDYING_S := 1.0
const SPEED_CAP := 200.0
const ABYSS_Y := -400.0
const FAR_M := 6000.0
const SURGE_COGS := 400
const SURGE_SCRAP := 400
const FROZEN_S := 30.0
const PAUSED_S := 2.0
const TICK_HZ := 90.0
const PRESS_CHANCE := 0.03
const HOLD_CHANCE := 0.01
const STICK_CHANCE := 0.004
const PAUSE_CHANCE := 0.002
const PRESSES := ["jump_pressed", "shift_pressed", "mount_pressed", "interact_pressed", "fire_pressed",
	"harpoon_pressed", "harpoon_released", "cancel_pressed", "ultimate_pressed", "active_pressed", "slot_pick"]
const HOLDS := ["jump_held", "shift_held", "brake_held", "fire_held", "harpoon_held", "mount_held"]
const QUITS := 2
# A quit waits this long after the last Continue, so each continued run plays before the next quit.
const QUIT_GAP_S := 30.0
const LOW_HULL := 0.15

var _mode := ""
# --spam-until=<s> stops the mash at that run second, to tell a bot the mash confused from a game left broken.
var _spam_until := 0.0
var _rng := RandomNumberGenerator.new()
var _file: FileAccess = null
var _hooked_id := 0
var _counts := {}
var _peaks := {"speed": 0.0, "cogs": 0, "scrap": 0, "cores": 0, "parts": 0, "hp_max": 0.0}
var _rows := 0
var _seed := 0
# spam
var _holds := {}
var _stick := Vector2.ZERO
var _stick_left := 0
var _pause_left := 0
var _paused_since := -1
# watch
var _undying := 0
var _state := ""
var _state_ticks := 0
var _frozen_told := false
var _second := -1.0
var _cogs_at := 0
var _scrap_at := 0
# quit: bot_run ticks across the whole process (a Continue rewinds run_time to the entrance)
var _quit_at: Array[float] = []
var _quits := 0
var _saved := {}
var _resuming := false
var _before := {}
var _terminal_checked := false
var _resumed_tick := 0
# --quit-in=<state>:<s> quits once, after s seconds in that flow state, in place of the seeded moments.
var _quit_state := ""
var _quit_state_s := 0.0
# stack
var _drafted := false
var _stacked_stages := {}


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--break="):
			_mode = arg.substr(8)
		elif arg.begins_with("--quit-in="):
			var parts := arg.substr(10).split(":")
			_quit_state = parts[0]
			_quit_state_s = float(parts[1]) if parts.size() > 1 else 1.0
		elif arg.begins_with("--spam-until="):
			_spam_until = float(arg.substr(13))
	if _mode not in ["spam", "quit", "stack"]:
		printerr("break_run: --break must be spam, quit or stack")
		quit(2)
		return
	super()


func _physics_process(delta: float) -> bool:
	var over := super(delta)
	if _game == null or _game.flow == null or _game.run == null or _driver == null:
		if over or _game == null:
			_close_if_done()
		return over
	if _game.get_instance_id() != _hooked_id:
		_hook()
	_watch(delta)
	match _mode:
		"spam":
			if _spam_until <= 0.0 or _game.run.run_time < _spam_until:
				_spam()
		"quit":
			_maybe_quit()
		"stack":
			_stack()
	return over


func _hook() -> void:
	var first := _hooked_id == 0
	_hooked_id = _game.get_instance_id()
	_resumed_tick = _ticks
	if first:
		_seed = _seeds[_index]
		_rng.seed = hash(["break", _mode, _seed])
		_file = FileAccess.open(_out.path_join("break-%d.ndjson" % _seed), FileAccess.WRITE)
		if _mode == "quit":
			for i in QUITS:
				_quit_at.append(_rng.randf_range(20.0, 300.0) * TICK_HZ)
			_quit_at.sort()
	_state = ""
	_state_ticks = 0
	_undying = 0
	_second = -1.0
	_game.events.stage_entered.connect(_on_stage_entered)
	_game.events.flow_changed.connect(_on_flow_changed)
	if _resuming:
		_resuming = false
		_check_resume.call_deferred()


func _row(kind: String, data := {}) -> void:
	_counts[kind] = int(_counts.get(kind, 0)) + 1
	# One row a kind a stage is enough to place it; the count keeps the rest.
	if int(_counts[kind]) > 3 and kind != "resume":
		return
	var ball: Vector3 = _game.player.ball_position()
	var row := {"kind": kind, "seed": _seed, "mode": _mode, "t": snappedf(_game.run.run_time, 0.01), "stage": _game.run.stage,
		"state": _game.flow.state_name(), "at": [snappedf(ball.x, 0.1), snappedf(ball.y, 0.1), snappedf(ball.z, 0.1)],
		"goal": String(_driver.get("_goal"))}
	row.merge(data)
	_file.store_line(JSON.stringify(row))
	_file.flush()
	_rows += 1
	print("break_run: " + JSON.stringify(row))


func _watch(_delta: float) -> void:
	var run = _game.run
	var player = _game.player
	var pos: Vector3 = player.ball_position()
	var vel: Vector3 = player.state.velocity
	if not (pos.is_finite() and vel.is_finite() and is_finite(run.hp) and is_finite(run.max_hp)):
		_row("nonfinite", {"v": [vel.x, vel.y, vel.z], "hp": str(run.hp), "hp_max": str(run.max_hp)})
		return
	_peaks["speed"] = maxf(_peaks["speed"], vel.length())
	_peaks["cogs"] = maxi(_peaks["cogs"], run.cogs)
	_peaks["scrap"] = maxi(_peaks["scrap"], run.scrap)
	_peaks["cores"] = maxi(_peaks["cores"], run.bonus_cores)
	_peaks["parts"] = maxi(_peaks["parts"], run.parts.size())
	_peaks["hp_max"] = maxf(_peaks["hp_max"], run.max_hp)
	if run.hp > run.max_hp + 0.01:
		_row("hull_over", {"hp": run.hp, "hp_max": run.max_hp})
	var playing: bool = _game.flow.in_play() and not _game.get_tree().paused
	if playing and run.hp <= 0.0 and not run.over:
		_undying += 1
		if _undying == int(UNDYING_S * TICK_HZ):
			_row("undying", {"hp": run.hp})
	else:
		_undying = 0
	if vel.length() > SPEED_CAP:
		_row("speed", {"speed": snappedf(vel.length(), 0.1)})
	if pos.y < ABYSS_Y or Vector2(pos.x, pos.z).length() > FAR_M:
		_row("abyss", {})
	if run.scrap < 0 or run.cogs < 0 or run.bonus_cores < 0:
		_row("negative", {"scrap": run.scrap, "cogs": run.cogs, "cores": run.bonus_cores})
	if run.run_time >= _second + 1.0:
		if _second >= 0.0:
			if run.cogs - _cogs_at > SURGE_COGS:
				_row("surge", {"what": "cogs", "from": _cogs_at, "to": run.cogs})
			if run.scrap - _scrap_at > SURGE_SCRAP:
				_row("surge", {"what": "scrap", "from": _scrap_at, "to": run.scrap})
		_second = run.run_time
		_cogs_at = run.cogs
		_scrap_at = run.scrap
	var state: String = _game.flow.state_name()
	if state != _state:
		_state = state
		_state_ticks = 0
		_frozen_told = false
	else:
		_state_ticks += 1
	if not _game.flow.in_play() and state not in ["dead", "summary"] and _state_ticks >= int(FROZEN_S * TICK_HZ) and not _frozen_told:
		_frozen_told = true
		_row("frozen", {})
	if _game.get_tree().paused and _pause_left <= 0:
		if _paused_since < 0:
			_paused_since = _ticks
		elif _ticks - _paused_since == int(PAUSED_S * TICK_HZ):
			_row("paused", {"toggled": _game.pause_toggled(), "notes": _game.notes_held()})
	else:
		_paused_since = -1


# The mash rides on the driver's own input for this tick: the driver rewrites source.hold every
# tick and Scripted.poll clears source.press after the player reads it.
func _spam() -> void:
	var source = _driver.source
	for key in PRESSES:
		if _rng.randf() < PRESS_CHANCE:
			source.press[key] = _rng.randi_range(0, 2) if key == "slot_pick" else true
	for key in HOLDS:
		if _rng.randf() < HOLD_CHANCE:
			_holds[key] = _rng.randi_range(5, 90)
	for key in _holds.keys():
		source.hold[key] = true
		_holds[key] -= 1
		if _holds[key] <= 0:
			_holds.erase(key)
			if key == "harpoon_held":
				source.press["harpoon_released"] = true
	if _stick_left <= 0 and _rng.randf() < STICK_CHANCE:
		_stick = Vector2.from_angle(_rng.randf() * TAU)
		_stick_left = _rng.randi_range(9, 45)
	if _stick_left > 0:
		_stick_left -= 1
		source.hold["move"] = _stick
	if _pause_left > 0:
		_pause_left -= 1
		if _pause_left == 0 and _game.pause_toggled():
			_game.toggle_pause()
	elif _rng.randf() < PAUSE_CHANCE and not _game.pause_toggled():
		_game.toggle_pause()
		_pause_left = _rng.randi_range(1, 30)


# A quit is a free with no save: what is on disk is what the last entrance wrote. bot_run's next
# game is the same seed with --from-stage at the saved stage, which continues through
# flow.resume_run, as the title's Continue does.
func _maybe_quit() -> void:
	if _quit_state != "":
		if _quits == 0 and _state == _quit_state and _state_ticks >= int(_quit_state_s * TICK_HZ) and not _game.run.over:
			_quit_at = [float(_ticks)]
			_resumed_tick = -100000
		elif _quits == 0:
			return
	if _quits >= _quit_at.size() or _ticks < _quit_at[_quits] or _ticks - _resumed_tick < QUIT_GAP_S * TICK_HZ \
			or _game.run.over:
		return
	var doc: Dictionary = _game.flow.saved_run()
	if doc.is_empty():
		return
	_quits += 1
	var run = _game.run
	_saved = doc
	_before = {"stage": run.stage, "cogs": run.cogs, "parts": run.parts.size(), "cores": run.bonus_cores,
		"death_save_spent": run.death_save_spent, "hp": run.hp, "state": _game.flow.state_name()}
	_row("quit", {"saved_stage": int(doc.get("stage", 0)), "before": _before})
	_settings["from-stage"] = str(int(doc.get("stage", 1)))
	_resuming = true
	_driver = null
	_qa = null
	_audit = null
	_index -= 1
	_game.free()
	_game = null
	Engine.time_scale = 1.0
	_next_pending = true


# Called the tick after a continued run's first tick: the run must be the saved entrance.
func _check_resume() -> void:
	if _game == null or _game.run == null:
		_row_dead("resume", {"why": "no game after Continue"})
		return
	var run = _game.run
	var now := {"stage": run.stage, "cogs": run.cogs, "parts": run.parts.size(), "cores": run.bonus_cores,
		"death_save_spent": run.death_save_spent, "hp": snappedf(run.hp, 0.01), "state": _game.flow.state_name()}
	var want := {"stage": int(_saved.get("stage", 0)), "cogs": int(_saved.get("cogs", 0)),
		"parts": (_saved.get("parts", []) as Array).size(), "death_save_spent": bool(_saved.get("death_save_spent", false)),
		"hp": snappedf(float(_saved.get("hp", 0.0)), 0.01)}
	var wrong := []
	for key in want:
		if now[key] != want[key]:
			wrong.append(key)
	# More than was held when the game was quit is a duplicate whatever the doc says.
	if run.cogs > int(_before["cogs"]) and run.stage == int(_before["stage"]):
		wrong.append("cogs_above_quit")
	if run.parts.size() > int(_before["parts"]) and run.stage == int(_before["stage"]):
		wrong.append("parts_above_quit")
	if bool(_before["death_save_spent"]) and not run.death_save_spent and run.stage == int(_before["stage"]) \
			and bool(_saved.get("death_save_spent", false)):
		wrong.append("death_save_refilled")
	_row("resume", {"ok": wrong.is_empty(), "wrong": wrong, "now": now, "saved": want, "before": _before})


func _row_dead(kind: String, data: Dictionary) -> void:
	_counts[kind] = int(_counts.get(kind, 0)) + 1
	var row := {"kind": kind, "seed": _seed, "mode": _mode}
	row.merge(data)
	_file.store_line(JSON.stringify(row))
	_file.flush()


func _stack() -> void:
	if not _drafted and _game.flow.in_stage():
		_drafted = true
		_draft()
		_curse()
		if _game.build != null:
			_game.build.recompute()
		_row("stacked", {"parts": Array(_game.run.parts), "cursed": _game.run.cursed()})
		# The run's first stage_entered fired before this wrapper hooked the game.
		_on_stage_entered(_game.run.stage, false)


# A terminal run must not come back from the title's Continue (BIBLE section 6). Deferred so the
# run end has cleared the store; it runs before the next tick, when bot_run frees the game.
func _on_flow_changed(state: String) -> void:
	if _mode == "quit" and state in ["dead", "summary"] and not _terminal_checked:
		_terminal_checked = true
		_check_terminal.call_deferred()


func _check_terminal() -> void:
	if _game == null or _game.flow == null:
		return
	var left: Dictionary = _game.flow.saved_run()
	_row("terminal", {"continue_offered": not left.is_empty()})
	if not left.is_empty():
		_row("resurrect", {"saved_stage": int(left.get("stage", 0))})


func _on_stage_entered(stage: int, retry: bool) -> void:
	if _mode == "stack" and not retry and not _stacked_stages.has(stage):
		_stacked_stages[stage] = true
		_low_hull.call_deferred()
		var modifier: Dictionary = StageModifier.for_stage(_game.run, _game.ctx.terrain, stage)
		_row("modifier", {"modifier": String(modifier.get("id", "none")), "cursed": _game.run.cursed()})


func _low_hull() -> void:
	if _game == null or _game.run == null:
		return
	_game.run.hp = _game.run.max_hp * LOW_HULL


# item_fuzz's draft: 6 to 14 legal parts from the game's own rolls.
func _draft() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["fuzz", _seed])
	var run = _game.run
	var class_id: String = run.class_id()
	var parts: Array = []
	var want := rng.randi_range(6, 14)
	var tries := 0
	while parts.size() < want and tries < 200:
		tries += 1
		var roll := rng.randi_range(0, 9)
		var picks: Array = []
		if roll < 6:
			picks = Parts.roll_gate(rng, Parts.gate_rarities(rng.randi_range(0, 2)), class_id, parts, 2, rng.randi_range(1, 3))
			if not picks.is_empty():
				picks = [picks[rng.randi_range(0, picks.size() - 1)]]
		elif roll < 8:
			picks = Parts.roll(rng, Parts.SOURCE_RARITIES["fabricator"], class_id, parts, 1)
		elif roll < 9:
			picks = Parts.roll(rng, Parts.SOURCE_RARITIES["vault"], class_id, parts, 1)
		else:
			picks = [Parts.milestone_for("event_%d" % rng.randi(), parts)]
		for part_id in picks:
			parts.append(part_id)
			run.add_part(part_id, "fuzz")


# A curse deal taken on stage 1, as RunState.cursed() reads it.
func _curse() -> void:
	var memory: Dictionary = _game.run.trade_memory
	memory.seen.append({"curse": true, "stage": 1})
	memory.decisions["1"] = true
	memory.risk_taken = true


func _close_if_done() -> void:
	if _file == null or _next_pending and _resuming:
		return
	_file.store_line(JSON.stringify({"kind": "summary", "seed": _seed, "mode": _mode, "counts": _counts,
		"quits": _quits, "peaks": _peaks}))
	_file.close()
	_file = null
