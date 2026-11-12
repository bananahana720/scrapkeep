extends SceneTree

const BossPlate := preload("res://src/ui/boss_plate.gd")
const UiDraw := preload("res://src/ui/ui_draw.gd")
const BossPosture := preload("res://src/combat/boss_posture.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const SpeedTier := preload("res://src/movement/speed_tier.gd")
const Roster := preload("res://src/combat/roster.gd")
const T := preload("res://tests/support/t.gd")

# The boss plate reads one Warden (LEGIBILITY section 4), on the slice table with the
# Warden engaged and driven through combat.strike():
#   B3-1  it reports exactly the name's words; draws four pips; three filled and one empty
#         after a chunk shatters through the rule; the crack mark on a cracked chunk; the
#         bar fills to posture / 100; staggered the bar is the live colour and follows
#         stagger_left; a glance shows the slate glyph for 0.6 s of stepped time; bound to
#         nothing it draws nothing and reports no words.
#         The crack mark is the live colour while the core is open and the neutral role while
#         it is closed; a dead or freed Warden is never held.
#   B3-5  boss_plate.gd and the posture code added to or branched inside warden_look.gd and
#         hero_assets.gd hold no Color( literal: every state colour is a STATE_ROWS row or a role.
# The plate's own clock is stepped by hand (its process is off), never read from the wall.

const SliceDefs := preload("res://src/core/slice_defs.gd")
const PLATING: float = SliceDefs.DEFS[0]["warden_plating"]
const ADDED_CODE := {
	"res://src/combat/warden_look.gd": ["posture_fight", "_rest_core_color", "_update_open", "_update_body_glow", "_update_guard_seams", "_build_seams"],
	"res://src/presentation/hero_assets.gd": ["_rig_warden_jaws", "_update_warden_open", "_warden_chunk_mark", "_update_warden_chunks", "_throw_warden_segment", "_paint_warden_inner"],
}
# Existing functions with a posture branch inside them: only the posture arm is scanned,
# because the plating arm keeps its amber.
const BRANCHED_CODE := {
	"res://src/combat/warden_look.gd": ["_build_badge", "_update_core"],
	"res://src/presentation/hero_assets.gd": ["_dress_warden"],
}

var _t := T.new("boss_plate_test")
# F6 2026-10-04: the plating-table case is gone, and _build_seams has no plating arm left to skip.

var _game
var _combat
var _player
var _warden
var _plate
var _source := Intent.Scripted.new()


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "slice"
	root.add_child(_game)
	_run()


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _seconds(seconds: float) -> void:
	await _frames(roundi(seconds * Engine.physics_ticks_per_second))


func _ground(out: float) -> Vector3:
	return _game.ctx.terrain.drop_point(_warden.global_position.x + out, _warden.global_position.z, 1.5)


func _matched_force() -> float:
	var force := 1.0
	while _combat.punch_of("ram", force) < PLATING:
		force += 0.05
	return force


func _fast_force() -> float:
	var force := _matched_force()
	var cruise: float = _player.tuning.f("cruise")
	while SpeedTier.of(force, cruise) < 2:
		force += 0.5
	return force


func _ram() -> void:
	_combat.strike(_warden, "ram", _matched_force())
	await physics_frame


func _fill() -> void:
	var guard := 0
	while is_instance_valid(_warden) and not _warden.staggered() and guard < 20:
		await _ram()
		guard += 1
	await physics_frame


func _filled() -> int:
	return _plate.pips().filter(func(pip): return pip["filled"]).size()


func _start() -> bool:
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.flow.force_warden = true
	_player = _game.player
	_player.source = _source
	_combat = _game.ctx.spawner
	_game.flow.press_start()
	_game.flow.choose_class(1)
	await _seconds(0.4)
	_game.run.set_max_hp(99999.0)
	_combat.heft_override = 1.0
	_warden = _game.flow.warden
	if not is_instance_valid(_warden):
		return false
	for enemy in get_nodes_in_group("enemy"):
		if enemy != _warden and enemy.get("kind") != "vault":
			enemy.queue_free()
	_plate = BossPlate.new()
	_plate.set_process(false)
	root.add_child(_plate)
	return true


# The text of one function, from its func line to the next top-level line.
func _body_of(source: String, name: String) -> String:
	var at := source.find("func %s(" % name)
	if at < 0:
		return ""
	var end := source.find("\nfunc ", at + 1)
	return source.substr(at, end - at if end >= 0 else -1)


# The posture arm of a function: the text before " if posture_fight() else" on a ternary
# line, and the indented block under an "if posture_fight():" line.
func _posture_arm(body: String) -> String:
	var arm := ""
	var block_indent := -1
	for line in body.split("\n"):
		var indent := line.length() - line.lstrip("\t").length()
		if block_indent >= 0:
			if line.strip_edges() == "" or indent > block_indent:
				arm += line + "\n"
				continue
			block_indent = -1
		var code := line.strip_edges()
		if code.ends_with("posture_fight():") and code.begins_with("if ") and not code.begins_with("if not "):
			block_indent = indent
		elif line.contains(" if posture_fight() else "):
			arm += line.get_slice(" if posture_fight() else ", 0) + "\n"
	return arm


func _colour_sources() -> void:
	var plate := FileAccess.get_file_as_string("res://src/ui/boss_plate.gd")
	_t.check("boss_plate.gd is readable", plate.length() > 0)
	_t.check("boss_plate.gd holds no Color( literal", not plate.contains("Color("))
	_t.check("and no amber", not plate.contains("AMBER") and not plate.contains("amber"))
	for path in ADDED_CODE:
		var source := FileAccess.get_file_as_string(path)
		for name in ADDED_CODE[path]:
			var body := _body_of(source, name)
			_t.check("%s %s is found" % [path.get_file(), name], body.length() > 0)
			_t.check("%s %s holds no Color( literal or amber" % [path.get_file(), name], not body.contains("Color(") and not body.contains("AMBER"))
	for path in BRANCHED_CODE:
		var source := FileAccess.get_file_as_string(path)
		for name in BRANCHED_CODE[path]:
			var arm := _posture_arm(_body_of(source, name))
			_t.check("%s %s has a posture arm" % [path.get_file(), name], arm.length() > 0)
			_t.check("%s %s posture arm holds no Color( literal or amber" % [path.get_file(), name], not arm.contains("Color(") and not arm.contains("AMBER"))


func _run() -> void:
	_colour_sources()
	if not await _start():
		print("boss_plate_test: FAIL (no Warden on the slice table)")
		quit(1)
		return
	_player.reset_to(_ground(58.0))
	await _seconds(0.3)
	_unbound()
	_plate.bind(_warden)
	_words_and_pips()
	await _guard_bar()
	await _glance()
	await _crack_and_shatter()
	await _stagger_bar()
	_warden._dead = true
	_t.eq("a dead, unfreed posture Warden: no words", _plate.drawn_words(), [])
	_t.check("a dead, unfreed posture Warden: not active", not _plate.active())
	_plate.unbind()
	_game.free()
	_t.verdict()
	quit(1 if _t.failures > 0 else 0)


func _unbound() -> void:
	_t.eq("unbound it reports no words", _plate.drawn_words(), [])
	_t.eq("unbound it draws no pips", _plate.pips().size(), 0)
	_t.check("unbound it is not active", not _plate.active())


func _words_and_pips() -> void:
	var name: String = Roster.warden_name(_warden.family, _warden.variant)
	_t.eq("it reports exactly the name's words", _plate.drawn_words(), Array(name.split(" ")))
	_t.check("the name is two words or fewer", _plate.drawn_words().size() <= 2)
	# PF-34: every Warden's name ends before the pips start, and a long name widens the plate, not shortens the bar.
	var widest := ""
	for family in Roster.WARDEN_NAMES:
		for variant in Roster.WARDEN_NAMES[family]:
			var each := String(Roster.WARDEN_NAMES[family][variant])
			if UiDraw.width(each, BossPlate.FONT) > UiDraw.width(widest, BossPlate.FONT):
				widest = each
	_t.check("planted: the widest Warden name (%s) is wider than the old fixed name column" % widest,
		UiDraw.width(widest, BossPlate.FONT) > BossPlate.NAME_WIDTH, "%.0f px" % UiDraw.width(widest, BossPlate.FONT))
	_t.check("this Warden's name ends a gap before its first pip", UiDraw.width(name, BossPlate.FONT) + BossPlate.GAP <= _plate.name_width(),
		"%.0f + %.0f vs %.0f" % [UiDraw.width(name, BossPlate.FONT), BossPlate.GAP, _plate.name_width()])
	_t.check("and the plate is wider by what the name needs, so the bar keeps its length",
		is_equal_approx(_plate.size.x, BossPlate.SIZE.x + _plate.name_width() - BossPlate.NAME_WIDTH), "%.0f" % _plate.size.x)
	_t.eq("four pips", _plate.pips().size(), BossPosture.CHUNKS)
	_t.eq("all four filled at the start", _filled(), 4)
	_t.check("no crack mark yet", _plate.pips().all(func(pip): return not pip["cracked"]))
	_t.eq("the glyph is the posture step", _plate.glyph_id(), "posture_step")
	_t.check("the posture step is the neutral role colour", _plate.glyph_color() == EventKinds.role_color("neutral"))
	_t.check("the bar is the neutral role colour", _plate.bar_color() == EventKinds.role_color("neutral"))


func _guard_bar() -> void:
	_t.check("the bar starts empty", absf(_plate.bar_fraction()) <= 0.02)
	await _ram()
	_t.check("the bar equals posture / 100 after a ram", absf(_plate.bar_fraction() - _warden.posture() / 100.0) <= 0.02,
		"bar %.3f, posture %.1f" % [_plate.bar_fraction(), _warden.posture()])
	await _ram()
	_t.check("the bar equals posture / 100 after two", absf(_plate.bar_fraction() - _warden.posture() / 100.0) <= 0.02,
		"bar %.3f, posture %.1f" % [_plate.bar_fraction(), _warden.posture()])


func _glance() -> void:
	_t.eq("no glance yet", _plate.glyph_id(), "posture_step")
	_combat.strike(_warden, "runner", 5.0)
	_t.eq("a glance shows the glancing glyph", _plate.glyph_id(), "glancing")
	_t.check("in the slate colour", _plate.glyph_color() == EventKinds.state_color("glancing") and _plate.glyph_color() == EventKinds.role_color("slate"))
	_plate.advance(0.5)
	_t.eq("still glancing at 0.5 s", _plate.glyph_id(), "glancing")
	_plate.advance(0.15)
	_t.eq("back to the posture step after 0.6 s", _plate.glyph_id(), "posture_step")


func _crack_and_shatter() -> void:
	await _fill()
	_t.check("it is staggered", _warden.staggered())
	_combat.strike(_warden, "stomp", _matched_force())
	await _frames(2)
	_t.check("a lesser contact cracks the chunk", _warden.chunk_cracked())
	_t.check("the current chunk shows the crack mark", _plate.pips()[3]["cracked"] and _plate.pips()[3]["filled"])
	_t.check("open, the crack mark is the live colour", _plate.crack_color() == EventKinds.state_color("chunk_shatter") and _plate.crack_color() == EventKinds.role_color("live"))
	_t.check("only the current chunk shows it", _plate.pips().filter(func(pip): return pip["cracked"]).size() == 1)
	await _seconds(BossPosture.STAGGER_SECONDS + 0.5)
	_t.check("the stagger ran out", not _warden.staggered())
	_t.check("the crack waits for the next opening", _plate.pips()[3]["cracked"])
	_t.check("closed, the crack mark is the neutral role colour", _plate.crack_color() == EventKinds.role_color("neutral") and _plate.crack_color() != EventKinds.state_color("chunk_shatter"))
	await _fill()
	await physics_frame
	_combat.strike(_warden, "ram", _fast_force())
	await _frames(2)
	_t.eq("a shattered chunk leaves three filled", _filled(), 3)
	_t.check("and one empty", _plate.pips().size() == 4 and not _plate.pips()[3]["filled"])
	_t.check("the crack is spent with the chunk", _plate.pips().all(func(pip): return not pip["cracked"]))
	await _seconds(0.5)


func _stagger_bar() -> void:
	await _fill()
	_t.check("it is staggered again", _warden.staggered())
	_t.check("staggered the bar is full", absf(_plate.bar_fraction() - 1.0) <= 0.02)
	_t.check("staggered the bar is the live colour", _plate.bar_color() == EventKinds.state_color("open") and _plate.bar_color() == EventKinds.role_color("live"))
	_t.eq("staggered the glyph is open", _plate.glyph_id(), "open")
	await _seconds(1.5)
	_t.check("the bar follows stagger_left", absf(_plate.bar_fraction() - _warden.stagger_left() / BossPosture.STAGGER_SECONDS) <= 0.02 and _plate.bar_fraction() < 0.8,
		"bar %.3f, %.2f s left" % [_plate.bar_fraction(), _warden.stagger_left()])
	_combat.strike(_warden, "runner", 5.0)
	_t.eq("open outranks a glance", _plate.glyph_id(), "open")
	await _seconds(BossPosture.STAGGER_SECONDS)
	_t.check("after the stagger the bar is the guard in the neutral colour", not _warden.staggered() and _plate.bar_color() == EventKinds.role_color("neutral"))
