extends SceneTree


const Model := preload("res://tests/consumed_light_test.gd")


func _initialize() -> void:
	print("# consumed sample %s, band hue %.0f-%.0f sat >= %.2f, gap floor %.0f CIE76" % [Model.CONSUMED.to_html(false),
		Model.CONSUMED_HUE.x, Model.CONSUMED_HUE.y, Model.CONSUMED_SAT_MIN, Model.MIN_GAP])
	print("look | normal | colour | lit hex | hue | sat | L* | gap HAZARD | gap AMBER | gap MOLTEN | lit drift (info; per #241 ruling 6367828092): in 300-330 / 0.6 | nearest lit life gap")
	var life := Model.life_colours()
	var cells := 0
	var clamped_cells := 0
	for entry in Model.looks_all():
		for n in entry.rig.normals.size():
			var gaps := Model.warning_gaps(Model.CONSUMED, entry.rig, n)
			print(_row(entry.label, n, Model.CONSUMED, entry.rig, "consumed", "%.1f | %.1f | %.1f" % [gaps.HAZARD, gaps.AMBER, gaps.MOLTEN], _nearest(life, entry.rig, n) + " | cell peak %.4f | life clamped %d of %d" % [Model.cell_scale(entry.rig, n), _clamped(life, entry.rig, n), life.size()]))
			cells += 1
			if _clamped(life, entry.rig, n) > 0:
				clamped_cells += 1
			for c in life:
				print(_row(entry.label, n, c, entry.rig, "life", "- | - | -", "%.1f from consumed | clamp %s" % [Model.pair_gap(Model.CONSUMED, c, entry.rig, n), "yes" if Model.clamps(c, entry.rig, n) else "no"]))
	print("# %d of %d cells clamp at least one life colour in the pairwise scaling" % [clamped_cells, cells])
	quit(0)


func _row(label: String, n: int, albedo: Color, rig: Dictionary, kind: String, gaps: String, extra: String) -> String:
	var lin := Model.lit_linear(albedo, rig, n)
	var peak := maxf(lin.r, maxf(lin.g, lin.b))
	var shown := Color(lin.r / peak, lin.g / peak, lin.b / peak).linear_to_srgb() if peak > 0.0 else Color.BLACK
	var hs := Model.lit_hs(albedo, rig, n)
	return "%s | %s | %s %s | %s | %.1f | %.3f | %.1f | %s | %s | %s" % [label, rig.normals[n].name, kind, albedo.to_html(false),
		shown.to_html(false), hs.x, hs.y, Model._lab(shown).x, gaps, "yes" if Model.in_consumed_band(hs.x, hs.y) else "no", extra]


func _nearest(life: Array, rig: Dictionary, n: int) -> String:
	var best := 999.0
	var which := ""
	for c in life:
		var d := Model.pair_gap(Model.CONSUMED, c, rig, n)
		if d < best:
			best = d
			which = c.to_html(false)
	return "%.1f (%s)" % [best, which]


func _clamped(life: Array, rig: Dictionary, n: int) -> int:
	var count := 0
	for c in life:
		if Model.clamps(c, rig, n):
			count += 1
	return count
