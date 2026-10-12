# smoke: bots timeout=1500s (four full skipper runs of one pilot in child processes at once, stage 1 to the win)
# 2026-10-12 (W13 coordinator): on 00a1bdf, pre-kit Kest won 4/4 at 637, 739, 742, 791 s wall
# (435 to 626 s game) with an 1100 s child cap; Cannon won 4/4 at 442 to 471 s wall.
# At the old 330 s child cap every child was killed (coordinator receipts, 2026-10-12).
# The six-pilot slice: this file plays Sable and is the template; bot_six_<pilot>_test.gd extends it
# for each other pilot, one bot-tier test per pilot under the runner's 1500 s head cap.
# 2026-10-10 (wave 13 B4): re-pinned for the skill bar; each winning run must also cast slots 2
# and 3 and fire a set piece (SKILL-BAR.md section 10, B4 acceptance). The win rule is unchanged.
extends SceneTree

const ChildRuns := preload("res://tests/trees/child_runs.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")
const T := preload("res://tests/support/t.gd")

# Every pilot must win the whole run on at least MIN_WINS of SEEDS, so a tuning change that
# strands one pilot fails here. One seed may lose to run luck (P-R19: Tally seeds 6 and 7 stall).
const SEEDS := [1, 2, 3, 4]
const MIN_WINS := 3
# Under the 1500 s head cap, with room for the parent's start and the record reads.
const CHILD_CAP_S := 1380.0
# A losing seed's child log and record land here, under <pilot>/, for the report.
const LOSS_DIR := "../../artifacts/local/bots/six"


func _pilot() -> String:
	return "pylon_engineer"


func _initialize() -> void:
	var pilot := _pilot()
	var t := T.new(get_script().resource_path.get_file().get_basename())
	var base := OS.get_user_data_dir().path_join("bot-six-%s-%d" % [pilot, OS.get_process_id()])
	var jobs := []
	for s in SEEDS:
		jobs.append({"script": "res://tools/bot_run.gd", "args": ["--out=" + base.path_join(str(s)),
			"--policy=skipper", "--seeds=%d" % s, "--pilot=" + pilot, "--trace=1"]})
	var results := ChildRuns.run(jobs, CHILD_CAP_S)
	var wins := 0
	var table := []
	for i in SEEDS.size():
		var s: int = SEEDS[i]
		var result: Dictionary = results[i]
		var errors: Array = ChildRuns.summary(result)["errors"]
		t.check("%s seed %d no script errors" % [pilot, s], errors.is_empty(), "%s" % [errors])
		var path := base.path_join(str(s)).path_join("bots.ndjson")
		var rows := FileAccess.get_file_as_string(path).split("\n", false) if FileAccess.file_exists(path) else PackedStringArray()
		var row = JSON.parse_string(rows[-1]) if not rows.is_empty() else null
		var record: Dictionary = row if row is Dictionary else {}
		var outcome := String(record.get("outcome", "timed_out" if result["timed_out"] else "no_record"))
		if not record.is_empty():
			t.eq("%s seed %d played %s" % [pilot, s, pilot], record["class"], pilot)
		var won := outcome == "won" and int(record.get("stage_reached", 0)) == StageDefs.COUNT
		if won:
			wins += 1
			# 2026-10-10 (wave 13 B4, SKILL-BAR section 10): a winning run casts slot 2 and slot 3 at
			# least once each and fires at least one set piece, through the bot's number keys and Q.
			var casts: Dictionary = record.get("slot_casts", {})
			t.check("%s seed %d won with slot 2 and slot 3 cast and a set piece fired" % [pilot, s],
				int(casts.get("special", 0)) >= 1 and int(casts.get("line", 0)) >= 1 and int(record.get("ultimates", 0)) >= 1,
				"slot casts %s, set pieces %s, fills %s" % [casts, record.get("ultimates", 0), record.get("ult_fill_s", [])])
		else:
			_keep_loss(pilot, s, String(result["log"]), rows)
		table.append("six-pilot %s seed %d: %s at stage %d, %d ticks, %.1f wall seconds, casts %s, set pieces %s" % [pilot, s, outcome,
			int(record.get("stage_reached", 0)), int(record.get("ticks", 0)), float(record.get("wall_seconds", 0.0)),
			record.get("slot_casts", {}), record.get("ultimates", 0)])
	for line in table:
		print(line)
	t.check("%s won at least %d of seeds %s" % [pilot, MIN_WINS, SEEDS], wins >= MIN_WINS, "%d won" % wins)
	_remove_tree(base)
	quit(t.verdict())


func _keep_loss(pilot: String, s: int, text: String, rows: PackedStringArray) -> void:
	var dir := ProjectSettings.globalize_path("res://").path_join(LOSS_DIR).path_join(pilot).simplify_path()
	DirAccess.make_dir_recursive_absolute(dir)
	var file := FileAccess.open(dir.path_join("seed-%d.log" % s), FileAccess.WRITE)
	if file != null:
		file.store_string(text + "\n" + "\n".join(rows) + "\n")
	print("six-pilot %s seed %d trace kept at %s" % [pilot, s, dir.path_join("seed-%d.log" % s)])


func _remove_tree(path: String) -> void:
	for sub in DirAccess.get_directories_at(path):
		_remove_tree(path.path_join(sub))
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)
