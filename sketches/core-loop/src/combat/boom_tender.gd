extends "res://src/combat/counter.gd"

const SpeedTier := preload("res://src/movement/speed_tier.gd")

# The boom tender (Boom Tender No. 22, design-v3/SPILLWAY-ROSTER.md; world 1): a low tug on
# tracks paying out a debris boom of five floats and an end buoy. It stows the boom to one side
# and the warning is a lane from the hull toward where the ball is rolling (W1-66, LEAD_REACH),
# the boom's whole reach; through the warn the reel ratchets and the float lamps light one by one out along the lane. Live, the
# boom swings into the lane. A ball in the lane below FAST tier is pinned: stung, shoved and
# hauled toward the hull. A ball at FAST tier bowls through instead: every float within
# POP_REACH of it bursts like a pin, pays FLOAT_SCRAP, and stays burst for the tender's life.
# All five in one pass is a strike. Boost, jump or hook out of a pin. Speed beats Flow.

const BODY := "res://assets/models/world_one/enemy_boom_tender.glb"
const HULL_RADIUS := 1.3
const LANE_LENGTH := 8.4
const LANE_WIDTH := 3.0
const SWING := 1.1
# The boom crosses the lane in SWEEP seconds; a pin it makes then holds up to PIN.
const SWEEP := 0.6
const POP_TIER := SpeedTier.FAST
const POP_REACH := 1.6
const FLOAT_SCRAP := 1
const PIN := 1.0
const PIN_PULL := 6.0
const PIN_DAMP := 2.5
const STING_DAMAGE := 5.0
const SHOVE := 6.0
const HP := 60.0
# W1-66 (gameplay critique finding 4): the lane is aimed where the ball's roll carries it by the middle
# of the sweep, at most LEAD_REACH metres on, so the boom swings across the ball's line and a ball that
# holds it rolls into the sweep. The answer is a turn off the line (or speed to bowl through).
const LEAD_REACH := 10.0
# The floats' distances out from the hull centre (-Z forward); the glb's BoomFloat sits at the first.
const FLOAT_OUT := [2.07, 3.37, 4.67, 5.97, 7.27]
const LAMP_ON := 2.4
const BOOM_DROP := 0.5
const BUOY_OUT := 7.88
const BUOY_SCALE := 0.5

var pinned := 0
var pops := 0
var strikes := 0
var popped := [false, false, false, false, false]

var _heading := Vector3.FORWARD
var _origin := Vector3.ZERO
var _side := 1.0
var _pops_live := 0
var _boom: Node3D
var _floats: MultiMeshInstance3D
var _reel: Node3D
var _lamps: MultiMeshInstance3D

static var _shared: Array = []


func _configure(threat: float) -> void:
	_set_health(HP * threat)
	scrap_value = 5
	weight = 2.0
	warn_seconds = 1.1
	live_seconds = SWEEP + PIN
	rest_seconds = 4.0
	attack_range = LANE_LENGTH + 1.0
	keep_near = 5.0
	impact_resist = 1.2


# A squat collider for the hull instead of the crew capsule.
func _build_crew() -> void:
	radius = HULL_RADIUS
	half_height = HULL_RADIUS
	_crew = _add_capsule(HULL_RADIUS, HULL_RADIUS * 2.0, Palette.RUST)


