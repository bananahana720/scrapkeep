extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const LaunchTake := preload("res://src/presentation/launch_take.gd")
const T := preload("res://tests/support/t.gd")
const Comfort := preload("res://src/core/comfort.gd")

# The launch take (launch_take.gd, world 1 unit 17) on the real game:
#   - not live (tests, bots, headless), a play runs its cover call at once and shows nothing;
#   - pilot select: the pick waits under the wind, keys are swallowed, the run starts on the first fully covered frame
#     and the panel never shows the cut, then sweeps off; the deck camera rushes in during the wind;
#   - the camp gate fires the ball up and out of the gate, then the run starts on stage 1 with the gate's pilot;
#   - a first run (prologue due) at the gate goes to pilot select instead;
#   - reduced motion skips the wind and keeps the panel's lines still;
#   - the whole take stays inside its budget once the dam is drawn.

const STEP := 1.0 / 30.0

var _t := T.new("launch_take_test")
var _game
var _take


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


# Steps the take by hand, a frame of the tree between steps, until it leaves `phase` (or max_steps). Returns steps taken.
func _step_while(phase: int, max_steps := 200) -> int:
	var steps := 0
	while _take.phase == phase and steps < max_steps:
		_take.advance(STEP)
		steps += 1
		await process_frame
	return steps


