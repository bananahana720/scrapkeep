extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")
const Rules := preload("res://src/boss/boss_rules.gd")
const BossContract := preload("res://src/boss/boss_contract.gd")
const BossPosture := preload("res://src/combat/boss_posture.gd")

# Brindle's hull on the posture contract, struck through the game's own combat module:
# real contacts fill the bar and stagger him, a stagger opens the cockpit, a contact in
# the opening cracks and a later one shatters a chunk, each chunk ends a phase no sooner
# than its floor (the opening flourish on the base tier; the tier row decides), guns press the bar and never crack, a smash shatters at once,
# three chunks lead to the eject and the catch takes the fourth through _defeat exactly
# once. A wear-trail patch cannot make the catch, and a kill under its tag carries it.
# Strikes are a physics frame apart (the rule keys contacts to the frame); time in the
# fight is stepped with advance(DT), never the wall clock.
#
# Evidence limit: combat.strike() stands in for the ball's contacts; this does not fly
# the ball into the hull.

const DT := 1.0 / 90.0
const RAM_FORCE := 150.0

var _game
var _boss
var _combat
var _failures := 0
var _phases: Array = []
# The fight clock at each boss_phase_changed, by phase.
var _turned_at := {}
var _defeats := 0
var _weak: Array = []
var _kill_tags: Array = []


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _above() -> void:
	Harness.put_ball(_game, _boss.arena.global_position + Vector3.UP * 40.0)


func _hit(target, kind: String, force: float) -> void:
	_above()
	_combat.strike(target, kind, force)
	await physics_frame


func _advance(seconds: float) -> void:
	for _i in int(ceil(seconds / DT)):
		_above()
		_boss.advance(DT)


