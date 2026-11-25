extends "res://src/combat/counter.gd"

const FxLibrary := preload("res://src/presentation/fx_library.gd")

const LANE_LENGTH := 24.0
const LANE_WIDTH := 2.4
const POST_HEIGHT := 4.2
const SPRING := 5.0
const RADIAL_DAMP := 3.0
const REEL := 2.5
const MIN_ROPE := 3.0
const SNAP_SPEED := 19.0
const RATING_BASE := 2.2
const RATING_PER_THREAT := 0.5
const HP := 55.0

const PRIMARY_WARN := 1.0
const PRIMARY_LIVE := 2.2
const WHIP_WARN := 0.75
const WHIP_LIVE := 0.25
const WHIP_HALF_DEG := 75.0
const WHIP_TETHER_S := 1.0
const WHIP_BEHIND_RANGE := 14.0
const WHIP_BEHIND_DOT := -0.25
const WHIP_RADIUS := 14.0
const WHIP_REACH := 4.0
const WHIP_DAMAGE := 14.0
const WHIP_SHOVE := 12.0
const WHIP_CREST_START := 0.45
const CATAPULT_MULT := 1.5
const CATAPULT_MIN_SPEED := 22.0
const CATAPULT_LIFT := 10.0

var rating := RATING_BASE
var rope := 0.0
var snaps := 0
var whips := 0
var catapult_snaps := 0
var landed_attack := ""

var _whipping := false
var _whip_armed := false
var _tether_held := 0.0
var _whip_clock := 0.0
var _whip_dir := Vector3.FORWARD
var _whip_crest_rewarded := false
var _whip_tele: Node3D
var _whip_bus_bound := false


func _configure(threat: float) -> void:
	_set_health(HP * threat)
	scrap_value = 4
	weight = 1.5
	warn_seconds = PRIMARY_WARN
	live_seconds = PRIMARY_LIVE
	rest_seconds = 4.0
	attack_range = 22.0
	keep_near = 12.0
	rating = RATING_BASE + RATING_PER_THREAT * (threat - 1.0)
	_bind_whip_bus()


func _bind_whip_bus() -> void:
	if _whip_bus_bound or _reaction_bus == null:
		return
	_whip_bus_bound = true
	_reaction_bus.boosted.connect(_on_player_boost_whip)
	_reaction_bus.dashed.connect(_on_player_boost_whip)
	_reaction_bus.blink_used.connect(_on_player_blink_whip)
	_reaction_bus.sprint_started.connect(_on_player_boost_whip)
	_reaction_bus.grapple_fired.connect(_on_player_grapple_whip)


func _unbind_whip_bus() -> void:
	if not _whip_bus_bound:
		return
	_whip_bus_bound = false
	if is_instance_valid(_reaction_bus):
		if _reaction_bus.boosted.is_connected(_on_player_boost_whip):
			_reaction_bus.boosted.disconnect(_on_player_boost_whip)
		if _reaction_bus.dashed.is_connected(_on_player_boost_whip):
			_reaction_bus.dashed.disconnect(_on_player_boost_whip)
		if _reaction_bus.blink_used.is_connected(_on_player_blink_whip):
			_reaction_bus.blink_used.disconnect(_on_player_blink_whip)
		if _reaction_bus.sprint_started.is_connected(_on_player_boost_whip):
			_reaction_bus.sprint_started.disconnect(_on_player_boost_whip)
		if _reaction_bus.grapple_fired.is_connected(_on_player_grapple_whip):
			_reaction_bus.grapple_fired.disconnect(_on_player_grapple_whip)


func is_whipping() -> bool:
	return _whipping or _whip_armed


func in_whip_crest() -> bool:
	if _whip_armed:
		return _whip_clock >= WHIP_WARN * WHIP_CREST_START
	if _whipping:
		return (phase == Phase.WARN and _t >= WHIP_WARN * WHIP_CREST_START) or phase == Phase.LIVE
	return false


func telegraph() -> Node3D:
	if is_instance_valid(_whip_tele):
		return _whip_tele
	return super.telegraph()


const COCK := 0.45
const THRUST := 0.3

