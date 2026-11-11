extends SceneTree

const Game := preload("res://src/game.gd")
const SettingsStore := preload("res://src/ui/settings_store.gd")
const T := preload("res://tests/support/t.gd")
# The speed FS-5 places the ball with: slow enough that the ball stays near the spot.
const PLACED_SPEED := Vector3(0.0, 0.0, -3.0)

# Frame smoothing (9 Nov 2026): the ball is drawn between its last two physics ticks, so a
# display that is not 90 Hz shows it moving every frame. Checked here: interpolation is opt-in
# per body (the Game root is off, only the ball's body asks); the saved Display row; and that a
# test or a headless bot never takes the setting, because the sim reads the lens and the lens
# follows the drawn ball; that one reset_to places the ball and it is drawn there at once; and that
# the drawn place is the ball's own place inside a physics tick, so rules that run on the tick
# never see a between-ticks ball. tools/judder_probe.gd measures the picture at a display rate and
# tools/interp_audit.gd lists every node the tree's interpolation would draw wrong.

var _t := T.new("frame_smoothing_test")
var _game
var _step := 0
var _placed := Vector3.ZERO
var _worst := 0.0
var _strayed := 0.0
var _ticks := 0
var _tick_gap := 0.0
var _frame_gap := 0.0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _process(_delta: float) -> bool:
	if _game == null or _game.flow == null:
		return false
	_step += 1
	if _step == 1:
		_settings()
	elif _step == 2:
		_game.ctx.calm = true
		_game.flow.press_start()
		_game.flow.choose_class(0)
	elif _step == 6:
		_bodies()
		_game.toggle_interpolation()
	elif _step == 12:
		# A stage entry, a boss intro and a rescue place the ball this way: one reset_to, and the
		# ball reads at the new spot at once so the lens can snap in the same breath.
		_placed = _game.player.body().global_position + Vector3(0.0, 30.0, 300.0)
		_game.player.reset_to(_placed, PLACED_SPEED)
		_t.check("FS-5 one call places a rolling ball: its body reads at the new spot at once", not _game.player.body().freeze and _game.player.ball_position().distance_to(_placed) < 0.01, "frozen %s, body %.1f m away" % [_game.player.body().freeze, _game.player.ball_position().distance_to(_placed)])
		# A ride that catches the ball on this tick reads the body's speed, so it is the new one already.
		_t.check("FS-5 the placed ball's body has its new speed at once", _game.player.body().linear_velocity.is_equal_approx(PLACED_SPEED), "body speed %s" % _game.player.body().linear_velocity)
		# This is a frame, not a physics tick (the camp walk places the ball from a key press):
		# the lens snaps before the reset has run and must still land on the new spot.
		_game.camera.snap(Vector3(0.0, 0.0, -1.0))
		_t.check("FS-5 a placed ball reads as placed in the same breath", _game.player.shown_position().distance_to(_placed) < 0.01, "shown %.1f m away" % _game.player.shown_position().distance_to(_placed))
		_t.check("FS-5 a lens snapped in that breath is on the new spot", _game.camera.global_position.distance_to(_placed) < 2.0, "lens %.1f m away" % _game.camera.global_position.distance_to(_placed))
	elif _step >= 13 and _step <= 16:
		_worst = maxf(_worst, _game.player.shown_position().distance_to(_game.player.body().global_position))
		_strayed = maxf(_strayed, _game.player.ball_position().distance_to(_placed))
		if _step == 16:
			_t.check("FS-5 the ball stays where it was placed on the frames after", _strayed < 2.0, "up to %.1f m from the spot" % _strayed)
			# FS-5: no frame after a placement is drawn on the way from the old spot.
			_t.check("FS-5 a placed ball is drawn where it was placed, not sliding from the old spot", _worst < 1.0, "drawn up to %.1f m from the ball" % _worst)
	elif _step > 16:
		# FS-6: a rolling ball is drawn behind its body between ticks (the control), and reads
		# exactly on its body inside a tick.
		_frame_gap = maxf(_frame_gap, _game.player.shown_position().distance_to(_game.player.body().global_position))
		if _ticks >= 12:
			_t.check("FS-6 between ticks a rolling ball is drawn off its body", _frame_gap > 0.01, "largest gap %.4f m" % _frame_gap)
			_t.check("FS-6 inside a tick the drawn place is the body's place", _tick_gap == 0.0, "largest gap %.4f m" % _tick_gap)
			_game.toggle_interpolation()
			quit(_t.verdict())
	return false


