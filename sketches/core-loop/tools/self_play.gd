extends Node

# --self-play (src/game.gd): a bot plays the launched game with real ticks, as a player's
# game runs (no SimClock), so `npm run sketch:frametime -- --self-play` can log a stage swap
# or a stage exit unattended (SWAP-HITCH-6, STAGE6-GATE). Only packs that carry tools/ have
# it: `npm run sketch:export -- --self-play`. Seconds are since launch; the watch line's blank_max
# and bar_off_max are seconds of play.
#
# Flags (after `--`):
#   --self-play-seed=<n>      run seed (default 1)
#   --self-play-pilot=<id>    class id, e.g. pylon_engineer
#   --self-play-policy=<p>    a BotDriver policy: skipper (default), completionist, random,
#                             camper, traversal, brawler
#   --self-play-from=<stage>  enter that stage directly (tools/bot_run.gd --from-stage)
#   --self-play-until=<what>  <n>: stop once stage n is entered (default 2); exit<n>: once
#                             stage n's exit is taken; win: once the run is won
#   --self-play-hand-off=<h>  switch one of the sitting hand's hands off (bot_loops.gd hands: called_shot, bay, trade, overtime, carry), so a test
#                             can show its loop reads as not fired; only on a --profile=sitting launch
#   --self-play-hold=<s>      keep playing this long after the goal (default 30)
#   --self-play-min=<s>       and until this many seconds since launch (default 0)
#   --self-play-stall=<s>     seconds the exit may stay untaken after the fight ends, and seconds the
#                             next stage may stay unopened after an exit is taken, a boss fight
#                             aside (default 120)
#   --self-play-plant-stall   TEST PLANT: freeze the bot after its first tick and count the fight as
#                             ended then, so the stall detector fires after --self-play-stall
#   --self-play-keys=1        the menus are pressed as keys, as a player presses them (Space on the title,
#                             the interact key through the prologue, the pilot's number at the pilot
#                             select, N after a death), through the game's own input path; absent, the
#                             run is started by code. The pilot must be one the save has open (no pilot
#                             named: the first that is). The game is still bot-driven, so the launch
#                             take and the start-pick card do not show. Not with --self-play-from.
#   --self-play-continue=1    take the saved run: C on the title (with keys), or the bot's resume
#                             (without). No Continue offered quits 1 and starts nothing; with keys C is
#                             pressed all the same, and the title has to stand. The bot leaves the
#                             upgrade tree's offers to the workshop on a continued run, so the saved
#                             picks are replayed as a player's are.
#   --self-play-save=<name>   the run's save folder is user://self-play-<name>, not one named for this
#                             process, so a second launch can continue the first (read by src/game.gd)
#   --self-play-plant-death=<s>  TEST PLANT, with keys: the ball takes a scripted kill after s seconds
#                             of play; the keys then start a second run, which stands in play for
#                             --self-play-hold with nobody steering (the dead run's driver is spent; its
#                             signal handlers still answer offers). Quits 0 then; a hit that did not kill quits 3.
#   --self-play-plant-hide=objective  TEST PLANT, for a film's control run: the objective plate is drawn
#                             clear from the first tick of play (its words still chosen, so the play
#                             watch sees nothing), so a reader of the film has to say it is missing
#   --self-play-plant-after-exit  TEST PLANT: freeze the bot after its first tick and count the
#                             stage's exit as taken then, so the after-exit stall fires
#   --self-play-plant-end     TEST PLANT: end the run at once (outcome planted_end), so it quits 1
#   --self-play-plant-limit=<s>  TEST PLANT: give the driver this stage limit (sim seconds), so its
#                             own stall limit ends the run (the driver-limit branch)
#   --self-play-beat=<s>      print a "self-play: beat" progress line every s seconds (default off)
#   --self-play-eyes=1        with keys: the game is not told a bot is at the controls, so what only a
#                             player's game shows is on the screen (the launch take, the briefing's kit
#                             pick and start pick) and each held screen is answered with its first key
#                             after EYES_READ_S, as a player who reads it and takes the first choice.
#                             Kit picks are then the first card, not the bot's seeded draw. A pause menu
#                             the game opened by itself is closed with Esc and said. Each prologue line
#                             stands EYES_READ_S before it is turned and a death screen twice that.
#   --self-play-probe=<file>  write what built each frame over 25 ms (tools/frame_probe.gd, reads only) to <file> as
#                             the game quits: the bot's own tick, draw, node work, nodes added, pipeline compiles.
#                             --self-play-probe-signals=1 also times every GameEvents handler (it adds cost).
#   --self-play-film=<dir>    film the run as the player's eyes meet it (tools/eye_film.gd, reads only): the
#                             picture at each screen, plate change, prompt, offer, big hit (with the two
#                             seconds before it) and death, and every --self-play-film-every=<s> seconds
#                             of play (default 10), as frames with one row of ground truth each in
#                             <dir>/film.ndjson. Needs a rendered display (not --headless; quits 2) and
#                             --fixed-fps. It draws only the frames it keeps unless --self-play-film-live=1,
#                             and the run's seconds are then game seconds, not seconds since launch. Prints "self-play: film <n> frames in <dir>" as the run ends.
#   --self-play-watch=1       watch the run as a player would meet it (tools/qa_watch.gd, reads only): where the
#                             ball sat stuck, hung off the ground, wedged or fell through, each objective plate
#                             change, the longest stretches of play with an empty plate and with the hull bar
#                             off the hull, and the boss fight's start and end. Rows go to qa.ndjson in the run's own save folder; the totals print
#                             on one "self-play: watch" line as the run ends. Absent, the run is unchanged.
#
# Lines: "self-play: stage <n> entered at <s> s" (one per stage entered, retries marked), each followed by
# "self-play: carry stage=<n> hp=<f> mass=<f> cogs=<n> parts=<list> picks=<list>" (what the run carries in),
# With keys: "self-play: prologue read with <n> presses at <s> s", "self-play: pilot <n> picked by key at <s> s",
# "self-play: in play by keys at <s> s", "self-play: continue pressed at <s> s",
# "self-play: no Continue offered at <s> s ...", "self-play: planted death at <s> s (stage <n>) holding ...",
# "self-play: new run pressed on '<state>' at <s> s", "self-play: second run in play at <s> s ...",
# "self-play: menus stalled in '<state>' at <s> s" (quit 3).
# "self-play: stage <n> exit taken at <s> s", "self-play: done at <s> s". With --self-play-watch=1 also
# "self-play: boss arena entered at <s> s", "self-play: boss defeated at <s> s" and
# "self-play: watch stuck=<n> hung=<n> wedged=<n> fell=<n> objectives=<n> blank_max=<s> bar_off_max=<s> stages=<list>"
# and "self-play: skills slot2=<n> slot3=<n> set_pieces=<n>" (casts of the skill bar's slots 2 and 3, set pieces fired).
# Quit codes: 0 goal reached, 1 the run ended first or no Continue was offered, 2 bad flag, a pilot the keys cannot pick, or no tools/ in the pack
# (game.gd), 3 stalled (every code waits for --self-play-min first, so a frame log stays whole): "self-play: stalled at stage <n> exit at <s> s pos <x,y,z>"
# (the exit never taken), or "... stalled at stage <n> after-exit at ..." (the exit taken, the next stage never opened).

