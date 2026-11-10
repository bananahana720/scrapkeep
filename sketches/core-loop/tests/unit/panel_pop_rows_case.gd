extends RefCounted

const PanelFx := preload("res://src/presentation/panel_fx.gd")

# A grey panel's pop (presentation/panel_fx.gd): one that lands while the last is still up stands
# a line above it, so a streak never prints two pops on top of each other.


func run(t) -> void:
	var fx = PanelFx.new()
	t.check("the first pop stands at the pop height", is_zero_approx(fx.next_pop_lift()), "")
	fx._process(0.3)
	var second: float = fx.next_pop_lift()
	t.check("a pop inside the last one's life stands a line above it", is_equal_approx(second, PanelFx.POP_LINE), "lift %.2f" % second)
	var lifts := []
	var want := []
	for i in PanelFx.POP_ROWS + 1:
		fx._process(0.2)
		lifts.append(fx.next_pop_lift())
		want.append(((i + 2) % PanelFx.POP_ROWS) * PanelFx.POP_LINE)
	t.check("a longer streak goes round the lines, each pop a line off the one before it", lifts == want and lifts.has(0.0), "lifts %s, want %s" % [lifts, want])
	fx._process(PanelFx.POP_LIFE + 0.1)
	t.check("a pop after the last has gone stands at the pop height again", is_zero_approx(fx.next_pop_lift()), "")
	fx.free()
