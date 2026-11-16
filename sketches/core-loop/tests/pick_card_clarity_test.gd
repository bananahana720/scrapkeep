extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Cards := preload("res://src/core/trees/world_one_cards.gd")
const WordFxWord := preload("res://src/presentation/world_fx/world_fx_word.gd")
const Push := preload("res://tests/workshop/push.gd")

# The kit pick a first-timer can read (PF-01, PF-10, PF-30):
#   - copy: no sentence appears on two world-one cards, none of the old jargon lines survives, and
#     every card's first sentence is within the word budget;
#   - taking a card marks it with the amber, the edge weight and the pop, and no word, and the kit's
#     name toasts once, after the screen has left; a skipped depth reopens the screen without
#     closing it, and its two kits share one toast after the final close;
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
var _name := ""
var _chain: Array = []
var _skip_names: Array = []
var _watched := 0
var _after_card := false
var _early: Array = []


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
				_report("a1 taken card marked, with no word", cards[0].is_taken() and not cards[1].is_taken() and _ws.pick.visible and _no_taken_label(cards[0]),
					"card 0 taken %s, card 1 taken %s, screen still up %s" % [cards[0].is_taken(), cards[1].is_taken(), _ws.pick.visible])
				_report("a2 no toast while the pick is up", _game.hud.toast_texts().is_empty() and _ws.pick.visible, "toasts %s" % [_game.hud.toast_texts()])
				_name = name_of
				_next("brief")
		"brief":
			if _wait >= SETTLE and _ws.pick.visible and _wait < 600:
				return false
			if _wait >= SETTLE:
				var toasts: Array = _game.hud.toast_texts()
				_report("a2 kit named once after the pick is gone", not _ws.pick.visible and toasts == [_name + " taken"], "toast %s for %s, pick visible %s" % [toasts, _name, _ws.pick.visible])
				Push.key(root, KEY_D)
				Push.key(root, KEY_ENTER)
				_next("stage_card")
		"stage_card":
			if _game.hud.launch_card.showing() and _wait < 1500:
				return false
			if not _after_card:
				_after_card = true
				return false
			var left: float = float(_game.hud._toast.get("left", 0.0))
			_report("t2 the kit toast is shown when the stage card ends, with its life intact", _game.hud.toast_texts() == [_name + " taken"] and left > 2.4,
				"toasts %s, %.2f s left after %d frames" % [_game.hud.toast_texts(), left, _wait])
			_next("t_expire")
		"t_expire":
			if not _game.hud.toast_texts().is_empty() and _wait < 900:
				return false
			_report("t3 the kit toast then expires", _game.hud.toast_texts().is_empty(), "toasts %s after %d frames" % [_game.hud.toast_texts(), _wait])
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
				_next("chain_open")
		"chain_open":
			if _wait >= 3 and not _ws.pick.visible:
				_game.hud.launch_card.visible = false
				_game.player.tree.open_checkpoint()
				_next("chain_pick")
		"chain_pick":
			if _wait > 600:
				_report("a3 the pick opened", false, "no open pick after %d frames" % _wait)
				_finish()
				return true
			if _wait >= SETTLE and _ws.pick.is_open():
				_name = String(_ws.pick.cards()[1].node.get("name", ""))
				Push.key(root, KEY_2)
				_next("chain_gone")
		"chain_gone":
			if _ws.pick.visible and _wait < 600:
				return false
			_report("a3 the screen has gone", not _ws.pick.visible, "visible %s after %d frames" % [_ws.pick.visible, _wait])
			var seen: Array = _game.hud.toast_texts()
			_chain.append(seen.duplicate())
			_report("a3 pick %d toasts its kit once" % _chain.size(), seen.count(_name + " taken") == 1, "toasts %s for %s" % [seen, _name])
			if _chain.size() < 2:
				_next("chain_open")
				return false
			_next("skip_open")
		"skip_open":
			# A fresh tree owing two picks at once: choosing the first reopens the same screen.
			if _wait == 3:
				_game.hud.drop_toast(_game.hud.toast_texts()[0] if not _game.hud.toast_texts().is_empty() else "")
				_game.hud.launch_card.visible = false
				var tree = _game.player.tree
				tree.reset(tree.class_id)
				tree.open_checkpoint()
				tree.open_checkpoint()
				_next("skip_first")
		"skip_first":
			if _wait > 600:
				_report("s1 the first pick opened", false, "no open pick after %d frames" % _wait)
				_finish()
				return true
			if _wait >= SETTLE * 2 and _ws.pick.is_open() and _ws.pick.depth == 1:
				_skip_names.append(String(_ws.pick.cards()[0].node.get("name", "")))
				Push.key(root, KEY_1)
				_next("skip_second")
		"skip_second":
			if _wait > 600:
				_report("s1 the second pick opened", false, "no reopened pick after %d frames" % _wait)
				_finish()
				return true
			_watch_toasts()
			if _wait >= SETTLE and _ws.pick.is_open() and _ws.pick.depth == 2:
				_skip_names.append(String(_ws.pick.cards()[1].node.get("name", "")))
				Push.key(root, KEY_2)
				_next("skip_gone")
		"skip_gone":
			_watch_toasts()
			if _ws.pick.visible and _wait < 600:
				return false
			var seen: Array = _game.hud.toast_texts()
			var want: String = ", ".join(_skip_names) + " taken"
			_report("s2 the screen has gone", not _ws.pick.visible, "visible %s after %d frames" % [_ws.pick.visible, _wait])
			_report("s3 no toast at any frame while the pick was up", _watched > 0 and _early.is_empty(), "%d frames watched, toasts seen %s" % [_watched, _early])
			_report("s4 one toast names both kits in order", _skip_names.size() == 2 and seen == [want], "toast %s, want [%s]" % [seen, want])
			_toast_life()
			_finish()
			return true
	return false


