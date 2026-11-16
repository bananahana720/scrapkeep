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
# The control is the same run with one loop off: that loop must read as not fired.
# Evidence limit: one seed, skipper policy, headless; a loop the bot never plays reads as not fired.

const LOOPS := ["heat", "overtime", "called_shot", "marked_hull", "moss_scale", "carry_core"]
# The flag that switches each loop off; a flag on the command line wins over the profile (tuning.gd).
const OFF_FLAG := {"heat": "--heat=off", "overtime": "--overtime=off", "called_shot": "--called-shot=off",
	"marked_hull": "--marked-hull=off", "moss_scale": "--moss-scale=off", "carry_core": "--carry-core=off"}
const CONTROL := "heat"


# The two runs are independent children, started together so the test costs one run's wall time.
var _t := T.new("sitting_played_run_test")
var _runs := {}
var _done := false


func _initialize() -> void:
	var pid := OS.get_process_id()
	_runs["full"] = _start("sitrun-%d" % pid, [])
	_runs["control"] = _start("sitrun-ctl-%d" % pid, [OFF_FLAG[CONTROL]])


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
	var control := _finish(_runs["control"])
	_judge(_t, full, control)
	quit(_t.verdict())
	return true


func _judge(t, full: Dictionary, control: Dictionary) -> void:
	t.eq("the sitting run reaches the win and quits 0", full["code"], 0)
	t.check("the bot says the run was won", full["text"].contains("self-play: run won at "), _tail(full["text"]))
	var last: Dictionary = full["last"]
	t.check("the run log has a closing line", not last.is_empty(), str(full["lines"]) + " lines")
	t.eq("the run was won", last.get("outcome", ""), "won")
	var fired := _fired(last)
	var count := 0
	for loop in LOOPS:
		count += 1
		t.check("%s fired in the played run" % loop, fired.get(loop, false), "count %s" % str(_counts(last).get(loop, 0)))
	t.eq("every one of the six loops was checked", count, 6)
	t.eq("six of six loops fired", fired.values().count(true), 6)
	_check_profile(t, full)
	print("RECEIPT %s" % JSON.stringify({"seconds": snappedf(full["seconds"], 1.0), "loops": _counts(last), "fired": fired}))
	var cfired := _fired(control["last"])
	t.check("the control run wrote a closing line", not control["last"].is_empty(), _tail(control["text"]))
	t.check("the control reads %s as not fired" % CONTROL, not cfired.get(CONTROL, true) and cfired.has(CONTROL), str(_counts(control["last"])))
	var others := 0
	for loop in LOOPS:
		if loop != CONTROL and cfired.get(loop, false) == fired.get(loop, false):
			others += 1
	t.eq("the control changes that loop only", others, 5)
	print("CONTROL %s" % JSON.stringify({"off": CONTROL, "seconds": snappedf(control["seconds"], 1.0), "fired": cfired}))


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
		"--self-play", "--self-play-until=win", "--self-play-hold=1", "--self-play-save=" + save, "--profile=sitting-earned"]
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
