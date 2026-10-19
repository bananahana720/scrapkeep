extends SceneTree

const Kinds := preload("res://src/core/ambient_kinds.gd")
const T := preload("res://tests/support/t.gd")

# Ambient life sounds (ambient_kinds.gd `sound`, rendered by tools/ace/ambient_sfx.py): every kind
# in the record has both wavs, as mono 44.1 kHz AudioStreamWAV, no loop, peaking at or under
# -6 dBFS (5 dB under the combat foley), calls 0.3 to 1.2 s and reacts 0.2 to 0.8 s. The wav checks
# run for every kind whether or not its GLB exists yet; the GLB count is reported alongside.

const LIMITS := {"call": [0.3, 1.2], "react": [0.2, 0.8]}
const RATE := 44100
const PEAK_DB := -6.0

var _t := T.new("ambient_sounds_test")


func _initialize() -> void:
	var with_glb := 0
	var wavs := 0
	for id in Kinds.KINDS:
		var row: Dictionary = Kinds.row(id)
		if ResourceLoader.exists(row.model):
			with_glb += 1
		for slot in ["call", "react"]:
			wavs += 1
			_check_wav("%s %s" % [id, slot], row.sound[slot], LIMITS[slot])
	print("ambient_sounds_test: %d kinds, %d with a GLB, %d wavs checked" % [Kinds.KINDS.size(), with_glb, wavs])
	quit(_t.verdict())


func _check_wav(label: String, path: String, limits: Array) -> void:
	var stream = load(path) if ResourceLoader.exists(path) else null
	if not _t.check(label + " loads as AudioStreamWAV", stream is AudioStreamWAV, path):
		return
	var wav: AudioStreamWAV = stream
	var seconds := wav.get_length()
	_t.check(label + " length", seconds >= limits[0] and seconds <= limits[1], "%.2f s, want %s to %s" % [seconds, limits[0], limits[1]])
	_t.check(label + " mono 44.1 kHz 16-bit", not wav.stereo and wav.mix_rate == RATE and wav.format == AudioStreamWAV.FORMAT_16_BITS, "stereo %s rate %d format %d" % [wav.stereo, wav.mix_rate, wav.format])
	_t.check(label + " no loop", wav.loop_mode == AudioStreamWAV.LOOP_DISABLED)
	var data := wav.data
	var peak := 0
	for i in range(0, data.size() - 1, 2):
		var s := data[i] | (data[i + 1] << 8)
		if s >= 32768:
			s -= 65536
		peak = maxi(peak, absi(s))
	var db := 20.0 * log(maxf(peak, 1) / 32768.0) / log(10.0)
	_t.check(label + " peak", db <= PEAK_DB, "%.2f dBFS, want <= %.1f" % [db, PEAK_DB])
