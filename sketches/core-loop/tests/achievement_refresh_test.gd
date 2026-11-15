extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Profile := preload("res://src/core/profile.gd")
const Progress := preload("res://src/core/progress.gd")
const Achievements := preload("res://src/core/achievements.gd")
const ActiveDefs := preload("res://src/combat/actives/active_defs.gd")
const RadioTakes := preload("res://src/core/radio_takes.gd")
const T := preload("res://tests/support/t.gd")

# ACHIEVEMENTS-REFRESH (w20, WHATS-LEFT row 9): the six content-family records.
#   ach_w20_kill_first   three kill-first specials broken (run_state.record_kill)
#   ach_w20_signal_cache a Signal cache take filed (radio_deck.cache_found)
#   ach_w20_legend_take  a legend-tier take filed (radio_deck.find)
#   ach_w20_relay_stake  a staked relay won (activities.gd, the real 18 s charge)
#   ach_w20_maker_set    a maker set turned on (build.maker_bonuses refresh)
#   ach_w20_overflow     an active fired with three overflow pieces (active_rack.press)
# Each is driven through its real source in a park Game, with a controls pass first: the near
# misses (a chaser kill, a non-cache take, two overflow pieces) earn nothing through the real source,
# an unstaked win is a direct relay_stake_paid(0) emit (not a played relay), so the relay-loss branch is untested here,
# and a row whose signal never fires stays unearned. Evidence limit: headless rules, not feel.

const NOW := 1700000000.0
const NEW_IDS := ["ach_w20_kill_first", "ach_w20_signal_cache", "ach_w20_legend_take", "ach_w20_relay_stake",
	"ach_w20_maker_set", "ach_w20_overflow"]
const SEED := 23
const CHARGE_SECONDS := 25.0

var _t := T.new("achievement_refresh_test")
var _game
var _profile
var _source := Intent.Scripted.new()


func _initialize() -> void:
	_run()


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _earned() -> Array:
	return NEW_IDS.filter(func(id): return _profile.earned(id))


func _run() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "park"
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.ctx.rng.seed = SEED
	_game.player.source = _source
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.run.set_max_hp(99999.0)
	await _frames(4)
	_profile = Profile.new("%s/refresh.json" % _game.storage_dir)
	_profile.load_profile()
	var progress := Progress.new()
	_game.add_child(progress)
	progress.setup(_game.events, null, _profile, func(): return NOW)

	_t.eq("00 the table holds every new row", NEW_IDS.filter(func(id): return Achievements.ROWS.has(id)), NEW_IDS)
	_t.eq("01 a planted control: nothing fired, nothing earned", _earned(), [])
	_specials()
	_radio()
	_sets()
	await _overflow()
	await _relay()
	_t.eq("90 every new row is earned through its real source", _earned(), NEW_IDS)
	_game.free()
	await _frames(2)
	quit(_t.verdict())


func _specials() -> void:
	var run = _game.ctx.run
	for i in 5:
		run.record_kill("chaser", Vector3.ZERO, 1)
	_t.check("10 five ordinary kills do not count as specials", not _profile.earned("ach_w20_kill_first"), "count %s" % _profile.stat("ach.ach_w20_kill_first"))
	run.record_kill("foreman", Vector3.ZERO, 1)
	run.record_kill("splitter", Vector3.ZERO, 1)
	_t.check("11 two specials are not enough", not _profile.earned("ach_w20_kill_first"), "count %s" % _profile.stat("ach.ach_w20_kill_first"))
	run.record_kill("linker", Vector3.ZERO, 1)
	_t.check("12 the third special earns Kill First", _profile.earned("ach_w20_kill_first"), "count %s" % _profile.stat("ach.ach_w20_kill_first"))


func _take(want_tier: String, want_rule: String) -> String:
	for t in RadioTakes.takes():
		if String(t["tier"]) == want_tier and String(t["found"].get("on", "")) == want_rule and not _game.ctx.profile.has_tune(String(t["id"])):
			return String(t["id"])
	return ""


