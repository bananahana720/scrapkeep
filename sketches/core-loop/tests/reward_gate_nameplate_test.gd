extends SceneTree

# PF-22 (wave 42 film): the reward gates' names sat in a detached 2D row below the gates, the row changed
# from frame to frame, and nothing said which part was taken. A gate now owns its name: a screen prompt
# (WorldPrompt, owner_placed) that the gate puts at its own projected crossbar point every frame, centred on
# its column, never slotted, aside or clamped. The speech bubble keeps off the shown names and the launch take
# stamps the part that was taken.
#
#   A  each gate's name: its part's title, centred on its gate, hanging under the crossbar point (even in the top
#      HUD band), at a type size whose cap height is 14 px or more on a 1280x720 window
#   B  fit_names with numbers: two rows before hiding, the farther gate hides its name only, ties, hysteresis
#   C  stability: the ball crosses a symmetric row's centre line and the camera sways a pixel for 120 frames
#   D  approach: the real dam row spacing (16 m), three and four gates, from 120 m to 20 m
#   E  keep_clear_rects()
#   F  the launch take's stamp, in every path
#   G  through the game: the speech bubble's seat in the workshop's order, and the hand-over from the gate's
#      event to the take, in both orders and scrapless

const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const RewardGates := preload("res://src/build/reward_gates.gd")
const LaunchTake := preload("res://src/presentation/launch_take.gd")
const WorldPrompt := preload("res://src/ui/world_prompt.gd")
const Parts := preload("res://src/build/parts.gd")
const Icons := preload("res://src/ui/icons.gd")
const Workshop := preload("res://src/ui/workshop.gd")
const ScreenRegions := preload("res://src/ui/screen_regions.gd")

const FRAMES := 120
# The project's canvas is 1600x900; a 1280x720 window draws it at 0.8.
const WINDOW_SCALE := 720.0 / 900.0
const CAP_RATIO := 0.714

var _t := T.new("reward_gate_nameplate_test")
var _cam: Camera3D


class StubTerrain:
	func height(_x: float, _z: float) -> float:
		return 0.0

	func drop_point(x: float, z: float, _lift: float) -> Vector3:
		return Vector3(x, 0.0, z)


# Stands in for a word that keeps off the plates: one fixed rect in the group.
class FakeKeepClear:
	extends Node
	var rect := Rect2()

	func keep_clear_rects() -> Array[Rect2]:
		return [rect]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_fit_part()
	await _gates_part()
	await _take_part()
	await _game_part()
	quit(_t.verdict())


func _entry(index: int, col_x: float, dist: float, w1 := 140.0, was_shown := false, w2 := 80.0, dw := 0.0) -> Dictionary:
	return {"index": index, "col": Vector2(col_x, 300.0), "dist": dist, "w1": w1, "w2": w2, "two": PackedStringArray(["a", "b"]),
		"h1": 30.0, "h2": 62.0, "dw": dw, "dh": 40.0 if dw > 0.0 else 0.0, "was_shown": was_shown, "was_detail": false}


