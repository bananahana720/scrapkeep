extends SceneTree

const Synergies := preload("res://src/build/synergies.gd")
const UpgradeTree := preload("res://src/core/upgrade_tree.gd")
const BuildSheet := preload("res://src/build/build_sheet.gd")
const Parts := preload("res://src/build/parts.gd")

# SG14 slot growth sweep (W13-INTEGRATION-3.md SG14; comps/gunfire/weapons-and-inscriptions.md:93).
# The arm is tools/build_sweep.gd --arm=slot_growth. Its rows are one per milestone (worlds one to
# three), read from UpgradeTree.depth_cap, and its numbers come from the same BuildSheet.power()
# estimate the stack arm uses on a fixed dummy.
#
# (a) slot count matches the depth cap at each milestone, never decreases, and reaches
#     UpgradeTree.DEPTHS at the last milestone.
# (b) at every milestone with a pair available, the best paired set is no weaker than the best
#     set with that trick asleep, and beats it by at most 40%. The floor was 15% while tag pairs
#     made synergies; since systems audit pass D a trick wakes on two pieces of one maker and is
#     a rule change the power estimate mostly cannot see (Storm Lattice's chain jumps are the one
#     it counts), so a floor above zero measured nothing the player meets. Re-setting a floor is
#     the world 1 economy pass's call (docs/systems-audit/).
# (c) the best set at the last milestone is at most 6x the best set at the first.
# (d) every trick does something the player meets: two pieces of its maker, folded with the trick
#     awake and again with it asleep (a table that leaves it out), give different builds (a
#     transformer, pattern level, element trigger, dial or mod only the awake one has). This keeps
#     the old 15% floor's intent, "a pair pays", at no extra wall-clock time; whether a trick is
#     worth taking is a world 1 economy sim arm. A planted row with no effect must fail it.
# Each band is written here, not read from the tool, so the test cannot pass by reading the tool's
# own constants. Planted rows must make each gate fire, or the zero above proves nothing.

const MARGIN_MIN := 0.0
const MARGIN_MAX := 0.40
const RATIO_MAX := 6.0
const NULL_MAX := 0.05
const EPS := 1e-6
# Six checks: schedule, margins, last-vs-first, pair availability, controls, every trick acts. Any other count fails.
const EXPECTED_REPORTS := 6

var _failures := 0
var _reports := 0


