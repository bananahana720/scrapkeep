extends SceneTree

const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const RunState := preload("res://src/core/run_state.gd")
const Profile := preload("res://src/core/profile.gd")
const Intent := preload("res://src/movement/intent.gd")
const RunLog := preload("res://src/core/run_log.gd")
const RunStore := preload("res://src/core/run_store.gd")
const SpawnerDouble := preload("res://tests/doubles/spine_spawner_double.gd")
const BossDouble := preload("res://tests/doubles/spine_boss_double.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const PAGE := "res://src/ui/logbook_page.gd"
const KEYS := Profile.RUN_TALLY_KEYS
const EXPECTED_CHECKS := 91

# A full three-stage flow, as spine_run_log_test uses, with combat and boss doubles.
class ScriptedGame extends Game:
	func _chosen_table():
		return preload("res://tests/doubles/two_world_defs.gd").FirstWorld

var _t := T.new("logbook_test")
var _game
var _expected := _zero_tallies()
var _expected_wardens := {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_game = ScriptedGame.new()
	_game.test_mode = true
	root.add_child(_game)
	await process_frame
	var codex = _game.codex
	var run = _game.run
	var profile = _game.ctx.profile
	var ready := _t.check("SR12 codex status API exists", codex.has_method("status") and codex.has_method("open_entry"))
	ready = _t.check("SR12 run tally API exists", run.has_method("tallies")) and ready
	ready = _t.check("SR12 profile tally API exists", profile.has_method("record_run_tallies")) and ready
	ready = _t.check("SR12 logbook page exists", FileAccess.file_exists(PAGE)) and ready
	if not ready:
		_game.free()
		quit(_t.verdict())
		return
	var spawner := SpawnerDouble.new()
	_game.add_child(spawner)
	spawner.setup(_game.ctx)
	_game.ctx.spawner = spawner
	var boss := BossDouble.new()
	_game.add_child(boss)
	boss.setup(_game.ctx)
	_game.ctx.calm = true
	_game.flow.force_warden = true
	_game.player.source = Intent.Scripted.new()
	_game.events.stage_cleared.connect(func(_stage: int): _expected["stages_cleared"] += 1)
	_game.events.warden_engaged.connect(func(stage: int):
		_expected_wardens["%d/%d" % [_game.run.world, stage]] = true
		_expected["wardens_seen"] = _expected_wardens.size())
	_game.events.enemy_killed.connect(func(_kind: String, _at: Vector3, _scrap: int): _expected["kills"] += 1)
	_game.events.player_died.connect(func(): _expected["deaths"] += 1)
	_game.flow.press_start()
	_game.flow.choose_class(1)
	_check_page(codex, profile)
	_check_run(spawner, run, profile)
	_check_tally_merge()
	_game.free()
	await _check_quit_reload()
	_t.eq("SR12 expected check count", _t.checks + 1, EXPECTED_CHECKS)
	quit(_t.verdict())


func _check_page(codex, profile) -> void:
	var entries: Array = codex.entries()
	_t.check("SR12 registered entries nonempty", entries.size() > 50, "%d registered entries" % entries.size())
	var resolved := true
	for entry in entries:
		resolved = resolved and entry.has("status") and entry["status"] == codex.status(entry["id"], profile) and entry["status"] == "unencountered"
	_t.check("SR12 every registered entry resolves to status", resolved, "%d entries" % entries.size())
	_t.eq("SR12 absent entry has no status", codex.status("not_registered", profile), "none")
	var id: String = entries[0]["id"]
	var before: Dictionary = profile._doc.duplicate(true)
	_t.check("SR12 unencountered entry cannot be marked viewed", not codex.open_entry(id, profile) and profile._doc == before)
	codex.mark_discovered(id)
	_t.eq("SR12 discovery is new until viewed", codex.status(id, profile), "new")
	var page = load(PAGE).new()
	root.add_child(page)
	page.refresh(codex, profile)
	_t.eq("SR12 page contains every registered entry", page.rows.size(), entries.size())
	_t.check("SR12 refresh does not mark entries viewed", not profile.is_seen(id))
	_t.check("SR12 page shows status and marker", page.rows[id].text.contains("New") and page.rows[id].text.contains(entries[0]["name"]))
	before = profile._doc.duplicate(true)
	var scrap_before: int = _game.run.scrap
	page.rows[id].pressed.emit()
	_t.check("SR12 opening clears only the seen marker", profile.is_seen(id) and codex.status(id, profile) == "available")
	var after: Dictionary = profile._doc.duplicate(true)
	after["seen"] = before["seen"]
	after["generation"] = before["generation"]
	_t.check("SR12 opening grants nothing", after == before and _game.run.scrap == scrap_before)
	_t.check("SR12 opened row clears its visible marker", page.rows[id].text.contains("Available") and not page.rows[id].text.contains("New"))
	_t.check("SR12 opening displays the known entry text", page.detail.text.contains(entries[0]["name"]) and page.detail.text.contains(entries[0]["text"]))
	_t.check("SR12 repeat open is idempotent", not codex.open_entry(id, profile) and profile.seen_ids().count(id) == 1)
	var reload := Profile.new(profile.path)
	_t.check("SR12 viewed marker round-trips", reload.load_profile() and reload.is_seen(id) and codex.status(id, reload) == "available")
	page.free()


func _check_run(spawner, run, profile) -> void:
	_advance(run, 2.5)
	spawner.strike(_game.flow.warden, "arc", 99999.0)
	run.record_kill("chaser", Vector3.ZERO, 0)
	run.damage(99999.0, "test")
	var at_death: Dictionary = run.tallies()
	var open_profile := Profile.new(profile.path)
	var open_entrance: Dictionary = run.to_entrance_doc()
	open_entrance.erase("run_tallies")
	# The game writes entrance docs only at a stage entrance, alive; validate_entrance_doc refuses
	# hp 0 (a resumed ball that could never die). This case is about the tallies, so it resumes
	# the doc the stage entrance would have written.
	open_entrance["hp"] = open_entrance["max_hp"]
	var resumed := RunState.new(null, 123)
	var resumed_ok := open_profile.load_profile() and resumed.from_entrance_doc(open_entrance)
	resumed.reconcile_tallies(open_profile.run_tallies(run.run_id))
	_t.check("SR12 open run retains logged contributions on resume", resumed_ok and _same_tallies(resumed.tallies(), at_death))
	_game.flow.retry_stage()
	_t.eq("SR12 retry retains cumulative tallies", run.tallies(), at_death)
	_t.check("SR12 tally kills survive combat checkpoint rewind", int(run.tallies()["kills"]) > run.kills)
	for stage in range(1, _game.flow.final_stage() + 1):
		_t.eq("SR12 scripted flow reaches stage %d" % stage, run.stage, stage)
		_advance(run, float(stage) + 0.5)
		spawner.strike(_game.flow.warden, "arc", 99999.0)
		if stage == 1:
			_t.eq("SR12 retried stage counts its Warden once", run.tallies()["wardens_seen"], 1)
		_game.flow._finish_stage()
		if _game.flow.state_name() == "boss":
			_game.ctx.boss.defeat()
			_game.flow.physics_step(_game.flow.VICTORY_SECONDS + 1.0)
	_t.check("SR12 scripted full run ends won", run.over and _game.flow.run_won)
	var tallies: Dictionary = run.tallies()
	_t.eq("SR12 five run tallies equal independent signal ledger", tallies, _expected)
	var lines := FileAccess.get_file_as_string(_game.storage_dir.path_join(RunLog.LOG_FILE)).strip_edges().split("\n", false)
	_t.eq("SR12 death and end each write a run log", lines.size(), 2)
	var record: Dictionary = JSON.parse_string(lines[-1]) if not lines.is_empty() else {}
	_t.check("SR12 actual run log tallies match run", _same_tallies(record.get("tallies"), tallies) and record.get("outcome") == "won", JSON.stringify(record.get("tallies")))
	var stages: Array = record.get("stages", [])
	var logged_deaths := 0
	var logged_clears := 0
	var logged_wardens := 0
	var logged_ticks := 0
	for row in stages:
		logged_deaths += row["deaths"].size()
		logged_clears += 1 if row["heft_at_exit"] != null else 0
		logged_wardens += 1 if row["ticks_to_warden_engaged"] != null else 0
		logged_ticks += int(row["ticks_to_warden_break"])
		for death in row["deaths"]:
			logged_ticks += int(death["ticks"])
	_t.eq("SR12 distinct Wardens agree with stage log", tallies["wardens_seen"], logged_wardens)
	_t.near("SR12 time agrees with run log tick fields", tallies["time"], float(logged_ticks) / Engine.physics_ticks_per_second, 0.000001)
	_t.check("SR12 existing stage log agrees with clears and deaths", logged_clears == tallies["stages_cleared"] and logged_deaths == tallies["deaths"])
	var stored := {}
	for key in KEYS:
		stored[key] = profile.stat(key)
	_t.check("SR12 profile receives cumulative tallies once", _same_tallies(stored, tallies), JSON.stringify(stored))
	_t.check("SR12 won run leaves no per-run profile keys", _has_no_run_tallies(profile))
	_t.check("SR12 repeated tally settlement changes nothing", not profile.record_run_tallies(run.run_id, tallies) and profile.stat("kills") == tallies["kills"])
	var reload := Profile.new(profile.path)
	_t.check("SR12 tallied profile reloads", reload.load_profile(), reload.last_error)
	var saved := {}
	for key in KEYS:
		saved[key] = reload.stat(key)
	_t.check("SR12 all five profile tallies round-trip", _same_tallies(saved, tallies), JSON.stringify(saved))
	var entrance: Dictionary = run.to_entrance_doc()
	var restored := RunState.new(null, 123)
	_t.check("SR12 entrance tallies survive JSON round-trip", restored.from_entrance_doc(JSON.parse_string(JSON.stringify(entrance))) and restored.tallies() == tallies)
	var restored_events := GameEvents.new()
	var encountered := RunState.new(restored_events, 123)
	var encountered_ok := encountered.from_entrance_doc(JSON.parse_string(JSON.stringify(entrance)))
	restored_events.warden_engaged.emit(run.stage)
	_t.check("SR12 saved entrance counts a known Warden once", encountered_ok and encountered.tallies()["wardens_seen"] == tallies["wardens_seen"])
	encountered.world += 1
	restored_events.warden_engaged.emit(run.stage)
	_t.eq("SR12 same stage in another world is a distinct Warden", encountered.tallies()["wardens_seen"], tallies["wardens_seen"] + 1)
	restored_events.free()
	var broken := entrance.duplicate(true)
	broken["run_tallies"]["deaths"] = -1
	_t.check("SR12 invalid entrance tally rejected without applying", not restored.from_entrance_doc(broken) and restored.tallies() == tallies)
	broken = entrance.duplicate(true)
	broken["run_tallies"]["time"] += 1.0
	_t.check("SR12 inconsistent entrance clock rejected", not restored.from_entrance_doc(broken) and restored.tallies() == tallies)
	broken = entrance.duplicate(true)
	broken["seen_wardens"].append(broken["seen_wardens"][0])
	_t.check("SR12 duplicate saved Warden rejected atomically", not restored.from_entrance_doc(broken) and restored.tallies() == tallies)
	broken = entrance.duplicate(true)
	broken["seen_wardens"][0] = "not/a/warden"
	_t.check("SR12 malformed saved Warden rejected atomically", not restored.from_entrance_doc(broken) and restored.tallies() == tallies)
	var legacy := entrance.duplicate(true)
	legacy.erase("run_tallies")
	_t.check("SR12 old entrance remains readable", restored.from_entrance_doc(legacy) and restored.tallies()["kills"] == run.kills)
	var invalid := tallies.duplicate()
	invalid["time"] = NAN
	var before: Dictionary = profile._doc.duplicate(true)
	_t.check("SR12 nonfinite tally rejected atomically", not profile.record_run_tallies("bad", invalid) and profile._doc == before)
	_game.flow.new_run()
	_t.eq("SR12 new run clears tallies", run.tallies(), _zero_tallies())
	run.record_kill("chaser", Vector3.ZERO, 0)
	run.advance(1.5)
	_game.run_log.abandon_open_run()
	_t.check("SR12 abandoned run feeds profile", profile.stat("kills") == tallies["kills"] + 1 and profile.stat("time") == tallies["time"] + 1.5)
	_game.flow.new_run()
	_t.check("SR12 replaced second run leaves no per-run profile keys", _has_no_run_tallies(profile))
	var doc_before: Dictionary = profile._doc.duplicate(true)
	_t.check("SR12 stale snapshot cannot reduce totals", not profile.record_run_tallies(run.run_id, _zero_tallies()) and profile._doc == doc_before)
	_t.check("SR12 second run saves and reloads", reload.load_profile() and reload.stat("kills") == tallies["kills"] + 1 and reload.stat("time") == tallies["time"] + 1.5)
	_t.check("SR12 reloaded terminal profile leaves no per-run keys", _has_no_run_tallies(reload))
	var folded := {}
	for key in KEYS:
		folded[key] = reload.stat(Profile.RUN_TALLY_BASE + key)
	var expected_lifetime: Dictionary = tallies.duplicate()
	expected_lifetime["kills"] += 1
	expected_lifetime["time"] += 1.5
	_t.check("SR12 terminal base holds all lifetime contributions", _same_tallies(folded, expected_lifetime))


func _check_quit_reload() -> void:
	for action in ["continue", "new", "view"]:
		_game = ScriptedGame.new()
		_game.test_mode = true
		root.add_child(_game)
		await process_frame
		_game.ctx.calm = true
		_game.player.source = Intent.Scripted.new()
		var flow = _game.flow
		var run = _game.run
		var profile = _game.ctx.profile
		flow.store = RunStore.new(_game.storage_dir.path_join("quit-entrance.json"))
		flow.press_start()
		flow.choose_class(1)
		run.record_kill("chaser", Vector3.ZERO, 0)
		run.record_kill("chaser", Vector3.ZERO, 0)
		run.advance(2.5)
		_game.events.warden_engaged.emit(1)
		_game.events.stage_cleared.emit(1)
		flow.enter_stage(2, Vector3.ZERO, false)
		var entrance: Dictionary = flow.store.load()
		_t.check("SR12 %s saves entrance with completed-stage tallies" % action,
			entrance.get("run_tallies", {}).get("kills") == 2 and entrance.get("run_tallies", {}).get("stages_cleared") == 1)
		run.record_kill("chaser", Vector3.ZERO, 0)
		run.advance(1.25)
		var tallies: Dictionary = run.tallies()
		var run_id: String = run.run_id
		_t.eq("SR12 %s quit snapshot" % action, tallies,
			{"stages_cleared": 1, "time": 3.75, "kills": 3, "deaths": 0, "wardens_seen": 1})
		_game.run_log._exit_tree()
		var lines := FileAccess.get_file_as_string(_game.storage_dir.path_join(RunLog.LOG_FILE)).strip_edges().split("\n", false)
		var record: Dictionary = JSON.parse_string(lines[-1]) if not lines.is_empty() else {}
		_t.check("SR12 %s quit writes abandoned snapshot" % action,
			record.get("outcome") == "abandoned" and _same_tallies(record.get("tallies"), tallies))
		var reloaded := Profile.new(profile.path)
		_t.check("SR12 %s quit profile reloads from disk" % action, reloaded.load_profile(), reloaded.last_error)
		_game.ctx.profile = reloaded
		profile = reloaded
		if action == "continue":
			flow._set_state(flow.TITLE)
			_t.check("SR12 Continue restores the same saved run", flow.resume_run() and run.run_id == run_id and run.stage == 2)
			run.damage(99999.0, "quit-continue-test")
			tallies["deaths"] += 1
			_t.eq("SR12 Continue reconciles all five tallies before death", run.tallies(), tallies)
			_t.eq("SR12 quit Continue death counts kills once", profile.stat("kills"), tallies["kills"])
			_t.eq("SR12 quit Continue death counts stages once", profile.stat("stages_cleared"), tallies["stages_cleared"])
			_t.check("SR12 quit Continue death lifetime totals count once", _same_tallies(_profile_tallies(profile), tallies))
		elif action == "new":
			var older := _zero_tallies()
			older["kills"] = 2
			_t.check("SR12 another earlier run retains per-run keys", profile.record_run_tallies("earlier_quit", older) and profile.save())
			flow.new_run()
			tallies["kills"] += 2
			_t.check("SR12 new run replaces saved entrance", run.run_id != run_id and flow.store.load().get("run_id") == run.run_id)
			_t.check("SR12 new run removes every earlier per-run key", _has_no_run_tallies(profile))
			_t.check("SR12 new run folds quit contributions into base once", _same_tallies(_profile_tallies(profile, Profile.RUN_TALLY_BASE), tallies))
			_t.check("SR12 new run settled totals survive reload", profile.load_profile() and _has_no_run_tallies(profile) and _same_tallies(_profile_tallies(profile), tallies))
		else:
			_t.check("SR12 quit reload retains resumable high-water marks", _same_tallies(profile.run_tallies(run_id), tallies))
			_t.check("SR12 quit reload leaves lifetime base unsettled", _same_tallies(_profile_tallies(profile, Profile.RUN_TALLY_BASE), _zero_tallies()))
			_t.check("SR12 logbook lifetime totals include quit run once", _same_tallies(_profile_tallies(profile), tallies))
			_t.check("SR12 repeated profile reload keeps quit totals once", profile.load_profile() and _same_tallies(_profile_tallies(profile), tallies))
		_game.free()


func _profile_tallies(profile, prefix := "") -> Dictionary:
	var totals := {}
	for key in KEYS:
		totals[key] = profile.stat(prefix + key)
	return totals


func _advance(run, seconds: float) -> void:
	run.advance(seconds)
	_expected["time"] += seconds


static func _zero_tallies() -> Dictionary:
	var totals := {}
	for key in KEYS:
		totals[key] = 0.0 if key == "time" else 0
	return totals


func _has_no_run_tallies(profile) -> bool:
	for key in profile._doc["stats"]:
		if String(key).begins_with(Profile.RUN_TALLY_PREFIX):
			return false
	return true


func _same_tallies(got, want: Dictionary) -> bool:
	if not got is Dictionary or got.size() != KEYS.size():
		return false
	for key in KEYS:
		var value = got.get(key)
		if not (value is int or value is float) or not is_finite(value) or float(value) != float(want[key]):
			return false
	return true


func _check_tally_merge() -> void:
	var path: String = _game.storage_dir.path_join("tally-merge.json")
	var base := Profile.new(path)
	base.load_profile()
	base.set_stat("kills", 7.0)
	base.set_stat("time", 4.0)
	_t.check("SR12 prior lifetime stats save", base.save(), base.last_error)
	var a := Profile.new(path)
	var b := Profile.new(path)
	_t.check("SR12 stale tally writers load same generation", a.load_profile() and b.load_profile())
	_t.check("SR12 distinct runs accept their snapshots", a.record_run_tallies("merge_a", {"stages_cleared": 1, "time": 2.0, "kills": 3, "deaths": 0, "wardens_seen": 1}) and b.record_run_tallies("merge_b", {"stages_cleared": 1, "time": 3.0, "kills": 5, "deaths": 1, "wardens_seen": 1}))
	_t.check("SR12 stale tally writers both save", a.save() and b.save(), b.last_error)
	var merged := Profile.new(path)
	var loaded := merged.load_profile()
	_t.check("SR12 merged tallies retain both runs and prior stats", loaded and merged.stat("kills") == 15.0 and merged.stat("time") == 9.0 and merged.stat("stages_cleared") == 2.0 and merged.stat("deaths") == 1.0 and merged.stat("wardens_seen") == 2.0,
		"kills %s, time %s, stages %s" % [merged.stat("kills"), merged.stat("time"), merged.stat("stages_cleared")])
	var stale := Profile.new(path)
	var stale_loaded := stale.load_profile()
	_t.check("SR12 first stale writer compacts its terminal run", a.settle_run_tallies("merge_a") and a.save(), a.last_error)
	_t.check("SR12 second stale writer compacts without double counting", b.settle_run_tallies("merge_b") and b.save() and b.stat("kills") == 15.0 and b.stat("time") == 9.0 and _has_no_run_tallies(b), b.last_error)
	var advanced := {"stages_cleared": 1, "time": 4.0, "kills": 9, "deaths": 0, "wardens_seen": 1}
	var stale_advanced := stale.record_run_tallies("merge_a", advanced)
	stale.add_stat("unrelated", 1.0)
	_t.check("SR12 stale writer cannot resurrect a compacted run", stale_loaded and stale_advanced and stale.save() and stale.stat("kills") == 15.0 and stale.stat("time") == 9.0 and stale.stat("unrelated") == 1.0 and _has_no_run_tallies(stale), stale.last_error)
	_t.check("SR12 compacted totals survive reload", merged.load_profile() and merged.stat("kills") == 15.0 and merged.stat("time") == 9.0 and _has_no_run_tallies(merged))
	var new_totals := _zero_tallies()
	new_totals["kills"] = 2
	_t.check("SR12 new run adds onto compacted base", stale.record_run_tallies("merge_c", new_totals) and stale.save() and stale.stat("kills") == 17.0)
	_t.check("SR12 later terminal run preserves compacted totals", stale.settle_run_tallies("merge_c") and stale.save() and stale.stat("kills") == 17.0 and _has_no_run_tallies(stale))
