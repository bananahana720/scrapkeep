extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const WordBudget := preload("res://src/core/word_budget.gd")
const SettingsStore := preload("res://src/ui/settings_store.gd")
const HelpPage := preload("res://src/ui/help_page.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const Push := preload("res://tests/workshop/push.gd")

# The pause menu, its settings and the title's help page (v2 W10), driven by real mouse
# and key events pushed into the viewport, with the workshop armed as in play. Screen
# keys go through game._screen_key, since game._input stands aside in test mode:
#   - Help on the title opens by click and by H, shows the goal and the key list within
#     the calm-screen budget, and closes by H, Esc and its Back button;
#   - P does nothing while the upgrade pick holds the tree, and the pick keeps its pause;
#   - P opens the menu paused with Resume focused, inside the budget;
#   - S/W move the focus, Enter takes Resume; in the Feel tab of Settings D/A step a focused volume;
#   - clicks on the Feel tab set effects on the segments and step it on the arrows, the mixer follows,
#     and settings.json keeps it and puts it back at launch;
#   - Field notes pins the notes until the next click; Resume by click unpauses;
#   - Esc opens and closes it, N asks and N again restarts the run at stage 1 (the ask's own
#     cases are death_summary_loop_test's);
#   - a pick that opens under the menu keeps the tree paused after Resume.

const CALM_BUDGET := 40
# The title's Help page is the key reference: 43 words since the skill bar (re-pinned 40 -> 43 on
# 2026-10-10, wave 13 unit B2, design-v3/SKILL-BAR.md section 5). Its controls diagram gains the
# pick keys 1, 2, 3 with "pick" and Q with "ultimate", and loses F and "special". The pause menu
# itself keeps CALM_BUDGET.
const HELP_BUDGET := 43
const SETTLE := 0.45

var _game
var _ws
var _menu
var _failures := 0
var _phase := "boot"
var _clock := 0.0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _next(phase: String) -> void:
	_phase = phase
	_clock = 0.0


func _words(node: Node, label: String) -> int:
	var seen: Dictionary = WordBudget.count(node)
	print("  %s words: %s" % [label, " | ".join(seen["items"].map(func(i): return "%s %d \"%s\"" % [i["node"], i["words"], i["text"]]))])
	return seen["hud"]


func _process(delta: float) -> bool:
	if _game.flow == null:
		return false
	_clock += delta
	if _clock < SETTLE and _phase != "boot":
		return false
	match _phase:
		"boot":
			_ws = _game.get_node("Workshop")
			_menu = _game.get_node("PauseMenu")
			_ws.armed = true
			_game.ctx.calm = true
			_game.player.source = Intent.Scripted.new()
			_next("help")
		"help":
			var prev_music = _game.tuning.option(Tuning.MUSIC_KEY)
			var prev_breath = _game.tuning.option(Tuning.BREATH_KEY)
			_game.tuning.set_option(Tuning.MUSIC_KEY, "ace")
			var b_ignored: bool = not _game.dev and not _game._screen_key(KEY_B) and _game.tuning.option(Tuning.BREATH_KEY) == prev_breath
			_game.tuning.set_option(Tuning.MUSIC_KEY, prev_music)
			_report("title B gated on dev", b_ignored, "non-dev title ignores B (breath %s)" % _game.tuning.option(Tuning.BREATH_KEY))
			var help_button: Button = _game.screens.button_for("help")
			Push.click(root, help_button)
			_next("help_open")
		"help_open":
			var opened: bool = _game.screens.help_open()
			var words := _words(_game.screens, "help page")
			var rows := HelpPage.key_rows().size()
			_report("help by click", opened and _game.flow.state_name() == "title" and words <= HELP_BUDGET and rows >= 8,
				"the Help click opened it %s, %d key rows, %d words (budget %d)" % [opened, rows, words, HELP_BUDGET])
			var handled: bool = _game._screen_key(KEY_H)
			var by_h: bool = handled and not _game.screens.help_open()
			_game._screen_key(KEY_H)
			var reopened: bool = _game.screens.help_open()
			Push.key(root, KEY_ESCAPE)
			var by_esc: bool = not _game.screens.help_open() and _game.flow.state_name() == "title"
			Push.click(root, _game.screens.button_for("help"))
			_next("help_back")
			_report("help keys", by_h and reopened and by_esc, "H closed %s, H reopened %s, Esc closed %s" % [by_h, reopened, by_esc])
		"help_back":
			Push.click(root, _game.screens.button_for("back"))
			_report("help back", not _game.screens.help_open() and _game.screens.button_for("start") != null,
				"Back's click leaves help open %s" % _game.screens.help_open())
			Push.click(root, _game.screens.button_for("start"))
			_next("class")
		"class":
			Push.click(root, _game.screens.class_cards()[0])
			_next("pick")
		"pick":
			var held: bool = _ws.pick.is_open() and paused
			Push.key(root, KEY_P)
			_report("P under the pick", held and not _menu.is_open() and paused and _ws.pick.is_open(),
				"pick open and paused %s; after P the menu is open %s, tree paused %s, pick open %s"
					% [held, _menu.is_open(), paused, _ws.pick.is_open()])
			Push.key(root, KEY_ESCAPE)
			_next("open")
		"open":
			var free: bool = not _ws.pick.is_open() and not paused and _game.flow.in_play()
			Push.key(root, KEY_P)
			_report("P opens", free and _menu.is_open() and paused and _game.pause_toggled() and _menu.focused_id() == "resume",
				"pick closed and play running %s; after P open %s, paused %s, focus %s" % [free, _menu.is_open(), paused, _menu.focused_id()])
			_next("keys")
		"keys":
			var words := _words(_menu, "pause menu")
			_report("pause word budget", words > 0 and words <= CALM_BUDGET, "%d words on the pause menu (budget %d)" % [words, CALM_BUDGET])
			var audio = _game.presentation.audio
			Push.key(root, KEY_S)
			var down: String = _menu.focused_id()
			Push.key(root, KEY_O)
			var page = _menu.settings_page()
			page.show_page(3)
			page.focus_first()
			var on_music: String = page.focused_id()
			var before: float = audio.volumes["Music"]
			Push.key(root, KEY_A)
			var lowered: float = audio.volumes["Music"]
			Push.key(root, KEY_D)
			var raised: float = audio.volumes["Music"]
			_report("keys focus and step", down == "restart" and on_music == "music" and is_equal_approx(lowered, before - 0.1)
					and is_equal_approx(raised, before) and page.row("music").steps_filled() == roundi(before * 10.0),
				"S focused %s, then Feel opened on %s; A took music %.2f to %.2f, D back to %.2f" % [down, on_music, before, lowered, raised])
			Push.key(root, KEY_ESCAPE)
			var back_on: String = _menu.focused_id()
			for i in 4:
				Push.key(root, KEY_W)
			var top: String = _menu.focused_id()
			Push.key(root, KEY_ENTER)
			_report("enter resumes", top == "resume" and not _menu.is_open() and not paused and not _game.pause_toggled(),
				"Esc left Settings on %s, W x4 focused %s; Enter left the menu open %s, paused %s" % [back_on, top, _menu.is_open(), paused])
			_next("mouse_open")
		"mouse_open":
			Push.key(root, KEY_P)
			Push.key(root, KEY_O)
			_menu.settings_page().show_page(3)
			_next("mouse")
		"mouse":
			var audio = _game.presentation.audio
			var effects: Control = _menu.settings_page().row("effects")
			var at: Vector2 = effects.get_global_rect().position
			_click_at(at + Vector2(effects.bar_rect().position.x + 2.5 * (effects.SEG_W + effects.SEG_GAP), effects.size.y * 0.5))
			var on_bar: float = audio.volumes["SFX"]
			_click_at(at + effects.up_rect().get_center())
			var stepped_up: float = audio.volumes["SFX"]
			_click_at(at + effects.down_rect().get_center())
			_click_at(at + effects.down_rect().get_center())
			var stepped_down: float = audio.volumes["SFX"]
			var saved := SettingsStore.new(_game.storage_dir)
			_report("mouse volume", is_equal_approx(on_bar, 0.3) and is_equal_approx(stepped_up, 0.4) and is_equal_approx(stepped_down, 0.2)
					and is_equal_approx(audio.volumes["UI"], 0.2) and is_equal_approx(float(saved.volumes.get("SFX", -1.0)), 0.2)
					and _menu.settings_page().focused_id() == "effects",
				"third segment set effects %.2f, up %.2f, down twice %.2f (UI bus %.2f); settings.json holds %s"
					% [on_bar, stepped_up, stepped_down, audio.volumes["UI"], saved.volumes])
			audio.set_volume("SFX", 1.0)
			_menu.apply_saved()
			_report("saved levels apply", is_equal_approx(audio.volumes["SFX"], 0.2),
				"with the mixer reset to 1.00, the saved settings put effects back at %.2f" % audio.volumes["SFX"])
			Push.key(root, KEY_ESCAPE)
			_next("mouse_notes")
		"mouse_notes":
			var resume: Button = _menu.row("resume")
			Push.hover(root, resume)
			var lit: bool = resume.is_hovered()
			Push.click(root, _menu.row("notes"))
			var pinned: bool = _menu.notes_pinned() and _game.notes_held() and paused
			_report("notes pinned", lit and pinned, "hover lit Resume %s; the Field notes click pinned the notes %s" % [lit, pinned])
			_next("notes")
		"notes":
			var hidden: bool = WordBudget.count(_menu)["hud"] == 0
			_click_at(Vector2(20.0, 20.0))
			var unpinned: bool = not _menu.notes_pinned() and not _game.notes_held() and _menu.is_open() and paused
			_report("notes unpin", hidden and unpinned, "the menu hid under the notes %s; a click put it back, still paused %s" % [hidden, unpinned])
			Push.key(root, KEY_TAB)
			var tab_pinned: bool = _menu.notes_pinned() and _game.notes_held() and paused
			_report("Tab pins notes from pause menu", tab_pinned, "Tab press+release pinned %s held %s paused %s" % [_menu.notes_pinned(), _game.notes_held(), paused])
			if _menu.notes_pinned():
				_click_at(Vector2(20.0, 20.0))
			_next("resume")
		"resume":
			Push.click(root, _menu.row("resume"))
			_report("click resumes", not _menu.is_open() and not paused, "after the Resume click open %s, paused %s" % [_menu.is_open(), paused])
			_next("esc")
		"esc":
			Push.key(root, KEY_ESCAPE)
			var opened: bool = _menu.is_open() and paused
			Push.key(root, KEY_ESCAPE)
			_report("esc toggles", opened and not _menu.is_open() and not paused, "Esc opened %s, Esc again closed %s" % [opened, not _menu.is_open()])
			_game.flow.enter_stage(2, _game.ctx.terrain.spawn_point(2), false)
			_next("restart")
		"restart":
			var was: int = _game.run.stage
			Push.key(root, KEY_P)
			Push.key(root, KEY_N)
			var asked: bool = _menu.armed() == "restart" and _game.run.stage == was and _menu.is_open()
			_menu.step_arm(_menu.ARM_GUARD)
			Push.key(root, KEY_N)
			_report("N asks, N again restarts", asked and was == 2 and _game.run.stage == 1 and _game.flow.in_play() and not _menu.is_open() and not paused,
				"from stage %d, the first N asked %s, the second put the run at stage %d, in play %s, paused %s" % [was, asked, _game.run.stage, _game.flow.in_play(), paused])
			_next("under")
		"under":
			if _ws.pick.is_open():
				Push.key(root, KEY_ESCAPE)
				return false
			Push.key(root, KEY_P)
			_game.player.tree.open_checkpoint()
			_next("under_pick")
		"under_pick":
			var both: bool = _menu.is_open() and _ws.pick.is_open()
			Push.click(root, _menu.row("resume"))
			_report("pick keeps its pause", both and not _menu.is_open() and _ws.pick.is_open() and paused and not _game.pause_toggled(),
				"menu and pick both open %s; after Resume the menu is open %s, the pick %s, tree paused %s"
					% [both, _menu.is_open(), _ws.pick.is_open(), paused])
			Push.key(root, KEY_ESCAPE)
			print("ui_pause_menu_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
			quit(0 if _failures == 0 else 1)
			return true
	return false


func _click_at(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	root.push_input(motion, true)
	for pressed in [true, false]:
		var button := InputEventMouseButton.new()
		button.button_index = MOUSE_BUTTON_LEFT
		button.pressed = pressed
		button.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		button.position = at
		button.global_position = at
		root.push_input(button, true)
