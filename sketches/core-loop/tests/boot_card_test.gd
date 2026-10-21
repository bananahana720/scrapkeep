extends SceneTree

# The 2D title card (src/boot/boot.gd; Andrew, 18 Oct, launch screen option A). Frame-driven, on a
# headless display, with the card forced on (force_card). Checked: the card is interactive before
# the game exists; it loads unpaced (no vsync, LOAD_FPS) and the hand-off puts the project's pacing
# back; the game hands off and the 3D title's MENU_READY follows; a Start picked while
# loading is honoured once the game is up; a close request mid-load waits for the load; and the
# synchronous path (what a headless launch, a test or a bot takes) leaves no card and no errors at
# quit on the main scene's 300-frame boot.

const T := preload("res://tests/support/t.gd")
const Screens := preload("res://src/ui/screens.gd")
const BOOT_SCENE := "res://src/boot/boot.tscn"
const FRAMES_MAX := 4000

var _t := T.new("boot_card_test")
var _interactive_before_game := false
var _interactive_ms := -1


func _initialize() -> void:
	_run.call_deferred()


func _card(force_card := true):
	var boot = load(BOOT_SCENE).instantiate()
	boot.force_card = force_card
	_interactive_before_game = false
	boot.title_interactive.connect(func(ms: int):
		_interactive_ms = ms
		_interactive_before_game = root.get_node_or_null("Game") == null)
	root.add_child(boot)
	return boot


func _wait_for_game() -> Node:
	var frames := 0
	while root.get_node_or_null("Game") == null and frames < FRAMES_MAX:
		await process_frame
		frames += 1
	return root.get_node_or_null("Game")


func _run() -> void:
	# 1. The card takes input before the game exists; an early Start is held, then honoured.
	_t.check("the 3D title has not announced itself yet", not Screens._ready_announced)
	var max_fps := Engine.max_fps
	var boot = _card()
	_t.check("the card loads unpaced: no vsync, the frame cap at LOAD_FPS", Engine.max_fps == boot.LOAD_FPS and int(boot._paced.get("max_fps", -1)) == max_fps, "max_fps %d" % Engine.max_fps)
	boot._play.pressed.emit()
	await process_frame
	await process_frame
	_t.check("the card prints TITLE_INTERACTIVE before the game exists", _interactive_ms >= 0 and _interactive_before_game, str(_interactive_ms))
	_t.check("an early Start shows the loading state", boot._status.text == "Loading" and boot._start_wanted)
	var game = await _wait_for_game()
	_t.check("the game hands off as /root/Game and is the current scene", game != null and current_scene == game)
	if game == null:
		quit(_t.verdict())
		return
	_t.check("MENU_READY follows the hand-off", Screens._ready_announced)
	_t.check("the hand-off puts the project's vsync and frame cap back", Engine.max_fps == max_fps and boot._paced.is_empty(), "max_fps %d" % Engine.max_fps)
	_t.check("the early Start is honoured after the load", game.flow.state_name() == "class_select", game.flow.state_name())
	_t.check("the card stopped taking input at the hand-off", boot._card.mouse_filter == Control.MOUSE_FILTER_IGNORE and not boot._play.has_focus())
	var frames := 0
	while is_instance_valid(boot) and frames < FRAMES_MAX:
		await process_frame
		frames += 1
	_t.check("the card fades and the boot scene is freed", not is_instance_valid(boot), "%d frames" % frames)
	game.free()
	await process_frame

	# 1b. After the hand-off, while the card still fades: it is click-through, and a Play that lands starts.
	var late_boot = _card()
	var seen = await _wait_for_game()
	var fading_game = seen
	var blocking := []
	var stack := [late_boot._card]
	while not stack.is_empty():
		var node = stack.pop_back()
		if node is Control and node.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			blocking.append(node.name)
		stack.append_array(node.get_children())
	_t.check("after the hand-off every control on the card lets clicks through", is_instance_valid(late_boot) and blocking.is_empty(), str(blocking))
	_t.check("the title is up and waiting under the fading card", fading_game != null and fading_game.flow.state_name() == "title")
	late_boot._play.pressed.emit()
	_t.check("a Play after the hand-off starts the run", fading_game.flow.state_name() == "class_select", fading_game.flow.state_name())
	frames = 0
	while is_instance_valid(late_boot) and frames < FRAMES_MAX:
		await process_frame
		frames += 1
	fading_game.free()
	await process_frame

	# 2. The synchronous path: headless without the card flag builds the game in place.
	var plain = _card(false)
	var printed := _interactive_ms
	var built = await _wait_for_game()
	_t.check("headless takes the synchronous path: the game is in place", built != null and _interactive_ms == printed)
	_t.check("the game is a played game at the title", built != null and built.flow.state_name() == "title" and not built.test_mode)
	await process_frame
	_t.check("the boot scene is gone", not is_instance_valid(plain))
	built.free()
	await process_frame

	# 3. No errors at quit: the main scene's 300-frame boot in its own process.
	var out := []
	var code := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--quit-after", "300"], out, true)
	var text := "\n".join(out)
	var bad := RegEx.create_from_string("(?m)^(SCRIPT ERROR|ERROR)")
	_t.check("the 300-frame boot of the main scene exits clean", code == 0 and bad.search(text) == null, "exit %d %s" % [code, text.substr(0, 400)])

	# 4. A close request mid-load waits for the load, a frame at a time.
	var closes := []
	var closing = load(BOOT_SCENE).instantiate()
	closing.force_card = true
	closing.close_handler = func(): closes.append(root.get_node_or_null("Game") != null)
	root.add_child(closing)
	closing.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	_t.check("a close request mid-load is held, not carried out", closing._closing and closes.is_empty() and root.get_node_or_null("Game") == null)
	var late = await _wait_for_game()
	await process_frame
	_t.check("the close is carried out once the load is done", late != null and closes == [true], str(closes))
	quit(_t.verdict())
