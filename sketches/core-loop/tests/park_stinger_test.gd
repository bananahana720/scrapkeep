extends SceneTree

const MusicRows := preload("res://src/presentation/music_rows.gd")
const MusicEngine := preload("res://src/presentation/music_engine.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const ParkDefs := preload("res://src/core/park_defs.gd")
const T := preload("res://tests/support/t.gd")

# Each park stage plays stingers cut from its own ACE pack (tools/ace/cut_stingers.py). The
# synth row is the fallback when a stage has no file for a cue.

var _t := T.new("park_stinger_test")
# The Highdraft's Mind cues are never cut from its pack, so every pilot hears its own motif quoted.
const MIND_CUES := ["riser_mind_quote", "drop_mind_wrong"]


func _initialize() -> void:
	var zones := {}
	for stage in range(1, ParkDefs.COUNT + 1):
		zones[stage] = MusicRows.zone_id(stage, ParkDefs)
	_t.eq("six park stages", zones.size(), 6)
	var by_cue := {}
	for stage in zones:
		var zone: String = zones[stage]
		var map_id: String = ParkDefs.of(stage)["map"]
		var cues := _park_cues(map_id)
		_t.check("%s (%s) names park cues" % [zone, map_id], cues.size() >= 8, str(cues))
		for cue in cues:
			var row := MusicRows.cue(cue, {"stage": zone, "theme": 0, "ancient": "reactor", "motif": "sable"})
			if zone.begins_with("3") and cue in MIND_CUES:
				# No file: the engine's pilot-aware Mind quote plays (tools/ace/highdraft_stingers.py).
				_t.check("%s %s has no cut file" % [zone, cue], not SfxBank.file_exists(SfxBank.stinger_id(zone, cue)))
				_t.check("%s %s plays the synth Mind quote" % [zone, cue], not row.get("stinger", false))
				continue
			var want := SfxBank.stinger_id(zone, cue)
			_t.check("%s %s resolves to its own file" % [zone, cue], row.get("stinger", false) and row.get("sound", "") == want, str(row.get("sound", "")))
			var samples := SfxBank.file_samples(want)
			_t.check("%s %s file has audio" % [zone, cue], samples.size() > 4000, str(samples.size()))
			var path := SfxBank.file_path(want)
			if not by_cue.has(cue):
				by_cue[cue] = {}
			by_cue[cue][zone] = FileAccess.get_sha256(path)
	for cue in by_cue:
		var seen := {}
		for zone in by_cue[cue]:
			seen[by_cue[cue][zone]] = zone
		_t.eq("%s is cut separately in every stage that uses it" % cue, seen.size(), by_cue[cue].size())

	_fallback_checks()
	_riser_landing_checks()
	_unfinished_warm_checks()
	_late_cell_checks()
	quit(_t.verdict())


func _park_cues(map_id: String) -> Array:
	var text := FileAccess.get_file_as_string("res://src/world/park/%s.json" % map_id)
	var data = JSON.parse_string(text)
	var out := {}
	for row in data["event_rows"]:
		out[row["music_cue"]["telegraph"]] = true
		out[row["music_cue"]["land"]] = true
	var ids := out.keys()
	ids.sort()
	return ids


func _fallback_checks() -> void:
	var options := {"theme": 0, "ancient": "reactor", "motif": "sable"}
	for cue in ["drop_flood", "riser_natural", "drop_boiler", "riser_mind_quote"]:
		var plain := MusicRows.cue(cue, options)
		var missing_stage := options.duplicate()
		missing_stage["stage"] = "9-9"
		_t.eq("a stage with no files falls back to the synth row for %s" % cue, MusicRows.cue(cue, missing_stage), plain)
		_t.check("%s synth fallback has notes" % cue, plain.has("notes") and not plain.has("stinger"))
	# A real stage with no file for this cue: stage 1-1's park never lands drop_impact.
	var no_file := options.duplicate()
	no_file["stage"] = "1-1"
	_t.check("1-1 has no drop_impact file", not SfxBank.file_exists(SfxBank.stinger_id("1-1", "drop_impact")))
	_t.eq("1-1 drop_impact is the synth row", MusicRows.cue("drop_impact", no_file), MusicRows.cue("drop_impact", options))
	# #83 gave the Highdraft its own boiler, so drop_boiler's synth row is no longer drop_industrial's.
	var boiler := MusicRows.cue("drop_boiler", options)
	_t.check("drop_boiler without a stage is its own boiler_burst synth row",
		boiler.get("sound") == "boiler_burst" and boiler != MusicRows.cue("drop_industrial", options))


func _active(e) -> Array:
	return e._actions.filter(func(a): return a.get("type") == "park_cue")


func _riser_landing_checks() -> void:
	var options := {"stage": "3-1", "theme": 2, "ancient": "mind", "motif": "sable"}
	var riser_length: int = SfxBank.file_samples(SfxBank.stinger_id("3-1", "riser_fleet")).size()
	_t.check("the riser file is a bar long", riser_length > 60000, str(riser_length))
	for lead: int in [riser_length * 4, riser_length, riser_length - 5000, 20000]:
		var e = MusicEngine.new()
		e.band_muted = true
		var landing: int = 100000 + lead
		e.park_cue("riser_fleet", lead, 100000, options, 0.0, "ev")
		e.park_cue("drop_fleet_anvil", 0, landing, options, 0.0, "ev")
		var actions := _active(e)
		var files := actions.filter(func(a): return a.row.get("stinger", false) and a.row.rise)
		var drops := actions.filter(func(a): return not a.row.rise)
		_t.eq("lead %d: one file riser and one drop" % lead, [files.size(), drops.size()], [1, 1])
		if files.size() != 1 or drops.size() != 1:
			continue
		var file: Dictionary = files[0]
		_t.eq("lead %d: the riser ends on the drop's frame" % lead, int(file.at) + int(file.length), int(drops[0].at))
		_t.eq("lead %d: the drop is at the landing" % lead, int(drops[0].at), landing)
		_t.check("lead %d: the drop plays a file" % lead, drops[0].row.get("stinger", false))
		var synth := actions.filter(func(a): return a.row.rise and not a.row.get("stinger", false))
		var latest := 0
		for a in synth:
			latest = maxi(latest, int(a.at) + int(a.length))
			_t.check("lead %d: synth cells sit before the file" % lead, int(a.at) >= 100000)
		_t.check("lead %d: synth ends by the file's start" % lead, synth.is_empty() or latest <= int(file.at), "%d vs %d" % [latest, file.at])
		if lead >= riser_length:
			_t.eq("lead %d: the whole file plays" % lead, int(file.length), riser_length)
			_t.eq("lead %d: it starts at landing minus its length" % lead, int(file.at), landing - riser_length)
		else:
			_t.eq("lead %d: a short lead starts now and trims the head" % lead, int(file.at), 100000)
			_t.eq("lead %d: the trim is the overhang" % lead, int(file.get("skip", 0)), riser_length - lead)
		var buf: PackedFloat32Array = e.park_cue_samples(file, 0)
		_t.eq("lead %d: the rendered riser length is the action length" % lead, buf.size(), int(file.length))


# A cell whose warm task is still queued or rendering when its beat comes renders on the spot: at the
# Warden's engage the next stage's preparation held a park cue's warm for 1 s on the cloud, and the
# beat waited on it (scrapkeep#241, the 4080 stage 1 spikes).
func _unfinished_warm_checks() -> void:
	var options := {"stage": "1-1", "theme": 0, "ancient": "reactor", "motif": "sable"}
	var e = MusicEngine.new()
	e.band_muted = true
	e.park_cue("drop_fleet_anvil", 0, 100000, options, 0.0, "ev")
	var actions := _active(e)
	if actions.is_empty():
		_t.check("a park cue is booked", false)
		return
	var cell: Dictionary = actions[0]
	var signature := MusicEngine._park_signature(cell, 0, e.step_len)
	var plain = MusicEngine.new()
	plain.band_muted = true
	var want: PackedFloat32Array = plain.park_cue_samples(cell, 0)
	# The held warm finishes only when released below, so a render that waited on it would never return.
	var gate := Semaphore.new()
	var held := WorkerThreadPool.add_task(func(): gate.wait(), true, "park_stinger_test held warm")
	e._park_pcm.clear()
	e._park_tasks[signature] = held
	MusicEngine._stinger_tasks.append(held)
	var buf: PackedFloat32Array = e.park_cue_samples(cell, 0)
	_t.check("an unfinished warm is not waited for; the cell renders on the spot",
		not WorkerThreadPool.is_task_completed(held) and buf == want)
	_t.check("the unfinished warm stays listed for teardown", MusicEngine._stinger_tasks.has(held))
	gate.post()
	MusicEngine.settle_stingers()


# A cell booked ahead whose worker is still rendering at its beat waits for it like a late cell (the crown's
# spire telegraph held a frame 300 ms on the cloud, scrapkeep#241), then plays from where it would be by now.
func _late_cell_checks() -> void:
	var options := {"stage": "1-1", "theme": 0, "ancient": "reactor", "motif": "sable"}
	var e = MusicEngine.new()
	e.band_muted = true
	e.park_cue("drop_fleet_anvil", 0, 100000, options, 0.0, "ev")
	var actions := _active(e)
	if actions.is_empty():
		_t.check("a park cue is booked", false)
		return
	var cell: Dictionary = actions[0]
	e._actions.clear()
	var signature := MusicEngine._park_signature(cell, 0, e.step_len)
	var plain = MusicEngine.new()
	plain.band_muted = true
	var want: PackedFloat32Array = plain.park_cue_samples(cell, 0)
	var gate := Semaphore.new()
	var held := WorkerThreadPool.add_task(func(): gate.wait(), true, "park_stinger_test late cell")
	e._park_pcm.clear()
	e._park_tasks[signature] = held
	MusicEngine._stinger_tasks.append(held)
	var booked := int(cell.at)
	e.clock = booked
	e._step_clock = e.clock
	e._actions.append(cell)
	e._run_due()
	var waiting := _active(e)
	_t.check("a due cell whose worker is rendering waits and plays nothing yet",
		waiting.size() == 1 and waiting[0].get("late", false) and e.park_cue_log.is_empty(), str(waiting))
	gate.post()
	while not WorkerThreadPool.is_task_completed(held):
		pass
	e._park_warm_lock.lock()
	e._park_warm[signature] = want
	e._park_warm_lock.unlock()
	var waited := 512
	e.clock += waited
	e._step_clock = e.clock
	e._run_due()
	var log: Dictionary = e.park_cue_log.back() if not e.park_cue_log.is_empty() else {}
	_t.check("once rendered it plays from where it would be by now, logged at its booked time",
		_active(e).is_empty() and not log.is_empty() and int(log.at) == booked + waited and int(log.end) - int(log.at) == want.size() and int(log.scheduled) == booked,
		str(log))
