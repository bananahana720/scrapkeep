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
const TYPICAL_FROM := {3: 75.0, 4: 75.0}
const LONGEST_FROM := {3: 45.0, 4: 45.0}

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


# A pair 140 px apart (room 128): the one-row width is 124 and the two-row width 80. `was_rows` says what it was last frame.
func _two_rows_entry(was_rows: int, w1: float) -> Array:
	var a := _entry(0, 400.0, 50.0, w1)
	a["was_rows"] = was_rows
	return RewardGates.fit_names([a, _entry(1, 540.0, 80.0, w1)])


# The room between the top band's end (band_end) and the bottom HUD band, across the whole view.
func _room(view: Vector2, band_end: float) -> Rect2:
	return Rect2(0.0, band_end, view.x, ScreenRegions.rect("bottom", view).position.y - band_end)


# B. The rule, with numbers.
func _fit_part() -> void:
	var lone := RewardGates.fit_names([_entry(0, 400.0, 50.0, 140.0, false, 80.0, 200.0)])
	_t.check("B. a lone gate shows its name on one row with its effect lines", lone[0]["shown"] and lone[0]["rows"] == 1 and lone[0]["detail"], str(lone))
	_t.check("B. the name is centred on its gate's column and hangs under it", is_equal_approx((lone[0]["rect"] as Rect2).get_center().x, 400.0) and is_equal_approx((lone[0]["rect"] as Rect2).position.y, 300.0 + RewardGates.NAME_DROP), str(lone[0]["rect"]))
	for x in [8.0, 1272.0]:
		var edge := RewardGates.fit_names([_entry(0, x, 25.0, 140.0, false, 80.0, 248.0)], _room(Vector2(1280, 720), 90.0))[0] as Dictionary
		var rect: Rect2 = edge["rect"]
		_t.check("the complete edge offer opens inward from its own arch at x=%s" % x,
			edge["shown"] and edge["detail"] and rect.position.x <= x and x <= rect.end.x
			and Rect2(0, 0, 1280, 720).encloses(rect), str(edge))
	# Two gates 100 px apart: room is 88, the one-row name (140) does not fit, two rows (80) do, so both show.
	# A crossbar can be inside the screen while its sign falls over the speed and armour readouts.
	var lower_edge := _entry(0, 24.0, 25.0, 140.0, false, 80.0, 248.0)
	lower_edge.col.y = 700.0
	var viewport_size := Vector2(1280, 720)
	var docked: Dictionary = RewardGates.fit_names([lower_edge], _room(viewport_size, 90.0))[0]
	var bottom_hud := ScreenRegions.rect("bottom", viewport_size)
	_t.check("a low edge offer stays on its arch column and clears the bottom HUD", docked.detail
		and docked.rect.end.y <= bottom_hud.position.y and docked.rect.position.x <= 24.0
		and docked.rect.end.x >= 24.0, str(docked))

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
	var stays := RewardGates.fit_names([_entry(0, 400.0, 50.0, 140.0, true), _entry(1, 480.0, 80.0, 140.0, true)])
	_t.check("B. a shown name stays while the two do not overlap at all", stays[1]["shown"], str(stays))
	var goes := RewardGates.fit_names([_entry(0, 400.0, 50.0, 140.0, true), _entry(1, 470.0, 80.0, 140.0, true)])
	_t.check("B. a shown name hides as soon as it overlaps another shown name (10 px)", not goes[1]["shown"], str(goes))
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
	# Rows: back to one row only with 16 px to spare. Room 128 (140 apart less 12): the one-row name is 120 wide.
	var rows_one := RewardGates.fit_names([_entry(0, 400.0, 50.0, 120.0), _entry(1, 540.0, 80.0, 120.0)])
	_t.check("B. a name that fits its room takes one row", rows_one[0]["rows"] == 1, str(rows_one))
	var rows_kept := _two_rows_entry(2, 120.0)
	_t.check("B. a name on two rows stays on two while it has less than 16 px to spare", rows_kept[0]["rows"] == 2, str(rows_kept))
	var rows_back := _two_rows_entry(2, 100.0)
	_t.check("B. and goes back to one row with 16 px to spare", rows_back[0]["rows"] == 1, str(rows_back))
	var rows_new := _two_rows_entry(1, 120.0)
	_t.check("B. a name that was on one row stays on one row at the same room", rows_new[0]["rows"] == 1, str(rows_new))
	# The top band: the name drops straight down its own column to the band's lower edge, and returns below it.
	var high := Dictionary(_entry(0, 400.0, 50.0))
	high["col"] = Vector2(400.0, 95.0)
	var dropped := RewardGates.fit_names([high], Rect2(0.0, 126.0, INF, INF))
	_t.check("B. a crossbar point in the top band drops the name to the band's lower edge, same column", is_equal_approx((dropped[0]["rect"] as Rect2).position.y, 126.0) and is_equal_approx((dropped[0]["rect"] as Rect2).get_center().x, 400.0), str(dropped[0]["rect"]))
	var low := Dictionary(_entry(0, 400.0, 50.0))
	low["col"] = Vector2(400.0, 300.0)
	var kept := RewardGates.fit_names([low], Rect2(0.0, 126.0, INF, INF))
	_t.check("B. below the band the name hangs at the crossbar point", is_equal_approx((kept[0]["rect"] as Rect2).position.y, 300.0 + RewardGates.NAME_DROP), str(kept[0]["rect"]))
	# The flip above the crossbar: a name that would run off the room's bottom hangs above, and one pixel either
	# side of the boundary does not flip it back and forth.
	var space := Rect2(0.0, 126.0, 1280.0, 400.0)
	var edge_y := space.end.y - RewardGates.NAME_DROP - 30.0
	var hang := Dictionary(_entry(0, 400.0, 50.0))
	var hung := []
	for dy in [-1.0, 0.0, 1.0, 0.0, -1.0, 0.0]:
		hang["col"] = Vector2(400.0, edge_y + dy)
		var got: Dictionary = RewardGates.fit_names([hang], space)[0]
		hang["was_above"] = got["above"]
		hung.append(got["above"])
	_t.eq("B. a name at the flip boundary flips above once and a one pixel change does not flip it back", hung, [false, false, true, true, true, true])
	hang["col"] = Vector2(400.0, edge_y - RewardGates.NAME_HOLD - 1.0)
	_t.check("B. it comes back below with NAME_HOLD px to spare", not RewardGates.fit_names([hang], space)[0]["above"])


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
	var cap := _font_cap_px(WorldPrompt.SIGN_NAME_SIZE) * WINDOW_SCALE
	print("reward_gate_nameplate_test: measured cap height of the name font at size %d: %.2f canvas px, %.2f px on a 1280x720 window" % [WorldPrompt.SIGN_NAME_SIZE, cap / WINDOW_SCALE, cap])
	_t.check("A. the name font's measured cap height is at least 14 px on a 1280x720 window", cap >= 14.0, "%.2f px" % cap)
	# In the top HUD band the name drops straight down its own gate's column to the band's lower edge.
	_stand(gates, [-9.0, 0.0, 9.0], 24.0, -38.0)
	await process_frame
	var top_ok := true
	var band_end := ScreenRegions.rect("top", view).end.y
	var notes := []
	for gate in gates._gates:
		var prompt := _name_of(gate)
		var col := _cam.unproject_position(gate.global_position + Vector3.UP * RewardGates.HEIGHT)
		top_ok = top_ok and prompt.visible and prompt.position.y >= band_end - 0.01 and absf(prompt.position.y - band_end) < 0.6 and absf(Rect2(prompt.position, prompt.size).get_center().x - col.x) < 0.6 and col.y < band_end
		notes.append("col %.0f,%.0f name top %.0f" % [col.x, col.y, prompt.position.y])
	_t.check("A. a crossbar point in the top HUD band: the name's top is at the band's lower edge and its centre x is its gate's column", top_ok, "%s, band ends %.0f" % [notes, band_end])
	_stand(gates, [-9.0, 0.0, 9.0], 0.0, -38.0)
	await process_frame
	var back_ok := true
	for gate in gates._gates:
		var col := _cam.unproject_position(gate.global_position + Vector3.UP * RewardGates.HEIGHT)
		back_ok = back_ok and absf(_name_of(gate).position.y - (col.y + RewardGates.NAME_DROP)) < 0.6 and col.y > band_end
	_t.check("A. and returns to the crossbar point once that is below the band", back_ok)

	# E. keep_clear_rects.
	await process_frame
	var rects := gates.keep_clear_rects()
	var same := rects.size() == 3 and gates._gates.all(func(g): return rects.has(Rect2(_name_of(g).position, _name_of(g).size)))
	_t.check("E. keep_clear_rects returns each shown name's rect", same, "%d rects" % rects.size())
	_t.check("E. the gates join the groups word_keep_clear and speech_keep_clear", gates.is_in_group("word_keep_clear") and gates.is_in_group("speech_keep_clear"))
	var behind := gates._gates[1] as Node3D
	behind.global_position = Vector3(0.0, 0.0, 40.0)
	await process_frame
	_t.check("E. a gate behind the camera has no rect and no name", gates.keep_clear_rects().size() == 2 and not _name_of(behind).visible, "%d rects" % gates.keep_clear_rects().size())
	_cam.rotation.y = PI
	await process_frame
	_t.check("E. looking away leaves the one gate now in front", gates.keep_clear_rects().size() == 1, "%d rects" % gates.keep_clear_rects().size())
	_cam.rotation.y = 0.0
	gates.close()

	# C. Stability on a layout where names do hide: the dam row's 16 m spacing at 100 m with the longest names. The ball
	# crosses the row's centre line once while the camera sways a pixel.
	var long4 := _longest_parts(4)
	gates.open(long4, Vector3.ZERO, Vector3.FORWARD)
	_stand(gates, [-24.0, -8.0, 8.0, 24.0], 0.0, -100.0)
	var sway := 1.0 / _focal()
	var last := []
	var changes := 0
	var sets := []
	var change_frames := []
	for f in FRAMES:
		var ball := Vector3(lerpf(-3.0, 3.0, float(f) / (FRAMES - 1)), 0.0, 0.0)
		_cam.position = Vector3(ball.x, 8.0, 0.0)
		_cam.rotation.y = sway if f % 2 == 0 else -sway
		gates._ball = ball
		await process_frame
		var now := _named(gates)
		if f > 0 and now != last:
			changes += 1
			change_frames.append(f)
		if not sets.has(now):
			sets.append(now)
		last = now
	print("reward_gate_nameplate_test: stability, %d frames, named set changed %d times at frames %s, sets in order %s" % [FRAMES, changes, change_frames, sets])
	_t.check("C. names do hide on this layout (the test is not vacuous)", sets.all(func(s): return s.size() < 4), str(sets))
	_t.check("C. one crossing of the centre line with a pixel of sway changes the named set at most once over %d frames" % FRAMES, changes <= 1 and not sets.is_empty(), "%d changes at %s, sets %s" % [changes, change_frames, sets])
	_t.check("C. at least one gate is named throughout", sets.all(func(s): return not s.is_empty()), str(sets))
	gates.close()

	# C. Holding a distance where a name's return threshold sits: the ball comes in until the named set first
	# changes, then holds there with the camera dollying a fraction of a pixel's worth back and forth.
	gates.open(long4, Vector3.ZERO, Vector3.FORWARD)
	_stand(gates, [-24.0, -8.0, 8.0, 24.0], 0.0, -100.0)
	_cam.rotation.y = 0.0
	var first := _named_at(gates, 120.0)
	await process_frame
	var found := 0.0
	var d := 120.0
	while d > 30.0 and found == 0.0:
		d -= 0.25
		_cam.position = Vector3(0.0, 8.0, -100.0 + d)
		gates._ball = _cam.position
		await process_frame
		var now_set := _named(gates)
		if now_set != first and d < 119.0:
			found = d
		first = now_set
	var held_changes := 0
	var held_sets := []
	var before := _named(gates)
	for f in FRAMES:
		_cam.position = Vector3(0.0, 8.0, -100.0 + found + (0.2 if f % 2 == 0 else -0.2))
		gates._ball = _cam.position
		await process_frame
		var held_now := _named(gates)
		if held_now != before:
			held_changes += 1
		if not held_sets.has(held_now):
			held_sets.append(held_now)
		before = held_now
	print("reward_gate_nameplate_test: threshold hold at %.2f m, %d frames, named set changed %d times, sets %s" % [found, FRAMES, held_changes, held_sets])
	_t.check("C. holding a distance at a name's threshold with the camera moving about a pixel, the named set changes at most once", found > 0.0 and held_changes <= 1, "threshold at %.2f m, %d changes, sets %s" % [found, held_changes, held_sets])
	gates.close()

	# C. A pause keeps the names: walk out from close until the next step would hide a name, so the last shown name has
	# only a few px clear, then pause and unpause. The same set shows on the first frame back.
	gates.open(long4, Vector3.ZERO, Vector3.FORWARD)
	_stand(gates, [-24.0, -8.0, 8.0, 24.0], 0.0, -100.0)
	_cam.rotation.y = 0.0
	_cam.position = Vector3(0.0, 8.0, -100.0 + 30.0)
	gates._ball = _cam.position
	await process_frame
	var out_set := _named(gates)
	var edge := out_set
	var edge_d := 30.0
	var out_d := 30.0
	while out_d < 118.0:
		out_d += 0.25
		_cam.position = Vector3(0.0, 8.0, -100.0 + out_d)
		gates._ball = _cam.position
		await process_frame
		var out_now := _named(gates)
		if out_now.size() < out_set.size():
			break
		edge = out_now
		edge_d = out_d
		out_set = out_now
	_cam.position = Vector3(0.0, 8.0, -100.0 + edge_d)
	gates._ball = _cam.position
	await process_frame
	var before_pause := _named(gates)
	paused = true
	await process_frame
	var while_paused := _named(gates)
	paused = false
	await process_frame
	var after_pause := _named(gates)
	_t.check("C. a pause hides every name and the unpause brings the same set back on the first frame, with a name shown on a few px clear", before_pause.size() > 0 and before_pause.size() < 4 and while_paused.is_empty() and after_pause == before_pause, "at %.2f m before %s, paused %s, after %s" % [edge_d, before_pause, while_paused, after_pause])
	gates.close()

	# D. Approach on the dam row's spacing (16 m), three and four gates: typical names, then the longest there are.
	var typical := ["impact_driver", "brace_frame", "chain_arc", "rime_rounds"]
	for count in [3, 4]:
		var got := await _approach(gates, typical, count)
		_t.check("D. %d gates 16 m apart, typical names: every gate is named from 60 m in" % count, got["frames"] == 101 and got["from"] >= 60.0 - 0.001 and got["from"] != INF and absf(got["from"] - TYPICAL_FROM[count]) <= 2.0, "all named from %s m (observed %s m, tolerance 2) over %d frames" % [got["from"], TYPICAL_FROM[count], got["frames"]])
	var longest := _longest_parts(4)
	for count in [3, 4]:
		var got := await _approach(gates, longest, count)
		_t.check("D. %d gates 16 m apart, the longest names: every gate is named from about %d m in" % [count, LONGEST_FROM[count]], got["frames"] == 101 and got["from"] != INF and absf(got["from"] - LONGEST_FROM[count]) <= 2.0, "all named from %s m (observed %s m, tolerance 2) over %d frames" % [got["from"], LONGEST_FROM[count], got["frames"]])
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


