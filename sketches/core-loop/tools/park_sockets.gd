extends SceneTree

# SQ15's paired seeded laboratory. These layouts are separate from the six authored parks.
# godot --headless --path sketches/core-loop --script res://tools/park_sockets.gd -- --sockets=1000
# --sockets defaults to 1,000 seeds; --sockets-out=<path> writes both arms' per-stage metrics.
# Gates: 95% success, 3..8 pockets, off-route guarantees and fillers, <10% and <=half-fixed
# re-rolls, and <=3.0 complete full-visit ratio.

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
