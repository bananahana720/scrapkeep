extends SceneTree

const ShopModel := preload("res://tools/shop_model.gd")
const Fabricators := preload("res://src/build/fabricators.gd")
const Activities := preload("res://src/world/activities.gd")

# SG16, the shop price-to-income report. Report-then-gate: this test asserts the report's
# structure (a nonzero row count, every field filled and finite, deterministic from the seed)
# and that its flag logic fires on planted defects. It asserts no price or ratio band, because
# the prices are Andrew's (owner item 4) and nothing here adopts one. It also pins the price
# constants it reads, so a unit that edits one fails here and not silently.
#
# Rows: 3 worlds x 2 stages x 20 seeds = 120 stage rows, plus 60 (seed, world) rows.

const SEEDS := 20
const STAGES := 6

var _failures := 0


func _initialize() -> void:
	var seeds: Array = range(1, SEEDS + 1)
	var rows: Array = ShopModel.stage_rows(seeds)
	_check(rows.size() == SEEDS * STAGES, "stage row count", "rows=%d want %d" % [rows.size(), SEEDS * STAGES])
	_check(ShopModel.world_rows(rows).size() == SEEDS * 3, "world row count", "rows=%d want %d" % [ShopModel.world_rows(rows).size(), SEEDS * 3])
	var issues: Array = ShopModel.structural_issues(rows, SEEDS * STAGES)
	_check(issues.is_empty(), "real rows are structurally sound", "issues=%s" % [issues])
	var worlds := {}
	for r in rows:
		worlds[r["world"]] = true
	_check(worlds.size() == 3, "three worlds present", "worlds=%s" % [worlds.keys()])
	_check(ShopModel.stage_rows(seeds) == rows, "deterministic from the seed", "second run equals first")
	_check(ShopModel.stage_rows([1]) != ShopModel.stage_rows([2]), "seeds differ", "seed 1 vs seed 2 rows differ")
	var text: String = ShopModel.render(rows)
	_check(text.contains("ratio") and text.contains("stage"), "report prints the table", "chars=%d" % text.length())

	# A planted empty income log must fail loud: no rows, then rows with their income zeroed.
	var empty_issues: Array = ShopModel.structural_issues([], SEEDS * STAGES)
	_check(not empty_issues.is_empty(), "planted empty log fails", "issues=%s" % [empty_issues])
	var zeroed: Array = rows.duplicate(true)
	for r in zeroed:
		r["income"] = 0
	_check(not ShopModel.structural_issues(zeroed, SEEDS * STAGES).is_empty(), "planted zero income fails", "zeroed %d rows" % zeroed.size())
	var nan_rows: Array = rows.duplicate(true)
	nan_rows[0]["ratio"] = NAN
	_check(not ShopModel.structural_issues(nan_rows, SEEDS * STAGES).is_empty(), "planted NaN ratio fails", "nan injected")

	# The flag logic fires on planted defects: a ratio outside the band, a price that falls
	# inside a world and a price that does not rise at a world boundary.
	var planted := [
		_row(1, 1, 1, 100, 100.0), _row(1, 2, 1, 90, 100.0),
		_row(1, 3, 2, 90, 100.0), _row(1, 4, 2, 95, 400.0),
	]
	var flags: Array = ShopModel.flags(planted)
	_check(_has(flags, "outside_band"), "flags a ratio outside 0.5 to 2.0", "flags=%s" % [flags])
	_check(_has(flags, "price_falls"), "flags a price that falls inside a world", "flags=%s" % [flags])
	_check(_has(flags, "no_boundary_rise"), "flags a flat boundary", "flags=%s" % [flags])
	var clean := [_row(1, 1, 1, 100, 100.0), _row(1, 2, 1, 110, 100.0), _row(1, 3, 2, 200, 150.0)]
	_check(ShopModel.flags(clean).is_empty(), "clean planted rows raise no flag", "flags=%s" % [ShopModel.flags(clean)])

	# Reports only: the constants it reads are the ones on the branch.
	_check(Activities.PAY_SCRAP == 180, "PAY_SCRAP unchanged", "PAY_SCRAP=%d" % Activities.PAY_SCRAP)
	var p: Dictionary = Fabricators.COG_PRICES
	_check(p["part_base"] == 10.0 and p["part_growth"] == 1.15 and p["part_tier"] == {1: 1.0, 2: 1.6, 3: 2.6}, "part price constants unchanged", "part_base=%s growth=%s" % [p["part_base"], p["part_growth"]])
	print("shop_model_report_test: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


static func _row(seed_value: int, stage: int, world: int, price: int, income: float) -> Dictionary:
	return {"seed": seed_value, "stage": stage, "world": world, "price": price, "income": income, "ratio": float(price) / income}


static func _has(flags: Array, kind: String) -> bool:
	for f in flags:
		if String(f).begins_with(kind):
			return true
	return false


func _check(ok: bool, label: String, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])