static var _warned_asset := false
static var _shared: Dictionary = {}

var _harpoon: MeshInstance3D
var _rest_z := 0.0


func _build_tool() -> void:
	_crew.free()
	_crew = null
	var parts := _parts()
	var dress := Node3D.new()
	dress.name = "HookerBody"
	_visual_parent().add_child(dress)
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = parts["body"]
	body.set_surface_override_material(parts["flash"], _material)
	dress.add_child(body)
	_harpoon = MeshInstance3D.new()
	_harpoon.name = "HookerHarpoon"
	_harpoon.mesh = parts["harpoon"]
	_harpoon.position = parts["pivot"]
	_rest_z = _harpoon.position.z
	dress.add_child(_harpoon)


static func _parts() -> Dictionary:
	if not _shared.is_empty():
		return _shared
	var scene := (load(ModelVariants.path("res://assets/models/world_one/enemy_hooker.glb")) as PackedScene).instantiate()
	var painted := Palette.solid(Color.WHITE)
	painted.vertex_color_use_as_albedo = true
	var flash := 0
	var meshes := {}
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (node as MeshInstance3D).mesh.duplicate()
		for i in mesh.get_surface_count():
			var surface_material := mesh.surface_get_material(i)
			if surface_material == null and not _warned_asset:
				_warned_asset = true
				push_warning("hooker: surface has no material; using default finish")
			var slot := surface_material.resource_name if surface_material != null else ""
			if slot == "fleet_paint":
				flash = i
			mesh.surface_set_material(i, painted)
		meshes[node.name] = mesh
	var pivot := scene.find_child("HookerHarpoonMesh", true, false) as Node3D
	_shared = {"body": meshes["HookerBody"], "harpoon": meshes["HookerHarpoonMesh"], "flash": flash,
		"pivot": pivot.position + (pivot.get_parent() as Node3D).position}
	scene.free()
	return _shared


func _pose() -> void:
	if _harpoon == null:
		return
	var dt := get_physics_process_delta_time()
	var z := 0.0
	var yaw := 0.0
	if _whipping or _whip_armed:
		var prog := clampf(_whip_clock / WHIP_WARN, 0.0, 1.0) if _whip_armed else clampf(_warn_progress(), 0.0, 1.0)
		var eased := prog * prog * (3.0 - 2.0 * prog)
		if _whip_armed or phase == Phase.WARN:
			z = -COCK * eased
			yaw = deg_to_rad(-WHIP_HALF_DEG) * eased
		elif phase == Phase.LIVE:
			var snap := 1.0 - pow(1.0 - clampf(_t / maxf(WHIP_LIVE * 0.5, 0.05), 0.0, 1.0), 3.0)
			z = THRUST
			yaw = lerpf(deg_to_rad(-WHIP_HALF_DEG), deg_to_rad(WHIP_HALF_DEG), snap)
		_harpoon.position.z = _rest_z + z
		_harpoon.rotation.y = yaw
		return
	match phase:
		Phase.WARN:
			var t := clampf(_warn_progress(), 0.0, 1.0)
			z = -COCK * t * t * (3.0 - 2.0 * t)
		Phase.LIVE:
			z = THRUST
		_:
			z = lerpf(_harpoon.position.z - _rest_z, 0.0, 1.0 - exp(-10.0 * dt))
	_harpoon.position.z = _rest_z + z
	if not is_zero_approx(_harpoon.rotation.y):
		_harpoon.rotation.y = lerp_angle(_harpoon.rotation.y, 0.0, 1.0 - exp(-10.0 * dt))


func anchor() -> Vector3:
	return global_position + Vector3(0.0, POST_HEIGHT - CREW_HALF, 0.0)


func _wants_behind_whip(to_ball: Vector3) -> bool:
	if warned <= 0:
		return false
	var flat := _flat(to_ball)
	var dist := flat.length()
	if dist < 0.5 or dist > WHIP_BEHIND_RANGE:
		return false
	var fwd := _flat(global_basis.z)
	if fwd.length_squared() < 0.01:
		return false
	return flat.normalized().dot(fwd.normalized()) <= WHIP_BEHIND_DOT


