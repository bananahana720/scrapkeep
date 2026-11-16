# smoke: bots timeout=1800s (two real-tick played game children from the title to the win at Brindle)
extends SceneTree

const T := preload("res://tests/support/t.gd")
const Profile := preload("res://src/core/profile.gd")

# The launch Andrew plays, --profile=sitting-earned (six loops on: heat, overtime, called shot, marked
# hull, Moss's scale, carry a core), played by the self-play bot with real ticks to the win at Brindle
# (final world 1). The run log's "loops" block (src/core/loop_tally.gd, the redline's counts for heat)
# must show each loop fired at least once, and the profile the run saved in its own scratch folder must
# hold what it earned and load again. The bot saves to user://self-play-<name> (src/game.gd takes that
# branch before the sitting-earned one), so the real user://sitting-earned and profile are never touched.
# The bot's choices for the five loops the skipper never makes are tools/bot_loops.gd's hands. The
# controls are the same run twice more, each with one loop off: heat by its launch flag, the called
# shot by switching its hand off. Each must read that loop as not fired and every other loop as the
# full run read it, so a hand that does nothing, or a count that is always on, cannot pass.
# Evidence limit: one seed, skipper policy, headless; a loop the bot never plays reads as not fired.

const LOOPS := ["heat", "overtime", "called_shot", "marked_hull", "moss_scale", "carry_core"]
# Loops the bot has no hand for yet, so the run cannot fire them. Carry a core needs two things the skipper
# never does before the bay: a finished activity (a companion piece, activities.gd _pay_piece) and a bonus
# core (an overtime pot cashed after three rings, a vault, an ambush altar). Until a hand does both, the
# run's receipt (scripts/gate/sitting-played-receipt.mjs) reads fail and names it. A loop here is not
# asserted as fired, and the test fails the day it does fire, so the list cannot go stale.
const OPEN := ["carry_core"]
# The seed the run is played on: one where a keeper's trade stands near the stage's start, which the
# marked hull needs (trade_pockets.gd draws one by seed and stage).
const SEED := 5
# One control per row: the loop it shows as not fired, and the flag that switches it off.
const CONTROLS := [
	{"off": "heat", "flag": "--heat=off"},
	{"off": "called_shot", "flag": "--self-play-hand-off=called_shot"},
]


# The runs are independent children, started together so the test costs one run's wall time.
var _t := T.new("sitting_played_run_test")
var _runs := {}
var _done := false


func _initialize() -> void:
	var pid := OS.get_process_id()
	_runs["full"] = _start("sitrun-%d" % pid, [])
	for control in CONTROLS:
		_runs[control["off"]] = _start("sitrun-%s-%d" % [control["off"], pid], [control["flag"]])


func _process(_delta: float) -> bool:
	if _done:
		return false
	var waiting := false
	for key in _runs:
		var child: Dictionary = _runs[key]
		if not child.has("ended"):
			if FileAccess.get_file_as_string(child["out"] + ".code") == "":
				waiting = true
			else:
				child["ended"] = true
	if waiting:
		return false
	_done = true
	var full := _finish(_runs["full"])
	var controls := {}
	for control in CONTROLS:
		controls[control["off"]] = _finish(_runs[control["off"]])
	_judge(_t, full, controls)
	quit(_t.verdict())
	return true


func _judge(t, full: Dictionary, controls: Dictionary) -> void:
	t.eq("the sitting run reaches the win and quits 0", full["code"], 0)
	t.check("the bot says the run was won", full["text"].contains("self-play: run won at "), _tail(full["text"]))
	var last: Dictionary = full["last"]
	t.check("the run log has a closing line", not last.is_empty(), str(full["lines"]) + " lines")
	t.eq("the run was won", last.get("outcome", ""), "won")
	var fired := _fired(last)
	var count := 0
	var fired_count := 0
	for loop in LOOPS:
		count += 1
		var detail := "count %s" % str(_counts(last).get(loop, 0))
		if loop in OPEN:
			t.check("%s has no hand yet and did not fire (when it fires, take it off OPEN)" % loop, not fired.get(loop, false), detail)
		else:
			t.check("%s fired in the played run" % loop, fired.get(loop, false), detail)
			fired_count += 1 if fired.get(loop, false) else 0
	t.eq("every one of the six loops was checked", count, 6)
	t.eq("every loop that has a hand fired", fired_count, LOOPS.size() - OPEN.size())
	_check_profile(t, full)
	print("RECEIPT %s" % JSON.stringify({"seconds": snappedf(full["seconds"], 1.0), "loops": _counts(last), "fired": fired}))
	for control in CONTROLS:
		var off: String = control["off"]
		var ran: Dictionary = controls[off]
		var cfired := _fired(ran["last"])
		t.check("the %s control wrote a closing line" % off, not ran["last"].is_empty(), _tail(ran["text"]))
		t.check("the %s control reads it as not fired" % off, not cfired.get(off, true) and cfired.has(off), str(_counts(ran["last"])))
		var others := 0
		for loop in LOOPS:
			if loop != off and cfired.get(loop, false) == fired.get(loop, false):
				others += 1
		t.eq("the %s control changes that loop only" % off, others, 5)
		print("CONTROL %s" % JSON.stringify({"off": off, "seconds": snappedf(ran["seconds"], 1.0), "fired": cfired}))


