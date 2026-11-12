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


# Waits `seconds` of game time, however many frames that takes.
func _settle(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		await process_frame
		left -= _game.get_process_delta_time()


func _run() -> void:
	await _frames(2)
	_game.ctx.calm = true
	_game.flow.press_start()
	_game.flow.choose_class(0)
	await _frames(5)
	# The ball holds still: on a free-running clock a loaded machine drops physics ticks, so a rolling ball ends up
	# somewhere else on the slope each run, and the camera with it, and the word spots this test reads move off the
	# safe area. The checks set the ball's state (velocity, contact) where they need motion.
	_game.player.set_frozen(true)
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

	# PF-26: BWAP, the word for an ordinary hit on the beat, waits BEAT_REPEAT_S, not a big
	# moment's WORD_REPEAT_S; and no word lands on a hostile warning.
	for w in fx._words:
		w["t"] = 1.0
	fx._last_word = -1.0e9
	fx._word_seen.clear()
	t.check("an on-beat BWAP stands no taller than a plain KLANG", PlayerFx.WORDS["beat"]["size"] * PlayerFx.ONBEAT_GROW <= PlayerFx.WORDS["smash"]["size"] + 0.001)
	t.check("BWAP stamps", fx.word("beat", ball + Vector3(3, 2, 0)))
	for w in fx._words:
		w["t"] = 1.0
	fx._last_word = -1.0e9
	fx._word_seen["beat"] = fx._clock - PlayerFx.WORD_REPEAT_S - 0.1
	t.check("planted: past a big word's repeat window, BWAP still waits", not fx.word("beat", ball + Vector3(3, 2, 0)))
	fx._word_seen["beat"] = fx._clock - PlayerFx.BEAT_REPEAT_S - 0.1
	t.check("past its own window BWAP stamps again", fx.word("beat", ball + Vector3(3, 2, 0)))
	# A hit's own word grows on the beat (on_beat_hit): the growth's warning check builds a typed rect list, which once
	# raised a script error and left the word its plain size.
	for w in fx._words:
		w["t"] = 1.0
	fx._last_word = -1.0e9
	fx._word_seen.clear()
	t.check("KLANG stamps for the beat to grow", fx.word("smash", ball + Vector3(3, 2, 0)))
	var plain: float = float(fx._words_by_id("smash").get("size", 0.0))
	fx._on_beat_word(null, "smash", fx._clock)
	t.near("and the beat grows it", float(fx._words_by_id("smash").get("size", -1.0)), plain * PlayerFx.ONBEAT_GROW)
	for w in fx._words:
		w["t"] = 1.0
	fx._last_word = -1.0e9
	fx._word_seen.clear()
	var own := Rect2(600, 300, 120, 50)
	var other := Rect2(400, 300, 120, 50)
	var warn_own: Array[Rect2] = [Rect2(650, 320, 40, 40)]
	var warn_both: Array[Rect2] = [Rect2(450, 320, 240, 40)]
	var warn_none: Array[Rect2] = [Rect2(50, 50, 40, 40)]
	var above := Rect2(500, 200, 120, 50)
	var spots: Array[Rect2] = [own, other, above]
	var foe_box: Array[Rect2] = [Rect2(380, 280, 360, 90)]
	t.eq("a word clear of warnings keeps its spot", PlayerFx.word_spot(spots, warn_none), 0)
	t.eq("planted: a word on a warning takes the ball's other side", PlayerFx.word_spot(spots, warn_own), 1)
	t.eq("a word with its foe on both sides goes above the foe", PlayerFx.word_spot(spots, foe_box), 2)
	t.eq("a word with every spot covered stays unsaid", PlayerFx.word_spot(spots, [Rect2(0, 0, 1000, 1000)] as Array[Rect2]), -1)
	# The camera eases its arm and field of view toward the ball's speed (chase_camera.gd), and the checks above set the
	# ball's velocity, so the placement checks below wait until it has settled by game time, not by frame count: a
	# loaded machine runs fewer, longer frames, and the view then sat a pixel or two elsewhere each run.
	await _settle(4.0)
	var wcam: Camera3D = fx.camera.cam
	# A ring on the ground under each side's spot: the word has nowhere to go.
	var at: Vector3 = fx.clear_of_lane(ball + Vector3(3, 2, 0))
	var side: Vector3 = wcam.global_basis.x
	var rel: Vector3 = at - ball
	var covers: Array = []
	for spot in [at, at - side * 2.0 * rel.dot(side)]:
		var px := wcam.unproject_position(spot)
		var floor_at = Plane(Vector3.UP, 0.0).intersects_ray(wcam.project_ray_origin(px), wcam.project_ray_normal(px))
		if floor_at != null:
			covers.append(Telegraph.ring(_game, FlatGround.new(), Threat.Type.INSTANT, floor_at, 6.0))
	await _frames(1)
	for w in fx._words:
		w["t"] = 1.0
	fx._last_word = -1.0e9
	fx._word_seen.clear()
	var held: int = fx.spawned.get("word_held", 0)
	# The foe a word names is avoided like a warning: a box mesh where the word would go.
	var foe := Node3D.new()
	var shape := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.5, 1.5, 1.5)
	shape.mesh = box
	foe.add_child(shape)
	_game.add_child(foe)
	foe.global_position = ball + Vector3(3, 2, 0)
	var foe_px := PlayerFx.foe_rect(foe, wcam)
	t.check("the foe has a screen rect", foe_px.has_area(), str(foe_px))
	t.check("a word naming its foe never lands on it", fx.word("smash", ball + Vector3(3, 2, 0), Color.TRANSPARENT, foe)
		and not PlayerFx._word_rect(wcam, fx._words_by_id("smash")["at"], float(fx._words_by_id("smash")["away"]) > 0.0, float(fx._words_by_id("smash")["width_px"]),
			float(fx._words_by_id("smash")["size"]), 0.01).intersects(foe_px), "foe %s" % foe_px)
	# A foe filling the top of the view: the spot above it is off screen, so the word stays clear
	# of it or unsaid, never pulled back onto it.
	foe.global_position = ball + Vector3(3, 6, 0)
	(shape.mesh as BoxMesh).size = Vector3(8, 8, 1.5)
	await _frames(1)
	for w in fx._words:
		w["t"] = 1.0
	fx._last_word = -1.0e9
	fx._word_seen.clear()
	var big := PlayerFx.foe_rect(foe, wcam)
	var said: bool = fx.word("smash", ball + Vector3(3, 2, 0), Color.TRANSPARENT, foe)
	var vsize := wcam.get_viewport().get_visible_rect().size
	var safe := Rect2(vsize * 0.5 * (Vector2.ONE - PlayerFx.WORD_SAFE), vsize * PlayerFx.WORD_SAFE)
	var took := Rect2() if not said else PlayerFx._word_rect(wcam, fx._words_by_id("smash")["at"], float(fx._words_by_id("smash")["away"]) > 0.0,
		float(fx._words_by_id("smash")["width_px"]), float(fx._words_by_id("smash")["size"]), 0.01)
	t.check("planted: a word by a big foe never ends up on it, nor off the safe area", not said or (safe.encloses(took) and not took.intersects(big)),
		"said %s at %s foe %s" % [said, took, big])
	# FX-07: a read word (DENT) speaks inside the sound words' gap, but places by their rules:
	# beside the foe, clear of its body by the warning gap, inside the safe area, at render priority.
	foe.global_position = ball + Vector3(3, 2, 0)
	(shape.mesh as BoxMesh).size = Vector3(1.5, 1.5, 1.5)
	await _frames(1)
	for w in fx._words:
		w["t"] = 1.0
	fx._last_word = -1.0e9
	fx._word_seen.clear()
	var body := PlayerFx.foe_rect(foe, wcam)
	fx._last_word = fx._clock
	var gap_said: bool = not fx.word("vault", ball + Vector3(-3, 2, 0))
	var read_said: bool = fx.read_word("DENT", foe, Color.WHITE)
	var read: Dictionary = fx._words_by_id("read")
	var read_rect := Rect2() if read.is_empty() else PlayerFx._word_rect(wcam, read["at"], float(read["away"]) > 0.0, float(read["width_px"]), float(read["size"]), 0.01)
	t.check("a read word speaks inside the gap, beside its foe, clear of it and inside the safe area",
		gap_said and read_said and read_rect.has_area() and not read_rect.intersects(body.grow(PlayerFx.WORD_WARNING_GAP)) and safe.encloses(read_rect)
		and is_equal_approx(float(read["size"]), PlayerFx.READ_SIZE) and (read["node"] as Label3D).render_priority == PlayerFx.RENDER_PRIORITY,
		"said %s/%s at %s foe %s" % [gap_said, read_said, read_rect, body])
	shape.visible = false
	t.check("a read word for a foe out of view stays unsaid, so the next hit asks again", not fx.read_word("ZZAP!", foe, Color.WHITE))
	foe.free()
	for w in fx._words:
		w["t"] = 1.0
	fx._last_word = -1.0e9
	fx._word_seen.clear()
	held = fx.spawned.get("word_held", 0)
	t.check("a warning under both sides holds the word", not PlayerFx.warning_rects(root.get_tree(), wcam, 0.0).is_empty()
		and not fx.word("slam", ball + Vector3(3, 2, 0)) and fx.spawned.get("word_held", 0) == held + 1,
		"rects %s" % [PlayerFx.warning_rects(root.get_tree(), wcam, 0.0)])
	for c in covers:
		c.free()
	await _frames(1)

	# Knockback moments: a blazing ram says WHAM, a bump says nothing; three pins inside
	# the window stamp STRIKE.
	var dummy := Node3D.new()
	_game.add_child(dummy)
	dummy.global_position = ball + Vector3(3, 2, 0)
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

	# The impact frame yields to warnings on the GPU (Andrew, 17 Oct 16:36Z: warnings always
	# draw on top): its shader discards inside each warning rect plus a margin. The CPU draws
	# every piece, so the geometry is the old frame, polygon for polygon, and the rects go up
	# as uniforms.
	var frame = fx._frame
	var screen := Vector2(1920.0, 1080.0)
	for case in [[1.0, 0.0, 11], [0.5, 0.9, 99], [1.0, 0.9, 5]]:
		frame._strength = case[0]
		frame._heat = case[1]
		frame._seed = case[2]
		frame._focus = Vector2(900.0, 500.0)
		var now: Array = frame._shapes(screen)
		var old := _old_shapes(screen, frame._focus, case[0], case[1], case[2])
		var same := now.size() == old.size()
		for k in mini(now.size(), old.size()):
			same = same and now[k]["poly"] == old[k]["poly"] and now[k].get("color") == old[k].get("color") and now[k].get("colors") == old[k].get("colors")
		t.check("the frame is the old frame (strength %.1f heat %.1f)" % [case[0], case[1]], same and old.size() > 0,
			"%d now, %d old" % [now.size(), old.size()])
		t.eq("same piece count (strength %.1f heat %.1f)" % [case[0], case[1]], now.size(), old.size())
	frame._strength = 1.0
	frame._heat = 0.9
	frame._seed = 5
	var open_shapes: Array = frame._shapes(screen)
	var open_wedges := open_shapes.filter(func(sh): return sh.has("color"))
	t.eq("a hot full-strength frame is 8 wash trapezoids and its wedges", open_shapes.size() - open_wedges.size(), 8)

	# A synthetic rect on the edge reaches the shader as a uniform, and the shader's test (written
	# out in GDScript) discards inside the rect plus the margin and keeps a pixel on its edge.
	var margin: float = PlayerFx.ImpactFrame.YIELD_MARGIN_PX
	var left_edge := Rect2(0.0, 380.0, 150.0, 320.0)
	frame.apply_rects([left_edge])
	var mat: ShaderMaterial = frame.material
	t.check("the frame has the yield shader", mat != null and mat.shader != null and mat.shader.code.contains("discard"))
	t.eq("one rect: the count uniform", mat.get_shader_parameter("rect_count"), 1)
	t.eq("the margin uniform is the yield margin", mat.get_shader_parameter("margin"), margin)
	t.eq("the rect uniform is x, y, w, h", (mat.get_shader_parameter("rects") as PackedVector4Array)[0], Vector4(0.0, 380.0, 150.0, 320.0))
	var yields := func(p: Vector2) -> bool: return PlayerFx.ImpactFrame._yields(p, [left_edge], 1, margin)
	t.check("a point inside the rect is discarded", yields.call(Vector2(60.0, 500.0)))
	t.check("a point inside the margin is discarded", yields.call(Vector2(150.0 + margin - 0.5, 500.0)) and yields.call(Vector2(60.0, 380.0 - margin + 0.5)))
	t.check("a point on the margin's edge stays", not yields.call(Vector2(150.0 + margin, 500.0)) and not yields.call(Vector2(60.0, 380.0 - margin)))
	t.check("a point just outside the margin stays", not yields.call(Vector2(150.0 + margin + 0.5, 500.0)) and not yields.call(Vector2(60.0, 700.0 + margin + 0.5)))
	t.check("only the first count rects count", not PlayerFx.ImpactFrame._yields(Vector2(60.0, 500.0), [left_edge], 0, margin))

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
		var rects := PlayerFx.warning_rects(root.get_tree(), cam, 0.0)
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
		var sent := PlayerFx.warning_rects(root.get_tree(), cam, 0.0)
		var uniforms: PackedVector4Array = frame.material.get_shader_parameter("rects")
		var matched: bool = frame._rects.size() == sent.size() and int(frame.material.get_shader_parameter("rect_count")) == sent.size()
		for k in sent.size():
			matched = matched and uniforms[k] == Vector4(sent[k].position.x, sent[k].position.y, sent[k].size.x, sent[k].size.y)
		t.check("the uniforms are the real telegraph's rects", matched and sent.size() >= 1, "%d sent, %d held" % [sent.size(), frame._rects.size()])
		var inside: Vector2 = sent[0].get_center() if not sent.is_empty() else Vector2(-1.0, -1.0)
		t.check("the shader test discards the telegraph's centre", PlayerFx.ImpactFrame._yields(inside, frame._rects, frame._rects.size(), margin))
		await _frames(1)
		t.check("the draw drew the frame", frame.drawn > 0, str(frame.drawn))
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
		var hz := PlayerFx.warning_rects(root.get_tree(), cam, 0.0)
		t.check("a hostile boss hazard has a screen rect", hz.size() == 1 and hz[0].position.x < minf(vp.x, vp.y) * PlayerFx.ImpactFrame.BAND, str(hz))
		frame.hide_now()
		fx._last_frame = -1.0e9
		fx.impact_frame(Vector3(hit.x + 30.0, 0.0, hit.z), 1.0)
		var hz_uniform: PackedVector4Array = frame.material.get_shader_parameter("rects")
		t.check("the frame sends a boss hazard's rect to the shader", frame._rects.size() == 1 and int(frame.material.get_shader_parameter("rect_count")) == 1 and hz_uniform[0] == Vector4(hz[0].position.x, hz[0].position.y, hz[0].size.x, hz[0].size.y), str(hz_uniform[0]))
		t.check("the shader test discards the hazard's centre", PlayerFx.ImpactFrame._yields(hz[0].get_center(), frame._rects, 1, margin))
		hazard.queue_free()
	# Dunk charge: the coil on the collar's rear arc shows the held record in the class colour,
	# its pips go dark as the window runs down, and it clears on spend and on expiry.
	var dunk = _game.player.dunk
	dunk.clear("reset")
	await _frames(1)
	t.check("no dunk coil without a charge", not fx.dunk_glow_shown())
	var cls: Color = _game.player.class_color()
	dunk.store(30.0, "test", "test", cls)
	await _frames(1)
	var shown: Color = fx.dunk_glow_color()
	t.check("a held charge shows the coil in the class colour's hue", fx.dunk_glow_shown() and absf(shown.h - cls.h) < 0.01 and shown.s > 0.2,
		"%s vs %s" % [shown, cls])
	t.eq("every pip lit at the store", fx.dunk_pips_lit(), PlayerFx.DUNK_PIPS)
	var rear: Vector3 = fx._dunk_glow.global_basis.z
	var travel: Vector3 = _game.player.state.velocity * Vector3(1, 0, 1)
	t.check("the arc sits level behind the line of travel", absf(rear.y) < 0.001 and (travel.length() < PlayerFx.DUNK_HOLD_SPEED or rear.dot(-travel.normalized()) > 0.9),
		"rear %s, travel %s" % [rear, travel])
	dunk.clock = float(dunk.charge["until"]) - dunk.WINDOW * 0.5
	await _frames(1)
	t.eq("half the window left lights two pips", fx.dunk_pips_lit(), 2)
	dunk.clock = float(dunk.charge["until"]) - dunk.WINDOW * 0.2
	await _frames(1)
	t.eq("a fifth of the window left lights one pip", fx.dunk_pips_lit(), 1)
	dunk.spend(null)
	await _frames(1)
	t.check("a spent charge clears the coil", not fx.dunk_glow_shown())
	dunk.store(30.0, "test", "test", cls)
	await _frames(1)
	dunk.tick(dunk.WINDOW + 0.1)
	await _frames(1)
	t.check("an expired charge clears the coil", not fx.dunk_glow_shown())
	quit(t.verdict())


class FlatGround:
	extends RefCounted

	func height(_x: float, _z: float) -> float:
		return 0.0


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
