extends "res://src/combat/counter.gd"

const RosterHighdraft := preload("res://src/combat/roster_highdraft.gd")

# The line cutter (World 3, roster_highdraft.gd): a crew figure that throws a spinning
# cutter at where the ball will be. The reticle waits through the wind-up and closes over the
# flight; the disc flies the committed arc to the ball's predicted point. If the ball is inside
# the landing ring when the disc lands and is on a harpoon line, the line is cut: it goes through
# the ball's own cut_line and nothing else of the harpoon is touched. A glide under the arc, or a
# ball that landed early, dodges it. A hard hit in the wind-up breaks the throw (counter.gd).
#
# The Highdraft rules (design-v3/WORLD-ROSTERS.md): a cut costs you only over a gap, so a ball
# less than GAP_HEIGHT over the ground under it is grazed, not cut. A fresh harpoon bite within
# REBITE_WINDOW of the cut saves the swing and adds REBITE_KICK along the ball's heading. The
# re-bite is the player's event, not the cutter's, so a cutter killed meanwhile still pays it.
#
# Grown remix: every other throw (the odd ones) lands on where the ball will touch down. A ball
# grounded inside that ring when the disc lands takes LANDING_DAMAGE.

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

var throws := 0
var cuts := 0
var dodged := 0
var grazed := 0
var rebites := 0
var landing_hits := 0
# What this throw aims at: "line", or (grown) "landing".
var aim := "line"

var _disc: MeshInstance3D
var _launch := Vector3.ZERO
var _target := Vector3.ZERO
var _bump := 0.0
var _landed := false
var _body: MeshInstance3D
var _throw_arm: MeshInstance3D
static var _shared: Array = []


func _configure(threat: float) -> void:
	_set_health(HP * threat)
	scrap_value = 4
	weight = 1.0
	warn_seconds = 0.6
	live_seconds = FLIGHT + 0.2
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
	return super(to_ball) and player != null and (player.kit.hooked or not player.state.on_floor())


func _commit(_to_ball: Vector3) -> Node3D:
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


# The reticle stays open through the wind-up and closes over the flight.
func _warn_progress() -> float:
	return 0.0


func _go_live() -> void:
	_landed = false


func _live(_delta: float) -> bool:
	var ring := telegraph()
	if ring == null:
		return false
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


func _over_gap(ball: Vector3) -> bool:
	return terrain == null or ball.y - Telegraph.ground_under(terrain, ball) >= GAP_HEIGHT


# One fresh bite within REBITE_WINDOW pays REBITE_KICK once; a later bite pays nothing.
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
	_rest_disc()


func _rest_disc() -> void:
	if _disc != null:
		_disc.top_level = false
		_disc.position = Vector3(0.0, CREW_HALF + 1.0, 0.0)
		_disc.basis = Basis.IDENTITY
