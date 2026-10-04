extends SceneTree

const Game := preload("res://src/game.gd")
const Warden := preload("res://src/combat/warden.gd")
const Roster := preload("res://src/combat/roster.gd")

# A stage row's "warden_variant" reaches the Warden through fleet.dress and changes one
# thing per family: meltdown leaves slag lanes and a longer core window, brood racks a
# lamp_swarm when one is built, choir moves the open lens and braces in a stagger. An
# empty variant changes nothing. Every Warden is built from the spec fleet.dress returns
# for a stage row carrying the variant, so a dress that drops the key fails every
# variant check.


class FlowDouble extends RefCounted:
	var row := {}

	func stage_def() -> Dictionary:
		return row


class CtxDouble extends RefCounted:
	var events
	var flow := FlowDouble.new()


class FleetDouble extends "res://src/combat/fleet.gd":
	var made := {}
	var guard_kinds: Array = []

	func makes(kind: String) -> bool:
		return bool(made[kind]) if made.has(kind) else super.makes(kind)

	func spawn_guard(_home: Vector3, _at: Vector3, kind := "swarm_remnant") -> Object:
		guard_kinds.append(kind)
		return null


var _game
var _failures := 0
var _x := 40.0


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "slice"
	root.add_child(_game)
	_run()


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.flow.press_start()
	_game.flow.choose_class(1)
	await physics_frame
	_game.run.set_max_hp(99999.0)
	_meltdown()
	_brood()
	_choir()
	_defaults()
	_unknown()
	_game.free()
	print("warden_variants_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


func _fleet(variant: String) -> FleetDouble:
	var fleet := FleetDouble.new()
	var ctx := CtxDouble.new()
	ctx.events = _game.events
	ctx.flow.row = {"warden_variant": variant}
	fleet.ctx = ctx
	fleet.combat = _game.ctx.spawner
	return fleet


# A Warden held out of play, set up with the spec the fleet dresses for this row.
func _spawn(family: String, fleet: FleetDouble) -> Node3D:
	var warden := Warden.new()
	_game.add_child(warden)
	warden.position = Vector3(_x, 0.0, 0.0)
	_x += 30.0
	warden.setup(_game.player, _game.ctx.terrain, _game, func(): return false, 1.0,
		fleet.dress("warden", {"family": family, "stage": 1, "fleet": fleet, "plating": 30.0, "hp": 800.0}))
	return warden


func _pulse_once(warden) -> void:
	var guard := 0
	while warden.pulses == 0 and guard < 2000:
		warden._step_pulse(1.0 / 90.0, true)
		guard += 1


func _meltdown() -> void:
	var fleet := _fleet("meltdown")
	var warden := _spawn(Roster.REACTOR, fleet)
	_report("meltdown window", warden.variant == "meltdown" and warden._posture.stagger_seconds == 6.0,
		"variant '%s', stagger_seconds %.1f" % [warden.variant, warden._posture.stagger_seconds])
	_pulse_once(warden)
	var lanes: Array = warden.slag_lanes
	var along := false
	var beside := true
	if lanes.size() == 1:
		var lane: Dictionary = lanes[0]
		var dir: Vector3 = lane["dir"]
		along = warden.in_slag(lane["from"] + dir * 5.0)
		beside = warden.in_slag(lane["from"] + dir.cross(Vector3.UP).normalized() * 20.0)
	_report("meltdown slag after a pulse", warden.pulses == 1 and lanes.size() == 1 and along and not beside,
		"pulses %d, lanes %d, 5 m along %s, 20 m beside %s" % [warden.pulses, lanes.size(), along, beside])
	var laid: int = lanes.size()
	warden._step_slag(Warden.SLAG_SECONDS + 0.1)
	_report("meltdown slag cools", laid == 1 and warden.slag_lanes.is_empty(),
		"lanes %d laid, %d after %.1f s" % [laid, warden.slag_lanes.size(), Warden.SLAG_SECONDS + 0.1])
	warden.free()
	fleet.free()


func _brood() -> void:
	for made in [true, false]:
		var fleet := _fleet("brood")
		fleet.made["lamp_swarm"] = made
		var warden := _spawn(Roster.SWARM, fleet)
		warden._step_guard(0.0)
		var want := "lamp_swarm" if made else "swarm_remnant"
		_report("brood guard, lamp_swarm built %s" % made, warden.variant == "brood" and fleet.guard_kinds == [want],
			"variant '%s', guard kinds %s" % [warden.variant, fleet.guard_kinds])
		warden.free()
		fleet.free()


func _choir() -> void:
	var fleet := _fleet("choir")
	var warden := _spawn(Roster.MIND, fleet)
	var seats: Array = [warden.open_lens]
	var spots: Array = [warden.family_point_at()]
	for i in 3:
		warden._step_choir(Warden.ADAPT_CYCLE)
		seats.append(warden.open_lens)
		spots.append(warden.family_point_at())
	var distinct: bool = spots[0].distance_to(spots[1]) > 0.5 and spots[1].distance_to(spots[2]) > 0.5 \
		and spots[0].distance_to(spots[2]) > 0.5 and spots[0].distance_to(spots[3]) < 0.01
	_report("choir lens turns", warden.variant == "choir" and seats == [0, 1, 2, 0] and distinct and warden.family_point() == "lens",
		"variant '%s', seats %s, distinct %s, point %s" % [warden.variant, seats, distinct, warden.family_point()])
	fleet.habits.add("ram", 3.0)
	warden._posture.staggered = true
	warden._begin_stagger()
	var plating: float = warden.plating
	_report("choir braces in a stagger", warden.plating_for("ram", "body") == plating * 1.6
		and warden.plating_for("stomp", "body") == plating and warden.plating_for("ram", "lens") == 0.0
		and fleet.mind_memory.size() == 1,
		"ram %.1f, stomp %.1f, lens %.1f, plating %.1f, memory %s" % [warden.plating_for("ram", "body"),
			warden.plating_for("stomp", "body"), warden.plating_for("ram", "lens"), plating, fleet.mind_memory])
	warden.free()
	fleet.free()


func _defaults() -> void:
	var fleet := _fleet("")
	var reactor := _spawn(Roster.REACTOR, fleet)
	_pulse_once(reactor)
	_report("default reactor", reactor.pulses == 1 and reactor.slag_lanes.is_empty() and reactor._posture.stagger_seconds == 4.0,
		"pulses %d, lanes %d, stagger_seconds %.1f" % [reactor.pulses, reactor.slag_lanes.size(), reactor._posture.stagger_seconds])
	reactor.free()
	fleet.made["lamp_swarm"] = true
	var swarm := _spawn(Roster.SWARM, fleet)
	swarm._step_guard(0.0)
	_report("default swarm", fleet.guard_kinds == ["swarm_remnant"], "guard kinds %s with lamp_swarm built" % [fleet.guard_kinds])
	swarm.free()
	var mind := _spawn(Roster.MIND, fleet)
	var at: Vector3 = mind.family_point_at()
	mind._step_choir(Warden.ADAPT_CYCLE * 2.0)
	fleet.habits.add("ram", 3.0)
	mind._posture.staggered = true
	mind._begin_stagger()
	_report("default mind", mind.open_lens == 0 and mind.family_point_at() == at and mind.plating_for("ram", "body") == mind.plating
		and fleet.mind_memory.is_empty(),
		"open_lens %d, point moved %s, ram plating %.1f, memory %d" % [mind.open_lens, mind.family_point_at() != at,
			mind.plating_for("ram", "body"), fleet.mind_memory.size()])
	mind.free()
	fleet.free()


func _unknown() -> void:
	var before: int = Warden.warned_variants.size()
	var fleet := _fleet("bogus")
	var first := _spawn(Roster.REACTOR, fleet)
	var second := _spawn(Roster.REACTOR, fleet)
	_report("unknown variant", first.variant == "" and second.variant == "" and Warden.warned_variants.has("bogus")
		and Warden.warned_variants.size() == before + 1,
		"variants '%s' '%s', warned %s" % [first.variant, second.variant, Warden.warned_variants.keys()])
	first.free()
	second.free()
	fleet.free()
