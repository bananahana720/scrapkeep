extends "res://tools/bot_run.gd"

# The challenge lane's runner (scripts/challenge/README.md): tools/bot_run.gd plus the four
# switches the band-table harness needs to start a run from a saved build and stop it at a
# fight. One seed per process; the harness rotates seeds across processes.
#
#   godot --headless --fixed-fps 90 --path sketches/core-loop --script res://tools/band_run.gd \
#     -- --out=<dir> --policy=<p> --seeds=<n> --table=park --gate=1 --from-stage=N [--until=N]
#     [--entrance=<abs path>] [--keep-entrances=1] [--to-boss=1] [--stop-at=engaged:<stage>]
#     [--cell=<id>]
#
# --entrance=<file> copies a saved entrance doc to <out>/entrance.json before the Game exists,
# so --from-stage=N resumes it. The doc's stage must equal --from-stage (exit 2 otherwise).
# --keep-entrances=1 copies each entrance the run writes to <out>/entrance-s<stage>.json, one
# physics tick after the stage is entered (the doc lands after stage_entered fires).
# --to-boss=1 calls flow.enter_boss once the run is in play, so the bot fights the world's boss at
# once. The run ends on the boss's result, or "until" if --until=N is set and the boss falls.
# --stop-at=engaged:<stage> ends the run as "reached" the tick that stage's Warden is engaged.
# The row keeps bot_run's format and gains "entrance" (the doc's basename) and "cell".
# The band flags (--band, --attempt) are tools/bot_run.gd's, from tools/skill_band.gd.

var _band_hooked := false
var _band_copy_stage := -1
var _band_boss_done := false
var _band_reached := false
var _band_stop_stage := -1
var _band_rows_seen := 0


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
			if _band_reached:
				_driver._end("reached")
			elif _settings.get("to-boss", "0") == "1" and not _band_boss_done and _game.flow.in_stage() \
					and (not _settings.has("from-stage") or _game.run.stage == int(_settings["from-stage"])):
				_band_boss_done = true
				_game.flow.enter_boss(Vector3(15.0, 0.0, 0.0))
	var over := super._physics_process(delta)
	# The doc is saved at the end of enter_stage, so by here it is on disk, even on the tick that ends an --until run.
	if _band_copy_stage >= 0 and _settings.get("keep-entrances", "0") == "1":
		_keep_entrance()
	_band_copy_stage = -1
	if _results.size() > _band_rows_seen:
		_band_rows_seen = _results.size()
		_annotate_row()
	return over


# A RunStore file wraps the entrance doc: {generation, schema, run: {stage, ...}}.
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


# bot_run appends the row inside its tick; rewrite the last line with the harness fields.
func _annotate_row() -> void:
	var path := _out.path_join("bots.ndjson")
	var lines := FileAccess.get_file_as_string(path).split("\n", false)
	if lines.is_empty():
		return
	var row = JSON.parse_string(lines[lines.size() - 1])
	if not row is Dictionary:
		return
	row["entrance"] = String(_settings["entrance"]).get_file() if _settings.has("entrance") else null
	row["cell"] = String(_settings["cell"]) if _settings.has("cell") else null
	lines[lines.size() - 1] = JSON.stringify(row)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