# B. The rule, with numbers.
func _fit_part() -> void:
	var lone := RewardGates.fit_names([_entry(0, 400.0, 50.0, 140.0, false, 80.0, 200.0)])
	_t.check("B. a lone gate shows its name on one row with its effect lines", lone[0]["shown"] and lone[0]["rows"] == 1 and lone[0]["detail"], str(lone))
	_t.check("B. the name is centred on its gate's column and hangs under it", is_equal_approx((lone[0]["rect"] as Rect2).get_center().x, 400.0) and is_equal_approx((lone[0]["rect"] as Rect2).position.y, 300.0 + RewardGates.NAME_DROP), str(lone[0]["rect"]))
	# Two gates 100 px apart: room is 88, the one-row name (140) does not fit, two rows (80) do, so both show.
	var rows := RewardGates.fit_names([_entry(0, 400.0, 50.0), _entry(1, 520.0, 80.0)])
	_t.check("B. a name wider than its room takes two rows before anything hides", rows.all(func(r): return r["shown"] and r["rows"] == 2), str(rows))
	# 40 px apart: two rows still overlap by 40 px, more than the hold: the farther gate hides its name only.
	var crowd := RewardGates.fit_names([_entry(0, 400.0, 50.0), _entry(1, 440.0, 80.0)])
	_t.check("B. when two names still overlap, the farther gate hides", crowd[0]["shown"] and not crowd[1]["shown"], str(crowd))
	var mirror := RewardGates.fit_names([_entry(0, 400.0, 80.0), _entry(1, 440.0, 50.0)])
	_t.check("B. which gate is farther decides, not its place in the list", not mirror[0]["shown"] and mirror[1]["shown"], str(mirror))
	var tie := RewardGates.fit_names([_entry(0, 400.0, 60.0), _entry(1, 440.0, 60.0)])
	var tie_swapped := RewardGates.fit_names([_entry(1, 440.0, 60.0), _entry(0, 400.0, 60.0)])
	_t.check("B. equal distances: the lower index keeps its name, in either list order", tie[0]["shown"] and not tie[1]["shown"] and tie_swapped[1]["shown"] and not tie_swapped[0]["shown"], "%s %s" % [tie, tie_swapped])
	# Hysteresis: a shown name stays until the overlap exceeds 32 px; a hidden one returns with 32 px clear.
	var stays := RewardGates.fit_names([_entry(0, 400.0, 50.0, 140.0, true), _entry(1, 460.0, 80.0, 140.0, true)])
	_t.check("B. a shown name stays at 20 px of overlap", stays[1]["shown"], str(stays))
	var goes := RewardGates.fit_names([_entry(0, 400.0, 50.0, 140.0, true), _entry(1, 440.0, 80.0, 140.0, true)])
	_t.check("B. a shown name hides at 40 px of overlap", not goes[1]["shown"], str(goes))
	var held := RewardGates.fit_names([_entry(0, 400.0, 50.0, 140.0, true), _entry(1, 500.0, 80.0, 140.0, false)])
	_t.check("B. a hidden name stays hidden with 20 px clear", not held[1]["shown"], str(held))
	var back := RewardGates.fit_names([_entry(0, 400.0, 50.0, 140.0, true), _entry(1, 520.0, 80.0, 140.0, false)])
	_t.check("B. a hidden name returns with 40 px clear", back[1]["shown"], str(back))
	# The effect lines: only under a one-row name that has room for them, whole or not at all.
	var wide := RewardGates.fit_names([_entry(0, 400.0, 50.0, 100.0, false, 80.0, 250.0), _entry(1, 700.0, 80.0, 100.0, false, 80.0, 250.0)])
	_t.check("B. effect lines show when they fit the room", wide.all(func(r): return r["shown"] and r["rows"] == 1 and r["detail"]), str(wide))
	var narrow := RewardGates.fit_names([_entry(0, 400.0, 50.0, 100.0, false, 80.0, 290.0), _entry(1, 700.0, 80.0, 100.0, false, 80.0, 290.0)])
	_t.check("B. effect lines that do not fit the room do not show at all", narrow.all(func(r): return r["shown"] and not r["detail"]), str(narrow))
	var split := RewardGates.fit_names([_entry(0, 400.0, 50.0, 140.0, false, 80.0, 60.0), _entry(1, 520.0, 80.0, 140.0, false, 80.0, 60.0)])
	_t.check("B. no effect lines under a name on two rows", split.all(func(r): return r["rows"] == 2 and not r["detail"]), str(split))
	_t.check("B. fit_names of nothing is nothing", RewardGates.fit_names([]).is_empty())


func _focal() -> float:
	var view := Vector2(root.get_visible_rect().size)
	return view.y * 0.5 / tan(deg_to_rad(_cam.fov) * 0.5)


func _name_of(gate: Node3D) -> Label:
	return gate.get_node_or_null("Name") as Label


func _named(gates: Node3D) -> Array:
	var out := []
	for i in gates._gates.size():
		if _name_of(gates._gates[i]).visible:
			out.append(i)
	return out


func _stand(gates: Node3D, xs: Array, y: float, z: float) -> void:
	for i in xs.size():
		(gates._gates[i] as Node3D).global_position = Vector3(xs[i], y, z)
		gates.offers[i]["at"] = (gates._gates[i] as Node3D).global_position


