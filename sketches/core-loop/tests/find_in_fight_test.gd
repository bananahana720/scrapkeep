extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Parts := preload("res://src/build/parts.gd")
const WordBudget := preload("res://src/ui/word_budget.gd")

# A find never puts a card up during a fight (alpha R3, unit RV). A live slice game, a posture
# Warden engaged by a real ram:
#   - the one gate: the ceremony and the banner both ask WhyCallout.find_may_speak and test
#     calm no other way (a source scan);
#   - a first find in the fight draws no ceremony card and no banner card for 300 physics
#     frames, the part's name shows at the ball, and no hit-stop is asked for it;
#   - a repeat find, common or rare_plus, shows no card and no pop in the fight;
#   - when the Warden dies the held card opens within 60 frames, once, and the part is seen in
#     both records only then; a repeat out of the fight shows nothing either;
#   - a second fight: three first finds are held and a fourth shows its name only; a retry drops
#     them, they are still unseen, and the next first find out of a fight shows its card.
# Frames are counted, never read from the clock.

const SETTLE := 300
const HOLD_FRAMES := 300
const OPEN_WITHIN := 60
const QUIET_FRAMES := 30
const PLATING := 45.0
const SOURCES := ["res://src/presentation/reward_ceremony.gd", "res://src/presentation/codex_banner.gd"]

var _game
var _failures := 0
var _phase := "boot"
var _wait := 0
var _first := ""
var _repeat_common := ""
var _repeat_rare := ""
var _held: Array = []
var _stops := 0
var _cards_before := 0
var _opened := -1
var _marked_early := false
var _words_in_hold := 0
var _name_up := false


func _initialize() -> void:
	_pick_parts()
	_scan_sources()
	_game = Game.new()
	_game.test_mode = true
	_game.table = "slice"
	root.add_child(_game)


func _pick_parts() -> void:
	var rare_plus: Array = []
	var common: Array = []
	for id in Parts.ids():
		var rarity := String(Parts.def(id).rarity)
		if rarity == "rare_plus":
			rare_plus.append(id)
		elif rarity == "common":
			common.append(id)
	_first = rare_plus[0]
	_repeat_rare = rare_plus[1]
	_repeat_common = common[0]
	_held = [common[1], common[2], common[3], common[4]]


func _scan_sources() -> void:
	var bad: Array = []
	for path in SOURCES:
		var text := FileAccess.get_file_as_string(path)
		if not text.contains("WhyCallout.find_may_speak("):
			bad.append("%s never calls the gate" % path)
		if text.contains("is_calm(") or text.contains("threat_live("):
			bad.append("%s reads calm itself" % path)
	_report("one gate", bad.is_empty(), "the ceremony and the banner both call WhyCallout.find_may_speak and neither tests calm another way; %s" % [bad])


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _ceremony():
	return _game.presentation.ceremony


func _banner():
	return _game.presentation.banner


func _card_words() -> int:
	return _ceremony().view.drawn_words().size() + WordBudget.count(_banner())["hud"]


func _card_up() -> bool:
	return not _ceremony().view.card.is_empty() or _banner().showing() or _banner().visible


func _seen_both(part: String) -> bool:
	return _ceremony().seen(part) and _banner()._was_seen("part:" + part)


func _unseen_both(part: String) -> bool:
	return not _ceremony().seen(part) and not _banner()._was_seen("part:" + part)


func _rare_stops() -> int:
	return _game.presentation.juice.hit_stop_log.filter(func(s: Array): return s[2] == "reward_rare").size()


func _engage() -> void:
	var combat = _game.ctx.spawner
	combat.heft_override = 1.0
	var force := 1.0
	while combat.punch_of("ram", force) < PLATING:
		force += 0.05
	combat.strike(_game.flow.warden, "ram", force)


