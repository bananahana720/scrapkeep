extends SceneTree

const Audio := preload("res://src/presentation/audio.gd")
const Ace := preload("res://src/presentation/ace_sequencer.gd")
const MusicRows := preload("res://src/presentation/music_rows.gd")
const PhaseMusic := preload("res://src/presentation/phase_music.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const T := preload("res://tests/support/t.gd")

# Where the sound bible's picks play (SOUND-INT picks, music thread 17 Oct): each world's
# roaming take on its zone packs' shelf (cut into the packs, RENDERS.md), never inside a
# Warden's arena and crossing into it on the drums alone; each boss's picked
# theme opening its fight; title A until an opening names its theme; the summary pack in won
# mode on a won run and the ending (PR #12 rebuilds it to open on theme C), lost mode on a
# loss; the camp take while the camp is open. Every pick not on disk falls back to the older pack. The packs are stood in by
# title_available, so the slots are checked everywhere; the pivot is heard only where the
# Oggs are.

const ZONES := ["1-1", "1-2", "2-1", "2-2", "3-1", "3-2"]
const WARDEN_SECTIONS := ["pivot", "build", "telegraph", "open", "drop", "break", "return"]

class FakeCtx:
	extends RefCounted
	var events: Node

class Rig:
	extends Audio
	var named: Array = []
	func ace_wanted() -> bool:
		return true
	func _ace_named(id: String, at: int, _boss := false, won := true) -> void:
		_on_title = false
		named.append([id, at, won])

var _t := T.new("audio_pick_slots_test")
var _nodes: Array = []


func _initialize() -> void:
	_title()
	_summary()
	_camp()
	_bosses()
	_shelf_rows()
	_pivot_heard()
	for node in _nodes:
		if is_instance_valid(node):
			node.queue_free()
	quit(_t.verdict())


func _title() -> void:
	var none := _rig({})
	_t.eq("no title takes on disk: the plain title", none.title_now(), "title")
	var a := _rig({"title-a": true, "title-b": true})
	_t.eq("before any opening the title plays theme A", a.title_now(), "title-a")
	a.title_theme("B")
	_t.eq("a B opening plays theme B", a.title_now(), "title-b")
	var no_a := _rig({"title-b": true})
	_t.eq("theme A not on disk: the plain title", no_a.title_now(), "title")


func _summary() -> void:
	# The summary pack holds theme C with its lift (won) and the jazz-club summary (lost).
	var c := _rig({"summary": true, "title-c": true})
	_t.eq("the won-summary slot is the summary pack", Audio.WON_SUMMARY_ROW, "summary")
	_t.eq("a won run's summary plays the summary pack, theme C with its lift", c.summary_row(true), "summary")
	_t.eq("a lost run keeps the jazz-club summary", c.summary_row(false), "summary")
	_t.eq("the summary pack not on disk: a won run plays plain theme C", _rig({"title-c": true}).summary_row(true), "title-c")
	_t.eq("neither on disk: the summary row", _rig({}).summary_row(true), "summary")
	c.get_meta("events").run_ended.emit(false)
	c._flush_flow()
	_t.check("a lost run starts the summary as lost", _last(c) == ["summary", false], str(c.named))
	c.get_meta("events").run_ended.emit(true)
	c._flush_flow()
	_t.check("a won run starts the summary as won (theme C with its lift)", _last(c) == ["summary", true], str(c.named))


func _camp() -> void:
	var a := _rig({"title-a": true, "title-b": true, "camp": true})
	a.camp_theme(true)
	_t.eq("opening the camp plays the camp take", _last_id(a), "camp")
	_t.eq("on the next bar", int(a.named[-1][1]) if not a.named.is_empty() else -1, a.engine.next_bar())
	a.title_theme("B")
	_t.eq("an opening under the camp restarts nothing", _last_id(a), "camp")
	a.camp_theme(false)
	_t.eq("closing the camp brings the title back", _last_id(a), "title-b")
	_t.check("and the title owns the music again", a._on_title)
	var count := a.named.size()
	a.camp_theme(false)
	_t.eq("closing a closed camp changes nothing", a.named.size(), count)
	a.camp_theme(true)
	a.spinning = "x"
	a.stop_spin()
	_t.eq("lifting the jukebox needle in the camp returns the camp take", _last_id(a), "camp")
	a.camp_theme(false)
	var flat := _rig({"title-a": true})
	flat.camp_theme(true)
	_t.eq("no camp take on disk: the title plays on", _last_id(flat), "title-a")


func _bosses() -> void:
	for boss in PhaseMusic.PICKED:
		var row := String(PhaseMusic.PICKED[boss])
		_t.check("%s's pick has a row" % boss, MusicRows.ROWS.has(row) and String(MusicRows.ROWS[row]["ace_manifest"]).ends_with("/boss_%s/manifest.json" % boss))
		_t.eq("%s's pick opens the fight" % boss, PhaseMusic.entry_track(boss, func(id): return id == row), row)
		_t.eq("%s with no pick on disk keeps its older theme" % boss, PhaseMusic.entry_track(boss, func(_id): return false), boss)
		var m := _manifest(row)
		_t.check("%s's pick sits on the 129 combat grid" % boss, _bpms(m) == [129])
	_t.eq("brindle's later phases still follow the pick", PhaseMusic.track_for_phase("brindle", 2), "brindle-p2-furnace")
	_t.eq("the final phase is still the euro track", PhaseMusic.final_plan("brindle", func(_id): return true)["track"], "euro-brindle-p3")


func _shelf_rows() -> void:
	for zone in ZONES:
		var pack := _manifest(zone)
		_t.check("%s roams at 172" % zone, int(pack["clips"]["calm"]["bpm"]) == 172 and int(pack["clips"]["travel"]["bpm"]) == 172)
		var inside := true
		for section in WARDEN_SECTIONS:
			if pack["sections"].has(section) and String(pack["sections"][section]["clip"]) in ["calm", "travel"]:
				inside = false
		_t.check("%s: no Warden section plays the roaming shelf" % zone, inside)
		_t.check("%s's Warden build is on the 129 grid" % zone, int(pack["clips"]["build"]["bpm"]) == 129)


# The pivot from the roaming shelf into the Warden's combat clips crosses on the drums alone:
# the shelf's bass and lead are silent at the downbeat, so two keys never overlap.
func _pivot_heard() -> void:
	var heard := 0
	for zone in ZONES:
		var path := String(MusicRows.ROWS[zone]["ace_manifest"])
		if not MusicRows.pack_on_disk(path):
			print("SKIP control %s pivot PCM: its Oggs are not in this checkout" % zone)
			continue
		heard += 1
		var band := Ace.new(path)
		band.start_level(0)
		band.render(band.grid_bar * 2)
		band.commit_warden()
		var at := int(band.pending.get("at", -1))
		_t.check("%s schedules the pivot" % zone, at > band.clock and band.pending.get("section", "") == "pivot")
		band.render(maxi(at - band.clock - 64, 1))
		var harmony := 0.0
		var drums := 0.0
		for v in band.voices + band.fading:
			if v in band.pending.get("voices", []):
				continue
			if v.stem == "drums" and not v.cleared:
				drums = maxf(drums, v.gain)
			elif v.stem != "drums":
				harmony = maxf(harmony, v.gain)
		_t.check("%s's shelf harmony is out before the pivot" % zone, harmony < 0.02, "gain %.3f" % harmony)
		_t.check("%s's shelf drums carry to the pivot's downbeat" % zone, drums > 0.1, "gain %.3f" % drums)
		band.render(band.grid_beat)
		_t.eq("%s lands on the pivot" % zone, band.section, "pivot")
		_t.check("%s pivots with no short reads" % zone, band.short_reads == 0 and band.misses == 0)
	print("PICK_SLOTS pivots=%d heard=%d" % [ZONES.size(), heard])


func _rig(on_disk: Dictionary) -> Rig:
	var events := GameEvents.new()
	var ctx := FakeCtx.new()
	ctx.events = events
	var audio := Rig.new()
	audio.setup(ctx)
	audio.bake_now()
	audio.title_available = func(row: String) -> bool: return on_disk.has(row)
	audio.set_meta("events", events)
	_nodes.append_array([events, audio])
	return audio


func _last(rig: Rig) -> Array:
	return [] if rig.named.is_empty() else [rig.named[-1][0], rig.named[-1][2]]


func _last_id(rig: Rig) -> String:
	return "" if rig.named.is_empty() else String(rig.named[-1][0])


func _manifest(row: String) -> Dictionary:
	return _manifest_at(String(MusicRows.ROWS[row]["ace_manifest"]))


func _manifest_at(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _bpms(m: Dictionary) -> Array:
	var out := []
	for clip in m["clips"].values():
		if not int(clip["bpm"]) in out:
			out.append(int(clip["bpm"]))
	return out
