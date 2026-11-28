extends SceneTree

const ScrapFrame := preload("res://src/ui/scrap_frame.gd")
const UiTokens := preload("res://src/core/ui_tokens.gd")
const Palette := preload("res://src/core/palette.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const ClassCard := preload("res://src/ui/class_card.gd")
const TreeCard := preload("res://src/ui/tree_card.gd")
const ShopTile := preload("res://src/ui/shop_tile.gd")
const ShopCounter := preload("res://src/ui/shop_counter.gd")
const Workshop := preload("res://src/ui/workshop.gd")
const CallerTile := preload("res://src/ui/caller_tile.gd")
const ChoiceButton := preload("res://src/ui/choice_button.gd")
const StartPickCard := preload("res://src/ui/start_pick_card.gd")
const StartPicks := preload("res://src/core/start_picks.gd")
const TreePick := preload("res://src/ui/tree_pick.gd")
const Game := preload("res://src/game.gd")
const T := preload("res://tests/support/t.gd")
const Comfort := preload("res://src/core/comfort.gd")

# The Keeper screens in the Keeper's hand (LEGIBILITY.md section 14.3, ruling ek, unit E2-12):
#   - every frame the pilot cards, the tree pick's cards, Moss's counter and its tiles, and the talk bubble
#     build is a ScrapFrame in the Keeper's hand, and draws; a focus plate draws its edge alone;
#   - what is drawn: a Keeper caller's plate and a start-pick card's tiles are read back from the frames
#     the last draw put down (drawn_frames, drawn_marks), and the next-shift note from the plate the
#     summary builds in a booted game;
#   - colour law, on the colours those frames and gauges actually draw (hex or computed alike): no brass,
#     purple or mint on any of them, a pilot's own colour included (Sable's cards wear her screen colour,
#     class_def.gd SABLE_SCREEN), and every shop tier's frame is lawful on the Keeper's hand; planted
#     brass, purple and mint are caught;
#   - Brindle's call-in plate is the Fleet's hand, stamped, and every caller's name tag holds 4.5:1;
#   - the Keeper screens' scripts name no purple, brass only for Brindle's Fleet call-in plate, mint only
#     as world 3's comic tint, and build no flat plate or generic panel;
#   - with motion on, a Keeper card plate leans and the tree pick's taken card pops; with less motion
#     nothing leans, the taken card holds its size, and Moss's relent and restart come up whole and
#     straight;
#   - every word on the built cards is at the 15 px caption floor or over, and the Keeper's words hold
#     4.5:1 on its fill.

const RECT := Rect2(Vector2(10.0, 10.0), Vector2(340.0, 220.0))
const KEEPER := UiTokens.Hand.KEEPER
# The scripts that draw Keeper screens (screens.gd is read for its Keeper note alone: its run-over and
# Foreman surfaces are the old works' hand).
const KEEPER_FILES := ["class_card.gd", "class_kit.gd", "start_pick_card.gd", "workshop.gd", "tree_pick.gd", "tree_card.gd",
	"shop_counter.gd", "shop_tile.gd", "moss_bubble.gd", "summary_rows.gd", "comic_page.gd", "caller_tile.gd"]
# Mint a Keeper script may name, by file: world 3's comic panel tint, slate with a fifth of mint in it.
const MINT_ALLOWED := {"comic_page.gd": 1}
# Brass a Keeper script may name: Brindle's own call-in plate, which is the Fleet's hand.
const BRASS_ALLOWED := {"caller_tile.gd": 1}

var _t := T.new("keeper_screens_hand_test")
# A booted game, for the surfaces that live in one: the summary's note and Moss's bubble.
var _game


# A run and a profile with the HARD ladder open, enough for a start-pick card to draw its tiles and gauges.
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


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Comfort.reduced_motion = false
	_planted()
	_pilot_cards()
	_tree_cards()
	_shop()
	await _callers()
	await _start_picks()
	await _tip()
	_sources()
	await _motion()
	_words()
	_game.queue_free()
	await _frames(2)
	Comfort.reduced_motion = false
	quit(_t.verdict())


func _frames(count: int) -> void:
	for i in count:
		await process_frame


# Which ruled colour family a colour reads as: mint (press now), brass (the Fleet) or purple (the Kindness).
func _family(c: Color) -> String:
	if c.a <= 0.0:
		return ""
	for pair in [[Palette.ARC, "mint"], [Palette.BRASS, "brass"], [Palette.KINDNESS, "purple"]]:
		if _near(c, pair[0]):
			return pair[1]
	if c.s < 0.3 or c.v < 0.35:
		return ""
	var deg := c.h * 360.0
	if absf(deg - 163.0) < 8.0 and c.s > 0.35:
		return "mint"
	if absf(deg - 44.5) < 7.0 and c.s > 0.5:
		return "brass"
	if absf(deg - 315.0) < 25.0:
		return "purple"
	return ""


func _near(a: Color, b: Color) -> bool:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length() < 0.08


# The faults in one frame: not a ScrapFrame, not in the hand it should be, or a part in a colour that
# hand may not wear. No pilot's colour is let off.
func _faults(box: StyleBox, where: String, which := KEEPER) -> Array:
	if box is StyleBoxEmpty:
		return []
	if box == null or box.get_script() != ScrapFrame:
		return ["%s is not a ScrapFrame" % where]
	var out := []
	if box.hand != which:
		out.append("%s is hand %d" % [where, box.hand])
	for part in box.parts(RECT):
		var family := _family(part.color)
		if (family != "" and not (family == "brass" and which == UiTokens.Hand.FLEET)) or not ScrapFrame.lawful(which, part.color):
			out.append("%s %s is %s (%s)" % [where, part.role, family if family != "" else "unlawful", part.color.to_html(false)])
	return out


# Every stylebox a control and its children wear.
func _boxes(control: Control, where: String) -> Array:
	var out := []
	for state in ["normal", "hover", "pressed", "focus", "disabled", "panel"]:
		if control.has_theme_stylebox_override(state):
			out.append([control.get_theme_stylebox(state), "%s %s" % [where, state]])
	for child in control.get_children():
		# The shared menu choice (choice_button.gd) keeps its own plate on every screen.
		if child is Control and not (child is ChoiceButton):
			out.append_array(_boxes(child, "%s/%s" % [where, child.name]))
	return out


func _planted() -> void:
	for c in [Palette.BRASS, Palette.KINDNESS, Palette.ARC]:
		var box = ScrapFrame.hand_plate(KEEPER, 5)
		box.border_color = c
		_t.check("planted: a Keeper frame edged %s is caught" % c.to_html(false), not _faults(box, "planted").is_empty())
	_t.check("planted: a flat plate is caught", not _faults(StyleBoxFlat.new(), "planted").is_empty())
	_t.check("planted: another hand's frame is caught", not _faults(ScrapFrame.hand_plate(UiTokens.Hand.FLEET, 5), "planted").is_empty())
	_t.eq("planted: copper, sand, bone and charcoal are lawful", [Palette.COPPER, Palette.SAND, Palette.LEDGER_CREAM, Palette.CHARCOAL,
		UiTokens.TEXT, Palette.AMBER, Palette.STEEL].map(_family).filter(func(f): return f != ""), [])


func _pilot_cards() -> void:
	var canvas := RenderingServer.canvas_item_create()
	for def in ClassDef.all():
		var card := ClassCard.new(def, "key_1", 420.0)
		root.add_child(card)
		var faults := []
		var found := _boxes(card, String(def.id))
		for pair in found:
			faults.append_array(_faults(pair[0], pair[1]))
			pair[0].draw(canvas, RECT)
		_t.check("%s's card wears its states and tags in the Keeper's hand" % def.display_name, found.size() >= 5, str(found.size()))
		_t.eq("%s's card frames are the Keeper's and lawful" % def.display_name, faults, [])
		card.set_locked(true, "")
		var locked := []
		for pair in _boxes(card, "%s locked" % def.id):
			locked.append_array(_faults(pair[0], pair[1]))
		_t.eq("%s's locked card stays in the Keeper's hand" % def.display_name, locked, [])
		card.queue_free()
	RenderingServer.free_rid(canvas)


func _tree_cards() -> void:
	var node := {"id": "e2_12_probe", "name": "Probe", "effect": "probe effect", "key": "weapon", "knob": {}}
	for def in ClassDef.all():
		var card = TreeCard.new(node, "key_1", def.color, 2)
		root.add_child(card)
		var faults := []
		for pair in _boxes(card, "%s tree card" % def.id):
			faults.append_array(_faults(pair[0], pair[1]))
		faults.append_array(_faults(card._slot, "%s tree slot" % def.id))
		# The colour the lifted slot's edge, the glyph and the notches take.
		if not ScrapFrame.lawful(KEEPER, card.color) or _family(card.color) != "":
			faults.append("%s tree card's colour is %s" % [def.id, card.color.to_html(false)])
		var ring: StyleBox = card.get_theme_stylebox("focus")
		_t.check("%s's tree focus plate is its edge alone" % def.display_name, ring.bg_color.a == 0.0 and not ring.rivets
			and not ring.halftone and ring.tape < 0.0)
		card.mark_taken()
		faults.append_array(_faults(card.get_theme_stylebox("disabled"), "%s taken" % def.id))
		_t.eq("%s's tree card is the Keeper's and lawful" % def.display_name, faults, [])
		card.queue_free()


func _shop() -> void:
	var faults := []
	var kinds := [{"kind": "shelf", "rarity": "common"}, {"kind": "shelf", "rarity": "rare"}, {"kind": "shelf", "rarity": "relic"},
		{"kind": "shelf", "rarity": "evolved"}, {"kind": "reroll"}, {"kind": "cell", "cells": 1, "cap": 2}, {"kind": "brew"},
		{"kind": "weigh", "mass": 3}, {"kind": "stow"}, {"kind": "pick"}]
	for i in kinds.size():
		var rec: Dictionary = kinds[i].merged({"id": "tile_%d" % i, "price": 4})
		var tile := ShopTile.new(rec)
		faults.append_array(_faults(tile._plate, "tile %s" % rec))
		faults.append_array(_faults(tile._ring, "tile ring %s" % rec))
		_t.check("tile %d's focus ring draws no fill and no fastener" % i, tile._ring.bg_color.a == 0.0 and not tile._ring.rivets)
		tile.free()
	for rung in ShopTile.RARITY:
		if not ScrapFrame.lawful(KEEPER, ShopTile.RARITY[rung]["color"]) or _family(ShopTile.RARITY[rung]["color"]) != "":
			faults.append("the %s tier's frame is %s" % [rung, ShopTile.RARITY[rung]["color"].to_html(false)])
	var counter := ShopCounter.new()
	faults.append_array(_faults(counter._frame, "Moss's counter"))
	_t.check("Moss's counter is taped where it joins the hatch", counter._frame.tape >= 0.0)
	for pair in _boxes(counter, "counter"):
		faults.append_array(_faults(pair[0], pair[1]))
		if pair[1].ends_with(" focus"):
			_t.check("%s is its edge alone" % pair[1], pair[0].bg_color.a == 0.0 and not pair[0].rivets and not pair[0].halftone)
	counter.free()
	var talk = Workshop.TalkButton.new()
	faults.append_array(_faults(talk._bubble, "talk bubble"))
	talk.free()
	_t.eq("Moss's counter, its tiles and the talk bubble are the Keeper's and lawful", faults, [])


# Each caller comes up on a tile and draws; a Keeper's plate is read back from the frames that draw put down.
func _callers() -> void:
	var pilots := ClassDef.all()
	var ids: Array = CallerTile.CALLERS.keys()
	for def in pilots:
		ids.append(String(def.id))
	for id in ids:
		var tile := CallerTile.new()
		tile.pilots = pilots
		root.add_child(tile)
		tile.present(id, "Probe", 1.0)
		await _frames(2)
		var drawn: Array = tile.drawn_frames()
		if tile.hands() in ["keeper", "fleet"]:
			var which := KEEPER if tile.hands() == "keeper" else UiTokens.Hand.FLEET
			var faults := []
			for box in drawn:
				faults.append_array(_faults(box, "%s plate" % id, which))
			_t.check("%s's call-in plate is drawn in its maker's hand (%d)" % [id, which], drawn.size() == 2, str(drawn.size()))
			_t.eq("%s's call-in plate draws only lawful colours" % id, faults, [])
		else:
			_t.eq("%s's call-in plate is the old works' or Moss's own, not a scrap frame" % id, drawn, [])
		var ink: Color = CallerTile.tag_ink(tile.tint())
		_t.check("%s's name tag holds 4.5:1" % id, UiTokens.contrast(ink, tile.tint()) >= 4.5, "%.2f" % UiTokens.contrast(ink, tile.tint()))
		if id == "brindle":
			var plate_rect := Rect2(Vector2.ZERO, Vector2(CallerTile.SIDE, CallerTile.SIDE))
			var stamps: Array = drawn.filter(func(box): return box.parts(plate_rect).any(func(part): return part.role == "stamp"))
			_t.eq("Brindle's call-in plate carries the Fleet's rubber stamp once", stamps.size(), 1)
		tile.queue_free()
	_t.eq("Brindle stays the Fleet's brass", CallerTile.CALLERS["brindle"]["color"], Palette.BRASS)
	_t.check("the pump crew's tag was the short one: charcoal on copper is under 4.5:1", UiTokens.contrast(Palette.CHARCOAL, Palette.COPPER) < 4.5)


# A start-pick card with the ladder open draws three tile plates and the tier gauges; each is read back.
func _start_picks() -> void:
	for def in ClassDef.all():
		var run := FakeRun.new()
		run.class_def = def
		var card := StartPickCard.new()
		card.set_interactive(true)
		root.add_child(card)
		card.show_picks(run, FakeProfile.new())
		await _frames(2)
		var marks: Dictionary = card.drawn_marks()
		var faults := []
		for box in marks.frames:
			faults.append_array(_faults(box, "%s start tile" % def.id))
		var yours: int = marks.gauges.filter(func(c): return c != Palette.HAZARD).size()
		_t.check("%s's start card draws three Keeper tiles and the pilot's own gauges" % def.display_name, marks.frames.size() == StartPicks.OFFERED
			and yours > 0, "%d tiles, %d gauges, %d the pilot's" % [marks.frames.size(), marks.gauges.size(), yours])
		for colour in marks.gauges:
			if _family(colour) != "":
				faults.append("%s gauge is %s (%s)" % [def.id, _family(colour), colour.to_html(false)])
		_t.eq("%s's start card draws only lawful colours" % def.display_name, faults, [])
		card.queue_free()


# The run summary's next-shift note, as a booted game's summary builds it.
func _tip() -> void:
	root.size = Vector2i(1600, 900)
	var game := Game.new()
	game.test_mode = true
	root.add_child(game)
	await _frames(3)
	game.screens._show_tip("probe")
	var note = game.screens._tip
	var box: StyleBox = note.get_theme_stylebox("panel") if note != null else null
	_t.eq("the summary's next-shift note is a lawful Keeper plate", _faults(box, "next-shift note"), [])
	_t.check("the next-shift note is taped up", box != null and box.get_script() == ScrapFrame and box.tape >= 0.0)
	_game = game


func _sources() -> void:
	var bad := []
	for file in KEEPER_FILES:
		var text := FileAccess.get_file_as_string("res://src/ui/" + file)
		_t.check("%s reads" % file, text != "")
		for token in ["Palette.KINDNESS", "StyleBoxFlat.new()", "UiDraw.panel(", "ScrapFrame.plate(", "ScrapFrame.tag("]:
			if text.contains(token):
				bad.append("%s names %s" % [file, token])
		var brass := text.count("Palette.BRASS")
		if brass > int(BRASS_ALLOWED.get(file, 0)):
			bad.append("%s names brass %d times" % [file, brass])
		var mint := text.count("Palette.ARC")
		if mint > int(MINT_ALLOWED.get(file, 0)):
			bad.append("%s names mint %d times" % [file, mint])
	_t.eq("the Keeper screens name no brass, purple, flat plate or bare frame, and mint only as world 3's tint", bad, [])


func _points(box: StyleBox) -> Array:
	var out := []
	for part in box.parts(RECT):
		out.append(part.points)
	return out


func _motion() -> void:
	var leaning := 0
	for serial in 8:
		var box = ClassCard.keeper_plate(Palette.COPPER, serial * 977, 2)
		var level = ClassCard.keeper_plate(Palette.COPPER, serial * 977, 2)
		level.tilt = 0.0
		if _points(box) != _points(level):
			leaning += 1
		Comfort.reduced_motion = true
		_t.eq("serial %d: with less motion a Keeper plate stands straight" % serial, _points(box), _points(level))
		Comfort.reduced_motion = false
	_t.check("with motion on, Keeper plates lean", leaning > 0, "%d of 8" % leaning)
	_t.eq("with less motion the Keeper's frames move without overshoot", (func():
		Comfort.reduced_motion = true
		var trans: int = UiTokens.hand(KEEPER).trans
		Comfort.reduced_motion = false
		return trans).call(), Tween.TRANS_LINEAR)
	for still in [false, true]:
		Comfort.reduced_motion = still
		for record in [{"text": "probe", "relent": true}, {"text": "probe", "restart": true}]:
			var bubble = _game.workshop().bubble
			bubble.beat(record)
			var whole: bool = is_equal_approx(bubble._pop, 1.0) and is_equal_approx(bubble._spin, 0.0)
			_t.check("Moss's %s %s" % ["relent" if record.has("relent") else "restart",
				"comes up whole with less motion" if still else "pops with motion on"], whole == still, "pop %.2f spin %.2f" % [bubble._pop, bubble._spin])
			bubble.hush()
	Comfort.reduced_motion = false
	for still in [false, true]:
		var peak: float = await _taken_pop(still)
		_t.check("the tree pick's taken card %s" % ("holds its size with less motion" if still else "pops with motion on"),
			(peak <= 1.0001) == still, "peak scale %.3f" % peak)
	Comfort.reduced_motion = false


# The largest the taken card grows as the tree pick closes on it.
func _taken_pop(still: bool) -> float:
	var host := Node.new()
	root.add_child(host)
	var pick := TreePick.new()
	host.add_child(pick)
	var nodes := [{"id": "e2_12_a", "name": "Probe A", "effect": "a", "key": "weapon", "knob": {}},
		{"id": "e2_12_b", "name": "Probe B", "effect": "b", "key": "weapon", "knob": {}}]
	Comfort.reduced_motion = false
	pick.open("pylon_engineer", 1, nodes, [], Palette.COPPER)
	await _frames(2)
	var taken: Control = pick.cards()[0]
	Comfort.reduced_motion = still
	pick.close(0)
	# Half a second of the engine's own frame time: the pop and the fade both end inside it.
	var peak := 0.0
	var waited := 0.0
	while waited < 0.5:
		peak = maxf(peak, taken.scale.x)
		await process_frame
		waited += root.get_process_delta_time()
	host.queue_free()
	await process_frame
	return peak


func _labels(node: Node, out: Array) -> void:
	if node is Label:
		out.append(node)
	for child in node.get_children():
		_labels(child, out)


func _words() -> void:
	var small := []
	for def in ClassDef.all():
		var card := ClassCard.new(def, "key_1", 420.0)
		var labels := []
		_labels(card, labels)
		for label in labels:
			var px: int = label.get_theme_font_size("font_size")
			if px < UiTokens.CAPTION:
				small.append("%s %s %d px" % [def.id, label.text.left(20), px])
		card.free()
	_t.eq("every word on a pilot card is at the caption floor or over", small, [])
	var row: Dictionary = UiTokens.hand(KEEPER)
	_t.check("the Keeper's caption is the 15 px floor", row.caption >= 15)
	_t.check("the Keeper's words hold 4.5:1 on its fill", UiTokens.contrast(row.ink, row.fill) >= 4.5 and UiTokens.contrast(row.quiet, row.fill) >= 4.5,
		"ink %.2f quiet %.2f" % [UiTokens.contrast(row.ink, row.fill), UiTokens.contrast(row.quiet, row.fill)])
