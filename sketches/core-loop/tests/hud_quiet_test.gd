extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Achievements := preload("res://src/core/achievements.gd")
const Parts := preload("res://src/build/parts.gd")


const T := preload("res://tests/support/t.gd")

# Nothing talks over a fight (PF-19, wave 36 unit hud). On the real game in a run:
#   - with a fight on (the bus's pressure), a record, a B-side, an achievement, a look, a field
#     note, a synergy and a fleet-grade find are raised and none of the seven shows;
#   - when the fight ends they come one at a time, oldest first, each alone on screen, and not
#     before the screen has been quiet for two seconds;
#   - a card still waiting when the run ends is not on screen afterwards;

const SETTLE_S := 2.0
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
	_texts = {"Test Record\nOn Moss's jukebox at camp": "record", "Test Take\nOn the radio: KEEP Live": "b-side",
		Achievements.toast_text("first_win"): "achievement", Achievements.toast_text(look): "look"}
	hud.tune_found("Test Record")
	hud.take_found("Test Take", "KEEP Live", "b-side")
	_game.events.achievement_earned.emit("first_win")
	_game.events.achievement_earned.emit(look)
	_game.codex.lore_found.emit("test_note")
	_game.presentation.banner.show_discovery("Test Synergy", "build", "Two parts work as one.", "New synergy", "test_synergy")
	_game.run.add_part(_rare_part(), "pickup")


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

	# A fight is on: the seven cards wait.
	_game.events.pressure_changed.emit(0.9)
	await _frames(2)
	_raise_all()
	var seen_in_fight := []
	var until := _clock + 2.5
	while _clock < until:
		await _frames(1)
		seen_in_fight.append_array(_on_screen())
	_t.eq("with a fight on none of the seven shows", seen_in_fight.slice(0, 6), [])

	# The fight ends: one at a time, oldest first, after two quiet seconds.
	_game.events.pressure_changed.emit(0.0)
	var over_at := _clock
	var first_at := -1.0
	var order: Array = []
	var together := false
	until = _clock + 60.0
	while _clock < until and order.size() < ORDER.size():
		await _frames(1)
		var now := _on_screen()
		if now.size() > 1:
			together = true
		for kind in now:
			if not kind in order:
				order.append(kind)
				if first_at < 0.0:
					first_at = _clock - over_at
	_t.eq("they come oldest first", order, ORDER)
	_t.check("each is alone on screen", not together, "two at once %s" % [together])
	_t.check("none comes before the screen has been quiet for two seconds", first_at >= SETTLE_S - 0.1, "first at %.2f s" % first_at)
	await _settle(8.0)

	# A run that ends with cards waiting leaves none on the summary.
	_game.events.pressure_changed.emit(0.9)
	await _frames(2)
	_raise_all()
	await _frames(5)
	_game.events.player_died.emit()
	_game.events.run_ended.emit(false)
	_game.events.pressure_changed.emit(0.0)
	var late := []
	until = _clock + 9.0
	while _clock < until:
		await _frames(1)
		# What the ending itself earns is its own; only the seven raised in the fight count.
		late.append_array(_on_screen().filter(func(kind): return kind != "achievement?"))
	_t.eq("a card waiting when the run ends never shows", late, [])

	quit(_t.verdict())