func _counts(line: Dictionary) -> Dictionary:
	return line.get("loops", {})


# Loop name to whether the run log shows it fired: a count of one or more.
func _fired(line: Dictionary) -> Dictionary:
	var counts := _counts(line)
	var out := {}
	for loop in LOOPS:
		out[loop] = int(counts.get(loop, 0)) > 0
	return out


# What the run earned stays: the profile file is in the bot's own folder, is a real save, and a
# fresh load reads back the same rows. Routing Brindle is what opens Tarn and earns brindle_routed,
# so those two are the named proof; the rest is compared as a whole.
func _check_profile(t, played: Dictionary) -> void:
	var path: String = played["folder"].path_join("profile.json")
	t.check("the run saved a profile in its own folder", FileAccess.file_exists(path), path.get_file())
	var doc = JSON.parse_string(FileAccess.get_file_as_string(path))
	t.check("the saved profile is a document", typeof(doc) == TYPE_DICTIONARY, path.get_file())
	if typeof(doc) != TYPE_DICTIONARY:
		return
	var profile := Profile.new(path)
	t.check("the saved profile loads", profile.load_profile(), profile.last_error)
	t.check("the profile kept the Brindle win it earned", doc["achievements"].has("brindle_routed") and profile.earned("brindle_routed"), str(doc["achievements"].keys().size()) + " earned")
	t.check("and the pilot that win opens", doc["pilots"].has("tarn") and profile.has_pilot("tarn"), str(doc["pilots"]))
	var kept := 0
	for id in doc["achievements"].keys():
		kept += 1 if profile.earned(id) else 0
	t.check("a fresh load holds every earned row", kept == doc["achievements"].size() and kept > 0, "%d of %d" % [kept, doc["achievements"].size()])
	var paints := 0
	for id in doc["cosmetics"]:
		paints += 1 if profile.has_cosmetic(id) else 0
	t.check("and every cosmetic it paid", paints == doc["cosmetics"].size() and paints > 0, "%d of %d" % [paints, doc["cosmetics"].size()])
	# The child's own user folder: the bot's folder is the only save place it used, so neither the
	# sitting-earned folder nor a profile at the root (the player's) exists there.
	var root: String = played["folder"].get_base_dir()
	t.check("the run never used the sitting-earned folder or a profile at the root", not DirAccess.dir_exists_absolute(root.path_join("sitting-earned")) and not FileAccess.file_exists(root.path_join("profile.json")), str(DirAccess.get_directories_at(root)))


func _tail(text: String) -> String:
	var lines := text.strip_edges().split("\n")
	return " | ".join(lines.slice(maxi(0, lines.size() - 3)))


# One played child, started and left running: a fresh XDG tree, so its own app_userdata holds only
# this run. sh keeps its output and, last, its exit code, so the test can poll without blocking.
func _start(save: String, extra: Array) -> Dictionary:
	var base := ProjectSettings.globalize_path("user://").path_join("sitrun-%d-%s" % [OS.get_process_id(), save])
	for dir in ["data", "config", "cache"]:
		DirAccess.make_dir_recursive_absolute(base.path_join(dir))
	var out := base.path_join("out.txt")
	var args := ["-c", "out=$1; shift; \"$@\" > \"$out\" 2>&1; echo $? > \"$out.code\"", "sh", out, "env",
		"XDG_DATA_HOME=" + base.path_join("data"), "XDG_CONFIG_HOME=" + base.path_join("config"),
		"XDG_CACHE_HOME=" + base.path_join("cache"), OS.get_executable_path(),
		"--headless", "--fixed-fps", "90", "--path", ProjectSettings.globalize_path("res://"), "--",
		"--self-play", "--self-play-until=win", "--self-play-hold=1", "--self-play-save=" + save, "--self-play-seed=%d" % SEED, "--profile=sitting-earned"]
	args.append_array(extra)
	var pid := OS.create_process("sh", args)
	return {"base": base, "out": out, "save": save, "pid": pid}


func _finish(child: Dictionary) -> Dictionary:
	var code := int(FileAccess.get_file_as_string(child["out"] + ".code").strip_edges())
	var folder := ""
	var apps: String = child["base"].path_join("data/godot/app_userdata")
	for dir in DirAccess.get_directories_at(apps):
		folder = apps.path_join(dir).path_join("self-play-" + child["save"])
	var last := {}
	var lines := 0
	var log_path := folder.path_join("runs.ndjson")
	if folder != "" and FileAccess.file_exists(log_path):
		for line in FileAccess.get_file_as_string(log_path).split("\n"):
			if line.strip_edges() != "":
				lines += 1
				last = JSON.parse_string(line)
	# Seconds since the child's launch, as its own win line says them (the lint bans wall-clock reads).
	var text: String = FileAccess.get_file_as_string(child["out"])
	var won := RegEx.create_from_string("self-play: run won at ([0-9.]+) s").search(text)
	var seconds := float(won.get_string(1)) if won != null else 0.0
	return {"code": code, "text": text, "folder": folder, "last": last, "lines": lines, "seconds": seconds}
