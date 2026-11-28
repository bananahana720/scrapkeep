extends SceneTree

const Game := preload("res://src/game.gd")
const Hud := preload("res://src/ui/hud.gd")
const Intent := preload("res://src/movement/intent.gd")
const Objectives := preload("res://src/core/objectives.gd")
const ScreenRegions := preload("res://src/core/screen_regions.gd")
const WordBudget := preload("res://src/core/word_budget.gd")

# The objective board on the slice table (design-v3/LEGIBILITY.md, "A goal exists" and the
# Warden fight). The plate and the edge marker read one row of objectives.gd in each state:
# before the Warden "Find the Warden" with the metres, engaged "Break its guard", after ten
# seconds of weak rams "Get heavy, then return", staggered "Smash the core" and at the gates
# "Roll through a gate". The staggered Warden is driven through combat.strike(), the real
# contact path, so the rule's own state moves. The HUD then carries no heft dial, bars, core
# pips, clock or first-run callout and no part or heft toast; a part name rides the ball for
# 1.2 s of simulated time; a mounted plate sits top-centre with the objective under it; and
# a bar slot hides its keycap exactly while a prompt on the same key shows. Every wait is a
# counted physics frame.

const SliceDefs := preload("res://src/core/slice_defs.gd")
const PLATING: float = SliceDefs.DEFS[0]["warden_plating"]
const SIZES := [Vector2(1600.0, 900.0), Vector2(1280.0, 720.0)]
const PLATE_SIZE := Vector2(420.0, 44.0)
const WEAK_FORCE := 0.05
const WEAK_GAP := 2.8


class Plate:
	extends Control

	func drawn_words() -> PackedStringArray:
		return PackedStringArray(["Rust Warden"])


var _game
var _hud
var _combat
var _warden
var _failures := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "slice"
	root.add_child(_game)
	_run()


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _seconds(seconds: float) -> void:
	await _frames(roundi(seconds * Engine.physics_ticks_per_second))


