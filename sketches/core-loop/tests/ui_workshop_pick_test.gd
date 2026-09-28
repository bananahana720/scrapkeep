extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const WordBudget := preload("res://src/ui/word_budget.gd")
const Push := preload("res://tests/workshop/push.gd")

# The upgrade pick screen (v2 W8). A real run, the workshop armed as in play:
#   - the start pick opens with the run, pauses the tree and holds the mouse and keys;
#   - its words stay inside the calm-screen budget;
#   - a mouse click on the second card takes that node, and the screen lets go;
#   - D, A and Enter take the first card of the next pair, and the 2 key the second;
#   - Esc in the middle of the drop-in closes it with nothing left focused or held, the
#     pick stays open, and reopening in the middle of the fade-out keeps the screen up.

const CALM_BUDGET := 40
const SETTLE := 20

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
			_ws = _game.workshop
			_ws.armed = true
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
				_report("start pick opens", _ws.pick.is_open() and cards.size() == 2 and paused and _game.menu_held()
						and cards.map(func(c): return c.node_id()) == _offered,
					"open %s, cards %s for offered %s, tree paused %s, menu held %s"
						% [_ws.pick.is_open(), cards.map(func(c): return c.node_id()), _offered, paused, _game.menu_held()])
				var seen: Dictionary = WordBudget.count(_ws)
				print("  pick words: " + " | ".join(seen["items"].map(func(i): return "%s %d \"%s\"" % [i["node"], i["words"], i["text"]])))
				_report("pick word budget", seen["hud"] <= CALM_BUDGET and seen["hud"] > 0, "%d words on the pick screen (budget %d)" % [seen["hud"], CALM_BUDGET])
				Push.hover(root, cards[1])
				var lit: bool = cards[1].has_focus()
				Push.click(root, cards[1])
				var path: Array = tree.path()
				_report("mouse pick", lit and path == [_offered[1]] and not _ws.pick.is_open() and not paused and not _game.menu_held(),
					"hover focused the second card %s; after the click the path is %s, open %s, paused %s, held %s"
						% [lit, path, _ws.pick.is_open(), paused, _game.menu_held()])
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
				_report("esc mid drop-in", opened and not _ws.pick.is_open() and not paused and not _game.menu_held()
						and _game.player.tree.pending(),
					"open before %s; after Esc open %s, paused %s, held %s, pick still pending %s"
						% [opened, _ws.pick.is_open(), paused, _game.menu_held(), _game.player.tree.pending()])
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
				print("ui_workshop_pick_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
				quit(0 if _failures == 0 else 1)
				return true
	return false


func _next(phase: String) -> void:
	_phase = phase
	_wait = 0
