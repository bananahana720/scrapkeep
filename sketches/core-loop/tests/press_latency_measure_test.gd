extends SceneTree

const Capture := preload("res://tools/press_latency_capture.gd")
const T := preload("res://tests/support/t.gd")

# UA-08 (principle P5): the timing and first-change arithmetic behind tools/press_latency_capture.gd, on
# synthetic frame lists and tiny images, no GPU. `--plant=wrong` feeds the press time after the frame that
# answered it, a wrong input the checks must catch (the run then exits 1).

var _t := T.new("press_latency_measure_test")


func _frame(t: int, px: int, cues := 0) -> Dictionary:
	return {"t": t, "px": px, "cues": cues}


func _initialize() -> void:
	var wrong := OS.get_cmdline_user_args().has("--plant=wrong")
	var t0 := 10_000_000
	if wrong:
		t0 = 10_000_000 + 90_000
	# A press at t0: two still frames, then a frame 33 ms later with 400 changed pixels.
	var frames := [_frame(10_016_000, 0), _frame(10_024_000, 3), _frame(10_033_000, 400), _frame(10_050_000, 900)]
	var hit := Capture.first_change(t0, frames, Capture.MIN_PX)
	_t.check("the change is found", hit["answered"], str(hit))
	_t.eq("it is the third frame", hit["frame"], 2)
	_t.eq("the time is the frame's stamp minus the press", hit["us"], 33_000)
	_t.eq("a screen change answers by screen", hit["by"], "screen")

	var sound := Capture.first_change(t0, [_frame(10_016_000, 0), _frame(10_030_000, 2, 1), _frame(10_050_000, 500)], Capture.MIN_PX)
	_t.eq("a cue with a still screen answers by sound", sound["by"], "sound")
	_t.eq("and at the cue's frame, not the later screen change", sound["us"], 30_000)
	var both := Capture.first_change(t0, [_frame(10_020_000, 90, 1)], Capture.MIN_PX)
	_t.eq("both in one frame is both", both["by"], "both")

	var none := Capture.first_change(t0, [_frame(10_016_000, 0), _frame(10_032_000, Capture.MIN_PX - 1), _frame(10_048_000, 0)], Capture.MIN_PX)
	_t.check("frames under the pixel line do not answer", not none["answered"] and none["us"] == -1, str(none))
	_t.check("no frames at all do not answer", not Capture.first_change(t0, [], Capture.MIN_PX)["answered"])
	var early := Capture.first_change(t0, [_frame(9_990_000, 800), _frame(10_040_000, 0)], Capture.MIN_PX)
	_t.check("a change stamped before the press is not its answer", not early["answered"], str(early))

	_t.eq("a control with one changed frame counts one", Capture.false_changes([_frame(1, 0), _frame(2, 500), _frame(3, 1)], Capture.MIN_PX), 1)
	_t.eq("a control with a cue counts it", Capture.false_changes([_frame(1, 0, 1)], Capture.MIN_PX), 1)
	_t.eq("a still control counts none", Capture.false_changes([_frame(1, 0), _frame(2, 4)], Capture.MIN_PX), 0)

	var answered := func(us: int) -> Dictionary:
		return {"answered": true, "us": us, "by": "screen"}
	var fast := Capture.summarize([answered.call(20_000), answered.call(30_000), answered.call(25_000), answered.call(99_000), answered.call(22_000)], [0, 0, 0, 0, 0], 100.0)
	_t.near("the median of five is the middle one", fast["median_ms"], 25.0)
	_t.near("the worst is the largest", fast["worst_ms"], 99.0)
	_t.check("a worst under the line passes", fast["pass"], str(fast))
	var slow := Capture.summarize([answered.call(20_000), answered.call(150_000), answered.call(25_000)], [0, 0, 0], 100.0)
	_t.check("one press at 150 ms fails the case", not slow["pass"] and slow["worst_ms"] == 150.0, str(slow))
	var edge := Capture.summarize([answered.call(100_000)], [0], 100.0)
	_t.check("exactly the line passes", edge["pass"], str(edge))
	var miss := Capture.summarize([answered.call(20_000), {"answered": false, "us": -1, "by": "none"}], [0, 0], 100.0)
	_t.check("an unanswered press fails the case and is counted", not miss["pass"] and miss["unanswered"] == 1, str(miss))
	var noisy := Capture.summarize([answered.call(20_000)], [0, 2], 100.0)
	_t.check("a false change in a control fails the case", not noisy["pass"] and noisy["false_changes"] == 2, str(noisy))
	_t.check("no presses is not a pass", not Capture.summarize([], [], 100.0)["pass"])

	var a := Image.create(64, 36, false, Image.FORMAT_RGB8)
	a.fill(Color8(50, 50, 50))
	var b := a.duplicate() as Image
	_t.eq("identical pictures differ in no pixel", Capture.differing_pixels(a, b, Capture.DIFFER), 0)
	b.fill_rect(Rect2i(10, 10, 5, 4), Color8(200, 50, 50))
	_t.eq("a 5 by 4 patch is 20 pixels", Capture.differing_pixels(a, b, Capture.DIFFER), 20)
	var faint := a.duplicate() as Image
	faint.fill_rect(Rect2i(0, 0, 64, 36), Color8(53, 50, 50))
	_t.eq("a 3-level drift is under the threshold", Capture.differing_pixels(a, faint, Capture.DIFFER), 0)
	quit(_t.verdict())
