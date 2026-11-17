extends SceneTree

# The rotating title openings: the pick per profile state (title_intros.gd) and one playback on
# the real title stage (title_intro_player.gd). TTL_CAPTURE_DIR saves a still of every shot of
# the given rows (TTL_INTRO_ROWS, comma separated; default sable) on a rendered display.

const Game := preload("res://src/game.gd")
const TitleIntros := preload("res://src/presentation/title_intros.gd")
const T := preload("res://tests/support/t.gd")

var _t := T.new("title_intros_test")


# The profile surface the pick reads, in memory.
class FakeProfile:
	var seen: Array[String] = []
	var stats := {}
	var achievements: Array[String] = []

	func earned(id: String) -> bool:
		return achievements.has(id)

	func is_seen(id: String) -> bool:
		return seen.has(id)

	func mark_seen(id: String) -> bool:
		if seen.has(id):
			return false
		seen.append(id)
		return true

	func stat(stat_name: String) -> float:
		return float(stats.get(stat_name, 0.0))

	func set_stat(stat_name: String, value: float) -> void:
		stats[stat_name] = value


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_picks()
	var capture := OS.get_environment("TTL_CAPTURE_DIR")
	if capture != "":
		if DisplayServer.get_name() == "headless":
			_t.check("capture requires a rendered display", false)
			quit(_t.verdict())
			return
		root.size = Vector2i(1600, 900)
		DirAccess.make_dir_recursive_absolute(capture)
	await _playback(capture)
	quit(_t.verdict())


func _picks() -> void:
	var starters := ["pylon_engineer", "runner_gunner", "demolitions_caster"]
	var flyable := func(pilot: String) -> bool: return starters.has(pilot)
	var none := func(_pilot: String) -> bool: return false
	_t.eq("no profile plays Sable", TitleIntros.pick(TitleIntros.facts_from(null, flyable)), "sable")
	var profile := FakeProfile.new()
	_t.eq("first launch plays Sable", _pick(profile, flyable), "sable")
	TitleIntros.mark_shown(profile, "sable")
	_t.check("Sable is marked seen", profile.is_seen(TitleIntros.SEEN_PREFIX + "sable"))
	_t.eq("then the newest unseen unlock: Kest", _pick(profile, flyable), "kest")
	TitleIntros.mark_shown(profile, "kest")
	_t.eq("then Rivet", _pick(profile, flyable), "rivet")
	TitleIntros.mark_shown(profile, "rivet")
	_t.eq("then Spillway", _pick(profile, flyable), "spillway")
	TitleIntros.mark_shown(profile, "spillway")
	var open := TitleIntros.available(TitleIntros.facts_from(profile, flyable))
	_t.eq("fresh profile offers Sable, Spillway, Rivet, Kest", str(open), str(["sable", "spillway", "rivet", "kest"]))
	_t.check("no boss before it is met", not open.has("brindle") and not open.has("waking") and not open.has("mind"))
	_t.check("no Dig or Highdraft before they are reached", not open.has("dig") and not open.has("highdraft"))
	_t.eq("all seen: round robin after the last shown (Spillway) is Rivet", _pick(profile, flyable), "rivet")
	TitleIntros.mark_shown(profile, "rivet")
	_t.eq("round robin goes on to Kest", _pick(profile, flyable), "kest")
	TitleIntros.mark_shown(profile, "kest")
	_t.eq("round robin wraps to Sable", _pick(profile, flyable), "sable")
	TitleIntros.mark_shown(profile, "sable")
	_t.eq("and on to Spillway", _pick(profile, flyable), "spillway")
	_t.check("the pointer only grows, so a max-merge save keeps it", profile.stat(TitleIntros.LAST_STAT) > TitleIntros.ROWS.size())
	_t.check("meeting Brindle records once", TitleIntros.mark_met(profile, "brindle") and not TitleIntros.mark_met(profile, "brindle"))
	_t.check("an unknown boss is not recorded", not TitleIntros.mark_met(profile, ""))
	_t.eq("a met boss is the newest unseen", _pick(profile, flyable), "brindle")
	TitleIntros.mark_shown(profile, "brindle")
	profile.achievements.append("ach_d7_mushroom")
	_t.eq("reaching the Dig unlocks its opening", _pick(profile, flyable), "dig")
	TitleIntros.mark_shown(profile, "dig")
	profile.achievements.append("waking_stilled")
	_t.eq("beating the Waking counts as meeting it", _pick(profile, flyable), "waking")
	var everything := func(_pilot: String) -> bool: return true
	_t.check("the Cannon waits for the ending", not TitleIntros.available(TitleIntros.facts_from(profile, everything)).has("cannon"))
	profile.achievements.append("mind_quieted")
	_t.eq("after the ending the Cannon is newest", _pick(profile, everything), "cannon")
	_late_unlocks()
	var locked := FakeProfile.new()
	TitleIntros.mark_shown(locked, "sable")
	_t.eq("with nothing flyable, Sable and Spillway still rotate", str(TitleIntros.available(TitleIntros.facts_from(locked, none))), str(["sable", "spillway"]))
	for row in TitleIntros.ROWS:
		var length := TitleIntros.length_seconds(String(row.id))
		_t.check("%s opening is 30 to 45 s (%.1f)" % [row.id, length], length >= 30.0 and length <= 45.0)
		_t.eq("%s card holds three stats" % row.id, row.card.size(), 8)
		_t.eq("%s ends on the slam" % row.id, TitleIntros.shots(String(row.id)).back().kind, "slam")
		var line := TitleIntros.pointer_line(String(row.id))
		_t.check("%s postcard line is a sentence (%s)" % [row.id, line], line.split(" ").size() >= 3 and line.ends_with(".")
			and line == line.strip_edges() and not line.contains("  "))
	_t.eq("Sable's postcard line", TitleIntros.pointer_line("sable"), "this is her.")
	_t.eq("a world's postcard line", TitleIntros.pointer_line("spillway"), "you are here.")
	_t.eq("a boss's postcard line names it", TitleIntros.pointer_line("brindle"), "this is Admiral Brindle.")
	_t.eq("a name that starts with The keeps a small the", TitleIntros.pointer_line("waking"), "this is the Waking.")


