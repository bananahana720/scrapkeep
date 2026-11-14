# smoke: solo timeout=180s (wave 37 unit D4: terrain stops lobber shells on world 1; lobbers lead the roll by three quarters)
extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Lobber := preload("res://src/combat/lobber.gd")
const Projectile := preload("res://src/combat/projectile.gd")
const Director := preload("res://src/world/director.gd")
const T := preload("res://tests/support/t.gd")

# Ruling cu, call 2: terrain stops enemy shells, paired with lobbers that lead more of them. On the dam and
# the flume (ChallengeDials hazard.shell_cover_by_stage, mobs.lobber_lead_by_stage, mobs.lobber_share_step_by_stage):
#   - a shell flown over open ground lands and hurts a ball standing in its ring;
#   - the same shot with a wall across the arc bursts on the wall, harmlessly, before its flight is over;
#   - the planted case: that walled shot with the cover dial at zero (the game before this unit) lands and hurts,
#     or the wall check says nothing about the dial;
#   - a ball rolling a straight line at 7 m/s is inside the ring when the shell lands at the shipped 0.75 lead and
#     outside it at the old 0.5 (the planted case); a ball at cruise (14 m/s) is outside either way;
#   - the tells are as long as they were; the lobber share step is a dial that ships at its old value.
# The shell's target is the real player, held still at the ring's centre; the lead passes use a roller on rails.

const GAP := 22.0
const ROLL := 7.0
const CRUISE := 14.0
const COVER_OFF := {"hazard.shell_cover_by_stage": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]}
const LEAD_OLD := {"mobs.lobber_lead_by_stage": [0.5, 0.5, 0.5, 0.5, 0.5, 0.5]}


class Roller:
	var at := Vector3.ZERO
	var v := Vector3.ZERO

	func ball_position() -> Vector3:
		return at

	func planar_velocity() -> Vector3:
		return Vector3(v.x, 0.0, v.z)


var _game
var _t := T.new("lobber_cover_test")
var _wall: StaticBody3D


func _initialize() -> void:
	_run.call_deferred()


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _boot() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "slice"
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.ctx.rng.seed = 11
	_game.player.source = Intent.Scripted.new()
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.run.set_max_hp(99999.0)
	_game.presentation.juice.hit_stop_sink = func(_seconds: float): pass
	await _frames(3)
	for enemy in get_nodes_in_group("enemy"):
		enemy.free()


func _lobber_at(p: Vector3):
	var enemy = _game.combat.spawn_enemy("lobber", p)
	enemy.hp = 100000.0
	return enemy


func _put_wall(at: Vector3) -> void:
	_wall = StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 80.0, 40.0)
	shape.shape = box
	_wall.add_child(shape)
	root.add_child(_wall)
	_wall.global_position = at + Vector3(0.0, 30.0, 0.0)
	await _frames(3)


func _drop_wall() -> void:
	if _wall != null:
		_wall.free()
		_wall = null
	await _frames(2)


# One shot from the lobber to a ring GAP metres east of it, the player held at the ring's centre. Returns
# {"hit", "burst" (exploded with hit false), "ticks" (physics ticks until it burst or landed), "ring_gone",
# "at"}. `wall` stands midway across the arc.
func _shot(overrides: Dictionary, wall: bool) -> Dictionary:
	ChallengeDials.set_overrides(overrides)
	var p: Vector3 = _game.ctx.terrain.drop_point(-100.0, -90.0, 1.6)
	var enemy = _lobber_at(p)
	await _frames(40)
	var land: Vector3 = _game.ctx.terrain.drop_point(p.x + GAP, p.z, 1.05)
	_game.player.reset_to(land)
	_game.player.body().freeze = true
	await _frames(2)
	if wall:
		await _put_wall(p + Vector3(GAP * 0.5, 0.0, 0.0))
	var landing := Vector3(land.x, _game.ctx.terrain.height(land.x, land.z), land.z)
	enemy.fired.emit(enemy.muzzle_point(), landing, Lobber.FLIGHT)
	var shells := get_nodes_in_group("enemy_shot")
	var shell = shells[shells.size() - 1]
	var out := {"hit": false, "burst": false, "ticks": -1, "ring_gone": false, "at": Vector3.ZERO}
	var ring = shell.ring
	var done := [false]
	shell.hit_player.connect(func(_a: float, _s: Vector3): out.hit = true)
	shell.exploded.connect(func(at: Vector3, _r: float, h: bool):
		done[0] = true
		out.at = at
		out.burst = not h)
	var n := 0
	while not done[0] and n < 260:
		await physics_frame
		n += 1
	out.ticks = n
	await _frames(3)
	out.ring_gone = not is_instance_valid(ring)
	ChallengeDials.set_overrides({})
	await _drop_wall()
	enemy.free()
	await _frames(2)
	return out


