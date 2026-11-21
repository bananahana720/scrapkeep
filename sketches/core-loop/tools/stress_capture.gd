extends SceneTree

const Game := preload("res://src/game.gd")
const BotDriver := preload("res://tools/bot_driver.gd")
const Parts := preload("res://src/build/parts.gd")
const Telegraph := preload("res://src/combat/telegraph.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const Palette := preload("res://src/core/palette.gd")
const WordBudget := preload("res://src/ui/word_budget.gd")
const Vfx := preload("res://src/presentation/vfx.gd")
const Bolts := preload("res://src/combat/bolts.gd")
const Warden := preload("res://src/combat/warden.gd")
const Director := preload("res://src/world/director.gd")
const WorldLook := preload("res://src/presentation/world_look.gd")
const PlayerFx := preload("res://src/presentation/player_fx.gd")

# Dense-scene diagnostic. Synthetic attacks do not establish gameplay or human readability.
# Does a hostile telegraph stay readable when the screen fills, and what do the effect
# counts and frame times look like? Three scenes on stage 1 (or --stage=N) as Rivet with a stacked build:
#   S1  1 pack, no extra telegraphs (baseline)
#   S2  3 packs, 4 committed telegraphs of each hostile type around the ball
#   S3  6 packs, 8 of each type, and the stage's Warden moved in front and charging
# A pack is a director PACKS row (controller + punisher) plus two chasers.
# After four seconds of warmup, time 240 live frames while preserving the fixture load.
# Then pause and save six paired images to isolate P1 edges from fills and scenery.
# Needs imported assets and a real display; see FEEL-READABILITY.md section 6.3.
# Options, all after `--`: --out=<dir> (required), --stage, --calm, --dry, --size, --timeout and
# --impact=hold (forces impact-frame fires in the sample phase so impact_ms_per_fire is read
# from real fires; opt-in, notes at --calm below).
# --dry=1 skips readback and writes schema/control-flow evidence only, never pixels or
# valid performance evidence. Synthetic attacks recycle and do not resolve damage.

const PLAY_SECONDS := 4.0
const COMMIT_BEFORE := 1.4
const SAMPLE_FRAMES := 240
const HARD_TIMEOUT := 120.0
const SCENES := [
	{"id": "s1", "packs": 1, "per_type": 0, "warden": false},
	{"id": "s2", "packs": 3, "per_type": 4, "warden": false},
	{"id": "s3", "packs": 6, "per_type": 8, "warden": true},
]
const PACK_ORDER := ["grounded", "strung", "netted", "rebound", "reeled", "wobble", "flung", "cupped"]
const EXTRA_COPIES := ["spiral_wave", "chain_arc", "cross_split", "gatling_heart", "double_feed", "arc_coil"]
# HAZARD family: hue within HUE_TOL of HAZARD, saturation over SAT_MIN, value over VAL_MIN.
const HUE_TOL := 12.0
const SAT_MIN := 0.5
const VAL_MIN := 0.25
# A run is strong when S3's differential mask holds at least this many candidate pixels, so the
# P1 bar reads straight from the file (ruling #241 comment 6332468877).
const STRONG_MIN := 50000
const RIVET_SEED := 1
# --impact=hold: the shortest gap between forced fires, the game's own rate limit.
const IMPACT_HOLD_PERIOD_S := PlayerFx.FRAME_GAP_S

var _out := ""
var _game
var _driver
var _start_usec := 0
var _phase := "boot"
var _phase_usec := 0
var _scene_index := -1
var _scene_spawned: Array = []
var _scene_threats: Array = []
var _busy := false
var _granted: Array = []
var _results: Array = []
var _frames: Array = []
var _pre_frames: Array = []
var _last_usec := 0
var _committed := false
var _warden_note := ""
var _spawned_at_start := {}
# PlayerFx impact-frame counters when the sample window opened (see _impact_counters).
var _impact_at_sample := [0, 0, 0, 0, 0]
var _images := {}
var _render_rid: RID
var _dry := false
var _load_slots: Array = []
var _count_samples: Array = []
var _errors: Array = []
# --stage=N (1..6) runs the scenes on that stage of the launched park table and tags every
# output file "stN-"; absent, the run is stage 1 of the default table with untagged names.
# --timeout=<seconds> and --size=WxH (default 1920x1080) are for slow software renderers.
# --calm=1 holds no fire and no roll, so no hit bursts or speed lines reach the frame; the
# telegraphs, packs and light are the same. It tags outputs "calm-" (the dusk P1 split, #241).
# Contact hits can still fire impact frames under calm (measured: 3 and 6 fires in two scenes).
# --impact=hold forces impact frames during the sample phase, so impact_ms_per_fire reads from
# real fires over the scene's live warnings (the 4080 read for lighting L7, #297): each scene
# asks PlayerFx.impact_frame (at the ball, strength 1.0) every IMPACT_HOLD_PERIOD_S of
# sample time, the shortest gap the game itself allows (PlayerFx.FRAME_GAP_S; a gated ask
# retries on the next frame). The scene's synthetic telegraphs are the warnings: S2 holds 16
# and S3 32, plus the packs' own. Each result then also carries "impact_hold": forced fires,
# the period and the fewest and most hostile marks (Threat.GROUP) standing at a fire. Opt-in:
# absent, no fire is forced, no field is added and the output names are as before; present,
# outputs are tagged "impact-". Meaningful only on a rendered display, like the rest of the tool.
var _stage := 1
var _staged := false
var _entered := false
var _table := ""
var _tag := ""
var _timeout := HARD_TIMEOUT
var _size := Vector2i(1920, 1080)
var _calm := false
var _impact_hold := false
var _impact_clock := 0.0
# Hostile marks standing at each forced fire, this scene.
var _impact_marks: Array = []


func _initialize() -> void:
	var settings := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and "=" in arg:
			settings[arg.substr(2, arg.find("=") - 2)] = arg.substr(arg.find("=") + 1)
	# --dry=1 runs the logic headless with blank stills, to check the script before the
	# one display run; its numbers are meaningless.
	_dry = settings.get("dry", "0") == "1"
	if (DisplayServer.get_name() == "headless" and not _dry) or not settings.has("out"):
		printerr("stress_capture: needs a rendered display and -- --out=<absolute dir>")
		quit(2)
		return
	_out = settings["out"]
	var dims: PackedStringArray = String(settings.get("size", "1920x1080")).split("x")
	if dims.size() == 2 and dims[0].is_valid_int() and dims[1].is_valid_int():
		_size = Vector2i(int(dims[0]), int(dims[1]))
	var timeout: String = settings.get("timeout", "")
	_timeout = float(timeout) if timeout.is_valid_float() and float(timeout) > 0.0 else HARD_TIMEOUT
	if settings.has("stage"):
		var wanted: String = settings["stage"]
		if not wanted.is_valid_int() or int(wanted) < 1 or int(wanted) > 6:
			printerr("stress_capture: --stage must be 1..6")
			quit(2)
			return
		_stage = int(wanted)
		_staged = true
		_tag = "st%d-" % _stage
		_table = "park"
	_table = settings.get("table", _table)
	_calm = settings.get("calm", "0") == "1"
	if _calm:
		_tag += "calm-"
	_impact_hold = settings.get("impact", "") == "hold"
	if _impact_hold:
		_tag += "impact-"
	if not _out.is_absolute_path() or DirAccess.make_dir_recursive_absolute(_out) != OK:
		printerr("stress_capture: --out must be an absolute writable directory")
		quit(2)
		return
	if settings.get("self-test", "0") == "1":
		_metric_self_test()
		return
	root.size = _size
	root.content_scale_size = _size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_render_rid = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_render_rid, true)
	for asset in ["shell_sable", "shell_rivet", "shell_kest"]:
		if load("res://assets/models/" + asset + ".glb") == null:
			printerr("stress_capture: import this project with --headless --editor --import first")
			quit(2)
			return
	seed(RIVET_SEED)
	_game = Game.new()
	_game.test_mode = true
	if not _table.is_empty():
		_game.table = _table
	root.add_child(_game)
	_start_usec = Time.get_ticks_usec()


