extends RefCounted

const Indicator := preload("res://src/movement/indicator.gd")

# The aim mark (movement/indicator.gd): a cone the ball would leave along wears one dashed line and a
# root of fill, both starting at its clear edge so they stay off the ball; the root thins to nothing a
# couple of metres on, whatever the cone's length, so it cannot lie across the view as a sheet; and the
# mark's material fades it near the lens. A cone a release commits as an area stays filled flat from its
# apex to its end, with its two edges and its centre line. The ball builds every aim cone in one place.


func run(t) -> void:
	var fill := Color(0.5, 0.9, 0.8, Indicator.FILL_ALPHA)
	var kick := Indicator.cone_fill({"kind": "cone", "aim": true, "length": 5.0, "clear": 1.0}, fill)
	t.check("an aim cone's fill thins to nothing in its own colour", is_zero_approx(kick["far"].a) and kick["far"].r == fill.r and kick["far"].g == fill.g, "%s" % [kick])
	t.check("it starts at the clear edge and reaches a couple of metres on", is_equal_approx(kick["from"] * 5.0, 1.0) and is_equal_approx(kick["reach"] * 5.0, 1.0 + Indicator.AIM_FILL) and Indicator.AIM_FILL < 4.0, "%s" % [kick])
	var sling := Indicator.cone_fill({"kind": "cone", "aim": true, "length": 10.0, "clear": 1.0, "fill": 1.0}, fill)
	t.check("a longer aim cone's fill reaches no further", is_equal_approx(sling["reach"] * 10.0, 1.0 + Indicator.AIM_FILL), "%s" % [sling])
	var stub := Indicator.cone_fill({"kind": "cone", "aim": true, "length": 2.0, "clear": 1.0}, fill)
	t.check("a cone shorter than the reach is filled to its end, thinning", is_equal_approx(stub["reach"], 1.0) and is_zero_approx(stub["far"].a), "%s" % [stub])
	var bare := Indicator.cone_fill({"kind": "cone", "aim": true, "length": 5.0}, fill)
	t.check("an aim cone with no clear edge starts at its apex", is_zero_approx(bare["from"]) and is_equal_approx(bare["reach"] * 5.0, Indicator.AIM_FILL), "%s" % [bare])
	var area := Indicator.cone_fill({"kind": "cone", "length": 14.0, "fill": 0.4}, fill)
	t.check("a committed area stays filled flat from its apex to its end", is_zero_approx(area["from"]) and is_equal_approx(area["reach"], 1.0) and area["far"] == fill, "%s" % [area])

	var record := {"kind": "cone", "apex": Vector3(1.0, 2.0, 3.0), "dir": Vector3(0.0, 0.0, -2.0), "length": 5.0, "half_angle": 0.3}
	var edges := Indicator.cone_tips(record)
	var line := Indicator.cone_tips(record.merged({"aim": true}))
	t.check("an aim cone wears one line, along the direction, to its length", line.size() == 1 and (line[0] as Vector3).is_equal_approx(Vector3(1.0, 2.0, -2.0)), "%s" % [line])
	t.check("an area wears its two edges and its centre line", edges.size() == 3 and (edges[2] as Vector3).is_equal_approx(line[0])
			and absf((edges[0] as Vector3).x - 1.0) > 1.0 and is_equal_approx((edges[0] as Vector3).x - 1.0, 1.0 - (edges[1] as Vector3).x), "%s" % [edges])

	var aim: StandardMaterial3D = Indicator.material(true)
	var plain: StandardMaterial3D = Indicator.material(false)
	t.check("an aim mark fades out near the lens and an area does not", aim.distance_fade_mode == BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
			and is_equal_approx(aim.distance_fade_min_distance, Indicator.LENS_CLEAR) and is_equal_approx(aim.distance_fade_max_distance, Indicator.LENS_FULL)
			and Indicator.LENS_CLEAR > 0.0 and Indicator.LENS_CLEAR < Indicator.LENS_FULL and plain.distance_fade_mode == BaseMaterial3D.DISTANCE_FADE_DISABLED,
		"aim mode %d from %.1f to %.1f m, area mode %d" % [aim.distance_fade_mode, aim.distance_fade_min_distance, aim.distance_fade_max_distance, plain.distance_fade_mode])
	t.check("both say their colours are sRGB, so the keyline stays charcoal on the PC's renderer", aim.vertex_color_is_srgb and plain.vertex_color_is_srgb,
		"aim %s, area %s" % [aim.vertex_color_is_srgb, plain.vertex_color_is_srgb])
	t.check("a record is an aim mark only when it says so", Indicator.is_aim({"aim": true}) and not Indicator.is_aim({"kind": "cone"}) and not Indicator.is_aim({"kind": "ring"}), "")

	var empty := [{"kind": "marks", "points": []}, {"kind": "arc", "points": [Vector3.ZERO]}, {"kind": "arc", "points": []}, {}]
	var full := [{"kind": "marks", "points": [Vector3.ZERO]}, {"kind": "arc", "points": [Vector3.ZERO, Vector3.ONE]}, {"kind": "arc", "points": [Vector3.ZERO], "blocked": true},
		{"kind": "ring"}, {"kind": "line"}, {"kind": "cone", "aim": true}]
	t.check("a record with nothing to draw is left out of the mesh, and only such a record", empty.all(func(shape): return not Indicator.draws(shape)) and full.all(func(shape): return Indicator.draws(shape)),
		"empty %s, full %s" % [empty.map(func(shape): return Indicator.draws(shape)), full.map(func(shape): return Indicator.draws(shape))])

	var source := FileAccess.get_file_as_string("res://src/movement/player_ball.gd")
	var cones := 0
	var aims := 0
	for text in source.split("\n"):
		if text.contains("\"kind\": \"cone\""):
			cones += 1
			aims += 1 if text.contains("\"aim\": true") and text.contains("\"clear\": AIM_CONE_CLEAR") else 0
	t.check("the ball builds its cones in one place, as aim marks that start clear of it", cones == 1 and aims == 1 and source.count("_aim_cone(") == 4, "%d cones, %d aim, %d uses" % [cones, aims, source.count("_aim_cone(") - 1])