func _commit(to_ball: Vector3) -> Node3D:
	_whipping = false
	_whip_armed = false
	_tether_held = 0.0
	_whip_clock = 0.0
	_whip_crest_rewarded = false
	_clear_whip_tele()
	if _wants_behind_whip(to_ball):
		_whipping = true
		warn_seconds = WHIP_WARN
		live_seconds = WHIP_LIVE
		var flat := _flat(to_ball)
		_whip_dir = flat.normalized() if flat.length() > 0.05 else Vector3.FORWARD
		_facing(to_ball)
		_clear_telegraph()
		_telegraph = Telegraph.secondary_wedge(world_root, terrain, Threat.Type.INSTANT, global_position,
			_whip_dir, WHIP_RADIUS, WHIP_HALF_DEG, WHIP_WARN, WHIP_REACH)
		_facts_begin(_telegraph)
		return _telegraph
	warn_seconds = PRIMARY_WARN
	live_seconds = PRIMARY_LIVE
	_facing(to_ball)
	return _commit_lane(Threat.Type.LANE, global_position, to_ball, LANE_LENGTH, LANE_WIDTH)


func _voice(tele: Node3D) -> void:
	super(tele)
	if _whipping:
		tele.mechanic_tag = "scrap_rip"
		tele.warn_seconds = WHIP_WARN


func _go_live() -> void:
	if _whipping:
		_strike_whip(telegraph())
		return
	var lane := telegraph()
	var ball := _real_ball()
	if lane == null or not lane.contains(ball):
		broken_by = "missed"
		return
	if not _catch(0.0, Vector3.ZERO, anchor()):
		broken_by = "ignored"
		return
	_tether_held = 0.0
	_whip_armed = false
	_whip_clock = 0.0
	_whip_crest_rewarded = false
	rope = maxf(MIN_ROPE, _flat(ball - anchor()).length())
	if _player().heft() >= rating:
		snaps += 1
		holds.snap(self, "speed")


func _live(delta: float) -> bool:
	if _whipping:
		return false
	if not _holding():
		return false
	var player = _player()
	if player.planar_velocity().length() >= SNAP_SPEED:
		snaps += 1
		holds.snap(self, "speed")
		return false
	_tether_held += delta
	if _whip_armed:
		_whip_clock += delta
		if is_instance_valid(_whip_tele):
			_whip_tele.set_progress(_whip_clock / WHIP_WARN)
		if _whip_clock >= WHIP_WARN:
			_release("expired")
			_strike_whip(_whip_tele)
			return false
	elif _tether_held >= WHIP_TETHER_S and AttackBudget.gap_open_for(self):
		_arm_tether_whip()
	rope = maxf(MIN_ROPE, rope - REEL * delta)
	var out := _flat(_real_ball() - anchor())
	var accel := Vector3.ZERO
	if out.length() > rope:
		var dir := out.normalized()
		accel -= dir * (out.length() - rope) * SPRING
		var radial: float = player.planar_velocity().dot(dir)
		if radial > 0.0:
			accel -= dir * radial * RADIAL_DAMP
	_pull(accel)
	return true


func _arm_tether_whip() -> void:
	_whip_armed = true
	_whip_clock = 0.0
	_whip_crest_rewarded = false
	if is_instance_valid(_telegraph):
		_telegraph.queue_free()
	_telegraph = null
	var to_ball := _flat(_real_ball() - global_position)
	_whip_dir = to_ball.normalized() if to_ball.length() > 0.05 else Vector3.FORWARD
	var whip_radius := clampf(rope + 3.0, 9.0, WHIP_RADIUS)
	_whip_tele = Telegraph.secondary_wedge(world_root, terrain, Threat.Type.INSTANT, global_position,
		_whip_dir, whip_radius, WHIP_HALF_DEG, WHIP_WARN, WHIP_REACH)
	_whip_tele.owner_voice = "clank"
	_whip_tele.mechanic_tag = "scrap_rip"
	AttackBudget.mark_warn(self)
	live_seconds = maxf(live_seconds, _t + WHIP_WARN + 0.15)
	if world_root != null and is_inside_tree():
		FxLibrary.burst(world_root, "steam_puff", anchor(), 6)