func _seconds_since(usec: int) -> float:
	return (Time.get_ticks_usec() - usec) / 1000000.0


func _process(delta: float) -> bool:
	var now := Time.get_ticks_usec()
	var dt_ms := (now - _last_usec) / 1000.0 if _last_usec > 0 else 0.0
	_last_usec = now
	if _seconds_since(_start_usec) > _timeout:
		_finish("timeout")
		return false
	if _game == null or _game.flow == null or _busy:
		return false
	match _phase:
		"boot":
			_driver = BotDriver.new(_game, "skipper", RIVET_SEED)
			_driver.start()
			_phase = "drop"
			_phase_usec = now
		"drop":
			if _staged and _stage != 1 and not _entered and _game.flow.in_stage() and _seconds_since(_phase_usec) > 1.5:
				# The start lands on stage 1; once it has settled, move the run to stage N and settle again.
				_entered = true
				_game.flow.enter_stage(_stage, Vector3.ZERO, false)
				_phase_usec = now
			elif _game.flow.in_stage() and _seconds_since(_phase_usec) > 1.5 and (not _staged or _stage == 1 or _entered):
				_grant()
				_phase = "warm"
				_phase_usec = now
		"warm":
			if _seconds_since(_phase_usec) > 2.0:
				_next_scene()
		"play":
			_maintain_load()
			_pre_frames.append(_sample(dt_ms))
			_step_threats(delta)
			var t := _seconds_since(_phase_usec)
			if not _committed and t >= PLAY_SECONDS - COMMIT_BEFORE:
				_committed = true
				_commit_threats(SCENES[_scene_index])
			if t >= PLAY_SECONDS:
				_phase = "sample"
				_last_usec = now
				_impact_open()
		"sample":
			_maintain_load()
			_step_threats(delta)
			_frames.append(_sample(dt_ms))
			_count_samples.append(_counts())
			_hold_impact(delta)
			if _frames.size() >= SAMPLE_FRAMES:
				_busy = true
				_capture()
	return false


func _physics_process(_delta: float) -> bool:
	if _game == null or _game.run == null or _driver == null or paused:
		return false
	# The run must survive the stress: HP is topped up every tick (a harness write).
	_game.run.hp = _game.run.max_hp
	if _phase == "play" or _phase == "sample" or _phase == "warm":
		_hold_fire()
		if _phase in ["play", "sample"]:
			_maintain_load()
	return false


