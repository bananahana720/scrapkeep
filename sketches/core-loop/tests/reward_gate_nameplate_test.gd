extends SceneTree

# PF-22 (wave 42 film, pictures 054-058 and 085-089): the reward gates' names sat in a detached 2D row far
# below the gates, the row changed from frame to frame, and nothing said which part was taken. A gate now
# wears its name as a plate in the world (reward_gates.gd), the name's drawn size has a floor, the speech bubble
# keeps off the plates, and the launch take stamps the part that was taken.
#
#   1  each of three gates carries a name label equal to its part's title, under its crossbar, facing the ball
#   2  four gates on a raised row 60 to 100 m ahead, camera panned over 120 frames at 1280x720: every gate in
#      view has its name, centred on its own gate, at least 14 px tall unless the overlap rule shrank or hid it
#   3  the overlap rule: the nearer gate keeps its name, the farther one shrinks or hides; no gate moves
#   4  keep_clear_rects(): one rect per plate in front of the camera, none for one behind it
#   5  the bubble's rect is clear of those rects while gates are open
#   6  the launch take stamps the taken part's name at full cover; with no part it stays wordless

const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const RewardGates := preload("res://src/build/reward_gates.gd")
const LaunchTake := preload("res://src/presentation/launch_take.gd")

const VIEW := Vector2i(1280, 720)
const FRAMES := 120

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
	root.size = VIEW
	root.content_scale_size = VIEW
	_run.call_deferred()


func _run() -> void:
	await _gates_part()
	await _take_part()
	await _bubble_part()
	quit(_t.verdict())


func _focal() -> float:
	return float(VIEW.y) * 0.5 / tan(deg_to_rad(_cam.fov) * 0.5)


func _depth(at: Vector3) -> float:
	return (at - _cam.global_position).dot(-_cam.global_basis.z)


func _cap_px(plate: Node3D) -> float:
	return float(plate.get_meta("name_cap_m")) * plate.scale.x * _focal() / _depth(plate.global_position)


