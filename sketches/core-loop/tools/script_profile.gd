extends SceneTree
# Headless per-function frame profiler. It stands in for the editor's debugger: it listens
# on PROF_PORT, turns on the engine's "servers" profiler for the game that connects, and
# writes every message to PROF_OUT as JSON lines. tools/script_profile_report.py names the
# slowest frames and the script functions inside them.
#   PROF_PORT=6011 PROF_OUT=<abs>.jsonl godot --headless --script res://tools/script_profile.gd &
#   godot --headless --fixed-fps 90 --remote-debug tcp://127.0.0.1:6011 --path . --script res://tools/bot_run.gd -- <args>
var server := TCPServer.new()
var peer: StreamPeerTCP
var out: FileAccess
var buf := PackedByteArray()


func _initialize() -> void:
	server.listen(int(OS.get_environment("PROF_PORT")), "127.0.0.1")
	out = FileAccess.open(OS.get_environment("PROF_OUT"), FileAccess.WRITE)


func _send(message: String, data: Array) -> void:
	var bytes := var_to_bytes([message, 1, data])
	peer.put_32(bytes.size())
	peer.put_data(bytes)


func _process(_delta: float) -> bool:
	if peer == null:
		if server.is_connection_available():
			peer = server.take_connection()
			_send("profiler:servers", [true, [1024]])
		return false
	peer.poll()
	if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		out.close()
		return true
	var n := peer.get_available_bytes()
	if n > 0:
		buf.append_array(peer.get_data(n)[1])
	while buf.size() >= 4 and buf.size() >= 4 + buf.decode_u32(0):
		var size := buf.decode_u32(0)
		_handle(bytes_to_var(buf.slice(4, 4 + size)))
		buf = buf.slice(4 + size)
	return false


func _handle(message) -> void:
	if typeof(message) != TYPE_ARRAY or message.size() < 3:
		return
	var kind: String = message[0]
	# A script error breaks into the debugger; carry on as a plain run would.
	if kind == "debug_enter":
		_send("continue", [])
	elif kind == "servers:function_signature" or kind == "servers:profile_frame":
		out.store_line(JSON.stringify({"kind": kind, "data": message[2]}))