func _gates_part() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	_cam = Camera3D.new()
	holder.add_child(_cam)
	_cam.make_current()
	_cam.position = Vector3(0.0, 8.0, 0.0)
	var gates := RewardGates.new()
	holder.add_child(gates)
	gates.setup(StubTerrain.new())
	var view := Vector2(root.get_visible_rect().size)

	# A. Each gate's name.
	var ids := ["impact_driver", "brace_frame", "chain_arc"]
	gates.open(ids, Vector3.ZERO, Vector3.FORWARD)
	await process_frame
	await process_frame
	var prompts := 0
	var titles_ok := true
	var centred := true
	var hangs := true
	var worst := 0.0
	for i in gates._gates.size():
		var gate: Node3D = gates._gates[i]
		var prompt := _name_of(gate)
		if prompt == null or not prompt is WorldPrompt:
			continue
		prompts += 1
		titles_ok = titles_ok and prompt.parts()["title"] == RewardGates.prompt_parts(gates.offers[i]).title and prompt.visible
		var col := _cam.unproject_position(gate.global_position + Vector3.UP * RewardGates.HEIGHT)
		var rect := Rect2(prompt.position, prompt.size)
		worst = maxf(worst, absf(rect.get_center().x - col.x))
		centred = centred and absf(rect.get_center().x - col.x) < 0.6
		hangs = hangs and absf(rect.position.y - (col.y + RewardGates.NAME_DROP)) < 0.6
	_t.check("A. each of 3 opened gates has a name prompt that shows its part's title", prompts == 3 and titles_ok, "%d prompts" % prompts)
	_t.check("A. each name is centred on its own gate's column", prompts == 3 and centred, "worst %.2f px" % worst)
	_t.check("A. each name hangs under its crossbar point", prompts == 3 and hangs)
	_t.check("A. no gate wears a Label3D or a 2D prompt the HUD places", gates.find_children("*", "Label3D", true, false).is_empty() and gates.find_children("*", "MeshInstance3D", true, false).all(func(m): return m.name != "Board"))
	var cap := float(WorldPrompt.SIGN_NAME_SIZE) * WINDOW_SCALE * CAP_RATIO
	_t.check("A. the name's cap height is at least 14 px on a 1280x720 window", cap >= 14.0, "%.1f px" % cap)
	# In the top HUD band the name stays at its gate's crossbar point, never clamped down.
	_stand(gates, [-9.0, 0.0, 9.0], 24.0, -38.0)
	await process_frame
	var top_ok := true
	var band_end := ScreenRegions.rect("top", view).end.y
	var notes := []
	for gate in gates._gates:
		var prompt := _name_of(gate)
		var col := _cam.unproject_position(gate.global_position + Vector3.UP * RewardGates.HEIGHT)
		top_ok = top_ok and prompt.visible and absf(prompt.position.y - (col.y + RewardGates.NAME_DROP)) < 0.6 and col.y < band_end
		notes.append("%.0f" % col.y)
	_t.check("A. a gate whose crossbar point is in the top HUD band keeps its name there", top_ok, "crossbar y %s, band ends %.0f" % [notes, band_end])
	_stand(gates, [-9.0, 0.0, 9.0], 0.0, -38.0)

	# E. keep_clear_rects.
	await process_frame
	var rects := gates.keep_clear_rects()
	var same := rects.size() == 3 and gates._gates.all(func(g): return rects.has(Rect2(_name_of(g).position, _name_of(g).size)))
	_t.check("E. keep_clear_rects returns each shown name's rect", same, "%d rects" % rects.size())
	_t.check("E. the gates join the group word_keep_clear", gates.is_in_group("word_keep_clear"))
	var behind := gates._gates[1] as Node3D
	behind.global_position = Vector3(0.0, 0.0, 40.0)
	await process_frame
	_t.check("E. a gate behind the camera has no rect and no name", gates.keep_clear_rects().size() == 2 and not _name_of(behind).visible, "%d rects" % gates.keep_clear_rects().size())
	_cam.rotation.y = PI
	await process_frame
	_t.check("E. looking away leaves the one gate now in front", gates.keep_clear_rects().size() == 1, "%d rects" % gates.keep_clear_rects().size())
	_cam.rotation.y = 0.0
	gates.close()

	# C. Stability: the ball crosses a symmetric row's centre line, the camera sways a pixel.
	gates.open(["impact_driver", "brace_frame", "chain_arc", "rime_rounds"], Vector3.ZERO, Vector3.FORWARD)
	_stand(gates, [-27.0, -9.0, 9.0, 27.0], 0.0, -70.0)
	var sway := 1.0 / _focal()
	var last := []
	var changes := 0
	var sets := []
	for f in FRAMES:
		var ball := Vector3(lerpf(-3.0, 3.0, float(f) / (FRAMES - 1)), 0.0, 0.0)
		_cam.position = Vector3(ball.x, 8.0, 0.0)
		_cam.rotation.y = sway if f % 2 == 0 else -sway
		gates._ball = ball
		await process_frame
		var now := _named(gates)
		if f > 0 and now != last:
			changes += 1
		if not sets.has(now):
			sets.append(now)
		last = now
	print("reward_gate_nameplate_test: stability, %d frames, named set changed %d times, sets %s" % [FRAMES, changes, sets])
	_t.check("C. the set of named gates changes at most once over %d frames of a centre-line crossing and a pixel of sway" % FRAMES, changes <= 1 and not sets.is_empty(), "%d changes, sets %s" % [changes, sets])
	_t.check("C. at least one gate is named throughout", sets.all(func(s): return not s.is_empty()), str(sets))
	gates.close()

	# D. Approach on the dam row's spacing (16 m), three and four gates: typical names, then the longest there are.
	var typical := ["impact_driver", "brace_frame", "chain_arc", "rime_rounds"]
	for count in [3, 4]:
		var got := await _approach(gates, typical, count)
		_t.check("D. %d gates 16 m apart, typical names: every gate is named from 60 m in" % count, got["frames"] == 101 and got["from"] >= 60.0 - 0.001 and got["from"] != INF, "all named from %s m over %d frames" % [got["from"], got["frames"]])
	var longest := _longest_parts(4)
	for count in [3, 4]:
		var got := await _approach(gates, longest, count)
		_t.check("D. %d gates 16 m apart, the longest names: every gate is named from 50 m in" % count, got["frames"] == 101 and got["from"] >= 50.0 - 0.001 and got["from"] != INF, "all named from %s m over %d frames" % [got["from"], got["frames"]])
	holder.queue_free()
	await process_frame


