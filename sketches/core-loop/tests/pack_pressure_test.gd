# the world 1 pack pressure experiments: presets, identity defaults, the curved lead, churned silt, silt boils
extends SceneTree

const PackPressure := preload("res://src/combat/pack_pressure.gd")
const ChurnGround := preload("res://src/combat/churn_ground.gd")
const SiltBoil := preload("res://src/combat/silt_boil.gd")
const SpeedTier := preload("res://src/core/speed_tier.gd")
const Director := preload("res://src/world/director.gd")
const Vfx := preload("res://src/presentation/vfx.gd")
const Presentation := preload("res://src/presentation/presentation.gd")
const T := preload("res://tests/support/t.gd")

# src/combat/pack_pressure.gd and its two ground systems. Without --pack-pressure every dial reads its
# identity, so nothing here changes the shipped game; a preset fills only world 1's stages. The curved lead
# must land a ball holding a ring near where it really goes, where a straight-line lead misses by metres.
# The churn and the boils run against a fake context: no game is started.

const CRUISE := 14.0
const RING := 14.0


class FakeState:
	var floor := true

	func on_floor() -> bool:
		return floor


class FakePlayer:
	var at := Vector3.ZERO
	var v := Vector3.ZERO
	var state := FakeState.new()
	var pushed := Vector3.ZERO

	func ball_position() -> Vector3:
		return at

	func planar_velocity() -> Vector3:
		return Vector3(v.x, 0.0, v.z)

	func add_external_accel(accel: Vector3) -> void:
		pushed += accel


class FakeTuning:
	func f(_key: String) -> float:
		return CRUISE


class FakeBeacon extends Node3D:
	var radius := 30.0


class FakeFlow:
	var warden_engaged := false
	var beacon: Node3D = null
	var warden: Node3D = null
	var state := "stage"

	func state_name() -> String:
		return state

	func in_play() -> bool:
		return true

	func engaged() -> bool:
		return warden_engaged

	func in_stage() -> bool:
		return true


class FakeTerrain:
	func height(_x: float, _z: float) -> float:
		return 0.0


# Ground a metre under the ball: a ring's centre snaps to it, the rumble's point does not.
class SunkTerrain:
	func height(_x: float, _z: float) -> float:
		return -1.0


class FakeAudio:
	var stopped: Array = []

	func play(_kind: String, _db := 0.0, _pitch := 1.0, _bus := "SFX", _sound := "") -> bool:
		return true

	func stop(sound: String) -> void:
		stopped.append(sound)


class FakeRun:
	var stage := 1
	var run_seed := 7


class FakeCtx:
	var run := FakeRun.new()
	var flow := FakeFlow.new()
	var player := FakePlayer.new()
	var tuning := FakeTuning.new()
	var terrain := FakeTerrain.new()
	var calm := false
	var root: Node3D


class FakeSite extends Node3D:
	var pack: Array = []
	var minibosses: Array = []
	var brute = null


class FakeActivities:
	var sites: Array = []


class FakeWorld extends Node3D:
	var activities := FakeActivities.new()


class FakeEnemy extends Node3D:
	var kind := "chaser"
	var last_damage_source := ""
	var half_height := 1.5
	var knocked := 0
	var taken := 0.0

	func is_dead() -> bool:
		return false

	func knock(_d: Vector3, _f: float) -> void:
		knocked += 1

	func take_damage(amount: float) -> float:
		taken += amount
		return amount


var _t := T.new("pack_pressure_test")


func _initialize() -> void:
	await process_frame
	ChallengeDials.reset()
	_identity()
	_presets()
	_extras()
	await _lead()
	_churn()
	await _boils()
	ChallengeDials.reset()
	quit(_t.verdict())


func _identity() -> void:
	for key in ["pack.lead_by_stage", "pack.crew_extra_by_stage", "pack.rest_by_stage", "pack.flank_by_stage", "ground.churn_by_stage", "hazard.boil_by_stage"]:
		_t.eq("01 %s is at its default with no flag" % key, ChallengeDials.value(key), ChallengeDials.DEFAULTS[key])
	_t.eq("01b silt boils ship on world 1 at strength 2, nowhere else", ChallengeDials.value("hazard.boil_by_stage"), [2.0, 2.0, 0.0, 0.0, 0.0, 0.0])
	_t.eq("01c W46-S1: the lead ships at 0.7 on stage 1 and half on stages 2 to 6", ChallengeDials.value("pack.lead_by_stage"), [0.7, 0.5, 0.5, 0.5, 0.5, 0.5])
	_t.eq("02 a dam crew reads the 0.7 lead, none of it kept at cruise, and nothing else", PackPressure.crew_row(1), {"lead": 0.7, "lead_cruise": 0.0, "rest": 1.0, "flank": 0.0})
	_t.eq("02b a Dig crew inherits the half lead and cruise fade", PackPressure.crew_row(3), {"lead": 0.5, "lead_cruise": 0.0, "rest": 1.0, "flank": 0.0})
	_t.eq("03 no extra chasers", PackPressure.crew_extra(1), 0)


