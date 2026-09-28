extends SceneTree

# Compares two still sets from tools/still_capture.gd (E1-DENSITY.md section 5.2):
#   godot --headless --path sketches/core-loop --script res://tools/still_diff.gd -- --ref=/abs/ref --head=/abs/head --out=/abs/diff
# A still fails when more than MAX_SHARE of its pixels differ by more than CHANNEL_STEP
# in any channel, or the mean absolute difference over every channel exceeds MAX_MEAN.
# Writes diffs.json, an amplified diff image per still and contact.png (reference, head,
# diff x8 per row). Stills named in --expect-change are reported but not judged; a still
# named control-* is a known-bad calibration and must fail the budget.

const CHANNEL_STEP := 12
const MAX_SHARE := 0.003
const MAX_MEAN := 0.75
const AMPLIFY := 8
const THUMB := Vector2i(480, 270)


func _initialize() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and "=" in arg:
			args[arg.substr(2, arg.find("=") - 2)] = arg.substr(arg.find("=") + 1)
	var expect: Array = String(args.get("expect-change", "")).split(",", false)
	if not args.has("ref") or not args.has("head") or not args.has("out"):
		push_error("still_diff: --ref, --head and --out are required")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(args["out"])
	var names: Array = []
	for file in DirAccess.get_files_at(args["ref"]):
		if file.ends_with(".png") and FileAccess.file_exists(String(args["head"]).path_join(file)):
			names.append(file.get_basename())
	names.sort()
	var rows: Array = []
	var sheet := Image.create_empty(THUMB.x * 3, THUMB.y * maxi(1, names.size()), false, Image.FORMAT_RGB8)
	var failed := 0
	for i in names.size():
		var name: String = names[i]
		var a := Image.load_from_file(String(args["ref"]).path_join(name + ".png"))
		var b := Image.load_from_file(String(args["head"]).path_join(name + ".png"))
		var row := _compare(a, b, String(args["out"]).path_join(name + "-diff.png"), sheet, i)
		row["name"] = name
		row["judged"] = not name in expect
		row["pass"] = row["share"] <= MAX_SHARE and row["mean"] <= MAX_MEAN
		row["control"] = name.begins_with("control-")
		if row["judged"] and row["pass"] == row["control"]:
			failed += 1
		rows.append(row)
		var verdict := ("PASS" if row["pass"] else "FAIL") if row["judged"] else ("differs" if not row["pass"] else "same")
		if row["control"]:
			verdict = "known-bad control %s the budget" % ("FAILS" if not row["pass"] else "PASSES (budget too loose)")
		print("%-48s share %.4f%% mean %.3f/255 max %d -> %s" % [name, row["share"] * 100.0, row["mean"], row["max"], verdict])
	sheet.save_png(String(args["out"]).path_join("contact.png"))
	var f := FileAccess.open(String(args["out"]).path_join("diffs.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"budget": {"channel_step": CHANNEL_STEP, "max_share": MAX_SHARE, "max_mean": MAX_MEAN},
		"stills": rows, "failed": failed}, " "))
	f.close()
	print("still_diff: %d stills, %d judged failures" % [rows.size(), failed])
	quit(0 if failed == 0 else 1)


func _compare(a: Image, b: Image, diff_path: String, sheet: Image, row: int) -> Dictionary:
	a.convert(Image.FORMAT_RGB8)
	b.convert(Image.FORMAT_RGB8)
	if a.get_size() != b.get_size():
		return {"share": 1.0, "mean": 255.0, "max": 255, "pixels": 0, "note": "size %s vs %s" % [a.get_size(), b.get_size()]}
	var da := a.get_data()
	var db := b.get_data()
	var out := PackedByteArray()
	out.resize(da.size())
	var over := 0
	var total := 0
	var peak := 0
	var i := 0
	while i < da.size():
		var r := absi(da[i] - db[i])
		var g := absi(da[i + 1] - db[i + 1])
		var bl := absi(da[i + 2] - db[i + 2])
		total += r + g + bl
		var m := maxi(r, maxi(g, bl))
		peak = maxi(peak, m)
		if m > CHANNEL_STEP:
			over += 1
		out[i] = mini(255, r * AMPLIFY)
		out[i + 1] = mini(255, g * AMPLIFY)
		out[i + 2] = mini(255, bl * AMPLIFY)
		i += 3
	var diff := Image.create_from_data(a.get_width(), a.get_height(), false, Image.FORMAT_RGB8, out)
	diff.save_png(diff_path)
	var pixels := da.size() / 3
	for k in 3:
		var thumb: Image = [a, b, diff][k].duplicate()
		thumb.resize(THUMB.x, THUMB.y, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(thumb, Rect2i(Vector2i.ZERO, THUMB), Vector2i(THUMB.x * k, THUMB.y * row))
	return {"share": float(over) / pixels, "mean": float(total) / (pixels * 3), "max": peak, "pixels": over}
