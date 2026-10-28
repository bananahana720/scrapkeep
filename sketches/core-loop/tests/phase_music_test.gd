extends SceneTree

const Audio := preload("res://src/presentation/audio.gd")
const PhaseMusic := preload("res://src/presentation/phase_music.gd")
const MusicRows := preload("res://src/presentation/music_rows.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const T := preload("res://tests/support/t.gd")

# Boss phase tracks, the hype rule and the champion (INTEGRATION.md section 6, items 5 to 7).
# The decisions are pure (PhaseMusic); the glue is read from what the director asks the ACE
# band to start, with the packs stood in by pack_available. A pack that is not on disk must
# change nothing.

class FakeCtx:
	extends RefCounted
	var events: Node

class Rig:
	extends Audio
	var named: Array = []
	var staged: Array = []
	func ace_wanted() -> bool:
		return true
	func _ace_named(id: String, at: int, _boss := false, _won := true) -> void:
		named.append([id, at])
	func _ace_stage(stage: int, at: int) -> void:
		staged.append([stage, at])

class FakeElite:
	extends Node3D
	signal died(where: Vector3, scrap: int)
	var affix := {"id": "rail_strike"}
	var hp := 100.0
	var max_hp := 100.0

var _t := T.new("phase_music_test")
var _nodes: Array = []


func _initialize() -> void:
	_pure()


func _pure() -> void:
	_t.eq("brindle phase 1", PhaseMusic.track_for_phase("brindle", 1), "brindle-p1-requisition")
	_t.eq("brindle phase 2", PhaseMusic.track_for_phase("brindle", 2), "brindle-p2-furnace")
	_t.eq("brindle phase 3", PhaseMusic.track_for_phase("brindle", 3), "brindle-p3-scuttle")
	_t.eq("the waking keeps its track before the last posture", PhaseMusic.track_for_phase("waking", 2), "")
	_t.eq("the waking final", PhaseMusic.track_for_phase("waking", 3), "waking-final")
	_t.eq("the mind final", PhaseMusic.track_for_phase("mind", 3), "mind-final")
	_t.eq("no track for a level", PhaseMusic.track_for_phase("level", 3), "")
	_t.eq("brindle opens on its anthem when it loads", PhaseMusic.entry_track("brindle", func(_id): return true), "anthem-brindle")
	_t.eq("brindle opens on the picked theme without its anthem", PhaseMusic.entry_track("brindle", func(id): return not id.begins_with("anthem-")), "boss-brindle")
	_t.eq("brindle opens on phase 1 without the pick", PhaseMusic.entry_track("brindle", func(id): return id == "brindle-p1-requisition"), "brindle-p1-requisition")
	_t.eq("brindle opens on its own theme without the packs", PhaseMusic.entry_track("brindle", func(_id): return false), "brindle")
	_t.eq("the mind opens on its anthem", PhaseMusic.entry_track("mind", func(_id): return true), "anthem-mind")
	_t.eq("the mind opens on the picked theme without its anthem", PhaseMusic.entry_track("mind", func(id): return not id.begins_with("anthem-")), "boss-mind")
	_t.eq("the mind opens on its own theme without the pick", PhaseMusic.entry_track("mind", func(_id): return false), "mind")
	_t.eq("euro when it loads", PhaseMusic.final_plan("mind", func(id): return not id.begins_with("anthem-")), {"track": "euro-mind-final", "hype": true})
	_t.eq("the mind's heavier anthem takes its final phase", PhaseMusic.final_plan("mind", func(_id): return true), {"track": "anthem-mind-heavier", "hype": true})
	_t.eq("base final without euro, no drop", PhaseMusic.final_plan("mind", func(id): return id == "mind-final"), {"track": "mind-final", "hype": false})
	_t.eq("nothing without packs", PhaseMusic.final_plan("brindle", func(_id): return false), {"track": "", "hype": false})
	_t.eq("the waking's anthem takes its final phase", PhaseMusic.final_plan("waking", func(_id): return true), {"track": "anthem-waking-heavier", "hype": true})
	_t.eq("the waking's anthem without its heavier take", PhaseMusic.final_plan("waking", func(id): return id == "anthem-waking"), {"track": "anthem-waking", "hype": true})
	_t.eq("a missing heavier take falls back to phase 2, not phase 1", PhaseMusic.final_plan("brindle", func(id): return id in ["anthem-brindle", "anthem-brindle-heavy", "euro-brindle-p3"]), {"track": "anthem-brindle-heavy", "hype": true})
	_t.eq("with no phase 2 or 3 take the euro beats phase 1", PhaseMusic.final_plan("mind", func(id): return id in ["anthem-mind", "euro-mind-final"]), {"track": "euro-mind-final", "hype": true})
	_t.eq("the champion's anthem first", PhaseMusic.champion_final(func(_id): return true), "anthem-champion")
	_t.eq("the champion's euro without its anthem", PhaseMusic.champion_final(func(id): return id == "euro-champion"), "euro-champion")
	_t.eq("no champion final without packs", PhaseMusic.champion_final(func(_id): return false), "")
	var lead := roundi(2.0 * 44100)
	var plan := PhaseMusic.drop_plan(0, 100000, 40000, 44100)
	_t.eq("hype_drop's drop lands on the downbeat", [plan["drop"], plan["start"]], [100000, 100000 - lead])
	plan = PhaseMusic.drop_plan(0, 50000, 40000, 44100)
	_t.check("a too-near downbeat moves a bar at a time", plan["start"] >= 0 and (plan["drop"] - 50000) % 40000 == 0 and plan["drop"] == 90000, str(plan))
	_t.check("champion third", PhaseMusic.champion_in_final_third(33.0, 100.0) and not PhaseMusic.champion_in_final_third(50.0, 100.0))
	for id in PhaseMusic.TRACKS:
		_t.check("%s has a music row" % id, MusicRows.ROWS.has(id) and String(MusicRows.ROWS[id]["ace_manifest"]).ends_with("/%s/manifest.json" % PhaseMusic.theme_of(id)))
	# available() is kept per stem tree: the same answer as a fresh read, read again when stem_dir moves.
	var stems := MusicRows.stem_dir
	MusicRows.stem_dir = "user://no_stems_here"
	_t.check("a pack with no stems under the stem tree is not available", not PhaseMusic.available("brindle-p1-requisition"))
	MusicRows.stem_dir = stems
	_t.eq("the kept answer is the fresh read", PhaseMusic.available("brindle-p1-requisition"), MusicRows.pack_on_disk(PhaseMusic.manifest_of("brindle-p1-requisition")))
	_t.eq("and asking again gives it again", PhaseMusic.available("brindle-p1-requisition"), MusicRows.pack_on_disk(PhaseMusic.manifest_of("brindle-p1-requisition")))


func _rig(avail: Callable) -> Rig:
	var events := GameEvents.new()
	var ctx := FakeCtx.new()
	ctx.events = events
	var audio := Rig.new()
	audio.setup(ctx)
	audio.bake_now()
	audio.pack_available = avail
	audio._phase_music_done = 1
	_nodes.append_array([events, audio])
	return audio


func _process(_delta: float) -> bool:
	var a := _rig(func(_id): return true)
	a.engine.track = "brindle"
	_t.eq("phase 1 is the opening, nothing to start", a.phase_music(1), {})
	var p2 := a.phase_music(2)
	_t.check("phase 2 starts the heavy anthem on the next downbeat", p2.get("track") == "anthem-brindle-heavy" and a.named == [["anthem-brindle-heavy", a.engine.next_bar()]], str(a.named))
	_t.eq("the same phase twice starts nothing", a.phase_music(2), {})
	var p3 := a.phase_music(3)
	_t.check("the last phase drops into the fight anthem", p3.get("track") == "anthem-brindle-heavier" and p3.get("hype") == true, str(p3))
	var hype := a.cue_log.filter(func(c): return c[1] == "hype_drop")
	_t.check("hype_drop starts two seconds before the drop", hype.size() == 1 and int(p3["at"]) - int(hype[0][3]) == roundi(2.0 * 44100), str(hype))
	_t.eq("the anthem enters on the drop", a.named[-1], ["anthem-brindle-heavier", p3["at"]])

	a = _rig(func(id): return not id.begins_with("anthem-"))
	a.engine.track = "brindle"
	_t.eq("without anthems phase 2 plays the furnace", a.phase_music(2).get("track"), "brindle-p2-furnace")
	_t.eq("without anthems the last phase is the euro track", a.phase_music(3).get("track"), "euro-brindle-p3")

	a = _rig(func(_id): return true)
	a.engine.track = "waking"
	_t.eq("the waking's middle phase moves to its heavy anthem", a.phase_music(2).get("track"), "anthem-waking-heavy")
	_t.check("the waking's last phase goes to its anthem", a.phase_music(3).get("track") == "anthem-waking-heavier")

	a = _rig(func(id): return id == "waking-final")
	a.engine.track = "waking"
	var fb := a.phase_music(3)
	_t.check("without euro the base final track plays, no drop", fb.get("track") == "waking-final" and a.cue_log.filter(func(c): return c[1] == "hype_drop").is_empty(), str(fb))

	a = _rig(func(_id): return false)
	a.engine.track = "brindle"
	a.phase_music(2)
	a.phase_music(3)
	_t.check("no packs on disk changes nothing", a.named.is_empty())

	a = _rig(func(_id): return true)
	a.engine.track = "level"
	_t.eq("a level track is no boss", a.phase_music(3), {})

	_champion()
	for node in _nodes:
		node.free()
	quit(_t.verdict())
	return true


func _champion() -> void:
	var a := _rig(func(_id): return true)
	a._stage_now = 4
	var e1 := FakeElite.new()
	var e2 := FakeElite.new()
	root.add_child(e1)
	root.add_child(e2)
	a._on_enemy_spawned(e1, "plated_brute")
	_t.check("an elite moves the band to champion-hype on a downbeat", a.named == [["champion-hype", a.engine.next_bar()]], str(a.named))
	a._on_enemy_spawned(e2, "plated_brute")
	_t.eq("a second elite does not restart it", a.named.size(), 1)
	e1.hp = 30.0
	a._tend_champions()
	_t.check("the final third drops into the champion anthem", a.named.size() == 2 and a.named[1][0] == "anthem-champion", str(a.named))
	_t.check("with a hype drop before it", not a.cue_log.filter(func(c): return c[1] == "hype_drop" or c[0] == "champion_final").is_empty())
	a._tend_champions()
	_t.eq("once per champion", a.named.size(), 2)
	e1.died.emit(Vector3.ZERO, 0)
	_t.eq("one champion alive keeps the hype", a.staged, [])
	e2.died.emit(Vector3.ZERO, 0)
	_t.eq("the last champion's death returns to the stage's band", a.staged, [[4, a.engine.next_bar()]])
	var plain := FakeElite.new()
	plain.affix = {}
	root.add_child(plain)
	var before := a.named.size()
	a._on_enemy_spawned(plain, "chaser")
	_t.eq("an ordinary enemy is no champion", a.named.size(), before)
	var b := _rig(func(_id): return false)
	var e3 := FakeElite.new()
	root.add_child(e3)
	b._on_enemy_spawned(e3, "plated_brute")
	_t.check("without the pack the band is left alone", b.named.is_empty() and not b._champion_hyped)
	for n in [e1, e2, e3, plain]:
		n.free()