func _presets() -> void:
	var unknown := []
	var spec := ChallengeDials.pack_pressure_spec("a+d+Q", unknown)
	_t.eq("04 an unknown letter is reported", unknown, ["Q"])
	var parsed := ChallengeDials.parse(spec)
	_t.eq("05 A+D names the lead and churn dials", parsed.keys(), ["pack.lead_by_stage", "ground.churn_by_stage"])
	_t.eq("06 the lead fills world 1 only", parsed["pack.lead_by_stage"], [1.0, 1.0, 0.0, 0.0, 0.0, 0.0])
	ChallengeDials.set_overrides(ChallengeDials.parse(ChallengeDials.pack_pressure_spec("B")))
	_t.eq("07 B adds one chaser on the dam", PackPressure.crew_extra(1), 1)
	_t.eq("08 B adds none in the Dig", PackPressure.crew_extra(3), 0)
	_t.near("09 B halves the re-engage gap on the flume", PackPressure.crew_row(2).rest, 0.5)
	_t.near("10 B leaves the Dig's gap alone", PackPressure.crew_row(3).rest, 1.0)
	ChallengeDials.set_overrides({})


# B's extra chasers join a crew last and only inside the room the caller checked: one with room, none
# without it, none for a lone spawn, and none at all without the dial.
func _extras() -> void:
	var queued := func(room: int, kinds: Array) -> Array:
		var d := Director.new(71)
		d.set_run_tier_reader(func(): return 0)
		d.dial_stage = 1
		var n := d._place_pack(Vector2(40.0, 0.0), kinds, Vector2.ZERO, false, room)
		return [n, d.extras_placed]
	_t.eq("27 no dial: the crew as authored", queued.call(5, ["chaser", "lobber"]), [2, 0])
	ChallengeDials.set_overrides(ChallengeDials.parse(ChallengeDials.pack_pressure_spec("B")))
	_t.eq("28 B with room: one more chaser", queued.call(5, ["chaser", "lobber"]), [3, 1])
	_t.eq("29 B with no spare room: none", queued.call(2, ["chaser", "lobber"]), [2, 0])
	_t.eq("30 B never pads a lone spawn", queued.call(5, ["chaser"]), [1, 0])
	ChallengeDials.set_overrides({})


# A ball on a 14 m ring at cruise, sampled each physics tick: the lead 1 s ahead lands within a metre of the
# ring's true point; the straight-line lead is more than 5 m off.
func _lead() -> void:
	var player := FakePlayer.new()
	var w := CRUISE / RING
	var angle := 0.0
	for i in 150:
		await physics_frame
		angle += w / float(Engine.physics_ticks_per_second)
		player.at = Vector3(cos(angle), 0.0, sin(angle)) * RING
		player.v = Vector3(-sin(angle), 0.0, cos(angle)) * CRUISE
		PackPressure.observe(player.planar_velocity())
	var truth := Vector3(cos(angle + w), 0.0, sin(angle + w)) * RING
	var led := PackPressure.predict(player, 1.0)
	_t.near("11 the turn rate read is the ring's", PackPressure.turn_rate(), w, 0.05)
	_t.check("12 the curved lead lands within 1 m", led.distance_to(truth) < 1.0, "%.2f m" % led.distance_to(truth))
	_t.check("13 a straight lead would miss by over 5 m", (player.at + player.v).distance_to(truth) > 5.0)


