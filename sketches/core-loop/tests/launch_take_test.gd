extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const LaunchTake := preload("res://src/presentation/launch_take.gd")
const HighdraftFx := preload("res://src/presentation/highdraft_fx.gd")
const T := preload("res://tests/support/t.gd")

# The launch take (launch_take.gd, world 1 unit 17) on the real game:
#   - not live (tests, bots, headless), a play runs its cover call at once and shows nothing;
#   - pilot select: the pick waits under the wind, keys are swallowed, the run starts on the first fully covered frame
#     and the panel never shows the cut, then sweeps off; the deck camera rushes in during the wind;
#   - the camp gate fires the ball up and out of the gate, then the run starts on stage 1 with the gate's pilot;
#   - a first run (prologue due) at the gate goes to pilot select instead;
#   - a stage launch: the swipe starts from the cover near the flight's end and the next stage is entered under it;
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
	title_stage.launch_push(0.05)
	for i in 600:
		if title_stage.push >= 1.0:
			break
		await process_frame
	_t.check("launch_push rushes the deck camera in", title_stage.push >= 1.0 and title_stage.camera.fov > 70.0, "%s fov %s" % [title_stage.push, title_stage.camera.fov])
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

	# A stage launch, live: the flight is the wind, the swipe crosses as it ends, the next stage is entered under it.
	_take.force_live = false
	flow.press_start()
	await _frames(2)
	_game._screen_key(KEY_1)
	await _frames(3)
	_t.check("a run on stage 1 for the stage launch", flow.in_stage() and _game.run.stage == 1, flow.state_name())
	_take.force_live = true
	at_cover.clear()
	flow._set_state(flow.LAUNCH)
	flow._on_launched(Vector3.ZERO)
	for i in 120:
		if _take.busy():
			_take.set_process(false)
			break
		await physics_frame
	_t.check("the swipe starts as the flight nears its end, from the cover", _take.phase == LaunchTake.COVER and flow.state_name() == "launch"
		and flow._flight >= flow.LAUNCH_FLIGHT - flow.CUT_LEAD - 0.05, "%s %s %.2f" % [_take.phase, flow.state_name(), flow._flight])
	await _physics(60)
	_t.check("the flight waits for the cover", flow.state_name() == "launch" and _game.run.stage == 1 and at_cover.is_empty(), "%s stage %d cover %s phase %d flight %.2f" % [flow.state_name(), _game.run.stage, at_cover, _take.phase, flow._flight])
	_t.check("a flight past LAUNCH_FLIGHT keeps the velocity it had then", flow._cut_velocity != null, "%s" % [flow._cut_velocity])
	await _step_while(LaunchTake.COVER)
	_t.check("the next stage is entered on the fully covered frame", at_cover.size() == 1 and at_cover[0][0] == 1.0
		and flow.in_stage() and _game.run.stage == 2, "%s stage %d" % [at_cover, _game.run.stage])
	await _step_while(LaunchTake.HOLD)
	await _step_while(LaunchTake.REVEAL)
	_t.check("the stage launch's take ends", not _take.busy(), "")
	# Not live (bots, tests, headless): the flight ends at LAUNCH_FLIGHT with cover_cut installed, as before.
	_take.force_live = false
	flow._set_state(flow.LAUNCH)
	flow._on_launched(Vector3.ZERO)
	var ticks := 0
	while flow.state_name() == "launch" and ticks < 200:
		await physics_frame
		ticks += 1
	var tick := 1.0 / Engine.physics_ticks_per_second
	_t.check("a launch that is not live ends at LAUNCH_FLIGHT", flow.state_name() != "launch" and not _take.busy()
		and absf(ticks * tick - flow.LAUNCH_FLIGHT) <= 2.0 * tick + 0.001, "stage %d ticks %d state %s" % [_game.run.stage, ticks, flow.state_name()])
	# A boss's victory into the next world's first stage, live: the swipe crosses as the victory ends.
	if flow.state_name() == "boss":
		var run_last: bool = flow.ctx.stages.is_run_last(_game.run.stage)
		var boss_stage: int = _game.run.stage
		_take.force_live = true
		at_cover.clear()
		flow._on_boss_defeated()
		flow._victory_left = 0.5
		for i in 120:
			if _take.busy() or flow.state_name() != "victory":
				_take.set_process(false)
				break
			await physics_frame
		if run_last:
			_t.check("the run's last victory plays no swipe", not _take.busy(), "%s" % flow.state_name())
		else:
			_t.check("a victory's swipe starts from the cover before it ends", _take.phase == LaunchTake.COVER and flow.state_name() == "victory"
				and flow._victory_left <= flow.CUT_LEAD + 0.05, "%s %s %.2f" % [_take.phase, flow.state_name(), flow._victory_left])
			await _physics(60)
			_t.check("the victory waits for the cover", flow.state_name() == "victory" and at_cover.is_empty() and flow._cut_velocity != null, "%s %s" % [flow.state_name(), at_cover])
			await _step_while(LaunchTake.COVER)
			_t.check("the next world is entered on the fully covered frame", at_cover.size() == 1 and flow.in_stage()
				and _game.run.stage == boss_stage + 1, "%s stage %d" % [at_cover, _game.run.stage])
			await _step_while(LaunchTake.HOLD)
			await _step_while(LaunchTake.REVEAL)
			_t.check("the victory's take ends", not _take.busy(), "")
		_take.force_live = false
	else:
		_t.check("the not-live launch reached a boss for the victory case", false, flow.state_name())
	flow.show_title()
	await _frames(2)

	# Reduced motion: no wind, still lines.
	_take.force_live = true
	HighdraftFx.preferred = true
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
	HighdraftFx.preferred = false
	quit(_t.verdict())
