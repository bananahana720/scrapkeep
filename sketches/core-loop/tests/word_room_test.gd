extends SceneTree

# Sound words and damage numbers keep off what the player must read (PF-26). One module owns the
# list, player_fx; the HUD, the flourish player and the screens join the group word_keep_clear and
# answer keep_clear_rects(). Checks:
#   a  a player word aimed at the screen centre, ball still, is held or clear of the reticle
#   b  a machine KLANG over the centre is refused or drawn clear of the reticle
#   c  a node in the group around (0.70, 0.32): bowl_handoff's HONK is not visible over it
#   d  a flourish word aimed at the victory title is not drawn over it
#   e  a stamped word then a paused tree: after 2 frames no player_fx word shows
#   f  three damage numbers on one point: their start rects meet neither each other, nor the
#      reticle, nor a planted tag rect
#   g  two player words alive, 0.35 s apart: a machine candy word is refused (budget 2)
#   h  positive control: the same calls aimed at clear screen all draw
# Evidence limit: headless rules and rectangles, not how a fight reads.
const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const PlayerFx := preload("res://src/presentation/player_fx.gd")
const DamageNumbers := preload("res://src/presentation/damage_numbers.gd")
const Palette := preload("res://src/core/palette.gd")

var t := T.new("word_room_test")
var _game
var _fx
var _mfx
var _fl
var _cam: Camera3D
var _view := Vector2.ZERO


# A stand-in for a gate sign, a tag or any other member of the group.
class Plate extends Node:
	var rects: Array[Rect2] = []

	func keep_clear_rects() -> Array[Rect2]:
		return rects


func _initialize() -> void:
	root.size = Vector2i(1600, 900)
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


# Every word pool empty and the gaps open, so a check starts from nothing.
func _reset() -> void:
	_fx._last_word = -1.0e9
	_fx._word_seen.clear()
	for w in _fx._words:
		w["t"] = 1.0
		w["node"].visible = false
	_mfx._last_word = -INF
	for w in _mfx._words:
		w["t"] = INF
		w["node"].visible = false
	_fl.stop_all()


func _tests() -> int:
	var v = _fx.get("rect_tests")
	return int(v) if v != null else -1


func _world(frac: Vector2) -> Vector3:
	return _cam.project_position(_view * frac, 12.0)


func _reticle() -> Rect2:
	var r := 24.0 + 8.0 + 4.0
	var c := _view * 0.5
	return Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0)


# The screen rects of the player_fx words showing now (the layout _word_rect gives the placement rule).
func _player_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for w in _fx._words:
		if w["t"] < 1.0 and w["node"].visible:
			out.append(PlayerFx._word_rect(_cam, w["at"], w["away"] > 0.0, w["width_px"], w["size"], w["node"].pixel_size))
	return out


# The screen rect a machine word's label covers.
func _machine_rect(slot: Dictionary) -> Rect2:
	var label: Label3D = slot["node"]
	var at := label.global_position
	var px := _cam.unproject_position(at + _cam.global_basis.y).distance_to(_cam.unproject_position(at))
	var half := Vector2(float(slot["width_px"]) * label.pixel_size * label.scale.x, label.font_size * label.pixel_size * label.scale.y) * px * 0.5
	var c := _cam.unproject_position(at)
	return Rect2(c - half, half * 2.0)


func _machine_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for slot in _mfx._words:
		if slot["t"] < slot["life"] and slot["node"].visible:
			out.append(_machine_rect(slot))
	return out


func _any_meets(rects: Array[Rect2], r: Rect2) -> bool:
	for x in rects:
		if x.intersects(r):
			return true
	return false


# The rect each live damage number starts from, read off path_rects (the bottom line of each).
func _starts(layer) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var shown: Array = layer.shown()
	var paths: Array[Rect2] = layer.path_rects()
	for i in paths.size():
		var size := DamageNumbers.font_size(shown[i]["value"], shown[i]["crit"])
		var line := float(size + 2 * DamageNumbers.outline_px(size))
		out.append(Rect2(paths[i].position.x, paths[i].end.y - line, paths[i].size.x, line))
	return out


