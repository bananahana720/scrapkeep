extends CanvasLayer

const ResultsOdds := preload("res://src/ui/results_odds.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")

const Palette := preload("res://src/core/palette.gd")
const SummaryRows := preload("res://src/ui/summary_rows.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const FieldNotes := preload("res://src/ui/field_notes.gd")
const Icons := preload("res://src/ui/icons.gd")
const Keycap := preload("res://src/ui/keycap.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const ChoiceButton := preload("res://src/ui/choice_button.gd")
const ClassCard := preload("res://src/ui/class_card.gd")
const HelpPage := preload("res://src/ui/help_page.gd")
const AchievementsPage := preload("res://src/ui/achievements_page.gd")
const SettingsPages := preload("res://src/ui/settings_pages.gd")
const CampMenu := preload("res://src/ui/camp_menu.gd")
const CampScrapbook := preload("res://src/ui/camp_scrapbook.gd")
const JukeboxPage := preload("res://src/ui/jukebox_page.gd")
const RadioPage := preload("res://src/ui/radio_page.gd")
const Achievements := preload("res://src/core/achievements.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const Worlds := preload("res://src/core/worlds.gd")
const EndingSequence := preload("res://src/ui/ending_sequence.gd")
const PrologueRows := preload("res://src/core/prologue_rows.gd")
const CreditsHint := preload("res://src/ui/credits_hint.gd")
const DeathTips := preload("res://src/core/death_tips.gd")
const ScrapFrame := preload("res://src/ui/scrap_frame.gd")
const ChasePlate := preload("res://src/ui/chase_plate.gd")

# The screens outside play: title (with its how-to-play page on H), class select,
# death, victory and summary. Each is one glance and one key, and every choice is also
# a button that presses that key through game._screen_key, so a click and a key can
# never disagree. Starting and restarting take a second (principle 2). Screens fade in
# and out with a tween that never holds input or the ball, so play starts under a veil.

const FADE_IN := 0.3
const FADE_OUT := 0.25
const SLIDE := 14.0
# The death screen ignores clicks for its first beat: a fire button held or mashed as
# the ball died must not pick a choice. Keys work at once.
const CLICK_GUARD := 0.5
const CARD_GAP := 24.0
# Five or more cards close the gap so six fit one row at 1600 px.
const CARD_GAP_TIGHT := 12.0
const CARD_MAX := 420.0
const SIDE := 60.0
# Frames the card row waits for its first layout before it levels.
const LEVEL_TRIES := 6
# The actions' gap, between buttons and between rows. A row that would pass the narrowest
# supported width (int_screen_layout_test's 1280) less SIDE each way wraps onto a second
# centred row; no button is dropped or shrunk.
const ACTION_GAP := UiTokens.GAP_M
const NARROW_W := 1280.0
const MENU_STATES := ["title", "class_select", "dead", "victory", "summary"]
# The screens a run ends on.
const END_STATES := ["dead", "summary"]
const TITLE := "SCRAPKEEP"
# The title's name lands like an ink stamp (TONE-BIBLE UI motion): it starts big and tilted and
# snaps down with a short overshoot. It rests straight, because its container's layout resets a
# child's scale and rotation. Reduced motion skips the slam.
const STAMP_FROM := 1.35
const STAMP_TIME := 0.18
const STAMP_TILT := -6.0
# A win over the final world's boss opens the summary on the ending page (Worlds.ENDING). For
# its first ENDING_HOLD seconds no key closes it, so a press meant for the fight cannot skip
# it; after that Space, Enter, Esc or any pad button shows the summary beneath.
const ENDING_HOLD := 1.0
const PROLOGUE_TITLE := "FIRST SHIFT"
# The pilot select's heading, its one line (ui_class_card_level_test L4 pins it with the key row on screen):
# the game's one line (STORY-MAP.md section 1) as the crew's board would say it.
const PILOT_LINE := "Loose cannons, all of them. Pick one."
# Start is the one filled button on the title: the primary action reads first and biggest.
# The run-end comic page (run_moments.gd) on the summary, drawn by the camp's comic_page.gd
# when the build has it: 3:4, at most this share of the screen's height.
const COMIC_PAGE_PATH := "res://src/ui/comic_page.gd"
const COMIC_HEIGHT := 0.5
# The word under each of the summary's stats.
const STAT_WORD_FONT := UiTokens.CAPTION
const COMIC_MAX_HEIGHT := 540.0
const COMIC_BODY_LINES := 3
const COMIC_MIN_HEIGHT := 240.0
# RUN OVER's "next shift" note (core/death_tips.gd): an amber-edged plate taped up beside the comic page,
# where the column has room; under the body it pushed the actions off a 900 px screen. Its words wrap at
# TIP_WIDTH.
const TIP_FONT := UiTokens.BODY
const TIP_HEAD_FONT := UiTokens.BODY
const TIP_WIDTH := 300.0
const TIP_GAP := UiTokens.GAP_XL
const TIP_SERIAL := 33
# The summary's input latch (game.summary_latched) shuts every key while an input held at its opening is
# still down. The cue names that input once the latch has held LATCH_CUE_AFTER seconds, or at once when a
# press is turned away, and goes with the release. It is laid over the actions row, which it dims to
# LATCH_DIM while it shows: the row takes nothing then, the column has no spare line, and laying it over
# moves nothing.
const LATCH_CUE_AFTER := 0.5
const LATCH_DIM := 0.12
const PRIMARY_FONT := UiTokens.LABEL
const PRIMARY_HEIGHT := 60.0
# The widest a wrapped body line runs.
const BODY_WIDTH := 1000.0

var game
var _victory_boss := {}
var _veil_wait := 0.0
# The end screen is held back while the run's last still is being taken (_step_still_wait).
var _still_wait := false

var _veil: ColorRect
var _content: VBoxContainer
var _title: Label
# A beaten boss row's "stamp" (Worlds.BOSSES), inked under the victory title: the Mind's HIRED.
var _mark: Label
var _body: Label
# The summary's "next shift" note, in the comic row; null when the screen has none.
var _tip: Control
var _tip_said := ""
# The summary's "what to chase" plate (chase_plate.gd), left of the comic page; null when the screen has none.
var _chase: Control
var _latch_cue
var _latch_held := 0.0
var _latch_glyph := ""
var _stats: HBoxContainer
var _choices: HBoxContainer
var _comic_row: HBoxContainer
var _actions: HFlowContainer
# Under the title's buttons: why a saved run was refused, so New run is the plain next step.
var _refusal: Label
# Under the class cards: how to choose and start, drawn with the title's keycaps.
var _footer
# The ACE music's held breath, on the settings page (B); the title no longer carries it.
var _breath_row: Button
var _help
var _achievements
var _settings
var _camp
var _jukebox
var _radio
# The camp walk (camp_hub.gd): K on the title puts the ball in the 3D camp. The camp page shrinks to a key-hint strip
# and each station's page opens over the walk and gives it back. _walk_page is a page a feature opened through
# open_walk_page(), with the call that runs when it closes.
var _walking := false
var _walk_page: Control
var _walk_on_close := Callable()
var _companion_hooked := false
var _ending: VBoxContainer
var _ending_title: Label
var _ending_body: Label
var _ending_left := 0.0
var ending_sequence
var _guard := 0.0
var _tween: Tween
var _stamp_tween: Tween
var _state := ""
# The prologue (PrologueRows) plays on the first pilot select of a profile. A bot-driven game
# (the headless tests) skips it unless it opts in, so its Start lands on the cards as before.
var prologue_enabled := true
var _prologue_line := -1
var _level_tries := 0


func setup(game_ref) -> void:
	game = game_ref
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	_veil = ColorRect.new()
	_veil.color = Color(Palette.CHARCOAL, 0.84)
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veil)

	_content = VBoxContainer.new()
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_theme_constant_override("separation", 24)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	_title = _label(UiTokens.DISPLAY)
	_content.add_child(_title)
	_mark = _label(UiTokens.HEADING)
	_mark.add_theme_color_override("font_color", Palette.AMBER)
	_mark.visible = false
	_content.add_child(_mark)
	_body = _label(UiTokens.LABEL)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(BODY_WIDTH, 0.0)
	_body.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_content.add_child(_body)
	_stats = _row(UiTokens.GAP_XL)
	_content.add_child(_stats)
	_comic_row = _row(TIP_GAP)
	_content.add_child(_comic_row)
	_choices = _row(CARD_GAP)
	_content.add_child(_choices)
	_actions = HFlowContainer.new()
	_actions.alignment = FlowContainer.ALIGNMENT_CENTER
	_actions.add_theme_constant_override("h_separation", ACTION_GAP)
	_actions.add_theme_constant_override("v_separation", ACTION_GAP)
	_actions.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_actions)
	_refusal = _label(UiTokens.BODY)
	_refusal.add_theme_color_override("font_color", Palette.SAND)
	_refusal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_refusal.custom_minimum_size = Vector2(1000.0, 0.0)
	_refusal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_refusal.visible = false
	_content.add_child(_refusal)
	_footer = CreditsHint.new()
	_footer.visible = false
	_footer.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_content.add_child(_footer)
	prologue_enabled = not game.bot_driven
	# A card that can wait (a record heard, a take found) waits for the story cards to close: the
	# menu's own record used to land its card on the prologue's first line (PF-19).
	if game.ctx.screen_busy != null:
		game.ctx.screen_busy.add_source(prologue_showing)
	_help = HelpPage.new()
	_help.tuning = game.tuning
	_help.visible = false
	_help.back.pressed.connect(_press.bind("key_h"))
	_content.add_child(_help)
	_achievements = AchievementsPage.new()
	_achievements.visible = false
	# Back closes the page directly: over the camp walk the A hotkey is the trophy wall's, not the page's.
	_achievements.back.pressed.connect(toggle_achievements)
	_content.add_child(_achievements)
	_settings = SettingsPages.new()
	_settings.visible = false
	_settings.setup(game, "key_esc")
	_settings.back_requested.connect(toggle_settings)
	_content.add_child(_settings)
	_breath_row = ChoiceButton.new("breath", "key_b", "")
	_breath_row.pressed.connect(_press.bind("key_b"))
	_breath_row.visible = false
	_breath_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_content.add_child(_breath_row)
	_camp = CampMenu.new()
	_camp.visible = false
	_camp.button_for("launch").pressed.connect(_press.bind("key_space"))
	_camp.button_for("achievements").pressed.connect(_press.bind("key_a"))
	_camp.button_for("settings").pressed.connect(_press.bind("key_s"))
	_camp.back.pressed.connect(_press.bind("key_k"))
	_camp.companion_button().pressed.connect(walk_companion)
	_camp.button_for("jukebox").pressed.connect(_press.bind("key_j"))
	_content.add_child(_camp)
	_camp.customize.back_requested.connect(_sync_walk)
	_jukebox = JukeboxPage.new()
	_jukebox.visible = false
	_jukebox.sleeve_chosen.connect(_spin_toggle)
	_jukebox.play_button.pressed.connect(_press.bind("key_space"))
	for i in 3:
		_jukebox.detent_button(i).pressed.connect(_press.bind("key_%d" % (i + 1)))
	_jukebox.back.pressed.connect(_press.bind("key_j"))
	_content.add_child(_jukebox)
	_camp.button_for("radio").pressed.connect(_press.bind("key_r"))
	_radio = RadioPage.new()
	_radio.visible = false
	_radio.track_chosen.connect(_radio_track)
	_radio.tape_chosen.connect(func(i: int): radio_key(KEY_1 + i))
	_radio.new_button.pressed.connect(_press.bind("key_n"))
	_radio.shuffle_button.pressed.connect(_press.bind("key_x"))
	_radio.tune_button.pressed.connect(_press.bind("key_t"))
	_radio.back.pressed.connect(_press.bind("key_r"))
	_content.add_child(_radio)
	_ending = VBoxContainer.new()
	_ending.alignment = BoxContainer.ALIGNMENT_CENTER
	_ending.add_theme_constant_override("separation", 24)
	_ending.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ending.visible = false
	_ending_title = _label(UiTokens.DISPLAY)
	_ending.add_child(_ending_title)
	_ending_body = _label(UiTokens.LABEL)
	_ending_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ending_body.custom_minimum_size = Vector2(1000.0, 0.0)
	_ending_body.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_ending.add_child(_ending_body)
	_content.add_child(_ending)
	_latch_cue = CreditsHint.new()
	_latch_cue.visible = false
	add_child(_latch_cue)
	game.events.flow_changed.connect(_on_flow_changed)
	game.events.run_started.connect(func(_class_id): _victory_boss = {})
	if game.run_moments != null:
		game.run_moments.page_ready.connect(_show_comic_page)


func _label(font_size: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", UiFonts.bold())
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _row(separation: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", separation)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return row


func _on_flow_changed(state: String) -> void:
	if _walking:
		_stop_walk()
	if is_instance_valid(ending_sequence):
		ending_sequence.cancel()
		ending_sequence.queue_free()
		ending_sequence = null
	_content.visible = true
	_veil.visible = true
	_state = state
	_help.visible = false
	_achievements.visible = false
	_settings.visible = false
	_camp.visible = false
	_jukebox.visible = false
	_radio.visible = false
	_ending.visible = false
	_ending_left = 0.0
	_prologue_line = -1
	_footer.visible = false
	_breath_row.visible = false
	_refusal.text = ""
	_tip = null
	_tip_said = ""
	_chase = null
	_latch_held = 0.0
	_mark.visible = false
	_unstamp()
	_stats.visible = true
	_comic_row.visible = true
	_choices.visible = true
	_actions.visible = true
	_fit_actions()
	for row in [_stats, _comic_row, _choices, _actions]:
		for child in row.get_children():
			row.remove_child(child)
			child.queue_free()
	match state:
		"title":
			# Continue (RS6) leads when a saved run is valid, so a pad's first focus lands on
			# it; a saved file this build cannot use names its cause under the buttons and
			# leaves New run, focused, as the next step.
			game.flow.saved_run()
			_show(TITLE, Palette.AMBER, FieldNotes.OBJECTIVE)
			# The title fills none of these rows; hidden, their gaps no longer push a wrapped
			# action row below the stage line at 1280x720.
			for row in [_stats, _comic_row, _choices]:
				row.visible = false
			if game.flow.continue_ready:
				_action("continue", "key_c", "Continue")
			# The main menu (decisions.tsv 2026-10-16 alpha-scope): Play to pilot select, then
			# Camp, Settings, Help and Achievements, and Quit last. Esc only moves the focus to Quit.
			var saved: bool = game.flow.continue_ready or game.flow.saved_run_cause != ""
			_action("start", "key_space", "New run" if saved else "Play")
			_action("camp", "key_k", "Camp")
			_action("settings", "key_s", "Settings")
			_action("help", "key_h", "Help")
			_action("achievements", "key_a", "Achievements")
			if game.ctx.profile != null and not game.ctx.profile.companion().is_empty():
				_companion_action()
			_action("quit", "key_esc", "Quit")
			_stamp()
			_announce_ready()
			if game.flow.saved_run_cause != "":
				_refusal.text = "The saved run would not load. %s" % continue_refusal()
				button_for("start").grab_focus()
		"class_select":
			_show("", Palette.SAND, PILOT_LINE)
			# Pilot select fills none of these rows; hidden, their gaps (26 px each) are room for
			# the line under the title with the cards at full height and the key row on screen.
			for row in [_stats, _comic_row, _actions]:
				row.visible = false
			var classes: Array = game.flow.classes
			var gap := CARD_GAP if classes.size() <= 4 else CARD_GAP_TIGHT
			_choices.add_theme_constant_override("separation", int(gap))
			var width := minf(CARD_MAX, (_screen().x - 2.0 * SIDE - (classes.size() - 1) * gap) / maxf(1.0, classes.size()))
			for i in classes.size():
				var card := ClassCard.new(classes[i], "key_%d" % (i + 1), width)
				card.pressed.connect(_press.bind(card.key))
				_choices.add_child(card)
				card.bind_profile(game.ctx.profile)
				card.set_locked(not game.pilot_unlocked(classes[i]), _unlock_hint(classes[i]))
			_queue_level()
			_footer.setup([{"cap": "key_enter", "say": "Enter"}, {"say": "start"}])
			_footer.visible = true
			if _prologue_due():
				_begin_prologue()
			else:
				_open_first_pilot()
		"dead":
			# The store-less flow's end screen says what RUN OVER says: who, then what to try (death_tips.gd).
			var said: String = game.flow.death_cause
			if game.flow.death_tip != "":
				said += "\n" + DeathTips.shown(game.flow.death_tip)
			_show("SCRAPPED", EventKinds.color("player_died"), said.strip_edges())
			_action("new", "key_n", "New run")
			_action("class", "key_c", "Choose pilot")
			if not game.run.companion.is_empty():
				_companion_action()
			if game.flow.can_replay_final_stage():
				_action("replay", "key_t", "Replay stage %d" % game.ctx.stages.local(game.flow.final_stage()))
			_guard = CLICK_GUARD
		"victory":
			var boss := _beaten_boss()
			_victory_boss = boss
			_show(String(boss.get("title", "BOSS ROUTED")), EventKinds.color("boss_defeated"), String(boss.get("victory", "")))
			_mark.text = String(boss.get("stamp", ""))
			if _mark.text != "":
				_mark.visible = true
				_stamp(_mark)
		"summary":
			var body := String(game.run.summary()["class"])
			# What scrapped you, under the pilot (core/death_cause.gd): a won run has none.
			if not game.flow.run_won and game.flow.death_cause != "":
				body += "\n" + game.flow.death_cause
			# The trade pockets' odds are a tuning readout (recency, safe share, refusal weight), so
			# only a --dev launch prints them; a played run's summary keeps to the run.
			var trade_lines := ResultsOdds.text(game.run.summary().trade_pockets) if game.ctx.dev else ""
			if trade_lines != "":
				body += "\n" + trade_lines
			var epitaph := String(_victory_boss.get("epitaph", ""))
			if epitaph != "":
				body += "\n" + epitaph
			var ending: bool = game.flow.won_final() and not _victory_boss.is_empty()
			if not ending:
				_victory_boss = {}
			var board := _board_line()
			if board != "":
				body += "\n" + board
			_show("RUN COMPLETE" if game.flow.run_won else "RUN OVER", EventKinds.color("run_ended"), body)
			# The summary has no choice cards; hidden, the row's gap is the column's (a first win
			# that lands several shift board stamps takes two body lines for them).
			_choices.visible = false
			# What to try next shift (core/death_tips.gd): only a lost run has one.
			if not game.flow.run_won and game.flow.death_tip != "":
				_show_tip(game.flow.death_tip)
			_show_chase()
			_summary_stats()
			_action("again", "key_n", "New run")
			_action("class", "key_c", "Choose pilot")
			if not game.run.companion.is_empty():
				_companion_action()
			_action("camp", "key_k", "Camp")
			if ending:
				_open_ending()
	_veil_wait = game.flow.victory_veil if state == "victory" and "victory_veil" in game.flow else 0.0
	_still_wait = state in END_STATES and game.run_moments != null and game.run_moments.still_pending()
	if _veil_wait > 0.0 or _still_wait:
		_hide_for_rout()
	else:
		_fade(state in MENU_STATES)
	_update_enabled()


# The victory card waits while a boss's rout plays over the world (flourish_cues.gd); flow
# zeroes victory_veil when the rout is skipped. An end screen waits the same way for the run's
# last still (_step_still_wait).
func _hide_for_rout() -> void:
	if _tween != null:
		_tween.kill()
	_veil.modulate.a = 0.0
	_content.modulate.a = 0.0
	visible = false


# A run that ends on a death is photographed for its comic page on the frame it ends
# (run_moments.gd). The end screen comes up the frame after the picture is taken, so the
# page's last panel shows the death and not this screen fading in over it.
func _step_still_wait() -> void:
	if not _still_wait or game.run_moments.still_pending():
		return
	_still_wait = false
	if _state in END_STATES:
		_fade(true)


func _step_veil_wait(delta: float) -> void:
	if _veil_wait <= 0.0 or get_tree().paused:
		return
	_veil_wait -= delta
	if _veil_wait <= 0.0 or game.flow.victory_veil <= 0.0 or _state != "victory":
		_veil_wait = 0.0
		if _state == "victory":
			_fade(true)
			_stamp()


# The sentence a refused saved run gives: game.continue_refusal() when the build has it, else
# the run store's last error, else flow's reason for a document it could not apply.
func continue_refusal() -> String:
	if game.flow.saved_run_cause == "":
		return ""
	if game.has_method("continue_refusal"):
		var said := String(game.continue_refusal())
		if said != "":
			return said
	if game.flow.store != null and String(game.flow.store.last_error) != "":
		return String(game.flow.store.last_error)
	return game.flow.saved_run_why


func refusal_text() -> String:
	return _refusal.text if _refusal.visible else ""


# The camp gate asks: a first run goes by pilot select, where the prologue plays.
func prologue_due() -> bool:
	return _prologue_due()


# The launch take's wind (launch_take.gd): pilot select fades off the deck so its camera lift shows.
func fade_for_launch() -> void:
	_fade(false)


# The UI profile records the prologue as a seen callout; see REPORT ST5 for why not the codex.
func _prologue_due() -> bool:
	if not prologue_enabled:
		return false
	var profile = game.hud.profile if game.hud != null else null
	return profile != null and not profile.seen(PrologueRows.ID)


func _begin_prologue() -> void:
	game.hud.profile.mark_seen(PrologueRows.ID)
	_prologue_line = 0
	_choices.visible = false
	_footer.visible = false
	_actions.visible = true
	_show_prologue_line()


func prologue_showing() -> bool:
	return _prologue_line >= 0


func prologue_line() -> int:
	return _prologue_line


func _show_prologue_line() -> void:
	var row: Dictionary = PrologueRows.ROWS[_prologue_line]
	_show(PROLOGUE_TITLE, Palette.AMBER, "%s: %s" % [row["speaker"], row["text"]])
	for child in _actions.get_children():
		_actions.remove_child(child)
		child.queue_free()
	var last := _prologue_line == PrologueRows.ROWS.size() - 1
	var next := ChoiceButton.new("prologue_next", "key_e", "Clock in" if last else "Next")
	next.pressed.connect(advance_prologue)
	_actions.add_child(next)
	_fade(true)


# The interact key, pad Y or the Next button: the next line, and after the last the cards.
func advance_prologue() -> void:
	if not prologue_showing():
		return
	_prologue_line += 1
	if _prologue_line >= PrologueRows.ROWS.size():
		end_prologue()
	else:
		_show_prologue_line()


# Fire or hook skips what is left, as they end a zone-entry exchange.
func end_prologue() -> void:
	if not prologue_showing():
		return
	_prologue_line = -1
	for child in _actions.get_children():
		_actions.remove_child(child)
		child.queue_free()
	_show("", Palette.SAND, PILOT_LINE)
	_actions.visible = false
	_choices.visible = true
	_footer.visible = true
	_queue_level()
	_fade(true)
	_open_first_pilot()


# While the prologue shows, every key stays on it (Esc too, which never quits), so a number cannot
# pick a pilot unseen. A click on its own button is the GUI's, not a skip.
func _prologue_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var next := button_for("prologue_next")
		if next != null and next.get_global_rect().has_point(event.position):
			return
	if event.is_action_pressed("cl_interact"):
		advance_prologue()
	elif event.is_action_pressed("cl_fire") or event.is_action_pressed("cl_harpoon"):
		end_prologue()
	elif not (event is InputEventKey and event.pressed):
		return
	get_viewport().set_input_as_handled()


# H on the title swaps its body and actions for the how-to-play page, and back.
func toggle_help() -> void:
	_close_camp_silently()
	if _state != "title" or _achievements.visible or _settings.visible:
		return
	_help.visible = not _help.visible
	_actions.visible = not _help.visible
	if _help.visible:
		_show("", Palette.AMBER, "")
		_help.page_button.grab_focus()
	else:
		_show(TITLE, Palette.AMBER, FieldNotes.OBJECTIVE)
		var help_button = button_for("help")
		if help_button != null:
			help_button.grab_focus()
	_fade(true)


func help_open() -> bool:
	return _help.visible


# A on the title swaps its body and actions for the achievements page, and back.
func toggle_achievements() -> void:
	_close_camp_silently()
	if _state != "title" or _help.visible or _settings.visible:
		return
	_achievements.visible = not _achievements.visible
	_actions.visible = not _achievements.visible
	if _achievements.visible:
		_achievements.refresh(game.ctx.profile, game.progress, game.tuning != null and game.tuning.sitting())
		_achievements.back.set_key("key_esc")
		_show("", Palette.AMBER, "")
		_sync_walk()
	else:
		_back_to_base()
	_fade(true)


# S on the title swaps its body and actions for the settings page, and back. It never
# pauses the game or touches the mouse; Esc only goes back.
func toggle_settings() -> void:
	_close_camp_silently()
	if _state != "title" or _help.visible or _achievements.visible:
		return
	_settings.visible = not _settings.visible
	_actions.visible = not _settings.visible
	if _settings.visible:
		_settings.refresh()
		_show("", Palette.AMBER, "")
		_settings.focus("fullscreen")
		refresh_lab_row()
		_sync_walk()
	else:
		_breath_row.visible = false
		_back_to_base()
	_fade(true)


# K on the title opens the camp: a walk through the 3D camp (camp_hub.gd) with a key-hint strip, and K again
# leaves it. The stations open their pages from their zones; each page's Back returns to the walk.
func toggle_camp() -> void:
	if _state != "title" or _help.visible or _achievements.visible or _settings.visible:
		return
	if _walking:
		if not walk_live():
			return
		_end_walk()
		return
	_begin_walk()


func _begin_walk() -> void:
	_walking = true
	_camp.set_walk(true)
	_camp.refresh(game)
	var audio = _audio()
	if audio != null:
		audio.camp_theme(true)
	_actions.visible = false
	_show("CAMP", Palette.AMBER, "")
	game.camp_hub.enter_walk()
	_hook_companion()
	get_viewport().gui_release_focus()
	_sync_walk()
	_fade(true)


func _end_walk() -> void:
	_stop_walk()
	_camp.visible = false
	_actions.visible = true
	_show(TITLE, Palette.AMBER, FieldNotes.OBJECTIVE)
	get_viewport().gui_release_focus()
	_fade(true)


# The walk ends: the hub hides, the ball freezes and the input goes back to the menus. The title is restored by the
# caller (K) or by the flow change that rebuilds it (Launch).
func _stop_walk() -> void:
	if not _walking:
		return
	_walking = false
	var audio = _audio()
	if audio != null:
		audio.camp_theme(false)
	if is_instance_valid(_walk_page):
		_walk_page.visible = false
	_walk_page = null
	_walk_on_close = Callable()
	game.camp_hub.leave_walk()
	_camp.set_walk(false)
	_veil.visible = true
	_title.visible = true
	_content.alignment = BoxContainer.ALIGNMENT_CENTER
	game.walk_input(false)


func walking() -> bool:
	return _walking


# The gate's launch ends the walk before the run starts, so leaving the camp never lands after the run has placed the ball.
func stop_walk_for_launch() -> void:
	_stop_walk()


# The walk is live when it shows no page: the ball rolls, the zones answer their keys and the prompts show.
func walk_live() -> bool:
	return _walking and not page_open()


# A page covers the walk: Help, Achievements, Settings, Jukebox, Mixtapes, Customize, the Companion panel or a page a
# feature opened with open_walk_page().
func page_open() -> bool:
	if _help.visible or _achievements.visible or _settings.visible or _jukebox.visible or _radio.visible:
		return true
	if _camp.customize != null and _camp.customize.visible:
		return true
	var workshop = game.get_node_or_null("Workshop")
	if workshop != null and workshop.companion_panel.is_open():
		return true
	return is_instance_valid(_walk_page)


# Brings the screen in line with the walk: live shows the strip and the prompts and rolls the ball; a page shows
# the veil and holds the ball.
func _sync_walk() -> void:
	if not _walking:
		return
	var live := walk_live()
	var customizing: bool = _camp.customize != null and _camp.customize.visible
	game.walk_input(live)
	game.camp_hub.set_prompts_visible(live)
	# The camp's caption card belongs to the walk: a page over it is read alone.
	for card in get_tree().get_nodes_in_group(CampScrapbook.LINE_GROUP):
		card.visible = live
	_camp.visible = live or customizing
	_veil.visible = not live
	_title.visible = not live and _title.text != ""
	_content.alignment = BoxContainer.ALIGNMENT_END if live else BoxContainer.ALIGNMENT_CENTER
	_layout_backdrop()


# A page closes: the title when there is no walk, else the walk.
func _back_to_base() -> void:
	if _walking:
		_actions.visible = false
		_show("CAMP", Palette.AMBER, "")
		_sync_walk()
	else:
		_show(TITLE, Palette.AMBER, FieldNotes.OBJECTIVE)


# The one way a new page opens over the walk and returns to it: the page is shown over the veil, the ball is held,
# and Back, Esc or pad B (or close_walk_page()) hides it, runs on_close and gives the walk back with the ball where
# it was. A page that has its own Back button connects it to close_walk_page.
func open_walk_page(page: Control, on_close := Callable()) -> void:
	if not walk_live():
		return
	if page.get_parent() == null:
		_content.add_child(page)
	page.visible = true
	_walk_page = page
	_walk_on_close = on_close
	_actions.visible = false
	_show("", Palette.AMBER, "")
	_sync_walk()
	_fade(true)


func close_walk_page() -> void:
	if not is_instance_valid(_walk_page):
		_walk_page = null
		return
	var page := _walk_page
	var after := _walk_on_close
	_walk_page = null
	_walk_on_close = Callable()
	page.visible = false
	if after.is_valid():
		after.call()
	_back_to_base()
	_fade(true)


func walk_page() -> Control:
	return _walk_page


# The walk's keys, from game._screen_key while the walk is live: K leaves; any other key acts only inside the zone
# of a station that names it, and the rest go to the ball.
func walk_key(key: int) -> bool:
	if key == KEY_K:
		toggle_camp()
		return true
	return game.camp_hub.press_key(key)


# Customize at the lockers: the camp page's own customize page, over the walk.
func walk_customize() -> void:
	if _camp.customize == null:
		return
	_camp.customize._open_from_camp()
	if _camp.customize.visible:
		_show("", Palette.AMBER, "")
		_sync_walk()
		_fade(true)


# Moss's bench at his stall. The panel refuses under an overlay, so the walk steps aside for the call.
func walk_companion() -> void:
	var workshop = game.workshop()
	_walking = false
	_camp.visible = false
	var opened: bool = workshop.open_companion()
	_walking = true
	_camp.visible = not opened
	_sync_walk()
	if not opened:
		game.hud.toast(CampMenu.NO_PIECES)


func _hook_companion() -> void:
	if _companion_hooked:
		return
	_companion_hooked = true
	game.workshop().companion_panel.closed.connect(_sync_walk)


func _close_camp_silently() -> void:
	# The camp's music ends with it, so a needle lifted below goes back to the title theme.
	var audio = _audio()
	if audio != null:
		audio.camp_theme(false)
	if _jukebox.visible:
		_close_jukebox()
	if _radio.visible:
		_radio.visible = false
	if _walking or not _camp.visible:
		return
	_camp.visible = false
	_actions.visible = true
	get_viewport().gui_release_focus()


# The summary's Camp: back to the title, with the camp open.
func open_camp_from_summary() -> void:
	game.flow.show_title()
	toggle_camp()


func camp_open() -> bool:
	return _walking or _camp.visible


# J on the camp swaps it for Moss's jukebox, and back. Leaving lifts the needle, so the
# title theme returns with the camp.
func toggle_jukebox() -> void:
	if _jukebox.visible:
		_close_jukebox()
		if _walking:
			_back_to_base()
			_fade(true)
			return
		_camp.visible = true
		_camp.refresh(game)
		_show("CAMP", Palette.AMBER, "")
		_camp.button_for("jukebox").grab_focus()
		_fade(true)
		return
	if not _camp.visible:
		return
	_camp.visible = false
	_jukebox.visible = true
	_refresh_jukebox()
	_show("MOSS'S JUKEBOX", Palette.AMBER, "")
	_jukebox.focus_first()
	_sync_walk()
	_fade(true)


func _close_jukebox() -> void:
	_jukebox.visible = false
	var audio = _audio()
	if audio != null:
		audio.stop_spin()


func jukebox_open() -> bool:
	return _jukebox.visible


func jukebox_page():
	return _jukebox


# The jukebox's keys, from game._screen_key while it is open: Space or Enter plays the
# focused sleeve (or stops the deck), 1 to 3 set the dial, J and Esc go back. Every other
# key is swallowed so the title's keys stay off the camp behind it.
func jukebox_key(key: int) -> bool:
	match key:
		KEY_J, KEY_ESCAPE:
			toggle_jukebox()
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			var id: String = _jukebox.focused_id()
			var audio = _audio()
			if audio != null and audio.spinning != "" and not _jukebox.is_found(id):
				id = audio.spinning
			_spin_toggle(id)
		KEY_1, KEY_2, KEY_3:
			var audio = _audio()
			if audio != null:
				audio.set_spin_detent(key - KEY_1)
			_refresh_jukebox()
	return true


# A found record goes on the deck; the record already playing comes off; a blank sleeve
# only shows its hint.
func _spin_toggle(id: String) -> void:
	var audio = _audio()
	if audio == null or id == "":
		return
	if audio.spinning == id:
		audio.stop_spin()
	elif _jukebox.is_found(id) and audio.spin(id):
		audio.play("bay_jukebox", 0.0, 1.0, "UI")
	_refresh_jukebox()


func _refresh_jukebox() -> void:
	var audio = _audio()
	var sitting: bool = game.tuning != null and game.tuning.sitting()
	_jukebox.refresh(game.ctx.profile, audio.spinning if audio != null else "", audio.spin_detent if audio != null else 2, sitting)


func _audio():
	return game.audio()


# R on the camp swaps it for the radio's mixtapes, and back. The radio keeps what was changed.
func toggle_radio() -> void:
	if _radio.visible:
		_radio.visible = false
		_save_radio()
		if _walking:
			_back_to_base()
			_fade(true)
			return
		_camp.visible = true
		_camp.refresh(game)
		_show("CAMP", Palette.AMBER, "")
		_camp.button_for("radio").grab_focus()
		_fade(true)
		return
	if not _camp.visible or game.get("radio_deck") == null:
		return
	_camp.visible = false
	_radio.visible = true
	_radio.refresh(game.ctx.profile, game.radio_deck.radio)
	_show("", Palette.AMBER, "")
	_radio.focus_first()
	_sync_walk()
	_fade(true)


func radio_open() -> bool:
	return _radio.visible


func radio_page():
	return _radio


# The mixtape keys, from game._screen_key while the page is open: Space or Enter takes the
# focused track on or off the tape, comma and period move a tape track, 1 to 6 pick a tape, N
# starts one, X shuffles, T tunes the radio to it, R and Esc go back. Every other key is
# swallowed so the title's keys stay off the camp behind it.
func radio_key(key: int) -> bool:
	var radio = game.radio_deck.radio
	var focused: String = _radio.focused_id()
	match key:
		KEY_R, KEY_ESCAPE:
			toggle_radio()
			return true
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			if focused != "":
				_radio_track(focused.substr(2), focused[0] == "t")
			return true
		KEY_COMMA, KEY_PERIOD:
			if focused.begins_with("t:"):
				radio.nudge(radio.mixtape, focused.substr(2), -1 if key == KEY_COMMA else 1)
		KEY_N:
			var made: int = radio.new_mixtape()
			if made >= 0:
				radio.mixtape = made
		KEY_X:
			var rng := RandomNumberGenerator.new()
			rng.randomize()
			radio.shuffle_mixtape(radio.mixtape, rng)
		KEY_T:
			radio.tune(radio.MIXTAPE)
		_:
			if key >= KEY_1 and key < KEY_1 + radio.mixtapes.size():
				radio.mixtape = key - KEY_1
			else:
				return true
	_radio.refresh(game.ctx.profile, radio)
	if focused != "":
		_radio.focus(focused[0] == "t", focused.substr(2))
	return true


func _radio_track(id: String, on_tape: bool) -> void:
	var radio = game.radio_deck.radio
	if on_tape:
		radio.remove_from(radio.mixtape, id)
	elif not radio.add_to(radio.mixtape, id):
		radio.remove_from(radio.mixtape, id)
	var audio = _audio()
	if audio != null:
		audio.play("flow_changed", 0.0, 1.0, "UI")
	_radio.refresh(game.ctx.profile, radio)
	_radio.focus(on_tape, id)


func _save_radio() -> void:
	if game.get("radio_deck") != null:
		game.radio_deck._save()


func camp_page():
	return _camp


func settings_open() -> bool:
	return _settings.visible


func settings_page():
	return _settings


func achievements_open() -> bool:
	return _achievements.visible


func achievements_page():
	return _achievements


# Pilot select opens on the first pilot the profile can take (w37 film PF-40), on arrival and when the prologue ends: an
# open card names each key's icon and the role, so the closed cards' icon rows read by example, and the arrows walk to a
# locked card's unlock words. The focus waits a frame, for the cards to be in the row.
func _open_first_pilot() -> void:
	for card in class_cards():
		if not card.locked:
			_focus_card.call_deferred(card)
			return


# A screen change in the same frame can take the card away first; a card no longer shown takes no focus.
func _focus_card(card: Control) -> void:
	if is_instance_valid(card) and card.is_inside_tree() and card.is_visible_in_tree() and get_viewport().gui_get_focus_owner() == null:
		card.grab_focus()


# The words on a locked pilot's card: the pilot's reward row text and lifetime count, then
# the row's beat, the one line of why.
func _unlock_hint(def) -> String:
	var hint := ClassCard.unlock_hint(def, game.progress)
	var beat := Achievements.beat_of(Achievements.for_pilot(def.id))
	return hint if hint == "" or beat == "" else "%s\n%s" % [hint, beat]


# With --dev and --music=ace the settings page's Breath button (B) cycles the Warden open's held
# breath and names what the next run plays; with the synth the button is hidden.
func refresh_lab_row() -> void:
	_breath_row.visible = _settings.visible and game.dev and game.tuning.option(Tuning.MUSIC_KEY) == "ace"
	_breath_row.text = "Breath %s" % game.tuning.option(Tuning.BREATH_KEY)


func overlay_open() -> bool:
	return _help.visible or _achievements.visible or _camp.visible or _walking or _jukebox.visible or _radio.visible or ending_open()


func ending_open() -> bool:
	return _ending.visible or (is_instance_valid(ending_sequence) and ending_sequence.active)


func start_ending_sequence() -> void:
	if is_instance_valid(ending_sequence):
		return
	_ending.visible = false
	_content.visible = false
	_veil.visible = false
	if game.hud != null:
		game.hud.clear_achievement_toasts()
	_ending_left = ENDING_HOLD
	ending_sequence = EndingSequence.new()
	add_child(ending_sequence)
	ending_sequence.finished.connect(_close_ending)
	ending_sequence.start(game, game.flow.lap_stats)


# The Q16 ending's first act: the crew's fly-over over the victory card, after which flow starts the victory lap.
func start_ending_prelude() -> void:
	if is_instance_valid(ending_sequence):
		return
	_content.visible = false
	_veil.visible = false
	if game.hud != null:
		game.hud.clear_achievement_toasts()
	_ending_left = ENDING_HOLD
	ending_sequence = EndingSequence.new()
	add_child(ending_sequence)
	ending_sequence.finished.connect(_close_prelude)
	ending_sequence.start(game, {}, true)


func _close_prelude() -> void:
	if is_instance_valid(ending_sequence):
		ending_sequence.queue_free()
		ending_sequence = null
	game.flow.start_lap()


# The summary's title, epitaph, stats and actions are built beneath and wait hidden.
func _open_ending() -> void:
	_ending_title.text = String(Worlds.ENDING["title"])
	_ending_title.add_theme_color_override("font_color", EventKinds.color("run_ended"))
	var ending_lines := PackedStringArray()
	for world_id in [1, 2, 3]:
		ending_lines.append_array(PackedStringArray(Worlds.ENDING["log"][world_id]))
	ending_lines.append_array(PackedStringArray(Worlds.ENDING["close"]))
	_ending_body.text = "\n".join(ending_lines) + "\n\n" + String(Worlds.ENDING["sign"])
	_ending.visible = true
	_ending_left = ENDING_HOLD
	for node in [_title, _body, _stats, _comic_row, _actions]:
		node.visible = false


# The summary beneath takes over with its input latch fresh, so the press that closed the page
# cannot also start a run.
func _close_ending() -> void:
	if is_instance_valid(ending_sequence):
		ending_sequence.queue_free()
		ending_sequence = null
	_content.visible = true
	_veil.visible = true
	_ending.visible = false
	_victory_boss = {}
	_title.visible = true
	_body.visible = _body.text != ""
	_stats.visible = true
	_comic_row.visible = true
	_actions.visible = true
	game.arm_summary_latch()
	_fade(true)
	_update_enabled()


func _ending_closes(event: InputEvent) -> bool:
	if event is InputEventJoypadButton:
		return event.pressed
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return false
	var key: int = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
	return key in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE]


func _input(event: InputEvent) -> void:
	# The launch take (launch_take.gd) owns input until the dam shows: Esc or pad Start must not leave the camp under it.
	if game.launch_take != null and game.launch_take.busy():
		get_viewport().set_input_as_handled()
		return
	if is_instance_valid(ending_sequence) and ending_sequence.active:
		ending_sequence.handle(event)
		get_viewport().set_input_as_handled()
		return
	if _ending.visible:
		if _ending_left <= 0.0 and _ending_closes(event):
			_close_ending()
			get_viewport().set_input_as_handled()
		return
	if prologue_showing():
		_prologue_input(event)
		return
	if is_instance_valid(_walk_page):
		if _backs(event):
			close_walk_page()
			get_viewport().set_input_as_handled()
		return
	if _settings.visible:
		if _settings.handle(event):
			get_viewport().set_input_as_handled()
		return
	if _radio.visible or _jukebox.visible:
		if _backs(event):
			if _radio.visible:
				toggle_radio()
			else:
				toggle_jukebox()
			get_viewport().set_input_as_handled()
		return
	if _camp.visible:
		# Pad B boosts in the walk; Start (the pause button elsewhere) leaves the camp. Esc leaves on keys.
		var start: bool = event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START
		if start or (_backs(event) and not (_walking and event is InputEventJoypadButton)):
			toggle_camp()
			get_viewport().set_input_as_handled()
		return
	if overlay_open() and event is InputEventJoypadButton and event.pressed:
		# A reaches Help's focused control; other accepts stay off the title behind it.
		if event.button_index == JOY_BUTTON_A and _help.visible:
			var focused := get_viewport().gui_get_focus_owner()
			if focused != null and _help.is_ancestor_of(focused):
				return
		if event.button_index == JOY_BUTTON_B:
			if _help.visible:
				toggle_help()
			else:
				toggle_achievements()
		if event.button_index == JOY_BUTTON_A or event.button_index == JOY_BUTTON_B:
			get_viewport().set_input_as_handled()
		return
	if _pad_enters_title(event):
		get_viewport().set_input_as_handled()
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var code: int = event.physical_keycode
	var quit := button_for("quit")
	if code == KEY_C and _state == "summary":
		if not game.workshop().companion_panel.is_open():
			_press("key_c")
	elif code == KEY_ESCAPE and (_help.visible or _achievements.visible):
		if _help.visible:
			toggle_help()
		else:
			toggle_achievements()
	elif code == KEY_ESCAPE and _state == "title" and quit != null:
		quit.grab_focus()
	elif code == KEY_ESCAPE and _state in ["class_select", "dead", "victory"]:
		if _state == "class_select":
			game.flow.show_title()
		elif _state == "dead":
			open_camp_from_summary()
	elif quit != null and quit.has_focus() and code in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		quit.pressed.emit()
	else:
		return
	get_viewport().set_input_as_handled()


# Esc or pad B, the keys every page's Back answers to.
func _backs(event: InputEvent) -> bool:
	if event is InputEventJoypadButton:
		return event.pressed and event.button_index == JOY_BUTTON_B
	return event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE


# On the title with nothing focused, a pad's d-pad or stick lands on the first button so A
# can press it. Pad events only: the keyboard's arrows keep doing what they did.
func _pad_enters_title(event: InputEvent) -> bool:
	if not (event is InputEventJoypadButton or event is InputEventJoypadMotion) or overlay_open():
		return false
	if game.flow.state_name() != "title" or get_viewport().gui_get_focus_owner() != null:
		return false
	for action in ["ui_down", "ui_up", "ui_left", "ui_right"]:
		if event.is_action_pressed(action):
			for child in _actions.get_children():
				if child is Button and child.focus_mode != Control.FOCUS_NONE:
					child.grab_focus()
					return true
	return false


func _show(title: String, color: Color, body: String) -> void:
	_title.text = title
	_title.visible = title != ""
	_title.add_theme_color_override("font_color", color)
	_body.text = body
	_body.visible = body != ""
	_balance(_body, BODY_WIDTH)


# A wrapped line breaks into lines of even length, never one long line over a lone tail: the label
# is as wide as half its words plus a margin, and never wider than the column.
func _balance(label: Label, widest: float) -> void:
	var font_size := label.get_theme_font_size("font_size")
	var whole := UiFonts.bold().get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var lines := ceili(whole / widest)
	label.custom_minimum_size.x = widest if lines <= 1 else minf(widest, whole / lines + font_size * 2.0)


func _action(id: String, key: String, words: String) -> void:
	var button := ChoiceButton.new(id, key, words)
	if id == "quit":
		button.pressed.connect(func(): if not game.test_mode: get_tree().quit())
	else:
		button.pressed.connect(_press.bind(key))
	if id == "start":
		_make_primary(button)
	else:
		_make_quiet(button)
	_actions.add_child(button)


# Every choice beside the primary one steps down a size: body words on a target-height plate, so
# the eye lands on the filled primary first and reads the rest as a row of ways out.
func _make_quiet(button: Button) -> void:
	button.add_theme_font_size_override("font_size", UiTokens.BODY)
	button.custom_minimum_size.y = UiTokens.TARGET
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER


# The filled amber plate, charcoal words and a taller, larger face; the unfilled focus ring
# stays so keyboard focus still reads.
func _make_primary(button: Button) -> void:
	var left := ChoiceButton.PAD + Keycap.size_of(button.key, ChoiceButton.KEY_H).x + ChoiceButton.PAD
	for state in ["normal", "hover", "pressed", "disabled"]:
		var box := ChoiceButton.plate(Palette.AMBER, 2, left)
		box.bg_color = Palette.AMBER.lightened(0.15) if state == "hover" else Palette.AMBER
		if state == "disabled":
			box.bg_color = Color(Palette.AMBER, 0.5)
		button.add_theme_stylebox_override(state, box)
	button.add_theme_stylebox_override("focus", UiTokens.focus_ring(left))
	for color in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(color, Palette.CHARCOAL)
	button.add_theme_font_size_override("font_size", PRIMARY_FONT)
	button.custom_minimum_size.y = PRIMARY_HEIGHT
	button.set_meta("primary", true)


# The death screen's, the summary's and the title's way into the companion screen
# (workshop.gd owns the M key); it is offered only when there is something to assemble.
func _companion_action() -> void:
	var button := ChoiceButton.new("companion", "key_m", "Companion")
	button.pressed.connect(func(): game.workshop().open_companion())
	_make_quiet(button)
	_actions.add_child(button)


# A button presses its key: the same route, the same guards, the same result. On the summary C (Choose
# pilot, as on the death screen) takes Space's route; Space is the jump, so it never wears the cap.
func _press(key: String) -> void:
	var code := OS.find_keycode_from_string(Keycap.label(key))
	game._screen_key(KEY_SPACE if _state == "summary" and code == KEY_C else code)


# The boss row of the world the run is in: on the victory screen, the world whose boss was
# just beaten. The summary reads the row the victory screen showed, so a run that ends with
# no boss beaten (a table with no boss, an unbuilt world) shows no epitaph.
func _beaten_boss() -> Dictionary:
	return game.flow.boss_row(game.ctx.stages.world_of(game.run.stage))


# The page folds at run_ended, after the summary has opened, so it arrives on its own row.
func _show_comic_page(page: Dictionary) -> void:
	if _state != "summary" or not ResourceLoader.exists(COMIC_PAGE_PATH):
		return
	var comic: Control = load(COMIC_PAGE_PATH).new()
	comic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_comic_row.add_child(comic)
	_comic_row.move_child(comic, 0)
	if is_instance_valid(_chase):
		_comic_row.move_child(_chase, 0)
	_fit_comic()
	comic.show_page(page)


# Sizes the summary's comic page to the body as it reads now. The page and a lost run's shift
# board line both arrive after the summary opens, in either order, so each asks again.
func _fit_comic() -> void:
	var comic := comic_page()
	if comic == null:
		return
	var height := comic_height(_screen().y, _body.get_line_count(), _body.get_line_height() + _body.get_theme_constant("line_spacing"))
	comic.custom_minimum_size = Vector2(height * 0.75, height)


# The comic page's height on the summary: half the screen, less a line's height for every body
# line past the COMIC_BODY_LINES the column holds with the page at full height, so a long
# summary (cause, epitaph, a two-line shift board) never pushes the buttons off the screen. It
# stops at COMIC_MIN_HEIGHT, under which the page is no longer a page (a --dev summary's odds lines).
static func comic_height(screen_h: float, body_lines: int, line_h: float) -> float:
	return maxf(COMIC_MIN_HEIGHT, minf(COMIC_MAX_HEIGHT, screen_h * COMIC_HEIGHT) - maxi(0, body_lines - COMIC_BODY_LINES) * line_h)


func comic_page() -> Control:
	for child in _comic_row.get_children():
		if child != _tip and child != _chase:
			return child
	return null


# The "next shift" note: its head in amber, the tip's words wrapped under it. It stands right of the
# comic page once that arrives, and alone in the row until then.
func _show_tip(tip: String) -> void:
	var plate := ScrapFrame.plate(Color(Palette.AMBER, 0.7), TIP_SERIAL, Color(Palette.CHARCOAL, 0.94), 2.0, 0.5)
	plate.content_margin_left = 16.0
	plate.content_margin_right = 16.0
	plate.content_margin_top = 16.0
	plate.content_margin_bottom = 14.0
	_tip = PanelContainer.new()
	_tip.add_theme_stylebox_override("panel", plate)
	_tip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.add_child(column)
	var head := _label(TIP_HEAD_FONT)
	head.text = DeathTips.HEAD.to_upper()
	head.add_theme_color_override("font_color", Palette.AMBER)
	column.add_child(head)
	var words := _label(TIP_FONT)
	words.text = tip
	words.add_theme_color_override("font_color", Palette.SAND)
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.custom_minimum_size.x = TIP_WIDTH
	column.add_child(words)
	_tip_said = DeathTips.shown(tip)
	_comic_row.add_child(_tip)


# What to chase next shift (chase_plate.gd): the shift board's next rung and the run's world's secrets,
# left of the comic page. The summary opens before run_ended reaches progress, which closes the shift
# (a first run's Clocked In stamps then), so the plate is drawn again once run_ended has gone round. The
# one-shot connection re-arms on each draw; outside the summary it does nothing.
func _show_chase() -> void:
	if is_instance_valid(_chase):
		_comic_row.remove_child(_chase)
		_chase.queue_free()
	_chase = null
	var codex = game.ctx.get("codex")
	var sitting: bool = game.tuning != null and game.tuning.sitting()
	var read := ChasePlate.reading(game.ctx.profile, game.ctx.stages.world_of(game.run.stage),
		func(id): return codex != null and codex.known(id), sitting)
	if ChasePlate.shows(read):
		_chase = ChasePlate.new(read)
		_comic_row.add_child(_chase)
		_comic_row.move_child(_chase, 0)
	if not game.events.run_ended.is_connected(_on_run_ended_chase):
		game.events.run_ended.connect(_on_run_ended_chase, CONNECT_ONE_SHOT | CONNECT_DEFERRED)


func _on_run_ended_chase(_won: bool) -> void:
	if _state == "summary":
		_show_chase()


# The chase plate as it reads (ChasePlate.said); "" when the screen has none.
func chase_text() -> String:
	return _chase.text() if is_instance_valid(_chase) and _chase.visible else ""


# What the run did to the shift board (progress.gd board_line). A lost run's summary is built before
# run_ended reaches progress, so the line is added once progress has closed the shift.
func _board_line() -> String:
	var progress = game.get("progress")
	if progress == null:
		return ""
	if String(progress.board_line) == "" and not game.events.run_ended.is_connected(_on_run_ended_board):
		game.events.run_ended.connect(_on_run_ended_board, CONNECT_ONE_SHOT | CONNECT_DEFERRED)
	return String(progress.board_line)


func _on_run_ended_board(_won: bool) -> void:
	var progress = game.get("progress")
	if _state != "summary" or progress == null or String(progress.board_line) == "":
		return
	if not _body.text.contains(String(progress.board_line)):
		_body.text += "\n" + String(progress.board_line)
		_fit_comic()


# The summary as icons and numbers, each with its word and what becomes of it (summary_rows.gd).
static func summary_chips(s: Dictionary, stage_count: int) -> Array:
	return SummaryRows.rows(s, stage_count)


func _summary_stats() -> void:
	for block in SummaryRows.grouped(summary_chips(game.run.summary(), game.ctx.stages.COUNT)):
		var group := VBoxContainer.new()
		group.add_theme_constant_override("separation", 4)
		group.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if block[0] != "":
			var head := _label(STAT_WORD_FONT)
			head.text = block[0]
			head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			head.add_theme_color_override("font_color", Palette.AMBER)
			group.add_child(head)
		var cells := _row(UiTokens.GAP_XL)
		for chip in block[1]:
			cells.add_child(_stat_cell(chip))
		group.add_child(cells)
		_stats.add_child(group)


func _stat_cell(chip: Array) -> VBoxContainer:
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", 0)
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := _row(8)
	var icon := TextureRect.new()
	icon.texture = Icons.texture(chip[0])
	icon.modulate = Icons.tint(chip[0], Palette.SAND)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(30.0, 30.0)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var value := _label(UiTokens.LABEL)
	value.add_theme_font_override("font", UiFonts.mono())
	value.text = chip[1]
	row.add_child(value)
	cell.add_child(row)
	var word := _label(STAT_WORD_FONT)
	word.text = String(chip[2]).to_upper()
	word.add_theme_color_override("font_color", Color(Palette.SAND, 0.7))
	cell.add_child(word)
	return cell


func _stamp(target: Label = null) -> void:
	if target == null:
		target = _title
	if game.camera != null and game.camera.reduced_motion:
		return
	_stamp_tween = create_tween()
	_stamp_tween.tween_callback(func():
		target.pivot_offset = target.size / 2.0
		target.scale = Vector2.ONE * STAMP_FROM
		target.rotation = deg_to_rad(STAMP_TILT))
	_stamp_tween.set_parallel(true)
	_stamp_tween.tween_property(target, "scale", Vector2.ONE, STAMP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_stamp_tween.tween_property(target, "rotation", 0.0, STAMP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# The release-candidate gate launches the AppImage on a fresh profile and waits for this one
# line, printed the first time the main menu shows in this process. After ms it names the launch
# set and how many pilots the title opens, so a cold launch shows the unlock ladder (P-R21: 1 on a
# fresh profile) or the sitting (all six).
static var _ready_announced := false


func _announce_ready() -> void:
	if _ready_announced:
		return
	_ready_announced = true
	print(ready_line(Time.get_ticks_msec()))


func ready_line(ms: int) -> String:
	var open: int = game.flow.classes.filter(func(def): return game.pilot_unlocked(def)).size()
	var launch_set: String = game.tuning.option("profile") if game.tuning != null else "default"
	return "SCRAPKEEP_MENU_READY ms=%d profile=%s pilots=%d/%d" % [ms, launch_set, open, game.flow.classes.size()]


func _unstamp() -> void:
	if _stamp_tween != null:
		_stamp_tween.kill()
		_stamp_tween = null
	for label in [_title, _mark]:
		label.scale = Vector2.ONE
		label.rotation = 0.0


func _fade(show: bool) -> void:
	_layout_backdrop()
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	if show:
		visible = true
		_content.modulate.a = 0.0
		_content.position.y = SLIDE
		_tween.tween_property(_veil, "modulate:a", 1.0, FADE_IN).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tween.tween_property(_content, "modulate:a", 1.0, FADE_IN).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tween.tween_property(_content, "position:y", 0.0, FADE_IN).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		return
	_tween.tween_property(_veil, "modulate:a", 0.0, FADE_OUT).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.tween_property(_content, "modulate:a", 0.0, FADE_OUT).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.chain().tween_callback(func():
		if not game.flow.state_name() in MENU_STATES:
			visible = false)


func _layout_backdrop() -> void:
	var title_deck: bool = _state == "title" and not (_help.visible or _achievements.visible or _settings.visible or _camp.visible or _walking or _jukebox.visible or _radio.visible)
	_veil.anchor_bottom = 0.5 if title_deck else 1.0
	_content.anchor_bottom = _veil.anchor_bottom
	_content.add_theme_constant_override("separation", 18 if title_deck else 26)
	_veil.color = Color(Palette.CHARCOAL, 1.0 if title_deck else 0.84)


# The actions wrap at the room's width: the first row fills it, the rest centre below.
func _fit_actions() -> void:
	_actions.custom_minimum_size.x = minf(_screen().x, NARROW_W) - 2.0 * SIDE


func _screen() -> Vector2:
	return get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(1600.0, 900.0)


func _process(delta: float) -> void:
	_guard = maxf(0.0, _guard - delta)
	_step_veil_wait(delta)
	_step_still_wait()
	if ending_open():
		_ending_left = maxf(0.0, _ending_left - delta)
		if game.bot_driven and _ending_left <= 0.0:
			if is_instance_valid(ending_sequence):
				ending_sequence.skip()
			else:
				_close_ending()
	_step_latch_cue(delta)
	_update_enabled()


# Buttons take clicks only on a live screen, after its guard, and never while the
# summary still holds its keys (game.summary_shut()).
func _update_enabled() -> void:
	var live := _state in MENU_STATES and _state != "victory" and _guard <= 0.0
	if _state == "summary" and game != null and game.summary_shut():
		live = false
	for row in [_choices, _actions]:
		for child in row.get_children():
			(child as BaseButton).disabled = not live
	_refusal.visible = _state == "title" and _actions.visible and _refusal.text != ""


# The latch cue's clock and words. A press the latch turned away (game._screen_key) shows it at once.
func _step_latch_cue(delta: float) -> void:
	var latched: bool = _state == "summary" and game.summary_latched and not ending_open()
	_latch_held = _latch_held + delta if latched else 0.0
	var glyph: String = game.held_glyph() if latched and _latch_held >= LATCH_CUE_AFTER else ""
	if glyph != _latch_glyph:
		_latch_glyph = glyph
		_latch_cue.setup(latch_cue_parts(glyph))
	_latch_cue.visible = glyph != ""
	_actions.modulate.a = LATCH_DIM if _latch_cue.visible else 1.0
	if _latch_cue.visible:
		var cue_size: Vector2 = _latch_cue.custom_minimum_size
		_latch_cue.size = cue_size
		_latch_cue.position = _actions.global_position + (_actions.size - cue_size) * 0.5


func latch_pressed() -> void:
	_latch_held = maxf(_latch_held, LATCH_CUE_AFTER)


# The cue's words for a held input's cap id: "Let go of [W] to continue", or without the cap when the
# input has none to draw.
static func latch_cue_parts(glyph: String) -> Array:
	if glyph == "":
		return []
	if not (glyph.begins_with("key_") or glyph.begins_with("pad_")):
		return [{"say": "Let go to continue"}]
	return [{"say": "Let go of"}, {"cap": glyph, "say": Keycap.label(glyph)}, {"say": "to continue"}]


# What the latch cue says now, "" while it is down.
func latch_cue_text() -> String:
	return _latch_cue.text() if _latch_cue.visible else ""


# The note as it reads, "Next shift: ..."; "" when the screen has none.
func tip_text() -> String:
	return _tip_said if is_instance_valid(_tip) and _tip.visible else ""


func button_for(action: String) -> Button:
	if action == "back":
		if _settings.visible:
			return _settings.back
		if _camp.visible:
			return _camp.back
		if _jukebox.visible:
			return _jukebox.back
		if _radio.visible:
			return _radio.back
		return _achievements.back if _achievements.visible else _help.back
	if action == "breath":
		return _breath_row if _breath_row.visible else null
	for child in _actions.get_children():
		if child.action == action:
			return child
	return null


func class_cards() -> Array:
	return _choices.get_children()


# Every card's name, role and fantasy line take the row's tallest, so a line that wraps on one
# card does not push that card's text rows below the others'.
func _level_text(row: Array) -> void:
	for pick in [func(c): return c.name_label(), func(c): return c.role_label(), func(c): return c.fantasy_label()]:
		var tallest := 0.0
		for card in row:
			tallest = maxf(tallest, pick.call(card).get_combined_minimum_size().y)
		for card in row:
			pick.call(card).custom_minimum_size.y = tallest


# The cards' wrapped words measure true only once laid out, so the row levels on a later frame.
# A fresh request restarts the count, so a row rebuilt mid-wait gets its full wait.
func _queue_level() -> void:
	_level_tries = LEVEL_TRIES
	if not get_tree().process_frame.is_connected(_level_cards):
		get_tree().process_frame.connect(_level_cards)


# Every card in the row gives its preview the row's largest overflow, so every key row ends
# inside its card on the same bottom edge. The containers sort after a physics tick or at the
# end of the frame, so on a frame with no tick the next frame signal comes before the cards'
# first sort: the row waits for it frame by frame, and a row that never lays out (hidden under
# the prologue) keeps its built heights until the next request.
func _level_cards() -> void:
	var row := class_cards()
	var ready: bool = not row.is_empty() and row.all(func(c): return c.laid_out())
	_level_tries -= 1
	if not ready and _level_tries > 0:
		return
	get_tree().process_frame.disconnect(_level_cards)
	if not ready:
		return
	_level_text(row)
	var spill: float = row.reduce(func(m, c): return maxf(m, c.overflow()), 0.0)
	for card in row:
		card.shrink_preview(spill)


# The screen as a player reads it: the body, then each choice as its key and words.
func body_text() -> String:
	var lines := PackedStringArray()
	if _body.text != "":
		lines.append(_body.text)
		if tip_text() != "":
			lines.append(tip_text())
		lines.append("")
	for card in _choices.get_children():
		lines.append("%s   %s" % [Keycap.label(card.key), card.words().to_lower()])
	for button in _actions.get_children():
		lines.append("%s   %s" % [Keycap.label(button.key), button.text.to_lower()])
	if refusal_text() != "":
		lines.append("")
		lines.append(refusal_text())
	return "\n".join(lines)
