extends RefCounted

# The player's progress as one versioned document, saved as profile.json: unlocked
# pilots, worlds and cosmetics, earned achievements, equipped cosmetics, stats and the
# last pilot, the between-run nodes opened (SG12, an id list added inside schema 4: a
# file without it reads as none opened) and the jukebox tunes heard (tune_rows.gd, an id
# list added the same way; the pilot radio's takes join that list) and the radio's dial and
# mixtapes (radio.gd's to_dict, a dict added the same way). Preferences live in settings_store.gd. The store knows no starters,
# and the caller passes the time an achievement was earned; the only clock it reads is the save
# lock's age. Mutators change memory and save() writes. A store cannot save until it has loaded,
# and a save that finds a newer generation on disk merges it in instead of replacing it. Every
# save, and every transact (one decision against the newest file), holds the save lock, a
# directory beside the file, so two games on one profile never write between each other's read
# and write. A file this build
# cannot read is never overwritten: unreadable files are kept as .bad, and a file from a
# newer build is left alone.

const SafeStore := preload("res://src/core/safe_store.gd")

const SCHEMA := 4
const RUN_TALLY_KEYS := ["stages_cleared", "time", "kills", "deaths", "wardens_seen"]
const RUN_TALLY_PREFIX := "run_tallies."
const RUN_TALLY_BASE := "run_tally_base."
# Runs whose tallies were folded into the base: a run brought back after that (run.json.prev
# restored, then continued) would otherwise add its whole snapshot again, because compaction
# erased the high-water marks that pay only deltas. The newest CLOSED_KEEP are kept, ordered.
const RUN_TALLY_CLOSED := "run_tally_closed."
const CLOSED_KEEP := 16

# From-version to the method that returns the document one version up.
const MIGRATIONS := {0: "_migrate_0", 1: "_migrate_1", 2: "_migrate_2", 3: "_migrate_3"}

# Pilot ids every schema 2 build let anyone fly (Rivet was a starter, Kest came free with it).
# Frozen history, not a rule: a returning v2 profile keeps them under the v3 locks.
const V2_FREE_PILOTS := ["runner_gunner", "demolitions_caster"]

# Cosmetic ids a cut item left in saves, to the id that replaces it. Every read swaps them, so
# a save that earned the old item owns the new one; the new one stays unseen so it glows as new,
# and a slot still wearing the old id is cleared. 2026-10-16: the Rigger Harness was cut for
# alpha, and Homecoming pays Rigger Blue instead (COSMETICS-ART-BRIEFS.md).
const RETIRED_COSMETICS := {"outfit_kest_rigger": "paint_kest_rigger"}

const SHAPE := {
	"pilots": SafeStore.STRINGS,
	"worlds": SafeStore.STRINGS,
	"cosmetics": SafeStore.STRINGS,
	"achievements": SafeStore.NUMBERS,
	"equipped": SafeStore.STRING_MAP,
	"stats": SafeStore.NUMBERS,
	"settled": SafeStore.STRINGS,
	"companion": SafeStore.DICT,
	"seen": SafeStore.STRINGS,
	"options": SafeStore.STRINGS,
	"tunes": SafeStore.STRINGS,
	"radio": SafeStore.DICT,
	"camp": SafeStore.DICT,
}

const LOCK_WAIT_MS := 250
const LOCK_POLL_MS := 2

var path := ""
var last_error := ""
var can_save := false
# Seconds after which a save lock is taken as left by a game that died inside a save. A test sets its own.
var lock_stale_s := 5.0

var _doc := {}
var _refusal := ""
var _on_disk := false
var _loaded_generation := 0
var _backup_path := ""
var _backup_bytes := PackedByteArray()
var _loaded_tally_prefixes := {}
var _pending_tally_settlements := {}
var _last_closed_tally_run := ""
var _lock_depth := 0
# Inside a transact that could not get the lock: the error it got, and how deep. Every lock taken
# under it fails at once with that error instead of waiting again.
var _lock_refused := 0
var _lock_error := OK


func _init(file_path := "user://profile.json") -> void:
	path = file_path
	_refusal = "not saving: %s has not been loaded" % path
	_doc = _defaults()