func _churn() -> void:
	var ctx := FakeCtx.new()
	ctx.root = Node3D.new()
	root.add_child(ctx.root)
	var churn := ChurnGround.new()
	churn.setup(ctx)
	var dt := 1.0 / 90.0
	ctx.player.v = Vector3(10.0, 0.0, 0.0)
	churn.step(dt)
	_t.eq("14 off with no dial: nothing churns", churn.churned_cells, 0)
	ChallengeDials.set_overrides(ChallengeDials.parse(ChallengeDials.pack_pressure_spec("D")))
	var a := Vector3(1.0, 0.0, 1.0)
	var b := Vector3(20.0, 0.0, 1.0)
	for pass_i in 2:
		ctx.player.at = a
		for i in 10:
			churn.step(dt)
		ctx.player.at = b
		for i in 180:
			churn.step(dt)
	ctx.player.at = a
	ctx.player.pushed = Vector3.ZERO
	churn.step(dt)
	_t.eq("15 the third pass over a cell is churned twice", churn.level_at(a), 2)
	_t.check("16 a cruise ball is dragged back", ctx.player.pushed.x < 0.0)
	ctx.player.pushed = Vector3.ZERO
	ctx.player.v = Vector3(CRUISE * SpeedTier.MULTIPLES[SpeedTier.FAST] + 0.5, 0.0, 0.0)
	churn.step(dt)
	_t.eq("17 a FAST ball skims churned silt", ctx.player.pushed, Vector3.ZERO)
	_t.eq("18 fresh ground is not churned", churn.level_at(Vector3(60.0, 0.0, 60.0)), 0)
	ChallengeDials.set_overrides({})
	ctx.root.queue_free()


# A ball looping a 14 m ring with a crew 10 m off: a ring is committed once the loop is read, it erupts
# after its warning, and it hits a ball (and tosses a crew) inside it.
func _boils() -> void:
	var ctx := FakeCtx.new()
	ctx.root = Node3D.new()
	root.add_child(ctx.root)
	var enemy := FakeEnemy.new()
	ctx.root.add_child(enemy)
	enemy.global_position = Vector3(0.0, 1.5, 0.0)
	var boils := SiltBoil.new()
	boils.setup(ctx, ctx.terrain)
	boils.reset(true)
	var dealt := []
	boils.deal = func(amount: float, _shove: Vector3): dealt.append(amount)
	var dt := 1.0 / 90.0
	ChallengeDials.set_overrides(ChallengeDials.parse("hazard.boil_by_stage=0/0/0/0/0/0"))
	boils.step(dt, [enemy])
	_t.eq("19 off with the dial at 0: no boil", boils.boils, 0)
	ChallengeDials.set_overrides(ChallengeDials.parse(ChallengeDials.pack_pressure_spec("E")))
	var w := CRUISE / RING
	var angle := 0.0
	var steps := 0
	while boils.boils == 0 and steps < 90 * 20:
		angle += w * dt
		ctx.player.at = Vector3(cos(angle), 0.0, sin(angle)) * RING
		ctx.player.v = Vector3(-sin(angle), 0.0, cos(angle)) * CRUISE
		boils.step(dt, [enemy])
		steps += 1
	_t.eq("20 a loop in a fight raises a boil", boils.boils, 1)
	_t.check("21 not before the loop window", steps * dt >= SiltBoil.LOOP_WINDOW - 0.5, "%.1f s" % (steps * dt))
	_t.check("21b the ring warns at least the tell floor", SiltBoil.WARN >= ChallengeDials.TELL_FLOOR)
	ctx.player.at = boils._ring.center
	enemy.global_position = boils._ring.center + Vector3(1.0, 1.5, 0.0)
	for i in int(ChallengeDials.TELL_FLOOR * 90.0):
		boils.step(dt, [enemy])
	_t.eq("21c nothing erupts inside the tell floor", boils.ball_hits, 0)
	for i in int((SiltBoil.WARN - ChallengeDials.TELL_FLOOR) * 90.0) + 2:
		boils.step(dt, [enemy])
	_t.eq("22 the eruption hits the ball inside", boils.ball_hits, 1)
	_t.eq("23 it deals the boil's damage times the strength", dealt, [SiltBoil.DAMAGE * 2.0])
	_t.eq("24 it tosses the crew inside", enemy.knocked, 1)
	_t.eq("25 a crew it kills is the silt's", enemy.get("last_damage_source"), "silt_boil")
	boils.reset(true)
	_t.eq("26 a stage entry clears the counts and any ring", [boils.boils, boils._ring], [0, null])
	var beacon := FakeBeacon.new()
	var warden := Node3D.new()
	ctx.root.add_child(beacon)
	ctx.root.add_child(warden)
	ctx.flow.beacon = beacon
	ctx.flow.warden = warden
	_t.eq("26b a loop inside an engaged Warden's ring never boils", _loop_boils(boils, ctx, enemy, func(): ctx.flow.warden_engaged = true), 0)
	beacon.position = Vector3(200.0, 0.0, 0.0)
	_t.eq("26e kiting a roaming pack away from the engaged Warden still boils", _loop_boils(boils, ctx, enemy, func(): pass), 1)
	ctx.flow.warden_engaged = false
	var world := FakeWorld.new()
	world.name = "World"
	ctx.root.add_child(world)
	var site := FakeSite.new()
	ctx.root.add_child(site)
	site.pack = [enemy]
	world.activities.sites = [site]
	_t.eq("26c an activity's own crew on its site is not a fight to boil", _loop_boils(boils, ctx, enemy, func(): pass), 0)
	site.position = Vector3(0.0, 0.0, 150.0)
	_t.eq("26f a crew dragged off its site is", _loop_boils(boils, ctx, enemy, func(): pass), 1)
	world.activities.sites = []
	_t.eq("26d a roaming pack still is", _loop_boils(boils, ctx, enemy, func(): pass), 1)
	_t.eq("26g the exit run (gates, launch) never boils", _loop_boils(boils, ctx, enemy, func(): ctx.flow.state = "gates"), 0)
	ctx.flow.state = "stage"
	_t.eq("26n a calm context never boils", _loop_boils(boils, ctx, enemy, func(): ctx.calm = true), 0)
	ctx.calm = false
	_stall(boils, ctx, enemy)
	_quelled(boils, ctx, enemy, dealt, beacon)
	ChallengeDials.set_overrides({})
	ctx.root.queue_free()
	await process_frame


