extends "res://src/combat/counter.gd"

const SpeedTier := preload("res://src/movement/speed_tier.gd")
const FxLibrary := preload("res://src/presentation/fx_library.gd")

const BODY := "res://assets/models/world_one/enemy_boom_tender.glb"
const HULL_RADIUS := 1.3
const LANE_LENGTH := 8.4
const LANE_WIDTH := 3.0
const SWING := 1.1
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
const LEAD_REACH := 10.0
const FLOAT_OUT := [2.07, 3.37, 4.67, 5.97, 7.27]
const LAMP_ON := 2.4
const BOOM_DROP := 0.5
const BUOY_OUT := 7.88
const BUOY_SCALE := 0.5
const PRIMARY_WARN := 1.1
const PRIMARY_LIVE := SWEEP + PIN

const BUOY_MIN_POPS := 2
const BUOY_WARN := 0.75
const BUOY_FLIGHT := 0.85
const BUOY_RETURN_S := 0.35
const BUOY_RANGE := 16.0
const BUOY_WIDTH := 2.8
const BUOY_LEAD_REACH := 8.0
const BUOY_HIT_RADIUS := 2.2
const BUOY_DAMAGE := 10.0
const BUOY_SHOVE := 10.0
const BUOY_THROW_SCALE := 1.35
const BASE_SCRAP := 5

var pinned := 0
var pops := 0
var strikes := 0
var popped := [false, false, false, false, false]
var buoy_throws := 0
var buoy_returns := 0
var buoy_knockouts := 0

var _heading := Vector3.FORWARD
var _origin := Vector3.ZERO
var _side := 1.0
var _pops_live := 0
var _boom: Node3D
var _floats: MultiMeshInstance3D
var _reel: Node3D
var _lamps: MultiMeshInstance3D
var _buoy_rest_xform := Transform3D.IDENTITY
var _buoy_throw := false
var _buoy_returned := false
var _buoy_hit_player := false
var _buoy_pos := Vector3.ZERO
var _buoy_return_from := Vector3.ZERO
var _buoy_return_t := 0.0

static var _shared: Array = []


func _configure(threat: float) -> void:
	_set_health(HP * threat)
	scrap_value = BASE_SCRAP
	weight = 2.0
	warn_seconds = PRIMARY_WARN
	live_seconds = PRIMARY_LIVE
	rest_seconds = 4.0
	attack_range = LANE_LENGTH + 1.0
	keep_near = 5.0
	impact_resist = 1.2


func _build_crew() -> void:
	radius = HULL_RADIUS
	half_height = HULL_RADIUS
	_crew = _add_capsule(HULL_RADIUS, HULL_RADIUS * 2.0, Palette.RUST)


func _build_tool() -> void:
	var parts := _parts()
	var dress := Node3D.new()
	dress.name = "BoomTenderBody"
	dress.position = Vector3(0.0, -half_height, 0.0)
	_visual_parent().add_child(dress)
	_boom = Node3D.new()
	_boom.name = "Boom"
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


func _lay_boom(mesh: Mesh, at: Vector3, turn: Basis) -> void:
	_floats = _multimesh("BoomFloats", mesh, FLOAT_OUT.size() + 1, false)
	for i in FLOAT_OUT.size():
		_floats.multimesh.set_instance_transform(i, Transform3D(turn, Vector3(at.x, at.y, -float(FLOAT_OUT[i]))))
	_buoy_rest_xform = Transform3D(turn.scaled(Vector3.ONE * BUOY_SCALE), Vector3(at.x, at.y, -BUOY_OUT))
	_floats.multimesh.set_instance_transform(FLOAT_OUT.size(), _buoy_rest_xform)
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


func _burst_count() -> int:
	var count := 0
	for is_burst in popped:
		if is_burst:
			count += 1
	return count


func _wants_attack(to_ball: Vector3) -> bool:
	if _burst_count() >= BUOY_MIN_POPS:
		return to_ball.length() <= BUOY_RANGE and is_on_floor()
	return super._wants_attack(to_ball)


func buoy_position() -> Vector3:
	return _buoy_pos


