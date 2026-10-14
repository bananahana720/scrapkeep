extends SceneTree

const ClassDef := preload("res://src/core/class_def.gd")
const RunState := preload("res://src/core/run_state.gd")
const T := preload("res://tests/support/t.gd")

# SQ8 Baseline ratios (W13-INTEGRATION-3.md, unit sq8-baseline-ratios). Each pilot's baseline
# is stated as ratios to Sable, the starter: hull (base_hp) and hull gained per heft class
# (hp_growth). comps/roboquest/classes-and-perks.md found the baseline is a class's first
# layer and that the heavier class also grows faster per level; Scrapkeep states its own
# start values and copies none of the source's numbers.
#
# Checks: the class_def rows, the PILOTS.md section 7 table against them, the spread and
# the order rule. The live reading (a run begun as each pilot starts at its base_hp) is
# printed for every pilot and asserted only once GATE_LIVE is true: run_state.gd begin(),
# build_sheet.gd BASE_MAX_HP and build.gd's ceiling still read one shared 100, and those
# files sit outside SQ8's scope. The wiring unit flips GATE_LIVE.

const GATE_LIVE := false # The wiring unit (run_state, build_sheet, build) flips this to true.
const REFERENCE := "pylon_engineer"
const PILOT_NAMES := {"pylon_engineer": "Sable", "runner_gunner": "Rivet", "demolitions_caster": "Kest",
	"tarn": "Tarn", "tally": "Tally", "remembered_cannon": "The Cannon"}
# A declared ratio cell is written to two decimals, so it matches the code within half a unit.
const DOC_TOLERANCE := 0.005
# The live ratio a begun run reads may drift from the declared one by at most this much.
const LIVE_TOLERANCE := 0.02
# Distinct baselines: the heaviest hull is at least SPREAD_MIN times the lightest, and at
# most SPREAD_MAX (readable-capped scaling: no pilot doubles another).
const SPREAD_MIN := 1.5
const SPREAD_MAX := 2.0
# 6 pilots x 2 row checks, 1 readable, 1 heading, 1 row count, 6 x 2 ratio cells, spread
# min, spread max, order rule. GATE_LIVE adds 6 live checks.
const EXPECTED_CHECKS := 30


func _ratio(def: Resource, ref: Resource, key: String) -> float:
	return float(def.get(key)) / maxf(0.0001, float(ref.get(key)))


func _initialize() -> void:
	var t := T.new("pilot_baseline_ratio_test")
	var defs := ClassDef.all()
	var ref: Resource = ClassDef.by_id(REFERENCE)

	for def in defs:
		var hp = def.get("base_hp")
		var growth = def.get("hp_growth")
		t.check("%s has a finite positive base_hp" % def.id, hp != null and is_finite(float(hp)) and float(hp) > 0.0, str(hp))
		t.check("%s has a finite hp_growth of at least 0" % def.id, growth != null and is_finite(float(growth)) and float(growth) >= 0.0, str(growth))

	# PILOTS.md section 7 states the same rows as ratios to Sable.
	var text := FileAccess.get_file_as_string("res://design-v3/PILOTS.md")
	t.check("PILOTS.md is readable", text.length() > 0, "")
	var lines := text.split("\n")
	var start := -1
	for i in lines.size():
		if lines[i].begins_with("## 7. Baseline ratios"):
			start = i
	t.check("PILOTS.md has the section 7 baseline table", start >= 0, "")
	var rows_md := {}
	if start >= 0:
		for i in range(start + 1, lines.size()):
			if lines[i].begins_with("## "):
				break
			for id in PILOT_NAMES:
				if lines[i].begins_with("| **%s** |" % PILOT_NAMES[id]) and not rows_md.has(id):
					rows_md[id] = lines[i]
	t.eq("baseline table has six pilot rows", rows_md.size(), 6)

	print("")
	print("BASELINE  pilot  base_hp  hull ratio  hp_growth  growth ratio  declared hull  declared growth")
	for def in defs:
		if ref == null or def.get("base_hp") == null or def.get("hp_growth") == null:
			continue
		var hull := _ratio(def, ref, "base_hp")
		var grow := _ratio(def, ref, "hp_growth")
		var cells: PackedStringArray = (rows_md.get(def.id, "") as String).split("|")
		# | Pilot | base_hp | hull ratio | hp_growth | growth ratio | why |
		var d_hull := float(cells[3].strip_edges()) if cells.size() > 6 else -1.0
		var d_grow := float(cells[5].strip_edges()) if cells.size() > 6 else -1.0
		print("BASELINE  %s  %.0f  %.2f  %.1f  %.2f  %.2f  %.2f" % [PILOT_NAMES.get(def.id, def.id),
			float(def.base_hp), hull, float(def.hp_growth), grow, d_hull, d_grow])
		t.check("%s declared hull ratio matches class_def" % def.id, absf(d_hull - hull) <= DOC_TOLERANCE, "declared %.2f, code %.3f" % [d_hull, hull])
		t.check("%s declared growth ratio matches class_def" % def.id, absf(d_grow - grow) <= DOC_TOLERANCE, "declared %.2f, code %.3f" % [d_grow, grow])

	var hulls: Array = []
	var pairs: Array = []
	for def in defs:
		if def.get("base_hp") != null and def.get("hp_growth") != null:
			hulls.append(float(def.base_hp))
			pairs.append([float(def.base_hp), float(def.hp_growth), def.id])
	var spread: float = (hulls.max() / maxf(0.0001, hulls.min())) if not hulls.is_empty() else 0.0
	t.check("heaviest hull is at least %.1fx the lightest" % SPREAD_MIN, spread >= SPREAD_MIN, "%.3f" % spread)
	t.check("heaviest hull is at most %.1fx the lightest" % SPREAD_MAX, spread <= SPREAD_MAX and spread > 0.0, "%.3f" % spread)
	# The lighter hull never grows faster per heft class than a heavier one.
	pairs.sort_custom(func(a, b): return a[0] < b[0])
	var ordered := pairs.size() == 6
	var why := ""
	for i in range(1, pairs.size()):
		if pairs[i][1] < pairs[i - 1][1]:
			ordered = false
			why = "%s grows less than %s" % [pairs[i][2], pairs[i - 1][2]]
	t.check("hp_growth never falls as base_hp rises", ordered, why)

	# Live: a run begun as each pilot starts at its own hull.
	var ref_live := -1.0
	var live := {}
	for def in defs:
		var run = RunState.new()
		run.begin(def)
		live[def.id] = float(run.max_hp)
		if def.id == REFERENCE:
			ref_live = float(run.max_hp)
	for def in defs:
		if def.get("base_hp") == null or ref == null:
			continue
		var live_ratio: float = live[def.id] / maxf(0.0001, ref_live)
		var want := _ratio(def, ref, "base_hp")
		var inside := absf(live_ratio - want) <= LIVE_TOLERANCE
		print("LIVE  %s  begun max_hp %.0f  ratio %.2f  declared %.2f  %s" % [PILOT_NAMES.get(def.id, def.id),
			live[def.id], live_ratio, want, "inside" if inside else "NOT WIRED"])
		if GATE_LIVE:
			t.check("%s begun run reads its hull ratio" % def.id, inside, "%.3f vs %.3f" % [live_ratio, want])

	var expected := EXPECTED_CHECKS + (6 if GATE_LIVE else 0)
	t.eq("check count", t.checks, expected)
	quit(t.verdict())
