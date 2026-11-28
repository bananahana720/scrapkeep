extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const WordBudget := preload("res://src/core/word_budget.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const StartPicks := preload("res://src/core/start_picks.gd")
const Parts := preload("res://src/build/parts.gd")
const Push := preload("res://tests/support/push.gd")

# The upgrade pick screen (v2 W8) and the run's briefing. A real run, the workshop armed as in play:
#   - the kit pick opens with the run, pauses the tree and holds the mouse and keys, and the start
#     pick's card waits behind it;
#   - its words stay inside the calm-screen budget;
#   - a mouse click on the second card takes that node, and the briefing turns to the start pick's
#     page: the tree stays paused, the mouse stays free, the job and the prompt show over the card;
#   - on that page a confirm with nothing focused takes nothing, D and A move between the tiles,
#     V rerolls, and Enter takes the focused tile; only then does the screen let go;
#   - D, A and Enter take the first card of the next pair, and the 2 key the second;
#   - Esc in the middle of the drop-in closes it with nothing left focused or held, the
#     pick stays open, and reopening in the middle of the fade-out keeps the screen up;
#   - a second run: Later (Esc) on the kit pick still turns to the start pick's page; Esc and P there
#     take nothing and open no pause menu (the page holds the screen as the kit page does), the pad's
#     first confirm only lands the focus and its second takes the tile;
#   - a third run: the 1 key takes a kit card, a click on Reroll rerolls, a click on the third tile
#     takes it.

const CALM_BUDGET := 40
const SETTLE := 20
# The start pick's page of the briefing, counted with Moss's bubble off (the bubble is the run
# start's own voice and is counted on the kit page above).
const BRIEF_BUDGET := 40

var _game
var _ws
var _failures := 0
var _phase := "boot"
var _wait := 0
var _offered: Array = []


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
			_next("opened")
		"opened":
			if _wait == SETTLE:
				var tree = _game.player.tree
				_offered = tree.offered(tree.class_id, 1).map(func(n): return n["id"])
				var cards: Array = _ws.pick.cards()
				_report("kit pick opens", _ws.pick.is_open() and cards.size() == 2 and paused and _game.get_meta("menu_held", false)
						and cards.map(func(c): return c.node_id()) == _offered,
					"open %s, cards %s for offered %s, tree paused %s, menu held %s"
						% [_ws.pick.is_open(), cards.map(func(c): return c.node_id()), _offered, paused, _game.get_meta("menu_held", false)])
				_report("start card waits behind the kit pick", not _card().showing() and not _ws.briefing() and not _ws.brief.visible and _taken() == "",
					"card showing %s, briefing %s, veil %s" % [_card().showing(), _ws.briefing(), _ws.brief.visible])
				var seen: Dictionary = WordBudget.count(_ws)
				print("  pick words: " + " | ".join(seen["items"].map(func(i): return "%s %d \"%s\"" % [i["node"], i["words"], i["text"]])))
				_report("pick word budget", seen["hud"] <= CALM_BUDGET and seen["hud"] > 0, "%d words on the pick screen (budget %d)" % [seen["hud"], CALM_BUDGET])
				Push.hover(root, cards[1])
				var lit: bool = cards[1].has_focus()
				Push.click(root, cards[1])
				var path: Array = tree.path()
				_report("mouse pick", lit and path == [_offered[1]] and not _ws.pick.is_open(),
					"hover focused the second card %s; after the click the path is %s, open %s" % [lit, path, _ws.pick.is_open()])
				_report("briefing turns to the start pick", _briefed(),
					"briefing %s, card showing %s, veil %s, paused %s, held %s, mouse captured %s"
						% [_ws.briefing(), _card().showing(), _ws.brief.visible, paused, _game.get_meta("menu_held", false), _game.mouse_captured()])
				_next("brief")
		"brief":
			if _wait == SETTLE:
				var card = _card()
				# The card reports its tiles and its tier line (drawn_words); Reroll is its one other word-bearer here.
				var seen: Dictionary = WordBudget.count(_ws.brief)
				var on_card: Array = Array(card.drawn_words()) + [card.reroll_button.text]
				var tiles: int = WordBudget.words_in(" ".join(on_card))
				print("  brief words: " + " | ".join(seen["items"].map(func(i): return "%d \"%s\"" % [i["words"], i["text"]]) + on_card))
				_report("brief word budget", seen["hud"] + tiles <= BRIEF_BUDGET and seen["hud"] > 0 and tiles > 0,
					"%d words over the card and %d on it (budget %d)" % [seen["hud"], tiles, BRIEF_BUDGET])
				# The draw above is one of many; this is every pilot's wordiest three tiles on the same page.
				var fixed: int = seen["hud"] + WordBudget.words_in(card.UNLOCK_WORDS) + WordBudget.words_in(card.reroll_button.text)
				var worst := 0
				var worst_pilot := ""
				for def in ClassDef.all():
					var part_info := func(pid: String) -> Dictionary: return {"name": Parts.display_name(pid), "icon": Parts.icon_of(pid), "effect": String(Parts.row(pid).get("verb", ""))}
					var counts: Array = StartPicks.ids_for(def.id).map(func(id):
						var row: Dictionary = StartPicks.row(def.id, String(id), part_info)
						return WordBudget.words_in(String(row["name"])) + WordBudget.words_in(String(row.get("effect", ""))))
					counts.sort()
					counts.reverse()
					var top: int = counts.slice(0, StartPicks.OFFERED).reduce(func(a, b): return a + b, 0)
					if top > worst:
						worst = top
						worst_pilot = String(def.id)
				_report("brief word budget, wordiest draw", fixed + worst <= BRIEF_BUDGET and worst > 0,
					"%d fixed words and %d on %s's wordiest three tiles (budget %d)" % [fixed, worst, worst_pilot, BRIEF_BUDGET])
				var rows: Array = _ws.brief.get_children().map(func(c): return c.text)
				_report("brief rows", rows == [_ws.BRIEF_LINE, _ws.BRIEF_WORDS]
						and _ws.brief.get_children().all(func(c): return c.position.y + c.size.y <= card.position.y + 1.0 and c.position.y >= 0.0),
					"rows %s, all above the card at y %.0f" % [rows, card.position.y])
				var inside: bool = Rect2(Vector2.ZERO, _ws.screen_size()).encloses(card.get_global_rect())
				_report("card inside the screen", inside, "card %s on screen %s" % [card.get_global_rect(), _ws.screen_size()])
				Push.key(root, KEY_ENTER)
				Push.key(root, KEY_SPACE)
				_report("confirm with nothing focused takes nothing", _taken() == "" and _briefed() and card.focused_tile() == -1,
					"taken '%s', briefed %s, focused tile %d" % [_taken(), _briefed(), card.focused_tile()])
				Push.key(root, KEY_D)
				var first: int = card.focused_tile()
				Push.key(root, KEY_D)
				var second: int = card.focused_tile()
				Push.key(root, KEY_A)
				var back: int = card.focused_tile()
				Push.key(root, KEY_RIGHT)
				Push.key(root, KEY_RIGHT)
				var third: int = card.focused_tile()
				# Past the last tile the focus walks on to Reroll, so the pad reaches it too.
				Push.key(root, KEY_RIGHT)
				var on_reroll: bool = card.reroll_button.has_focus()
				Push.key(root, KEY_LEFT)
				_report("D, A and the arrows move the focus", first == 0 and second == 1 and back == 0 and third == 2 and on_reroll and card.focused_tile() == 2 and _taken() == "",
					"D %d, D %d, A %d, right twice %d, right again on Reroll %s, left %d" % [first, second, back, third, on_reroll, card.focused_tile()])
				# Tab and the pad's Back open no notes over the page: the notes would let go of the pause.
				Push.key(root, KEY_TAB)
				Push.pad(root, JOY_BUTTON_BACK)
				_report("the notes stay shut over the briefing", not _game.notes_held() and _briefed(), "notes held %s, briefed %s" % [_game.notes_held(), _briefed()])
				var rerolls: int = card.rerolls_left()
				Push.key(root, KEY_V)
				_report("V rerolls in the briefing", _card().rerolls_left() == rerolls - 1 and _briefed(),
					"rerolls %d -> %d, briefed %s" % [rerolls, _card().rerolls_left(), _briefed()])
				_next("brief_take")
		"brief_take":
			if _wait == 2:
				var card = _card()
				var options: Array = _game.run.start_pick_options()
				Push.key(root, KEY_D)
				Push.key(root, KEY_D)
				Push.key(root, KEY_ENTER)
				_report("Enter takes the focused tile", _taken() == String(options[1]), "took '%s' of %s" % [_taken(), options])
				_report("briefing lets go", not card.showing() and not _ws.briefing() and not _ws.brief.visible and not paused and not _game.get_meta("menu_held", false),
					"card showing %s, briefing %s, veil %s, paused %s, held %s" % [card.showing(), _ws.briefing(), _ws.brief.visible, paused, _game.get_meta("menu_held", false)])
				_game.player.tree.open_checkpoint()
				_next("keys")
		"keys":
			if _wait == SETTLE:
				var tree = _game.player.tree
				_offered = tree.offered(tree.class_id, 2).map(func(n): return n["id"])
				var cards: Array = _ws.pick.cards()
				Push.key(root, KEY_D)
				var right: bool = cards[1].has_focus()
				Push.key(root, KEY_A)
				var left: bool = cards[0].has_focus()
				Push.key(root, KEY_ENTER)
				_report("keys pick", right and left and tree.path().size() == 2 and tree.path()[1] == _offered[0],
					"D focused the right card %s, A the left %s; Enter took %s of %s"
						% [right, left, tree.path().back(), _offered])
				tree.open_checkpoint()
				_next("number")
		"number":
			if _wait == SETTLE:
				var tree = _game.player.tree
				_offered = tree.offered(tree.class_id, 3).map(func(n): return n["id"])
				Push.key(root, KEY_2)
				_report("number key pick", tree.path().size() == 3 and tree.path()[2] == _offered[1] and not _ws.pick.is_open(),
					"2 took %s of %s" % [tree.path().back(), _offered])
				tree.open_checkpoint()
				_next("interrupt")
		"interrupt":
			if _wait == 2:
				var opened: bool = _ws.pick.is_open()
				Push.key(root, KEY_ESCAPE)
				_report("esc mid drop-in", opened and not _ws.pick.is_open() and not paused and not _game.get_meta("menu_held", false)
						and _game.player.tree.pending(),
					"open before %s; after Esc open %s, paused %s, held %s, pick still pending %s"
						% [opened, _ws.pick.is_open(), paused, _game.get_meta("menu_held", false), _game.player.tree.pending()])
				_next("settled_closed")
		"settled_closed":
			if _wait == 60:
				var owner: Control = root.gui_get_focus_owner()
				_report("no stuck focus", not _ws.pick.visible and (owner == null or owner.is_visible_in_tree()),
					"pick visible %s after its fade; focus owner %s" % [_ws.pick.visible, owner])
				_ws.open_pick()
				_next("reopen_cut")
		"reopen_cut":
			if _wait == 3:
				_ws.close_pick()
				_ws.open_pick()
				_next("reopen_settled")
		"reopen_settled":
			if _wait == 60:
				var cards: Array = _ws.pick.cards()
				var owner: Control = root.gui_get_focus_owner()
				_report("reopen mid fade-out", _ws.pick.visible and _ws.pick.is_open() and cards.size() == 2 and owner == cards[0] and paused,
					"visible %s, open %s, focus on the first card %s, paused %s" % [_ws.pick.visible, _ws.pick.is_open(), owner == cards[0] if cards.size() > 0 else false, paused])
				Push.key(root, KEY_1)
				_report("last pick", _game.player.tree.path().size() == 4 and not _game.player.tree.pending() and not paused,
					"path %s" % [_game.player.tree.path()])
				_game.flow._begin_run(ClassDef.all()[0])
				_next("second_run")
		"second_run":
			if _wait == SETTLE:
				var card = _card()
				var opened: bool = _ws.pick.is_open() and not card.showing()
				Push.key(root, KEY_ESCAPE)
				_report("Later on the kit pick still briefs", opened and not _ws.pick.is_open() and _game.player.tree.pending() and _briefed(),
					"kit pick first %s; after Esc open %s, pick still owed %s, briefed %s" % [opened, _ws.pick.is_open(), _game.player.tree.pending(), _briefed()])
				_next("second_menu")
		"second_menu":
			if _wait == 2:
				# game.gd reads its own keys only outside test mode, so this case plays as a launched game.
				var menu = _game.get_node_or_null("PauseMenu")
				_game.test_mode = false
				Push.key(root, KEY_ESCAPE)
				Push.key(root, KEY_P)
				_game.test_mode = true
				_game.bot_driven = false
				_report("Esc and P leave the briefing up", menu != null and not menu.is_open() and _taken() == "" and _briefed(),
					"pause menu open %s, taken '%s', briefed %s" % [menu != null and menu.is_open(), _taken(), _briefed()])
				_next("second_pad")
		"second_pad":
			if _wait == 4:
				var card = _card()
				var options: Array = _game.run.start_pick_options()
				var held: bool = _briefed()
				Push.pad(root, JOY_BUTTON_A)
				var landed: bool = _taken() == "" and card.focused_tile() == 0
				Push.pad(root, JOY_BUTTON_A)
				_report("pad confirm lands, then takes", held and landed and _taken() == String(options[0]) and not paused and not _card().showing(),
					"briefed after the menu closed %s; first press landed the focus %s; second took '%s' of %s; paused %s"
						% [held, landed, _taken(), options, paused])
				_game.flow._begin_run(ClassDef.all()[0])
				_next("third_run")
		"third_run":
			if _wait == SETTLE:
				var tree = _game.player.tree
				_offered = tree.offered(tree.class_id, 1).map(func(n): return n["id"])
				Push.key(root, KEY_1)
				_report("1 takes the first kit card, not a tile", tree.path() == [_offered[0]] and _taken() == "" and _briefed(),
					"path %s of %s, start pick '%s', briefed %s (kit pick open %s, card showing %s, paused %s, held %s, captured %s)"
						% [tree.path(), _offered, _taken(), _briefed(), _ws.pick.is_open(), _card().showing(), paused, _game.get_meta("menu_held", false), _game.mouse_captured()])
				_next("third_mouse")
		"third_mouse":
			if _wait == 2:
				var card = _card()
				var rerolls: int = card.rerolls_left()
				Push.click(root, card.reroll_button)
				var rerolled: bool = _card().rerolls_left() == rerolls - 1 and _briefed()
				var options: Array = _game.run.start_pick_options()
				_click_at(card.global_position + card.tile_rects()[2].get_center())
				_report("mouse rerolls and takes the third tile", rerolled and _taken() == String(options[2]) and not paused and not _game.get_meta("menu_held", false),
					"rerolled %s; click took '%s' of %s; paused %s, held %s" % [rerolled, _taken(), options, paused, _game.get_meta("menu_held", false)])
				print("ui_workshop_pick_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
				quit(0 if _failures == 0 else 1)
				return true
	return false


func _next(phase: String) -> void:
	_phase = phase
	_wait = 0


func _card():
	return _game.flow.start_card


# The start pick taken this run, "" while it is still owed.
func _taken() -> String:
	return String(_game.run.start_pick.get("taken", ""))


# The briefing's start pick page is up and holds the game: paused, the mouse free, the veil drawn.
func _briefed() -> bool:
	return _ws.briefing() and _card().showing() and _ws.brief.visible and paused \
		and _game.get_meta("menu_held", false) and not _game.mouse_captured()


func _click_at(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	root.push_input(motion, true)
	for pressed in [true, false]:
		var button := InputEventMouseButton.new()
		button.button_index = MOUSE_BUTTON_LEFT
		button.pressed = pressed
		button.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		button.position = at
		button.global_position = at
		root.push_input(button, true)
