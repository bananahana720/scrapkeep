extends SceneTree

# Player effects (PLAYER-FX.md) through the real game: might grows with the build, sound
# words keep their caps and stay out of the lane ahead, overdrive switches at the soft cap
# with hysteresis, carve sparks need banked ground at speed, and the layer's per-frame
# script cost stays small. Headless runs simulate no particles (fx_library_test), so this
# pins configuration and switches, not pixels.
const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const PlayerFx := preload("res://src/presentation/player_fx.gd")
const Density := preload("res://src/presentation/density.gd")
const Telegraph := preload("res://src/combat/telegraph.gd")
const Hazard := preload("res://src/boss/hazard.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const Palette := preload("res://src/core/palette.gd")

var t := T.new("player_fx_test")
var _game


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	await _frames(2)
	_game.ctx.calm = true
	_game.flow.press_start()
	_game.flow.choose_class(0)
	await _frames(5)
	var fx = _game.presentation.player_fx
	t.check("player fx is built by presentation", fx != null and fx.root != null and fx.root.is_inside_tree())
	Density.live().reset()

	# Might: a fresh pilot is small; the inputs each move it; it saturates at 1.
	t.near("might 0 for a fresh pilot", PlayerFx.might_from(1, 0, 0, 0, 0), 0.0)
	t.near("might 1 for a full build", PlayerFx.might_from(5, 12, 4, 3, 4), 1.0)
	t.check("every input grows might", PlayerFx.might_from(2, 0, 0, 0) > 0.0 and PlayerFx.might_from(1, 1, 0, 0) > 0.0
		and PlayerFx.might_from(1, 0, 1, 0) > 0.0 and PlayerFx.might_from(1, 0, 0, 1) > 0.0 and PlayerFx.might_from(1, 0, 0, 0, 1) > 0.0)
	t.check("the power read's depth-4 build (heft IV, 4 parts, 4 picks) reads grown", PlayerFx.might_tier(PlayerFx.might_from(4, 4, 0, 0, 4)) >= 2,
		str(PlayerFx.might_from(4, 4, 0, 0, 4)))
	t.eq("tiers small to mighty", [PlayerFx.might_tier(0.0), PlayerFx.might_tier(0.3), PlayerFx.might_tier(0.6), PlayerFx.might_tier(1.0)], [0, 1, 2, 3])
	var parts: Array = ["frost_vane", "arc_coil", "frost_vane"]
	for id in parts:
		_game.run.parts.append(id)
		_game.events.part_gained.emit(id, "test")
	await _frames(2)
	t.eq("one mote per part", fx.motes_shown(), _game.run.parts.size())
	t.check("might rose with parts", fx.might > 0.0, str(fx.might))
	var before: float = fx.might
	_game.events.evolution_fired.emit("frost_vane")
	t.check("a fusion grows might and raises the column", fx.might > before and fx.spawned.get("column", 0) == 1)
	t.check("a fusion stamps FUSED", fx.spawned.get("word_fused", 0) == 1)

	# Words: gap, alive cap, per-word repeat, pilot voice, the lane ahead stays clear.
	await _frames(int(PlayerFx.WORD_GAP_S * 60) + 30)
	var ball: Vector3 = _game.player.shown_position()
	fx._last_word = -1.0e9
	fx._word_seen.clear()
	for w in fx._words:
		w["t"] = 1.0
	t.check("first word stamps", fx.word("slam", ball + Vector3(3, 2, 0)))
	t.check("a second inside the gap is refused", not fx.word("vault", ball + Vector3(3, 2, 0)))
	fx._last_word = -1.0e9
	t.check("the same word inside its repeat window is refused", not fx.word("slam", ball + Vector3(3, 2, 0)))
	t.check("a different word after the gap stamps", fx.word("vault", ball + Vector3(-3, 2, 0)))
	fx._last_word = -1.0e9
	t.check("never more than two alive", not fx.word("launch", ball) and fx.words_alive() == PlayerFx.WORDS_ALIVE)
	t.eq("Sable launches with her own word", fx.word_text("launch"), "ZWOOSH")
	t.eq("unvoiced moments keep the house word", fx.word_text("slam"), "WHUMP")
	_game.player.state.velocity = Vector3(0, 0, -30)
	var ahead: Vector3 = ball + Vector3(0.5, 2.0, -10.0)
	var moved: Vector3 = fx.clear_of_lane(ahead)
	var lateral := Vector2(moved.x - ball.x, 0.0).length()
	t.check("a word ahead of the ball is pushed out of the lane", lateral >= PlayerFx.LANE_M, "lateral %.2f m" % lateral)
	t.check("a word behind the ball stays put", fx.clear_of_lane(ball + Vector3(0, 2, 5)).is_equal_approx(ball + Vector3(0, 2, 5)))
	Density.live().force(1.0)
	fx._last_word = -1.0e9
	fx._word_seen.clear()
	for w in fx._words:
		w["t"] = 1.0
	t.check("the densest band refuses words", not fx.word("rocket", ball))
	Density.live().reset()

	# Knockback moments: a blazing ram says WHAM, a bump says nothing; three pins inside
	# the window stamp STRIKE.
	var dummy := Node3D.new()
	_game.add_child(dummy)
	dummy.global_position = ball + Vector3(4, 0, 0)
	for w in fx._words:
		w["t"] = 1.0
	fx._last_word = -1.0e9
	fx._word_seen.clear()
	fx.pose = {"velocity": Vector3(0, 0, -10)}
	_game.events.enemy_struck.emit(dummy, "ram", 20.0)
	t.check("a ram at cruise is a bump: no word", fx.spawned.get("word_wham", 0) == 0)
	fx.pose = {"velocity": Vector3(0, 0, -32)}
	_game.events.enemy_struck.emit(dummy, "ram", 20.0)
	t.check("a blazing ram says WHAM", fx.spawned.get("word_wham", 0) == 1)
	fx.pose = {}
	for w in fx._words:
		w["t"] = 1.0
	fx._last_word = -1.0e9
	for i in 3:
		_game.events.enemy_pinned.emit(dummy, 10.0)
	t.check("a rack of three pins stamps STRIKE", fx.spawned.get("word_strike", 0) == 1)
	dummy.free()

	# Overdrive: on at the cap, held over the hysteresis band, off below it.
	fx.overdrive = false
	fx.heat = 0.0
	t.check("below the cap stays cold", not fx.overdrive_step(59.0, 0.016) and not fx.overdrive)
	t.check("the cap ignites once", fx.overdrive_step(60.5, 0.016) and fx.overdrive)
	t.check("no second ignite while burning", not fx.overdrive_step(61.0, 0.016))
	fx.overdrive_step(56.0, 0.016)
	t.check("holds between 54 and 60", fx.overdrive)
	for i in 10:
		fx.overdrive_step(62.0, 0.016)
	t.check("heat reaches full within its rise", fx.heat >= 0.99, str(fx.heat))
	fx.overdrive_step(50.0, 0.016)
	t.check("cools below 54", not fx.overdrive)

	# Carve: banked ground at speed only.
	var s = _game.player.state
	s.grounded = true
	s.contact_normal = Vector3(0.7, 0.71, 0).normalized()
	s.velocity = Vector3(0, 0, -40)
	t.check("bank at speed carves", fx.carving() == (_game.player.speed_tier() >= 2), "tier %d" % _game.player.speed_tier())
	s.contact_normal = Vector3.UP
	t.check("flat ground never carves", not fx.carving())

	# A grown slam throws the build's colour up and earns the impact frame; vfx's hit glyphs
	# read the same might.
	fx.pose = {}
	s.contact_normal = Vector3.UP
	fx.might = 0.8
	fx._might_wait = 10.0
	var columns: int = fx.spawned.get("column", 0)
	fx._last_frame = -1.0e9
	_game.events.slammed.emit(ball, 1.0, 1.0)
	t.check("a grown slam keeps the centre clear: no column", fx.spawned.get("column", 0) == columns)
	t.check("a grown slam earns the impact frame", fx.spawned.get("impact_frame", 0) >= 1 and fx._frame.active())
	t.check("a grown build's edge ink burns hot", fx._frame._heat > 0.9, str(fx._frame._heat))
	# Colour heat, not size: the depth-4 build already runs mostly hot; a fresh pilot is cold.
	t.check("heat is cold for a fresh pilot and mostly hot at depth 4", PlayerFx.heat_k(0.0) == 0.0
		and PlayerFx.heat_k(PlayerFx.might_from(4, 4, 0, 0, 4)) >= 0.75, str(PlayerFx.heat_k(PlayerFx.might_from(4, 4, 0, 0, 4))))
	var hot: Color = fx.heat_tint(Color(0.2, 0.6, 1.0))
	t.check("a grown build's colours run toward heat orange", hot.r > 0.8 and hot.b < 0.4, str(hot))
	fx.refresh_might()
	t.near("vfx glyphs read the same might", _game.presentation.vfx.might, fx.might)
	t.near("vfx glyphs read the same heat", _game.presentation.vfx.heat, PlayerFx.HEAT_SHARE * PlayerFx.heat_k(fx.might))
	t.check("hit glyphs grow by a quarter at most", 1.0 + _game.presentation.vfx.MIGHT_GLYPH <= 1.25)
	t.check("particle ceiling pinned at 440", PlayerFx.ceiling() == 440, str(PlayerFx.ceiling()))
	t.check("no boon burst for a small pilot; a mighty one throws the full burst", PlayerFx.boon_count(0.0) == 0 and PlayerFx.boon_count(1.0) == PlayerFx.BOON)
	# Enemy warnings draw on top: every player-effect material sorts under the threat marks.
	var Threat := load("res://src/combat/threat_grammar.gd")
	var under := true
	for node in fx.root.find_children("*", "", true, false):
		if node is Label3D:
			under = under and node.render_priority < Threat.LINE_UNDER_PRIORITY and node.alpha_cut == Label3D.ALPHA_CUT_DISABLED
		elif node is GeometryInstance3D:
			var mat: Material = node.material_override
			if node is GPUParticles3D:
				mat = node.draw_pass_1.surface_get_material(0) if node.draw_pass_1.surface_get_material(0) != null else node.draw_pass_1.material
			if mat != null:
				under = under and mat.render_priority < Threat.LINE_UNDER_PRIORITY
	t.check("every player effect sorts under the threat marks", under)

	# The impact frame yields to warnings at the screen edge (Andrew, 17 Oct 16:36Z: warnings
	# always draw on top). With nothing to yield to it is the old frame, polygon for polygon.
	var frame = fx._frame
	var screen := Vector2(1920.0, 1080.0)
	for case in [[1.0, 0.0, 11], [0.5, 0.9, 99], [1.0, 0.9, 5]]:
		frame._strength = case[0]
		frame._heat = case[1]
		frame._seed = case[2]
		frame._focus = Vector2(900.0, 500.0)
		var now: Array = frame._shapes(screen, [])
		var old := _old_shapes(screen, frame._focus, case[0], case[1], case[2])
		var same := now.size() == old.size()
		var skipped := 0
		for k in mini(now.size(), old.size()):
			skipped += 1 if now[k]["skipped"] else 0
			same = same and now[k]["poly"] == old[k]["poly"] and now[k].get("color") == old[k].get("color") and now[k].get("colors") == old[k].get("colors")
		t.check("no warning: the frame is the old frame (strength %.1f heat %.1f)" % [case[0], case[1]], same and skipped == 0 and old.size() > 0,
			"%d now, %d old" % [now.size(), old.size()])
		t.eq("no warning: same piece count (strength %.1f heat %.1f)" % [case[0], case[1]], now.size(), old.size())
	frame._strength = 1.0
	frame._heat = 0.9
	frame._seed = 5
	var open_shapes: Array = frame._shapes(screen, [])
	var open_wedges := open_shapes.filter(func(sh): return sh.has("color"))
	t.eq("a hot full-strength frame is 8 wash trapezoids and its wedges", open_shapes.size() - open_wedges.size(), 8)
	var left_edge := Rect2(0.0, 380.0, 150.0, 320.0)
	var yielded_shapes: Array = frame._shapes(screen, [left_edge])
	var overlap := 0
	var absent := true
	for sh in yielded_shapes:
		if not sh["skipped"]:
			overlap += 0 if Geometry2D.intersect_polygons(sh["poly"], PackedVector2Array([left_edge.position, Vector2(left_edge.end.x, left_edge.position.y), left_edge.end, Vector2(left_edge.position.x, left_edge.end.y)])).is_empty() else 1
	var cut := yielded_shapes.filter(func(sh): return sh["skipped"]).size()
	for sh in yielded_shapes.filter(func(sh): return sh.has("color")):
		if not sh["skipped"]:
			absent = absent and open_wedges.any(func(w): return w["poly"] == sh["poly"] and w["color"] == sh["color"])
	t.check("a rect on the edge skips wedges and wash", cut > 0, str(cut))
	t.eq("no drawn piece crosses the rect", overlap, 0)
	t.check("a drawn wedge is one the open frame draws: the random stream is unmoved", absent)
	t.eq("every wedge is still computed", yielded_shapes.filter(func(sh): return sh.has("color")).size(), open_wedges.size())
	# The wash pieces tile the side they cut: same area, same four colours.
	var wash_area := 0.0
	var open_area := 0.0
	for sh in yielded_shapes:
		if sh.has("colors"):
			wash_area += _area(sh["poly"])
	for sh in open_shapes:
		if sh.has("colors"):
			open_area += _area(sh["poly"])
	var skipped_area := 0.0
	for sh in yielded_shapes:
		if sh.has("colors") and sh["skipped"]:
			skipped_area += _area(sh["poly"])
	# Vertices are float32, so the sums agree to a part in 1e6, not exactly.
	t.check("wash drawn plus wash left out is the whole wash", absf(wash_area / open_area - 1.0) < 1.0e-6, str(wash_area / open_area - 1.0))
	t.check("the wash yields a sliver, not the whole side", skipped_area > 0.0 and skipped_area < 0.2 * open_area, str(skipped_area / open_area))

	# A real telegraph whose ground footprint projects into the edge band.
	var cam: Camera3D = fx.camera.cam
	var vp: Vector2 = cam.get_viewport().get_visible_rect().size
	var ray_from := cam.project_ray_origin(Vector2(vp.x * 0.04, vp.y * 0.5))
	var ray_dir := cam.project_ray_normal(Vector2(vp.x * 0.04, vp.y * 0.5))
	var hit = Plane(Vector3.UP, 0.0).intersects_ray(ray_from, ray_dir)
	t.check("the camera sees the ground at the left edge", hit != null)
	if hit != null:
		var ground := FlatGround.new()
		var warn = Telegraph.ring(_game, ground, Threat.Type.INSTANT, Vector3(hit.x, 0.0, hit.z), 2.0)
		await _frames(1)
		var rects := PlayerFx.warning_rects(root.get_tree(), cam, PlayerFx.ImpactFrame.YIELD_MARGIN_PX)
		t.check("a live telegraph has a screen rect", rects.size() >= 1, str(rects.size()))
		var band_hit := false
		for r in rects:
			band_hit = band_hit or r.position.x < minf(vp.x, vp.y) * PlayerFx.ImpactFrame.BAND
		t.check("that rect reaches the edge band", band_hit, str(rects))
		frame.hide_now()
		fx._last_frame = -1.0e9
		var burst: Vector3 = Vector3(hit.x + 30.0, 0.0, hit.z)
		var fired: bool = fx.impact_frame(burst, 1.0)
		t.check("the frame fires with a warning on screen", fired and frame.active())
		t.check("the frame holds the warning's rect", frame._rects.size() >= 1)
		var live: Array = frame._shapes(vp, frame._rects)
		t.check("the frame yields to the real telegraph", live.any(func(sh): return sh["skipped"]))
		await _frames(1)
		t.check("the draw counted what it left out", frame.yielded + frame.drawn > 0 and frame.yielded > 0, "%d drawn, %d yielded" % [frame.drawn, frame.yielded])
		warn.queue_free()
		await _frames(1)
		t.eq("a spent telegraph leaves no rect", PlayerFx.warning_rects(root.get_tree(), cam, 0.0).filter(func(r): return r.has_point(Vector2(vp.x * 0.04, vp.y * 0.5))).size(), 0)
		# Boss and world-event hazards are not in group "telegraph" but are enemy warnings too;
		# a neutral mark (a Warden lift, a Silo ring) is not one.
		var rects_before := PlayerFx.warning_rects(root.get_tree(), cam, 0.0).size()
		var neutral = Telegraph.ring(_game, ground, Threat.Type.INSTANT, Vector3(hit.x, 0.0, hit.z), 2.0, 3.5, Palette.SAND)
		var amber = Telegraph.ring(_game, ground, Threat.Type.INSTANT, Vector3(hit.x, 0.0, hit.z), 2.0, 3.5, Palette.AMBER)
		await _frames(1)
		t.eq("neutral and owned marks add no rect", PlayerFx.warning_rects(root.get_tree(), cam, 0.0).size(), rects_before)
		neutral.queue_free()
		amber.queue_free()
		var hazard := Hazard.new()
		hazard.commit_annulus("edge_test", Threat.Type.INSTANT, Vector3(hit.x, 0.0, hit.z), Vector2(0.0, 2.0), 3.5, 2.0, 1.0)
		_game.add_child(hazard)
		await _frames(1)
		t.check("the hazard is not in group telegraph", not hazard.is_in_group("telegraph") and hazard.is_in_group(Threat.GROUP))
		var hz := PlayerFx.warning_rects(root.get_tree(), cam, PlayerFx.ImpactFrame.YIELD_MARGIN_PX)
		t.check("a hostile boss hazard has a screen rect", hz.size() == 1 and hz[0].position.x < minf(vp.x, vp.y) * PlayerFx.ImpactFrame.BAND, str(hz))
		frame.hide_now()
		fx._last_frame = -1.0e9
		fx.impact_frame(Vector3(hit.x + 30.0, 0.0, hit.z), 1.0)
		t.check("the frame yields to a boss hazard", frame._shapes(vp, frame._rects).any(func(sh): return sh["skipped"]))
		t.check("a rect clear of the edge band tests and splits nothing", frame._shapes(vp, [Rect2(vp * 0.4, vp * 0.2)]).all(func(sh): return not sh["skipped"]))
		hazard.queue_free()
	quit(t.verdict())


class FlatGround:
	extends RefCounted

	func height(_x: float, _z: float) -> float:
		return 0.0


static func _area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in poly.size():
		var j := (i + 1) % poly.size()
		a += poly[i].x * poly[j].y - poly[j].x * poly[i].y
	return absf(a) * 0.5


# The impact frame as it was before it yielded (player_fx.gd at f259e8cf), written out again
# here so a change to the live geometry cannot move this reference with it.
static func _old_shapes(rect: Vector2, focus_in: Vector2, strength: float, heat: float, seed_value: int) -> Array:
	var out := []
	var band := minf(rect.x, rect.y) * 0.2
	var focus := focus_in.clamp(Vector2.ZERO, rect)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var ink_base := PlayerFx.INK
	if heat > 0.0:
		var dark := Color(ink_base.r, ink_base.g, ink_base.b, 0.8 * heat)
		var hot := Color(PlayerFx.HEAT_COLOR.r, PlayerFx.HEAT_COLOR.g, PlayerFx.HEAT_COLOR.b, PlayerFx.FlashGuard.alpha(0.4 * heat))
		var clear := Color(hot.r, hot.g, hot.b, 0.0)
		for ring in [[0.0, band * 0.6, dark, hot], [band * 0.6, band, hot, clear]]:
			var o := [Vector2(ring[0], ring[0]), Vector2(rect.x - ring[0], ring[0]), rect - Vector2(ring[0], ring[0]), Vector2(ring[0], rect.y - ring[0])]
			var n_in := [Vector2(ring[1], ring[1]), Vector2(rect.x - ring[1], ring[1]), rect - Vector2(ring[1], ring[1]), Vector2(ring[1], rect.y - ring[1])]
			for k in 4:
				var n := (k + 1) % 4
				out.append({"poly": PackedVector2Array([o[k], o[n], n_in[n], n_in[k]]), "colors": PackedColorArray([ring[2], ring[2], ring[3], ring[3]])})
	for i in int(56 * strength):
		var angle := TAU * (float(i) + rng.randf() * 0.8) / float(56 * strength)
		var dir := Vector2(cos(angle), sin(angle))
		var exit := INF
		if dir.x > 0.001:
			exit = minf(exit, (rect.x - focus.x) / dir.x)
		elif dir.x < -0.001:
			exit = minf(exit, -focus.x / dir.x)
		if dir.y > 0.001:
			exit = minf(exit, (rect.y - focus.y) / dir.y)
		elif dir.y < -0.001:
			exit = minf(exit, -focus.y / dir.y)
		if exit == INF or exit < 1.0:
			continue
		var inner := maxf(0.0, exit - band * rng.randf_range(0.5, 1.0))
		var width := rng.randf_range(5.0, 16.0) * (0.6 + 0.4 * strength)
		var side := Vector2(-dir.y, dir.x) * width
		var tip := focus + dir * inner
		var outer := focus + dir * (exit + width * 2.0)
		var accent := i % (3 if heat > 0.0 else 7) == 0
		var ink := ink_base
		ink.a = 0.75 + 0.2 * heat
		if accent:
			ink = Color(1, 1, 1, 0.5).lerp(Color(PlayerFx.HEAT_COLOR.r, PlayerFx.HEAT_COLOR.g, PlayerFx.HEAT_COLOR.b, 0.9), heat)
			ink.a = PlayerFx.FlashGuard.alpha(ink.a)
		out.append({"poly": PackedVector2Array([tip, outer + side, outer - side]), "color": ink})
	return out
