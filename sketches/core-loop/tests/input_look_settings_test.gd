extends SceneTree

const Game := preload("res://src/game.gd")
const SettingsStore := preload("res://src/ui/settings_store.gd")

# IN1: saved look settings keep the existing rates and radial deadzone by default;
# sensitivity scales both stick axes and mouse look, while invert flips stick pitch only.
# A real game boot applies the saved values. Storage stays in cleared test-only folders.

var _game
var _dir := "user://input-look-settings-%d" % OS.get_process_id()
var _boot_dir := "user://test-%d" % OS.get_process_id()
var _failures := 0


func _initialize() -> void:
	_clear(_dir.path_join("absent"))
	_clear(_dir)
	_clear(_boot_dir)
	DirAccess.make_dir_recursive_absolute(_dir)
	DirAccess.make_dir_recursive_absolute(_boot_dir)
	_store()
	var file := FileAccess.open(_boot_dir.path_join(SettingsStore.FILE), FileAccess.WRITE)
	file.store_string(FileAccess.get_file_as_string(_dir.path_join(SettingsStore.FILE)))
	file.close()
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run.call_deferred()


func _clear(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for name in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(name))
	DirAccess.remove_absolute(dir)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _near(label: String, actual: float, expected: float) -> void:
	_report(label, absf(actual - expected) <= 0.000002, "%.8f expected %.8f" % [actual, expected])


func _defaults(store) -> void:
	_near("default stick sensitivity", store.stick_sensitivity(), 2.6)
	_near("default mouse sensitivity", store.mouse_sensitivity(), 0.0022)
	_near("default stick deadzone", store.stick_deadzone(), 0.2)
	_report("default invert off", not store.invert_y(), "invert %s" % store.invert_y())


func _store() -> void:
	var store = SettingsStore.new(_dir)
	_defaults(store)
	var file := FileAccess.open(store.path, FileAccess.WRITE)
	file.store_string('{"volumes":{"music":0.4},"comfort":{"shake":0.3},"bindings":{"cl_jump":"key:G"}}')
	file.close()
	store.load_saved()
	_defaults(store)
	store.set_comfort("hitstop", 0.5)
	var old: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(store.path))
	_report("old file leaves look absent", not old.has("look"), "keys %s" % [old.keys()])
	store.set_look(SettingsStore.STICK_SENSITIVITY, 3.9)
	store.set_look(SettingsStore.INVERT_Y, 1.0)
	store.set_look(SettingsStore.STICK_DEADZONE, 0.3)
	store.set_look(SettingsStore.MOUSE_SENSITIVITY, 0.0044)
	var fresh = SettingsStore.new(_dir)
	_near("saved stick survives reload", fresh.stick_sensitivity(), 3.9)
	_near("saved mouse survives reload", fresh.mouse_sensitivity(), 0.0044)
	_near("saved deadzone survives reload", fresh.stick_deadzone(), 0.3)
	_report("saved invert survives reload", fresh.invert_y(), "invert %s" % fresh.invert_y())
	_near("existing volume survives", fresh.volumes.get("music", -1.0), 0.4)
	_near("existing comfort survives", fresh.comfort.get("shake", -1.0), 0.3)
	_report("existing binding survives", fresh.binding("cl_jump") == "key:G", fresh.binding("cl_jump"))
	# Saving through the existing controls must keep the look values too.
	fresh.set_volume("music", 0.6)
	fresh.set_comfort("shake", 0.7)
	var again = SettingsStore.new(_dir)
	_report("comfort and volume saves keep look", again.invert_y() and is_equal_approx(again.stick_sensitivity(), 3.9) and is_equal_approx(again.stick_deadzone(), 0.3) and is_equal_approx(again.mouse_sensitivity(), 0.0044), "%s" % [again.look])


