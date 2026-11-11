extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ScreenRegions := preload("res://src/ui/screen_regions.gd")
const T := preload("res://tests/support/t.gd")
const ScreenBusy := preload("res://src/ui/screen_busy.gd")

# The top-right corner holds the radio chip, the unlock plate (achievement, record, radio take)
# and the field note pill. They were pinned to fixed heights in one corner: a plate drew over
# the chip, and the pill landed on a two-line plate's second line. C1: in play with all three
# up, they are a column, chip then plate then pill, and no two overlap. C2: all three end inside
# the screen's right edge. C3: on a menu, where the chip is away, the plate takes the top slot.
# C4: the plate, two lines tall, still ends inside the top band (screen_regions.gd), so no toast
# can meet it. C5: the pill, which hangs below that band, is right of the toast column.
# C6: a chip swollen by a station change is twice its height; a new plate waits for it to settle.

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
	# The cold open has the floor first (plates and the pill wait for a flourish's reading matter); this is about the corner.
	game.presentation.flourish.stop_all()
	hud.take_found("Lights On, Late Set", "Moss's Back Room", "b-side")
	game.codex.lore_found.emit("lore.spillway.note.shift")
	# Wave 36 (PF-19): cards that can wait take turns, so the plate and the pill are never up together
	# (the old C1 wanted all three at once). Each is read on the frames it is up, beside the chip; the
	# bound is both cards' lives and the screen's quiet hold, from the source's constants, plus a second.
	var bound: float = ScreenBusy.SETTLE + hud.ACH_TOTAL + hud.LORE_TOTAL + 1.0
	var with_plate: Array = []
	var with_pill: Array = []
	var together := false
	var waited := 0.0
	while waited < bound and (with_plate.is_empty() or with_pill.is_empty()):
		await process_frame
		waited += game.get_process_delta_time()
		var now: Array = hud.corner_rects()
		var now_names: Array = now.map(func(r): return r["name"])
		together = together or (now_names.has("plate") and now_names.has("pill"))
		if now_names == ["chip", "plate"] and with_plate.is_empty():
			with_plate = now
		if now_names == ["chip", "pill"] and with_pill.is_empty():
			with_pill = now
	_t.check("C1 the plate and the pill each come up beside the chip, one at a time", not with_plate.is_empty() and not with_pill.is_empty() and not together,
		"plate %s, pill %s, together %s, %.2f s of %.2f" % [with_plate, with_pill, together, waited, bound])
	for rects in [with_plate, with_pill]:
		var what: String = rects[1]["name"] if rects.size() == 2 else "none"
		var apart: bool = rects.size() == 2
		var ordered: bool = rects.size() == 2
		var inside: bool = rects.size() == 2
		for i in rects.size():
			var rect: Rect2 = rects[i]["rect"]
			inside = inside and rect.size.x > 1.0 and rect.end.x <= screen.x and rect.position.x >= 0.0
			for j in range(i + 1, rects.size()):
				apart = apart and not rect.intersects(rects[j]["rect"])
				ordered = ordered and rect.end.y <= rects[j]["rect"].position.y
		_t.check("C1 the chip and the %s do not overlap" % what, apart, str(rects))
		_t.check("C1 the chip and the %s stack top to bottom" % what, ordered, str(rects))
		_t.check("C2 the chip and the %s end inside the screen" % what, inside, str(rects))
	var band: Rect2 = ScreenRegions.rect("top", screen)
	var plate_end: float = with_plate[1]["rect"].end.y if with_plate.size() == 2 else INF
	_t.check("C4 a two-line plate under the chip ends inside the top band", plate_end <= band.end.y, "plate ends %.1f, band ends %.1f" % [plate_end, band.end.y])
	var toasts: Rect2 = hud._toasts.get_global_rect()
	var pill: Rect2 = with_pill[1]["rect"] if with_pill.size() == 2 else Rect2()
	_t.check("C5 the pill sits right of the toast column", with_pill.size() == 2 and pill.position.x >= toasts.end.x, "pill starts %.1f, toasts end %.1f" % [pill.position.x, toasts.end.x])

	hud.clear_achievement_toasts()
	await _frames(2)
	game.radio_deck.dial.swell()
	hud.take_found("Cable Reach", "Moss's Back Room")
	await _frames(6)
	var swollen: Array = hud.corner_rects().map(func(r): return r["name"])
	_t.check("C6 while the chip is swollen from a station change, a new plate waits", not swollen.has("plate") and hud.tune_waiting().size() == 1,
		"%s, %d waiting" % [swollen, hud.tune_waiting().size()])
	quit(_t.verdict())
