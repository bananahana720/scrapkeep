extends SceneTree

# Load-time and write-site guards from the invariants pass (2026-11-08): each case plants the bad
# value the guard exists for and checks the game degrades instead of erroring or freezing.
const Profile := preload("res://src/core/profile.gd")
const RunState := preload("res://src/core/run_state.gd")
const RunStore := preload("res://src/core/run_store.gd")
const Radio := preload("res://src/core/radio.gd")
const Companion := preload("res://src/core/companion.gd")
const CampRecords := preload("res://src/core/camp_records.gd")
const DefenceBars := preload("res://tests/support/defence_bars.gd")
const Parts := preload("res://src/build/parts.gd")
const Pattern := preload("res://src/combat/pattern.gd")
const Requisition := preload("res://src/boss/requisition.gd")
const T := preload("res://tests/support/t.gd")

const DIR := "user://invariant_guards_test"

var _t := T.new("invariant_guards_test")


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	_entrance_ranges()
	_run_store_shapes()
	_camp_records()
	_radio_types()
	_companion()
	_closed_tallies()
	_defence_pool()
	_parts_binding()
	_brindle_model_fit()
	_fire_rate_floor()
	_reward_targets()
	quit(_t.verdict())


func _live_doc() -> Dictionary:
	var run := RunState.new(null, 7)
	run.begin(null)
	run.snapshot(Vector3.ZERO, Vector3.ZERO, 0.0)
	return run.to_entrance_doc()


func _entrance_ranges() -> void:
	var clean := _live_doc()
	_t.eq("a live entrance doc validates", RunState.validate_entrance_doc(clean), "")
	for plant in [["hp", 0.0], ["hp", -5.0], ["hp", float(clean["max_hp"]) + 50.0], ["max_hp", 0.0],
			["mass", -50.0], ["scrap", -1], ["cogs", -3], ["stage", 0], ["heft_class", 0], ["heft_class", 99],
			["kills", -1], ["retries", -1]]:
		var doc := clean.duplicate(true)
		doc[plant[0]] = plant[1]
		_t.check("entrance doc with %s = %s is refused" % plant, RunState.validate_entrance_doc(doc) != "",
			RunState.validate_entrance_doc(doc))
	var spent := clean.duplicate(true)
	spent["retries_spent"] = {"1": -2}
	_t.check("a negative retries_spent is refused", RunState.validate_entrance_doc(spent) != "")


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _run_store_shapes() -> void:
	for bad in [{"retries_spent": {"1": [2]}}, {"retries_spent": [[1, 2]]}, {"worlds_cleared": ["a"]}, {"worlds_cleared": 3}]:
		var path := DIR.path_join("run.json")
		for leftover in DirAccess.get_files_at(DIR):
			if leftover.begins_with("run.json"):
				DirAccess.remove_absolute(DIR.path_join(leftover))
		var run := _live_doc()
		run.merge(bad, true)
		_write(path, JSON.stringify({"schema": RunStore.SCHEMA, "generation": 1, "run": run}))
		var store := RunStore.new(path)
		var loaded: Dictionary = store.load()
		_t.check("run.json with %s loads as unreadable, not an error" % [bad], loaded.is_empty() and store.last_error != "", store.last_error)


func _camp_records() -> void:
	for camp in [{"trial": null}, {"trial": 61240}, {"trial": {"best_ms": "fast"}}, {"skee_best": [340]}, {"trial": {"best_ms": 900, "ghost": 3}},
			{"trial": {"best_ms": 900, "ghost": {"p0": [null, 0, 0], "d": ""}}}]:
		var path := DIR.path_join("profile.json")
		for leftover in DirAccess.get_files_at(DIR):
			if leftover.begins_with("profile.json"):
				DirAccess.remove_absolute(DIR.path_join(leftover))
		_write(path, JSON.stringify({"schema": Profile.SCHEMA, "generation": 1, "camp": camp}))
		var profile := Profile.new(path)
		var ok := profile.load_profile()
		var records := CampRecords.new(profile)
		var best := records.trial_best_ms()
		var skee := records.skee_best()
		var ghost := records.ghost()
		_t.check("camp %s loads and reads without error" % [camp], ok and best >= 0 and skee >= 0 and ghost is PackedVector3Array,
			"best %d skee %d" % [best, skee])


func _radio_types() -> void:
	var radio := Radio.new()
	radio.from_dict({"mixtapes": [{"ids": [7, null], "name": 3}, "x"], "mixtape": [0], "last_on": 3, "station": {}})
	_t.check("radio with wrong-typed fields falls back to defaults", radio.station == Radio.LIVE and radio.mixtape == 0
		and radio.mixtapes.size() == 1 and (radio.mixtapes[0]["ids"] as Array).is_empty(), str(radio.to_dict()))
	var lists := Radio.new()
	lists.from_dict({"mixtapes": "x"})
	_t.check("radio with a non-list mixtapes keeps its default tape", lists.mixtapes.size() == 1)