func load_profile() -> bool:
	_doc = _defaults()
	last_error = ""
	_refusal = ""
	can_save = true
	_on_disk = false
	_loaded_generation = 0
	_backup_path = ""
	_backup_bytes = PackedByteArray()
	_loaded_tally_prefixes = {}
	_pending_tally_settlements = {}
	_last_closed_tally_run = ""
	var read := _read()
	if read["state"] == "missing":
		return true
	if read["state"] == "newer":
		return _refuse("%s; playing without saving" % read["why"])
	if read["state"] != "ok":
		return _reject(read["why"])
	_doc = read["doc"]
	_on_disk = true
	_loaded_generation = int(_doc["generation"])
	_remember_run_tallies()
	if read["from_version"] < SCHEMA:
		_backup_path = "%s.v%d" % [path, read["from_version"]]
		_backup_bytes = read["bytes"]
	return true


func save() -> bool:
	if not can_save:
		last_error = _refusal
		return false
	var locked := _lock()
	if locked != OK:
		last_error = _lock_message(locked)
		return false
	var saved := _save_locked()
	_unlock()
	return saved


# Runs change, a Callable, as one step against the newest file, and returns what it returns. It holds
# the save lock, so no other game's save comes between, and first takes in what another game saved
# since this one last read or wrote the file (the same merge as save). A save inside change writes
# under the same lock. A profile that cannot save, or a lock it cannot get, runs change on memory as
# before: never lost outranks at most once (ruling ea).
# Inside a held transact it runs change at once: the file was taken in under the same lock.
func transact(change: Callable) -> Variant:
	if not can_save or _lock_depth > 0 or _lock_refused > 0:
		return change.call()
	var locked := _lock()
	if locked != OK:
		last_error = _lock_message(locked)
		_lock_refused += 1
		_lock_error = locked
		var unlocked = change.call()
		_lock_refused -= 1
		return unlocked
	var read := _read()
	if _newer_on_disk(read):
		_discard_compacted_tallies(_doc["stats"], read["doc"]["stats"])
		_doc = merge(_doc, read["doc"])
		_on_disk = true
		_loaded_generation = int(read["doc"]["generation"])
		_remember_run_tallies()
		if _backup_path.is_empty() and read["from_version"] < SCHEMA:
			_backup_path = "%s.v%d" % [path, read["from_version"]]
			_backup_bytes = read["bytes"]
	var result = change.call()
	_unlock()
	return result


# The save lock is a directory beside the file: making it is atomic, so one game holds it at a time.
# Held for one save or one transact (milliseconds); taken again inside them it nests. A game waits
# LOCK_WAIT_MS for another's save to finish (then ERR_BUSY), and breaks a lock whose time is more than
# lock_stale_s from now either way: only a game that died inside a save, or a clock that was moved,
# leaves one. Any other error is the directory's own.
func _lock() -> Error:
	if _lock_refused > 0:
		return _lock_error
	if _lock_depth > 0:
		_lock_depth += 1
		return OK
	var dir := path + ".lock"
	var waited := 0
	while waited <= LOCK_WAIT_MS:
		var err := DirAccess.make_dir_absolute(dir)
		if err == OK:
			_lock_depth = 1
			return OK
		if err != ERR_ALREADY_EXISTS:
			return err
		# 0 when the holder let go between the two calls: try again.
		var made := FileAccess.get_modified_time(dir) if DirAccess.dir_exists_absolute(dir) else 0
		if made > 0 and absf(Time.get_unix_time_from_system() - made) > lock_stale_s:
			DirAccess.remove_absolute(dir)
		else:
			OS.delay_msec(LOCK_POLL_MS)
		waited += LOCK_POLL_MS
	return ERR_BUSY


func _lock_message(err: Error) -> String:
	if err == ERR_BUSY:
		return "not saving: another game is saving %s" % path
	return "not saving: could not take the save lock %s.lock: %s" % [path, error_string(err)]


func _unlock() -> void:
	_lock_depth -= 1
	if _lock_depth == 0:
		DirAccess.remove_absolute(path + ".lock")


# True when the file holds what another game saved since this one last read or wrote it.
func _newer_on_disk(read: Dictionary) -> bool:
	return read["state"] == "ok" and (not _on_disk or int(read["doc"]["generation"]) != _loaded_generation)


