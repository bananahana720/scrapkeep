extends Node3D

const Tuning := preload("res://src/movement/tuning.gd")
const Rules := preload("res://src/movement/ball_rules.gd")
const SpeedTier := preload("res://src/movement/speed_tier.gd")
const BallState := preload("res://src/movement/ball_state.gd")
const KinematicBall := preload("res://src/kinematic_ball.gd")
const RigidBall := preload("res://src/movement/rigid_ball.gd")
const Intent := preload("res://src/movement/intent.gd")
const LabMaterials := preload("res://src/lab_materials.gd")
const Augments := preload("res://src/movement/augments.gd")
const AugmentKit := preload("res://src/movement/augment_kit.gd")
const AimStyle := preload("res://src/movement/aim_style.gd")

enum { KINEMATIC, RIGID }

const MODE_NAMES := ["kinematic", "rigid"]
const ZAP_RANGE := 70.0
const ZAP_KNOCK := 22.0
const ZAP_COOLDOWN := 0.2
const ZAP_SHOW := 0.12
const ZAP_MASK := 5

signal shockwave(position: Vector3, strength: float)

var tuning
var state := BallState.new()
var kit := AugmentKit.new()
var intent := Intent.new()
var source = Intent.Source.new()
var mode := KINEMATIC
var drive_basis := Basis.IDENTITY
var spawn_point := Vector3.ZERO

var _kinematic
var _rigid
var _visual: MeshInstance3D
var _rope: MeshInstance3D
var _wings: Node3D
var _pylon: Node3D
var _aim_marks := {}
var _zap_beam: MeshInstance3D
var _zap_spark: MeshInstance3D
var _zap_show := 0.0
var _zap_cooldown := 0.0
var _roll := Basis.IDENTITY


func setup(tuning_ref, spawn: Vector3) -> void:
	tuning = tuning_ref
	spawn_point = spawn

	_kinematic = KinematicBall.new()
	_kinematic.name = "KinematicBall"
	add_child(_kinematic)
	_kinematic.setup(tuning, state)
	_kinematic.enemy_touched.connect(_on_enemy_touched)

	_rigid = RigidBall.new()
	_rigid.name = "RigidBall"
	add_child(_rigid)
	_rigid.setup(tuning, state)
	_rigid.intent = intent
	_rigid.kit = kit
	_rigid.enemy_touched.connect(_on_enemy_touched)
	_rigid.slammed.connect(_on_slammed)
	_rigid.pylon_planted.connect(_on_pylon_planted)

	# Everything under the player is placed per frame in _process, which interpolation
	# must leave alone; only the two bodies are ticked by physics and interpolated.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_kinematic.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	_rigid.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON

	_visual = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = Tuning.RADIUS
	sphere.height = Tuning.RADIUS * 2.0
	sphere.radial_segments = 32
	sphere.rings = 16
	_visual.mesh = sphere
	_visual.material_override = LabMaterials.ball_material()
	add_child(_visual)

	_build_augment_visuals()

	set_mode(KINEMATIC)
	reset_to(spawn_point)


func active_body() -> Node3D:
	return _kinematic if mode == KINEMATIC else _rigid


func ball_position() -> Vector3:
	return active_body().global_position


# Where the ball is drawn this frame. With physics interpolation on (F3) that is the
# body's interpolated transform, so the visuals and the camera move every frame
# instead of stepping at the 90 Hz physics rate; with it off it is the raw position.
func shown_transform() -> Transform3D:
	var body := active_body()
	if is_inside_tree() and get_tree().physics_interpolation:
		return body.get_global_transform_interpolated()
	return body.global_transform


func shown_position() -> Vector3:
	return shown_transform().origin


# Switching modes must not change where you are or how fast you are going, or the
# two feels cannot be compared.
func set_mode(new_mode: int) -> void:
	var carried_position := ball_position() if _kinematic != null and is_inside_tree() else spawn_point
	var carried_velocity: Vector3 = state.velocity
	mode = new_mode
	kit.release_holds()
	_kinematic.set_active(mode == KINEMATIC)
	_rigid.set_active(mode == RIGID)
	active_body().teleport(carried_position, carried_velocity)


func toggle_mode() -> void:
	set_mode(RIGID if mode == KINEMATIC else KINEMATIC)


func reset_to(point: Vector3) -> void:
	state.reset()
	kit.clear_runtime()
	_roll = Basis.IDENTITY
	_kinematic.teleport(point, Vector3.ZERO)
	_rigid.teleport(point, Vector3.ZERO)


# The rope is a hard max-length constraint on the ball, so it is anchored where the
# ball is standing when it is fired, not where the camera ray started.
func grapple_to(point: Vector3, normal := Vector3.ZERO) -> void:
	if not kit.on(Augments.GRAPPLE):
		return
	Augments.attach(kit, ball_position(), point, normal)


func release_grapple() -> void:
	kit.hooked = false