func _pick(profile, flyable: Callable) -> String:
	return TitleIntros.pick(TitleIntros.facts_from(profile, flyable))


func _playback(capture: String) -> void:
	var game := Game.new()
	game.test_mode = true
	game.table = "alpha"
	root.add_child(game)
	await process_frame
	await physics_frame
	var display = game.presentation.title_stage
	_t.check("bots and tests never autoplay", not display.intro_autoplay and not display.intro_playing())
	var bodies := _bodies(root)
	var rows := ["sable"]
	if capture != "" and OS.get_environment("TTL_INTRO_ROWS") != "":
		rows = OS.get_environment("TTL_INTRO_ROWS").split(",")
	for id in rows:
		await _play_row(game, display, String(id), capture)
	await _workshop_key(game, display)
	var saved: int = game.ctx.profile.generation()
	game.ctx.run.world = 1
	game.ctx.events.boss_arena_entered.emit()
	_t.check("entering a boss arena marks it met", game.ctx.profile.is_seen(TitleIntros.MET_PREFIX + "brindle"))
	_t.eq("and adds no disk write", game.ctx.profile.generation(), saved)
	_t.eq("body count unchanged after the openings", _bodies(root), bodies)
	_t.check("played opening is recorded as shown", game.ctx.profile.is_seen(TitleIntros.SEEN_PREFIX + String(rows[0])))
	_t.check("an opening refuses to start off the title", (func() -> bool:
		game.flow.press_start()
		var refused: bool = not display.play_intro("sable")
		game.flow.show_title()
		return refused).call())
	await _hold(game, display)
	game.free()
	await process_frame


# intro_hold keeps the autoplay off until release_intro(); released twice it still starts once.
func _hold(game: Node, display) -> void:
	display.intro_autoplay = true
	display.intro_hold = true
	display._intro_tried = false
	game.flow.press_start()
	game.flow.show_title()
	await process_frame
	await process_frame
	_t.check("a held title starts no opening", not display.intro_playing() and not display._intro_tried)
	display.release_intro()
	_t.check("release lifts the hold", not display.intro_hold)
	await process_frame
	_t.check("release starts the opening", display.intro_playing())
	display.intro.skip()
	await process_frame
	display.release_intro()
	await process_frame
	_t.check("a second release starts nothing", not display.intro_playing())
	# Off the title a release leaves the opening untried.
	display.intro_hold = true
	display._intro_tried = false
	game.flow.press_start()
	display.release_intro()
	await process_frame
	_t.check("release off the title starts nothing", not display.intro_playing() and not display._intro_tried)
	# Planted control: a hold that is never released shows no opening on the title.
	display.intro_hold = true
	game.flow.show_title()
	await process_frame
	await process_frame
	_t.check("an unreleased hold never plays", not display.intro_playing() and not display._intro_tried)
	display.intro_hold = false
	display.intro_autoplay = false


