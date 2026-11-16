extends SceneTree

const T := preload("res://tests/support/t.gd")
const Profile := preload("res://src/core/profile.gd")
const Progress := preload("res://src/core/progress.gd")
const RunState := preload("res://src/core/run_state.gd")
const GameEvents := preload("res://src/core/game_events.gd")

# RS4: the settle-once ledger. Progress.settle(id) is true the first time and false after,
# the run document and the profile hold one set, and a profile-level grant wired through
# grant_once fires once across runs. The test uses its own user:// folder and no clock.

const DIR := "user://unlock_settle_once_test/"

var _t := T.new("unlock_settle_once_test")
var _n := 0
var _events := GameEvents.new()


func _initialize() -> void:
	_clear_dir()
	DirAccess.make_dir_recursive_absolute(DIR)
	_first_then_false()
	_survives_reload()
	_union_when_run_doc_and_profile_disagree()
	_grant_fires_once_across_runs()
	_reward_never_settled_without_its_unlock()
	_entrance_doc_field()
	_grant_saves_once_never_the_middle()
	_events.free()
	_clear_dir()
	quit(_t.verdict())


func _clear_dir() -> void:
	if not DirAccess.dir_exists_absolute(DIR):
		return
	for file_name in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + file_name)
	DirAccess.remove_absolute(DIR)


func _path() -> String:
	_n += 1
	return "%ssettle_%d.json" % [DIR, _n]


func _profile(path: String) -> Profile:
	var profile := Profile.new(path)
	profile.load_profile()
	return profile


func _progress(profile: Profile, run: RunState) -> Progress:
	var progress := Progress.new()
	progress.rows = {}
	progress.setup(_events, run, profile)
	return progress


func _first_then_false() -> void:
	var profile := _profile(_path())
	var run := RunState.new()
	var progress := _progress(profile, run)
	_t.check("RS4 first settle is true", progress.settle("first_win_paint"))
	_t.check("RS4 second settle is false", not progress.settle("first_win_paint"))
	_t.check("RS4 another id is its own first", progress.settle("hotwire_offer") and not progress.settle("hotwire_offer"))
	_t.check("RS4 run document holds both", run.settled == ["first_win_paint", "hotwire_offer"], str(run.settled))
	_t.check("RS4 profile holds both", profile.is_settled("first_win_paint") and profile.is_settled("hotwire_offer"))
	progress.free()


func _survives_reload() -> void:
	var path := _path()
	var first := _profile(path)
	var progress := _progress(first, RunState.new())
	_t.check("RS4 settle before reload", progress.settle("discovery_burst"))
	progress.free()
	var reloaded := _profile(path)
	var again := _progress(reloaded, RunState.new())
	_t.check("RS4 settled survives save and reload", reloaded.is_settled("discovery_burst") and not again.settle("discovery_burst"))
	_t.check("RS4 the reload did not settle new ids", again.settle("other_id"))
	again.free()


func _union_when_run_doc_and_profile_disagree() -> void:
	var path := _path()
	var profile := _profile(path)
	profile.settle("profile_only")
	profile.save()
	var run := RunState.new()
	run.settled.append("run_only")
	var progress := _progress(profile, run)
	_t.check("RS4 an id only the run document holds is settled", not progress.settle("run_only"))
	_t.check("RS4 settling it copied it into the profile", profile.is_settled("run_only"))
	_t.check("RS4 an id only the profile holds is settled", not progress.settle("profile_only"))
	_t.check("RS4 settling it copied it into the run document", run.settled.has("profile_only"))
	progress.free()
	var other_profile := _profile(_path())
	var other_run := RunState.new()
	other_run.settled.append("from_doc")
	other_profile.settle("from_disk")
	var other := _progress(other_profile, other_run)
	other.reconcile_settled()
	_t.check("RS4 reconcile gives both sides the union", other_run.settled.size() == 2 and other_profile.settled_ids().size() == 2 and other_run.settled.has("from_disk") and other_profile.is_settled("from_doc"), "%s %s" % [other_run.settled, other_profile.settled_ids()])
	_t.check("RS4 reconcile saved the profile", _profile(other_profile.path).is_settled("from_doc"))
	other.free()


# F-B R-1 (Andrew, 16 Nov: never lost wins): a run document that settled a reward its profile
# never saved (both profile saves of the earn failed) must not make Continue mark the reward paid
# with no unlock. The run's own list still refuses it this run; the next launch pays it, once.
func _reward_never_settled_without_its_unlock() -> void:
	var path := _path()
	var profile := _profile(path)
	var run := RunState.new()
	for id in ["reward:fb_row:cosmetic", "reward:fb_row:cosmetic:paint_rust", "ledger.found.3"]:
		run.settled.append(id)
	var resumed := _progress(profile, run)
	resumed.reconcile_settled()
	_t.check("FB Continue copies no reward key into a profile that lacks its unlock", not profile.is_settled("reward:fb_row:cosmetic") and not profile.is_settled("reward:fb_row:cosmetic:paint_rust"), str(profile.settled_ids()))
	_t.check("FB Continue still copies a ledger id, whose settle is its grant", profile.is_settled("ledger.found.3"))
	_t.check("FB the ledger id reached the profile file", _profile(path).is_settled("ledger.found.3"))
	_t.check("FB the continued run still refuses the reward its own list settled", not resumed._grant_reward("fb_row", "cosmetic", "paint_rust") and not profile.has_cosmetic("paint_rust"))
	resumed.free()
	var relaunched := _profile(path)
	var next := _progress(relaunched, RunState.new())
	_t.check("FB the next launch pays the reward", next._grant_reward("fb_row", "cosmetic", "paint_rust") and relaunched.has_cosmetic("paint_rust"))
	_t.check("FB and pays it once", not next._grant_reward("fb_row", "cosmetic", "paint_rust"))
	next.free()
	var again := _profile(path)
	var later := _progress(again, RunState.new())
	_t.check("FB a later launch pays nothing more", not later._grant_reward("fb_row", "cosmetic", "paint_rust") and again._doc["cosmetics"] == ["paint_rust"], str(again._doc["cosmetics"]))
	later.free()


