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
const Rows := preload("res://src/presentation/flourish_rows.gd")

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


# Runs `pieces` as a row so several start in one frame (the rows' own times are fixed constants).
func _force_row(pieces: Array, anchors := {}) -> void:
	_fl.play("bowl_handoff", 1, {}, "short")
	_fl.stop_all()
	_fl.playing = true
	_fl.id = "bowl_handoff"
	_fl.short = true
	_fl.clock = 0.0
	_fl._pieces = pieces
	_fl._anchors = anchors
	var started: Array[bool] = []
	started.resize(pieces.size())
	started.fill(false)
	_fl._started = started


func _kind_nodes(kind: String) -> Array:
	return _fl.live_nodes().filter(func(n): return n.get_meta("flourish_kind", "") == kind)


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
	var held_before: int = _fx.spawned.get("held_keep", 0)
	var stamped: bool = _fx.word("smash", _world(Vector2(0.5, 0.5) + Vector2(10.0, 0.0) / _view))
	var rects := _player_rects()
	var held_keep: int = _fx.spawned.get("held_keep", 0) - held_before
	t.check("a: a player word at the centre is drawn clear of the reticle, or held because the keep list covers it (stamped %s, %d on screen, %d held by keep)" % [stamped, rects.size(), held_keep],
		(stamped and rects.size() == 1 and not _any_meets(rects, _reticle())) or (not stamped and rects.is_empty() and held_keep == 1))

	# b: a machine KLANG at the centre
	_reset()
	var centre_at := _world(Vector2(0.5, 0.5))
	var no_spot: bool = _mfx._free_spot(_fx, 100.0, centre_at, 1.0) == null
	var klang: bool = _mfx.word("KLANG", centre_at, Palette.BRASS)
	var machine := _machine_rects()
	t.check("b: a machine KLANG at the centre is drawn clear of the reticle, or refused because no spot is free (stamped %s, no free spot %s, %d on screen)" % [klang, no_spot, machine.size()],
		(klang and machine.size() == 1 and not _any_meets(machine, _reticle())) or (not klang and no_spot and machine.is_empty()))

	# b2: a member without keep_clear_rects() cannot break the list (a bad member, not a crash)
	_reset()
	var odd := Node.new()
	odd.add_to_group("word_keep_clear")
	root.add_child(odd)
	await _frames(1)
	t.check("b: a group member without keep_clear_rects() leaves a word on clear screen drawn", _fx.word("smash", _world(Vector2(0.2, 0.45))) and _player_rects().size() == 1)
	odd.remove_from_group("word_keep_clear")
	odd.queue_free()
	# b3: the list is read again when a member says its rects changed within the frame
	_reset()
	var late := Plate.new()
	late.add_to_group("word_keep_clear")
	root.add_child(late)
	await _frames(1)
	var probe := Rect2(_view * Vector2(0.15, 0.4), Vector2(120.0, 60.0))
	var before_free: bool = _fx.spot_free(probe)
	late.rects = [probe]
	var stale_free: bool = _fx.spot_free(probe)
	_fx.keep_clear_changed()
	var after_free: bool = _fx.spot_free(probe)
	t.check("b: a keep rect that appears mid-frame is seen once keep_clear_changed() is called (free %s, stale read %s, after %s)" % [before_free, stale_free, after_free],
		before_free and stale_free and not after_free)
	late.remove_from_group("word_keep_clear")
	late.queue_free()
	await _frames(1)

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
	var placed: bool = _fl._place_word(label, {"at_share": centre_share})
	var asked := Rect2(label.position, label.size)
	t.check("d: the victory title shows and has an area (%s)" % title, _game.screens.visible and title.has_area())
	t.check("d: a flourish word aimed over the title is not built, or drawn clear of it (placed %s at %s, title %s)" % [placed, asked, title], not (placed and asked.intersects(title)))
	label.queue_free()
	_game.screens._on_flow_changed("stage")
	await _frames(60)
	var bare := Label.new()
	bare.text = "KLANG"
	bare.add_theme_font_size_override("font_size", 72)
	_fl._overlay.add_child(bare)
	var placed_bare: bool = _fl._place_word(bare, {"at_share": centre_share})
	var landed := Rect2(bare.position, bare.size)
	t.check("d: the control word, with the screen down, is placed over the title's place (%s vs %s)" % [landed, title], placed_bare and landed.intersects(title))
	bare.queue_free()
	await _frames(3)

	# e: pause hides the words only
	_reset()
	var spot := _world(Vector2(0.2, 0.45))
	t.check("e: a word stamps before the pause", _fx.word("heft_up", spot))
	_fx._aura.visible = true
	_fx._dunk_glow.visible = true
	var live_word: Dictionary = _fx._words.filter(func(w): return w["t"] < 1.0)[0]
	var life_before: float = live_word["t"]
	paused = true
	await _frames(2)
	var shown := 0
	for w in _fx._words:
		if w["node"].is_visible_in_tree():
			shown += 1
	t.check("e: after 2 paused frames no player_fx word shows (%d showing, words node visible %s)" % [shown, _fx._word_root.visible], shown == 0 and not _fx._word_root.visible)
	t.check("e: the aura and the dunk coil stay visible while paused (aura %s, coil %s, root %s)" % [_fx._aura.is_visible_in_tree(), _fx._dunk_glow.is_visible_in_tree(), _fx.root.visible],
		_fx._aura.is_visible_in_tree() and _fx._dunk_glow.is_visible_in_tree() and _fx.root.visible)
	t.check("e: the paused word's life did not run (t %f before, %f now)" % [life_before, live_word["t"]], is_equal_approx(life_before, live_word["t"]))
	paused = false
	await _frames(1)
	t.check("e: the word shows again with its remaining life, not restarted, not gone (t %f from %f, visible %s)" % [live_word["t"], life_before, live_word["node"].is_visible_in_tree()],
		live_word["node"].is_visible_in_tree() and live_word["t"] >= life_before and live_word["t"] < 1.0)

	# f: three numbers on one point
	var layer = _game.hud.damage_numbers
	var real_off: Callable = layer.get("keep_off")
	layer.clear()
	var tag := Rect2(_view * 0.5 + Vector2(-40.0, -100.0), Vector2(80.0, 28.0))
	layer.set("keep_off", func() -> Dictionary: return {"ring": [_reticle()], "tags": [tag]})
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
	# f2: the ball beside the ring: a number pushed off the reticle does not land on the ball
	layer.clear()
	var ball := Rect2(_reticle().end + Vector2(0.0, -30.0), Vector2(120.0, 120.0))
	layer.set("keep_off", func() -> Dictionary: return {"ring": [_reticle(), ball], "tags": []})
	layer.add("b", 20.0, _view * 0.5, "kinetic", "player")
	var on_ball := _starts(layer)
	t.check("f: a number at the reticle is pushed clear of the ring and of the ball beside it (%s)" % [on_ball],
		on_ball.size() == 1 and not on_ball[0].intersects(_reticle()) and not on_ball[0].intersects(ball))
	# f3: a tag above the number is not crossed by its rise
	layer.clear()
	var high_tag := Rect2(_view * Vector2(0.3, 0.3), Vector2(100.0, 24.0))
	layer.set("keep_off", func() -> Dictionary: return {"ring": [], "tags": [high_tag]})
	layer.add("t", 20.0, Vector2(_view.x * 0.3 + 50.0, _view.y * 0.3 + 60.0), "kinetic", "player")
	var low := _starts(layer)
	var rise := Rect2(low[0].position - Vector2(0.0, DamageNumbers.RISE), low[0].size + Vector2(0.0, DamageNumbers.RISE)) if low.size() == 1 else Rect2()
	t.check("f: a number's whole rise misses the tag above it (rise %s, tag %s)" % [rise, high_tag], low.size() == 1 and not rise.intersects(high_tag))
	# f4: the push is bounded: a wall of rects cannot move a number past MAX_PUSHES widths
	layer.clear()
	var wall: Array = []
	for i in 8:
		wall.append(Rect2(_view * 0.5 + Vector2(-30.0 + 80.0 * i, -200.0), Vector2(80.0, 400.0)))
	layer.set("keep_off", func() -> Dictionary: return {"ring": wall, "tags": []})
	layer.add("w", 20.0, _view * 0.5, "kinetic", "player")
	var walled := _starts(layer)
	var moved_x: float = absf(walled[0].get_center().x - _view.x * 0.5) if walled.size() == 1 else INF
	t.check("f: a number's sideways push is bounded by MAX_PUSHES (moved %f px, 3 rects wide at most %f)" % [moved_x, 3.0 * 80.0 + 40.0], moved_x <= 3.0 * 80.0 + 40.0)
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
	layer.add("big", 90.0, Vector2(100.0, 300.0), "kinetic", "player")
	for i in 4:
		layer.add("small%d" % i, 2.0, Vector2(300.0 + 200.0 * i, 300.0), "kinetic", "player")
	var kept: Array = layer.shown().map(func(n): return n["key"])
	t.check("f: one big number and four small ones, the big one survives (%s)" % [kept], layer.visible_count() == 4 and "big" in kept)
	layer.clear()
	# f6: the cap, a new number always shows; damage dealt and taken count apart
	layer.set("keep_off", Callable())
	layer.clear()
	for i in 4:
		layer.add("L%d" % i, 50.0 + 10.0 * i, Vector2(100.0 + 300.0 * i, 300.0), "kinetic", "player")
	layer.add("tick", 1.0, Vector2(1200.0, 500.0), "kinetic", "player")
	var keys: Array = layer.shown().map(func(n): return n["key"])
	t.check("f: a small new dealt number shows over four large ones and the smallest old one goes (%s)" % [keys],
		layer.visible_count() == 4 and "tick" in keys and not ("L0" in keys) and "L3" in keys)
	layer.clear()
	for i in 4:
		layer.add("D%d" % i, 50.0 + 10.0 * i, Vector2(100.0 + 300.0 * i, 300.0), "kinetic", "player")
	layer.add("hurt", 1.0, Vector2(1200.0, 500.0), "kinetic", "monster")
	t.check("f: four dealt numbers and a taken one all show (%d)" % layer.visible_count(), layer.visible_count() == 5)
	layer.clear()
	# f7: a tag close on the reticle's right: three numbers on the centre, none ends inside the ring
	var side_ball := Rect2(_reticle().end - Vector2(0.0, 40.0), Vector2(60.0, 120.0))
	var near_tag := Rect2(side_ball.end.x, side_ball.position.y - 30.0, 50.0, 180.0)
	layer.set("keep_off", func() -> Dictionary: return {"ring": [_reticle(), side_ball], "tags": [near_tag]})
	layer.add("r1", 20.0, _view * 0.5, "kinetic", "player")
	layer.add("r2", 20.0, _view * 0.5, "frost", "player")
	layer.add("r3", 20.0, _view * 0.5, "arc", "player")
	var inside := 0
	for r in _starts(layer):
		if r.intersects(_reticle()) or r.intersects(side_ball):
			inside += 1
	t.check("f: with a tag close on the reticle's right no number of three ends inside the ring or the ball (%d inside of %d)" % [inside, layer.visible_count()], layer.visible_count() == 3 and inside == 0)
	layer.clear()
	# f8: through the HUD's own keep-off hook, a real reticle and a real ball
	layer.set("keep_off", real_off)
	var real_ring: Rect2 = _game.hud.reticle.rect()
	var real_ball: Rect2 = _game.hud._ball_rect()
	layer.add("real", 20.0, _view * 0.5, "kinetic", "player")
	var real_start := _starts(layer)
	t.check("f: the HUD's real hook has a reticle and a ball rect (%s, %s)" % [real_ring, real_ball], real_off.is_valid() and real_ring.has_area() and real_ball.has_area())
	t.check("f: through the HUD's real hook a number at the centre misses the real reticle and ball (%s)" % [real_start],
		real_start.size() == 1 and not real_start[0].intersects(real_ring) and not real_start[0].intersects(real_ball))
	layer.clear()
	# f5: a hidden reticle has no rect
	var ret = _game.hud.reticle
	var was_visible: bool = ret.visible
	ret.visible = false
	var hidden_rect: Rect2 = ret.rect() if ret.has_method("rect") else Rect2(Vector2.ZERO, Vector2.ONE)
	ret.visible = was_visible
	t.check("f: a hidden reticle reports an empty rect (%s)" % hidden_rect, not hidden_rect.has_area())

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

	await _frames(1)
	# i: a word that starts with a stamp of its own row, in the same frame or after it
	_reset()
	var word_piece := {"kind": "sfx_word", "at": 0.0, "for": 0.8, "text": "FWOOMP", "at_share": Vector2(0.5, 0.40)}
	var stamp_piece := {"kind": "stamp", "at": 0.0, "for": 0.9, "text": "ROUTED", "colour": "AMBER", "slot": "centre"}
	_force_row([word_piece.duplicate(), stamp_piece.duplicate()])
	_fl.advance(0.0)
	var sw := _kind_nodes("sfx_word")
	var ss := _kind_nodes("stamp")
	var meets := 0
	for w in sw:
		if w.is_visible_in_tree() and w.get_global_rect().intersects(ss[0].get_global_rect()):
			meets += 1
	t.check("i: the row's stamp is live (%d)" % ss.size(), ss.size() == 1)
	t.check("i: a word starting in the same frame as its stamp is clear of it or was refused for it (%d words, %d over)" % [sw.size(), meets], meets == 0)
	# Control: the same word with no stamp is placed, so the check above did not pass on an empty list.
	_fl.stop_all()
	_force_row([word_piece.duplicate()])
	_fl.advance(0.0)
	var lone_word := _kind_nodes("sfx_word")
	t.check("i: control, the same word with no stamp is placed (%d)" % lone_word.size(), lone_word.size() == 1)
	_fl.stop_all()
	# The real brindle_rout row: FWOOMP at 0.0, ROUTED later; the stamp carries the fact, so the word yields.
	var real: Array = Rows.resolve("brindle_rout", true, 1)
	var stamp_at: float = real.filter(func(pc): return pc["kind"] == "stamp")[0]["at"]
	var scooter := Node3D.new()
	root.add_child(scooter)
	scooter.global_position = _world(Vector2(0.62, 0.45))
	_force_row(real.duplicate(true), {"scooter": scooter})
	_fl.advance(0.0)
	var up_first := _kind_nodes("sfx_word")
	t.check("i: on the real brindle_rout row the word is up before the stamp (%d words, stamp at %.1f s)" % [up_first.size(), stamp_at], up_first.size() == 1 and up_first[0].is_visible_in_tree() and _kind_nodes("stamp").is_empty())
	var word_rect: Rect2 = up_first[0].get_global_rect() if up_first.size() == 1 else Rect2()
	_fl.advance(stamp_at + 0.05)
	var stamp_now := _kind_nodes("stamp")
	var word_now := _kind_nodes("sfx_word")
	var yielded := true
	for w in word_now:
		if w.is_visible_in_tree() and stamp_now.size() == 1 and w.get_global_rect().intersects(stamp_now[0].get_global_rect()):
			yielded = false
	t.check("i: the real row's stamp starts and no visible word meets it (%d stamps, %d words)" % [stamp_now.size(), word_now.size()], stamp_now.size() == 1 and yielded)
	_fl.stop_all()
	# The real row with both at 0.0.
	var both: Array = real.duplicate(true)
	for pc in both:
		pc["at"] = 0.0
	_force_row(both, {"scooter": scooter})
	_fl.advance(0.0)
	var b_stamp := _kind_nodes("stamp")
	var b_word := _kind_nodes("sfx_word")
	var b_meets := 0
	for w in b_word:
		if w.is_visible_in_tree() and b_stamp.size() == 1 and w.get_global_rect().intersects(b_stamp[0].get_global_rect()):
			b_meets += 1
	t.check("i: the real row with both at 0.0 puts the stamp up and no word over it (%d stamps, %d words, %d over)" % [b_stamp.size(), b_word.size(), b_meets], b_stamp.size() == 1 and b_meets == 0)
	_fl.stop_all()
	scooter.queue_free()
	# A word forced to meet a later stamp is hidden at once, whatever the real row's spots allow.
	_force_row([{"kind": "sfx_word", "at": 0.0, "for": 2.0, "text": "FWOOMP", "at_share": Vector2(0.5, 0.40)},
		{"kind": "stamp", "at": 0.5, "for": 1.0, "text": "ROUTED", "colour": "AMBER", "slot": "centre"}])
	_fl.advance(0.0)
	var pre := _kind_nodes("sfx_word")
	_fl.advance(0.6)
	var post_stamp := _kind_nodes("stamp")
	var post_word := _kind_nodes("sfx_word")
	var overlapped: bool = pre.size() == 1 and post_stamp.size() == 1 and pre[0].get_global_rect().intersects(post_stamp[0].get_global_rect())
	t.check("i: a live word that a later stamp would cover is hidden at once (word up %d, overlap %s, visible after %s)" % [pre.size(), overlapped, post_word[0].visible if post_word.size() == 1 else "gone"],
		pre.size() == 1 and overlapped and (post_word.is_empty() or not post_word[0].visible))
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
