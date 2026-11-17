extends Node

# The achievement listener. It reads Achievements.ROWS, connects to the bus signals the
# rows name (plus world_entered, player_died and run_ended), counts each matching fact,
# earns a row once, saves the profile and announces the earn on the bus. The profile has
# no bus knowledge; this node is the only place the two meet.
#
# A fact is the signal's arguments keyed by their declared names. A row matches when every
# where key equals the fact's value; sum adds the named argument instead of 1. Counts are
# lifetime and live in the profile's stats under "ach.<id>". need, min and max compare
# run.summary() at the moment of the fact (parts by size) or the evaluator keys: class (the
# class id), won (run_ended's argument, false before it) and world (the last world_entered).

const Achievements := preload("res://src/core/achievements.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Secrets := preload("res://src/core/secrets.gd")
const ShiftBoard := preload("res://src/core/shift_board.gd")

const STAT_PREFIX := "ach."
const SAVE_POINTS := ["player_died", "run_ended"]
# Tally's ledger (ROADMAP Tally row): beating world N's boss finds leaf N; Moss's bay takes it
# back (shop.enter). Both are settle-once ids, so collection spans runs.
const LEDGER_WORLDS := 3
const LEDGER_FOUND := "ledger.found.%d"
const LEDGER_RETURNED := "ledger.returned.%d"
const LEDGER_FACT := "ledger_returned"

# The table to read. A test sets its own before setup.
var rows: Dictionary = Achievements.ROWS

# Earns whose save failed, for a test or a screen that wants to say so.
var warnings := 0
# What the last finished run did to the shift board (ShiftBoard.run_line), for the summary;
# "" from run_started until the run ends.
var board_line := ""

var _events
var _run
var _profile
var _now := Callable()
var _world := 0
var _won := false
var _rows_on := {}
var _codex
var _board_before: Array = []


func setup(events, run, profile, now := Callable(), codex = null) -> void:
	_events = events
	_run = run
	_profile = profile
	_codex = codex
	_now = now if now.is_valid() else Callable(Time, "get_unix_time_from_system")
	_board_before = ShiftBoard.stamped_ids(profile)
	_rows_on.clear()
	for id in rows:
		var on := String(rows[id].get("on", ""))
		if not _rows_on.has(on):
			_rows_on[on] = []
		_rows_on[on].append(id)
	var wanted := {"world_entered": true, "run_started": true, "boss_defeated": true}
	for on in _rows_on:
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
	if open_met_pilots() > 0 and _profile.can_save and not _profile.save():
		warnings += 1
		push_warning("progress: earned pilots opened but not saved: %s" % _profile.last_error)


# Pays the reward of every row the profile already earned, once per reward target (the
# settle-once ledger keys it), so a reward changed after the earn still lands. Returns the number of grants made.
# It runs at every launch: rewards memory already shows paid cost nothing, and the rest share one
# profile.transact (one lock and one read of the file).
func backfill_rewards() -> int:
	if _profile == null:
		return 0
	var owed: Array = []
	for id in rows:
		if not _profile.earned(id):
			continue
		var reward: Dictionary = rows[id].get("reward", {})
		for kind in reward:
			# Paid already: _grant_reward_now only settles the targeted key beside an older build's legacy key.
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


# The settle key names the reward's target, so a row whose reward target changes pays the new
# target to profiles that earned the row before the change. A profile from before the target
# joined the key holds only "reward:<row>:<kind>": with no targeted key for that row and kind yet,
# the legacy key covers the current target (it is what that profile was paid), once. The legacy
# key is still settled beside the targeted one, so older builds reading the profile pay nothing twice.
# The decision is one profile.transact, so a reward another game on this profile paid is seen, and
# paid here no more. A reward memory already shows paid needs no read: settled ids only grow (the
# merge is a union), so the file cannot change that answer.
func _grant_reward(id: String, kind: String, target: String) -> bool:
	if _paid_in_memory(id, kind, target):
		return _grant_reward_now(id, kind, target)
	return bool(_profile.transact(_grant_reward_now.bind(id, kind, target)))


# True when _grant_reward_now would refuse without reading the file: the targeted key is settled, or
# the profile holds the legacy key with no targeted key (an older build's payment).
func _paid_in_memory(id: String, kind: String, target: String) -> bool:
	var legacy := "reward:%s:%s" % [id, kind]
	return _is_settled("%s:%s" % [legacy, target]) or (_profile.is_settled(legacy) and not _has_targeted(legacy))


func _grant_reward_now(id: String, kind: String, target: String) -> bool:
	var legacy := "reward:%s:%s" % [id, kind]
	var key := "%s:%s" % [legacy, target]
	# The legacy key counts as paid only from the profile. A run file from a build before 8 November
	# may hold it after both profile saves of the earn failed; read from there it would settle the
	# targeted key with nothing paid (W1-117), so the reward is paid instead. A profile's key is not
	# proof either: builds from 4 October to 16 November could save a reward key without its unlock
	# (finding R-1). Such a reward stays unpaid here; repairing it is card W1-121.
	if _profile.is_settled(legacy) and not _has_targeted(legacy):
		settle(key, false)
		return false
	if _is_settled(key):
		return false
	# Settled first: grant_once saves once after its own settle, so both keys land in that save.
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


# Earns every row on synergy_discovered whose where names one synergy_id the codex already
# knows (CUSTOMIZE.md section 4), so a trick found before its row existed pays at the next
# launch. _earn and the settle-once ledger keep it idempotent. Returns the rows earned.
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


# Earns the hidden first-win paint rows (secrets.gd PAINT_ROWS) for a profile that won a run before
# they existed, so every won profile holds every secret. _earn keeps it idempotent. Returns the rows earned.
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


# The saved count toward a row (read-only), for the achievements page.
func count_of(id: String) -> float:
	return _profile.stat(STAT_PREFIX + id) if _profile != null else 0.0


# The settle-once ledger (RS4). True the first time an id is settled, false after. The run
# document's settled list and the profile's are one set: an id known to either is settled,
# and both end up holding it. A fresh settle saves the profile unless save is false; a
# caller that applies something right after settling saves once itself (grant_once).
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
		elif fresh and save and _profile.can_save and not _profile.save():
			warnings += 1
			push_warning("progress: %s settled but not saved: %s" % [id, _profile.last_error])
	return fresh


# Unions a loaded run document's settled ids and the profile's, so neither forgets a grant.
func reconcile_settled() -> void:
	if _run == null or _profile == null:
		return
	for id in _profile.settled_ids():
		if not _run.settled.has(id):
			_run.settled.append(id)
	var added := false
	for id in _run.settled:
		# A reward key reaches the profile only through grant_once, in the same save as its unlock.
		# Copied alone it would mark the reward paid with nothing paid (F-B R-1; Andrew, 16 Nov 2026:
		# never lost outranks at most once). The run's own list still refuses it this run; the first
		# launch after the row is earned again pays it once (backfill_rewards needs the earned row,
		# which the same failed save may have lost). Ledger ids still copy: their settle is their grant.
		if String(id).begins_with("reward:"):
			continue
		if _profile.settle(id):
			added = true
	if added and _profile.can_save:
		_profile.save()


# A profile-level one-time grant: kind is pilot, cosmetic or world. True when this call
# made the grant, false when the id was settled before. A pilot grant opens the pilots whose
# class row unlock rule is now met, not the reward's id alone; a reward id with no class row
# (Achievements.PENDING_PILOTS) is recorded as given.
func grant_once(id: String, kind: String, target: String) -> bool:
	# One save after the unlock: a save between settle and unlock could lose the grant.
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
		# An item opens from the earned row itself (ShiftBoard.opened_items), so the settle is the grant.
		"item":
			pass
	if _profile.can_save and not _profile.save():
		warnings += 1
		push_warning("progress: %s granted but not saved: %s" % [id, _profile.last_error])
	return true


# Opens every locked pilot whose class row unlock rule the saved achievements meet. setup runs
# it too, so a profile from an older schema gets what it earned. Memory only; returns how many opened.
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


# The ledger leaves Moss holds, by world.
func leaves_returned() -> int:
	if _profile == null:
		return 0
	var count := 0
	for w in range(1, LEDGER_WORLDS + 1):
		if _profile.is_settled(LEDGER_RETURNED % w):
			count += 1
	return count


# Hands every found, unreturned leaf to Moss. Saves once before announcing, so an earn's own
# save never races an unsaved return. Returns the worlds returned, in world order.
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
	if _profile.can_save and not _profile.save():
		warnings += 1
		push_warning("progress: ledger leaves %s returned but not saved: %s" % [returned, _profile.last_error])
	for w in returned:
		_events.world_fact.emit(LEDGER_FACT, at)
	return returned


# When a row was earned, as unix seconds, or 0 if it has not been.
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


# The last world_entered, or the run's own world when this listener joined after it fired: game.gd
# sets Progress up on the first physics frame, so a run a launch flag or a bot starts in frame 0
# enters world 1 before anyone here hears it, and Brindle's ledger leaf would never be found.
func _world_now() -> int:
	if _world >= 1:
		return _world
	return int(_run.world) if _run != null else 0


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
	elif signal_name == "run_ended":
		_won = bool(fact.get("won", false))
	elif signal_name == "boss_defeated" and _world_now() >= 1 and _world_now() <= LEDGER_WORLDS:
		settle(LEDGER_FOUND % _world_now())
	for id in _rows_on.get(signal_name, []):
		_evaluate(id, fact)
	if signal_name == "run_ended":
		_close_shift()
	if SAVE_POINTS.has(signal_name) and _profile.can_save:
		_profile.save()
	if signal_name == "run_ended":
		_won = false


func _evaluate(id: String, fact: Dictionary) -> void:
	if _profile.earned(id):
		return
	var row: Dictionary = rows[id]
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


# The time card (ShiftBoard.TIME_CARD): a finished run that stamped no rung and broke enough
# machines punches one hole. Runs after the run's own earns, so a stamp landed on run_ended counts.
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
	# No bounds: the fact must be present (a class chosen, a run won, a world entered).
	if value is String:
		return value != ""
	if value is bool:
		return value
	return float(value) != 0.0


# The earn, its grants and its save are one profile.transact: a row another game on this profile
# already saved as earned is taken in from the file, and neither announced nor paid again here.
func _earn(id: String, row: Dictionary) -> void:
	var silent: bool = Secrets.PAINT_ROWS.values().has(id)
	if not bool(_profile.transact(_earn_now.bind(id, row))):
		return
	if not silent:
		_events.achievement_earned.emit(id)


func _earn_now(id: String, row: Dictionary) -> bool:
	if not _profile.earn(id, float(_now.call())):
		return false
	var reward: Dictionary = row.get("reward", {})
	for kind in reward:
		_grant_reward(id, String(kind), String(reward[kind]))
	# A row that is a pilot's "or" rule carries no pilot reward (one row per pilot reward), so its earn opens
	# the pilot here.
	open_met_pilots()
	if not _profile.save():
		warnings += 1
		push_warning("progress: %s earned but not saved: %s" % [id, _profile.last_error])
	return true
