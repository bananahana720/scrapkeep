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
const HUD_WORDS := 11

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
	var words: int = WordBudget.count(hud)["hud"]
	_report("no new HUD words", words == HUD_WORDS, "%d words, pinned %d" % [words, HUD_WORDS])
	_report("gauge and chip icons differ", gauge.icon_id == "res_mass" and gauge.icon_id != chip.ICON
			and Icons.glyph_of(gauge.icon_id) != Icons.glyph_of(chip.ICON),
		"gauge %s (%s), chip %s (%s)" % [gauge.icon_id, Icons.glyph_of(gauge.icon_id), chip.ICON, Icons.glyph_of(chip.ICON)])
	_report("gauge wears the mass colour", gauge.visible and gauge.color == mass_color,
		"gauge shown %s, colour %s, scrap_collected %s" % [gauge.visible, gauge.color.to_html(), mass_color.to_html()])
	_report("chip wears brass", chip.COLOR == Palette.BRASS and chip.COLOR != mass_color,
		"chip %s, brass %s, mass %s" % [chip.COLOR.to_html(), Palette.BRASS.to_html(), mass_color.to_html()])
	print("hud_icon_distinct_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true