func _save_locked() -> bool:
	var read := _read()
	var next := _doc.duplicate(true)
	var backup_path := _backup_path
	var backup_bytes := _backup_bytes
	if read["state"] == "newer":
		last_error = "not saving: %s was replaced by a newer build since it was loaded" % path
		return false
	if read["state"] != "missing" and read["state"] != "ok":
		last_error = "not saving: %s changed since it was loaded and cannot be read (%s)" % [path, read["why"]]
		return false
	if _newer_on_disk(read):
		_discard_compacted_tallies(next["stats"], read["doc"]["stats"])
		next = merge(next, read["doc"])
		if backup_path.is_empty() and read["from_version"] < SCHEMA:
			backup_path = "%s.v%d" % [path, read["from_version"]]
			backup_bytes = read["bytes"]
	if not backup_path.is_empty():
		var kept := _keep_backup(backup_path, backup_bytes)
		if kept != OK:
			last_error = "could not keep the old save as %s: %s" % [backup_path, error_string(kept)]
			return false
		_backup_path = ""
		_backup_bytes = PackedByteArray()
	_compact_run_tallies(next["stats"])
	next["generation"] = int(next["generation"]) + 1
	var err := SafeStore.write_atomic(path, JSON.stringify(next, "  ", true, true))
	if err != OK:
		last_error = "could not write %s: %s" % [path, error_string(err)]
		return false
	_doc = next
	_on_disk = true
	_loaded_generation = int(next["generation"])
	_remember_run_tallies()
	if not _pending_tally_settlements.is_empty():
		_last_closed_tally_run = _pending_tally_settlements.keys().back()
		_pending_tally_settlements.clear()
	last_error = ""
	return true


# What two writers of one file both did, as one document: lists are the union,
# achievements keep the earliest time and stats the larger value, an equipped slot
# both hold and last_pilot are the saver's, and a slot or key only the other side
# holds is kept. Settled ids are a union and rewards_settled never goes back to false.
# The companion keeps the union of owned pieces, the saver's assembly when it has one
# (else theirs) and the saver's escape flag. The generation is the larger of the two.
static func merge(ours: Dictionary, theirs: Dictionary) -> Dictionary:
	var out := ours.duplicate(true)
	for key in ["pilots", "worlds", "cosmetics", "settled", "seen", "options", "tunes"]:
		if not out.has(key):
			out[key] = []
		for id in theirs.get(key, []):
			if not out[key].has(id):
				out[key].append(id)
	if bool(theirs.get("rewards_settled", false)):
		out["rewards_settled"] = true
	var mine: Dictionary = out.get("companion", {})
	var other: Dictionary = theirs.get("companion", {})
	if mine.is_empty():
		out["companion"] = other.duplicate(true)
	elif not other.is_empty():
		var owned: Array = mine.get("owned", []).duplicate()
		for id in other.get("owned", []):
			if not owned.has(id):
				owned.append(id)
		mine["owned"] = owned
		if mine.get("sockets", []).is_empty() and not other.get("sockets", []).is_empty():
			mine["sockets"] = other["sockets"].duplicate()
		out["companion"] = mine
	out["camp"] = _merge_camp(out.get("camp", {}), theirs.get("camp", {}))
	var times: Dictionary = theirs.get("achievements", {})
	for id in times:
		if not out["achievements"].has(id) or times[id] < out["achievements"][id]:
			out["achievements"][id] = times[id]
	var stats: Dictionary = theirs.get("stats", {})
	for stat_name in stats:
		if not out["stats"].has(stat_name) or stats[stat_name] > out["stats"][stat_name]:
			out["stats"][stat_name] = stats[stat_name]
	# Run snapshots merge by max, but distinct runs contribute additively.
	for key in RUN_TALLY_KEYS:
		if out["stats"].has(RUN_TALLY_BASE + key):
			out["stats"][key] = float(out["stats"][RUN_TALLY_BASE + key]) + _run_contributions(out["stats"], key)
	var worn: Dictionary = theirs.get("equipped", {})
	for slot in worn:
		if not out["equipped"].has(slot):
			out["equipped"][slot] = worn[slot]
	for key in theirs:
		if not out.has(key):
			out[key] = theirs[key]
	out["generation"] = maxi(int(ours.get("generation", 0)), int(theirs.get("generation", 0)))
	return out


