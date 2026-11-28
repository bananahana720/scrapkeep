extends RefCounted

const Harmony := preload("res://src/presentation/harmony.gd")
const Synth := preload("res://src/presentation/synth.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const MusicEngine := preload("res://src/presentation/music_engine.gd")
const MusicPhrases := preload("res://src/presentation/music_phrases.gd")

# Serialized because GDScript lazy operator cache is not thread-safe on concurrent cold calls (SIGSEGV in _prepare_wobble).
static var _rest_lock := Mutex.new()


static func reset_for_tests() -> void:
	_rest_lock.lock()
	_rest_lock.unlock()
	_rest_lock = Mutex.new()


static func prepare() -> void:
	_prepare_chords(Harmony.PROGRESSION + Harmony.CADENCE + [Harmony.MINOR_OF["G13"], Harmony.MINOR_OF["Cmaj9"], Harmony.MINOR_OF["Bbmaj9"]], ["lead"], 0)
	for drum in Synth.DRUMS:
		if SfxBank.bake_cancel:
			return
		Synth.drum(drum)
	for chord in Harmony.PROGRESSION:
		if SfxBank.bake_cancel:
			return
		Synth.note("reese", chord["root"] + 19)


static func prepare_opening() -> void:
	_prepare_club(Harmony.PROGRESSION, 0, [12, 19, 22, 24])
	_prepare_chords(Harmony.PROGRESSION, ["brass", "talk"], 0)
	_prepare_chords(Harmony.PROGRESSION, ["lead", "brass", "talk"], 1)
	_prepare_club(Harmony.PROGRESSION, 1, [12, 18, 19, 22])
	for shift in [0, 1]:
		_prepare_club(Harmony.SINISTER + [Harmony.DOMINANT, Harmony.TRITONE], shift, [12, 18, 19, 22])
	for midi in range(58, 88):
		if SfxBank.bake_cancel:
			return
		Synth.note("choir_ah", midi)
		Synth.note("choir_oo", midi)
		Synth.note("keys", midi)
		Synth.note("talk", midi)
		Synth.note("tom", midi)
		Synth.note("beep", midi)
	for midi in range(58, 104):
		if SfxBank.bake_cancel:
			return
		Synth.note("bell", midi)
		Synth.note("mallet", midi)
		Synth.note("clav", midi)
	for midi in range(34, 72):
		if SfxBank.bake_cancel:
			return
		Synth.note("fbass", midi)
		Synth.note("reese", midi + 10)
	for cell in Harmony.motif("reactor")["cells"]:
		Synth.note("sub", int(cell[1]))


static func _prepare_club(chords: Array, shift: int, reese_offsets: Array) -> void:
	for chord in chords:
		if SfxBank.bake_cancel:
			return
		var voicing := MusicPhrases.shift_voicing(chord["voicing"], shift)
		var root: int = int(chord["root"]) + shift
		Synth.stab_chord(voicing, false)
		Synth.stab_chord(voicing, true)
		for offset in [0, 7, 10, 12]:
			Synth.note("fbass", root + offset)
		if SfxBank.bake_cancel:
			return
		for offset in reese_offsets:
			Synth.note("reese", root + offset)
		for midi in voicing:
			if SfxBank.bake_cancel:
				return
			Synth.note("clav", midi)
			Synth.note("clav", midi + 12)
			Synth.note("clav", midi + 24)


static func prepare_rest() -> void:
	_rest_lock.lock()
	_bake_rest()
	_rest_lock.unlock()


static func _bake_rest() -> void:
	var chords: Array = []
	for list in [Harmony.SLUICE, Harmony.WEIR, Harmony.BRINDLE, Harmony.VICTORY, Harmony.MINOR_OF.values(), Harmony.BRINDLE_PHRYGIAN]:
		chords.append_array(list)
	_prepare_chords(chords, ["brass", "talk"], 0)
	_prepare_chords(Harmony.BRINDLE_PHRYGIAN, ["brass"], 1)
	_prepare_chords(Harmony.BRINDLE, ["brass"], 2)
	for list in [Harmony.WEIR, Harmony.BRINDLE, Harmony.MINOR_OF.values(), Harmony.BRINDLE_PHRYGIAN]:
		for chord in list:
			if SfxBank.bake_cancel:
				return
			Synth.organ_chord(chord["voicing"])
	for pair in [[Harmony.BRINDLE_PHRYGIAN, 1], [Harmony.BRINDLE, 1], [Harmony.BRINDLE, 2]]:
		for chord in pair[0]:
			if SfxBank.bake_cancel:
				return
			Synth.organ_chord(MusicPhrases.shift_voicing(chord["voicing"], pair[1]))
	for pair in [[Harmony.SLUICE, 0], [Harmony.WEIR, 0], [Harmony.VICTORY, 0], [Harmony.BRINDLE, 0],
			[Harmony.BRINDLE_PHRYGIAN, 1], [Harmony.BRINDLE, 1], [Harmony.BRINDLE, 2]]:
		_prepare_club(pair[0], pair[1], [12, 19, 22, 24])
	var lifted: Array = Harmony.PROGRESSION + Harmony.SLUICE + Harmony.WEIR + Harmony.SINISTER + [Harmony.DOMINANT, Harmony.TRITONE]
	_prepare_chords(lifted, ["lead", "brass", "talk"], 1)
	_prepare_chords(Harmony.SINISTER + [Harmony.DOMINANT, Harmony.TRITONE], [], 0)
	for shift in [0, 1]:
		for chord in lifted:
			if SfxBank.bake_cancel:
				return
			var voicing := MusicPhrases.shift_voicing(chord["voicing"], shift)
			Synth.stab_chord(voicing, false)
			Synth.stab_chord(voicing, true)
			for offset in [0, 7, 10, 12]:
				Synth.note("fbass", int(chord["root"]) + shift + offset)
			if SfxBank.bake_cancel:
				return
			for offset in [12, 18, 19, 22]:
				Synth.note("reese", int(chord["root"]) + shift + offset)
	for shift in [0, 1, 2, 3]:
		for level in 3:
			if SfxBank.bake_cancel:
				return
			SfxBank.samples_at("synergy_fanfare", Harmony.STEP, shift, level)
			SfxBank.samples_at("synergy_fanfare", Harmony.BOSS_STEP, shift, level)
		if shift == 0:
			continue
		for id in ["class_up", "class_down", "stinger_milestone", "threat_up", "boss_phase"]:
			if SfxBank.bake_cancel:
				return
			SfxBank.samples_at(id, Harmony.STEP, shift)
			SfxBank.samples_at(id, Harmony.BOSS_STEP, shift)
	for id in SfxBank.STINGER_BEATS:
		if SfxBank.bake_cancel:
			return
		if SfxBank.file_backed(id):
			for shift in [0, 1, 2, 3] if id == "stinger_boss_defeated" else [0]:
				SfxBank.samples_at(id, Harmony.BOSS_STEP, shift)
	_prepare_wobble(Harmony.PROGRESSION + Harmony.SLUICE + Harmony.WEIR + Harmony.BRINDLE, [0], [Harmony.BOSS_STEP], ["wub"])
	_prepare_wobble(Harmony.BRINDLE_PHRYGIAN, [1], [Harmony.BOSS_STEP], ["wub"])
	_prepare_wobble(Harmony.BRINDLE, [2], [MusicEngine.PHASE3_STEP], ["wub"])
	_prepare_wobble(Harmony.BRINDLE + Harmony.VICTORY, [0, 2], [Harmony.STEP], ["wub"])
	var boss_chords: Array = Harmony.BRINDLE + Harmony.BRINDLE_PHRYGIAN + Harmony.SINISTER + [Harmony.DOMINANT, Harmony.TRITONE]
	for shift in [0, 1, 2, 3]:
		for chord in boss_chords:
			if SfxBank.bake_cancel:
				return
			var voicing := MusicPhrases.shift_voicing(chord["voicing"], shift)
			Synth.pad_chord(voicing)
			Synth.organ_chord(voicing)
			if SfxBank.bake_cancel:
				return
			Synth.stab_chord(voicing, false)
			Synth.stab_chord(voicing, true)
			Synth.chord(voicing)
			Synth.note("sub", int(chord["root"]) + shift)
	for chord in Harmony.VICTORY:
		if SfxBank.bake_cancel:
			return
		var voicing := MusicPhrases.shift_voicing(chord["voicing"], int(MusicEngine.BOSS_SECTIONS.mind.victory.key))
		Synth.chord(voicing)
		Synth.stab_chord(voicing, true)
		Synth.pad_chord(voicing)
		var root := int(chord["root"]) + int(MusicEngine.BOSS_SECTIONS.mind.victory.key)
		Synth.note("sub", root)
		Synth.note("reese", root + 12)
		Synth.note("fbass", root)
		Synth.note("fbass", root + 12)
	for step in [Harmony.BOSS_STEP, MusicEngine.PHASE3_STEP]:
		if SfxBank.bake_cancel:
			return
		SfxBank.samples_at("build_riser", step)


static func prepare_all() -> void:
	prepare()
	prepare_opening()
	prepare_rest()


static func _prepare_chords(chords: Array, leads: Array, shift: int) -> void:
	for chord in chords:
		if SfxBank.bake_cancel:
			return
		var voicing := MusicPhrases.shift_voicing(chord["voicing"], shift)
		Synth.note("sub", chord["root"] + shift)
		Synth.note("reese", chord["root"] + 12 + shift)
		Synth.chord(voicing)
		if SfxBank.bake_cancel:
			return
		Synth.pad_chord(voicing)
		for midi in voicing:
			Synth.note("bell", midi + 12)
			Synth.note("bell", midi + 24)
	for midi in range(60 + shift, 87 + shift):
		if SfxBank.bake_cancel:
			return
		for voice in leads:
			Synth.note(voice, midi)


static func _prepare_wobble(chords: Array, shifts: Array, steps: Array, vowels: Array) -> void:
	var roots := {}
	for chord in chords:
		roots[int(chord["root"])] = true
		roots[int(chord["root"]) - 1] = true
	for root in roots:
		for shift in shifts:
			for step in steps:
				for rate in MusicEngine.DROP_RATES.map(func(r: String): return MusicEngine.RATES[r]):
					for vowel in vowels:
						if SfxBank.bake_cancel:
							return
						Synth.wob(root + shift, int(step) * Harmony.STEPS_PER_BEAT / int(rate), vowel)