# The ball from 120 m to 20 m before a row of `count` gates 16 m apart (the dam's spacing): which gates are named,
# on how many rows (r) and with effect lines (+), every 10 m. Returns the nearest distance from which all are
# named without a break, and the frame count.
func _approach(gates: Node3D, ids: Array, count: int) -> Dictionary:
	var xs := []
	for i in count:
		xs.append((float(i) - (count - 1) * 0.5) * 16.0)
	gates.open(ids.slice(0, count), Vector3.ZERO, Vector3.FORWARD)
	_stand(gates, xs, 0.0, 0.0)
	_cam.rotation.y = 0.0
	var all_named_from := INF
	var table := []
	var frames := 0
	for step in 101:
		var d := 120.0 - float(step)
		_cam.position = Vector3(0.0, 8.0, d)
		gates._ball = Vector3(0.0, 0.0, d)
		await process_frame
		frames += 1
		var named := _named(gates)
		if named.size() == count:
			if all_named_from == INF:
				all_named_from = d
		else:
			all_named_from = INF
		if step % 10 == 0:
			var shape := []
			for i in named:
				var p := _name_of(gates._gates[i])
				shape.append("%d:%dr%s" % [i, maxi(1, p.name_rows.size()), "+" if p.detail_shown else ""])
			table.append("%dm %s" % [int(d), " ".join(shape) if not shape.is_empty() else "none"])
	print("reward_gate_nameplate_test: approach, %d gates 16 m apart, names %s (r rows, + effect lines): %s" % [count, ids.slice(0, count).map(func(id): return Parts.display_name(id)), " | ".join(table)])
	gates.close()
	return {"from": all_named_from, "frames": frames}


# The ids of the parts with the longest titles, longest first.
func _longest_parts(count: int) -> Array:
	var rows := []
	for id in Parts.ids():
		var d: Resource = Parts.offer_def(id, [])
		if d != null:
			rows.append([RewardGates.prompt_parts({"name": Parts.display_name(id)}).title.length(), id])
	rows.sort_custom(func(a, b): return a[0] > b[0] or (a[0] == b[0] and a[1] < b[1]))
	return rows.slice(0, count).map(func(r): return r[1])


