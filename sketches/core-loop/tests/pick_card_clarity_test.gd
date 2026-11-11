extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Cards := preload("res://src/core/trees/world_one_cards.gd")
const WordFxWord := preload("res://src/presentation/world_fx/world_fx_word.gd")
const Push := preload("res://tests/workshop/push.gd")

# The kit pick a first-timer can read (PF-01, PF-10, PF-30):
#   - copy: no sentence appears on two world-one cards, none of the old jargon lines survives, and
#     every card's first sentence is within the word budget;
#   - taking a card marks it "Taken" before the screen leaves and the kit's name toasts once;
#   - while a pick card is up in the middle of a fight, the "Paused" line shows and the hit
#     word, the synergy callout, the toast row and Moss's line behind it do not; they come back
#     after the pick;
#   - pick_quiet.gd reaches the HUD through quiet() alone: no tree walk, no read of a HUD member.

const FIRST_LINE_WORDS := 8
const OLD_LINES := [
	"Vault kicks zap what's near.", "Mount walls from twice as far.", "Vaults restore jumps. Heavy fins steer harder.",
]
const SETTLE := 20

var _game
var _ws
var _failures := 0
var _phase := "boot"
var _wait := 0
var _word: Label3D
var _hidden_words := 0


func _initialize() -> void:
	_copy()
	_quiet_source()
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _copy() -> void:
	var seen := {}
	var dupes: Array = []
	var long: Array = []
	var jargon: Array = []
	for id in Cards.ROWS:
		var line := String(Cards.ROWS[id])
		for old in OLD_LINES:
			if line.contains(old) or line == old:
				jargon.append(id)
		var first := true
		for sentence in line.split(".", false):
			var text := sentence.strip_edges()
			if first and text.split(" ", false).size() > FIRST_LINE_WORDS:
				long.append(id)
			first = false
			if seen.has(text):
				dupes.append("%s/%s: %s" % [seen[text], id, text])
			seen[text] = id
	_report("no sentence on two cards", dupes.is_empty(), "%d rows, repeats %s" % [Cards.ROWS.size(), dupes])
	_report("old jargon lines gone", jargon.is_empty(), "still present on %s" % [jargon])
	_report("first lines within the budget", long.is_empty(), "over %d words: %s" % [FIRST_LINE_WORDS, long])


# pick_quiet.gd calls hud.quiet and the word effects' quiet, and nothing else of the HUD's.
func _quiet_source() -> void:
	var text := FileAccess.get_file_as_string("res://src/ui/pick_quiet.gd")
	var reaches: Array = []
	for banned in ["get_tree", "find_children", "get_children"]:
		if text.contains(banned):
			reaches.append(banned)
	var hud_calls := RegEx.create_from_string("hud[.\\w]*")
	for found in hud_calls.search_all(text):
		var member := found.get_string()
		if member != "hud" and member != "hud.quiet" and not text.contains("# " + member):
			reaches.append(member)
	_report("pick_quiet reaches the HUD only through quiet", reaches.is_empty(), "reaches %s" % [reaches])


func _process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_wait += 1
	match _phase:
		"boot":
			_ws = _game.get_node("Workshop")
			_ws.armed = true
			_game.bot_driven = false
			_game.ctx.calm = true
			_game.player.source = Intent.Scripted.new()
			_game.flow.press_start()
			_game.flow.choose_class(0)
			_next("first")
		"first":
			if _wait == SETTLE:
				var cards: Array = _ws.pick.cards()
				var name_of: String = String(cards[0].node.get("name", ""))
				_report("held line on the first pick", _ws.pick.held_text() != "" and paused, "line '%s', tree paused %s" % [_ws.pick.held_text(), paused])
				Push.key(root, KEY_1)
				_report("taken card marked", cards[0].taken_text() == "Taken" and cards[1].taken_text() == "" and _ws.pick.visible,
					"card 0 '%s', card 1 '%s', screen still up %s" % [cards[0].taken_text(), cards[1].taken_text(), _ws.pick.visible])
				var toasts: Array = _game.hud.toast_texts()
				_report("kit named once", toasts == [name_of + " taken"], "toast %s for %s" % [toasts, name_of])
				_next("brief")
		"brief":
			if _wait == SETTLE:
				Push.key(root, KEY_D)
				Push.key(root, KEY_ENTER)
				_next("fight")
		"fight":
			if _wait == SETTLE:
				# A fight in progress: a hit word in the world, a synergy callout and Moss's line up.
				_word = WordFxWord.stamp(_game, "KA-CHUNK", Vector3.ZERO)
				_game.events.cause_fired.emit("wrecking_ball", null, _game.player.ball_position())
				_ws.bubble.beat({"text": "Mind the gap."})
				# The stage card holds the toast row back; clear it so the row can show.
				_game.hud.launch_card.visible = false
				_game.hud.toast("Test toast")
				_next("fight_up")
		"fight_up":
			if _wait == 10:
				_report("the fight words are up before the pick", _ws.bubble.showing() and _word.is_visible_in_tree() and _game.hud.why_callout.is_visible_in_tree(),
					"Moss's line %s, hit word %s, callout %s" % [_ws.bubble.showing(), _word.is_visible_in_tree(), _game.hud.why_callout.is_visible_in_tree()])
				_report("the toast row is up before the pick", _game.hud._toast_row.is_visible_in_tree(), "toast row visible %s, launch card %s, toasts %s" % [_game.hud._toast_row.is_visible_in_tree(), _game.hud.launch_card.showing(), _game.hud.toast_texts()])
				_game.player.tree.open_checkpoint()
				_next("held")
		"held":
			if _wait == 3:
				var open: bool = _ws.pick.is_open()
				_report("held line shows mid-fight", open and _ws.pick.held_text() != "", "open %s, line '%s'" % [open, _ws.pick.held_text()])
				_report("the toast row is hidden behind the card", not _game.hud._toast_row.is_visible_in_tree(), "toast row visible %s" % _game.hud._toast_row.is_visible_in_tree())
				_report("fight words hidden behind the card", _ws.bubble.showing() == false and not _word.is_visible_in_tree() and not _ws.bubble.is_visible_in_tree() and not _game.hud.why_callout.is_visible_in_tree(),
					"hit word %s, Moss's line %s, callout %s" % [_word.is_visible_in_tree(), _ws.bubble.is_visible_in_tree(), _game.hud.why_callout.is_visible_in_tree()])
				Push.key(root, KEY_1)
				_next("after")
		"after":
			if _wait == 3:
				_report("the toast row returns after the pick", not _game.hud.toast_texts().is_empty() and _game.hud._toast_row.is_visible_in_tree(), "toast row visible %s, toasts %s" % [_game.hud._toast_row.is_visible_in_tree(), _game.hud.toast_texts()])
				_report("fight words return after the pick", not _ws.pick.is_open() and _word.is_visible_in_tree() and _ws.bubble.showing() and _game.hud.why_callout.is_visible_in_tree(),
					"pick open %s, hit word %s, Moss's line %s, callout %s" % [_ws.pick.is_open(), _word.is_visible_in_tree(), _ws.bubble.showing(), _game.hud.why_callout.is_visible_in_tree()])
				print("pick_card_clarity_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
				quit(0 if _failures == 0 else 1)
				return true
	return false


func _next(phase: String) -> void:
	_phase = phase
	_wait = 0