# Loops the ball on a 14 m ring around `enemy` for up to 20 s after `arrange`, from a fresh stage entry;
# the boils raised.
func _loop_boils(boils, ctx, enemy, arrange: Callable) -> int:
	boils.reset(true)
	enemy.global_position = Vector3(0.0, 1.5, 0.0)
	arrange.call()
	var dt := 1.0 / 90.0
	var w := CRUISE / RING
	var angle := 0.0
	for i in 90 * 20:
		angle += w * dt
		ctx.player.at = Vector3(cos(angle), 0.0, sin(angle)) * RING
		ctx.player.v = Vector3(-sin(angle), 0.0, cos(angle)) * CRUISE
		boils.step(dt, [enemy])
		if boils.boils > 0:
			break
	return boils.boils


# Wave 37 unit D5 (ruling cu call 3): the boils punish the stall, not the wide kite. Each path runs for 20 s
# against a roaming pack that stays in reach; the planted cases run the same paths with the stall dial off,
# the loop test the boils shipped with, and must read the other way, or the checks say nothing about the rule.
const WIDE := 24.0
const LOOP_TEST := {"hazard.boil_stall_by_stage": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0], "hazard.boil_by_stage": [2.0, 2.0, 0.0, 0.0, 0.0, 0.0]}


func _stall(boils, ctx, enemy) -> void:
	_t.eq("31 the stall test ships across all stages", ChallengeDials.DEFAULTS["hazard.boil_stall_by_stage"], [1.0, 1.0, 1.0, 1.0, 1.0, 1.0])
	var stall_on: Dictionary = ChallengeDials.parse(ChallengeDials.pack_pressure_spec("E"))
	stall_on["hazard.boil_stall_by_stage"] = [1.0, 1.0, 0.0, 0.0, 0.0, 0.0]
	ChallengeDials.set_overrides(stall_on)
	_t.check("31b a tight orbit ring is inside the stall reach, a wide kite ring outside", RING + 3.0 < SiltBoil.STALL_SPREAD and WIDE > SiltBoil.STALL_SPREAD,
		"orbit %.0f m (+3 m band), reach %.0f m, kite %.0f m" % [RING, SiltBoil.STALL_SPREAD, WIDE])
	var parked := func(_t_s: float) -> Array: return [Vector3(8.0, 0.0, 0.0), Vector3.ZERO]
	var crawl := func(t_s: float) -> Array: return [Vector3(-10.0 + 2.0 * t_s, 0.0, 6.0), Vector3(2.0, 0.0, 0.0)]
	var kite := func(t_s: float) -> Array:
		var a := CRUISE / WIDE * t_s
		return [Vector3(cos(a), 0.0, sin(a)) * WIDE, Vector3(-sin(a), 0.0, cos(a)) * CRUISE]
	var orbit := func(t_s: float) -> Array:
		var a := CRUISE / RING * t_s
		return [Vector3(cos(a), 0.0, sin(a)) * RING, Vector3(-sin(a), 0.0, cos(a)) * CRUISE]
	var run := func(t_s: float) -> Array: return [Vector3(CRUISE * t_s, 0.0, 0.0), Vector3(CRUISE, 0.0, 0.0)]
	_t.eq("32 a ball that stops in a fight boils", _path_boils(boils, ctx, enemy, parked, false), 1)
	_t.eq("33 a ball that crawls through a fight boils", _path_boils(boils, ctx, enemy, crawl, false), 1)
	_t.eq("34 a tight orbit at cruise still boils", _path_boils(boils, ctx, enemy, orbit, false), 1)
	_t.eq("35 a wide kite round the pack at cruise never boils", _path_boils(boils, ctx, enemy, kite, false), 0)
	_t.eq("36 a straight run at cruise with the pack on its tail never boils", _path_boils(boils, ctx, enemy, run, true), 0)
	ChallengeDials.set_overrides(LOOP_TEST)
	_t.eq("37 planted: the loop test never boiled a ball that stopped", _path_boils(boils, ctx, enemy, parked, false), 0)
	_t.eq("38 planted: nor one that crawled", _path_boils(boils, ctx, enemy, crawl, false), 0)
	_t.eq("39 planted: and it boiled the wide kite", _path_boils(boils, ctx, enemy, kite, false), 1)
	ChallengeDials.set_overrides(ChallengeDials.parse(ChallengeDials.pack_pressure_spec("E")))