# A lobber aiming at a roller on rails that rolls a straight line along +z at `speed`. Returns the flat miss in
# metres between the committed landing and the roller where it is when the shell lands, and the lead the lobber
# read.
func _lead_pass(speed: float, overrides: Dictionary) -> Dictionary:
	ChallengeDials.set_overrides(overrides)
	var p: Vector3 = _game.ctx.terrain.drop_point(-100.0, -90.0, 1.6)
	var enemy = _lobber_at(p)
	ChallengeDials.set_overrides({})
	var roller := Roller.new()
	enemy.target = roller
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	roller.at = p + Vector3(GAP, 0.0, -10.0)
	roller.v = Vector3(0.0, 0.0, speed)
	# Park the player far away so the real shell the fired handler makes hurts nothing.
	_game.player.reset_to(_game.ctx.terrain.drop_point(p.x - 60.0, p.z, 1.05))
	_game.player.body().freeze = true
	var landed := [Vector3.INF]
	enemy.fired.connect(func(_o: Vector3, l: Vector3, _f: float): landed[0] = l)
	await _frames(40)
	roller.at = p + Vector3(GAP, 0.0, -10.0)
	enemy._clock = Lobber.CYCLE - 0.02
	var n := 0
	while landed[0] == Vector3.INF and n < 60:
		roller.at += roller.v * dt
		await physics_frame
		n += 1
	var ticks := int(round(Lobber.FLIGHT / dt))
	for i in ticks:
		roller.at += roller.v * dt
		await physics_frame
	var fired: bool = landed[0] != Vector3.INF
	var miss := Vector2(landed[0].x - roller.at.x, landed[0].z - roller.at.z).length() if fired else INF
	var out := {"miss": miss, "fired": fired, "lead": float(enemy.spec.get("lead", -1.0))}
	for shell in get_nodes_in_group("enemy_shot"):
		shell.free()
	enemy.free()
	await _frames(2)
	return out


