# smoke: bots timeout=900s (five real-tick played game children: three boot-only quits, one planted-limit run, one from the title through stage 1 into stage 2; about 250 s for the last on the loaded cloud box, 2026-10-18)
extends SceneTree

const T := preload("res://tests/support/t.gd")

# --self-play (src/game.gd, tools/self_play.gd): the launched main scene is played by a bot with
# real ticks (a played game, not test_mode or SimClock) and quits by code: 0 the goal was reached,
# 2 a bad flag or a missing script (--self-play-script= stands in for a pack without tools/),
# 3 a stall (planted: --self-play-plant-stall for the detector, --self-play-plant-limit for the
# driver's limit). Evidence limit: one seed, skipper, headless; the gates trigger of the detector
# is not exercised, only its timing, line and exit code.

func _initialize() -> void:
	var t := T.new("self_play_launch_test")
	var bad_policy := _launch(["--self-play-policy=nope"])
	t.eq("an unknown policy quits 2", bad_policy["code"], 2)
	var bad_until := _launch(["--self-play-until=soon"])
	t.eq("an unreadable --self-play-until quits 2", bad_until["code"], 2)
	var missing := _launch(["--self-play-script=res://tools/not_there.gd"])
	t.eq("a pack without the self-play script quits 2", missing["code"], 2)
	var planted := _launch(["--self-play-plant-stall", "--self-play-stall=2"])
	t.eq("a planted stall quits 3", planted["code"], 3)
	var stall_line := _line(planted["text"], "self-play: stalled at stage ")
	t.check("the stall line names stage 1, the exit and a position", stall_line.contains("stage 1 exit at ") and stall_line.contains(" pos "))
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
	quit(t.verdict())


func _line(text: String, prefix: String) -> String:
	for line in text.split("\n"):
		if line.begins_with(prefix):
			return line
	return ""


func _launch(extra: Array) -> Dictionary:
	var args := ["--headless", "--fixed-fps", "90", "--path", ProjectSettings.globalize_path("res://"), "--", "--self-play"]
	args.append_array(extra)
	var output := []
	var code := OS.execute(OS.get_executable_path(), args, output, true)
	return {"code": code, "text": "\n".join(output)}
