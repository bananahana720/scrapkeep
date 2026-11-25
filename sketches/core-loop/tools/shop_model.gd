extends SceneTree

const StageDefs := preload("res://src/core/stage_defs.gd")
const Terrain := preload("res://src/world/terrain.gd")
const Activities := preload("res://src/world/activities.gd")
const Fabricators := preload("res://src/build/fabricators.gd")
const ScrapField := preload("res://src/build/scrap_field.gd")


const BAND := Vector2(0.5, 2.0)
const REFERENCE_PART := "arc_coil"
const START_PARTS := 1
const BOT_LINE_SHARE := 0.8
const BOT_ACTIVITY_RATE := 0.85
const BOT_KILLS := 30
const BOT_KILL_VALUE := 4.0
const BOT_JITTER := 0.15
const STAGE_COUNT := StageDefs.COUNT

var _out_dir := ""


func _initialize() -> void:
	var settings := _parse(OS.get_cmdline_user_args())
	var seeds := _seed_list(String(settings.get("seeds", "1-20")))
	_out_dir = String(settings.get("out-dir", ProjectSettings.globalize_path("res://").path_join("../../artifacts/local").simplify_path()))
	var rows: Array = stage_rows(seeds)
	var issues: Array = structural_issues(rows, seeds.size() * STAGE_COUNT)
	var text: String = render(rows)
	print(text)
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_write(_out_dir.path_join("shop-model.md"), text)
	_write(_out_dir.path_join("shop-model.tsv"), tsv(rows))
	if not issues.is_empty():
		printerr("shop_model: structural issues: %s" % [issues])
		quit(1)
		return
	print("shop_model: %d stage rows, %d world rows, written to %s" % [rows.size(), world_rows(rows).size(), _out_dir])
	quit(0)


static func stage_rows(seeds: Array) -> Array:
	var out: Array = []
	var maps := {}
	for seed_value in seeds:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("shop_model:%d" % int(seed_value))
		var parts := START_PARTS
		for stage in range(1, STAGE_COUNT + 1):
			var def: Dictionary = StageDefs.of(stage)
			var map_id := String(def["map"])
			if not maps.has(map_id):
				maps[map_id] = Terrain.MAPS[map_id].new()
			var map = maps[map_id]
			var price := Fabricators.price(REFERENCE_PART, parts)
			var gears := _line_cogs(map, float(def.get("scrap_density", 1.0)))
			var kill_scrap := float(def.get("kill_scrap", 1.0))
			var kills := int(round(BOT_KILLS * rng.randf_range(1.0 - BOT_JITTER, 1.0 + BOT_JITTER)))
			var line_share := BOT_LINE_SHARE * rng.randf_range(1.0 - BOT_JITTER, 1.0 + BOT_JITTER)
			var done := 0
			for spec in map.activity_sites:
				if Activities.RULES.has(String(spec["id"])) and rng.randf() < BOT_ACTIVITY_RATE:
					done += 1
			var income := gears * minf(line_share, 1.0) + kills * BOT_KILL_VALUE * kill_scrap \
				+ 30.0 * stage * kill_scrap + done * Activities.PAY_SCRAP
			out.append({"seed": int(seed_value), "stage": stage, "world": StageDefs.world_of(stage), "parts_held": parts,
				"activities": done, "price": price, "income": income, "ratio": float(price) / income if income > 0.0 else NAN,
				"in_band": income > 0.0 and float(price) / income >= BAND.x and float(price) / income <= BAND.y})
			parts += done
	return out


static func _line_cogs(map, density: float) -> float:
	var total := 0
	for line in map.scrap_lines:
		var from: Vector2 = line[0]
		var to: Vector2 = line[1]
		var n := clampi(int(from.distance_to(to) / ScrapField.SPACING * density), 4, int(ScrapField.MAX_PER_LINE * density))
		total += (n / ScrapField.COG_LINE_EVERY) * ScrapField.COG_LINE_VALUE
	return float(total)


static func world_rows(rows: Array) -> Array:
	var by_key := {}
	var order: Array = []
	for r in rows:
		var key := "%d:%d" % [r["seed"], r["world"]]
		if not by_key.has(key):
			by_key[key] = {"seed": r["seed"], "world": r["world"], "entry_price": r["price"], "income": 0.0, "stages": 0}
			order.append(key)
		by_key[key]["income"] += float(r["income"])
		by_key[key]["stages"] += 1
	var out: Array = []
	for key in order:
		var w: Dictionary = by_key[key]
		w["ratio"] = float(w["entry_price"]) / w["income"] if w["income"] > 0.0 else NAN
		out.append(w)
	return out


static func structural_issues(rows: Array, expect_rows: int) -> Array:
	var issues: Array = []
	if rows.is_empty():
		issues.append("no rows: the income log is empty")
		return issues
	if rows.size() != expect_rows:
		issues.append("row count %d, expected %d" % [rows.size(), expect_rows])
	for r in rows:
		for field in ["seed", "stage", "world", "price", "income", "ratio"]:
			if not r.has(field):
				issues.append("row missing %s" % field)
			elif typeof(r[field]) in [TYPE_FLOAT, TYPE_INT] and not is_finite(float(r[field])):
				issues.append("seed %s stage %s: %s is not finite" % [r.get("seed"), r.get("stage"), field])
		if r.has("income") and float(r["income"]) <= 0.0:
			issues.append("seed %s stage %s: income is zero" % [r.get("seed"), r.get("stage")])
		if r.has("price") and float(r["price"]) <= 0.0:
			issues.append("seed %s stage %s: price is zero" % [r.get("seed"), r.get("stage")])
	return issues