func _run() -> void:
	while _game.flow == null:
		await process_frame
	await _frames(5)
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	_take = _game.launch_take
	var flow = _game.flow
	_t.check("the game has a launch take", _take != null and not _take.busy(), "")

	# Not live: the cover call runs at once.
	var ran := [false]
	_take.live = false
	var played: bool = _take.play(func(): ran[0] = true)
	_t.check("not live, on_cover runs at once and nothing shows", not played and ran[0] and not _take.busy() and not _take._layer.visible, "")

	# Pilot select, live.
	_take.force_live = true
	var at_cover := []
	_take.covered.connect(func(): at_cover.append([_take.progress(), flow.state_name()]))
	flow.press_start()
	await _frames(2)
	_t.eq("Play reaches pilot select", flow.state_name(), "class_select")
	_game._screen_key(KEY_1)
	_take.set_process(false)
	_t.check("the pick starts the take", _take.busy() and _take.phase == LaunchTake.WIND and _take._layer.visible, str(_take.phase))
	_t.eq("pilot select holds through the wind", flow.state_name(), "class_select")
	_t.check("a second pick under the take is swallowed", _game._screen_key(KEY_2) and flow.state_name() == "class_select", "")
	var title_stage = _game.presentation.title_stage
	var wind_steps: int = await _step_while(LaunchTake.WIND)
	_t.check("the deck camera rushes in during the wind", title_stage.push > 0.0, str(title_stage.push))
	await _frames(3)
	var cover_steps: int = await _step_while(LaunchTake.COVER)
	_t.check("the run starts under the swipe, on a fully covered frame", at_cover.size() == 1 and at_cover[0][0] == 1.0
		and at_cover[0][1] != "class_select", str(at_cover))
	_t.check("the start-pick card waits for the panel to go", not _game.flow.start_card.visible, "")
	_t.check("the run is on stage 1 with the picked pilot", flow.in_stage() and _game.run.stage == 1
		and _game.run.class_def == flow.classes[0], flow.state_name())
	_t.check("the panel holds over the dam with the word stamped", _take.covering() and _take.progress() == 1.0 and _take._word.visible, "")
	var hold_steps: int = await _step_while(LaunchTake.HOLD)
	_take.advance(STEP)
	var reveal_seen: bool = _take.phase == LaunchTake.REVEAL and _take.progress() > 1.0
	var reveal_steps: int = await _step_while(LaunchTake.REVEAL)
	_t.check("the panel sweeps off and the take ends", reveal_seen and not _take.busy() and not _take._layer.visible, "")
	var seconds := (wind_steps + cover_steps + hold_steps + reveal_steps) * STEP
	_t.check("the take lasts at most 1.3 s with the dam drawn", seconds <= 1.3, "%.2f s" % seconds)
	_t.check("the ball is live over the dam", not _game.player.frozen()
		and _game.player.ball_position().distance_to(_game.ctx.terrain.spawn_point(1)) < 30.0, str(_game.player.ball_position()))
	_t.check("the deck camera rush is cleared once the run is on", title_stage.push == 0.0, str(title_stage.push))
	flow.show_title()
	await _frames(2)
	title_stage.active = true
	# Each title poster frames at its own fov (W46-09); the rush widens it by the push's full span.
	var rest_fov: float = title_stage.camera.fov
	title_stage.launch_push(0.05)
	for i in 600:
		if title_stage.push >= 1.0:
			break
		await process_frame
	_t.check("launch_push rushes the deck camera in", title_stage.push >= 1.0 and title_stage.camera.fov > rest_fov + title_stage.PUSH_FOV - 2.0, "%s fov %s from %s" % [title_stage.push, title_stage.camera.fov, rest_fov])
	flow.show_title()
	await _frames(2)

	# The camp gate, live.
	_t.eq("the profile remembers the last pilot", _game.ctx.profile.last_pilot(), flow.classes[0].id)
	_game._screen_key(KEY_K)
	await _frames(3)
	var hub = _game.camp_hub
	var centre: Vector3 = hub.zone_position("gate")
	var toward: Vector3 = hub.root.global_position - centre
	toward.y = 0.0
	var spot: Vector3 = centre + toward.normalized() * 1.5
	spot.y = 1.3
	_game.player.reset_to(spot)
	_game.player.body().global_position = spot
	await _physics(4)
	_t.check("the ball is in the gate's zone", hub.inside("gate"), str(hub.inside_ids()))
	at_cover.clear()
	_game._screen_key(KEY_SPACE)
	_take.set_process(false)
	_t.check("the gate starts the take on the title", _take.phase == LaunchTake.WIND and flow.state_name() == "title", flow.state_name())
	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	_game.screens._input(esc)
	_t.check("Esc under the gate's wind does not leave the camp", _game.screens.walking() and hub.walking, "")
	await _physics(2)
	_t.check("the gate fires the ball up", _game.player.state.velocity.y > 5.0, str(_game.player.state.velocity))
	await _step_while(LaunchTake.WIND)
	await _step_while(LaunchTake.COVER)
	_t.check("the gate's run starts on stage 1 under the swipe", at_cover.size() == 1 and at_cover[0][0] == 1.0
		and flow.in_stage() and _game.run.stage == 1, str(at_cover))
	_t.check("the walk ended before the run placed the ball", not _game.screens.walking() and not hub.walking and not _game.player.frozen()
		and _game.player.ball_position().distance_to(_game.ctx.terrain.spawn_point(1)) < 30.0, str(_game.player.ball_position()))
	await _step_while(LaunchTake.HOLD)
	await _step_while(LaunchTake.REVEAL)
	_t.check("the gate's take ends", not _take.busy(), "")
	var line_layer: Node = hub.get_node_or_null("CampLineLayer")
	_t.check("the camp's line card does not follow the ball into the dam", line_layer != null and line_layer.get_child_count() == 0,
		str(line_layer.get_child_count()) if line_layer != null else "no layer")
	flow.show_title()
	await _frames(2)

	# A first run at the gate goes by pilot select, where the prologue plays.
	_game.screens.prologue_enabled = true
	_game.hud.profile.callouts_seen.erase("lore.prologue")
	if _game.screens.prologue_due():
		_game._screen_key(KEY_K)
		await _frames(3)
		_game.player.reset_to(spot)
		_game.player.body().global_position = spot
		await _physics(4)
		_game._screen_key(KEY_SPACE)
		await _frames(2)
		_t.check("a first run at the gate goes to pilot select with the prologue", flow.state_name() == "class_select"
			and _game.screens.prologue_showing() and not _take.busy(), flow.state_name())
		_game.screens.end_prologue()
		flow.show_title()
		await _frames(2)
	else:
		_t.check("the prologue was due for the fallback check", false, "seen already")
	_game.screens.prologue_enabled = false

	# Reduced motion: no wind, still lines.
	Comfort.reduced_motion = true
	flow.press_start()
	await _frames(2)
	_game._screen_key(KEY_1)
	_take.set_process(false)
	_t.check("reduced motion skips the wind", _take.phase == LaunchTake.COVER, str(_take.phase))
	_t.eq("reduced motion keeps the lines still", float(_take._material.get_shader_parameter("lines")), 0.0)
	await _step_while(LaunchTake.COVER)
	await _step_while(LaunchTake.HOLD)
	await _step_while(LaunchTake.REVEAL)
	_t.check("the reduced take still starts the run", flow.in_stage() and not _take.busy(), flow.state_name())
	Comfort.reduced_motion = false
	await _seam_tests()
	quit(_t.verdict())