func _name_of(gate: Node3D) -> Label3D:
	return gate.find_child("Nameplate", true, false) as Label3D


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

	# 1. Each opened gate has its part's name under its crossbar, facing the ball.
	var ids := ["impact_driver", "brace_frame", "chain_arc"]
	gates.open(ids, Vector3.ZERO, Vector3.FORWARD)
	var named := 0
	var worst_reach := 0.0
	var facing_ok := true
	var text_ok := true
	var flat_ok := true
	for i in gates._gates.size():
		var gate: Node3D = gates._gates[i]
		var label := _name_of(gate)
		if label == null:
			continue
		named += 1
		text_ok = text_ok and label.text == RewardGates.prompt_parts(gates.offers[i]).title
		worst_reach = maxf(worst_reach, label.global_position.distance_to(gate.global_position + Vector3.UP * RewardGates.HEIGHT))
		flat_ok = flat_ok and label.billboard == BaseMaterial3D.BILLBOARD_DISABLED
		facing_ok = facing_ok and label.global_basis.z.dot((_cam.global_position - label.global_position).normalized()) > 0.5
	_t.check("1. each of 3 opened gates has a name label", named == 3 and gates.offers.size() == 3, "%d named of %d" % [named, gates.offers.size()])
	_t.check("1. each label's text equals prompt_parts(offer).title", text_ok and named == 3)
	_t.check("1. each label stands within 1.5 m of its crossbar", named == 3 and worst_reach <= 1.5, "farthest %.2f m" % worst_reach)
	_t.check("1. each label is a flat plate that faces the ball", named == 3 and flat_ok and facing_ok)
	_t.check("1. no gate wears a 2D sign", gates.find_children("*", "WorldPrompt", true, false).is_empty())

	# 4. One rect per plate in front of the camera, none for a plate behind it.
	await process_frame
	var ahead := gates.keep_clear_rects()
	_t.check("4. keep_clear_rects returns one rect per plate in front", ahead.size() == 3, "%d rects" % ahead.size())
	_t.check("4. the gates join the group word_keep_clear", gates.is_in_group("word_keep_clear"))
	var screen := Rect2(Vector2.ZERO, Vector2(VIEW))
	_t.check("4. the rects lie on the screen, around the gates", ahead.all(func(r): return screen.intersects(r)), str(ahead))
	var behind := gates._gates[1] as Node3D
	behind.global_position = Vector3(0.0, 0.0, 40.0)
	await process_frame
	_t.check("4. a plate behind the camera has no rect", gates.keep_clear_rects().size() == 2, "%d rects" % gates.keep_clear_rects().size())
	_cam.rotation.y = PI
	await process_frame
	_t.check("4. looking away leaves one rect, for the gate now in front", gates.keep_clear_rects().size() == 1, "%d rects" % gates.keep_clear_rects().size())
	_cam.rotation.y = 0.0

	# 2. Four gates on a raised row 60 to 100 m ahead, panned across.
	gates.open(["impact_driver", "brace_frame", "chain_arc", "rime_rounds"], Vector3.ZERO, Vector3.FORWARD)
	var xs := [-30.0, -10.0, 10.0, 30.0]
	var zs := [-100.0, -80.0, -70.0, -60.0]
	for i in 4:
		(gates._gates[i] as Node3D).global_position = Vector3(xs[i], 10.0, zs[i])
		gates.offers[i]["at"] = (gates._gates[i] as Node3D).global_position
	gates.step(Vector3.ZERO, Vector3.FORWARD)
	var frames := 0
	var smallest := INF
	var seen := {"floor": 0, "shrunk": 0, "hidden": 0, "centred": 0, "pairs": 0}
	var bad: Array = []
	for f in FRAMES:
		_cam.rotation.y = deg_to_rad(lerpf(30.0, -30.0, float(f) / (FRAMES - 1)))
		await process_frame
		frames += 1
		for i in 4:
			var gate: Node3D = gates._gates[i]
			var plate := gate.get_node("Plate") as Node3D
			var crossbar := gate.global_position + Vector3.UP * RewardGates.HEIGHT
			if _cam.is_position_behind(crossbar) or not screen.has_point(_cam.unproject_position(crossbar)):
				continue
			seen["pairs"] += 1
			var overlaps := _overlaps_another(gates, i)
			if not plate.is_visible_in_tree():
				seen["hidden"] += 1
				if not overlaps:
					bad.append("frame %d gate %d hidden with nothing to overlap" % [f, i])
				continue
			var cap := _cap_px(plate)
			smallest = minf(smallest, cap)
			var left := _cam.unproject_position(gate.global_position + gate.global_basis.x * -RewardGates.WIDTH * 0.5 + Vector3.UP * RewardGates.HEIGHT).x
			var right := _cam.unproject_position(gate.global_position + gate.global_basis.x * RewardGates.WIDTH * 0.5 + Vector3.UP * RewardGates.HEIGHT).x
			var centre := _cam.unproject_position(_name_of(gate).global_position).x
			if centre >= minf(left, right) and centre <= maxf(left, right):
				seen["centred"] += 1
			else:
				bad.append("frame %d gate %d name centre %.0f outside its gate %.0f..%.0f" % [f, i, centre, left, right])
			if cap >= RewardGates.NAME_FLOOR_PX - 0.5:
				seen["floor"] += 1
			else:
				seen["shrunk"] += 1
				if not overlaps or cap < RewardGates.NAME_MIN_PX - 0.5:
					bad.append("frame %d gate %d cap %.1f px without an overlap or under the minimum" % [f, i, cap])
	_t.check("2. the pan ran %d frames and looked at gates" % frames, frames == FRAMES and seen["pairs"] > 0, "%d frames, %d gate-frames in view" % [frames, seen["pairs"]])
	_t.check("2. every gate in view has its name, centred on its gate, at the floor unless overlap shrank or hid it", bad.is_empty() and seen["floor"] > 0,
		"%d at the floor or taller, %d shrunk, %d hidden, %d centred; smallest cap %.1f px; first problems %s" % [seen["floor"], seen["shrunk"], seen["hidden"], seen["centred"], smallest, bad.slice(0, 3)])
	print("reward_gate_nameplate_test: pan frames %d, smallest cap height %.1f px" % [frames, smallest])

	# 3. The overlap rule, as a pure function and on live gates.
	_cam.rotation.y = 0.0
	var pair := RewardGates.fit_names([
		{"dist": 90.0, "centre": Vector2(660.0, 300.0), "natural": 5.0, "aspect": 9.0},
		{"dist": 50.0, "centre": Vector2(640.0, 300.0), "natural": 9.0, "aspect": 9.0},
	])
	_t.check("3. pure: the nearer name keeps the floor", is_equal_approx(pair[1]["cap"], RewardGates.NAME_FLOOR_PX) and not pair[1]["hidden"], str(pair))
	_t.check("3. pure: the farther name is smaller or hidden", pair[0]["hidden"] or pair[0]["cap"] < pair[1]["cap"], str(pair))
	var apart := RewardGates.fit_names([
		{"dist": 90.0, "centre": Vector2(100.0, 300.0), "natural": 5.0, "aspect": 9.0},
		{"dist": 50.0, "centre": Vector2(640.0, 300.0), "natural": 9.0, "aspect": 9.0},
	])
	_t.check("3. pure: names that do not overlap both take the floor", apart.all(func(r): return is_equal_approx(r["cap"], RewardGates.NAME_FLOOR_PX) and not r["hidden"]), str(apart))
	var big := RewardGates.fit_names([{"dist": 5.0, "centre": Vector2(640.0, 300.0), "natural": 60.0, "aspect": 9.0}])
	_t.check("3. pure: a close name keeps its own larger size", is_equal_approx(big[0]["cap"], 60.0) and not big[0]["hidden"], str(big))
	gates.open(["impact_driver", "brace_frame"], Vector3.ZERO, Vector3.FORWARD)
	var near_gate := gates._gates[0] as Node3D
	var far_gate := gates._gates[1] as Node3D
	near_gate.global_position = Vector3(0.0, 0.0, -90.0)
	far_gate.global_position = Vector3(5.0, 0.0, -100.0)
	for i in 2:
		gates.offers[i]["at"] = (gates._gates[i] as Node3D).global_position
	gates.step(Vector3.ZERO, Vector3.FORWARD)
	var before := [near_gate.global_position, far_gate.global_position, _name_of(near_gate).global_position, _name_of(far_gate).global_position]
	await process_frame
	await process_frame
	var near_plate := near_gate.get_node("Plate") as Node3D
	var far_plate := far_gate.get_node("Plate") as Node3D
	var near_cap := _cap_px(near_plate) if near_plate.visible else 0.0
	var far_cap := _cap_px(far_plate) if far_plate.visible else 0.0
	_t.check("3. live: the nearer gate has the full name at the floor", near_plate.visible and near_cap >= RewardGates.NAME_FLOOR_PX - 0.5, "%.1f px" % near_cap)
	_t.check("3. live: the farther gate's name is smaller or hidden", not far_plate.visible or far_cap < near_cap - 0.5, "visible %s, %.1f px against %.1f px" % [far_plate.visible, far_cap, near_cap])
	var after := [near_gate.global_position, far_gate.global_position, _name_of(near_gate).global_position, _name_of(far_gate).global_position]
	_t.check("3. live: neither gate nor its plate moved off its gate", before[0] == after[0] and before[1] == after[1] and absf((after[2] as Vector3).x - (after[0] as Vector3).x) < 0.01 and
		absf(((after[3] as Vector3) - (after[1] as Vector3)).x) < 0.01, "%s -> %s" % [before, after])
	gates.close()
	holder.queue_free()
	await process_frame


