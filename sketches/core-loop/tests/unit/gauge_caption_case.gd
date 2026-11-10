extends RefCounted

const Gauge := preload("res://src/ui/gauge.gd")

# The HUD gauge's caption (ui/gauge.gd): one word under a bar, counted in the gauge's words and
# its extent, with the icon and bar still on the line a caller centres on. A blind read of one
# still found no reader who took the amber bar for armour without its word.


func run(t) -> void:
	var plain = Gauge.new("res_health", 150.0, true)
	var named = Gauge.new("res_health", 150.0, true, "HEALTH")
	t.check("the caption is no word until the bar has a reading", named.drawn_words().is_empty(), "words %s" % [named.drawn_words()])
	plain.set_reading(0.8, Color.WHITE)
	named.set_reading(0.8, Color.WHITE)
	t.check("a caption is one of the gauge's words", Array(named.drawn_words()) == ["HEALTH"] and plain.drawn_words().is_empty(),
		"named %s, plain %s" % [named.drawn_words(), plain.drawn_words()])
	t.check("it adds one line under the bar and no width", is_equal_approx(named.size.y, plain.size.y + Gauge.CAPTION_LINE) and is_equal_approx(named.size.x, plain.size.x),
		"named %s, plain %s" % [named.size, plain.size])
	t.check("the bar stays on the same line", is_equal_approx(named.bar_mid(), plain.bar_mid()) and is_equal_approx(plain.bar_mid(), plain.size.y * 0.5),
		"named %.1f, plain %.1f of %.1f" % [named.bar_mid(), plain.bar_mid(), plain.size.y])
	named.set_reading(0.5, Color.WHITE, "12")
	t.check("a count beside the bar keeps the caption", Array(named.drawn_words()) == ["12", "HEALTH"], "words %s" % [named.drawn_words()])
	plain.free()
	named.free()
	var count = Gauge.new("res_scrap", 0.0, false, "SCRAP")
	count.set_reading(-1.0, Color.WHITE, "12")
	t.check("a gauge with no bar takes no caption", count.caption == "" and is_equal_approx(count.size.y, Gauge.ICON), "caption '%s', height %.1f" % [count.caption, count.size.y])
	count.free()
