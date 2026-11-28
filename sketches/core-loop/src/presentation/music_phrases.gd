extends RefCounted

const Harmony := preload("res://src/presentation/harmony.gd")

const MOTIF := [[2, 69, 2], [4, 72, 1], [5, 74, 1], [6, 76, 2], [8, 74, 2], [10, 72, 1], [11, 69, 3],
	[16, 67, 2], [18, 65, 2], [20, 69, 6]]
const MOTIF_SLUICE := [[0, 74, 1], [2, 77, 1], [3, 79, 1], [5, 81, 3], [8, 84, 2], [10, 81, 1], [11, 79, 1],
	[12, 77, 2], [14, 74, 2], [16, 72, 2], [18, 74, 4], [24, 77, 1], [25, 79, 1], [26, 74, 4]]
const MOTIF_WEIR := [[0, 62, 2], [2, 65, 2], [4, 69, 2], [6, 72, 2], [8, 74, 3], [11, 76, 1], [12, 77, 4],
	[16, 76, 2], [18, 74, 2], [20, 72, 6]]


static func shift_voicing(voicing: Array, by: int) -> Array:
	var out := []
	for midi in voicing:
		out.append(int(midi) + by)
	return out


static func make_counter(lead: Array, progression: Array) -> Array:
	var out: Array = []
	for event in lead:
		var step := (int(event[0]) + 32) % 128
		var chord: Dictionary = progression[(step / 16) % progression.size()]
		var midi := Harmony.scale_shift(int(event[1]), -2, Harmony.DORIAN)
		midi = Harmony.nearest_tone(midi, chord["tones"]) if step % 4 == 0 else Harmony.snap(midi, chord["scale"])
		while midi > 79:
			midi -= 12
		while midi < 57:
			midi += 12
		out.append([step, midi, event[2]])
	out.sort_custom(func(a: Array, b: Array): return a[0] < b[0])
	return out


static func make_class_counter(class_motif: String, progression: Array) -> Array:
	var row := Harmony.motif(class_motif)
	if row.get("family", "") != "class":
		return []
	var cells: Array = row["cells"]
	var last: Array = cells[cells.size() - 1]
	var span: int = int(last[0]) + int(last[2])
	var octave: int = row.get("band_octave", 0)
	var out: Array = []
	for k in 4:
		var start := 32 * k + 30 - span
		var chord: Dictionary = progression[(start / 16) % progression.size()]
		var first: int = int(cells[0][1]) + octave
		var shift := Harmony.nearest_tone(first, chord["tones"]) - first
		for cell in cells:
			out.append([start + int(cell[0]), Harmony.snap(int(cell[1]) + octave + shift, chord["scale"]), int(cell[2])])
	return out


static func make_lead(index: int, motif := MOTIF, progression := Harmony.PROGRESSION, ending := 73, answers := [0, 1, 2]) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260926 + index * 7919
	var shift: int = [0, 1, 2, -1][rng.randi() % 4]
	var pick := rng.randi() % answers.size()
	var notes := []
	notes.append_array(_place(_transpose(motif, shift), 0))
	notes.append_array(_place(_answer(motif, answers[pick], shift), 32))
	notes.append_array(_place(_transpose(motif, shift + 2), 64))
	notes.append_array(_place(_answer(motif, answers[(pick + 1) % answers.size()], shift), 96))
	var span := progression.size() * 16
	var fitted := []
	for event in notes:
		var step: int = event[0]
		if step >= mini(128, span * 2):
			continue
		var chord: Dictionary = progression[(step / 16) % progression.size()]
		var midi: int = event[1]
		midi = Harmony.nearest_tone(midi, chord["tones"]) if step % 4 == 0 else Harmony.snap(midi, chord["scale"])
		while midi < 62:
			midi += 12
		while midi > 84:
			midi -= 12
		fitted.append([step, midi, mini(event[2], 128 - step)])
	if not fitted.is_empty():
		var last: Array = fitted[fitted.size() - 1]
		if ending >= 0:
			last[1] = ending
		else:
			var chord: Dictionary = progression[(int(last[0]) / 16) % progression.size()]
			last[1] = Harmony.nearest_tone(last[1], chord["tones"])
	var taken := {}
	for event in fitted:
		taken[event[0]] = true
	var ornamented := []
	for event in fitted:
		if event[0] % 4 == 0 and event[0] > 0 and not taken.has(event[0] - 1) and rng.randf() < 0.35:
			ornamented.append([event[0] - 1, event[1] - 1, 1])
		ornamented.append(event)
	return ornamented


static func make_lounge_lead(index: int, motif: Array, progression: Array, answers := [0, 1]) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260927 + index * 7919
	var slow: Array = []
	for cell in motif:
		slow.append([int(cell[0]) * 2, int(cell[1]), int(cell[2]) * 2])
	var notes: Array = _place(slow, 0)
	notes.append_array(_place(_answer(slow, answers[rng.randi() % answers.size()], 0), 64))
	var fitted: Array = []
	for event in notes:
		var step: int = event[0]
		if step >= 128:
			continue
		var chord: Dictionary = progression[(step / 16) % progression.size()]
		var midi: int = event[1]
		midi = Harmony.nearest_tone(midi, chord["tones"]) if step % 4 == 0 else Harmony.snap(midi, chord["scale"])
		while midi < 62:
			midi += 12
		while midi > 81:
			midi -= 12
		fitted.append([step, midi, mini(event[2], 128 - step)])
	if not fitted.is_empty():
		var last: Array = fitted[fitted.size() - 1]
		last[1] = Harmony.nearest_tone(last[1], progression[(int(last[0]) / 16) % progression.size()]["tones"])
	return fitted


static func _place(cell: Array, offset: int) -> Array:
	var placed := []
	for event in cell:
		placed.append([event[0] + offset, event[1], event[2]])
	return placed


static func _transpose(cell: Array, steps: int) -> Array:
	var moved := []
	for event in cell:
		moved.append([event[0], Harmony.scale_shift(event[1], steps, Harmony.DORIAN) if steps != 0 else event[1], event[2]])
	return moved


static func _answer(cell: Array, kind: int, shift: int) -> Array:
	var source := _transpose(cell, shift)
	var answer := []
	match kind:
		0:
			var pivot: int = source[0][1]
			for event in source:
				answer.append([event[0], Harmony.snap(2 * pivot - event[1], Harmony.DORIAN), event[2]])
		1:
			for i in source.size():
				answer.append([source[i][0], source[source.size() - 1 - i][1], source[i][2]])
		_:
			for event in source:
				if event[0] + 2 < 32:
					answer.append([event[0] + 2, Harmony.scale_shift(event[1], -2, Harmony.DORIAN), event[2]])
	return answer
