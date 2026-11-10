extends RefCounted

const RunStatus := preload("res://src/ui/run_status.gd")

# The difficulty steps on the run plate (ui/run_status.gd): a ramp of rising steps, the lowest
# always lit and one more per threat tier, inside the plate. It was a filled red bar, and six
# of six blind readers of one still took that bar for their health.


func run(t) -> void:
	var plate = RunStatus.new()
	var lit := []
	for tier in [0, 1, 2, 9, -3]:
		plate.set_status(1, 3, true, false, tier)
		lit.append(plate.steps_lit())
	t.check("the lowest step is always lit and each tier lights one more", lit == [1, 2, 3, 3, 1] and RunStatus.steps() == RunStatus.THREAT_TIERS + 1, "lit %s of %d" % [lit, RunStatus.steps()])
	var origin := Vector2(RunStatus.BAR_X, plate.size.y - 1.0)
	var rising := true
	var inside := true
	var apart := true
	var last_right := -INF
	var last_top := INF
	for i in RunStatus.steps():
		var step := RunStatus.step_points(i, origin)
		# foot left, top left, top right, foot right
		rising = rising and step[2].y < step[1].y and step[1].y < step[0].y and step[2].y < last_top
		apart = apart and step[0].x > last_right
		for point in step:
			inside = inside and point.x >= 0.0 and point.x <= plate.size.x and point.y >= RunStatus.PIP and point.y <= plate.size.y
		last_right = step[3].x
		last_top = step[2].y
	t.check("each step rises along its top and stands taller than the one before", rising, "last top %.1f" % last_top)
	t.check("the steps stand apart, so they read as a level and not as one bar", apart, "last right edge %.1f" % last_right)
	t.check("the ramp stays inside the plate and under the stage pips", inside, "plate %s" % plate.size)
	var first := RunStatus.step_points(0, origin)
	var top := RunStatus.step_points(RunStatus.steps() - 1, origin)
	t.check("the top step is the ramp's full height and the first has a foot", is_equal_approx(origin.y - top[2].y, RunStatus.STEP.y) and first[1].y < first[0].y,
		"top %.1f of %.1f, first foot %.1f" % [origin.y - top[2].y, RunStatus.STEP.y, first[0].y - first[1].y])
	t.check("the steps carry their word, inside the plate", Array(plate.drawn_words()) == [RunStatus.THREAT_WORD] and RunStatus.THREAT_WORD == "THREAT"
			and RunStatus.word_left() > top[3].x and plate.size.x >= RunStatus.PLATE_WIDTH,
		"words %s, word at %.1f after %.1f, plate %.1f wide" % [plate.drawn_words(), RunStatus.word_left(), top[3].x, plate.size.x])
	plate.free()
