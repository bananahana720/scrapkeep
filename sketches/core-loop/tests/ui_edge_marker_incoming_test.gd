extends SceneTree

const EdgeMarkers := preload("res://src/ui/edge_markers.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Palette := preload("res://src/core/palette.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const EventDirector := preload("res://src/world/event_director.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")

# Rule (PF-16): an event announced with a lead and a place points the edge marker at that place
# through its lead, in the warning colour with the event glyph, and no longer: the marker goes
# while the event is still coming: the lead running out does not drop it, since the director can
# hold an announced event for clear ground, and it goes when the event starts or ends or the stage
# or run resets (through the bus). In view the place wears
# brackets instead of the edge chevron (W1-04), so the target is a mark. The weather, the flood
# and a squall have no one place (Vector3.INF) and get none; nor does an event with no lead.

var _t := preload("res://tests/support/t.gd").new("ui_edge_marker_incoming_test")


func _initialize() -> void:
	var m = EdgeMarkers.new()
	var at := Vector3(40.0, 3.0, -12.0)
	m.note_incoming("dome_lightning", 6.0, at)
	m.note_incoming("monsoon_buildup", 20.0, Vector3.INF)
	m.note_incoming("dawn_still", 0.0, Vector3(1.0, 0.0, 1.0))
	var shown: Array = m.incoming_targets()
	_t.eq("only the placed event with a lead is marked", shown.size(), 1)
	if shown.size() == 1:
		_t.check("it points at the published place", shown[0]["at"] == at, str(shown[0]))
		_t.check("in the warning colour", EdgeMarkers.marker_color(shown[0]) == Palette.HAZARD, str(EdgeMarkers.marker_color(shown[0])))
		_t.eq("with the event glyph", shown[0]["icon"], "obj_event")
		_t.check("and brackets on the place once it is in view", shown[0].get("mark", false) and String(shown[0].get("tag", "")) == "", str(shown[0]))
	m.step_incoming(5.9)
	_t.eq("still up inside its lead", m.incoming_targets().size(), 1)
	m.step_incoming(0.2)
	_t.eq("still up once the lead has run out: the event may be waiting for clear ground", m.incoming_targets().size(), 1)
	m.step_incoming(5.0)
	_t.eq("and after a long wait", m.incoming_targets().size(), 1)
	m.note_incoming("bench_dropship", 4.0, at)
	_t.eq("a second placed event is marked beside the first", m.incoming_targets().size(), 2)
	m.note_incoming("bench_dropship", 4.0, Vector3.INF)
	_t.eq("a re-announcement with no place clears only that event", m.incoming_targets().size(), 1)
	m.note_incoming("dome_lightning", 0.0, at)
	_t.eq("and one with no lead clears the other", m.incoming_targets().size(), 0)
	_t.check("the announcement colour is the hazard role", EventKinds.color("event_announced") == Palette.HAZARD)
	m.free()
	_bus_clears()
	_through_a_hold()
	quit(_t.verdict())


func _bus_clears() -> void:
	var bus := GameEvents.new()
	var m = EdgeMarkers.new()
	m.setup({"events": bus})
	var at := Vector3(8.0, 0.0, 8.0)
	bus.event_announced.emit("dome_lightning", 2.0, at)
	m.step_incoming(5.0)
	_t.eq("a 2 s lead stepped 5 s with no start is still marked", m.incoming_targets().size(), 1)
	if m.incoming_targets().size() == 1:
		_t.check("at the published place", m.incoming_targets()[0]["at"] == at)
	bus.event_started.emit("dome_lightning")
	_t.eq("event_started removes it", m.incoming_targets().size(), 0)
	bus.event_announced.emit("dome_lightning", 2.0, at)
	bus.event_ended.emit("dome_lightning", "passed")
	_t.eq("event_ended removes it", m.incoming_targets().size(), 0)
	bus.event_announced.emit("dome_lightning", 2.0, at)
	bus.event_started.emit("another_event")
	_t.eq("another event's start leaves it", m.incoming_targets().size(), 1)
	bus.stage_entered.emit(2, false)
	_t.eq("stage_entered clears it", m.incoming_targets().size(), 0)
	bus.event_announced.emit("dome_lightning", 2.0, at)
	bus.run_started.emit("any_class")
	_t.eq("run_started clears it", m.incoming_targets().size(), 0)
	m.free()
	bus.free()


# The real director on the dam map with the ball standing in the flood pool's footprint: the event
# is announced, cannot land while the ball is inside, and lands once the ball walks clear. The
# marker is fed the director's own facts the way world.gd publishes them.
func _through_a_hold() -> void:
	var id := "plunge_pool_flood"
	var park := ParkMap.new("res://src/world/park/park_dam.json")
	_t.check("the dam map loads", park.ok)
	if not park.ok:
		return
	var row: Dictionary = park.park.event_rows.filter(func(r): return r.id == id).front()
	var site: Dictionary = park.park.park_rows.filter(func(r): return r.id == row.site).front()
	park.park.event_rows = [row]
	park.park.weather_rows = []
	var inside := Vector2(float(site.at[0]), float(site.at[1]))
	var clear := inside + Vector2(ParkMap.footprint_half_extents(site).x + float(row.hold_clear_m) + 10.0, 0.0)
	var director := EventDirector.new(823, {}, park, 14.0, func(_x: float, _z: float) -> float: return 0.0)
	var m = EdgeMarkers.new()
	var due := -1.0
	var started := false
	var held_with_marker := 0
	var point := inside
	for tick in 700:
		if started:
			break
		if due > 0.0 and director.stage_time > due + 20.0:
			point = clear
		for fact in director.advance(0.1, Vector3(point.x, 1.2, point.y), Vector3.ZERO, {"clock_tier": 1, "grounded": true}):
			if fact.id != id:
				continue
			match fact.kind:
				"announced":
					due = fact.landing_s
					m.note_incoming(id, fact.seconds, fact.at)
				"started":
					started = true
		m.step_incoming(0.1)
		if due > 0.0 and director.stage_time > due + 2.0 and not started and m.incoming_targets().size() == 1:
			held_with_marker += 1
	_t.check("the event was announced", due > 0.0)
	_t.check("the director held it past its due time with the marker up", held_with_marker > 100, str(held_with_marker))
	_t.check("and it landed once the ball was clear", started)
	m.free()