func _radio() -> void:
	var deck = _game.radio_deck
	var plain := _take("take", "heard")
	if plain == "":
		plain = _take("b-side", "heard")
	_t.check("20 a non-cache, non-legend take exists to plant", plain != "", plain)
	if plain != "":
		_t.check("21 filing it is real", deck.find(plain), plain)
	_t.check("22 a plain take earns neither radio row", not _profile.earned("ach_w20_signal_cache") and not _profile.earned("ach_w20_legend_take"), str(_earned()))
	var legend := _take("legend", "heard")
	var cache := _take("take", "cache")
	if cache == "":
		cache = _take("b-side", "cache")
	_t.check("23 a legend and a cache take exist to drive", legend != "" and cache != "", "%s %s" % [legend, cache])
	_t.check("24 a cache find files", deck.cache_found(cache), cache)
	_t.check("25 the cache earns Signal Found and not Legend Heard", _profile.earned("ach_w20_signal_cache") and not _profile.earned("ach_w20_legend_take"), str(_earned()))
	_t.check("26 a legend find files", deck.find(legend), legend)
	_t.check("27 the legend earns Legend Heard", _profile.earned("ach_w20_legend_take"), str(_earned()))


func _sets() -> void:
	var build = _game.ctx.build
	build.maker_bonuses()
	_t.check("30 no set yet, no row", not _profile.earned("ach_w20_maker_set"), "")
	for id in ["tracer_round", "magnet_coil"]:
		_game.ctx.run.add_part(id, "test")
	_t.eq("31 two Fleet pieces are not a set", build.maker_bonuses(), [])
	_t.check("32 so the row stays locked", not _profile.earned("ach_w20_maker_set"), "")
	_game.ctx.run.add_part("rivet_seam", "test")
	_t.eq("33 the third piece turns Rounded Up on", build.maker_bonuses(), ["rounded_up"])
	_t.check("34 which earns Set Complete", _profile.earned("ach_w20_maker_set"), "")


func _overflow() -> void:
	_game.tuning.set_option("actives", "on")
	await _frames(12)
	var rack = _game.combat.get("actives")
	_t.check("40 the rack is on", rack != null and rack.enabled(), "")
	rack.rack(ActiveDefs.SCRAP_ROCKET)
	rack.bonus = 0
	rack.press()
	_t.check("41 a plain fire earns nothing", not _profile.earned("ach_w20_overflow"), "")
	await _frames(240)
	rack.rack(ActiveDefs.SCRAP_ROCKET)
	rack.bonus = 2
	rack.press()
	_t.check("42 two overflow pieces are not enough", not _profile.earned("ach_w20_overflow"), "")
	await _frames(240)
	rack.rack(ActiveDefs.SCRAP_ROCKET)
	rack.bonus = 3
	rack.press()
	_t.check("43 three pieces earn Overflow Paid", _profile.earned("ach_w20_overflow"), "")


func _relay() -> void:
	_game.flow.enter_stage(1, Vector3.ZERO, false)
	await _frames(4)
	var s = _game.world.activities.site("hold_the_relay")
	_t.check("50 the dam builds a relay site", s != null and s.relay != null, "no site")
	if s == null:
		return
	var seen := []
	_game.events.relay_stake_paid.connect(func(k: int): seen.append(k))
	var at: Vector3 = _game.ctx.terrain.drop_point(s.global_position.x, s.global_position.z, 1.05)
	_game.events.relay_stake_paid.emit(0)
	_t.check("51 an unstaked win (stake 0) earns nothing", not _profile.earned("ach_w20_relay_stake"), str(seen))
	seen.clear()
	s.relay.set_stakes(1)
	# The ball holds still on the pad for the whole charge: world 1's crews hit twice as hard on the dam since
	# wave 37 (ChallengeDials.MOBS_DAMAGE_W1, ruling cu), enough to end the run first. This row is the payout.
	_game.run.set_max_hp(99999.0)
	for frame in int(CHARGE_SECONDS * Engine.physics_ticks_per_second):
		_game.player.reset_to(at, Vector3.ZERO)
		_game.player.set_velocity_now(Vector3.ZERO)
		await physics_frame
		if frame % 30 == 29:
			for enemy in s.pack + s.minibosses:
				if is_instance_valid(enemy):
					enemy.take_damage(100000.0)
		if s.done:
			break
	_t.check("52 a staked win earns Stake Paid", s.done and seen == [1] and _profile.earned("ach_w20_relay_stake"), "done %s seen %s" % [s.done, str(seen)])
