extends SceneTree

const Ace := preload("res://src/presentation/ace_sequencer.gd")
const TuneMoments := preload("res://src/presentation/tune_moments.gd")
const T := preload("res://tests/support/t.gd")

# The 24 place-and-moment packs (tune_moments.gd): each has a committed flat manifest with one
# looping clip on a whole-bar grid. Where the gitignored Oggs exist, the sequencer loads the
# pack, starts the boss on "main" and never schedules a Warden section.

var _t := T.new("tune_pack_test")


func _initialize() -> void:
	var loaded := 0
	for id in TuneMoments.TUNES.keys():
		var path: String = TuneMoments.manifest_of(id)
		_t.check("%s manifest is committed" % id, FileAccess.file_exists(path))
		if not FileAccess.file_exists(path):
			continue
		var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		_t.check("%s is flat with one looping clip" % id, bool(m.get("flat", false)) and m["clips"].keys() == ["main"] and bool(m["clips"]["main"]["loop"]) and m["sections"].keys() == ["main"])
		var c: Dictionary = m["clips"]["main"]
		_t.check("%s is whole bars on its grid" % id, int(c["bar"]) == 4 * int(c["beat"]) and int(c["exit"]) - int(c["entry"]) == int(c["bars"]) * int(c["bar"]) and int(c["loop_offset"]) == int(c["entry"]))
		_t.check("%s keeps the profiles and breath the sequencer reads" % id, m["profiles"].has("full") and m["breath"].has("hard"))
		var ogg: String = path.get_base_dir().path_join("main.drums.ogg")
		if not FileAccess.file_exists(ogg):
			_t.check("%s without its Oggs is not available" % id, not TuneMoments.available(id))
			continue
		var ace := Ace.new(path)
		_t.check("%s loads" % id, ace.ready(), ace.missing)
		_t.check("%s is available exactly when it loads" % id, TuneMoments.available(id) == ace.ready())
		if not ace.ready():
			continue
		loaded += 1
		ace.start_boss(0)
		_t.eq("%s boss opens on main, not a pivot" % id, ace.pending.get("section", ""), "main")
		ace.advance(44100)
		ace.set_warden_state("telegraph")
		ace.set_warden_state("open")
		_t.eq("%s drop_now is refused" % id, ace.drop_now(), -1)
		var mode_before := ace.mode
		ace.warden_broken()
		ace.commit_warden()
		_t.eq("%s keeps its mode through a Warden break" % id, ace.mode, mode_before)
		var out := ace.render(8192)
		var peak := 0.0
		for f in out:
			peak = maxf(peak, maxf(absf(f.x), absf(f.y)))
		_t.check("%s sounds" % id, peak > 0.05, "peak %.3f" % peak)
		_t.eq("%s stays on main" % id, ace.section if ace.section != "" else String(ace.pending.get("section", "")), "main")
	print("tune_pack_test: %d of %d packs had Oggs and were played" % [loaded, TuneMoments.TUNES.keys().size()])
	quit(_t.verdict())
