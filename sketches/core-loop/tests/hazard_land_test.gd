extends SceneTree

const Game := preload("res://src/game.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")
const Hazard := preload("res://src/boss/hazard.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const Warden := preload("res://src/combat/warden.gd")
const Roster := preload("res://src/combat/roster.gd")
const WarningBound := preload("res://src/combat/warning_bound.gd")
const T := preload("res://tests/support/t.gd")

# FX-27: a boss or Warden ground hazard lands like a crew mark. On the step Brindle's slag ring
# or charge lane goes live, one Threat.Flash (the FX-05 crack ring and dust kick) appears under
# the arena, drawn over the hazard's committed footprint; a crane sweep leaves none. The Warden's
# slag lane and core ring each leave one landing at their strike and the body wears the release
# flash (strike_flashing). Evidence limit: node counts, bounds and material state in a headless
# run, not a rendered still.

const DT := 1.0 / 90.0

class WardenFlow extends RefCounted:
	var row := {"warden_variant": "meltdown"}

	func stage_def() -> Dictionary:
		return row


class WardenCtx extends RefCounted:
	var events
	var flow := WardenFlow.new()


var game
var t := T.new("hazard_land_test")
var _flashes: Array = []


func _initialize() -> void:
	game = Game.new()
	game.test_mode = true
	root.add_child(game)
	_run.call_deferred()


func _run() -> void:
	while game.flow == null:
		await physics_frame
	Harness.install(game)
	Harness.start_run(game)
	_warden()
	Harness.enter(game, Vector3(18.0, 0.0, 0.0))
	_brindle()
	game.free()
	quit(t.verdict())


# The landing's footprint must cover the hazard's committed area: the flash's own marks span
# at least the reach the descriptor names, and lie over its centre.
func _covers(flash: Node, d: Dictionary) -> bool:
	var box: AABB = WarningBound.mesh_box(flash)
	if box.size == Vector3.ZERO:
		return false
	var c: Vector3 = d["centre"]
	var half: float = d["r_out"] if d["form"] == "radial" else float(d["length"]) * 0.5
	var probe := c if d["form"] == "radial" else c + (d["dir"] as Vector3) * half
	return box.position.x <= probe.x and box.end.x >= probe.x and box.position.z <= probe.z and box.end.z >= probe.z \
		and maxf(box.size.x, box.size.z) >= half * 0.8


func _brindle() -> void:
	var boss = game.boss
	var arena = boss.arena
	arena.child_entered_tree.connect(func(n: Node):
		if n is Threat.Flash:
			_flashes.append([n, boss.clock]))
	var seen := {}
	var rings := 0
	var lanes := 0
	var bad_place := 0
	var wrong_count := 0
	var waves_with_flash := 0
	for phase in 3:
		if phase > 0:
			boss.jump_to_phase(phase + 1)
		var until: float = boss.clock + 30.0
		while boss.clock < until:
			boss.advance(DT)
			game.run.heal(1000.0)
			if game.run.mass < 200.0:
				game.run.add_scrap(300, Vector3.ZERO)
			for h in boss.active_hazards():
				if not h.is_live() or seen.has(h.get_instance_id()):
					continue
				seen[h.get_instance_id()] = true
				# advance() already ran the live step: the landing is the newest flash this tick.
				var mine := _flashes.filter(func(f): return is_equal_approx(float(f[1]), boss.clock) or float(f[1]) >= boss.clock - DT * 1.5)
				if h.type == Threat.Type.WAVE:
					waves_with_flash += mine.size()
					continue
				if h.is_hostile():
					if mine.size() != 1:
						wrong_count += 1
					elif not _covers(mine[0][0], h.descriptor()):
						bad_place += 1
					if h.shape == Hazard.Shape.ANNULUS:
						rings += 1
					elif h.shape == Hazard.Shape.LANE:
						lanes += 1
	t.check("brindle slag rings landed", rings >= 2, "%d rings went live" % rings)
	t.check("brindle charge lanes landed", lanes >= 2, "%d lanes went live" % lanes)
	t.check("brindle one landing per strike", wrong_count == 0, "%d strikes with other than one landing" % wrong_count)
	t.check("brindle landing at the committed place", bad_place == 0, "%d landings off the descriptor's footprint" % bad_place)
	t.check("brindle crane sweep leaves none", waves_with_flash == 0, "%d landings under a sweep" % waves_with_flash)


func _warden() -> void:
	var fleet := preload("res://src/combat/fleet.gd").new()
	var ctx := WardenCtx.new()
	ctx.events = game.events
	fleet.ctx = ctx
	fleet.combat = game.ctx.spawner
	var warden := Warden.new()
	game.add_child(warden)
	warden.position = Vector3(40.0, 0.0, 0.0)
	warden.setup(game.player, game.ctx.terrain, game, func(): return false, 1.0,
		fleet.dress("warden", {"family": Roster.REACTOR, "stage": 1, "fleet": fleet, "plating": 30.0, "hp": 800.0}))
	var landings: Array = []
	warden.world_root.child_entered_tree.connect(func(n: Node):
		if n is Threat.Flash:
			landings.append(n))
	var guard := 0
	var at_pulse := -1
	var seen_before := 0
	while warden.pulses == 0 and guard < 2000:
		seen_before = landings.size()
		warden._step_pulse(DT, true)
		guard += 1
	at_pulse = landings.size() - seen_before
	t.check("warden core ring lands once at the pulse", at_pulse == 1, "%d landings on the pulse tick" % at_pulse)
	warden._update_flash(DT)
	t.check("warden body flashes at the pulse", warden.strike_flashing(), "strike_flashing after the pulse")
	t.check("warden slag lane laid without landing", warden.slag_lanes.size() == 1 and landings.size() == 1, "%d lanes, %d landings so far" % [warden.slag_lanes.size(), landings.size()])
	var node = warden.slag_lanes[0]["node"]
	var d: Dictionary = node.descriptor()
	for i in 4:
		warden._update_flash(DT)
	var before := landings.size()
	var t_run := 0.0
	while t_run < Warden.SLAG_WARN + 0.5 and not warden.slag_lanes.is_empty() and warden.slag_lanes[0]["phase"] != Warden.PHASE_STRIKE:
		warden._step_slag(DT)
		t_run += DT
	t.check("warden slag lane lands once at its strike", landings.size() == before + 1, "%d landings at the strike" % (landings.size() - before))
	t.check("warden slag landing over the lane", landings.size() > before and _covers(landings[-1], d), "flash bounds cover the lane's committed footprint")
	warden._update_flash(DT)
	t.check("warden body flashes at the lane strike", warden.strike_flashing(), "strike_flashing after the strike")
	warden.free()
	fleet.free()
