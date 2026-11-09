extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ScreenRegions := preload("res://src/ui/screen_regions.gd")
const T := preload("res://tests/support/t.gd")

# The top-right corner holds the radio chip, the unlock plate (achievement, record, radio take)
# and the field note pill. They were pinned to fixed heights in one corner: a plate drew over
# the chip, and the pill landed on a two-line plate's second line. C1: in play with all three
# up, they are a column, chip then plate then pill, and no two overlap. C2: all three end inside
# the screen's right edge. C3: on a menu, where the chip is away, the plate takes the top slot.
# C4: the plate, two lines tall, still ends inside the top band (screen_regions.gd), so no toast
# can meet it. C5: the pill, which hangs below that band, is right of the toast column.

var _t := T.new("ui_corner_column_test")


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	var game = Game.new()
	game.test_mode = true
	game.table = "alpha"
	root.add_child(game)
	await physics_frame
	var hud = game.hud
	var screen: Vector2 = root.get_visible_rect().size

	hud.take_found("Lights On, Late Set", "Moss's Back Room", "b-side")
	await _frames(4)
	var menu: Array = hud.corner_rects()
	_t.check("C3 on a menu the plate is alone in the top slot", menu.size() == 1 and menu[0]["name"] == "plate"
			and is_equal_approx(menu[0]["rect"].position.y, hud.ACH_TOP), str(menu))
	hud.clear_achievement_toasts()

	game.flow.press_start()
	game.flow.choose_class(0)
	game.player.source = Intent.Scripted.new()
	await _frames(4)
	hud.take_found("Lights On, Late Set", "Moss's Back Room", "b-side")
	game.codex.lore_found.emit("lore.spillway.note.shift")
	await _frames(6)
	var rects: Array = hud.corner_rects()
	var names: Array = rects.map(func(r): return r["name"])
	_t.eq("C1 chip, plate and pill are all up", names, ["chip", "plate", "pill"])
	var apart := true
	var ordered := true
	var inside := true
	for i in rects.size():
		var rect: Rect2 = rects[i]["rect"]
		inside = inside and rect.size.x > 1.0 and rect.end.x <= screen.x and rect.position.x >= 0.0
		for j in range(i + 1, rects.size()):
			apart = apart and not rect.intersects(rects[j]["rect"])
			ordered = ordered and rect.end.y <= rects[j]["rect"].position.y
	_t.check("C1 no two of them overlap", apart and rects.size() == 3, str(rects))
	_t.check("C1 they stack top to bottom", ordered and rects.size() == 3, str(rects))
	_t.check("C2 each ends inside the screen", inside and rects.size() == 3, str(rects))
	var band: Rect2 = ScreenRegions.rect("top", screen)
	var plate_end: float = rects[1]["rect"].end.y if rects.size() == 3 else INF
	_t.check("C4 a two-line plate under the chip ends inside the top band", plate_end <= band.end.y, "plate ends %.1f, band ends %.1f" % [plate_end, band.end.y])
	var toasts: Rect2 = hud._toasts.get_global_rect()
	var pill: Rect2 = rects[2]["rect"] if rects.size() == 3 else Rect2()
	_t.check("C5 the pill sits right of the toast column", pill.position.x >= toasts.end.x, "pill starts %.1f, toasts end %.1f" % [pill.position.x, toasts.end.x])
	quit(_t.verdict())
