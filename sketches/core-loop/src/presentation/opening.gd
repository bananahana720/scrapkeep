extends Node

# A run's opening, one voice at a time (ruling bw). A first stage used to say everything in its
# first second, and some of it under the launch take's panel: the world and stage cards, the
# shift card and its captions, Moss's hello (drawn under the shift card), a tip and an unlock
# plate. Here they take turns. A speaker asks one thing, waits(its name), or
# hears turned(its name) on the frame its turn comes; this file alone knows the order and what
# ends each turn.
#
#   title   the world and stage cards and the cold open: once the take's panel has gone
#   moss    Moss's hello at the hatch and his Warden line: once the cold open's written
#           pieces are off the screen. A cold open the profile has not seen is the shift card
#           and three captions, drawn where his bubble goes; once seen it is a stamp, and he
#           speaks as the panel clears
#   tip     a first-meet tip: once Moss has said his piece, or had MOSS_TURN seconds
#   plate   an unlock plate or a jukebox record: with the tips, and not before the ball has
#           rolled PLATE_AFTER seconds of the run
#
# The opening follows the launch take: game begins one when a played game's take starts a run
# (pilot select or the camp gate). A bot's run, a test's, and a restart from the death screen or
# a held R go straight in, as they always did: a run that starts without a begin() ends any
# opening still playing, silently, because the new run's own stage entry says everything again.
# A Warden fight, a retry, another stage or a screen away from play ends it at once, and every
# voice still waiting hears its turn then. It is pausable: a screen that pauses the drop (the
# briefing with the kit choice and the start pick) holds every turn until it closes.

signal turned(voice: String)

const VOICES := ["title", "moss", "tip", "plate"]
const TAKE := -1
const TITLE := 0
const MOSS := 1
const PLATE := 3
const MOSS_TURN := 6.0
# Moss's bubble fades in: his turn is not over before it has had the chance to come up.
const MOSS_MIN := 0.4
const PLATE_AFTER := 4.0
const ROLLING := 1.0
const OPEN_ROW := "cold_open"

var game
# An opening is playing: from the run's start to its last turn.
var live := false
# The voice whose turn has come, an index into VOICES; TAKE while the panel still covers.
var _turn := TAKE
var _turn_age := 0.0
var _rolled := 0.0
var _entered := false
# begin() was called and its run has not started yet: the next run_started is this opening's own.
var _fresh := false
# The take's panel was seen gone on the frame before: a screen that pauses the drop on the frame
# the take ends (the briefing) gets that frame to do it, whichever of the two is stepped first.
var _clear := false


func setup(game_ref) -> void:
	name = "Opening"
	game = game_ref
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var events = game.events
	events.run_started.connect(_on_run_started)
	events.stage_entered.connect(_on_stage_entered)
	events.warden_engaged.connect(func(_stage: int): finish())
	events.flow_changed.connect(func(_state: String):
		if _entered and not game.flow.in_stage():
			finish())


# Whether a voice must still hold its tongue. False for every voice outside an opening.
func waits(voice: String) -> bool:
	if not live:
		return false
	var at := VOICES.find(voice)
	return at > _turn or (at == PLATE and _rolled < PLATE_AFTER)


# The voice whose turn has come: "" outside an opening and under the take's panel.
func turn() -> String:
	return VOICES[_turn] if live and _turn >= 0 else ""


# The run about to start has an opening. Called before the run starts, so every speaker asks a
# live opening from the run's first signal on.
func begin() -> void:
	finish()
	live = true
	_fresh = true
	_turn = TAKE
	_turn_age = 0.0
	_rolled = 0.0
	_entered = false
	_clear = false


# The run this opening was begun for, or another: a restart, which says everything again itself.
func _on_run_started(_class_id: String) -> void:
	if _fresh:
		_fresh = false
	else:
		live = false


func _on_stage_entered(_stage: int, retry: bool) -> void:
	if not live:
		return
	if retry or _entered:
		finish()
		return
	_entered = true


func _process(delta: float) -> void:
	if not live:
		return
	# Begun, and the run never reached a stage (the flow refused it): nothing to open.
	if not _entered:
		finish()
		return
	step(delta)


# One frame of the opening. A test steps it by hand.
func step(delta: float) -> void:
	_turn_age += delta
	if _turn >= TITLE and game.player != null and game.player.state.velocity.length() > ROLLING:
		_rolled += delta
	match _turn:
		TAKE:
			if _take_busy():
				_clear = false
			elif _clear:
				_next()
			else:
				_clear = true
		TITLE:
			if not _written_up():
				_next()
		MOSS:
			if (_turn_age >= MOSS_MIN and not _moss_up()) or _turn_age >= MOSS_TURN:
				while _turn < PLATE:
					_next()
		PLATE:
			if _rolled >= PLATE_AFTER:
				finish()


func _next() -> void:
	_turn += 1
	_turn_age = 0.0
	turned.emit(VOICES[_turn])


# Ends the opening where it stands. Whoever was still waiting hears their turn now, in order.
func finish() -> void:
	if not live:
		return
	live = false
	_fresh = false
	for at in range(_turn + 1, VOICES.size()):
		turned.emit(VOICES[at])


func _take_busy() -> bool:
	var take = game.get("launch_take")
	return take != null and take.busy()


# The cold open still has reading matter to show (flourish_player.reading).
func _written_up() -> bool:
	var flourish = game.presentation.get("flourish") if game.get("presentation") != null else null
	return flourish != null and flourish.reading(OPEN_ROW)


func _moss_up() -> bool:
	var host = game.get_node_or_null("Workshop")
	var bubble = host.get("bubble") if host != null else null
	return bubble != null and bubble.showing()
