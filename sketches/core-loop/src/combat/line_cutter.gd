extends "res://src/combat/counter.gd"

const RosterHighdraft := preload("res://src/combat/roster_highdraft.gd")
const IslandEdge := preload("res://src/combat/island_edge.gd")
const SpeedTier := preload("res://src/movement/speed_tier.gd")

const FLIGHT := 1.1
const RING_RADIUS := 2.6
const RING_REACH := 40.0
const GAP_HEIGHT := 5.0
const REBITE_WINDOW := 0.5
const REBITE_KICK := 4.0
const LANDING_DAMAGE := 8.0
const HEIGHT := 2.2
const STING := 4.0
const HP := 38.0
const SPIN_RATE := 0.9
const PRIMARY_WARN := 0.75
const PRIMARY_LIVE := FLIGHT + 0.2
const BOOMERANG_WARN := 0.85
const BOOMERANG_OUT := 0.65
const BOOMERANG_RETURN := 0.65
const BOOMERANG_LENGTH := 22.0
const BOOMERANG_WIDTH := 3.0
const BAT_DISC_RADIUS := 3.2
const BOOMERANG_RINGOUT_KNOCK := 34.0
const RIM_SEARCH := 28.0
const RIM_DROP := 4.0

var throws := 0
var cuts := 0
var dodged := 0
var grazed := 0
var rebites := 0
var landing_hits := 0
var boomerangs := 0
var boomerangs_batted := 0
var returning_disc := false
var next_attack := ""
var last_bat := {}
var aim := "line"

var _disc: MeshInstance3D
var _launch := Vector3.ZERO
var _target := Vector3.ZERO
var _bump := 0.0
var _landed := false
var _boomerang := false
var _boom_dir := Vector3.FORWARD
var _boom_apex := Vector3.ZERO
var _boom_cut_done := false
var _boom_batted := false
var _body: MeshInstance3D
var _throw_arm: MeshInstance3D
static var _shared: Array = []


func _configure(threat: float) -> void:
	_set_health(HP * threat)
	scrap_value = 4
	weight = 1.0
	warn_seconds = PRIMARY_WARN
	live_seconds = PRIMARY_LIVE
	rest_seconds = 3.0
	attack_range = 28.0
	keep_near = 12.0


func _build_tool() -> void:
	var parts := _parts()
	if not parts.is_empty():
		_crew.free()
		_crew = null
		_base_color = Color.WHITE
		_material.albedo_color = _base_color
		_material.vertex_color_use_as_albedo = true
		for part in parts:
			var mi := MeshInstance3D.new()
			mi.name = part.name
			mi.mesh = part.mesh
			mi.transform = part.xform
			if part.flash >= 0:
				mi.set_surface_override_material(part.flash, _material)
			_visual_parent().add_child(mi)
			match part.name:
				"CutterCrewBody": _body = mi
				"ThrowArm": _throw_arm = mi
				"CutterDisc": _disc = mi
		return
	_disc = _cylinder(0.7, 0.08, Palette.HAZARD, Vector3(0.0, CREW_HALF + 1.0, 0.0), 0.6, _visual_parent())


static func _parts() -> Array:
	if _shared.is_empty():
		_shared = EnemyCasting.parts("res://assets/models/world_three/enemy_line_cutter.glb", "line_cutter")
	return _shared


func _pose() -> void:
	if _body == null or _throw_arm == null:
		return
	var cock := clampf(_t / warn_seconds, 0.0, 1.0) if phase == Phase.WARN else 0.0
	_body.rotation.x = 0.08 * cock
	_throw_arm.position = _body.basis * Vector3(-0.48, 0.7, 0.0)
	_throw_arm.rotation.x = -0.52 * cock
	if phase == Phase.WARN and not _disc.top_level:
		_disc.position = _throw_arm.transform * Vector3(0.48, 1.4, 0.0)


func _wants_attack(to_ball: Vector3) -> bool:
	var player = _player()
	if player == null or not super(to_ball):
		return false
	if next_attack == "boomerang":
		return true
	return player.kit.hooked or not player.state.on_floor() or (throws > boomerangs and player.speed_tier() < SpeedTier.CRUISE)


