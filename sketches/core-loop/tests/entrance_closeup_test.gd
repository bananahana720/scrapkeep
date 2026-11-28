extends SceneTree

const Game := preload("res://src/game.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")
const Intent := preload("res://src/movement/intent.gd")
const Rows := preload("res://src/presentation/flourish_rows.gd")
const Cues := preload("res://src/presentation/flourish_cues.gd")
const T := preload("res://tests/support/t.gd")
const Comfort := preload("res://src/core/comfort.gd")

# Ruling cf: Brindle's entrance has a close-up. A comic panel beside his card shows the
# Requisition from a low camera as it comes over the rim (flourish_inset.gd), and the world
# drops to slow motion for as long as the panel is up (flourish_cues.gd "slow",
# game.slow_motion).
#   R1     the arrival's full form carries one panel and one slow beat over the same seconds,
#          inside the arrival; the short form carries neither.
#   G1-G3  game.slow_motion multiplies the scale a tool set and gives it back; a hit stop
#          inside it lifts back to the slowed speed, and one that outlasts it to full speed; it
#          leaves the smoothing setting (physics interpolation) alone.
#   B1     a bot's arrival shows the panel and never slows the world.
#   M1     reduced motion: the panel shows, the world does not slow.
#   K1-K3  the skip grace counts wall seconds, so a press cannot end the row at the window's
#          middle and can before its end; that press gives the speed back at once; a row
#          stopped any other way gives it back by the next frame.
#   F1-F2  a screen away from play gives it back, and takes his waiting line with it.
#   H1-H5  a hand on the controls: full speed before the window; the beat's scale inside it,
#          with the panel up; a pause gives the speed back and the unpause returns it; full
#          speed and no panel past it. H6: a hit stop inside the window lifts back to the
#          slowed speed.
#   O1-O4  his first second, one voice at a time: the HUD's boss title stays down while his
#          card says the name; his line in the speech bubble waits for the picture and comes
#          when the panel has gone; a jukebox record and a field note found meanwhile wait
#          for the card (O3, O5). An arena retry, which replays no arrival, gets the title, even
#          with another flourish's card up (O4).
#   C1     the panel's camera stands low, between the ship's berth and the arena's middle, and
#          looks at the ship's body.

const DT := 1.0 / 60.0

var _t = T.new("entrance_closeup_test")
var _game
var _started := false


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _to_arena() -> void:
	_game.flow.enter_stage(2, Vector3(0.0, 0.0, 16.0), false)
	_game.flow._finish_stage()


func _arrive(hands_on: bool) -> void:
	_game.flow.show_title()
	_game.bot_driven = not hands_on
	Harness.start_run(_game)
	_game.presentation.flourish.stop_all()
	_to_arena()


# Moves the row on to `clock` seconds and lets the cues read it, as a frame does.
func _to(clock: float) -> void:
	var player = _game.presentation.flourish
	while player.playing and player.clock < clock:
		player.advance(minf(DT, clock - player.clock + 0.0001))
		_frame()


func _frame() -> void:
	var cues = _game.presentation.flourish_cues
	if cues.is_processing():
		cues._process(DT)


func _inset():
	for node in _game.presentation.flourish.live_nodes():
		if is_instance_valid(node) and String(node.get_meta("flourish_kind", "")) == "inset":
			return node
	return null


func _row_checks() -> void:
	var slow: Array = Cues.world_beats("brindle_arrival", false).filter(func(b): return b.get("kind") == "slow")
	var panels: Array = Rows.pieces("brindle_arrival", false).filter(func(p): return p.kind == "inset")
	var same: bool = slow.size() == 1 and panels.size() == 1 and is_equal_approx(float(slow[0]["at"]), float(panels[0]["at"])) \
		and is_equal_approx(float(slow[0]["for"]), float(panels[0]["for"]))
	var inside: bool = same and float(slow[0]["at"]) + float(slow[0]["for"]) < Rows.length("brindle_arrival", false) \
		and float(slow[0]["scale"]) > 0.1 and float(slow[0]["scale"]) < 1.0
	var short_clean: bool = not Cues.world_beats("brindle_arrival", true).any(func(b): return b.get("kind") == "slow") \
		and not Rows.pieces("brindle_arrival", true).any(func(p): return p.kind == "inset")
	_t.check("R1 the full arrival carries one panel and one slow beat over the same seconds; the short form neither", same and inside and short_clean,
		"slow %s, panels %s, short clean %s" % [slow, panels.size(), short_clean])