# Fire held, a slow roll forward, the camera turned toward the nearest non-Warden enemy
# the way bot_driver._look turns it (mouse pixels through camera.look).
func _hold_fire() -> void:
	var hold := {"fire_held": not _calm, "move": Vector2.ZERO if _calm else Vector2(0.25, 0.25)}
	_driver.source.hold = hold
	var ball: Vector3 = _game.player.ball_position()
	var best: Node3D = null
	var best_d := INF
	for node in get_nodes_in_group("enemy"):
		if not (node is Node3D) or not is_instance_valid(node) or node is Warden:
			continue
		var d := ball.distance_to((node as Node3D).global_position)
		if d < best_d and d < 40.0:
			best_d = d
			best = node
	if best == null:
		return
	var cam = _game.camera
	var flat := best.global_position - ball
	flat.y = 0.0
	if flat.length() < 0.3:
		return
	var step := 5.0 / Engine.physics_ticks_per_second
	var want := atan2(-flat.x, -flat.z)
	var dyaw := clampf(wrapf(want - cam.yaw, -PI, PI), -step, step)
	var dpitch := clampf(-0.30 - cam.pitch, -step, step)
	cam.look(Vector2(-dyaw / 0.0022, -dpitch / 0.0022))


# Every catalogue part Rivet may be offered, then a second copy of the pattern and
# fire-rate parts, so weapon effects are as dense as the catalogue allows.
func _grant() -> void:
	var class_id: String = _game.run.class_id()
	var pool := Parts.offer_pool(class_id, ["common", "uncommon", "rare", "rare_plus"])
	for id in Parts.CATALOGUE:
		if id in pool:
			_granted.append(id)
	for id in EXTRA_COPIES:
		if id in pool:
			_granted.append(id)
	for id in _granted:
		_game.run.add_part(id, "stress")


func _forward() -> Vector3:
	var f: Vector3 = -_game.camera.yaw_basis().z
	f.y = 0.0
	return f.normalized()


func _ground(p: Vector3, lift := 2.4) -> Vector3:
	return _game.ctx.terrain.drop_point(p.x, p.z, lift)


func _next_scene() -> void:
	_phase = "setup"
	_scene_index += 1
	if _scene_index >= SCENES.size():
		_analyse()
		return
	for node in _scene_spawned + _scene_threats:
		if is_instance_valid(node):
			node.queue_free()
	_scene_spawned = []
	_scene_threats = []
	_load_slots = []
	_count_samples = []
	_pre_frames = []
	_frames = []
	_committed = false
	_warden_note = ""
	var scene: Dictionary = SCENES[_scene_index]
	var home: Vector3 = _game.ctx.terrain.beacon_point(_stage) + Vector3(0, 0, 22)
	_game.player.reset_to(_ground(home))
	_game.camera.snap(Vector3.FORWARD)
	var ball: Vector3 = _ground(home)
	var fwd := Vector3.FORWARD
	var right := Vector3.RIGHT
	for i in int(scene["packs"]):
		var row: Dictionary = Director.PACKS[PACK_ORDER[i % PACK_ORDER.size()]]
		var centre := ball + fwd * (16.0 + 4.0 * float(i / 3)) + right * (-9.0 + 9.0 * float(i % 3))
		var kinds := [row["controller"], row["punisher"], "chaser", "chaser"]
		for k in kinds.size():
			var spot := centre + right * (float(k) - 1.5) * 2.2
			var enemy: Node3D = _game.ctx.spawner.spawn_enemy(String(kinds[k]), _ground(spot))
			if enemy != null:
				_scene_spawned.append(enemy)
				_load_slots.append({"node": enemy, "kind": String(kinds[k]), "offset": spot - ball})
	_spawned_at_start = (_vfx().spawned as Dictionary).duplicate() if _vfx() != null else {}
	_phase = "play"
	_phase_usec = Time.get_ticks_usec()


# [fires, rect calls, rect usec, shape calls, shape usec] so far. A fire is rate-limited
# (PlayerFx.FRAME_GAP_S), so fires can be fewer than the hits that asked. A rect call is one
# refresh of a live impact frame (the source and the uniform upload), made every live frame;
# a shape call is one build and draw of its pieces, made once per fire (ImpactFrame).
func _impact_counters() -> Array:
	var fx = _game.presentation.player_fx
	if fx == null or fx._frame == null:
		return [0, 0, 0, 0, 0]
	var f = fx._frame
	return [int(fx.spawned.get("impact_frame", 0)), f.rect_calls, f.rect_usec, f.shape_calls, f.shape_usec]


# --impact=hold: asks for a fire every IMPACT_HOLD_PERIOD_S of sample time. The game's rate
# limit and its own checks decide whether it fires; a refused ask is retried next frame.
func _hold_impact(delta: float) -> void:
	var fx = _game.presentation.player_fx
	if not _impact_hold or fx == null:
		return
	_impact_clock += delta
	if _impact_clock < IMPACT_HOLD_PERIOD_S:
		return
	var marks := get_nodes_in_group(Threat.GROUP).size()
	if fx.impact_frame(_game.player.ball_position(), 1.0):
		_impact_clock = 0.0
		_impact_marks.append(marks)


# Opens a window: the worst single call is reset so the window's max is its own.
func _impact_open() -> void:
	_impact_clock = 0.0
	_impact_marks = []
	_impact_at_sample = _impact_counters()
	var fx = _game.presentation.player_fx
	if fx != null and fx._frame != null:
		fx._frame.rect_usec_max = 0
		fx._frame.shape_usec_max = 0