const BotDriver := preload("res://tools/bot_driver.gd")
const QaWatch := preload("res://tools/qa_watch.gd")
const EyeFilm := preload("res://tools/eye_film.gd")
const ObjectiveView := preload("res://src/ui/objective_view.gd")
const RunState := preload("res://src/core/run_state.gd")
const FrameProbe := preload("res://tools/frame_probe.gd")

# Keys mode: how long a key stays down, the gap before the next, and how long the menus may take.
const KEY_DOWN_S := 0.1
const KEY_GAP_S := 0.5
const MENU_STALL_S := 60.0
const DEAD_WAIT_S := 2.0
# A refused Continue: how long the title has to stand after C before the bot says so.
const REFUSED_WAIT_S := 2.0
# Eyes mode: how long a held screen stands before its key, so a film sees it as a reader would.
const EYES_READ_S := 3.0

var game: Node
var _driver
var _goal_at := -1.0
var _hold := 30.0
var _hands_off: Array = []
var _min := 0.0
var _seed := 1
var _pilot := ""
var _policy := "skipper"
var _from := 0
var _until := "2"
var _stall := 120.0
var _fight_end := -1.0
# The stage's exit is taken: the exit stall has nothing left to time until the next stage opens
# (a boss fight after the exit is the driver's own limit to end, not this one's).
var _exit_taken := false
# Since when the taken exit has led nowhere (seconds; -1 while there is nothing to time): the wait
# for the next stage outside a boss fight, a victory beat or a paused tree nobody answers included.
var _after_exit := -1.0
var _stage := 0
var _beat := 0.0
var _beat_at := 0.0
var _quit_code := -1
var _plant_stall := false
var _plant_after_exit := false
var _keys := false
var _continue := false
var _plant_death := -1.0
# Keys mode: true while the menus still stand between the bot and play.
var _menus := false
var _menu_at := 0.0
# The death leg waits for the dead run to leave play before it reads "in play" as the second run.
var _await_out := false
var _key := KEY_NONE
var _pressed_at := -10.0
var _play_at := -1.0
var _died := false
var _prologue := 0
var _c_at := -1.0
var _offered := false
var _plant_end := false
var _plant_limit := 0.0
var _watch_on := false
var _watch
var _read_gap := 0.0
var _stages: Array[int] = []
var _watch_told := false
var _film_dir := ""
var _film_every := 10.0
var _film
var _film_live := false
var _film_world := 1.0
var _clock := 0.0
var _eyes := false
var _plant_hide := ""
var _held_at := -1.0
var _probe


