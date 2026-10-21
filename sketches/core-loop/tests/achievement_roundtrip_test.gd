extends SceneTree

const Game := preload("res://src/game.gd")
const Profile := preload("res://src/core/profile.gd")
const Progress := preload("res://src/core/progress.gd")
const Achievements := preload("res://src/core/achievements.gd")
const T := preload("res://tests/support/t.gd")

# ACHIEVEMENTS-REFRESH save round trip (w20): earn every new content-family row on the real bus,
# save through the real store, reload into a fresh profile, and find every new id earned with its
# first-earn time kept and the old ids unchanged. A row that never fired stays unearned after the
# reload, and a second earn of a kept row does not move its time. Evidence limit: one file on disk.

const NEW_IDS := ["ach_w20_kill_first", "ach_w20_signal_cache", "ach_w20_legend_take", "ach_w20_relay_stake",
	"ach_w20_maker_set", "ach_w20_overflow"]
const OLD_IDS := ["first_event", "ach_d7_mushroom"]
const START := 1700000000.0

var _t := T.new("achievement_roundtrip_test")
var _game
var _clock := START


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _tick() -> float:
	_clock += 100.0
	return _clock


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	await physics_frame
	var path := "%s/roundtrip.json" % _game.storage_dir
	var profile := Profile.new(path)
	profile.load_profile()
	var progress := Progress.new()
	_game.add_child(progress)
	progress.setup(_game.events, null, profile, Callable(self, "_tick"))
	var ev = _game.events
	# Old rows first, so the reload has earlier times to keep unchanged.
	ev.milestone_won.emit("roundtrip_event")
	ev.world_entered.emit(2)
	var old_times := {}
	for id in OLD_IDS:
		old_times[id] = profile.earned_at(id)
	_t.check("00 the old rows earned", OLD_IDS.all(func(id): return profile.earned(id)), str(old_times))

	# One new row is withheld as the planted control.
	for i in 3:
		ev.special_broken.emit("foreman")
	ev.radio_take_found.emit("rt_cache", "take", "cache")
	ev.radio_take_found.emit("rt_legend", "legend", "heard")
	ev.relay_stake_paid.emit(2)
	ev.maker_set_completed.emit("fleet_surplus", "rounded_up")
	_t.eq("10 five of the six new rows earned", NEW_IDS.filter(func(id): return profile.earned(id)),
		["ach_w20_kill_first", "ach_w20_signal_cache", "ach_w20_legend_take", "ach_w20_relay_stake", "ach_w20_maker_set"])
	ev.overflow_cashed.emit("scrap_rockets", 2)
	_t.check("11 two overflow pieces do not earn the sixth", not profile.earned("ach_w20_overflow"), "")
	ev.overflow_cashed.emit("scrap_rockets", 3)
	_t.eq("12 then all six are earned", NEW_IDS.filter(func(id): return profile.earned(id)), NEW_IDS)
	var new_times := {}
	for id in NEW_IDS:
		new_times[id] = profile.earned_at(id)
		_t.check("13 %s has a first-earn time" % id, int(new_times[id]) > int(START), str(new_times[id]))
	_t.check("14 the profile saved", profile.save(), profile.last_error)

	var reloaded := Profile.new(path)
	_t.check("20 a fresh profile loads the file", reloaded.load_profile(), reloaded.last_error)
	for id in NEW_IDS:
		_t.check("21 %s survives the reload" % id, reloaded.earned(id) and reloaded.earned_at(id) == new_times[id],
			"at %s want %s" % [reloaded.earned_at(id), new_times[id]])
	for id in OLD_IDS:
		_t.check("22 old row %s is unchanged" % id, reloaded.earned(id) and reloaded.earned_at(id) == old_times[id], str(reloaded.earned_at(id)))
	_t.eq("23 no row appears that nothing earned", Achievements.ids().filter(func(id): return reloaded.earned(id) and not profile.earned(id)), [])

	# A second listener over the reloaded profile: a repeat earn keeps the first time.
	var again := Progress.new()
	_game.add_child(again)
	again.setup(ev, null, reloaded, Callable(self, "_tick"))
	ev.radio_take_found.emit("rt_cache_2", "take", "cache")
	_t.eq("30 a repeat earn keeps the first time", reloaded.earned_at("ach_w20_signal_cache"), new_times["ach_w20_signal_cache"])

	# A planted control: a profile that earned nothing reloads with none of the new rows.
	var blank_path := "%s/roundtrip_blank.json" % _game.storage_dir
	var blank := Profile.new(blank_path)
	blank.load_profile()
	_t.check("40 a blank profile saves", blank.save(), blank.last_error)
	var blank_back := Profile.new(blank_path)
	blank_back.load_profile()
	_t.eq("41 and reloads with no new row earned", NEW_IDS.filter(func(id): return blank_back.earned(id)), [])
	_game.free()
	quit(_t.verdict())
