extends SceneTree

const Director := preload("res://src/world/event_director.gd")
const Schema := preload("res://src/world/park/park_schema.gd")
const T := preload("res://tests/support/t.gd")
var t := T.new("park_permanent_capacity_test")

class Map:
	extends RefCounted
	var park := {}

func _initialize() -> void:
	var map := Map.new()
	map.park = Schema.read_file("res://src/world/park/park_dam.json").data.duplicate(true)
	var template: Dictionary = map.park.event_rows[0].duplicate(true)
	map.park.event_rows = []
	for i in 3:
		var row := template.duplicate(true)
		row.id = "permanent_" + str(i)
		row.live_s = 0.0
		row.effect.fill_s = 4.0
		row.route_change = {"opens": [], "closes": []}
		map.park.event_rows.append(row)
	var d = Director.new(823, {}, map, 14.0, func(_x, _z): return 0.0)
	var a: Dictionary = d._park_states[0]
	var b: Dictionary = d._park_states[1]
	var candidate: Dictionary = d._park_states[2]
	a.phase = Director.LIVE
	b.phase = Director.LIVE
	candidate.phase = Director.ANNOUNCED
	for elapsed in [0.0, 2.0, 3.9]:
		a.live_elapsed_s = elapsed
		b.live_elapsed_s = elapsed
		t.check("two transforming permanent rows occupy ground slots at %s" % elapsed, not d._park_capacity(candidate))
	a.live_elapsed_s = 4.0
	b.live_elapsed_s = 4.0
	t.check("settled permanent effects free scheduling capacity", d._park_capacity(candidate))
	t.eq("settled effects retain LIVE lifecycle", a.phase, Director.LIVE)
	t.eq("settled effects keep authored lifetime", a.row.live_s, 0.0)
	# Ordinary timed effects keep their slots until ending, even after fill_s.
	a.row.live_s = 10.0
	b.row.live_s = 10.0
	t.check("timed effects still consume capacity after fill", not d._park_capacity(candidate))
	quit(t.verdict())
