extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const HeroAssets := preload("res://src/presentation/hero_assets.gd")

# The shell's air-factor cue (--hotwire-shell=on --world-one-builds=on): one cue whenever Build's
# resolved shell factor moves between two fitted values, read from Build.shell_air_changed, so S4,
# R6 and K5 share it with no per-inversion code. Three layers are
# counted from that one signal: the signal itself, the ring on the hero pod (hero_assets.gd) and
# the spring sound (audio.gd), each rise and return told apart. Colour, shape and sound id come
# from the EventKinds row shell_air_shift.
# Evidence limit: counts, parameters and node types on the real Game, headless. Whether the ring
# reads at chase distance and how the spring feels are unjudged.

const SOUND := "shell_spring"
const STEP := 2
const R6_PHASES := 40
const R6_PHASE_STEP := 8
const GROUND_WAIT_TICKS := 600

var _failures := 0
var _game
var _player
var _class := ""
var _sig: Array = []       # rose flags, in order, from Build.shell_air_changed
var _rings: Array = []     # {rose, from, to, color, shape} per AirCue entering the pod
var _pod_seen := 0
var _canvas_before := 0


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _sim(seconds: float) -> void:
	await _ticks(roundi(seconds * Engine.physics_ticks_per_second))


func _until_grounded() -> void:
	var waited := 0
	while not _player.state.grounded and waited < GROUND_WAIT_TICKS:
		await physics_frame
		waited += 1


func _audio():
	return _game.presentation.audio


func _sounds() -> Array:
	return _audio().cue_log.filter(func(c: Array) -> bool: return c[1] == SOUND and c[2] == "now")


func _rises(flags: Array) -> int:
	return flags.filter(func(f) -> bool: return f).size()


func _returns(flags: Array) -> int:
	return flags.filter(func(f) -> bool: return not f).size()


# Fresh counters. The audio log and the signal list restart; the pod watcher rebinds to the
# current pod (a class change replaces it).
func _reset() -> void:
	_sig.clear()
	_rings.clear()
	_audio().cue_log.clear()
	var pod = _game.presentation.hero_assets.shell_of(_player).get("pod")
	if pod != null and is_instance_valid(pod) and pod.get_instance_id() != _pod_seen:
		_pod_seen = pod.get_instance_id()
		pod.child_entered_tree.connect(_on_pod_child)


func _on_pod_child(node: Node) -> void:
	if node.name != HeroAssets.AIR_CUE_NAME:
		return
	var mat := (node as MeshInstance3D).material_override as StandardMaterial3D
	_rings.append({"rose": node.get_meta("rose"), "from": node.scale.x, "shape": node.get_meta("shape"),
		"color": mat.albedo_color, "is_mesh": node is MeshInstance3D, "canvas": _under_canvas(node)})


func _under_canvas(node: Node) -> bool:
	var at := node
	while at != null:
		if at is CanvasLayer:
			return true
		at = at.get_parent()
	return false


func _count(kind: String) -> int:
	return root.find_children("*", kind, true, false).size()


# "cues" = [signal, rings, sounds] for one scenario.
func _tally() -> Array:
	return [_sig.size(), _rings.size(), _sounds().size()]


func _fit(class_id: String) -> void:
	_class = class_id
	var def = ClassDef.by_id(class_id)
	_game.run.class_def = def
	_player.fit_class(def)


# A fresh tree for the class with these picks, shell as given, then a recompute (silent baseline).
func _setup(class_id: String, picks: Array, shell: bool) -> void:
	_game.tuning.set_option("world_one_builds", "on")
	_game.tuning.set_option("hotwire_shell", "on" if shell else "off")
	var tree = _player.tree
	for pass_index in 2:
		tree.reset(class_id)
		tree.max_depth = 2
		tree.world_one = true
		for id in picks:
			tree.open_checkpoint()
			tree.pick(id)
		if pass_index == 0:
			_player.fit_class(ClassDef.by_id(class_id))
	_player.kit.sprinting = false
	_game.run.parts.clear()
	_game.build.recompute()


func _lift() -> void:
	var body = _player.body()
	body.global_position = _player.ball_position() + Vector3(0.0, 30.0, 0.0)
	body.linear_velocity = Vector3.ZERO


func _vault() -> void:
	_game.events.vault_kicked.emit(_player.ball_position(), 20.0)


func _sprint_start() -> void:
	_player.source.hold = {"movement_held": true}
	_player.source.press = {"movement_pressed": true}


