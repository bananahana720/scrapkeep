extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Icons := preload("res://src/ui/icons.gd")
const Palette := preload("res://src/core/palette.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const WordBudget := preload("res://src/ui/word_budget.gd")

# The armour gauge reads as mass and the wallet chip as money: a different icon and a
# different colour each, and the split adds no word to the HUD (playtest entry 7).

# The HUD's word count on the first armour frame, read before the split (2026-10-04).
# Re-pinned 11 -> 9 on 2026-10-04 (alpha wave 7 fix round E): the icon split changed no
# word; 254db18's six-stage, three-world default table puts the world card "Spillway
# Works" (2 words) where stage 1's card "Spillway: the top shelf" (4) stood on this frame.
# Re-pinned 9 -> 11 on 2026-10-10 (wave 13 unit B2, SKILL-BAR section 5): the skill bar draws
# five keycap words (1, 2, 3, Shift, Ctrl) where the four-slot bar drew three (Shift, F, Ctrl;
# the LMB glyph has no letters). The fight-case budget stays 25 (LEGIBILITY.md:114).
# Re-pinned 11 -> 16 on 2026-10-17 (FIRST-TIMER audit): a fresh profile's first frame now shows
# the drive lesson (ui/first_steps.gd), the four drive keycaps and DRIVE at the ball.
# Re-pinned 16 -> 17 on 2026-10-24 (#445, actives on by default): the racked active's F chip
# adds its keycap word. The fight-case budget stays 25 (ruling l).
# Re-pinned 17 -> 20 on 2026-11-10 (play finding PF-02): the health and armour bars each carry
# their word (ui/gauge.gd caption) and the difficulty steps theirs (ui/run_status.gd). Blind
# readers took the difficulty bar for health, the armour bar for a resource and the steps for
# a signal meter; the three words are what the reads asked for. The budget stays 25.
# 21 since wave 35 (PF-03): the Shift prompt reads BOOST, because a key and an icon alone told a new player nothing.
# 20 since wave 42 (W1-63 with W1-77): the BOOST word waits until the ball has speed, so it is off the first frame.
const HUD_WORDS := 20

var _game
var _frames := 0
var _failures := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_frames += 1
	if _frames == 1:
		_game.ctx.calm = true
		_game.player.source = Intent.Scripted.new()
		_game.flow.press_start()
		_game.flow.choose_class(0)
		return false
	if _frames == 2:
		_game.run.armor_mode = true
		return false
	if _frames < 5:
		return false
	var hud = _game.hud
	var gauge = hud._armor
	var chip = hud._cogs
	var mass_color: Color = EventKinds.color("scrap_collected")
	var counted: Dictionary = WordBudget.count(hud)
	var words: int = counted["hud"]
	var read: Array = []
	for item in counted["items"]:
		if item["kind"] == "hud":
			read.append("%s: %s" % [item["node"], item["text"]])
	_report("no new HUD words", words == HUD_WORDS, "%d words, pinned %d: %s" % [words, HUD_WORDS, read])
	_report("each meter says what it holds", Array(hud._health.drawn_words()).has("HEALTH") and Array(gauge.drawn_words()).has("ARMOUR")
			and Array(hud._status.drawn_words()).has("THREAT"),
		"health %s, armour %s, plate %s" % [hud._health.drawn_words(), gauge.drawn_words(), hud._status.drawn_words()])
	_report("gauge and chip icons differ", gauge.icon_id == "res_mass" and gauge.icon_id != chip.ICON
			and Icons.glyph_of(gauge.icon_id) != Icons.glyph_of(chip.ICON),
		"gauge %s (%s), chip %s (%s)" % [gauge.icon_id, Icons.glyph_of(gauge.icon_id), chip.ICON, Icons.glyph_of(chip.ICON)])
	_report("gauge wears the mass colour", gauge.visible and gauge.color == mass_color,
		"gauge shown %s, colour %s, scrap_collected %s" % [gauge.visible, gauge.color.to_html(), mass_color.to_html()])
	# W1-21: the chip wears the cog's steel, off Brindle's brass (VISUAL-LANGUAGE palette table).
	_report("chip wears the cog's steel", chip.COLOR == Palette.STEEL and chip.COLOR != mass_color and chip.COLOR != Palette.BRASS,
		"chip %s, steel %s, mass %s" % [chip.COLOR.to_html(), Palette.STEEL.to_html(), mass_color.to_html()])
	print("hud_icon_distinct_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true
