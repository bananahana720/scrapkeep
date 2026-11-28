extends "res://tools/bot_run.gd"

const Parts := preload("res://src/build/parts.gd")
const PartOffers := preload("res://src/build/part_offers.gd")
const StageModifier := preload("res://src/world/events/stage_modifier.gd")


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
const RELEASES := {"harpoon_held": "harpoon_released", "fire_held": "fire_released", "shift_held": "shift_released"}
const QUITS := 2
const QUIT_GAP_S := 30.0
const LOW_HULL := 0.15

var _mode := ""
var _spam_until := 0.0
var _rng := RandomNumberGenerator.new()
var _file: FileAccess = null
var _hooked_id := 0
var _counts := {}
var _peaks := {"speed": 0.0, "cogs": 0, "scrap": 0, "cores": 0, "parts": 0, "hp_max": 0.0}
var _rows := 0
var _seed := 0
var _holds := {}
var _stick := Vector2.ZERO
var _stick_left := 0
var _pause_left := 0
var _paused_since := -1
var _undying := 0
var _state := ""
var _state_ticks := 0
var _frozen_told := false
var _second := -1.0
var _cogs_at := 0
var _scrap_at := 0
var _quit_at: Array[float] = []
var _quits := 0
var _saved := {}
var _resuming := false
var _before := {}
var _terminal_checked := false
var _resumed_tick := 0
var _quit_state := ""
var _quit_state_s := 0.0
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


func _spam() -> void:
	var source = _driver.source
	for key in PRESSES:
		if _rng.randf() < PRESS_CHANCE:
			source.press[key] = _rng.randi_range(0, 2) if key == "slot_pick" else true
	for key in HOLDS:
		if _rng.randf() < HOLD_CHANCE:
			_holds[key] = _rng.randi_range(5, 90)
	for key in _holds.keys():
		_holds[key] -= 1
		if _holds[key] < 0:
			_holds.erase(key)
			if key in RELEASES:
				source.press[RELEASES[key]] = true
		else:
			source.hold[key] = true
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


func _check_resume() -> void:
	if _game == null or _game.run == null:
		_row_dead("resume", {"why": "no game after Continue"})
		return
	var run = _game.run
	var now := {"stage": run.stage, "cogs": run.cogs, "parts": run.parts.size(), "cores": run.bonus_cores,
		"death_save_spent": run.death_save_spent, "hp": snappedf(run.hp, 0.01), "state": _game.flow.state_name()}
	var want := {"stage": int(_saved.get("stage", 0)), "cogs": int(_saved.get("cogs", 0)),
		"parts": (_saved.get("parts", []) as Array).size(), "cores": int(_saved.get("bonus_cores", 0)),
		"death_save_spent": bool(_saved.get("death_save_spent", false)),
		"hp": snappedf(float(_saved.get("hp", 0.0)), 0.01)}
	if bool(_saved.get("cleared", false)) and (now["stage"] == want["stage"] + 1 or now["state"] == "boss"):
		want["stage"] = now["stage"]
	var wrong := []
	for key in want:
		if now[key] != want[key]:
			wrong.append(key)
	if run.cogs > int(_before["cogs"]) and run.stage == int(_before["stage"]):
		wrong.append("cogs_above_quit")
	if run.parts.size() > int(_before["parts"]) and run.stage == int(_before["stage"]):
		wrong.append("parts_above_quit")
	if bool(_before["death_save_spent"]) and not run.death_save_spent and run.stage == int(_before["stage"]):
		wrong.append("death_save_refilled")
	if String(_before["state"]) in ["gates", "launch", "boss", "victory"] and run.stage == int(_before["stage"]) \
			and _game.flow.state_name() == "stage" and (run.cogs < int(_before["cogs"]) or run.parts.size() < int(_before["parts"])):
		wrong.append("cleared_stage_lost")
	if String(_before["state"]) == "victory" and _game.flow.state_name() == "boss":
		wrong.append("won_boss_refought")
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
		_on_stage_entered(_game.run.stage, false)


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
			picks = PartOffers.roll_gate(rng, PartOffers.gate_rarities(rng.randi_range(0, 2)), class_id, parts, 2, rng.randi_range(1, 3), {}, Parts.offer_ops())
			if not picks.is_empty():
				picks = [picks[rng.randi_range(0, picks.size() - 1)]]
		elif roll < 8:
			picks = Parts.roll(rng, PartOffers.SOURCE_RARITIES["fabricator"], class_id, parts, 1)
		elif roll < 9:
			picks = Parts.roll(rng, PartOffers.SOURCE_RARITIES["vault"], class_id, parts, 1)
		else:
			picks = [PartOffers.milestone_for("event_%d" % rng.randi(), parts)]
		for part_id in picks:
			parts.append(part_id)
			run.add_part(part_id, "fuzz")


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
