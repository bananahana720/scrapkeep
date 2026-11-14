extends Node

# The project's first scene (Andrew, 18 Oct, launch screen option A): a 2D title card that takes
# input within about 2 s while the game (main.tscn, the 3D park title) loads behind it. It keeps
# to the engine's own classes and one font: no preload of game.gd or anything heavy, so it is up
# before the script load that costs most of a cold boot.
#
# The game loads with ONE ResourceLoader.load_threaded_request, polled once per process_frame and
# never waited on. No script is requested on its own: the preload cycles (combat, player_ball,
# rivet_kit) deadlock when loaded on separate threads. When it has loaded, the game is added to the
# root as /root/Game under the card, its 3D title comes up, and the card fades out over FADE_S.
# A Start picked while loading shows "Loading" and is pressed on the real title once it is up.
#
# Tests, bots and every headless run take the old synchronous path: a headless display server
# (the sketch tests, sketch:fast's 300-frame boot of the main scene, bots) loads and builds the
# game in place, since a quit in the middle of a threaded load logs script errors for every script
# it was reading. --boot-card forces the card there (the cloud boot measure); --boot-sync forces the
# synchronous path anywhere. A test sets force_card / force_sync before adding this scene.
#
# A build whose game does not load says so and leaves (_broken): main.tscn still loads when game.gd,
# or anything it preloads, does not, and its root then comes up as a bare node. Without the check the
# card fades onto an empty window that never answers. A test points game_scene at a stand-in.
#
# Every launch prints the build stamp once (build_stamp.gd, SCRAPKEEP_BUILD), and the card shows it
# in its bottom right corner. The stamp script preloads nothing, so it costs the card no load.

# The one headless question (src/core/app_shell.gd). It reads engine classes only and preloads
# nothing, so the card stays as light as the note above asks.
const AppShell := preload("res://src/core/app_shell.gd")
const BuildStamp := preload("res://src/core/build_stamp.gd")
# The drawn name (src/ui/wordmark.gd preloads nothing), so the card stamps the same name as the title.
const Wordmark := preload("res://src/ui/wordmark.gd")
const WORDMARK_H := 132.0
const GAME_SCENE := "res://main.tscn"
const FONT_PATH := "res://assets/fonts/NotoSans-Bold.ttf"
# Palette.CHARCOAL and Palette.AMBER, copied: palette.gd pulls the material table with it.
const CHARCOAL := Color("242a28")
const AMBER := Color("e5a044")
const FADE_S := 0.7
# The fade waits for stage 1's ground behind the menu, at most this long, so the 3D park title is
# what the card fades onto.
const GROUND_WAIT_S := 1.5
# A loader-thread call into the RenderingServer that returns a value is thought to wait for the main
# thread's next frame, and at vsync a frame waits for the display (up to 16.7 ms a call). The card is one
# flat panel, so while the game loads it draws without vsync, capped at LOAD_FPS, and the project's
# vsync and frame cap come back at the hand-off, before the game's own setup runs. The 4080 read
# cold menu-ready at 7.8 to 8.3 s before the card and 9.6 to 10.2 s with it (scrapkeep#241).
const LOAD_FPS := 480

signal title_interactive(ms: int)
signal handed_off(game: Node)

var force_card := false
var force_sync := false
var close_handler := Callable()
var game_scene := GAME_SCENE

var _card: Control
var _play: Button
var _status: Label
var _loading := false
var _game: Node
var _start_wanted := false
var _closing := false
var _failed := false
var _ground_wait := 0.0
var _fade_started := false
# The window's vsync mode and Engine.max_fps from before the load, put back at the hand-off.
var _paced := {}


func _ready() -> void:
	name = "Boot"
	# The card fades over a paused tree too: Continue opens the kit pick, which pauses, and a card
	# that paused with it would stay over the screen for good.
	process_mode = Node.PROCESS_MODE_ALWAYS
	print(BuildStamp.line())
	if _use_card():
		# A close request in the middle of the load waits for it (_notification, _poll).
		get_tree().auto_accept_quit = false
		_build_card()
		_boot("boot_card")
		_unpace()
		ResourceLoader.load_threaded_request(game_scene, "", false)
		_loading = true
		_announce_interactive.call_deferred()
	else:
		_build_in_place.call_deferred()


