extends SceneTree

const Game := preload("res://src/game.gd")
const Augments := preload("res://src/movement/augments.gd")
const SettingsStore := preload("res://src/ui/settings_store.gd")
const T := preload("res://tests/support/t.gd")

# IN2: stick aim assist. While the crosshair is on a hookable surface or enemy (the harpoon's
# aim record holds a target), the right stick turns slower by aim_assist * 0.8; with no target,
# at aim_assist 0, and for the mouse, nothing changes. Default aim_assist is 0.5, saved in
# settings.json and clamped to 0..1.

var _t := T.new("input_aim_assist_test")
var _game
var _dir := "user://input-aim-assist-%d" % OS.get_process_id()


func _initialize() -> void:
	var boot := "user://test-%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(boot)
	var file := boot.path_join(SettingsStore.FILE)
	if FileAccess.file_exists(file):
		DirAccess.remove_absolute(file)
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run.call_deferred()


func _yaw(camera, on_target: bool) -> float:
	camera.yaw = 0.0
	camera.pitch = 0.0
	camera.look_stick(Vector2.RIGHT, 0.1, on_target)
	return absf(camera.yaw)


func _frame_yaw(camera) -> float:
	camera.yaw = 0.0
	Input.action_press("cl_look_right", 1.0)
	_game.step_stick_look(0.1)
	Input.action_release("cl_look_right")
	return absf(camera.yaw)


func _run() -> void:
	while _game.flow == null:
		await process_frame
	await process_frame
	var camera = _game.camera
	var store = _game.settings_store()
	DirAccess.make_dir_recursive_absolute(_dir)
	var fresh := SettingsStore.new(_dir)
	_t.near("default aim assist is 0.5", fresh.aim_assist(), 0.5)
	_t.near("camera boots at the default", camera.aim_assist, 0.5)
	camera.apply_look_settings(store)

	var open_rate := _yaw(camera, false)
	_t.near("no target: full stick turns 0.26 rad in 0.1 s", open_rate, 0.26)
	for level in [0.0, 0.25, 0.5, 1.0]:
		store.set_look(SettingsStore.AIM_ASSIST, level)
		_game.apply_look()
		var friction: float = level * 0.8
		_t.near("aim assist %.2f: target yaw ratio is 1 - %.2f" % [level, friction], _yaw(camera, true) / open_rate, 1.0 - friction)
		_t.near("aim assist %.2f: no target is unchanged" % level, _yaw(camera, false) / open_rate, 1.0)

	store.set_look(SettingsStore.AIM_ASSIST, 0.5)
	_game.apply_look()
	camera.pitch = 0.0
	camera.look_stick(Vector2.DOWN, 0.1, false)
	var pitch_open := absf(camera.pitch)
	camera.pitch = 0.0
	camera.look_stick(Vector2.DOWN, 0.1, true)
	_t.near("pitch slows by the same factor", absf(camera.pitch) / pitch_open, 0.6)

	for level in [0.0, 1.0]:
		store.set_look(SettingsStore.AIM_ASSIST, level)
		_game.apply_look()
		camera.yaw = 0.0
		camera.pitch = 0.0
		camera.look(Vector2(12.0, 8.0))
		_t.near("mouse yaw at aim assist %.0f is the plain rate" % level, camera.yaw, -12.0 * 0.0022)
		_t.near("mouse pitch at aim assist %.0f is the plain rate" % level, camera.pitch, -8.0 * 0.0022)

	store.set_look(SettingsStore.AIM_ASSIST, 0.5)
	_game.apply_look()
	var kit = _game.player.kit
	kit.aim = Augments.no_aim()
	_t.check("an empty aim record is no target", not _game.stick_on_target(), "state %s" % kit.aim["state"])
	var plain := _frame_yaw(camera)
	_t.near("game step outside the cone: full stick, 0.26 rad", plain, 0.26)
	for state in [Augments.AIM_REACH, Augments.AIM_ASSIST, Augments.AIM_BODY]:
		kit.aim = {"state": state, "point": Vector3.ZERO, "normal": Vector3.UP}
		_t.check("aim state %d is a target" % state, _game.stick_on_target(), "state %d" % state)
		_t.near("game step in the cone with state %d: ratio 0.6" % state, _frame_yaw(camera) / plain, 0.6)
	kit.aim = Augments.no_aim()
	_t.near("leaving the cone restores the full rate", _frame_yaw(camera) / plain, 1.0)

	store.set_look(SettingsStore.AIM_ASSIST, 7.0)
	_t.near("a too-high value clamps to 1", store.aim_assist(), 1.0)
	store.set_look(SettingsStore.AIM_ASSIST, -2.0)
	_t.near("a negative value clamps to 0", store.aim_assist(), 0.0)
	store.set_look(SettingsStore.AIM_ASSIST, 0.75)
	_t.near("the setting is saved", SettingsStore.new(_game.storage_dir).aim_assist(), 0.75)

	_game.queue_free()
	await process_frame
	var file := _dir.path_join(SettingsStore.FILE)
	if FileAccess.file_exists(file):
		DirAccess.remove_absolute(file)
	DirAccess.remove_absolute(_dir)
	quit(_t.verdict())
