# smoke: bots timeout=900s (one real-tick played game child from the title through stage 1 into stage 2; about 250 s on the loaded cloud box, 2026-10-18)
extends SceneTree

const T := preload("res://tests/support/t.gd")

# --self-play (src/game.gd, tools/self_play.gd): the launched main scene is played by a bot with
# real ticks (a played game, not test_mode or SimClock) and quits by code: 0 the goal was reached,
# 2 a bad flag (a pack without tools/ also quits 2 in game.gd, which this project cannot stage
# because it holds tools/), 3 a stall. Evidence limit: one seed, skipper, headless; a code 1 or 3
# run is not reproduced here.

func _initialize() -> void:
	var t := T.new("self_play_launch_test")
	var bad_policy := _launch(["--self-play-policy=nope"])
	t.eq("an unknown policy quits 2", bad_policy["code"], 2)
	var bad_until := _launch(["--self-play-until=soon"])
	t.eq("an unreadable --self-play-until quits 2", bad_until["code"], 2)
	var run := _launch(["--self-play-hold=1"])
	t.eq("a skipper reaches stage 2 and quits 0", run["code"], 0)
	var text: String = run["text"]
	t.check("stage 1 is announced", text.contains("self-play: stage 1 entered at "))
	t.check("stage 1's exit is announced", text.contains("self-play: stage 1 exit taken at "))
	t.check("stage 2 is announced with seconds since launch", text.contains("self-play: stage 2 entered at "))
	t.check("the run finishes with done", text.contains("self-play: done at "))
	quit(t.verdict())


func _launch(extra: Array) -> Dictionary:
	var args := ["--headless", "--fixed-fps", "90", "--path", ProjectSettings.globalize_path("res://"), "--", "--self-play"]
	args.append_array(extra)
	var output := []
	var code := OS.execute(OS.get_executable_path(), args, output, true)
	return {"code": code, "text": "\n".join(output)}