func _run() -> void:
	ChallengeDials.reset()
	_t.eq("01 terrain stops shells on the dam and the flume only", ChallengeDials.value("hazard.shell_cover_by_stage"), [1.0, 1.0, 0.0, 0.0, 0.0, 0.0])
	_t.eq("02 lobbers lead 0.75 on the dam and the flume", ChallengeDials.value("mobs.lobber_lead_by_stage"), [0.75, 0.75, 0.5, 0.5, 0.5, 0.5])
	_t.eq("03 the lobber share step ships at the old 0.07 on every stage", ChallengeDials.value("mobs.lobber_share_step_by_stage"), [0.07, 0.07, 0.07, 0.07, 0.07, 0.07])
	_t.near("04 stage 3 reads the old lead", ChallengeDials.by_stage_or("mobs.lobber_lead_by_stage", 3, 0.5), Lobber.LEAD)
	_t.near("05 stage 3 reads the old share step", ChallengeDials.by_stage_or("mobs.lobber_share_step_by_stage", 3, 0.0), 0.07)
	_t.near("06 stage 3 has no cover", ChallengeDials.by_stage_or("hazard.shell_cover_by_stage", 3, 1.0), 0.0)
	_t.near("07 the tell is as long as it was", Lobber.TELEGRAPH, 1.3)
	_t.near("08 the flight is as long as it was", Lobber.FLIGHT, 1.9)
	_t.check("09 the tell is at least the tell floor", Lobber.TELEGRAPH >= ChallengeDials.TELL_FLOOR, "TELEGRAPH %.2f s, floor %.2f s" % [Lobber.TELEGRAPH, ChallengeDials.TELL_FLOOR])
	var d1 := Director.new(1)
	d1.dial_stage = 1
	d1.stage_time = 2.0 * Director.TIER_SECONDS + 1.0
	_t.near("10 the dam director at tier 2 shares 0.15 + 2 x 0.07", d1.lobber_share(), 0.15 + 2.0 * 0.07)
	ChallengeDials.set_overrides({"mobs.lobber_share_step_by_stage": [0.12, 0.12, 0.07, 0.07, 0.07, 0.07]})
	_t.near("10b dialled to 0.12 on the dam it shares 0.15 + 2 x 0.12", d1.lobber_share(), 0.15 + 2.0 * 0.12)
	ChallengeDials.set_overrides({})
	var d3 := Director.new(1)
	d3.dial_stage = 3
	d3.stage_time = 2.0 * Director.TIER_SECONDS + 1.0
	_t.near("11 the Dig director at tier 2 shares 0.15 + 2 x 0.07", d3.lobber_share(), 0.15 + 2.0 * 0.07)
	var d0 := Director.new(1)
	d0.stage_time = 2.0 * Director.TIER_SECONDS + 1.0
	_t.near("12 a director with no stage row keeps 0.07", d0.lobber_share(), 0.15 + 2.0 * 0.07)
	await _boot()
	_t.check("13 the run is in a stage on the dam", _game.flow.in_stage() and _game.flow.stage() == 1, "stage %d" % _game.flow.stage())
	var flight_ticks := int(round(Lobber.FLIGHT * float(Engine.physics_ticks_per_second)))

	var open: Dictionary = await _shot({}, false)
	_t.check("14 a shell over open ground lands and hurts a ball in its ring", open.hit and not open.burst, "hit %s, ticks %d" % [open.hit, open.ticks])
	var walled: Dictionary = await _shot({}, true)
	_t.check("15 the walled shot hurts nothing", not walled.hit, "hit %s" % walled.hit)
	_t.check("16 the walled shot bursts on the wall before its flight is over", walled.burst and walled.ticks < flight_ticks - 3,
		"burst %s at tick %d of %d, x %.1f (wall at %.1f)" % [walled.burst, walled.ticks, flight_ticks, walled.at.x, -100.0 + GAP * 0.5])
	_t.check("17 the burst shell's ring is gone", walled.ring_gone)
	# The planted case: cover off is the game before this unit; the same walled shot must land and hurt.
	var planted: Dictionary = await _shot(COVER_OFF, true)
	_t.check("18 planted: with cover off the walled shot flies through and hurts", planted.hit and not planted.burst, "hit %s, burst %s" % [planted.hit, planted.burst])

	var rolled: Dictionary = await _lead_pass(ROLL, {})
	_t.check("19 the lobber on the dam reads the 0.75 lead", is_equal_approx(rolled.lead, 0.75) and rolled.fired, "lead %.2f, fired %s" % [rolled.lead, rolled.fired])
	_t.check("20 a ball rolling a straight line at 7 m/s is inside the ring when the shell lands", rolled.miss < Projectile.BLAST_RADIUS, "miss %.2f m, ring %.1f m" % [rolled.miss, Projectile.BLAST_RADIUS])
	var old_lead: Dictionary = await _lead_pass(ROLL, LEAD_OLD)
	_t.check("21 planted: at the old 0.5 lead the same roll is outside the ring", old_lead.fired and old_lead.miss > Projectile.BLAST_RADIUS, "lead %.2f, miss %.2f m" % [old_lead.lead, old_lead.miss])
	var fast: Dictionary = await _lead_pass(CRUISE, {})
	_t.check("22 a ball at 14 m/s is outside the ring at 0.75: cruise stays free", fast.fired and fast.miss > Projectile.BLAST_RADIUS, "miss %.2f m" % fast.miss)
	ChallengeDials.reset()
	quit(_t.verdict())
