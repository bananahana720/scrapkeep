extends SceneTree

const EdgeMarkers := preload("res://src/ui/edge_markers.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Palette := preload("res://src/core/palette.gd")

# Rule (PF-16): an event announced with a lead and a place points the edge marker at that place
# through its lead, in the warning colour with the event glyph, and no longer: the marker goes
# when the lead runs out (or the event starts or ends, through the bus). In view the place wears
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
	_t.eq("gone once the lead runs out", m.incoming_targets().size(), 0)
	m.note_incoming("bench_dropship", 4.0, at)
	m.note_incoming("bench_dropship", 4.0, Vector3.INF)
	_t.eq("a re-announcement with no place clears it", m.incoming_targets().size(), 0)
	_t.check("the announcement colour is the hazard role", EventKinds.color("event_announced") == Palette.HAZARD)
	m.free()
	quit(_t.verdict())
