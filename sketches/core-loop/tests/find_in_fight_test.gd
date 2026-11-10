extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Parts := preload("res://src/build/parts.gd")
const WordBudget := preload("res://src/ui/word_budget.gd")
const Flow := preload("res://src/core/flow.gd")
const WhyCallout := preload("res://src/ui/why_callout.gd")

# A find never puts a card up during a fight (alpha R3, unit RV). A live slice game, a posture
# Warden engaged by a real ram:
#   - the one gate: the ceremony and the banner both ask WhyCallout.find_may_speak and test
#     calm no other way (a source scan);
#   - a first find in the fight draws no ceremony card and no banner card for 300 physics
#     frames, the part's name shows at the ball, and no hit-stop is asked for it;
#   - a repeat find, common or relic, shows no card and no pop in the fight;
#   - when the Warden dies the held card opens within 60 frames, once, and the part is seen in
#     both records only then; a repeat out of the fight shows nothing either;
#   - a second fight: three first finds are held and a fourth shows its name only; in the banner
#     option a synergy found there draws nothing; a retry drops them, they are still unseen, and
#     the next first find out of a fight shows its card;
#   - a reveal card that is up when a Warden fight turns live closes at once, the part stays seen;
#   - a boss's own reward (source "boss") never waits on the damage clock, only on the calm hold.
# Frames are counted, never read from the clock.

const SETTLE := 300
const HOLD_FRAMES := 300
# A held card now waits for the screen's two quiet seconds (screen_busy.gd SETTLE, 120 frames, 150 with the
# process clock lagging the physics one) and then shows within the old 60 frames. The first find has two
# cards, the banner's and the ceremony's, which take turns, so the second is seen at its own turn.
const SETTLE_FRAMES := 150
const OPEN_WITHIN := SETTLE_FRAMES + 60
const BOTH_WITHIN := 900
const CALM_WITHIN := 900
const QUIET_FRAMES := 30
const STEP_S := 1.0 / 60.0
const SliceDefs := preload("res://src/core/slice_defs.gd")
const PLATING: float = SliceDefs.DEFS[0]["warden_plating"]
const SOURCES := ["res://src/presentation/reward_ceremony.gd", "res://src/presentation/codex_banner.gd"]

var _game
var _failures := 0
var _phase := "boot"
var _wait := 0
var _first := ""
var _repeat_common := ""
var _repeat_rare := ""
var _boss_part := ""
var _held: Array = []
var _stops := 0
var _cards_before := 0
var _opened := -1
var _marked_early := false
var _words_in_hold := 0
var _name_up := false
var _clock_ms := 0
var _calm_run := 0
# Drawn frames. The card closes in the ceremony's _process, and under load several physics
# ticks can run back to back before the next one, so a close is read after a drawn frame.
var _drawn := 0
var _engaged_at := 0
var _gate_run := 0
var _opened_reported := false
var _open_ok := false
var _again_first := -1


func _initialize() -> void:
	_pick_parts()
	_scan_sources()
	_game = Game.new()
	_game.test_mode = true
	_game.table = "slice"
	root.add_child(_game)


func _pick_parts() -> void:
	var relic: Array = []
	var common: Array = []
	for id in Parts.ids():
		var rarity := String(Parts.def(id).rarity)
		if rarity == "relic":
			relic.append(id)
		elif rarity == "common":
			common.append(id)
	_first = relic[0]
	_repeat_rare = relic[1]
	_boss_part = relic[2]
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
	return _game.flow.sealed and _game.flow.engaged() and is_instance_valid(_game.flow.warden)