func _fight_on() -> bool:
	return _game.flow.sealed and _game.flow._engaged and is_instance_valid(_game.flow.warden)


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_wait += 1
	match _phase:
		"boot":
			var source := Intent.Scripted.new()
			_game.player.source = source
			_game.flow.press_start()
			_game.flow.choose_class(1)
			_next("settle")
		"settle":
			if _wait == SETTLE:
				_engage()
				_report("fight on", _fight_on() and _game.flow.warden.fight() == "posture", "a posture Warden engaged by a ram: sealed %s, engaged %s" % [_game.flow.sealed, _game.flow._engaged])
				_stops = _rare_stops()
				_cards_before = _banner().cards_shown
				_game.run.add_part(_first, "pickup")
				_name_up = _name_showing()
				_next("hold")
		"hold":
			_words_in_hold += _card_words()
			if _card_up():
				_report("no card in the fight", false, "a card was up %d frames into the fight" % _wait)
				_words_in_hold = 0
				return _finish()
			if _wait == HOLD_FRAMES:
				_report("a first find in a fight draws no card", _words_in_hold == 0 and _banner().cards_shown == _cards_before and _ceremony().view.card.is_empty()
						and _banner().queued() == 1 and _name_up and _fight_on(),
					"%s held %d frames behind a live Warden: card words %d, banner queued %d, name at the ball %s" % [_first, HOLD_FRAMES, _words_in_hold, _banner().queued(), _name_up])
				_report("held and unseen", _unseen_both(_first), "%s unseen in the ceremony's record (%s) and the banner's (%s)" % [_first, _ceremony().seen(_first), _banner()._was_seen("part:" + _first)])
				_report("no hit-stop while held", _rare_stops() == _stops, "reward_rare stops asked during the held find: %d" % (_rare_stops() - _stops))
				_prime_repeats()
				_game.run.add_part(_repeat_common, "pickup")
				_game.run.add_part(_repeat_rare, "pickup")
				_next("repeat_fight")
		"repeat_fight":
			if _card_up():
				_report("a repeat in a fight shows nothing", false, "a card or pop was up %d frames after a repeat find" % _wait)
				return _finish()
			if _wait == QUIET_FRAMES:
				var presented: Array = _ceremony().presented.filter(func(p: Array): return p[0] in [_repeat_common, _repeat_rare])
				_report("a repeat in a fight shows nothing", _banner().cards_shown == _cards_before and _name_showing()
						and presented.all(func(p: Array): return p[1] in ["common", "rare"]),
					"common and rare_plus repeats for %d frames in a fight: no card, no pop; tiers %s" % [QUIET_FRAMES, presented.map(func(p: Array): return p[1])])
				_game.flow.warden._die()
				_next("open")
		"open":
			if _opened < 0 and _card_up():
				_opened = _wait
				_marked_early = false
				_report("held card opens", _ceremony().view.card.get("part", "") == _first or _banner().showing(), "%s opens %d frames after the Warden's break" % [_first, _wait])
				_report("seen only now", _seen_both(_first), "%s seen in both records at the frame its card shows" % _first)
			if _opened < 0 and _seen_either(_first):
				_marked_early = true
			if _wait == OPEN_WITHIN:
				_report("opens within 60 frames, once", _opened >= 0 and not _marked_early and _banner().cards_shown == _cards_before + 1 and not _fight_on(),
					"opened at frame %d, seen early %s, banner cards %d (was %d)" % [_opened, _marked_early, _banner().cards_shown, _cards_before])
				_cards_before = _banner().cards_shown
				_game.run.add_part(_repeat_common, "pickup")
				_game.run.add_part(_repeat_rare, "pickup")
				_next("repeat_calm")
		"repeat_calm":
			var shown: String = _ceremony().view.card.get("part", "")
			if shown in [_repeat_common, _repeat_rare] or _banner().cards_shown != _cards_before:
				_report("a repeat out of a fight shows nothing", false, "a card for %s was up %d frames after a repeat find" % [shown, _wait])
				return _finish()
			if _wait == QUIET_FRAMES:
				_report("a repeat out of a fight shows nothing", true, "common and rare_plus repeats with the Warden dead: no card, no pop for %d frames" % QUIET_FRAMES)
				_game.flow.retry_stage()
				_next("refight")
		"refight":
			if _wait == 5:
				_engage()
				_stops = _rare_stops()
				for id in _held:
					_game.run.add_part(id, "pickup")
				var held_cards: int = _ceremony()._cards.size()
				_report("at most three held", _fight_on() and held_cards == 3 and _banner().queued() == 3 and _unseen_both(_held[3]),
					"four first finds in a fight: ceremony holds %d, banner holds %d, the fourth %s is unseen with its name only" % [held_cards, _banner().queued(), _held[3]])
				_game.flow.retry_stage()
				_next("retried")
		"retried":
			if _wait == 5:
				var dropped: bool = _ceremony()._cards.is_empty() and _banner().queued() == 0 and not _card_up()
				var unseen := true
				for id in _held:
					unseen = unseen and _unseen_both(id)
				_report("a retry drops the held cards", dropped and unseen, "after a retry: ceremony holds %d, banner holds %d, every held part still unseen %s" % [_ceremony()._cards.size(), _banner().queued(), unseen])
				_game.run.add_part(_held[0], "pickup")
				_next("again")
		"again":
			if _card_up():
				_report("the next first find shows its card", _ceremony().view.card.get("part", "") == _held[0] and _seen_both(_held[0]) and not _fight_on(),
					"%s found out of a fight after the retry shows its card at frame %d and is seen" % [_held[0], _wait])
				return _finish()
			if _wait == OPEN_WITHIN:
				_report("the next first find shows its card", false, "no card for %s within %d frames out of a fight" % [_held[0], OPEN_WITHIN])
				return _finish()
	return false


func _seen_either(part: String) -> bool:
	return _ceremony().seen(part) or _banner()._was_seen("part:" + part)


func _name_showing() -> bool:
	return _game.hud.part_name.left > 0.0 and _game.hud.part_name.drawn_words().size() > 0


func _prime_repeats() -> void:
	for id in [_repeat_common, _repeat_rare]:
		_ceremony()._mark_seen(id)
		_banner()._mark_seen("part:" + id)


func _next(phase: String) -> void:
	_phase = phase
	_wait = 0


func _finish() -> bool:
	print("find_in_fight_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
	return true
