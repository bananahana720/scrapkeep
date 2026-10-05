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
#   - every card shows its class row's four slots (LMB, then RMB or Shift by pilot, F, Ctrl) with the row's
#     ability icons, plus its Space extra, and wears the row's colour;
#   - at rest the whole screen reads in 50 words or fewer;
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
			_next("rows")
		"rows":
			_check_rows(cards)
			_calm = _words("calm words")
			_calm_cards = cards.map(func(c): return WordBudget.count(c)["hud"])
			_report("calm budget", _calm > 0 and _calm <= CALM_BUDGET and cards.all(func(c): return not c.is_open()),
				"%d words with no card open (budget %d)" % [_calm, CALM_BUDGET])
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
			_report("open words", open_words > _calm and range(now.size()).all(func(j): return j == 1 or now[j] == _calm_cards[j])
					and open_words - _calm == now[1] - _calm_cards[1],
				"%d words with Rivet open (%d at rest); per card %s at rest, %s now" % [open_words, _calm, _calm_cards, now])
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


# A locked card's hint is the pilot's reward row text (with the lifetime count when the row
# needs several), empty only for a pilot no row rewards (the starters) or a hidden row.
func _check_hints() -> void:
	for def in _game.flow.classes:
		var hint: String = ClassCard.unlock_hint(def, _game.progress)
		var id := Achievements.for_pilot(def.id)
		if def.starter:
			_report("hint %s" % def.display_name, hint == "", "starter hint \"%s\"" % hint)
		else:
			var want := ""
			if id != "":
				var r: Dictionary = Achievements.row(id)
				var need := int(r.get("count", 1))
				want = str(r["text"]) if need <= 1 else "%s (%d/%d)" % [r["text"], mini(int(_game.progress.count_of(id)), need), need]
			_report("hint %s" % def.display_name, id != "" and hint == want, "hint \"%s\" for row %s, want \"%s\"" % [hint, id, want])
		_report("screen hint %s" % def.display_name, _game.screens._unlock_hint(def) == hint, "screens agree")
	_report("hint with no row", ClassCard.unlock_hint(_stub("no_such_pilot"), null) == "", "unknown pilot")
	_report("hint Rivet starter", ClassCard.unlock_hint(_game.flow.classes[1], _game.progress) == "", "Rivet is a starter until a rescue emitter exists")
	_report("hint Kest text", ClassCard.unlock_hint(_game.flow.classes[2], _game.progress) == Achievements.row(Achievements.for_pilot("demolitions_caster"))["text"], "row text")
	_report("hint Tarn text", ClassCard.unlock_hint(_game.flow.classes[3], _game.progress) == "Rout Admiral Brindle.", "row text")
	var by_id := {}
	for def in _game.flow.classes:
		by_id[def.id] = def
	_report("hint Tally text", ClassCard.unlock_hint(by_id["tally"], _game.progress).begins_with(Achievements.row("ledger_balanced")["text"]), "row text, then the lifetime count")
	_report("hint cannon text", ClassCard.unlock_hint(by_id["remembered_cannon"], _game.progress) == Achievements.row("mind_quieted")["text"], "row text")


func _stub(id: String) -> Resource:
	var def: Resource = load("res://src/core/class_def.gd").new()
	def.id = id
	return def


# Each card's keys are its class row's slots, in the bar's order, with the ability
# rows' icons, then its Space extras.
func _check_rows(cards: Array) -> void:
	var classes: Array = _game.flow.classes
	_report("one card per class", cards.size() == classes.size(), "%d cards for %d classes" % [cards.size(), classes.size()])
	for i in cards.size():
		var card = cards[i]
		var def = classes[i]
		var shown: Array = card.keys_shown()
		var want := []
		for slot in AbilityState.SLOTS:
			want.append({"key": Bindings.glyph(ClassKit.slot_verb(slot, def)),
				"icon": AbilityState.ABILITIES[def.get("%s_id" % slot)]["icon"]})
		var slots_ok := shown.size() >= 4
		for j in mini(4, shown.size()):
			slots_ok = slots_ok and shown[j]["key"] == want[j]["key"] and shown[j]["icon"] == want[j]["icon"] \
				and shown[j]["words"].split(" ", false).size() in [2, 3]
		var extras: Array = shown.slice(4).map(func(k): return k["key"])
		var want_extras: Array = ClassKit.card_keys(def).slice(4).map(func(k): return k["key"])
		var worn: Color = card.get_theme_stylebox("normal").border_color
		_report("%s keys" % def.display_name, slots_ok and extras == want_extras and extras.all(func(k): return k == "key_space")
				and card.def == def and Color(worn, 1.0).is_equal_approx(def.color),
			"shows %s; extras %s; edge %s for row colour %s"
				% [shown.map(func(k): return "%s %s \"%s\"" % [k["key"], k["icon"], k["words"]]), extras, worn.to_html(false), def.color.to_html(false)])


# Which cards should be open when only card `i` is: one entry per card on the row.
func _only(cards: Array, i: int) -> Array:
	var out := []
	for j in cards.size():
		out.append(j == i)
	return out
