# 2026-10-12 FIXTURE-ADAPT: 000763f added Windhover; Kest's sheet :23 calls her "a hovering mortar".
extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const WordBudget := preload("res://src/ui/word_budget.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const Bindings := preload("res://src/core/bindings.gd")
const ClassKit := preload("res://src/ui/class_kit.gd")
const ClassPreview := preload("res://src/ui/class_preview.gd")
const Push := preload("res://tests/workshop/push.gd")
const ClassCard := preload("res://src/ui/class_card.gd")
const Achievements := preload("res://src/core/achievements.gd")

# The class cards that sell a pilot (v3 W12, playtest entry 8). On the real class
# select, driven by pushed mouse and key events:
#   - every card shows its class row's bar (1, 2, 3, Q) over its chips (RMB, Shift, Ctrl) with
#     the rows' ability icons, plus its Space extra, and wears the row's colour;
#   - the whole screen reads in 75 words or fewer, as it opens (on the first card, PF-40) and with
#     any one card open: the keycaps are the same on every card, so they read on the open card
#     only (re-pinned 2026-10-10, unit B2);
#   - hovering a card opens that card alone: it lifts, its words fade in, its preview
#     plays and moves, the others step back; the extra words all belong to it;
#   - with nothing focused, Right opens the first card, Right again the second, and
#     Enter starts that class.

# 75 since six pilots (wave 15 roster, 2026-10-05); each card rests at 13 words or fewer.
const CALM_BUDGET := 75
const SETTLE := 0.5

var _game
var _failures := 0
var _phase := "boot"
var _clock := 0.0
var _calm := 0
var _calm_cards := []
var _probe := Vector3.ZERO
var _travel := 0.0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _next(phase: String) -> void:
	_phase = phase
	_clock = 0.0


func _words(label: String) -> int:
	var seen: Dictionary = WordBudget.count(_game.screens)
	print("  %s: %s" % [label, " | ".join(seen["items"].map(func(i): return "%s %d \"%s\"" % [i["node"], i["words"], i["text"]]))])
	return seen["hud"]


func _process(delta: float) -> bool:
	if _game.flow == null:
		return false
	_clock += delta
	var cards: Array = _game.screens.class_cards()
	if _phase == "hover_check":
		_travel = maxf(_travel, cards[1].preview.ball.position.distance_to(_probe))
	if _clock < (ClassPreview.LOOP + 0.1 if _phase == "hover_check" else SETTLE) and _phase != "boot":
		return false
	match _phase:
		"boot":
			_game.ctx.calm = true
			_game.player.source = Intent.Scripted.new()
			_check_hints()
			for def in _game.flow.classes:
				_game.ctx.profile.unlock_pilot(def.id)
			_game.flow.press_start()
			_next("first_open")
		"first_open":
			# Pilot select opens on the first pilot (PF-40); the calm count is the row with every card shut.
			_report("pilot select opens on the first card", cards[0].is_open() and cards.slice(1).all(func(c): return not c.is_open()),
				"open %s" % [cards.map(func(c): return c.is_open())])
			var first := _words("first words")
			_report("the screen as it opens reads within the budget", first > 0 and first <= CALM_BUDGET,
				"%d words with the first card open (budget %d)" % [first, CALM_BUDGET])
			root.gui_release_focus()
			_next("rows")
		"rows":
			_check_rows(cards)
			_calm = _words("calm words")
			_calm_cards = cards.map(func(c): return WordBudget.count(c)["hud"])
			_report("calm budget", _calm > 0 and _calm <= CALM_BUDGET and cards.all(func(c): return not c.is_open()),
				"%d words with every card shut (budget %d)" % [_calm, CALM_BUDGET])
			Push.hover(root, cards[1])
			_next("hovered")
		"hovered":
			_probe = cards[1].preview.ball.position
			_next("hover_check")
		"hover_check":
			var open: Array = cards.map(func(c): return c.is_open())
			var moved := _travel > 2.0
			_report("hover opens one", open == _only(cards, 1) and cards[1].openness > 0.95 and cards[1].scale.x > cards[0].scale.x
					and cards[1].preview.playing() and not cards[0].preview.playing() and moved,
				"open %s, openness %.2f, scale %.3f vs %.3f, preview playing %s, the shell travelled %.1f m over a loop"
					% [open, cards[1].openness, cards[1].scale.x, cards[0].scale.x, cards[1].preview.playing(), _travel])
			var open_words := _words("open words")
			var now: Array = cards.map(func(c): return WordBudget.count(c)["hud"])
			_report("open words", open_words > _calm and open_words <= CALM_BUDGET and range(now.size()).all(func(j): return j == 1 or now[j] == _calm_cards[j])
					and open_words - _calm == now[1] - _calm_cards[1],
				"%d words with Rivet open (budget %d, %d shut); per card %s at rest, %s now" % [open_words, CALM_BUDGET, _calm, _calm_cards, now])
			# The title deals these cards once and keeps them (MG-09): one leaving pilot select open, shaken and
			# looked at comes back as a new card stands.
			var rivet = cards[1]
			rivet._shake = 0.2
			rivet.preview.look_drag(Vector2(30.0, 0.0))
			rivet.preview.look_dragging = true
			_game.flow.show_title()
			var preview = rivet.preview
			_report("a dealt card leaves pilot select at rest", is_instance_valid(rivet) and rivet.openness == 0.0 and rivet.scale == Vector2.ONE
					and rivet.modulate == Color.WHITE and rivet.rotation == 0.0 and preview.open == 0.0 and preview._time == 0.0
					and not preview.looking() and preview.look_weight == 0.0,
				"openness %.2f scale %s modulate %s rotation %.3f; preview open %.2f time %.2f looking %s weight %.2f" % [rivet.openness,
					rivet.scale, rivet.modulate, rivet.rotation, preview.open, preview._time, preview.looking(), preview.look_weight])
			_game.flow.press_start()
			_report("and comes back in the next pilot select", _game.screens.class_cards().has(rivet), "the same card dealt again")
			var away := InputEventMouseMotion.new()
			away.position = Vector2(4.0, 4.0)
			away.global_position = away.position
			root.push_input(away, true)
			root.gui_release_focus()
			Push.key(root, KEY_RIGHT)
			_next("first_key")
		"first_key":
			var first: Array = cards.map(func(c): return c.is_open())
			Push.key(root, KEY_RIGHT)
			_next("second_key")
			_report("arrow lands", first == _only(cards, 0), "the first Right with nothing focused opens %s" % [first])
		"second_key":
			var second: Array = cards.map(func(c): return c.is_open())
			_report("arrow moves", second == _only(cards, 1), "Right again opens %s" % [second])
			Push.key(root, KEY_ENTER)
			_next("picked")
		"picked":
			var def = _game.run.class_def
			_report("enter picks", _game.flow.in_play() and def != null and def.id == _game.flow.classes[1].id,
				"Enter on the open card started %s" % (def.id if def != null else "nothing"))
			print("ui_class_card_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
			quit(0 if _failures == 0 else 1)
			return true
	return false


# A locked card's hint is the class row's unlock label (with the lifetime count when the rule's
# achievement row needs several), empty only for a starter or a pilot with no label.
func _check_hints() -> void:
	for def in _game.flow.classes:
		var hint: String = ClassCard.unlock_hint(def, _game.progress)
		var id := Achievements.for_pilot(def.id)
		if def.starter:
			_report("hint %s" % def.display_name, hint == "", "starter hint \"%s\"" % hint)
		else:
			var want := ""
			if id != "":
				var label := String(def.unlock["label"])
				var need := int(Achievements.row(id).get("count", 1))
				want = label if need <= 1 else "%s (%d/%d)" % [label, mini(int(_game.progress.count_of(id)), need), need]
			_report("hint %s" % def.display_name, id != "" and hint == want, "hint \"%s\" for row %s, want \"%s\"" % [hint, id, want])
		var beat := Achievements.beat_of(id)
		var screen_hint: String = _game.screens._unlock_hint(def)
		_report("screen hint %s" % def.display_name, screen_hint == (hint if hint == "" or beat == "" else "%s\n%s" % [hint, beat]), "screens add the beat: \"%s\"" % screen_hint)
	_report("hint with no row", ClassCard.unlock_hint(_stub("no_such_pilot"), null) == "", "unknown pilot")
	_report("hint Rivet label", ClassCard.unlock_hint(_game.flow.classes[1], _game.progress) == "Open the cage. The runner never clocked out.", "class row label")
	_report("hint Kest text", ClassCard.unlock_hint(_game.flow.classes[2], _game.progress) == String(_game.flow.classes[2].unlock["label"]), "class row label")
	_report("hint Tarn text", ClassCard.unlock_hint(_game.flow.classes[3], _game.progress) == "Rout Brindle. Somebody signs on the day he falls.", "class row label")
	var by_id := {}
	for def in _game.flow.classes:
		by_id[def.id] = def
	_report("hint Tally text", ClassCard.unlock_hint(by_id["tally"], _game.progress).begins_with(String(by_id["tally"].unlock["label"])), "class row label, then the lifetime count")
	_report("hint cannon text", ClassCard.unlock_hint(by_id["remembered_cannon"], _game.progress) == String(by_id["remembered_cannon"].unlock["label"]), "class row label")


func _stub(id: String) -> Resource:
	var def: Resource = load("res://src/core/class_def.gd").new()
	def.id = id
	return def


# Each card's keys are its class row's slots, in the bar's order, with the ability
# rows' icons, then its Space extras.
# Re-pinned 2026-10-10 (wave 13 unit B2, SKILL-BAR section 5): a card shows the bar as it plays,
# [1 weapon] [2 special] [3 line skill] [Q ultimate], over a chip row [RMB harpoon] [Shift verb]
# [Ctrl smash] and the Space extras. Sable's harpoon chip is her grapple row and her Shift chip
# her boost. Was one row of LMB, RMB or Shift, F, Ctrl. The bar cells keep 2 or 3 words; the
# chips draw an icon and a small keycap and no words, so the six-card row keeps its floor.
const BAR_KEYS := ["key_1", "key_2", "key_3", "key_q"]
const CHIP_KEYS := ["key_rmb", "key_shift", "key_ctrl"]


func _icon(id: String) -> String:
	return String(AbilityState.ABILITIES.get(id, {}).get("icon", ""))


func _check_rows(cards: Array) -> void:
	var classes: Array = _game.flow.classes
	_report("one card per class", cards.size() == classes.size(), "%d cards for %d classes" % [cards.size(), classes.size()])
	for i in cards.size():
		var card = cards[i]
		var def = classes[i]
		var shown: Array = card.keys_shown()
		var grapple: bool = "grapple" in AbilityState.ABILITIES[def.movement_id].get("augments", [])
		var want_icons := [_icon(def.weapon_id), _icon(def.special_id), _icon(def.line_id), _icon(def.ultimate_id),
			_icon(def.movement_id) if grapple else Bindings.icon("harpoon"),
			Bindings.icon("boost") if grapple else _icon(def.movement_id), _icon(def.smash_id)]
		var want_keys: Array = BAR_KEYS + CHIP_KEYS
		var slots_ok := shown.size() >= want_keys.size()
		for j in mini(want_keys.size(), shown.size()):
			var words_ok: bool = shown[j]["words"].split(" ", false).size() in [2, 3] if j < BAR_KEYS.size() else shown[j]["words"] == ""
			slots_ok = slots_ok and shown[j]["key"] == want_keys[j] and shown[j]["icon"] == want_icons[j] and words_ok
		var rows: Array = card.key_rows()
		var rows_ok: bool = rows.size() == 2 and rows[0] == BAR_KEYS and rows[1].slice(0, 3) == CHIP_KEYS
		var extras: Array = shown.slice(want_keys.size()).map(func(k): return k["key"])
		var worn: Color = card.get_theme_stylebox("normal").border_color
		_report("%s keys" % def.display_name, slots_ok and rows_ok and extras.all(func(k): return k == "key_space")
				and card.def == def and Color(worn, 1.0).is_equal_approx(def.color),
			"shows %s; rows %s; extras %s; edge %s for row colour %s"
				% [shown.map(func(k): return "%s %s \"%s\"" % [k["key"], k["icon"], k["words"]]), rows, extras, worn.to_html(false), def.color.to_html(false)])


# Which cards should be open when only card `i` is: one entry per card on the row.
func _only(cards: Array, i: int) -> Array:
	var out := []
	for j in cards.size():
		out.append(j == i)
	return out
