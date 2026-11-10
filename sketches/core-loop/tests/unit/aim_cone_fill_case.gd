extends RefCounted

const Indicator := preload("res://src/movement/indicator.gd")

# The aim cone's fill (movement/indicator.gd cone_fill): a cone the ball would leave along wears a root of
# fill at the ball that thins to nothing a few metres out, whatever its length, so it cannot lie across
# the view as a sheet; a cone a release commits as an area stays filled flat to its end. The three aim
# cones the ball draws (vault kick, slingshot, bank shot) say so.


func run(t) -> void:
	var fill := Color(0.5, 0.9, 0.8, Indicator.FILL_ALPHA)
	var kick := Indicator.cone_fill({"kind": "cone", "aim": true, "length": 5.0}, fill)
	t.check("an aim cone's fill thins to nothing in its own colour", is_zero_approx(kick["far"].a) and kick["far"].r == fill.r and kick["far"].g == fill.g, "%s" % [kick])
	t.check("and reaches a few metres from the ball", is_equal_approx(kick["reach"] * 5.0, Indicator.AIM_FILL) and Indicator.AIM_FILL < 5.0, "%s" % [kick])
	var sling := Indicator.cone_fill({"kind": "cone", "aim": true, "length": 10.0, "fill": 1.0}, fill)
	t.check("a longer aim cone's fill reaches no further", is_equal_approx(sling["reach"] * 10.0, Indicator.AIM_FILL), "%s" % [sling])
	var stub := Indicator.cone_fill({"kind": "cone", "aim": true, "length": 2.0}, fill)
	t.check("a cone shorter than the reach is filled to its end, thinning", is_equal_approx(stub["reach"], 1.0) and is_zero_approx(stub["far"].a), "%s" % [stub])
	var area := Indicator.cone_fill({"kind": "cone", "length": 14.0, "fill": 0.4}, fill)
	t.check("a committed area stays filled flat to its end", is_equal_approx(area["reach"], 1.0) and area["far"] == fill, "%s" % [area])

	var source := FileAccess.get_file_as_string("res://src/movement/player_ball.gd")
	var cones := 0
	var aims := 0
	for line in source.split("\n"):
		if line.contains("\"kind\": \"cone\""):
			cones += 1
			aims += 1 if line.contains("\"aim\": true") else 0
	t.check("every cone the ball draws is an aim cone", cones == 3 and aims == cones, "%d cones, %d aim" % [cones, aims])
