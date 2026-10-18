extends SceneTree

# Rule (WHATS-LEFT unit 5, HIGHDRAFT-SOUND): the Highdraft's four event cues are rows of their
# own, not aliases of the generic family cues, so the Fleet anvil, the boiler, the Mind's quote
# and the Mind's wrong note each sound unlike their Spillway and Dig cousins, and each Highdraft
# park hears at least four event sounds no Spillway or Dig park plays.
#
# Evidence limit: synth fallback rows and baked recipes only. Rendered per-stage stingers (PR
# #12, assets/audio/stingers/3_*) override these where present; how either reads in a firefight
# is Andrew's ear at the sitting.

const MusicRows := preload("res://src/presentation/music_rows.gd")
const Bank := preload("res://src/presentation/sfx_bank.gd")
const Harmony := preload("res://src/presentation/harmony.gd")

const OWN := {"drop_fleet_anvil": "drop_fleet", "drop_boiler": "drop_industrial",
	"riser_mind_quote": "riser_ancient", "drop_mind_wrong": "drop_ancient"}
const MOTIFS := ["sable", "rivet", "kest", "tarn", "tally", "cannon"]
const MIN_SAMPLES := Harmony.RATE / 20

var _failures := 0
var _checks := 0


func _report(label: String, ok: bool, detail: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _signature(row: Dictionary) -> String:
	return str([row.get("voice", ""), row.get("notes", []), row.get("accent", ""), row.get("sound", "")])


func _initialize() -> void:
	# A context from another world: the Highdraft's Mind cues still speak as the Mind.
	var context := {"ancient": "reactor", "motif": "tarn", "theme": 2}
	for id in OWN:
		_report("own row", not MusicRows.CUES[id].has("alias"), "%s: %s" % [id, MusicRows.CUES[id]])
		var own := MusicRows.cue(id, context)
		var generic := MusicRows.cue(OWN[id], context)
		_report("sounds unlike its generic cue", _signature(own) != _signature(generic), "%s %s vs %s %s" % [id, _signature(own), OWN[id], _signature(generic)])
		_report("same danger as its generic cue", MusicRows.danger(id) == MusicRows.danger(OWN[id]), id)
		if own.has("sound"):
			_report("bank bakes it", Bank.has_recipe(own.sound) and Bank.samples(own.sound).size() > MIN_SAMPLES, "%s -> %s" % [id, own.sound])
		_report("trim names a bank level", Bank.has_recipe(own.trim_sound), "%s -> %s" % [id, own.trim_sound])
	var quote := MusicRows.cue("riser_mind_quote", context)
	var notes: Array = []
	for cell in Harmony.mind_quote("tarn"):
		notes.append(int(cell[1]))
	_report("the quote is the Mind playing the pilot's hook", quote.notes == notes and quote.voice == Harmony.motif("mind").voice, str(quote))
	var wrongs := {}
	for motif in MOTIFS:
		var wrong := MusicRows.cue("drop_mind_wrong", {"motif": motif})
		_report("wrong note per pilot", wrong.sound == "mind_wrong_" + motif and Bank.has_recipe(wrong.sound), str(wrong.get("sound", "")))
		wrongs[Bank.samples(wrong.sound)] = true
	_report("each pilot's wrong note differs", wrongs.size() == MOTIFS.size(), "%d distinct of %d" % [wrongs.size(), MOTIFS.size()])
	_report("the wrong note is not the quote", Bank.samples("mind_wrong_tarn") != Bank.samples("mind_tarn"), "mind_wrong_tarn vs mind_tarn")
	# The scorecard's count stays at the 9 cues each park names; what changes is whose they are.
	var elsewhere := {}
	for park in ["park_dam", "park_flume", "park_pit", "park_sinkhole"]:
		for sound in _park_sounds(park):
			elsewhere[sound] = true
	for park in ["park_crown", "park_islands"]:
		var own := _park_sounds(park).filter(func(sound): return not elsewhere.has(sound))
		_report("Highdraft-only event sounds", own.size() >= OWN.size(), "%s: %d of its cues heard in no Spillway or Dig park" % [park, own.size()])
	# sketch:smoke needs the suite verdict line (tests/support/t.gd verdict()), not just the exit code.
	if _failures == 0:
		print("highdraft_cues_test: PASS (%d checks)" % _checks)
	else:
		print("highdraft_cues_test: FAIL (%d of %d checks)" % [_failures, _checks])
	quit(0 if _failures == 0 else 1)


func _park_sounds(park: String) -> Array:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://src/world/park/%s.json" % park))
	var sounds := {}
	for event in data.event_rows:
		for phase in event.get("music_cue", {}):
			sounds[_signature(MusicRows.cue(String(event.music_cue[phase]), {"ancient": "mind", "motif": "tarn", "theme": 2}))] = true
	return sounds.keys()
