extends SceneTree

const RECTS := {
	"sunlit_sand": Rect2i(180, 900, 220, 100),
	"shadowed_sand": Rect2i(1620, 700, 200, 160),
	"cliff": Rect2i(1300, 200, 300, 200),
	"dam": Rect2i(300, 470, 400, 80),
}

func _initialize() -> void:
	var paths := OS.get_cmdline_user_args()
	var peak := paths.size() == 3 and paths[0] == "--peak"
	if peak:
		paths = paths.slice(1)
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
	if peak:
		_print_peak(a, b)
		quit(0)
		return
	for name in RECTS:
		var area: Rect2i = RECTS[name]
		var mean_a := _mean(a, area)
		var mean_b := _mean(b, area)
		print("%-14s a=(%.3f %.3f %.3f) b=(%.3f %.3f %.3f) cie76=%.1f" % [name,
			mean_a.r, mean_a.g, mean_a.b, mean_b.r, mean_b.g, mean_b.b, _cie76(mean_a, mean_b)])
	quit(0)

static func _print_peak(rest: Image, flash: Image) -> void:
	var rises := PackedFloat32Array()
	var bright := 0
	var total := mini(rest.get_width(), flash.get_width()) * mini(rest.get_height(), flash.get_height())
	for y in mini(rest.get_height(), flash.get_height()):
		for x in mini(rest.get_width(), flash.get_width()):
			var rise := _luminance(flash.get_pixel(x, y)) - _luminance(rest.get_pixel(x, y))
			if rise > 0.0:
				rises.append(rise)
				if rise > 0.1:
					bright += 1
	rises.sort()
	var sum := 0.0
	for rise in rises:
		sum += rise
	var mean := sum / float(maxi(rises.size(), 1))
	var p99 := rises[int(rises.size() * 0.99)] if rises.size() > 0 else 0.0
	print("peak rise mean=%.4f p99=%.4f max=%.4f bright_share=%.4f" % [mean, p99, rises[-1] if rises.size() > 0 else 0.0, float(bright) / float(maxi(total, 1))])

static func _luminance(c: Color) -> float:
	return 0.2126 * _linear(c.r) + 0.7152 * _linear(c.g) + 0.0722 * _linear(c.b)

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
