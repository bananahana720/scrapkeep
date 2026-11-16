extends SceneTree

# Before and after stills for PR 1077's visible twins of four sounds (W1-108): the yard's wave
# whistle, overtime's whistle, the rogue's cue and the heat kettle. The real game on the dam, the
# chase camera and the HUD; the same seed and camera in both checkouts, so a pair differs only
# where the game does. Run it once in each checkout (the tool file is copied, uncommitted, into
# the older one):
#   scratch/w43-pc/gpu-run.sh <worktree> <data name> --path sketches/core-loop \
#     --script res://tools/twin_stills.gd -- --out=<abs dir> --side=before|after
# --side says which game this is. "after" demands every twin is there; "before" demands none is
# (the cross, the cue's brass core, the kettle flash), so a wrong checkout stops the run.
#
# Stills (<out>/<id>.png; frames.json holds the game state that proves each moment):
#   yard-half       a shut yard between waves, half the wave gap left before the next crew lands
#   yard-late       the same wait, under a tenth of a second before the landing
#   overtime-land   the tick after the bell lands overtime's crew; the cross is held over the drops
#   rogue-cue       the physics tick the rogue enters its cue state, the cue sounding on that tick
#   kettle-high     redline shell in the fuse's last 2 s at the beat's high (kettle_pulse near 1)
#   kettle-low      the same, at a low of the beat (near 0)
#   kettle-reduce   the low's moment with Reduce flashes on (the beat held at full)
# The tool stops with an error and keeps no still for a moment it did not reach: yard not shut or
# not between waves, overtime crew not landed, rogue not in its cue, kettle window not live.
# The kettle's moments are set on the shell's own fuse and drawn through player_fx; the rogue's
# cue is stepped by hand on one physics tick, as the cue test does. Everything else is the game's
# own flow. A software or gamescope renderer is no judge of final look.

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Telegraph := preload("res://src/combat/telegraph.gd")
const Rogue := preload("res://src/combat/rogue.gd")
const Redline := preload("res://src/combat/redline.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")
const LockRows := preload("res://src/world/lock_rows.gd")
const MossBubble := preload("res://src/ui/moss_bubble.gd")

# The kettle's window and beat as redline.gd sets them; held here so the older checkout, which has
# neither, is taken at the same moments.
const KETTLE_S := 2.0
const KETTLE_HZ := Vector2(4.0, 10.0)
const SETTLE := 45
const WAIT_TICKS := 2400
const QUIET_TICKS := 900
const LANDED := 1.6
# The beat's phase (redline.gd kettle_pulse) is 4 t + 1.5 t^2 over t seconds into the window:
# a whole number is a high, a half a low. These are the phases the stills take.
const HIGH_PHASE := 3.0
const LOW_PHASE := 4.5

var game
var out := ""
var side := ""
var records := []
var failed := ""
var _bubble: Node
var _facts := {}


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--side="):
			side = arg.trim_prefix("--side=")
	if out.is_empty() or not side in ["before", "after"] or DisplayServer.get_name() == "headless":
		push_error("twin_stills: needs --out=<abs dir>, --side=before|after and a display")
		quit(2)
		return
	if DirAccess.make_dir_recursive_absolute(out) != OK:
		quit(3)
		return
	_run.call_deferred()


func _run() -> void:
	seed(1)
	game = Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	var waited := 0
	while game.flow == null and waited < 600:
		waited += 1
		await physics_frame
	if game.flow == null:
		return _fail("the game never built its flow")
	game.player.tuning.apply_args(PackedStringArray(["--overtime=on"]))
	game.events.world_fact.connect(func(kind: String, _at: Vector3): _facts[kind] = int(_facts.get(kind, 0)) + 1)
	game.flow.press_start()
	game.flow.choose_class(0)
	for i in 8:
		await physics_frame
	game.ctx.calm = true
	game.run.set_max_hp(999999.0)
	game.player.source = Intent.Scripted.new()
	var ground = game.ctx.spawner.ground
	var down := 0
	for i in WAIT_TICKS:
		await physics_frame
		var p: Vector3 = game.player.ball_position()
		down = down + 1 if p.y - Telegraph.ground_under(ground, p) < LANDED else 0
		if down >= 30:
			break
	if down < 30:
		return _fail("the ball never landed")
	if game.hud.get("first_steps") != null:
		game.hud.first_steps.modulate.a = 0.0
	var spot: Vector3 = game.player.ball_position()
	var ahead := _flat(game.flow.beacon.global_position - spot)
	await _place(spot, ahead)
	await _quiet()

	await _kettle(spot, ahead)
	if failed == "":
		await _rogue(ground, spot, ahead)
	if failed == "":
		await _yard_and_overtime()
	if failed != "":
		return
	var file := FileAccess.open(out.path_join("frames.json"), FileAccess.WRITE)
	if file == null:
		quit(3)
		return
	var size := root.get_visible_rect().size
	file.store_string(JSON.stringify({"tool": "twin_stills.gd", "side": side, "size": [size.x, size.y],
		"adapter": RenderingServer.get_video_adapter_name(), "frames": records,
		"limits": "Same seed and camera in both checkouts, but enemy timing and the ball's exact spot are the game's own; the state recorded per still is what proves the moment. The kettle's fuse and the rogue's cue are set by hand on the game's own objects. Size, place and read only; not final look or sound."}, "\t"))
	file.close()
	quit(0)


