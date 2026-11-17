# smoke: bots timeout=900s (thirteen real-tick played game children: ten boot-only quits, two planted stalls, one planted-limit run, one from the title through stage 1 into stage 2; about 250 s for the last on the loaded cloud box, 2026-10-18)
extends SceneTree

const T := preload("res://tests/support/t.gd")
const ChildRuns := preload("res://tests/trees/child_runs.gd")

# --self-play (src/game.gd, tools/self_play.gd): the launched main scene is played by a bot with
# real ticks (a played game, not test_mode or SimClock) and quits by code: 0 the goal was reached,
# 1 the run ended first or there was nothing to continue, 2 a bad flag or a missing script
# (--self-play-script= stands in for a pack without tools/; a film asked for with no display; eyes
# without keys),
# 3 a stall (planted: --self-play-plant-stall for the exit detector, --self-play-plant-after-exit
# for an exit that opens no next stage, --self-play-plant-limit for the driver's limit). Evidence limit: one seed, skipper, headless; the gates trigger of the detector
# is not exercised, only its timing, line and exit code.

func _initialize() -> void:
	var t := T.new("self_play_launch_test")
	var bad_policy := _launch(["--self-play-policy=nope"])
	t.eq("an unknown policy quits 2", bad_policy["code"], 2)
	var bad_until := _launch(["--self-play-until=soon"])
	t.eq("an unreadable --self-play-until quits 2", bad_until["code"], 2)
	var missing := _launch(["--self-play-script=res://tools/not_there.gd"])
	t.eq("a pack without the self-play script quits 2", missing["code"], 2)
	var bad_save := _launch(["--self-play-save=../elsewhere"])
	t.eq("a save folder name that is not one plain name quits 2", bad_save["code"], 2)
	var keys_from := _launch(["--self-play-keys=1", "--self-play-from=2"])
	t.eq("keys with a later starting stage quit 2", keys_from["code"], 2)
	var eyes_alone := _launch(["--self-play-eyes=1"])
	t.eq("eyes without keys quit 2", eyes_alone["code"], 2)
	var blind_film := _launch(["--self-play-film=" + ProjectSettings.globalize_path("user://").path_join("sp-film-%d" % OS.get_process_id())])
	t.eq("a film with no picture to take (--headless) quits 2", blind_film["code"], 2)
	t.check("and says why", blind_film["text"].contains("eye-film: no picture under --headless"))
	var bad_hide := _launch(["--self-play-plant-hide=sky"])
	t.eq("a plant that hides something unknown quits 2", bad_hide["code"], 2)
	var no_save := _launch(["--self-play-continue=1"])
	t.eq("told to continue with nothing saved, the bot quits 1", no_save["code"], 1)
	t.check("and starts no run", no_save["text"].contains("self-play: no Continue offered at ") and _line(no_save["text"], "self-play: stage ") == "", _line(no_save["text"], "self-play: no Continue offered at "))
	var ended := _launch(["--self-play-plant-end"])
	t.eq("a run that ends before the goal quits 1", ended["code"], 1)
	t.check("the ended line names the outcome", ended["text"].contains("self-play: run ended 'planted_end'"))
	var planted := _launch(["--self-play-plant-stall", "--self-play-stall=2"])
	t.eq("a planted stall quits 3", planted["code"], 3)
	var stall_line := _line(planted["text"], "self-play: stalled at stage ")
	t.check("the stall line names stage 1, the exit and a position", stall_line.contains("stage 1 exit at ") and stall_line.contains(" pos "))
	var after := _launch(["--self-play-plant-after-exit", "--self-play-stall=2"])
	t.eq("an exit taken that opens no next stage quits 3", after["code"], 3)
	t.check("that stall line names stage 1, after the exit, and a position", _line(after["text"], "self-play: stalled at stage ").contains("stage 1 after-exit at ") and _line(after["text"], "self-play: stalled at stage ").contains(" pos "),
		_line(after["text"], "self-play: stalled at stage "))
	var limited := _launch(["--self-play-plant-limit=4"])
	t.eq("the driver's own stage limit quits 3", limited["code"], 3)
	t.check("the driver-limit stall line has a position", _line(limited["text"], "self-play: stalled at stage 1 ").contains(" pos "))
	var run := _launch(["--self-play-hold=1"])
	t.eq("a skipper reaches stage 2 and quits 0", run["code"], 0)
	var text: String = run["text"]
	t.check("stage 1 is announced", text.contains("self-play: stage 1 entered at "))
	t.check("stage 1's exit is announced", text.contains("self-play: stage 1 exit taken at "))
	t.check("stage 2 is announced with seconds since launch", text.contains("self-play: stage 2 entered at "))
	t.check("the run finishes with done", text.contains("self-play: done at "))
	# Saves: the child's own profile holds a self-play-<pid> folder, and nothing of the run sits at
	# the profile's root (run.json, profile.json), where a player's saves live.
	var userdata := _find_userdata(run["data"])
	t.check("the child has an app_userdata folder", userdata != "")
	var root_files := DirAccess.get_files_at(userdata)
	t.check("no run or profile save at the profile root", not root_files.has("run.json") and not root_files.has("profile.json"))
	var own := false
	for dir in DirAccess.get_directories_at(userdata):
		own = own or (dir.begins_with("self-play-") and DirAccess.get_files_at(userdata.path_join(dir)).has("run.json"))
	t.check("the run saved into its own self-play folder", own)
	quit(t.verdict())


func _line(text: String, prefix: String) -> String:
	for line in text.split("\n"):
		if line.begins_with(prefix):
			return line
	return ""


func _find_userdata(data: String) -> String:
	var apps := ChildRuns.userdata_root(data)
	for dir in DirAccess.get_directories_at(apps):
		return apps.path_join(dir)
	return ""


var _serial := 0


# Each child gets its own XDG data, config and cache, as sketch-export.mjs does for its proofs.
func _launch(extra: Array) -> Dictionary:
	_serial += 1
	var base := ProjectSettings.globalize_path("user://").path_join("sp-%d-%d" % [OS.get_process_id(), _serial])
	for dir in ["data", "config", "cache"]:
		DirAccess.make_dir_recursive_absolute(base.path_join(dir))
	var args: Array = ChildRuns.home_env(base) + [OS.get_executable_path(),
		"--headless", "--fixed-fps", "90", "--path", ProjectSettings.globalize_path("res://"), "--", "--self-play"]
	args.append_array(extra)
	var output := []
	var code := OS.execute("env", args, output, true)
	return {"code": code, "text": "\n".join(output), "data": base.path_join("data")}