func _run() -> void:
	while _game.flow == null:
		await process_frame
	var camera = _game.camera
	_near("boot applies stick sensitivity", camera.stick_sensitivity, 3.9)
	_near("boot applies mouse sensitivity", camera.mouse_sensitivity, 0.0044)
	_report("boot applies invert", camera.invert_y, "invert %s" % camera.invert_y)
	for action in ["cl_look_left", "cl_look_right", "cl_look_up", "cl_look_down"]:
		_near("boot applies deadzone to %s" % action, InputMap.action_get_deadzone(action), 0.3)
	_near("look deadzone leaves roll alone", InputMap.action_get_deadzone("cl_right"), 0.2)
	var saved_turn := _turn(camera, Vector2(0.6, 0.4))
	_near("saved stick yaw rate", saved_turn.x, -pow(0.6, 3.0) * 3.9 * 0.1)
	_near("saved stick pitch scales and inverts", saved_turn.y, pow(0.4, 3.0) * 2.4 * 0.1)
	var saved_mouse := _mouse(camera)
	_near("boot applies mouse rate", saved_mouse.x, -12.0 * 0.0044)
	_near("boot invert leaves mouse pitch alone", saved_mouse.y, -8.0 * 0.0044)

	var defaults = SettingsStore.new(_dir.path_join("absent"))
	DirAccess.make_dir_recursive_absolute(_dir.path_join("absent"))
	camera.apply_look_settings(defaults)
	camera.yaw = 0.0
	Input.action_press("cl_look_right", 1.0)
	for i in 10:
		_game.step_stick_look(0.1)
	_near("default full stick turns 2.6 rad in one second", -camera.yaw, 2.6)
	Input.action_release("cl_look_right")
	camera.yaw = 0.0
	Input.action_press("cl_look_right", 0.5)
	_game.step_stick_look(1.0)
	_near("default half stick keeps radial remap and cube", -camera.yaw, 2.6 * pow(0.375, 3.0))
	Input.action_release("cl_look_right")
	_near("default full stick pitch keeps 1.6 rad/s", _turn(camera, Vector2.DOWN).y, -0.16)
	var normal := _turn(camera, Vector2(0.6, 0.4))
	defaults.set_look(SettingsStore.INVERT_Y, 1.0)
	camera.apply_look_settings(defaults)
	var inverted := _turn(camera, Vector2(0.6, 0.4))
	_near("invert leaves stick yaw unchanged", inverted.x, normal.x)
	_near("invert flips stick pitch", inverted.y, -normal.y)
	var mouse := _mouse(camera)
	_near("default mouse yaw is 0.0022 per pixel", mouse.x, -12.0 * 0.0022)
	_near("invert does not flip mouse pitch", mouse.y, -8.0 * 0.0022)
	defaults.set_look(SettingsStore.MOUSE_SENSITIVITY, 0.0044)
	camera.apply_look_settings(defaults)
	var scaled := _mouse(camera)
	_near("mouse sensitivity doubles yaw", scaled.x, mouse.x * 2.0)
	_near("mouse sensitivity doubles pitch", scaled.y, mouse.y * 2.0)

	defaults.set_look(SettingsStore.STICK_DEADZONE, 0.0)
	camera.apply_look_settings(defaults)
	camera.yaw = 0.0
	Input.action_press("cl_look_right", 0.2)
	_game.step_stick_look(1.0)
	_near("zero deadzone responds to a 0.2 push", -camera.yaw, 2.6 * pow(0.2, 3.0))
	defaults.set_look(SettingsStore.STICK_DEADZONE, 0.3)
	camera.apply_look_settings(defaults)
	camera.yaw = 0.0
	_game.step_stick_look(1.0)
	_near("0.3 deadzone rejects a 0.2 push", camera.yaw, 0.0)
	Input.action_release("cl_look_right")
	_game.queue_free()
	await process_frame
	_clear(_dir.path_join("absent"))
	_clear(_dir)
	_clear(_boot_dir)
	print("input_look_settings_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


func _turn(camera, stick: Vector2) -> Vector2:
	camera.yaw = 0.0
	camera.pitch = 0.0
	camera.look_stick(stick, 0.1)
	return Vector2(camera.yaw, camera.pitch)


func _mouse(camera) -> Vector2:
	camera.yaw = 0.0
	camera.pitch = 0.0
	camera.look(Vector2(12.0, 8.0))
	return Vector2(camera.yaw, camera.pitch)
