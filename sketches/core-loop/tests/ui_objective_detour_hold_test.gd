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
	for site in _acts.sites:
		site.started = false
	_hud._engaged = false
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
	_t.eq("the row names the nearest site ahead", row.get("what"), String(first.id))

	# The run begins: the site is started and at hand (a live surge is at hand wherever the ball is).
	first.started = true
	first.surge_live = true
	await _frames(2)
	row = _row()
	var live_words := Objectives.activity_words(String(first.id), _acts.called(String(first.id)))
	_t.eq("the goal row takes the run at hand", _hud.objective_reading()["id"], "find_activity")
	_t.eq("the run keeps the detour row on its site", [row.get("what"), row.get("words"), row.get("distance")], [String(first.id), live_words, -1])
	_t.check("the live row is not a done tick", not row.has("done"))
	await _frames(120)
	row = _row()
	_t.eq("it holds through a long run", row.get("what"), String(first.id))

	# Won: the done words tick in the detour row for the hold, then the next site takes it.
	first.surge_live = false
	first.done = true
	_game.events.activity_done.emit(String(first.id), first.global_position)
	await _frames(1)
	row = _row()
	var won_words := Objectives.done_words(String(first.id), _acts.called(String(first.id)))
	_t.eq("won, the row ticks the done words", [row.get("words"), row.get("done")], [won_words, "won"])
	_t.eq("the view is handed the tick", _hud._objective.get("detour_done"), "won")
	_t.check("the view draws the done words", _hud._objective.drawn_words().has(won_words), str(_hud._objective.drawn_words()))
	var hold_frames := int(ceil(Objectives.Done.SECONDS * Engine.physics_ticks_per_second))
	var shown := 0
	var next_id := ""
	for i in hold_frames + 20:
		await _frames(1)
		row = _row()
		if row.get("done", "") == "won":
			shown += 1
		elif next_id == "":
			next_id = String(row.get("what", ""))
	_t.check("the tick holds for Done.SECONDS", shown > 0 and absi(shown - hold_frames) <= 3, "%d of %d frames" % [shown, hold_frames])
	_t.check("then the next site takes the row", next_id != "" and _named() != first and row.get("distance", -1) >= 0, "%s" % next_id)

	# Lost: a run lost ticks its own lost words.
	var near_second := _ahead(first)
	near_second.sort_custom(func(a, b): return _game.player.shown_position().distance_to(a.global_position) < _game.player.shown_position().distance_to(b.global_position))
	var second = near_second[0]
	_row()
	var real_id: String = second.id
	second.id = "surge_run"
	second.started = true
	second.surge_live = true
	await _frames(2)
	_t.eq("a second run holds its row", _row().get("what"), "surge_run")
	second.surge_live = false
	second.started = false
	_game.events.event_ended.emit("surge_run", "lost")
	await _frames(1)
	row = _row()
	_t.eq("lost, the row ticks the lost words", [row.get("words"), row.get("done")], [Objectives.lost_words("surge_run"), "lost"])
	_t.eq("the view is handed the cross", _hud._objective.get("detour_done"), "lost")
	await _frames(hold_frames + 10)
	_t.check("the lost tick gives way", _row().get("done", "") == "", str(_row()))
	second.id = real_id

	# Behind: a site passed on the way to the Warden is no longer on offer, and its metres never grow.
	for s in _acts.sites:
		s.started = false
		s.done = false
	var warden = _game.flow.warden
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
	_game.free()
	quit(_t.verdict())
