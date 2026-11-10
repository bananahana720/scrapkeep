extends RefCounted

const Gauge := preload("res://src/ui/gauge.gd")

# The HUD gauge's lost slice (ui/gauge.gd): a drop in the bar leaves what went standing for
# LOSS_HOLD seconds, drains it over LOSS_DRAIN, a second drop inside that time keeps the first
# one's edge, a rise or a gauge with no bar shows none, and clear() (a new run) forgets the bar. A player's-eye film found no bar
# that read as health after a hit; this is the answer that costs no word.


func run(t) -> void:
	var gauge = Gauge.new("res_health", 150.0, true)
	gauge.set_reading(1.0, Color.WHITE)
	t.check("a full bar has no lost slice", is_equal_approx(gauge.lost_edge(), 1.0), "edge %.2f" % gauge.lost_edge())
	gauge.set_reading(0.6, Color.WHITE)
	t.check("a hit leaves what went standing", is_equal_approx(gauge.lost_edge(), 1.0) and is_equal_approx(gauge.fraction, 0.6), "edge %.2f over %.2f" % [gauge.lost_edge(), gauge.fraction])
	gauge._process(Gauge.LOSS_HOLD * 0.9)
	t.check("it holds before it drains", is_equal_approx(gauge.lost_edge(), 1.0), "edge %.2f" % gauge.lost_edge())
	gauge._process(Gauge.LOSS_HOLD * 0.1 + Gauge.LOSS_DRAIN * 0.5)
	var mid: float = gauge.lost_edge()
	t.check("then it drains toward the bar", mid > 0.6 and mid < 1.0 and is_equal_approx(mid, 0.8), "edge %.2f" % mid)
	gauge.set_reading(0.5, Color.WHITE)
	t.check("a second hit keeps the first one's edge", is_equal_approx(gauge.lost_edge(), mid), "edge %.2f, was %.2f" % [gauge.lost_edge(), mid])
	gauge._process(Gauge.LOSS_HOLD + Gauge.LOSS_DRAIN)
	t.check("and it is gone when its time is up", is_equal_approx(gauge.lost_edge(), 0.5), "edge %.2f" % gauge.lost_edge())
	gauge.set_reading(0.9, Color.WHITE)
	t.check("a rise shows no slice", is_equal_approx(gauge.lost_edge(), 0.9), "edge %.2f" % gauge.lost_edge())
	gauge.set_reading(0.4, Color.WHITE)
	gauge.set_reading(0.95, Color.WHITE)
	t.check("a rise past a slice ends it", is_equal_approx(gauge.lost_edge(), 0.95), "edge %.2f" % gauge.lost_edge())
	gauge.set_reading(0.3, Color.WHITE)
	gauge.clear()
	gauge.set_reading(0.1, Color.WHITE)
	t.check("a new run's first reading is no loss", is_equal_approx(gauge.lost_edge(), 0.1) and is_equal_approx(gauge.fraction, 0.1), "edge %.2f over %.2f" % [gauge.lost_edge(), gauge.fraction])
	gauge.free()
	var count = Gauge.new("res_scrap")
	count.set_reading(0.8, Color.WHITE, "12")
	count.set_reading(0.2, Color.WHITE, "3")
	t.check("a gauge with no bar keeps none", is_equal_approx(count.lost_edge(), 0.2), "edge %.2f" % count.lost_edge())
	count.free()
