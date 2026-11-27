# smoke: bots timeout=720s (two bot children in sequence: stages 1-2 about 170 s wall, then stage 3 about 160 s)
# 2026-10-17 S3-HAUL: seed 1 skipper pylon_engineer on --table=park stalled at stage 3 every run:
# the Warden staggered with the posture bar full at least five times with all 4 chunks on, but
# its stagger drops it onto a floor 7 to 15 m over the ball's ground, and the bot's off-line bite
# (tools/bot_driver.gd _anchor_open) waited to be over the open point, out of a jump's reach. The
# stage ended at the stage cap with 1 chunk left. The first child plays stages 1 and 2 and saves
# the stage-3 entrance; the second resumes it with --from-stage=3 (the resumed stage repeats the
# stall on 475a12f5) and must break the Warden before the stage cap.
extends SceneTree

const ChildRuns := preload("res://tests/trees/child_runs.gd")
const T := preload("res://tests/support/t.gd")
const BotDriver := preload("res://tools/bot_driver.gd")
const STAGE := 3
const SEED := 1


func _initialize() -> void:
	var t := T.new("bot_park_stage3_break_test")
	var folder := OS.get_user_data_dir().path_join("bot-park-stage3-%d" % OS.get_process_id())
	var base := ["--out=" + folder, "--policy=skipper", "--seeds=%d" % SEED, "--pilot=pylon_engineer", "--table=park"]
	var first: Dictionary = ChildRuns.run([{"script": "res://tools/bot_run.gd", "home": folder, "args": base + ["--stages=%d" % (STAGE - 1)]}], 360.0)[0]
	t.check("stages 1-2 ran", first["code"] == 0 and not first["timed_out"], "exit %s, timed out %s" % [first["code"], first["timed_out"]])
	var entrance = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("entrance.json")))
	var run = entrance.get("run") if entrance is Dictionary else null
	var saved: bool = run is Dictionary and int(run.get("stage", 0)) == STAGE
	t.check("stage %d entrance saved" % STAGE, saved, str(run.get("stage") if run is Dictionary else null))
	var note := {}
	var row = null
	if saved:
		DirAccess.remove_absolute(folder.path_join("bots.ndjson"))
		var second: Dictionary = ChildRuns.run([{"script": "res://tools/bot_run.gd", "home": folder,
			"args": base + ["--from-stage=%d" % STAGE, "--until=%d" % STAGE]}], 360.0)[0]
		t.check("stage %d ran" % STAGE, second["code"] == 0 and not second["timed_out"],
			"exit %s, timed out %s" % [second["code"], second["timed_out"]])
		var lines := FileAccess.get_file_as_string(folder.path_join("bots.ndjson")).split("\n", false)
		row = JSON.parse_string(lines[0]) if lines.size() == 1 else null
		if row is Dictionary:
			for stage_note in row.get("stages", []):
				if int(stage_note.get("stage", 0)) == STAGE:
					note = stage_note
	var broken = note.get("warden_broken_s")
	var cap := float(BotDriver.STAGE_LIMIT)
	print("park stage %d: outcome %s, broken at %s, hauls %s, chunks from a haul %s, exit at %s" % [STAGE,
		row.get("outcome") if row is Dictionary else null, broken, note.get("latch_hauls"), note.get("latch_chunks"), note.get("exit_s")])
	t.check("the stage-%d Warden breaks before the %.0f s stage cap" % [STAGE, cap], broken != null and float(broken) < cap,
		"broken at %s; evidence %s" % [broken, folder])
	t.check("the run leaves stage %d" % STAGE, row is Dictionary and row.get("outcome") == "until",
		"outcome %s" % [row.get("outcome") if row is Dictionary else null])
	if t.failures == 0:
		_remove(folder)
	quit(t.verdict())


func _remove(path: String) -> void:
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	for sub in DirAccess.get_directories_at(path):
		_remove(path.path_join(sub))
	DirAccess.remove_absolute(path)
