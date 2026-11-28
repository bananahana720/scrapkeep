extends SceneTree

const MusicEngine := preload("res://src/presentation/music_engine.gd")
const MusicPrebake := preload("res://src/presentation/music_prebake.gd")
const T := preload("res://tests/support/t.gd")

# Track entry owns the band's fight state (music_engine.gd _end_escalation_build and
# drop_pending_track): a crew event's escalation riser ends when a fight track lands, a launch
# or ultimate build (start_build) carries through, and a fight that ends inside the bar before
# its track lands takes the queued switch with it. Engine only, rendered offline.
# Evidence limit: the band's state, not how the change sounds.

var _t := T.new("music_track_entry_test")


func _initialize() -> void:
	MusicPrebake.prepare()
	_escalation_build_ends_on_track()
	_start_build_carries()
	_pending_miniboss_dropped()
	_pending_warden_dropped()
	quit(_t.verdict())


func _level() -> MusicEngine:
	var engine := MusicEngine.new()
	engine.force_track("level", 0)
	return engine


func _past(engine: MusicEngine, at: int) -> void:
	engine.render(maxi(at - engine.clock, 0) + engine.bar_len() + 64)


func _escalation_build_ends_on_track() -> void:
	var engine := _level()
	engine.escalate(0.9, false)
	var built := engine.building()
	var at := engine.begin_boss("warden")
	_past(engine, at)
	_t.check("event riser ends on the Warden track", built and engine.track == "warden" and not engine.building(),
		"escalated %s, then track %s building %s" % [built, engine.track, engine.building()])


func _start_build_carries() -> void:
	var engine := _level()
	engine.start_build(8.0, true)
	var at := engine.begin_boss("warden")
	_past(engine, at)
	_t.check("a start_build riser carries through a track change", engine.track == "warden" and engine.building(),
		"track %s building %s" % [engine.track, engine.building()])


func _pending_miniboss_dropped() -> void:
	var engine := _level()
	var at := engine.begin_miniboss()
	var dropped := engine.drop_pending_track("miniboss")
	_past(engine, at)
	_t.check("a miniboss gone before its bar leaves the level playing", at >= 0 and dropped and engine.track == "level",
		"queued at %d, dropped %s, track %s" % [at, dropped, engine.track])
	_t.check("nothing left to drop", not engine.drop_pending_track("miniboss"), "second drop")


func _pending_warden_dropped() -> void:
	var engine := _level()
	var at := engine.begin_boss("warden")
	var dropped := engine.drop_pending_track("warden")
	_past(engine, at + engine.bar_len())
	_t.check("a Warden broken in its pivot bar never enters its track", dropped and engine.track == "level",
		"dropped %s, track %s" % [dropped, engine.track])