# The font's own cap height in canvas px at a size: the height of the glyph H's outline.
func _font_cap_px(size: int) -> float:
	var font: Font = preload("res://src/core/ui_fonts.gd").bold()
	var ts := TextServerManager.get_primary_interface()
	var rid: RID = font.get_rids()[0]
	var contours := ts.font_get_glyph_contours(rid, size, ts.font_get_glyph_index(rid, size, ord("H"), 0))
	var lo := INF
	var hi := -INF
	for point in contours.get("points", PackedVector3Array()):
		lo = minf(lo, point.y)
		hi = maxf(hi, point.y)
	return hi - lo


func _named_at(gates: Node3D, d: float) -> Array:
	_cam.position = Vector3(0.0, 8.0, -100.0 + d)
	gates._ball = _cam.position
	return _named(gates)


# The ids a gate can offer, longest on two rows first (the width of the longer row at the name size). A gate's
# parts come from Parts.roll_gate over offer_pool, which reads every row with no stage filter, plus a hot-wired
# part (build._hotwire_gate_ids); each name is cut to three words by prompt_parts. Parts.roll rolls a generated
# recipe (ItemGen name) 25% of the time only on a table that does not list its parts (Parts.listed_only); the alpha,
# park and slice tables all list theirs, so no generated name reaches a world 1 gate and none is measured.
func _longest_parts(count: int) -> Array:
	var ids: Array = Parts.ids().duplicate()
	for id in Parts.HOTWIRED:
		if not ids.has(id):
			ids.append(id)
	var rows := []
	for id in ids:
		if Parts.offer_def(id, []) == null:
			continue
		var title: String = RewardGates.prompt_parts({"name": Parts.display_name(id)}).title
		var widest := 0.0
		for row in WorldPrompt.split_name(title):
			widest = maxf(widest, WorldPrompt.row_width(row, WorldPrompt.SIGN_NAME_SIZE))
		rows.append([widest, id])
	rows.sort_custom(func(a, b): return a[0] > b[0] or (a[0] == b[0] and a[1] < b[1]))
	print("reward_gate_nameplate_test: longest name a gate can show: %s (%d px on two rows, %d px on one) of %d parts; the next: %s" % [Parts.display_name(rows[0][1]), int(rows[0][0]), int(WorldPrompt.row_width(Parts.display_name(rows[0][1]), WorldPrompt.SIGN_NAME_SIZE)), rows.size(), rows.slice(1, 4).map(func(r): return Parts.display_name(r[1]))])
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
	take.play_over_flight(func(): pass, func(): return true, Callable(), 1.0, "impact_driver")
	take.stamp_taken("no_such_part")
	var late := 0
	while take.phase != LaunchTake.HOLD and late < 600:
		take.advance(1.0 / 60.0)
		late += 1
	take.advance(1.0 / 60.0)
	_t.check("F. a part's name followed by an id that names no part leaves the take wordless", not take._word.visible and not take._glyph.visible, "word %s visible %s" % [take._word.text, take._word.visible])
	while take.phase != LaunchTake.IDLE and late < 2000:
		take.advance(1.0 / 60.0)
		late += 1
	take.play_over_flight(func(): pass, func(): return true, Callable(), 1.0, "impact_driver")
	take.stamp_taken("")
	_t.check("F. an empty id told late makes a running take wordless", take._wordless and take._word.text == LaunchTake.WORD)
	while take.phase != LaunchTake.IDLE and late < 4000:
		take.advance(1.0 / 60.0)
		late += 1
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
	fake.add_to_group("speech_keep_clear")
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
	# What sound words keep off (the reticle, the ball, target tags) is not the bubble's business: a rect
	# only in the sound words' group leaves the bubble in its seat.
	var other := FakeKeepClear.new()
	other.rect = Rect2(0.0, base_y, 500.0, 80.0)
	other.add_to_group("word_keep_clear")
	root.add_child(other)
	for _i in 40:
		await process_frame
	_t.check("G. a rect only in the sound words' group does not move the bubble", is_equal_approx(bubble.position.y, base_y), "y %.1f seat %.1f" % [bubble.position.y, base_y])
	other.queue_free()
	await process_frame
	# Gates open: the bubble is clear of the shown names.
	var names: Array[Rect2] = gates.keep_clear_rects()
	var box := Rect2(bubble.position, bubble.size)
	_t.check("G. the real gates are open and show names", gates.is_open() and not names.is_empty(), "%d names" % names.size())
	_t.check("G. the bubble is clear of the shown names while gates are open", not names.any(func(r): return r.intersects(box)), "bubble %s names %s" % [box, names])
	# A rect so low the bubble cannot clear it before the prompts band: it moved, then stopped at the band.
	var low := FakeKeepClear.new()
	low.rect = Rect2(0.0, base_y, 500.0, view.y)
	low.add_to_group("speech_keep_clear")
	root.add_child(low)
	for _i in 60:
		await process_frame
	var band_top := ScreenRegions.rect("prompts", view).position.y
	var bottom: float = bubble.position.y + bubble.size.y
	_t.check("G. under a rect that reaches below the band the bubble moved down, then stopped at the prompts band", bubble.position.y > base_y + 1.0 and bottom <= band_top + 0.5, "y %.1f from %.1f, bottom %.1f, band top %.1f" % [bubble.position.y, base_y, bottom, band_top])
	low.queue_free()
	await process_frame

	# Names hide when the game is not in play: the run ends under the standing gates, or a menu pauses the game.
	var showing := _named(gates).size()
	game.flow._set_state(game.flow.DEAD)
	for _i in 3:
		await process_frame
	_t.check("G. the ball dies under standing gates: no name shows and no rect is kept", showing > 0 and _named(gates).is_empty() and gates.keep_clear_rects().is_empty(), "%d named before, %d after, %d rects" % [showing, _named(gates).size(), gates.keep_clear_rects().size()])
	game.flow._set_state(game.flow.STAGE)
	for _i in 3:
		await process_frame
	_t.check("G. and the names are back when play resumes", _named(gates).size() == showing, "%d named" % _named(gates).size())
	game.get_tree().paused = true
	for _i in 3:
		await process_frame
	var paused_named := _named(gates).size()
	game.get_tree().paused = false
	_t.check("G. a pause (a menu over the world) hides the names", paused_named == 0, "%d named while paused" % paused_named)

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
	# A retry in the launch flight restores the run without the part: the swipe must not stamp it. The same for a run
	# that ends in the flight, and for a new run begun in the flight (a held R, the pause menu's Restart).
	for how in ["retry", "run end", "new run"]:
		game = await _boot()
		game.launch_take.force_live = true
		game.flow._set_state(game.flow.GATES)
		game.flow._on_reward_chosen("impact_driver")
		game.flow._on_launched(Vector3(0.0, 0.0, -20.0))
		var named_first: bool = game.launch_take.busy() and game.launch_take._word.text == "Impact Driver"
		var had_snapshot: bool = game.ctx.run.has_snapshot()
		if how == "retry":
			game.flow.retry_stage()
		elif how == "run end":
			game.flow._end_run(false)
		else:
			game.flow.new_run()
		_t.check("G. a %s in the launch flight: the take is told no part and stamps the plain word" % how, named_first and (had_snapshot) and game.launch_take.busy() and game.launch_take._wordless and game.launch_take._word.text == LaunchTake.WORD,
			"named first %s, snapshot %s, busy %s, word %s wordless %s" % [named_first, had_snapshot, game.launch_take.busy(), game.launch_take._word.text, game.launch_take._wordless])
		game.free()
		await process_frame
	# A finished run leaves no id behind: the run's last gate launches no take, and the next run, scrapless, starts clean.
	game = await _boot()
	var last_stage := 1
	while not game.ctx.stages.is_run_last(last_stage) and last_stage < 40:
		last_stage += 1
	game.ctx.run.stage = last_stage
	game.launch_take.force_live = true
	game.flow._set_state(game.flow.GATES)
	game.events.reward_chosen.emit("impact_driver")
	game.build.set_modifiers({"scrapless": true})
	game.flow.new_run()
	for _i in 10:
		await process_frame
	game.launch_take.force_live = true
	game.flow._set_state(game.flow.GATES)
	game.flow._on_launched(Vector3(0.0, 0.0, -20.0))
	game.flow._on_reward_chosen("impact_driver")
	_t.check("G. after a run that ended at its last gate, a scrapless run's first take is wordless", game.build.scrapless() and game.launch_take.busy() and game.launch_take._wordless and game.launch_take._word.text == LaunchTake.WORD,
		"last stage %d, scrapless %s, busy %s, word %s wordless %s" % [last_stage, game.build.scrapless(), game.launch_take.busy(), game.launch_take._word.text, game.launch_take._wordless])
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
