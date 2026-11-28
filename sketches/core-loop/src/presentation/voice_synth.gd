extends RefCounted

const Harmony := preload("res://src/presentation/harmony.gd")
const Synth := preload("res://src/presentation/synth.gd")

const RATE := Harmony.RATE
const BABBLE_TRIM_DB := -8.0
const BABBLE_ROOTS := [50, 52, 53, 55, 57, 48]
const BABBLE_LEVEL := 0
const BABBLE_RELENT := -1
const VOWELS := ["a", "e", "i", "o", "u"]
const SAY := "say|"
const MOSS := "moss"
const PURE := "pure"
const CALLERS := {
	"moss": {"bench": true, "mouth": 1.0, "drop": 12, "db": 3.5},
	"sable": {"motif": "sable", "voice": "bell", "lift": 12, "pace": 0.8, "bend": 2.0, "mouth": 1.4, "drop": -12, "db": 3.5},
	"rivet": {"motif": "rivet", "lift": 12, "pace": 0.7, "bend": 0.5, "run": true, "mouth": 1.3, "drop": -12, "db": 1.0},
	"kest": {"motif": "kest", "lift": 12, "pace": 1.15, "bend": -2.0, "stop": 1.6, "mouth": 1.15, "db": 4.5},
	"tarn": {"motif": "tarn", "voice": "fbass", "lift": 12, "pace": 1.3, "bend": 0.7, "mouth": 1.2, "db": 2.0},
	"tally": {"motif": "tally", "lift": 12, "bend": 0.5, "loose": 0.0, "mouth": 1.35, "drop": -12, "db": 4.0},
	"cannon": {"motif": "cannon", "lift": 12, "bend": 1.5},
	"pump_crew": {"root": 62, "voice": "mallet", "bend": 1.0, "second": -3, "mouth": 1.2, "db": 7.0},
	"flume_crew": {"root": 64, "voice": "mallet", "bend": 1.0, "second": -3, "mouth": 1.25, "db": 5.5},
	"signal_crew": {"root": 67, "voice": "mallet", "bend": 1.0, "second": -3, "mouth": 1.3, "db": 5.0},
	"brindle": {"motif": "fleet", "lift": 12, "pace": 1.7, "lean": true, "mouth": 0.95, "db": 3.5},
	"mind": {"root": 74, "voice": PURE, "grid": true, "db": -2.5},
}
const CHIRP_NOTE_S := 0.12
const CHIRP_GAIN := 0.6
const CALL_TALK_S := 0.36
const CALL_OVERLAP_S := 0.06
const CALL_LOOSE := 0.15
const MOUTH_VOWELS := {"a": [800.0, 1200.0], "e": [500.0, 1900.0], "i": [320.0, 2500.0], "o": [500.0, 900.0], "u": [350.0, 750.0]}
const MOUTH_SHUT := [420.0, 1400.0]
const MOUTH_HUM := [250.0, 1100.0]
const MOUTH_HUMMED := ["m", "n"]
const MOUTH_BREATHED := ["s", "f", "h", "z", "c", "x", "t", "k", "p"]
const MOUTH_RING := 1.25
const MOUTH_PEAK := 0.8
const BENCH_SIGH := 0.9
const BENCH_SIGH_LEVEL := 0.75
const SYNTH_ONLY_SPEAKERS := ["cannon"]

static var unknown_callers := {}
static var _voice_tts := false
static var _voice_clips := {}
static var _samples := {}
static var _lock := Mutex.new()
static var _cache_lock := Mutex.new()


static func reset_for_tests() -> void:
	unknown_callers.clear()
	_cache_lock.lock()
	_voice_tts = false
	_voice_clips.clear()
	_samples.clear()
	_cache_lock.unlock()
	_lock.lock()
	_lock.unlock()
	_lock = Mutex.new()
	_cache_lock = Mutex.new()


static func has_recipe(id: String) -> bool:
	return id == "babble" or id.begins_with(SAY)


