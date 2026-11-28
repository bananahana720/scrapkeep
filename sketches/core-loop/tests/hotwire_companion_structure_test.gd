extends SceneTree

const Parts := preload("res://src/build/parts.gd")

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Companion := preload("res://src/core/companion.gd")
const RewardView := preload("res://src/ui/reward_view.gd")
const Push := preload("res://tests/support/push.gd")
const T := preload("res://tests/support/t.gd")
const Icons := preload("res://src/core/icons.gd")

# Ruling cx on the hot-wire offer and the companion panel: they say what they are by how they
# look. The offer wears an amber stamp and no "HOT-WIRED" eyebrow, its Recycle choice is the
# cog icon and the number ("Recycle +N", no colon, no word "cogs"). The companion panel has
# no title, draws its two sockets as marks holding the piece icons (an empty ring when empty),
# shows the empty key as a cap and refuses a
# repeat kind with "One of each kind.".

const HOTWIRE_BANNED := ["HOT-WIRED", "Recycle:", "cogs"]
const PANEL_BANNED := ["COMPANION", "Socket 1", "Socket 2", "U empties", "Esc leaves", "family"]

var _t := T.new("hotwire_companion_structure_test")
var _game


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.bot_driven = false
	root.add_child(_game)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


# Every string a Label or Button under `node` draws.
func _texts(node: Node) -> Array[String]:
	var out: Array[String] = []
	if node is Label:
		out.append(node.text)
	elif node is Button:
		out.append(node.text)
	for child in node.get_children():
		out.append_array(_texts(child))
	return out


# The banned strings found in `texts`.
func _hits(texts: Array[String], banned: Array) -> Array:
	var found := []
	for text in texts:
		for word in banned:
			if text.contains(word):
				found.append(word)
	return found


func _doc(owned: Array, seated: Array) -> Dictionary:
	var m := Companion.new()
	for id in owned:
		m.acquire(id)
	if not seated.is_empty():
		m.assemble(seated)
	return m.to_dict()


func _run() -> void:
	while _game.flow == null:
		await process_frame
	await _frames(5)
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	_scanner_control()
	await _hotwire()
	await _companion()
	quit(_t.verdict())


# The planted case: the scanner must flag a broken copy that still has the old labels.
func _scanner_control() -> void:
	var broken: Array[String] = ["HOT-WIRED", "Recycle: +4 cogs", "COMPANION", "Socket 1: empty", "Socket 2: Ram Prow", "U empties. Esc leaves.", "Two of one family will not fit."]
	_t.check("planted: the scanner flags the old hot-wire labels", _hits(broken, HOTWIRE_BANNED).size() == 3, str(_hits(broken, HOTWIRE_BANNED)))
	_t.check("planted: the scanner flags the old panel labels", _hits(broken, PANEL_BANNED).size() == 6, str(_hits(broken, PANEL_BANNED)))
	_t.check("the scanner passes clean text", _hits(["Riveted Shell", "Recycle +4", "One of each kind."] as Array[String], HOTWIRE_BANNED + PANEL_BANNED).is_empty(), "")


# Since the pass D fold the hot-wired part is a rare gate part: its card line is the row's verb,
# and the Fit / Recycle screen (with its stamp and Recycle price) is gone.
func _hotwire() -> void:
	_game.flow.press_start()
	_game.flow.choose_class(0)
	await _frames(30)
	Push.key(root, KEY_1)
	await _frames(2)
	var lines: Array[String] = []
	for id in ["riveted_shell", "spark_tread"]:
		lines.append(Parts.def(id).display_name)
		lines.append(Parts.def(id).verb)
	_t.check("the hot-wired gate cards draw none of the old labels", _hits(lines, HOTWIRE_BANNED).is_empty(), " | ".join(lines))


func _companion() -> void:
	var ws = _game.get_node("Workshop")
	var panel = ws.companion_panel
	var all: Array = []
	for p in Companion.PIECES:
		all.append(p["id"])
	ws.armed = true
	_game.run.companion = _doc(all, [])
	_t.check("the panel opens", panel.open(), "")
	await _frames(3)
	var texts := _texts(panel)
	_t.check("panel draws none of the old labels", _hits(texts, PANEL_BANNED).is_empty(), " | ".join(texts))
	var marks = panel.find_child("SocketMarks", true, false)
	_t.check("one socket-marks control holds exactly two sockets", marks != null and panel.socket_icons().size() == 2, str(panel.socket_icons()))
	_t.eq("both sockets empty at first", panel.socket_icons(), ["", ""] as Array[String])
	panel.pick(0)
	await _frames(2)
	var icons: Array[String] = panel.socket_icons()
	_t.check("one piece fitted: one mark holds its icon, the other is empty", icons[0] != "" and icons[1] == "", str(icons))
	_t.eq("that icon is the piece's", icons[0], panel.PIECE_ICONS["primer_coil"])
	panel.pick(1)
	await _frames(2)
	_t.eq("a second piece of the same kind is refused", panel.message, "One of each kind.")
	_t.check("the refusal reads on screen without the word family", panel.screen_text().contains("One of each kind.") and not panel.screen_text().contains("family"), panel.screen_text())
	_t.eq("the cap shows U on keys", panel.empty_cap(), "key_u")
	Push.key(root, KEY_U)
	await _frames(2)
	_t.eq("U empties both sockets", panel.socket_icons(), ["", ""] as Array[String])
	# Back stays on Esc.
	var back := InputEventAction.new()
	back.action = "ui_cancel"
	back.pressed = true
	_t.check("Esc (ui_cancel) is taken by the panel", panel.handle(back), "")
	_t.check("Esc closes the panel and is_open reads false", not panel.is_open(), "")