func _ready() -> void:
	# Run before Game each tick, as bot_run does, so the bot's intent is read the same tick.
	process_physics_priority = -1
	# A reward ceremony or the pause menu pauses the tree; the bot must keep answering them.
	process_mode = Node.PROCESS_MODE_ALWAYS
	var probe_file := ""
	var probe_signals := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--self-play-hold="):
			_hold = float(arg.trim_prefix("--self-play-hold="))
		elif arg.begins_with("--self-play-hand-off="):
			_hands_off.append(arg.trim_prefix("--self-play-hand-off="))
		elif arg.begins_with("--self-play-min="):
			_min = float(arg.trim_prefix("--self-play-min="))
		elif arg.begins_with("--self-play-seed="):
			_seed = int(arg.trim_prefix("--self-play-seed="))
		elif arg.begins_with("--self-play-pilot="):
			_pilot = arg.trim_prefix("--self-play-pilot=")
		elif arg.begins_with("--self-play-policy="):
			_policy = arg.trim_prefix("--self-play-policy=")
		elif arg.begins_with("--self-play-from="):
			_from = int(arg.trim_prefix("--self-play-from="))
		elif arg.begins_with("--self-play-until="):
			_until = arg.trim_prefix("--self-play-until=")
		elif arg.begins_with("--self-play-stall="):
			_stall = float(arg.trim_prefix("--self-play-stall="))
		elif arg.begins_with("--self-play-script="):
			pass  # test override, read by src/game.gd; named here so the launch-flag lint finds its parser
		elif arg.begins_with("--self-play-save="):
			# Read by src/game.gd, which falls back to a folder of this process's own on a name it will not use.
			if not String(game.storage_dir).ends_with("self-play-" + arg.trim_prefix("--self-play-save=")):
				push_error("self-play: --self-play-save wants a plain folder name (no dots, slashes or spaces at the ends), got '%s'" % arg.trim_prefix("--self-play-save="))
				get_tree().quit.call_deferred(2)
		elif arg == "--self-play-plant-end":
			_plant_end = true
		elif arg == "--self-play-plant-stall":
			_plant_stall = true
		elif arg == "--self-play-plant-after-exit":
			_plant_after_exit = true
		elif arg.begins_with("--self-play-keys="):
			_keys = arg.trim_prefix("--self-play-keys=") == "1"
		elif arg.begins_with("--self-play-continue="):
			_continue = arg.trim_prefix("--self-play-continue=") == "1"
		elif arg.begins_with("--self-play-plant-death="):
			_plant_death = float(arg.trim_prefix("--self-play-plant-death="))
		elif arg.begins_with("--self-play-plant-limit="):
			_plant_limit = float(arg.trim_prefix("--self-play-plant-limit="))
		elif arg.begins_with("--self-play-beat="):
			_beat = float(arg.trim_prefix("--self-play-beat="))
		elif arg.begins_with("--self-play-watch="):
			_watch_on = arg.trim_prefix("--self-play-watch=") == "1"
		elif arg.begins_with("--self-play-film="):
			_film_dir = arg.trim_prefix("--self-play-film=")
		elif arg.begins_with("--self-play-film-every="):
			_film_every = float(arg.trim_prefix("--self-play-film-every="))
		elif arg.begins_with("--self-play-film-world="):
			_film_world = float(arg.trim_prefix("--self-play-film-world="))
		elif arg.begins_with("--self-play-film-live="):
			_film_live = arg.trim_prefix("--self-play-film-live=") == "1"
		elif arg.begins_with("--self-play-plant-hide="):
			_plant_hide = arg.trim_prefix("--self-play-plant-hide=")
			if _plant_hide != "objective":
				push_error("self-play: --self-play-plant-hide wants objective, got '%s'" % _plant_hide)
				get_tree().quit.call_deferred(2)
		elif arg.begins_with("--self-play-eyes="):
			_eyes = arg.trim_prefix("--self-play-eyes=") == "1"
		elif arg.begins_with("--self-play-probe="):
			probe_file = arg.trim_prefix("--self-play-probe=")
		elif arg.begins_with("--self-play-probe-signals="):
			probe_signals = arg.trim_prefix("--self-play-probe-signals=") == "1"
	if probe_file != "":
		_probe = FrameProbe.new()
		_probe.watch(game, probe_file, probe_signals, self)
	if not (_policy in BotDriver.POLICIES or _policy in BotDriver.PROFILES):
		push_error("self-play: unknown policy '%s'" % _policy)
		get_tree().quit.call_deferred(2)
	if _eyes and not _keys:
		push_error("self-play: --self-play-eyes needs --self-play-keys=1 (a player's game is started by its keys)")
		get_tree().quit.call_deferred(2)
	if _keys and _from > 1:
		push_error("self-play: --self-play-keys starts at the title; it cannot be used with --self-play-from")
		get_tree().quit.call_deferred(2)
	if _until != "win" and not (_until.is_valid_int() or (_until.begins_with("exit") and _until.trim_prefix("exit").is_valid_int())):
		push_error("self-play: --self-play-until wants <stage>, exit<stage> or win, got '%s'" % _until)
		get_tree().quit.call_deferred(2)