func reel_step(metres: float) -> void:
	if not kit.hooked:
		return
	kit.rope = clampf(kit.rope - metres, Augments.MIN_ROPE, tuning.f("rope_range"))


func grapple_range() -> float:
	return tuning.f("rope_range")


func mode_name() -> String:
	return MODE_NAMES[mode]


func _physics_process(delta: float) -> void:
	source.poll(intent)
	state.tick_timers(delta)
	if intent.jump_pressed:
		state.jump_buffer = Tuning.JUMP_BUFFER
	_kinematic.drive_basis = drive_basis
	_rigid.drive_basis = drive_basis
	if mode == KINEMATIC:
		_kinematic.step(intent, delta)
	state.refresh_tier(tuning.f("cruise"))


# The placeholder weapon: a hitscan from the ball toward whatever the crosshair is
# on. It exists so mount-to-fire can be felt, not as a weapon design.
func zap(from: Vector3, forward: Vector3) -> Dictionary:
	if not kit.mounted or _zap_cooldown > 0.0:
		return {}
	_zap_cooldown = ZAP_COOLDOWN
	var space := get_world_3d().direct_space_state
	var target := from + forward.normalized() * ZAP_RANGE
	var sight := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, target, ZAP_MASK))
	if not sight.is_empty():
		target = sight["position"]
	var origin := ball_position()
	var shot := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, origin + (target - origin) * 1.05, ZAP_MASK))
	var end: Vector3 = shot["position"] if not shot.is_empty() else target
	_show_zap(origin, end)
	if shot.is_empty() or not (shot["collider"] as Node).is_in_group("enemy"):
		return {"hit": false, "point": end}
	var enemy: Node3D = shot["collider"]
	var away := enemy.global_position - origin
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
	enemy.knock(away + Vector3.UP * 0.3, ZAP_KNOCK)
	enemy.flash()
	return {"hit": true, "point": end, "enemy": enemy}


func _process(delta: float) -> void:
	_zap_cooldown = maxf(0.0, _zap_cooldown - delta)
	var shown := shown_transform()
	_visual.global_position = shown.origin
	_update_augment_visuals(shown.origin)
	if mode == RIGID:
		_roll = shown.basis.orthonormalized()
	else:
		var axis := Rules.roll_axis(state.velocity, state.contact_normal)
		if axis != Vector3.ZERO:
			var angle := (state.velocity - state.contact_normal * state.velocity.dot(state.contact_normal)).length() * delta / Tuning.RADIUS
			_roll = Basis(axis.normalized(), angle) * _roll
			_roll = _roll.orthonormalized()
	_visual.global_basis = _squash_basis() * _roll


func _squash_basis() -> Basis:
	var amount := clampf(state.impact / 26.0, 0.0, 0.42)
	if amount <= 0.001:
		return Basis.IDENTITY
	var align := _align_up(state.contact_normal)
	var scale := Basis.from_scale(Vector3(1.0 + amount * 0.55, 1.0 - amount, 1.0 + amount * 0.55))
	return align * scale * align.inverse()


static func _align_up(normal: Vector3) -> Basis:
	var up := normal.normalized()
	var right := Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	right = (right - up * right.dot(up)).normalized()
	return Basis(right, up, right.cross(up))


func _build_augment_visuals() -> void:
	_rope = MeshInstance3D.new()
	_rope.mesh = ImmediateMesh.new()
	_rope.material_override = LabMaterials.unshaded(Color(1.0, 0.72, 0.30))
	_rope.visible = false
	add_child(_rope)

	_wings = Node3D.new()
	var wing_material := LabMaterials.unshaded(Color(0.55, 0.85, 1.0, 0.75))
	for side in [-1.0, 1.0]:
		var fin := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(2.6, 0.12, 1.5)
		fin.mesh = box
		fin.material_override = wing_material
		fin.position = Vector3(side * 1.7, 0.2, 0.2)
		fin.rotation = Vector3(0.0, 0.0, side * -0.25)
		_wings.add_child(fin)
	_wings.visible = false
	add_child(_wings)

	# A scrap post: the pylon the pilot drives into the face, the ball riding its end.
	_pylon = Node3D.new()
	var post := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.16
	cyl.bottom_radius = 0.26
	cyl.height = Augments.MOUNT_OFFSET
	post.mesh = cyl
	post.material_override = LabMaterials.solid(Color(0.58, 0.52, 0.44))
	post.position = Vector3(0.0, Augments.MOUNT_OFFSET * 0.5, 0.0)
	_pylon.add_child(post)
	var plate := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.7
	disc.bottom_radius = 0.7
	disc.height = 0.12
	plate.mesh = disc
	plate.material_override = LabMaterials.solid(Color(1.0, 0.72, 0.30), 1.2)
	_pylon.add_child(plate)
	_pylon.visible = false
	add_child(_pylon)

	for state_key in [Augments.AIM_REACH, Augments.AIM_ASSIST]:
		var style: Dictionary = AimStyle.STYLES[state_key]
		var mark := MeshInstance3D.new()
		if style["shape"] == "ring":
			var ball := SphereMesh.new()
			ball.radius = 0.35
			ball.height = 0.7
			mark.mesh = ball
		else:
			var box := BoxMesh.new()
			box.size = Vector3.ONE * 0.6
			mark.mesh = box
			mark.rotation = Vector3(PI * 0.25, 0.0, PI * 0.25)
		mark.material_override = LabMaterials.unshaded(style["color"])
		mark.visible = false
		add_child(mark)
		_aim_marks[state_key] = mark

	_zap_beam = MeshInstance3D.new()
	_zap_beam.mesh = ImmediateMesh.new()
	_zap_beam.material_override = LabMaterials.unshaded(Color(1.0, 0.55, 0.85))
	_zap_beam.visible = false
	add_child(_zap_beam)
	# Seen from behind the ball the beam runs almost along the view, so the spark at the
	# far end is what actually shows where the zap landed.
	_zap_spark = MeshInstance3D.new()
	var spark := SphereMesh.new()
	spark.radius = 0.45
	spark.height = 0.9
	_zap_spark.mesh = spark
	_zap_spark.material_override = LabMaterials.unshaded(Color(1.0, 0.55, 0.85))
	_zap_spark.visible = false
	add_child(_zap_spark)


