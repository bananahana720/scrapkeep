extends SceneTree

const Game := preload("res://src/game.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")
const Hazard := preload("res://src/boss/hazard.gd")
const Rules := preload("res://src/boss/boss_rules.gd")
const Palette := preload("res://src/core/palette.gd")
const T := preload("res://tests/support/t.gd")

# W1-107: Brindle's eject draws a ground mark where the scooter lands, committed through the
# shared Hazard code. It appears on the step the cue sounds (boss_attack_telegraphed "eject"),
# warns for EJECT_FLIGHT, goes live on the step the scooter lands, and covers the catch circle
# (SCOOTER_TOUCH around the landing point). The eject's numbers do not move: the landing step,
# the phase, the events, and no damage to the ball standing inside the mark.
# Evidence limit: committed geometry and timings headless, not a rendered still.

const DT := 1.0 / 90.0
# Measured on the unchanged code (the run's own numbers, see the report).
const BASE_LAND_TICKS := 226
const BASE_CUES := 1

var game
var t := T.new("eject_mark_test")
var _cues: Array = []
var _hits: Array = []
var _phases: Array = []


func _initialize() -> void:
	game = Game.new()
	game.test_mode = true
	root.add_child(game)
	_run.call_deferred()


func _mark(boss):
	return boss.eject_mark() if boss.has_method("eject_mark") else null


func _run() -> void:
	while game.flow == null:
		await physics_frame
	Harness.install(game)
	Harness.start_run(game)
	game.ctx.calm = false
	game.events.boss_attack_telegraphed.connect(func(id: String, s: float): _cues.append([id, s]))
	game.events.player_hit.connect(func(a: float, source: String): _hits.append([a, source]))
	game.events.boss_phase_changed.connect(func(n: int, _name: String): _phases.append(n))
	Harness.enter(game, Vector3(18.0, 0.0, 0.0))
	var boss = game.boss
	boss.jump_to_phase(4)
	t.check("eject began", boss.state == boss.EJECT and boss.phase == boss.CHASE_PHASE, "state %d phase %d" % [boss.state, boss.phase])
	var ejects := _cues.filter(func(c): return c[0] == "eject")
	t.check("one eject cue, warn is the flight", ejects.size() == BASE_CUES and is_equal_approx(float(ejects[0][1]), Rules.EJECT_FLIGHT), str(ejects))
	t.check("phase event flow", _phases.size() > 0 and _phases[-1] == boss.CHASE_PHASE and _phases.count(boss.CHASE_PHASE) == 1, str(_phases))

	var mark = _mark(boss)
	t.check("a mark exists at the cue", mark != null)
	var land_at: Vector3 = boss.arena.point_at(boss._eject["angle"], Rules.SCOOTER_RING, 0.7)
	if mark != null:
		t.check("mark is shared Hazard code", mark is Hazard and mark.is_inside_tree(), "%s" % mark.attack_id)
		t.check("mark warns for the flight", is_equal_approx(mark.warn_seconds, Rules.EJECT_FLIGHT), "%s s" % mark.warn_seconds)
		t.check("mark harmless bone style", mark.color == Palette.SAND and not mark.is_hostile(), "hostile=%s" % mark.is_hostile())
		var d: Dictionary = mark.descriptor()
		t.check("mark centre is the landing point", Vector2(mark.centre.x - land_at.x, mark.centre.z - land_at.z).length() < 0.001,
			"%s vs %s" % [mark.centre, land_at])
		t.check("mark radius is the catch circle", is_equal_approx(float(d["r_out"]), Rules.SCOOTER_TOUCH) and float(d["r_in"]) == 0.0,
			"r %s..%s" % [d["r_in"], d["r_out"]])
		# The mark's contains() against the catch rule, probed around the landing point.
		var probes := 0
		var mismatches := 0
		for i in 16:
			var a := TAU * i / 16.0
			for r in [1.0, 3.3, 3.7, 6.0]:
				var p: Vector3 = Vector3(land_at.x + cos(a) * r, land_at.y, land_at.z + sin(a) * r)
				probes += 1
				if mark.contains(p) != (p.distance_to(land_at) <= Rules.SCOOTER_TOUCH):
					mismatches += 1
		t.check("mark contains matches the catch rule", probes == 64 and mismatches == 0, "%d probes, %d mismatches" % [probes, mismatches])

	# Fly the scooter with the ball resting inside the mark.
	Harness.put_ball(game, land_at + Vector3(1.0, 0.3, 0.0))
	var ticks := 0
	var mark_every_tick := true
	var live_at_landing := false
	var warn_ok := true
	while ticks < 400 and not boss.scooter_landed():
		boss.advance(DT)
		ticks += 1
		if not boss.scooter_landed():
			var m = _mark(boss)
			if m == null:
				mark_every_tick = false
			elif m.is_live():
				warn_ok = false
		else:
			var m2 = _mark(boss)
			live_at_landing = m2 != null and m2.is_live()
	t.check("flight ran", ticks > 0, "%d ticks" % ticks)
	t.check("mark there every tick of the flight, never live early", mark_every_tick and warn_ok)
	t.check("mark live on the landing step", live_at_landing)
	t.check("landing step unchanged", ticks == BASE_LAND_TICKS, "landed after %d ticks, base %d" % [ticks, BASE_LAND_TICKS])
	t.check("no damage to the ball inside the mark", _hits.is_empty(), str(_hits))
	t.check("still in the chase", boss.state == boss.EJECT and boss.phase == boss.CHASE_PHASE)
	var after := 0
	while after < 90 and _mark(boss) != null:
		boss.advance(DT)
		after += 1
	t.check("mark clears after going live", after > 0 and _mark(boss) == null and after < 90, "%d ticks live" % after)
	t.check("no hazards listed by the fight for the eject", boss.hazards.is_empty())
	t.check("no damage after landing either", _hits.is_empty(), str(_hits))
	game.free()
	quit(t.verdict())