func _game_checks() -> void:
	var tree: SceneTree = _game.get_tree()
	Harness.start_run(_game)
	var before: bool = tree.physics_interpolation
	Engine.time_scale = 2.0
	_game.slow_motion(0.5)
	var slowed := Engine.time_scale
	var smoothed: bool = tree.physics_interpolation
	_game.slow_motion(1.0)
	_t.check("G1 slow motion multiplies the scale a tool set, and gives it back", is_equal_approx(slowed, 1.0) and is_equal_approx(Engine.time_scale, 2.0),
		"%.2f inside, %.2f after" % [slowed, Engine.time_scale])
	_t.check("G3 it leaves the smoothing setting alone", before == smoothed and before == tree.physics_interpolation,
		"before %s, inside %s, after %s" % [before, smoothed, tree.physics_interpolation])
	Engine.time_scale = 1.0
	_game.slow_motion(0.3)
	_game.hit_stop(0.05)
	var stopped := Engine.time_scale
	_game._end_hit_stop()
	var back := Engine.time_scale
	_game.hit_stop(0.05)
	_game.slow_motion(1.0)
	var held := Engine.time_scale
	_game._end_hit_stop()
	_t.check("G2 a hit stop inside lifts back to the slowed speed; one that outlasts it, to full speed", is_equal_approx(stopped, _game.HIT_STOP_SCALE)
			and is_equal_approx(back, 0.3) and is_equal_approx(held, _game.HIT_STOP_SCALE) and is_equal_approx(Engine.time_scale, 1.0),
		"stop %.2f, back %.2f, held %.2f, after %.2f" % [stopped, back, held, Engine.time_scale])


