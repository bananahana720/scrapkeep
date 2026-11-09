extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")
const Rules := preload("res://src/boss/boss_rules.gd")
const BossPosture := preload("res://src/combat/boss_posture.gd")
const BossPlate := preload("res://src/ui/boss_plate.gd")

# Hits on a held phase bank (ruling bs). A chunk broken before its phase's minimum time holds
# the phase; until now the hull then took nothing, so a fast build's hits for the rest of the
# floor were dead. Now they fill the bar the next phase opens with, up to Rules.HELD_BANK of
# it: no stagger starts from a banked bar, it does not drain through the hold or the beat
# after it, and the plate shows it in the phase diamonds' colour with a post at the stop.
# The floors themselves (Rules.PHASE_MIN_SECONDS) are unchanged, and the Scuttle's hold banks
# nothing because no bar follows it.
#
# The fight runs through the game's own combat module, as boss_posture_test does: strikes are
# a physics frame apart and time is stepped with advance(DT).
#
# Evidence limit: combat.strike() stands in for the ball's contacts, and the plate is read
# through its own methods, not from pixels.

const DT := 1.0 / 90.0
const RAM_FORCE := 150.0

var _game
var _boss
var _combat
var _plate
var _failures := 0
var _phases: Array = []


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


func _stagger_by_rams(hull) -> int:
	var rams := 0
	while not _boss.staggered() and rams < 8:
		await _hit(hull, "ram", RAM_FORCE)
		rams += 1
	return rams