# What the impact frame did since the sample window opened: fires, the refresh and shapes
# cost in ms per call, and ms per fire (all refreshes plus all shapes over the fires), the
# figure the 0.2 ms bar reads.
func _impact_window() -> Dictionary:
	var now := _impact_counters()
	var fires: int = now[0] - _impact_at_sample[0]
	var rect_calls: int = now[1] - _impact_at_sample[1]
	var rect_usec: int = now[2] - _impact_at_sample[2]
	var shape_calls: int = now[3] - _impact_at_sample[3]
	var shape_usec: int = now[4] - _impact_at_sample[4]
	var rect_max := 0.0
	var shape_max := 0.0
	var fx = _game.presentation.player_fx
	if fx != null and fx._frame != null:
		rect_max = fx._frame.rect_usec_max / 1000.0
		shape_max = fx._frame.shape_usec_max / 1000.0
	return {"fired": fires,
		"rect_ms": {"calls": rect_calls, "mean": snappedf(float(rect_usec) / 1000.0 / float(rect_calls), 0.0001) if rect_calls > 0 else 0.0, "max": snappedf(rect_max, 0.0001)},
		"shapes_ms": {"calls": shape_calls, "mean": snappedf(float(shape_usec) / 1000.0 / float(shape_calls), 0.0001) if shape_calls > 0 else 0.0, "max": snappedf(shape_max, 0.0001)},
		"ms_per_fire": snappedf(float(rect_usec + shape_usec) / 1000.0 / float(fires), 0.0001) if fires > 0 else 0.0}


func _vfx():
	for child in _game.presentation.get_children():
		if child is Vfx:
			return child
	return null


# Committed telegraphs of each hostile type in the camera's forward fan around the ball.
func _commit_threats(scene: Dictionary) -> void:
	var n := int(scene["per_type"])
	var ball: Vector3 = _game.player.ball_position()
	var fwd := _forward()
	var right := fwd.cross(Vector3.UP).normalized()
	var terrain = _game.ctx.terrain
	var parent: Node = _game.ctx.root
	for i in n:
		var a := deg_to_rad(-60.0 + 120.0 * (float(i) + 0.5) / float(n))
		var dir := fwd.rotated(Vector3.UP, a)
		var near := 6.0 + 3.0 * float(i % 3)
		var ring = Telegraph.ring(parent, terrain, Threat.Type.INSTANT, ball + dir * near, 6.0)
		ring.set_meta("warn", 2.5)
		_scene_threats.append(ring)
		var wave = Telegraph.wave(parent, terrain, ball + dir * (near + 8.0), 10.0, 6.0, 0.5)
		_scene_threats.append(wave)
		var land := ball + dir.rotated(Vector3.UP, 0.25) * (near + 4.0)
		var shell = Telegraph.ring(parent, terrain, Threat.Type.PROJECTILE, land, 3.5)
		shell.set_flight(_ground(land + dir * 18.0 + right * 4.0, 1.5), 6.0)
		shell.set_meta("warn", 2.0)
		_scene_threats.append(shell)
		var lane_from := ball + dir.rotated(Vector3.UP, -0.3) * (near + 14.0)
		var lane = Telegraph.lane(parent, terrain, Threat.Type.LANE, lane_from, ball - lane_from, 16.0, 3.0)
		lane.set_meta("warn", 2.0)
		_scene_threats.append(lane)
	if bool(scene["warden"]):
		_wake_warden(ball, fwd)


# The stage's Warden, moved 16 m in front of the ball and set to begin its pulse charge
# on its next tick (its _pulse_clock is set from outside; warden.gd is not edited).
func _wake_warden(ball: Vector3, fwd: Vector3) -> void:
	var warden = _game.flow.warden
	if warden == null or not is_instance_valid(warden):
		_warden_note = "fallback: no live Warden, 4 extra instant rings"
		for i in 4:
			var at := ball + fwd.rotated(Vector3.UP, deg_to_rad(-30.0 + 20.0 * i)) * 12.0
			_scene_threats.append(Telegraph.ring(_game.ctx.root, _game.ctx.terrain, Threat.Type.INSTANT, at, 6.0))
		return
	var at := ball + fwd * 16.0
	at.y = Telegraph.ground_under(_game.ctx.terrain, at)
	warden.global_position = at
	warden.max_hp = 1000000.0
	warden.hp = warden.max_hp
	warden.set("_pulse_clock", Warden.PULSE_CYCLE - Warden.PULSE_TELEGRAPH)
	_warden_note = "moved to 16 m ahead, pulse charge started; HP raised to preserve load"


func _step_threats(delta: float) -> void:
	for node in _scene_threats:
		if not is_instance_valid(node):
			continue
		if node.type == Threat.Type.WAVE:
			if node.is_spent():
				node.age = 0.0
			node.step(delta)
		else:
			node.age = fposmod(node.age + delta, float(node.get_meta("warn", 2.0)))
			node.set_progress(minf(node.age / float(node.get_meta("warn", 2.0)), 0.95))


func _sample(dt_ms: float) -> Dictionary:
	return {
		"dt": dt_ms,
		"cpu": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"physics": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"gpu": RenderingServer.viewport_get_measured_render_time_gpu(_render_rid),
		"rcpu": RenderingServer.viewport_get_measured_render_time_cpu(_render_rid),
		"draws": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"prims": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
	}