func _use_boomerang() -> bool:
	if next_attack == "boomerang":
		return true
	if next_attack == "line":
		return false
	return throws > boomerangs and not RosterHighdraft.grown(self)


func _commit(to_ball: Vector3) -> Node3D:
	var is_boom := _use_boomerang()
	_boomerang = is_boom
	next_attack = ""
	if is_boom:
		aim = "boomerang"
		warn_seconds = BOOMERANG_WARN
		live_seconds = BOOMERANG_OUT + BOOMERANG_RETURN + 0.15
		var flat := Vector3(to_ball.x, 0.0, to_ball.z)
		_boom_dir = flat.normalized() if flat.length() > 0.1 else Vector3.FORWARD
		_facing(_boom_dir)
		_launch = global_position + Vector3.UP * HEIGHT
		_boom_apex = _launch + _boom_dir * BOOMERANG_LENGTH
		_boom_cut_done = false
		_boom_batted = false
		returning_disc = false
		return _commit_lane(Threat.Type.LANE, global_position, _boom_dir, BOOMERANG_LENGTH, BOOMERANG_WIDTH, RING_REACH)
	warn_seconds = PRIMARY_WARN
	live_seconds = PRIMARY_LIVE
	var landing: Vector3 = _ball() + target.planar_velocity() * (FLIGHT + warn_seconds)
	aim = "landing" if RosterHighdraft.grown(self) and throws % 2 == 1 else "line"
	_target = landing
	if aim == "landing" and terrain != null:
		_target.y = terrain.height(landing.x, landing.z)
	_facing(landing - global_position)
	var ring := _commit_ring(Threat.Type.PROJECTILE, landing, RING_RADIUS, RING_REACH)
	_launch = global_position + Vector3.UP * HEIGHT
	_bump = Threat.lob_bump(GRAVITY, FLIGHT)
	ring.set_flight(_launch, _bump)
	return ring


# The reticle stays open through the wind-up and closes over the flight; the boomerang lane fills.
func _warn_progress() -> float:
	if _boomerang:
		return clampf(_t / maxf(warn_seconds, 0.001), 0.0, 1.0)
	return 0.0


func _go_live() -> void:
	_landed = false
	_boom_cut_done = false
	_boom_batted = false
	returning_disc = false
	if _boomerang:
		boomerangs += 1


func _live(_delta: float) -> bool:
	var ring := telegraph()
	if ring == null:
		return false
	if _boomerang:
		return _live_boomerang(ring)
	if _t < FLIGHT:
		_disc.top_level = true
		_disc.global_position = Threat.flight_point(_launch, _target, _bump, _t / FLIGHT)
		_disc.rotate_y(SPIN_RATE)
		ring.set_progress(_t / FLIGHT)
		return true
	if _landed:
		return false
	_landed = true
	# The flight never takes the ring to its end, so the landing is drawn as the disc arrives.
	ring.land()
	_rest_disc()
	throws += 1
	var player = _player()
	var ball := _real_ball()
	if player == null or not ring.contains(ball):
		return false
	if aim == "landing":
		if player.state.grounded:
			landing_hits += 1
			hit_player.emit(LANDING_DAMAGE, Vector3.ZERO)
		else:
			dodged += 1
		return false
	if player.kit.hooked and not player.kit.gliding and not _over_gap(ball):
		grazed += 1
	elif player.kit.hooked and not player.kit.gliding:
		player.cut_line("line_cutter")
		cuts += 1
		hit_player.emit(STING, Vector3.ZERO)
		_offer_rebite(player)
	else:
		dodged += 1
		if fleet != null:
			fleet.discover("line_cut", ball)
	return false