func _release() -> void:
	_player.source.hold = {}


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_player = _game.player
	_player.source = Intent.Scripted.new()
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_fit("pylon_engineer")
	_game.tuning.set_option("scrap_mode", "armor")
	await _sim(0.5)
	var build = _game.build
	# Bake the sound bank before any cue can be admitted; a frame budget races the bank's size.
	_audio().bake_now()
	_check("sound bank ready", _audio().sound_ready, "baked with bake_now")
	build.shell_air_changed.connect(func(_factor: float, rose: bool): _sig.append(rose))
	var row: Dictionary = EventKinds.WORLD_ROWS.get("shell_air_shift", {})
	_check("one EventKinds row carries the fact", row.get("shape", "") == "ring" and row.get("sound", "") == SOUND and row.get("color") is Color,
		"row %s" % [row])

	# --- S4 (Sable), shell on -------------------------------------------------------------
	# Re-pinned 2026-11-24 (E2-09, PILOT-CADENCE §6.2): S4 sits under Static Flutter.
	var s4 := ["s_static_flutter", "s_face_runner"]
	_setup("pylon_engineer", s4, true)
	await _ticks(STEP)
	_reset()
	_canvas_before = _count("CanvasLayer") + _count("ColorRect")
	_check("S4 fitted, no cue at baseline", build._face_runner_s4() and build.shell_fitted() and _tally() == [0, 0, 0], "tally %s" % [_tally()])
	await _sim(0.5)
	_vault()
	await _ticks(STEP)
	var open_tally := _tally()
	var rise_ring: Dictionary = _rings[0] if _rings.size() > 0 else {}
	_check("S4 vault: exactly 1 rise cue on open", open_tally == [1, 1, 1] and _rises(_sig) == 1 and _returns(_sig) == 0,
		"[signal, ring, sound] %s, rises %d returns %d" % [open_tally, _rises(_sig), _returns(_sig)])
	var overlay_now := _count("CanvasLayer") + _count("ColorRect")
	_check("no full-screen overlay during the cue", overlay_now == _canvas_before and not _rings.any(func(r): return r["canvas"]) and _rings.all(func(r): return r["is_mesh"]),
		"CanvasLayer+ColorRect %d -> %d, rings under a canvas %d" % [_canvas_before, overlay_now, _rings.filter(func(r): return r["canvas"]).size()])
	await _sim(0.5)
	build.recompute()
	await _ticks(STEP)
	_check("recompute inside the window emits no extra cue", _tally() == [1, 1, 1], "tally %s" % [_tally()])
	_vault()
	await _ticks(STEP)
	_check("second vault restarting the window emits no extra cue", _tally() == [1, 1, 1], "tally %s" % [_tally()])
	await _sim(2.3)
	var close_tally := _tally()
	_check("S4 window close: exactly 1 return cue", close_tally == [2, 2, 2] and _rises(_sig) == 1 and _returns(_sig) == 1,
		"[signal, ring, sound] %s, rises %d returns %d" % [close_tally, _rises(_sig), _returns(_sig)])

	# Rise and return differ in every layer that carries the direction, and read one row.
	var sounds := _sounds()
	var pitch_rise: float = float(sounds[0][4]) if sounds.size() > 1 else 0.0
	var pitch_return: float = float(sounds[1][4]) if sounds.size() > 1 else 0.0
	var ret_ring: Dictionary = _rings[1] if _rings.size() > 1 else {}
	_check("rise and return sound differ (pitch, an octave apart)", pitch_rise > pitch_return and pitch_return > 0.0 and is_equal_approx(pitch_rise / maxf(pitch_return, 0.0001), 2.0),
		"rise %.3f, return %.3f" % [pitch_rise, pitch_return])
	_check("rise and return ring differ (swell out vs draw in)", rise_ring.get("rose", false) and not ret_ring.get("rose", true) and rise_ring.get("from", 0.0) < ret_ring.get("from", 0.0),
		"rise starts %s, return starts %s" % [rise_ring.get("from"), ret_ring.get("from")])
	_check("ring colour, shape and sound id read the one row", rise_ring.get("color", Color.BLACK) == row.get("color") and ret_ring.get("color", Color.BLACK) == row.get("color")
			and rise_ring.get("shape", "") == row.get("shape") and sounds.size() > 0 and String(sounds[0][1]) == row.get("sound", "?"),
		"colour %s, shape %s, sound %s" % [rise_ring.get("color"), rise_ring.get("shape"), sounds[0][1] if sounds.size() > 0 else ""])

	# Shell off: a vault gives nothing.
	_setup("pylon_engineer", s4, false)
	await _ticks(STEP)
	_reset()
	await _sim(0.5)
	_vault()
	await _sim(2.3)
	_check("no shell: a vault gives 0 cues", not build.shell_fitted() and _tally() == [0, 0, 0], "tally %s" % [_tally()])

	# Fitting and unfitting the shell (option toggle plus recompute) is silent: 0 cues.
	_setup("pylon_engineer", s4, true)
	await _ticks(STEP)
	_reset()
	_game.tuning.set_option("hotwire_shell", "off")
	build.recompute()
	await _ticks(STEP)
	_game.tuning.set_option("hotwire_shell", "on")
	build.recompute()
	await _ticks(STEP)
	_check("fit and unfit the shell: 0 cues (0.75 <-> 1.0 is not an inversion)", build.shell_fitted() and _tally() == [0, 0, 0], "tally %s" % [_tally()])

	# --- R6 (Rivet), shell on -------------------------------------------------------------
	_fit("runner_gunner")
	await _sim(0.3)
	# Re-pinned 2026-11-24 (E2-09, PILOT-CADENCE §6.2): R6 sits under Big Iron.
	var r6 := ["r_big_iron", "r_second_wind"]
	# Grounded first (before any lift): the factor still moves, so the cue still fires. The hero
	# is still rolling down the spawn slope here, and where it is on that slope depends on how many
	# physics ticks the sound bake took (wall time), so the same scenario runs at many phases of the
	# roll and has to hold at every one. Each run waits for a grounded tick first; a hero that never
	# lands still fails the check.
	var grounded_bad := 0
	var grounded_last := ""
	for phase in R6_PHASES:
		await _ticks(R6_PHASE_STEP)
		_setup("runner_gunner", r6, true)
		await _ticks(STEP + 5)
		await _until_grounded()
		_reset()
		var grounded: bool = _player.state.grounded
		_sprint_start()
		await _ticks(STEP + 2)
		_release()
		await _ticks(STEP + 3)
		if not (grounded and _tally() == [2, 2, 2] and _rises(_sig) == 1 and _returns(_sig) == 1):
			grounded_bad += 1
			grounded_last = "grounded %s, [signal, ring, sound] %s" % [grounded, _tally()]
	_check("R6 sprint while grounded cues the same (rise then return)", grounded_bad == 0,
		"%d of %d phases failed, last: %s" % [grounded_bad, R6_PHASES, grounded_last])

	# Airborne sprint.
	_setup("runner_gunner", r6, true)
	_lift()
	await _ticks(STEP)
	_reset()
	_sprint_start()
	await _ticks(STEP + 2)
	_check("R6 sprint: exactly 1 rise cue on start", build._second_wind_r6() and _player.kit.sprinting and _tally() == [1, 1, 1] and _rises(_sig) == 1,
		"sprinting %s, [signal, ring, sound] %s" % [_player.kit.sprinting, _tally()])
	await _ticks(10)
	build.recompute()
	await _ticks(STEP)
	_check("R6 recompute inside the sprint emits no extra cue", _tally() == [1, 1, 1], "tally %s" % [_tally()])
	_release()
	await _ticks(STEP + 3)
	_check("R6 sprint end: exactly 1 return cue", not _player.kit.sprinting and _tally() == [2, 2, 2] and _returns(_sig) == 1,
		"[signal, ring, sound] %s, rises %d returns %d" % [_tally(), _rises(_sig), _returns(_sig)])

	# No shell: a sprint gives nothing.
	_setup("runner_gunner", r6, false)
	_lift()
	await _ticks(STEP)
	_reset()
	_sprint_start()
	await _ticks(STEP + 3)
	_release()
	await _ticks(STEP + 3)
	_check("no shell: a sprint gives 0 cues", not build.shell_fitted() and _tally() == [0, 0, 0], "tally %s" % [_tally()])

	# Without the inversion picked (R6 not taken) a sprint changes nothing, so no cue.
	_setup("runner_gunner", ["r_big_iron"], true)
	_lift()
	await _ticks(STEP)
	_reset()
	_sprint_start()
	await _ticks(STEP + 3)
	_release()
	await _ticks(STEP + 3)
	_check("shell on, no inversion taken: a sprint gives 0 cues", build.shell_fitted() and not build._second_wind_r6() and _tally() == [0, 0, 0], "tally %s" % [_tally()])

	# --- K5 (Kest), shell on: the glide edge refreshes through the same emit point ----------
	# Real input as in hotwire_k5_test: a jump press spends the air jump (fixture air_actions 1,
	# the lifted ball never touched ground), the held jump glides once the ball falls.
	_fit("demolitions_caster")
	await _sim(0.3)
	# Re-pinned 2026-11-24 (E2-09, PILOT-CADENCE §6.2): K5 sits under Keg.
	_setup("demolitions_caster", ["k_keg", "k_smoke_trail"], true)
	_lift()
	_player.state.air_actions = 1
	await _ticks(STEP)
	_reset()
	_player.source.hold = {"jump_held": true}
	_player.source.press = {"jump_pressed": true}
	var glided := false
	for i in 200:
		await physics_frame
		if _player.kit.gliding:
			glided = true
			break
	await _ticks(STEP)
	_check("K5 glide: exactly 1 rise cue on start", glided and build._smoke_trail_k5() and _tally() == [1, 1, 1] and _rises(_sig) == 1,
		"glided %s, [signal, ring, sound] %s" % [glided, _tally()])
	_release()
	await _ticks(STEP + 1)
	_check("K5 glide end: exactly 1 return cue", not _player.kit.gliding and _tally() == [2, 2, 2] and _returns(_sig) == 1,
		"[signal, ring, sound] %s, rises %d returns %d" % [_tally(), _rises(_sig), _returns(_sig)])

	if _failures == 0:
		print("hotwire_cue_test: PASS")
	else:
		print("hotwire_cue_test: FAIL (%d)" % _failures)
	quit(1 if _failures > 0 else 0)
