# 2026-10-11 (PC-SABLE): Pit Coil and Storm Crater become line relics; Crater Heart alone keeps the crater.
extends SceneTree

const Relics := preload("res://src/build/relics.gd")
const AbilityState := preload("res://src/core/ability_state.gd")

# RL1: the relic table is sound. Names are at most three words, effect text at most
# eight, every row rewrites one slot that exists in each of its pilots' kits, every
# pilot has at least two relics, and the one-per-slot rule refuses a second relic for a
# held slot.

var _failures := 0
var _checks := 0


func _report(label: String, ok: bool, detail: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _initialize() -> void:
	var problems := Relics.validate()
	_report("validator", problems.is_empty(), "table problems: %s" % [problems])
	var long_name := Relics.ids().filter(func(i): return Relics.name_of(i).split(" ", false).size() > 3)
	var long_text := Relics.ids().filter(func(i): return String(Relics.row(i)["text"]).split(" ", false).size() > 8)
	_report("caps", long_name.is_empty() and long_text.is_empty(), "name over 3 words %s, text over 8 words %s" % [long_name, long_text])
	for pilot in Relics.PILOTS:
		var mine := Relics.eligible(pilot, {})
		_report("pilot " + pilot, mine.size() >= 2, "%d relics %s" % [mine.size(), mine])
	var held := {AbilityState.SPECIAL: "quick_fuse"}
	_report("one per slot", not Relics.can_hold("quick_fuse", "pylon_engineer", held)
		and Relics.can_hold("crater_heart", "pylon_engineer", held)
		and not Relics.can_hold("long_fuse", "pylon_engineer", {}), "held slot refused, free slot and wrong pilot checked")
	_report("eligible skips held", not "quick_fuse" in Relics.eligible("pylon_engineer", held), "%s" % [Relics.eligible("pylon_engineer", held)])
	_report("tarn has its own relics", not Relics.fits("muzzle_heart", "tarn") and Relics.fits("muzzle_heart", "runner_gunner") and Relics.eligible("tarn", {}) == ["taut_cable", "vice_heart", "gutter_heart", "rake_heart", "spare_cable", "jaw_spring", "redjaw_cable", "twin_jaw"], "%s" % [Relics.eligible("tarn", {})])
	_report("tally has its own relics", Relics.eligible("tally", {}) == ["oiled_flywheel", "return_spring", "ink_heart", "double_entry", "spare_flywheel", "plate_hinge", "brass_governor", "second_plate"], "%s" % [Relics.eligible("tally", {})])
	_report("the cannon has its own relics", Relics.eligible("remembered_cannon", {}) == ["kick_spring", "brace_pin", "second_kick", "brace_spring", "hot_breech", "twin_plate"], "%s" % [Relics.eligible("remembered_cannon", {})])
	_report("Sable keeps one crater", Relics.ids().filter(func(id): return Relics.fits(id, "pylon_engineer") and Relics.swap_of(id) == "crater_slam") == ["crater_heart"], "Crater Heart only")
	_report("two Bank Shot relics", Relics.slot_of("pit_coil") == AbilityState.LINE and Relics.row("pit_coil")["cooldown"] == 0.7 and Relics.slot_of("storm_crater") == AbilityState.LINE and Relics.row("storm_crater")["charges"] == 1, "Pit Coil recharge; Storm Crater stock")
	# A bad row must be caught.
	var bad_rows: Dictionary = Relics.ROWS.duplicate(true)
	bad_rows["quick_fuse"]["slot"] = "nowhere"
	bad_rows["long_fuse"]["text"] = "one two three four five six seven eight nine"
	_report("validator catches", Relics.validate(bad_rows).size() >= 2, "%s" % [Relics.validate(bad_rows)])
	print("relics_data_test: %s" % ("PASS (%d checks)" % _checks if _failures == 0 else "FAIL (%d of %d checks)" % [_failures, _checks]))
	quit(0 if _failures == 0 else 1)