func _exit_tree() -> void:
	if _probe != null:
		_probe.write()


func _physics_process(delta: float) -> void:
	if _probe == null:
		_step(delta)
		return
	var started := Time.get_ticks_usec()
	_step(delta)
	_probe.bot_us += Time.get_ticks_usec() - started


func _step(delta: float) -> void:
	_clock += delta
	if game.flow == null:
		return
	if _film_dir != "" and _film == null:
		_film = EyeFilm.new()
		if not _film.setup(game, _film_dir, _film_every, _film_live, _film_world):
			get_tree().quit(2)
			return
	if _film != null:
		_film.step(delta)
	if _driver == null:
		# The played game builds stage 1's ground behind the menu (ground_behind_menu); start the
		# run once it is built, as a player pressing start after the menu settles.
		if not game.ctx.terrain.is_ready(1):
			return
		_start()
		return
	if _quit_code >= 0:
		# Every ending idles until --self-play-min so a frame log that needs its full length is whole.
		if _now() >= _min:
			get_tree().quit(_quit_code)
		return
	if _plant_hide != "" and game.hud != null:
		# Planted: the plate is there and holds its words; it is only not seen.
		for piece in game.hud.get_children():
			if piece.get_script() == ObjectiveView:
				piece.modulate.a = 0.0
	if _eyes:
		_answer_held()
	else:
		_answer_workshop()
	_release()
	var state: String = game.flow.state_name()
	if _beat > 0.0 and _now() - _beat_at >= _beat:
		_beat_at = _now()
		var b: Vector3 = game.player.ball_position()
		print("self-play: beat %.1f s stage %d %s%s stage_time %.1f pos %.0f,%.0f,%.0f" % [_now(), game.run.stage, state, " PAUSED" if get_tree().paused else "", game.run.stage_time, b.x, b.y, b.z])
	if _menus:
		_press_menus(state)
		_watch_tick(delta)
		return
	if _plant_death >= 0.0 and _death_step():
		_watch_tick(delta)
		return
	if _plant_stall:
		# Planted stall: the bot stands still and the fight counts as over from now.
		_driver.source.hold = {}
		if _fight_end < 0.0:
			_fight_end = _now()
		if _now() - _fight_end > _stall:
			_stalled("exit")
		_watch_tick(delta)
		return
	if _plant_after_exit:
		# Planted: the bot stands still and the exit counts as taken from now.
		_driver.source.hold = {}
		_exit_taken = true
	elif _driver.tick(delta):
		_watch_tick(delta)
		_finish()
		return
	_watch_tick(delta)
	if _fight_end < 0.0 and state == "gates" and not _exit_taken:
		_fight_end = _now()
	if _fight_end >= 0.0 and _goal_at < 0.0 and _now() - _fight_end > _stall:
		_stalled("exit")
		return
	# The exit is taken: the next stage has to open. A boss fight on the way, and the victory lap
	# after the last one, are the driver's own limits to end; everything else (the flight, the
	# victory beat, a pause nobody answers) is timed here.
	if not _exit_taken or state == "boss" or state == "lap":
		_after_exit = -1.0
	elif _after_exit < 0.0:
		_after_exit = _now()
	elif _goal_at < 0.0 and _now() - _after_exit > _stall:
		_stalled("after-exit")
		return
	if _goal_at >= 0.0 and _now() >= maxf(_goal_at + _hold, _min):
		print("self-play: done at %.2f s" % _now())
		_end_run(0)


