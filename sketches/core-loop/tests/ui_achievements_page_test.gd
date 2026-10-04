extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Achievements := preload("res://src/core/achievements.gd")
const AchievementsPage := preload("res://src/ui/achievements_page.gd")
const WordBudget := preload("res://src/ui/word_budget.gd")
const Push := preload("res://tests/workshop/push.gd")
const T := preload("res://tests/support/t.gd")

# The title's achievements page and the toast for an earn (P3). On the real title, driven
# by its key and its button:
#   - A and the Achievements button open the page, Escape and Back close it;
#   - the page lists one row per achievement in table order, each in 15 words or fewer; an
#     unearned hidden row reads "???" and "Keep playing."; a counted row shows its progress
#     from Progress.count_of; an earned row shows its date;
#   - achievement_earned shows one toast with the row's name for 3 s; while a Warden fight
#     is live toasts wait, then show in order.

const ROW_WORDS := 15
const EARNED_AT := 1790000000.0

var _t := T.new("ui_achievements_page_test")
var _game


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _settle(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		await process_frame
		left -= _game.get_process_delta_time()


func _run() -> void:
	while _game.flow == null:
		await process_frame
	await _frames(5)
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	var screens = _game.screens
	await _settle(0.6)
	_t.eq("P3-3 the game starts on the title", _game.flow.state_name(), "title")
	_t.check("P3-3 the title has an Achievements button on A", screens.button_for("achievements") != null and screens.button_for("achievements").key == "key_a", "button")
	_game._screen_key(KEY_A)
	_t.check("P3-3 the A key opens the page", screens.achievements_open() and not screens.help_open(), "open %s" % screens.achievements_open())
	_game._screen_key(KEY_H)
	_t.check("P3-3 H does not open Help over it", not screens.help_open(), "help %s" % screens.help_open())
	Push.key(root, KEY_ESCAPE)
	await _frames(2)
	_t.check("P3-3 Escape closes it", not screens.achievements_open() and _game.flow.state_name() == "title", "open %s" % screens.achievements_open())
	Push.click(root, screens.button_for("achievements"))
	await _frames(2)
	_t.check("P3-3 the button opens it", screens.achievements_open(), "open %s" % screens.achievements_open())
	var page = screens.achievements_page()
	var rows: Dictionary = page.rows
	_t.eq("P3-3 one row per achievement", rows.keys(), Achievements.ids())
	_t.eq("P3-3 eleven rows today", rows.size(), 11)
	var long := rows.keys().filter(func(id): return WordBudget.count(rows[id])["hud"] > ROW_WORDS)
	_t.check("P3-3 every row reads in 15 words or fewer", long.is_empty(), "long %s" % [long])
	var hidden := AchievementsPage.reading("clean_win", _game.ctx.profile, _game.progress)
	_t.check("P3-3 an unearned hidden row is ???", hidden["name"] == "???" and hidden["text"] == "Keep playing." and hidden["note"] == "", "%s" % [hidden])
	_t.check("P3-3 the page shows it so", _label_texts(rows["clean_win"]).has("???") and _label_texts(rows["clean_win"]).has("Keep playing."), "%s" % [_label_texts(rows["clean_win"])])
	_t.check("P3-3 a counted row shows its progress", _label_texts(rows["kills_100"]).has("0 / 100"), "%s" % [_label_texts(rows["kills_100"])])
	_t.check("P3-3 a row with a count of one shows none", not _label_texts(rows["first_win"]).any(func(s): return s.contains("/")), "%s" % [_label_texts(rows["first_win"])])
	_game.ctx.profile.add_stat("ach.kills_100", 37.0)
	_game.ctx.profile.earn("first_win", EARNED_AT)
	_game.ctx.profile.earn("clean_win", EARNED_AT)
	_t.near("P3-3 count_of reads the saved count", _game.progress.count_of("kills_100"), 37.0)
	screens.toggle_achievements()
	screens.toggle_achievements()
	rows = page.rows
	_t.check("P3-3 progress follows count_of", _label_texts(rows["kills_100"]).has("37 / 100"), "%s" % [_label_texts(rows["kills_100"])])
	var stamp := Time.get_date_string_from_unix_time(int(EARNED_AT))
	_t.check("P3-3 an earned row shows its date", _label_texts(rows["first_win"]).has(stamp), "%s want %s" % [_label_texts(rows["first_win"]), stamp])
	_t.check("P3-3 an earned hidden row shows its name", _label_texts(rows["clean_win"]).has("Clean Run"), "%s" % [_label_texts(rows["clean_win"])])
	Push.click(root, screens.button_for("back"))
	await _frames(2)
	_t.check("P3-3 Back closes it", not screens.achievements_open(), "open %s" % screens.achievements_open())
	# The toast.
	_game.flow.force_warden = true
	_game.flow.press_start()
	_game.flow.choose_class(0)
	await _settle(0.5)
	var hud = _game.hud
	_game.events.achievement_earned.emit("first_win")
	await _frames(3)
	_t.eq("P3-5 an earn shows one toast with the row's name", hud.ach_toasts(), ["Run Won"])
	await _settle(3.4)
	_t.check("P3-5 the toast ends after about 3 s", hud.ach_toasts().is_empty(), "%s" % [hud.ach_toasts()])
	_game.flow._engage()
	_t.check("P3-5 the Warden fight is live", _game.flow.engaged() and _game.flow.sealed, "engaged %s sealed %s" % [_game.flow.engaged(), _game.flow.sealed])
	_game.events.achievement_earned.emit("first_event")
	_game.events.achievement_earned.emit("full_rack")
	await _settle(0.5)
	_t.check("P3-5 during a live Warden fight the toast waits", hud.ach_toasts().is_empty() and hud.ach_waiting() == ["Event Won", "Full Rack"], "showing %s waiting %s" % [hud.ach_toasts(), hud.ach_waiting()])
	_game.flow._unseal()
	await _settle(0.5)
	_t.eq("P3-5 after the fight the first shows", hud.ach_toasts(), ["Event Won"])
	await _settle(3.4)
	_t.eq("P3-5 then the next, in order", hud.ach_toasts(), ["Full Rack"])
	await _settle(3.4)
	_t.eq("P3-5 the Warden's own earn comes last", hud.ach_toasts(), ["Warden Breaker"])
	_game.queue_free()
	quit(_t.verdict())


func _label_texts(node: Node) -> Array:
	var out := []
	if node is Label:
		out.append((node as Label).text)
	for child in node.get_children():
		out.append_array(_label_texts(child))
	return out
