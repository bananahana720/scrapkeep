extends SceneTree

const Game := preload("res://src/game.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Synergies := preload("res://src/build/synergies.gd")
const WhyCallout := preload("res://src/ui/why_callout.gd")
const WordBudget := preload("res://src/core/word_budget.gd")
const UiProfile := preload("res://src/ui/ui_profile.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const Icons := preload("res://src/ui/icons.gd")
const Parts := preload("res://src/build/parts.gd")
const ScreenBusy := preload("res://src/ui/screen_busy.gd")

# The callout that shows why a synergy fired, through the real game on the slice table. Every
# CAUSE_ROWS id is fired and must draw a callout in its row's shape and colour with its two
# callout parts' icons and a name; it runs 0.9 s; the name shows on a profile's first three
# firings, the callout's three words after; a wave 11 callout (Tesla Pylon's Live Line) draws
# two registered icons that resolve to textures;
# one callout per row per 4 s, one on screen in a fight and two when calm, and a firing over
# a limit still pulses the body; arming links two glyphs at the ball with no banner and
# the discovery burst and ring are gone; a discovery card raised in a fight waits for 3 s of
# calm; and the callout takes every colour from EventKinds. Clocks are stepped by hand.

const DT := 1.0 / 60.0
const AT := Vector3(0.0, 5.0, -8.0)
const SCREEN := Vector2(1600.0, 900.0)

var _game
var _why
var _vfx
var _banner
var _failures := 0
var _started := false


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "slice"
	root.add_child(_game)


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _process(_delta: float) -> bool:
	if _started or _game == null or _game.flow == null:
		return false
	_started = true
	_run()
	return false


func _steps(count: int) -> void:
	for i in count:
		_why.step(DT)


func _fresh() -> void:
	_why.clear()
	_why._calm_left = 0.0


# The card's gate is the screen's quiet clock (screen_busy.gd, wave 36): it is stepped by hand with the
# banner, so "3 s of calm" is counted on the same clock as before.
func _card_step() -> void:
	_game.ctx.screen_busy.step(DT)
	_banner._process(DT)


# The quiet clock already past the finds' hold, as the old banner clock set to zero was.
func _card_calm() -> void:
	_game.ctx.screen_busy.step(ScreenBusy.FIND_HOLD)


func _threat() -> Node:
	var node := Node3D.new()
	node.add_to_group(Threat.GROUP)
	_game.add_child(node)
	return node


func _run() -> void:
	_game.ctx.calm = true
	_game.flow.press_start()
	_game.flow.choose_class(0)
	for i in 4:
		await process_frame
	_why = _game.hud.why_callout
	_vfx = _game.presentation.vfx
	_banner = _game.presentation.banner
	_why.set_process(false)
	var events = _game.events
	for id in EventKinds.CAUSE_ROWS:
		_why.profile.glyph_uses.erase(WhyCallout.USE_PREFIX + id)

	for id in EventKinds.CAUSE_ROWS:
		_fresh()
		var row: Dictionary = EventKinds.cause_row(id)
		var named: bool = Synergies.ROWS.has(id) and String(Synergies.ROWS[id]["name"]) != ""
		var glyphs: Array = WhyCallout.callout_icons(id)
		events.cause_fired.emit(id, null, AT)
		var pieces: Array = _why.callouts()
		var piece = pieces[0] if pieces.size() == 1 else null
		_check("WY2-1 %s" % id, named and glyphs.size() == 2 and piece != null and piece.shape == String(row["shape"]) and piece.color == EventKinds.cause_color(id) and piece.part_icons == glyphs,
			"named %s, part icons %s, %d callout, shape %s against row %s, colour on the row's %s" % [named, glyphs, pieces.size(), piece.shape if piece != null else "none", row["shape"], EventKinds.cause_color(id) == (piece.color if piece != null else Color.BLACK)])
		_why.profile.glyph_uses.erase(WhyCallout.USE_PREFIX + id)

	_fresh()
	events.cause_fired.emit("wrecking_ball", null, AT)
	var first = _why.callouts()[0]
	_steps(53)
	var live_at_53: bool = _why.callouts().size() == 1
	_steps(2)
	var gone_at_55: bool = _why.callouts().is_empty() and first.is_queued_for_deletion()
	await process_frame
	_check("WY2-2", live_at_53 and gone_at_55 and not is_instance_valid(first),
		"on screen after 53 frames (%s), leaving the list and queued for deletion by 55 (0.9 s is 54 frames: %s), freed a frame later: %s" % [live_at_53, gone_at_55, not is_instance_valid(first)])

	_fresh()
	_why.profile.glyph_uses.erase(WhyCallout.USE_PREFIX + "pinwheel")
	var words: Array = []
	for n in 4:
		events.cause_fired.emit("pinwheel", null, AT)
		var shown = _why.callouts()[0]
		words.append(" ".join(shown.drawn_words()))
		_steps(250)
	var name_text: String = String(Synergies.ROWS["pinwheel"]["name"])
	var call_words: String = String(Synergies.callout("pinwheel")["words"])
	_check("WY2-3", words[0] == name_text and words[1] == name_text and words[2] == name_text and words[3] == call_words and WordBudget.words_in(name_text) <= 3
			and WordBudget.words_in(call_words) == 3,
		"firings one to four report %s" % [words])

	_fresh()
	var call := Synergies.callout("tesla_pylon")
	events.cause_fired.emit("tesla_pylon", null, AT)
	var tesla = _why.callouts()[0] if _why.callouts().size() == 1 else null
	var icons: Array = tesla.part_icons if tesla != null else []
	var resolve := icons.size() == 2 and icons.all(func(icon): return Icons.has(icon) and Icons.texture(icon) != null)
	if tesla != null:
		tesla.queue_redraw()
	await process_frame
	_check("GP2-3 new callout icons", call["b"] == "live_line" and resolve
			and icons == [Parts.icon_of(call["a"]), Parts.icon_of(call["b"])],
		"Tesla Pylon's callout %s + %s draws icons %s, registered and textured %s" % [call["a"], call["b"], icons, resolve])
	_why.profile.glyph_uses.erase(WhyCallout.USE_PREFIX + "tesla_pylon")

	_fresh()
	events.cause_fired.emit("wrecking_ball", null, AT)
	events.cause_fired.emit("wrecking_ball", null, AT)
	_check("WY2-4 one row at once", _why.callouts().size() == 1, "two firings of one row on one tick drew %d callouts" % _why.callouts().size())
	_steps(60)
	events.cause_fired.emit("wrecking_ball", null, AT)
	_check("WY2-4 one row after the first ended", _why.callouts().is_empty(), "a third firing 1 s later drew %d callouts" % _why.callouts().size())

	_fresh()
	var hostile := _threat()
	var pulses_before: int = _vfx.spawned.get("cause_fired", 0)
	events.cause_fired.emit("wrecking_ball", null, AT)
	events.cause_fired.emit("tesla_pylon", null, AT)
	var fight_count: int = _why.callouts().size()
	var pulses: int = _vfx.spawned.get("cause_fired", 0) - pulses_before
	_check("WY2-4 fight", _why.fight() and fight_count == 1 and pulses == 2,
		"with a live telegraph two rows drew %d callout and %d body pulses" % [fight_count, pulses])
	hostile.free()
	_fresh()
	events.cause_fired.emit("wrecking_ball", null, AT)
	events.cause_fired.emit("tesla_pylon", null, AT)
	events.cause_fired.emit("pinwheel", null, AT)
	_check("WY2-4 calm", not _why.fight() and _why.callouts().size() == 2, "when calm three rows drew %d callouts" % _why.callouts().size())
	_fresh()
	events.player_hit.emit(1.0, "test")
	events.cause_fired.emit("shrapnel_bloom", null, AT)
	events.cause_fired.emit("lightning_rod", null, AT)
	_check("WY2-4 damage is a fight", _why.fight() and _why.callouts().size() == 1, "after a hit two rows drew %d callout" % _why.callouts().size())

	_fresh()
	# Let the cleared callouts leave the tree, so the counted one keeps the node name "Callout".
	await process_frame
	_why.profile.glyph_uses.erase(WhyCallout.USE_PREFIX + "pinwheel")
	events.cause_fired.emit("pinwheel", null, AT)
	var counted := WordBudget.count(_game.hud)
	var budget_name := String(Synergies.ROWS["pinwheel"]["name"])
	var budget_words := 0
	for item in counted["items"]:
		if item["node"] == "Callout" and String(item["text"]) == budget_name:
			budget_words += int(item["words"])
	_check("WY2 word budget", _game.flow.in_play() and budget_words == WordBudget.words_in(budget_name) and budget_words > 0,
		"flow in play (%s), the HUD's word count holds the name '%s' as %d words (wanted %d)" % [_game.flow.in_play(), budget_name, budget_words, WordBudget.words_in(budget_name)])

	_fresh()
	var body := Node3D.new()
	_game.add_child(body)
	var cam: Camera3D = _game.camera.cam
	body.global_position = cam.global_position + (-cam.global_basis.z) * 12.0 + cam.global_basis.x * 3.0
	var pulses_at_body: int = _vfx.spawned.get("cause_fired", 0)
	events.cause_fired.emit("tesla_pylon", body, AT)
	var body_piece = _why.callouts()[0] if _why.callouts().size() == 1 else null
	var screen_size: Vector2 = _why.get_viewport_rect().size
	var want_spot := WhyCallout.place(cam.unproject_position(body.global_position + Vector3.UP), WhyCallout.SIZE, screen_size)
	var far_spot := WhyCallout.place(screen_size * 0.5, WhyCallout.SIZE, screen_size)
	var beside_body: bool = body_piece != null and body_piece.position.is_equal_approx(want_spot) and not body_piece.position.is_equal_approx(far_spot)
	var pulse_want: Vector3 = body.global_position + Vector3.UP * 0.8
	var pulse_at := Vector3.INF
	for slot in _vfx._glyphs:
		if slot["t"] < 1.0 and slot["node"].visible and slot["node"].global_position.is_equal_approx(pulse_want):
			pulse_at = slot["node"].global_position
	var pulse_lands: bool = _vfx.spawned.get("cause_fired", 0) - pulses_at_body == 1 and pulse_at.is_equal_approx(pulse_want)
	_check("WY2 real body", beside_body and pulse_lands,
		"callout at %s (wanted %s, the reticle default would be %s), pulse at %s (wanted %s)" % [body_piece.position if body_piece != null else "none", want_spot, far_spot, pulse_at, pulse_want])
	body.free()
	_fresh()

	_fresh()
	var clear_all := true
	for anchor in [SCREEN * 0.5, Vector2(0.0, 0.0), SCREEN, Vector2(SCREEN.x * 0.5 - 100.0, SCREEN.y * 0.5), Vector2(SCREEN.x * 0.5 - 200.0, SCREEN.y * 0.5 - 60.0)]:
		var spot := WhyCallout.place(anchor, WhyCallout.SIZE, SCREEN)
		var zone := Rect2(SCREEN * 0.5 - Vector2.ONE * WhyCallout.RETICLE_CLEAR, Vector2.ONE * WhyCallout.RETICLE_CLEAR * 2.0)
		var inside := Rect2(Vector2.ZERO, SCREEN).encloses(Rect2(spot, WhyCallout.SIZE))
		if Rect2(spot, WhyCallout.SIZE).intersects(zone) or not inside:
			clear_all = false
			print("   placement for %s went to %s" % [anchor, spot])
	_check("WY2 placement", clear_all, "five anchors, including the reticle's own, land on screen and off the reticle")

	var armed_before: int = _vfx.spawned.get("cause_armed", 0)
	var shown_before: int = _banner.shown
	events.cause_armed.emit("wrecking_ball")
	_check("WY2-5 armed", _vfx.spawned.get("cause_armed", 0) - armed_before == 3 and _banner.shown == shown_before and _banner.queued() == 0 and not _banner.showing() and _why.callouts().is_empty(),
		"arming drew %d glyphs at the ball (two causes and the link), banner shown %d to %d, %d queued" % [_vfx.spawned.get("cause_armed", 0) - armed_before, shown_before, _banner.shown, _banner.queued()])
	events.synergy_discovered.emit("wrecking_ball", "build", true)
	_check("WY2-5 discovery burst", _vfx.spawned.get("synergy_discovered", 0) == 0, "discovery drew %d burst or ring glyphs at the ball" % _vfx.spawned.get("synergy_discovered", 0))

	_banner.dismiss(true)
	_banner.set_process(false)
	_game.ctx.screen_busy.set_process(false)
	_banner.cards = true
	_banner.profile = UiProfile.new(_game.storage_dir)
	var hostile_two := _threat()
	_card_step()
	_banner.show_discovery("Held one", "build", "line", "New synergy", "wy2_a")
	var held_in_fight: bool = _banner.held() and not _banner.showing()
	hostile_two.free()
	for i in 170:
		_card_step()
	var held_before_3s: bool = _banner.held() and not _banner.showing()
	for i in 20:
		_card_step()
	_check("WY2-6 telegraph", held_in_fight and held_before_3s and _banner.showing() and _banner.last_style == "card",
		"raised in a fight it was held (%s), still held 2.83 s after the telegraph ended (%s), on screen after 3.17 s (%s)" % [held_in_fight, held_before_3s, _banner.showing()])
	_banner.dismiss(true)
	_card_step()
	events.player_hit.emit(1.0, "test")
	_banner.show_discovery("Held two", "build", "line", "New synergy", "wy2_b")
	var held_after_hit: bool = _banner.held()
	for i in 170:
		_card_step()
	var held_before: bool = _banner.held()
	for i in 20:
		_card_step()
	_check("WY2-6 damage", held_after_hit and held_before and _banner.showing(),
		"raised just after damage it was held (%s), held at 2.83 s (%s), on screen at 3.17 s (%s)" % [held_after_hit, held_before, _banner.showing()])
	_banner.dismiss(true)
	for i in 200:
		_card_step()
	_banner.show_discovery("Calm one", "build", "line", "New synergy", "wy2_c")
	var at_once: bool = _banner.showing()
	_card_step()
	_check("WY2-6 calm", at_once and _banner.showing(), "raised when calm it showed at once (%s) and on the next frame (%s)" % [at_once, _banner.showing()])
	_banner.dismiss(true)
	events.player_hit.emit(1.0, "test")
	_banner.show_discovery("Screens", "build", "line", "New synergy", "wy2_e")
	var held_for_screen: bool = _banner.held()
	_banner.dismiss(true)
	_check("WY2-6 screens clear it", held_for_screen and _banner.queued() == 0 and not _banner.held(), "a held card (%s) is dropped by dismiss: %d queued" % [held_for_screen, _banner.queued()])

	# A retry rewinds the stage: a held card goes without being marked seen.
	_banner.dismiss(true)
	_card_calm()
	events.player_hit.emit(1.0, "test")
	_banner.show_discovery("Held retry", "build", "line", "New synergy", "wy2_retry")
	var held_before_retry: bool = _banner.held()
	events.stage_entered.emit(1, true)
	var gone_after_retry: bool = not _banner.held() and _banner.queued() == 0 and not _banner.showing()
	_card_calm()
	for i in 5:
		_card_step()
	var never_shown: bool = not _banner.showing() and not _banner.profile.discovered("wy2_retry")
	_check("WY2 retry drops a held card", held_before_retry and gone_after_retry and never_shown,
		"held (%s), gone after a retry stage (%s), never shown or marked seen (%s)" % [held_before_retry, gone_after_retry, never_shown])
	_banner.dismiss(true)
	_card_calm()
	events.player_hit.emit(1.0, "test")
	_banner.show_discovery("Held next", "build", "line", "New synergy", "wy2_next")
	events.stage_entered.emit(1, false)
	_check("WY2 a new stage is not a retry", _banner.held(), "a first entry to a stage left the held card (%s)" % _banner.held())
	_banner.dismiss(true)

	# A held card never shows while the tree is paused.
	_card_calm()
	paused = true
	_banner.show_discovery("Paused one", "build", "line", "New synergy", "wy2_pause")
	for i in 240:
		_card_step()
	var held_paused: bool = _banner.held() and not _banner.showing() and not _banner.profile.discovered("wy2_pause")
	paused = false
	_card_step()
	_check("WY2 pause holds a card", held_paused and _banner.showing(),
		"after 4 s of paused calm the card was held and unseen (%s); one frame after unpausing it showed (%s)" % [held_paused, _banner.showing()])
	_banner.dismiss(true)

	# One definition of calm: the callout's fight and the card's calm read the same fact.
	_card_calm()
	_fresh()
	var live_threat := _threat()
	_why.step(DT)
	_card_step()
	var agree_live: bool = _why.fight() and not _banner.calm()
	live_threat.free()
	var agree_after := true
	var detail_calm := ""
	var elapsed := 0.0
	for frames in [30, 60, 60, 60]:
		for i in frames:
			_why.step(DT)
			_card_step()
		elapsed += frames * DT
		if _why.fight() == _banner.calm():
			agree_after = false
		detail_calm += " %.1fs:%s/%s" % [elapsed, _why.fight(), _banner.calm()]
	var calm_at_end: bool = not _why.fight() and _banner.calm()
	events.player_hit.emit(1.0, "test")
	var agree_hit: bool = _why.fight() and not _banner.calm()
	_check("WY2 one calm", agree_live and agree_after and calm_at_end and agree_hit,
		"live telegraph agrees (%s); after it ends (fight/calm) %s; calm 3.5 s on (%s); a hit agrees (%s)" % [agree_live, detail_calm, calm_at_end, agree_hit])
	_fresh()
	_card_calm()

	var source := FileAccess.get_file_as_string("res://src/ui/why_callout.gd")
	var literal := RegEx.create_from_string("Color\\(\\s*[-0-9.]+\\s*,\\s*[-0-9.]+\\s*,\\s*[-0-9.]+")
	_check("WY2-7", literal.search(source) == null and not source.contains("Palette."),
		"why_callout.gd holds %s colour literal and %s Palette reference" % ["a" if literal.search(source) != null else "no", "a" if source.contains("Palette.") else "no"])

	print("why_callout_test: %s" % ["FAIL" if _failures > 0 else "PASS"])
	quit(1 if _failures > 0 else 0)
