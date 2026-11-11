extends SceneTree

const Game := preload("res://src/game.gd")
const SettingsStore := preload("res://src/ui/settings_store.gd")
const T := preload("res://tests/support/t.gd")

# Wide picture (Andrew approved option B, 10 Nov 2026): on a screen wider than 16:9 the picture fills
# it, on by default, with a Display row "Wide picture: on / off" that brings back today's bars.
# Checked here: the default, the row, the save round trip; that only a played game's window fills
# (a headless window is not 16:9, so filling there would move every test's HUD and widen every
# bot's view) and that --wide beats both; and what "fill" does on the ultrawide's shape (a
# 3440x1440 window shows a 2150x900 picture, against 1600x900 with bars).

var _t := T.new("wide_picture_test")
var _game
var _step := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _process(_delta: float) -> bool:
	if _game == null or _game.flow == null:
		return false
	_step += 1
	if _step == 1:
		_run()
		quit(_t.verdict())
	return false


func _run() -> void:
	var dir: String = _game.storage_dir
	var file := dir.path_join(SettingsStore.FILE)
	if FileAccess.file_exists(file):
		DirAccess.remove_absolute(file)
	_game.settings_store().load_saved()
	_game.apply_saved_display(["--preset=high"])
	_t.check("WP-1 on by default in the store and as the game's wish", _game.settings_store().wide_picture() and _game.wide_picture, "store %s" % _game.settings_store().wide_picture())
	_t.check("WP-1 a test's window keeps the 16:9 picture", root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP, "aspect %d" % root.content_scale_aspect)

	var page = _game.get_node("PauseMenu").settings_page()
	_t.eq("WP-2 the Display row reads on", page.read("wide_picture"), {"label": "Wide picture", "value": "", "pip": 1})
	page.press("wide_picture")
	_t.eq("WP-2 a press reads off", page.read("wide_picture"), {"label": "Wide picture", "value": "", "pip": 0})
	_t.check("WP-2 the store and the game hold it", not _game.settings_store().wide_picture() and not _game.wide_picture, "store")
	_t.check("WP-2 off round-trips through save and load", not SettingsStore.new(dir).wide_picture(), "reloaded")
	_game.wide_picture = true
	_game.apply_saved_display(["--preset=high"])
	_t.check("WP-2 launch applies the saved wish", not _game.wide_picture, "wish after launch")
	page.press("wide_picture")
	_t.check("WP-2 on again", SettingsStore.new(dir).wide_picture() and _game.wide_picture, "restored")

	var ultra := Vector2i(3440, 1440)
	_t.check("WP-3 a played ultrawide window fills when wished", Game.wide_fills(true, true, [], ultra), "")
	_t.check("WP-3 a played window keeps the bars when not", not Game.wide_fills(false, true, [], ultra), "")
	_t.check("WP-3 a test or headless window never fills on the wish", not Game.wide_fills(true, false, [], ultra), "")
	_t.check("WP-3 --wide=1 fills anywhere, --wide=0 keeps the bars", Game.wide_fills(false, false, ["--wide=1"], ultra) and not Game.wide_fills(true, true, ["--wide=0"], ultra), "")
	_t.check("WP-3 a 16:9 or 16:10 window keeps (expand there would narrow the view)", not Game.wide_fills(true, true, [], Vector2i(2560, 1440)) and not Game.wide_fills(true, true, ["--wide=1"], Vector2i(1280, 800)), "")
	# The root itself, under --wide's override path: the game's own call sets the window's aspect,
	# and a resize to 16:9 is read again.
	# The game reads every resize (its own call is checked last): these raw window checks go unheard.
	if root.size_changed.is_connected(_game._fit_picture):
		root.size_changed.disconnect(_game._fit_picture)
	var was := root.size
	var args := ["--wide=1"]
	root.size = ultra
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND if Game.wide_fills(true, true, args, root.size) else Window.CONTENT_SCALE_ASPECT_KEEP
	_t.check("WP-3 the root fills on the ultrawide", root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_EXPAND, "")
	root.size = was

	# The ultrawide's shape: a 3440x1440 window over the 1600x900 base picture.
	root.size = Vector2i(3440, 1440)
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	var kept := root.get_visible_rect().size
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	var wide := root.get_visible_rect().size
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = was
	_t.eq("WP-4 bars: a 3440x1440 window shows the 1600x900 picture", kept, Vector2(1600, 900))
	_t.check("WP-4 fill: it shows a picture as high and wider (2150x900)", is_equal_approx(wide.y, 900.0) and absf(wide.x - 2150.0) < 1.0, "visible %s" % wide)
	_game.set_wide_picture(true)
	_t.check("WP-5 the game's own call listens for resizes, and a test window keeps", root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP and root.size_changed.is_connected(_game._fit_picture), "aspect %d" % root.content_scale_aspect)
	if FileAccess.file_exists(file):
		DirAccess.remove_absolute(file)
