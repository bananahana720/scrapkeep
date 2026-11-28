extends SceneTree

const Game := preload("res://src/game.gd")

# The discovery banner (--discovery=banner, the variant cards replaced) never outlives its moment (visual QA frames 19-26: it stayed
# pinned across the arena, death, victory and the summary). Through the real game on
# a fake clock: it is gone 4 s after it appears, even with the tree paused; it clears
# at once on a flow change, arena entry, death and run end; quick discoveries queue
# and play one at a time; and it follows the UI regions rule: in the toasts band beside
# the HUD's toast column, never in the top or prompts bands.

var _game
var _banner
var _failures := 0
var _step := 0
var _fake_ms := 100000


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _process(_delta: float) -> bool:
	if _game == null or _game.flow == null:
		return false
	match _step:
		0:
			_banner = _game.presentation.banner
			_banner.cards = false
			_banner.now_ms = func() -> int: return _fake_ms
			_game.ctx.calm = true
			_game.flow.press_start()
			_game.flow.choose_class(0)
			_discover("wrecking_ball")
			_step = 1
		1:
			var up: bool = _banner.showing() and _banner.visible
			paused = true
			_fake_ms += 4000
			_step = 2
			_check("appears", up, "a discovery shows the banner '%s'" % _banner.last_title)
		2:
			# A frame later, with the tree paused (as on the death and summary screens).
			_check("gone after 4 s", not _banner.visible and not _banner.showing(), "4 s after it appeared the banner is gone, with the tree paused")
			paused = false
			_discover("wrecking_ball")
			_game.events.flow_changed.emit("gates")
			var flow_gone: bool = not _banner.visible
			_discover("wrecking_ball")
			_game.events.stage_content_cleared.emit("arena")
			var arena_gone: bool = not _banner.visible
			_discover("wrecking_ball")
			_game.events.player_died.emit()
			var death_gone: bool = not _banner.visible
			_discover("wrecking_ball")
			_game.events.run_ended.emit(true)
			var end_gone: bool = not _banner.visible and _banner.queued() == 0
			_check("gone on a flow change", flow_gone and arena_gone and death_gone and end_gone, "cleared at once by flow_changed (%s), stage_content_cleared (%s), player_died (%s) and run_ended (%s)" % [flow_gone, arena_gone, death_gone, end_gone])
			# Two quick discoveries: one at a time.
			_discover("wrecking_ball")
			_discover("boarding_party")
			var first: String = _banner.last_title
			var one_at_a_time: bool = _banner.queued() == 1
			_fake_ms += 3100
			_step = 3
			_check("queued one at a time", one_at_a_time, "the second discovery waits while '%s' shows" % first)
		3:
			var second_up: bool = _banner.showing() and _banner.queued() == 0 and _banner.shown >= 7
			_check("next plays after", second_up, "when the first clears, the queued one plays ('%s')" % _banner.last_title)
			# Its own region, in the 1600 x 900 layout: clear of the objective line and
			# the toast column.
			_fake_ms += 1000
			_step = 4
		4:
			var rect: Rect2 = _banner._panel.get_global_rect()
			var screen: Vector2 = _banner.get_viewport_rect().size
			var ScreenRegions = load("res://src/core/screen_regions.gd")
			var top: Rect2 = ScreenRegions.rect("top", screen)
			var prompts: Rect2 = ScreenRegions.rect("prompts", screen)
			var band: Rect2 = ScreenRegions.rect("toasts", screen)
			var hud_toasts: Rect2 = _game.hud._toasts.get_global_rect() if _game.get("hud") != null else Rect2()
			hud_toasts.size.y = band.size.y
			var crosshair := screen * 0.5
			var clear: bool = not rect.intersects(top) and not rect.intersects(prompts) and not rect.intersects(hud_toasts) and not rect.has_point(crosshair) and rect.end.x <= screen.x and rect.position.y >= band.position.y
			_check("own region", clear, "the banner at %s is in the toasts band (%s) beside the HUD toast column (%s), clear of the top band, the prompts and the crosshair" % [rect, band, hud_toasts])
			print("presentation_banner_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
			quit(0 if _failures == 0 else 1)
			return true
	return false


func _discover(id: String) -> void:
	_game.presentation.banner.show_discovery(id.capitalize(), "build", "A test discovery that is long enough to wrap onto a second line.", "New synergy")


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])
