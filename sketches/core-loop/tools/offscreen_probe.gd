extends "res://tools/dam_look_capture.gd"

# One fixed station from a real capture tool: the dam yard, seed 280928, High. The Gate's
# reference and the embedded run draw via the same parent implementation. A separate
# headless invocation measures saved PNGs and cannot create a reference window.
const OffscreenWindow := preload("res://tools/offscreen_window.gd")
const Harness := preload("res://tools/look_harness.gd")
const Subjects := preload("res://tools/look_subjects.gd")
const Bars := preload("res://src/core/defence_bars.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty() and args[0].begins_with("--measure="):
		if args.size() > 2 or (args.size() == 2 and not args[1].begins_with("--reference=")):
			quit(2)
			return
		var reference := args[1].trim_prefix("--reference=") if args.size() == 2 else ""
		quit(_measure(args[0].trim_prefix("--measure="), reference))
		return
	OffscreenWindow.apply(root)
	super._initialize()


static func _means(img: Image) -> Array[Color]:
	var means: Array[Color] = []
	var width := img.get_width() / 2
	var height := img.get_height() / 2
	for row in 2:
		for col in 2:
			var sum := Vector3.ZERO
			for y in range(row * height, (row + 1) * height):
				for x in range(col * width, (col + 1) * width):
					var c := img.get_pixel(x, y)
					sum += Vector3(c.r, c.g, c.b)
			sum /= width * height
			means.append(Color(sum.x, sum.y, sum.z))
	return means


static func _measure(file: String, reference: String) -> int:
	var result := {"file": file, "reference": reference, "quadrant_cie76": []}
	var img := Image.load_from_file(file)
	if img == null or img.get_size() != SIZE:
		printerr("offscreen_probe: need a 1920x1080 PNG at ", file)
		return 1
	result["sha256"] = FileAccess.get_sha256(file)
	result["metrics"] = Harness.frame_metrics(img)
	var failed := Harness.is_dead(result["metrics"], Subjects.DEAD)
	if not reference.is_empty():
		var ref := Image.load_from_file(reference)
		if ref == null or ref.get_size() != SIZE:
			printerr("offscreen_probe: invalid reference ", reference)
			return 1
		result["reference_sha256"] = FileAccess.get_sha256(reference)
		failed = failed or Harness.is_dead(Harness.frame_metrics(ref), Subjects.DEAD)
		var a := _means(img)
		var b := _means(ref)
		for quadrant in 4:
			var distance := Bars.cie76(a[quadrant], b[quadrant])
			result["quadrant_cie76"].append(distance)
			if distance > 2.3:
				failed = true
	print("OFFSCREEN_FRAME ", JSON.stringify(result))
	return 1 if failed else 0
