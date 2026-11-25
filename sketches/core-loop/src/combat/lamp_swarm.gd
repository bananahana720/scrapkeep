extends "res://src/combat/counter.gd"

const SpeedTier := preload("res://src/movement/speed_tier.gd")

# The lamp swarm (DESIGN-V2 section 10, World 2): one crew rig carrying a formation of
# three lure lamps. Warn blooms a WAVE ring. While the bloom is live, a ball inside it
# that is under cruise speed is steered toward the lamps by a damage-free shove; a ball
# at cruise or faster is not touched, so boosting straight through is the counter. A ram
# at cruise or faster scatters the lamps and ends the attack; a slower ram does not.
# The lure never deals damage and never holds: hit_player(0.0, shove) only bends the line.

const HP := 35.0
const LAMP_COUNT := 3
const LAMP_RING := 1.3
const LAMP_HEIGHT := 1.6
const LAMP_RADIUS := 0.3
const BLOOM_RADIUS := 9.0
const BLOOM_SPEED := 6.0
const BLOOM_REACH := 3.0
const LURE := 6.0
const SCATTER_SPEED := 7.0
const PRIMARY_WARN := 0.9
const PRIMARY_LIVE := 3.0

# Secondary attack (W48-COMBAT): Flash-Focus Beam. Commits a >= 0.70 s Palette.HAZARD lane;
# slow/stalling balls inside the beam take flash damage (ruling cu), while boosting or
# cruising through the beam apex scatters the lamps and pays +25 Warden posture.
const BEAM_WARN := 0.85
const BEAM_LIVE := 1.6
const BEAM_LENGTH := 16.0
const BEAM_WIDTH := 2.8
const BEAM_APEX_OFFSET := 4.5
const BEAM_APEX_RADIUS := 3.2
const BEAM_DAMAGE := 6.0
const BEAM_SHOVE := 5.0
const APEX_WARDEN_POSTURE := 25.0

var lamps: Array = []
var blooms := 0
var lured_ticks := 0
var scatters := 0
var flash_beams := 0
var apex_breaks := 0
var warden_posture_paid := 0.0
var next_attack := ""
var last_apex_break := {}
var _flung := false
# This bloom already met the ball at cruise inside it (lure_bloom), so it reports once.
var _bloom_met := false
var _flash_beam := false
var _beam_dir := Vector3.FORWARD
var _beam_apex := Vector3.ZERO
var _beam_hit := false
var _beam_apex_paid := false
var _fling: Array = []
var _lamp_rig: Skeleton3D
var _lamp_bones: Array[int] = []
var _shutter_bones: Array[int] = []
var _lens_bones: Array[int] = []
static var _warned_asset := false
static var _shared: PackedScene
static var _painted: StandardMaterial3D


func _configure(threat: float) -> void:
	_set_health(HP * threat)
	scrap_value = 4
	weight = 1.0
	warn_seconds = 0.9
	live_seconds = 3.0
	rest_seconds = 3.5
	attack_range = 20.0
	keep_near = 10.0


func _build_tool() -> void:
	var packed := _parts()
	if packed != null:
		_crew.free()
		_crew = null
		var model := packed.instantiate() as Node3D
		_visual_parent().add_child(model)
		_base_color = Color.WHITE
		_material.albedo_color = _base_color
		_material.vertex_color_use_as_albedo = true
		for node in model.find_children("*", "MeshInstance3D", true, false):
			var mi := node as MeshInstance3D
			for surface in mi.mesh.get_surface_count():
				var surface_material := mi.mesh.surface_get_material(surface)
				if surface_material == null and not _warned_asset:
					_warned_asset = true
					push_warning("lamp_swarm: surface has no material; using default finish")
				var slot := surface_material.resource_name if surface_material != null else ""
				mi.set_surface_override_material(surface, _material if slot == "fleet_paint" else _painted)
		_lamp_rig = model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		for i in LAMP_COUNT:
			var lamp := Node3D.new()
			lamp.name = "LampTransform%d" % i
			_visual_parent().add_child(lamp)
			lamp.position = _lamp_rest(i)
			lamps.append(lamp)
			_lamp_bones.append(_lamp_rig.find_bone("LampBulb%d" % i))
			_lens_bones.append(_lamp_rig.find_bone("LampLens%d" % i))
			_shutter_bones.append(_lamp_rig.find_bone("LampShutter%d" % i))
			_shutter_bones.append(_lamp_rig.find_bone("LampShutter%dB" % i))
		_fling.resize(LAMP_COUNT)
		_fling.fill(Vector3.ZERO)
		_pose_lamps()
		return
	for i in LAMP_COUNT:
		var lamp := SphereMesh.new()
		lamp.radius = LAMP_RADIUS
		lamp.height = LAMP_RADIUS * 2.0
		lamps.append(_accent(lamp, Palette.HAZARD, 2.0, _lamp_rest(i)))
	_fling.resize(LAMP_COUNT)
	_fling.fill(Vector3.ZERO)


