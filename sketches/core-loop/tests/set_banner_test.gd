extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const PartSets := preload("res://src/build/part_sets.gd")
const UiProfile := preload("res://src/ui/ui_profile.gd")

# Completing a part set says so (world 1 design pass, 9 Nov: "Finishing a part set shows nothing.
# Named pairs already get a callout"). The third distinct member of a set, gained in play, raises
# one "Set complete" banner with the set's name and its one line, edged in the colour of the
# set's studs on the ball.
# 1. Two members raise nothing; the third raises build.set_completed once, with the set's row.
# 2. The banner shows that name, line, kicker and colour.
# 3. A fourth member, and selling a member and taking it back, raise nothing: once per run.
# 4. A recompute with no gain (a resume or a retry restoring a held set) raises nothing.
# 5. In cards mode the first showing ever is the card and the next run's is the small banner,
#    with its line and the set's colour; an ordinary repeat discovery still shows nothing.
# 6. The set's banner goes ahead of first-find cards still waiting.
# smoke: timeout=180s

# Live Wire without Arc Coil (part_sets_test's fixture), then a fourth member.
const WIRE := ["live_line", "beacon_lamp", "echo_locator"]
const FOURTH := "cap_relay"
const SET := "live_wire"
const DIR := "user://set_banner_test/"

var _t := preload("res://tests/support/t.gd").new("set_banner_test")
var _game
var _raised: Array = []


func _initialize() -> void:
	_run()


func _run() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	_game.world.set_physics_process(false)
	_game.world.activities.set_physics_process(false)
	_game.flow.press_start()
	_game.flow.choose_class(0)
	await physics_frame
	_check()
	_game.free()
	quit(_t.verdict())


func _check() -> void:
	var run = _game.run
	var build = _game.ctx.build
	var banner = _game.presentation.banner
	var row: Dictionary = PartSets.SETS[SET]
	# A fresh profile, so the first showing is the first ever.
	DirAccess.make_dir_recursive_absolute(DIR)
	DirAccess.remove_absolute(DIR + UiProfile.FILE)
	banner.profile = UiProfile.new(DIR)
	banner.cards = true
	banner.dismiss(true)
	build.set_completed.connect(func(set_id: String, title: String, text: String, color: Color):
		_raised.append([set_id, title, text, color]))
	var shown_before: int = banner.shown
	run.add_part(WIRE[0], "test")
	run.add_part(WIRE[1], "test")
	_t.check("two members raise nothing", _raised.is_empty() and not banner._queue.any(func(item): return item[6] == "set:" + SET),
		"raised %s" % [_raised])
	run.add_part(WIRE[2], "test")
	_t.check("the third member raises the set once, with its row", _raised == [[SET, row["name"], row["text"], row["color"]]],
		"raised %s" % [_raised])
	# One find card is up (the first part's, the piece that finished the set) and the rest wait. In the
	# screen's one line (screen_busy.gd, wave 36 ruling) the set goes first among the waiting cards and
	# never takes the card on screen off: its banner and chime land next, not two cards later.
	var busy = _game.ctx.screen_busy
	var line: Array = busy.waiting()
	var finds_after: bool = line.size() > 1 and line.slice(1).all(func(key: String): return key.begins_with("part:") or key.begins_with("find:"))
	_t.check("the set goes ahead of the waiting part cards", busy.showing().ends_with(WIRE[0]) and not line.is_empty() and line[0] == "set:" + SET and finds_after
		and banner._queue[0][6] == "set:" + SET,
		"on screen %s, line %s, banner queue %s" % [busy.showing(), line, banner._queue.map(func(item): return item[6])])
	# The find card up ends (its turn is over); the set is next.
	_game.presentation.ceremony.view.card = {}
	_game.presentation.ceremony._release_slot()
	banner.dismiss(false)
	busy.done(busy.showing())
	var guard := 0
	while banner.last_title != row["name"] and guard < 8:
		guard += 1
		banner.dismiss(false)
		banner._next()
	_t.check("the banner names the set, in its colour", guard == 1 and banner.showing() and banner.last_title == row["name"]
		and banner._body.text == row["text"] and banner._kicker.text.begins_with("SET COMPLETE")
		and banner._style.border_color.is_equal_approx(row["color"]) and banner.shown > shown_before,
		"title '%s', body '%s', kicker '%s', edge %s vs %s" % [banner.last_title, banner._body.text, banner._kicker.text,
			banner._style.border_color, row["color"]])
	_t.check("the first showing ever is the card", banner.last_style == "card" and banner.profile.discovered("set:" + SET),
		"style '%s'" % banner.last_style)
	run.add_part(FOURTH, "test")
	build.shop._remove_part(WIRE[1])
	run.add_part(WIRE[1], "test")
	_t.check("a fourth member and a re-bought member raise nothing more", _raised.size() == 1, "raised %d" % _raised.size())
	# A resume or retry: the ledger starts again and the held parts recompute with no gain.
	build.set_ledger = PartSets.Ledger.new()
	build.recompute()
	_t.check("a recompute with no gain raises nothing", _raised.size() == 1 and build.set_ledger.found == [SET],
		"raised %d, ledger %s" % [_raised.size(), build.set_ledger.found])
	# The next run completes the set again: the small banner, not nothing.
	banner.dismiss(true)
	var shown_mid: int = banner.shown
	_game.presentation._on_set_completed(SET, row["name"], row["text"], row["color"])
	_t.check("a later run's completion shows the small banner", banner.showing() and banner.last_style == "banner"
		and banner.last_title == row["name"] and banner.shown == shown_mid + 1, "style '%s', shown %d to %d" % [banner.last_style, shown_mid, banner.shown])
	# A banner straight after a card kept the card's trim and lost its whole line (seen in the
	# 9 Nov captures); the icon wears the set's colour like the edge.
	var icon_pixel: Color = banner._icon.texture.get_image().get_pixel(32, 32)
	_t.check("the small banner keeps its line and wears the set's colour", banner._body.visible and banner._body.text == row["text"]
		and banner._body.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING and banner._body.max_lines_visible == -1
		and Color(icon_pixel.r, icon_pixel.g, icon_pixel.b).is_equal_approx(Color(row["color"].r, row["color"].g, row["color"].b)),
		"body '%s', overrun %d, icon %s vs %s" % [banner._body.text, banner._body.text_overrun_behavior, icon_pixel, row["color"]])
	banner.dismiss(true)
	banner.show_discovery(row["name"], "build", row["text"], "Synergy", "set:" + SET)
	_t.check("an ordinary repeat discovery still shows nothing", not banner.showing() and banner.queued() == 0,
		"showing %s, queued %d" % [banner.showing(), banner.queued()])
