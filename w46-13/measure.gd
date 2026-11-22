extends SceneTree
# W46-13 evidence: numbers for each stills folder. ring_de: mean CIE76 between the telegraph still and the same held
# frame with the ring hidden, over the pixels the ring changed (how far the ring stands off the ground under it).
# floor_l: mean L* of the bottom 40% of the spawn and domes stills; sky_l: mean L* of the top 12% of the domes still.
const Bars := preload("res://src/core/defence_bars.gd")
func _initialize() -> void:
	var dirs := []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--dirs="): dirs = Array(arg.trim_prefix("--dirs=").split(","))
	for d in dirs:
		var row := {"dir": String(d).get_file()}
		for t in ["telegraph", "telegraph_lit", "telegraph_yard"]:
			var a := Image.load_from_file(d + "/" + t + ".png")
			var b := Image.load_from_file(d + "/" + t + "-plain.png")
			if a == null or b == null: continue
			var sum := 0.0
			var n := 0
			for y in range(0, a.get_height(), 2):
				for x in range(0, a.get_width(), 2):
					var ca := a.get_pixel(x, y)
					var cb := b.get_pixel(x, y)
					if maxf(absf(ca.r - cb.r), maxf(absf(ca.g - cb.g), absf(ca.b - cb.b))) > 0.1:
						sum += Bars.cie76(ca, cb)
						n += 1
			row[t + "_ring_de"] = snappedf(sum / maxf(1, n), 0.1)
			row[t + "_ring_px"] = n
		for t in ["spawn", "domes", "yard"]:
			var im := Image.load_from_file(d + "/" + t + ".png")
			if im == null: continue
			row[t + "_floor_l"] = snappedf(_mean_l(im, 0.6, 1.0), 0.1)
			if t == "domes": row["sky_l"] = snappedf(_mean_l(im, 0.0, 0.12), 0.1)
		print("MEASURE ", JSON.stringify(row))
	quit(0)
func _mean_l(im: Image, top: float, bottom: float) -> float:
	var s := 0.0
	var n := 0
	for y in range(int(im.get_height() * top), int(im.get_height() * bottom), 3):
		for x in range(0, im.get_width(), 3):
			var c := im.get_pixel(x, y)
			s += _l(c)
			n += 1
	return s / n
static func _l(c: Color) -> float:
	var lin := c.srgb_to_linear()
	var yy := 0.2126 * lin.r + 0.7152 * lin.g + 0.0722 * lin.b
	return 116.0 * pow(yy, 1.0 / 3.0) - 16.0 if yy > 0.008856 else 903.3 * yy
