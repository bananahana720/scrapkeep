extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const HotwireChoice := preload("res://src/ui/hotwire_choice.gd")
const HotwireRules := preload("res://src/build/hotwire_rules.gd")
const Push := preload("res://tests/workshop/push.gd")

# Unit HW2: the hot-wired Fit / Recycle screen in play, driven by real events pushed into the
# viewport, on the real Game. The offer is the first beacon_unsealed of the run, as
# hotwire_offer_flow_test triggers it.
#   - No offer, no screen, and the sim runs.
#   - An offer opens the screen with the part name, the upside and downside words and the
#     recycle price, and pauses the tree.
#   - E fits and pad Y fits; F recycles and pad X recycles, the cogs rise once; each choice
#     closes the screen, unpauses and puts a one-line callout on the HUD.
#   - Escape hides it, leaves the offer pending and the tree running, and the screen reopens
#     when the gates open.
#   - A spark_tread offer shows its bonus and wear words.
# Evidence limit: the Warden break is the beacon_unsealed fact flow emits, not a real kill.

const SETTLE := 30
const GAP := 4

var _game
var _failures := 0
var _frames := 0
var _step := 0
var _wait := 0
var _cogs_before := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	# This test plays the human who answers the screen.
	_game.bot_driven = false
	root.add_child(_game)


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _screen():
	return _game.hud.hotwire_screen


func _pending() -> Dictionary:
	return _game.build.hotwire_pending()


# A fresh run and its Warden I break: the offer opens on build's own signal.
func _offer() -> void:
	_game.build._on_run_started("")
	_game.events.beacon_unsealed.emit(1)


func _texts(node: Node) -> Array[String]:
	var out: Array[String] = []
	if node is Label:
		out.append(node.text)
	for child in node.get_children():
		out.append_array(_texts(child))
	return out


func _opened(label: String) -> void:
	var texts := _texts(_screen())
	var copy := HotwireChoice.resolve("riveted_shell")
	var shown := " | ".join(texts)
	_check(label + " visible", _screen().is_open() and _screen()._root.visible and _screen().visible,
		"open %s" % _screen().is_open())
	_check(label + " words", copy["name"] in texts and copy["upside"]["words"] in texts and copy["downside"]["words"] in texts
		and ("+%d" % copy["recycle"]) in _screen().choice_button("recycle").text, shown)
	_check(label + " sim paused", paused, "paused %s" % paused)
	_check(label + " stamp, no eyebrow", _screen().stamp_shown() and not shown.contains("HOT-WIRED") and not shown.contains("cogs") and not shown.contains(":"), shown)


func _resolved(label: String, choice: String) -> void:
	_check(label + " resolved", _pending()["state"] == choice and not _screen().is_open() and not paused,
		"state %s, open %s, paused %s" % [_pending()["state"], _screen().is_open(), paused])
	var wording := "fitted" if choice == "fit" else "recycled"
	var toasts: Array[String] = _game.hud.toast_texts()
	_check(label + " callout", toasts.size() == 1 and wording in toasts[0], "toasts %s" % [toasts])


func _process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_frames += 1
	if _wait > 0:
		_wait -= 1
		return false
	var price: int = HotwireChoice.resolve("riveted_shell")["recycle"]
	match _step:
		0:
			_game.ctx.calm = true
			_game.player.source = Intent.Scripted.new()
			_game.flow.press_start()
			_game.flow.choose_class(0)
			_wait = SETTLE
		1:
			if not _game.presentation.audio.sound_ready:
				return false
			# 2026-10-14: SG10 shows the human start-pick card before the Warden.
			Push.key(root, KEY_1)
			_check("no offer, no screen", _pending()["state"] == "" and not _screen().is_open() and not paused,
				"state \"%s\", open %s, paused %s" % [_pending()["state"], _screen().is_open(), paused])
			_offer()
			_wait = GAP
		2:
			_opened("offer")
			var cues: Array = _game.presentation.audio.cue_log.filter(func(c: Array) -> bool: return c[1] == "hotwire_offer" and c[2] == "now")
			_check("one offer cue", cues.size() == 1, "cues %s" % [cues])
			Push.key(root, KEY_E)
			_wait = GAP
		3:
			_resolved("E", "fit")
			_offer()
			_wait = GAP
		4:
			_check("pad run opens", _screen().is_open() and paused, "open %s, paused %s" % [_screen().is_open(), paused])
			Push.pad(root, JOY_BUTTON_Y)
			_wait = GAP
		5:
			_resolved("pad Y", "fit")
			_offer()
			_wait = GAP
		6:
			_cogs_before = _game.ctx.run.cogs
			Push.key(root, KEY_F)
			_wait = GAP
		7:
			_resolved("F", "recycle")
			_check("F pays once", _game.ctx.run.cogs == _cogs_before + price, "cogs %d -> %d, price %d" % [_cogs_before, _game.ctx.run.cogs, price])
			_offer()
			_wait = GAP
		8:
			_cogs_before = _game.ctx.run.cogs
			Push.pad(root, JOY_BUTTON_X)
			_wait = GAP
		9:
			_resolved("pad X", "recycle")
			_check("X pays once", _game.ctx.run.cogs == _cogs_before + price, "cogs %d -> %d, price %d" % [_cogs_before, _game.ctx.run.cogs, price])
			_offer()
			_wait = GAP
		10:
			_cogs_before = _game.ctx.run.cogs
			Push.key(root, KEY_ESCAPE)
			_wait = GAP
		11:
			_check("escape hides, offer stays", not _screen().is_open() and _pending()["state"] == "open" and not paused
				and not _game.get_node("PauseMenu").is_open() and _game.ctx.run.cogs == _cogs_before,
				"open %s, state %s, paused %s, menu %s, cogs %d" % [_screen().is_open(), _pending()["state"], paused,
				_game.get_node("PauseMenu").is_open(), _game.ctx.run.cogs])
			_game.events.flow_changed.emit("gates")
			_wait = GAP
		12:
			_check("gates reopen it", _screen().is_open() and paused, "open %s, paused %s" % [_screen().is_open(), paused])
			Push.click(root, _screen().choice_button("recycle"))
			_wait = GAP
		13:
			_resolved("click", "recycle")
			# A spark_tread offer: build's own signal with its id, to read the bonus and wear words.
			_game.build._on_run_started("")
			_game.build._hotwire_id = "spark_tread"
			_game.build._hotwire_state = "open"
			_game.build.hotwire_offered.emit("spark_tread", 30)
			_wait = GAP
		14:
			var copy := HotwireChoice.resolve("spark_tread")
			var texts := _texts(_screen())
			var bonus := str(int(round(HotwireRules.BONUS * 100.0)))
			_check("tread words", _screen().is_open() and copy["upside"]["words"] in texts and copy["downside"]["words"] in texts
				and bonus in copy["upside"]["words"] and ("%dx" % int(HotwireRules.WEAR_SCALE)) in copy["downside"]["words"],
				" | ".join(texts))
			Push.key(root, KEY_ESCAPE)
			_wait = GAP
		15:
			_check("tread closed", not _screen().is_open() and not paused, "open %s" % _screen().is_open())
			print("ui_hotwire_screen_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
			quit(0 if _failures == 0 else 1)
			return true
	_step += 1
	return false
