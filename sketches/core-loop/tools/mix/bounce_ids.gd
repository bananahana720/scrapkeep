extends SceneTree
# Bounces the stream of every sound id a recorded run played (the cue_rows of a run json),
# as the game plays it: after the bank's normalise, before any trim. Raw float32 mono with
# a manifest of rate and length, for mixsim.py.
#   godot --headless --audio-driver Dummy --script res://tools/mix/bounce_ids.gd -- <run.json> <out folder>
const Bank := preload("res://src/presentation/sfx_bank.gd")
const Harmony := preload("res://src/presentation/harmony.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var run: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	DirAccess.make_dir_recursive_absolute(args[1])
	var ids := {}
	for row in run["cue_rows"]:
		ids[String(row[2])] = true
	var rows := []
	var n := 0
	for id in ids:
		var stream: AudioStreamWAV = Bank.stream(id) if Bank.has_recipe(id) or Bank.file_backed(id) else null
		if stream == null or stream.data.is_empty():
			rows.append("%s\tNONE\t0\t0" % id)
			continue
		var stereo := stream.stereo
		var step := 4 if stereo else 2
		var frames := stream.data.size() / step
		var buf := PackedFloat32Array()
		buf.resize(frames)
		for i in frames:
			buf[i] = (stream.data.decode_s16(i * step) + (stream.data.decode_s16(i * step + 2) if stereo else stream.data.decode_s16(i * step))) / 65536.0
		var name := "s%03d" % n
		n += 1
		var f := FileAccess.open("%s/%s.f32" % [args[1], name], FileAccess.WRITE)
		f.store_buffer(buf.to_byte_array())
		f.close()
		rows.append("%s\t%s\t%d\t%d\t%s" % [id, name, stream.mix_rate, frames, Bank.trim_db(id)])
	var m := FileAccess.open(args[1] + "/ids.tsv", FileAccess.WRITE)
	m.store_string("\n".join(rows) + "\n")
	m.close()
	print("BOUNCED ", n, " of ", ids.size())
	quit(0)
