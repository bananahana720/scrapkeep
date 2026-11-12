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
	var view := Vfx.ring_view(0, Color.WHITE)
	var mat := view.material_override as StandardMaterial3D
	t.check("a ring is drawn at the news alpha", mat != null and is_equal_approx(mat.albedo_color.a, Vfx.RING_ALPHA), "alpha %.2f" % (mat.albedo_color.a if mat != null else -1.0))
	view.free()
	quit(t.verdict())