# Whether gate i's name, at the floor size, would overlap another gate's (shown or not).
func _overlaps_another(gates: Node3D, i: int) -> bool:
	var mine := _floor_rect(gates._gates[i])
	for j in gates._gates.size():
		if j != i and mine.intersects(_floor_rect(gates._gates[j])):
			return true
	return false


func _floor_rect(gate: Node3D) -> Rect2:
	var plate := gate.get_node("Plate") as Node3D
	var label := _name_of(gate)
	var cap := maxf(RewardGates.NAME_FLOOR_PX, float(plate.get_meta("name_cap_m")) * _focal() / maxf(0.1, _depth(plate.global_position)))
	var size := Vector2(cap * float(plate.get_meta("name_w_m")) / float(plate.get_meta("name_cap_m")), cap)
	return Rect2(_cam.unproject_position(label.global_position) - size * 0.5, size).grow(10.0)


func _take_part() -> void:
	var take = LaunchTake.new()
	root.add_child(take)
	await process_frame
	take.live = true
	var name_shown := _stamp_at_cover(take, "impact_driver")
	_t.check("6. impact_driver shows Impact Driver at full cover", name_shown["visible"] and name_shown["text"] == "Impact Driver" and name_shown["glyph"], str(name_shown))
	var tint: Color = name_shown["color"]
	_t.check("6. the name wears the part's rarity colour", tint == RewardGates.rarity_color("common") or tint != Color.WHITE, str(tint))
	var wordless := _stamp_at_cover(take, "")
	_t.check("6. an empty part stays wordless", not wordless["visible"] and not wordless["glyph"], str(wordless))
	var unknown := _stamp_at_cover(take, "no_such_part")
	_t.check("6. an id that names no part stays wordless", not unknown["visible"], str(unknown))
	var again := _stamp_at_cover(take, "impact_driver")
	_t.check("6. a take after a wordless one stamps again", again["visible"] and again["text"] == "Impact Driver", str(again))
	take.queue_free()
	await process_frame


