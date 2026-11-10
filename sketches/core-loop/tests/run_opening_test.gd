extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const LaunchTake := preload("res://src/presentation/launch_take.gd")
const Opening := preload("res://src/presentation/opening.gd")
const LaunchCard := preload("res://src/ui/launch_card.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const UiDraw := preload("res://src/ui/ui_draw.gd")
const T := preload("res://tests/support/t.gd")

# Ruling bw: a run's opening is said one voice at a time (src/presentation/opening.gd). A first
# stage used to put the stage card, the shift card, Moss's hello (under the shift card), a tip
# and an unlock plate up together, some of it under the launch take's panel.
#   B1     a run that does not come through a live launch take (a bot's, a test's) has no
#          opening: the cold open starts with the stage, and Moss's hello follows its words
#          as it follows any comic beat's (bubble_gives_way_test).
#   P1     without the take too, Moss holds his hello while a screen pauses the drop (the
#          briefing on a restart), and says it when the screen closes.
#   T1-T2  through the take, nothing of the title shows under its panel; the stage card and
#          the cold open start when the panel has gone.
#   M1-M2  Moss waits for a first run's cold open (the shift card sits where his bubble goes),
#          then says his hello.
#   U1-U2  an unlock plate waits for Moss and for PLATE_AFTER seconds of rolling.
#   O1     the turns came in order, each once.
#   X1     a screen that pauses the drop on the frame the take ends (the briefing) holds every
#          turn until it closes.
#   S1     the next run's cold open is the short form: Moss speaks as the panel clears.
#   W1     a Warden fight ends the opening and every voice still waiting hears its turn.
#   R1     a restart while the opening still holds everything goes straight in: the opening
#          ends without a word, and the new run's stage card, cold open and Moss start at once.
#   V1     an opening begun for a run the flow refused ends on the next frame.

const STEP := 1.0 / 30.0

var _t := T.new("run_opening_test")
var _game
var _turns: Array = []
var holding_stamp := false


func _initialize() -> void:
	# One physics tick a frame, as on an idle box: a loaded box otherwise packs several ticks into one
	# frame and the frame-paced checks drift (w33 gate, red only under load). The game just runs slower.
	Engine.max_physics_steps_per_frame = 1
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _bubble():
	return _game.get_node("Workshop").bubble


func _plate_up() -> bool:
	return _game.hud.corner_rects().any(func(r): return r["name"] == "plate")


func _moss_up() -> bool:
	return _bubble().visible and _bubble().text != ""


func _start_run() -> void:
	_game.flow.show_title()
	await _frames(2)
	_game.flow.press_start()
	await _frames(2)
	_game.flow.choose_class(0)
	_game.player.source = Intent.Scripted.new()


# Pilot select through the launch take, stepped by hand until the run has started under the panel.
func _take_run() -> void:
	var take = _game.launch_take
	_game.flow.show_title()
	await _frames(2)
	_game.presentation.flourish.stop_all()
	_game.hud.clear_achievement_toasts()
	# The last run's stage card may still be in its hold.
	_game.hud.launch_card.visible = false
	_game.flow.press_start()
	await _frames(2)
	_game._screen_key(KEY_1)
	take.set_process(false)
	while take.phase in [LaunchTake.WIND, LaunchTake.COVER]:
		take.advance(STEP)
		await process_frame
	_game.player.source = Intent.Scripted.new()


func _end_take() -> void:
	var take = _game.launch_take
	while take.busy():
		take.advance(STEP)
		await process_frame


func _run() -> void:
	while _game.flow == null:
		await process_frame
	await _frames(5)
	_game.ctx.calm = true
	_game.screens.prologue_enabled = false
	var flow = _game.flow
	var opening = _game.opening
	var flourish = _game.presentation.flourish
	var hud = _game.hud
	opening.turned.connect(func(voice: String): _turns.append(voice))

	# PF-08: the stage's name line keeps its contrast against the outline ink, in the card's own tint.
	var tint: Color = EventKinds.color("stage_entered")
	var ink := Color(0.0, 0.0, 0.0, 1.0)
	_t.check("C1 the stage name line is lightened and heavily outlined: contrast at least %.1f to 1" % LaunchCard.MIN_CONTRAST,
		LaunchCard.contrast(LaunchCard.word_colour(tint), ink) >= LaunchCard.MIN_CONTRAST and LaunchCard.TEXT_OUTLINE >= 10 and LaunchCard.FONT >= 32,
		"colour %s contrast %.1f (base tint %.1f), outline %d, size %d" % [LaunchCard.word_colour(tint).to_html(false), LaunchCard.contrast(LaunchCard.word_colour(tint), ink), LaunchCard.contrast(tint, ink), LaunchCard.TEXT_OUTLINE, LaunchCard.FONT])

	await _start_run()
	await _frames(3)
	var cold_open: bool = flourish.playing and flourish.id == "cold_open"
	var under_card: bool = _moss_up()
	# Stopped, not read to its end: a cold open read through is the short form from then on.
	flourish.stop_all()
	await _frames(3)
	_t.check("B1 a run that does not come through the take has no opening: the cold open starts with the stage and Moss's hello follows its words",
		not opening.live and cold_open and not under_card and _moss_up() and _turns.is_empty()
			and not opening.waits("title") and not opening.waits("plate"),
		"live %s, flourish %s, Moss under the card %s and after it %s, turns %s" % [opening.live, flourish.id, under_card, _moss_up(), _turns])

	flow.show_title()
	await _frames(2)
	flow.press_start()
	await _frames(2)
	flow.choose_class(0)
	paused = true
	_game.player.source = Intent.Scripted.new()
	await _frames(3)
	# The cold open's card would hold the hello too (B1), so it goes first and the bubble is
	# asked again: what holds the hello now is the pause alone.
	flourish.stop_all()
	_bubble()._process(0.0)
	var hushed: bool = flow.in_stage() and not opening.live and not _game.presentation.reading() and not _moss_up()
	paused = false
	_game.player.set_velocity_now(Vector3.ZERO)
	await _frames(3)
	_t.check("P1 without the take, Moss holds his hello while a screen pauses the drop", hushed and _moss_up(), "held %s, then Moss %s" % [hushed, _moss_up()])

	# A hand on the controls, through the launch take.
	_game.bot_driven = false
	var take = _game.launch_take
	take.force_live = true
	await _take_run()
	await _frames(3)
	_t.check("T1 under the take's panel the title has not begun", take.busy() and flow.in_stage() and opening.live and opening.turn() == ""
			and not flourish.playing and not hud.launch_card.showing() and not _moss_up(),
		"take busy %s, turn '%s', flourish %s, stage card %s" % [take.busy(), opening.turn(), flourish.playing, hud.launch_card.showing()])
	hud.take_found("Lights On, Late Set", "Moss's Back Room", "b-side")
	await _end_take()
	await _frames(3)
	_t.check("T2 the panel gone, the stage card and the cold open start", opening.turn() == "title" and flourish.playing and flourish.id == "cold_open"
			and not flourish.short and hud.launch_card.showing(),
		"turn '%s', flourish %s short %s, stage card %s" % [opening.turn(), flourish.id, flourish.short, hud.launch_card.showing()])
	_t.check("M1 Moss and the plate wait for a first run's cold open", opening.waits("moss") and not _moss_up() and not _plate_up(), "")

	_game.player.set_velocity_now(Vector3.ZERO)
	flourish.advance(flourish.length() + 0.1)
	await _frames(3)
	_t.check("M2 the cold open read, Moss says his hello", opening.turn() == "moss" and _moss_up() and not _plate_up(),
		"turn '%s', Moss %s, plate %s" % [opening.turn(), _moss_up(), _plate_up()])
	_t.check("U1 the plate and the tips wait for Moss", opening.waits("plate") and opening.waits("tip"), "")

	_bubble().dismiss_exchange()
	opening.step(Opening.MOSS_MIN + 0.1)
	await _frames(3)
	var held: bool = opening.live and not opening.waits("tip") and opening.waits("plate") and not _plate_up()
	_game.player.set_velocity_now(Vector3(6.0, 0.0, 0.0))
	opening.step(Opening.PLATE_AFTER + 0.1)
	await _frames(4)
	_t.check("U2 the plate waits for the ball to roll, then comes up and the opening is over", held and not opening.live and _plate_up(),
		"held %s, live %s, plate %s" % [held, opening.live, _plate_up()])
	_t.eq("O1 the turns came in order, each once", _turns, Opening.VOICES)

	# The next run: a pause over the drop, the short cold open, a Warden fight.
	_turns.clear()
	await _take_run()
	take.finished.connect(func(): paused = true, CONNECT_ONE_SHOT)
	await _end_take()
	await _frames(4)
	var holds: bool = not take.busy() and opening.live and opening.turn() == "" and not flourish.playing and not hud.launch_card.showing() and not _moss_up()
	paused = false
	_game.player.set_velocity_now(Vector3.ZERO)
	# Control is the flow's play state with the ball unfrozen; nothing in the opening gates it, so it
	# is read on the release frame itself: 0 on the base and after the change.
	var control_at := 0 if flow.in_play() and _game.player.get("_frozen") != true else -1
	var start_frame := Engine.get_physics_frames()
	var together := 0
	var overlap := 0
	var stamp_seen := false
	var moss_during_stamp := false
	for i in 400:
		await process_frame
		flourish.advance(0.05)
		if control_at < 0 and flow.in_play() and _game.player.get("_frozen") != true:
			control_at = Engine.get_physics_frames() - start_frame
		var stamps: Array = []
		for node in flourish.live_nodes():
			if is_instance_valid(node) and node.name == "FlourishStamp" and node.visible:
				stamps.append(node)
		stamp_seen = stamp_seen or not stamps.is_empty()
		if not stamps.is_empty() and _moss_up():
			together += 1
			for stamp in stamps:
				if stamp.get_global_rect().intersects(_bubble().get_global_rect()):
					overlap += 1
		if i == 3:
			holding_stamp = flourish.short and not stamps.is_empty()
			moss_during_stamp = _moss_up()
		if not flourish.playing and i > 10:
			break
	_t.check("X1 a paused tree holds every turn until it closes", holds and holding_stamp, "held %s, stamp up after the pause %s, stage card %s" % [holds, holding_stamp, hud.launch_card.showing()])
	_t.check("S2 the second run's CLOCKED IN stamp never shares the screen with Moss's message box (one voice at a time, ruling bw)",
		stamp_seen and together == 0 and overlap == 0 and not moss_during_stamp,
		"stamp seen %s, frames with both up %d, rectangles overlapping %d, Moss up 3 frames in %s" % [stamp_seen, together, overlap, moss_during_stamp])
	_t.eq("S3 the ball answers the player on the frame the drop releases, as on the base", control_at, 0)
	print("S2 frames from the drop's release to the ball's first control: %d (physics frames; stage card up %s)" % [control_at, hud.launch_card.showing()])
	await _frames(4)
	_t.check("S1 the short cold open: Moss speaks once the stamp is off, with the opening on his turn", flourish.short and opening.turn() == "moss" and _moss_up(),
		"short %s, turn '%s', Moss %s" % [flourish.short, opening.turn(), _moss_up()])
	hud.take_found("Cable Reach", "Moss's Back Room")
	await _frames(2)
	var waiting: bool = opening.live and opening.waits("plate")
	_game.events.warden_engaged.emit(1)
	_t.check("W1 a Warden fight ends the opening, and every voice has heard its turn", waiting and not opening.live and not opening.waits("plate")
			and _turns == Opening.VOICES, "waiting %s, live %s, turns %s" % [waiting, opening.live, _turns])

	# A restart under the take's panel, with the title, the cold open and Moss all held.
	_turns.clear()
	flourish.stop_all()
	await _take_run()
	await _frames(3)
	var holding: bool = opening.live and opening.waits("title") and not flourish.playing and not _moss_up()
	flow.new_run()
	_game.player.source = Intent.Scripted.new()
	_game.player.set_velocity_now(Vector3.ZERO)
	await _frames(3)
	_t.check("R1 a restart while the opening holds everything goes straight in", holding and not opening.live and _turns.is_empty()
			and flourish.playing and flourish.id == "cold_open" and hud.launch_card.showing() and not (flourish.reading() and _moss_up()),
		"holding %s, live %s, turns %s, flourish %s, stage card %s, Moss %s while the cold open reads %s" % [holding, opening.live, _turns, flourish.id, hud.launch_card.showing(), _moss_up(), flourish.reading()])
	flourish.advance(flourish.length() + 0.1)
	await _frames(4)
	_t.check("R1b the restart's cold open read, Moss follows it", not flourish.playing and _moss_up(), "flourish %s, Moss %s" % [flourish.playing, _moss_up()])
	await _end_take()

	opening.begin()
	var begun: bool = opening.live
	await _frames(2)
	_t.check("V1 an opening begun for a run the flow refused ends on the next frame", begun and not opening.live, "begun %s, live %s" % [begun, opening.live])
	take.force_live = false
	take.set_process(true)

	_game.bot_driven = true
	var code: int = _t.verdict()
	_game.free()
	quit(code)