# --- The stage seams (flow.gd, dam to flume and flume to the Slag Bowl) ---

const SEAM_LIMIT_S := 2.5
const SEAM_STEPS := 400


# One launch seen frame by frame: a hand on the controls (the take is live), the take stepped by hand beside the
# physics ticks, every frame noted. `early` plants a cut before the cover is full.
func _seam_run(early := false) -> Dictionary:
	var flow = _game.flow
	var from_stage: int = _game.run.stage
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	var frames := []
	_take.force_live = true
	flow._set_state(flow.GATES)
	_game.events.reward_chosen.emit("seam")
	_take.set_process(false)
	var started: bool = _take.busy() and _take.phase == LaunchTake.WIND and flow.state_name() == "launch"
	var lines := float(_take._material.get_shader_parameter("lines"))
	var steps := 0
	var cut_step := -1
	while steps < SEAM_STEPS:
		_take.advance(dt)
		await physics_frame
		steps += 1
		if early and steps == 4 and flow.state_name() == "launch":
			flow._finish_stage()
		var cut: bool = _game.run.stage != from_stage or flow.state_name() == "boss"
		if cut and cut_step < 0:
			cut_step = steps
		frames.append({"phase": _take.phase, "progress": _take.progress(), "cut": cut, "word": _take._word.visible})
		if not _take.busy():
			break
	return {"started": started, "frames": frames, "steps": steps, "dt": dt, "cut_step": cut_step,
		"lines": lines, "ended": not _take.busy(), "state": flow.state_name(), "stage": _game.run.stage}


# True when no frame shows the new place before the cover is full or the old place once the reveal has started.
func _seam_clean(run: Dictionary) -> bool:
	var revealing := false
	var saw_cut := false
	for f in run["frames"]:
		if f["phase"] == LaunchTake.REVEAL:
			revealing = true
		if f["cut"] and not saw_cut:
			saw_cut = true
			if f["progress"] < 1.0 or f["phase"] != LaunchTake.HOLD:
				return false
		if revealing and not f["cut"]:
			return false
	return saw_cut


func _seam_checks(label: String, run: Dictionary, reduced: bool) -> void:
	var seconds: float = float(run["steps"]) * float(run["dt"])
	_t.check("%s: the take starts on the launch" % label, run["started"], str(run["started"]))
	if not reduced:
		_t.check("%s: the lines turn in a full-motion take" % label, run["lines"] == 1.0, str(run["lines"]))
	_t.check("%s: the map changes under a full cover, never before or after" % label, _seam_clean(run), str(run["cut_step"]))
	_t.check("%s: at most %.1f s without control" % [label, SEAM_LIMIT_S], run["ended"] and seconds <= SEAM_LIMIT_S, "%.2f s" % seconds)
	if reduced:
		_t.check("%s: reduced motion keeps the lines still, as the camp swipe does" % label, run["lines"] == 0.0, str(run["lines"]))
	var full := -1
	var reveal := -1
	for i in run["frames"].size():
		var f: Dictionary = run["frames"][i]
		if full < 0 and f["progress"] >= 1.0:
			full = i + 1
		if reveal < 0 and f["phase"] == LaunchTake.REVEAL:
			reveal = i + 1
	var tick: float = run["dt"]
	var closing := -1
	var worded := 0
	for i in run["frames"].size():
		var f: Dictionary = run["frames"][i]
		if closing < 0 and f["progress"] > 0.0:
			closing = i + 1
		if f["word"]:
			worded += 1
	var flight: float = _game.flow.LAUNCH_FLIGHT
	_t.check("%s: the shot is on screen until the flight's last %.2f s" % [label, LaunchTake.COVER_S],
		closing * tick >= flight - LaunchTake.COVER_S - 0.001, "%.2f s" % (closing * tick))
	_t.check("%s: the cover is full as the flight ends" % label, full * tick >= flight - tick and full * tick <= flight + 3.0 * tick, "%.2f s" % (full * tick))
	_t.check("%s: the take stamps no second word over the launch's own" % label, worded == 0, str(worded))
	print("seam %s: %.2f s launch to the reveal's end; full cover at %.2f s, cut at %.2f s, reveal opens at %.2f s" % [label, seconds,
		full * tick, run["cut_step"] * tick, reveal * tick])