# --- Stills -------------------------------------------------------------------------------

func _player_fx() -> Array:
	var out: Array = []
	for name in ["PresentationFx", "CombatEffects", "Bolts", "StickyCharges", "ElementField"]:
		var node = _game.find_child(name, false, false)
		if node != null:
			out.append(node)
	var juice = _game.presentation.find_child("Juice", false, false)
	if juice != null:
		for child in juice.get_children():
			if child is Node3D:
				out.append(child)
	var indicator = _game.player.find_child("Indicator", false, false)
	if indicator != null:
		out.append(indicator)
	for layer in _all(root, func(n): return n is CanvasLayer):
		out.append(layer)
	return out


func _all(node: Node, pred: Callable, out: Array = []) -> Array:
	if pred.call(node):
		out.append(node)
	for child in node.get_children():
		_all(child, pred, out)
	return out


func _set_visible(nodes: Array, on: bool, saved: Dictionary) -> void:
	for node in nodes:
		if not is_instance_valid(node):
			continue
		if on:
			node.visible = saved.get(node.get_instance_id(), true)
		else:
			saved[node.get_instance_id()] = node.visible
			node.visible = false


func _still(name: String) -> Image:
	if _dry:
		var blank := Image.create(192, 108, false, Image.FORMAT_RGB8)
		blank.fill(Palette.HAZARD if name.ends_with("threats-only") else Color.BLACK)
		return blank
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.convert(Image.FORMAT_RGB8)
	if image.save_png(_out.path_join(_tag + name + ".png")) != OK:
		_errors.append("image_write: " + name)
	return image


func _capture() -> void:
	var scene: Dictionary = SCENES[_scene_index]
	var id: String = scene["id"]
	paused = true
	var counts := _counts()
	var impact := _impact_window()
	var fx := _player_fx()
	var threats := get_nodes_in_group(Threat.GROUP)
	var edges: Array = []
	var unsupported := 0
	for threat in threats:
		if not threat.has_method("painter"):
			unsupported += 1
			continue
		var painter = threat.painter()
		for layer in ["under", "base", "motion_under", "motion"]:
			if painter._layers.has(layer):
				edges.append(painter._layers[layer])
	var saved_fx := {}
	var saved_threats := {}
	var saved_edges := {}
	var particle_speeds := {}
	for particle in _all(root, func(n): return n is GPUParticles3D):
		particle_speeds[particle] = particle.speed_scale
		particle.speed_scale = 0.0
	var full: Image = await _still(id + "-full")
	_set_visible(edges, false, saved_edges)
	var full_no_edges: Image = await _still(id + "-full-no-edges")
	_set_visible(edges, true, saved_edges)
	_set_visible(threats, false, saved_threats)
	var no_threats: Image = await _still(id + "-no-threats")
	_set_visible(fx, false, saved_fx)
	var world: Image = await _still(id + "-world-only")
	_set_visible(threats, true, saved_threats)
	var threat_only: Image = await _still(id + "-threats-only")
	_set_visible(edges, false, saved_edges)
	var clean_no_edges: Image = await _still(id + "-clean-no-edges")
	_set_visible(edges, true, saved_edges)
	_set_visible(fx, true, saved_fx)
	for particle in particle_speeds:
		particle.speed_scale = particle_speeds[particle]
	_images[id] = {"full": full, "threats": threat_only, "world": world,
		"no_threats": no_threats, "full_no_edges": full_no_edges, "clean_no_edges": clean_no_edges}
	_results.append({"scene": id, "packs": scene["packs"], "telegraphs_committed": _scene_threats.size(),
		"synthetic_per_type": scene["per_type"], "edge_nodes": edges.size(), "unsupported_threats": unsupported,
		"warden": _warden_note, "counts": counts, "pre_capture_frames": _stats(_pre_frames),
		"frames": _stats(_frames), "impact_frames_fired": impact["fired"], "impact_rect_ms": impact["rect_ms"], "impact_shapes_ms": impact["shapes_ms"], "impact_ms_per_fire": impact["ms_per_fire"], "count_samples": _count_samples.duplicate(),
		"load_valid": counts["fixture_enemies_live"] == int(scene["packs"]) * 4 and counts["synthetic_threats_live"] == int(scene["per_type"]) * 4})
	if _impact_hold:
		_results.back()["impact_hold"] = {"forced_fires": _impact_marks.size(), "period_s": IMPACT_HOLD_PERIOD_S,
			"marks_min": _impact_marks.min() if not _impact_marks.is_empty() else 0, "marks_max": _impact_marks.max() if not _impact_marks.is_empty() else 0}
	paused = false
	_last_usec = 0
	_busy = false
	_next_scene()