# --- the heat kettle ----------------------------------------------------------------------
# The shell at redline with the fuse in its last 2 s, drawn through player_fx while the game is
# held. The beat's value is computed here from the fuse as redline.gd does, so the "before"
# checkout (which has no kettle_pulse) is still taken at the same moment.
func _kettle(spot: Vector3, ahead: Vector3) -> void:
	var red = game.player.get("redline")
	var fx = game.presentation.get("player_fx")
	if red == null or fx == null:
		return _fail("the game has no redline shell or no shell fx")
	await _place(spot, ahead)
	red.set_mode(Redline.ON)
	red.value = Redline.MAX
	fx._shell_band = 3
	var high_t := _t_at_phase(HIGH_PHASE)
	var low_t := _t_at_phase(LOW_PHASE)
	for case in [["kettle-high", high_t, false, 0.97, 1.0], ["kettle-low", low_t, false, 0.0, 0.03], ["kettle-reduce", low_t, true, 0.0, 0.03]]:
		var id: String = case[0]
		paused = true
		FlashGuard.on = case[2]
		red.value = Redline.MAX
		red.waited = Redline.COOK_OFF_S - KETTLE_S + float(case[1])
		fx._draw_overdrive(0.016)
		var left: float = red.fuse_left()
		var pulse := _pulse(KETTLE_S - left)
		var game_pulse = red.kettle_pulse() if red.has_method("kettle_pulse") else null
		var live: bool = red.kettle_live() if red.has_method("kettle_live") else (left > 0.0 and left <= KETTLE_S)
		if not live:
			return _fail("%s: the kettle window is not live (fuse left %s)" % [id, str(left)])
		if pulse < float(case[3]) or pulse > float(case[4]):
			return _fail("%s: the beat is %s, not in %s to %s" % [id, str(pulse), str(case[3]), str(case[4])])
		if side == "after" and (game_pulse == null or absf(float(game_pulse) - pulse) > 0.001):
			return _fail("%s: the game's kettle_pulse %s differs from the fuse's %s" % [id, str(game_pulse), str(pulse)])
		if side == "before" and (red.has_method("kettle_pulse") or red.has_method("kettle_live")):
			return _fail("%s: this checkout already has the kettle twin" % id)
		var rim: Color = fx._rim_mat.get_shader_parameter("rim")
		if not fx._rim.visible:
			return _fail("%s: the shell's rim is not drawn" % id)
		var base_rim: Color = fx.shell_color(red)
		var toward_hazard := absf(rim.r - base_rim.r) + absf(rim.g - base_rim.g) + absf(rim.b - base_rim.b)
		if side == "after" and pulse > 0.9 and toward_hazard < 0.2:
			return _fail("%s: the rim shows no hazard colour at the beat's high" % id)
		if side == "before" and toward_hazard > 0.001:
			return _fail("%s: the rim is not the plain shell colour" % id)
		await _shot(id, {"fuse_left": snappedf(left, 0.001), "kettle_pulse_from_fuse": snappedf(pulse, 0.001),
			"kettle_pulse_game": snappedf(float(game_pulse), 0.001) if game_pulse != null else null,
			"flash_guard_on": FlashGuard.on, "rim": [rim.r, rim.g, rim.b], "heat": fx._rim_mat.get_shader_parameter("heat")})
		paused = false
		if failed != "":
			return
	FlashGuard.on = false
	red.clear()
	red.set_mode(Redline.OFF)
	fx._shell_band = 0
	await _ticks(3)


# Seconds into the window at which the beat's phase is `phase`: 1.5 t^2 + 4 t = phase.
static func _t_at_phase(phase: float) -> float:
	return (-4.0 + sqrt(16.0 + 6.0 * phase)) / 3.0


static func _pulse(t: float) -> float:
	var phase := t * KETTLE_HZ.x + 0.5 * t * t / KETTLE_S * (KETTLE_HZ.y - KETTLE_HZ.x)
	return 0.5 + 0.5 * cos(TAU * phase)