func _run() -> void:
	await _frames(2)
	_game.ctx.calm = true
	_game.flow.press_start()
	_game.flow.choose_class(0)
	await _frames(5)
	_game.player.set_frozen(true)
	_game.player.state.velocity = Vector3.ZERO
	_fx = _game.presentation.player_fx
	_mfx = _game.presentation.machine_fx
	_fl = _game.presentation.flourish
	_cam = _game.camera.cam
	_view = _cam.get_viewport().get_visible_rect().size
	await _frames(3)
	t.check("setup: a camera, a viewport and three stampers", _cam != null and _view.x > 0.0 and _fx != null and _mfx != null and _fl != null)

	# a: a player word at the centre, ball still
	_reset()
	var stamped: bool = _fx.word("smash", _world(Vector2(0.5, 0.5) + Vector2(10.0, 0.0) / _view))
	var rects := _player_rects()
	t.check("a: a player word at the centre is held or drawn clear of the reticle (stamped %s, %d on screen)" % [stamped, rects.size()],
		(not stamped and rects.is_empty()) or (stamped and rects.size() == 1 and not _any_meets(rects, _reticle())))

	# b: a machine KLANG at the centre
	_reset()
	var klang: bool = _mfx.word("KLANG", _world(Vector2(0.5, 0.5)), Palette.BRASS)
	var machine := _machine_rects()
	t.check("b: a machine KLANG at the centre is refused or drawn clear of the reticle (stamped %s, %d on screen)" % [klang, machine.size()],
		(not klang and machine.is_empty()) or (klang and machine.size() == 1 and not _any_meets(machine, _reticle())))

	# c: a member of the group around (0.70, 0.32)
	_reset()
	var plate := Plate.new()
	plate.rects = [Rect2(_view * Vector2(0.58, 0.26), _view * Vector2(0.24, 0.12))]
	plate.add_to_group("word_keep_clear")
	root.add_child(plate)
	await _frames(2)
	var played: bool = _fl.play("bowl_handoff", 1, {}, "short")
	_fl.advance(0.7)
	var words: Array = _fl.live_nodes().filter(func(n): return n.name == "FlourishWord")
	var over := 0
	for w in words:
		if w.is_visible_in_tree() and Rect2(w.position, w.size).intersects(plate.rects[0]):
			over += 1
	t.check("c: bowl_handoff played and its stamp shows (played %s, kinds %s)" % [played, _fl.live_kinds()], played and "stamp" in _fl.live_kinds())
	t.check("c: the HONK is not visible over a member's rect (%d over it)" % over, over == 0)
	print("c: HONK ", "dropped" if words.is_empty() else "drawn at %s" % [words[0].position])
	plate.remove_from_group("word_keep_clear")
	plate.queue_free()
	_reset()

	# d: a flourish word aimed over the victory title
	_game.flow.victory_veil = 0.0
	_game.screens._on_flow_changed("victory")
	await _frames(40)
	var title: Rect2 = _game.screens._title.get_global_rect()
	var centre_share := Vector2(0.8, title.get_center().y / _view.y)
	var label := Label.new()
	label.text = "KLANG"
	label.add_theme_font_size_override("font_size", 72)
	_fl._overlay.add_child(label)
	_fl._place_word(label, {"at_share": centre_share})
	var asked := Rect2(label.position, label.size)
	var drawn: bool = label.visible
	t.check("d: the victory title shows and has an area (%s)" % title, _game.screens.visible and title.has_area())
	t.check("d: a flourish word played over the title is not drawn over it (drawn %s at %s, title %s)" % [drawn, asked, title],
		not drawn or not asked.intersects(title))
	# Precondition: with no member in the group, the same word does land on the title.
	label.queue_free()
	_game.screens._on_flow_changed("stage")
	await _frames(60)
	var bare := Label.new()
	bare.text = "KLANG"
	bare.add_theme_font_size_override("font_size", 72)
	_fl._overlay.add_child(bare)
	_fl._place_word(bare, {"at_share": centre_share})
	var landed := Rect2(bare.position, bare.size)
	t.check("d: the control word, with the screen down, lands on the title's place (%s vs %s)" % [landed, title], bare.visible and landed.intersects(title))
	bare.queue_free()
	await _frames(3)

	# e: pause
	_reset()
	var spot := _world(Vector2(0.2, 0.45))
	t.check("e: a word stamps before the pause", _fx.word("heft_up", spot))
	paused = true
	await _frames(2)
	var shown := 0
	for w in _fx._words:
		if w["node"].is_visible_in_tree():
			shown += 1
	t.check("e: after 2 paused frames no player_fx word shows (%d showing, root visible %s)" % [shown, _fx.root.visible], shown == 0 and not _fx.root.visible)
	paused = false
	await _frames(2)
	t.check("e: the word shows again after the pause", _fx.root.visible)

	# f: three numbers on one point
	var layer = _game.hud.damage_numbers
	layer.clear()
	var tag := Rect2(_view * 0.5 + Vector2(-40.0, -100.0), Vector2(80.0, 28.0))
	layer.set("keep_off", func() -> Array[Rect2]: return [_reticle(), tag])
	var at := _view * 0.5 + Vector2(0.0, -40.0)
	layer.add("k", 20.0, at, "kinetic", "player")
	layer.add("k", 20.0, at, "frost", "player")
	layer.add("k", 20.0, at, "arc", "player")
	var starts := _starts(layer)
	var clash := 0
	for i in starts.size():
		if starts[i].intersects(_reticle()) or starts[i].intersects(tag):
			clash += 1
		for j in range(i + 1, starts.size()):
			if starts[i].intersects(starts[j]):
				clash += 1
	t.check("f: three numbers on one point show three start rects (%d)" % starts.size(), starts.size() == 3)
	t.check("f: their start rects meet no other number, the reticle or the planted tag (%d meetings: %s)" % [clash, starts], clash == 0)
	layer.set("keep_off", Callable())
	layer.clear()
	layer.add("a", 5.0, at, "kinetic", "player")
	layer.add("a", 6.0, at, "kinetic", "player")
	t.check("f: the same key, type and team still merges into one number", layer.visible_count() == 1)
	layer.clear()
	for i in 6:
		layer.add("n%d" % i, 5.0, Vector2(100.0 + 300.0 * i, 200.0), "kinetic", "player")
	t.check("f: at most 4 numbers show at once (%d)" % layer.visible_count(), layer.visible_count() == 4)
	layer.clear()

	# g: the budget
	_reset()
	var one: bool = _fx.word("smash", _world(Vector2(0.2, 0.45)))
	_fx._last_word -= 0.5
	var two: bool = _fx.word("heft_up", _world(Vector2(0.2, 0.62)))
	var alive: int = _fx.words_alive()
	var third: bool = _mfx.word("KLANG", _world(Vector2(0.8, 0.45)), Palette.BRASS)
	t.check("g: two player words are alive (%s, %s, %d alive)" % [one, two, alive], one and two and alive == 2)
	t.check("g: a machine candy word is refused with the budget spent (stamped %s)" % third, not third)
	var read: bool = _mfx.word("KRNK", _world(Vector2(0.8, 0.45)), Palette.BRASS, true)
	t.check("g: a forced read stands outside the count (stamped %s)" % read, read)

	# h: positive control
	_reset()
	var pa: bool = _fx.word("smash", _world(Vector2(0.2, 0.45)))
	var ma: bool = _mfx.word("KLANG", _world(Vector2(0.8, 0.45)), Palette.BRASS)
	var fa: bool = _fl.play("bowl_handoff", 1, {}, "short")
	_fl.advance(0.7)
	var fw: Array = _fl.live_nodes().filter(func(n): return n.name == "FlourishWord")
	t.check("h: a player word on clear screen is drawn (%s)" % pa, pa and _player_rects().size() == 1)
	t.check("h: a machine word on clear screen is drawn (%s)" % ma, ma and _machine_rects().size() == 1)
	t.check("h: a flourish word with nothing in the way is drawn (%s, %d)" % [fa, fw.size()], fa and fw.size() == 1 and fw[0].is_visible_in_tree())
	layer.clear()
	layer.add("z", 7.0, Vector2(_view.x * 0.8, _view.y * 0.7), "kinetic", "player")
	var lone := _starts(layer)
	t.check("h: a lone number is not moved (start rect centred on its point)", lone.size() == 1 and absf(lone[0].get_center().x - _view.x * 0.8) < 1.0)

	# i: a word that starts in the same frame as its own row's stamp
	_reset()
	_fl.play("bowl_handoff", 1, {}, "short")
	_fl.stop_all()
	_fl.playing = true
	_fl.id = "bowl_handoff"
	_fl.short = true
	_fl.clock = 0.0
	_fl._pieces = [{"kind": "sfx_word", "at": 0.0, "for": 0.8, "text": "FWOOMP", "at_share": Vector2(0.5, 0.40)},
		{"kind": "stamp", "at": 0.0, "for": 0.9, "text": "ROUTED", "colour": "AMBER", "slot": "centre"}]
	_fl._started.assign([false, false])
	_fl.advance(0.0)
	var sw: Array = _fl.live_nodes().filter(func(n): return n.get_meta("flourish_kind", "") == "sfx_word")
	var ss: Array = _fl.live_nodes().filter(func(n): return n.get_meta("flourish_kind", "") == "stamp")
	var meets := 0
	for w in sw:
		if w.is_visible_in_tree() and Rect2(w.position, w.size).intersects(Rect2(ss[0].position, ss[0].size)):
			meets += 1
	t.check("i: the row's stamp is live (%d)" % ss.size(), ss.size() == 1)
	t.check("i: a word starting with its own row's stamp is held or clear of it (%d words, %d over)" % [sw.size(), meets], meets == 0)
	_fl.stop_all()

	# Cost: rect tests per placement
	_reset()
	var before: int = _tests()
	_fx.word("smash", _world(Vector2(0.2, 0.45)))
	print("cost: one player word on clear screen made %d rect tests" % (_tests() - before))
	_reset()
	var crowd := Plate.new()
	for i in 14:
		crowd.rects.append(Rect2(_view * Vector2(0.05 + 0.06 * i, 0.15 + 0.04 * (i % 5)), _view * Vector2(0.04, 0.06)))
	crowd.add_to_group("word_keep_clear")
	root.add_child(crowd)
	for i in 4:
		layer.add("c%d" % i, 9.0, _view * Vector2(0.3 + 0.1 * i, 0.5), "kinetic", "player")
	await _frames(2)
	before = _tests()
	var dense: bool = _fx.word("smash", _world(Vector2(0.45, 0.45)))
	print("cost: one player word in a crowd of %d group rects and 4 numbers made %d rect tests (stamped %s)" % [crowd.rects.size(), _tests() - before, dense])
	crowd.remove_from_group("word_keep_clear")
	crowd.queue_free()
	quit(t.verdict())
