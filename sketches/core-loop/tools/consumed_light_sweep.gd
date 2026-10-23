extends SceneTree

# Prints the consumed band lit (L-W19-consumed): for every light look and normal, the lit hex, hue, saturation and L* of the
# consumed sample and of each in-band life colour, plus the consumed sample's CIE76 gap to HAZARD, AMBER and MOLTEN lit under
# the same look. Same model as tests/consumed_light_test.gd, which this reads; run it for the reviewer and for the 3060 bench:
#   godot --headless --path sketches/core-loop --script res://tools/consumed_light_sweep.gd
# Columns: look | normal | colour | lit hex | hue | sat | L* | gap HAZARD | gap AMBER | gap MOLTEN
# Lit hex is the colour divided by its largest channel (hue and saturation are scale-free); a gap is on a shared scale.

const Model := preload("res://tests/consumed_light_test.gd")


func _initialize() -> void:
	print("# consumed sample %s, band hue %.0f-%.0f sat >= %.2f, gap floor %.0f CIE76" % [Model.CONSUMED.to_html(false),
		Model.CONSUMED_HUE.x, Model.CONSUMED_HUE.y, Model.CONSUMED_SAT_MIN, Model.MIN_GAP])
	print("look | normal | colour | lit hex | hue | sat | L* | gap HAZARD | gap AMBER | gap MOLTEN | in consumed band")
	var life := Model.life_colours()
	for entry in Model.looks_all():
		for n in Model.NORMALS.size():
			var gaps := Model.warning_gaps(Model.CONSUMED, entry.look, n)
			print(_row(entry.label, n, Model.CONSUMED, entry.look, "consumed", "%.1f | %.1f | %.1f" % [gaps.HAZARD, gaps.AMBER, gaps.MOLTEN]))
			for c in life:
				print(_row(entry.label, n, c, entry.look, "life", "- | - | -"))
	quit(0)


func _row(label: String, n: int, albedo: Color, look: Dictionary, kind: String, gaps: String) -> String:
	var lin := Model.lit_linear(albedo, look, n)
	var peak := maxf(lin.r, maxf(lin.g, lin.b))
	var shown := Color(lin.r / peak, lin.g / peak, lin.b / peak).linear_to_srgb() if peak > 0.0 else Color.BLACK
	var hs := Model.lit_hs(albedo, look, n)
	return "%s | %s | %s %s | %s | %.1f | %.3f | %.1f | %s | %s" % [label, Model.NORMALS[n], kind, albedo.to_html(false),
		shown.to_html(false), hs.x, hs.y, Model._lab(shown).x, gaps, "yes" if Model.in_consumed_band(hs.x, hs.y) else "no"]
