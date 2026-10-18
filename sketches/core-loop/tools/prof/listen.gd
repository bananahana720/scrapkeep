extends SceneTree
# Minimal remote-debugger listener: enables the servers profiler and dumps decoded messages.
var server := TCPServer.new()
var peer: StreamPeerTCP
var buf := PackedByteArray()
var out: FileAccess
var enabled := false
var start := 0

func _initialize() -> void:
	server.listen(6007, "127.0.0.1")
	out = FileAccess.open(OS.get_environment("PROF_OUT"), FileAccess.WRITE)
	start = Time.get_ticks_msec()

func _send(msg: Array) -> void:
	var b := var_to_bytes(msg)
	var l := PackedByteArray(); l.resize(4); l.encode_u32(0, b.size())
	peer.put_data(l); peer.put_data(b)

func _process(_d: float) -> bool:
	if peer == null:
		if server.is_connection_available():
			peer = server.take_connection()
			print("connected")
		elif Time.get_ticks_msec() - start > 120000:
			return true
		return false
	peer.poll()
	if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		out.close(); return true
	var n := peer.get_available_bytes()
	if n > 0:
		buf.append_array(peer.get_data(n)[1])
	while buf.size() >= 4:
		var l := buf.decode_u32(0)
		if buf.size() < 4 + l: break
		var v = bytes_to_var(buf.slice(4, 4 + l))
		buf = buf.slice(4 + l)
		var cmd: String = v[0]
		if cmd.begins_with("servers:") or cmd.begins_with("scripts") or cmd.begins_with("profiler"):
			out.store_line(var_to_str(v).replace("\n", " "))
		elif cmd == "output":
			for s in v[2][0]: if "PROFILE" in str(s): out.store_line(str(s))
			if not enabled:
				pass
	var t := OS.get_environment("PROF_AT")
	if not enabled and peer != null:
		enabled = true
		_send(["profiler:servers", 1, [true, [1024]]])
		_send(["profiler:scripts", 1, [true, []]])
		print("enabled")
	return false