# Moves the ball along `path` (seconds to [position, velocity]) for up to 20 s from a fresh stage entry; the
# boils raised. With `tail` the pack keeps 10 m behind the ball, else it stands at the origin.
func _path_boils(boils, ctx, enemy, path: Callable, tail: bool) -> int:
	boils.reset(true)
	enemy.global_position = Vector3(0.0, 1.5, 0.0)
	var dt := 1.0 / 90.0
	for i in 90 * 20:
		var row: Array = path.call(i * dt)
		ctx.player.at = row[0]
		ctx.player.v = row[1]
		if tail:
			enemy.global_position = row[0] - Vector3(10.0, -1.5, 0.0)
		boils.step(dt, [enemy])
		if boils.boils > 0:
			break
	return boils.boils


# A ring already rumbling when an exemption turns true never erupts: the Warden breaks (the exit run starts)
# or the ball rolls into an engaged Warden's ring inside the warning. The ball sits on the ring's centre, so
# an eruption would hit it; the ring, its marker and its rumble are quelled instead.
func _quelled(boils, ctx, enemy, dealt: Array, beacon: Node3D) -> void:
	var heard := []
	boils.quelled.connect(func(at: Vector3): heard.append(at))
	boils.setup(ctx, SunkTerrain.new())
	var cues := _cue_view(ctx)
	var shown: Node = cues.presentation
	boils.rumbled.connect(shown._on_boil_rumbled)
	boils.quelled.connect(shown._on_boil_quelled)
	var exemptions := [
		["26h a rumbling ring quells when the Warden breaks (gates)", func(): ctx.flow.state = "gates"],
		["26i a rumbling ring quells when the launch run starts", func(): ctx.flow.state = "launch"],
		["26j a rumbling ring quells when the ball enters an engaged Warden's ring", _enter_warden_ring.bind(ctx, beacon)],
		["26o a rumbling ring quells when calm turns on", func(): ctx.calm = true],
	]
	var dt := 1.0 / 90.0
	for row in exemptions:
		var label: String = row[0]
		beacon.position = Vector3(200.0, 0.0, 0.0)
		ctx.flow.warden_engaged = false
		ctx.flow.state = "stage"
		ctx.calm = false
		_t.eq(label + ": armed", _loop_boils(boils, ctx, enemy, func(): pass), 1)
		var ring = boils._ring
		var center: Vector3 = ring.center
		ctx.player.at = center
		enemy.global_position = center + Vector3(1.0, 1.5, 0.0)
		dealt.clear()
		enemy.knocked = 0
		heard.clear()
		cues.audio.stopped.clear()
		var chevron: Dictionary = shown._boil_marker
		_t.check(label + ": the chevron is up", not chevron.is_empty() and chevron["t"] < 1.0 and chevron["node"].visible)
		for i in int(SiltBoil.WARN * 0.5 * 90.0):
			boils.step(dt, [enemy])
		row[1].call()
		for i in int(SiltBoil.WARN * 90.0) + 10:
			boils.step(dt, [enemy])
		_t.eq(label + ": no eruption, no damage, no toss", [boils.ball_hits, dealt, enemy.knocked], [0, [], 0])
		_t.eq(label + ": the ring and its cue go", [boils._ring, boils.quells, heard], [null, 1, [center]])
		_t.check(label + ": the ring node is freed", ring.is_queued_for_deletion())
		_t.check(label + ": the chevron ends with it", chevron["t"] >= 1.0 and not chevron["node"].visible)
		_t.eq(label + ": the rumble is cut", cues.audio.stopped, ["boil_rumble"])
		_t.check(label + ": no loop is read while exempt", boils._samples.is_empty())
	beacon.position = Vector3(200.0, 0.0, 0.0)
	ctx.flow.warden_engaged = false
	ctx.flow.state = "stage"
	ctx.calm = false
	_t.eq("26k with no exemption the same ring still erupts", _loop_boils(boils, ctx, enemy, func(): pass), 1)
	ctx.player.at = boils._ring.center
	for i in int(SiltBoil.WARN * 90.0) + 2:
		boils.step(dt, [enemy])
	_t.eq("26l and hits the ball", [boils.ball_hits, boils.quells], [1, 0])
	_t.eq("26m leaving a long exemption mid-loop needs a fresh loop read", _after_exemption(boils, ctx, enemy), [0, 1])
	boils.setup(ctx, ctx.terrain)
	cues.presentation.free()
	cues.vfx.free()


