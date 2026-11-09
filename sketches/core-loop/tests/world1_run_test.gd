# smoke: bots timeout=1800s (six launched-game children and one planted control, three at a time, each from the title through the dam, the flume and Brindle into stage 3; 250 to 340 s a child and 662 s in all on a 4-core cloud box, 2026-11-09)
extends SceneTree

const T := preload("res://tests/support/t.gd")
const ChildRuns := preload("res://tests/trees/child_runs.gd")

# The world 1 run, on the game a player launches: the main scene, the six parks (not the legacy
# maps a test_mode game plays), real ticks, the workshop's pauses, its own save folder. A bot plays
# each pilot from the title through the dam and its Warden, the flume, and Brindle, and stops as
# stage 3 opens (tools/self_play.gd, --self-play-watch=1). Per pilot:
#   - the run gets there: the dam's exit, the flume, Brindle's arena, Brindle down, stage 3;
#   - nothing a player would report: no script error or engine ERROR line, the ball never wedged
#     against a wall at rest and never fell through the floor (tools/qa_watch.gd);
#   - the objective plate is never empty in play for PLATE_BLANK_S or more;
#   - the run saved into its own folder.
# Stuck and hung counts are printed, not judged: a camper's stall and a mounted special rest by design.
# Evidence limit: one seed a pilot, the skipper, headless; real ticks, so a seed does not replay
# exactly and a red here wants one rerun before it counts. Menus are not pressed: the run starts
# by code (flow.press_start), as every bot's does; the title's own tests press them.

const PILOTS := ["pylon_engineer", "runner_gunner", "demolitions_caster", "tarn", "tally", "remembered_cannon"]
const PARALLEL := 3
const CHILD_S := 1500.0
const PLATE_BLANK_S := 10.0
const NEEDS := [
	["the dam's exit is taken", "self-play: stage 1 exit taken at "],
	["the flume is entered", "self-play: stage 2 entered at "],
	["Brindle's arena is entered", "self-play: boss arena entered at "],
	["Brindle goes down", "self-play: boss defeated at "],
	["stage 3 opens", "self-play: stage 3 entered at "],
]


func _initialize() -> void:
	var t := T.new("world1_run_test")
	var jobs := []
	for pilot in PILOTS:
		jobs.append({"name": pilot, "args": ["--self-play", "--self-play-seed=1", "--self-play-pilot=" + pilot, "--self-play-until=3",
			"--self-play-hold=1", "--self-play-watch=1"]})
	# The control: a run planted to end at once must read red on the same lines a pilot is judged by.
	jobs.append({"name": "planted_end", "args": ["--self-play", "--self-play-until=3", "--self-play-watch=1", "--self-play-plant-end"]})
	var base := ProjectSettings.globalize_path("user://").path_join("world1-run-%d" % OS.get_process_id())
	var runs := ChildRuns.run_launched(jobs, base, CHILD_S, PARALLEL)
	for i in PILOTS.size():
		var pilot: String = PILOTS[i]
		var run: Dictionary = runs[i]
		var text: String = run["text"]
		t.check("%s: the run reaches stage 3 and quits 0" % pilot, _reached(run),
			"exit %d%s, %.0f s wall; %s" % [run["code"], " (killed at %d s)" % int(CHILD_S) if run["timed_out"] else "", run["seconds"], _last_line(text)])
		for need in NEEDS:
			t.check("%s: %s" % [pilot, need[0]], _line(text, need[1]) != "", _line(text, need[1]))
		var errors := _errors(text)
		t.check("%s: no script error or ERROR line" % pilot, errors.is_empty(), "%d lines%s" % [errors.size(), "" if errors.is_empty() else ": " + errors[0]])
		var watch := _watch(text)
		t.check("%s: the watch reported" % pilot, not watch.is_empty(), _line(text, "self-play: watch "))
		t.check("%s: the ball never wedged at rest and never fell through" % pilot, int(watch.get("wedged", -1)) == 0 and int(watch.get("fell", -1)) == 0,
			"wedged %s, fell %s (stuck %s, hung %s, not judged)" % [watch.get("wedged", "?"), watch.get("fell", "?"), watch.get("stuck", "?"), watch.get("hung", "?")])
		t.check("%s: the objective plate is never empty for %d s of play" % [pilot, int(PLATE_BLANK_S)],
			float(watch.get("blank_max", INF)) < PLATE_BLANK_S, "longest empty stretch %s s, %s plate changes" % [watch.get("blank_max", "?"), watch.get("objectives", "?")])
		t.check("%s: stages 1, 2 and 3 in order" % pilot, String(watch.get("stages", "")) == "1,2,3", "stages %s" % watch.get("stages", "?"))
		t.check("%s: the run saved into its own folder" % pilot, _saved(run["data"]), run["data"].get_file())
	var planted: Dictionary = runs[PILOTS.size()]
	t.check("control: a run that ends early reads as not reaching stage 3", not _reached(planted) and planted["code"] == 1,
		"exit %d; %s" % [planted["code"], _last_line(planted["text"])])
	t.check("control: and shows none of the run's milestones", NEEDS.all(func(need): return _line(planted["text"], need[1]) == ""),
		"%d of %d lines present" % [NEEDS.filter(func(need): return _line(planted["text"], need[1]) != "").size(), NEEDS.size()])
	quit(t.verdict())


func _reached(run: Dictionary) -> bool:
	return run["code"] == 0 and not run["timed_out"]


# The watch line's name=value pairs.
func _watch(text: String) -> Dictionary:
	var out := {}
	for pair in _line(text, "self-play: watch ").trim_prefix("self-play: watch ").split(" ", false):
		var at := pair.find("=")
		if at > 0:
			out[pair.substr(0, at)] = pair.substr(at + 1)
	return out


func _line(text: String, prefix: String) -> String:
	for line in text.split("\n"):
		if line.begins_with(prefix):
			return line.strip_edges()
	return ""


func _last_line(text: String) -> String:
	var last := ""
	for line in text.split("\n"):
		if line.begins_with("self-play: "):
			last = line.strip_edges()
	return last


func _errors(text: String) -> Array:
	var out := []
	for line in text.split("\n"):
		if line.contains("SCRIPT ERROR") or line.begins_with("ERROR"):
			out.append(line.strip_edges())
	return out


func _saved(data: String) -> bool:
	var apps := data.path_join("godot/app_userdata")
	for app in DirAccess.get_directories_at(apps):
		var userdata := apps.path_join(app)
		for dir in DirAccess.get_directories_at(userdata):
			if dir.begins_with("self-play-") and DirAccess.get_files_at(userdata.path_join(dir)).has("run.json"):
				return true
	return false
