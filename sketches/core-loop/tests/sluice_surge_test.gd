extends SceneTree

# The flume's surge course (activities.gd surge_run, surge_course.gd) and its sluice (the park's sluice_surge event row).
# (a) the flume park carries the course row and the sluice row and validates, and the schema names a
#     sluice that opens on anything but its activity, a trigger naming no activity row, and a course with no route;
# (b) the sluice's two forms have WORLD_ROWS records in the water colour, never the hazard one, and the land fact maps;
# (c) the director never opens the sluice unasked; notify_activity announces it on the bar after its lead, it lands
#     with sluice_landed and goes live, and finish_activity ends it early, or before it lands when the course ends first;
# (d) the course runs down flume_upper's grind rows from the head nearest the ring, six gates on their own rows' tops
#     (the weir reach's deck above the gap reach's);
# (e) a ball on the ground under the deck takes no gate and gets no push; on the deck it takes the gate, and the front
#     only ever pushes it on.

const ParkSchema := preload("res://src/world/park/park_schema.gd")
const Director := preload("res://src/world/event_director.gd")
const Kinds := preload("res://src/core/event_kinds.gd")
const Palette := preload("res://src/core/palette.gd")
const SurgeCourse := preload("res://src/world/surge_course.gd")
const SurgeRun := preload("res://src/world/surge_run.gd")

const PARK := "res://src/world/park/park_flume.json"
const H := 1.0 / 60.0
const FAR := Vector3(1000.0, 1.0, 1000.0)
const BAR_S := 240.0 / 172.0
const RING := Vector2(-418.0, -583.0)
# The weir reach's top (its y 104.4 plus its 5 m height); the gap reach's top stands well below it.
const UPPER_Y := 109.4
const EXPECTED_CHECKS := 20

var _t := preload("res://tests/support/t.gd").new("sluice_surge_test")
var _checks := 0


class Map:
	extends RefCounted
	var park := {}


var _course_row := {}
var _sluice_row := {}


func _initialize() -> void:
	var park: Dictionary = ParkSchema.read_file(PARK).data
	_course_row = _row(park.activity_rows, "weir_surge")
	_sluice_row = _row(park.event_rows, "head_gate_sluice")
	_check("(a) the flume carries the course and the sluice", not _course_row.is_empty() and not _sluice_row.is_empty())
	_schema(park)
	_records()
	_director(park)
	_course(park)
	_t.check("every check ran", _checks == EXPECTED_CHECKS, "%d checks" % _checks)
	quit(_t.verdict())


func _check(label: String, ok: bool, detail := "") -> void:
	_checks += 1
	_t.check(label, ok, detail)


func _row(rows: Array, id: String) -> Dictionary:
	for r in rows:
		if String(r.id) == id:
			return r
	return {}


# The park with its course and sluice rows swapped for these (a planted variant).
func _with(park: Dictionary, course: Dictionary, sluice: Dictionary) -> Dictionary:
	var out := park.duplicate(true)
	out.activity_rows = out.activity_rows.filter(func(r): return r.id != course.id)
	out.event_rows = out.event_rows.filter(func(r): return r.id != sluice.id)
	out.activity_rows.append(course.duplicate(true))
	out.event_rows.append(sluice.duplicate(true))
	return out


func _errors_for(park: Dictionary, ids: Array) -> Array:
	return ParkSchema.validate(park).filter(func(e): return String(e.get("id", "")) in ids)


func _schema(park: Dictionary) -> void:
	var errors := ParkSchema.validate(park)
	_check("(a) the flume validates with them", errors.is_empty(), ParkSchema.describe(errors))
	var clock := _sluice_row.duplicate(true)
	clock.trigger = {"on": "clock_tier", "value": 1}
	_check("(a) a sluice on the clock is named", not _errors_for(_with(park, _course_row, clock), ["head_gate_sluice"]).is_empty())
	var stray := _sluice_row.duplicate(true)
	stray.trigger = {"on": "activity", "value": "no_such_course"}
	_check("(a) a trigger naming no activity row is named", not _errors_for(_with(park, _course_row, stray), ["head_gate_sluice"]).is_empty())
	var lost := _course_row.duplicate(true)
	lost.erase("route")
	_check("(a) a course with no route is named", not _errors_for(_with(park, lost, _sluice_row), ["weir_surge"]).is_empty())


func _records() -> void:
	var siren: Dictionary = Kinds.world_row("sluice_siren")
	var landed: Dictionary = Kinds.world_row("sluice_landed")
	_check("(b) both forms have records", not siren.is_empty() and not landed.is_empty())
	_check("(b) the water colour, never the hazard one", siren.get("color") == Palette.VERDIGRIS and landed.get("color") == Palette.VERDIGRIS)
	_check("(b) the siren lands as sluice_landed", Director.PARK_LAND_FACTS.get("sluice_siren", "") == "sluice_landed")


