extends SceneTree

const Capture := preload("res://tools/flash_capture.gd")
const T := preload("res://tests/support/t.gd")

# UA-06 (principle P8): the arithmetic behind tools/flash_capture.gd's clip mode, on synthetic
# luminance series and images, no GPU. A series that blinks five times a second must count five,
# a steady or slowly pulsing one must count under the line, and a wrong expectation must fail.

var _t := T.new("flash_rate_measure_test")


func _series(hz: float, seconds: float, fps: float, lo: float, hi: float) -> Array:
	var times := PackedFloat32Array()
	var luma := PackedFloat32Array()
	var n := int(seconds * fps)
	for i in n:
		var t := i / fps
		times.append(t)
		luma.append(hi if int(floor(t * hz * 2.0)) % 2 == 0 else lo)
	return [times, luma]


func _initialize() -> void:
	var fast := _series(5.0, 2.0, 60.0, 0.2, 0.8)
	var rate: float = Capture.flashes_per_second(fast[0], fast[1], 0.05)
	_t.check("a mark blinking 5 times a second counts above the 3 a second line", rate > Capture.FLASH_LINE, "got %s" % rate)
	_t.check("and counts 5 in its worst second", is_equal_approx(rate, 5.0), "got %s" % rate)

	var slow := _series(2.0, 3.0, 60.0, 0.2, 0.8)
	var slow_rate: float = Capture.flashes_per_second(slow[0], slow[1], 0.05)
	_t.check("a 2 a second pulse is inside the line", slow_rate <= Capture.FLASH_LINE and slow_rate >= 2.0, "got %s" % slow_rate)

	var edge := _series(3.0, 3.0, 60.0, 0.2, 0.8)
	var edge_rate: float = Capture.flashes_per_second(edge[0], edge[1], 0.05)
	_t.check("3 a second is on the line and passes it", edge_rate <= Capture.FLASH_LINE and edge_rate >= 3.0, "got %s" % edge_rate)

	var steady := _series(5.0, 2.0, 60.0, 0.5, 0.5)
	_t.eq("a steady series counts 0", Capture.flashes_per_second(steady[0], steady[1], 0.05), 0.0)

	var shallow := _series(5.0, 2.0, 60.0, 0.50, 0.52)
	_t.eq("a 5 a second wobble smaller than the delta counts 0", Capture.flashes_per_second(shallow[0], shallow[1], 0.05), 0.0)

	var one := PackedFloat32Array([0.2, 0.2, 0.9, 0.9, 0.2, 0.2])
	var one_t := PackedFloat32Array([0.0, 0.1, 0.2, 0.3, 0.4, 0.5])
	_t.eq("a single rise and fall counts 1", Capture.flashes_per_second(one_t, one, 0.05), 1.0)
	var half := PackedFloat32Array([0.2, 0.2, 0.9, 0.9, 0.9, 0.9])
	_t.eq("a rise with no fall counts 0", Capture.flashes_per_second(one_t, half, 0.05), 0.0)
	_t.eq("a series with mismatched times reports -1", Capture.flashes_per_second(PackedFloat32Array([0.0]), half, 0.05), -1.0)

	# Region luminance on a synthetic frame: left half white, right half black, 4 x 3 grid.
	var image := Image.create(80, 60, false, Image.FORMAT_RGB8)
	image.fill(Color.BLACK)
	image.fill_rect(Rect2i(0, 0, 40, 60), Color.WHITE)
	var lin := Capture._linear_table()
	var means := Capture.region_means(image, Vector2i(4, 3), 1, lin)
	_t.eq("a 4 x 3 grid gives 12 regions", means.size(), 12)
	var left_ok := true
	var right_ok := true
	for row in 3:
		for col in 4:
			var v := means[row * 4 + col]
			if col < 2 and not is_equal_approx(v, 1.0):
				left_ok = false
			if col >= 2 and not is_equal_approx(v, 0.0):
				right_ok = false
	_t.check("the white half's regions read 1.0", left_ok, str(means))
	_t.check("the black half's regions read 0.0", right_ok, str(means))
	var grey := Image.create(40, 30, false, Image.FORMAT_RGBA8)
	grey.fill(Color8(119, 119, 119))
	var grey_mean := Capture.region_means(grey, Vector2i(1, 1), 1, lin)[0]
	_t.near("mid grey 119 reads its WCAG relative luminance, 0.184", grey_mean, 0.184, 0.002)

	# Planted wrong input: a blink the test's own rate must not call safe.
	var wrong := rate <= Capture.FLASH_LINE
	_t.check("planted: treating the 5 a second blink as inside the line is wrong", not wrong, "rate %s" % rate)
	quit(_t.verdict())
