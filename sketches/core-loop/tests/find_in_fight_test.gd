extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Parts := preload("res://src/build/parts.gd")
const WordBudget := preload("res://src/ui/word_budget.gd")
const Flow := preload("res://src/core/flow.gd")
const WhyCallout := preload("res://src/ui/why_callout.gd")
const ScreenBusy := preload("res://src/ui/screen_busy.gd")
const Hud := preload("res://src/ui/hud.gd")
const CodexBanner := preload("res://src/presentation/codex_banner.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")

# A find never puts a card up during a fight (alpha R3, unit RV). A live slice game, a posture
# Warden engaged by a real ram:
#   - the one gate: the ceremony and the banner both ask ScreenBusy (screen_busy.gd) and test
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
# Every bound is the source's own constant plus 60 frames. A find's card waits for the screen to be quiet
# for FIND_HOLD (screen_busy.gd); the first find's two cards (the banner's and the ceremony's) then take turns,
# so the second comes one card's life after the first; cards the HUD already holds go first, ACH_TOTAL each.
const FIND_FRAMES := int(ScreenBusy.FIND_HOLD * 60.0)
const OPEN_WITHIN := FIND_FRAMES + 60
const NEXT_WITHIN := 60
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
var _boss_holder := ""
# Drawn frames. The card closes in the ceremony's _process, and under load several physics
# ticks can run back to back before the next one, so a close is read after a drawn frame.
var _drawn := 0
var _engaged_at := 0
var _ahead := 0
var _first_by := 0
var _both_by := 0
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
		if not (text.contains("_busy().settled(") or text.contains("_busy.settled(")):
			bad.append("%s never calls the gate" % path)
		if text.contains("is_calm(") or text.contains("threat_live(") or text.contains("find_may_speak("):
			bad.append("%s reads calm itself" % path)
	_report("one gate", bad.is_empty(), "the ceremony and the banner both ask the screen_busy gate and neither tests calm another way; %s" % [bad])


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
	# The Warden break's hot-wired part would stand a third gate on the middle slot, where this
	# test parks the ball, and end the run; the cards here are about finds, so it is spent.
	_game.ctx.build._hotwire_spent = true
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
				# A quick break (RunClock) would stand a third arch on the middle slot too: not this fight's.
				_game.ctx.build.clock.engaged_at = -1.0
				_game.flow.warden._die()
				# The Warden's crowd is really removed (not announced away): the screen's quiet clock then runs.
				_remove_crowd()
				# The director would spawn the next crowd at once; this flag is how the tests ask it not to.
				_game.ctx.calm = true
				_ahead = _hud_ahead()
				_first_by = OPEN_WITHIN + int(_ahead * Hud.ACH_TOTAL * 60.0)
				_both_by = _first_by + _card_life_frames() + NEXT_WITHIN
				_next("open")
		"open":
			if _opened < 0 and _card_up():
				_opened = _wait
				_marked_early = false
				_report("held card opens", _ceremony().view.card.get("part", "") == _first or _banner().showing(), "%s opens %d frames after the Warden's break" % [_first, _wait])
				_report("seen only now", _seen_either(_first) and not _marked_early, "%s seen in a record at the frame its first card shows, not before" % _first)
			if _opened < 0 and _seen_either(_first):
				_marked_early = true
			if _wait == _first_by:
				_report("opens within the quiet hold plus 60 frames, once", _opened >= 0 and not _marked_early and not _fight_on(),
					"opened at frame %d (bound %d: hold %d + 60, %d cards ahead), seen early %s" % [_opened, _first_by, FIND_FRAMES, _ahead, _marked_early])
			if _wait == _both_by or (_wait > _first_by and _seen_both(_first)):
				_report("seen in both records, each when its own card shows", _seen_both(_first) and _banner().cards_shown == _cards_before + 1,
					"%s seen in both records by frame %d of %d, banner cards %d (was %d)" % [_first, _wait, _both_by, _banner().cards_shown, _cards_before])
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
				_game.ctx.calm = false
				_game.flow.retry_stage()
				_next("refight")
		"refight":
			if _wait == 5:
				_game.ctx.calm = false
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
			if _game.ctx.screen_busy.settled(ScreenBusy.FIND_HOLD):
				_game.ctx.calm = true
				_remove_crowd()
				_ahead = _hud_ahead()
				_first_by = OPEN_WITHIN + int(_ahead * Hud.ACH_TOTAL * 60.0)
				_game.run.add_part(_held[0], "pickup")
				_next("again")
			elif _wait == CALM_WITHIN:
				_report("the retried stage turns calm", false, "still not calm %d frames after a retry" % CALM_WITHIN)
				return _finish()
		"again":
			if _again_first < 0 and _card_up():
				_again_first = _wait
			if _again_first >= 0 and not _seen_both(_held[0]) and _wait > _again_first + NEXT_WITHIN + _card_life_frames():
				_report("the next first find shows its card", false, "no second card within one card's life plus 60 frames of the first (frame %d)" % _again_first)
				return _finish()
			if _seen_both(_held[0]):
				_report("the next first find shows its card", _again_first >= 0 and _again_first <= _first_by and not _fight_on(),
					"%s found out of a fight after the retry shows its first card at frame %d (bound %d) and both are seen" % [_held[0], _again_first, _first_by])
				_game.ctx.calm = false
				_engage()
				_engaged_at = _drawn
				_next("engaged")
			if _again_first < 0 and _wait == _first_by:
				_report("the next first find shows its card", false, "no card for %s within %d frames out of a fight" % [_held[0], OPEN_WITHIN])
				return _finish()
		"engaged":
			if _wait >= 2 and (_drawn > _engaged_at or _wait == 60):
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
				# A card on screen holds even a boss's crate back (crate_slot_test); this checks the damage clock
				# alone, so the HUD's cards are cleared as the ending clears them and the screen is free at the find.
				_game.hud.clear_achievement_toasts()
				_boss_holder = _game.ctx.screen_busy.showing()
				_game.events.player_hit.emit(1.0, "test")
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
				_report("a boss reward ignores the damage clock", false, "no ceremony within %.1f s of frames with a hit 0.5 s before the find (queued %d, calm %s, state %s, ball %s, grounded %s, screen held by '%s' at the find and '%s' now)"
					% [Flow.VICTORY_SECONDS, _ceremony().queued(), _ceremony().calm(), _game.flow.state_name(), _game.player.ball_position(), _game.player.state.grounded,
						_boss_holder, _game.ctx.screen_busy.showing()])
				return _finish()
	return false


# One card's life in frames: the longest of the banner's and the ceremony's reveal card.
func _card_life_frames() -> int:
	var row := EventKinds.reward_row("reveal")
	var reveal := float(row["in_s"]) + float(row["hold_s"]) + float(row["out_s"])
	var banner := CodexBanner.CARD_HOLD_MAX + CodexBanner.IN_TIME + CodexBanner.OUT_TIME
	return int(ceilf(maxf(reveal, banner) * 60.0))


# The HUD's own cards that go before a find's: waiting, or on screen now (the note counts while due or up).
func _hud_ahead() -> int:
	var hud = _game.hud
	return hud.ach_waiting().size() + hud.tune_waiting().size() + (1 if hud._lore_due or hud._lore_left > 0.0 else 0) + (0 if hud._ach_entry.is_empty() else 1)


# The Warden's crowd is removed for real, as a stage reset does (the Warden itself stays while it stands).
func _remove_crowd() -> void:
	for node in get_nodes_in_group("enemy"):
		if node != _game.flow.warden:
			node.queue_free()


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
