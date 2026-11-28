extends SceneTree

const Game := preload("res://src/game.gd")
const SettingsStore := preload("res://src/ui/settings_store.gd")
const Comfort := preload("res://src/core/comfort.gd")
const T := preload("res://tests/support/t.gd")

# Reduced motion (EV-0248): a saved setting on the settings page that holds the camera still,
# drops the hit-edge flash to a quarter and stills decorative motion. Measured on the real
# camera, edge flash and settings page: the computed shake amplitude, FOV punch and flash alpha
# with it off and on, the save round trip, and that nothing the setting touches is a telegraph.

var _t := T.new("reduced_motion_test")
var _game
var _done := false


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _process(_delta: float) -> bool:
	if _game == null or _game.flow == null or _done:
		return false
	_done = true
	_run()
	return true


func _run() -> void:
	var dir: String = _game.storage_dir
	var file := dir.path_join(SettingsStore.FILE)
	if FileAccess.file_exists(file):
		DirAccess.remove_absolute(file)
	_game.settings_store().load_saved()
	var cam = _game.camera
	var edge = _game.presentation.vfx.edge

	# RM-1: off by default; a shake, a punch and a flash have their full size.
	_t.check("RM-1 off by default", not _game.settings_store().reduced_motion(), "store default")
	cam.shake(0.8, 0.4)
	cam.punch_fov(6.0, 0.3)
	_t.near("RM-1 shake amplitude is the full shake", cam.shake_amplitude(), 0.8)
	var full_punch: float = cam._punch
	_t.near("RM-1 FOV punch is the full punch", full_punch, 6.0)
	edge.flash(Vector2.LEFT, Color.RED, 0.8, 0.4)
	var full_flash: float = edge.alpha
	_t.near("RM-1 flash alpha is the full strength", full_flash, 0.8)

	# RM-2: the settings page toggle turns it on, saves it and applies it at once.
	var page = _game.get_node("PauseMenu").settings_page()
	_t.check("RM-2 the page lists a Reduced motion row", page.row("reduced_motion") != null, "rows")
	_t.eq("RM-2 the row reads off", page.read("reduced_motion"), {"label": "Less motion", "value": "", "pip": 0})
	page.press("reduced_motion")
	_t.eq("RM-2 the row reads on", page.read("reduced_motion"), {"label": "Less motion", "value": "", "pip": 1})
	_t.check("RM-2 the store holds it", _game.settings_store().reduced_motion(), "store")

	# RM-3: round trip through the saved file.
	var again := SettingsStore.new(dir)
	_t.check("RM-3 the setting round-trips through save and load", again.reduced_motion(), "reloaded")
	again.set_comfort(SettingsStore.REDUCED_MOTION, 0.0)
	_t.check("RM-3 off round-trips too", not SettingsStore.new(dir).reduced_motion(), "reloaded off")
	again.set_comfort(SettingsStore.REDUCED_MOTION, 1.0)

	# RM-4: computed values with it on.
	cam._shake = 0.0
	cam._punch = 0.0
	cam.shake(0.8, 0.4)
	cam.punch_fov(6.0, 0.3)
	cam.kick(Vector3.RIGHT, 1.0)
	_t.near("RM-4 shake amplitude is 0", cam.shake_amplitude(), 0.0)
	_t.near("RM-4 FOV punch is 0", cam._punch, 0.0)
	_t.near("RM-4 kick is 0", cam._kick.length(), 0.0)
	edge.flash(Vector2.LEFT, Color.RED, 0.8, 0.4)
	_t.check("RM-4 flash alpha is at most a quarter of normal", edge.alpha <= full_flash * 0.25 + 0.0001 and edge.alpha > 0.0, "%f vs %f" % [edge.alpha, full_flash])
	_t.near("RM-4 enemy idle motion is off", Comfort.motion_scale(), 0.0)

	# RM-5: boot applies the saved value; turning it off restores everything.
	Comfort.reduced_motion = false
	_game.apply_saved_display(["--preset=high"])
	_t.check("RM-5 launch applies the saved setting", Comfort.reduced_motion and cam._comfort_scale() == 0.0 and Comfort.motion_scale() == 0.0, "camera and enemy motion")
	page.press("reduced_motion")
	_t.check("RM-5 off again", not Comfort.reduced_motion and Comfort.motion_scale() == 1.0 and edge.flash_scale == 1.0, "restored")
	cam._shake = 0.0
	cam.shake(0.8, 0.4)
	_t.near("RM-5 the shake is back", cam.shake_amplitude(), 0.8)

	if FileAccess.file_exists(file):
		DirAccess.remove_absolute(file)
	quit(_t.verdict())
