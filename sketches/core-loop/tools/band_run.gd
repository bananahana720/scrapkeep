extends "res://tools/bot_run.gd"


var _band_hooked := false
var _band_copy_stage := -1
var _band_boss_done := false
var _band_reached := false
var _band_stop_stage := -1
var _band_rows_seen := 0
var _band_limits_set := false
var _band_resumed = null
var _band_checked := false


func _initialize() -> void:
	var s := _parse(OS.get_cmdline_user_args())
	if s.has("out") and s.has("seeds") and String(s["seeds"]).contains(","):
		printerr("band_run: one seed per process; --seeds=%s" % s["seeds"])
		quit(2)
		return
	if s.has("stop-at"):
		var parts := String(s["stop-at"]).split(":")
		if parts.size() != 2 or parts[0] != "engaged" or not parts[1].is_valid_int():
			printerr("band_run: --stop-at must be engaged:<stage>")
			quit(2)
			return
		_band_stop_stage = int(parts[1])
	if s.has("out") and s.has("entrance"):
		var out := _absolute(s["out"])
		DirAccess.make_dir_recursive_absolute(out)
		var doc = JSON.parse_string(FileAccess.get_file_as_string(String(s["entrance"])))
		if not doc is Dictionary or not s.has("from-stage") or _doc_stage(doc) != int(s["from-stage"]):
			printerr("band_run: --entrance %s is stage %s but --from-stage is %s" % [s["entrance"],
				_doc_stage(doc) if doc is Dictionary else "unreadable", s.get("from-stage", "missing")])
			quit(2)
			return
		DirAccess.copy_absolute(String(s["entrance"]), out.path_join("entrance.json"))
	super._initialize()


func _physics_process(delta: float) -> bool:
	if _game != null and _game.flow != null:
		if not _band_hooked:
			_band_hooked = true
			_game.events.stage_entered.connect(func(stage: int, _retry: bool): _band_copy_stage = stage)
			if _band_stop_stage > 0:
				_game.events.warden_engaged.connect(func(stage: int):
					if stage == _band_stop_stage:
						_band_reached = true)
		if _driver != null:
			if not _band_limits_set:
				_band_limits_set = true
				if _settings.has("fight-limit"):
					_driver.fight_limit = float(_settings["fight-limit"])
				if _settings.has("stage-limit"):
					_driver.stage_limit = float(_settings["stage-limit"])
			if _band_reached:
				_driver._end("reached")
			elif _settings.get("to-boss", "0") == "1" and not _band_boss_done and _game.flow.in_stage() \
					and (not _settings.has("from-stage") or _game.run.stage == int(_settings["from-stage"])):
				_band_boss_done = true
				_game.flow.enter_boss(Vector3(15.0, 0.0, 0.0))
	var over := super._physics_process(delta)
	if not _band_checked and _driver != null and _game != null and _game.run != null:
		_band_checked = true
		_band_resumed = _check_resumed()
	if _band_copy_stage >= 0 and _settings.get("keep-entrances", "0") == "1":
		_keep_entrance()
	_band_copy_stage = -1
	if _results.size() > _band_rows_seen:
		_band_rows_seen = _results.size()
		_annotate_row()
	return over


static func _doc_stage(doc: Dictionary) -> int:
	var run = doc.get("run", doc)
	return int(run.get("stage", -1)) if run is Dictionary else -1


func _keep_entrance() -> void:
	var path := _out.path_join("entrance.json")
	if not FileAccess.file_exists(path):
		return
	var text := FileAccess.get_file_as_string(path)
	var doc = JSON.parse_string(text)
	if not doc is Dictionary:
		return
	var file := FileAccess.open(_out.path_join("entrance-s%d.json" % _doc_stage(doc)), FileAccess.WRITE)
	if file != null:
		file.store_string(text)


func _check_resumed():
	if not _settings.has("entrance"):
		return null
	var doc = JSON.parse_string(FileAccess.get_file_as_string(String(_settings["entrance"])))
	if not doc is Dictionary:
		return false
	var run = doc.get("run", doc)
	var ok: bool = _game.run.stage == int(run.get("stage", -1)) \
		and _game.run.parts.size() == (run.get("parts", []) as Array).size() \
		and absf(float(_game.run.mass) - float(run.get("mass", 0.0))) <= 0.01
	if not ok:
		printerr("band_run: --entrance was not resumed: run stage %d, %d parts, mass %s; doc stage %s, %d parts, mass %s" % [
			_game.run.stage, _game.run.parts.size(), _game.run.mass, run.get("stage"), (run.get("parts", []) as Array).size(), run.get("mass")])
	return ok


func _annotate_row() -> void:
	var path := _out.path_join("bots.ndjson")
	var lines := FileAccess.get_file_as_string(path).split("\n", false)
	if lines.is_empty():
		return
	var row = JSON.parse_string(lines[lines.size() - 1])
	if not row is Dictionary:
		return
	row["resumed"] = _band_resumed
	row["entrance"] = String(_settings["entrance"]).get_file() if _settings.has("entrance") else null
	row["cell"] = String(_settings["cell"]) if _settings.has("cell") else null
	lines[lines.size() - 1] = JSON.stringify(row)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
