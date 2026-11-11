extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Shop := preload("res://src/build/shop.gd")
const Parts := preload("res://src/build/parts.gd")
const WordBudget := preload("res://src/ui/word_budget.gd")
const Push := preload("res://tests/workshop/push.gd")

# Moss's counter and his conversation loop (v2 W8), on a real run with the workshop
# armed. The bay's catch is the shop's own enter(), the call world makes.
#   - Pulling up opens the counter: the ball parks and the mouse and keys are held.
#   - Its words stay inside the calm-screen budget on both faces.
#   - A click on a shelf plate buys: cogs drop by the record's price, the part is held,
#     and the bubble says the record's bark. Too poor: nothing changes but the bark.
#   - The reroll by keys and a sell by click change cogs and parts as their records say.
#   - The waiting pick's plate opens the pick in the counter's place and hands back.
#   - T plays the six beats with rising exasperation, then the restart, and once the ball
#     is heavy enough (scrap mass; under armour parts add no heft) the relent, which unlocks the hook.
#   - Esc leaves: the ball rolls again; a counter closed mid slide-in keeps no focus.

const CALM_BUDGET := 40
const SETTLE := 20

var _game
var _ws
var _shop
var _failures := 0
var _phase := "boot"
var _wait := 0
var _acted: Array = []


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
			_game.ctx.calm = true
			_game.player.source = Intent.Scripted.new()
			_game.flow.press_start()
			_game.flow.choose_class(1)
			_next("enter")
		"enter":
			if _wait == SETTLE:
				_ws.armed = true
				_shop = _game.build.shop
				_shop.enter()
				_game.run.scrap = 400
				_game.run.cogs = 400
				_ws.counter.acted.connect(func(fact: String, record: Dictionary): _acted.append([fact, record]))
				_report("pull up", _ws.should_open_counter(true, true, 1.0) and not _ws.should_open_counter(true, true, 9.0)
						and not _ws.should_open_counter(true, false, 1.0), "slow in reach opens; fast or out of reach does not")
				_ws.open_counter()
				_report("counter opens", _ws.counter.is_open() and _game.get_meta("menu_held", false) and _game.player.frozen() and not paused
						and _ws.talk.visible,
					"open %s, held %s, ball parked %s, tree paused %s, talk key shown %s"
						% [_ws.counter.is_open(), _game.get_meta("menu_held", false), _game.player.frozen(), paused, _ws.talk.visible])
				_next("buy")
		"buy":
			if _wait == SETTLE:
				var tile: Control = _ws.counter.tile_for("shelf", 0)
				var part_id: String = tile.rec["part_id"]
				var cogs: int = _game.run.cogs
				var held: int = _game.run.part_count(part_id)
				tile.grab_focus()
				var detail: String = _ws.counter.detail_text()
				var def: Resource = Parts.offer_def(part_id, _game.run.parts)
				_report("detail line", detail == Parts.offer_shop_line(part_id, _game.run.parts) and detail.begins_with(def.display_name + ". ")
						and not ": " in detail and not "; " in detail and def.text in detail,
					"the focused shelf plate reads \"%s\" (name, a full stop, then the part's own text \"%s\")" % [detail, def.text])
				Push.click(root, tile)
				var record: Dictionary = _acted.back()[1] if not _acted.is_empty() else {}
				_report("buy by click", record.get("ok", false) and _game.run.cogs == cogs - int(record["price"])
						and _game.run.part_count(part_id) == held + 1 and _ws.bubble.text == record["bark"]["text"]
						and _ws.counter.tile_for("shelf", 0).state() == "sold",
					"%s for %d: cogs %d to %d, held %d to %d, bubble \"%s\""
						% [part_id, record.get("price", -1), cogs, _game.run.cogs, held, _game.run.part_count(part_id), _ws.bubble.text])
				_game.run.scrap = 0
				_game.run.cogs = 0
				_ws.counter.refresh()
				tile = _ws.counter.tile_for("shelf", 1)
				var poor_state: String = tile.state()
				var parts_before: int = _game.run.parts.size()
				Push.click(root, tile)
				record = _acted.back()[1]
				_report("too poor", poor_state == "poor" and not record["ok"] and record["reason"] == Shop.CANT_AFFORD
						and _game.run.cogs == 0 and _game.run.parts.size() == parts_before and _ws.bubble.text == Shop.LINES["moss.bark.cant_afford"]
						and _acted.back()[0] == "shop_refused",
					"plate %s, reason %s, bubble \"%s\"" % [poor_state, record["reason"], _ws.bubble.text])
				_game.run.scrap = 400
				_game.run.cogs = 400
				_ws.counter.refresh()
				_next("reroll")
		"reroll":
			if _wait == 5:
				_words("buy face")
				var before: Array = _shop.shelf.map(func(s): return s["part_id"])
				var cogs: int = _game.run.cogs
				var tile: Control = _ws.counter.tile_for("reroll")
				tile.grab_focus()
				Push.key(root, KEY_ENTER)
				var record: Dictionary = _acted.back()[1]
				_report("reroll by keys", _acted.back()[0] == "shop_rerolled" and record["ok"] and _game.run.cogs == cogs - int(record["price"])
						and _shop.shelf.map(func(s): return s["part_id"]) != before and _ws.counter.tile_for("reroll").state() == "spent",
					"paid %d, cogs %d to %d, shelf %s to %s" % [record["price"], cogs, _game.run.cogs, before, _shop.shelf.map(func(s): return s["part_id"])])
				Push.click(root, _ws.counter.face_button("sell"))
				_next("sell")
		"sell":
			if _wait == 5:
				var tile: Control = null
				for t in _ws.counter.tiles():
					if t.rec.get("kind") == "sell" and t.state() == "ok":
						tile = t
						break
				var part_id: String = tile.rec["part_id"] if tile != null else ""
				var quote: int = int(tile.rec["price"]) if tile != null else -1
				var cogs: int = _game.run.cogs
				var count: int = _game.run.parts.size()
				_words("sell face")
				var screen: Rect2 = root.get_visible_rect()
				var panel: Rect2 = _ws.counter.get_global_rect()
				var said: Rect2 = _ws.bubble.get_global_rect()
				_report("layout", screen.encloses(panel) and screen.encloses(said) and not said.intersects(panel)
						and panel.end.y <= screen.size.y * 0.86,
					"counter %s and bubble %s inside %s, apart, above the HUD band" % [panel, said, screen])
				Push.click(root, tile)
				var record: Dictionary = _acted.back()[1]
				_report("sell by click", _acted.back()[0] == "shop_sold" and record["ok"] and record["price"] == -quote
						and _game.run.cogs == cogs + quote and _game.run.parts.size() == count - 1,
					"%s quoted %d: cogs %d to %d, parts %d to %d" % [part_id, quote, cogs, _game.run.cogs, count, _game.run.parts.size()])
				Push.click(root, _ws.counter.face_button("buy"))
				_next("plate")
		"plate":
			if _wait == 5:
				var plate: Control = _ws.counter.tile_for("pick")
				Push.click(root, plate)
				var over: bool = _ws.pick.is_open() and not _ws.counter.visible and paused
				var seen: int = WordBudget.count(_ws)["hud"]
				Push.click(root, _ws.pick.cards()[0])
				var owner: Control = root.gui_get_focus_owner()
				_report("pick plate", plate != null and over and seen <= CALM_BUDGET and _game.player.tree.path().size() == 1
						and _ws.counter.visible and _ws.counter.is_open() and not paused and _game.get_meta("menu_held", false)
						and owner != null and _ws.counter.is_ancestor_of(owner) and _ws.counter.tile_for("pick") == null,
					"plate %s; the pick stood in for the counter %s with %d words; after the click the path is %s, counter back %s with focus %s, paused %s"
						% [plate != null, over, seen, _game.player.tree.path(), _ws.counter.visible, owner, paused])
				_next("talk")
		"talk":
			if _wait == 5:
				var beats: Array = []
				var levels: Array = []
				var teeth: Array = []
				for i in Shop.BEATS.size():
					Push.key(root, KEY_T)
					beats.append(_ws.bubble.mood + ":" + str(int(_ws.bubble.exasperation)))
					levels.append(_ws.bubble.exasperation)
					_ws.bubble.shown_exasperation = _ws.bubble.exasperation
					teeth.append(_ws.bubble.outline(_ws.bubble.shown_exasperation).size())
				var rising := true
				for i in range(1, levels.size()):
					rising = rising and levels[i] > levels[i - 1]
				Push.key(root, KEY_T)
				var restart: bool = _ws.bubble.mood == "restart" and _ws.bubble.text == Shop.LINES["moss.restart"]
				Push.key(root, KEY_T)
				var again: bool = _ws.bubble.mood == "beat" and _ws.bubble.exasperation == 0.0
				_report("talk beats", rising and restart and again and teeth[0] < teeth[5],
					"beats %s, outline points %s, restart %s, then the ask again %s" % [beats, teeth, restart, again])
				var hook: Control = _ws.counter.tile_for("top")
				var locked: String = hook.state() if hook != null else "none"
				var guard := 0
				while _game.run.heft_class() < _shop.top["lock_class"] and guard < 60:
					_game.run.add_scrap(100, Vector3.ZERO)
					guard += 1
				Push.key(root, KEY_T)
				hook = _ws.counter.tile_for("top")
				_report("relent once heavy", locked == "locked" and _ws.bubble.mood == "relent" and hook != null and hook.state() != "locked"
						and _game.codex.known(Shop.CODEX_ID) and Shop.LINES.values().has(_ws.bubble.text),
					"hook %s before, %s after; bubble %s \"%s\"" % [locked, hook.state() if hook != null else "none", _ws.bubble.mood, _ws.bubble.text])
				Push.key(root, KEY_ESCAPE)
				_report("leave", not _ws.counter.is_open() and not _game.get_meta("menu_held", false) and not _game.player.frozen(),
					"open %s, held %s, ball parked %s" % [_ws.counter.is_open(), _game.get_meta("menu_held", false), _game.player.frozen()])
				_next("cut")
		"cut":
			if _wait == 3:
				_ws.open_counter()
				_next("cut_close")
		"cut_close":
			if _wait == 2:
				_ws.close_counter()
				_next("cut_settled")
		"cut_settled":
			if _wait == 40:
				var owner: Control = root.gui_get_focus_owner()
				_report("counter cut mid slide", not _ws.counter.visible and not _game.get_meta("menu_held", false) and (owner == null or owner.is_visible_in_tree()),
					"visible %s, held %s, focus owner %s" % [_ws.counter.visible, _game.get_meta("menu_held", false), owner])
				print("ui_workshop_shop_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
				quit(0 if _failures == 0 else 1)
				return true
	return false


func _words(label: String) -> void:
	var seen: Dictionary = WordBudget.count(_ws)
	print("  %s words: %s" % [label, " | ".join(seen["items"].map(func(i): return "%s %d \"%s\"" % [i["node"], i["words"], i["text"]]))])
	_report("%s word budget" % label, seen["hud"] <= CALM_BUDGET, "%d words on the counter (budget %d)" % [seen["hud"], CALM_BUDGET])


func _next(phase: String) -> void:
	_phase = phase
	_wait = 0
