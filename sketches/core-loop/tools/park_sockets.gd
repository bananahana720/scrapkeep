extends SceneTree


const Sockets := preload("res://src/world/park/sockets.gd")


func _initialize() -> void:
	var map_id := ""
	var socket_seeds := 0
	var socket_arm := false
	var socket_out := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--map="):
			map_id = arg.trim_prefix("--map=")
		elif arg == "--sockets" or arg.begins_with("--sockets="):
			socket_arm = true
			socket_seeds = Sockets.SEEDS if arg == "--sockets" else int(arg.trim_prefix("--sockets="))
		elif arg.begins_with("--sockets-out="):
			socket_out = arg.trim_prefix("--sockets-out=")
	if not socket_arm or socket_seeds <= 0 or not map_id.is_empty():
		printerr("park_graph: --sockets[=<positive seeds>] measures paired lab templates; omit --map")
		quit(2)
		return
	var started := Time.get_ticks_usec()
	var comparison := Sockets.sweep(socket_seeds)
	print(Sockets.report(comparison))
	print("sockets wall time: %.3f s" % ((Time.get_ticks_usec() - started) / 1000000.0))
	if not socket_out.is_empty():
		var file := FileAccess.open(socket_out, FileAccess.WRITE)
		if file == null:
			printerr("park_graph: cannot write socket metrics to %s" % socket_out)
			quit(1)
			return
		file.store_string(JSON.stringify(comparison, "\t", true) + "\n")
	quit(0 if comparison["ok"] else 1)