func _commit(to_ball: Vector3) -> Node3D:
	var is_buoy := _burst_count() >= BUOY_MIN_POPS
	_buoy_throw = is_buoy
	_buoy_returned = false
	_buoy_hit_player = false
	_buoy_return_t = 0.0
	warn_seconds = BUOY_WARN if is_buoy else PRIMARY_WARN
	live_seconds = BUOY_FLIGHT if is_buoy else PRIMARY_LIVE
	var lead_t := (BUOY_WARN + BUOY_FLIGHT * 0.4) if is_buoy else (warn_seconds + SWEEP * 0.5)
	var lead_cap := BUOY_LEAD_REACH if is_buoy else LEAD_REACH
	var aim := _ahead(lead_t, lead_cap) - global_position
	if Vector2(aim.x, aim.z).dot(Vector2(to_ball.x, to_ball.z)) <= 0.0 or Vector2(aim.x, aim.z).length() < 0.5:
		aim = to_ball
	_heading = Vector3(aim.x, 0.0, aim.z).normalized()
	if _heading.length() < 0.5:
		_heading = -global_transform.basis.z
	_facing(aim)
	_side = _strafe
	_origin = global_position
	_pops_live = 0
	if is_buoy:
		_buoy_pos = global_position + _heading * 2.0 + Vector3.UP * 0.65
		if world_root != null and is_inside_tree():
			FxLibrary.burst(world_root, "brass_spark", global_position + Vector3.UP * 1.4, 8)
	var lane_len := BUOY_RANGE if is_buoy else LANE_LENGTH
	var lane_w := BUOY_WIDTH if is_buoy else LANE_WIDTH
	return _commit_lane(Threat.Type.LANE, global_position, _heading, lane_len, lane_w)


func _go_live() -> void:
	if _buoy_throw:
		buoy_throws += 1
		_buoy_pos = _origin + _heading * 2.0 + Vector3.UP * 0.65
		if world_root != null and is_inside_tree():
			FxLibrary.burst(world_root, "steam_puff", _origin + Vector3.UP * 1.4, 6)


func _live(delta: float) -> bool:
	if _buoy_throw:
		return _live_buoy(delta)
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


func _live_buoy(delta: float) -> bool:
	if _dead:
		return false
	var player = _player()
	if _buoy_returned:
		_buoy_return_t += delta
		var ru := clampf(_buoy_return_t / BUOY_RETURN_S, 0.0, 1.0)
		_buoy_pos = _buoy_return_from.lerp(global_position + Vector3.UP * 0.8, ru)
		_place_buoy_visual(_buoy_pos, _buoy_return_t * 16.0)
		if ru >= 1.0:
			buoy_knockouts += 1
			scrap_value = BASE_SCRAP * 2
			if world_root != null and is_inside_tree():
				FxLibrary.burst(world_root, "plate_chunks", global_position + Vector3.UP * 0.8, 14)
				FxLibrary.burst(world_root, "brass_spark", global_position + Vector3.UP * 1.0, 16, Palette.BRASS)
				FxLibrary.burst(world_root, "steam_puff", global_position + Vector3.UP * 0.8, 8)
			take_damage(hp)
			return false
		return true
	var lane := telegraph()
	var u := clampf(_t / BUOY_FLIGHT, 0.0, 1.0)
	var along := lerpf(2.0, BUOY_RANGE, u)
	var flat_at := _origin + _heading * along
	var gy: float = Telegraph.ground_under(terrain, flat_at) if terrain != null else _origin.y
	_buoy_pos = Vector3(flat_at.x, gy + 0.65, flat_at.z)
	_place_buoy_visual(_buoy_pos, _t * 12.0)
	if lane != null:
		lane.run_body(along, BUOY_HIT_RADIUS)
	if player != null:
		var ball := _real_ball()
		var d_flat := Vector2(ball.x - _buoy_pos.x, ball.z - _buoy_pos.z).length()
		var d_y := absf(ball.y - _buoy_pos.y)
		if d_flat <= BUOY_HIT_RADIUS and d_y <= 2.4:
			if player.speed_tier() >= SpeedTier.CRUISE:
				_buoy_returned = true
				_buoy_return_from = _buoy_pos
				_buoy_return_t = 0.0
				buoy_returns += 1
				live_seconds = _t + BUOY_RETURN_S + 0.1
				_clear_telegraph()
				if world_root != null and is_inside_tree():
					FxLibrary.burst(world_root, "brass_spark", _buoy_pos, 14, Palette.BRASS)
					FxLibrary.burst(world_root, "steam_puff", _buoy_pos, 6)
				return true
			if not _buoy_hit_player:
				_buoy_hit_player = true
				hit_player.emit(BUOY_DAMAGE, _heading * BUOY_SHOVE + Vector3.UP * 2.5)
	return _t < BUOY_FLIGHT


