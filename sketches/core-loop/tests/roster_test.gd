extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Achievements := preload("res://src/core/achievements.gd")
const Cosmetics := preload("res://src/core/cosmetics.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const UpgradeTree := preload("res://src/core/upgrade_tree.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const WordBudget := preload("res://src/ui/word_budget.gd")
const Push := preload("res://tests/workshop/push.gd")
const T := preload("res://tests/support/t.gd")

# The six-pilot roster (wave 15): the rows in the order the kit units landed, nothing
# pending, a full kit and tree each (R1-R3); the number keys and the D-pad reach the fifth
# and sixth cards (R4-R5); six cards fit one row of the 1600x900 screen at rest (R6) and
# rest in 13 words each, 75 on the screen (R7).

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


func _open_select() -> void:
	_game.flow.open_class_select()
	_game.screens._on_flow_changed("class_select")
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
	root.gui_release_focus()
	await _frames(2)
	for i in 6:
		Push.pad(root, JOY_BUTTON_DPAD_RIGHT)
		await _frames(2)
	_t.check("R5 six D-pad Rights reach the sixth card", cards.size() == 6 and cards[5].has_focus(),
		"focus %s" % [cards.map(func(c): return c.has_focus())])
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
