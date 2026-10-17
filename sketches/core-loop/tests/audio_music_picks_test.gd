extends SceneTree

const Ace := preload("res://src/presentation/ace_sequencer.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const T := preload("res://tests/support/t.gd")

# The picked takes (tools/ace/package_picked_takes.py) are music_ace themes in the menu
# bank's shape: calm, travel and cadence. The manifests are committed and the Oggs are
# local, so the structural checks run everywhere, and the sound checks run wherever the
# Oggs are: the drum stem follows the speed fader and the lead stem follows the chain
# fader, heard in the rendered PCM of a real take.

const THEMES := ["title_a", "title_b", "title_c", "roam_spillway", "roam_dig", "roam_highdraft",
	"boss_brindle", "boss_waking", "boss_mind", "camp"]
const GRIDS := {129: 20512, 172: 15384}

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
	t.eq("%s is the menu bank's three clips" % theme, m["clips"].keys(), ["calm", "travel", "cadence"])
	t.check("%s says its cuts are unverified" % theme, m["timing_verified"] == false and m["cuts"] == "nominal-unverified")
	for cid in m["clips"]:
		var clip: Dictionary = m["clips"][cid]
		var bpm := int(clip["bpm"])
		t.check("%s/%s sits on a house grid" % [theme, cid], GRIDS.has(bpm) and clip["beat"] == GRIDS[bpm] and clip["bar"] == 4 * clip["beat"], "%d bpm, beat %d" % [bpm, clip["beat"]])
		t.eq("%s/%s is whole bars" % [theme, cid], int(clip["exit"]) - int(clip["entry"]), int(clip["bars"]) * int(clip["bar"]))
		t.check("%s/%s names all three Oggs" % [theme, cid], clip["files"].keys() == ["drums", "bass", "other"])
		t.check("%s/%s loops only calm and travel" % [theme, cid], bool(clip["loop"]) == (cid != "cadence"))
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
	var bar: int = GRIDS[int(JSON.parse_string(FileAccess.get_file_as_string(path))["clips"]["calm"]["bpm"])] * 4
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