# The camp's records: the skee best by max, the trial's best lap by min and its ghost with it.
static func _merge_camp(mine: Dictionary, other: Dictionary) -> Dictionary:
	var out := mine.duplicate(true)
	if other.has("skee_best") and (not out.has("skee_best") or int(other["skee_best"]) > int(out["skee_best"])):
		out["skee_best"] = other["skee_best"]
	var theirs_trial: Variant = other.get("trial")
	if theirs_trial is Dictionary and theirs_trial.has("best_ms"):
		var ours_trial: Variant = out.get("trial")
		if not (ours_trial is Dictionary) or not ours_trial.has("best_ms") or int(theirs_trial["best_ms"]) < int(ours_trial["best_ms"]):
			out["trial"] = (theirs_trial as Dictionary).duplicate(true)
	# The camp ring's best count per pilot: the higher of the two.
	var theirs_ring: Variant = other.get("ring")
	if theirs_ring is Dictionary:
		var ours_ring: Dictionary = (out["ring"] as Dictionary).duplicate() if out.get("ring") is Dictionary else {}
		for pilot in theirs_ring:
			if _whole(theirs_ring[pilot]) and int(theirs_ring[pilot]) > int(ours_ring.get(pilot, 0)):
				ours_ring[pilot] = theirs_ring[pilot]
		out["ring"] = ours_ring
	for key in other:
		if not out.has(key):
			out[key] = other[key]
	return out


func generation() -> int:
	return int(_doc["generation"])


func has_pilot(id: String) -> bool:
	return _doc["pilots"].has(id)


func unlock_pilot(id: String) -> void:
	_add(_doc["pilots"], id)


func has_world(id: String) -> bool:
	return _doc["worlds"].has(id)


func unlock_world(id: String) -> void:
	_add(_doc["worlds"], id)


func has_cosmetic(id: String) -> bool:
	return _doc["cosmetics"].has(id)


func unlock_cosmetic(id: String) -> void:
	_add(_doc["cosmetics"], id)


func earned(id: String) -> bool:
	return _doc["achievements"].has(id)


func earned_at(id: String) -> int:
	return int(_doc["achievements"].get(id, 0))


func earn(id: String, at: float) -> bool:
	if earned(id):
		return false
	_doc["achievements"][id] = int(floorf(at))
	return true


func equipped(pilot: String, slot: String) -> String:
	return String(_doc["equipped"].get("%s/%s" % [pilot, slot], ""))


func equip(pilot: String, slot: String, cosmetic_id: String) -> void:
	_doc["equipped"]["%s/%s" % [pilot, slot]] = cosmetic_id


func stat(stat_name: String) -> float:
	return float(_doc["stats"].get(stat_name, 0.0))


func add_stat(stat_name: String, amount := 1.0) -> void:
	_doc["stats"][stat_name] = stat(stat_name) + amount


func set_stat(stat_name: String, value: float) -> void:
	_doc["stats"][stat_name] = value


# Cumulative run snapshots pay only the delta since this run's last logged snapshot.
# The existing stats map carries the high-water marks, so a death, end or replayed
# record cannot count the same kills or time twice. No grant rows consume these keys.
func record_run_tallies(run_id: String, totals: Dictionary) -> bool:
	if run_id.is_empty() or totals.size() != RUN_TALLY_KEYS.size():
		return false
	if run_id == _last_closed_tally_run or _pending_tally_settlements.has(run_id) or tallies_closed(run_id):
		return false
	var prefix := RUN_TALLY_PREFIX + run_id + "."
	for key in RUN_TALLY_KEYS:
		var value = totals.get(key)
		if not (value is int or value is float) or not is_finite(value) or value < 0.0:
			return false
		if key != "time" and value != floorf(value):
			return false
		if value < stat(prefix + key) or not is_finite(stat(key) + value - stat(prefix + key)):
			return false
	var changed := false
	for key in RUN_TALLY_KEYS:
		changed = changed or float(totals[key]) > stat(prefix + key)
	if not changed:
		return false
	for key in RUN_TALLY_KEYS:
		if not _doc["stats"].has(RUN_TALLY_BASE + key):
			set_stat(RUN_TALLY_BASE + key, stat(key) - _run_contributions(_doc["stats"], key))
		var value := float(totals[key])
		var delta := value - stat(prefix + key)
		if delta > 0.0:
			add_stat(key, delta)
			set_stat(prefix + key, value)
	return changed


func settle_run_tallies(run_id: String) -> bool:
	if run_id.is_empty() or run_id == _last_closed_tally_run or _pending_tally_settlements.has(run_id) or tallies_closed(run_id):
		return false
	_pending_tally_settlements[run_id] = true
	return true


