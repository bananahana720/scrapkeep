extends SceneTree


const CHANNEL_STEP := 12
const MAX_SHARE := 0.003
const MAX_MEAN := 0.75
const AMPLIFY := 8
const BOX_MAX_SHARE := 0.005
const BOX_MAX_MEAN := 0.3
const BOX_PAD := 8
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
	for file in DirAccess.get_files_at(args["head"]):
		if file.ends_with(".png") and file != "empty.png" and FileAccess.file_exists(String(args["ref"]).path_join(_ref_name(file.get_basename()) + ".png")):
			names.append(file.get_basename())
	names.sort()
	if names.is_empty():
		push_error("still_diff: no still is in both %s and %s" % [args["ref"], args["head"]])
		quit(3)
		return
	var empty_path := String(args["ref"]).path_join("empty.png")
	var empty: Image = Image.load_from_file(empty_path) if FileAccess.file_exists(empty_path) else null
	if empty != null:
		empty.convert(Image.FORMAT_RGB8)
	var rows: Array = []
	var sheet := Image.create_empty(THUMB.x * 3, THUMB.y * maxi(1, names.size()), false, Image.FORMAT_RGB8)
	var failed := 0
	for i in names.size():
		var name: String = names[i]
		var a := Image.load_from_file(String(args["ref"]).path_join(_ref_name(name) + ".png"))
		var b := Image.load_from_file(String(args["head"]).path_join(name + ".png"))
		var row := _compare(a, b, empty, String(args["out"]).path_join(name + "-diff.png"), sheet, i)
		row["name"] = name
		row["ref"] = _ref_name(name)
		row["judged"] = not name in expect
		row["pass"] = row["share"] <= MAX_SHARE and row["mean"] <= MAX_MEAN \
			and row["box_share"] <= BOX_MAX_SHARE and row["box_mean"] <= BOX_MAX_MEAN
		row["control"] = name.begins_with("control-")
		if row["judged"] and row["pass"] == row["control"]:
			failed += 1
		rows.append(row)
		var verdict := ("PASS" if row["pass"] else "FAIL") if row["judged"] else ("differs" if not row["pass"] else "same")
		if row["control"]:
			verdict = "known-bad control %s the budget" % ("FAILS" if not row["pass"] else "PASSES (budget too loose)")
		print("%-44s frame %.4f%% mean %.3f | box %dx%d %.4f%% mean %.3f | max %d -> %s" % [name, row["share"] * 100.0, row["mean"],
			row["box"][2], row["box"][3], row["box_share"] * 100.0, row["box_mean"], row["max"], verdict])
	sheet.save_png(String(args["out"]).path_join("contact.png"))
	var f := FileAccess.open(String(args["out"]).path_join("diffs.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"budget": {"channel_step": CHANNEL_STEP, "max_share": MAX_SHARE, "max_mean": MAX_MEAN,
		"box_max_share": BOX_MAX_SHARE, "box_max_mean": BOX_MAX_MEAN, "box_pad": BOX_PAD, "boxed": empty != null},
		"stills": rows, "failed": failed}, " "))
	f.close()
	print("still_diff: %d stills, %d judged failures" % [rows.size(), failed])
	quit(0 if failed == 0 else 1)


static func _ref_name(name: String) -> String:
	if name.begins_with("control-") and "--" in name:
		return name.substr(8, name.find("--") - 8)
	return name


func _compare(a: Image, b: Image, empty: Image, diff_path: String, sheet: Image, row: int) -> Dictionary:
	a.convert(Image.FORMAT_RGB8)
	b.convert(Image.FORMAT_RGB8)
	if a.get_size() != b.get_size():
		return {"share": 1.0, "mean": 255.0, "max": 255, "pixels": 0, "box": [0, 0, 0, 0], "box_share": 1.0, "box_mean": 255.0,
			"note": "size %s vs %s" % [a.get_size(), b.get_size()]}
	var da := a.get_data()
	var db := b.get_data()
	var box := _box(da, db, empty, a.get_width(), a.get_height())
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
	var box_over := 0
	var box_total := 0
	for y in range(box.position.y, box.end.y):
		var at := (y * a.get_width() + box.position.x) * 3
		for x in box.size.x:
			var r := absi(da[at] - db[at])
			var g := absi(da[at + 1] - db[at + 1])
			var bl := absi(da[at + 2] - db[at + 2])
			box_total += r + g + bl
			if maxi(r, maxi(g, bl)) > CHANNEL_STEP:
				box_over += 1
			at += 3
	var box_pixels := maxi(1, box.size.x * box.size.y)
	var diff := Image.create_from_data(a.get_width(), a.get_height(), false, Image.FORMAT_RGB8, out)
	diff.save_png(diff_path)
	var pixels := da.size() / 3
	for k in 3:
		var thumb: Image = [a, b, diff][k].duplicate()
		thumb.resize(THUMB.x, THUMB.y, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(thumb, Rect2i(Vector2i.ZERO, THUMB), Vector2i(THUMB.x * k, THUMB.y * row))
	return {"share": float(over) / pixels, "mean": float(total) / (pixels * 3), "max": peak, "pixels": over,
		"box": [box.position.x, box.position.y, box.size.x, box.size.y], "box_share": float(box_over) / box_pixels,
		"box_mean": float(box_total) / (box_pixels * 3), "box_pixels": box_over}


func _box(da: PackedByteArray, db: PackedByteArray, empty: Image, width: int, height: int) -> Rect2i:
	if empty == null or empty.get_width() != width or empty.get_height() != height:
		return Rect2i(0, 0, width, height)
	var de := empty.get_data()
	var lo := Vector2i(width, height)
	var hi := Vector2i(-1, -1)
	var i := 0
	var n := width * height
	for p in n:
		var ea := maxi(absi(da[i] - de[i]), maxi(absi(da[i + 1] - de[i + 1]), absi(da[i + 2] - de[i + 2])))
		var eb := maxi(absi(db[i] - de[i]), maxi(absi(db[i + 1] - de[i + 1]), absi(db[i + 2] - de[i + 2])))
		if ea > CHANNEL_STEP or eb > CHANNEL_STEP:
			var x := p % width
			var y := p / width
			lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
			hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
		i += 3
	if hi.x < 0:
		return Rect2i(0, 0, width, height)
	lo = Vector2i(maxi(0, lo.x - BOX_PAD), maxi(0, lo.y - BOX_PAD))
	hi = Vector2i(mini(width - 1, hi.x + BOX_PAD), mini(height - 1, hi.y + BOX_PAD))
	return Rect2i(lo, hi - lo + Vector2i.ONE)
