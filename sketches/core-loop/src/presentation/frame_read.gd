extends RefCounted

const METRIC_SIZE := Vector2i(480, 270)
const BLACK_LEVEL := 24
const DEAD_BLACK_SHARE := 0.80
const DEAD_TOP_SHARE := 0.70
const DEAD_LUMA_FLOOR := 6.0
const BINS := 16


static func metrics(img: Image) -> Dictionary:
	if img == null or img.is_empty() or img.get_width() <= 0 or img.get_height() <= 0:
		return {"width": 0, "height": 0, "mean_luma": 0.0, "black_share": 1.0, "top_share": 1.0, "unique_colours": 0,
			"dead": true, "reason": "empty"}
	var width := img.get_width()
	var height := img.get_height()
	var probe := img.duplicate() as Image
	if probe.is_compressed():
		probe.decompress()
	probe.convert(Image.FORMAT_RGB8)
	if width > METRIC_SIZE.x or height > METRIC_SIZE.y:
		probe.resize(mini(width, METRIC_SIZE.x), mini(height, METRIC_SIZE.y), Image.INTERPOLATE_BILINEAR)
	var data := probe.get_data()
	var count := data.size() / 3
	var bins := PackedInt32Array()
	bins.resize(BINS * BINS * BINS)
	var luma_sum := 0.0
	var black := 0
	var step := 256 / BINS
	for i in count:
		var r := data[i * 3]
		var g := data[i * 3 + 1]
		var b := data[i * 3 + 2]
		var luma := 0.2126 * r + 0.7152 * g + 0.0722 * b
		luma_sum += luma
		if luma <= BLACK_LEVEL:
			black += 1
		bins[(r / step) * BINS * BINS + (g / step) * BINS + b / step] += 1
	var top := 0
	var unique := 0
	for n in bins:
		if n > 0:
			unique += 1
			top = maxi(top, n)
	var m := {"width": width, "height": height, "mean_luma": luma_sum / maxf(count, 1.0),
		"black_share": float(black) / maxf(count, 1.0), "top_share": float(top) / maxf(count, 1.0), "unique_colours": unique}
	m["reason"] = _reason(m)
	m["dead"] = m.reason != ""
	return m


static func is_dead(m: Dictionary) -> bool:
	if m.is_empty():
		return true
	return bool(m.get("dead", _reason(m) != ""))


static func note(m: Dictionary) -> String:
	match String(m.get("reason", "")):
		"black":
			return "black %s" % _share(float(m.black_share))
		"sky":
			return "sky %s" % _share(float(m.top_share))
		"dark":
			return "dark %.1f" % float(m.mean_luma)
		"empty":
			return "empty"
	return ""


static func _reason(m: Dictionary) -> String:
	if int(m.get("width", 0)) <= 0:
		return "empty"
	if float(m.get("black_share", 0.0)) >= DEAD_BLACK_SHARE:
		return "black"
	if float(m.get("mean_luma", 255.0)) < DEAD_LUMA_FLOOR:
		return "dark"
	if float(m.get("top_share", 0.0)) >= DEAD_TOP_SHARE:
		return "sky"
	return ""


static func _share(value: float) -> String:
	return ("%.2f" % clampf(value, 0.0, 1.0)).trim_prefix("0")
