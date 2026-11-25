extends "res://src/combat/counter.gd"

const Splitter := preload("res://src/combat/splitter.gd")
const BODY := "res://assets/models/world_one/enemy_splitter_piece.glb"
const WIND_POSE := "e03_leap_spread"

const HP := 40.0
const WEIGHT := 0.6
const BODY_RADIUS := 0.6
const BODY_HALF := 0.9
const WALK := 10.0
const BLAST_RADIUS := 4.5
const BLAST_RANGE := 3.5
const BLAST_DAMAGE := 12.0
const BLAST_SHOVE := 8.0
const FUSE := 1.0
const GLOW_IDLE := 1.0
const GLOW_FUSE := 5.0
const GLOW_SPENT := 0.1
const CRUMBLE := 0.15

var blasts := 0
var spent := false
var _crumble := 0.0
var _ring_had_ball := false
var _glow: StandardMaterial3D
var _body: Node3D
var _rig: Node
var _husk_age := -1.0


func _configure(threat: float) -> void:
	_set_health(HP * threat)
	scrap_value = 1
	weight = WEIGHT
	walk_speed = WALK
	keep_near = 0.0
	keep_far = 0.0
	attack_range = BLAST_RANGE
	warn_seconds = FUSE
	live_seconds = 0.05
	rest_seconds = 2.6
	first_rest = 0.5


func _roam(to_ball: Vector3) -> Vector3:
	if spent:
		return Vector3.ZERO
	var distance := to_ball.length()
	return to_ball / distance * walk_speed if distance > 0.5 else Vector3.ZERO


func _build_crew() -> void:
	radius = BODY_RADIUS
	half_height = BODY_HALF
	_add_capsule(BODY_RADIUS, BODY_HALF * 2.0, Palette.RUST).free()
	_glow = Palette.solid(Palette.AMBER, GLOW_IDLE)
	_body = Node3D.new()
	_body.name = "PodBody"
	_visual_parent().add_child(_body)
	var model := Splitter.SpecialRig.seat(self, _body, BODY, "splitter_piece")
	if model != null:
		_rig = get_node_or_null("SpecialRig")
		_rig.moment("spawn")
	for part in Splitter.parts(BODY)["meshes"]:
		var mi: MeshInstance3D = model.find_child(part.name, true, false) as MeshInstance3D if model != null else null
		if mi == null:
			mi = MeshInstance3D.new()
			mi.name = part.name
			mi.mesh = part.mesh
			mi.transform = part.xform
			_body.add_child(mi)
		for i in mi.mesh.get_surface_count():
			mi.set_surface_override_material(i, _material if part.paint else _glow)
		if part.paint:
			_crew = mi
	_base_color = Color.WHITE
	_material.albedo_color = _base_color
	_material.vertex_color_use_as_albedo = true


func _commit(to_ball: Vector3) -> Node3D:
	_facing(to_ball)
	var ring := _commit_ring(Threat.Type.INSTANT, global_position, BLAST_RADIUS, 2.2, Palette.HAZARD)
	_ring_had_ball = ring != null and ring.contains(_real_ball())
	return ring


func _go_live() -> void:
	blasts += 1
	var ring := telegraph()
	var ball := _real_ball()
	if ring != null and ring.contains(ball):
		var out: Vector3 = ball - global_position
		out.y = 0.0
		var dir := out.normalized() if out.length() > 0.1 else Vector3.FORWARD
		hit_player.emit(BLAST_DAMAGE, dir * BLAST_SHOVE + Vector3.UP * 3.0)
	elif ring != null and _ring_had_ball and fleet != null:
		fleet.discover("fuse_pod", ball)
	spent = true
	_husk_age = 0.0
	scrap_value = 0


func _wants_attack(to_ball: Vector3) -> bool:
	return not spent and super(to_ball)


func _physics_process(delta: float) -> void:
	super(delta)
	if not spent or _dead or phase != Phase.ROAM or recovering():
		return
	_crumble += delta
	if _crumble >= CRUMBLE:
		last_damage_source = "fuse"
		_die()


func _pose() -> void:
	if _glow == null:
		return
	_wind_up()
	if spent:
		_glow.emission_energy_multiplier = GLOW_SPENT
		return
	var burn := clampf(_warn_progress(), 0.0, 1.0) if phase == Phase.WARN else 0.0
	var blink := 0.5 + 0.5 * sin(_t * TAU * FlashGuard.rate(lerpf(3.0, 10.0, burn)))
	_glow.emission_energy_multiplier = FlashGuard.spike(GLOW_IDLE, lerpf(GLOW_IDLE, GLOW_FUSE, burn * blink))


func fuse_progress() -> float:
	return clampf(_warn_progress(), 0.0, 1.0) if phase == Phase.WARN and not spent else 0.0


func wind_basis() -> Basis:
	var tele := telegraph()
	var age: float = tele.age if tele != null and is_instance_valid(tele) else _t
	return WindupPoses.windup(WIND_POSE, fuse_progress(), age, EnemyMotion.motion_scale)


func release_basis() -> Basis:
	return WindupPoses.release(WIND_POSE, _husk_age, EnemyMotion.motion_scale)


func _wind_up() -> void:
	if _body != null:
		if spent:
			_body.basis = release_basis()
			_husk_age += get_physics_process_delta_time()
		else:
			_body.basis = wind_basis()
		_body.position = Vector3(0.0, -BODY_HALF * (1.0 - _body.basis.y.length()), 0.0)
	if _rig != null:
		_rig.player.speed_scale = 0.0 if spent else 1.0 - fuse_progress()
