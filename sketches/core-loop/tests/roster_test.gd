# 2026-10-12 FIXTURE-ADAPT: bd3e0ed added wrapping Tradeoff text; reserve a fixed-height slot above the keys.
# 2026-10-12 R5: open every pilot and measure the reserved Tradeoff slot and complete wrapped text.
extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Achievements := preload("res://src/core/achievements.gd")
const Cosmetics := preload("res://src/core/cosmetics.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const UpgradeTree := preload("res://src/core/upgrade_tree.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const WordBudget := preload("res://src/core/word_budget.gd")
const ClassCard := preload("res://src/ui/class_card.gd")
const Screens := preload("res://src/ui/screens.gd")
const Push := preload("res://tests/workshop/push.gd")
const T := preload("res://tests/support/t.gd")

# The six-pilot roster (wave 15): the rows in the order the kit units landed, nothing
# pending, a full kit and tree each (R1-R3); the number keys and the D-pad reach the fifth
# and sixth cards (R4-R5); six cards fit one row of the 1600x900 screen at rest (R6) and
# rest in 13 words each, 75 on the screen (R7); every key row ends on the card's floor with one bottom edge and one preview height (R8), the preview keeps its 160 px floor (R9), and both four-card layouts fit and level the same way (R10).

const ROSTER := ["pylon_engineer", "runner_gunner", "demolitions_caster", "tarn", "tally", "remembered_cannon"]
const REWARDS := {"tarn": "brindle_routed", "tally": "ledger_balanced", "remembered_cannon": "mind_quieted",
	"demolitions_caster": "dig_rescued"}
const SCREEN := Vector2(1600.0, 900.0)
const CARD_WORDS := 13
const SCREEN_WORDS := 75

var _t := T.new("roster_test")
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


# Pilot select opens on the first pilot the profile can take (PF-40); these checks read the cards at rest, so the
# focus is let go first.
func _open_select() -> void:
	_game.flow.open_class_select()
	_game.screens._on_flow_changed("class_select")
	await _settle(0.7)
	root.gui_release_focus()
	await _settle(0.7)


func _run() -> void:
	while _game.flow == null:
		await process_frame
	await _frames(5)
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	var ids: Array = ClassDef.all().map(func(d): return d.id)
	_t.check("R1 roster in landed order", ids == ROSTER and ClassDef.all().size() == 6, "%s" % [ids])
	_check_rewards(ids)
	_check_kits()
	await _open_select()
	var cards: Array = _game.screens.class_cards()
	_check_fit(cards)
	_check_words(cards)
	_check_rows(cards, "R8", "six cards")
	await _check_tradeoffs(cards)
	root.gui_release_focus()
	await _frames(2)
	for i in 6:
		Push.pad(root, JOY_BUTTON_DPAD_RIGHT)
		await _frames(2)
	_t.check("R5 six D-pad Rights reach the sixth card", cards.size() == 6 and cards[5].has_focus(),
		"focus %s" % [cards.map(func(c): return c.has_focus())])
	_check_preview_floor()
	await _check_four()
	await _check_wide()
	await _check_keys()
	print("roster_test: %d checks" % _t.checks)
	_game.free()
	quit(_t.verdict())


func _check_rewards(ids: Array) -> void:
	_t.eq("R2 nothing pending", Achievements.PENDING_PILOTS, [])
	var rewarded := {}
	for row_id in Achievements.ROWS:
		var pilot := String(Achievements.ROWS[row_id].get("reward", {}).get("pilot", ""))
		if pilot != "":
			rewarded[pilot] = int(rewarded.get(pilot, 0)) + 1
	var once := true
	for def in ClassDef.all():
		if not def.starter:
			once = once and Achievements.for_pilot(def.id) != "" and int(rewarded.get(def.id, 0)) == 1
	_t.check("R2 every non-starter is one row's reward", once, "rewards %s" % [rewarded])
	var pairs := {}
	for id in REWARDS:
		pairs[id] = Achievements.for_pilot(id)
	_t.eq("R2 reward pairs", pairs, REWARDS)
	_t.eq("R2 rows validate", Achievements.validate(Achievements.ROWS, Achievements.bus_signals(), ids, Cosmetics.ids()), [])


func _check_kits() -> void:
	for def in ClassDef.all():
		var slots := [def.weapon_id, def.movement_id, def.special_id, def.smash_id]
		var nodes := UpgradeTree.nodes(def.id).size()
		_t.check("R3 %s kit and tree" % def.id, slots.all(func(s): return AbilityState.ABILITIES.has(s)) and nodes == 30,
			"slots %s, %d tree nodes, motif %s has no Harmony row: %s" % [slots, nodes, def.motif, Harmony.motif(def.motif).is_empty()])
	var warned: Array = ROSTER.filter(func(id): return UpgradeTree.unknown_warned.has(id))
	_t.eq("R3 no roster pilot is an unknown tree", warned, [])


func _check_fit(cards: Array) -> void:
	_t.check("R6 six cards", cards.size() == 6, "%d cards" % cards.size())
	var screen := Rect2(Vector2.ZERO, SCREEN).grow(0.5)
	var widest := (SCREEN.x - 120.0 - 5.0 * 12.0) / 6.0 + 1.0
	var inside := true
	var apart := true
	var narrow := true
	var cells_out := []
	var names_out := []
	var roles_out := []
	var detail := PackedStringArray()
	for i in cards.size():
		var card = cards[i]
		var rect: Rect2 = card.get_global_rect()
		inside = inside and screen.encloses(rect)
		narrow = narrow and card.size.x <= widest
		for j in range(i + 1, cards.size()):
			apart = apart and not rect.grow(-0.5).intersects(cards[j].get_global_rect().grow(-0.5))
		var room := rect.grow(0.5)
		if card.key_cells().is_empty() or not card.key_cells().all(func(c): return room.encloses(c.get_global_rect())):
			cells_out.append("%s card %s cells %s" % [card.def.id, rect, card.key_cells().map(func(c): return c.get_global_rect())])
		var label: Label = card.name_label()
		if label == null or not room.encloses(label.get_global_rect()):
			names_out.append("%s %s" % [card.def.id, label.get_global_rect() if label != null else null])
		# The role tag is a detail, hidden at rest, but it still sizes the card's column.
		var role: Label = card.role_label()
		if role == null or not room.encloses(role.get_global_rect()):
			roles_out.append("%s %s" % [card.def.id, role.get_global_rect() if role != null else null])
		detail.append("%s %.1f px, name %d px" % [card.def.id, card.size.x, label.get_theme_font_size("font_size") if label != null else 0])
	_t.check("R6 every card inside the screen", inside, ", ".join(detail))
	_t.check("R6 no two cards overlap", apart, ", ".join(detail))
	_t.check("R6 every card at most the six-card width", narrow, "limit %.1f px: %s" % [widest, ", ".join(detail)])
	_t.check("R6 every key cell inside its card", cells_out.is_empty(), "outside: %s" % [cells_out])
	_t.check("R6 every name inside its card", names_out.is_empty(), "outside: %s" % [names_out])
	_t.check("R6 every role tag inside its card", roles_out.is_empty(), "outside: %s" % [roles_out])


# The key-row floor (a card's rect less its bottom pad), the spread of the key-cell bottoms
# across the row, and the preview heights at rest. Returns the verdicts and a detail line.
func _row_measures(cards: Array) -> Dictionary:
	var floors_ok := true
	var lo := INF
	var hi := -INF
	var preview_ok := true
	var same := true
	var first := -1.0
	var per := PackedStringArray()
	for card in cards:
		var floor_y: float = card.get_global_rect().end.y - ClassCard.PAD
		var bottom := -INF
		for c in card.key_cells():
			bottom = maxf(bottom, c.get_global_rect().end.y)
		floors_ok = floors_ok and bottom <= floor_y + 0.5
		lo = minf(lo, bottom)
		hi = maxf(hi, bottom)
		var h: float = card.preview.custom_minimum_size.y
		var drawn: float = card.preview.get_global_rect().size.y
		preview_ok = preview_ok and h >= ClassCard.PREVIEW_MIN and h <= ClassCard.PREVIEW_H and drawn >= ClassCard.PREVIEW_MIN - 0.5
		if first < 0.0:
			first = h
		same = same and absf(h - first) <= 0.01
		per.append("%s floor %.1f cell bottom %.1f preview %.1f (drawn %.1f) width %.1f" % [card.def.id, floor_y, bottom, h, drawn, card.size.x])
	var detail := "; ".join(per)
	print("  rows: ", detail)
	return {"floors": floors_ok, "edge": hi - lo <= 0.5 and not cards.is_empty(), "preview": preview_ok and same, "detail": detail,
		"spread": hi - lo}


func _check_rows(cards: Array, tag: String, label: String) -> void:
	var m := _row_measures(cards)
	_t.check("%s key rows end on the card floor" % tag, m["floors"] and not cards.is_empty(), "%s: %s" % [label, m["detail"]])
	_t.check("%s one key-row bottom edge" % tag, m["edge"], "%s: spread %.2f px" % [label, m["spread"]])
	_t.check("%s one preview height in [%d, %d]" % [tag, int(ClassCard.PREVIEW_MIN), int(ClassCard.PREVIEW_H)], m["preview"], "%s: %s" % [label, m["detail"]])


func _check_tradeoffs(cards: Array) -> void:
	for card in cards:
		card.grab_focus()
		await _settle(0.7)
		var label := card.find_child("Tradeoff", true, false) as Label
		if not _t.check("%s open card has Tradeoff" % card.def.id, card.is_open() and label != null):
			continue
		var slot := label.get_parent() as Control
		var card_rect: Rect2 = card.get_global_rect()
		var slot_rect := slot.get_global_rect()
		var label_rect := label.get_global_rect()
		var font := label.get_theme_font("font")
		var font_size := label.get_theme_font_size("font_size")
		var flags := TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
		var text_size := font.get_multiline_string_size(label.text, label.horizontal_alignment, label.size.x, font_size, -1, flags)
		var spacing := label.get_theme_constant("line_spacing") * maxi(label.get_line_count() - 1, 0)
		var required_height := text_size.y + spacing
		var scale_y: float = card.scale.y
		_t.check("%s Tradeoff common nonzero reserved height" % card.def.id,
			ClassCard.TRADEOFF_H > 0.0 and slot.custom_minimum_size.y == ClassCard.TRADEOFF_H
			and is_equal_approx(slot.size.y, ClassCard.TRADEOFF_H) and is_equal_approx(label.size.y, slot.size.y),
			"minimum %.1f, slot %.1f, label %.1f, reserved %.1f" % [slot.custom_minimum_size.y, slot.size.y, label.size.y, ClassCard.TRADEOFF_H])
		_t.check("%s Tradeoff slot and label contained in card" % card.def.id,
			card_rect.grow(0.5).encloses(slot_rect) and card_rect.grow(0.5).encloses(label_rect) and slot_rect.grow(0.5).encloses(label_rect))
		_t.check("%s Tradeoff complete wrapped text fits" % card.def.id,
			label.size.x > 0.0 and label_rect.size.y >= required_height * scale_y and label.visible_characters == -1 and label.max_lines_visible == -1,
			"text %s, width %.1f, font %d, needs %.1f, measured %.1f" % [label.text, label.size.x, font_size, required_height * scale_y, label_rect.size.y])
	root.gui_release_focus()
	await _settle(0.7)


# R9: the preview never gives up more than PREVIEW_H - PREVIEW_MIN, and a zero ask changes nothing.
func _check_preview_floor() -> void:
	var tight = ClassCard.new(ClassDef.by_id("tally"), "key_5", 236.0)
	tight.shrink_preview(500.0)
	var tight_h: float = tight.preview.custom_minimum_size.y
	var loose = ClassCard.new(ClassDef.by_id("tally"), "key_5", 236.0)
	loose.shrink_preview(0.0)
	var loose_h: float = loose.preview.custom_minimum_size.y
	_t.check("R9 preview floor holds", tight_h == ClassCard.PREVIEW_MIN and loose_h == ClassCard.PREVIEW_H,
		"shrink 500 -> %.1f (floor %.1f), shrink 0 -> %.1f (rest %.1f)" % [tight_h, ClassCard.PREVIEW_MIN, loose_h, ClassCard.PREVIEW_H])
	tight.free()
	loose.free()


# R10: four cards in one row, both halves of the roster, then the full six again.
func _check_four() -> void:
	var all: Array = _game.flow.classes.duplicate()
	var screen := Rect2(Vector2.ZERO, SCREEN).grow(0.5)
	for keep in [[0, 1, 2, 3], [2, 3, 4, 5]]:
		_game.flow.classes.clear()
		for i in keep:
			_game.flow.classes.append(all[i])
		await _open_select()
		var cards: Array = _game.screens.class_cards()
		var inside := true
		var apart := true
		var narrow := true
		for i in cards.size():
			var rect: Rect2 = cards[i].get_global_rect()
			inside = inside and screen.encloses(rect)
			narrow = narrow and cards[i].size.x <= Screens.CARD_MAX + 0.5
			for j in range(i + 1, cards.size()):
				apart = apart and not rect.grow(-0.5).intersects(cards[j].get_global_rect().grow(-0.5))
		var m := _row_measures(cards)
		_t.check("R10 four cards %s fit" % [keep], cards.size() == 4 and inside and apart and narrow and m["floors"] and m["edge"] and m["preview"],
			"%d cards, inside %s, apart %s, narrow %s, floor %s, edge %.2f px, preview %s: %s" % [cards.size(), inside, apart, narrow,
				m["floors"], m["spread"], m["preview"], m["detail"]])
	_game.flow.classes.clear()
	_game.flow.classes.append_array(all)
	await _open_select()
	_t.check("R10 the six cards come back", _game.screens.class_cards().size() == 6, "%d cards" % _game.screens.class_cards().size())


# R11: at a screen wide enough that six cards' natural width passes CARD_MAX, the cap binds and
# every card is exactly CARD_MAX wide. The 1600 px checks above never reach the cap.
func _check_wide() -> void:
	var before := root.content_scale_size
	var wide := Vector2i(3200, 1800)
	root.content_scale_size = wide
	await _frames(2)
	await _open_select()
	var cards: Array = _game.screens.class_cards()
	var natural := (float(wide.x) - 2.0 * Screens.SIDE - 5.0 * Screens.CARD_GAP_TIGHT) / 6.0
	var capped := true
	var widths := []
	for card in cards:
		capped = capped and absf(card.size.x - Screens.CARD_MAX) <= 0.5
		widths.append("%.1f" % card.size.x)
	_t.check("R11 six cards at %dx%d all sit at the card cap" % [wide.x, wide.y], cards.size() == 6 and natural > Screens.CARD_MAX and capped,
		"natural %.1f px, cap %.1f px, widths %s" % [natural, Screens.CARD_MAX, ", ".join(widths)])
	root.content_scale_size = before
	await _frames(2)
	await _open_select()


func _check_words(cards: Array) -> void:
	var per: Array = cards.map(func(c): return WordBudget.count(c)["hud"])
	_t.check("R7 every card rests at %d words or fewer" % CARD_WORDS, per.all(func(n): return n <= CARD_WORDS), "%s" % [per])
	var screen: int = WordBudget.count(_game.screens)["hud"]
	_t.check("R7 the screen rests at %d words or fewer" % SCREEN_WORDS, screen > 0 and screen <= SCREEN_WORDS, "%d words, per card %s" % [screen, per])


func _check_keys() -> void:
	_game._screen_key(KEY_6)
	await _frames(3)
	_t.eq("R4 KEY_6 on a locked sixth card stays on class select", _game.flow.state_name(), "class_select")
	_game.ctx.profile.unlock_pilot(ROSTER[4])
	_game.ctx.profile.unlock_pilot(ROSTER[5])
	await _open_select()
	_game._screen_key(KEY_5)
	await _frames(3)
	_t.eq("R4 KEY_5 starts the fifth pilot", _game.run.class_id(), ROSTER[4])
	_game.run.damage(99999.0, "test")
	await _frames(12)
	_game._screen_key(KEY_C)
	_game.screens._on_flow_changed("class_select")
	await _settle(0.7)
	_game._screen_key(KEY_6)
	await _frames(3)
	_t.eq("R4 KEY_6 starts the sixth pilot", _game.run.class_id(), ROSTER[5])
