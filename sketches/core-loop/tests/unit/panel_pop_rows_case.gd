extends RefCounted

const PanelFx := preload("res://src/presentation/panel_fx.gd")

# A grey panel's pop (presentation/panel_fx.gd): one that lands while the last is still up stands
# a line above it, and while every line is held the next pop waits for one to clear, so a cleared
# camp's handful of panels never prints two pops on top of each other.


func run(t) -> void:
	var fx = PanelFx.new()
	t.check("the first pop stands at the pop height", is_zero_approx(fx.next_pop_lift()), "")
	fx._process(0.3)
	var second: float = fx.next_pop_lift()
	t.check("a pop inside the last one's life stands a line above it", is_equal_approx(second, PanelFx.POP_LINE), "lift %.2f" % second)
	fx._process(0.2)
	t.check("while every line is held there is no line for the next pop", fx.next_pop_lift() < 0.0, "")
	fx._process(PanelFx.POP_LIFE - 0.5 + 0.01)
	var freed: float = fx.next_pop_lift()
	t.check("the first line to clear is the one the next pop takes", is_zero_approx(freed), "lift %.2f" % freed)
	t.check("the other line is still held", fx.next_pop_lift() < 0.0, "")
	fx._process(PanelFx.POP_LIFE + 0.1)
	t.check("a pop after every pop has gone stands at the pop height again", is_zero_approx(fx.next_pop_lift()), "")
	# Pickups queue: three at once show two now and the third when a line clears.
	var queued = PanelFx.new()
	for i in 3:
		queued._waiting.append(["louvre", false])
	queued._release()
	t.check("three pops at once: two show, one waits", queued._waiting.size() == 1, "waiting %d" % queued._waiting.size())
	queued._process(PanelFx.POP_LIFE + 0.01)
	t.check("the waiting pop shows once a line clears", queued._waiting.is_empty(), "waiting %d" % queued._waiting.size())
	queued.free()
	fx.free()