# BODY's glb (origin on the ground under the hull) dropped to the collider's floor. Its bow is
# -Z, so _facing turns -Z to the ball and the body keeps the glb's frame (enemy_clips.gd maps
# bones to parts by position only). The floats and the buoy hang off a boom node that pivots
# at the hull centre, so the swing is one rotation.
func _build_tool() -> void:
	var parts := _parts()
	var dress := Node3D.new()
	dress.name = "BoomTenderBody"
	dress.position = Vector3(0.0, -half_height, 0.0)
	_visual_parent().add_child(dress)
	_boom = Node3D.new()
	_boom.name = "Boom"
	# The glb lays the boom straight out at fairlead height; in play the floats ride the floor.
	_boom.position.y = -BOOM_DROP
	dress.add_child(_boom)
	if parts.is_empty():
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.3
		cyl.bottom_radius = 0.3
		cyl.height = 0.9
		cyl.material = Palette.solid(Palette.RUST)
		_lay_boom(cyl, Vector3(0.0, 0.85, 0.0), Basis(Vector3.RIGHT, PI * 0.5))
		return
	_crew.free()
	_crew = null
	_base_color = Color.WHITE
	_material.albedo_color = _base_color
	_material.vertex_color_use_as_albedo = true
	for part in parts:
		var name := String(part.name)
		if name == "BoomFloat":
			_lay_boom(part.mesh, (part.xform as Transform3D).origin, Basis.IDENTITY)
			continue
		var mi := MeshInstance3D.new()
		mi.name = name
		mi.mesh = part.mesh
		mi.transform = part.xform
		if part.flash >= 0:
			mi.set_surface_override_material(part.flash, _material)
		dress.add_child(mi)
		if name == "TenderReel":
			_reel = mi


# The one float laid at each FLOAT_OUT and once small as the end buoy, and a brass lamp on each
# float: two multimeshes, so the boom is two draws however many floats stand (the dam's draw
# split, 23 Oct: thirteen meshes a tender were +194 p99 draws with the pack cap). A popped float
# and its lamp collapse to a zero basis; the lamps light by instance colour, unshaded.
func _lay_boom(mesh: Mesh, at: Vector3, turn: Basis) -> void:
	_floats = _multimesh("BoomFloats", mesh, FLOAT_OUT.size() + 1, false)
	for i in FLOAT_OUT.size():
		_floats.multimesh.set_instance_transform(i, Transform3D(turn, Vector3(at.x, at.y, -float(FLOAT_OUT[i]))))
	_floats.multimesh.set_instance_transform(FLOAT_OUT.size(),
			Transform3D(turn.scaled(Vector3.ONE * BUOY_SCALE), Vector3(at.x, at.y, -BUOY_OUT)))
	var lamp := BoxMesh.new()
	lamp.size = Vector3(0.14, 0.12, 0.14)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.vertex_color_use_as_albedo = true
	lamp.material = glow
	_lamps = _multimesh("BoomLamps", lamp, FLOAT_OUT.size(), true)
	_lamps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in FLOAT_OUT.size():
		_lamps.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(at.x, at.y + 0.34, -float(FLOAT_OUT[i]))))
	_lamp(-1)


func _multimesh(node_name: String, mesh: Mesh, count: int, colours: bool) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colours
	mm.mesh = mesh
	mm.instance_count = count
	var node := MultiMeshInstance3D.new()
	node.name = node_name
	node.multimesh = mm
	_boom.add_child(node)
	return node


func _pop_float(i: int) -> void:
	for node in [_floats, _lamps]:
		if node != null:
			var mm: MultiMesh = (node as MultiMeshInstance3D).multimesh
			var xf := mm.get_instance_transform(i)
			mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), xf.origin))


static func _parts() -> Array:
	if _shared.is_empty():
		_shared = EnemyCasting.parts(BODY, "boom_tender", true)
	return _shared


func _commit(to_ball: Vector3) -> Node3D:
	var aim := _ahead(warn_seconds + SWEEP * 0.5, LEAD_REACH) - global_position
	# A ball rolling straight at the hull is led past it: the lane would point behind the tender, so it
	# is laid at the ball as it stands, which covers that approach.
	if Vector2(aim.x, aim.z).dot(Vector2(to_ball.x, to_ball.z)) <= 0.0 or Vector2(aim.x, aim.z).length() < 0.5:
		aim = to_ball
	_heading = Vector3(aim.x, 0.0, aim.z).normalized()
	if _heading.length() < 0.5:
		_heading = -global_transform.basis.z
	_facing(aim)
	_side = _strafe
	_origin = global_position
	_pops_live = 0
	return _commit_lane(Threat.Type.LANE, global_position, _heading, LANE_LENGTH, LANE_WIDTH)