func _play_row(game: Node, display, id: String, capture: String) -> void:
	var held: Transform3D = display.camera.transform
	_t.check(id + " starts", display.play_intro(id))
	var player = display.intro
	_t.check(id + " shows the comic layer and its own set", display.get_node_or_null("TitleIntroPlayer/TitleIntro") != null
		and display.stage.get_node_or_null("IntroSet") != null)
	_t.eq(id + " set has no collision objects", _colliders(display.stage), 0)
	_t.check(id + " renders every frame while playing", display.viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS)
	var shots: Array = TitleIntros.shots(id)
	var at := 0.0
	var kinds: Array[String] = []
	for i in shots.size():
		var middle: float = at + float(shots[i].bars) * TitleIntros.BAR * 0.5
		player.advance(middle - player.clock)
		kinds.append(player.shot_kind())
		if String(shots[i].kind) == "postcard":
			# The label over the tiny subject is a whole sentence with an arrow under its middle:
			# one word read as a caption that had lost its words, and a box as a speech bubble.
			await process_frame
			var pointer: Control = display.find_child("Pointer", true, false)
			var words: Label = pointer.get_node_or_null("Words") if pointer != null else null
			var arrow: Control = pointer.get_node_or_null("Arrow") if pointer != null else null
			_t.check(id + " pointer shows the row's line", words != null and words.text == TitleIntros.pointer_line(id) and words.text != "")
			_t.check(id + " pointer has no box", pointer != null and not (pointer is PanelContainer))
			# The arrow is drawn from its own left edge, so it must be no wider than a line.
			_t.check(id + " pointer's arrow hangs under the middle of its words", arrow != null and pointer.size.x > 0.0
				and arrow.size.x < 2.0 and absf(arrow.position.x - pointer.size.x * 0.5) < 2.0)
			if id == "sable":
				_check_sable_postcard(display)
		if id == "sable" and i == 1:
			var set_root: Node3D = display.stage.get_node("IntroSet")
			var postcard := set_root.get_node_or_null("SablePostcard") as Node3D
			var subject := set_root.get_node("Subject") as Node3D
			_t.check("Sable's hero shot leaves the dam set and dawn behind", postcard != null and not postcard.visible
				and display.camera.environment == display._environment)
			_t.check("Sable's hero shot restores the normal subject pose", subject.position.is_equal_approx(Vector3.UP * 1.04)
				and subject.scale.is_equal_approx(Vector3.ONE))
		if capture != "":
			for frame in 6:
				await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(capture.path_join("%s-%02d-%s.png" % [id, i + 1, shots[i].kind]))
		at += float(shots[i].bars) * TitleIntros.BAR
	var want: Array[String] = []
	for shot in shots:
		want.append(String(shot.kind))
	_t.eq(id + " walks every shot in order", kinds, want)
	_t.check(id + " name card is drawn on the card shot", _seen_card(player, shots))
	var press := InputEventKey.new()
	press.keycode = KEY_ENTER
	press.physical_keycode = KEY_ENTER
	press.pressed = true
	var state: String = game.flow.state_name()
	# A human's press: test_mode off, so game._input would start a run if the press got through.
	game.test_mode = false
	Input.parse_input_event(press)
	await process_frame
	await process_frame
	game.test_mode = true
	_t.check(id + " any key skips", not display.intro_playing())
	_t.eq(id + " the skip press does not also start a run", game.flow.state_name(), state)
	await process_frame
	_t.check(id + " removes its set and layer", display.stage.get_node_or_null("IntroSet") == null
		and display.get_node_or_null("TitleIntroPlayer/TitleIntro") == null)
	_t.check(id + " cuts back to the deck", display.camera.position.distance_to(held.origin) < 1.5)


