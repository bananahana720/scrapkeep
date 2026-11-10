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
#   - the objective plate is never empty in play for PLATE_BLANK_S or more, and the hull bar never
#     stands off the hull for BAR_OFF_S or more;
#   - the pilot's skill slots 2 and 3 are each cast at least once (the guard the old-map
#     bot_six_<pilot> proofs carried, which now run weekly);
#   - the run saved into its own folder.
# Stuck and hung counts are printed, not judged: a camper's stall and a mounted special rest by design.
# A second go: a pilot whose run does not reach stage 3 (it died, stalled or was killed at the
# wall) plays once more on AGAIN_SEED inside the same budget. The game is hard and its ticks are
# real, so a death is play, not a fault: on 10 Nov 2026 the test failed 5 of 22 runs of builds with
# nothing wrong, mostly a pilot scrapped on the dam (the plant measurement). The milestones, the
# skill slots, the stage order and the save are judged on the pilot's last go; an error line, a
# wedge, a fall, an empty plate and a bar off the hull are judged on every go, so a second go
# never hides one. A fault that stops every run (a Brindle that cannot die) fails both goes.
# Evidence limit: one seed a go, the skipper, headless; real ticks, so a seed does not replay
# exactly. Menus are not pressed: the run starts
# by code (flow.press_start); session_test presses the title, the prologue and the pilot select as keys. Each go
# has to beat Brindle without dying (a death ends it), and the run stops a second into stage 3,
# so stage 3's park has to build. What the watch's quiet rows are worth is play_watch_test's to
# prove (each row made to fire); the control here proves the milestone and exit-code lines.

const PILOTS := ["pylon_engineer", "runner_gunner", "demolitions_caster", "tarn", "tally", "remembered_cannon"]
const PARALLEL := 3
const CHILD_S := 1500.0
# All seven children share this wall, under the marker's 1800 s: a pilot that hangs in the second
# three is killed here and named in its own row, not left running when the runner kills this test.
const BUDGET_S := 1650.0
const PLATE_BLANK_S := 10.0
const BAR_OFF_S := 3.0
const AGAIN_SEED := 2
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
		jobs.append({"name": pilot, "args": _pilot_args(pilot, 1)})
	# The control: a run planted to end at once must read red on the same lines a pilot is judged by.
	jobs.append({"name": "planted_end", "args": ["--self-play", "--self-play-until=3", "--self-play-watch=1", "--self-play-plant-end"]})
	var base := ProjectSettings.globalize_path("user://").path_join("world1-run-%d" % OS.get_process_id())
	var began := Time.get_ticks_msec()
	var runs := ChildRuns.run_launched(jobs, base, CHILD_S, PARALLEL, BUDGET_S)
	# The second goes, in what is left of the budget (a budget of 0 would mean no wall at all).
	var again_jobs := []
	for i in PILOTS.size():
		if not _reached(runs[i]):
			again_jobs.append({"name": PILOTS[i] + "-again", "pilot": PILOTS[i], "args": _pilot_args(PILOTS[i], AGAIN_SEED)})
	var again := {}
	if not again_jobs.is_empty():
		var left := maxf(1.0, BUDGET_S - (Time.get_ticks_msec() - began) / 1000.0)
		var second := ChildRuns.run_launched(again_jobs, base, CHILD_S, PARALLEL, left)
		for i in again_jobs.size():
			again[again_jobs[i]["pilot"]] = second[i]
	print("world1_run_test: %d of %d pilots needed a second go%s" % [again.size(), PILOTS.size(),
		"" if again.is_empty() else " (%s)" % ", ".join(again.keys())])
	for i in PILOTS.size():
		var pilot: String = PILOTS[i]
		for row in _judge(pilot, [runs[i]] + ([again[pilot]] if again.has(pilot) else [])):
			t.check("%s: %s" % [pilot, row[0]], row[1], row[2])
	var planted: Dictionary = runs[PILOTS.size()]
	t.check("control: a run that ends early reads as not reaching stage 3", not _reached(planted) and planted["code"] == 1,
		"exit %d; %s" % [planted["code"], _last_line(planted["text"])])
	t.check("control: and shows none of the run's milestones", NEEDS.all(func(need): return _line(planted["text"], need[1]) == ""),
		"%d of %d lines present" % [NEEDS.filter(func(need): return _line(planted["text"], need[1]) != "").size(), NEEDS.size()])
	# The second go's rules, on goes made from this run's own logs (no extra child). The stand-in
	# for a good run is the first pilot's last go, so these only speak when that pilot passed.
	var good: Dictionary = again.get(PILOTS[0], runs[0])
	if _judge(PILOTS[0], [good]).all(func(row): return row[1]):
		t.check("control: a first go that ended early is made good by a second go that gets there", _judge(PILOTS[0], [planted, good]).all(func(row): return row[1]))
		t.check("control: two goes that both end early stay red", _failed(_judge(PILOTS[0], [planted, planted])).has("the run reaches stage 3 and quits 0"))
		var wedged: Dictionary = planted.duplicate()
		wedged["text"] = String(good["text"]).replace(" wedged=0 ", " wedged=1 ")
		t.eq("control: a wedge on the first go is not hidden by the second", _failed(_judge(PILOTS[0], [wedged, good])), ["the ball never wedged at rest and never fell through"])
		var errored: Dictionary = planted.duplicate()
		errored["text"] = String(planted["text"]) + "\nSCRIPT ERROR: planted\n"
		t.eq("control: nor is an error line on the first go", _failed(_judge(PILOTS[0], [errored, good])), ["no script error or ERROR line"])
		var stuck_bar: Dictionary = planted.duplicate()
		stuck_bar["text"] = String(good["text"]).replace(" bar_off_max=0.0 ", " bar_off_max=40.0 ")
		t.eq("control: nor a hull bar that stood off the hull", _failed(_judge(PILOTS[0], [stuck_bar, good])), ["the hull bar never stands off the hull for %d s of play" % int(BAR_OFF_S)])
	else:
		print("world1_run_test: the second go's controls did not run (%s did not pass)" % PILOTS[0])
	var code := t.verdict()
	# A green run leaves nothing behind; a red one keeps each child's log and save for reading.
	if code == 0:
		OS.execute("rm", ["-rf", base])
	quit(code)