func _counts() -> Dictionary:
	var cam: Camera3D = _game.camera.cam
	var vfx = _vfx()
	var glyphs_visible := 0
	var sparkles := 0
	var trail := 0
	var lines := 0
	var spawned_delta := {}
	if vfx != null:
		for slot in vfx._glyphs:
			if (slot["node"] as Node3D).visible:
				glyphs_visible += 1
		for s in vfx._sparkles:
			if s.emitting:
				sparkles += 1
		trail = vfx._trail_points.size()
		lines = vfx._streaks.size()
		for kind in vfx.spawned:
			var d: int = int(vfx.spawned[kind]) - int(_spawned_at_start.get(kind, 0))
			if d > 0:
				spawned_delta[kind] = d
	var threats_total := 0
	var threats_view := 0
	var by_kind := {}
	for node in get_nodes_in_group(Threat.GROUP):
		if not (node is Node3D) or not (node as Node3D).is_visible_in_tree():
			continue
		threats_total += 1
		var at: Vector3 = node.threat_at() if node.has_method("threat_at") else (node as Node3D).global_position
		if cam.is_position_in_frustum(at):
			threats_view += 1
			var k: String = node.threat_kind() if node.has_method("threat_kind") else "other"
			by_kind[k] = int(by_kind.get(k, 0)) + 1
	var enemies_view := 0
	for node in get_nodes_in_group("enemy"):
		if node is Node3D and cam.is_position_in_frustum((node as Node3D).global_position):
			enemies_view += 1
	var prompts := 0
	for label in get_nodes_in_group("world_prompt"):
		if label is CanvasItem and label.is_visible_in_tree():
			prompts += 1
	var bolts: int = _game.ctx.spawner.live_projectiles() if _game.ctx.spawner.has_method("live_projectiles") else -1
	var fx_node = _game.find_child("CombatEffects", false, false)
	var combat_marks: int = fx_node.live_mark_count() if fx_node != null else 0
	var words := WordBudget.count(_game, cam)
	var effects_total := glyphs_visible + sparkles + bolts + combat_marks + lines + (1 if trail > 2 else 0)
	var cap_sum := Vfx.POOL + Vfx.SPARKLE_POOL + Bolts.MAX_LIVE
	return {
		"vfx_glyphs_visible": glyphs_visible, "vfx_pool": Vfx.POOL,
		"vfx_spawned_this_scene": spawned_delta, "vfx_spawned_this_scene_total": spawned_delta.values().reduce(func(a, b): return a + b, 0),
		"sparkles_emitting": sparkles, "trail_points": trail, "speed_lines": lines,
		"bolts_live": bolts, "bolts_cap": Bolts.MAX_LIVE, "bolts_crowd_start": Bolts.CROWD_START,
		"combat_marks": combat_marks,
		"effects_total_mixed_units": effects_total, "pool_cap_subset": cap_sum,
		"fixture_enemies_live": _load_slots.filter(func(s): return is_instance_valid(s["node"]) and not s["node"].is_queued_for_deletion()).size(),
		"synthetic_threats_live": _scene_threats.filter(func(n): return is_instance_valid(n) and not n.is_queued_for_deletion()).size(),
		"threat_nodes_total": threats_total, "threat_nodes_in_view": threats_view, "threats_in_view_by_kind": by_kind,
		"enemies_in_view": enemies_view, "prompts_shown": prompts,
		"hud_words": words["hud"], "world_words": words["world"], "word_budget_fight": 25,
		"fps": Engine.get_frames_per_second(), "time_scale": Engine.time_scale,
	}


func _stats(samples: Array) -> Dictionary:
	if samples.is_empty():
		return {}
	var out := {"n": samples.size()}
	for key in ["dt", "cpu", "physics", "gpu", "rcpu", "draws", "prims"]:
		var values: Array = samples.map(func(s): return float(s[key])).filter(func(v): return v > 0.0)
		if values.is_empty():
			continue
		values.sort()
		out[key] = {"n": values.size(), "p50": snappedf(_pct(values, 0.5), 0.01), "p95": snappedf(_pct(values, 0.95), 0.01),
			"p99": snappedf(_pct(values, 0.99), 0.01), "max": snappedf(values.back(), 0.01)}
	return out


static func _pct(sorted: Array, q: float) -> float:
	return sorted[mini(int(floor(q * (sorted.size() - 1) + 0.5)), sorted.size() - 1)]


# --- Coverage -----------------------------------------------------------------------------

func _analyse() -> void:
	_phase = "analyse"
	var hazard_h := Palette.HAZARD.h * 360.0
	for result in _results:
		var id: String = result["scene"]
		var imgs: Dictionary = _images[id]
		result["coverage"] = _coverage(imgs, hazard_h, id)
		result["p1_edges"] = _edge_coverage(imgs, id)
		result["p1_edges"]["valid"] = result["p1_edges"]["valid"] and result["unsupported_threats"] == 0
	_finish("done")


static func _family(data: PackedByteArray, i: int, hazard_h: float) -> bool:
	var r := data[i]
	var g := data[i + 1]
	var b := data[i + 2]
	var hi := maxi(r, maxi(g, b))
	if hi < int(VAL_MIN * 255.0):
		return false
	var lo := mini(r, mini(g, b))
	if float(hi - lo) / float(hi) <= SAT_MIN:
		return false
	var h := 0.0
	var span := float(hi - lo)
	if hi == r:
		h = 60.0 * fposmod(float(g - b) / span, 6.0)
	elif hi == g:
		h = 60.0 * (float(b - r) / span + 2.0)
	else:
		h = 60.0 * (float(r - g) / span + 4.0)
	var dh := absf(h - hazard_h)
	return minf(dh, 360.0 - dh) <= HUE_TOL


