extends SceneTree

const ScrapFrame := preload("res://src/ui/scrap_frame.gd")
const UiTokens := preload("res://src/core/ui_tokens.gd")
const UiFonts := preload("res://src/core/ui_fonts.gd")
const Palette := preload("res://src/core/palette.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const BossPlate := preload("res://src/ui/boss_plate.gd")
const LaunchCard := preload("res://src/ui/launch_card.gd")
const ChasePlate := preload("res://src/ui/chase_plate.gd")
const AchievementsPage := preload("res://src/ui/achievements_page.gd")
const StartPickCard := preload("res://src/ui/start_pick_card.gd")
const ShopCounter := preload("res://src/ui/shop_counter.gd")
const ControlsDiagram := preload("res://src/ui/controls_diagram.gd")
const FieldNotes := preload("res://src/ui/field_notes.gd")
const StageModifier := preload("res://src/world/events/stage_modifier.gd")
const DeathCause := preload("res://src/core/death_cause.gd")
const DeathTips := preload("res://src/core/death_tips.gd")
const ShiftBoard := preload("res://src/core/shift_board.gd")
const StartPicks := preload("res://src/core/start_picks.gd")
const Roster := preload("res://src/combat/roster.gd")
const Game := preload("res://src/game.gd")
const T := preload("res://tests/support/t.gd")
const Comfort := preload("res://src/core/comfort.gd")

# The old works' hand on the screens it makes (LEGIBILITY.md section 14.3, ruling ek; unit E2-14):
#   - a Warden's plate (a stage Warden's and a stub boss's) is the old works', with its frame built once and
#     its name measured in the works' face; Brindle's stays the Fleet's and a rogue's the Rogue's; the bar,
#     pips and glyph stand clear of the seam;
#   - the stage card's memo stands on an old-works plate in the works' face, and a cursed run's line, the
#     crew's, stays off it; the card fades in a straight line;
#   - the Foreman's loss memo on the death screen and the summary is an old-works plate between the cause
#     and the crew's note, in the works' face and ink;
#   - the shift board is the one mixed surface: a cast frame, flap rows in the works' mono face that settle
#     in a straight line (at once with less motion), the Keepers' chalk over it, and a three-hole timecard
#     stamped HIRED on a row that signed on a pilot; PAID appears nowhere on it;
#   - the summary's chase plate is a strip of that board: cast frame, flap, chalk;
#   - every old-works frame here has no fastener, no tape and no lean, carries the uranium-green seam, and
#     wears no mint, brass or purple; purple is the Kindness's alone and none of these surfaces is it (the
#     Kindness's own prompt stands in the world, activities.gd);
#   - the works' words hold 4.5:1 on the works' fill and sit at the 15 px caption floor or over;
#   - Sable is off mint on the five screens swept here: the start pick card, the shop counter, the camp's
#     portraits, the controls diagram and the field notes' keys tab.
# Evidence limit: frames are read through their parts and controls through their theme overrides; the
# headless dummy renderer draws no pixels.

const RECT := Rect2(Vector2(10.0, 10.0), Vector2(360.0, 80.0))
const WORKS := UiTokens.Hand.OLD_WORKS
const SURFACES := ["launch_card.gd", "chase_plate.gd", "achievements_page.gd", "boss_plate.gd", "screens.gd"]
const SWEPT := ["start_pick_card.gd", "shop_counter.gd", "customize_page.gd", "controls_diagram.gd", "field_notes.gd"]

var _t := T.new("old_works_screens_hand_test")
# A hand_plate call that passes kindness = true.
var _asks_kindness := RegEx.create_from_string("hand_plate\\([^)]*,[^)]*,\\s*true\\s*\\)")
var _game


class FakePosture extends Node3D:
	var fleet = null

	func fight() -> String:
		return "posture"

	func is_dead() -> bool:
		return false

	func chunks_left() -> int:
		return 4

	func chunk_cracked() -> bool:
		return false

	func staggered() -> bool:
		return false

	func stagger_left() -> float:
		return 1.0

	func posture() -> float:
		return 40.0


class FakeWarden extends FakePosture:
	var family := ""
	var variant := ""


class FakeRogue extends Node3D:
	var row := {"crew": "07"}
	var hp := 1.0
	var max_hp := 2.0

	func is_dead() -> bool:
		return false

	func is_weak() -> bool:
		return false


class FakeRun extends RefCounted:
	var class_def
	var stage := 1
	var start_pick := {"taken": "", "rerolls_left": 1}

	func class_id() -> String:
		return String(class_def.id)

	func start_pick_options() -> Array:
		return StartPicks.ids_for(String(class_def.id)).slice(0, StartPicks.OFFERED)

	func run_tier_open() -> bool:
		return true

	func selected_run_tier() -> int:
		return 0


class FakeProfile extends RefCounted:
	func earned(_id: String) -> bool:
		return true

	func stat(_id: String) -> int:
		return 0


class FakeGame extends RefCounted:
	var run


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Comfort.reduced_motion = false
	_planted()
	await _wardens()
	await _launch_card()
	await _boot()
	await _memo_plates()
	await _shift_board()
	await _chase_plate()
	_kindness_sources()
	await _off_mint()
	_words()
	if _game != null:
		_game.queue_free()
	await _frames(2)
	Comfort.reduced_motion = false
	quit(_t.verdict())


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _near(a: Color, b: Color) -> bool:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length() < 0.08


func _purple(c: Color) -> bool:
	var hue := c.h * 360.0
	return c.a > 0.0 and c.s > 0.25 and hue >= 300.0 and hue <= 330.0


# The faults in an old-works frame: not a ScrapFrame, another hand, a fastener, tape or lean, the wrong seam,
# or a part in a colour the works may not wear (purple only when `kindness`).
func _faults(box, where: String, kindness := false) -> Array:
	if box == null or not (box is StyleBox) or box.get_script() != ScrapFrame:
		return ["%s is not a ScrapFrame" % where]
	var out := []
	if box.hand != WORKS:
		out.append("%s is hand %d" % [where, box.hand])
	if box.rivets or box.tape >= 0.0 or box.tilt != 0.0 or box.halftone:
		out.append("%s has a fastener, tape, halftone or lean" % where)
	var seams := 0
	for part in box.parts(RECT):
		if part.role in ["rivet", "tape", "halftone", "hole"]:
			out.append("%s draws a %s" % [where, part.role])
		if part.role == "seam":
			seams += 1
			var want := Palette.KINDNESS if kindness else Palette.ANCIENT
			if not _near(part.color, want):
				out.append("%s seam is %s" % [where, part.color.to_html(false)])
		if (_purple(part.color) and not kindness) or not ScrapFrame.lawful(WORKS, part.color, kindness):
			out.append("%s %s is %s" % [where, part.role, part.color.to_html(false)])
	if seams != 1:
		out.append("%s draws %d seams" % [where, seams])
	return out


func _planted() -> void:
	_t.check("planted: a Keeper plate is caught (rivets, lean, other hand)", not _faults(ScrapFrame.hand_plate(UiTokens.Hand.KEEPER, 3), "keeper").is_empty())
	_t.check("planted: the Kindness's purple seam on an ordinary surface is caught",
		not _faults(ScrapFrame.hand_plate(WORKS, 3, true), "kindness").is_empty())
	_t.eq("the Kindness's own plate is lawful only as the Kindness", _faults(ScrapFrame.hand_plate(WORKS, 3, true), "kindness", true), [])
	var leaning = ScrapFrame.hand_plate(WORKS, 3)
	leaning.tilt = 0.02
	_t.check("planted: a leaning old-works plate is caught", not _faults(leaning, "leaning").is_empty())
	_t.check("planted: a flat plate is caught", not _faults(StyleBoxFlat.new(), "flat").is_empty())
	_t.check("planted: hue 315 reads as purple and uranium green does not", _purple(Palette.KINDNESS) and not _purple(Palette.ANCIENT))
	_t.check("planted: a plate that asks for the Kindness's seam is caught, a works face is not",
		_asks_kindness.search("ScrapFrame.hand_plate(UiTokens.Hand.OLD_WORKS, SERIAL, true)") != null
		and _asks_kindness.search("UiFonts.face(UiTokens.Hand.OLD_WORKS, true)") == null)


func _plate(body: Node3D) -> Control:
	root.add_child(body)
	var plate = BossPlate.new()
	plate.set_process(false)
	root.add_child(plate)
	plate.bind(body)
	return plate


func _drop(plate: Control, body: Node3D) -> void:
	plate.unbind()
	plate.free()
	body.free()


func _works_width(words: String, px: int) -> float:
	return UiFonts.face(WORKS).get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x


func _wardens() -> void:
	for meta in ["", "Stub Boss"]:
		var warden := FakeWarden.new()
		warden.family = Roster.REACTOR
		if meta != "":
			warden.set_meta("plate_name", meta)
		var plate = _plate(warden)
		var label := "a stub boss's Warden" if meta != "" else "a stage Warden"
		_t.eq("%s's plate is the old works' hand" % label, plate.hand(), WORKS)
		var box = plate.frame_box()
		_t.eq("%s's frame is a lawful old-works plate" % label, _faults(box, label), [])
		_t.check("%s's frame is built once, not every draw" % label, box != null and plate.frame_box() == box)
		var name: String = plate.plate_name()
		_t.check("%s's name is measured in the works' face and ends a gap before its pips" % label,
			_works_width(name, BossPlate.FONT) + BossPlate.GAP <= plate.name_width() + 0.01, "%s %.0f vs %.0f" % [name, _works_width(name, BossPlate.FONT), plate.name_width()])
		var hits := _seam_hits(plate, box)
		_t.eq("%s's bar, pips and glyph stand clear of the seam" % label, hits, [])
		plate.queue_redraw()
		await _frames(1)
		_drop(plate, warden)
	var hull := FakePosture.new()
	var fleet = _plate(hull)
	_t.eq("Brindle's plate stays the Fleet's", fleet.hand(), UiTokens.Hand.FLEET)
	_drop(fleet, hull)
	var machine := FakeRogue.new()
	var rogue = _plate(machine)
	_t.eq("a rogue's plate stays the Rogue's", rogue.hand(), UiTokens.Hand.ROGUE)
	_drop(rogue, machine)
	var empty = BossPlate.new()
	_t.check("an unbound plate is in no hand and has no frame", empty.hand() == BossPlate.NO_HAND and empty.frame_box() == null)
	empty.free()


# The plate's marks as _draw lays them out, and which of them the seam's strokes cross.
func _seam_hits(plate, box) -> Array:
	var mid := BossPlate.SIZE.y * 0.5
	var marks := {}
	var x: float = BossPlate.MARGIN + plate.name_width()
	for i in plate.pips().size():
		marks["pip %d" % i] = Rect2(Vector2(x, mid - BossPlate.PIP * 0.5), Vector2(BossPlate.PIP, BossPlate.PIP))
		x += BossPlate.PIP + BossPlate.PIP_GAP
	x += BossPlate.GAP - BossPlate.PIP_GAP
	var right: float = plate.size.x - BossPlate.MARGIN - plate.stamp_room()
	marks["bar"] = Rect2(Vector2(x, mid - BossPlate.BAR_HEIGHT * 0.5), Vector2(right - BossPlate.GLYPH - BossPlate.GAP - x, BossPlate.BAR_HEIGHT))
	marks["glyph"] = Rect2(Vector2(right - BossPlate.GLYPH, mid - BossPlate.GLYPH * 0.5), Vector2(BossPlate.GLYPH, BossPlate.GLYPH))
	var out := []
	for part in box.parts(Rect2(Vector2.ZERO, Vector2(plate.size.x, BossPlate.SIZE.y))):
		if part.role != "seam":
			continue
		for i in part.points.size() - 1:
			var stroke := Rect2(part.points[i], Vector2.ZERO).expand(part.points[i + 1]).grow(part.width * 0.5)
			for id in marks:
				if marks[id].intersects(stroke) and not out.has(id):
					out.append(id)
	return out


func _launch_card() -> void:
	var card = LaunchCard.new()
	root.add_child(card)
	var memo := String(StageModifier.NOMINAL[0])
	card.show_card("obj_beacon", "Spillway", Palette.SAND, memo)
	_t.eq("the stage card's memo is the whole line", card.memo_text(), memo)
	_t.eq("the memo plate is a lawful old-works plate", _faults(card.memo_box(), "stage card memo"), [])
	var size: Vector2 = card.memo_size()
	_t.check("the memo plate is sized to the words in the works' face",
		is_equal_approx(size.x, _works_width(memo, LaunchCard.LINE_FONT) + LaunchCard.MEMO_PAD.x * 2.0), "%.1f" % size.x)
	_t.check("the card makes room for the plate", card.custom_minimum_size.y >= LaunchCard.ICON + 8.0 + LaunchCard.LINE_GAP + size.y)
	_t.check("the memo's words sit at the caption floor or over", LaunchCard.LINE_FONT >= UiTokens.CAPTION)
	# The fade is a straight line: halfway through the fade-in the card is half up.
	card.modulate.a = 0.0
	card.show_card("obj_beacon", "Spillway", Palette.SAND, memo)
	card._tween.custom_step(LaunchCard.FADE_IN * 0.5)
	_t.near("halfway through its fade the card is half up (a straight line)", card.modulate.a, 0.5, 0.05)
	var cursed := "%s%s%s" % [StageModifier.caption(StageModifier.CURSE), LaunchCard.SEPARATOR, memo]
	card.show_card("obj_beacon", "Spillway", Palette.SAND, cursed)
	var voices: Dictionary = LaunchCard.voices(cursed)
	_t.check("a cursed stage card keeps the crew's line off the works' plate", voices.crew == StageModifier.caption(StageModifier.CURSE) and voices.memo == memo,
		str(voices))
	card.show_card("obj_beacon", StageModifier.CURSE.word, Palette.SAND, StageModifier.CURSE.line)
	_t.eq("the cursed run's own card has no memo plate", card.memo_size(), Vector2.ZERO)
	await _frames(1)
	card.queue_free()


func _boot() -> void:
	root.size = Vector2i(1600, 900)
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	await _frames(3)


func _memo_plates() -> void:
	var screens = _game.screens
	var flow = _game.flow
	flow.death_cause = "Scrapped by the Warden."
	flow.death_tip = String(DeathTips.ROWS["warden"])
	screens._on_flow_changed("dead")
	await _frames(2)
	var memo := DeathCause.memo(_game.run.run_seed, _game.run.stage)
	_t.eq("the death screen's memo plate holds the Foreman's memo", screens.memo_text(), memo)
	var said: PackedStringArray = screens.said_body().split("\n")
	_t.check("the death screen reads cause, memo, then the crew's note", said.size() == 3 and said[0] == flow.death_cause and said[1] == memo
		and said[2] == DeathTips.shown(flow.death_tip), " | ".join(said))
	var plate: PanelContainer = screens.memo_plate()
	_t.eq("the memo plate is a lawful old-works plate", _faults(plate.get_theme_stylebox("panel"), "run-over memo"), [])
	var words: Label = plate.get_child(0)
	var ink: Color = UiTokens.HANDS[WORKS].ink
	_t.check("the memo is set in the works' face and ink", words.get_theme_font("font") == UiFonts.face(WORKS) and words.get_theme_color("font_color") == ink)
	_t.check("the memo's words sit at the caption floor or over", words.get_theme_font_size("font_size") >= UiTokens.CAPTION)
	_t.check("the memo plate stands between the cause and the note on screen", plate.is_visible_in_tree()
		and plate.get_global_rect().position.y >= screens._body.get_global_rect().end.y
		and screens._body_tail.get_global_rect().position.y >= plate.get_global_rect().end.y,
		"body to %.0f, memo %s, note from %.0f" % [screens._body.get_global_rect().end.y, plate.get_global_rect(), screens._body_tail.get_global_rect().position.y])
	flow.death_tip = ""
	screens._on_flow_changed("dead")
	_t.check("with no crew note the Foreman logs nothing and no plate shows", screens.memo_text() == "" and not plate.is_visible_in_tree(), screens.said_body())
	flow.death_cause = ""


func _shift_board() -> void:
	var profile = _game.ctx.profile
	for rung in ShiftBoard.RUNGS.values():
		if String(rung.stamp) == "HIRED":
			profile.earn(String(rung.when.earned), 1700000000)
	var page = AchievementsPage.new()
	root.add_child(page)
	Comfort.reduced_motion = false
	page.refresh(profile, null)
	var frame: PanelContainer = page.get_node("ShiftBoardFrame")
	_t.eq("the shift board's frame is a lawful old-works plate", _faults(frame.get_theme_stylebox("panel"), "shift board"), [])
	var board: Node = frame.get_node("ShiftBoard")
	var flaps: Array = [board.get_node("Count"), board.get_node("Card")]
	var chalk: Label = board.get_node("Next")
	for flap in flaps:
		_t.check("%s is a flap row in the works' mono face on a flap cell" % flap.name, flap.get_theme_font("font") == UiFonts.face(WORKS, true)
			and flap.has_theme_stylebox_override("normal") and flap.get_theme_color("font_color") == UiTokens.HANDS[WORKS].ink)
		var cell: StyleBoxFlat = flap.get_theme_stylebox("normal")
		_t.check("%s's words hold 4.5:1 on its cell" % flap.name, UiTokens.contrast(UiTokens.HANDS[WORKS].ink, cell.bg_color) >= 4.5,
			"%.2f" % UiTokens.contrast(UiTokens.HANDS[WORKS].ink, cell.bg_color))
		var font: Font = flap.get_theme_font("font")
		var missing := Array(flap.text.split("")).filter(func(ch: String): return ch != "" and not font.has_char(ch.unicode_at(0)))
		_t.eq("%s's face has every glyph it shows" % flap.name, missing, [])
	_t.check("the next rung is the Keepers' chalk over the board", chalk.get_theme_font("font") == UiFonts.face(UiTokens.Hand.KEEPER)
		and chalk.get_theme_color("font_color") == UiTokens.HANDS[UiTokens.Hand.KEEPER].ink and not chalk.has_theme_stylebox_override("normal"))
	_t.check("the chalk holds 4.5:1 on the cast fill", UiTokens.contrast(UiTokens.HANDS[UiTokens.Hand.KEEPER].ink, UiTokens.HANDS[WORKS].fill) >= 4.5)
	# The flaps settle in a straight line: halfway through, the first row shows half its letters.
	_t.check("with motion on the flaps start unsettled", flaps[0].visible_ratio == 0.0 and page._flaps != null)
	page._flaps.custom_step(AchievementsPage.FLAP_SECONDS * 0.5)
	_t.near("halfway through, the first flap row is half settled (a straight line)", flaps[0].visible_ratio, 0.5, 0.05)
	page._flaps.custom_step(AchievementsPage.FLAP_SECONDS * 2.0)
	_t.check("then every flap row stands settled", flaps.all(func(f): return f.visible_ratio == 1.0))
	Comfort.reduced_motion = true
	page.refresh(profile, null)
	var settled := [frame.get_node("ShiftBoard/Count"), frame.get_node("ShiftBoard/Card")]
	_t.check("with less motion the flaps stand settled at once", settled.all(func(f): return f.visible_ratio == 1.0) and page._flaps == null)
	Comfort.reduced_motion = false
	var carded := []
	var stamped := []
	for id in page.rows:
		var row: Control = page.rows[id]
		if row.has_node("Timecard"):
			carded.append(id)
	for rung in ShiftBoard.RUNGS.values():
		if String(rung.stamp) == "HIRED":
			stamped.append(String(rung.when.earned))
	carded.sort()
	stamped.sort()
	_t.eq("every row that signed on a pilot, and only those, carries a HIRED timecard", carded, stamped)
	var texts := []
	_texts(page, texts)
	_t.check("PAID is Tally's alone: the board never says it", not texts.any(func(s: String): return s.contains("PAID")) and AchievementsPage.HIRED == "HIRED")
	page.queue_free()
	await _frames(1)


func _texts(node: Node, out: Array) -> void:
	if node is Label:
		out.append((node as Label).text)
	for child in node.get_children():
		_texts(child, out)


func _chase_plate() -> void:
	var read := ChasePlate.reading(_game.ctx.profile, 1, func(_id): return false)
	_t.check("a profile with rungs left shows the chase plate", ChasePlate.shows(read) and String(read.next) != "", str(read))
	var plate = ChasePlate.new(read)
	root.add_child(plate)
	_t.eq("the chase plate is a lawful old-works plate", _faults(plate.get_theme_stylebox("panel"), "chase plate"), [])
	var flap: Label = plate.find_child("Flap", true, false)
	var chalk: Label = plate.find_child("Chalk", true, false)
	_t.check("the rung's name is a flap in the works' mono face", flap != null and flap.get_theme_font("font") == UiFonts.face(WORKS, true)
		and flap.has_theme_stylebox_override("normal"))
	_t.check("what to do is the Keepers' chalk", chalk != null and chalk.get_theme_font("font") == UiFonts.face(UiTokens.Hand.KEEPER))
	_t.check("the flap starts unsettled with motion on", flap.visible_ratio == 0.0 and plate._settling != null)
	plate._settling.custom_step(ChasePlate.FLAP_SECONDS * 0.5)
	_t.near("halfway through, the flap is half settled (a straight line)", flap.visible_ratio, 0.5, 0.05)
	plate.queue_free()
	Comfort.reduced_motion = true
	var still = ChasePlate.new(read)
	root.add_child(still)
	var still_flap: Label = still.find_child("Flap", true, false)
	_t.check("with less motion the flap stands settled at once", still_flap.visible_ratio == 1.0 and still._settling == null)
	still.queue_free()
	Comfort.reduced_motion = false
	await _frames(1)


# None of these surfaces is the Kindness, so none names its purple or asks for its seam.
func _kindness_sources() -> void:
	var bad := []
	for file in SURFACES:
		var text := FileAccess.get_file_as_string("res://src/ui/" + file)
		_t.check("%s reads" % file, text != "")
		for token in ["Palette.KINDNESS", "kindness_seam"]:
			if text.contains(token):
				bad.append("%s names %s" % [file, token])
		if _asks_kindness.search(text) != null:
			bad.append("%s asks for the Kindness's seam" % file)
		if text.contains("\"PAID\""):
			bad.append("%s says PAID" % file)
	_t.eq("no old-works surface here names the Kindness's purple, and none says PAID", bad, [])


func _off_mint() -> void:
	var sable := ClassDef.by_id("pylon_engineer")
	_t.check("Sable's pilot colour is mint and her screen colour is not", _near(sable.color, Palette.ARC) and ClassDef.screen_color(sable.color) == ClassDef.SABLE_SCREEN)
	var run := FakeRun.new()
	run.class_def = sable
	var card = StartPickCard.new()
	root.add_child(card)
	card.show_picks(run, FakeProfile.new())
	_t.eq("Sable's start pick card wears her screen colour", card._color, ClassDef.SABLE_SCREEN)
	card.queue_free()
	var fake := FakeGame.new()
	fake.run = run
	var counter = ShopCounter.new()
	counter.game = fake
	_t.eq("Sable's shop counter tints with her screen colour", counter._class_color(), ClassDef.SABLE_SCREEN)
	counter.free()
	var tones := ControlsDiagram.entries(sable).values().filter(func(e): return e.lit).map(func(e): return e.tone)
	_t.check("Sable's controls diagram keys wear her screen colour", not tones.is_empty() and tones.all(func(c): return c == ClassDef.SABLE_SCREEN), str(tones))
	var notes = FieldNotes.new()
	var held = _game.run.class_def
	_game.run.class_def = sable
	notes.game = _game
	_t.eq("Sable's field notes keys tab wears her screen colour", notes._tab_color("keys"), ClassDef.SABLE_SCREEN)
	_game.run.class_def = held
	notes.free()
	var custom = _game.screens._camp.customize
	custom.open(_game.ctx.profile)
	await _frames(2)
	var ring: StyleBoxFlat = custom._portraits["pylon_engineer"].get_theme_stylebox("normal")
	var open_pilot: bool = "pylon_engineer" in custom._pilots
	_t.check("Sable's camp portrait ring wears her screen colour (or the locked cable)", ring.bg_color == (ClassDef.SABLE_SCREEN if open_pilot else Palette.CABLE),
		"%s, open %s" % [ring.bg_color.to_html(false), open_pilot])
	var raw := []
	for file in SWEPT:
		var text := FileAccess.get_file_as_string("res://src/ui/" + file)
		for line in text.split("\n"):
			var code := line.strip_edges()
			if code.begins_with("#") or code.contains("screen_color("):
				continue
			if code.contains("class_def.color") or (file != "customize_page.gd" and code.contains("def.color")):
				raw.append("%s: %s" % [file, code])
	_t.eq("the swept screens draw no raw pilot colour (the camp's 3D paint keeps Sable's own)", raw, [])


func _words() -> void:
	var row: Dictionary = UiTokens.hand(WORKS)
	_t.check("the works' caption is the 15 px floor", row.caption >= UiTokens.CAPTION)
	_t.check("the works' words hold 4.5:1 on its fill", UiTokens.contrast(row.ink, row.fill) >= 4.5 and UiTokens.contrast(row.quiet, row.fill) >= 4.5,
		"ink %.2f quiet %.2f" % [UiTokens.contrast(row.ink, row.fill), UiTokens.contrast(row.quiet, row.fill)])
	_t.check("the works move in straight lines, with or without less motion", row.trans == Tween.TRANS_LINEAR and row.tilt == 0.0)
	_t.check("the boss plate's name and the stage card's memo are at the caption floor or over", BossPlate.FONT >= UiTokens.CAPTION and LaunchCard.LINE_FONT >= UiTokens.CAPTION)