func _use_card() -> bool:
	if force_sync or _flag("--boot-sync"):
		return false
	if force_card or _flag("--boot-card"):
		return true
	return not AppShell.headless()


static func _flag(flag: String) -> bool:
	return flag in OS.get_cmdline_args() or flag in OS.get_cmdline_user_args()


# The synchronous path: the old main scene, built in place, /root/Game, the boot scene gone.
func _build_in_place() -> void:
	_add_game(load(game_scene))
	if not _failed:
		queue_free()


func _process(delta: float) -> void:
	if _game == null:
		if _loading:
			_poll()
		return
	_step_fade(delta)


func _poll() -> void:
	match ResourceLoader.load_threaded_get_status(game_scene):
		ResourceLoader.THREAD_LOAD_LOADED:
			_loading = false
			_boot("boot_loaded")
			_add_game(ResourceLoader.load_threaded_get(game_scene))
			if _closing:
				_quit()
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			pass
		_:
			_loading = false
			push_warning("boot: threaded load of %s failed; loading it in place" % game_scene)
			_add_game(load(game_scene))
			if _closing:
				_quit()


func _unpace() -> void:
	_paced = {"vsync": DisplayServer.window_get_vsync_mode(), "max_fps": Engine.max_fps}
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = LOAD_FPS


func _repace() -> void:
	if _paced.is_empty():
		return
	DisplayServer.window_set_vsync_mode(_paced["vsync"])
	Engine.max_fps = _paced["max_fps"]
	_paced = {}


func _add_game(scene: PackedScene) -> void:
	_repace()
	if scene == null:
		_broken("%s did not load" % game_scene)
		return
	_game = scene.instantiate()
	if _game.get_script() == null:
		_game.free()
		_game = null
		_broken("the game script of %s did not load" % game_scene)
		return
	# The game builds its title stage inside add_child (_ready), and that stage queues the opening
	# at once, so the hold is a meta read in TitleStage.setup: set before the game enters the tree.
	# Only a card holds; the in-place path leaves it unset and the opening runs as ever.
	if _card != null:
		_game.set_meta(&"intro_hold", true)
	var tree := get_tree()
	tree.root.add_child(_game)
	tree.current_scene = _game
	get_tree().auto_accept_quit = true
	handed_off.emit(_game)
	if _start_wanted and _game.flow != null:
		_game.flow.press_start()
	_hand_over_input()


# A build that cannot start. With no card (a headless launch, a test, a bot) it exits at once with
# code 1. With the card up the player is told, Play becomes Quit, and the exit code is 1 however
# they leave (the card still owns the window's close, _notification). SCRAPKEEP_BOOT_FAILED marks
# the failure in the log. The exit with no card does not pass through close_handler: there is no
# close to watch, and a broken build must never stay up.
func _broken(why: String) -> void:
	_failed = true
	push_error("boot: %s" % why)
	print("SCRAPKEEP_BOOT_FAILED %s" % why)
	if _card == null:
		get_tree().quit(1)
		return
	_status.text = "This build did not load. Quit, then install it again."
	_play.text = "Quit"
	_play.disabled = false
	_play.focus_mode = Control.FOCUS_ALL
	_play.grab_focus()


# The card stops taking input the moment the game is up; a keyboard or pad focus on it goes to the
# real title's first entry, so one press never reaches both.
func _hand_over_input() -> void:
	if _card == null:
		return
	var had_focus := _play.has_focus()
	_ignore_mouse(_card)
	_play.focus_mode = Control.FOCUS_NONE
	_play.release_focus()
	if had_focus and _game.get("screens") != null and _game.flow.state_name() == "title":
		var start = _game.screens.button_for("start")
		if start != null:
			start.grab_focus()


# MOUSE_FILTER_IGNORE does not cascade: every control on the card lets clicks through to the title.
func _ignore_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)


func _step_fade(delta: float) -> void:
	if _card == null or _fade_started:
		return
	# A hitch must not shorten the wait: no frame counts for more than 1/30 s.
	_ground_wait += minf(delta, 1.0 / 30.0)
	var terrain = _game.ctx.terrain if _game.get("ctx") != null else null
	var ground_up: bool = terrain == null or terrain.is_ready(1) or _game.flow.state_name() != "title"
	if not ground_up and _ground_wait < GROUND_WAIT_S:
		return
	_fade_started = true
	var tween := create_tween()
	tween.tween_property(_card, "modulate:a", 0.0, FADE_S)
	tween.finished.connect(_fade_done)