static func trim_db(id: String) -> float:
	if id.begins_with(SAY):
		return BABBLE_TRIM_DB + float(_caller(parse_said(id)[0]).get("db", 0.0))
	if id == "babble":
		return BABBLE_TRIM_DB + float(CALLERS[MOSS].get("db", 0.0))
	return BABBLE_TRIM_DB


static func _cache_has(cache: Dictionary, key: String) -> bool:
	_cache_lock.lock()
	var hit := cache.has(key)
	_cache_lock.unlock()
	return hit


static func _cache_get(cache: Dictionary, key: String) -> Variant:
	_cache_lock.lock()
	var value = cache.get(key)
	_cache_lock.unlock()
	return value


static func _cache_put(cache: Dictionary, key: String, value: Variant) -> Variant:
	_cache_lock.lock()
	if not cache.has(key):
		cache[key] = value
	var held = cache[key]
	_cache_lock.unlock()
	return held


static func _gridded(id: String) -> bool:
	return id.begins_with(SAY) and caller_on_grid(parse_said(id)[0])


static func _plain(id: String, step: int, shift: int) -> bool:
	return (step == Harmony.STEP or not _gridded(id)) and shift == 0


static func _key_at(id: String, step: int, shift: int) -> String:
	return "%s@%d@%d@0" % [id, step if _gridded(id) else Harmony.STEP, shift]


static func samples(id: String) -> PackedFloat32Array:
	if _cache_has(_samples, id):
		return _cache_get(_samples, id)
	_lock.lock()
	var buf: PackedFloat32Array = _cache_get(_samples, id) if _cache_has(_samples, id) else _cache_put(_samples, id, Synth.normalize(_bake(id, Harmony.STEP, 0), 0.9))
	_lock.unlock()
	return buf


static func samples_at(id: String, step: int, shift := 0) -> PackedFloat32Array:
	if _plain(id, step, shift):
		return samples(id)
	var key := _key_at(id, step, shift)
	if _cache_has(_samples, key):
		return _cache_get(_samples, key)
	_lock.lock()
	if not _cache_has(_samples, key):
		var use_step := step if _gridded(id) else Harmony.STEP
		_cache_put(_samples, key, Synth.normalize(_bake(id, use_step, shift), 0.9))
	_lock.unlock()
	return _cache_get(_samples, key)


static func cached_at(id: String, step: int, shift := 0) -> bool:
	return _cache_has(_samples, id if _plain(id, step, shift) else _key_at(id, step, shift))


static func _bake(id: String, step: int, shift: int) -> PackedFloat32Array:
	if id == "babble":
		return babble("Hm. Hm, hm.", BABBLE_LEVEL)
	var parts := parse_said(id)
	return _say(parts[0], parts[1], step, shift)


static func babble(text: String, beat: int, shift := 0) -> PackedFloat32Array:
	var relent := beat == BABBLE_RELENT
	var laid := _babble_blips(text, beat)
	var buf := Synth.buffer(Synth.seconds(float(laid[1]) + 0.3))
	var row: Dictionary = CALLERS[MOSS]
	for blip in laid[0]:
		var piece: PackedFloat32Array
		if blip[5]:
			piece = _grumble(int(blip[1]) + shift)
		elif row.has("mouth"):
			piece = _mouth(int(blip[1]) + shift + int(row.get("drop", 0)), float(blip[2]), float(blip[4]), blip[6], float(row["mouth"]) * (BENCH_SIGH if relent else 1.0))
		else:
			piece = _blip(int(blip[1]) + shift, float(blip[2]), relent, float(blip[4]))
		Synth.add_into(buf, piece, Synth.seconds(float(blip[0])), float(blip[3]))
	return Synth.declick(Synth.normalize(buf, 0.9 * (BENCH_SIGH_LEVEL if relent and row.has("mouth") else 1.0)), 16, 600)


