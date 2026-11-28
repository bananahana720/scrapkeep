extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const ClassCard := preload("res://src/ui/class_card.gd")
const Achievements := preload("res://src/core/achievements.gd")
const Cosmetics := preload("res://src/core/cosmetics.gd")
const Profile := preload("res://src/core/profile.gd")
const WordBudget := preload("res://src/core/word_budget.gd")
const Palette := preload("res://src/core/palette.gd")
const Push := preload("res://tests/support/push.gd")
const T := preload("res://tests/support/t.gd")

# The class cards for a locked pilot and the paint a card wears (P3). On the real class
# select, with Rivet swapped for a locked copy of its row (as profile_unlock_gate_test does):
#   - the locked card stays clickable (not disabled), wears the slate plate, greys its
#     preview, shows a lock, and shows its hint only when open; a click starts nothing and
#     shakes it; the calm screen still reads in 50 words or fewer;
#   - unlocking the pilot clears the look on the next visit to the screen;
#   - a card's paint cycle (swatch click or P on the open card) offers only the paints this
#     profile owns plus none, saves each pick, and the preview wears the equipped one.
#   - Tarn's card offers Tarn's own starter paint, no other card offers it, and the swatch,
#     label and preview show it once equipped.

# 75 since six pilots (wave 15 roster, 2026-10-05); each card rests at 13 words or fewer.
const CALM_BUDGET := 75
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
	# Sable is the only starter: earn every non-starter but the second so only the second card is locked.
	for i in range(2, _game.flow.classes.size()):
		_game.ctx.profile.unlock_pilot(_game.flow.classes[i].id)
	_game.flow.open_class_select()
	await _settle(0.7)
	var cards: Array = _game.screens.class_cards()
	var card = cards[1]
	_t.check("P3-1 the locked card is flagged", cards.size() == 6 and card.locked and range(cards.size()).all(func(j): return j == 1 or not cards[j].locked), "locked %s" % [cards.map(func(c): return c.locked)])
	_t.check("P3-1 the locked card is not disabled", not card.disabled, "disabled %s" % card.disabled)
	var slate: Color = card.get_theme_stylebox("normal").border_color
	var other: Color = cards[0].get_theme_stylebox("normal").border_color
	_t.check("P3-1 the locked card wears a slate plate, the others their class colour",
		is_equal_approx(slate.r, Palette.SLATE.r) and is_equal_approx(slate.g, Palette.SLATE.g) and not is_equal_approx(other.r, Palette.SLATE.r), "slate %s other %s" % [slate, other])
	_t.check("P3-1 the locked preview is greyed", card.preview.material != null and cards[0].preview.material == null, "material")
	_t.check("P3-1 the lock replaces the role glyph", card._lock.visible and not card._glyph.visible and not cards[0]._lock.visible, "lock")
	_t.check("P3-1 the hint reads the pilot's unlock label, then its beat", card._hint.text == "Open the cage. The runner never clocked out.\n" + Achievements.beat_of("rivet_rescued"), "hint %s" % card._hint.text)
	card.set_locked(true, HINT)
	await _settle(0.5)
	var calm := WordBudget.count(_game.screens)
	_t.check("P3-2 class select at rest reads in 75 words or fewer with a locked card", calm["hud"] > 0 and calm["hud"] <= CALM_BUDGET, "%d words: %s" % [calm["hud"], _text_of("calm")])
	_t.check("P3-1 the hint is not shown at rest", not _text_of("calm").contains("Unlock"), _text_of("calm"))
	Push.hover(root, card)
	await _settle(0.7)
	var open_words := _text_of("open")
	_t.check("P3-1 the hint shows when the card is open", card.is_open() and open_words.contains(HINT), open_words)
	# PF-40: at six cards every pilot's real hint (its unlock words, then its beat) wraps to four or
	# five lines; on the open card it stays inside the preview and covers neither the name nor the tag.
	for def in ClassDef.all():
		if def.starter:
			continue
		var real := "%s\n%s" % [ClassCard.unlock_hint(def, null), Achievements.beat_of(Achievements.for_pilot(def.id))]
		card.set_locked(true, real)
		await _settle(0.3)
		var plate: Rect2 = card.hint_rect()
		var shell: Rect2 = card.preview.get_global_rect()
		var clear: bool = plate.size.y > 0.0 and not plate.intersects(card.name_label().get_global_rect()) \
			and not plate.intersects(card.role_label().get_global_rect()) \
			and plate.position.y >= shell.position.y - 0.5 and plate.end.y <= shell.end.y + 0.5
		_t.check("PF-40 %s's hint stays on the preview at six cards" % def.display_name, clear,
			"plate %s, preview %s, name %s, tag %s" % [plate, shell, card.name_label().get_global_rect(), card.role_label().get_global_rect()])
	card.set_locked(true, HINT)
	await _settle(0.3)
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
	# Wave 36: a profile with only the starter paints has nothing to choose, so the card draws no
	# paint row and P cycles nothing. Owning one more paint brings the row and the cycle.
	_t.check("P3-4 with only starter paints the card draws no paint row and cycles nothing",
		not sable.owns_paint() and sable.cycle_paint() == "" and profile.equipped(sable.def.id, "paint") == "paint_sable_violet",
		"owns %s equipped %s" % [sable.owns_paint(), profile.equipped(sable.def.id, "paint")])
	profile.equip(sable.def.id, "paint", "")
	profile.unlock_cosmetic("paint_sable_violet")
	sable.bind_profile(profile)
	_t.check("P3-4 an owned unlock joins the cycle", sable.owns_paint() and sable.paint_options() == starters + ["paint_sable_violet"]
		and not sable.paint_options().has("paint_any_night"), "options %s" % [sable.paint_options()])
	# Pilot select opens on the first card (PF-40); shut it to read a closed card's swatch.
	root.gui_release_focus()
	await _settle(0.7)
	_t.check("P3-4 on a closed card the hidden swatch lets clicks through to the card", sable._swatch.mouse_filter == Control.MOUSE_FILTER_IGNORE, "filter %s" % sable._swatch.mouse_filter)
	Push.hover(root, sable)
	await _settle(0.7)
	_t.check("P3-4 on the open card the swatch takes clicks", sable._swatch.mouse_filter == Control.MOUSE_FILTER_STOP, "filter %s" % sable._swatch.mouse_filter)
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
	_t.eq("P3-4 the owned unlock comes last in the cycle", profile.equipped(sable.def.id, "paint"), "paint_sable_violet")
	Push.key(root, KEY_P)
	await _frames(2)
	_t.eq("P3-4 after the last owned paint the cycle returns to none", profile.equipped(sable.def.id, "paint"), "")
	# Tarn's own paint, found by id since the chain may add cards.
	var tarn = null
	var offered_elsewhere: Array = []
	for c in cards:
		if c.def.id == "tarn":
			tarn = c
		elif c.paint_options().has("paint_tarn_ash"):
			offered_elsewhere.append(c.def.id)
	_t.check("P3-5 Tarn's card offers its own starter paint", tarn != null and tarn.paint_options().has("paint_tarn_ash"), "options %s" % [tarn.paint_options() if tarn != null else "no tarn card"])
	_t.check("P3-5 no other pilot is offered Tarn's paint", offered_elsewhere.is_empty(), "offered to %s" % [offered_elsewhere])
	if tarn != null:
		# The card cycles paint only once the profile owns one beyond the starters (wave 36).
		profile.unlock_cosmetic("paint_tarn_dig")
		tarn.bind_profile(profile)
		for i in tarn.paint_options().size():
			if profile.equipped("tarn", "paint") == "paint_tarn_ash":
				break
			tarn.cycle_paint()
		_t.check("P3-5 the swatch shows Tarn's tint", tarn._swatch.color == Cosmetics.row("paint_tarn_ash")["tint"], "swatch %s equipped %s" % [tarn._swatch.color, profile.equipped("tarn", "paint")])
		_t.eq("P3-5 the label shows the paint name", tarn._paint_label.text, "Redjaw Ash")
		_t.eq("P3-5 the preview wears it", tarn.preview.paint_id, "paint_tarn_ash")
	_game.queue_free()
	quit(_t.verdict())