# Loops 20 s exempt (the engaged Warden's ring around the loop), then the Warden's ring moves off: the
# boils raised in the first REST + 1 s after (none, the loop window has not refilled) and by the end of a
# full loop window (one).
func _after_exemption(boils, ctx, enemy) -> Array:
	var beacon: Node3D = ctx.flow.beacon
	boils.reset(true)
	enemy.global_position = Vector3(0.0, 1.5, 0.0)
	beacon.position = Vector3.ZERO
	ctx.flow.warden_engaged = true
	var dt := 1.0 / 90.0
	var w := CRUISE / RING
	var angle := 0.0
	var raised := []
	for i in 90 * 20:
		angle += w * dt
		ctx.player.at = Vector3(cos(angle), 0.0, sin(angle)) * RING
		ctx.player.v = Vector3(-sin(angle), 0.0, cos(angle)) * CRUISE
		boils.step(dt, [enemy])
	beacon.position = Vector3(200.0, 0.0, 0.0)
	for i in int(90 * (SiltBoil.LOOP_WINDOW + 2.0)):
		angle += w * dt
		ctx.player.at = Vector3(cos(angle), 0.0, sin(angle)) * RING
		ctx.player.v = Vector3(-sin(angle), 0.0, cos(angle)) * CRUISE
		boils.step(dt, [enemy])
		if i == int(90 * (SiltBoil.REST + 1.0)):
			raised.append(boils.boils)
		if boils.boils > 0:
			break
	raised.append(boils.boils)
	ctx.flow.warden_engaged = false
	return raised


# The live cue path for a boil: presentation's rumble and quell handlers over a real Vfx glyph pool.
func _cue_view(ctx) -> Dictionary:
	var vfx := Vfx.new()
	vfx.root = Node3D.new()
	ctx.root.add_child(vfx.root)
	vfx._meshes = {"flash": SphereMesh.new()}
	for i in 4:
		var node := MeshInstance3D.new()
		node.visible = false
		vfx.root.add_child(node)
		vfx._glyphs.append({"node": node, "mat": StandardMaterial3D.new(), "t": 1.0, "life": 1.0, "from": 1.0, "to": 1.0, "color": Color.WHITE})
	var shown = Presentation.new()
	shown.vfx = vfx
	shown.audio = FakeAudio.new()
	return {"presentation": shown, "vfx": vfx, "audio": shown.audio}


func _enter_warden_ring(ctx, beacon: Node3D) -> void:
	beacon.position = Vector3(ctx.player.at.x, 0.0, ctx.player.at.z)
	ctx.flow.warden_engaged = true
