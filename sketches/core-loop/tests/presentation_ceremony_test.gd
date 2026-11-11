extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Hud := preload("res://src/ui/hud.gd")
const ScreenBusy := preload("res://src/ui/screen_busy.gd")
const Parts := preload("res://src/build/parts.gd")
const Ceremony := preload("res://src/presentation/reward_ceremony.gd")
const WordBudget := preload("res://src/ui/word_budget.gd")
const BossRules := preload("res://src/boss/boss_rules.gd")
const PartName := preload("res://src/ui/part_name.gd")
const Presentation := preload("res://src/presentation/presentation.gd")
const Push := preload("res://tests/workshop/push.gd")
const Synergies := preload("res://src/build/synergies.gd")
const SliceDefs := preload("res://src/core/slice_defs.gd")

# The reward ceremony (v3 W13). A real run, the ceremony's pause armed as in play:
#   - the tier follows rarity, a first find, a completed synergy, the ceremony sources
#     and the short setting, and every card's effect line is at most six words;
#   - a vault find queues while an enemy is near and pauses the tree only once it is gone;
#   - the ball's velocity is identical across the pause;
#   - a reveal card showing when the crate opens plays again after it;
#   - a key during the build jumps to the reveal, a second key closes it;
#   - the payoff accent waits for the part to land, then fires once on its first effect;
#   - a completed synergy's card snaps a wire to the partner's glyph;
#   - a part that feeds a synergy hints at the partner still to find, and on the slice
#     table never at a synergy the slice cuts;
#   - short plays a gate find at the rare tier with no pause, its stop drawn from the
#     shared hit-stop budget (the fight word budget with a flare up is ui_word_budget_test);
#   - a find that never calms waits as long as it takes: no card, no pause, never demoted.

const SETTLE_MS := 1500
const DEADLINE_MS := 45000

# 2026-10-04: the default table is the alpha ruleset (twelve parts, five synergies, class pick on); this test checks the full catalogue so it runs on the legacy FirstWorld table.
class LegacyGame extends "res://src/game.gd":
	func _chosen_table():
		return preload("res://tests/doubles/two_world_defs.gd").FirstWorld

var _game
var _ceremony
var _failures := 0
var _phase := "boot"
var _since := 0
var _enemy: Node3D
var _started := ""
var _revealed := ""
var _v0 := Vector3.ZERO
var _s0 := Vector3.ZERO
var _clock_ms := 0.0
var _card_after := false


func _initialize() -> void:
	_check_tiers()
	_check_slice_hints()
	_game = LegacyGame.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _check_slice_hints() -> void:
	Synergies.table = SliceDefs
	var leaks: Array = []
	for part_id in Parts.ids():
		var fed: Array = Ceremony._fed(part_id, [])
		if not fed.is_empty() and not Synergies.in_play(fed[0]):
			leaks.append("%s -> %s" % [part_id, fed[0]])
	Synergies.table = null
	_report("slice never hints a cut synergy", leaks.is_empty() and Synergies.in_play("storm_lattice"),
		"on the slice table no part feeds a cut synergy; leaks %s" % [leaks])