# One pilot's rows, [what, ok, detail] each, from its goes in order (one, or two when the first
# did not get there). Milestones, skills, stage order and the save read the last go; an error line
# and the watch's findings read every go.
func _judge(pilot: String, goes: Array) -> Array:
	var rows := []
	var run: Dictionary = goes[-1]
	var text: String = run["text"]
	var first := "" if goes.size() == 1 else "; second go, the first ended: %s" % _last_line(goes[0]["text"])
	rows.append(["the run reaches stage 3 and quits 0", _reached(run),
		"exit %d%s, %.0f s wall; %s%s" % [run["code"], " (killed: %d s a child, %d s in all)" % [int(CHILD_S), int(BUDGET_S)] if run["timed_out"] else "", run["seconds"], _last_line(text), first]])
	for need in NEEDS:
		rows.append([need[0], _line(text, need[1]) != "", _line(text, need[1])])
	var errors := []
	for go in goes:
		errors.append_array(_errors(go["text"]))
	rows.append(["no script error or ERROR line", errors.is_empty(), "%d lines%s" % [errors.size(), "" if errors.is_empty() else ": " + errors[0]]])
	var watch := _pairs(text, "self-play: watch ")
	rows.append(["the watch reported", not watch.is_empty(), _line(text, "self-play: watch ")])
	# Every go that got as far as its watch line: a go killed at the wall has none, and the last go must have one.
	var watches: Array = goes.map(func(go): return _pairs(go["text"], "self-play: watch ")).filter(func(w): return not w.is_empty())
	rows.append(["the ball never wedged at rest and never fell through",
		not watches.is_empty() and watches.all(func(w): return int(w.get("wedged", -1)) == 0 and int(w.get("fell", -1)) == 0),
		"wedged %s, fell %s (stuck %s, hung %s, not judged)" % [_each(watches, "wedged"), _each(watches, "fell"), _each(watches, "stuck"), _each(watches, "hung")]])
	rows.append(["the objective plate is never empty for %d s of play" % int(PLATE_BLANK_S),
		not watches.is_empty() and watches.all(func(w): return float(w.get("blank_max", INF)) < PLATE_BLANK_S),
		"longest empty stretch %s s, %s plate changes" % [_each(watches, "blank_max"), _each(watches, "objectives")]])
	rows.append(["the hull bar never stands off the hull for %d s of play" % int(BAR_OFF_S),
		not watches.is_empty() and watches.all(func(w): return float(w.get("bar_off_max", INF)) < BAR_OFF_S),
		"longest stretch off %s s" % _each(watches, "bar_off_max")])
	# The skill bar's hands (SKILL-BAR section 10, B4): the pilot's slot 2 and slot 3 are each cast
	# at least once on the way. Set pieces fired are printed, not judged: world 1 may end first.
	var skills := _pairs(text, "self-play: skills ")
	rows.append(["skill slots 2 and 3 are each cast", int(skills.get("slot2", 0)) >= 1 and int(skills.get("slot3", 0)) >= 1,
		"slot 2 %s casts, slot 3 %s casts, %s set pieces" % [skills.get("slot2", "?"), skills.get("slot3", "?"), skills.get("set_pieces", "?")]])
	rows.append(["stages 1, 2 and 3 in order", String(watch.get("stages", "")) == "1,2,3", "stages %s" % watch.get("stages", "?")])
	rows.append(["the run saved into its own folder", _saved(run["data"]), run["data"].get_file()])
	return rows


# The names of the rows that are not ok.
func _failed(rows: Array) -> Array:
	return rows.filter(func(row): return not row[1]).map(func(row): return row[0])


func _pilot_args(pilot: String, run_seed: int) -> Array:
	return ["--self-play", "--self-play-seed=%d" % run_seed, "--self-play-pilot=" + pilot, "--self-play-until=3",
		"--self-play-hold=1", "--self-play-watch=1"]


# One watch value from every go, in order: "0" for one go, "0, 1" for two.
func _each(watches: Array, key: String) -> String:
	return ", ".join(watches.map(func(w): return String(w.get(key, "?"))))


func _reached(run: Dictionary) -> bool:
	return run["code"] == 0 and not run["timed_out"]


# A line's name=value pairs.
func _pairs(text: String, prefix: String) -> Dictionary:
	var out := {}
	for pair in _line(text, prefix).trim_prefix(prefix).split(" ", false):
		var at := pair.find("=")
		if at > 0:
			out[pair.substr(0, at)] = pair.substr(at + 1)
	return out


func _line(text: String, prefix: String) -> String:
	for line in text.split("\n"):
		if line.begins_with(prefix):
			return line.strip_edges()
	return ""


# The run's last three self-play lines: how it ended (a stall names the stage, the fight and the spot).
func _last_line(text: String) -> String:
	var lines := []
	for line in text.split("\n"):
		if line.begins_with("self-play: "):
			lines.append(line.strip_edges().trim_prefix("self-play: "))
	return " | ".join(lines.slice(-3))


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
