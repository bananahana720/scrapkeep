extends SceneTree

const Game := preload("res://src/game.gd")
const Palette := preload("res://src/core/palette.gd")
const T := preload("res://tests/support/t.gd")
var _t := T.new("pol_ui_title_readability_test")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var game := Game.new()
	game.test_mode = true
	root.add_child(game)
	await process_frame
	game.screens._tween.custom_step(1.0)
	var screens = game.screens
	_t.check("title leaves lower half of stage unobscured", screens._veil.anchor_bottom <= 0.5)
	_t.check("title text and actions stay above the stage", screens._content.anchor_bottom <= 0.5)
	var backdrop: Color = screens._veil.color
	var worst := Color.WHITE.lerp(backdrop, backdrop.a)
	for ink in [Palette.AMBER, Palette.SAND, Color.WHITE]:
		var ratio := (_luminance(ink) + 0.05) / (_luminance(worst) + 0.05)
		_t.check("title ink contrast is at least 4.5 over brightest stage", ratio >= 4.5, str(ratio))
	# Include the optional actions; their input routes have separate UI tests.
	screens._action("continue", "key_c", "Continue")
	screens._action("companion", "key_m", "Companion")
	for pixels in [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]:
		root.size = pixels
		root.content_scale_size = pixels
		for frame in 3:
			await process_frame
		for node in [screens._title, screens._body, screens._actions]:
			var rect: Rect2 = node.get_global_rect()
			_t.check("title controls fit above deck at %s" % pixels, rect.position.x >= 0.0
				and rect.end.x <= pixels.x and rect.position.y >= 0.0 and rect.end.y <= pixels.y * 0.5, str(rect))
	game.screens.toggle_help()
	_t.eq("help restores full backdrop", screens._veil.anchor_bottom, 1.0)
	game.screens.toggle_help()
	_t.check("help back reveals stage again", screens._veil.anchor_bottom <= 0.5)
	game.screens.toggle_camp()
	_t.eq("camp restores full backdrop", screens._veil.anchor_bottom, 1.0)
	game.screens.toggle_camp()
	_t.check("leaving the camp restores the title layout", screens._veil.anchor_bottom <= 0.5, str(screens._veil.anchor_bottom))
	game.flow.press_start()
	_t.eq("class cards keep full backdrop", screens._veil.anchor_bottom, 1.0)
	game.free()
	quit(_t.verdict())

func _luminance(c: Color) -> float:
	var linear := c.srgb_to_linear()
	return linear.r * 0.2126 + linear.g * 0.7152 + linear.b * 0.0722