func _strike_whip(wedge: Node3D) -> void:
	whips += 1
	landed_attack = "reel_whip"
	if world_root != null and is_inside_tree():
		FxLibrary.burst(world_root, "brass_spark", anchor(), 10)
	var ball := _real_ball()
	if wedge == null or not is_instance_valid(wedge) or not wedge.contains(ball):
		return
	var tangent := _whip_dir.cross(Vector3.UP) * (1.0 if _strafe >= 0.0 else -1.0)
	if tangent.length_squared() < 0.01:
		tangent = Vector3.RIGHT
	hit_player.emit(WHIP_DAMAGE, tangent.normalized() * WHIP_SHOVE + Vector3.UP * 3.0)


func _on_broken(method: String) -> void:
	if method == "boost" or method == "hook":
		snaps += 1
		if _whip_armed and in_whip_crest() and not _whip_crest_rewarded:
			_grant_catapult(method)
	if fleet == null:
		return
	if method == "hook":
		fleet.discover("hook_out", _real_ball())
	else:
		fleet.discover("tether_snap", _real_ball())


func _on_player_boost_whip(_dir: Vector3) -> void:
	_try_behind_whip_catapult("boost")


func _on_player_blink_whip(_from: Vector3, _to: Vector3) -> void:
	_try_behind_whip_catapult("boost")


func _on_player_grapple_whip(_at: Vector3) -> void:
	_try_behind_whip_catapult("hook")


func _try_behind_whip_catapult(method: String) -> void:
	if not _whipping or _dead or _whip_crest_rewarded or not in_whip_crest():
		return
	var ball := _real_ball()
	if _flat(ball - global_position).length() > WHIP_RADIUS + 2.5:
		return
	_grant_catapult(method)
	_end()


func _grant_catapult(method: String) -> void:
	_whip_crest_rewarded = true
	catapult_snaps += 1
	var player = _player()
	if player != null and is_instance_valid(player):
		var v: Vector3 = player.planar_velocity() if player.has_method("planar_velocity") else Vector3.ZERO
		var speed := Vector2(v.x, v.z).length()
		var target_speed := maxf(speed * CATAPULT_MULT, CATAPULT_MIN_SPEED)
		var delta_speed := maxf(target_speed - speed, CATAPULT_MIN_SPEED * 0.5)
		var dir := Vector3.ZERO
		if method == "hook" and player.get("kit") != null and player.kit.hooked:
			dir = _flat(player.kit.anchor - player.ball_position())
		if dir.length() < 0.1:
			dir = Vector3(v.x, 0.0, v.z)
		if dir.length() < 0.1:
			dir = _flat(player.ball_position() - global_position)
		if dir.length() < 0.1:
			dir = Vector3.FORWARD
		var step := maxf(get_physics_process_delta_time(), 1.0 / 90.0)
		if player.has_method("add_external_accel"):
			player.add_external_accel((dir.normalized() * delta_speed + Vector3.UP * CATAPULT_LIFT) / step)
		if player.has_method("refresh_air"):
			player.refresh_air()
	stun_left = maxf(stun_left, STAGGER_WINDOW)
	staggers += 1
	if world_root != null and is_inside_tree():
		FxLibrary.burst(world_root, "brass_spark", anchor(), 16)
		FxLibrary.burst(world_root, "spark_core", _real_ball(), 12, Palette.SAND)


func _on_end() -> void:
	_whipping = false
	_whip_armed = false
	_tether_held = 0.0
	_whip_clock = 0.0
	_whip_crest_rewarded = false
	_clear_whip_tele()
	warn_seconds = PRIMARY_WARN
	live_seconds = PRIMARY_LIVE


func _clear_whip_tele() -> void:
	if is_instance_valid(_whip_tele):
		_whip_tele.queue_free()
	_whip_tele = null


func _exit_tree() -> void:
	_unbind_whip_bus()
	_clear_whip_tele()
	super._exit_tree()


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
