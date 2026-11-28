extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")
const Rules := preload("res://src/boss/boss_rules.gd")
const BossPosture := preload("res://src/core/boss_posture.gd")
const BossPlate := preload("res://src/ui/boss_plate.gd")

# Hits on a held phase bank (ruling bs). A chunk broken before its phase's minimum time holds
# the phase, and hits on the held hull fill the bar the next phase opens with, up to
# Rules.HELD_BANK of it: no stagger starts from a banked bar, it does not drain through the
# hold or the beat after it, and the plate shows it in the phase diamonds' colour with a post
# at the stop. A hold with no hits banks nothing. The floors themselves
# (Rules.PHASE_MIN_SECONDS) are fixed, and the Scuttle's hold banks nothing because no bar
# follows it.
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

	# The beat is shorter than the rule's drain delay, so the delay is cut to a tenth of it here:
	# a bar that the beat did not hold would be drained before the beat ended.
	var delay: float = _boss._posture.drain_delay
	_boss._posture.drain_delay = FightPhases.TRANSITION_SECONDS * 0.1
	_advance(Rules.PHASE_MIN_SECONDS[0] - _boss.phase_clock - 0.5)
	var still_one: bool = _boss.phase == 1
	_advance(1.0)
	_report("the floor is unchanged", still_one and _boss.phase == 2 and _phases == [1, 2],
		"phase 1 at %.1f s %s; then phases %s" % [Rules.PHASE_MIN_SECONDS[0] - 0.5, still_one, _phases])

	await _hit(hull, "ram", RAM_FORCE)
	var in_beat: bool = _boss._in_transition()
	var beat: float = _boss.posture()
	_advance(FightPhases.TRANSITION_SECONDS - 0.5 - 2.0 * DT)
	var late_beat: bool = _boss._in_transition()
	var kept: float = _boss.posture()
	_report("the next phase opens on the banked bar", in_beat and late_beat and is_equal_approx(beat, cap) and is_equal_approx(kept, cap)
			and not _boss.banking() and not _plate.banking() and _plate.bar_color() == BossPlate.bar_color_for(false),
		"a ram in the beat left the bar at %.1f, and it read %.1f at the beat's last tick with the drain delay cut to %.1f s; banking %s"
			% [beat, kept, _boss._posture.drain_delay, _boss.banking()])

	# Past the beat the bar is the phase's own: left alone, it drains.
	_boss._posture.drain_delay = delay
	_advance(0.2)
	var opened: float = _boss.posture()
	_advance(BossPosture.DRAIN_DELAY + 1.0)
	var drained: float = _boss.posture()
	_report("an open bar still drains", not _boss._in_transition() and is_equal_approx(opened, cap) and drained < opened and _boss.phase == 2,
		"%.1f as the beat ended, %.1f after %.0f idle seconds" % [opened, drained, BossPosture.DRAIN_DELAY + 1.0])

	# The Furnace's hold banks the same way, from a bar that a hold without hits leaves empty.
	_advance(100.0 / BossPosture.DRAIN_RATE)
	var empty_rams: int = await _stagger_by_rams(hull)
	await _hit(hull, "ram", RAM_FORCE)
	_advance(BossPosture.STAGGER_SECONDS + 0.1)
	await _stagger_by_rams(hull)
	await _hit(hull, "ram", RAM_FORCE)
	var furnace_held: bool = _boss.phase == 2 and _boss.chunks_left() == 2 and _boss.banking()
	_advance(BossPosture.DRAIN_DELAY + 1.0)
	var unhit: float = _boss.posture()
	await _hit(hull, "ram", RAM_FORCE)
	await _hit(hull, "ram", RAM_FORCE)
	_report("the Furnace's hold banks, and a hold without hits banks nothing", furnace_held and unhit == 0.0
			and is_equal_approx(_boss.posture(), cap) and not _boss.staggered() and _boss.chunks_left() == 2,
		"held %s; %.1f after %.0f s with no hit; two rams left the bar at %.1f; staggered %s, %d chunks"
			% [furnace_held, unhit, BossPosture.DRAIN_DELAY + 1.0, _boss.posture(), _boss.staggered(), _boss.chunks_left()])

	_advance(Rules.PHASE_MIN_SECONDS[1] - _boss.phase_clock + 0.5)
	_advance(FightPhases.TRANSITION_SECONDS + 0.05)
	var scuttle_open: float = _boss.posture()
	var banked_rams: int = await _stagger_by_rams(hull)
	_report("the bank shortens the next stagger", _boss.phase == 3 and is_equal_approx(scuttle_open, cap) and _boss.staggered()
			and banked_rams >= 1 and banked_rams < empty_rams,
		"the Scuttle opened on %.1f: %d rams to stagger against %d from an empty bar in the Furnace" % [scuttle_open, banked_rams, empty_rams])

	# The Scuttle's hold: its chunk is gone, the eject waits for the floor, and no bar follows.
	await _hit(hull, "ram", RAM_FORCE)
	_advance(BossPosture.STAGGER_SECONDS + 0.1)
	await _stagger_by_rams(hull)
	await _hit(hull, "ram", RAM_FORCE)
	var scuttle_held: bool = _boss.phase == 3 and _boss.chunks_left() == 1 and _boss.music_state()["held"]
	await _hit(hull, "ram", RAM_FORCE)
	_report("the Scuttle's hold banks nothing", scuttle_held and not _boss.banking() and not _plate.banking() and _boss.posture() == 0.0,
		"held %s with %d chunk left; banking %s; a ram left the bar at %.1f" % [scuttle_held, _boss.chunks_left(), _boss.banking(), _boss.posture()])

	print("brindle_held_bank_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
