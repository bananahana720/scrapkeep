extends SceneTree

const Ace := preload("res://src/presentation/ace_sequencer.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const T := preload("res://tests/support/t.gd")

# The picked takes (tools/ace/package_core_packs.py, from the mastered picks) are music_ace
# themes: the menu bank's calm, travel and cadence, and for a boss its eight combat clips. The manifests are committed and the Oggs are
# local, so the structural checks run everywhere, and the sound checks run wherever the
# Oggs are: the drum stem follows the speed fader and the lead stem follows the chain
# fader, heard in the rendered PCM of a real take.

const THEMES := ["title_a", "title_b", "title_c", "roam_spillway", "roam_dig", "roam_highdraft",
	"boss_brindle", "boss_waking", "boss_mind", "camp"]
const BOSS_CLIPS := ["calm", "travel", "pivot", "build", "telegraph", "open", "drop", "cadence"]
# A boss clip that plays once: the pivot bar, the switch-up drop and the kill cadence.
const ONE_SHOTS := ["pivot", "drop", "cadence"]

var t := T.new("audio_music_picks_test")


func _initialize() -> void:
	var heard := 0
	for theme in THEMES:
		var path := "res://assets/music_ace/%s/manifest.json" % theme
		if not t.check("%s manifest is committed" % theme, FileAccess.file_exists(path)):
			continue
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		_structure(theme, manifest)
		if _stems_present(theme, manifest):
			heard += 1
			_faders(theme, path)
		else:
			# The Oggs are gitignored: say so, so the smoke receipt counts the unrun PCM checks.
			print("SKIP control %s fader PCM: its Oggs are not in this checkout" % theme)
	print("MUSIC_PICKS themes=%d heard=%d" % [THEMES.size(), heard])
	quit(t.verdict())


func _structure(theme: String, m: Dictionary) -> void:
	t.eq("%s names itself" % theme, m["theme"], theme)
	t.eq("%s has the three stems" % theme, m["stems"], ["drums", "bass", "other"])
	var boss := theme.begins_with("boss_")
	var want: Array = BOSS_CLIPS if boss else ["calm", "travel", "cadence"]
	t.eq("%s has its clips" % theme, m["clips"].keys(), want)
	var verified_cuts: bool = m["timing_verified"] == true and m["cuts"] == "lyria-3.5-stem-context"
	var unverified_cuts: bool = m["timing_verified"] == false and m["cuts"] in ["nominal-unverified", "measured-beat-phase"]
	t.check("%s records valid cut provenance" % theme, verified_cuts or unverified_cuts)
	for cid in m["clips"]:
		var clip: Dictionary = m["clips"][cid]
		var bpm := float(clip["bpm"])
		# Each clip sits on its own measured tempo: a whole number of samples per beat, four beats a bar.
		t.check("%s/%s sits on its tempo's grid" % [theme, cid], absi(int(clip["beat"]) - roundi(Harmony.RATE * 60.0 / bpm)) <= 1 and clip["bar"] == 4 * clip["beat"], "%.2f bpm, beat %d" % [bpm, clip["beat"]])
		t.eq("%s/%s is whole bars" % [theme, cid], int(clip["exit"]) - int(clip["entry"]), int(clip["bars"]) * int(clip["bar"]))
		t.check("%s/%s names all three Oggs" % [theme, cid], clip["files"].keys() == ["drums", "bass", "other"])
		var loops: bool = not (cid in ONE_SHOTS) if boss else cid != "cadence"
		t.check("%s/%s loops unless it plays once" % [theme, cid], bool(clip["loop"]) == loops)
	for section in m["sections"]:
		t.check("%s section %s points at a clip" % [theme, section], m["clips"].has(m["sections"][section]["clip"]))


func _stems_present(theme: String, m: Dictionary) -> bool:
	for cid in m["clips"]:
		for file in m["clips"][cid]["files"].values():
			if not FileAccess.file_exists("res://assets/music_ace/%s/%s" % [theme, file]):
				return false
	return true


func _energy(seq: Ace, stem: String, frames: int) -> float:
	seq.solo = [stem]
	var total := 0.0
	var left := frames
	while left > 0:
		var n := mini(4096, left)
		seq.render(n)
		for i in n:
			total += seq.out[i].length_squared()
		left -= n
	return total


func _level(theme: String, path: String, feed: Dictionary) -> Ace:
	var seq := Ace.new(path)
	seq.parameter_enabled = true
	seq.parameters = feed
	seq.start_level(0)
	return seq


func _faders(theme: String, path: String) -> void:
	var bar: int = int(JSON.parse_string(FileAccess.get_file_as_string(path))["clips"]["calm"]["bar"])
	var still := _level(theme, path, {"threat": 0.0, "speed": 0.0, "chain": 0.0})
	t.eq("%s loads every Ogg" % theme, still.missing, "")
	# Let the join finish, then listen to two bars.
	still.render(bar * 4)
	var drums_still := _energy(still, "drums", bar * 12)
	var fast := _level(theme, path, {"threat": 0.0, "speed": 1.0, "chain": 0.0})
	fast.render(bar * 4)
	var drums_fast := _energy(fast, "drums", bar * 12)
	t.eq("%s drums are silent standing still" % theme, drums_still, 0.0)
	t.check("%s drums play at speed" % theme, drums_fast > 1.0, "energy %.1f" % drums_fast)
	var bass_still := _energy(_level(theme, path, {"threat": 0.0, "speed": 0.0, "chain": 0.0}), "bass", bar * 12)
	t.check("%s bass stays under the world standing still" % theme, bass_still > 1.0, "energy %.1f" % bass_still)
	var lead_none := _level(theme, path, {"threat": 0.0, "speed": 0.0, "chain": 0.0})
	lead_none.render(bar * 4)
	var lead_chain := _level(theme, path, {"threat": 0.0, "speed": 0.0, "chain": 1.0})
	lead_chain.render(bar * 4)
	t.eq("%s lead is shut without a chain" % theme, _energy(lead_none, "other", bar * 12), 0.0)
	t.check("%s lead plays on a chain of four" % theme, _energy(lead_chain, "other", bar * 12) > 1.0)
