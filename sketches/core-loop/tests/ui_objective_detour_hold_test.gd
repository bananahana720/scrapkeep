extends SceneTree

const Game := preload("res://src/game.gd")
const Objectives := preload("res://src/core/objectives.gd")

# PF-54 (wave 42 first-timer film): the detour row dropped a side site the moment its run began, with no
# result, and then offered a cache the ball had already passed, its metres counting up. The row now
# stays on the site it named while the run is at hand, ticks its done or lost words for
# Objectives.Done.SECONDS in its own place, then gives way to the next site; and it offers only a site
# ahead of the ball on its way to the Warden. Every wait is counted physics frames.

var _t := preload("res://tests/support/t.gd").new("ui_objective_detour_hold_test")
var _game
var _hud
var _acts


func _initialize() -> void:
	_run()


func _frames(count: int) -> void:
	for i in count:
		_game.player.set_velocity_now(Vector3.ZERO)
		await physics_frame


# The site the row last named, where the HUD keeps it (null on a build that keeps none).
func _named():
	return _hud.get("_detour_site")


func _row() -> Dictionary:
	_hud._process(0.0)
	return _hud.detour_reading(_hud.objective_reading())


# A site of the dam on offer, ahead of the ball, other than `but`.
func _ahead(but = null) -> Array:
	var ball: Vector3 = _game.player.shown_position()
	var warden = _game.flow.warden
	return _hud.edge_markers.unfinished_sites().filter(func(s):
		return s != but and not s.started and not s.failed and s.rule.finishes != "trade" \
			and Vector2(s.global_position.x - ball.x, s.global_position.z - ball.z).dot(Vector2(warden.global_position.x - ball.x, warden.global_position.z - ball.z)) > 0.0)