# Breaks the live phase's chunk: a crack in one opening, the shatter in the next.
func _break_chunk(hull) -> void:
	await _stagger_by_rams(hull)
	await _hit(hull, "ram", RAM_FORCE)
	_advance(BossPosture.STAGGER_SECONDS + 0.1)
	await _stagger_by_rams(hull)
	await _hit(hull, "ram", RAM_FORCE)


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	await physics_frame
	_combat = _game.combat
	_game.ctx.spawner = _combat
	_boss = _game.boss
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	_game.events.boss_phase_changed.connect(func(p: int, _name: String): _phases.append(p))
	Harness.start_run(_game)
	Harness.enter(_game, Vector3(18.0, 0.0, 0.0))
	await physics_frame
	_plate = _game.hud.boss_plate
	var hull = _boss.ship.hull
	var cap: float = Rules.HELD_BANK
	_advance(FightPhases.TRANSITION_SECONDS + 0.05)

	var fresh_rams: int = await _stagger_by_rams(hull)
	_advance(BossPosture.STAGGER_SECONDS + 0.1)
	_report("an open phase does not bank", not _boss.banking() and not _plate.banking() and _plate.bank_cap() == 0.0
			and _plate.bar_color() != BossPlate.phase_color(),
		"phase 1 before its chunk breaks: banking %s, plate banking %s, %d rams filled an empty bar" % [_boss.banking(), _plate.banking(), fresh_rams])

	await _break_chunk(hull)
	var broke_at: float = _boss.phase_clock
	var held: bool = _boss.phase == 1 and _boss.chunks_left() == 3 and _boss.music_state()["held"]
	_report("the chunk breaks early and the phase is held", held and broke_at < Rules.PHASE_MIN_SECONDS[0] and _boss.posture() == 0.0
			and _boss.banking(),
		"chunk broken %.1f s into a %.0f s floor; bar at %.1f; banking %s" % [broke_at, Rules.PHASE_MIN_SECONDS[0], _boss.posture(), _boss.banking()])

	await _hit(hull, "arc", 1.0e6)
	var shot: float = _boss.posture()
	await _hit(hull, "ram", RAM_FORCE)
	var rammed: float = _boss.posture()
	for _i in 7:
		await _hit(hull, "ram", RAM_FORCE)
	_report("held hits bank and stop at the cap", shot > 0.0 and shot < cap and rammed > shot and is_equal_approx(_boss.posture(), cap)
			and not _boss.staggered() and _boss.chunks_left() == 3 and not _boss.chunk_cracked() and _boss.phase == 1,
		"a shot banked %.1f, a ram took it to %.1f, seven more left the bar at %.1f (cap %.0f); staggered %s, %d chunks, cracked %s"
			% [shot, rammed, _boss.posture(), cap, _boss.staggered(), _boss.chunks_left(), _boss.chunk_cracked()])

	_report("the plate shows the bank", _plate.banking() and is_equal_approx(_plate.bar_fraction(), cap / BossPosture.FULL)
			and is_equal_approx(_plate.bank_cap(), cap / BossPosture.FULL) and _plate.bar_color() == BossPlate.phase_color()
			and _plate.bar_color() != BossPlate.bar_color_for(false) and _plate.bar_color() != BossPlate.bar_color_for(true),
		"bar %.2f full with its stop at %.2f, in the phase colour %s" % [_plate.bar_fraction(), _plate.bank_cap(), _plate.bar_color() == BossPlate.phase_color()])

	_advance(BossPosture.DRAIN_DELAY + 3.0)
	_report("a banked bar does not drain through the hold", is_equal_approx(_boss.posture(), cap) and _boss.phase == 1,
		"%.1f after %.0f idle seconds (an open bar drains after %.0f)" % [_boss.posture(), BossPosture.DRAIN_DELAY + 3.0, BossPosture.DRAIN_DELAY])

	_advance(Rules.PHASE_MIN_SECONDS[0] - _boss.phase_clock - 0.5)
	var still_one: bool = _boss.phase == 1
	_advance(1.0)
	_report("the floor is unchanged", still_one and _boss.phase == 2 and _phases == [1, 2],
		"phase 1 at %.1f s %s; then phases %s" % [Rules.PHASE_MIN_SECONDS[0] - 0.5, still_one, _phases])

	await _hit(hull, "ram", RAM_FORCE)
	var in_beat: bool = _boss._in_transition()
	var beat: float = _boss.posture()
	_advance(FightPhases.TRANSITION_SECONDS + 0.05)
	_report("the next phase opens on the banked bar", in_beat and is_equal_approx(beat, cap) and is_equal_approx(_boss.posture(), cap)
			and not _boss.banking() and not _plate.banking() and _plate.bar_color() == BossPlate.bar_color_for(false),
		"a ram in the beat left the bar at %.1f, and it read %.1f when the beat ended; banking %s" % [beat, _boss.posture(), _boss.banking()])

	var banked_rams: int = await _stagger_by_rams(hull)
	_report("the bank shortens the next stagger", _boss.staggered() and banked_rams >= 1 and banked_rams < fresh_rams,
		"%d rams from the banked bar against %d from an empty one" % [banked_rams, fresh_rams])
	_advance(BossPosture.STAGGER_SECONDS + 0.1)
	_advance(BossPosture.DRAIN_DELAY + 100.0 / BossPosture.DRAIN_RATE)
	_report("an open bar still drains", _boss.posture() == 0.0 and _boss.phase == 2,
		"%.1f after the stagger and a full idle drain" % _boss.posture())

	# The Scuttle's hold: its chunk is gone, the eject waits for the floor, and no bar follows.
	_boss.jump_to_phase(3)
	_advance(FightPhases.TRANSITION_SECONDS + 0.05)
	await _break_chunk(hull)
	var scuttle_held: bool = _boss.phase == 3 and _boss.chunks_left() == 1 and _boss.music_state()["held"]
	await _hit(hull, "ram", RAM_FORCE)
	_report("the Scuttle's hold banks nothing", scuttle_held and not _boss.banking() and not _plate.banking() and _boss.posture() == 0.0,
		"held %s with %d chunk left; banking %s; a ram left the bar at %.1f" % [scuttle_held, _boss.chunks_left(), _boss.banking(), _boss.posture()])

	print("brindle_held_bank_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