func _take_part() -> void:
	var take = LaunchTake.new()
	root.add_child(take)
	await process_frame
	take.live = true
	var impact := _stamp_at_cover(take, "impact_driver")
	var want := RewardGates.rarity_color(Parts.def("impact_driver").rarity)
	_t.check("F. impact_driver shows Impact Driver and its glyph at full cover", impact["visible"] and impact["text"] == "Impact Driver" and impact["glyph"], str(impact))
	_t.check("F. the name wears the part's exact rarity colour", impact["color"] == want, "%s want %s" % [impact["color"], want])
	_t.check("F. the glyph is the part's family glyph", impact["icon"] == Icons.texture("cat_" + Parts.def("impact_driver").icon_category), str(impact["icon"]))
	var wordless := _stamp_at_cover(take, "")
	_t.check("F. an empty part stays wordless", not wordless["visible"] and not wordless["glyph"], str(wordless))
	var unknown := _stamp_at_cover(take, "no_such_part")
	_t.check("F. an id that names no part stays wordless", not unknown["visible"], str(unknown))
	_stamp_at_cover(take, "impact_driver")
	# play() after a stamped take shows the run-start word, not the last part's name.
	var ran := [false]
	take.play(func(): ran[0] = true)
	var guard := 0
	while take.phase != LaunchTake.HOLD and guard < 600:
		take.advance(1.0 / 60.0)
		guard += 1
	take.advance(1.0 / 60.0)
	_t.check("F. play() after a stamped take shows the run-start word and no glyph", take._word.visible and take._word.text == LaunchTake.WORD and not take._glyph.visible and take._word.get_theme_color("font_color") == Palette_charcoal(),
		"word %s visible %s glyph %s" % [take._word.text, take._word.visible, take._glyph.visible])
	while take.phase != LaunchTake.IDLE and guard < 2000:
		take.advance(1.0 / 60.0)
		guard += 1
	_stamp_at_cover(take, "impact_driver")
	_t.check("F. a take that ends leaves the word dressed as the run-start word", take._word.text == LaunchTake.WORD and not take._glyph.visible, "word %s" % take._word.text)
	take.queue_free()
	await process_frame


func Palette_charcoal() -> Color:
	return preload("res://src/core/palette.gd").CHARCOAL


func _stamp_at_cover(take, part: String) -> Dictionary:
	var started: bool = take.play_over_flight(func(): pass, func(): return true, Callable(), 1.0, part)
	var guard := 0
	while take.phase != LaunchTake.HOLD and guard < 600:
		take.advance(1.0 / 60.0)
		guard += 1
	take.advance(1.0 / 60.0)
	var out := {"started": started, "visible": take._word.visible, "text": take._word.text, "glyph": take._glyph.visible,
		"color": take._word.get_theme_color("font_color"), "icon": take._glyph.texture}
	while take.phase != LaunchTake.IDLE and guard < 2000:
		take.advance(1.0 / 60.0)
		guard += 1
	return out


func _boot(scrapless := false) -> Node:
	var game = Game.new()
	game.test_mode = true
	root.add_child(game)
	while game.flow == null:
		await process_frame
	game.ctx.calm = true
	game.player.source = Intent.Scripted.new()
	if scrapless:
		game.build.set_modifiers({"scrapless": true})
	game.flow.press_start()
	game.flow.choose_class(0)
	for _i in 10:
		await process_frame
	return game