static func _parts() -> PackedScene:
	if _shared != null:
		return _shared
	var path := "res://assets/models/world_two/enemy_lamp_swarm.glb"
	if not ResourceLoader.exists(path):
		return null
	_shared = load(path) as PackedScene
	if _shared != null:
		_painted = Palette.solid(Color.WHITE)
		_painted.vertex_color_use_as_albedo = true
	return _shared


func _lamp_rest(index: int) -> Vector3:
	var angle := TAU * float(index) / float(LAMP_COUNT)
	return Vector3(cos(angle) * LAMP_RING, LAMP_HEIGHT, sin(angle) * LAMP_RING)


func _use_flash_beam() -> bool:
	if next_attack == "flash_beam":
		return true
	if next_attack == "bloom":
		return false
	return blooms > flash_beams


func beam_apex() -> Vector3:
	return _beam_apex


func _commit(to_ball: Vector3) -> Node3D:
	var is_beam := _use_flash_beam()
	_flash_beam = is_beam
	next_attack = ""
	if is_beam:
		warn_seconds = BEAM_WARN
		live_seconds = BEAM_LIVE
		var flat := Vector3(to_ball.x, 0.0, to_ball.z)
		_beam_dir = flat.normalized() if flat.length() > 0.1 else Vector3.FORWARD
		_beam_apex = global_position + _beam_dir * BEAM_APEX_OFFSET
		_beam_hit = false
		_beam_apex_paid = false
		_facing(_beam_dir)
		return _commit_lane(Threat.Type.LANE, global_position, _beam_dir, BEAM_LENGTH, BEAM_WIDTH, 3.0)
	warn_seconds = PRIMARY_WARN
	live_seconds = PRIMARY_LIVE
	_clear_telegraph()
	_telegraph = Telegraph.wave(world_root, terrain, global_position, BLOOM_RADIUS, BLOOM_SPEED, warn_seconds, BLOOM_REACH)
	_bloom_met = false
	_facts_begin(_telegraph)
	return _telegraph


func _go_live() -> void:
	if _flash_beam:
		flash_beams += 1
		_beam_hit = false
		_beam_apex_paid = false
		return
	blooms += 1
	var tele := telegraph()
	if tele != null:
		tele.age = warn_seconds


func _is_boosting_or_fast(player) -> bool:
	if player == null:
		return false
	if player.speed_tier() >= SpeedTier.CRUISE:
		return true
	var state = player.get("state")
	if state != null and "boost_left" in state and float(state.boost_left) > 0.0:
		return true
	return false


func _pay_warden_posture() -> float:
	if not is_inside_tree():
		return 0.0
	var paid := 0.0
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy) or String(enemy.get("kind")) != "warden":
			continue
		if enemy.has_method("is_dead") and enemy.is_dead():
			continue
		if enemy.has_method("judge_hit") and enemy.has_method("_apply_posture"):
			var before: float = float(enemy.posture()) if enemy.has_method("posture") else 0.0
			var was_staggered: bool = bool(enemy.staggered()) if enemy.has_method("staggered") else false
			enemy._apply_posture(enemy.judge_hit("guard_rack", 0.0, false, 0))
			if not was_staggered:
				var after: float = float(enemy.posture()) if enemy.has_method("posture") else before
				paid = APEX_WARDEN_POSTURE if (enemy.has_method("staggered") and enemy.staggered()) or after > before else 0.0
			break
	warden_posture_paid += paid
	return paid