func _live(_delta: float) -> bool:
	var lane := telegraph()
	var player = _player()
	if lane == null or player == null:
		return false
	var ball := _real_ball()
	if _holding():
		var to_hull := _origin - ball
		to_hull.y = 0.0
		_pull(to_hull.normalized() * PIN_PULL * minf(to_hull.length(), 6.0) - player.planar_velocity() * PIN_DAMP)
		return true
	# Past the sweep the boom has crossed; only a pin it made keeps the attack open.
	if caught_live > 0 or _t > SWEEP:
		return false
	if not lane.contains(ball):
		return true
	if player.speed_tier() >= POP_TIER:
		_bowl_through(ball)
		return true
	var shove := global_position - ball
	shove.y = 0.0
	shove = shove.normalized() * SHOVE
	if _catch(PIN):
		pinned += 1
		hit_player.emit(STING_DAMAGE, shove)
	return true


# A fast ball bursts every standing float within POP_REACH of it.
func _bowl_through(ball: Vector3) -> void:
	for i in FLOAT_OUT.size():
		if popped[i]:
			continue
		var at := float_position(i)
		if Vector2(at.x - ball.x, at.z - ball.z).length() > POP_REACH:
			continue
		popped[i] = true
		pops += 1
		_pops_live += 1
		_pop_float(i)
		_pay(at)
		if fleet != null:
			fleet.discover("boom_pop", at)
	if _pops_live == FLOAT_OUT.size():
		_pops_live = 0
		strikes += 1
		if fleet != null:
			fleet.discover("boom_strike", ball)


# The bow (-Z) toward the ball, where the other kinds turn +Z.
func _facing(to_ball: Vector3) -> void:
	if to_ball.length() > 0.5:
		rotation.y = atan2(-to_ball.x, -to_ball.z)


# Where float i lies along the committed lane (from where the hull stood at the commit).
func float_position(i: int) -> Vector3:
	return _origin + _heading * float(FLOAT_OUT[i])


func _pay(at: Vector3) -> void:
	var ctx = fleet.ctx if fleet != null else null
	var build = ctx.build if ctx != null and "build" in ctx else null
	if build != null and build.scrap != null:
		build.scrap.drop(at, FLOAT_SCRAP, build.loot_rng)


func _on_end() -> void:
	_lamp(-1)


# E40's pose, e40_reel_ratchet: the boom stows SWING to one side and the reel winds back
# through the warn while the lamps light out along the lane; live, the boom swings into the
# lane. The lane, the pin and the pops read the committed heading, never this pose.
func _pose() -> void:
	if _boom == null:
		return
	var swing := 0.0
	var reel := 0.0
	match phase:
		Phase.WARN:
			var t := clampf(_warn_progress(), 0.0, 1.0)
			swing = SWING * _side * t * t * (3.0 - 2.0 * t)
			reel = -TAU * t
			_lamp(int(floor(t * float(FLOAT_OUT.size()))))
		Phase.LIVE:
			swing = SWING * _side * (1.0 - clampf(_t / SWEEP, 0.0, 1.0) * 2.0)
			_lamp(FLOAT_OUT.size())
		_:
			swing = lerpf(_boom.rotation.y, 0.0, 1.0 - exp(-6.0 * get_physics_process_delta_time()))
	_boom.rotation.y = swing
	if _reel != null:
		_reel.rotation.x = reel


# Lights the first `count` standing floats' lamps; -1 puts them all out.
func _lamp(count: int) -> void:
	if _lamps == null:
		return
	var lit := Palette.BRASS * LAMP_ON
	lit.a = 1.0
	for i in FLOAT_OUT.size():
		_lamps.multimesh.set_instance_color(i, lit if i < count else Palette.BRASS.darkened(0.6))