func settle_previous_run_tallies() -> bool:
	var changed := false
	for stat_name in _doc["stats"]:
		var key := String(stat_name)
		if key.begins_with(RUN_TALLY_PREFIX):
			var run_id := key.substr(RUN_TALLY_PREFIX.length(), key.rfind(".") - RUN_TALLY_PREFIX.length())
			changed = settle_run_tallies(run_id) or changed
	return changed


func _remember_run_tallies() -> void:
	_loaded_tally_prefixes = {}
	for stat_name in _doc["stats"]:
		if String(stat_name).begins_with(RUN_TALLY_PREFIX):
			_loaded_tally_prefixes[String(stat_name).substr(0, String(stat_name).rfind(".") + 1)] = true


func _discard_compacted_tallies(stats: Dictionary, saved: Dictionary) -> void:
	# A newer save folded these loaded contributions into its base. A stale writer
	# must not bring their per-run keys back, even if its snapshot advanced afterward.
	for prefix in _loaded_tally_prefixes:
		var still_open := false
		for key in RUN_TALLY_KEYS:
			still_open = still_open or saved.has(prefix + key)
		if not still_open:
			for key in RUN_TALLY_KEYS:
				stats.erase(prefix + key)


func _compact_run_tallies(stats: Dictionary) -> void:
	if _pending_tally_settlements.is_empty():
		return
	var order := 0.0
	for stat_name in stats:
		if String(stat_name).begins_with(RUN_TALLY_CLOSED):
			order = maxf(order, float(stats[stat_name]))
	for run_id in _pending_tally_settlements:
		order += 1.0
		stats[RUN_TALLY_CLOSED + run_id] = order
		var prefix: String = RUN_TALLY_PREFIX + run_id + "."
		for key in RUN_TALLY_KEYS:
			var base: String = RUN_TALLY_BASE + key
			if not stats.has(base):
				stats[base] = float(stats.get(key, 0.0)) - _run_contributions(stats, key)
			stats[base] += float(stats.get(prefix + key, 0.0))
			stats.erase(prefix + key)
	for key in RUN_TALLY_KEYS:
		if stats.has(RUN_TALLY_BASE + key):
			stats[key] = float(stats[RUN_TALLY_BASE + key]) + _run_contributions(stats, key)
	var closed := stats.keys().filter(func(k): return String(k).begins_with(RUN_TALLY_CLOSED))
	closed.sort_custom(func(a, b): return float(stats[a]) > float(stats[b]))
	for stale in closed.slice(CLOSED_KEEP):
		stats.erase(stale)


func tallies_closed(run_id: String) -> bool:
	return _doc["stats"].has(RUN_TALLY_CLOSED + run_id)


static func _run_contributions(stats: Dictionary, key: String) -> float:
	var total := 0.0
	for stat_name in stats:
		if String(stat_name).begins_with(RUN_TALLY_PREFIX) and String(stat_name).ends_with("." + key):
			total += float(stats[stat_name])
	return total


func run_tallies(run_id: String) -> Dictionary:
	var totals := {}
	for key in RUN_TALLY_KEYS:
		totals[key] = stat(RUN_TALLY_PREFIX + run_id + "." + key)
	return totals


func last_pilot() -> String:
	return String(_doc["last_pilot"])


func set_last_pilot(id: String) -> void:
	_doc["last_pilot"] = id


# The companion as the dictionary Companion.to_dict makes; {} until one is stored.
func companion() -> Dictionary:
	return _doc["companion"].duplicate(true)


func set_companion(doc: Dictionary) -> void:
	_doc["companion"] = doc.duplicate(true)


func is_settled(id: String) -> bool:
	return _doc["settled"].has(id)


# True the first time an id is settled, false after. Memory only; save() writes.
func settle(id: String) -> bool:
	if is_settled(id):
		return false
	_doc["settled"].append(id)
	return true


func settled_ids() -> Array:
	return _doc["settled"].duplicate()


# Cosmetic ids the player has looked at on the customize page; the new-item marks read it.
func is_seen(id: String) -> bool:
	return _doc["seen"].has(id)


# True the first time an id is marked seen. Memory only; save() writes.
func mark_seen(id: String) -> bool:
	if is_seen(id):
		return false
	_doc["seen"].append(id)
	return true


func seen_ids() -> Array:
	return _doc["seen"].duplicate()