func _physics_process(_delta: float) -> bool:
	if _step <= 16:
		return false
	_ticks += 1
	var velocity: Vector3 = _game.player.state.velocity
	_game.player.set_velocity_now(Vector3(40.0, velocity.y, 0.0), "test")
	if _ticks > 3:
		_tick_gap = maxf(_tick_gap, _game.player.shown_position().distance_to(_game.player.body().global_position))
	return false


func _settings() -> void:
	var dir: String = _game.storage_dir
	var file := dir.path_join(SettingsStore.FILE)
	if FileAccess.file_exists(file):
		DirAccess.remove_absolute(file)
	_game.settings_store().load_saved()
	_game.apply_saved_display(["--preset=high"])

	# FS-1: wanted by default, and a test's tree stays as the bots run it.
	_t.check("FS-1 on by default in the store and as the game's wish", _game.settings_store().frame_smoothing() and _game.frame_smoothing, "store %s wish %s" % [_game.settings_store().frame_smoothing(), _game.frame_smoothing])
	_t.check("FS-1 a test's tree does not interpolate", not _game.interpolating() and not physics_interpolation, "tree %s" % physics_interpolation)

	# FS-2: the Display row saves the wish and reads it back.
	var page = _game.get_node("PauseMenu").settings_page()
	_t.check("FS-2 the page lists a Frame smoothing row", page.row("frame_smoothing") != null, "rows")
	_t.eq("FS-2 the row reads on", page.read("frame_smoothing"), {"label": "Frame smoothing", "value": "", "pip": 1})
	page.press("frame_smoothing")
	_t.eq("FS-2 the row reads off", page.read("frame_smoothing"), {"label": "Frame smoothing", "value": "", "pip": 0})
	_t.check("FS-2 the store and the game hold it", not _game.settings_store().frame_smoothing() and not _game.frame_smoothing, "store")
	_t.check("FS-2 off round-trips through save and load", not SettingsStore.new(dir).frame_smoothing(), "reloaded")
	_game.frame_smoothing = true
	_game.apply_saved_display(["--preset=high"])
	_t.check("FS-2 launch applies the saved wish", not _game.frame_smoothing, "wish after launch")
	page.press("frame_smoothing")
	_t.check("FS-2 on again, and the test's tree still does not interpolate", SettingsStore.new(dir).frame_smoothing() and _game.frame_smoothing and not _game.interpolating(), "restored")
	if FileAccess.file_exists(file):
		DirAccess.remove_absolute(file)

	# FS-3: the session switch (F3 under --dev) turns the tree's interpolation on and off, and
	# the engine's jitter fix rests while it is on.
	var jitter := Engine.physics_jitter_fix
	_t.check("FS-3 the switch turns it on", _game.toggle_interpolation() and physics_interpolation, "tree %s" % physics_interpolation)
	_t.near("FS-3 the jitter fix rests while smoothing is on", Engine.physics_jitter_fix, 0.0)
	_t.check("FS-3 the switch turns it off", not _game.toggle_interpolation() and not physics_interpolation, "tree %s" % physics_interpolation)
	_t.near("FS-3 the jitter fix is back", Engine.physics_jitter_fix, jitter)


func _bodies() -> void:
	# FS-4: opt-in per body. The Game root is off, so a node that says nothing is drawn where
	# it is; only the ball's body asks.
	_t.eq("FS-4 the Game root is off", _game.physics_interpolation_mode, Node.PHYSICS_INTERPOLATION_MODE_OFF)
	var asking: Array[String] = []
	for node: Node3D in _game.find_children("*", "Node3D", true, false):
		if node.physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_ON:
			asking.append(String(_game.get_path_to(node)))
	_t.eq("FS-4 only the ball's body asks for interpolation", asking, [String(_game.get_path_to(_game.player._rigid))])
	_t.check("FS-4 the ball's body is interpolated and the lens is not", _game.player._rigid.is_physics_interpolated() and not _game.camera.is_physics_interpolated() and not _game.camera.cam.is_physics_interpolated(), "modes")
