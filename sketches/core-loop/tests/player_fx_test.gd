extends SceneTree

# Player effects (PLAYER-FX.md) through the real game: might grows with the build, sound
# words keep their caps and stay out of the lane ahead, overdrive switches at the soft cap
# with hysteresis, carve sparks need banked ground at speed, and the layer's per-frame
# script cost stays small. Headless runs simulate no particles (fx_library_test), so this
# pins configuration and switches, not pixels.
const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const PlayerFx := preload("res://src/presentation/player_fx.gd")
const ImpactFrame := preload("res://src/presentation/impact_frame.gd")
const Density := preload("res://src/presentation/density.gd")
const Telegraph := preload("res://src/combat/telegraph.gd")
const Hazard := preload("res://src/boss/hazard.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const Palette := preload("res://src/core/palette.gd")
const UiFonts := preload("res://src/core/ui_fonts.gd")
const DamageNumbers := preload("res://src/presentation/damage_numbers.gd")
const Comfort := preload("res://src/core/comfort.gd")

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
	var held_kind := func(kind: String) -> int: return fx.spawned.get("held_" + kind, 0)
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
	var rings_before: int = held_kind.call("warning")
	var ring_said: bool = fx.word("smash", ball + Vector3(3, 2, 0), Color.TRANSPARENT, foe)
	var ring_word := Rect2()
	if ring_said:
		var rw: Dictionary = fx._words_by_id("smash")
		ring_word = PlayerFx._word_rect(wcam, rw["at"], float(rw["away"]) > 0.0, float(rw["width_px"]), float(rw["size"]), 0.01)
	t.check("a word naming its foe, with the rings on both sides, stands clear of the foe or is held by a warning",
		(ring_said and not ring_word.intersects(foe_px)) or (not ring_said and held_kind.call("warning") == rings_before + 1),
		"said %s word %s foe %s held warning +%d" % [ring_said, ring_word, foe_px, held_kind.call("warning") - rings_before])
	# PF-26: with both sides covered by the rings, a word naming its foe has only the spot above the foe. It lifts over
	# the foe's whole mark column, so it never lies on the marks stacked over the foe: held, or clear of them.
	for w in fx._words:
		w["t"] = 1.0
	fx._last_word = -1.0e9
	fx._word_seen.clear()
	var named_said: bool = fx.word("smash", ball + Vector3(3, 2, 0), Color.TRANSPARENT, foe)
	var named_rect := Rect2()
	if named_said and not fx._words_by_id("smash").is_empty():
		var nw: Dictionary = fx._words_by_id("smash")
		named_rect = PlayerFx._word_rect(wcam, nw["at"], float(nw["away"]) > 0.0, float(nw["width_px"]), float(nw["size"]), 0.01)
	t.check("PF-26: a word naming its foe, with the rings on both sides, never lies on the foe", foe_px.has_area()
		and (not named_said or not named_rect.intersects(foe_px)), "said %s word %s foe %s" % [named_said, named_rect, foe_px])
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
	var stack := PlayerFx.stack_rect(foe, wcam)
	fx._last_word = fx._clock
	var gap_said: bool = not fx.word("vault", ball + Vector3(-3, 2, 0))
	var read_said: bool = fx.read_word("DENT", foe, Color.WHITE)
	var read: Dictionary = fx._words_by_id("read")
	var read_rect := Rect2() if read.is_empty() else PlayerFx._word_rect(wcam, read["at"], float(read["away"]) > 0.0, float(read["width_px"]), float(read["size"]), 0.01)
	t.check("a read word speaks inside the gap, beside its foe, clear of it and the marks stacked over it, inside the safe area",
		gap_said and read_said and read_rect.has_area() and not read_rect.intersects(body.grow(PlayerFx.WORD_WARNING_GAP))
		and stack.has_area() and not read_rect.intersects(stack.grow(PlayerFx.WORD_WARNING_GAP)) and safe.encloses(read_rect)
		and is_equal_approx(float(read["size"]), PlayerFx.READ_SIZE) and is_equal_approx(fx._last_word, fx._clock) and (read["node"] as Label3D).render_priority == PlayerFx.RENDER_PRIORITY,
		"said %s/%s at %s foe %s" % [gap_said, read_said, read_rect, body])
	# Every pooled slot showing: the read waits rather than cut a live word short.
	var live: Array = []
	for w in fx._words:
		live.append(w["t"])
		w["t"] = 0.5
	var busy_said: bool = fx.read_word("ZZAP!", foe, Color.WHITE)
	t.check("a read word with every slot showing waits and cuts no word short", not busy_said and fx._words.all(func(w): return w["t"] == 0.5))
	for i in fx._words.size():
		fx._words[i]["t"] = live[i]
	shape.visible = false
	t.check("a read word for a foe out of view stays unsaid, so the next hit asks again", not fx.read_word("ZZAP!", foe, Color.WHITE))
	foe.free()
	for w in fx._words:
		w["t"] = 1.0
	fx._last_word = -1.0e9
	fx._word_seen.clear()
	held = fx.spawned.get("word_held", 0)
	var ring_rects := PlayerFx.warning_rects(root.get_tree(), wcam, PlayerFx.WORD_WARNING_GAP)
	var both_said: bool = fx.word("slam", ball + Vector3(3, 2, 0))
	var both_word := Rect2()
	if both_said:
		var bw: Dictionary = fx._words_by_id("slam")
		both_word = PlayerFx._word_rect(wcam, bw["at"], float(bw["away"]) > 0.0, float(bw["width_px"]), float(bw["size"]), 0.01)
	t.check("a warning under both sides leaves the word a spot beside the ball, clear of both", ring_rects.size() >= 2 and both_said
		and not ring_rects.any(func(r: Rect2): return r.intersects(both_word)), "said %s word %s rects %s" % [both_said, both_word, ring_rects])
	for c in covers:
		c.free()
	await _frames(1)

	# PF-26: the fight stays visible. The rings are gone, so only the fight rules and the foe's own
	# rectangles can refuse a word here. Every placement claim below needs the stamp to be clear of the
	# rectangle it names, or the held counter of that kind (held_foe, held_number) to rise by one; a plain
	# "held" is not enough, so a word that never speaks cannot pass.
	var fight := Node3D.new()
	var fight_shape := MeshInstance3D.new()
	var fight_box := BoxMesh.new()
	fight_box.size = Vector3(1.5, 1.5, 1.5)
	fight_shape.mesh = fight_box
	fight.add_child(fight_shape)
	_game.add_child(fight)
	fight.add_to_group("enemy")
	var word_rect := func(id: String) -> Rect2:
		var w: Dictionary = fx._words_by_id(id)
		return Rect2() if w.is_empty() else PlayerFx._word_rect(wcam, w["at"], float(w["away"]) > 0.0, float(w["width_px"]), float(w["size"]), 0.01)
	var reset_words := func() -> void:
		for w in fx._words:
			w["t"] = 1.0
		fx._last_word = -1.0e9
		fx._word_seen.clear()
	var kinds_in := func(kind: String) -> int:
		var n := 0
		for k in fx._fight_kind:
			if k == kind:
				n += 1
		return n
	# The owner of a foe's marks, as status_marks.gd and machine_fx.gd are: a test double answers marked().
	var marker_script := GDScript.new()
	marker_script.source_code = "extends Node\nvar shown = null\nfunc marked(f) -> bool:\n\treturn f == shown\n"
	marker_script.reload()
	var marker = marker_script.new()
	marker.add_to_group(PlayerFx.MARKS_GROUP)
	_game.add_child(marker)
	# (a) A foe in the group, unnamed, sits where the slam would go.
	fight.global_position = ball + Vector3(3, 2, 0)
	await _frames(2)
	reset_words.call()
	var column := PlayerFx.foe_rect(fight, wcam)
	held = held_kind.call("foe")
	var slam_said: bool = fx.word("slam", ball + Vector3(3, 2, 0))
	var slam_rect: Rect2 = word_rect.call("slam") if slam_said else Rect2()
	t.check("PF-26: a word that names no foe stays off a foe in view, or is held by it",
		column.has_area() and ((slam_said and not slam_rect.intersects(column)) or (not slam_said and held_kind.call("foe") == held + 1)),
		"said %s word %s column %s held foe +%d" % [slam_said, slam_rect, column, held_kind.call("foe") - held])
	# (a2) A foe showing no mark reserves no marks rectangle; the same foe showing one does.
	await _frames(2)
	fx._fight_rects()
	var plain_marks: int = kinds_in.call("marks")
	var plain_foes: int = kinds_in.call("foe")
	marker.shown = fight
	await _frames(2)
	fx._fight_rects()
	var shown_marks: int = kinds_in.call("marks")
	var shown_at := PlayerFx.stack_rect(fight, wcam).grow(PlayerFx.WORD_WARNING_GAP)
	t.check("PF-26: a foe showing no mark reserves no marks rectangle", plain_foes >= 1 and plain_marks == 0, "foes %d marks %d" % [plain_foes, plain_marks])
	t.check("PF-26: a foe showing a mark reserves the marks rectangle over it", shown_marks == 1 and fx._fight_rects().has(shown_at),
		"marks %d want %s" % [shown_marks, shown_at])
	marker.shown = null
	# (b) The named foe's body is avoided; this foe is outside the group, so only the named-foe rule sees it.
	fight.remove_from_group("enemy")
	reset_words.call()
	await _frames(2)
	held = held_kind.call("foe")
	var smash_said: bool = fx.word("smash", ball + Vector3(3, 2, 0), Color.TRANSPARENT, fight)
	var smash_rect: Rect2 = word_rect.call("smash") if smash_said else Rect2()
	t.check("PF-26: a word naming a foe outside the group stays off its body, or is held by it",
		(smash_said and not smash_rect.intersects(column)) or (not smash_said and held_kind.call("foe") == held + 1),
		"said %s word %s column %s" % [smash_said, smash_rect, column])
	fight.add_to_group("enemy")
	# (c) BWAP, the on-beat word, lands beside the ball: an unnamed foe in the group sits on that spot, and the
	# foe the hit names is a different one, away from it.
	reset_words.call()
	fight_box.size = Vector3(6, 6, 6)
	fight.global_position = fx._beside_ball()
	var hit_foe := Node3D.new()
	_game.add_child(hit_foe)
	hit_foe.global_position = ball + Vector3(-14, 2, -6)
	await _frames(2)
	reset_words.call()
	column = PlayerFx.foe_rect(fight, wcam)
	held = held_kind.call("foe")
	var beat_before: int = fx.spawned.get("word_beat", 0)
	fx._on_beat_word(hit_foe, "ram", fx._clock)
	var beat_said: bool = fx.spawned.get("word_beat", 0) > beat_before
	var beat_rect: Rect2 = word_rect.call("beat") if beat_said else Rect2()
	t.check("PF-26: BWAP beside the ball stands clear of an unnamed foe there, or is held by it",
		column.has_area() and ((beat_said and not beat_rect.intersects(column)) or (not beat_said and held_kind.call("foe") == held + 1)),
		"said %s beat %s column %s held foe +%d" % [beat_said, beat_rect, column, held_kind.call("foe") - held])
	hit_foe.free()
	# (d) Control that can fail both ways: a foe in view, well off the spot and inside the screen, is in the avoid
	# list (the rule sees it) and the word still stamps clear of it (the rule does not hold every word).
	reset_words.call()
	fight_box.size = Vector3(1.5, 1.5, 1.5)
	var vsize_all := wcam.get_viewport().get_visible_rect().size
	fight.global_position = wcam.project_position(vsize_all * Vector2(0.16, 0.3), 25.0)
	await _frames(2)
	reset_words.call()
	var far_rect := PlayerFx.foe_rect(fight, wcam)
	var control_said: bool = fx.word("slam", ball + Vector3(3, 2, 0))
	var control_rect: Rect2 = word_rect.call("slam") if control_said else Rect2()
	var seen: bool = fx._fight_rects().any(func(r: Rect2): return r.encloses(far_rect))
	t.check("PF-26 control: a foe in view away from the spot is in the avoid list, and the word still stamps clear of it",
		far_rect.has_area() and Rect2(Vector2.ZERO, vsize_all).encloses(far_rect) and seen and control_said and not control_rect.intersects(far_rect),
		"foe %s seen %s word %s" % [far_rect, seen, control_rect])
	# (d2) A foe 90 m out whose rectangle is bigger than a word, over the spot: the word keeps off it.
	reset_words.call()
	var spot_at: Vector3 = fx.clear_of_lane(ball + Vector3(3, 2, 0))
	fight_box.size = Vector3(20, 20, 20)
	fight.global_position = wcam.project_position(wcam.unproject_position(spot_at), 90.0)
	await _frames(2)
	reset_words.call()
	var far90 := PlayerFx.foe_rect(fight, wcam)
	held = held_kind.call("foe")
	var far_said: bool = fx.word("slam", ball + Vector3(3, 2, 0))
	var far_word: Rect2 = word_rect.call("slam") if far_said else Rect2()
	t.check("PF-26: a foe 90 m out, larger on screen than a word, is kept off", far90.size.y > 80.0 and far90.has_point(wcam.unproject_position(spot_at))
		and ((far_said and not far_word.intersects(far90)) or (not far_said and held_kind.call("foe") == held + 1)),
		"foe %s said %s word %s" % [far90, far_said, far_word])
	# (d3) A long foe whose origin is behind the camera plane with its front part on screen: kept off too.
	reset_words.call()
	var forward := -wcam.global_basis.z
	var spot_depth := (spot_at - wcam.global_position).dot(forward)
	fight_box.size = Vector3(2, 2, 40)
	fight.global_basis = wcam.global_basis
	fight.global_position = spot_at - forward * (spot_depth + 10.0)
	await _frames(2)
	reset_words.call()
	var behind := PlayerFx.foe_rect(fight, wcam)
	held = held_kind.call("foe")
	var behind_said: bool = fx.word("slam", ball + Vector3(3, 2, 0))
	var behind_word: Rect2 = word_rect.call("slam") if behind_said else Rect2()
	t.check("PF-26: a foe whose origin is behind the camera, with part of it on screen, is kept off",
		(fight.global_position - wcam.global_position).dot(forward) < 0.0 and behind.has_area()
		and ((behind_said and not behind_word.intersects(behind)) or (not behind_said and held_kind.call("foe") == held + 1)),
		"foe %s said %s word %s" % [behind, behind_said, behind_word])
	fight.global_basis = Basis.IDENTITY
	fight_box.size = Vector3(1.5, 1.5, 1.5)
	# (d4) A dot of a foe, under FOE_MIN_PX, is skipped: a far crowd costs nothing and hides nothing.
	reset_words.call()
	fight.global_position = wcam.project_position(wcam.unproject_position(spot_at), 150.0)
	await _frames(2)
	var dot := PlayerFx.foe_rect(fight, wcam)
	t.check("PF-26: a foe smaller than FOE_MIN_PX is not in the avoid list", dot.has_area() and maxf(dot.size.x, dot.size.y) < PlayerFx.FOE_MIN_PX
		and fx._fight_rects().size() == fx._warnings().size(), "%s rects %d warnings %d" % [dot, fx._fight_rects().size(), fx._warnings().size()])
	fight.free()
	await _frames(2)
	# The box clip: a box that passes beside the camera and crosses the near plane with nothing of it on screen adds
	# no rectangle, and one partly on screen adds a rectangle inside the viewport.
	var origin := wcam.global_position
	var vb := wcam.global_basis
	var beside_box := AABB(Vector3(-40, -1, -5), Vector3(10, 2, 10))
	var beside_rect := PlayerFx._view_rect(PlayerFx._box_points(Transform3D(vb, origin), beside_box, wcam), wcam)
	var partly_box := AABB(Vector3(-1, -1, -5), Vector3(40, 2, 10))
	var partly_points := PlayerFx._box_points(Transform3D(vb, origin), partly_box, wcam)
	var partly_rect := PlayerFx._view_rect(partly_points, wcam)
	var partly_raw := Rect2(partly_points[0], Vector2.ZERO)
	for pt in partly_points:
		partly_raw = partly_raw.expand(pt)
	var view_all := Rect2(Vector2.ZERO, wcam.get_viewport().get_visible_rect().size)
	t.check("PF-26: a box beside the camera that crosses the near plane, with nothing of it on screen, adds no rectangle",
		not beside_rect.has_area(), "%s" % beside_rect)
	t.check("PF-26: a box partly on screen adds a rectangle inside the viewport, though its raw projection is far larger",
		partly_rect.has_area() and view_all.encloses(partly_rect) and partly_raw.size.x > view_all.size.x * 3.0, "rect %s raw %s" % [partly_rect, partly_raw])
	# Cost: forty foes in the view, one refresh per drawn frame however many words ask in it.
	var crowd: Array = []
	for i in 40:
		var c := Node3D.new()
		var cm := MeshInstance3D.new()
		var cb := BoxMesh.new()
		cb.size = Vector3(1.5, 1.5, 1.5)
		cm.mesh = cb
		for k in 3:
			var extra := MeshInstance3D.new()
			extra.mesh = cb
			c.add_child(extra)
		c.add_child(cm)
		_game.add_child(c)
		c.add_to_group("enemy")
		c.global_position = wcam.project_position(vsize_all * Vector2(0.1 + 0.8 * (i % 8) / 8.0, 0.15 + 0.7 * (i / 8) / 5.0), 20.0 + i)
		crowd.append(c)
	await _frames(2)
	var refreshes_before: int = fx.spawned.get("fight_refresh", 0)
	fx._fight_rects()
	fx._fight_rects()
	fx._fight_rects()
	t.eq("PF-26: three asks in one drawn frame are one refresh", fx.spawned.get("fight_refresh", 0) - refreshes_before, 1)
	await process_frame
	var rect_count: int = fx._fight_rects().size()
	t.check("PF-26: one refresh sees all 40 foes in view", rect_count >= 30, "%d rects" % rect_count)
	for c in crowd:
		c.free()
	await _frames(2)
	# (e) A rising damage number: the word keeps off its path.
	reset_words.call()
	var spot_px := wcam.unproject_position(fx.clear_of_lane(ball + Vector3(3, 2, 0)))
	var layer = _game.hud.damage_numbers
	layer.clear()
	layer.add("pf26", 50.0, spot_px + Vector2(0, 40), "kinetic", "player")
	var path: Array[Rect2] = layer.path_rects()
	var figure := UiFonts.mono().get_string_size("50", HORIZONTAL_ALIGNMENT_LEFT, -1, DamageNumbers.font_size(50.0, false)).x
	t.check("PF-26: a damage number reports the path it rises along, as wide as the figure _draw measures", path.size() == 1 and path[0].has_area()
		and is_equal_approx(path[0].size.x, figure + 2.0 * DamageNumbers.outline_px(DamageNumbers.font_size(50.0, false))), "%s figure %s" % [path, figure])
	held = held_kind.call("number")
	var num_said: bool = fx.word("slam", ball + Vector3(3, 2, 0))
	var num_rect: Rect2 = word_rect.call("slam") if num_said else Rect2()
	t.check("PF-26: a word keeps off a damage number's rising path, or is held by it",
		not path.is_empty() and ((num_said and not num_rect.intersects(path[0])) or (not num_said and held_kind.call("number") == held + 1)),
		"said %s word %s path %s" % [num_said, num_rect, path])
	layer.clear()
	reset_words.call()
	t.check("PF-26 control: with the number gone the same word stamps", fx.word("slam", ball + Vector3(3, 2, 0)))
	reset_words.call()
	marker.free()

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
	var margin: float = ImpactFrame.YIELD_MARGIN_PX
	var left_edge := Rect2(0.0, 380.0, 150.0, 320.0)
	frame.apply_rects([left_edge])
	var mat: ShaderMaterial = frame.material
	t.check("the frame has the yield shader", mat != null and mat.shader != null and mat.shader.code.contains("discard"))
	t.eq("one rect: the count uniform", mat.get_shader_parameter("rect_count"), 1)
	t.eq("the margin uniform is the yield margin", mat.get_shader_parameter("margin"), margin)
	t.eq("the rect uniform is x, y, w, h", (mat.get_shader_parameter("rects") as PackedVector4Array)[0], Vector4(0.0, 380.0, 150.0, 320.0))
	var yields := func(p: Vector2) -> bool: return ImpactFrame._yields(p, [left_edge], 1, margin)
	t.check("a point inside the rect is discarded", yields.call(Vector2(60.0, 500.0)))
	t.check("a point inside the margin is discarded", yields.call(Vector2(150.0 + margin - 0.5, 500.0)) and yields.call(Vector2(60.0, 380.0 - margin + 0.5)))
	t.check("a point on the margin's edge stays", not yields.call(Vector2(150.0 + margin, 500.0)) and not yields.call(Vector2(60.0, 380.0 - margin)))
	t.check("a point just outside the margin stays", not yields.call(Vector2(150.0 + margin + 0.5, 500.0)) and not yields.call(Vector2(60.0, 700.0 + margin + 0.5)))
	t.check("only the first count rects count", not ImpactFrame._yields(Vector2(60.0, 500.0), [left_edge], 0, margin))

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
			band_hit = band_hit or r.position.x < minf(vp.x, vp.y) * ImpactFrame.BAND
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
		t.check("the shader test discards the telegraph's centre", ImpactFrame._yields(inside, frame._rects, frame._rects.size(), margin))
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
		t.check("a hostile boss hazard has a screen rect", hz.size() == 1 and hz[0].position.x < minf(vp.x, vp.y) * ImpactFrame.BAND, str(hz))
		frame.hide_now()
		fx._last_frame = -1.0e9
		fx.impact_frame(Vector3(hit.x + 30.0, 0.0, hit.z), 1.0)
		var hz_uniform: PackedVector4Array = frame.material.get_shader_parameter("rects")
		t.check("the frame sends a boss hazard's rect to the shader", frame._rects.size() == 1 and int(frame.material.get_shader_parameter("rect_count")) == 1 and hz_uniform[0] == Vector4(hz[0].position.x, hz[0].position.y, hz[0].size.x, hz[0].size.y), str(hz_uniform[0]))
		t.check("the shader test discards the hazard's centre", ImpactFrame._yields(hz[0].get_center(), frame._rects, 1, margin))
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
	await _sable_halo(fx)
	await _rivet_fire(fx)
	quit(t.verdict())


# Holds the weapon's public charge at `level` (the record the halo reads), or lets it go.
func _hold_charge(level: float) -> void:
	var driver = _game.combat.weapon_driver
	driver._charge_armed = false
	driver._charging = level > 0.0
	driver._charge = level


# Sable's charge halo (wave 46 3D blueprint section 3.2), through the real weapon record and events.
func _sable_halo(fx) -> void:
	var ChargeHalo := load("res://src/presentation/charge_halo.gd")
	var Weapons := load("res://src/combat/weapons.gd")
	var cadence: Dictionary = fx.weapon_cadence()
	t.check("Sable's weapon is a tap-charge weapon, so she wears the halo", PlayerFx.halo_pilot(cadence), str(cadence.get("trigger")))
	t.near("the tap floor is the casters' least charged bolt", ChargeHalo.TAP_FLOOR, float(Weapons.BASE[Weapons.ARC_CASTER]["charge_min"]))
	t.check("frost is ice blue, never the old works' green", PlayerFx.ELEMENT_COLORS["frost"] == Palette.ICE and PlayerFx.ELEMENT_COLORS["frost"] != Palette.ANCIENT)
	t.check("a frost part's mote is ice blue", PlayerFx.part_color("frost_vane") in [Palette.ICE, Palette.ICE.lerp(Color.WHITE, 0.25)], str(PlayerFx.part_color("frost_vane")))
	Comfort.reduced_motion = false
	_hold_charge(0.0)
	await _settle(0.15)
	t.check("no halo before a charge", fx.halo() == null or fx.halo().hoops_shown() == 0)
	var shown := []
	var radii := []
	for level in [0.35, 0.7, 1.0]:
		_hold_charge(level)
		await _settle(0.12)
		shown.append(fx.halo().hoops_shown())
		radii.append(fx.halo().hoop_radius())
	t.eq("the hoops track the charge: 2 at 0.35, 3 at 0.7, 4 at full", shown, [2, 3, 4])
	t.check("the hoops pull in as the charge grows, 0.16 m to 0.105 m", radii[0] < ChargeHalo.RADIUS_START and radii[0] > radii[1] and radii[1] > radii[2]
		and is_equal_approx(radii[2], ChargeHalo.RADIUS_FULL), str(radii))
	var halo = fx.halo()
	var marker: Node3D = _game.player.pod_mount().find_child("Emitter_L", true, false)
	if marker != null:
		t.check("the halo hangs on the shell's WeaponRing, beside the prong markers", halo.mounted_on() == marker.get_parent())
	else:
		t.check("without a shell the halo hangs under player_fx", halo.mounted_on() == halo and halo.is_inside_tree())
	t.check("the sparks are capped at 12", halo.sparks_cap() == ChargeHalo.SPARKS and ChargeHalo.SPARKS == 12, str(halo.sparks_cap()))
	t.check("the sparks emit at 24 a second at full: half the cap's rate", is_equal_approx(halo.spark_ratio(), 0.5), str(halo.spark_ratio()))
	t.check("full charge closes the hoops into one halo and pulses once", halo.closed() > 0.0 and halo.spawned.get("pulse", 0) == 1)
	# One swell, never a repeat: over a long hold at full the glow rises and falls once at most.
	var turns := [0]
	await _held_glow(halo, 1.2, turns)
	t.check("a held full charge never flickers: it turns from rise to fall once at most, then holds", turns[0] <= 1 and halo.spawned.get("pulse", 0) == 1, str(turns))
	var steady: float = halo.glow()

	# A charged release: the halo ends and one ring leaves the prong tips.
	var weapon := String(cadence.get("weapon", ""))
	var taps: int = fx.spawned.get("sable_tap", 0)
	_hold_charge(0.0)
	_game.combat.weapon_driver._recover_s = 0.12
	var tip: Vector3 = halo.tip()
	_game.events.shot_fired.emit(weapon, tip, tip + Vector3(0, 0, -40))
	t.check("a charged bolt fires the release ring and hides the halo", halo.rings_alive() == 1 and halo.spawned.get("release", 0) == 1
		and not halo.halo_shown() and fx.spawned.get("sable_tap", 0) == taps)
	await _settle(0.1)
	var mid: float = halo.ring_radius(0)
	t.check("the ring grows from 0.2 m toward 1.4 m", mid > ChargeHalo.RING_FROM and mid < ChargeHalo.RING_TO, "%.2f" % mid)
	await _settle(0.15)
	t.eq("the ring is gone after its life", halo.rings_alive(), 0)
	_game.combat.weapon_driver._recover_s = 0.0

	# A spark: the jagged arc in vfx's glyph pool, and no ring.
	var vfx = _game.presentation.vfx
	_game.events.shot_fired.emit(weapon, tip, tip + Vector3(0, 0, -40))
	var arc_up := false
	for g in vfx._glyphs:
		arc_up = arc_up or (g["t"] < 1.0 and g["node"].mesh == vfx._meshes["arc"])
	t.check("a spark draws the tap arc from vfx's glyph pool, not a ring", fx.spawned.get("sable_tap", 0) == taps + 1 and arc_up and halo.rings_alive() == 0)
	t.eq("the arc keeps vfx's pool size", vfx._glyphs.size(), vfx.POOL)

	# Pools stay capped: three quick releases keep two rings, and a new halo never takes a third draw.
	_game.combat.weapon_driver._recover_s = 0.12
	for i in 3:
		_game.events.shot_fired.emit(weapon, tip, tip + Vector3(0, 0, -40))
	t.eq("the release rings stay pooled at 2", halo.rings_alive(), ChargeHalo.RINGS)
	_game.combat.weapon_driver._recover_s = 0.0
	await _frames(1)
	_hold_charge(0.5)
	await _frames(2)
	t.check("a halo with rings alive stays within 2 draws", halo.draws_alive() <= ChargeHalo.DRAWS and halo.halo_shown(), str(halo.draws_alive()))

	# A charge that drops with no bolt, and a cancelled gauge: the hoops collapse, no ring.
	await _settle(0.3)
	var releases: int = halo.spawned.get("release", 0)
	_hold_charge(0.0)
	await _frames(2)
	t.check("a dropped charge collapses the hoops", halo.state() == "collapsing" and halo.spawned.get("cancel", 0) == 1)
	await _settle(0.15)
	t.check("the collapse ends in 0.1 s with no ring", halo.state() == "idle" and halo.rings_alive() == 0 and halo.spawned.get("release", 0) == releases)
	_hold_charge(0.6)
	await _frames(2)
	_game.events.gauge_cancelled.emit("test", "cancel")
	t.check("gauge_cancelled collapses it too", halo.state() == "collapsing" and halo.spawned.get("cancel", 0) == 2)
	_hold_charge(0.0)
	await _settle(0.15)

	# A gauge release: at or under the tap floor it is the arc, above it the ring.
	_game.events.gauge_released.emit("test", 0.2)
	t.check("a gauge released at the tap floor draws the arc", fx.spawned.get("sable_tap", 0) == taps + 2 and halo.rings_alive() == 0)
	_game.events.gauge_released.emit("test", 0.8)
	t.check("a gauge released above it fires the ring", halo.rings_alive() == 1)
	await _settle(0.3)

	# Reduce motion: the hoops hold still and throw no sparks; Reduce flashes cuts the full-charge swell.
	Comfort.reduced_motion = true
	_hold_charge(0.5)
	await _frames(2)
	var spin: float = halo._spin
	await _settle(0.2)
	t.check("reduced motion: the hoops do not spin and no sparks fly", is_equal_approx(halo._spin, spin) and halo.spark_ratio() == 0.0 and halo.hoops_shown() == 3)
	Comfort.reduced_motion = false
	_hold_charge(0.0)
	await _settle(0.2)
	var FlashGuard := load("res://src/core/flash_guard.gd")
	FlashGuard.on = true
	_hold_charge(1.0)
	var peak := [0.0]
	await _held_glow(halo, 0.5, [0], peak)
	FlashGuard.on = false
	t.check("Reduce flashes keeps the full-charge swell at a third of its rise", peak[0] <= steady * (1.0 + ChargeHalo.PULSE_GAIN * FlashGuard.SPIKE_SHARE) + 0.001
		and peak[0] < steady * (1.0 + ChargeHalo.PULSE_GAIN) - 0.01, "%.3f of %.3f" % [peak[0], steady])
	_hold_charge(0.0)
	await _settle(0.2)
	t.eq("the halo sorts under the threat marks", halo._mesh.material_override.render_priority, PlayerFx.RENDER_PRIORITY)


# Samples the halo's glow every frame for `seconds`: counts the times it turns (rise to fall or back) in
# turns[0] and keeps the highest in peak[0].
func _held_glow(halo, seconds: float, turns: Array, peak := [0.0]) -> void:
	var last: float = halo.glow()
	var slope := 0.0
	var left := seconds
	while left > 0.0:
		await process_frame
		left -= _game.get_process_delta_time()
		var g: float = halo.glow()
		peak[0] = maxf(peak[0], g)
		var d := g - last
		if absf(d) > 1e-5:
			if slope != 0.0 and signf(d) != signf(slope):
				turns[0] += 1
			slope = d
		last = g


# Rivet's muzzle flash and casings (section 3.3): through fake LaserMuzzle markers on a WeaponRing under
# the pod mount, so the effects stand where the shell's markers stand.
func _rivet_fire(fx) -> void:
	var ring := Node3D.new()
	ring.name = "WeaponRing"
	var markers := []
	for side in [["LaserMuzzle_L", -0.6], ["LaserMuzzle_R", 0.6]]:
		var m := Node3D.new()
		m.name = side[0]
		m.position = Vector3(side[1], 0.17, -1.15)
		ring.add_child(m)
		markers.append(m)
	_game.player.pod_mount().add_child(ring)
	fx._marker_wait.clear()
	fx._rivet_shots = 0
	Comfort.reduced_motion = false
	var from: Vector3 = _game.player.shown_position()
	var dir := Vector3(0, 0, -1)
	fx._rivet_shot(from, dir)
	t.check("shot 0 flashes at the left muzzle", fx.flashes_alive() == 1 and fx.flash_at(0).is_equal_approx(markers[0].global_position),
		"%s vs %s, %d alive" % [fx.flash_at(0), markers[0].global_position, fx.flashes_alive()])
	fx._rivet_shot(from, dir)
	t.check("shot 1 flashes at the right muzzle", fx.flashes_alive() == 2 and fx.flash_at(1).is_equal_approx(markers[1].global_position))
	t.eq("the first shot on each side throws a casing", fx.casings_alive(), 2)
	fx._rivet_shot(from, dir)
	fx._rivet_shot(from, dir)
	t.eq("the second shot on a side throws none", fx.casings_alive(), 2)
	for i in 40:
		fx._rivet_shot(from, dir)
	t.check("pools stay capped: 2 flashes and 8 casings", fx.flashes_alive() <= PlayerFx.FLASHES and fx.casings_alive() == PlayerFx.CASINGS
		and PlayerFx.FLASHES == 2 and PlayerFx.CASINGS == 8, "%d flashes, %d casings" % [fx.flashes_alive(), fx.casings_alive()])
	t.eq("the flash and casing pools are one MultiMesh each", [fx._flashes.multimesh.instance_count, fx._casings.multimesh.instance_count], [PlayerFx.FLASHES, PlayerFx.CASINGS])
	var views: Array = fx.root.find_children("*", "MultiMeshInstance3D", false, false).filter(func(n): return n.name in ["MuzzleFlashes", "SpentCasings"])
	t.eq("rivet fire is RIVET_DRAWS draws", views.size(), PlayerFx.RIVET_DRAWS)
	var metal: StandardMaterial3D = fx._casings.material_override
	t.check("a casing is brass leaning 45% to steel, roughness 0.5, metallic 0.35", metal.albedo_color.is_equal_approx(Palette.BRASS.lerp(Palette.STEEL, 0.45))
		and is_equal_approx(metal.roughness, 0.5) and is_equal_approx(metal.metallic, 0.35))
	var gap: Vector3 = ring.global_transform.affine_inverse() * fx._casing_at[0]
	t.check("a left casing leaves outboard of the left drum, behind the muzzle", gap.x < -0.6 and gap.z > -1.15 and gap.y < 0.17, str(gap))
	await _settle(0.08)
	t.eq("a flash lives 0.05 s", fx.flashes_alive(), 0)
	await _settle(0.35)
	t.eq("a casing lives 0.35 s", fx.casings_alive(), 0)
	t.check("a casing falls under gravity", fx._casing_v[0].y < 0.0, str(fx._casing_v[0]))
	Comfort.reduced_motion = true
	fx._rivet_shot(from, dir)
	t.check("reduced motion keeps the flash and throws no casing", fx.flashes_alive() == 1 and fx.casings_alive() == 0)
	Comfort.reduced_motion = false
	ring.free()
	fx._marker_wait.clear()


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
		var hot := Color(ImpactFrame.HEAT_COLOR.r, ImpactFrame.HEAT_COLOR.g, ImpactFrame.HEAT_COLOR.b, PlayerFx.FlashGuard.alpha(0.4 * heat))
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
			ink = Color(1, 1, 1, 0.5).lerp(Color(ImpactFrame.HEAT_COLOR.r, ImpactFrame.HEAT_COLOR.g, ImpactFrame.HEAT_COLOR.b, 0.9), heat)
			ink.a = PlayerFx.FlashGuard.alpha(ink.a)
		out.append({"poly": PackedVector2Array([tip, outer + side, outer - side]), "color": ink})
	return out