# The HUD's toast lifetime, stepped by hand: the hold for an unseen toast must not freeze one in
# play, and a toast hushed or held under a card shows for its full life once it can be seen.
func _toast_life() -> void:
	var hud = _game.hud
	hud.drop_toast(hud.toast_texts()[0] if not hud.toast_texts().is_empty() else "")
	hud.launch_card.visible = false
	hud.toast("Plain toast")
	hud._step_toast(0.0)
	hud._step_toast(2.0)
	var mid: bool = hud.toast_texts() == ["Plain toast"]
	hud._step_toast(0.8)
	_report("t4 an ordinary toast expires in its normal time", mid and hud.toast_texts().is_empty(), "present at 2.0 s %s, after 2.8 s %s" % [mid, hud.toast_texts()])
	hud.quiet(true)
	hud.toast("Hushed toast")
	hud._step_toast(10.0)
	var held: bool = hud.toast_texts() == ["Hushed toast"]
	hud.quiet(false)
	hud._step_toast(0.0)
	hud._step_toast(2.5)
	var shown: bool = hud.toast_texts() == ["Hushed toast"]
	hud._step_toast(0.4)
	_report("t5 a toast held under quiet shows for its full life after quiet ends", held and shown and hud.toast_texts().is_empty(),
		"kept through 10 s of quiet %s, still up 2.5 s after %s, gone after 2.9 s %s" % [held, shown, hud.toast_texts().is_empty()])


func _watch_toasts() -> void:
	if _ws.pick.visible:
		_watched += 1
		for text in _game.hud.toast_texts():
			_early.append(text)


func _finish() -> void:
	print("pick_card_clarity_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


# No label on the card says "Taken": the colour carries it.
func _no_taken_label(card: Control) -> bool:
	for node in card.find_children("*", "Label", true, false):
		if (node as Label).text == "Taken":
			return false
	return true


func _next(phase: String) -> void:
	_phase = phase
	_wait = 0