static func flags(rows: Array) -> Array:
	var out: Array = []
	var prev := {}
	for r in rows:
		var seed_value = r["seed"]
		if float(r["ratio"]) < BAND.x or float(r["ratio"]) > BAND.y:
			out.append("outside_band: seed %s stage %s ratio %.3f" % [seed_value, r["stage"], r["ratio"]])
		if prev.has(seed_value):
			var p: Dictionary = prev[seed_value]
			if r["world"] == p["world"] and r["price"] < p["price"]:
				out.append("price_falls: seed %s stage %s %s -> %s" % [seed_value, r["stage"], p["price"], r["price"]])
			elif r["world"] != p["world"] and r["price"] <= p["price"]:
				out.append("no_boundary_rise: seed %s stage %s %s -> %s" % [seed_value, r["stage"], p["price"], r["price"]])
		prev[seed_value] = r
	return out


static func render(rows: Array) -> String:
	var lines: Array[String] = []
	lines.append("# Shop price-to-income report (SG16)")
	lines.append("")
	lines.append("Report only. No price is proposed or changed (owner item 4). Reference item `%s`, price = Fabricators.price(part, parts held on entering the stage). Income = cog wallet per stage (activities and kills pay scrap and equal cogs). Target band %.1f to %.1f." % [REFERENCE_PART, BAND.x, BAND.y])
	lines.append("PAY_SCRAP %d, COG_PRICES part_base %s, part_growth %s, part_tier %s." % [Activities.PAY_SCRAP, Fabricators.COG_PRICES["part_base"], Fabricators.COG_PRICES["part_growth"], Fabricators.COG_PRICES["part_tier"]])
	lines.append("")
	lines.append("## Per stage, across seeds (min / mean / max)")
	lines.append("")
	lines.append("| world | stage | price min / mean / max | income min / mean / max | ratio min / mean / max | seeds outside band |")
	lines.append("|---|---|---|---|---|---|")
	for stage in range(1, STAGE_COUNT + 1):
		var sel: Array = rows.filter(func(r): return r["stage"] == stage)
		if sel.is_empty():
			continue
		var out_n := 0
		for r in sel:
			if not r["in_band"]:
				out_n += 1
		lines.append("| %d | %d | %s | %s | %s | %d of %d |" % [sel[0]["world"], stage, _spread(sel, "price", "%d"), _spread(sel, "income", "%.0f"), _spread(sel, "ratio", "%.3f"), out_n, sel.size()])
	lines.append("")
	lines.append("## Per world (price on entering, summed income, ratio), min / mean / max across seeds")
	lines.append("")
	lines.append("| world | entry price | income | ratio |")
	lines.append("|---|---|---|---|")
	var worlds: Array = world_rows(rows)
	for w in range(1, 4):
		var sel_w: Array = worlds.filter(func(r): return r["world"] == w)
		if sel_w.is_empty():
			continue
		lines.append("| %d | %s | %s | %s |" % [w, _spread(sel_w, "entry_price", "%d"), _spread(sel_w, "income", "%.0f"), _spread(sel_w, "ratio", "%.3f")])
	var found: Array = flags(rows)
	lines.append("")
	lines.append("## Flags (%d)" % found.size())
	lines.append("")
	if found.is_empty():
		lines.append("None.")
	var shown := 0
	for f in found:
		if shown >= 40:
			lines.append("- ... %d more (see shop-model.tsv for every row)" % (found.size() - shown))
			break
		lines.append("- " + String(f))
		shown += 1
	lines.append("")
	lines.append("%d stage rows." % rows.size())
	return "\n".join(lines) + "\n"


static func tsv(rows: Array) -> String:
	var lines: Array[String] = ["seed\tworld\tstage\tparts_held\tactivities\tprice\tincome\tratio\tin_band"]
	for r in rows:
		lines.append("%d\t%d\t%d\t%d\t%d\t%d\t%.1f\t%.4f\t%s" % [r["seed"], r["world"], r["stage"], r["parts_held"], r["activities"], r["price"], r["income"], r["ratio"], str(r["in_band"])])
	return "\n".join(lines) + "\n"


static func _spread(rows: Array, field: String, fmt: String) -> String:
	var lo := INF
	var hi := -INF
	var sum := 0.0
	for r in rows:
		var v := float(r[field])
		lo = minf(lo, v)
		hi = maxf(hi, v)
		sum += v
	return (fmt + " / " + fmt + " / " + fmt) % [lo, sum / rows.size(), hi]


static func _seed_list(spec: String) -> Array:
	var out: Array = []
	for part in spec.split(","):
		if "-" in part:
			var ends := part.split("-")
			for s in range(int(ends[0]), int(ends[1]) + 1):
				out.append(s)
		elif part.is_valid_int():
			out.append(int(part))
	return out


static func _parse(args: PackedStringArray) -> Dictionary:
	var out := {}
	for a in args:
		if a.begins_with("--") and "=" in a:
			var kv := a.substr(2).split("=", true, 1)
			out[kv[0]] = kv[1]
	return out


static func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(text)
		f.close()
