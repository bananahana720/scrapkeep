extends SceneTree

# CUSTOMIZE.md sections 3, 4 and 9: the at_least field, the first_time rule on named
# discoveries, backfill_discoveries at setup, the toast's item line and the invariant that
# every non-starter cosmetic is the reward of exactly one achievement row.

const Achievements := preload("res://src/core/achievements.gd")
const Cosmetics := preload("res://src/core/cosmetics.gd")
const Profile := preload("res://src/core/profile.gd")
const Progress := preload("res://src/core/progress.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const T := preload("res://tests/support/t.gd")


# The codex's one read the backfill uses.
class FakeCodex:
	extends RefCounted
	var ids := {}

	func known(id: String) -> bool:
		return ids.has(id)


# A bus with one signal carrying a counted argument, as ultimate_landed will (SKILL-BAR section 7).
class Bus:
	extends Node
	signal synergy_discovered(synergy_id: String, category: String, first_time: bool)
	signal ultimate_landed(ultimate_id: String, hits: int)
	signal achievement_earned(id: String)
	signal player_died
	signal run_ended(won: bool)


var _t := T.new("grant_grammar_test")
var _serial := 0


func _initialize() -> void:
	_invariant()
	_at_least()
	_at_least_validate()
	_first_time_rule()
	_backfill_discoveries()
	_toast()
	quit(_t.verdict())


func _fresh() -> Profile:
	_serial += 1
	var store := Profile.new("user://grant-%d-%d.json" % [OS.get_process_id(), _serial])
	store.load_profile()
	return store


func _pilots() -> Array:
	return ClassDef.all().map(func(d): return d.id)


func _invariant() -> void:
	_t.eq("achievements validate", Achievements.validate(Achievements.ROWS, Achievements.bus_signals(), _pilots(), Cosmetics.ids()), [])
	var checked := 0
	for id in Cosmetics.ids():
		if Cosmetics.row(id)["starter"]:
			continue
		checked += 1
		var granters: Array = []
		for row_id in Achievements.ids():
			if Achievements.reward_of(row_id).get("cosmetic", "") == id:
				granters.append(row_id)
		_t.check("%s is the reward of exactly one row" % id, granters.size() == 1, str(granters))
		_t.eq("for_cosmetic %s" % id, Achievements.for_cosmetic(id), granters[0] if granters.size() == 1 else "?")
	_t.check("every non-starter cosmetic was checked", checked >= 30, str(checked))
	_t.eq("a starter has no grant row", Achievements.for_cosmetic("paint_any_salt"), "")
	for id in ["ach_any_set_piece", "ach_any_curtain_call", "ach_any_cash_in"]:
		var row := Achievements.row(id)
		_t.check("%s is on synergy_discovered with one synergy_id and no first_time" % id, row.get("on") == "synergy_discovered" and row["where"].has("synergy_id") and not row["where"].has("first_time"))


func _rows_six() -> Dictionary:
	return {"six": {"name": "Full Breach", "text": "Land one ultimate on six machines.", "on": "ultimate_landed",
		"where": {"ultimate_id": "foundry_cutter"}, "at_least": {"hits": 6}, "count": 1, "reward": {"cosmetic": "trail_salt_skip"}}}


func _at_least() -> void:
	var store := _fresh()
	var bus := Bus.new()
	var listener := Progress.new()
	listener.rows = _rows_six()
	listener.setup(bus, null, store, func(): return 50.0)
	var earned: Array = []
	bus.achievement_earned.connect(func(id): earned.append(id))
	bus.ultimate_landed.emit("foundry_cutter", 5)
	_t.eq("a fact under the number does not count", listener.count_of("six"), 0.0)
	_t.check("a fact under the number does not earn", not store.earned("six") and not store.has_cosmetic("trail_salt_skip"))
	bus.ultimate_landed.emit("redjaw_rend", 9)
	_t.check("a fact at the number but the wrong where does not earn", not store.earned("six"))
	bus.ultimate_landed.emit("foundry_cutter", 6)
	_t.check("a fact at the number earns", store.earned("six") and store.has_cosmetic("trail_salt_skip"))
	bus.ultimate_landed.emit("foundry_cutter", 9)
	_t.eq("it earns once", earned, ["six"])
	var reload := Profile.new(store.path)
	reload.load_profile()
	_t.check("the earn saved", reload.earned("six") and reload.has_cosmetic("trail_salt_skip"))
	listener.free()
	bus.free()


func _signals() -> Dictionary:
	var bus := Bus.new()
	var out := {}
	for info in bus.get_signal_list():
		var names: Array = []
		for arg in info["args"]:
			names.append(arg["name"])
		out[info["name"]] = names
	bus.free()
	return out


# validate needs MIN_ROWS rows; pad with the shipped table.
func _with(rows: Dictionary) -> Dictionary:
	var out := Achievements.ROWS.duplicate(true)
	for id in rows:
		out[id] = rows[id]
	return out


func _at_least_validate() -> void:
	var signals := Achievements.bus_signals()
	signals.merge(_signals())
	var cosmetics := Cosmetics.ids()
	var good := _with(_rows_six())
	_t.eq("an at_least on an argument validates", Achievements.validate(good, signals, _pilots(), cosmetics), [])
	var bad := _with(_rows_six())
	bad["six"]["at_least"] = {"machines": 6}
	var problems := Achievements.validate(bad, signals, _pilots(), cosmetics)
	_t.check("validate refuses an at_least key that is not an argument of on", problems.any(func(p): return String(p).contains("at_least key machines")), str(problems))
	bad["six"]["at_least"] = {"hits": "six"}
	problems = Achievements.validate(bad, signals, _pilots(), cosmetics)
	_t.check("validate refuses an at_least value that is not a number", problems.any(func(p): return String(p).contains("must be a number")), str(problems))


func _first_time_rule() -> void:
	var rows := _with({"named": {"name": "Parting Shot", "text": "Kill a machine after a slingshot.", "on": "synergy_discovered",
		"where": {"synergy_id": "parting_shot", "first_time": true}, "count": 1, "reward": {"cosmetic": "trail_salt_skip"}}})
	var problems := Achievements.validate(rows, Achievements.bus_signals(), _pilots(), Cosmetics.ids())
	_t.check("a row naming one synergy_id with first_time fails validation", problems.any(func(p): return String(p).contains("cannot filter first_time")), str(problems))
	rows["named"]["where"].erase("first_time")
	problems = Achievements.validate(rows, Achievements.bus_signals(), _pilots(), Cosmetics.ids())
	_t.check("the same row without first_time passes", not problems.any(func(p): return String(p).begins_with("named")), str(problems))


func _parting_shot_rows() -> Dictionary:
	return {"ach_sable_parting_shot": {"name": "Parting Shot", "text": "Kill a machine within a second of a pylon slingshot.", "on": "synergy_discovered",
		"where": {"synergy_id": "parting_shot"}, "count": 1, "reward": {"cosmetic": "decal_fern"}},
		"other": {"name": "Other", "text": "Something else.", "on": "synergy_discovered",
		"where": {"synergy_id": "never_found"}, "count": 1, "reward": {"cosmetic": "decal_patch"}}}


func _backfill_discoveries() -> void:
	var store := _fresh()
	var codex := FakeCodex.new()
	codex.ids["parting_shot"] = true
	var bus := Bus.new()
	var listener := Progress.new()
	listener.rows = _parting_shot_rows()
	var earned: Array = []
	bus.achievement_earned.connect(func(id): earned.append(id))
	listener.setup(bus, null, store, func(): return 70.0, codex)
	_t.check("a known discovery earns its row at setup", store.earned("ach_sable_parting_shot") and store.has_cosmetic("decal_fern"))
	_t.check("an unknown discovery earns nothing", not store.earned("other") and not store.has_cosmetic("decal_patch"))
	_t.eq("the backfill announced once", earned, ["ach_sable_parting_shot"])
	var reload := Profile.new(store.path)
	reload.load_profile()
	_t.check("the backfill saved", reload.earned("ach_sable_parting_shot") and reload.has_cosmetic("decal_fern"))
	var settled_before := store.settled_ids().size()
	var generation_before := store.generation()
	var second := Progress.new()
	second.rows = _parting_shot_rows()
	second.setup(bus, null, store, func(): return 80.0, codex)
	_t.eq("a second setup grants nothing", earned, ["ach_sable_parting_shot"])
	_t.eq("a second setup settles nothing", store.settled_ids().size(), settled_before)
	_t.eq("the earn keeps its first time", store.earned_at("ach_sable_parting_shot"), 70)
	_t.eq("a second setup saved nothing new", store.generation(), generation_before)
	var none := Progress.new()
	none.rows = _parting_shot_rows()
	var other_store := _fresh()
	none.setup(bus, null, other_store, func(): return 90.0)
	_t.check("no codex means no backfill", not other_store.earned("ach_sable_parting_shot"))
	_t.eq("backfill_discoveries without a codex is zero", none.backfill_discoveries(), 0)
	# The live route still works after setup: a fresh find on the bus pays the row.
	bus.synergy_discovered.emit("never_found", "combat", true)
	_t.check("a live discovery earns its row", other_store.earned("other") and other_store.has_cosmetic("decal_patch"))
	listener.free()
	second.free()
	none.free()
	bus.free()


func _toast() -> void:
	_t.eq("a pilot reward keeps its beat line", Achievements.toast_text("brindle_routed"), "Brindle Routed\n%s" % Achievements.beat_of("brindle_routed"))
	_t.eq("a delivered cosmetic reward names the look", Achievements.toast_text("ach_d7_salt_skip"), "Salt Skip\nNew look: Salt Skip")
	_t.eq("a paint reward names the look", Achievements.toast_text("warden_broken"), "Warden Breaker\nNew look: Night Slate")
	# The pending id is read at runtime, as achievement_rows_case does for PENDING_PILOTS.
	var pending: Array = Cosmetics.PENDING_ART.filter(func(id): return Achievements.for_cosmetic(id) != "")
	if pending.is_empty():
		_t.check("no granted look waits for art", true)
	else:
		var pending_grant := Achievements.for_cosmetic(pending[0])
		_t.eq("a pending item's toast shows the row name only", Achievements.toast_text(pending_grant), String(Achievements.row(pending_grant)["name"]))
	_t.eq("a delivered shell's toast names the look", Achievements.toast_text("ach_sable_switchback"), "Switchback\nNew look: Felt Rig")
	_t.eq("a delivered outfit's toast names the look", Achievements.toast_text(Achievements.for_cosmetic("outfit_rivet_hood")),
		"%s\nNew look: Welding Hood" % Achievements.row(Achievements.for_cosmetic("outfit_rivet_hood"))["name"])
	_t.eq("an unknown row toasts its id", Achievements.toast_text("not_a_row"), "not_a_row")
