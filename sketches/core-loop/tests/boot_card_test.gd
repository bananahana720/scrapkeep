extends SceneTree

# The 2D title card (src/boot/boot.gd; Andrew, 18 Oct, launch screen option A). Frame-driven, on a
# headless display, with the card forced on (force_card). Checked: the card is interactive before
# the game exists; it loads unpaced (no vsync, LOAD_FPS) and the hand-off puts the project's pacing
# back before the game is added; the game hands off and the 3D title's MENU_READY follows; a Start picked while
# loading is honoured once the game is up; a close request mid-load waits for the load; and the
# synchronous path (what a headless launch, a test or a bot takes) leaves no card and no errors at
# quit on the main scene's 300-frame boot. A build whose game does not load says so and exits with
# code 1, with and without the card (tests/support/boot_broken_child.gd, one process a case).

const T := preload("res://tests/support/t.gd")
const TeardownNoise := preload("res://tests/support/teardown_noise.gd")
const TitleIntros := preload("res://src/presentation/title_intros.gd")
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
	# A headless window has no vsync to read, so the checks read the frame cap the card sets with it.
	var cap_at_game := []
	var on_added := func(node: Node):
		if node.name == "Game" and node.get_parent() == root:
			cap_at_game.append(Engine.max_fps)
	node_added.connect(on_added)
	var boot = _card()
	_t.check("the card loads unpaced: the frame cap at LOAD_FPS, the project's saved", Engine.max_fps == boot.LOAD_FPS and int(boot._paced.get("max_fps", -1)) == max_fps, "max_fps %d" % Engine.max_fps)
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
	node_added.disconnect(on_added)
	_t.check("the hand-off puts the project's pacing back before the game is added", cap_at_game == [max_fps] and Engine.max_fps == max_fps and boot._paced.is_empty(), "at the game %s, now %d" % [cap_at_game, Engine.max_fps])
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

	# 5. The opening waits for the card (title_stage.intro_hold, released when the card's fade ends).
	# A headless display never autoplays, so the stage's autoplay is switched on once the game is up;
	# the hold itself was set before the game entered the tree (checked at handed_off, which fires
	# after the stage's own setup and first show_flow).
	var held_at_handoff := []
	var hold_boot = _card()
	hold_boot.handed_off.connect(func(g: Node): held_at_handoff.append(g.presentation.title_stage.intro_hold))
	var hold_game = await _wait_for_game()
	var stage = hold_game.presentation.title_stage
	_t.check("the stage is held before the hand-off signal, ahead of any autoplay", held_at_handoff == [true], str(held_at_handoff))
	stage.intro_autoplay = true
	stage.show_flow("title")
	for i in 3:
		await process_frame
	_t.check("no opening plays while the card is up", is_instance_valid(hold_boot) and stage.intro_hold and not stage.intro_playing() and not stage._intro_tried)
	frames = 0
	while is_instance_valid(hold_boot) and frames < FRAMES_MAX:
		await process_frame
		frames += 1
	_t.check("the card is gone after its fade", not is_instance_valid(hold_boot), "%d frames" % frames)
	_t.check("the fade's end lifts the hold", not stage.intro_hold)
	await process_frame
	await process_frame
	_t.check("the opening plays after the fade", stage.intro_playing())
	var shown_after: bool = hold_game.ctx.profile.is_seen(TitleIntros.SEEN_PREFIX + "sable") or stage._intro_tried
	stage.intro.skip()
	await process_frame
	stage.show_flow("title")
	await process_frame
	await process_frame
	_t.check("a second return to the title does not replay the opening", shown_after and not stage.intro_playing())
	hold_game.free()
	await process_frame

	# 5d. A card freed before its fade ends leaves the opening untried and nothing marked shown.
	var early_boot = _card()
	var early_game = await _wait_for_game()
	var early_stage = early_game.presentation.title_stage
	early_stage.intro_autoplay = true
	var seen_before: bool = early_game.ctx.profile.is_seen(TitleIntros.SEEN_PREFIX + "sable")
	var gen_before: int = early_game.ctx.profile.generation()
	await process_frame
	await process_frame
	early_boot.free()
	for i in 4:
		await process_frame
	_t.check("an early-freed card clears the hold without starting the opening", not early_stage.intro_hold and not early_stage.intro_playing() and not early_stage._intro_tried)
	_t.check("and marks nothing shown nor writes the profile", early_game.ctx.profile.is_seen(TitleIntros.SEEN_PREFIX + "sable") == seen_before and early_game.ctx.profile.generation() == gen_before)
	early_game.free()
	await process_frame

	# 5a. The ordering trap: a hold set after the autoplay was queued still stops it until released.
	var late_game = load("res://main.tscn").instantiate()
	root.add_child(late_game)
	var late_stage = late_game.presentation.title_stage
	late_stage.intro_autoplay = true
	late_stage._intro_tried = false
	late_stage.show_flow("title")
	late_stage.intro_hold = true
	for i in 3:
		await process_frame
	_t.check("a hold set after show_flow queued the autoplay still stops it", not late_stage.intro_playing() and not late_stage._intro_tried)
	late_stage.release_intro()
	await process_frame
	await process_frame
	_t.check("release then plays it", late_stage.intro_playing())
	late_game.free()
	await process_frame

	# 5b. A Start pressed during the card: the run starts, no opening plays over it, the hold is released.
	var start_boot = _card()
	start_boot._play.pressed.emit()
	var start_game = await _wait_for_game()
	var start_stage = start_game.presentation.title_stage
	start_stage.intro_autoplay = true
	await process_frame
	_t.check("the early Start reached the class select with the stage held", start_game.flow.state_name() == "class_select" and start_stage.intro_hold)
	frames = 0
	while is_instance_valid(start_boot) and frames < FRAMES_MAX:
		await process_frame
		frames += 1
	await process_frame
	await process_frame
	_t.check("the hold is not stuck after the card", not start_stage.intro_hold)
	_t.check("no opening plays over the run start", not start_stage.intro_playing() and start_game.flow.state_name() == "class_select")
	start_game.flow.show_title()
	await process_frame
	await process_frame
	_t.check("a later return to the title is eligible again", start_stage.intro_playing())
	start_game.free()
	await process_frame

	# 5d. A paused tree under the card (Continue opens the kit pick, which pauses) does not freeze the fade.
	var paused_boot = _card()
	var paused_game = await _wait_for_game()
	paused = true
	frames = 0
	while is_instance_valid(paused_boot) and frames < FRAMES_MAX:
		await process_frame
		frames += 1
	_t.check("the card fades and frees with the tree paused", not is_instance_valid(paused_boot), "%d frames" % frames)
	paused = false
	paused_game.free()
	await process_frame

	# 5c. The no-card path never holds.
	var plain_boot = _card(false)
	var plain_game = await _wait_for_game()
	var plain_stage = plain_game.presentation.title_stage
	_t.check("the in-place path sets no hold", not plain_game.has_meta(&"intro_hold") and not plain_stage.intro_hold)
	plain_stage.intro_autoplay = true
	plain_stage.show_flow("title")
	await process_frame
	await process_frame
	_t.check("the in-place path's opening is eligible at once", plain_stage.intro_playing())
	plain_game.free()
	await process_frame

	# 3. No errors at quit: the main scene's 300-frame boot in its own process.
	var out := []
	var code := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--quit-after", "300"], out, true)
	var text := TeardownNoise.strip("\n".join(out))
	var bad := RegEx.create_from_string("(?m)^(SCRIPT ERROR|ERROR)")
	_t.check("the 300-frame boot of the main scene exits clean", code == 0 and bad.search(text) == null, "exit %d %s" % [code, text.substr(0, 400)])

	# 6. A build whose game does not load. Each case runs in its own process, because the boot's
	# answer is an error line and an exit code, and neither belongs in this test's own output.
	for mode in ["sync", "missing", "play", "close"]:
		var child_out := []
		var child_code := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/support/boot_broken_child.gd", "--", mode], child_out, true)
		var child_text := "\n".join(child_out)
		# The child's tail goes on one line: its ERROR line at a line start would fail this test's run.
		var child_tail := child_text.right(400).replace("\n", " | ")
		_t.check("a game that does not load (%s) ends the boot with code 1 and the failure line" % mode, child_code == 1 and child_text.contains("SCRAPKEEP_BOOT_FAILED"), "exit %d %s" % [child_code, child_tail])
		if mode in ["play", "close"]:
			_t.check("the card says so and offers Quit, with no game added (%s)" % mode, child_text.contains("BOOT_CHILD play=Quit disabled=false focus=true game=false status=This build did not load"), child_tail)

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