func _check_sable_postcard(display: Node) -> void:
	var set_root: Node3D = display.stage.get_node("IntroSet")
	var postcard := set_root.get_node_or_null("SablePostcard") as Node3D
	if not _t.check("Sable's postcard shows the dam set", postcard != null and postcard.visible):
		return
	var subject: Node3D = set_root.get_node("Subject")
	var subject_at := postcard.to_local(subject.global_position)
	# The landmark's arch deck is at 121 m; between the gate towers and the abutments it is open to the sky.
	_t.check("Sable is on the open crest", absf(subject_at.x) > 24.0 and absf(subject_at.x) < 160.0
		and subject_at.y >= 121.0 and subject_at.y <= 126.0)
	var water: Node3D = postcard.get_node("Tailwater")
	var camera_height: float = display.camera.global_position.y - water.global_position.y
	_t.check("Sable's postcard looks up at the dam from just over the water", camera_height > 0.0 and camera_height < 10.0)


# The workshop's companion key (M) runs before the title stage in tree order; the opening must
# still take it as a skip and the panel must stay shut.
func _workshop_key(game: Node, display) -> void:
	_t.check("plays again for the workshop key", display.play_intro("spillway"))
	var key := InputEventKey.new()
	key.keycode = KEY_M
	key.physical_keycode = KEY_M
	key.pressed = true
	game.test_mode = false
	Input.parse_input_event(key)
	await process_frame
	await process_frame
	game.test_mode = true
	var panel_open := false
	for child in game.get_children():
		if child.get("companion_panel") != null and child.companion_panel.is_open():
			panel_open = true
	_t.check("the companion key skips the opening", not display.intro_playing())
	_t.check("and does not open the companion panel", not panel_open)
	await process_frame


func _seen_card(player, shots: Array) -> bool:
	var at := 0.0
	for shot in shots:
		if shot.kind == "card":
			player.clock = at
			player.shot_index = -1
			player.advance(0.01)
			return player.get_node_or_null("TitleIntro/IntroOverlay/NameCard") != null
		at += float(shot.bars) * TitleIntros.BAR
	return false


func _bodies(node: Node) -> int:
	var count := 1 if node is PhysicsBody3D else 0
	for child in node.get_children():
		count += _bodies(child)
	return count


func _colliders(node: Node) -> int:
	var count := 1 if node is CollisionObject3D else 0
	for child in node.get_children():
		count += _colliders(child)
	return count


# The rows the main walk never reaches: Tarn and Tally once flyable, the Highdraft once reached,
# the Mind once its arena is entered (mark_met, as the title stage does on boss_arena_entered).
func _late_unlocks() -> void:
	var profile := FakeProfile.new()
	var pilots: Array[String] = ["pylon_engineer", "runner_gunner", "demolitions_caster"]
	var flyable := func(pilot: String) -> bool: return pilots.has(pilot)
	for id in ["sable", "kest", "rivet", "spillway"]:
		TitleIntros.mark_shown(profile, id)
	pilots.append("tarn")
	_t.eq("unlocking Tarn plays Tarn next", _pick(profile, flyable), "tarn")
	TitleIntros.mark_shown(profile, "tarn")
	pilots.append("tally")
	_t.eq("unlocking Tally plays Tally next", _pick(profile, flyable), "tally")
	TitleIntros.mark_shown(profile, "tally")
	_t.check("no Highdraft before it is reached", not TitleIntros.available(TitleIntros.facts_from(profile, flyable)).has("highdraft"))
	profile.achievements.append("highdraft_reached")
	_t.eq("reaching the Highdraft unlocks its opening", _pick(profile, flyable), "highdraft")
	TitleIntros.mark_shown(profile, "highdraft")
	_t.check("no Mind before its arena", not TitleIntros.available(TitleIntros.facts_from(profile, flyable)).has("mind"))
	_t.check("entering the Mind's arena records it", TitleIntros.mark_met(profile, "mind"))
	_t.eq("a met Mind is the newest unseen", _pick(profile, flyable), "mind")
	_t.check("meeting the Mind is not the ending", not TitleIntros.available(TitleIntros.facts_from(profile, func(_p): return true)).has("cannon"))
