extends SceneTree

# Packs land on the route the ball is riding (director.gd HOME_CONE, LINE_AHEAD, LINE_SIDE, facing, _line_spot):
# 1. facing(): inside the cone, outside it, and true with no heading.
# 2. On the staged dam director, a ball heading down a pilot line gets free spots that sit LINE_AHEAD ahead, beside a
#    line point (LINE_SIDE off it) and off every corridor. Planted: heading away from every line ahead gives none.
# 3. A crew home behind the ball's heading is out of the window that a heading-less call (the breather's) still sees.

const T := preload("res://tests/support/t.gd")
const Director := preload("res://src/world/director.gd")
const ParkDefs := preload("res://src/core/park_defs.gd")

var t := T.new("director_route_test")


func _initialize() -> void:
	_facing()
	_line_spots()
	_homes_by_heading()
	quit(t.verdict())


func _facing() -> void:
	t.check("straight ahead faces", Director.facing(Vector2(0, 1), Vector2(0, 50), Director.HOME_CONE))
	t.check("40 degrees off faces a 50 degree cone", Director.facing(Vector2(0, 1), Vector2(0, 50).rotated(deg_to_rad(40.0)), Director.HOME_CONE))
	t.check("90 degrees off does not", not Director.facing(Vector2(0, 1), Vector2(50, 0), Director.HOME_CONE))
	t.check("no heading faces everything", Director.facing(Vector2.ZERO, Vector2(-50, 0), Director.HOME_CONE))


static func _staged() -> Director:
	var d := Director.new(3101)
	var row: Dictionary = ParkDefs.DEFS[0]
	d.author(row, ParkDefs)
	d.use_row(row)
	d.breathers = []
	# world.gd sets the park's play rect on stage entry; the staged director keeps the default small one.
	d.play_rect = Rect2(-800.0, -800.0, 1600.0, 1600.0)
	return d


# A pilot line point and the heading along the line there.
static func _on_line(d: Director) -> Array:
	var line: Array = d._corridors._park_pilot_lines[0]
	var i := int(line.size() / 3)
	return [line[i], (line[i + 4] - line[i]).normalized()]


func _line_spots() -> void:
	var d := _staged()
	t.check("the staged dam director has pilot lines", d._corridors != null and not d._corridors._park_pilot_lines.is_empty())
	if d._corridors == null or d._corridors._park_pilot_lines.is_empty():
		return
	var at: Array = _on_line(d)
	var ball: Vector2 = at[0]
	var heading: Vector2 = at[1]
	var placed := 0
	var good := 0
	for i in 20:
		var spot := d._line_spot(ball, heading)
		if spot == Vector2.INF:
			continue
		placed += 1
		var near_line := INF
		for line in d._corridors._park_pilot_lines:
			for k in range(1, line.size()):
				var on := Geometry2D.get_closest_point_to_segment(spot, line[k - 1], line[k])
				near_line = minf(near_line, on.distance_to(spot))
		var dist := spot.distance_to(ball)
		if near_line <= Director.LINE_SIDE.y + 1.0 and dist >= Director.LINE_AHEAD.x - Director.LINE_SIDE.y \
				and dist <= Director.LINE_AHEAD.y + Director.LINE_SIDE.y and d._park_safe(spot):
			good += 1
	t.check("dam: a ball riding a line gets spots beside the line ahead", placed >= 10, "%d of 20" % placed)
	t.eq("each one is beside a line, ahead and off every corridor", good, placed)
	t.eq("planted: heading straight away from the lines ahead gives no line spot",
		_staged()._line_spot(ball + heading * -400.0, -heading), Vector2.INF)


func _homes_by_heading() -> void:
	var d := _staged()
	var found := false
	for home in d.homes:
		var at: Vector2 = d._home_at(home)
		# A ball 120 m short of the home along the landmark distance, facing away from it.
		for probe in [Vector2(0, -120), Vector2(0, 120), Vector2(-120, 0), Vector2(120, 0)]:
			var ball: Vector2 = at + probe
			if d._window_homes(ball).has(home):
				found = true
				t.check("%s: in the window facing it" % home.id, d._window_homes(ball, -probe.normalized()).has(home))
				t.check("%s: out of the window facing away" % home.id, not d._window_homes(ball, probe.normalized()).has(home))
				break
		if found:
			break
	t.check("a crew home was found in some ball's window to test", found)