func _check_tiers() -> void:
	var cases := [
		["common", {}, "common"], ["rare", {}, "rare"], ["relic", {}, "reveal"],
		["evolved", {}, "ceremony"], ["common", {"first": true}, "reveal"], ["rare", {"synergy": "storm_lattice"}, "reveal"],
		["common", {"source": "gate"}, "ceremony"], ["rare", {"source": "vault"}, "ceremony"], ["common", {"source": "boss"}, "ceremony"],
		["relic", {"source": "gate", "short": true}, "rare"], ["common", {"first": true, "short": true}, "rare"],
		["relic", {"source": "shop"}, "reveal"], ["common", {"source": "fabricator"}, "common"],
	]
	var wrong: Array = []
	for c in cases:
		var got := Ceremony.tier_for(c[0], c[1])
		if got != c[2]:
			wrong.append("%s %s -> %s, wanted %s" % [c[0], c[1], got, c[2]])
	_report("tiers", wrong.is_empty(), "%d rarity and context cases; wrong %s" % [cases.size(), wrong])
	var by_part := {"hot_rivets": "common", "sunforged_core": "rare", "tempest_core": "reveal", "slag_rounds": "common"}
	var part_wrong: Array = []
	for id in by_part:
		if Ceremony.tier_of(id) != by_part[id]:
			part_wrong.append("%s -> %s" % [id, Ceremony.tier_of(id)])
	_report("tier from the part row", part_wrong.is_empty(), "tier_of reads each row's rarity; wrong %s" % [part_wrong])
	var long: Array = []
	for id in Parts.ids():
		if WordBudget.words_in(Ceremony.card_words(id)) > int(EventKinds.reward_row("reveal")["words"]):
			long.append(id)
	_report("six words", long.is_empty(), "%d parts, each card line at most 6 words; over %s" % [Parts.ids().size(), long])
	var tokens: Array = []
	for id in Parts.TOKENS:
		var row: Dictionary = Parts.token(id)
		if Parts.def(id) != null or String(row.get("name", "")) == "" or String(row.get("stamp", "")) == "" \
				or Ceremony.card_words(id) != String(row.get("verb", "")) or Ceremony.card_words(id) == "":
			tokens.append(id)
	var found: Dictionary = Presentation.part_card(BossRules.CREST_PART)
	_report("run tokens", tokens.is_empty() and not Parts.token(BossRules.CREST_PART).is_empty() and PartName.name_of(BossRules.CREST_PART) == "Admiral's Crest"
			and found == {"title": "Admiral's Crest", "detail": "Fleet property. Yours now."} and Presentation.part_card("hot_rivets")["title"] == Parts.display_name("hot_rivets"),
		"%d run tokens, each with a name, a stamp and a card line inside six words, and no catalogue row; Brindle's crest is one and its found card reads %s; wrong %s"
			% [Parts.TOKENS.size(), found, tokens])


func _next(phase: String) -> void:
	_phase = phase
	_since = int(_clock_ms)


# The finds' quiet hold plus 60 frames, from the source's own constant; three held cards' lives for the drain.
const FIND_MS := int(ScreenBusy.FIND_HOLD * 1000.0) + 1000
# The crate is still on screen for its out phase when this phase starts; the card it pushed off comes back after.
var OUT_MS := int(float(EventKinds.reward_row("ceremony")["out_s"]) * 1000.0)
# The held reveal cards drain one card's life each (the reveal row's in, hold and out) plus 60 frames, up to MAX_HELD.
var REVEAL_MS := int((float(EventKinds.reward_row("reveal")["in_s"]) + float(EventKinds.reward_row("reveal")["hold_s"]) \
		+ float(EventKinds.reward_row("reveal")["out_s"])) * 1000.0)
var DRAIN_MS := FIND_MS + Ceremony.MAX_HELD * (REVEAL_MS + 1000)


var _ahead_ms := 0


func _elapsed() -> int:
	return int(_clock_ms) - _since