static func _babble_blips(text: String, beat: int) -> Array:
	var relent := beat == BABBLE_RELENT
	var root: int = BABBLE_ROOTS[beat - 1] if beat >= 1 and beat <= 6 else 50
	var triad := [root, Harmony.scale_shift(root, 2, Harmony.DORIAN), Harmony.scale_shift(root, 4, Harmony.DORIAN)]
	var speed := pow(0.92, maxi(beat - 1, 0)) * (1.25 if relent else 1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = text.hash()
	var words := text.split(" ", false)
	var blips: Array = []
	var at := 0.0
	for w in words.size():
		var word: String = words[w]
		var letters := _letters(word)
		var slow := 1.6 if beat == 6 and w == words.size() - 1 else 1.0
		for l in letters.size():
			var vowel: bool = letters[l] in VOWELS
			var length := (0.08 if vowel else 0.04) * speed * slow
			var midi: int = triad[rng.randi() % 3]
			var gain := 1.0
			if l == 0:
				midi = Harmony.scale_shift(midi, 1, Harmony.DORIAN)
				gain = db_to_linear(3.0)
			if l == letters.size() - 1 and word.ends_with("?"):
				midi += 5
			blips.append([at, midi, length, gain, 0.0, false, letters[l]])
			at += length
		if w == 0 and beat in [2, 4, 6]:
			blips.append([0.0, root - 12, 0.2, 0.9, 0.0, true, ""])
		if word.ends_with(","):
			at += 0.12
		elif _ends_sentence(word):
			at += 0.25
		else:
			at += 0.03 * speed
	if relent and not blips.is_empty():
		var last: Array = blips[blips.size() - 1]
		last[2] = 0.32
		last[4] = -7.0
		at = maxf(at, float(last[0]) + 0.32)
	return [blips, at]


static func _letters(word: String) -> Array:
	var letters: Array = []
	for c in word:
		if c.to_lower() != c.to_upper():
			letters.append(c.to_lower())
	return letters


static func _ends_sentence(word: String) -> bool:
	return word.ends_with(".") or word.ends_with("?") or word.ends_with("!")


static func _blip(midi: int, length: float, warm: bool, glide: float) -> PackedFloat32Array:
	var n := Synth.seconds(length)
	var buf := Synth.buffer(n)
	var phase := 0.0
	var low := 0.0
	var band := 0.0
	var g := 2.0 * sin(PI * (800.0 if warm else 1200.0) * Synth.INV_RATE)
	for i in n:
		var t := i * Synth.INV_RATE
		var x := float(i) / n
		phase = fposmod(phase + Harmony.hz(midi + glide * x) * Synth.INV_RATE, 1.0)
		var wave := (1.0 - 4.0 * absf(phase - 0.5)) if warm else (1.0 if phase < 0.5 else -1.0)
		low += g * band
		band += g * (wave - low - 0.9 * band)
		buf[i] = low * minf(1.0, t / 0.005) * (1.0 - 0.6 * x)
	return Synth.declick(buf, 8, 96)


static func _grumble(midi: int) -> PackedFloat32Array:
	var n := Synth.seconds(0.2)
	var buf := Synth.buffer(n)
	var f0 := Harmony.hz(midi)
	var f1 := Harmony.hz(midi - 1)
	var phase := 0.0
	var low := 0.0
	for i in n:
		var t := i * Synth.INV_RATE
		var f := f0 * pow(f1 / f0, float(i) / n)
		phase = fposmod(phase + f * Synth.INV_RATE, 1.0)
		low += ((2.0 * phase - 1.0) - low) * 0.08
		buf[i] = low * 2.0 * minf(1.0, t * 600.0) * exp(-t * 6.0)
	return Synth.declick(buf, 8, 300)


static func say_id(speaker: String, text: String) -> String:
	if not CALLERS.has(speaker) and not unknown_callers.has(speaker):
		unknown_callers[speaker] = true
		push_warning("voice_synth: no caller row for '%s'; the line uses Moss's voice" % speaker)
	return "%s%s|%s" % [SAY, speaker, text]


static func parse_said(id: String) -> Array:
	var parts := id.trim_prefix(SAY).split("|", true, 1)
	return [parts[0], parts[1] if parts.size() > 1 else ""]


static func keep_said(id: String) -> void:
	_cache_lock.lock()
	for key in _samples.keys():
		if key.begins_with(SAY) and key != id and not key.begins_with(id + "@"):
			_samples.erase(key)
	_cache_lock.unlock()


static func _caller(speaker: String) -> Dictionary:
	return CALLERS.get(speaker, CALLERS[MOSS])


static func caller_on_grid(speaker: String) -> bool:
	return _caller(speaker).get("grid", false)


static func _caller_notes(speaker: String) -> Array:
	var row := _caller(speaker)
	var notes: Array = []
	for midi in Harmony.motif_notes(row.get("motif", "")):
		if not (midi + int(row.get("lift", 0))) in notes:
			notes.append(midi + int(row.get("lift", 0)))
	if notes.is_empty():
		var root := int(row.get("root", 50))
		notes = [root, Harmony.scale_shift(root, 2, Harmony.DORIAN), Harmony.scale_shift(root, 4, Harmony.DORIAN)]
	return notes


static func _caller_voice(speaker: String) -> String:
	var row := _caller(speaker)
	return row.get("voice", Harmony.motif(row.get("motif", "")).get("voice", ""))


static func say_seconds(speaker: String, text: String, step := Harmony.STEP) -> float:
	var clip := voice_clip_path(speaker, text)
	if clip != "":
		var info := _read_wav_info(clip)
		if not info.is_empty():
			return float(int(info["frames"])) / float(Harmony.RATE)
	return float(_say_plan(speaker, text, step)[1]) + 0.3


static func set_voice_sidecar(enabled: bool, clips: Dictionary) -> void:
	_cache_lock.lock()
	if _voice_tts == enabled and _voice_clips == clips:
		_cache_lock.unlock()
		return
	_voice_tts = enabled
	_voice_clips = clips.duplicate(true)
	for key in _samples.keys():
		if String(key).begins_with(SAY):
			_samples.erase(key)
	_cache_lock.unlock()


static func reset_voice_sidecar() -> void:
	set_voice_sidecar(false, {})


static func _norm_voice_text(text: String) -> String:
	return text.strip_edges().to_lower()


static func voice_clip_path(speaker: String, text: String) -> String:
	if not _voice_tts or speaker == "" or text == "" or speaker in SYNTH_ONLY_SPEAKERS:
		return ""
	var path := ""
	_cache_lock.lock()
	if not _voice_clips.is_empty():
		var exact := "%s|%s" % [speaker, text]
		var norm := "%s|%s" % [speaker, _norm_voice_text(text)]
		var wild := "%s|*" % speaker
		if _voice_clips.has(exact):
			path = String(_voice_clips[exact])
		elif _voice_clips.has(norm):
			path = String(_voice_clips[norm])
		elif _voice_clips.has(wild):
			path = String(_voice_clips[wild])
	_cache_lock.unlock()
	if path != "" and FileAccess.file_exists(path):
		return path
	return ""


static func _read_wav_info(path: String) -> Dictionary:
	if path == "" or not FileAccess.file_exists(path):
		return {}
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() < 44:
		return {}
	if bytes.slice(0, 4).get_string_from_ascii() != "RIFF" or bytes.slice(8, 12).get_string_from_ascii() != "WAVE":
		return {}
	var audio_format := 0
	var channels := 0
	var sample_rate := 0
	var bits_per_sample := 0
	var data_offset := -1
	var data_size := 0
	var at := 12
	while at + 8 <= bytes.size():
		var chunk_id := bytes.slice(at, at + 4).get_string_from_ascii()
		var size := bytes.decode_u32(at + 4)
		var body := at + 8
		if chunk_id == "fmt " and size >= 16 and body + 16 <= bytes.size():
			audio_format = bytes.decode_u16(body)
			channels = bytes.decode_u16(body + 2)
			sample_rate = bytes.decode_u32(body + 4)
			bits_per_sample = bytes.decode_u16(body + 14)
		elif chunk_id == "data" and body <= bytes.size():
			data_offset = body
			data_size = mini(int(size), bytes.size() - body)
		at = body + int(size) + (int(size) & 1)
	if audio_format != 1 or channels != 1 or bits_per_sample != 16 or sample_rate != RATE or data_offset < 0 or data_size < 2:
		return {}
	return {"bytes": bytes, "offset": data_offset, "size": data_size, "frames": data_size / 2}


static func load_voice_wav(path: String) -> PackedFloat32Array:
	var info := _read_wav_info(path)
	if info.is_empty():
		return PackedFloat32Array()
	var bytes: PackedByteArray = info["bytes"]
	var offset: int = int(info["offset"])
	var size: int = int(info["size"])
	var slice := bytes.slice(offset, offset + size)
	var frames := slice.size() / 2
	var out := PackedFloat32Array()
	out.resize(frames)
	for i in frames:
		out[i] = slice.decode_s16(i * 2) / 32768.0
	return Synth.declick(out, 16, 600)


static func _say_plan(speaker: String, text: String, step := Harmony.STEP) -> Array:
	var row := _caller(speaker)
	if row.get("bench", false):
		return _moss_call(text)
	var notes := _caller_notes(speaker)
	var voice := _caller_voice(speaker)
	var loose := float(row.get("loose", CALL_LOOSE))
	var grid: bool = row.get("grid", false)
	var unit := float(step) / Harmony.RATE
	var pace := float(row.get("pace", 1.0))
	var bend := float(row.get("bend", 0.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = (speaker + text).hash()
	var chirp := [notes[0], notes[0] + 7] if grid else [notes[0], notes[notes.size() - 1]]
	var blips: Array = []
	for i in 2:
		blips.append([i * (unit if grid else CHIRP_NOTE_S), chirp[i], unit * 0.7 if grid else CHIRP_NOTE_S, 1.0 if grid else CHIRP_GAIN, 0.0, voice, ""])
	var at := 4.0 * unit if grid else CALL_TALK_S
	var said := 0
	var joined := false
	for word in text.split(" ", false):
		var letters := _letters(word)
		if letters.is_empty():
			continue
		var other: bool = row.has("second") and said % 2 == 1
		if other and joined:
			at -= CALL_OVERLAP_S
		said += 1
		joined = not (word.ends_with(",") or _ends_sentence(word))
		for l in letters.size():
			var vowel: bool = letters[l] in VOWELS
			if grid:
				blips.append([at, notes[0], unit * 0.35, 1.0, 0.0, voice, letters[l]])
				at += unit * 0.5
				continue
			var length := (0.08 if vowel else 0.04) * pace * rng.randf_range(1.0 - loose, 1.0 + loose)
			var midi: int = notes[rng.randi() % notes.size()]
			if other:
				midi = Harmony.scale_shift(midi, int(row["second"]), Harmony.DORIAN)
			if l == letters.size() - 1 and word.ends_with("?"):
				midi += 5
			var last_of_sentence: bool = l == letters.size() - 1 and _ends_sentence(word)
			if last_of_sentence and row.get("lean", false):
				midi = int(notes[0]) + 1
				length = 0.28
			blips.append([at, midi, length, db_to_linear(3.0) if l == 0 else (0.7 if other else 1.0),
				bend if vowel or l == 0 else 0.0, voice, letters[l]])
			at += length
		if grid:
			at = (ceilf(at / unit + 0.499) + (2.0 if _ends_sentence(word) else (1.0 if word.ends_with(",") else 0.0))) * unit
		elif word.ends_with(","):
			at += 0.04 if row.get("run", false) else 0.12
		elif _ends_sentence(word):
			at += 0.25 * float(row.get("stop", 1.0))
		elif not (row.get("run", false) or row.has("second")):
			at += 0.03 * pace
	return [blips, at]


static func _moss_call(text: String) -> Array:
	var blips: Array = []
	for i in 2:
		blips.append([i * 0.16, 86, CHIRP_NOTE_S, CHIRP_GAIN, 0.0, "mallet", ""])
	var laid := _babble_blips(text, BABBLE_LEVEL)
	for blip in laid[0]:
		blips.append([CALL_TALK_S + float(blip[0]), blip[1], blip[2], blip[3], blip[4], "", blip[6]])
	return [blips, CALL_TALK_S + float(laid[1])]


static func _say(speaker: String, text: String, step := -1, shift := 0) -> PackedFloat32Array:
	var clip := voice_clip_path(speaker, text)
	if clip != "":
		var loaded := load_voice_wav(clip)
		if not loaded.is_empty():
			return loaded
	var use_step := Synth.score_step if step < 0 else step
	var plan := _say_plan(speaker, text, use_step)
	var row := _caller(speaker)
	var buf := Synth.buffer(roundi((float(plan[1]) + 0.3) * Harmony.RATE))
	for blip in plan[0]:
		var voice: String = blip[5]
		var piece: PackedFloat32Array
		if row.has("mouth") and blip[6] != "":
			piece = _mouth(int(blip[1]) + int(row.get("drop", 0)) + shift, float(blip[2]), float(blip[4]), blip[6], float(row["mouth"]))
		elif voice == "":
			piece = _blip(int(blip[1]) + shift, float(blip[2]), false, float(blip[4]))
		else:
			piece = _letter(voice, int(blip[1]), float(blip[2]), float(blip[4]), shift)
		Synth.add_into(buf, piece, roundi(float(blip[0]) * Harmony.RATE), float(blip[3]))
	return Synth.declick(buf, 16, 600)


static func _mouth(midi: int, length: float, bend: float, letter: String, size: float) -> PackedFloat32Array:
	var n := Synth.seconds(length * MOUTH_RING)
	var buf := Synth.buffer(n)
	var vowel := MOUTH_VOWELS.has(letter)
	var shape: Array = MOUTH_VOWELS.get(letter, MOUTH_HUM if letter in MOUTH_HUMMED else MOUTH_SHUT)
	var g1 := 2.0 * sin(PI * float(shape[0]) * size * Synth.INV_RATE)
	var g2 := 2.0 * sin(PI * float(shape[1]) * size * Synth.INV_RATE)
	var air := 0.3 if letter in MOUTH_BREATHED else 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(letter) + midi
	var phase := 0.0
	var l1 := 0.0
	var b1 := 0.0
	var l2 := 0.0
	var b2 := 0.0
	for i in n:
		var x := float(i) / n
		var slot := minf(1.0, x * MOUTH_RING)
		phase = fposmod(phase + Harmony.hz(midi + (bend * (slot - 1.0) if bend > 0.0 else bend * slot)) * Synth.INV_RATE, 1.0)
		var reed := 2.0 * phase - 1.0
		if x < air:
			reed = lerpf(rng.randf_range(-1.0, 1.0), reed, x / air)
		l1 += g1 * b1
		b1 += g1 * (reed - l1 - 0.25 * b1)
		l2 += g2 * b2
		b2 += g2 * (reed - l2 - 0.2 * b2)
		buf[i] = (b1 + 0.6 * b2) * minf(1.0, i / 220.0) * (1.0 - 0.7 * x)
	return Synth.declick(Synth.normalize(buf, MOUTH_PEAK if vowel else MOUTH_PEAK * 0.6), 8, 200)


static func _letter(voice: String, midi: int, length: float, bend: float, shift := 0) -> PackedFloat32Array:
	var n := Synth.seconds(length)
	var buf := Synth.buffer(n)
	if voice == PURE:
		var f := Harmony.hz(midi + shift)
		for i in n:
			buf[i] = sin(TAU * f * i * Synth.INV_RATE) * minf(1.0, minf(i, n - 1 - i) / 130.0)
		return buf
	var note := Synth.note(voice, midi + shift)
	var pos := 0.0
	for i in n:
		var x := float(i) / n
		var j := int(pos)
		if j + 1 >= note.size():
			break
		buf[i] = lerpf(note[j], note[j + 1], pos - j) * (1.0 - 0.6 * x)
		pos += pow(2.0, (bend * (x - 1.0) if bend > 0.0 else bend * x) / 12.0)
	return Synth.declick(buf, 8, 96)