func _companion() -> void:
	var piece: String = Companion.PIECES[0]["id"]
	var good := {"chassis": Companion.CHASSIS, "owned": [piece, "cut_piece"], "sockets": ["cut_piece"], "escape_ready": true, "escape_spent": false}
	var fixed: Array = Companion.sanitize(good)
	_t.check("a cut piece is dropped and the rest kept", fixed[0]["owned"] == [piece] and (fixed[0]["sockets"] as Array).is_empty() and fixed[1] != "", str(fixed))
	var model = Companion.new()
	_t.check("the cleaned companion loads", model.from_dict(fixed[0]))
	_t.check("a companion with string lists reads as none", Companion.sanitize({"owned": "x", "sockets": []})[0].is_empty())
	_t.eq("an empty companion stays empty", Companion.sanitize({})[0], {})


func _closed_tallies() -> void:
	var path := DIR.path_join("tally.json")
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var profile := Profile.new(path)
	profile.load_profile()
	var totals := {"stages_cleared": 1, "time": 30.0, "kills": 12, "deaths": 0, "wardens_seen": 1}
	_t.check("a run records its tallies", profile.record_run_tallies("run-a", totals))
	profile.settle_run_tallies("run-a")
	_t.check("the settle saves", profile.save())
	var kills := profile.stat("kills")
	var reread := Profile.new(path)
	reread.load_profile()
	_t.check("the closed run is remembered", reread.tallies_closed("run-a"))
	# The same run, restored from run.json.prev and continued, reports its tallies again.
	_t.check("a closed run cannot record again", not reread.record_run_tallies("run-a", totals))
	_t.eq("kills are counted once", reread.stat("kills"), kills)


func _defence_pool() -> void:
	var pool = DefenceBars.Pool.new("armour", 100.0)
	pool.hit(-50.0)
	_t.eq("a negative hit does not overfill", pool.value, 100.0)
	var empty = DefenceBars.Pool.new("armour", -5.0)
	_t.check("a negative maximum reads as an empty pool", empty.max_value == 0.0 and empty.value == 0.0)
	_t.eq("an empty breaking pool starts broken", empty.broken, bool(DefenceBars.CLASSES["armour"]["breaks"]))


func _parts_binding() -> void:
	var events = preload("res://src/core/game_events.gd").new()
	var live := RunState.new(events, 1)
	live.begin(null)
	var bare := RunState.new(null, 2)
	bare.begin(null)
	_t.check("a bare run does not take the binding from a live one", Parts._run_ref.get_ref() == live)
	if events is Node:
		events.free()


func _brindle_model_fit() -> void:
	var good := Node3D.new()
	for part in Requisition.MODEL_PARTS:
		var node: Node3D = MeshInstance3D.new() if part.begins_with("Armour") or part.begins_with("Cap") else Node3D.new()
		node.name = part
		good.add_child(node)
	_t.check("a model with every part fits", Requisition.model_fits(good, 4, 3))
	var wrapped := good.duplicate()
	var armour := wrapped.get_node("Armour0")
	wrapped.remove_child(armour)
	armour.free()
	var holder := Node3D.new()
	holder.name = "Armour0"
	wrapped.add_child(holder)
	_t.check("a model whose Armour0 is not a mesh does not fit", not Requisition.model_fits(wrapped, 4, 3))
	_t.check("a model short of a cap the materials reach does not fit", not Requisition.model_fits(good, 4, 4))
	good.free()
	wrapped.free()


func _fire_rate_floor() -> void:
	var p := Pattern.new()
	p.rate = -3.0
	p._clamp()
	_t.check("a pattern's rate never reaches zero", p.rate >= Pattern.MIN_RATE, str(p.rate))


# A reward row pays each target once: the same target never twice, a changed target once more,
# and a profile from before targeted keys (legacy key only) is not paid its current target again.
func _reward_targets() -> void:
	var path := DIR.path_join("rewards.json")
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var profile := Profile.new(path)
	profile.load_profile()
	var events = preload("res://src/core/game_events.gd").new()
	var progress = preload("res://src/core/progress.gd").new()
	progress.setup(events, null, profile)
	_t.check("a row pays its target", progress._grant_reward("row_x", "cosmetic", "hat_a") and profile.has_cosmetic("hat_a"))
	_t.check("the same target is not paid twice", not progress._grant_reward("row_x", "cosmetic", "hat_a"))
	_t.check("a changed target pays once", progress._grant_reward("row_x", "cosmetic", "hat_b") and profile.has_cosmetic("hat_b"))
	_t.check("the changed target is not paid twice", not progress._grant_reward("row_x", "cosmetic", "hat_b"))
	profile.settle("reward:row_y:cosmetic")
	_t.check("a legacy-settled row is not paid its current target again", not progress._grant_reward("row_y", "cosmetic", "hat_c")
		and not profile.has_cosmetic("hat_c") and profile.is_settled("reward:row_y:cosmetic:hat_c"))
	progress.free()
	if events is Node:
		events.free()