func _matched_force() -> float:
	var force := 1.0
	while _combat.punch_of("ram", force) < PLATING:
		force += 0.05
	return force


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.flow.force_warden = true
	_game.player.source = Intent.Scripted.new()
	_combat = _game.ctx.spawner
	_game.flow.press_start()
	_game.flow.choose_class(1)
	await _seconds(0.4)
	_game.run.set_max_hp(99999.0)
	_combat.heft_override = 1.0
	_hud = _game.hud
	_warden = _game.flow.warden
	if not is_instance_valid(_warden):
		print("ui_objective_board_test: FAIL (no Warden on the slice table)")
		quit(1)
		return
	for enemy in get_nodes_in_group("enemy"):
		if enemy != _warden and enemy.get("kind") != "vault":
			enemy.queue_free()

	_before_the_warden()
	await _weak_rams()
	await _stagger()
	await _gates()
	_play_view()
	_part_name()
	_plate()
	_bar_keys()
	_game.free()
	print("ui_objective_board_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


func _plate_state() -> Dictionary:
	_hud._process(0.0)
	var targets: Array = _hud.edge_markers.targets()
	return {"words": _hud._objective.words, "icon": _hud._objective.icon_id, "metres": _hud._objective.metres,
		"marker": targets[0]["icon"] if not targets.is_empty() else "", "drawn": _hud._objective.drawn_words()}


func _before_the_warden() -> void:
	# While an activity is left the plate points at it first (activity_signpost_test); the
	# Warden's find row is what shows once every site is finished.
	for site in _game.world.activities.sites:
		site.done = true
	var state := _plate_state()
	var metres := int(_game.player.ball_position().distance_to(_warden.global_position))
	_report("O1-3 find", state["words"] == "Find the Warden" and state["metres"] == metres and metres > 0
			and state["drawn"] == PackedStringArray(["Find the Warden", "%dm" % metres]) and state["marker"] == state["icon"] and state["icon"] != "",
		"the plate reads \"%s\" with %d m (the ball is %d m out), glyph %s, edge marker glyph %s" % [state["words"], state["metres"], metres, state["icon"], state["marker"]])


# Weak rams 2.8 s apart: each gains a little, the bar never drains between them and stays
# under 50 for the ten seconds the struggle needs.
func _weak_rams() -> void:
	_combat.strike(_warden, "ram", WEAK_FORCE)
	await physics_frame
	var first := _plate_state()
	_report("O1-3 engaged", first["words"] == "Break its guard" and first["metres"] == -1 and first["marker"] == first["icon"],
		"after the first strike the plate reads \"%s\" with no distance, glyph %s, edge marker glyph %s" % [first["words"], first["icon"], first["marker"]])
	var guard_icon: String = first["icon"]
	for i in 3:
		await _seconds(WEAK_GAP)
		_combat.strike(_warden, "ram", WEAK_FORCE)
	await _seconds(1.1)
	var early := _plate_state()
	_report("struggling waits", early["words"] == "Break its guard" and _warden.posture() < 50.0,
		"9.5 s into weak rams the posture is %.0f and the plate still reads \"%s\"" % [_warden.posture(), early["words"]])
	await _seconds(1.0)
	var struggling := _plate_state()
	_report("struggling shows", struggling["words"] == "Get heavy, then return" and _warden.posture() < 50.0 and struggling["marker"] == struggling["icon"]
			and struggling["icon"] != guard_icon,
		"10.5 s of weak rams, posture %.0f: the plate reads \"%s\" with glyph %s against the guard's %s" % [_warden.posture(), struggling["words"], struggling["icon"], guard_icon])


func _stagger() -> void:
	var guard := 0
	while is_instance_valid(_warden) and not _warden.staggered() and guard < 20:
		_combat.strike(_warden, "ram", _matched_force())
		await physics_frame
		guard += 1
	var state := _plate_state()
	_report("O1-3 staggered", _warden.staggered() and state["words"] == "Smash the core" and state["marker"] == state["icon"],
		"driven through combat.strike(): staggered %s, the plate reads \"%s\", glyph %s, edge marker glyph %s" % [_warden.staggered(), state["words"], state["icon"], state["marker"]])
	await _seconds(4.6)
	var after := _plate_state()
	_report("a stagger clears the struggle", not _warden.staggered() and after["words"] == "Break its guard",
		"the stagger ran out and the plate reads \"%s\"" % after["words"])


func _gates() -> void:
	_game.flow._unseal()
	await _frames(3)
	if _hud.edge_markers.gate_points.is_empty():
		_game.events.reward_offered.emit([{"at": _game.player.ball_position() + Vector3(0.0, 0.0, -30.0)}])
	# The finished Warden is ticked in the goal's own place first, then the gate row follows.
	var ticked := _plate_state()
	_report("O1-3 the Warden is ticked", ticked["words"] == "Warden broken" and _hud._objective.done == "won",
		"at the unseal the plate reads \"%s\", done \"%s\"" % [ticked["words"], _hud._objective.done])
	await _seconds(Objectives.Done.SECONDS + 0.1)
	var state := _plate_state()
	_report("O1-3 gates", state["words"] == "Roll through a gate" and state["marker"] == state["icon"] and state["icon"] != "",
		"%.1f s after the unseal the plate reads \"%s\", glyph %s, edge marker glyph %s" % [Objectives.Done.SECONDS + 0.1, state["words"], state["icon"], state["marker"]])


func _play_view() -> void:
	var gone := []
	for child in _hud.get_children():
		var script: Script = child.get_script()
		var path: String = script.resource_path if script != null else ""
		for retired in ["heft_dial", "callouts", "gauge_scrap"]:
			if path.contains(retired):
				gone.append(path)
	var toasts := Hud.toast_kinds()
	var kept := toasts.filter(func(kind): return kind in ["part_gained", "reward_chosen", "heft_class_changed", "heft_class_dropped"])
	var toasts_before: Array = _hud.toast_texts()
	_game.events.scrap_collected.emit(5, Vector3.ZERO, 5)
	_game.events.warden_engaged.emit(1)
	_game.events.part_gained.emit("boost_coil", "gate")
	_game.events.reward_chosen.emit("boost_coil")
	_game.events.heft_class_changed.emit(2, 1.5)
	_game.events.heft_class_dropped.emit(1, 1.2)
	_hud._process(0.0)
	var words: Array = WordBudget.count(_hud)["items"].map(func(item): return item["text"])
	# 2026-10-11 (w13 coordinator): a clock word is a time, digits round a colon. The achievement
	# toast "<title>\nNew look: <item>" (achievements.gd:147, unit B5) carries a colon and is not a clock.
	var clock_re := RegEx.create_from_string("\\d:\\d\\d")
	var clock := words.filter(func(text): return clock_re.search(String(text)) != null)
	var absent: bool = _hud.get("callouts") == null and _hud.get("_heft") == null and _hud.get("_scrap") == null \
		and _hud._objective.get("plating") == null and _hud._objective.get("cores") == null and _hud._status.get("seconds") == null
	_report("O1-4 play view", gone.is_empty() and kept.is_empty() and absent and clock.is_empty() and _hud.toast_texts() == toasts_before,
		"retired children %s, part or heft toast kinds %s, heft, scrap, callouts, bars, pips and clock absent %s, clock words %s, toasts %s before and %s after a part, a reward and two heft changes"
			% [gone, kept, absent, clock, toasts_before, _hud.toast_texts()])


func _part_name() -> void:
	_hud.set_physics_process(false)
	var shown = _hud.part_name
	_game.events.part_gained.emit("sunforged_core_ring", "gate")
	var first: String = shown.text
	_hud._physics_process(1.19)
	var held: bool = shown.text == first and shown.drawn_words() == PackedStringArray([first])
	_hud._physics_process(0.02)
	var gone: bool = shown.text == "" and shown.drawn_words().is_empty() and not shown.visible
	_game.events.part_gained.emit("sunforged_core_ring", "pickup")
	_hud._physics_process(0.6)
	_game.events.part_gained.emit("boost_coil", "pickup")
	var replaced: String = shown.text
	_hud._physics_process(0.7)
	var held_again: bool = shown.text == replaced and shown.left > 0.0
	_hud._physics_process(0.6)
	_report("O1-5 part name", first == "Sunforged Core" and held and gone and replaced == "Boost Coil" and held_again and shown.text == "",
		"a pickup reads \"%s\" for 1.19 s (%s), is gone at 1.21 s (%s); a second at 0.6 s replaces it with \"%s\", which then runs its own 1.2 s (%s)"
			% [first, held, gone, replaced, held_again])
	_hud.set_physics_process(true)


func _plate() -> void:
	var sizes: Array = SIZES.duplicate()
	sizes.append(_hud._screen_size())
	var bad := []
	for size in sizes:
		_hud.layout(size)
		var before: Dictionary = _hud.piece_rects()
		var plate := Plate.new()
		plate.custom_minimum_size = PLATE_SIZE
		_hud.mount_plate(plate)
		_hud.layout(size)
		var rects: Dictionary = _hud.piece_rects()
		var plate_rect := Rect2(plate.position, plate.size)
		var objective: Rect2 = rects["top"][0]
		var others: Array[Rect2] = []
		for region in rects:
			if region != "top":
				others.append_array(rects[region])
		var clash := []
		for piece in rects["top"]:
			for other in rects["top"] + others:
				if piece != other and piece.intersects(other) and (piece == plate_rect or other == plate_rect or piece == objective or other == objective):
					clash.append([piece, other])
		var centred := absf(plate_rect.get_center().x - size.x * 0.5) < 0.5
		var under := absf(objective.get_center().x - size.x * 0.5) < 0.5 and objective.position.y >= plate_rect.end.y \
			and objective.position.y - plate_rect.end.y <= Hud.PLATE_GAP + 0.5
		var inside := Rect2(Vector2.ZERO, size).encloses(plate_rect) and ScreenRegions.rect("top", size).grow(0.5).encloses(plate_rect) \
			and ScreenRegions.rect("top", size).grow(0.5).encloses(objective)
		var listed: bool = rects["top"].has(plate_rect)
		var counted: bool = WordBudget.count(_hud)["items"].any(func(item): return item["text"] == "Rust Warden" and item["words"] == 2)
		_hud.unmount_plate()
		_hud.layout(size)
		var restored: bool = _hud.piece_rects() == before
		if not (plate_rect.size == PLATE_SIZE and centred and under and inside and listed and clash.is_empty() and counted and restored):
			bad.append("%s: size %s centred %s under %s inside %s listed %s clash %s counted %s restored %s" % [size, plate_rect.size, centred, under, inside, listed, clash, counted, restored])
		plate.free()
	_hud.layout(_hud._screen_size())
	var real_before: Dictionary = _hud.piece_rects()
	var other := Plate.new()
	other.custom_minimum_size = PLATE_SIZE
	_hud.mount_plate(other)
	_hud.unmount_plate()
	var exact: bool = _hud.piece_rects() == real_before
	other.free()
	var sized := Control.new()
	sized.size = PLATE_SIZE
	_hud.mount_plate(sized)
	var sized_rect := Rect2(sized.position, sized.size)
	var sized_ok: bool = sized_rect.size == PLATE_SIZE and absf(sized_rect.get_center().x - _hud._screen_size().x * 0.5) < 0.5 \
		and _hud._objective.position.y >= sized_rect.end.y
	_hud.unmount_plate()
	sized.free()
	_report("O1-6 plate sized only by size", sized_ok, "a Control that sets only size %s is placed at %s with the objective under it at y %.1f" % [PLATE_SIZE, sized_rect, _hud._objective.position.y])
	_report("O1-6 plate", bad.is_empty() and exact,
		"a 420 by 44 plate at %s: top-centre, objective under it, inside the screen and the top band, no overlap with the other pieces, counted in the word budget, unmount restores %s; problems %s"
			% [sizes, exact, bad])


func _bar_keys() -> void:
	var glyphs = _hud.key_glyphs
	glyphs.set_physics_process(false)
	glyphs.new_run()
	var cam: Camera3D = _game.camera.cam
	var ahead: Vector3 = cam.global_position - cam.global_transform.basis.z * 5.0
	var ready := {"harpoon": false, "haul": true, "boost": true, "interact": false, "jump": false}
	var view := {"ready": ready, "line": "body", "charging": false, "mounted": false, "airborne": false, "winching": false,
		"points": {"harpoon": ahead, "haul": ahead, "boost": ahead, "interact": ahead, "jump": ahead}}
	glyphs.step(2.0, view)
	_hud._process(0.0)
	var bar = _hud.ability_bar
	var shown: Array = glyphs.shown_glyphs()
	var hidden_now: Array = bar.slots.filter(func(slot): return bar.key_hidden(slot)).map(func(slot): return slot["key"])
	var want: Array = bar.slots.filter(func(slot): return slot["key"] in shown).map(func(slot): return slot["key"])
	var words_hidden: bool = not "Ctrl" in bar.drawn_words() and not "Shift" in bar.drawn_words()
	var none := {"ready": {"harpoon": false, "haul": false, "boost": false, "interact": false, "jump": false}, "line": "", "charging": false,
		"mounted": false, "airborne": false, "winching": false, "points": view["points"]}
	glyphs.step(0.016, none)
	_hud._process(0.0)
	var hidden_after: Array = bar.slots.filter(func(slot): return bar.key_hidden(slot))
	_report("O1-7 bar keys", shown.size() == 2 and not want.is_empty() and hidden_now == want and words_hidden and hidden_after.is_empty() and "Ctrl" in bar.drawn_words(),
		"prompts on %s hide the bar's caps on %s; a tick with none shows all %d again" % [shown, hidden_now, bar.slots.size() - hidden_after.size()])
	# A prompt whose anchor is behind the camera is not drawn, so the bar keeps its own cap.
	var behind: Vector3 = cam.global_position + cam.global_transform.basis.z * 5.0
	var behind_view: Dictionary = view.duplicate(true)
	behind_view["points"]["haul"] = behind
	glyphs.new_run()
	glyphs.step(2.0, behind_view)
	_hud._process(0.0)
	var behind_glyphs: Array = glyphs.shown_glyphs()
	var behind_hidden: Array = bar.slots.filter(func(slot): return bar.key_hidden(slot)).map(func(slot): return slot["key"])
	_report("O1-7 bar keys behind the camera", behind_view["points"]["haul"] != Vector3.INF and cam.is_position_behind(behind) and not "key_ctrl" in behind_glyphs
			and not "key_ctrl" in behind_hidden and "Ctrl" in bar.drawn_words(),
		"the haul prompt anchored behind the camera: glyphs told to the bar %s, caps hidden %s, Ctrl drawn on the bar %s" % [behind_glyphs, behind_hidden, "Ctrl" in bar.drawn_words()])
	# The same for an anchor in front of the camera but off the side of the screen.
	var aside: Vector3 = cam.global_position - cam.global_transform.basis.z * 2.0 + cam.global_transform.basis.x * 60.0
	var aside_view: Dictionary = view.duplicate(true)
	aside_view["points"]["haul"] = aside
	glyphs.new_run()
	glyphs.step(2.0, aside_view)
	_hud._process(0.0)
	var aside_glyphs: Array = glyphs.shown_glyphs()
	var aside_hidden: Array = bar.slots.filter(func(slot): return bar.key_hidden(slot)).map(func(slot): return slot["key"])
	var off_screen: bool = not cam.is_position_behind(aside) and not cam.get_viewport().get_visible_rect().has_point(cam.unproject_position(aside))
	_report("O1-7 bar keys off the screen", off_screen and not "key_ctrl" in aside_glyphs and not "key_ctrl" in aside_hidden and "Ctrl" in bar.drawn_words(),
		"the haul prompt anchored off the side of the screen: glyphs told to the bar %s, caps hidden %s, Ctrl drawn on the bar %s" % [aside_glyphs, aside_hidden, "Ctrl" in bar.drawn_words()])
	glyphs.set_physics_process(true)