func _coverage(imgs: Dictionary, hazard_h: float, id: String) -> Dictionary:
	var threats: PackedByteArray = (imgs["threats"] as Image).get_data()
	var world: PackedByteArray = (imgs["world"] as Image).get_data()
	var full: PackedByteArray = (imgs["full"] as Image).get_data()
	var overlay: Image = (imgs["full"] as Image).duplicate()
	var w: int = (imgs["full"] as Image).get_width()
	var pixels := threats.size() / 3
	var raw := 0
	var raw_occluded := 0
	var threat_px := 0
	var occluded := 0
	var world_family := 0
	for p in pixels:
		var i := p * 3
		if not _family(threats, i, hazard_h):
			continue
		raw += 1
		var in_full := _family(full, i, hazard_h)
		if not in_full:
			raw_occluded += 1
		if _family(world, i, hazard_h):
			world_family += 1
			continue
		threat_px += 1
		if not in_full:
			occluded += 1
			overlay.set_pixel(p % w, p / w, Color(1, 0, 1))
		else:
			overlay.set_pixel(p % w, p / w, Color(0, 1, 0.4))
	if not _dry and overlay.save_png(_out.path_join(_tag + id + "-occlusion.png")) != OK:
		_errors.append("overlay_write: " + id)
	return {
		"screen_pixels": pixels,
		"threat_pixels": threat_px, "threat_screen_pct": snappedf(100.0 * threat_px / pixels, 0.01),
		"occluded_pixels": occluded, "occluded_pct": snappedf(100.0 * occluded / maxi(threat_px, 1), 0.1),
		"raw_family_pixels": raw, "raw_occluded_pct": snappedf(100.0 * raw_occluded / maxi(raw, 1), 0.1),
		"world_family_pixels_excluded": world_family,
	}


func _finish(reason: String) -> void:
	if _phase == "finished":
		return
	_phase = "finished"
	if reason == "done" and _results.size() != SCENES.size():
		_errors.append("incomplete scenes")
	for result in _results:
		if not result["load_valid"] or result["frames"].get("dt", {}).get("n", 0) != SAMPLE_FRAMES:
			_errors.append("invalid load or sample count: " + result["scene"])
		for sample in result["count_samples"]:
			if sample["fixture_enemies_live"] != int(result["packs"]) * 4 or sample["synthetic_threats_live"] != int(result["synthetic_per_type"]) * 4:
				_errors.append("load fell below target during sampling: " + result["scene"])
				break
	var info := {
		"reason": reason, "dry_schema_only": _dry, "stage": _stage, "time_id": WorldLook.time_id(_stage), "table": _table if not _table.is_empty() else "default", "calm": _calm, "errors": _errors,
		"godot": Engine.get_version_info()["string"], "source_sha256": _source_hashes(),
		"timing": "uncapped frame intervals; captures and analysis excluded; replenishment included; GPU zero means unavailable",
		"class": _game.run.class_id() if _game != null and _game.run != null else "",
		"adapter": RenderingServer.get_video_adapter_name(), "display": DisplayServer.get_name(),
		"size": [root.get_texture().get_width(), root.get_texture().get_height()],
		"granted_parts": _granted, "hazard": "#ff5a3c", "hue_tol_deg": HUE_TOL, "sat_min": SAT_MIN, "val_min": VAL_MIN,
		"wall_seconds": snappedf(_seconds_since(_start_usec), 0.1), "scenes": _results,
	}
	info.merge(_strength(_results))
	var file := FileAccess.open(_out.path_join("stress.json" if _tag.is_empty() else "stress-%s.json" % _tag.trim_suffix("-")), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(info, "  "))
		file.close()
	else:
		printerr("stress_capture: could not write " + ("stress.json" if _tag.is_empty() else "stress-%s.json" % _tag.trim_suffix("-")))
		quit(1)
		return
	if reason == "done" and not _dry and OS.execute("which", ["montage"]) == 0:
		var args: Array = []
		for id in ["s1", "s2", "s3"]:
			for kind in ["full", "threats-only", "no-threats"]:
				args.append(_out.path_join("%s%s-%s.png" % [_tag, id, kind]))
		args.append_array(["-tile", "3x3", "-geometry", "640x360+4+4", "-background", "#202020", _out.path_join("contact-stress.jpg" if _tag.is_empty() else "contact-stress-%s.jpg" % _tag.trim_suffix("-"))])
		OS.execute("montage", PackedStringArray(args))
	print("stress_capture: %s, %d scenes in %s" % [reason, _results.size(), _out])
	quit(0 if reason == "done" and _errors.is_empty() else 1)


# Keep each scene populated through warmup and sampling. Replacement work is timed.
# Positions reset only when a surviving fixture leaves the camera neighbourhood.
func _maintain_load() -> void:
	var ball: Vector3 = _game.player.ball_position()
	if is_instance_valid(_game.flow.warden):
		_game.flow.warden.hp = _game.flow.warden.max_hp
	for slot in _load_slots:
		var enemy = slot["node"]
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or enemy.is_dead():
			enemy = _game.ctx.spawner.spawn_enemy(slot["kind"], _ground(ball + slot["offset"]))
			slot["node"] = enemy
			_scene_spawned.append(enemy)
		elif enemy.global_position.distance_to(ball) > 35.0:
			enemy.global_position = _ground(ball + slot["offset"])