func _grant_fires_once_across_runs() -> void:
	var path := _path()
	var profile := _profile(path)
	var run_one := RunState.new()
	var one := _progress(profile, run_one)
	_t.check("RS4 grant fires in run one", one.grant_once("grant:paint_rust", "cosmetic", "paint_rust") and profile.has_cosmetic("paint_rust"))
	one.free()
	var run_two := RunState.new()
	var two := _progress(profile, run_two)
	_t.check("RS4 grant does not fire in run two", not two.grant_once("grant:paint_rust", "cosmetic", "paint_rust"))
	two.free()
	var doc := run_one.to_entrance_doc()
	var wiped := _profile(_path())
	var run_three := RunState.new()
	_t.check("RS4 run document loads", run_three.from_entrance_doc(doc), RunState.validate_entrance_doc(doc))
	var three := _progress(wiped, run_three)
	three.reconcile_settled()
	_t.check("RS4 a profile without the id still sees the run document's grant", not three.grant_once("grant:paint_rust", "cosmetic", "paint_rust") and not wiped.has_cosmetic("paint_rust"))
	three.free()
	var reloaded := _profile(path)
	var four := _progress(reloaded, RunState.new())
	_t.check("RS4 grant stays once after a reload", not four.grant_once("grant:paint_rust", "cosmetic", "paint_rust") and reloaded._doc["cosmetics"] == ["paint_rust"], str(reloaded._doc["cosmetics"]))
	_t.check("RS4 a pilot grant is once too", four.grant_once("grant:pilot_x", "pilot", "pilot_x") and not four.grant_once("grant:pilot_x", "pilot", "pilot_x") and reloaded.has_pilot("pilot_x"))
	four.free()


func _entrance_doc_field() -> void:
	var run := RunState.new()
	run.settled.append("a")
	var doc := run.to_entrance_doc()
	_t.check("RS4 entrance doc carries settled", doc.get("settled") == ["a"] and RunState.validate_entrance_doc(doc) == "")
	var without := doc.duplicate(true)
	without.erase("settled")
	var plain := RunState.new()
	_t.check("RS4 an older doc without settled loads empty", RunState.validate_entrance_doc(without) == "" and plain.from_entrance_doc(without) and plain.settled.is_empty())
	var bad := doc.duplicate(true)
	bad["settled"] = [4]
	_t.check("RS4 a wrong-typed settled is refused", RunState.validate_entrance_doc(bad) != "")
	var back := RunState.new()
	_t.check("RS4 settled round trips through the doc", back.from_entrance_doc(doc) and back.settled == ["a"] and not back.extra.has("settled"))


# A store double that records the document at every save. A crash that drops the first save
# leaves the disk as it was (nothing) or as that snapshot holds; the snapshot must be whole.
class SaveSpy:
	extends Profile
	var snaps: Array = []

	func save() -> bool:
		snaps.append(_doc.duplicate(true))
		return true


func _spy() -> SaveSpy:
	var spy := SaveSpy.new(_path())
	spy.load_profile()
	return spy


func _grant_saves_once_never_the_middle() -> void:
	var spy := _spy()
	var progress := _progress(spy, RunState.new())
	_t.check("RS4 grant_once true", progress.grant_once("grant:paint_z", "cosmetic", "paint_z"))
	_t.check("RS4 exactly one save per grant", spy.snaps.size() == 1, str(spy.snaps.size()))
	var snap: Dictionary = spy.snaps[0]
	_t.check("RS4 the one save holds settled and unlocked together", snap["settled"].has("grant:paint_z") and snap["cosmetics"].has("paint_z"), str(snap))
	progress.free()
	var earn_spy := _spy()
	var earner := _progress(earn_spy, RunState.new())
	earner.rows = {"row_z": {"on": "run_ended", "reward": {"pilot": "pilot_z"}}}
	earner.setup(_events, RunState.new(), earn_spy, func(): return 5.0)
	earner._evaluate("row_z", {})
	var first: Dictionary = earn_spy.snaps[0]
	var whole: bool = first["achievements"].has("row_z") and first["settled"].has("reward:row_z:pilot") and first["pilots"].has("pilot_z")
	var none: bool = not first["achievements"].has("row_z") and not first["settled"].has("reward:row_z:pilot")
	_t.check("RS4 the first save of an earn is all or nothing", whole or none, str(first))
	_t.check("RS4 an earn with a reward saves the grant once, then the earn", earn_spy.snaps.size() == 2, str(earn_spy.snaps.size()))
	earner.free()