func _physics_process(_delta: float) -> bool:
	# Fixed simulation ticks continue through the ceremony's tree pause.
	_clock_ms += 1000.0 / Engine.physics_ticks_per_second
	# The screen's quiet seconds follow this test's own clock (screen_busy.gd).
	_game.ctx.screen_busy.step(1.0 / Engine.physics_ticks_per_second)
	if _game == null or _game.flow == null:
		return false
	if int(_clock_ms) > DEADLINE_MS:
		_report("deadline", false, "stuck in phase %s" % _phase)
		return _finish()
	if _ceremony != null:
		_ceremony._process(1.0 / Engine.physics_ticks_per_second)
	match _phase:
		"boot":
			_game.ctx.calm = true
			_game.player.source = Intent.Scripted.new()
			_game.flow.press_start()
			_game.flow.choose_class(0)
			_ceremony = _game.presentation.ceremony
			_ceremony.set_process(false)
			_ceremony.now_ms = func() -> int: return int(_clock_ms)
			_ceremony.pause_armed = true
			_ceremony.started.connect(func(part: String): _on_started(part))
			_ceremony.revealed.connect(func(part: String): _revealed = part)
			_next("settle")
		"settle":
			if _elapsed() > SETTLE_MS:
				var ball: Vector3 = _game.player.ball_position()
				_enemy = _game.ctx.spawner.spawn_enemy("chaser", _game.ctx.terrain.drop_point(ball.x + 6.0, ball.z + 6.0, 1.0))
				_game.run.add_part("sunforged_core", "vault")
				_game.ctx.spawner.strike(_enemy, "shell", 1.0)
				_next("near")
		"near":
			if _elapsed() > 900:
				_report("queued while not calm", _ceremony.queued() == 1 and not _ceremony.active() and not paused and not _ceremony.calm(),
					"an enemy %.1f m off: queued %d, active %s, paused %s" % [_enemy.global_position.distance_to(_game.player.ball_position()),
						_ceremony.queued(), _ceremony.active(), paused])
				_report("no payoff before it lands", _ceremony.payoffs.filter(func(p: Array): return p[0] == "sunforged_core").is_empty()
						and not _ceremony.armed().has("sunforged_core"),
					"a strike while the vault find waits: payoffs %s, armed %s" % [_ceremony.payoffs, _ceremony.armed()])
				_game.ctx.spawner.strike(_enemy, "ram", 9999.0)
				_game.run.add_part("tempest_core", "milestone")
				_game.player.set_velocity_now(Vector3(4.0, 0.0, 3.0))
				_next("calming")
		"calming":
			if _started != "":
				_next("build")
			elif _elapsed() > 8000:
				_report("pauses when calm", false, "no ceremony began within 8 s of the enemy's death (calm %s)" % _ceremony.calm())
				return _finish()
		"build":
			if _elapsed() > 300:
				var body: RigidBody3D = _game.player.body()
				_report("paused mid-build", paused and _ceremony.phase() == "build" and body.linear_velocity == _v0,
					"paused %s, phase %s, velocity %s (held %s)" % [paused, _ceremony.phase(), body.linear_velocity, _v0])
				Push.key(root, KEY_X)
				_report("skip to the reveal", _ceremony.phase() == "reveal" and _revealed == "sunforged_core" and paused,
					"a key in the build: phase %s, revealed %s, still paused %s" % [_ceremony.phase(), _revealed, paused])
				Push.key(root, KEY_X)
				var v1: Vector3 = body.linear_velocity
				var s1: Vector3 = _game.player.state.velocity
				_report("closes", not paused and _ceremony.phase() == "out", "a second key: paused %s, phase %s" % [paused, _ceremony.phase()])
				_card_after = true
				_report("velocity kept", v1 == _v0 and s1 == _s0 and _v0.length() > 0.5,
					"body %s -> %s, state %s -> %s" % [_v0, v1, _s0, s1])
				# The HUD's own cards (a note, an achievement) go first, ACH_TOTAL each; one more for a note raised meanwhile.
				var hud = _game.hud
				_ahead_ms = int((hud.ach_waiting().size() + hud.tune_waiting().size() + (1 if hud._lore_due or hud._lore_left > 0.0 else 0) + (0 if hud._ach_entry.is_empty() else 1) + 1) * Hud.ACH_TOTAL * 1000.0)
				_next("payoff")
		"payoff":
			# The card the crate pushed off comes back, oldest first, once the screen is quiet again: polled each
			# frame (its life is short) and failed at the bound.
			if _card_after:
				var shown: Dictionary = _ceremony.view.card
				var back: bool = shown.get("part", "") == "tempest_core" and not shown.get("ceremony", true)
				if back or _elapsed() > FIND_MS + OUT_MS + _ahead_ms:
					_card_after = false
					_report("a card the crate interrupted comes back", back, "after the ceremony the card shows %s (bound %d ms)" % [shown.get("part", "nothing"), FIND_MS + OUT_MS + _ahead_ms])
			if _elapsed() > FIND_MS + OUT_MS + _ahead_ms and not _card_after:
				var armed: Array = _ceremony.armed()
				var ball: Vector3 = _game.player.ball_position()
				var target: Node3D = _game.ctx.spawner.spawn_enemy("chaser", _game.ctx.terrain.drop_point(ball.x + 5.0, ball.z - 5.0, 1.0))
				_game.ctx.spawner.strike(target, "shell", 1.0)
				_game.ctx.spawner.strike(target, "shell", 1.0)
				var paid: Array = _ceremony.payoffs.filter(func(p: Array): return p[0] == "sunforged_core")
				_report("payoff once", armed.has("sunforged_core") and paid.size() == 1 and paid[0][1] == "enemy_struck"
						and _ceremony.view.flashes.size() >= 1,
					"armed after landing %s; two strikes paid %s; flashes %d" % [armed, paid, _ceremony.view.flashes.size()])
				_game.ctx.spawner.strike(target, "ram", 9999.0)
				_next("synergy")
		"synergy":
			if _elapsed() > 200:
				var find: Dictionary = _ceremony.find_of("loose_trigger", "test")
				_report("synergy hint", find["link"] == "hint" and find["partner"] == "spiral_wave",
					"loose_trigger with no spiral held feeds %s: link %s, partner %s" % [find["synergy"], find["link"], find["partner"]])
				_game.run.add_part("chain_arc", "test")
				_game.run.add_part("cross_split", "test")
				var wired: Dictionary = _ceremony.find_of("cross_split", "test")
				var card: Dictionary = _ceremony.card_state(wired, int(_clock_ms), false)
				_report("synergy snaps", wired["link"] == "lit" and wired["tier"] == "reveal" and card["partner_icon"] == Ceremony.icon_of("chain_arc"),
					"cross_split after chain_arc completes %s: link %s, tier %s, partner glyph %s"
						% [wired["synergy"], wired["link"], wired["tier"], card["partner_icon"]])
				var crest: Dictionary = _ceremony.card_state(_ceremony.find_of(BossRules.CREST_PART, "boss"), int(_clock_ms), false)
				_report("crest card", crest["name"] == "Admiral's Crest" and crest["stamp"] == "TROPHY" and crest["verb"] == "Fleet property. Yours now.",
					"Brindle's crest reveals as %s · %s, \"%s\"" % [crest["stamp"], crest["name"], crest["verb"]])
				_next("short")
		"short":
			if _elapsed() > FIND_MS:
				_ceremony.short = true
				_game.presentation.juice.reset_stops()
				var before: int = _game.presentation.juice.hit_stop_log.size()
				_game.run.add_part("tempest_core", "gate")
				var last: Array = _ceremony.presented.back()
				var stops: Array = _game.presentation.juice.hit_stop_log.slice(before).filter(func(s: Array): return s[2] == "reward_rare")
				var row := EventKinds.reward_row("rare")
				_report("short is rare", last[1] == "rare" and _ceremony.queued() == 0 and not _ceremony.active() and not paused
						and stops.size() == 1 and float(stops[0][1]) <= float(row["stop_ms"]) / 1000.0 + 0.0001,
					"a gate find with short on: tier %s, queued %d, paused %s, stop asked %s" % [last[1], _ceremony.queued(), paused, stops])
				_ceremony.short = false
				_next("wait")
		"wait":
			# The reveal cards held so far take their turns first (a crate counts them against its cap).
			if _elapsed() > DRAIN_MS and not _ceremony._cards.is_empty():
				_report("never calm keeps waiting", false, "%d held reveal cards never took their turns within %d ms" % [_ceremony._cards.size(), DRAIN_MS])
				return _finish()
			if _elapsed() > 300 and _ceremony._cards.is_empty():
				var ball: Vector3 = _game.player.ball_position()
				_enemy = _game.ctx.spawner.spawn_enemy("chaser", _game.ctx.terrain.drop_point(ball.x - 6.0, ball.z + 6.0, 1.0))
				_game.run.add_part("rime_heart", "cache")
				_ceremony.now_ms = func() -> int: return int(_clock_ms) + 11000
				_next("demoted")
		"demoted":
			if _elapsed() > 200:
				var last: Array = _ceremony.presented.back()
				_report("never calm keeps waiting", last[0] == "rime_heart" and last[1] == "ceremony" and _ceremony.queued() == 1
						and not _ceremony.active() and not paused and _ceremony.view.card.get("part", "") != "rime_heart",
					"11 s with an enemy near: last %s, queued %d, paused %s, card shows %s"
						% [last, _ceremony.queued(), paused, _ceremony.view.card.get("part", "nothing")])
				return _finish()
	return false


func _on_started(part: String) -> void:
	_started = part
	_v0 = _game.player.body().linear_velocity
	_s0 = _game.player.state.velocity
	_report("pauses when calm", part == "sunforged_core" and paused and _ceremony.queued() == 0,
		"the enemy gone: began %s, paused %s, queued %d, velocity %s" % [part, paused, _ceremony.queued(), _v0])


func _finish() -> bool:
	print("presentation_ceremony_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	paused = false
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true