func _stamp_at_cover(take, part: String) -> Dictionary:
	var started: bool = take.play_over_flight(func(): pass, func(): return true, Callable(), 1.0, part)
	var guard := 0
	while take.phase != LaunchTake.HOLD and guard < 600:
		take.advance(1.0 / 60.0)
		guard += 1
	take.advance(1.0 / 60.0)
	var out := {"started": started, "visible": take._word.visible, "text": take._word.text, "glyph": take._glyph.visible,
		"color": take._word.get_theme_color("font_color"), "frames": guard}
	while take.phase != LaunchTake.IDLE and guard < 2000:
		take.advance(1.0 / 60.0)
		guard += 1
	return out


func _bubble_part() -> void:
	var game = Game.new()
	game.test_mode = true
	root.add_child(game)
	while game.flow == null:
		await process_frame
	game.ctx.calm = true
	game.player.source = Intent.Scripted.new()
	game.flow.press_start()
	game.flow.choose_class(0)
	for _i in 10:
		await process_frame
	game.events.flow_changed.emit("gates")
	for _i in 8:
		await process_frame
	var gates = game.ctx.build.gates
	var view := Vector2(root.get_visible_rect().size)
	var bubble = game.get_node("Workshop").bubble
	var base_y := view.y * 0.30
	bubble.position = Vector2(0.0, base_y)
	bubble._say("Pump crew: mind the gates", "moss_beat", "intro", 0.0, false, "")
	for _i in 3:
		await process_frame
	var box := Rect2(bubble.position, bubble.size)
	# Positive control: a rect planted where the bubble would sit pushes it down, and it comes back when the rect goes.
	var fake := FakeKeepClear.new()
	fake.rect = Rect2(0.0, base_y, 500.0, 80.0)
	fake.add_to_group("word_keep_clear")
	root.add_child(fake)
	await process_frame
	await process_frame
	var pushed := Rect2(bubble.position, bubble.size)
	_t.check("5. a rect planted in the bubble's seat moves it down, clear of the rect", pushed.position.y >= fake.rect.end.y and not pushed.intersects(fake.rect) and pushed.position.y > box.position.y,
		"base %.0f, bubble now %s, rect %s" % [base_y, pushed, fake.rect])
	fake.queue_free()
	await process_frame
	await process_frame
	_t.check("5. the bubble comes back up when the rect goes", is_equal_approx(bubble.position.y, base_y), "y %.1f, base %.1f" % [bubble.position.y, base_y])
	var rects: Array[Rect2] = gates.keep_clear_rects()
	var bubble_rect := Rect2(bubble.position, bubble.size)
	_t.check("5. the real gates are open and have plate rects", gates.is_open() and not rects.is_empty(), "%d rects" % rects.size())
	_t.check("5. the bubble's rect is clear of the plates' rects while gates are open", not rects.any(func(r): return r.intersects(bubble_rect)), "bubble %s, plates %s" % [bubble_rect, rects])
	# A plate planted so low the bubble cannot clear it before the prompts band stops at the band, never above its base.
	var low := FakeKeepClear.new()
	low.rect = Rect2(0.0, base_y, 500.0, view.y)
	low.add_to_group("word_keep_clear")
	root.add_child(low)
	await process_frame
	await process_frame
	var prompts_top := view.y * 0.62
	_t.check("5. the bubble stops above the prompts band when the plates reach below it", Rect2(bubble.position, bubble.size).end.y <= prompts_top + 0.5 or bubble.position.y <= base_y + 0.5,
		"bubble bottom %.0f, band top %.0f, y %.0f, base %.0f" % [bubble.position.y + bubble.size.y, prompts_top, bubble.position.y, base_y])
	low.queue_free()

	# 6. Through the game's own entry: the flow hands the taken part to the take.
	game.launch_take.force_live = true
	var played: bool = game.play_launch_take(func(): pass, func(): return true, Callable(), 1.0, "impact_driver")
	_t.check("6. game.play_launch_take passes the part to the take", played and game.launch_take._word.text == "Impact Driver" and not game.launch_take._wordless,
		"played %s, word %s" % [played, game.launch_take._word.text])
	game.queue_free()
	await process_frame
