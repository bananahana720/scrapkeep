# smoke: bots timeout=1200s (one bot child: Tarn completionist through stage 5, about 9 to 14 min wall)
# 2026-10-17 ISLE-SKIRT: red team w16 sweep b0, seed 36003 completionist tarn --late-offer=take,
# stalled in the stage-5 beacon state at 768 s on 692fa3ff: engaged at 37.3 s, never broken. From
# t=100 s the ball ran up and down the east skirt of the Hanging Isle's ramp (x 14 to 17, z -7 to
# -24, the ramp at x 6 to 12) while every replan pointed it up the skirt's side face. Stage 5 then
# planned with the end-height slope test (MIND-ROUTE, 035829c8), which reads that skirt as one gentle
# step; with the two-half test the other stages use the same run wins at 73003 ticks. The stall
# needs the whole run's path: a calm climb from the stall points and a --from-stage=5 resume both
# clear stage 5 either way, so this test replays the run from the start.
extends SceneTree

const ChildRuns := preload("res://tests/trees/child_runs.gd")
const T := preload("res://tests/support/t.gd")
const STAGE := 5
const SEED := 36003


func _initialize() -> void:
	var t := T.new("bot_isle_stage5_test")
	var folder := OS.get_user_data_dir().path_join("bot-isle-stage5-%d" % OS.get_process_id())
	var args := ["--out=" + folder, "--policy=completionist", "--seeds=%d" % SEED, "--pilot=tarn", "--late-offer=take", "--stages=%d" % STAGE]
	var result: Dictionary = ChildRuns.run([{"script": "res://tools/bot_run.gd", "home": folder, "args": args}], 1080.0)[0]
	t.check("the run ran", result["code"] == 0 and not result["timed_out"], "exit %s, timed out %s" % [result["code"], result["timed_out"]])
	var lines := FileAccess.get_file_as_string(folder.path_join("bots.ndjson")).split("\n", false)
	var row = JSON.parse_string(lines[0]) if lines.size() == 1 else null
	var note := {}
	if row is Dictionary:
		for stage_note in row.get("stages", []):
			if int(stage_note.get("stage", 0)) == STAGE:
				note = stage_note
	var broken = note.get("warden_broken_s")
	print("stage %d: outcome %s, engaged at %s, broken at %s, stuck detours %s, stall state %s" % [STAGE,
		row.get("outcome") if row is Dictionary else null, note.get("warden_engaged_s"), broken, note.get("stuck_detours"), note.get("stall_state")])
	t.check("the stage-%d Warden breaks" % STAGE, broken != null, "broken at %s; evidence %s" % [broken, folder])
	t.check("the run clears stage %d" % STAGE, row is Dictionary and row.get("outcome") == "stages_done",
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
