extends Node


const Achievements := preload("res://src/core/achievements.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const PilotStory := preload("res://src/core/pilot_story.gd")
const Secrets := preload("res://src/core/secrets.gd")
const ShiftBoard := preload("res://src/core/shift_board.gd")
const WorkOrders := preload("res://src/core/work_orders.gd")

signal work_order_changed(order_id: String, phase: String, summary: Dictionary)
signal story_chapter_punched(cast_id: String, chapter: int, chapter_id: String)

const STAT_PREFIX := "ach."
const SAVE_POINTS := ["player_died", "run_ended"]
const LEDGER_WORLDS := 3
const LEDGER_FOUND := "ledger.found.%d"
const LEDGER_RETURNED := "ledger.returned.%d"
const LEDGER_FACT := "ledger_returned"

var rows: Dictionary = Achievements.ROWS

var warnings := 0
var board_line := ""

var _events
var _run
var _profile
var _now := Callable()
var _world := 0
var _won := false
var _rows_on := {}
var _active_rows := {}
var _codex
var _board_before: Array = []
var _wo_tracker := {}
var _wo_shift_paid := {}
var _story_chapter_hook := Callable()


func set_story_chapter_hook(resolver: Callable) -> void:
	_story_chapter_hook = resolver


func setup(events, run, profile, now := Callable(), codex = null) -> void:
	_events = events
	_run = run
	_profile = profile
	_codex = codex
	_now = now if now.is_valid() else Callable(Time, "get_unix_time_from_system")
	_board_before = ShiftBoard.stamped_ids(profile)
	_wo_tracker = {}
	_wo_shift_paid = {}
	_active_rows = Achievements.all_rows() if rows == Achievements.ROWS else rows
	_rows_on.clear()
	for id in _active_rows:
		var on := String(_active_rows[id].get("on", ""))
		if not _rows_on.has(on):
			_rows_on[on] = []
		_rows_on[on].append(id)
	var wanted := {"world_entered": true, "run_started": true, "boss_defeated": true, "trade_taken": true}
	for on in _rows_on:
		wanted[on] = true
	for on in WorkOrders.all_signals():
		wanted[on] = true
	for on in SAVE_POINTS:
		wanted[on] = true
	var arg_names := {}
	for info in events.get_signal_list():
		var names: Array = []
		for arg in info["args"]:
			names.append(arg["name"])
		arg_names[info["name"]] = names
	for signal_name in wanted:
		if arg_names.has(signal_name):
			_connect(signal_name, arg_names[signal_name])
	backfill_rewards()
	backfill_discoveries()
	backfill_secrets()
	if open_met_pilots() > 0 and not _profile.save_if_allowed():
		warnings += 1
		push_warning("progress: earned pilots opened but not saved: %s" % _profile.last_error)


func backfill_rewards() -> int:
	if _profile == null:
		return 0
	var owed: Array = []
	for id in rows:
		if not _profile.earned(id):
			continue
		var reward: Dictionary = rows[id].get("reward", {})
		for kind in reward:
			if _paid_in_memory(id, String(kind), String(reward[kind])):
				_grant_reward_now(id, String(kind), String(reward[kind]))
			else:
				owed.append([id, String(kind), String(reward[kind])])
	if owed.is_empty():
		return 0
	return int(_profile.transact(_backfill_now.bind(owed)))


func _backfill_now(owed: Array) -> int:
	var granted := 0
	for row in owed:
		if _grant_reward(row[0], row[1], row[2]):
			granted += 1
	return granted


func _grant_reward(id: String, kind: String, target: String) -> bool:
	if _paid_in_memory(id, kind, target):
		return _grant_reward_now(id, kind, target)
	return bool(_profile.transact(_grant_reward_now.bind(id, kind, target)))


func _paid_in_memory(id: String, kind: String, target: String) -> bool:
	var legacy := "reward:%s:%s" % [id, kind]
	return _is_settled("%s:%s" % [legacy, target]) or (_profile.is_settled(legacy) and not _has_targeted(legacy))


func _grant_reward_now(id: String, kind: String, target: String) -> bool:
	var legacy := "reward:%s:%s" % [id, kind]
	var key := "%s:%s" % [legacy, target]
	if _profile.is_settled(legacy) and not _has_targeted(legacy):
		settle(key, false)
		return false
	if _is_settled(key):
		return false
	settle(legacy, false)
	return grant_once(key, kind, target)


func _is_settled(id: String) -> bool:
	return (_profile != null and _profile.is_settled(id)) or (_run != null and _run.settled.has(id))


func _has_targeted(legacy: String) -> bool:
	var prefix := legacy + ":"
	var ids: Array = _profile.settled_ids() if _profile != null else []
	if _run != null:
		ids = ids + Array(_run.settled)
	for settled_id in ids:
		if String(settled_id).begins_with(prefix):
			return true
	return false


func backfill_discoveries() -> int:
	if _profile == null or _codex == null or not _codex.has_method("known"):
		return 0
	var earned := 0
	for id in rows:
		var row: Dictionary = rows[id]
		if row.get("on", "") != "synergy_discovered" or _profile.earned(id):
			continue
		var where: Dictionary = row.get("where", {})
		if not where.has("synergy_id") or not _codex.known(String(where["synergy_id"])):
			continue
		if _profile.stat(STAT_PREFIX + id) < float(row.get("count", 1)):
			_profile.set_stat(STAT_PREFIX + id, float(row.get("count", 1)))
		_earn(id, row)
		earned += 1
	return earned


func backfill_secrets() -> int:
	if _profile == null or not _profile.earned(Secrets.UNLOCK):
		return 0
	var earned := 0
	for pilot in Secrets.PAINT_ROWS:
		var id: String = Secrets.PAINT_ROWS[pilot]
		if not rows.has(id) or _profile.earned(id):
			continue
		_profile.set_stat(STAT_PREFIX + id, maxf(_profile.stat(STAT_PREFIX + id), float(rows[id].get("count", 1))))
		_earn(id, rows[id])
		earned += 1
	return earned


func count_of(id: String) -> float:
	return _profile.stat(STAT_PREFIX + id) if _profile != null else 0.0


func settle(id: String, save := true) -> bool:
	var fresh := true
	if _run != null:
		if _run.settled.has(id):
			fresh = false
		else:
			_run.settled.append(id)
	if _profile != null:
		if not _profile.settle(id):
			fresh = false
		elif fresh and save and not _profile.save_if_allowed():
			warnings += 1
			push_warning("progress: %s settled but not saved: %s" % [id, _profile.last_error])
	return fresh


func reconcile_settled() -> void:
	if _run == null or _profile == null:
		return
	for id in _profile.settled_ids():
		if not _run.settled.has(id):
			_run.settled.append(id)
	var added := false
	for id in _run.settled:
		var sid := String(id)
		if sid.begins_with("reward:") or sid.begins_with("order:") or sid.begins_with("license:"):
			continue
		if _profile.settle(id):
			added = true
	if added:
		_profile.save_if_allowed()
	if not _is_bot_driven() and "extra" in _run and _run.extra is Dictionary:
		var saved_wo = _run.extra.get(WorkOrders.RUN_KEY)
		if saved_wo is Dictionary and not (saved_wo as Dictionary).is_empty():
			_wo_tracker = saved_wo
		elif not _wo_tracker.is_empty():
			_run.extra[WorkOrders.RUN_KEY] = _wo_tracker


func grant_once(id: String, kind: String, target: String) -> bool:
	if not settle(id, false):
		return false
	match kind:
		"pilot":
			open_met_pilots()
			if ClassDef.by_id(target) == null:
				_profile.unlock_pilot(target)
		"cosmetic":
			_profile.unlock_cosmetic(target)
		"world":
			_profile.unlock_world(target)
		"item":
			pass
	if not _profile.save_if_allowed():
		warnings += 1
		push_warning("progress: %s granted but not saved: %s" % [id, _profile.last_error])
	return true


func open_met_pilots() -> int:
	if _profile == null:
		return 0
	var earned := Callable(_profile, "earned")
	var opened := 0
	for def in ClassDef.all():
		if not def.starter and not _profile.has_pilot(def.id) and ClassDef.unlock_open(def.unlock, earned):
			_profile.unlock_pilot(def.id)
			opened += 1
	return opened


func leaves_returned() -> int:
	if _profile == null:
		return 0
	var count := 0
	for w in range(1, LEDGER_WORLDS + 1):
		if _profile.is_settled(LEDGER_RETURNED % w):
			count += 1
	return count


func return_leaves(at: Vector3) -> Array:
	if _profile == null:
		return []
	var returned: Array = []
	for w in range(1, LEDGER_WORLDS + 1):
		if _profile.is_settled(LEDGER_FOUND % w) and not _profile.is_settled(LEDGER_RETURNED % w):
			settle(LEDGER_RETURNED % w, false)
			returned.append(w)
	if returned.is_empty():
		return returned
	if not _profile.save_if_allowed():
		warnings += 1
		push_warning("progress: ledger leaves %s returned but not saved: %s" % [returned, _profile.last_error])
	for w in returned:
		_events.world_fact.emit(LEDGER_FACT, at)
	return returned


func earned_at(id: String) -> int:
	if _profile == null:
		return 0
	return _profile.earned_at(id)


func _connect(signal_name: String, names: Array) -> void:
	var sig: Signal = Signal(_events, signal_name)
	match names.size():
		0:
			sig.connect(func(): _fact(signal_name, names, []))
		1:
			sig.connect(func(a): _fact(signal_name, names, [a]))
		2:
			sig.connect(func(a, b): _fact(signal_name, names, [a, b]))
		3:
			sig.connect(func(a, b, c): _fact(signal_name, names, [a, b, c]))
		4:
			sig.connect(func(a, b, c, d): _fact(signal_name, names, [a, b, c, d]))
		_:
			push_warning("progress: %s has %d arguments; not listened to" % [signal_name, names.size()])


func _world_now() -> int:
	if _world >= 1:
		return _world
	if _run != null and _run.get("world") != null:
		return int(_run.get("world"))
	return 0


func _run_tier_now() -> int:
	if _run == null:
		return 0
	if _run.has_method("selected_run_tier"):
		return int(_run.selected_run_tier())
	if _run.get("run_tier") != null:
		return int(_run.get("run_tier"))
	return 0


func _is_bot_driven() -> bool:
	if _run != null and _run.get("bot_driven") is bool and bool(_run.get("bot_driven")):
		return true
	var parent := get_parent()
	if parent != null and parent.get("bot_driven") is bool:
		return bool(parent.get("bot_driven"))
	return false


func _is_sitting() -> bool:
	var parent := get_parent()
	var t = parent.get("tuning") if parent != null else null
	return t != null and t.has_method("sitting") and bool(t.sitting())


func _fact(signal_name: String, names: Array, values: Array) -> void:
	var fact := {}
	for i in names.size():
		fact[names[i]] = values[i]
	if signal_name == "world_entered":
		_world = int(fact.get("world", 0))
	elif signal_name == "run_started":
		_won = false
		_board_before = ShiftBoard.stamped_ids(_profile)
		board_line = ""
		_wo_shift_paid.clear()
		if _run != null:
			for sid in WorkOrders.SHIFT_ORDERS:
				_run.settled.erase(WorkOrders.SETTLE_ORDER_PREFIX + String(sid))
		_wo_tracker = WorkOrders.begin_run(_run, _profile, _is_bot_driven(), _is_sitting())
	elif signal_name == "run_ended":
		_won = bool(fact.get("won", false))
	elif signal_name == "boss_defeated" and _world_now() >= 1 and _world_now() <= LEDGER_WORLDS:
		settle(LEDGER_FOUND % _world_now())
	elif signal_name == "enemy_killed" and not _is_bot_driven():
		var rogue_id := PilotStory.patch_rogue_for_kind(String(fact.get("kind", "")))
		if rogue_id != "":
			if _codex != null and _codex.has_method("mark_known"):
				_codex.mark_known(rogue_id)
			if _events != null and _events.has_signal("world_fact"):
				_events.world_fact.emit("rogue_downed", fact.get("at", Vector3.ZERO))
	elif signal_name == "trade_taken" and _profile != null and not _is_bot_driven():
		var tkind := String(fact.get("kind", ""))
		if tkind == "trade_risk":
			_profile.add_stat("habit.trade_risk", 1.0)
		elif tkind == "trade_safe":
			_profile.add_stat("habit.trade_safe", 1.0)
	for id in _rows_on.get(signal_name, []):
		_evaluate(id, fact)
	if not _wo_tracker.is_empty() and _profile != null and not _is_bot_driven():
		var ctx := {"world": _world_now(), "pilot": _run.class_id() if _run != null else "", "run_tier": _run_tier_now()}
		var done_orders := WorkOrders.eval_fact(_wo_tracker, signal_name, fact, ctx)
		for order_id in done_orders:
			_complete_work_order(order_id)
	if signal_name == "run_ended":
		_record_run_habits()
		WorkOrders.close_run(_run, _profile, _wo_tracker, _is_bot_driven(), _is_sitting())
		_close_shift()
	if SAVE_POINTS.has(signal_name):
		_profile.save_if_allowed()
	if signal_name == "run_ended":
		_won = false


func _record_run_habits() -> void:
	if _profile == null or _is_bot_driven():
		return
	_profile.add_stat("habit.runs_total", 1.0)
	if _run != null:
		var pilot_id := String(_run.class_id())
		if pilot_id != "":
			_profile.add_stat("habit.pilot_runs." + pilot_id, 1.0)
			if _won and _run_tier_now() >= 1:
				PilotStory.record_overtime(pilot_id, _run_tier_now(), _profile)
		if _run.has_method("heft_class") and int(_run.call("heft_class")) >= 4:
			_profile.add_stat("habit.runs_heft_high", 1.0)
		var is_cursed := false
		if _run.has_method("cursed"):
			is_cursed = bool(_run.call("cursed"))
		elif _run.get("cursed") is bool:
			is_cursed = _run.get("cursed")
		elif _run.get("extra") is Dictionary and _run.get("extra").get("cursed") is bool:
			is_cursed = _run.get("extra").get("cursed")
		if is_cursed:
			_profile.add_stat("habit.runs_cursed", 1.0)


func _complete_work_order(order_id: String) -> void:
	if _profile == null:
		return
	var result: Variant = _profile.transact(_complete_work_order_now.bind(order_id))
	if result is Dictionary and not (result as Dictionary).is_empty():
		work_order_changed.emit(order_id, "completed", result)
		_notify_story_chapters(WorkOrders.SETTLE_ORDER_PREFIX + order_id)


func _complete_work_order_now(order_id: String) -> Dictionary:
	var row := WorkOrders.order(order_id)
	if row.is_empty():
		return {}
	var settle_key := WorkOrders.SETTLE_ORDER_PREFIX + order_id
	var is_shift := String(row.get("track", "")) == "shift"
	var maker := String(row.get("maker", ""))
	var tier_before := WorkOrders.license_tier(maker, _profile)
	if is_shift:
		if _wo_shift_paid.has(order_id) or (_run != null and _run.settled.has(settle_key)):
			return {}
		_wo_shift_paid[order_id] = true
		if _run != null and not _run.settled.has(settle_key):
			_run.settled.append(settle_key)
	else:
		if _is_settled(settle_key):
			return {}
		settle(settle_key, false)
	var pays: Dictionary = row.get("pays", {})
	for kind in pays:
		var target := String(pays[kind])
		match String(kind):
			"option":
				_profile.open_option(target)
			"tune":
				_profile.hear_tune(target)
	if is_shift and maker != "":
		_profile.add_stat(WorkOrders.LICENSE_SHIFT_STAT_PREFIX + maker, 1.0)
	var tier_after := WorkOrders.license_tier(maker, _profile)
	var new_tiers: Array[int] = []
	for t in range(maxi(1, tier_before + 1), tier_after + 1):
		var lic_key := "%s%s:%d" % [WorkOrders.SETTLE_LICENSE_PREFIX, maker, t]
		if settle(lic_key, false):
			new_tiers.append(t)
	if not _profile.save_if_allowed():
		warnings += 1
		push_warning("progress: work order %s completed but not saved: %s" % [order_id, _profile.last_error])
	return {
		"order_id": order_id,
		"maker": maker,
		"pays": pays.duplicate(true),
		"license_tier": tier_after,
		"new_license_tiers": new_tiers,
	}


func _notify_story_chapters(trigger_id: String) -> void:
	if not _story_chapter_hook.is_valid() or _profile == null:
		return
	var punched: Variant = _story_chapter_hook.call(trigger_id, _profile)
	if punched is Array:
		for item in punched:
			if item is Dictionary:
				story_chapter_punched.emit(String(item.get("cast", "")), int(item.get("num", 0)), String(item.get("id", "")))


func _evaluate(id: String, fact: Dictionary) -> void:
	if _profile.earned(id):
		return
	var row: Dictionary = _active_rows[id]
	var where: Dictionary = row.get("where", {})
	for key in where:
		if not fact.has(key) or fact[key] != where[key]:
			return
	var at_least: Dictionary = row.get("at_least", {})
	for key in at_least:
		var value = fact.get(key)
		if not (value is int or value is float) or float(value) < float(at_least[key]):
			return
	if row.has("pilot") and (_run == null or _run.class_id() != String(row["pilot"])):
		return
	var amount := 1.0
	if row.has("sum"):
		amount = float(fact.get(row["sum"], 0))
	_profile.add_stat(STAT_PREFIX + id, amount)
	if _profile.stat(STAT_PREFIX + id) < float(row.get("count", 1)):
		return
	if row.has("need") and not _need_met(row):
		return
	_earn(id, row)


func _close_shift() -> void:
	if _profile == null:
		return
	var fresh := ShiftBoard.stamped_ids(_profile).any(func(id): return not id in _board_before)
	var kills := int(_run.summary().get("kills", 0)) if _run != null else 0
	var punched := false
	if not fresh and kills >= int(ShiftBoard.TIME_CARD["min_kills"]):
		_profile.add_stat(ShiftBoard.PUNCH_STAT, 1.0)
		punched = true
	board_line = ShiftBoard.run_line(_board_before, _profile, punched)
	_board_before = ShiftBoard.stamped_ids(_profile)


func _need_met(row: Dictionary) -> bool:
	var key: String = row["need"]
	var value
	match key:
		"class":
			value = _run.class_id()
		"won":
			value = _won
		"world":
			value = _world_now()
		"run_tier":
			value = _run_tier_now()
		_:
			value = _run.summary().get(key)
			if value is Array:
				value = value.size()
	if row.has("min") or row.has("max"):
		if not (value is int or value is float or value is bool):
			return false
		var number := float(value)
		if row.has("min") and number < float(row["min"]):
			return false
		if row.has("max") and number > float(row["max"]):
			return false
		return true
	if value is String:
		return value != ""
	if value is bool:
		return value
	return float(value) != 0.0


func _earn(id: String, row: Dictionary) -> void:
	var silent: bool = Secrets.PAINT_ROWS.values().has(id)
	if not bool(_profile.transact(_earn_now.bind(id, row))):
		return
	if not silent:
		_events.achievement_earned.emit(id)
	_notify_story_chapters(id)


func _earn_now(id: String, row: Dictionary) -> bool:
	if not _profile.earn(id, float(_now.call())):
		return false
	var reward: Dictionary = row.get("reward", {})
	for kind in reward:
		_grant_reward(id, String(kind), String(reward[kind]))
	open_met_pilots()
	if not _profile.save():
		warnings += 1
		push_warning("progress: %s earned but not saved: %s" % [id, _profile.last_error])
	return true