# Rams the hull a frame apart until it staggers; returns the rams it took.
func _stagger_by_rams(hull) -> int:
	var rams := 0
	while not _boss.staggered() and rams < 6:
		await _hit(hull, "ram", RAM_FORCE)
		rams += 1
	return rams


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	await physics_frame
	_combat = _game.combat
	_game.ctx.spawner = _combat
	_boss = _game.boss
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	var events = _game.events
	events.boss_phase_changed.connect(func(p: int, _name: String):
		_phases.append(p)
		_turned_at[p] = _boss.clock)
	events.boss_defeated.connect(func(): _defeats += 1)
	events.boss_weak_point_hit.connect(func(id: String): _weak.append(id))
	events.enemy_killed.connect(func(kind: String, _at: Vector3, _scrap: int):
		if kind == "brindle":
			_kill_tags.append(_game.run.last_kill_from_spark))
	Harness.start_run(_game)
	Harness.enter(_game, Vector3(18.0, 0.0, 0.0))
	await physics_frame
	var hull = _boss.ship.hull

	# The contract surfaces.
	var target_missing: Array = BossContract.conforms(hull, BossContract.TARGET)
	var module_missing: Array = BossContract.conforms(_boss, BossContract.MODULE)
	_report("contract", target_missing.is_empty() and module_missing.is_empty() and hull.fight() == "posture"
			and _boss.ship.magnets[0].fight() == "plating" and _boss.chunks_left() == BossPosture.CHUNKS and _boss.hp == Rules.MAX_HP,
		"hull misses %s, module misses %s; hull fights %s, a magnet %s; %d chunks, hp %.0f"
			% [target_missing, module_missing, hull.fight(), _boss.ship.magnets[0].fight(), _boss.chunks_left(), _boss.hp])

	# Real contacts fill the bar; a full bar staggers and opens the cockpit.
	await _hit(hull, "ram", RAM_FORCE)
	var first: float = _boss.posture()
	var rams := 1 + await _stagger_by_rams(hull)
	var cockpit_open: bool = not _boss.ship._cockpit.visible
	_report("contacts stagger", first > 0.0 and first < BossPosture.FULL and _boss.staggered() and rams == 2
			and absf(hull.stagger_left() - BossPosture.STAGGER_SECONDS) < 0.1 and cockpit_open,
		"one ram filled the bar to %.1f, %d rams staggered him (%s, %.2f s left), cockpit open %s"
			% [first, rams, _boss.staggered(), hull.stagger_left(), cockpit_open])

	# In the opening a gun does nothing to the core; a contact cracks the chunk.
	await _hit(hull, "arc", 1.0e6)
	var gun_cracked: bool = _boss.chunk_cracked()
	await _hit(hull, "ram", RAM_FORCE)
	var cracked: bool = _boss.chunk_cracked()
	await _hit(hull, "ram", RAM_FORCE)
	_report("contact cracks", not gun_cracked and cracked and _boss.chunks_left() == 4 and _boss.staggered(),
		"a 1e6 shot on the open core cracked %s; a ram cracked %s; a second ram in the same opening left %d chunks"
			% [gun_cracked, cracked, _boss.chunks_left()])

	# The stagger runs out and closes the cockpit; the next opening's contact shatters.
	_advance(BossPosture.STAGGER_SECONDS + 0.1)
	var closed: bool = not _boss.staggered() and _boss.ship._cockpit.visible
	await _stagger_by_rams(hull)
	_weak.clear()
	# A build strong enough to break him inside the opening flourish: the phase clock restarts here.
	_boss.phase_clock = 0.0
	await _hit(hull, "ram", RAM_FORCE)
	_report("contact shatters", closed and _boss.chunks_left() == 3 and _boss.hp == 3.0 and not _boss.staggered()
			and _boss.posture() == 0.0 and _weak == ["cockpit"],
		"cockpit closed after the stagger %s; the crack paid off in the next opening: %d chunks, hp %.0f, stagger over %s, published %s"
			% [closed, _boss.chunks_left(), _boss.hp, not _boss.staggered(), _weak])

	# The floor is the longer of the flourish and the run tier's row (Brindle phase floors card, 24 Oct).
	var floor_one: float = _boss.phase_floor()
	_game.run.run_tier = 1
	var hard_one: float = _boss.phase_floor()
	_game.run.run_tier = 0
	var rows_ok: bool = (Rules.PHASE_MIN_BY_TIER.has(0) and Rules.PHASE_MIN_BY_TIER.has(1)
		and Rules.PHASE_MIN_BY_TIER[0].size() == 3 and Rules.PHASE_MIN_BY_TIER[1].size() == 3
		and Rules.SET_PIECE_SECONDS == [28.0, 24.0, 22.0])
	_report("floor reads the tier row", rows_ok and is_equal_approx(floor_one, maxf(Rules.INTRO_SECONDS, float(Rules.PHASE_MIN_BY_TIER[0][0])))
			and is_equal_approx(hard_one, maxf(Rules.INTRO_SECONDS, float(Rules.PHASE_MIN_BY_TIER[1][0]))),
		"phase 1 floor %.2f s base, %.2f s HARD (intro %.1f s); rows %s, set pieces kept %s"
			% [floor_one, hard_one, Rules.INTRO_SECONDS, Rules.PHASE_MIN_BY_TIER, Rules.SET_PIECE_SECONDS])

	# The broken chunk holds the phase until its floor; the bar takes nothing meanwhile.
	await _hit(hull, "ram", RAM_FORCE)
	var held_posture: float = _boss.posture()
	var held: bool = _boss.phase == 1 and _boss.music_state()["held"]
	_advance(floor_one - _boss.phase_clock - 0.5)
	var still_one: bool = _boss.phase == 1
	_advance(1.0)
	_report("phase waits its floor", held and held_posture == 0.0 and still_one and _boss.phase == 2 and _phases == [1, 2],
		"chunk broken at phase 1: held %s, a ram moved the bar to %.1f; phase 1 at %.1f s %s, then phases %s"
			% [held, held_posture, floor_one - 0.5, still_one, _phases])

	# Phase 2 opens with the transition beat (fight_phases.gd): the bar takes nothing until it ends.
	_combat.strike(hull, "arc", 1.0e6)
	var beat_posture: float = _boss.posture()
	var floor_two: float = _boss.phase_floor()
	_advance(FightPhases.TRANSITION_SECONDS + 0.05)
	_report("transition beat holds the bar", beat_posture == 0.0 and not _boss._in_transition(),
		"a 1e6 shot in the beat moved the bar to %.1f; beat over %s" % [beat_posture, not _boss._in_transition()])

	# Guns press the bar to a stagger, but never crack the core.
	var shots := 0
	while not _boss.staggered() and shots < 200:
		_combat.strike(hull, "arc", 1.0e6)
		shots += 1
	var gun_stagger: bool = _boss.staggered()
	await physics_frame
	for _i in 3:
		await _hit(hull, "arc", 1.0e6)
	_report("guns press, never crack", gun_stagger and shots > 2 and not _boss.chunk_cracked() and _boss.chunks_left() == 3,
		"%d shots staggered him (%s); three more on the open core left cracked %s, %d chunks"
			% [shots, gun_stagger, _boss.chunk_cracked(), _boss.chunks_left()])

	# The hook chain's smash shatters an open core on its first contact.
	_game.player.smash_landing = hull
	await _hit(hull, "ram", RAM_FORCE)
	_game.player.smash_landing = null
	_report("smash shatters", _boss.chunks_left() == 2 and not _boss.staggered(),
		"a smash on the open core left %d chunks" % _boss.chunks_left())

	# Phase 3, its chunk, then the eject. Past its floor, a broken chunk turns the phase at once.
	_advance(maxf(floor_two - _boss.phase_clock, 0.0))
	var broke_two: float = _boss.clock
	_advance(0.1)
	var into_three: bool = _boss.phase == 3
	var waited_two: float = float(_turned_at.get(3, INF)) - broke_two
	_advance(Rules.CHARGE_REST + Rules.CHARGE_WARN + 3.0)
	await _stagger_by_rams(hull)
	_game.player.smash_landing = hull
	await _hit(hull, "ram", RAM_FORCE)
	_game.player.smash_landing = null
	var after_three: int = _boss.chunks_left()
	_advance(maxf(_boss.phase_floor() - _boss.phase_clock, 0.0) + 0.1)
	_report("three chunks to the eject", into_three and after_three == 1 and _boss.state_name() == "eject" and _phases == [1, 2, 3, 4]
			and is_equal_approx(floor_two, maxf(FightPhases.TRANSITION_SECONDS, float(Rules.PHASE_MIN_BY_TIER[0][1]))) and waited_two <= 0.1 + DT,
		"phase 2 floor %.2f s (beat %.1f s), turned %.2f s after its chunk; phase 3 %s; chunks after its opening %d; state %s, phases %s"
			% [floor_two, FightPhases.TRANSITION_SECONDS, waited_two, into_three, after_three, _boss.state_name(), _phases])

	# A patch cannot make the catch: it only damages, and the catch is a contact.
	_advance(Rules.EJECT_FLIGHT + 0.2)
	var scooter = _boss.scooter
	scooter.last_damage_source = "spark"
	scooter.take_damage(1.0e6)
	scooter.last_damage_source = ""
	var patch_no_kill: bool = _boss.state_name() == "eject" and _defeats == 0
	# The fourth chunk: the catch, made while the scooter carries the patch's tag.
	Harness.put_ball(_game, scooter.global_position + Vector3.UP * 1.8)
	scooter.last_damage_source = "spark"
	_combat.strike(scooter, "ram", 20.0)
	scooter.last_damage_source = ""
	_combat.strike(scooter, "ram", 20.0)
	_boss._defeat("ram", scooter.global_position)
	_report("defeat once", patch_no_kill and _defeats == 1 and _boss.state_name() == "defeated" and _boss.chunks_left() == 0
			and _boss.hp == 0.0 and _kill_tags.size() == 1,
		"a patch on the landed scooter left state %s; the catch: defeats %d, state %s, chunks %d, hp %.0f, kills recorded %d"
			% ["eject" if patch_no_kill else "changed", _defeats, _boss.state_name(), _boss.chunks_left(), _boss.hp, _kill_tags.size()])
	_report("kill tag", _kill_tags == [true], "the defeat's enemy_killed saw last_kill_from_spark %s" % [_kill_tags])

	print("boss_posture_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