func _process(_delta: float) -> bool:
	_drawn += 1
	return false


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
			if _wait == 1:
				# The inputless ball rolls straight down the spawn launch past the hauler bounty, whose
				# brute wakes and telegraphs; this test is about the find gate, so no activity stands.
				for s in _game.world.activities.sites:
					if s.brute != null and is_instance_valid(s.brute):
						s.brute.queue_free()
				_game.world.activities.clear()
			if _wait == SETTLE:
				_engage()
				_report("fight on", _fight_on() and _game.flow.warden.fight() == "posture", "a posture Warden engaged by a ram: sealed %s, engaged %s" % [_game.flow.sealed, _game.flow.engaged()])
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
				_game.run.add_part(_first, "pickup")
				_report("a second find of a held part queues nothing", _ceremony()._cards.size() == 1 and _ceremony().queued() == 0 and _banner().queued() == 1,
					"%s found again while its card is held: ceremony holds %d (queue %d), banner holds %d" % [_first, _ceremony()._cards.size(), _ceremony().queued(), _banner().queued()])
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
				_report("a repeat in a fight shows nothing", _banner().cards_shown == _cards_before and _banner().queued() == 1
						and _ceremony()._cards.size() == 1 and _ceremony().queued() == 0 and _name_showing()
						and presented.all(func(p: Array): return p[1] in ["common", "rare"]),
					"common and relic repeats for %d frames in a fight: no card, no pop; tiers %s" % [QUIET_FRAMES, presented.map(func(p: Array): return p[1])])
				_game.flow.warden._die()
				# Badges and notes the fight raised keep their own turns ahead of the find's; this test is about the find card.
				_game.hud.clear_achievement_toasts()
				_clear_crowd()
				_next("open")
		"open":
			if _opened < 0 and _card_up():
				_opened = _wait
				_marked_early = false
				_report("held card opens", _ceremony().view.card.get("part", "") == _first or _banner().showing(), "%s opens %d frames after the Warden's break" % [_first, _wait])
				_report("seen only now", _seen_either(_first), "%s seen in a record at the frame its first card shows" % _first)
			if _opened < 0 and _seen_either(_first):
				_marked_early = true
			# The gate is the old calm plus the screen's two quiet seconds; the 60 frames count from both holding.
			if WhyCallout.find_may_speak(_ceremony().get("_calm_left"), self, _game.flow) and _game.ctx.screen_busy.settled():
				_gate_run += 1
			else:
				_gate_run = 0
			if _wait == BOTH_WITHIN or (_gate_run >= 60 and _opened_reported == false):
				_opened_reported = true
				_open_ok = _opened >= 0 and not _marked_early
			# The world's crowd fights on after the break; its end (pressure back to nothing, as at a stage park) lets the held card in.
			if _opened >= 0 and not _banner().showing() and _game.ctx.screen_busy.fighting():
				_game.events.pressure_changed.emit(0.0)
			if _opened_reported and (_seen_both(_first) or _wait == BOTH_WITHIN):
				_report("opens within 60 frames, once", _open_ok and _banner().cards_shown == _cards_before + 1 and not _fight_on(),
					"opened at frame %d (the two quiet seconds, then 60), seen early %s, banner cards %d (was %d)" % [_opened, _marked_early, _banner().cards_shown, _cards_before])
				_report("the first find's second card takes its turn", _seen_both(_first), "%s seen in both records %d frames after the break" % [_first, _wait])
				# The first find's cards would hide a regressed repeat card behind them: clear both.
				_ceremony().view.card = {}
				_banner().dismiss(false)
				_cards_before = _banner().cards_shown
				var tiers_before: int = _ceremony().presented.size()
				_game.run.add_part(_repeat_common, "pickup")
				_game.run.add_part(_repeat_rare, "pickup")
				var tiers: Array = _ceremony().presented.slice(tiers_before).map(func(p: Array): return p[1])
				_report("a repeat out of a fight queues nothing", _ceremony()._cards.is_empty() and _ceremony().queued() == 0 and _banner().queued() == 0
						and _banner().cards_shown == _cards_before and tiers.size() == 2 and tiers.all(func(t: String): return t in ["common", "rare"]),
					"common and relic repeats with the Warden dead: ceremony cards %d, queue %d, banner queued %d, presented tiers %s"
						% [_ceremony()._cards.size(), _ceremony().queued(), _banner().queued(), tiers])
				_next("repeat_calm")
		"repeat_calm":
			var shown: String = _ceremony().view.card.get("part", "")
			if shown != "" or _banner().cards_shown != _cards_before or _banner().showing():
				_report("a repeat out of a fight shows nothing", false, "a card for %s was up %d frames after a repeat find" % [shown, _wait])
				return _finish()
			if _wait == QUIET_FRAMES:
				_report("a repeat out of a fight shows nothing", true, "common and relic repeats with the Warden dead: no card, no pop for %d frames" % QUIET_FRAMES)
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
				_banner().dismiss(true)
				_banner().cards = false
				_game.events.synergy_discovered.emit("wrecking_ball", "build", true)
				_game.events.synergy_discovered.emit("wrecking_ball", "build", false)
				_next("banner_mode")
		"banner_mode":
			if _banner().showing() or _banner().visible:
				_report("the banner option waits too", false, "a banner was drawn %d frames into a live Warden fight" % _wait)
				_banner().cards = true
				return _finish()
			if _wait == QUIET_FRAMES:
				_report("the banner option waits too", _banner().queued() == 1 and _fight_on(),
					"a synergy and its repeat found in a live Warden fight with --discovery=banner: nothing drawn for %d frames, %d queued (the repeat queues nothing)" % [QUIET_FRAMES, _banner().queued()])
				_banner().cards = true
				_game.flow.retry_stage()
				_next("retried")
		"retried":
			if _wait == 5:
				var dropped: bool = _ceremony()._cards.is_empty() and _banner().queued() == 0 and not _card_up()
				var unseen := true
				for id in _held:
					unseen = unseen and _unseen_both(id)
				_report("a retry drops the held cards", dropped and unseen, "after a retry: ceremony holds %d, banner holds %d, every held part still unseen %s" % [_ceremony()._cards.size(), _banner().queued(), unseen])
				_next("retried_calm")
		# The retried stage replays its own opening, and a plan that telegraphs early holds the
		# calm clock for a while; the next find is made once the stage is calm, so the check
		# reads the card gate and not the stage plan.
		"retried_calm":
			if WhyCallout.find_may_speak(_ceremony().get("_calm_left"), self, _game.flow):
				_game.hud.clear_achievement_toasts()
				_clear_crowd()
				_game.run.add_part(_held[0], "pickup")
				_next("again")
			elif _wait == CALM_WITHIN:
				_report("the retried stage turns calm", false, "still not calm %d frames after a retry" % CALM_WITHIN)
				return _finish()
		# A part is seen when its card is shown, so both seen means both cards took their turn, one after the other.
		"again":
			if _again_first < 0 and _card_up():
				_again_first = _wait
			if _seen_both(_held[0]):
				_report("the next first find shows its card", _seen_both(_held[0]) and not _fight_on() and _again_first >= 0 and _again_first <= OPEN_WITHIN,
					"%s found out of a fight after the retry shows its first card at frame %d (within %d) and both are seen at %d" % [_held[0], _again_first, OPEN_WITHIN, _wait])
				_engage()
				_engaged_at = _drawn
				_next("engaged")
			if _wait == BOTH_WITHIN:
				_report("the next first find shows its card", false, "no card for %s within %d frames out of a fight" % [_held[0], OPEN_WITHIN])
				return _finish()
		"engaged":
			if _wait >= 2 and (_drawn > _engaged_at or _wait == OPEN_WITHIN):
				_report("a reveal card closes when the fight goes live", _fight_on() and _ceremony().view.card.is_empty() and not _banner().showing() and _seen_both(_held[0]),
					"a reveal card up as the Warden engages: card %s, banner showing %s, %s still seen in both records" % [_ceremony().view.card.get("part", "none"), _banner().showing(), _held[0]])
				_game.flow.retry_stage()
				_next("boss_ready")
		"boss_ready":
			# The ball lands first: the ceremony's own calm() needs it on the ground.
			if _wait == 1:
				for node in get_nodes_in_group("enemy"):
					node.queue_free()
			if _wait > SETTLE:
				_report("a boss reward is queued", false, "the ball never settled for the boss check within %d frames" % SETTLE)
				return _finish()
			_calm_run = _calm_run + 1 if _ceremony().calm() else 0
			if _calm_run >= 60:
				_game.presentation.ceremony.set_process(false)
				_game.presentation.ceremony.pause_armed = true
				_game.presentation.ceremony.now_ms = func() -> int: return _clock_ms
				_game.events.player_hit.emit(1.0, "test")
				_game.presentation.ceremony._calm_left = WhyCallout.CALM_SECONDS - 0.5
				_game.run.add_part(_boss_part, "boss")
				_report("a boss reward is queued", _ceremony().queued() == 1 and _ceremony().presented.back()[2] == "boss" and _ceremony().calm(),
					"a boss-source ceremony 0.5 s after a hit: queued %d, calm %s" % [_ceremony().queued(), _ceremony().calm()])
				_next("boss_wait")
		"boss_wait":
			_clock_ms += int(STEP_S * 1000.0)
			# Only the damage clock is under test: the ball stays on the ground for the ceremony's own calm().
			_game.player.state.grounded = true
			_ceremony()._process(STEP_S)
			if _ceremony().active():
				_report("a boss reward ignores the damage clock", true, "opened %.2f s after the find, within the %.1f s victory roll" % [_wait * STEP_S, Flow.VICTORY_SECONDS])
				return _finish()
			if _wait * STEP_S >= Flow.VICTORY_SECONDS:
				_report("a boss reward ignores the damage clock", false, "no ceremony within %.1f s of frames with a hit 0.5 s before the find (queued %d, calm %s, state %s, ball %s, grounded %s)"
					% [Flow.VICTORY_SECONDS, _ceremony().queued(), _ceremony().calm(), _game.flow.state_name(), _game.player.ball_position(), _game.player.state.grounded])
				return _finish()
	return false


# The Warden's crowd still fights on in this stage; the card rule is about a quiet screen, so the
# test clears the stage's enemies (as its boss check does) and the fight's pressure.
func _clear_crowd() -> void:
	for node in get_nodes_in_group("enemy"):
		if node != _game.flow.warden:
			node.queue_free()
	_game.events.pressure_changed.emit(0.0)


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
