extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const ClassCard := preload("res://src/ui/class_card.gd")
const Cosmetics := preload("res://src/core/cosmetics.gd")
const Profile := preload("res://src/core/profile.gd")
const WordBudget := preload("res://src/ui/word_budget.gd")
const Palette := preload("res://src/core/palette.gd")
const Push := preload("res://tests/workshop/push.gd")
const T := preload("res://tests/support/t.gd")

# The class cards for a locked pilot and the paint a card wears (P3). On the real class
# select, with Rivet swapped for a locked copy of its row (as profile_unlock_gate_test does):
#   - the locked card stays clickable (not disabled), wears the slate plate, greys its
#     preview, shows a lock, and shows its hint only when open; a click starts nothing and
#     shakes it; the calm screen still reads in 40 words or fewer;
#   - unlocking the pilot clears the look on the next visit to the screen;
#   - a card's paint cycle (swatch click or P on the open card) offers only the paints this
#     profile owns plus none, saves each pick, and the preview wears the equipped one.

const CALM_BUDGET := 40
const HINT := "Unlock: Win a run."

var _t := T.new("ui_locked_card_test")
var _game


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _settle(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		await process_frame
		left -= _game.get_process_delta_time()


func _enter_select() -> void:
	_game.screens._on_flow_changed("class_select")


func _text_of(label: String) -> String:
	return " | ".join(WordBudget.count(_game.screens)["items"].map(func(i): return i["text"]))


func _run() -> void:
	while _game.flow == null:
		await process_frame
	await _frames(5)
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	var rivet: Resource = _game.flow.classes[1]
	var locked_def := ClassDef.make({"id": rivet.id, "display_name": rivet.display_name, "starter": false})
	for prop in ["role", "species", "pitch", "weapon_id", "movement_id", "special_id", "smash_id", "color", "shape", "motif", "sound", "bible_home", "synergy_hooks"]:
		locked_def.set(prop, rivet.get(prop))
	_game.flow.classes[1] = locked_def
	_game.flow.open_class_select()
	await _settle(0.7)
	var cards: Array = _game.screens.class_cards()
	var card = cards[1]
	_t.check("P3-1 the locked card is flagged", card.locked and not cards[0].locked and not cards[2].locked, "locked %s" % [cards.map(func(c): return c.locked)])
	_t.check("P3-1 the locked card is not disabled", not card.disabled, "disabled %s" % card.disabled)
	var slate: Color = card.get_theme_stylebox("normal").border_color
	var other: Color = cards[0].get_theme_stylebox("normal").border_color
	_t.check("P3-1 the locked card wears a slate plate, the others their class colour",
		is_equal_approx(slate.r, Palette.SLATE.r) and is_equal_approx(slate.g, Palette.SLATE.g) and not is_equal_approx(other.r, Palette.SLATE.r), "slate %s other %s" % [slate, other])
	_t.check("P3-1 the locked preview is greyed", card.preview.material != null and cards[0].preview.material == null, "material")
	_t.check("P3-1 the lock replaces the role glyph", card._lock.visible and not card._glyph.visible and not cards[0]._lock.visible, "lock")
	_t.check("P3-1 no pilot-reward row, so the hint reads Locked", card._hint.text == "Locked", "hint %s" % card._hint.text)
	card.set_locked(true, HINT)
	await _settle(0.5)
	var calm := WordBudget.count(_game.screens)
	_t.check("P3-2 class select at rest reads in 40 words or fewer with a locked card", calm["hud"] > 0 and calm["hud"] <= CALM_BUDGET, "%d words: %s" % [calm["hud"], _text_of("calm")])
	_t.check("P3-1 the hint is not shown at rest", not _text_of("calm").contains("Unlock"), _text_of("calm"))
	Push.hover(root, card)
	await _settle(0.7)
	var open_words := _text_of("open")
	_t.check("P3-1 the hint shows when the card is open", card.is_open() and open_words.contains(HINT), open_words)
	Push.click(root, card)
	await _frames(3)
	_t.check("P3-1 a click on the locked card starts nothing", _game.flow.state_name() == "class_select" and not _game.flow.in_play(), "state %s" % _game.flow.state_name())
	_t.check("P3-1 the click shakes the card", card._shake > 0.0, "shake %s" % card._shake)
	await _settle(0.4)
	_t.check("P3-1 the shake ends", card._shake == 0.0 and is_zero_approx(card.rotation), "rotation %s" % card.rotation)
	# Unlocking clears the look on the next visit.
	_game.ctx.profile.unlock_pilot(locked_def.id)
	_enter_select()
	await _settle(0.5)
	cards = _game.screens.class_cards()
	_t.check("P3-1 the unlocked pilot's card loses the locked look", not cards[1].locked and cards[1].preview.material == null and not cards[1]._lock.visible and cards[1]._glyph.visible, "locked %s" % cards[1].locked)
	# A card's paint.
	var profile = _game.ctx.profile
	var sable = cards[0]
	var starters := ["", "paint_any_salt", "paint_sable_lagoon"]
	var options: Array = sable.paint_options()
	_t.eq("P3-4 an unowned profile offers none plus the starter paints", options, starters)
	_t.check("P3-4 an unowned paint is not offered", not options.has("paint_sable_violet") and not options.has("paint_any_night"), "options %s" % [options])
	profile.equip(sable.def.id, "paint", "paint_sable_violet")
	sable.bind_profile(profile)
	_t.check("P3-4 an equipped paint the profile does not own shows as none", sable.paint_shown() == "" and sable.preview.paint_id == "", "shown %s preview %s" % [sable.paint_shown(), sable.preview.paint_id])
	Push.hover(root, sable)
	await _settle(0.7)
	var picked := []
	Push.key(root, KEY_P)
	await _frames(2)
	picked.append(profile.equipped(sable.def.id, "paint"))
	_t.check("P3-4 P on the open card cycles to the first owned paint", picked[0] == "paint_any_salt", "equipped %s" % picked[0])
	_t.eq("P3-4 the preview wears the equipped paint", sable.preview.paint_id, picked[0])
	Push.click(root, sable._swatch)
	await _frames(2)
	picked.append(profile.equipped(sable.def.id, "paint"))
	_t.check("P3-4 a click on the swatch cycles on", picked[1] == "paint_sable_lagoon", "equipped %s" % picked[1])
	_t.eq("P3-4 the preview follows", sable.preview.paint_id, picked[1])
	var shown: String = sable._paint_label.text
	_t.check("P3-4 the paint name shows", shown == Cosmetics.row("paint_sable_lagoon")["name"], shown)
	var reloaded := Profile.new(profile.path)
	reloaded.load_profile()
	_t.eq("P3-4 an equip is saved", reloaded.equipped(sable.def.id, "paint"), "paint_sable_lagoon")
	Push.key(root, KEY_P)
	await _frames(2)
	_t.eq("P3-4 after the last owned paint the cycle returns to none", profile.equipped(sable.def.id, "paint"), "")
	profile.unlock_cosmetic("paint_sable_violet")
	_t.check("P3-4 an owned unlock joins the cycle", sable.paint_options().has("paint_sable_violet") and not sable.paint_options().has("paint_any_night"), "options %s" % [sable.paint_options()])
	_game.queue_free()
	quit(_t.verdict())
