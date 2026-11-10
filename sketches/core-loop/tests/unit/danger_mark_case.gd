extends RefCounted

const DangerMark := preload("res://src/ui/danger_mark.gd")

# The danger mark's own rules (ui/danger_mark.gd): it keeps the run of 0 to 1 and its fill
# grows foot first to the whole diamond, but since wave 36 it never shows over the ball.


func run(t) -> void:
	var mark = DangerMark.new()
	t.check("no warning, no mark", not mark.shown() and mark.rect() == Rect2(), "run %.2f" % mark.run)
	mark.show_run(0.25)
	mark.avoid = Rect2(762.0, 520.0, 76.0, 76.0)
	mark.follow(Vector2(800.0, 601.0))
	# Wave 36 (PF-16): the bang stacked on the aim reticle read as a target mark; the ground
	# mark's growing fill carries the warning, so this mark never stands over the ball.
	t.check("the retired mark stays off the reticle mid-warning", not mark.shown() and mark.rect() == Rect2() and is_equal_approx(mark.run, 0.25),
		"run %.2f, box %s" % [mark.run, mark.rect()])
	mark.show_run(-1.0)
	t.check("the mark goes with the warning", not mark.shown(), "run %.2f" % mark.run)
	mark.show_run(7.0)
	t.check("a run past the landing reads full", is_equal_approx(mark.run, 1.0), "run %.2f" % mark.run)
	mark.free()

	t.check("an unrun warning has no fill", DangerMark.fill_points(10.0, 0.0).is_empty(), "%s" % [DangerMark.fill_points(10.0, 0.0)])
	var low := DangerMark.fill_points(10.0, 0.25)
	t.check("a quarter fills the foot", low.size() == 3 and is_equal_approx(low[0].y, 5.0) and is_equal_approx(low[1].x, 5.0), "%s" % [low])
	var high := DangerMark.fill_points(10.0, 0.75)
	t.check("three quarters fills past the waist", high.size() == 5 and is_equal_approx(high[0].y, -5.0) and is_equal_approx(high[1].x, 5.0), "%s" % [high])
	var full := DangerMark.fill_points(10.0, 1.0)
	t.check("a full run fills the diamond, four corners and no doubled point", full.size() == 4 and is_equal_approx(full[0].y, -10.0) and is_zero_approx(full[0].x), "%s" % [full])
