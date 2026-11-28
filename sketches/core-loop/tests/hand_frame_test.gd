extends SceneTree

const ScrapFrame := preload("res://src/ui/scrap_frame.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const Palette := preload("res://src/core/palette.gd")
const T := preload("res://tests/support/t.gd")
const Comfort := preload("res://src/core/comfort.gd")

# The four hands (LEGIBILITY.md section 14.3, ruling ek), drawn by ScrapFrame from UiTokens.HANDS:
#   - every hand builds a plate and a tag and draws them;
#   - the old works draw no rivet, tape, halftone or hole and never lean, whatever the box is told;
#   - colour law: no hand's frame is mint, only the Fleet's is brass, and only the Kindness's old-works
#     seam is purple; lawful() refuses each, with planted cases;
#   - every hand's words and quiet words hold 4.5:1 on its fill, its edge 3:1, and its smallest word is
#     the 15 px caption floor;
#   - plate() and tag() still draw the Keeper's frame exactly as before;
#   - with less motion nothing leans and nothing overshoots;
#   - the Keeper and the old works set their words in their own vendored display faces (Archivo Black and
#     IBM Plex Sans SemiBold), each distinct from Noto and from each other, with every printable ASCII
#     glyph and the typographic marks the cards use, a caption line at least the 15 px floor tall and at
#     most 15% wider than Noto Bold's; the Fleet keeps Noto Sans Bold, the Rogues Noto Sans Mono Bold, and every hand's
#     numbers the mono face;
#   - vendored() fails when any one face falls back (planted), and UiFonts.reset_for_tests() empties the
#     cache and the next load gives the same faces.

const RECT := Rect2(Vector2(40.0, 30.0), Vector2(360.0, 220.0))
const HANDS := [UiTokens.Hand.KEEPER, UiTokens.Hand.FLEET, UiTokens.Hand.OLD_WORKS, UiTokens.Hand.ROGUE]
const NAMES := ["keeper", "fleet", "old works", "rogue"]
# A Keeper card's caption (ART-DIRECTION-PACK2 sheet 09), and how much wider than Noto Bold a display face may set
# it, so a card measured for Noto overruns by no more than this when its words move to the hand's face.
const CAPTION_LINE := "Charges trigger from two metres away"
const WIDER := 1.15

var _t := T.new("hand_frame_test")


func _initialize() -> void:
	Comfort.reduced_motion = false
	_every_hand_draws()
	_old_works_has_no_fasteners()
	_colour_law()
	_contrast()
	_keeper_compat()
	_reduced_motion()
	_fonts()
	Comfort.reduced_motion = false
	quit(_t.verdict())


func _roles(box: StyleBox, rect := RECT) -> Array:
	var out := []
	for part in box.parts(rect):
		out.append(part.role)
	return out


func _every_hand_draws() -> void:
	_t.eq("one token row per hand", UiTokens.HANDS.size(), UiTokens.Hand.size())
	var canvas := RenderingServer.canvas_item_create()
	for hand in HANDS:
		var plate: StyleBox = ScrapFrame.hand_plate(hand, 17)
		var tag: StyleBox = ScrapFrame.hand_tag(hand, 17)
		_t.check("%s plate is its hand" % NAMES[hand], plate.hand == hand and tag.hand == hand)
		var roles := _roles(plate)
		_t.check("%s plate fills and frames" % NAMES[hand], roles.has("fill") and (roles.has("edge") or roles.has("tick")), str(roles))
		_t.check("%s tag fills and frames" % NAMES[hand], _roles(tag, Rect2(0, 0, 120, 26)).has("fill"))
		plate.draw(canvas, RECT)
		tag.draw(canvas, Rect2(0, 0, 120, 26))
		_t.eq("%s plate fill is its token" % NAMES[hand], plate.bg_color, Color(UiTokens.HANDS[hand].fill, UiTokens.PLATE_ALPHA))
	RenderingServer.free_rid(canvas)
	var fleet: StyleBox = ScrapFrame.hand_plate(UiTokens.Hand.FLEET, 3)
	fleet.dividers = PackedFloat32Array([0.3, 0.6])
	var fleet_roles := _roles(fleet)
	_t.check("the Fleet draws a bezel, two ledger rules and a stamp", fleet_roles.has("bezel") and fleet_roles.count("divider") == 2
		and fleet_roles.has("stamp"), str(fleet_roles))
	_t.eq("the Fleet's card has one notched corner (six corners)", fleet.parts(RECT)[0].points.size(), 6)
	var rogue_roles := _roles(ScrapFrame.hand_plate(UiTokens.Hand.ROGUE, 3))
	_t.check("a Rogue plate is corner ticks with no edge line", rogue_roles.count("tick") == 6 and not rogue_roles.has("edge"), str(rogue_roles))
	var keeper_roles := _roles(ScrapFrame.hand_plate(UiTokens.Hand.KEEPER, 3))
	_t.check("a Keeper hand plate has rivets and halftone corners", keeper_roles.count("rivet") == 8 and keeper_roles.has("halftone"), str(keeper_roles))


func _old_works_has_no_fasteners() -> void:
	for kindness in [false, true]:
		var box: StyleBox = ScrapFrame.hand_plate(UiTokens.Hand.OLD_WORKS, 41, kindness)
		box.rivets = true
		box.tape = 0.5
		box.halftone = true
		box.tilt = 0.3
		var roles := _roles(box)
		var bad := roles.filter(func(r): return r in ["rivet", "tape", "halftone", "hole", "lip"])
		_t.eq("old works (kindness %s) draw no fastener, tape or halftone even when asked" % kindness, bad, [])
		_t.eq("old works draw one seam", roles.count("seam"), 1)
		var level: StyleBox = ScrapFrame.hand_plate(UiTokens.Hand.OLD_WORKS, 41, kindness)
		_t.eq("old works never lean", _points(box), _points(level))
	_t.eq("old works tag has no punched hole", _roles(ScrapFrame.hand_tag(UiTokens.Hand.OLD_WORKS, 2), Rect2(0, 0, 120, 26)).count("hole"), 0)
	_t.eq("old works move in straight lines", UiTokens.hand(UiTokens.Hand.OLD_WORKS).trans, Tween.TRANS_LINEAR)
	_t.eq("old works' seam is uranium green", ScrapFrame.hand_plate(UiTokens.Hand.OLD_WORKS, 1).seam, Palette.ANCIENT)
	_t.eq("the Kindness's seam is purple", ScrapFrame.hand_plate(UiTokens.Hand.OLD_WORKS, 1, true).seam, Palette.KINDNESS)


func _points(box: StyleBox) -> Array:
	var out := []
	for part in box.parts(RECT):
		out.append(part.points)
	return out


# Which ruled colour family a colour reads as, if any: mint (press now), brass (the Fleet) or purple (the Kindness).
func _family(c: Color) -> String:
	if c.s < 0.3 or c.v < 0.35:
		return ""
	var deg := c.h * 360.0
	if absf(deg - 163.0) < 12.0:
		return "mint"
	if absf(deg - 44.5) < 7.0 and c.s > 0.5:
		return "brass"
	if absf(deg - 315.0) < 25.0:
		return "purple"
	return ""


func _colour_law() -> void:
	_t.eq("planted: mint reads as mint", _family(Palette.ARC), "mint")
	_t.eq("planted: brass reads as brass", _family(Palette.BRASS), "brass")
	_t.eq("planted: the Kindness reads as purple", _family(Palette.KINDNESS), "purple")
	_t.eq("planted: copper is not brass", _family(Palette.COPPER), "")
	for hand in HANDS:
		for kindness in [false, true]:
			var box: StyleBox = ScrapFrame.hand_plate(hand, 23, kindness)
			box.tape = 0.4
			if hand == UiTokens.Hand.FLEET:
				box.dividers = PackedFloat32Array([0.5])
			var found := {}
			var unlawful := []
			for part in box.parts(RECT) + ScrapFrame.hand_tag(hand, 23).parts(Rect2(0, 0, 120, 26)):
				var family := _family(part.color)
				if family != "":
					found[family] = true
				if not ScrapFrame.lawful(hand, part.color, kindness):
					unlawful.append("%s %s" % [part.role, part.color.to_html(false)])
			var label := "%s%s" % [NAMES[hand], " kindness" if kindness else ""]
			_t.check("%s frame is never mint" % label, not found.has("mint"))
			_t.check("%s frame is brass only if it is the Fleet's" % label, found.has("brass") == (hand == UiTokens.Hand.FLEET), str(found.keys()))
			var purple_ok: bool = hand == UiTokens.Hand.OLD_WORKS and kindness
			_t.check("%s frame is purple only on the Kindness" % label, found.has("purple") == purple_ok, str(found.keys()))
			_t.eq("%s frame draws only lawful colours" % label, unlawful, [])
	# The token rows themselves.
	for hand in HANDS:
		for key in UiTokens.HANDS[hand]:
			var value = UiTokens.HANDS[hand][key]
			if value is Color:
				_t.check("%s %s is not mint" % [NAMES[hand], key], _family(value) != "mint")
				_t.check("%s %s is brass only on the Fleet" % [NAMES[hand], key], _family(value) != "brass" or hand == UiTokens.Hand.FLEET)
				_t.check("%s %s is purple only as the Kindness seam" % [NAMES[hand], key],
					_family(value) != "purple" or (hand == UiTokens.Hand.OLD_WORKS and key == "kindness_seam"))
	_t.check("planted: lawful refuses mint on every hand", HANDS.all(func(h): return not ScrapFrame.lawful(h, Palette.ARC, true)))
	_t.check("planted: lawful refuses brass off the Fleet", not ScrapFrame.lawful(UiTokens.Hand.KEEPER, Palette.BRASS)
		and not ScrapFrame.lawful(UiTokens.Hand.OLD_WORKS, Palette.BRASS) and not ScrapFrame.lawful(UiTokens.Hand.ROGUE, Palette.BRASS)
		and ScrapFrame.lawful(UiTokens.Hand.FLEET, Palette.BRASS))
	_t.check("planted: lawful refuses purple on an old-works memo and every other hand", not ScrapFrame.lawful(UiTokens.Hand.OLD_WORKS, Palette.KINDNESS)
		and not ScrapFrame.lawful(UiTokens.Hand.KEEPER, Palette.KINDNESS, true) and not ScrapFrame.lawful(UiTokens.Hand.FLEET, Palette.KINDNESS, true)
		and ScrapFrame.lawful(UiTokens.Hand.OLD_WORKS, Palette.KINDNESS, true))
	_t.check("planted: kindness on a Keeper plate draws no purple", ScrapFrame.hand_plate(UiTokens.Hand.KEEPER, 5, true).parts(RECT).all(
		func(part): return _family(part.color) != "purple"))


func _over(fill: Color, alpha: float, under: Color) -> Color:
	return under.lerp(Color(fill, 1.0), alpha)


func _contrast() -> void:
	for hand in HANDS:
		var row: Dictionary = UiTokens.HANDS[hand]
		var worst := INF
		for under in [Color.BLACK, Color.WHITE]:
			var ground := _over(row.fill, UiTokens.PLATE_ALPHA, under)
			for key in ["ink", "quiet"]:
				worst = minf(worst, UiTokens.contrast(row[key], ground))
		_t.check("%s words and quiet words hold 4.5:1 on its plate over any ground" % NAMES[hand], worst >= 4.5, "%.2f" % worst)
		var edge := UiTokens.contrast(row.edge, row.fill)
		_t.check("%s edge holds 3:1 on its fill" % NAMES[hand], edge >= 3.0, "%.2f" % edge)
		_t.check("%s smallest word is the caption floor" % NAMES[hand], row.caption >= 15 and row.caption in UiTokens.TYPE, str(row.caption))
	var seam := UiTokens.contrast(Palette.ANCIENT, UiTokens.HANDS[UiTokens.Hand.OLD_WORKS].fill)
	var kind := UiTokens.contrast(Palette.KINDNESS, UiTokens.HANDS[UiTokens.Hand.OLD_WORKS].fill)
	_t.check("both old-works seams hold 3:1 on the enamel", seam >= 3.0 and kind >= 3.0, "%.2f %.2f" % [seam, kind])
	_t.check("planted: slate words on the Fleet's oxide fail 4.5:1", UiTokens.contrast(Palette.SLATE, UiTokens.HANDS[UiTokens.Hand.FLEET].fill) < 4.5)


# The Keeper's cut-plate outline as plate() has always drawn it.
func _legacy_outline(rect: Rect2, serial: int, tag := false) -> PackedVector2Array:
	var small := minf(rect.size.x, rect.size.y)
	var base := clampf(small * 0.18, 2.0, 9.0) if not tag else clampf(small * 0.22, 2.0, 5.0)
	var cut := []
	for i in 4:
		cut.append(base * (0.45 + 1.1 * ScrapFrame.quirk(serial, i)))
	var p := rect.position
	var e := rect.end
	return PackedVector2Array([
		Vector2(p.x + cut[0], p.y), Vector2(e.x - cut[1], p.y), Vector2(e.x, p.y + cut[1]), Vector2(e.x, e.y - cut[2]),
		Vector2(e.x - cut[2], e.y), Vector2(p.x + cut[3], e.y), Vector2(p.x, e.y - cut[3]), Vector2(p.x, p.y + cut[0]),
	])


func _keeper_compat() -> void:
	var fill := Color(Palette.CHARCOAL, 0.8)
	var box: StyleBox = ScrapFrame.plate(Palette.AMBER, 31, fill, 3.0, 0.25)
	_t.check("plate() is a Keeper plate that neither leans nor prints halftone", box.hand == UiTokens.Hand.KEEPER and box.tilt == 0.0 and not box.halftone)
	var parts: Array = box.parts(RECT)
	var roles := _roles(box)
	_t.eq("plate() draws fill, lip, shine, edge, four rivets and tape as before", roles,
		["fill", "lip", "shine", "edge", "rivet", "rivet", "rivet", "rivet", "rivet", "rivet", "rivet", "rivet", "tape", "tape"])
	_t.eq("plate()'s outline is the cut plate it always was", parts[0].points, _legacy_outline(RECT, 31))
	_t.eq("plate()'s fill is the fill it was given", parts[0].color, fill)
	_t.check("plate()'s edge is its colour at its width, smoothed", parts[3].color == Palette.AMBER and parts[3].width == 3.0 and parts[3].aa)
	var tag: StyleBox = ScrapFrame.tag(Palette.COPPER, 9)
	var tag_rect := Rect2(0, 0, 140, 28)
	_t.eq("tag() draws fill, edge and a punched hole as before", _roles(tag, tag_rect), ["fill", "edge", "hole", "hole"])
	_t.eq("tag()'s outline is the cut tag it always was", tag.parts(tag_rect)[0].points, _legacy_outline(tag_rect, 9, true))
	_t.check("tag()'s margins are unchanged", tag.content_margin_left == 14.0 and tag.content_margin_right == 6.0
		and tag.content_margin_top == 1.0 and tag.content_margin_bottom == 2.0)
	var faded: StyleBox = ScrapFrame.plate(Palette.AMBER, 31)
	faded.fade = 0.5
	_t.near("a faded plate's edge fades once", faded.parts(RECT)[3].color.a, 0.5)


func _reduced_motion() -> void:
	var serial := 0
	while absf(2.0 * ScrapFrame.quirk(serial, 8) - 1.0) < 0.5:
		serial += 1
	var leaning: StyleBox = ScrapFrame.hand_plate(UiTokens.Hand.KEEPER, serial)
	var level: StyleBox = ScrapFrame.hand_plate(UiTokens.Hand.KEEPER, serial)
	level.tilt = 0.0
	_t.check("a Keeper hand plate leans a little", leaning.tilt != 0.0 and absf(leaning.tilt) <= UiTokens.HANDS[UiTokens.Hand.KEEPER].tilt, "%.4f" % leaning.tilt)
	_t.check("the lean moves the drawn frame", _points(leaning) != _points(level))
	Comfort.reduced_motion = true
	_t.eq("with less motion the Keeper plate draws level", _points(leaning), _points(level))
	for hand in HANDS:
		var row := UiTokens.hand(hand)
		_t.check("with less motion %s neither leans nor overshoots" % NAMES[hand], row.tilt == 0.0 and row.trans == Tween.TRANS_LINEAR)
	_t.check("the token rows themselves are untouched", UiTokens.HANDS[UiTokens.Hand.KEEPER].tilt > 0.0)
	Comfort.reduced_motion = false
	_t.eq("Keeper overshoots again with motion on", UiTokens.hand(UiTokens.Hand.KEEPER).trans, Tween.TRANS_BACK)
	for hand in [UiTokens.Hand.FLEET, UiTokens.Hand.OLD_WORKS, UiTokens.Hand.ROGUE]:
		_t.eq("%s never leans" % NAMES[hand], UiTokens.HANDS[hand].tilt, 0.0)


func _fonts() -> void:
	_t.eq("one face row per hand", UiFonts.HAND_FACES.size(), UiTokens.Hand.size())
	for row in UiFonts.HAND_FACES:
		_t.eq("every hand's numbers are in the mono face", row.numbers, UiFonts.MONO_PATH)
	var words := [UiFonts.KEEPER_PATH, UiFonts.BOLD_PATH, UiFonts.OLD_WORKS_PATH, UiFonts.MONO_PATH]
	for hand in HANDS:
		_t.eq("%s sets its words in its own face" % NAMES[hand], UiFonts.HAND_FACES[hand].words, words[hand])
	var first := []
	for hand in HANDS:
		first.append(UiFonts.face(hand).resource_path + "|" + UiFonts.face(hand, true).resource_path)
	_t.check("faces are cached", not UiFonts._faces.is_empty())
	if not UiFonts.vendored():
		_t.skip("the display faces are vendored and distinct", "vendored fonts are missing in this checkout")
		return
	var keeper := UiFonts.face(UiTokens.Hand.KEEPER)
	var old_works := UiFonts.face(UiTokens.Hand.OLD_WORKS)
	for pair in [["keeper", keeper], ["old works", old_works]]:
		var font: Font = pair[1]
		_t.check("the %s face is no fallback" % pair[0], font != ThemeDB.fallback_font)
		_t.check("the %s face is neither Noto face" % pair[0], font != UiFonts.bold() and font != UiFonts.mono())
		_t.eq("the %s face sets every glyph the cards use" % pair[0], _missing_glyphs(font), "")
		var line: Vector2 = font.get_string_size(CAPTION_LINE, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.CAPTION)
		var noto: float = UiFonts.bold().get_string_size(CAPTION_LINE, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.CAPTION).x
		_t.check("the %s face's caption line stands at least the 15 px floor" % pair[0], line.y >= UiTokens.CAPTION, "%.1f" % line.y)
		_t.check("the %s face's caption runs at most %d%% wider than Noto Bold's" % [pair[0], roundi(WIDER * 100.0 - 100.0)],
			line.x <= noto * WIDER, "%.1f against %.1f" % [line.x, noto])
	_t.check("the Keeper and the old works have different faces", keeper != old_works)
	_t.check("the Fleet's words stay Noto Sans Bold", UiFonts.face(UiTokens.Hand.FLEET) == UiFonts.bold())
	_t.check("the Rogues' stencil stays Noto Sans Mono Bold", UiFonts.face(UiTokens.Hand.ROGUE) == UiFonts.mono())
	for hand in HANDS:
		_t.check("%s's numbers are the mono face" % NAMES[hand], UiFonts.face(hand, true) == UiFonts.mono())
	UiFonts._faces[UiFonts.OLD_WORKS_PATH] = ThemeDB.fallback_font
	_t.check("planted: one face falling back fails vendored()", not UiFonts.vendored())
	UiFonts.reset_for_tests()
	_t.check("reset_for_tests empties the cache", UiFonts._faces.is_empty())
	var again := []
	for hand in HANDS:
		again.append(UiFonts.face(hand).resource_path + "|" + UiFonts.face(hand, true).resource_path)
	_t.eq("after a reset each hand loads the same faces", again, first)
	_t.check("after a reset every face loads from its file again", UiFonts.vendored())


# The glyphs a display face lacks among printable ASCII and the marks card copy uses (curly quotes,
# en and em dash, ellipsis, times, middle dot, degree), as one string; empty when it has them all.
func _missing_glyphs(font: Font) -> String:
	var wanted := []
	for code in range(0x20, 0x7f):
		wanted.append(code)
	wanted.append_array([0x2018, 0x2019, 0x201c, 0x201d, 0x2013, 0x2014, 0x2026, 0xd7, 0xb7, 0xb0])
	var missing := ""
	for code in wanted:
		if not font.has_char(code):
			missing += char(code)
	return missing