# Between-run nodes opened (meta_options.gd). A list of ids and nothing else: no count, price
# or stat travels with them. Memory only; save() writes.
func has_option(id: String) -> bool:
	return _doc["options"].has(id)


# True the first time a node is opened, false after.
func open_option(id: String) -> bool:
	if has_option(id):
		return false
	_doc["options"].append(id)
	return true


func option_ids() -> Array:
	return _doc["options"].duplicate()


# Jukebox tunes heard in play (tune_rows.gd ids). Memory only; save() writes.
func has_tune(id: String) -> bool:
	return _doc["tunes"].has(id)


# True the first time a tune is heard, false after.
func hear_tune(id: String) -> bool:
	if has_tune(id):
		return false
	_doc["tunes"].append(id)
	return true


func tune_ids() -> Array:
	return _doc["tunes"].duplicate()


# The pilot radio's station and mixtapes as Radio.to_dict makes them; {} until one is stored.
func radio() -> Dictionary:
	return _doc["radio"].duplicate(true)


func set_radio(doc: Dictionary) -> void:
	_doc["radio"] = doc.duplicate(true)


# The camp's records as camp_records.gd keeps them; {} until one is stored.
func camp() -> Dictionary:
	return _doc["camp"].duplicate(true)


func set_camp(doc: Dictionary) -> void:
	_doc["camp"] = doc.duplicate(true)


func rewards_settled() -> bool:
	return bool(_doc["rewards_settled"])


func mark_rewards_settled() -> bool:
	if rewards_settled():
		return false
	_doc["rewards_settled"] = true
	return true


func _add(list: Array, id: String) -> void:
	if not list.has(id):
		list.append(id)


func _refuse(why: String) -> bool:
	can_save = false
	_refusal = "not saving: %s" % why
	last_error = why
	return false


func _reject(why: String) -> bool:
	var kept := SafeStore.quarantine(path)
	if kept.is_empty():
		return _refuse("%s and could not be moved aside; not saving this session" % why)
	last_error = "%s; kept as %s" % [why, kept]
	return false


# Where the pending backup goes: the name itself, or the next free .1, .2 when that
# name holds different bytes. A name already holding these bytes is the backup.
func _keep_backup(base: String, bytes: PackedByteArray) -> Error:
	var target := base
	var n := 1
	while FileAccess.file_exists(target):
		if FileAccess.get_file_as_bytes(target) == bytes:
			return OK
		target = "%s.%d" % [base, n]
		n += 1
	return SafeStore.write_atomic(target, bytes.get_string_from_utf8())


# The file at path as a state: missing, unreadable, bad_schema, newer, wrong_type or
# ok. An ok read carries the migrated document, the schema it was written at and the
# bytes it came from; the other states carry why.
func _read() -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"state": "missing"}
	var bytes := FileAccess.get_file_as_bytes(path)
	var parsed = SafeStore.parse(bytes.get_string_from_utf8(), TYPE_DICTIONARY)
	if parsed == null:
		return {"state": "unreadable", "why": "unreadable %s" % path}
	var version := 0
	if parsed.has("schema"):
		if not (typeof(parsed["schema"]) in [TYPE_INT, TYPE_FLOAT]):
			return {"state": "bad_schema", "why": "%s has a schema that is not a number" % path}
		version = int(parsed["schema"])
	if version > SCHEMA:
		return {"state": "newer", "why": "%s is schema %d, written by a newer build; this build reads up to %d" % [path, version, SCHEMA]}
	if version < 0:
		return {"state": "bad_schema", "why": "%s has schema %d" % [path, version]}
	var from_version := version
	while version < SCHEMA:
		parsed = call(MIGRATIONS[version], parsed)
		version += 1
	if not _shape_ok(parsed):
		return {"state": "wrong_type", "why": "%s has fields of the wrong type" % path}
	var doc := _defaults()
	for key in parsed:
		doc[key] = parsed[key]
	doc["schema"] = SCHEMA
	doc["generation"] = int(doc["generation"])
	for id in doc["achievements"]:
		doc["achievements"][id] = int(floorf(doc["achievements"][id]))
	_retire_cosmetics(doc)
	_sanitize_records(doc)
	return {"state": "ok", "doc": doc, "from_version": from_version, "bytes": bytes}


