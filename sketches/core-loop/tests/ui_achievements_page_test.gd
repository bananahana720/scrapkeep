extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Achievements := preload("res://src/core/achievements.gd")
const AchievementsPage := preload("res://src/ui/achievements_page.gd")
const Secrets := preload("res://src/core/secrets.gd")
const WordBudget := preload("res://src/ui/word_budget.gd")
const Push := preload("res://tests/workshop/push.gd")
const Profile := preload("res://src/core/profile.gd")
const Progress := preload("res://src/core/progress.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const ScreenBusy := preload("res://src/ui/screen_busy.gd")
const Hud := preload("res://src/ui/hud.gd")
const TuneRows := preload("res://src/core/tune_rows.gd")
const T := preload("res://tests/support/t.gd")
const PilotBlocks := preload("res://tests/support/pilot_blocks.gd")

# The title's achievements page and the toast for an earn (P3). On the real title, driven
# by its key and its button:
#   - A and the Achievements button open the page, Escape and Back close it;
#   - the page lists one row per achievement in table order, each in 15 words or fewer; an
#     unearned hidden row reads "???" and "Keep playing."; a counted row shows its progress
#     from Progress.count_of; an earned row shows its date;
#   - achievement_earned shows one toast with the row's name for 3 s; while a Warden fight
#     is live toasts wait, then show in order.
#   - 2026-10-10 (w13 B5 fix round, re-pin): a toast may carry a second "New look: <item>"
#     line (CUSTOMIZE section 4), so the toast checks expect Achievements.toast_text(id), the
#     one source of the toast's words, instead of bare names.
#   - PG10: a won run's bus facts earn first_win and mind_quieted, and the page shows both with their date.

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


# Waits for a card other than the last one returned to come up and returns it ([] at the bound). The
# bound is the source's own constants plus 60 frames: the screen's quiet hold for the first card after a
# fight (screen_busy.gd SETTLE), a card's life (hud.gd ACH_TOTAL) for each next, and the Warden's own earn, raised by the break itself,
# may also need the quiet hold.
var _last_toast: Array[String] = []


func _next_toast(bound: float) -> Array[String]:
	var limit := bound + 1.0
	while (_game.hud.ach_toasts().is_empty() or _game.hud.ach_toasts() == _last_toast) and limit > 0.0:
		await _settle(0.05)
		limit -= 0.05
	_last_toast = _game.hud.ach_toasts()
	return _last_toast


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
	# 2026-10-17 (first-win secrets): the six secret paint rows stay off the page until earned.
	_t.eq("P3-3 one row per achievement", rows.keys(), _listed())
	# 2026-10-10 (w13 B5 fix round, re-pin): B5 ships the skill bar's three shared grant rows
	# (CUSTOMIZE section 8, Shared), 36 + 3.
	# 2026-10-11 (w13 SG12, merge re-pin): the four ach_meta_* between-run option grants, 39 + 4.
	# 2026-10-12 (W13 coordinator): the pin holds the shared rows; P-C kit rows sit in marked blocks.
	# 2026-10-17 (crown authored pass): isles_rescued, Tally's sky-islands rescue, 43 + 1.
	# 2026-10-19 (w20 ACHIEVEMENTS-REFRESH): six reward-free content-family rows; was 44.
	# 2026-10-24 merge of #406 (world 1 unit 16, shift board: six brindle_mark_* rows) onto #402's
	# five ach_w19_* rows: 50 + 5 + 6.
	_t.eq("P3-3 sixty-one rows today", PilotBlocks.shared(rows.keys(), "res://src/core/achievements.gd").size(), 61)
	await _frames(2)
	_t.check("Back stays visible during page entry", root.get_visible_rect().encloses(page.back.get_global_rect()))
	await _reach_rows(page)
	Push.pad(root, JOY_BUTTON_A)
	await _frames(2)
	_t.check("pad A activates focused Back", not screens.achievements_open())
	_game._screen_key(KEY_A)
	await _settle(0.6)
	rows = page.rows
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
	# The cold open has the floor first (plates wait for a flourish's reading matter); this is about the plates.
	_game.presentation.flourish.stop_all()
	# 2026-11-11 (wave 36): every card waits in one line, oldest first (screen_busy.gd), so a record the
	# band's ear reports around the Warden's break could land ahead of the Warden's earn. This is about
	# the achievements' order, so the ear already knows every tune and raises no record here.
	for id in TuneRows.ids():
		_game.audio().knows_tune(String(id))
	await _settle(0.5)
	var hud = _game.hud
	_game.events.achievement_earned.emit("first_win")
	await _frames(3)
	_t.eq("P3-5 an earn shows one toast with the row's name", hud.ach_toasts(), [Achievements.toast_text("first_win")])
	await _settle(3.4)
	_t.check("P3-5 the toast ends after about 3 s", hud.ach_toasts().is_empty(), "%s" % [hud.ach_toasts()])
	_game.flow._engage()
	_t.check("P3-5 the Warden fight is live", _game.flow.engaged() and _game.flow.sealed, "engaged %s sealed %s" % [_game.flow.engaged(), _game.flow.sealed])
	_game.events.achievement_earned.emit("first_event")
	_game.events.achievement_earned.emit("full_rack")
	await _settle(0.5)
	_t.check("P3-5 during a live Warden fight the toast waits", hud.ach_toasts().is_empty() and hud.ach_waiting() == [Achievements.toast_text("first_event"), Achievements.toast_text("full_rack")], "showing %s waiting %s" % [hud.ach_toasts(), hud.ach_waiting()])
	_game.flow._unseal()
	# The Warden's crowd is removed for real (its telegraphs would keep the screen loud), and the
	# director spawns no next one, so the bounds below are the source's constants alone.
	_game.ctx.calm = true
	for node in _game.get_tree().get_nodes_in_group("enemy"):
		node.queue_free()
	await _settle(0.5)
	# 2026-10-04 (fix round D): since HW2 the Warden's break offers a hot-wired part, and the
	# Fit / Recycle screen opens over the paused tree as the gates open, freezing the HUD's
	# toast clock. Recycle it here so the earn queue runs; the toast order is unchanged.
	if hud.hotwire_screen != null and hud.hotwire_screen.is_open():
		hud.hotwire_screen.choose("recycle")
		await _frames(3)
	# 2026-11-11 (wave 36): a ball still rolling can pass a reward gate while the cards below come, and
	# the gate's own crate and take then hold the one line. The gates close so the line is the earns alone.
	_game.build.gates.close()
	# The screen has to be quiet for two seconds after the fight (screen_busy.gd), then the cards come one
	# at a time in the order earned: each is awaited, and a card that never shows fails the check.
	_t.eq("P3-5 after the fight the first shows", await _next_toast(ScreenBusy.SETTLE), [Achievements.toast_text("first_event")])
	_t.eq("P3-5 then the next, in order", await _next_toast(Hud.ACH_TOTAL), [Achievements.toast_text("full_rack")])
	_t.eq("P3-5 the Warden's own earn comes last", await _next_toast(Hud.ACH_TOTAL + ScreenBusy.SETTLE), [Achievements.toast_text("warden_broken")])
	_t.check("P3-5 no record card joined that line", hud.tune_waiting().is_empty(), "%s" % [hud.tune_waiting()])
	# 2026-10-05 (wave 14, prog-G10): the page after a won run's bus facts, on its own bus.
	var bus = GameEvents.new()
	_game.add_child(bus)
	var fresh := Profile.new("%s/progression_win.json" % _game.storage_dir)
	fresh.load_profile()
	var progress := Progress.new()
	_game.add_child(progress)
	const NOW := 1700000000.0
	progress.setup(bus, _game.run, fresh, func(): return NOW)
	bus.run_started.emit("x")
	bus.world_entered.emit(3)
	bus.boss_defeated.emit()
	bus.run_ended.emit(true)
	page.refresh(fresh, progress)
	rows = page.rows
	var won_stamp := Time.get_date_string_from_unix_time(int(NOW))
	var fw := _label_texts(rows["first_win"])
	var mq := _label_texts(rows["mind_quieted"])
	var fr := _label_texts(rows["full_rack"])
	_t.check("PG10 first_win row shows its name and date", fw.has(String(Achievements.row("first_win")["name"])) and fw.has(won_stamp), "%s" % [fw])
	_t.check("PG10 mind_quieted row shows its name and date", mq.has(String(Achievements.row("mind_quieted")["name"])) and mq.has(won_stamp), "%s" % [mq])
	_t.check("PG10 full_rack stays unearned", not AchievementsPage.reading("full_rack", fresh, progress)["earned"] and not fr.has(won_stamp), "%s" % [fr])
	_t.eq("PG10 first_win counted once", progress.count_of("first_win"), 1.0)
	progress.free()
	bus.free()
	_game.queue_free()
	quit(_t.verdict())


func _label_texts(node: Node) -> Array:
	var out := []
	if node is Label:
		out.append((node as Label).text)
	for child in node.get_children():
		out.append_array(_label_texts(child))
	return out


func _reach_rows(page) -> void:
	var original := root.size
	var original_scale := root.content_scale_size
	await _settle(0.6)
	for resolution in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = resolution
		root.content_scale_size = resolution
		await _frames(5)
		_t.eq("viewport checks actual resolution", Vector2i(root.get_visible_rect().size), resolution)
		var view := root.get_visible_rect()
		var plate: Rect2 = page.list_rect()
		var first: Rect2 = page.rows.values()[0].get_global_rect()
		var second: Rect2 = page.rows.values()[1].get_global_rect()
		_t.check("the list's plate sits inside the view at %s" % resolution, view.encloses(plate), "view %s plate %s" % [view, plate])
		_t.check("the list is centred at %s" % resolution, absf(plate.get_center().x - view.get_center().x) <= 2.0, "view %s plate %s" % [view, plate])
		_t.check("rows start inside the plate and off the screen edge at %s" % resolution, plate.position.x >= 8.0 and first.position.x >= plate.position.x + 8.0, "plate %s row %s" % [plate, first])
		_t.check("both columns are one width at %s" % resolution, is_equal_approx(first.size.x, second.size.x), "%s against %s" % [first.size.x, second.size.x])
		for pad in [false, true]:
			page.rows.values()[0].grab_focus()
			await _frames(3)
			var reached := []
			for id in _listed():
				var row: Control = page.rows[id]
				await _frames(3)
				if row.has_focus() and page._scroll.get_global_rect().encloses(row.get_global_rect()):
					reached.append(id)
				_t.check("Back visible at %s with %s focused" % [resolution, id], root.get_visible_rect().encloses(page.back.get_global_rect()), "view %s back %s" % [root.get_visible_rect(), page.back.get_global_rect()])
				if pad:
					Push.pad(root, JOY_BUTTON_DPAD_DOWN)
				else:
					Push.key(root, KEY_DOWN)
			await _frames(3)
			_t.eq("all rows reachable by %s at %s" % ["pad" if pad else "keyboard", resolution], reached, _listed())
			_t.check("navigation reaches fixed Back at %s" % resolution, page.back.has_focus())
			_t.check("list scrolls to its final row at %s" % resolution, page._scroll.scroll_vertical > 0)
	root.size = original
	root.content_scale_size = original_scale
	await _frames(5)


# The rows the page lists for the game's profile: every row but an unearned first-win secret.
func _listed() -> Array:
	return Achievements.ids().filter(func(id): return not Secrets.shut_row(id, _game.ctx.profile))