# Keys mode: one key a step, as a player presses them, until the run is in play.
func _press_menus(state: String) -> void:
	var in_play: bool = game.flow.in_play()
	if _await_out and not in_play:
		_await_out = false
	if in_play and not _await_out:
		_menus = false
		print("self-play: in play by keys at %.2f s" % _now())
		return
	if _now() - _menu_at > MENU_STALL_S:
		print("self-play: menus stalled in '%s' at %.2f s" % [state, _now()])
		_end_run(3)
		return
	if _key != KEY_NONE or _now() - _pressed_at < KEY_GAP_S:
		return
	# A player reads a page before turning it and a death screen before leaving it.
	var reading: bool = _eyes and (state == "dead" or state == "summary" or (state == "class_select" and game.screens.prologue_showing()))
	if reading and _now() - maxf(_pressed_at, _menu_at) < EYES_READ_S * (1.0 if state == "class_select" else 2.0):
		return
	match state:
		"title":
			if not _continue or _died:
				_press(KEY_SPACE)
			elif _c_at < 0.0:
				# Continue is settled by the time the title shows. Not offered, C is pressed all the
				# same: the title has to stand.
				_c_at = _now()
				_offered = game.flow.continue_ready
				if _offered:
					print("self-play: continue pressed at %.2f s" % _now())
				_press(KEY_C)
			elif not _offered and _now() - _c_at >= REFUSED_WAIT_S:
				print("self-play: no Continue offered at %.2f s (C pressed, the title stands)%s" % [_now(), _why_refused()])
				_end_run(1)
		"class_select":
			# A profile's first pilot select opens on the prologue: the interact key reads it line by line.
			if game.screens.prologue_showing():
				_prologue += 1
				_press(KEY_E)
				if _film != null:
					_film.page()
			else:
				if _prologue > 0:
					print("self-play: prologue read with %d presses at %.2f s" % [_prologue, _now()])
					_prologue = 0
				print("self-play: pilot %d picked by key at %.2f s" % [_driver.class_index + 1, _now()])
				_press(KEY_1 + _driver.class_index)
		"dead", "summary":
			# The death screen stands a moment first, as it does for a player.
			if _now() - _menu_at >= DEAD_WAIT_S:
				print("self-play: new run pressed on '%s' at %.2f s" % [state, _now()])
				_press(KEY_N)


