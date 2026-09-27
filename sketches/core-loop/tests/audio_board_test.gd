extends SceneTree

const Board := preload("res://tools/audio_board.gd")

# The audio board (tools/audio_board.gd) writes every demo: each file exists, reads back
# as 16-bit stereo at the band's rate, lasts 4 to 40 s, carries real audio and never
# clips, and was matched to -14 LUFS. Buffers and files, not ears: how the board sounds
# is Andrew's to judge.

# One folder per process: every worktree shares this project's user:// folder, so two
# smoke runs at once would otherwise overwrite and read each other's demos.
const OUT := "user://audio_board_test"

var _failures := 0


func _initialize() -> void:
	var out := ProjectSettings.globalize_path(OUT).path_join(str(OS.get_process_id()))
	var report := Board.write_all(out)
	_check("every demo", report.size() == Board.DEMOS.size(), "%d of %d demos written" % [report.size(), Board.DEMOS.size()])
	for row in report:
		var name: String = row[0]
		var stats: Dictionary = row[1]
		var wav := AudioStreamWAV.load_from_file(out.path_join(name))
		if int(row[2]) != OK or wav == null:
			_check(name, false, "save_to_wav returned %d" % row[2])
			continue
		var top := 0
		var sum := 0.0
		var data := wav.data
		var count := data.size() / 2
		for i in range(0, data.size() - 1, 2):
			var v := data.decode_s16(i)
			top = maxi(top, absi(v))
			sum += float(v) * v
		var seconds := count / 2.0 / wav.mix_rate
		var rms_db := linear_to_db(sqrt(sum / maxi(count, 1)) / 32767.0)
		var peak_db := linear_to_db(top / 32767.0)
		var ok: bool = wav.stereo and wav.format == AudioStreamWAV.FORMAT_16_BITS and wav.mix_rate == 44100 \
			and seconds >= 4.0 and seconds <= 40.0 and rms_db > -40.0 and peak_db <= -0.9 and absf(float(stats["lufs"]) + 14.0) <= 1.0
		_check(name, ok, "%.1f s, RMS %.1f dBFS, peak %.2f dBFS, %.1f LUFS" % [seconds, rms_db, peak_db, stats["lufs"]])
	for row in report:
		DirAccess.remove_absolute(out.path_join(row[0]))
	print("audio_board_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


func _check(name: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("%s %s: %s" % ["PASS" if ok else "FAIL", name, detail])
