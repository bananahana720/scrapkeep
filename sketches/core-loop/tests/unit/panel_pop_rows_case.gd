extends RefCounted

const PanelFx := preload("res://src/presentation/panel_fx.gd")

# A grey panel's pop (presentation/panel_fx.gd): one that lands while the last is still up takes
# the row above it, and while every row is held the next pop waits for one to clear, so a cleared
# camp's handful of panels never prints two pops on top of each other.


func run(t) -> void:
	var fx = PanelFx.new()
	t.eq("the first pop takes the bottom row", fx.next_pop_row(), 0)
	fx._process(0.3)
	t.eq("a pop inside the last one's life takes the row above it", fx.next_pop_row(), 1)
	fx._process(0.2)
	t.check("while every row is held there is no row for the next pop", fx.next_pop_row() < 0, "")
	fx._process(PanelFx.POP_LIFE - 0.5 + 0.01)
	t.eq("the first row to clear is the one the next pop takes", fx.next_pop_row(), 0)
	t.check("the other row is still held", fx.next_pop_row() < 0, "")
	fx._process(PanelFx.POP_LIFE + 0.1)
	t.eq("a pop after every pop has gone takes the bottom row again", fx.next_pop_row(), 0)
	# Pickups queue: three at once show two now and the third when a row clears.
	var queued = PanelFx.new()
	for i in 3:
		queued._waiting.append(["louvre", false])
	queued._release()
	t.check("three pops at once: two show, one waits", queued._waiting.size() == 1, "waiting %d" % queued._waiting.size())
	queued._process(PanelFx.POP_LIFE + 0.01)
	t.check("the waiting pop shows once a row clears", queued._waiting.is_empty(), "waiting %d" % queued._waiting.size())
	queued.free()
	fx.free()