func _live_boomerang(lane: Node3D) -> bool:
	if _boom_batted:
		return false
	var total := BOOMERANG_OUT + BOOMERANG_RETURN
	if _t >= total:
		returning_disc = false
		_rest_disc()
		return false
	var player = _player()
	var ball := _real_ball()
	_disc.top_level = true
	_disc.rotate_y(SPIN_RATE * 1.4)
	if _t < BOOMERANG_OUT:
		returning_disc = false
		var frac := clampf(_t / BOOMERANG_OUT, 0.0, 1.0)
		var side := _boom_dir.cross(Vector3.UP).normalized()
		_disc.global_position = _launch.lerp(_boom_apex, frac) + side * sin(frac * PI) * 1.6
		if not _boom_cut_done and player != null and lane.contains(ball):
			if player.kit.hooked and not player.kit.gliding and _over_gap(ball):
				_boom_cut_done = true
				player.cut_line("line_cutter")
				cuts += 1
				hit_player.emit(STING, Vector3.ZERO)
				_offer_rebite(player)
			elif player.kit.hooked and not player.kit.gliding and not _over_gap(ball):
				_boom_cut_done = true
				grazed += 1
		return true
	returning_disc = true
	var rfrac := clampf((_t - BOOMERANG_OUT) / BOOMERANG_RETURN, 0.0, 1.0)
	var home := global_position + Vector3.UP * HEIGHT
	var rside := _boom_dir.cross(Vector3.UP).normalized()
	_disc.global_position = _boom_apex.lerp(home, rfrac) - rside * sin(rfrac * PI) * 1.6
	if player != null and ball.distance_to(_disc.global_position) <= BAT_DISC_RADIUS \
			and (player.speed_tier() >= SpeedTier.CRUISE or player.planar_velocity().length() >= 12.0):
		bat_return_disc()
		return false
	return true


func bat_return_disc() -> bool:
	if not returning_disc or _boom_batted or is_dead():
		return false
	_boom_batted = true
	returning_disc = false
	boomerangs_batted += 1
	broken_by = "boomerang_bat"
	last_damage_source = "boomerang_bat"
	var disc_at := _disc.global_position if _disc != null else global_position
	last_bat = {"at": disc_at, "frame": Engine.get_physics_frames()}
	var rim := IslandEdge.nearest_rim(terrain, global_position, RIM_SEARCH, RIM_DROP) if terrain != null else {}
	var out_dir: Vector3 = rim["dir"] if not rim.is_empty() else (global_position - _real_ball())
	out_dir.y = 0.0
	out_dir = out_dir.normalized() if out_dir.length() > 0.1 else _boom_dir
	_rest_disc()
	knock(out_dir + Vector3.UP * 0.4, BOOMERANG_RINGOUT_KNOCK)
	if fleet != null:
		fleet.discover("line_cut", global_position)
	return true


func on_struck(hit_kind: String, _part: String, _result: Dictionary) -> void:
	if returning_disc and hit_kind in ["ram", "slam", "stomp"]:
		bat_return_disc()


func _over_gap(ball: Vector3) -> bool:
	return terrain == null or ball.y - Telegraph.ground_under(terrain, ball) >= GAP_HEIGHT


func _offer_rebite(player) -> void:
	if player.get("events") == null:
		return
	var deadline := Engine.get_physics_frames() + int(ceil(REBITE_WINDOW * Engine.physics_ticks_per_second))
	var me: WeakRef = weakref(self)
	player.events.grapple_fired.connect(func(_anchor: Vector3):
		if Engine.get_physics_frames() > deadline or not is_instance_valid(player):
			return
		var heading: Vector3 = player.planar_velocity()
		heading = heading.normalized() if heading.length() > 0.1 else Vector3.ZERO
		player.add_external_accel(heading * REBITE_KICK * float(Engine.physics_ticks_per_second))
		var cutter = me.get_ref()
		if cutter != null:
			cutter.rebites += 1, CONNECT_ONE_SHOT)


func _on_end() -> void:
	_boomerang = false
	returning_disc = false
	_boom_batted = false
	warn_seconds = PRIMARY_WARN
	live_seconds = PRIMARY_LIVE
	_rest_disc()


func _rest_disc() -> void:
	if _disc != null:
		_disc.top_level = false
		_disc.position = Vector3(0.0, CREW_HALF + 1.0, 0.0)
		_disc.basis = Basis.IDENTITY