# The camp record is only shape-checked as a dictionary above; the camp trial and skee lane cast
# its nested values. A bad nested value is dropped here, with a warning, and the rest is kept.
# (The companion is cleaned where it enters a run: flow._seed_companion, Companion.sanitize.)
static func _sanitize_records(doc: Dictionary) -> void:
	var camp: Dictionary = doc["camp"]
	if camp.has("skee_best") and not _whole(camp["skee_best"]):
		push_warning("profile: camp skee_best %s is not a number; dropped" % str(camp["skee_best"]))
		camp.erase("skee_best")
	if camp.has("ring"):
		var ring = camp["ring"]
		if not (ring is Dictionary) or not (ring as Dictionary).values().all(func(v): return _whole(v)):
			push_warning("profile: camp ring is malformed; dropped")
			camp.erase("ring")
	if camp.has("trial"):
		var trial = camp["trial"]
		if not (trial is Dictionary) or not _whole(trial.get("best_ms")):
			push_warning("profile: camp trial is malformed; dropped")
			camp.erase("trial")
		elif trial.has("ghost") and not (trial["ghost"] is Dictionary):
			trial.erase("ghost")


static func _whole(value) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))


static func _retire_cosmetics(doc: Dictionary) -> void:
	for old in RETIRED_COSMETICS:
		if not doc["cosmetics"].has(old):
			continue
		doc["cosmetics"].erase(old)
		doc["seen"].erase(old)
		if not doc["cosmetics"].has(RETIRED_COSMETICS[old]):
			doc["cosmetics"].append(RETIRED_COSMETICS[old])
		for slot in doc["equipped"]:
			if doc["equipped"][slot] == old:
				doc["equipped"][slot] = ""


func _shape_ok(doc: Dictionary) -> bool:
	if SafeStore.parse(JSON.stringify(doc), TYPE_DICTIONARY, SHAPE) == null:
		return false
	if doc.has("last_pilot") and typeof(doc["last_pilot"]) != TYPE_STRING:
		return false
	if doc.has("generation") and not (typeof(doc["generation"]) in [TYPE_INT, TYPE_FLOAT]):
		return false
	if doc.has("rewards_settled") and typeof(doc["rewards_settled"]) != TYPE_BOOL:
		return false
	return true


func _defaults() -> Dictionary:
	return {
		"schema": SCHEMA,
		"generation": 0,
		"pilots": [],
		"worlds": [],
		"achievements": {},
		"cosmetics": [],
		"equipped": {},
		"stats": {},
		"last_pilot": "",
		"settled": [],
		"companion": {},
		"rewards_settled": false,
		"seen": [],
		"options": [],
		"tunes": [],
		"radio": {},
		"camp": {},
	}


func _migrate_0(doc: Dictionary) -> Dictionary:
	var out := _defaults()
	for key in doc:
		out[key] = doc[key]
	out["schema"] = 1
	return out


# Schema 1 to 2 adds the companion, the settled ids and the rewards_settled marker;
# every v1 field passes through untouched.
func _migrate_1(doc: Dictionary) -> Dictionary:
	var out := _defaults()
	for key in doc:
		out[key] = doc[key]
	out["schema"] = 2
	return out


# Schema 2 to 3 turns the pilot locks on (ruling P-R21). The pilots a v2 build gave everyone
# are added so a returning player keeps them; pilots the saved achievements already earned
# are opened by progress.gd's open_met_pilots at setup. Nothing is removed.
func _migrate_2(doc: Dictionary) -> Dictionary:
	var out := _defaults()
	for key in doc:
		out[key] = doc[key]
	if out["pilots"] is Array:
		var pilots: Array = (out["pilots"] as Array).duplicate()
		for id in V2_FREE_PILOTS:
			if not pilots.has(id):
				pilots.append(id)
		out["pilots"] = pilots
	out["schema"] = 3
	return out


# Schema 3 to 4 adds the seen marks. Everything a v3 profile owned counts as seen, so only
# items earned after the upgrade glow as new. A seen list already in the file (from a tool)
# is kept and unioned. Nothing is removed. A malformed cosmetics or seen value is left for
# _shape_ok to reject after migration.
func _migrate_3(doc: Dictionary) -> Dictionary:
	var out := _defaults()
	for key in doc:
		out[key] = doc[key]
	if out["seen"] is Array and out["cosmetics"] is Array:
		var seen: Array = (out["seen"] as Array).duplicate()
		for id in out["cosmetics"]:
			if id is String and not seen.has(id):
				seen.append(id)
		out["seen"] = seen
	out["schema"] = 4
	return out