func _fling_lamps() -> void:
	_flung = true
	for i in lamps.size():
		var out: Vector3 = lamps[i].position
		out.y = 0.0
		_fling[i] = out.normalized() * SCATTER_SPEED + Vector3.UP * 3.0


func _live(delta: float) -> bool:
	var tele := telegraph()
	if tele == null:
		return false
	if _flash_beam:
		var player = _player()
		if player == null:
			return true
		var ball := _real_ball()
		var to_apex := Vector2(ball.x - _beam_apex.x, ball.z - _beam_apex.z).length()
		if not _beam_apex_paid and _is_boosting_or_fast(player) and (to_apex <= BEAM_APEX_RADIUS or tele.contains(ball)):
			_beam_apex_paid = true
			apex_breaks += 1
			scatters += 1
			broken_by = "apex_boost"
			_fling_lamps()
			var paid := _pay_warden_posture()
			last_apex_break = {"at": _beam_apex, "posture": paid, "frame": Engine.get_physics_frames()}
			var to_me: Vector3 = global_position - ball
			to_me.y = 0.0
			_meet_bloom(to_me)
			return false
		if not _beam_hit and tele.contains(ball) and player.speed_tier() < SpeedTier.CRUISE:
			_beam_hit = true
			var side := _beam_dir.cross(Vector3.UP).normalized()
			hit_player.emit(BEAM_DAMAGE, side * BEAM_SHOVE)
		return true
	tele.step(delta)
	if tele.is_spent():
		return false
	var player = _player()
	if player == null:
		return true
	var ball := _real_ball()
	var to: Vector3 = global_position - ball
	to.y = 0.0
	if player.speed_tier() >= SpeedTier.CRUISE:
		_meet_bloom(to)
	elif tele.contains(ball):
		lured_ticks += 1
		hit_player.emit(0.0, to.normalized() * LURE * delta)
	return true


# A ball at cruise or faster inside the bloom went through the light: lure_bloom, once per bloom.
func _meet_bloom(to: Vector3) -> void:
	if _bloom_met or to.length() > BLOOM_RADIUS or fleet == null:
		return
	_bloom_met = true
	fleet.discover("lure_bloom", _real_ball())


func on_struck(kind_hit: String, _part: String, _result: Dictionary) -> void:
	var player = _player()
	if kind_hit != "ram" or phase == Phase.ROAM or player == null or player.speed_tier() < SpeedTier.CRUISE:
		return
	scatters += 1
	var to: Vector3 = global_position - _real_ball()
	to.y = 0.0
	_meet_bloom(to)
	broken_by = "scattered"
	_fling_lamps()


func _pose() -> void:
	if not _flung:
		_pose_lamps()
		return
	var delta := get_physics_process_delta_time()
	for i in lamps.size():
		_fling[i] += Vector3.DOWN * 9.8 * delta
		lamps[i].position += _fling[i] * delta
	_pose_lamps()


func _pose_lamps(reset := false) -> void:
	if _lamp_rig == null:
		return
	var open := clampf(_warn_progress(), 0.0, 1.0) if phase == Phase.WARN else (1.0 if phase == Phase.LIVE else 0.0)
	if reset:
		open = 0.0
	for i in LAMP_COUNT:
		_lamp_rig.set_bone_pose_position(_lamp_bones[i], lamps[i].position)
		_lamp_rig.set_bone_pose_scale(_lens_bones[i], Vector3.ONE * lerpf(0.001, 1.0, open))
		for side in 2:
			_lamp_rig.set_bone_pose_rotation(_shutter_bones[i * 2 + side], Quaternion(Vector3.UP, (1.0 if side == 1 else -1.0) * deg_to_rad(100.0) * open))


func _on_end() -> void:
	_flash_beam = false
	warn_seconds = PRIMARY_WARN
	live_seconds = PRIMARY_LIVE
	_flung = false
	for i in lamps.size():
		lamps[i].position = _lamp_rest(i)
	_pose_lamps(true)
