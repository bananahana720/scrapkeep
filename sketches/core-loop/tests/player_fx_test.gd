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
	quit(t.verdict())