# The card is gone from the player's eye: the 3D title's opening may now play (title_stage.gd).
func _fade_done() -> void:
	_release_intro()
	queue_free()


# _exit_tree only clears the hold (play=false): a card freed early or a quit mid-fade must not start
# an opening that was never seen, which would mark it shown and save the profile.
func _release_intro(play := true) -> void:
	if _game == null or not is_instance_valid(_game):
		return
	_game.remove_meta(&"intro_hold")
	var presentation = _game.get("presentation")
	var stage = presentation.get("title_stage") if presentation != null else null
	if stage == null or not is_instance_valid(stage):
		return
	if play:
		stage.release_intro()
	else:
		stage.intro_hold = false


func _exit_tree() -> void:
	_repace()
	_release_intro(false)


# A test sets close_handler to see the close without ending its process.
func _quit() -> void:
	if close_handler.is_valid():
		close_handler.call()
	else:
		get_tree().quit(1 if _failed else 0)


func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_CLOSE_REQUEST:
		return
	# A close in the middle of the threaded load waits for it, a frame at a time (_poll).
	if _loading:
		_closing = true
	else:
		_quit()


# The card takes input from its first drawn frame; the line is for the release gate.
func _announce_interactive() -> void:
	await get_tree().process_frame
	if not is_inside_tree():
		return
	if _play.focus_mode != Control.FOCUS_NONE:
		_play.grab_focus()
	var ms := Time.get_ticks_msec()
	print("SCRAPKEEP_TITLE_INTERACTIVE ms=%d" % ms)
	title_interactive.emit(ms)


func _on_play() -> void:
	if _failed:
		_quit()
		return
	if _game != null:
		# Past the hand-off the card is click-through; a Play that still lands (Enter on a held focus)
		# does what the real title's Play does.
		if _game.flow != null and _game.flow.state_name() == "title":
			_game.flow.press_start()
		return
	_start_wanted = true
	_status.text = "Loading"
	_play.disabled = true
	_play.focus_mode = Control.FOCUS_NONE


func _build_card() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 128
	add_child(layer)
	_card = Control.new()
	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_card)
	var back := ColorRect.new()
	back.color = CHARCOAL
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card.add_child(back)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 28)
	_card.add_child(box)
	var font: Font = load(FONT_PATH) if ResourceLoader.exists(FONT_PATH) else null
	# The engine splash's ball (assets/app), so the card continues it.
	var splash_path := "res://assets/app/scrapkeep_splash.png"
	if ResourceLoader.exists(splash_path):
		var splash := TextureRect.new()
		splash.texture = load(splash_path)
		splash.custom_minimum_size = Vector2(192.0, 192.0)
		splash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		splash.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		box.add_child(splash)
	var title := Label.new()
	title.text = "SCRAPKEEP"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", AMBER)
	# The drawn name (W1-47) when it loads; the plain word stays only as its fallback.
	if Wordmark.texture() != null:
		title.add_theme_color_override("font_color", Color.TRANSPARENT)
		title.custom_minimum_size = Vector2(WORDMARK_H * Wordmark.ASPECT, WORDMARK_H)
		Wordmark.dress(title)
	_play = Button.new()
	_play.text = "Play"
	_play.custom_minimum_size = Vector2(240.0, 56.0)
	_play.add_theme_font_size_override("font_size", 28)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", AMBER)
	if font != null:
		title.add_theme_font_override("font", font)
		_play.add_theme_font_override("font", font)
		_status.add_theme_font_override("font", font)
	for node in [title, _play, _status]:
		box.add_child(node)
	var stamp := Label.new()
	stamp.name = "BuildStamp"
	stamp.text = BuildStamp.label()
	stamp.add_theme_font_size_override("font_size", 14)
	stamp.add_theme_color_override("font_color", Color(AMBER, 0.6))
	stamp.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 16)
	stamp.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	stamp.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_card.add_child(stamp)
	_play.pressed.connect(_on_play)


func _boot(step: String) -> void:
	if _flag("--boot-profile"):
		print("SCRAPKEEP_BOOT %s ms=%d" % [step, Time.get_ticks_msec()])