# Paired renders isolate P1 edges/keylines/height rails from fills, scenery and HUD.
# A candidate must change the clean image by >= 12/255 in at least one RGB channel.
# Count as lost if the full image retains < 50% of that differential contrast.
# This is a contrast-loss proxy, not a semantic readability verdict.
func _edge_coverage(imgs: Dictionary, id: String) -> Dictionary:
	var a: PackedByteArray = imgs["threats"].get_data()
	var b: PackedByteArray = imgs["clean_no_edges"].get_data()
	var c: PackedByteArray = imgs["full"].get_data()
	var d: PackedByteArray = imgs["full_no_edges"].get_data()
	var overlay: Image = imgs["full"].duplicate()
	var width := overlay.get_width()
	var candidates := 0
	var lost := 0
	for p in a.size() / 3:
		var ref_delta := 0
		var live_delta := 0
		for channel in 3:
			var i := p * 3 + channel
			ref_delta = maxi(ref_delta, absi(int(a[i]) - int(b[i])))
			live_delta = maxi(live_delta, absi(int(c[i]) - int(d[i])))
		if ref_delta < 12:
			continue
		candidates += 1
		var hidden := live_delta < ref_delta * 0.5
		if hidden:
			lost += 1
		overlay.set_pixel(p % width, p / width, Color.MAGENTA if hidden else Color(0, 1, 0.4))
	if not _dry and overlay.save_png(_out.path_join(_tag + id + "-p1-occlusion.png")) != OK:
		_errors.append("p1_overlay_write: " + id)
	return {"candidate_pixels": candidates, "lost_pixels": lost,
		"lost_pct": 100.0 * lost / candidates if candidates > 0 else -1.0,
		"valid": not _dry and candidates >= 100, "minimum_reference_delta": 12, "contrast_retention": 0.5}


# s3_mask_px is S3's P1 candidate pixel count, -1 when S3 has no analysed edges. Strong also
# needs S3's mask valid (a display run with no unsupported painters), as the bar does.
static func _strength(results: Array) -> Dictionary:
	var mask := -1
	var valid := false
	for result in results:
		if result.get("scene", "") == "s3" and result.has("p1_edges"):
			mask = int(result["p1_edges"]["candidate_pixels"])
			valid = bool(result["p1_edges"].get("valid", false))
	return {"s3_mask_px": mask, "strong": valid and mask >= STRONG_MIN}


func _source_hashes() -> Dictionary:
	var hashes := {}
	for path in ["res://tools/stress_capture.gd", "res://src/combat/telegraph.gd",
		"res://src/combat/threat_grammar.gd", "res://src/presentation/vfx.gd",
		"res://src/presentation/juice.gd", "res://src/game.gd", "res://src/core/flow.gd",
		"res://src/presentation/world_look.gd"]:
		hashes[path] = FileAccess.get_sha256(path)
	return hashes


func _metric_self_test() -> void:
	_dry = false
	var edges := Image.create(20, 20, false, Image.FORMAT_RGB8)
	edges.fill(Color(0.5, 0.5, 0.5))
	var empty := Image.create(20, 20, false, Image.FORMAT_RGB8)
	empty.fill(Color.BLACK)
	var full: Image = edges.duplicate()
	for y in 5:
		for x in 20:
			full.set_pixel(x, y, Color.BLACK)
	var known := _edge_coverage({"threats": edges, "clean_no_edges": empty,
		"full": full, "full_no_edges": empty}, "self-test-quarter")
	var missing := _edge_coverage({"threats": empty, "clean_no_edges": empty,
		"full": empty, "full_no_edges": empty}, "self-test-empty")
	# Planted controls: a telegraph off-screen leaves S3 an empty mask and must not read strong;
	# a valid mask of exactly STRONG_MIN pixels must, and an invalid one must not.
	var wide := Image.create(250, 200, false, Image.FORMAT_RGB8)
	wide.fill(Color(0.5, 0.5, 0.5))
	var wide_empty := Image.create(250, 200, false, Image.FORMAT_RGB8)
	wide_empty.fill(Color.BLACK)
	var at_floor := _edge_coverage({"threats": wide, "clean_no_edges": wide_empty,
		"full": wide, "full_no_edges": wide_empty}, "self-test-floor")
	var off_screen := _strength([{"scene": "s3", "p1_edges": missing}])
	var floor_run := _strength([{"scene": "s3", "p1_edges": at_floor}])
	var below_run := _strength([{"scene": "s3", "p1_edges": {"candidate_pixels": STRONG_MIN - 1, "valid": true}}])
	var invalid_run := _strength([{"scene": "s3", "p1_edges": {"candidate_pixels": STRONG_MIN, "valid": false}}])
	var strength_ok: bool = off_screen == {"s3_mask_px": 0, "strong": false} and floor_run == {"s3_mask_px": STRONG_MIN, "strong": true} and not below_run["strong"] and not invalid_run["strong"] and _strength([])["s3_mask_px"] == -1
	var passed: bool = strength_ok and known["candidate_pixels"] == 400 and known["lost_pixels"] == 100 and is_equal_approx(known["lost_pct"], 25.0) and known["valid"] and not missing["valid"] and missing["lost_pct"] == -1.0 and _errors.is_empty()
	print("stress_capture metric self-test: ", "PASS" if passed else "FAIL", " ", JSON.stringify({"quarter": known, "empty": missing, "off_screen": off_screen, "floor": floor_run}))
	quit(0 if passed else 1)
