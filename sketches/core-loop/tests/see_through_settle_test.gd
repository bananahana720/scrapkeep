extends SceneTree

# See-through shapes thin out once read (W1-12, PF-27): a synergy ring round the ball is whole
# while it is news and settles faint for the rest of the run.

const T := preload("res://tests/support/t.gd")
const Vfx := preload("res://src/presentation/vfx.gd")


func _initialize() -> void:
	var t := T.new("see_through_settle_test")
	var news := Vfx.ring_alpha(0.0)
	var read := Vfx.ring_alpha(Vfx.RING_READ)
	var settled := Vfx.ring_alpha(Vfx.RING_READ + Vfx.RING_SETTLE)
	var later := Vfx.ring_alpha(600.0)
	t.check("a new synergy ring is whole until it has been read", is_equal_approx(news, Vfx.RING_ALPHA) and is_equal_approx(read, Vfx.RING_ALPHA),
		"alpha %.2f at discovery, %.2f at %.1f s" % [news, read, Vfx.RING_READ])
	t.check("then it settles faint and stays", is_equal_approx(settled, Vfx.RING_ALPHA * Vfx.RING_REST) and is_equal_approx(later, settled)
			and settled > 0.0 and settled < news * 0.5,
		"alpha %.2f after %.1f s and %.2f ten minutes on" % [settled, Vfx.RING_READ + Vfx.RING_SETTLE, later])
	# The trail: whole at the ball, gone well short of the lens, on the 8 m arm and the 4.2 m mount.
	var rows: Array = []
	var trail_ok := true
	for ball_m in [8.0, 4.2]:
		var at_ball := Vfx.trail_near(ball_m, ball_m)
		var by_lens := Vfx.trail_near(ball_m * 0.3, ball_m)
		var behind := Vfx.trail_near(ball_m * 1.5, ball_m)
		trail_ok = trail_ok and is_equal_approx(at_ball, 1.0) and is_equal_approx(behind, 1.0) and is_zero_approx(by_lens)
		rows.append("arm %.1f m: %.2f at the ball, %.2f past it, %.2f at %.1f m from the lens" % [ball_m, at_ball, behind, by_lens, ball_m * 0.3])
	t.check("the trail clears the lens and stays whole at the ball", trail_ok, "; ".join(rows))
	var view := Vfx.ring_view(0, Color.WHITE)
	var mat := view.material_override as StandardMaterial3D
	t.check("a ring is drawn at the news alpha", mat != null and is_equal_approx(mat.albedo_color.a, Vfx.RING_ALPHA), "alpha %.2f" % (mat.albedo_color.a if mat != null else -1.0))
	view.free()
	quit(t.verdict())