func _physics_process(_delta: float) -> bool:
	if _game.flow == null or _started:
		return false
	_started = true
	Harness.install(_game)
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	var player = _game.presentation.flourish
	var slow: Dictionary = Cues.world_beats("brindle_arrival", false).filter(func(b): return b.get("kind") == "slow")[0]
	var from := float(slow["at"])
	var until := from + float(slow["for"])
	var mid := (from + until) * 0.5
	_row_checks()
	_game_checks()

	_arrive(false)
	_to(mid)
	_t.check("B1 a bot's arrival shows the panel and never slows the world", player.id == "brindle_arrival" and not player.short and _inset() != null
			and is_equal_approx(Engine.time_scale, 1.0), "playing %s, panel %s, scale %.2f" % [player.id, _inset() != null, Engine.time_scale])

	Comfort.reduced_motion = true
	_arrive(true)
	_to(mid)
	_t.check("M1 reduced motion: the panel shows, the world does not slow", not player.short and _inset() != null and is_equal_approx(Engine.time_scale, 1.0),
		"panel %s, scale %.2f" % [_inset() != null, Engine.time_scale])
	Comfort.reduced_motion = false

	var bubble = _game.get_node("Workshop").bubble
	var press := InputEventKey.new()
	press.keycode = KEY_Q
	press.pressed = true
	_arrive(true)
	_to(mid)
	var in_window := Engine.time_scale
	var early: bool = player.skippable()
	player._input(press)
	var held: bool = player.playing
	_to(until - 0.1)
	var late: bool = player.skippable() and is_equal_approx(Engine.time_scale, float(slow["scale"]))
	_t.check("K1 the skip grace counts wall seconds: no skip at the window's middle, one before its end", not early and held and late,
		"middle %s (still up %s), near the end %s at scale %.2f" % [early, held, late, Engine.time_scale])
	player._input(press)
	_t.check("K2 a press inside the window ends the row and gives the speed back at once", is_equal_approx(in_window, float(slow["scale"]))
			and not player.playing and is_equal_approx(Engine.time_scale, 1.0), "%.2f inside, %.2f after the press" % [in_window, Engine.time_scale])

	_arrive(true)
	_to(mid)
	player.stop_all()
	_frame()
	_t.check("K3 a row stopped any other way gives the speed back by the next frame", is_equal_approx(Engine.time_scale, 1.0)
			and not _game.presentation.flourish_cues.is_processing(), "scale %.2f" % Engine.time_scale)

	_arrive(true)
	_to(mid)
	in_window = Engine.time_scale
	var waiting: int = bubble._intro_queue.size()
	_game.flow.show_title()
	_t.check("F1 a screen away from play gives it back", is_equal_approx(in_window, float(slow["scale"])) and is_equal_approx(Engine.time_scale, 1.0),
		"%.2f inside, %.2f on the title" % [in_window, Engine.time_scale])
	_t.check("F2 and his waiting line does not follow the player to the title", waiting == 1 and bubble._intro_queue.is_empty() and not bubble.showing(),
		"waiting %d, then %d" % [waiting, bubble._intro_queue.size()])

	_arrive(true)
	_frame()
	_t.check("H1 a hand on the controls: full speed before the window", player.id == "brindle_arrival" and not player.short and player.clock < from
			and is_equal_approx(Engine.time_scale, 1.0), "clock %.2f, scale %.2f" % [player.clock, Engine.time_scale])
	_to(mid)
	var panel = _inset()
	_t.check("H2 inside the window the world runs at the beat's scale, with the panel up", panel != null and is_equal_approx(Engine.time_scale, float(slow["scale"])),
		"panel %s, scale %.2f" % [panel != null, Engine.time_scale])
	_game.hit_stop(0.05)
	_frame()
	var stopped := Engine.time_scale
	_game._end_hit_stop()
	_t.check("H6 a hit stop inside the window lifts back to the slowed speed", is_equal_approx(stopped, _game.HIT_STOP_SCALE)
			and is_equal_approx(Engine.time_scale, float(slow["scale"])), "stop %.2f, back %.2f" % [stopped, Engine.time_scale])
	if panel != null:
		var ship: Node3D = _game.boss.ship
		var arena: Node3D = _game.boss.arena
		var stand: Vector3 = panel.stands_at()
		var to_ship: Vector3 = (ship.global_position - stand).normalized()
		var between: bool = (stand - ship.global_position).dot(arena.global_position - ship.global_position) > 0.0
		_t.check("C1 the panel's camera stands low between the berth and the arena's middle, looking at the ship", between
				and stand.y < ship.global_position.y + 3.0 and panel.looks_at().dot(to_ship) > 0.7,
			"between %s, eye %.1f over the berth, aim %.2f" % [between, stand.y - ship.global_position.y, panel.looks_at().dot(to_ship)])
	var hud = _game.hud
	bubble._process(DT)
	# Any pill an earlier arrival's run left up is cleared, so this one is the note found now.
	hud._lore_left = 0.0
	hud._lore_panel.visible = false
	hud._show_lore()
	var pill_held: bool = not hud._lore_panel.visible
	hud.take_found("Lights On, Late Set", "Moss's Back Room", "b-side")
	hud._step_ach(DT)
	var plate_held: bool = not hud.corner_rects().any(func(r): return r["name"] == "plate")
	_t.check("O1 his card says the name: the boss title stays down, and his line waits for the picture", not String(EventKinds.hud("boss_arena_entered")) in hud.launch_card.drawn_words()
			and not bubble.showing(), "title %s, bubble '%s'" % [hud.launch_card.drawn_words(), bubble.text if bubble.showing() else ""])
	paused = true
	_frame()
	var under_pause := Engine.time_scale
	paused = false
	_frame()
	_t.check("H3 a pause gives the speed back, and the unpause returns it", is_equal_approx(under_pause, 1.0) and is_equal_approx(Engine.time_scale, float(slow["scale"])),
		"%.2f paused, %.2f after" % [under_pause, Engine.time_scale])
	_to(until + 0.05)
	_t.check("H4 past the window the world is back at full speed and the panel has gone", player.playing and _inset() == null
			and is_equal_approx(Engine.time_scale, 1.0),
		"playing %s, panel %s, scale %.2f" % [player.playing, _inset() != null, Engine.time_scale])
	bubble._process(DT)
	_t.check("O2 the panel gone, his line comes up", bubble.visible and bubble.text != "", "bubble '%s'" % bubble.text)
	_to(player.length() + 0.1)
	_frame()
	# The arena is a fight from the moment it is entered (screen_busy.gd), so the record waits past the
	# card, through the fight, and shows once Brindle is down and the screen has been quiet.
	_game.ctx.screen_busy.step(2.5)
	hud._step_ach(DT)
	var held_in_fight: bool = not hud.corner_rects().any(func(r): return r["name"] == "plate")
	_game.ctx.screen_busy.fight_over()
	_game.ctx.screen_busy.step(2.5)
	# The note was found first, so it takes the screen first (oldest first, one at a time); the record follows it.
	hud._step_lore(DT)
	var pill_up: bool = hud._lore_panel.visible
	hud._step_lore(3.1)
	hud._step_ach(DT)
	_t.check("O3 a record found meanwhile waited for the card, then for the fight, then showed", plate_held and held_in_fight and hud.corner_rects().any(func(r): return r["name"] == "plate"),
		"held under the card %s, held through the fight %s" % [plate_held, held_in_fight])
	_t.check("O5 a field note found meanwhile waited too", pill_held and pill_up, "held %s, up %s" % [pill_held, pill_up])
	_t.check("H5 the arrival ends on its own at full speed", not player.playing and is_equal_approx(Engine.time_scale, 1.0)
			and not _game.presentation.flourish_cues.is_processing(), "playing %s, scale %.2f" % [player.playing, Engine.time_scale])

	hud.launch_card.visible = false
	player.play("cold_open", -1, {}, "full")
	_game.events.boss_arena_entered.emit()
	_t.check("O4 an arena retry replays no arrival, so the boss title goes up, whatever else reads", player.reading() and player.id == "cold_open"
			and String(EventKinds.hud("boss_arena_entered")) in hud.launch_card.drawn_words(), str(hud.launch_card.drawn_words()))

	_game.bot_driven = true
	var code: int = _t.verdict()
	_game.free()
	quit(code)
	return true
