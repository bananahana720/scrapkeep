extends SceneTree

# Headless: godot --headless --path <sketch> --script res://tools/still_compare.gd -- <a.png> <b.png>
# Prints the mean colour of each named rectangle in both stills and their CIE76 distance.
const RECTS := {
	"sunlit_sand": Rect2i(180, 900, 220, 100),
	"shadowed_sand": Rect2i(1620, 700, 200, 160),
	"cliff": Rect2i(1300, 200, 300, 200),
	"dam": Rect2i(300, 470, 400, 80),
}

func _initialize() -> void:
	var paths := OS.get_cmdline_user_args()
	if paths.size() != 2:
		print("usage: -- <a.png> <b.png>")
		quit(2)
		return
	var a := Image.load_from_file(paths[0])
	var b := Image.load_from_file(paths[1])
	if a == null or b == null:
		print("cannot load a still")
		quit(3)
		return
	for name in RECTS:
		var area: Rect2i = RECTS[name]
		var mean_a := _mean(a, area)
		var mean_b := _mean(b, area)
		print("%-14s a=(%.3f %.3f %.3f) b=(%.3f %.3f %.3f) cie76=%.1f" % [name,
			mean_a.r, mean_a.g, mean_a.b, mean_b.r, mean_b.g, mean_b.b, _cie76(mean_a, mean_b)])
	quit(0)

static func _mean(image: Image, area: Rect2i) -> Color:
	var sum := Vector3.ZERO
	var count := 0
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var c := image.get_pixel(x, y)
			sum += Vector3(c.r, c.g, c.b)
			count += 1
	sum /= float(maxi(count, 1))
	return Color(sum.x, sum.y, sum.z)

static func _cie76(a: Color, b: Color) -> float:
	return _lab(a).distance_to(_lab(b))

static func _lab(c: Color) -> Vector3:
	var r := _linear(c.r)
	var g := _linear(c.g)
	var b := _linear(c.b)
	var x := (r * 0.4124564 + g * 0.3575761 + b * 0.1804375) / 0.95047
	var y := r * 0.2126729 + g * 0.7151522 + b * 0.0721750
	var z := (b * 0.9503041 + g * 0.1191920 + r * 0.0193339) / 1.08883
	var fx := _lab_f(x)
	var fy := _lab_f(y)
	var fz := _lab_f(z)
	return Vector3(116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz))

static func _linear(v: float) -> float:
	return pow((v + 0.055) / 1.055, 2.4) if v > 0.04045 else v / 12.92

static func _lab_f(v: float) -> float:
	return pow(v, 1.0 / 3.0) if v > 0.008856 else 7.787 * v + 16.0 / 116.0