# --- the rogue's cue ----------------------------------------------------------------------
func _rogue(ground, spot: Vector3, ahead: Vector3) -> void:
	await _place(spot, ahead)
	var kind: String = Rogue.ROWS.keys()[0]
	var at: Vector3 = _on(ground, spot + ahead * 14.0) + Vector3.UP * 1.0
	var rogue = game.ctx.spawner.spawn_enemy(kind, at)
	if rogue == null:
		return _fail("the rogue did not spawn")
	await _ticks(30)
	rogue.set_physics_process(false)
	rogue.live = func(): return true
	var cued := []
	game.events.attack_cued.connect(func(fight: String, attack: String, _s: float): cued.append([fight, attack]))
	rogue.enter_phase(2)
	rogue._enter(Rogue.State.STALK)
	rogue._begin_attack(spot - rogue.global_position)
	rogue.state = Rogue.State.STRIKE
	rogue._clock = 99.0
	# The tick the game enters its cue: the sound's signal fires on this call, and so does the twin.
	rogue._physics_process(0.016)
	paused = true
	if rogue.state != Rogue.State.CUE or cued.size() != 1:
		paused = false
		return _fail("rogue-cue: the rogue is in %s with %d cues sounded" % [rogue.state_name(), cued.size()])
	if rogue._core == null:
		return _fail("rogue-cue: the rogue has no core")
	var showing: bool = rogue.cue_showing() if rogue.has_method("cue_showing") else false
	if side == "after" and not showing:
		return _fail("rogue-cue: the core does not show the cue on the cue's tick")
	if side == "before" and (showing or rogue.has_method("cue_showing")):
		return _fail("rogue-cue: this checkout already has the cue twin")
	var core: Color = (rogue._core.material_override as BaseMaterial3D).albedo_color if rogue._core.material_override is BaseMaterial3D else Color.BLACK
	await _shot("rogue-cue", {"rogue_state": rogue.state_name(), "cues_sounded": cued.size(), "cue_showing": showing,
		"core_scale": snappedf(rogue._core.scale.x, 0.01), "core_albedo": [core.r, core.g, core.b], "rogue_kind": kind})
	paused = false
	rogue._clear_telegraph()
	rogue.free()
	await _ticks(4)


# --- the yard's wave whistle, then overtime's ------------------------------------------------
func _yard_and_overtime() -> void:
	var locks = game.flow.gate
	var row: Dictionary = LockRows.row("park_dam")["lock"]
	var beacon: Vector3 = game.flow.beacon.global_position
	var arm := beacon + Vector3(0.0, 0.0, -float(row["within_m"]) * 0.75 + 10.0)
	var body = game.player.body()
	body.freeze = false
	game.player.reset_to(game.ctx.terrain.drop_point(arm.x, arm.z, 1.0), Vector3.ZERO)
	var waited := 0
	while locks.lock_state == "armed" and waited < 600:
		await physics_frame
		waited += 1
	if locks.lock_state != "locked":
		return _fail("the yard never shut (state %s)" % locks.lock_state)
	# The ball stands inside the wall looking at where the next crew will land.
	# The next wave lands round the ring, centred on this heading (the members fan evenly either side).
	var turn: float = locks._facing + 0.6 * PI * float(locks._wave + 1)
	var heading := Vector3(cos(turn), 0.0, sin(turn))
	var stand: Vector3 = game.ctx.terrain.drop_point(locks.lock_centre.x - heading.x * 6.0, locks.lock_centre.z - heading.z * 6.0, 1.0)
	await _place(stand, heading)
	# Strike the first wave down; the whistle is the tick the wait starts.
	var ticks := 0
	while locks._wave_wait < 0.0 and ticks < WAIT_TICKS:
		for enemy in locks.crew_alive():
			game.ctx.spawner.strike(enemy, "ram", 1000000.0)
		await physics_frame
		ticks += 1
	if locks._wave_wait < 0.0:
		return _fail("the first wave was never struck down, so no whistle")
	var gap := float(row["wave_gap_s"])
	ticks = 0
	while locks._wave_wait > gap * 0.5 and locks._wave_wait >= 0.0 and ticks < WAIT_TICKS:
		await physics_frame
		ticks += 1
	paused = true
	if not await _yard_shot("yard-half", locks, gap * 0.4, gap * 0.6):
		return
	paused = false
	ticks = 0
	while locks._wave_wait > 0.05 and locks._wave_wait >= 0.0 and ticks < WAIT_TICKS:
		await physics_frame
		ticks += 1
	paused = true
	if not await _yard_shot("yard-late", locks, 0.0, 0.1):
		return
	paused = false
	# Win the yard for real, then ring the overtime bell.
	ticks = 0
	while locks.lock_state != "spent" and ticks < 60 * Engine.physics_ticks_per_second:
		for enemy in locks.crew_alive():
			game.ctx.spawner.strike(enemy, "ram", 1000000.0)
		await physics_frame
		ticks += 1
	var ot = locks.overtime
	if locks.lock_state != "spent" or not locks.lock_won or ot.state != "offered":
		return _fail("overtime-land: the yard was not won into an offer (lock %s, won %s, overtime %s)" % [locks.lock_state, str(locks.lock_won), ot.state])
	var facing := Vector3(cos(ot._facing), 0.0, sin(ot._facing)).normalized()
	var base: Vector3 = ot.centre - facing * 8.0
	await _place(game.ctx.terrain.drop_point(base.x, base.z, 1.0), facing)
	var whistles_before := int(_facts.get("arena_wave", 0))
	if not ot.ring():
		return _fail("overtime-land: the bell did not land a crew")
	await physics_frame
	paused = true
	var marks = ot.get_node_or_null("ArenaWaveMarks")
	var crew: int = ot.crew_alive().size()
	var whistles := int(_facts.get("arena_wave", 0)) - whistles_before
	if crew == 0 or whistles != 1:
		paused = false
		return _fail("overtime-land: %d crew landed, %d whistles sounded" % [crew, whistles])
	if side == "after" and (marks == null or marks.get_child_count() != crew):
		paused = false
		return _fail("overtime-land: the cross is not held over the %d drop spots" % crew)
	if side == "before" and marks != null:
		paused = false
		return _fail("overtime-land: this checkout already holds a cross")
	await _shot("overtime-land", {"overtime_state": ot.state, "rings": ot.rings, "crew_landed": crew, "whistles_sounded": whistles,
		"cross_marks": marks.get_child_count() if marks != null else 0})
	paused = false