func _place_buoy_visual(world_at: Vector3, spin: float) -> void:
	if _floats == null or _boom == null or not _boom.is_inside_tree():
		return
	var local_at := _boom.to_local(world_at)
	var rot := Basis(Vector3.RIGHT, spin * EnemyMotion.motion_scale) * Basis.from_scale(Vector3.ONE * (BUOY_SCALE * BUOY_THROW_SCALE))
	_floats.multimesh.set_instance_transform(FLOAT_OUT.size(), Transform3D(rot, local_at))


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
		if world_root != null and is_inside_tree():
			FxLibrary.burst(world_root, "plate_chunks", at + Vector3.UP * 0.5, 8)
			FxLibrary.burst(world_root, "brass_spark", at + Vector3.UP * 0.6, 10)
			FxLibrary.burst(world_root, "steam_puff", at + Vector3.UP * 0.5, 5)
		_pay(at)
		if fleet != null:
			fleet.discover("boom_pop", at)
	if _pops_live == FLOAT_OUT.size():
		_pops_live = 0
		strikes += 1
		if world_root != null and is_inside_tree():
			FxLibrary.burst(world_root, "brass_spark", ball + Vector3.UP * 1.2, 16, Palette.BRASS)
			FxLibrary.burst(world_root, "steam_puff", ball + Vector3.UP * 0.8, 8)
		if fleet != null:
			fleet.discover("boom_strike", ball)


func _facing_yaw(to_ball: Vector3) -> float:
	return atan2(-to_ball.x, -to_ball.z)


func float_position(i: int) -> Vector3:
	return _origin + _heading * float(FLOAT_OUT[i])


func pop_float_at(index: int, pay := true) -> bool:
	if index < 0 or index >= popped.size() or bool(popped[index]):
		return false
	popped[index] = true
	pops += 1
	_pop_float(index)
	if pay:
		_pay(float_position(index))
	return true


func pop_all_floats(pay := false) -> int:
	var count := 0
	for i in popped.size():
		if pop_float_at(i, pay):
			count += 1
	return count


func _pay(at: Vector3) -> void:
	var ctx = fleet.ctx if fleet != null else null
	var build = ctx.build if ctx != null and "build" in ctx else null
	if build != null and build.scrap != null:
		build.scrap.drop(at, FLOAT_SCRAP, build.loot_rng)


func _on_end() -> void:
	_lamp(-1)
	_buoy_throw = false
	_buoy_returned = false
	_buoy_hit_player = false
	_buoy_return_t = 0.0
	warn_seconds = PRIMARY_WARN
	live_seconds = PRIMARY_LIVE
	if _floats != null:
		_floats.multimesh.set_instance_transform(FLOAT_OUT.size(), _buoy_rest_xform)


func _pose() -> void:
	if _boom == null:
		return
	var swing := 0.0
	var reel := 0.0
	if _buoy_throw:
		match phase:
			Phase.WARN:
				var t := clampf(_warn_progress(), 0.0, 1.0)
				swing = -SWING * 0.4 * _side * t * t * (3.0 - 2.0 * t)
				reel = TAU * 2.0 * t
				_lamp(FLOAT_OUT.size() if int(floor(t * 6.0)) % 2 == 0 else 0)
			Phase.LIVE:
				swing = 0.0
				reel = TAU * 3.0 * clampf(_t / BUOY_FLIGHT, 0.0, 1.0)
				_lamp(FLOAT_OUT.size())
		_boom.rotation.y = swing
		if _reel != null:
			_reel.rotation.x = reel
		return
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


func _lamp(count: int) -> void:
	if _lamps == null:
		return
	var lit := Palette.BRASS * LAMP_ON
	lit.a = 1.0
	for i in FLOAT_OUT.size():
		_lamps.multimesh.set_instance_color(i, lit if i < count else Palette.BRASS.darkened(0.6))
