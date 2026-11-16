extends SceneTree

const Capture := preload("res://tools/hud_contrast_capture.gd")
const T := preload("res://tests/support/t.gd")

# UA-04 (principle P3): the arithmetic behind tools/hud_contrast_capture.gd, on synthetic frames, no
# GPU. A white word on a dark ground reaches the 4.5 line, a word a few levels from its ground does
# not, a drawn outline counts as what the glyph touches, and an empty or unseen element scores nothing.

var _t := T.new("hud_contrast_measure_test")
const AREA := Rect2i(0, 0, 40, 40)


func _ground() -> Image:
	var image := Image.create(40, 40, false, Image.FORMAT_RGBA8)
	image.fill(Color8(60, 60, 60))
	return image


func _initialize() -> void:
	_t.near("white against black is 21 to 1", Capture.ratio(Capture.luminance(Color.WHITE), Capture.luminance(Color.BLACK)), 21.0)
	_t.near("white's luminance is 1", Capture.luminance(Color.WHITE), 1.0)
	_t.near("mid grey 119 has luminance 0.184", Capture.luminance(Color8(119, 119, 119)), 0.184, 0.002)

	var ground := _ground()
	var white := _ground()
	white.fill_rect(Rect2i(15, 15, 10, 10), Color.WHITE)
	var good := Capture.measure(white, ground, AREA, Color.WHITE)
	_t.check("a white word on a dark ground is scored", good["scored"], str(good))
	_t.check("and reaches the word line", good["contrast"] >= Capture.WORD_LINE, str(good))
	_t.eq("it found its 100 glyph pixels", good["glyph_px"], 100)

	var close := _ground()
	close.fill_rect(Rect2i(15, 15, 10, 10), Color8(70, 70, 70))
	var bad := Capture.measure(close, ground, AREA, Color8(70, 70, 70))
	_t.check("planted: a word 10 levels from its ground is scored", bad["scored"], str(bad))
	_t.check("planted: and falls under the word line", bad["contrast"] < Capture.WORD_LINE and bad["contrast"] < 1.5, str(bad))
	_t.check("planted: and under the mark line", bad["contrast"] < Capture.MARK_LINE)

	# A slate glyph with a black outline two pixels wide over a mid ground: the outline is what it touches.
	var mid := Image.create(40, 40, false, Image.FORMAT_RGBA8)
	mid.fill(Color8(140, 120, 130))
	var outlined := mid.duplicate()
	outlined.fill_rect(Rect2i(11, 11, 18, 18), Color8(0, 0, 0))
	outlined.fill_rect(Rect2i(13, 13, 14, 14), Color8(111, 127, 143))
	var out_rec := Capture.measure(outlined, mid, AREA, Color8(111, 127, 143))
	var bare := mid.duplicate()
	bare.fill_rect(Rect2i(13, 13, 14, 14), Color8(111, 127, 143))
	var bare_rec := Capture.measure(bare, mid, AREA, Color8(111, 127, 143))
	_t.check("an outlined glyph scores against its outline, above the bare glyph's score", out_rec["scored"] and bare_rec["scored"] and out_rec["contrast"] > bare_rec["contrast"] + 1.0, "%s vs %s" % [out_rec["contrast"], bare_rec["contrast"]])
	_t.check("its ground ratio is the same either way", is_equal_approx(out_rec["ground_contrast"], bare_rec["ground_contrast"]), "%s vs %s" % [out_rec["ground_contrast"], bare_rec["ground_contrast"]])

	# A mark (alpha below zero): every changed pixel is the glyph.
	var mark := Capture.measure(white, ground, AREA, Color(0, 0, 0, -1))
	_t.check("a white mark on a dark ground reaches the 3 line", mark["scored"] and mark["contrast"] >= Capture.MARK_LINE, str(mark))

	_t.check("nothing drawn is not scored", not Capture.measure(ground.duplicate(), ground, AREA, Color.WHITE)["scored"])
	var speck := _ground()
	speck.fill_rect(Rect2i(5, 5, 2, 2), Color.WHITE)
	_t.check("a glyph under 8 pixels is not scored", not Capture.measure(speck, ground, AREA, Color.WHITE)["scored"])
	# A pixel that differs from the ground but not in the word's own colour is not the glyph.
	var other := _ground()
	other.fill_rect(Rect2i(15, 15, 10, 10), Color8(200, 0, 0))
	_t.check("a changed region that is not the word's colour is not scored as the word", not Capture.measure(other, ground, AREA, Color.WHITE)["scored"])
	quit(_t.verdict())