func _run(d, ticks: int, notify_at := -1, finish_at := -1) -> Array:
	var facts := []
	for i in ticks:
		if i == notify_at:
			d.notify_activity("weir_surge")
		if i == finish_at:
			facts.append_array(d.finish_activity("weir_surge"))
		var ctx := {"clock_tier": 4, "grounded": true, "bar_s": BAR_S, "bar_origin_s": 0.0}
		facts.append_array(d.advance(H, FAR, Vector3.ZERO, ctx))
	return facts


func _director(park: Dictionary) -> void:
	var map := Map.new()
	map.park = park
	var quiet = Director.new(7, {}, map, 14.0, func(_x, _z): return 0.0)
	var unasked := _run(quiet, 3600).filter(func(f): return f.id == "head_gate_sluice")
	_check("(c) never opens unasked", unasked.is_empty(), str(unasked.size()))
	var d = Director.new(7, {}, map, 14.0, func(_x, _z): return 0.0)
	var facts := _run(d, 1800, 60, 1200).filter(func(f): return f.id == "head_gate_sluice")
	var announced = facts.filter(func(f): return f.kind == "announced")
	var landed = facts.filter(func(f): return f.kind == "world" and f.get("phase", "") == "land")
	var ended = facts.filter(func(f): return f.kind == "ended")
	var lead: float = landed[0].time_s - announced[0].time_s if not announced.is_empty() and not landed.is_empty() else -1.0
	_check("(c) announced once, then lands after its lead", announced.size() == 1 and landed.size() == 1 and lead >= 4.0 - H, "lead %.2f" % lead)
	var phase: float = fmod(landed[0].time_s, BAR_S) if not landed.is_empty() else -1.0
	_check("(c) lands on the bar with sluice_landed", not landed.is_empty() and landed[0].fact == "sluice_landed"
		and minf(phase, BAR_S - phase) < H * 1.5, "bar phase %.3f" % phase)
	_check("(c) finish_activity ends it before live_s", ended.size() == 1 and ended[0].time_s < 1200 * H + H, str(ended))
	# The course is over (fallback started it and it ended) while the sluice is still announced: it ends, never lands.
	var early = Director.new(7, {}, map, 14.0, func(_x, _z): return 0.0)
	var cut := _run(early, 1800, 60, 120).filter(func(f): return f.id == "head_gate_sluice")
	_check("(c) a sluice still announced ends with its course and never lands",
		cut.filter(func(f): return f.kind == "announced").size() == 1 and cut.filter(func(f): return f.kind == "ended").size() == 1
		and cut.filter(func(f): return f.kind == "world" and f.get("phase", "") == "land").is_empty(), str(cut.map(func(f): return f.kind)))


func _course(park: Dictionary) -> void:
	var course := SurgeCourse.new()
	course.setup({"ring": RING, "route": "flume_upper"}, 14.0, park, func(_x, _z): return 0.0)
	var model = course.model
	var head: Vector2 = model.route.points[0]
	_check("(d) the course starts at the head nearest the ring", head.distance_to(RING) < 60.0, str(head))
	_check("(d) six gates down two rows", model.gates.size() == SurgeRun.GATE_COUNT and model.route.total > 400.0, "%d gates over %.0f m" % [model.gates.size(), model.route.total])
	var first: float = model.gate_heights[0]
	var last: float = model.gate_heights[model.gate_heights.size() - 1]
	_check("(d) gates stand on their own decks", absf(first - UPPER_Y) < 0.1 and last < UPPER_Y - 10.0, str(model.gate_heights))
	model.begin()
	var g: Vector2 = model.gates[0]
	var under := Vector3(g.x, model.gate_heights[0] - 40.0, g.y)
	model.step(H, under, Vector3.ZERO)
	_check("(e) under the deck takes no gate", model.next_gate == 0)
	model.front = model.gate_distances[0] - 4.0
	_check("(e) under the deck gets no push", model.push(under, Vector3.ZERO) == Vector3.ZERO)
	var on := Vector3(g.x, model.gate_heights[0] + 1.0, g.y)
	var pushed: Vector3 = Director.never_brake(model.push(on, Vector3.ZERO), Vector3.ZERO)
	var along: Vector2 = model.route.tangent(model.gate_distances[0])
	_check("(e) on the deck the front pushes it on", pushed.length() > 0.0 and Vector2(pushed.x, pushed.z).dot(along) > 0.0, str(pushed))
	model.front = SurgeRun.FRONT_START
	model.step(H, on, Vector3.ZERO)
	_check("(e) on the deck it takes the gate", model.next_gate == 1)
	course.free()