func _press(key: Key) -> void:
	_key = key
	_pressed_at = _now()
	_send(key, true)


# A pressed key is let go a moment later, so nothing reads it as held (the summary's latch does).
func _release() -> void:
	if _key != KEY_NONE and _now() - _pressed_at >= KEY_DOWN_S:
		_send(_key, false)
		_key = KEY_NONE


func _send(key: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = down
	Input.parse_input_event(event)


# Planted death: the first run takes a fatal hit after _plant_death seconds of play; the keys then
# start a second run. True once the hit has landed: the bot's driver is spent from there.
func _death_step() -> bool:
	if not _died:
		if _play_at < 0.0:
			_play_at = _now()
		if _now() - _play_at < _plant_death:
			return false
		_died = true
		_driver.source.hold = {}
		var run = game.run
		var held := "hp=%.2f mass=%.2f cogs=%d parts=%d picks=%d" % [run.hp, run.mass, run.cogs, run.parts.size(), game.player.tree.picks.size()]
		run.damage(RunState.SCRIPTED_KILL, "chaser")
		if run.alive():
			# A set piece, a ward or an earned save turned the hit aside: say so, not a menu stall.
			print("self-play: planted death did not land at %.2f s (stage %d, hp %.1f)" % [_now(), run.stage, run.hp])
			_end_run(3)
			return true
		print("self-play: planted death at %.2f s (stage %d) holding %s" % [_now(), run.stage, held])
		_menus = true
		_await_out = true
		_menu_at = _now()
		return true
	if _goal_at < 0.0:
		_goal_at = _now()
		print("self-play: second run in play at %.2f s stage %d hp %.0f of %.0f" % [_now(), game.run.stage, game.run.hp, game.run.max_hp])
	if _now() >= maxf(_goal_at + _hold, _min):
		print("self-play: done at %.2f s" % _now())
		_end_run(0)
	return true


# A pick the offer signal did not settle (the workshop reopened it) is taken by its first card, so
# the paused tree never waits on a player.
func _answer_workshop() -> void:
	var workshop: Node = game.get_node_or_null("Workshop")
	if workshop != null and workshop.get("pick") != null and workshop.pick.is_open():
		workshop.choose(0)


# Eyes mode: a screen that holds the game (the kit pick, the briefing's start pick) stands for
# EYES_READ_S and is then answered with its first key; a pause menu the game opened by itself is
# closed.
func _answer_held() -> void:
	if not get_tree().paused or _menus:
		_held_at = -1.0
		return
	if _held_at < 0.0:
		_held_at = _now()
		return
	if _now() - _held_at < EYES_READ_S or _key != KEY_NONE or _now() - _pressed_at < KEY_GAP_S:
		return
	_held_at = _now()
	var workshop: Node = game.get_node_or_null("Workshop")
	var menu: Node = game.get_node_or_null("PauseMenu")
	if menu != null and menu.is_open():
		print("self-play: the game paused itself at %.2f s; closed with Esc" % _now())
		_press(KEY_ESCAPE)
	elif workshop != null and workshop.pick.is_open():
		print("self-play: kit pick taken with 1 at %.2f s" % _now())
		_press(KEY_1)
	elif workshop != null and workshop.briefing():
		print("self-play: start pick taken with 1 at %.2f s" % _now())
		_press(KEY_1)


# Print the verdict now, quit with its code once --self-play-min has passed.
func _end_run(code: int) -> void:
	_tell_watch()
	if _film != null and _quit_code < 0:
		print("self-play: film %d frames (%d drawn) in %s" % [_film.frames, _film.drawn, _film_dir])
	_quit_code = code


# Every path of a tick that plays goes through here once, the planted ones and the menus the
# keys press included, so a second run after a death is watched like the first.
func _watch_tick(delta: float) -> void:
	if _watch != null and not get_tree().paused:
		_watch_step(delta)


# The watch's ball checks every tick; once a second of play its plate read, and how long play has
# gone on with nothing on the objective plate (to the second). The gap is counted in the ticks
# this is called on, which a paused tree does not give it, so a pause, a held screen or the
# launch before the run starts is never read as seconds of play.
func _watch_step(delta: float) -> void:
	_watch.step(delta)
	_read_gap += delta
	if _read_gap < 1.0:
		return
	_watch.read_text(_read_gap)
	_read_gap = 0.0


func _tell_watch() -> void:
	if _watch == null or _watch_told:
		return
	_watch_told = true
	var c: Dictionary = _watch.counts
	print("self-play: watch stuck=%d hung=%d wedged=%d fell=%d objectives=%d blank_max=%.1f bar_off_max=%.1f stages=%s" % [int(c.get("stuck", 0)),
		int(c.get("hung", 0)), int(c.get("wedged", 0)), int(c.get("fell", 0)), _watch.plates, _watch.blank_max, _watch.bar_off_max,
		",".join(_stages.map(func(n): return str(n)))])
	# The skill bar's hands, as the driver's record counts them: casts of slots 2 and 3 and set pieces fired.
	var record: Dictionary = _driver.record(_now())
	var casts: Dictionary = record.get("slot_casts", {})
	print("self-play: skills slot2=%d slot3=%d set_pieces=%d" % [int(casts.get("special", 0)), int(casts.get("line", 0)), int(record.get("ultimates", 0))])


func _start() -> void:
	_driver = BotDriver.new(game, _policy, _seed)
	if _pilot != "":
		_driver.class_index = BotDriver.class_index_for(_seed, _pilot)
	game.run.run_seed_override = _seed
	_driver.hands_off = _hands_off
	# The played game's workshop pauses the tree on an upgrade pick (bot_run's test_mode game has no
	# workshop); the driver answers each offer as it arrives, with a seeded random pick.
	_driver.tree_policy = "random"
	if _plant_limit > 0.0:
		_driver.stage_limit = _plant_limit
	if _plant_end:
		_driver._end("planted_end")
	game.events.stage_entered.connect(_on_stage_entered)
	game.events.stage_cleared.connect(_on_stage_cleared)
	if _watch_on:
		_watch = QaWatch.new()
		_watch.setup(game, _driver, String(game.storage_dir).path_join("qa.ndjson"))
		game.events.boss_arena_entered.connect(func(): print("self-play: boss arena entered at %.2f s" % _now()))
		game.events.boss_defeated.connect(func(): print("self-play: boss defeated at %.2f s" % _now()))
	if _keys:
		# No pilot named: the first the save has open, as a new player's first run takes.
		if _pilot == "":
			for i in game.flow.classes.size():
				if game.pilot_unlocked(game.flow.classes[i]):
					_driver.class_index = i
					break
		if _driver.class_index < 0 or _driver.class_index >= 9 or not game.pilot_unlocked(game.flow.classes[_driver.class_index]):
			push_error("self-play: --self-play-keys cannot pick pilot %d: it is locked on this save, or past key 9" % (_driver.class_index + 1))
			get_tree().quit.call_deferred(2)
			return
		_leave_saved_picks()
		if _eyes:
			# The kit pick is the player's to read and take: the driver leaves every offer on the screen.
			_driver.tree_policy = ""
		_driver.wire()
		if _eyes:
			game.bot_driven = false
		_menus = true
		_menu_at = _now()
	elif _continue and not game.flow.continue_ready:
		# Nothing to take: say so and start nothing, so no new run is written over the save's place.
		print("self-play: no Continue offered at %.2f s%s" % [_now(), _why_refused()])
		_end_run(1)
		return
	else:
		_leave_saved_picks()
		_driver.start(_continue)
		# As bot_run does: the stage is entered over the one the start pick opened.
		if _from > 1:
			game.flow.enter_stage(_from, Vector3.ZERO, false)
	print("self-play: %s seed %d until %s started at %.2f s" % [_policy, _seed, _until, _now()])


# A continued run replays its saved tree picks as it lands. A driver that answers the tree's offer
# on the signal gets in first and the saved picks no longer fit, so on a continued run the offers
# are left to the workshop (the first card, _answer_workshop), as a player meets them.
func _leave_saved_picks() -> void:
	if _continue:
		_driver.tree_policy = ""


func _why_refused() -> String:
	var why: String = game.flow.continue_refusal()
	return "" if why == "" else ": " + why


# The driver ended the run. A stall is the driver's own limit; won ends a "win" goal.
func _finish() -> void:
	var outcome: String = _driver.outcome
	if _goal_at >= 0.0:
		print("self-play: done at %.2f s" % _now())
		_end_run(0)
	elif outcome == "won" and _until == "win":
		print("self-play: run won at %.2f s" % _now())
		_end_run(0)
	elif outcome == "stalled" or outcome == "boss_stalled" or outcome == "fight_capped":
		_stalled("exit" if _fight_end >= 0.0 else outcome)
	else:
		print("self-play: run ended '%s' at stage %d before the goal at %.2f s" % [outcome, game.run.stage, _now()])
		_end_run(1)


func _stalled(what: String) -> void:
	var p: Vector3 = game.player.ball_position()
	print("self-play: stalled at stage %d %s at %.2f s pos %.1f,%.1f,%.1f" % [game.run.stage, what, _now(), p.x, p.y, p.z])
	_end_run(3)


func _on_stage_entered(stage: int, retry := false) -> void:
	_stage = stage
	_fight_end = -1.0
	_exit_taken = false
	_after_exit = -1.0
	if not retry:
		_stages.append(stage)
	print("self-play: stage %d entered%s at %.2f s" % [stage, " (retry)" if retry else "", _now()])
	var run = game.run
	print("self-play: carry stage=%d hp=%.2f mass=%.2f cogs=%d parts=%s picks=%s" % [stage, run.hp, run.mass, run.cogs,
		"+".join(PackedStringArray(Array(run.parts))), "+".join(PackedStringArray(Array(game.player.tree.picks)))])
	if _until.is_valid_int() and stage >= int(_until) and _goal_at < 0.0 and not retry and _plant_death < 0.0:
		_goal_at = _now()


func _on_stage_cleared(stage: int) -> void:
	print("self-play: stage %d exit taken at %.2f s" % [stage, _now()])
	_fight_end = -1.0
	_exit_taken = true
	if _until == "exit%d" % stage and _goal_at < 0.0:
		_goal_at = _now()


# Seconds since launch. A filmed run counts game seconds instead (its own ticks), so its key
# presses, holds and stall limits keep their meaning however slowly the renderer draws.
func _now() -> float:
	return _clock if _film_dir != "" else Time.get_ticks_msec() / 1000.0