func _game_part() -> void:
	var game = await _boot()
	game.events.flow_changed.emit("gates")
	for _i in 8:
		await process_frame
	var gates = game.ctx.build.gates
	var view := Vector2(root.get_visible_rect().size)
	var workshop = game.get_node("Workshop")
	var bubble = workshop.bubble
	var base_y := view.y * Workshop.BUBBLE_Y

	# G. The workshop's order: the line is said, then the bubble is placed. Its seat is the 30 percent line.
	bubble._say("Pump crew: mind the gates", "moss_beat", "bark", 0.0, false, "")
	workshop._place_bubble()
	await process_frame
	_t.check("G. said first and placed second, as the workshop does: the bubble sits at the 30 percent line", is_equal_approx(bubble.position.y, base_y), "y %.1f, seat %.1f" % [bubble.position.y, base_y])
	await process_frame
	_t.check("G. and it stays there", is_equal_approx(bubble.position.y, base_y), "y %.1f" % bubble.position.y)
	# A rect planted in its seat: it eases down below it, clear of it, and comes back up when the rect goes.
	var fake := FakeKeepClear.new()
	fake.rect = Rect2(0.0, base_y, 500.0, 80.0)
	fake.add_to_group("word_keep_clear")
	root.add_child(fake)
	await process_frame
	var eased: float = bubble.position.y
	for _i in 40:
		await process_frame
	var pushed := Rect2(bubble.position, bubble.size)
	_t.check("G. a rect in its seat eases it down, not in one jump", eased > base_y and eased < fake.rect.end.y, "first frame y %.1f between %.1f and %.1f" % [eased, base_y, fake.rect.end.y])
	_t.check("G. it ends below the rect and clear of it", pushed.position.y >= fake.rect.end.y and not pushed.intersects(fake.rect), "bubble %s rect %s" % [pushed, fake.rect])
	fake.queue_free()
	for _i in 40:
		await process_frame
	_t.check("G. it comes back to its seat when the rect goes", is_equal_approx(bubble.position.y, base_y), "y %.1f seat %.1f" % [bubble.position.y, base_y])
	# Gates open: the bubble is clear of the shown names.
	var names: Array[Rect2] = gates.keep_clear_rects()
	var box := Rect2(bubble.position, bubble.size)
	_t.check("G. the real gates are open and show names", gates.is_open() and not names.is_empty(), "%d names" % names.size())
	_t.check("G. the bubble is clear of the shown names while gates are open", not names.any(func(r): return r.intersects(box)), "bubble %s names %s" % [box, names])
	# A rect so low the bubble cannot clear it before the prompts band: it moved, then stopped at the band.
	var low := FakeKeepClear.new()
	low.rect = Rect2(0.0, base_y, 500.0, view.y)
	low.add_to_group("word_keep_clear")
	root.add_child(low)
	for _i in 60:
		await process_frame
	var band_top := ScreenRegions.rect("prompts", view).position.y
	var bottom: float = bubble.position.y + bubble.size.y
	_t.check("G. under a rect that reaches below the band the bubble moved down, then stopped at the prompts band", bubble.position.y > base_y + 1.0 and bottom <= band_top + 0.5, "y %.1f from %.1f, bottom %.1f, band top %.1f" % [bubble.position.y, base_y, bottom, band_top])
	low.queue_free()
	await process_frame

	# G. The hand-over, as the game emits it. Flow and world both hear reward_chosen; whichever is first, the
	# take's stamp is the part's name.
	game.launch_take.force_live = true
	game.flow._set_state(game.flow.GATES)
	game.events.reward_chosen.emit("impact_driver")
	var natural_word: String = game.launch_take._word.text
	_t.check("G. reward_chosen through the game's events: the take is running with the part's name", game.launch_take.busy() and natural_word == "Impact Driver" and not game.launch_take._wordless,
		"busy %s word %s" % [game.launch_take.busy(), natural_word])
	game.free()
	await process_frame
	# World first: the launch happens, then flow hears the choice.
	game = await _boot()
	game.launch_take.force_live = true
	game.flow._set_state(game.flow.GATES)
	game.flow._on_launched(Vector3(0.0, 0.0, -20.0))
	var first_wordless: bool = game.launch_take.busy() and game.launch_take._wordless
	game.flow._on_reward_chosen("impact_driver")
	_t.check("G. the launch first, the choice heard after: the take names the part late", first_wordless and game.launch_take._word.text == "Impact Driver" and not game.launch_take._wordless,
		"wordless at launch %s, word %s wordless %s" % [first_wordless, game.launch_take._word.text, game.launch_take._wordless])
	game.free()
	await process_frame
	# Flow first: the choice is heard, then the launch.
	game = await _boot()
	game.launch_take.force_live = true
	game.flow._set_state(game.flow.GATES)
	game.flow._on_reward_chosen("impact_driver")
	game.flow._on_launched(Vector3(0.0, 0.0, -20.0))
	_t.check("G. the choice heard first, the launch after: the take names the part", game.launch_take.busy() and game.launch_take._word.text == "Impact Driver" and not game.launch_take._wordless,
		"word %s wordless %s" % [game.launch_take._word.text, game.launch_take._wordless])
	game.free()
	await process_frame
	# Scrapless: no part is granted, so the take stays wordless.
	game = await _boot(true)
	game.launch_take.force_live = true
	game.flow._set_state(game.flow.GATES)
	game.events.reward_chosen.emit("impact_driver")
	_t.check("G. a scrapless run's launch take stays wordless (no part was granted)", game.build.scrapless() and game.launch_take.busy() and game.launch_take._wordless,
		"scrapless %s busy %s wordless %s" % [game.build.scrapless(), game.launch_take.busy(), game.launch_take._wordless])
	game.free()
	await process_frame
