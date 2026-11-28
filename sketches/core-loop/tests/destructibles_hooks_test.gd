extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Augments := preload("res://src/movement/augments.gd")
const Destructibles := preload("res://src/world/destructibles.gd")
const Redline := preload("res://src/combat/redline.gd")
const Rockets := preload("res://src/combat/actives/scrap_rockets.gd")
const Silo := preload("res://src/combat/actives/silo_battery.gd")
const Quake := preload("res://src/combat/actives/quake_knock.gd")
const Palette := preload("res://src/core/palette.gd")
const Telegraph := preload("res://src/combat/telegraph.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const RunState := preload("res://src/core/run_state.gd")
const T := preload("res://tests/support/t.gd")

# Heft destructibles, unit B (design-v3/HEFT-DESTRUCTIBLES.md sections 2.3, 3.2, 4.2; tests T3 and T9). A real Game
# hosts the module through the one small interface (ctx.destructibles, ctx.break_props, player.bind_destructibles):
#   T3  the seven +1 sources (a slam, Redline, a Kest sticky, a Q landing, scrap_rocket, silo_battery, quake_knock)
#       each break a tier 2 piece inside the ring they committed and leave a tier 2 piece outside it and a tier 3
#       piece inside it intact, at class I. A spy on on_blast reads the radius each source passed against the ring
#       the source itself holds; a radius worked out separately must disagree.
#   T9  a harpoon aim, a latched world line and a pylon mount that rested on a piece let go on the tick it breaks;
#       a yawed piece does not take a neighbour's line with it.
#   host  a map with no destructible_rows hosts nothing; a map with rows hosts one module a stage entry, ticks it
#       once a physics tick with the run's heft class and frees it with the stage.
# Evidence limit: rules and state in a headless run, not the look or the sound.

const FLAT_SHELF := Vector3(-45.0, 15.0, 6.0)
const WIDE := 4.0

var _t := T.new("destructibles_hooks_test")
var _game
var _ctx
var _player
var _combat
var _source := Intent.Scripted.new()
var _fixture: Destructibles = null


# The module with every call it is given kept, so a source's radius can be read against its own ring.
class Spy extends Destructibles:
	var blasts: Array[Dictionary] = []
	var balls: Array[Dictionary] = []

	func on_blast(at: Vector3, radius: float, source: String, tier_bonus: int = 1, heft_class: int = -1) -> void:
		blasts.append({"at": at, "radius": radius, "source": source, "bonus": tier_bonus, "heft": heft_class})
		super.on_blast(at, radius, source, tier_bonus, heft_class)

	func on_ball(ball_pos: Vector3, velocity: Vector3, heft_class: int, dt: float = 1.0 / 60.0) -> void:
		balls.append({"at": ball_pos, "heft": heft_class, "dt": dt})
		super.on_ball(ball_pos, velocity, heft_class, dt)


class FakeMap extends RefCounted:
	var park := {}
	var contraptions: Array = []


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run.call_deferred()


func _sim(seconds: float) -> void:
	for i in roundi(seconds * Engine.physics_ticks_per_second):
		await physics_frame


func _ground(dx: float, dz := 0.0, lift := 2.0) -> Vector3:
	return _ctx.terrain.drop_point(FLAT_SHELF.x + dx, FLAT_SHELF.z + dz, lift)


func _row(id: String, tier: int, at: Vector3, size := Vector3(1.0, 2.0, 1.0), yaw := 0.0) -> Dictionary:
	return {"id": id, "tier": tier, "at": [at.x, at.y, at.z], "size": [size.x, size.y, size.z], "yaw_deg": yaw}


# Builds the module over `rows` as the stage's own and binds the ball to it, exactly as world.gd does.
func _host(rows: Array) -> Spy:
	_drop_fixture()
	var spy := Spy.new()
	spy.build({"destructible_rows": rows}, {"ctx": _ctx, "root": _ctx.root, "no_visuals": true})
	spy.finish_build()
	_ctx.destructibles = spy
	_player.bind_destructibles(spy, Callable(_ctx.run, "heft_class"))
	_fixture = spy
	return spy


func _drop_fixture() -> void:
	if _fixture != null and is_instance_valid(_fixture):
		_player.bind_destructibles(null)
		_ctx.destructibles = null
		_fixture.teardown()
		_fixture.queue_free()
	_fixture = null


# Three pieces around a blast at `at` of `radius`: a tier 2 whose box the ring reaches, a tier 2 it does not, and a
# tier 3 it reaches.
func _ring_fixture(at: Vector3, radius: float) -> Spy:
	return _host([
		_row("in2", 2, at + Vector3(radius - 1.5, 0.0, 0.0)),
		_row("out2", 2, at + Vector3(-(radius + 3.0), 0.0, 0.0)),
		_row("in3", 3, at + Vector3(0.0, 0.0, radius - 1.5)),
	])


# Where a ring sits, floor height aside: a telegraph snaps its centre to the ground it stands on.
func _same_spot(a: Vector3, b: Vector3) -> bool:
	return absf(a.x - b.x) < 0.01 and absf(a.z - b.z) < 0.01


func _split(d: Spy) -> bool:
	return d.state_of("in2") == "shattered" and d.state_of("out2") == "intact" and d.state_of("in3") == "intact"


func _states(d: Spy) -> String:
	return "in2 %s, out2 %s, in3 %s" % [d.state_of("in2"), d.state_of("out2"), d.state_of("in3")]


# One source, fired at `at` through `fire`, whose committed ring is `radius`: the +1 bypass, the one call it made,
# and the planted control, the same blast with a radius worked out separately (wider), which must disagree.
func _source_case(label: String, source: String, at: Vector3, radius: float, fire: Callable) -> void:
	var d := _ring_fixture(at, radius)
	fire.call(at)
	_t.check("T3 %s: a class I blast breaks the tier 2 inside its ring and leaves the tier 2 outside and the tier 3 inside" % label,
		_split(d), _states(d))
	var blast: Dictionary = d.blasts.back() if not d.blasts.is_empty() else {}
	_t.check("T3 %s: one call carrying the source's own ring, a +1 bonus and the run's class" % label,
		d.blasts.size() == 1 and blast.get("source") == source and is_equal_approx(float(blast.get("radius", -1.0)), radius)
		and int(blast.get("bonus", 0)) == 1 and int(blast.get("heft", 0)) == _ctx.run.heft_class() and _same_spot(blast.get("at", Vector3.INF), at),
		str(d.blasts))
	var control := _ring_fixture(at, radius)
	_ctx.break_props(at, radius + WIDE, "control")
	_t.check("T3 %s: planted control, a radius computed apart from the source's ring breaks the piece outside it" % label,
		not _split(control), _states(control))


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	_ctx = _game.ctx
	_ctx.calm = true
	_player = _game.player
	_player.source = _source
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_combat = _game.combat
	await _sim(0.4)
	_t.eq("00 the run starts at class I", _ctx.run.heft_class(), 1)
	_t.check("01 no stage rows, no module: the Spillway hosts nothing today", not is_instance_valid(_ctx.destructibles),
		str(_ctx.destructibles))
	_t.check("02 a blast with no module standing is a safe no-op", _noop_without_module())

	await _blast_sources()
	await _grapple()
	_hosting()
	_drop_fixture()
	quit(_t.verdict())


func _noop_without_module() -> bool:
	_ctx.break_props(_ground(0.0), 5.0, "slam")
	_player._on_slammed(_ground(0.0), 30.0, 1.0)
	_player.redline.set_mode(Redline.ON)
	_player.redline._set_value(Redline.MAX)
	_player.redline.spend("slam", _ground(0.0), 10.0)
	_player.redline.set_mode(Redline.OFF)
	return true


# --- T3 -----------------------------------------------------------------------------------------------------

func _blast_sources() -> void:
	var at := _ground(30.0, 20.0)
	var ult = _combat.ultimate
	var rack = _combat.actives

	_source_case("slam", "slam", at, _player.slam_radius(), func(p: Vector3): _player._on_slammed(p, 30.0, 1.0))
	var flat := _ring_fixture(at, _player.slam_radius())
	_player._on_slammed(at, 30.0, 0.0)
	_t.check("T3 slam: a landing under the 0.05 strength floor breaks nothing and asks nothing", flat.intact_count() == 3 and flat.blasts.is_empty(),
		str(flat.blasts))

	_source_case("redline", "redline", at, Redline.BLAST_RADIUS, func(p: Vector3):
		_player.redline.set_mode(Redline.ON)
		_player.redline._set_value(Redline.MAX)
		_player.redline.spend("slam", p, 10.0))
	var cool := _ring_fixture(at, Redline.BLAST_RADIUS)
	_player.redline._set_value(Redline.MAX * 0.5)
	_player.redline.spend("slam", at, 10.0)
	_t.check("T3 redline: a shell short of redline detonates nothing and breaks nothing", cool.intact_count() == 3 and cool.blasts.is_empty())
	_player.redline.set_mode(Redline.OFF)

	_source_case("Kest sticky", "sticky", at, 4.0, func(p: Vector3):
		_combat.detonate({"pos": p, "radius": 4.0, "damage": 10.0, "crit": false}))

	_source_case("Q landing (arc)", "ultimate", at, ult.landing_radius(), func(p: Vector3): ult._sable_landing(p, 1.0, 1.0))
	_source_case("Q landing (line, +3)", "ultimate", at, ult.landing_radius() + 3.0, func(p: Vector3): ult._lightning_landing(p, 1.0, 1.0))
	ult._outpost_second = true
	_source_case("Q landing (second outpost)", "ultimate", at, ult.landing_radius(), func(p: Vector3): ult._outpost_landing(p, 1.0, 1.0))
	ult._outpost_second = false
	ult._plan = {"legs": []}
	_source_case("Q landing (cannon)", "ultimate", at, ult.landing_radius(), func(p: Vector3): ult._cannon_landing(p, 1.0, 1.0))

	_source_case("scrap_rocket", "scrap_rocket", at, Rockets.BLAST_RADIUS, func(p: Vector3):
		rack._kinds["scrap_rocket"]._burst({"pos": p, "damage": 1.0, "vel": Vector3.FORWARD}, null))

	var silo = rack._kinds["silo_battery"]
	_source_case("silo_battery", "silo_battery", at, Silo.RADIUS, func(p: Vector3):
		var ring: Node3D = Telegraph.ring(_ctx.root, _combat.ground, Threat.Type.INSTANT, p, Silo.RADIUS, 3.5, Palette.AMBER)
		silo.rings = [{"ring": ring, "at": ring.center, "shells": 1}]
		silo._land())
	silo.clear()

	var quake = rack._kinds["quake_knock"]
	_source_case("quake_knock", "quake_knock", at, quake.radius_for(0), func(p: Vector3):
		quake._strike(quake._commit(p, quake.radius_for(0)), 1.0))
	_source_case("quake_knock with two overflow pieces", "quake_knock", at, quake.radius_for(2), func(p: Vector3):
		quake._strike(quake._commit(p, quake.radius_for(2)), 1.0))
	quake.clear()

	# One class up the same slam reaches one tier further: the bonus is +1 and never more.
	var tiers := _host([_row("a2", 2, at + Vector3(2.0, 0.0, 0.0)), _row("a3", 3, at + Vector3(0.0, 0.0, 2.0)),
		_row("a4", 4, at + Vector3(-2.0, 0.0, 0.0))])
	_ctx.run.mass = 450.0 * (RunState.HEFT_CLASS_AT[1] - 1.0) + 1.0
	_t.eq("T3 the run now holds class II", _ctx.run.heft_class(), 2)
	_player._on_slammed(at, 30.0, 1.0)
	_t.check("T3 a class II slam breaks tier 3 and stops there: tier 4 is two classes up", tiers.state_of("a2") == "shattered"
		and tiers.state_of("a3") == "shattered" and tiers.state_of("a4") == "intact", "a2 %s a3 %s a4 %s" % [tiers.state_of("a2"), tiers.state_of("a3"), tiers.state_of("a4")])
	_ctx.run.mass = 0.0
	_drop_fixture()
	await physics_frame



# --- T9 -----------------------------------------------------------------------------------------------------

func _pilot() -> void:
	var def: Resource = ClassDef.by_id("pylon_engineer")
	_game.run.class_def = def
	_player.fit_class(def)
	_player.abilities.refill()
	_player.kit.drop_line()
	_player.kit.mounted = false
	_player.kit.aim = Augments.no_aim()
	_source.hold = {}
	_source.press = {}


func _aim_at(point: Vector3) -> Dictionary:
	return {"state": Augments.AIM_REACH, "point": point, "normal": Vector3.UP, "body": null}


# The ring a remote source would commit: wide enough to reach the piece at `at`.
func _blast_on(d: Spy, at: Vector3) -> void:
	d.on_blast(at, 4.0, "scrap_rocket", 1, 2)


func _grapple() -> void:
	_pilot()
	var kit = _player.kit
	var at := _ground(-30.0, -20.0)

	# 1. An aim on a piece that breaks before the press: the press finds nothing and latches nothing.
	var d := _host([_row("slab", 2, at), _row("neighbour", 2, at + Vector3(40.0, 0.0, 0.0))])
	kit.aim = _aim_at(at + Vector3(0.0, 0.0, 0.5))
	_blast_on(d, at)
	_t.eq("T9 the aimed piece is shattered", d.state_of("slab"), "shattered")
	_t.eq("T9 its aim is cleared the same tick", kit.aim.get("state"), Augments.AIM_NONE)
	_player._press_harpoon()
	_t.check("T9 a press on the same tick latches nothing", not kit.hooked)
	kit.aim = _aim_at(at + Vector3(40.0, 0.0, 0.5))
	_blast_on(d, at)
	_t.eq("T9 an aim on a piece that still stands is kept", kit.aim.get("state"), Augments.AIM_REACH)
	kit.aim = Augments.no_aim()
	# planted control: with the ball unbound the stale aim survives, and the press latches onto empty air
	_player.chain.reset()
	d = _host([_row("slab", 2, at)])
	_player.bind_destructibles(null)
	kit.aim = _aim_at(at + Vector3(0.0, 0.0, 0.5))
	_blast_on(d, at)
	_player._press_harpoon()
	_t.check("T9 planted control: left unwired, the press latches the shattered piece's aim, so the test reads it as a failure",
		kit.hooked and d.state_of("slab") == "shattered")
	kit.drop_line()
	kit.aim = Augments.no_aim()

	# 2. A latched world line on an intact piece, shattered from afar.
	_pilot()
	d = _host([_row("pier", 2, at, Vector3(2.0, 3.0, 2.0)), _row("wall", 3, at + Vector3(10.0, 0.0, 0.0))])
	kit.hooked = true
	kit.on_body = false
	kit.anchor = at + Vector3(1.0, 0.5, 0.0)
	_t.eq("T9 the line is latched to the intact piece", [kit.hooked, d.state_of("pier")], [true, "intact"])
	_blast_on(d, at)
	_t.check("T9 the remote shatter cut the world line the same tick, cause shattered",
		d.state_of("pier") == "shattered" and not kit.hooked and kit.line_end == "shattered", "hooked %s end %s" % [kit.hooked, kit.line_end])
	# planted control: unwired, the line stands after the same shatter
	d = _host([_row("pier", 2, at, Vector3(2.0, 3.0, 2.0))])
	_player.bind_destructibles(null)
	kit.hooked = true
	kit.on_body = false
	kit.anchor = at + Vector3(1.0, 0.5, 0.0)
	_blast_on(d, at)
	_t.check("T9 planted control: a world line left hooked after the remote shatter is what the cut test reads as failing",
		d.state_of("pier") == "shattered" and kit.hooked)
	kit.drop_line()
	# a line bitten into a body, and a line on something else, stay
	d = _host([_row("pier", 2, at, Vector3(2.0, 3.0, 2.0))])
	kit.hooked = true
	kit.on_body = true
	kit.anchor = at
	_blast_on(d, at)
	_t.check("T9 a line bitten into a body stays latched when a piece breaks under it", kit.hooked)
	kit.drop_line()
	d = _host([_row("pier", 2, at, Vector3(2.0, 3.0, 2.0)), _row("wall", 3, at + Vector3(10.0, 0.0, 0.0))])
	kit.hooked = true
	kit.on_body = false
	kit.anchor = at + Vector3(10.0, 0.5, 0.0)
	_blast_on(d, at)
	_t.check("T9 a world line on another piece keeps standing", kit.hooked and d.state_of("pier") == "shattered" and d.state_of("wall") == "intact")
	kit.drop_line()

	# 2b. A yawed piece: its world box reaches a neighbour's anchor that its own box does not.
	var yawed := _host([_row("diag", 2, at, Vector3(4.0, 2.0, 1.0), 45.0)])
	kit.hooked = true
	kit.on_body = false
	kit.anchor = at + Vector3(1.5, 0.0, 1.5)
	_t.check("T9 the first anchor sits in the yawed piece's world box and outside the piece",
		yawed.bounds_of("diag").grow(0.25).has_point(kit.anchor) and not yawed.contains_point("diag", kit.anchor, 0.25))
	_blast_on(yawed, at)
	_t.check("T9 a yawed piece shattered beside a line anchored outside it leaves the line hooked", kit.hooked and yawed.state_of("diag") == "shattered")
	kit.drop_line()
	yawed = _host([_row("diag", 2, at, Vector3(4.0, 2.0, 1.0), 45.0)])
	kit.hooked = true
	kit.on_body = false
	kit.anchor = at + Vector3(1.2, 0.0, -1.2)
	_t.check("T9 the second anchor sits inside the yawed piece", yawed.contains_point("diag", kit.anchor, 0.25))
	_blast_on(yawed, at)
	_t.check("T9 a line anchored inside the yawed piece is cut", not kit.hooked)

	# 3. Mounted on a face of a shattered piece.
	_pilot()
	d = _host([_row("tower", 2, at, Vector3(2.0, 4.0, 2.0)), _row("keep", 3, at + Vector3(30.0, 0.0, 0.0), Vector3(2.0, 4.0, 2.0))])
	kit.mounted = true
	kit.mount_face = at + Vector3(1.0, 0.0, 0.0)
	kit.mount_normal = Vector3.RIGHT
	kit.mount_point = kit.mount_face + kit.mount_normal * Augments.MOUNT_OFFSET
	kit.dismount_fired = false
	_blast_on(d, at)
	_t.check("T9 a pylon mounted on a face of a piece that shatters dismounts on the same tick",
		d.state_of("tower") == "shattered" and not kit.mounted and kit.dismount_fired and kit.mount_block > 0.0,
		"mounted %s fired %s" % [kit.mounted, kit.dismount_fired])
	_t.eq("T9 the dismount hands the ball no launch", kit.dismount_velocity, Vector3.ZERO)
	await physics_frame
	_t.check("T9 the dismount is published once and the ball is free", not kit.dismount_fired and not kit.mounted)
	# planted control: unwired, the mount outlives its face
	d = _host([_row("tower", 2, at, Vector3(2.0, 4.0, 2.0))])
	_player.bind_destructibles(null)
	kit.mounted = true
	kit.mount_face = at + Vector3(1.0, 0.0, 0.0)
	_blast_on(d, at)
	_t.check("T9 planted control: a mount left standing on a shattered face is what the dismount test reads as failing",
		kit.mounted and d.state_of("tower") == "shattered")
	kit.mounted = false
	d = _host([_row("tower", 2, at, Vector3(2.0, 4.0, 2.0)), _row("keep", 3, at + Vector3(30.0, 0.0, 0.0), Vector3(2.0, 4.0, 2.0))])
	kit.mounted = true
	kit.mount_face = at + Vector3(30.0, 0.0, 1.0)
	_blast_on(d, at)
	_t.check("T9 a mount on a standing piece is kept when another one shatters", kit.mounted)
	kit.mounted = false

	# With no piece to name, the world box decides.
	var empty := _host([])
	kit.hooked = true
	kit.on_body = false
	kit.anchor = at
	_player._on_piece_shattered(AABB(at - Vector3.ONE, Vector3.ONE * 2.0))
	_t.check("T9 with no piece to name, the world box decides", not kit.hooked and empty.last_shattered_id() == "")
	kit.drop_line()
	_pilot()
	_drop_fixture()
	await physics_frame


# --- hosting ------------------------------------------------------------------------------------------------

func _hosting() -> void:
	var world = _game.world
	_drop_fixture()
	var bare := FakeMap.new()
	world._host_destructibles(bare)
	_t.check("H1 a map with no destructible_rows hosts nothing", not is_instance_valid(_ctx.destructibles))

	var at := _ground(0.0, -30.0)
	var map := FakeMap.new()
	map.park = {"destructible_rows": [_row("crate", 1, at), _row("taken", 2, at + Vector3(10.0, 0.0, 0.0))]}
	map.contraptions = [{"id": "taken"}]
	world._host_destructibles(map)
	var d: Destructibles = _ctx.destructibles
	_t.check("H2 a map with rows hosts one module, joined to the tree, bound to the ball",
		is_instance_valid(d) and d.is_inside_tree() and d.ids() == ["crate"], str(d.ids() if is_instance_valid(d) else null))
	_t.check("H3 the id a contraption owns is refused", is_instance_valid(d) and d.refusals().any(func(r): return r["id"] == "taken"))
	var again := FakeMap.new()
	again.park = {"destructible_rows": [_row("crate", 1, at)]}
	world._host_destructibles(again)
	var second: Destructibles = _ctx.destructibles
	_t.check("H4 a stage entry again (a retry) rebuilds the module and frees the old one", is_instance_valid(second) and second != d
		and second.state_of("crate") == "intact" and (not is_instance_valid(d) or d.is_queued_for_deletion()))

	# The world tick calls on_ball once with the run's class.
	var spy := Spy.new()
	spy.build({"destructible_rows": [_row("crate", 1, at)]}, {"ctx": _ctx, "root": _ctx.root, "no_visuals": true})
	world._release_destructibles()
	_ctx.destructibles = spy
	var before := spy.balls.size()
	world._physics_process(1.0 / 60.0)
	_t.check("H5 the world tick calls on_ball once, with the run's heft class",
		spy.balls.size() == before + 1 and int(spy.balls.back()["heft"]) == _ctx.run.heft_class() if spy.balls.size() > before else false,
		str(spy.balls))
	_ctx.destructibles = null
	spy.teardown()
	spy.queue_free()

	world._host_destructibles(again)
	var held: Destructibles = _ctx.destructibles
	_game.events.stage_content_cleared.emit("test")
	_t.check("H6 a stage clear tears the module down and frees it", _ctx.destructibles == null and (not is_instance_valid(held) or held.is_queued_for_deletion())
		and (not is_instance_valid(held) or held.ids().is_empty()))
