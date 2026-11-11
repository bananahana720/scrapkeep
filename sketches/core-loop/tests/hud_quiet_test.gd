extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Achievements := preload("res://src/core/achievements.gd")
const Parts := preload("res://src/build/parts.gd")


const T := preload("res://tests/support/t.gd")
const ScreenBusy := preload("res://src/ui/screen_busy.gd")

# Nothing talks over a fight (PF-19, wave 36 unit hud). On the real game in a run:
#   - with a fight on (the bus's pressure), a record, a B-side, an achievement, a look, a field
#     note, a synergy and a fleet-grade find are raised and none of the seven shows;
#   - when the fight ends they come one at a time, oldest first, each alone on screen, and not
#     before the screen has been quiet for two seconds;
#   - a card still waiting when the run ends (a banner card and a crate too) is not on screen afterwards;
#   - a death is not a run end: after a death and a retry of the same run a waiting card still shows;
#   - planted control: with no fight the same card shows, so the "none shows" check can see a card.

const SETTLE_S := ScreenBusy.SETTLE
# A card is due within this many frames of the moment it may show.
const SLACK_S := 1.0
const ORDER := ["record", "b-side", "achievement", "look", "note", "synergy", "fleet grade"]

var _t := T.new("hud_quiet_test")
var _game
var _clock := 0.0
var _texts := {}


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame
		_clock += _game.get_process_delta_time()


func _settle(seconds: float) -> void:
	var until := _clock + seconds
	while _clock < until:
		await _frames(1)


func _look_id() -> String:
	for id in Achievements.ROWS:
		if Achievements.toast_text(id).contains("New look") or Achievements.toast_text(id).contains("look unlocked"):
			return id
	return ""


func _rare_part() -> String:
	for id in Parts.ids():
		if String(Parts.def(id).rarity) == "rare":
			return id
	return ""


# The kinds on screen now, by what each one says.
func _on_screen() -> Array:
	var out: Array = []
	var hud = _game.hud
	for text in hud.ach_toasts():
		out.append(_texts.get(text, "achievement?"))
	if hud.lore_pulse_visible():
		out.append("note")
	if _game.presentation.banner.showing():
		out.append("synergy")
	if not _game.presentation.ceremony.view.card.is_empty():
		out.append("fleet grade")
	return out


func _raise_all() -> void:
	var hud = _game.hud
	var look := _look_id()
	_texts = {"Test Record\nOn Moss's jukebox at camp": "record", "Test Take\nOn the radio at KEEP Live": "b-side",
		Achievements.toast_text("first_win"): "achievement", Achievements.toast_text(look): "look"}
	hud.tune_found("Test Record")
	hud.take_found("Test Take", "KEEP Live", "b-side")
	_game.events.achievement_earned.emit("first_win")
	_game.events.achievement_earned.emit(look)
	_game.codex.lore_found.emit("test_note")
	_game.presentation.banner.show_discovery("Test Synergy", "build", "Two parts work as one.", "New synergy", "test_synergy")
	_game.run.add_part(_rare_part(), "pickup")


# Seconds the kinds on screen are collected for, as the list of everything seen.
func _collect(seconds: float) -> Array:
	var seen := []
	var until := _clock + seconds
	while _clock < until:
		await _frames(1)
		seen.append_array(_on_screen())
	return seen


func _crate_part() -> String:
	for id in Parts.ids():
		if String(Parts.def(id).rarity) == "relic":
			return id
	return ""


func _crate_state() -> Array:
	var ceremony = _game.presentation.ceremony
	return [ceremony.queued(), ceremony.active()]


