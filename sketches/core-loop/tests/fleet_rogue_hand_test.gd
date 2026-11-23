extends SceneTree

const BossPlate := preload("res://src/ui/boss_plate.gd")
const ScrapFrame := preload("res://src/ui/scrap_frame.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const Palette := preload("res://src/core/palette.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Roster := preload("res://src/combat/roster.gd")
const Rogue := preload("res://src/combat/rogue.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")
const T := preload("res://tests/support/t.gd")

# The Fleet's and the Rogues' hands on the boss plate (LEGIBILITY.md section 14.3, ruling ek):
#   - Brindle's hull is drawn in the Fleet's hand: a brass bezel on iron oxide with one notched corner,
#     his two-word name in the Fleet's words face, every frame colour lawful for the Fleet; on the real
#     arena hull too, as the HUD seats it;
#   - a stage Warden and a stub boss's Warden keep the HUD panel they have always worn (no hand frame),
#     with the same name and pips;
#   - a rogue machine is drawn in a Rogue's hand: stencil ticks on near black, its crew number in the
#     Rogue face and no words, no pips, its health on the bar, the open glyph only while it is vented;
#     every rogue row has a crew number;
#   - neither frame wears mint or purple, no mark the plate draws on either is purple (hue 300 to 330),
#     their ink holds 4.5:1 on their fill, and their type is at or above the 15 px caption floor;
#   - with less motion both frames draw the same parts (nothing leans);
#   - the Keeper's first-run callouts and the threat page stay the Keeper's: no brass, no Fleet or
#     Rogue frame, no Kindness purple.
# Evidence limit: the plate is read through its accessors and its frame's parts, not its pixels; the
# headless dummy renderer draws none. The plate draws once in the tree so its draw path runs.

const RECT := Rect2(Vector2.ZERO, Vector2(420.0, 44.0))


class FakePosture extends Node3D:
	var fleet = null
	var dead := false
	var open := false

	func fight() -> String:
		return "posture"

	func is_dead() -> bool:
		return dead

	func chunks_left() -> int:
		return 3

	func chunk_cracked() -> bool:
		return false

	func staggered() -> bool:
		return open

	func stagger_left() -> float:
		return 1.0

	func posture() -> float:
		return 40.0


class FakeWarden extends FakePosture:
	var family := ""
	var variant := ""


class FakeRogue extends Node3D:
	var row := {}
	var hp := 320.0
	var max_hp := 640.0
	var dead := false
	var vented := false

	func is_dead() -> bool:
		return dead

	func is_weak() -> bool:
		return vented


var _t := T.new("fleet_rogue_hand_test")
var _game


func _initialize() -> void:
	UiTokens.reduced_motion = false
	_fleet_plate()
	_warden_plates()
	_rogue_plate()
	_colour_law()
	_reduced_motion()
	_keeper_stays_keeper()
	UiTokens.reduced_motion = false
	_run()


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


func _roles(box: StyleBox, rect := RECT) -> Array:
	var out := []
	for part in box.parts(rect):
		out.append(part.role)
	return out


func _fleet_plate() -> void:
	var hull := FakePosture.new()
	var plate = _plate(hull)
	_t.eq("Brindle's plate is the Fleet's hand", plate.hand(), UiTokens.Hand.FLEET)
	var box: StyleBox = plate.frame_box()
	var row: Dictionary = UiTokens.HANDS[UiTokens.Hand.FLEET]
	_t.check("Brindle's frame is a Fleet plate", box != null and box.hand == UiTokens.Hand.FLEET)
	_t.eq("Brindle's bezel is brass", box.border_color, Palette.BRASS)
	_t.eq("Brindle's plate is iron oxide", box.bg_color, Color(row.fill, UiTokens.PLATE_ALPHA))
	var parts: Array = box.parts(Rect2(Vector2.ZERO, plate.size))
	_t.eq("Brindle's card has one notched corner (six corners)", parts[0].points.size(), 6)
	_t.check("Brindle's card has an inner bezel", _roles(box).has("bezel"), str(_roles(box)))
	var bad := []
	for part in parts:
		if not ScrapFrame.lawful(UiTokens.Hand.FLEET, part.color):
			bad.append(part.role)
	_t.check("every colour on Brindle's frame is lawful for the Fleet", bad.is_empty(), str(bad))
	_t.eq("Brindle's plate says his two-word name and nothing else", plate.drawn_words(), ["Admiral", "Brindle"])
	_t.eq("Brindle's plate draws no number", plate.drawn_number(), "")
	_t.eq("Brindle's plate keeps four pips", plate.pips().size(), 4)
	_t.check("Brindle's phase colour is brass, lawful on his frame", ScrapFrame.lawful(UiTokens.Hand.FLEET, BossPlate.phase_color()))
	_drop(plate, hull)


func _warden_plates() -> void:
	var warden := FakeWarden.new()
	warden.family = Roster.REACTOR
	var plate = _plate(warden)
	_t.eq("a stage Warden's plate is in no hand", plate.hand(), BossPlate.NO_HAND)
	_t.check("a stage Warden's plate wears the HUD panel, no hand frame", plate.frame_box() == null)
	_t.eq("a stage Warden's plate keeps its family name", plate.plate_name(), Roster.warden_name(Roster.REACTOR, ""))
	_t.eq("a stage Warden's plate keeps four pips", plate.pips().size(), 4)
	_t.eq("a stage Warden's glyph is the posture step", plate.glyph_id(), "posture_step")
	_drop(plate, warden)
	var stub := FakeWarden.new()
	stub.family = Roster.REACTOR
	stub.set_meta("plate_name", "Stub Boss")
	plate = _plate(stub)
	_t.eq("a stub boss's Warden is in no hand", plate.hand(), BossPlate.NO_HAND)
	_t.eq("a stub boss's Warden keeps its row's name", plate.plate_name(), "Stub Boss")
	_drop(plate, stub)


func _rogue_plate() -> void:
	var missing := []
	for kind in Rogue.ROWS:
		if String(Rogue.ROWS[kind].get("crew", "")) == "":
			missing.append(kind)
	_t.check("every rogue row has a crew number to stencil", missing.is_empty(), str(missing))
	var machine := FakeRogue.new()
	machine.row = Rogue.ROWS["rogue_crane"]
	var plate = _plate(machine)
	var crew := String(Rogue.ROWS["rogue_crane"]["crew"])
	_t.check("a rogue machine's plate is up", plate.active())
	_t.eq("a rogue machine's plate is the Rogue's hand", plate.hand(), UiTokens.Hand.ROGUE)
	_t.eq("a Rogue's plate says no words", plate.drawn_words(), [])
	_t.eq("a Rogue's plate stencils its crew number", plate.drawn_number(), crew)
	_t.check("the crew number is all digits", crew.is_valid_int(), crew)
	_t.check("the number is set in the Rogue face", BossPlate._stencil_face() == UiFonts.face(UiTokens.Hand.ROGUE, true))
	_t.eq("a Rogue's plate sets no pips", plate.pips().size(), 0)
	_t.near("a Rogue's bar is its health", plate.bar_fraction(), 0.5)
	_t.eq("a Rogue between vents shows no glyph", plate.glyph_id(), "")
	machine.vented = true
	_t.eq("a vented Rogue shows the open glyph", plate.glyph_id(), "open")
	_t.eq("a vented Rogue's bar is the open colour", plate.bar_color(), BossPlate.bar_color_for(true))
	var box: StyleBox = plate.frame_box()
	var roles := _roles(box)
	_t.check("a Rogue's frame is corner ticks with no edge line", box.hand == UiTokens.Hand.ROGUE and roles.has("tick") and not roles.has("edge"), str(roles))
	_t.eq("a Rogue's plate is near black", box.bg_color, Color(UiTokens.HANDS[UiTokens.Hand.ROGUE].fill, UiTokens.PLATE_ALPHA))
	_t.check("a Rogue's plate asks for less room than a Warden's, with none for pips",
		plate.rest_size().x < BossPlate.SIZE.x and plate.custom_minimum_size == plate.rest_size(), str(plate.rest_size()))
	machine.dead = true
	_t.check("a dead Rogue's plate is down", not plate.active() and plate.drawn_number() == "")
	_drop(plate, machine)


func _purple(color: Color) -> bool:
	var hue := color.h * 360.0
	return color.s > 0.25 and hue >= 300.0 and hue <= 330.0


func _colour_law() -> void:
	var marks := [EventKinds.role_color("neutral"), BossPlate.bar_color_for(false), BossPlate.bar_color_for(true),
		BossPlate.crack_color_for(true), BossPlate.phase_color()]
	for hand in [UiTokens.Hand.FLEET, UiTokens.Hand.ROGUE]:
		var label := "the Fleet" if hand == UiTokens.Hand.FLEET else "a Rogue"
		var row: Dictionary = UiTokens.HANDS[hand]
		var frame: StyleBox = ScrapFrame.hand_plate(hand, BossPlate.SERIAL)
		var bad := []
		for part in frame.parts(RECT):
			if _purple(part.color) or ScrapFrame._near(part.color, Palette.ARC) or ScrapFrame._near(part.color, Palette.KINDNESS):
				bad.append(part.role)
		_t.check("%s's frame wears no mint and no purple" % label, bad.is_empty(), str(bad))
		var purple := marks.filter(func(c: Color): return _purple(c))
		_t.check("no mark on %s's plate is purple" % label, purple.is_empty(), str(purple))
		_t.check("%s's ink holds 4.5:1 on its fill" % label, UiTokens.contrast(row.ink, row.fill) >= 4.5,
			"%.2f" % UiTokens.contrast(row.ink, row.fill))
	_t.check("the plate's name and stencil are at or above the caption floor", BossPlate.FONT >= UiTokens.CAPTION and BossPlate.STENCIL >= UiTokens.CAPTION)


func _reduced_motion() -> void:
	for hand in [UiTokens.Hand.FLEET, UiTokens.Hand.ROGUE]:
		var frame: StyleBox = ScrapFrame.hand_plate(hand, BossPlate.SERIAL)
		UiTokens.reduced_motion = false
		var moving: Array = frame.parts(RECT)
		UiTokens.reduced_motion = true
		var still: Array = frame.parts(RECT)
		var same := moving.size() == still.size()
		for i in mini(moving.size(), still.size()):
			same = same and moving[i].points == still[i].points
		_t.check("hand %d's plate draws the same with less motion: nothing leans" % hand, same)
	UiTokens.reduced_motion = false


func _keeper_stays_keeper() -> void:
	for path in ["res://src/ui/callouts.gd", "res://src/ui/threat_sheet.gd"]:
		var source := FileAccess.get_file_as_string(path)
		_t.check("%s is readable" % path.get_file(), source.length() > 0)
		var found := []
		for token in ["BRASS", "KINDNESS", "Hand.FLEET", "Hand.ROGUE", "Hand.OLD_WORKS"]:
			if source.contains(token):
				found.append(token)
		_t.check("%s stays the Keeper's: no brass, purple or other hand" % path.get_file(), found.is_empty(), str(found))
	var bad := []
	for id in ["callout_scrap", "callout_warden", "callout_gates", "callout_notes"]:
		var color: Color = EventKinds.UI_ROWS[id]["color"]
		if not ScrapFrame.lawful(UiTokens.Hand.KEEPER, color):
			bad.append(id)
	_t.check("every first-run callout's colour is lawful for the Keeper (no brass, mint or purple)", bad.is_empty(), str(bad))


# A Rogue's plate draws once in the tree; then the real arena: the HUD seats the plate on Brindle's
# hull in the Fleet's hand, and it draws.
func _run() -> void:
	var machine := FakeRogue.new()
	machine.row = Rogue.ROWS["rogue_crane"]
	machine.vented = true
	var rogue_plate = _plate(machine)
	rogue_plate.queue_redraw()
	await process_frame
	_t.check("a Rogue's plate draws in the tree", rogue_plate.is_visible_in_tree() and rogue_plate.active())
	_drop(rogue_plate, machine)
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	await physics_frame
	_game.ctx.spawner = _game.combat
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	Harness.start_run(_game)
	Harness.enter(_game, Vector3(18.0, 0.0, 0.0))
	await physics_frame
	await physics_frame
	var plate = _game.hud.boss_plate
	_t.check("the HUD seats a plate on Brindle's hull", plate != null and plate.active())
	if plate != null:
		_t.eq("the seated hull plate is the Fleet's hand", plate.hand(), UiTokens.Hand.FLEET)
		_t.eq("the seated hull plate says his name", plate.drawn_words(), ["Admiral", "Brindle"])
		plate.queue_redraw()
		await process_frame
		_t.check("the seated hull plate draws in the tree", plate.is_visible_in_tree())
	quit(_t.verdict())