func _initialize() -> void:
	var tool: Script = load("res://tools/build_sweep.gd")
	if not tool.has_method("slot_growth_arm") or not tool.has_method("slot_growth_problems"):
		# Red until the arm exists: every check reports, so the count still holds.
		for label in ["schedule (a)", "pair margins (b)", "last vs first (c)", "pair availability", "controls fire", "every trick acts (d)"]:
			_report(label, false, "tools/build_sweep.gd has no slot_growth_arm yet")
	else:
		var rows: Array = tool.call("slot_growth_arm")
		_check_schedule(rows)
		_check_margins(rows)
		_check_last_vs_first(rows)
		_check_pair_availability(rows)
		_check_tricks_act()
		_check_controls(tool)
	if _reports != EXPECTED_REPORTS:
		_failures += 1
		print("FAIL report count: %d of %d checks reported (a check died mid-way)" % [_reports, EXPECTED_REPORTS])
	print("slot_growth_sweep_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


func _report(label: String, ok: bool, detail: String) -> void:
	_reports += 1
	print("%s %s: %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures += 1


func _check_schedule(rows: Array) -> void:
	var slots: Array = []
	var expected: Array = []
	var worlds: Array = []
	for row in rows:
		slots.append(int(row["slots"]))
		worlds.append(int(row["world"]))
		expected.append(UpgradeTree.depth_cap(int(row["world"])))
	var never_down := true
	for i in range(1, slots.size()):
		if slots[i] < slots[i - 1]:
			never_down = false
	_report("schedule (a)", rows.size() == 3 and worlds == [1, 2, 3] and slots == expected and never_down
		and slots.size() > 0 and slots[-1] == UpgradeTree.DEPTHS,
		"worlds %s, slots %s (depth cap %s, DEPTHS %d), never falls %s"
			% [worlds, slots, expected, UpgradeTree.DEPTHS, never_down])


func _check_margins(rows: Array) -> void:
	var paired_rows := 0
	var bad: Array = []
	var margins: Array = []
	for row in rows:
		if not row["pair_available"]:
			continue
		paired_rows += 1
		var m := float(row["margin"])
		margins.append(snappedf(m, 0.001))
		if m < MARGIN_MIN - EPS or m > MARGIN_MAX + EPS:
			bad.append("world %d margin %.3f" % [int(row["world"]), m])
	_report("pair margins (b)", paired_rows == rows.size() and rows.size() > 0 and bad.is_empty(),
		"%d of %d milestones have a pair; margins %s against band %d%% to %d%%; out of band %s"
			% [paired_rows, rows.size(), margins, int(MARGIN_MIN * 100), int(MARGIN_MAX * 100), bad])


func _check_last_vs_first(rows: Array) -> void:
	if rows.size() < 2:
		_report("last vs first (c)", false, "fewer than two milestones")
		return
	var first_best := float(rows[0]["best"])
	var last_best := float(rows[-1]["best"])
	var ratio := last_best / maxf(first_best, EPS)
	_report("last vs first (c)", ratio >= 1.0 - EPS and ratio <= RATIO_MAX + EPS,
		"first best %.2f, last best %.2f, ratio %.2fx (limit %sx)" % [first_best, last_best, ratio, RATIO_MAX])


func _check_pair_availability(rows: Array) -> void:
	var named := 0
	for row in rows:
		named = maxi(named, int(row.get("named_pairs", 0)))
	var called: int = Synergies.ROWS.keys().filter(func(id): return not Synergies.callout(id).is_empty()).size()
	_report("pair availability", named == called and rows.size() > 0,
		"%d of %d tricks with a callout pair have its first part and another piece of its maker in the legal pool" % [named, called])


func _check_controls(tool: Script) -> void:
	var decreasing := [_row(1, 3, true, 0.25, 10.0), _row(2, 2, true, 0.25, 12.0), _row(3, 4, true, 0.25, 14.0)]
	var out_of_band := [_row(1, 2, true, 0.50, 10.0), _row(2, 3, true, 0.20, 12.0), _row(3, 4, true, 0.20, 14.0)]
	var over_ratio := [_row(1, 2, true, 0.25, 10.0), _row(2, 3, true, 0.25, 30.0), _row(3, 4, true, 0.25, 70.0)]
	var clean := [_row(1, 2, true, 0.20, 10.0), _row(2, 3, true, 0.25, 12.0), _row(3, 4, true, 0.30, 20.0)]
	var caught_dec: Array = tool.call("slot_growth_problems", decreasing)
	var caught_band: Array = tool.call("slot_growth_problems", out_of_band)
	var caught_ratio: Array = tool.call("slot_growth_problems", over_ratio)
	var clean_problems: Array = tool.call("slot_growth_problems", clean)
	# Planted null: a named pair whose partner adds no power on its own must not show a positive
	# margin (a false gain would inflate the band check). One-sided on purpose: a neutral partner
	# can measure below zero, because the paired greedy spends the slot the substitute fills.
	var nul: Dictionary = tool.call("slot_growth_null", UpgradeTree.DEPTHS)
	var null_ok := String(nul["row"]) != "" and float(nul["margin"]) <= NULL_MAX + EPS
	_report("controls fire", caught_dec.size() > 0 and caught_band.size() > 0 and caught_ratio.size() > 0
		and clean_problems.is_empty() and null_ok,
		"falling slots -> %s; out-of-band margin -> %s; 7x last-vs-first -> %s; clean planted rows -> %s; null pair %s margin %.1f%% (no gain above %d%%)"
			% [caught_dec, caught_band, caught_ratio, clean_problems, nul["row"],
				100.0 * float(nul["margin"]), int(100.0 * NULL_MAX)])


func _row(world: int, slots: int, pair_ok: bool, margin: float, best: float) -> Dictionary:
	return {"world": world, "slots": slots, "pair_available": pair_ok, "margin": margin, "best": best,
		"named_pairs": Synergies.ROWS.size()}


# A stage table that keeps every trick but one.
class Without:
	var skip := ""

	func _init(trick_id: String) -> void:
		skip = trick_id

	func synergy_in_play(trick_id: String) -> bool:
		return trick_id != skip


# What the build hands the game: everything a trick's row can fold in.
static func _build_of(sheet) -> String:
	return var_to_str([sheet.transformers, sheet.patterns, sheet.triggers, sheet.dials, sheet.mods])


# Two distinct class-neutral pieces of the trick's maker: its callout pair when it has one.
static func _pieces(trick_id: String) -> Array:
	var call := Synergies.callout(trick_id)
	if not call.is_empty():
		return [call["a"], call["b"]]
	var out: Array = []
	for part_id in Parts.ids():
		if out.size() < 2 and Parts.maker_of(part_id) == Synergies.ROWS[trick_id]["maker"] and Parts.def(part_id).class_id == "":
			out.append(part_id)
	return out


func _check_tricks_act() -> void:
	var saved = Synergies.table
	var idle: Array = []
	for trick_id in Synergies.ROWS:
		var pieces := _pieces(trick_id)
		Synergies.table = null
		var awake = BuildSheet.from_parts(pieces)
		Synergies.table = Without.new(trick_id)
		var asleep = BuildSheet.from_parts(pieces)
		if not trick_id in awake.synergies or trick_id in asleep.synergies or _build_of(awake) == _build_of(asleep):
			idle.append("%s %s" % [trick_id, pieces])
	Synergies.table = saved
	# Planted: a trick row with no effect, folded onto a real asleep build, changes nothing.
	var planted = BuildSheet.from_parts(_pieces("wrecking_ball"))
	var before := _build_of(planted)
	planted.fold_row({"name": "Planted", "maker": "fleet_surplus", "tags": ["speed"], "text": ""})
	var caught := _build_of(planted) == before
	_report("every trick acts (d)", idle.is_empty() and caught,
		"%d tricks folded awake and asleep; no difference for %s; planted empty row caught %s" % [Synergies.ROWS.size(), idle, caught])