# A fresh run on stage 1 with the take not live (the pick starts the run at once).
func _fresh_run() -> void:
	var flow = _game.flow
	Comfort.reduced_motion = false
	_take.force_live = false
	flow.show_title()
	await _frames(2)
	flow.press_start()
	await _frames(2)
	_game._screen_key(KEY_1)
	await _frames(2)
	_game.ctx.calm = true


func _seam_tests() -> void:
	var flow = _game.flow
	await _fresh_run()
	_t.check("the seam test starts on stage 1", flow.in_stage() and _game.run.stage == 1, flow.state_name())

	# A bot (not live): no take, the cut falls on the flight's last tick, the events fall as they always did.
	var order := []
	var on_launched := func(_v): order.append("launched")
	var on_cleared := func(_s): order.append("cleared")
	var on_entered := func(_s, _r): order.append("entered")
	_game.events.launched.connect(on_launched)
	_game.events.stage_cleared.connect(on_cleared)
	_game.events.stage_entered.connect(on_entered)
	flow._set_state(flow.GATES)
	_game.events.reward_chosen.emit("bot")
	var ticks := 0
	var busy_seen := false
	while _game.run.stage == 1 and ticks < 200:
		await physics_frame
		ticks += 1
		busy_seen = busy_seen or _take.busy()
	var expect := 0
	var flown := 0.0
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	while flown < flow.LAUNCH_FLIGHT:
		flown += dt
		expect += 1
	_t.check("a bot's launch plays no take", not busy_seen and not _take.busy(), "")
	_t.check("a bot's launch cuts on the flight's last tick as on the base", absi(ticks - expect) <= 1, "%d ticks, base %d" % [ticks, expect])
	_t.check("a bot's events keep their order", order == ["launched", "cleared", "entered"], str(order))
	_game.events.launched.disconnect(on_launched)
	_game.events.stage_cleared.disconnect(on_cleared)
	_game.events.stage_entered.disconnect(on_entered)

	# Dam to flume with a hand on the controls.
	await _fresh_run()
	var first: Dictionary = await _seam_run()
	_seam_checks("dam to flume", first, false)
	_t.check("dam to flume lands on stage 2", _game.run.stage == 2 and flow.in_stage(), flow.state_name())

	# The planted case: a cut fired four steps in, under a half-closed cover, must be caught by the same check.
	await _fresh_run()
	var planted: Dictionary = await _seam_run(true)
	_t.check("planted: a cut before the cover is full is caught", not _seam_clean(planted), str(planted["cut_step"]))

	# Reduced motion, same seam.
	await _fresh_run()
	Comfort.reduced_motion = true
	var reduced: Dictionary = await _seam_run()
	_seam_checks("reduced motion", reduced, true)

	# Flume to the Slag Bowl, when the table ends this world with its boss.
	await _fresh_run()
	await _seam_run()
	await _frames(2)
	var bowl: Dictionary = await _seam_run()
	_t.check("the second launch reaches the Slag Bowl", flow.state_name() == "boss", flow.state_name())
	_seam_checks("flume to the Slag Bowl", bowl, false)
	Comfort.reduced_motion = false