func _run() -> void:
	while _game.flow == null:
		await process_frame
	await _frames(5)
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.presentation.flourish.stop_all()
	await _settle(1.0)
	_t.check("the look card exists", _look_id() != "", "row '%s'" % _look_id())
	_t.check("a fleet-grade part exists", _rare_part() != "", "part '%s'" % _rare_part())

	# Planted control: with no fight the same kind of card shows inside the settle hold plus a second,
	# so an empty list in the fight below means the cards waited and not that this check cannot see one.
	_game.hud.tune_found("Control Record")
	_texts["Control Record\nOn Moss's jukebox at camp"] = "record"
	var control: Array = await _collect(SETTLE_S + SLACK_S)
	_t.check("planted control: a card with no fight is seen", "record" in control, "seen %s" % [control])
	await _settle(4.0)

	# A fight is on: the seven cards wait.
	_game.events.pressure_changed.emit(0.9)
	await _frames(2)
	_raise_all()
	var seen_in_fight: Array = await _collect(SETTLE_S + SLACK_S)
	_t.eq("with a fight on none of the seven shows", seen_in_fight, [])

	# The fight ends: one at a time, oldest first, after two quiet seconds, no longer than a second apart.
	_game.events.pressure_changed.emit(0.0)
	var over_at := _clock
	var first_at := -1.0
	var order: Array = []
	var together := false
	var empty_for := 0.0
	var stalled := false
	while order.size() < ORDER.size() and not stalled:
		await _frames(1)
		var now := _on_screen()
		if now.size() > 1:
			together = true
		if now.is_empty():
			empty_for += _game.get_process_delta_time()
			stalled = empty_for > (SETTLE_S + SLACK_S if first_at < 0.0 else SLACK_S)
		else:
			empty_for = 0.0
		for kind in now:
			if not kind in order:
				order.append(kind)
				if first_at < 0.0:
					first_at = _clock - over_at
	_t.eq("they come oldest first", order, ORDER)
	_t.check("none stalls: the first inside the settle hold plus a second, each next inside a second", not stalled, "stalled after %s" % [order])
	_t.check("each is alone on screen", not together, "two at once %s" % [together])
	_t.check("none comes before the screen has been quiet for two seconds", first_at >= SETTLE_S - 0.1, "first at %.2f s" % first_at)
	await _settle(8.0)

	# A death is not a run end: after a death and a retry of the same run a waiting card still shows.
	_game.events.pressure_changed.emit(0.9)
	await _frames(2)
	_game.hud.tune_found("Death Record")
	_texts["Death Record\nOn Moss's jukebox at camp"] = "record"
	_game.events.achievement_earned.emit("first_win")
	await _frames(5)
	_game.events.player_died.emit()
	_game.flow.retry_stage()
	_game.events.pressure_changed.emit(0.0)
	var after_death: Array = await _collect(SETTLE_S + SLACK_S + 2.0)
	_t.check("after a death and a retry a waiting record still shows", "record" in after_death, "seen %s" % [after_death])
	_t.check("and so does a waiting achievement", "achievement" in after_death or "achievement?" in after_death, "seen %s" % [after_death])
	await _settle(4.0)

	# A run that ends with cards waiting (a banner card and a crate too) leaves none on the summary.
	_game.presentation.ceremony.pause_armed = true
	_game.events.pressure_changed.emit(0.9)
	await _frames(2)
	_raise_all()
	_game.run.add_part(_crate_part(), "vault")
	await _frames(5)
	var crate_waits: Array = _crate_state()
	_game.flow._end_run(false)
	_game.events.pressure_changed.emit(0.0)
	var late: Array = await _collect(SETTLE_S + ScreenBusy.FIND_HOLD + SLACK_S)
	# What the ending itself earns is its own; only the seven raised in the fight count.
	late = late.filter(func(kind): return kind != "achievement?")
	_t.eq("a crate was waiting before the run ended", crate_waits, [1, false])
	_t.eq("a card waiting when the run ends never shows", late, [])
	_t.eq("nor does the crate or the banner", _crate_state() + [_game.presentation.banner.queued()], [0, false, 0])
	_game.presentation.ceremony.pause_armed = false

	quit(_t.verdict())
