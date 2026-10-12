extends SceneTree

const Replay := preload("res://tools/bot_replay.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 3:
		printerr("bot_replay_check: usage: -- <baseline> <candidate> <seed>")
		quit(2)
		return
	var result := Replay.compare(args[0], args[1], int(args[2]))
	print(JSON.stringify(result))
	print("bot_replay_check: %s" % ("PASS" if result.pass else "FAIL"))
	quit(0 if result.pass else 1)