func _update_augment_visuals(at: Vector3) -> void:
	_rope.visible = kit.hooked
	if kit.hooked:
		var line: ImmediateMesh = _rope.mesh
		line.clear_surfaces()
		line.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		line.surface_add_vertex(at)
		line.surface_add_vertex(kit.anchor)
		line.surface_end()

	_pylon.visible = kit.mounted
	if kit.mounted:
		_pylon.global_transform = Transform3D(_align_up(kit.mount_normal), kit.mount_face)

	var aim_state: int = kit.aim.get("state", Augments.AIM_NONE)
	for state_key in _aim_marks:
		var mark: MeshInstance3D = _aim_marks[state_key]
		mark.visible = state_key == aim_state and not kit.hooked
		if mark.visible:
			mark.global_position = kit.aim["point"]

	_zap_show = maxf(0.0, _zap_show - get_process_delta_time())
	_zap_beam.visible = _zap_show > 0.0
	_zap_spark.visible = _zap_beam.visible

	_wings.visible = kit.gliding
	if kit.gliding:
		_wings.global_position = at
		var heading := Vector3(state.velocity.x, 0.0, state.velocity.z)
		if heading.length() > 0.5:
			_wings.global_basis = Basis.looking_at(heading.normalized(), Vector3.UP)


func _show_zap(from: Vector3, to: Vector3) -> void:
	var line: ImmediateMesh = _zap_beam.mesh
	line.clear_surfaces()
	line.surface_begin(Mesh.PRIMITIVE_LINES)
	line.surface_add_vertex(from)
	line.surface_add_vertex(to)
	line.surface_end()
	_zap_spark.global_position = to
	_zap_show = ZAP_SHOW


# The shockwave carries the same flatness as the plant: a full thump on flat ground,
# next to nothing when the slam went into a launch.
func _on_slammed(at: Vector3, speed: float, flatness: float) -> void:
	var strength := clampf(speed / 30.0, 0.4, 1.6) * flatness
	if strength < 0.05:
		return
	shockwave.emit(at, strength)
	_push_enemies(at, Augments.SLAM_RADIUS, Augments.SLAM_KNOCK * strength)


func _on_pylon_planted(at: Vector3) -> void:
	shockwave.emit(at, 0.7)
	_push_enemies(at, Augments.MOUNT_REPEL_RADIUS, Augments.MOUNT_REPEL_KNOCK)


func _push_enemies(at: Vector3, radius: float, force: float) -> void:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		var away: Vector3 = enemy.global_position - at
		var reach := away.length()
		if reach > radius:
			continue
		away.y = 0.0
		away = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
		var falloff := 1.0 - reach / radius
		enemy.knock(away + Vector3.UP * 0.5, force * falloff)
		enemy.flash()


func _on_enemy_touched(enemy: Node3D, normal: Vector3) -> void:
	var velocity: Vector3 = state.velocity
	var away := enemy.global_position - ball_position()
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
	if velocity.y < -3.0 and normal.y > 0.3:
		# The one mechanic worth keeping from the orchard: a descending rebound
		# gives the air jump back, so bouncing is a way to keep a line going.
		state.air_actions = 1
		kit.dash_ready = true
		state.impact = maxf(state.impact, absf(velocity.y))
		active_body().set_velocity_now(Vector3(velocity.x, tuning.f("jump_speed") * 0.95, velocity.z))
		enemy.knock(away * 0.6 + Vector3.DOWN * 0.2, 7.0)
		shockwave.emit(enemy.global_position, 0.6)
	elif state.tier >= SpeedTier.FAST:
		enemy.knock(away + Vector3.UP * 0.35, 18.0)
		enemy.flash()
		shockwave.emit(enemy.global_position, 1.0)
