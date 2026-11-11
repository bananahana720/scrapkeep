extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Parts := preload("res://src/build/parts.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const ScreenBusy := preload("res://src/ui/screen_busy.gd")
const Hud := preload("res://src/ui/hud.gd")
const CodexBanner := preload("res://src/presentation/codex_banner.gd")
const T := preload("res://tests/support/t.gd")

# A reward crate takes the screen's one slot like a card (wave 36 unit crate-slot). On the real
# game in a run, the crate's pause armed as in play, an achievement card raised through the HUD's
# real path (the bus's achievement_earned):
#   - card first: a crate made due while the card holds the screen does not open until the card
#     is gone, and then opens within the card's life plus the crate's calm hold plus a second (the
#     bound on its wait is the holder's own life);
#   - both in one frame: a card and a crate raised together are never on screen together;
#   - a boss crate (source "boss") may go to the front of the line but still waits for the card;
#   - mirror: while a crate is opening a card raised then waits, and shows after the crate is done,
#     within the crate's out fade, its find card's life and the quiet hold plus a second; the gate
#     names the crate's beat (its own key or its find card's) as the holder while it is up;
#   - planted control: the same card-first scene with the ceremony's gate swapped for one that
#     always says yes must show the overlap, so a zero above means the slot held the crate back.
# Crates are skipped (the ceremony's own key path) so each order ends quickly.

const SLACK_S := 1.0
var CALM_HOLD_S := float(EventKinds.reward_row("ceremony")["calm_hold_s"])
var CRATE_OUT_S := float(EventKinds.reward_row("ceremony")["out_s"])
# The crate's find card (the banner's card for the same part) may still be up when the crate closes.
const FIND_CARD_S := CodexBanner.CARD_HOLD_MAX + CodexBanner.IN_TIME + CodexBanner.OUT_TIME

var _t := T.new("crate_slot_test")
var _game
var _used := {}


# A gate that always says yes: the ceremony's view of the screen with the slot request removed.
class YesGate extends Node:
	var real
	func settled(hold := ScreenBusy.SETTLE) -> bool:
		return real.settled(hold)
	func request(_key: String, _first := false) -> void:
		pass
	func ready(_key: String) -> void:
		pass
	func may_show(_key: String, _hold := ScreenBusy.SETTLE) -> bool:
		return true
	func take(_key: String) -> bool:
		return true
	func done(_key: String) -> void:
		pass
	func give_back(_key: String) -> void:
		pass
	func showing() -> String:
		return ""
	func waiting() -> Array[String]:
		return []


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run.call_deferred()


# Seconds of drawn frames, stepped by the game's own process delta (the ceremony's pause does not stop it).
var _clock := 0.0


func _now() -> float:
	return _clock


func _frame() -> void:
	await process_frame
	_clock += _game.get_process_delta_time()


func _ceremony():
	return _game.presentation.ceremony


func _busy():
	return _game.ctx.screen_busy


func _card_up() -> bool:
	return not _game.hud.ach_toasts().is_empty()


# A part nothing has found yet this run, so its vault or boss find is a crate and not a name at the ball.
func _fresh_part() -> String:
	for id in Parts.ids():
		if not _used.has(id) and not _ceremony().seen(id) and not (_game.run.parts as Array).has(id):
			_used[id] = true
			return id
	return ""


func _wait_until(cond: Callable, seconds: float) -> bool:
	var until := _now() + seconds
	while _now() < until:
		if cond.call():
			return true
		await _frame()
	return cond.call()


# The screen is clear: no card up or in the gate's line, no crate, the ball on the ground and calm.
func _quiet_screen() -> bool:
	var calm_for := 0
	var until := _now() + 30.0
	while _now() < until:
		await _frame()
		var clear: bool = not _card_up() and _game.hud.ach_waiting().is_empty() and _busy().showing() == "" and _busy().waiting().is_empty() \
			and not _ceremony().active() and _ceremony().queued() == 0 and _ceremony().view.card.is_empty()
		calm_for = calm_for + 1 if clear and _ceremony().calm() else 0
		if calm_for >= 30:
			return true
	return false


# Watches until the crate has opened and closed (skipping it once it is up), or `seconds` pass.
# Returns {overlap: frames a card and a crate were both up, began: seconds to the crate's start,
# card_gone: seconds to the card leaving, -1 for never}.
func _watch(seconds: float) -> Dictionary:
	var start := _now()
	var out := {"overlap": 0, "began": -1.0, "card_gone": -1.0}
	var was_up := _card_up()
	while _now() - start < seconds:
		await _frame()
		var up := _card_up()
		if was_up and not up and float(out["card_gone"]) < 0.0:
			out["card_gone"] = _now() - start
		was_up = up
		if _ceremony().active():
			if float(out["began"]) < 0.0:
				out["began"] = _now() - start
			if up:
				out["overlap"] += 1
			if _ceremony().phase() != "out":
				_ceremony().skip()
		elif float(out["began"]) >= 0.0 and not up:
			break
	return out


func _card_then_crate(source: String) -> Dictionary:
	var part := _fresh_part()
	_game.events.achievement_earned.emit("first_win")
	var shown: bool = await _wait_until(_card_up, ScreenBusy.SETTLE + SLACK_S)
	var holder: String = _busy().showing()
	_game.run.add_part(part, source)
	var seen: Dictionary = await _watch(Hud.ACH_TOTAL + ScreenBusy.FIND_HOLD + 6.0)
	seen["shown"] = shown
	seen["holder"] = holder
	seen["part"] = part
	return seen


func _run() -> void:
	while _game.flow == null:
		await process_frame
	for i in 5:
		await _frame()
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.presentation.flourish.stop_all()
	_ceremony().pause_armed = true
	_t.check("a quiet screen to start from", await _quiet_screen(), "holder '%s'" % _busy().showing())

	# Card first: the crate waits for the card, then opens within the card's life (its bound).
	var a: Dictionary = await _card_then_crate("vault")
	_t.check("card first: the card holds the screen", a["shown"] and String(a["holder"]).begins_with("hud:"), "shown %s, holder '%s'" % [a["shown"], a["holder"]])
	_t.eq("card first: no frame shows the card and the crate together", a["overlap"], 0)
	_t.check("card first: the crate opens after the card, within its life plus the calm hold plus a second",
		float(a["began"]) >= float(a["card_gone"]) and float(a["card_gone"]) >= 0.0
			and float(a["began"]) <= Hud.ACH_TOTAL + CALM_HOLD_S + SLACK_S,
		"card gone at %.2f s, crate began at %.2f s (%s)" % [a["card_gone"], a["began"], a["part"]])

	# Both in one frame.
	_t.check("a quiet screen before both in one frame", await _quiet_screen(), "holder '%s'" % _busy().showing())
	_game.run.add_part(_fresh_part(), "vault")
	_game.events.achievement_earned.emit("first_win")
	var b: Dictionary = await _watch(Hud.ACH_TOTAL + ScreenBusy.FIND_HOLD + 6.0)
	_t.eq("both in one frame: no frame shows the card and the crate together", b["overlap"], 0)
	_t.check("both in one frame: the crate still opens", float(b["began"]) >= 0.0, "began at %.2f s" % b["began"])

	# A boss crate goes to the front, but not off the card on screen.
	_t.check("a quiet screen before the boss crate", await _quiet_screen(), "holder '%s'" % _busy().showing())
	var c: Dictionary = await _card_then_crate("boss")
	_t.eq("boss crate: no frame shows the card and the crate together", c["overlap"], 0)
	_t.check("boss crate: it opens within the card's life plus the calm hold plus a second",
		float(c["began"]) >= 0.0 and float(c["began"]) <= Hud.ACH_TOTAL + CALM_HOLD_S + SLACK_S,
		"card gone at %.2f s, crate began at %.2f s" % [c["card_gone"], c["began"]])

	# Mirror: a card raised while a crate is opening waits for it.
	_t.check("a quiet screen before the mirror", await _quiet_screen(), "holder '%s'" % _busy().showing())
	var mirror_part := _fresh_part()
	_game.run.add_part(mirror_part, "vault")
	var opened: bool = await _wait_until(func() -> bool: return _ceremony().active(), ScreenBusy.FIND_HOLD + CALM_HOLD_S + SLACK_S)
	var crate_holder: String = _busy().showing()
	_game.events.achievement_earned.emit("first_win")
	var card_in_crate := false
	var crate_done_at := -1.0
	var card_at := -1.0
	var start := _now()
	while _now() - start < 20.0 and card_at < 0.0:
		await _frame()
		if _ceremony().active():
			card_in_crate = card_in_crate or _card_up()
			if _ceremony().phase() == "build" or _ceremony().phase() == "reveal":
				_ceremony().skip()
		elif crate_done_at < 0.0:
			crate_done_at = _now() - start
		if _card_up():
			card_at = _now() - start
	_t.check("mirror: the crate opened and its beat holds the slot (its own key or its find card's)", opened
		and not crate_holder.begins_with("hud:") and crate_holder.ends_with(":" + mirror_part), "opened %s, holder '%s'" % [opened, crate_holder])
	_t.check("mirror: a card raised while the crate is up does not show over it", not card_in_crate, "card up inside the crate %s" % card_in_crate)
	_t.check("mirror: the card shows after the crate, within its out fade, its find card's life and the quiet hold plus a second",
		card_at >= 0.0 and crate_done_at >= 0.0 and card_at > crate_done_at and card_at - crate_done_at <= CRATE_OUT_S + FIND_CARD_S + ScreenBusy.SETTLE + SLACK_S,
		"crate done at %.2f s, card at %.2f s" % [crate_done_at, card_at])

	# Planted control: the ceremony asks a gate that always says yes; the same card-first scene must overlap.
	_t.check("a quiet screen before the control", await _quiet_screen(), "holder '%s'" % _busy().showing())
	var real = _game.ctx.screen_busy
	var yes := YesGate.new()
	yes.real = real
	_game.ctx.screen_busy = yes
	var p: Dictionary = await _card_then_crate("vault")
	_game.ctx.screen_busy = real
	yes.free()
	_t.check("planted control: with an always-yes gate the crate opens over the card", p["shown"] and int(p["overlap"]) > 0,
		"shown %s, overlap frames %d, card gone at %.2f s, crate began at %.2f s" % [p["shown"], p["overlap"], p["card_gone"], p["began"]])

	quit(_t.verdict())