# The yard's wait between waves, proven before the still is kept.
func _yard_shot(id: String, locks, low: float, high: float) -> bool:
	var left: float = locks._wave_wait
	var marks: bool = locks.has_wave_marks() if locks.has_method("has_wave_marks") else false
	var problem := ""
	if locks.lock_state != "locked":
		problem = "the yard is %s, not shut" % locks.lock_state
	elif left < low or left > high:
		problem = "the wait left is %s, not in %s to %s" % [str(left), str(low), str(high)]
	elif not locks.crew_alive().is_empty():
		problem = "a crew is still standing"
	elif side == "after" and not marks:
		problem = "the cross is not up"
	elif side == "before" and (marks or locks.has_method("has_wave_marks")):
		problem = "this checkout already has the cross"
	if problem != "":
		paused = false
		_fail("%s: %s" % [id, problem])
		return false
	await _shot(id, {"wave_index": locks._wave, "next_wave_index": locks._wave + 1, "wait_left_s": snappedf(left, 0.001),
		"wait_total_s": float(locks.lock_row().get("wave_gap_s", 0.0)), "lock_state": locks.lock_state, "cross_up": marks})
	return failed == ""


# --- shared ----------------------------------------------------------------------------------
func _shot(id: String, proof: Dictionary) -> void:
	if failed != "":
		return
	await _frames(3)
	await RenderingServer.frame_post_draw
	var path := out.path_join("%s.png" % id)
	if root.get_texture().get_image().save_png(path) != OK:
		return _fail("could not save %s" % path)
	proof["id"] = id
	proof["crew_line"] = _speaking()
	proof["sha256"] = FileAccess.get_sha256(path)
	records.append(proof)


func _place(point: Vector3, heading: Vector3, settle := SETTLE) -> void:
	var body = game.player.body()
	body.freeze = false
	game.player.reset_to(point)
	await _ticks(2)
	body.freeze = true
	game.camera.snap(heading)
	await _frames(settle)


func _quiet() -> void:
	await _ticks(QUIET_TICKS)
	var down := 0
	for i in WAIT_TICKS:
		if _speaking():
			_bubble.dismiss_exchange()
			_bubble.hush()
		down = 0 if _speaking() else down + 1
		if down >= 2 * Engine.physics_ticks_per_second:
			return
		await physics_frame


func _speaking() -> bool:
	if _bubble == null:
		for node in game.find_children("*", "Control", true, false):
			if node.get_script() == MossBubble:
				_bubble = node
				break
	return is_instance_valid(_bubble) and _bubble.showing()


func _fail(why: String) -> void:
	if failed != "":
		return
	failed = why
	push_error("twin_stills: %s" % why)
	paused = false
	quit(4)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z).normalized()


static func _on(ground, point: Vector3) -> Vector3:
	return Vector3(point.x, Telegraph.ground_under(ground, point), point.z)