func _run() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "park"
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.ctx.calm = true
	_game.flow.force_warden = true
	_game.flow.enter_stage(1, Vector3.ZERO, false)
	await _frames(60)
	_hud = _game.hud
	_acts = _game.world.activities
	_acts.set_physics_process(false)
	# Only sites a live run can bring to hand are offered here: a trade spot never comes to hand, and a
	# bounty or a find site needs its own trigger, so which one happened to be nearest made the test flaky.
	for site in _acts.sites:
		site.started = false
		if site.rule.finishes == "trade" or site.id == "hauler_bounty" or site.has_meta("find"):
			site.failed = true
	_hud._engaged = false
	# A still ball: which sites lie ahead must not drift between runs.
	_game.player._rigid.freeze = true
	var cage = _game.world.rescue.cage("rivet")
	if cage != null:
		cage.fire()
		await _frames(int(ceil(preload("res://src/world/rescue_site.gd").BREAK_SECONDS * Engine.physics_ticks_per_second)) + 10)
	_t.check("the cage is out of the way", cage == null or cage.spent)

	var ahead := _ahead()
	_t.check("the dam has side sites ahead of the ball", ahead.size() >= 2, "%d" % ahead.size())
	if ahead.size() < 2:
		quit(_t.verdict())
		return
	ahead.sort_custom(func(a, b): return _game.player.shown_position().distance_to(a.global_position) < _game.player.shown_position().distance_to(b.global_position))
	var first = ahead[0]
	var row := _row()
	_t.eq("the row names the nearest site ahead (%s at %d m)" % [first.id, int(_game.player.shown_position().distance_to(first.global_position))], row.get("what"), String(first.id))

	# The run begins: the site is started and at hand (a live surge is at hand wherever the ball is).
	first.started = true
	first.surge_live = true
	await _frames(2)
	row = _row()
	var live_words := Objectives.activity_words(String(first.id), _acts.called(String(first.id)))
	_t.eq("the goal row takes the run at hand", _hud.objective_reading()["id"], "find_activity")
	_t.eq("the goal row says the run's words", _hud.objective_reading()["words"], live_words)
	_t.eq("during the run the detour row draws nothing", row, {})
	_t.check("the view draws the run's words once", _hud._objective.drawn_words().count(live_words) == 1, str(_hud._objective.drawn_words()))
	_t.check("the row stays held on the run's site", _named() == first)
	var others := 0
	for i in 120:
		await _frames(1)
		row = _row()
		others += 1 if not row.is_empty() else 0
	_t.check("no other site takes the row mid-run", others == 0 and _named() == first, "%d frames" % others)

	# Won: the done words tick in the detour row for the hold, then the next site takes it.
	first.surge_live = false
	first.done = true
	_game.events.activity_done.emit(String(first.id), first.global_position)
	await _frames(1)
	var won_words := Objectives.done_words(String(first.id), _acts.called(String(first.id)))
	var hold_frames := int(ceil(Objectives.Done.SECONDS * Engine.physics_ticks_per_second))
	# The result shows once on the plate for the hold: on the goal row while it ticks it, never on both.
	var once := 0
	var twice := 0
	var next_id := ""
	var early := 0
	for i in hold_frames + 20:
		row = _row()
		var count: int = _hud._objective.drawn_words().count(won_words)
		if i < hold_frames - 4:
			once += 1 if count == 1 else 0
			early += 1 if not row.is_empty() and row.get("done", "") == "" else 0
		twice += 1 if count > 1 else 0
		if row.get("done", "") == "" and not row.is_empty() and next_id == "":
			next_id = String(row.get("what", ""))
		await _frames(1)
	_t.check("won, the done words show once for the hold", once == hold_frames - 4, "%d of %d frames" % [once, hold_frames - 4])
	_t.check("never on both rows at once", twice == 0, "%d frames" % twice)
	_t.check("no other site showed before the tick ended", early == 0, "%d frames" % early)
	_t.check("then the next site takes the row", next_id != "" and _named() != first and _row().get("distance", -1) >= 0, "%s" % next_id)

	# Lost: a run lost ticks its own lost words.
	var near_second := _ahead(first)
	near_second.sort_custom(func(a, b): return _game.player.shown_position().distance_to(a.global_position) < _game.player.shown_position().distance_to(b.global_position))
	if not _t.check("a site is left ahead for the lost run", not near_second.is_empty(), "%d" % near_second.size()):
		quit(_t.verdict())
		return
	var second = near_second[0]
	_row()
	var real_id: String = second.id
	second.id = "surge_run"
	second.started = true
	second.surge_live = true
	await _frames(2)
	_t.eq("a second run holds its row empty", [_row(), _named() == second], [{}, true])
	second.surge_live = false
	second.started = false
	_game.events.event_ended.emit("surge_run", "lost")
	await _frames(1)
	row = _row()
	var lost_words := Objectives.lost_words("surge_run")
	_t.check("lost, the lost words show once", _hud._objective.drawn_words().count(lost_words) == 1, str(_hud._objective.drawn_words()))
	_t.eq("the goal row has them, the detour row stays held", [_hud.plate_shown()["done"], row, _named() == second], ["lost", {}, true])
	_hud._done.clear()
	row = _row()
	_t.eq("goal row moved on, the detour row crosses the run", [row.get("words"), row.get("done")], [lost_words, "lost"])
	_t.eq("the view is handed the cross", _hud._objective.get("detour_done"), "lost")
	await _frames(hold_frames + 10)
	_t.check("the lost tick gives way", _row().get("done", "") == "", str(_row()))
	second.id = real_id

	# Rolled away: a run started but not at hand (its sluice still shut, or the ball rode on) keeps the
	# row with its own words and metres, so no other site takes it before its result; past the run's
	# let-go range the player has left it, and the row moves on.
	for s in _acts.sites:
		s.started = false
		s.done = false
	var warden = _game.flow.warden
	var away_site = _ahead()[0]
	var back: Vector3 = away_site.global_position - warden.global_position
	back.y = 0.0
	back = back.normalized()
	# At the site's height, so the planar range is the distance (the dam's sites sit tens of metres up or down).
	var y: float = away_site.global_position.y + 1.0
	var near_at: Vector3 = away_site.global_position + back * 30.0
	_game.player.reset_to(Vector3(near_at.x, y, near_at.z))
	await _frames(2)
	_row()
	_t.check("rolled away: the site is named from 30 m", _named() == away_site, str(_row()))
	var far_at: Vector3 = away_site.global_position + back * 90.0
	_game.player.reset_to(Vector3(far_at.x, y, far_at.z))
	away_site.started = true
	await _frames(2)
	row = _row()
	_t.check("rolled away: the run is not at hand at 90 m", _hud.get("_site") != away_site,
		"%s started %s done %s failed %s finishes %s, %.0f m (planar %.0f), named %s" % [away_site.id, away_site.started, away_site.done,
		away_site.failed, away_site.rule.get("finishes", ""), _game.player.shown_position().distance_to(away_site.global_position),
		Vector2(_game.player.shown_position().x - away_site.global_position.x, _game.player.shown_position().z - away_site.global_position.z).length(),
		_named().id if _named() != null else "none"])
	_t.check("rolled away: the row keeps the run with its metres", _named() == away_site and row.get("what", "") == String(away_site.id)
		and absi(int(row.get("distance", -1)) - 90) <= 5 and away_site.started, str(row))
	var gone_at: Vector3 = away_site.global_position + back * 130.0
	_game.player.reset_to(Vector3(gone_at.x, y, gone_at.z))
	await _frames(2)
	row = _row()
	# Another site may share the id (the dam has more than one cache), so the row is told apart by its metres.
	_t.check("rolled away: past the let-go range the row moves on", _named() != away_site and absi(int(row.get("distance", -1)) - 130) > 5, str(row))

	# Behind: a site passed on the way to the Warden is no longer on offer, and its metres never grow.
	for s in _acts.sites:
		s.started = false
		s.done = false
	var site = _ahead()[0]
	var toward: Vector3 = (warden.global_position - site.global_position)
	toward.y = 0.0
	toward = toward.normalized()
	var checked := 0
	var last := -1
	var left_row := false
	var trace := ""
	for step_m in range(-200, 241, 20):
		# The ball drives straight along the line through the site toward the Warden.
		var at: Vector3 = site.global_position + toward * float(step_m)
		_game.player.reset_to(Vector3(at.x, _game.player.shown_position().y, at.z))
		await _frames(2)
		row = _row()
		trace += " %d:%s/%s" % [step_m, str(row.get("distance")), str(_named() == site)]
		if _named() == site and row.get("what", "") != "" and not left_row:
			var m := int(row["distance"])
			if last >= 0:
				_t.check("the row's metres never grow as the ball drives on at %dm" % step_m, m <= last or step_m <= 0, "%d after %d" % [m, last])
			last = m
			checked += 1
		elif step_m > 0 and _named() != site:
			left_row = true
	print("TRACE", trace)
	_t.check("the row counted the approach", checked > 3, "%d" % checked)
	_t.check("the site leaves the row once passed", left_row)
	_t.check("a passed site is not offered behind the ball", _named() != site, str(row))

	for s in _acts.sites:
		s.started = false
		s.done = false
		s.failed = false
	_hud._detour_done.clear()
	_hud._detour_site = null
	_hud._detour_ticked = null
	var caches: Array = _acts.sites.filter(func(s): return String(s.id) == "cracked_cache")
	if _t.check("the dam has two cracked_cache sites for W1-113", caches.size() >= 2, "%d" % caches.size()):
		var named_cache = caches[0]
		var other_cache = caches[1]
		var to_warden: Vector3 = warden.global_position - named_cache.global_position
		to_warden.y = 0.0
		var behind_cache: Vector3 = named_cache.global_position - to_warden.normalized() * 15.0
		_game.player.reset_to(Vector3(behind_cache.x, named_cache.global_position.y + 1.0, behind_cache.z))
		await _frames(2)
		_hud._detour_site = named_cache
		other_cache.done = true
		_game.events.activity_done.emit("cracked_cache", other_cache.global_position)
		_t.check("cracking a non-named cache does not tick the named detour cache", not _hud._detour_done.showing(), _hud._detour_done.words)
		named_cache.done = true
		_game.events.activity_done.emit("cracked_cache", named_cache.global_position)
		_t.check("cracking the named cache itself ticks the detour row once", _hud._detour_done.showing() and _hud._detour_done.words == Objectives.done_words("cracked_cache"), _hud._detour_done.words)
		_hud._detour_done.clear()
		_game.events.activity_done.emit("cracked_cache", other_cache.global_position)
		_t.check("a second cache done event never re-ticks the already-ticked cache", not _hud._detour_done.showing(), _hud._detour_done.words)
	_game.free()
	quit(_t.verdict())
