extends Node3D

const Tuning := preload("res://src/movement/tuning.gd")
const Rules := preload("res://src/movement/ball_rules.gd")
const SpeedTier := preload("res://src/movement/speed_tier.gd")
const BallState := preload("res://src/movement/ball_state.gd")
const RigidBall := preload("res://src/movement/rigid_ball.gd")
const Intent := preload("res://src/movement/intent.gd")
const Palette := preload("res://src/core/palette.gd")
const Augments := preload("res://src/movement/augments.gd")
const AugmentKit := preload("res://src/movement/augment_kit.gd")
const AimStyle := preload("res://src/movement/aim_style.gd")

# Rigid physics only (TADR-006; entry 6 kept it for its arcade weight). The ball owns
# movement and publishes each movement fact on the bus; what a collision does to an
# enemy's health is combat's, so a contact is handed on through struck().

const STOMP := "stomp"
const RAM := "ram"
const SLAM := "slam"
# The bow sensor reaches this far past the shell, so a crush is decided before contact.
const BOW_REACH := 1.0
# How long a crushed enemy is ignored by the ball's collider while it dies.
const CRUSH_PASS := 0.3
# A contact is a stomp when the ball was coming down faster than this onto an enemy
# below its centre.
const STOMP_SPEED := 3.0

signal shockwave(position: Vector3, strength: float)
# A physical contact the ball made, for combat to turn into damage. Local, not the bus:
# the bus fact is enemy_struck, which combat publishes once the hit is resolved.
signal struck(enemy: Node3D, kind: String, force: float)

var tuning
var events
var state := BallState.new()
var kit := AugmentKit.new()
var intent := Intent.new()
var source = Intent.Source.new()
var drive_basis := Basis.IDENTITY
var spawn_point := Vector3.ZERO
# Presentation turns this off when it draws its own squash and stretch.
var builtin_squash := true
# Asks combat whether a contact would kill outright: (enemy, kind, force) -> bool.
# game.gd wires it to ctx.spawner.would_crush once combat is set up.
var crush_check := Callable()

var _rigid
# The draw rig. _visual_root follows the shown position and never rotates; _juice is
# free for presentation (squash, stretch, trails); _mesh rolls; _roll_mount rolls with
# the mesh for anything that should stick to the ball's surface, like accreted scrap.
var _visual_root: Node3D
var _juice: Node3D
var _mesh: MeshInstance3D
var _roll_mount: Node3D
var _rope: MeshInstance3D
var _wings: Node3D
var _pylon: Node3D
var _aim_marks := {}
var _roll := Basis.IDENTITY
var _frozen := false
var _was_hooked := false
var _bow: Area3D
var _crushing := {}


func setup(tuning_ref, events_ref, spawn: Vector3) -> void:
	tuning = tuning_ref
	events = events_ref
	spawn_point = spawn

	_rigid = RigidBall.new()
	_rigid.name = "RigidBall"
	add_child(_rigid)
	_rigid.setup(tuning, state)
	_rigid.intent = intent
	_rigid.kit = kit
	# Seed the body before its first physics step: a pending teleport arrives too late
	# on the very first tick. Outside the tree only the local position can be set.
	if _rigid.is_inside_tree():
		_rigid.global_position = spawn_point
	else:
		_rigid.position = spawn_point
	_rigid.enemy_touched.connect(_on_enemy_touched)
	_rigid.slammed.connect(_on_slammed)
	_rigid.pylon_planted.connect(_on_pylon_planted)
	_rigid.pylon_ejected.connect(func(v: Vector3): events.dismounted.emit(v))
	_rigid.jumped.connect(func(air: bool): events.jumped.emit(air))
	_rigid.boosted.connect(func(dir: Vector3): events.boosted.emit(dir))
	_rigid.dashed.connect(func(dir: Vector3): events.dashed.emit(dir))
	_rigid.landed.connect(func(impact: float): events.landed.emit(impact))

	# Everything under the player is placed per frame in _process, which interpolation
	# must leave alone; only the body is ticked by physics and interpolated.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_rigid.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON

	_visual_root = Node3D.new()
	_visual_root.name = "Visual"
	add_child(_visual_root)
	_juice = Node3D.new()
	_juice.name = "Juice"
	_visual_root.add_child(_juice)
	_mesh = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = Tuning.RADIUS
	sphere.height = Tuning.RADIUS * 2.0
	sphere.radial_segments = 32
	sphere.rings = 16
	_mesh.mesh = sphere
	_mesh.material_override = Palette.ball_material()
	_juice.add_child(_mesh)
	_roll_mount = Node3D.new()
	_roll_mount.name = "RollMount"
	_mesh.add_child(_roll_mount)

	_build_bow()
	_build_augment_visuals()
	_rigid.set_active(true)
	reset_to(spawn_point)


func body() -> RigidBody3D:
	return _rigid


# Kept for code copied from the mobility kit, which had two bodies.
func active_body() -> RigidBody3D:
	return _rigid


func ball_position() -> Vector3:
	return _rigid.global_position


# Where the ball is drawn this frame. With physics interpolation on (F3) that is the
# body's interpolated transform, so the visuals and the camera move every frame
# instead of stepping at the 90 Hz physics rate; with it off it is the raw position.
func shown_transform() -> Transform3D:
	if is_inside_tree() and get_tree().physics_interpolation:
		return _rigid.get_global_transform_interpolated()
	return _rigid.global_transform


func shown_position() -> Vector3:
	return shown_transform().origin


# Presentation hooks. The juice node is presentation's to transform and parent to;
# the spine never writes it. The roll mount turns with the ball's surface.
func juice_node() -> Node3D:
	return _juice


func roll_node() -> Node3D:
	return _roll_mount


func speed_tier() -> int:
	return state.tier


func speed_fraction() -> float:
	return SpeedTier.fraction(state.velocity.length(), tuning.f("cruise"))


func planar_velocity() -> Vector3:
	return Vector3(state.velocity.x, 0.0, state.velocity.z)


# A frozen ball takes no push: a killing blow's shove lands after the death has frozen
# it, and must not wait for the retry (FIXWAVE spine, the stale shove).
func add_external_accel(accel: Vector3) -> void:
	if _frozen:
		return
	_rigid.external_accel += accel


# Screens freeze the ball so a title or death screen never lets it roll off; unfreezing
# hands back exactly the velocity given, which is how a launch carries between stages.
# Freezing drops any push already handed over this tick.
func set_frozen(frozen: bool) -> void:
	_frozen = frozen
	_rigid.set_active(not frozen)
	if frozen:
		_rigid.external_accel = Vector3.ZERO


func frozen() -> bool:
	return _frozen


func reset_to(point: Vector3, velocity := Vector3.ZERO) -> void:
	state.reset()
	kit.clear_runtime()
	_roll = Basis.IDENTITY
	_was_hooked = false
	_rigid.external_accel = Vector3.ZERO
	_rigid.teleport(point, velocity)


func set_velocity_now(velocity: Vector3) -> void:
	_rigid.set_velocity_now(velocity)


# The rope is a hard max-length constraint on the ball, so it is anchored where the
# ball is standing when it is fired, not where the camera ray started.
func grapple_to(point: Vector3, normal := Vector3.ZERO) -> void:
	if not kit.on(Augments.GRAPPLE):
		return
	Augments.attach(kit, ball_position(), point, normal)
	events.grapple_fired.emit(point)


func release_grapple() -> void:
	kit.hooked = false


func reel_step(metres: float) -> void:
	if not kit.hooked:
		return
	kit.rope = clampf(kit.rope - metres, Augments.MIN_ROPE, tuning.f("rope_range"))


func grapple_range() -> float:
	return tuning.f("rope_range")


func _physics_process(delta: float) -> void:
	source.poll(intent)
	state.tick_timers(delta)
	if intent.jump_pressed:
		state.jump_buffer = Tuning.JUMP_BUFFER
	_rigid.drive_basis = drive_basis
	state.refresh_tier(tuning.f("cruise"))
	if _was_hooked and not kit.hooked:
		events.grapple_released.emit()
	_was_hooked = kit.hooked
	_recheck_bow()


func _process(_delta: float) -> void:
	var shown := shown_transform()
	_visual_root.global_position = shown.origin
	_visual_root.global_basis = Basis.IDENTITY
	_update_augment_visuals(shown.origin)
	_roll = shown.basis.orthonormalized()
	_mesh.basis = (_squash_basis() if builtin_squash else Basis.IDENTITY) * _roll


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


# The Katamari moment: fodder the ball now outweighs is rolled straight through. The
# sensor sees it a metre early, combat confirms the hit would kill, and the collider
# ignores that enemy while it dies, so the pass costs no speed, knock or hit-stop.
func _build_bow() -> void:
	_bow = Area3D.new()
	_bow.name = "Bow"
	_bow.collision_layer = 0
	_bow.collision_mask = 0
	_bow.set_collision_mask_value(3, true)
	_bow.monitorable = false
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = Tuning.RADIUS + BOW_REACH
	shape.shape = sphere
	_bow.add_child(shape)
	_rigid.add_child(_bow)
	_bow.body_entered.connect(_on_bow_entered)


func _on_bow_entered(body: Node3D) -> void:
	_try_crush(body)


# Rechecked every tick for whatever is inside the bow, so an enemy the ball grows or
# speeds into outweighing mid-overlap is still rolled up.
func _recheck_bow() -> void:
	if _bow == null or _frozen or state.tier < SpeedTier.CRUISE:
		return
	for body in _bow.get_overlapping_bodies():
		_try_crush(body)


func _try_crush(body: Node3D) -> void:
	if _frozen or not body.is_in_group("enemy") or state.tier < SpeedTier.CRUISE or not crush_check.is_valid():
		return
	var id := body.get_instance_id()
	if _crushing.has(id):
		return
	var speed := planar_velocity().length()
	if not crush_check.call(body, RAM, speed):
		return
	_crushing[id] = true
	_rigid.add_collision_exception_with(body)
	struck.emit(body, RAM, speed)
	get_tree().create_timer(CRUSH_PASS, false, true).timeout.connect(_end_crush.bind(id))


# Bound by id: the crushed enemy is usually freed by now, and a freed exception
# leaves the physics server with it.
func _end_crush(id: int) -> void:
	_crushing.erase(id)
	var body := instance_from_id(id)
	if is_instance_valid(body) and body is PhysicsBody3D:
		_rigid.remove_collision_exception_with(body)


func _build_augment_visuals() -> void:
	_rope = MeshInstance3D.new()
	_rope.mesh = ImmediateMesh.new()
	_rope.material_override = Palette.unshaded(Color(1.0, 0.72, 0.30))
	_rope.visible = false
	add_child(_rope)

	_wings = Node3D.new()
	var wing_material := Palette.unshaded(Color(0.55, 0.85, 1.0, 0.75))
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
	_pylon.name = "Pylon"
	var post := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.16
	cyl.bottom_radius = 0.26
	cyl.height = Augments.MOUNT_OFFSET
	post.mesh = cyl
	post.material_override = Palette.solid(Color(0.58, 0.52, 0.44))
	post.position = Vector3(0.0, Augments.MOUNT_OFFSET * 0.5, 0.0)
	_pylon.add_child(post)
	var plate := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.7
	disc.bottom_radius = 0.7
	disc.height = 0.12
	plate.mesh = disc
	plate.material_override = Palette.solid(Color(1.0, 0.72, 0.30), 1.2)
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
		mark.material_override = Palette.unshaded(style["color"])
		mark.visible = false
		add_child(mark)
		_aim_marks[state_key] = mark


# The pylon node, so presentation can animate the plant and eject without owning it.
func pylon_node() -> Node3D:
	return _pylon


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

	_wings.visible = kit.gliding
	if kit.gliding:
		_wings.global_position = at
		var heading := Vector3(state.velocity.x, 0.0, state.velocity.z)
		if heading.length() > 0.5:
			_wings.global_basis = Basis.looking_at(heading.normalized(), Vector3.UP)


# The shockwave carries the same flatness as the plant: a full thump on flat ground,
# next to nothing when the slam went into a launch.
func _on_slammed(at: Vector3, speed: float, flatness: float) -> void:
	var strength := clampf(speed / 30.0, 0.4, 1.6) * flatness
	events.slammed.emit(at, strength, flatness)
	if strength < 0.05:
		return
	shockwave.emit(at, strength)
	_push_enemies(at, Augments.SLAM_RADIUS, Augments.SLAM_KNOCK * strength, SLAM)


func _on_pylon_planted(at: Vector3, banked_speed: float) -> void:
	events.mounted.emit(at, banked_speed)
	shockwave.emit(at, 0.7)
	_push_enemies(at, Augments.MOUNT_REPEL_RADIUS, Augments.MOUNT_REPEL_KNOCK, "")


func _push_enemies(at: Vector3, radius: float, force: float, kind: String) -> void:
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
		if kind != "":
			struck.emit(enemy, kind, force * falloff)


# The motion the ball had going into a contact: of the velocities recently handed to the
# solver, the one closing fastest on the enemy. The live velocity is already the bounce.
func pre_contact_velocity(toward: Vector3) -> Vector3:
	var best: Vector3 = state.velocity
	var closing := -INF
	for velocity in _rigid.recent_velocities:
		var c: float = velocity.dot(toward)
		if c > closing:
			closing = c
			best = velocity
	return best


func _on_enemy_touched(enemy: Node3D, normal: Vector3) -> void:
	if _crushing.has(enemy.get_instance_id()):
		return
	var to_enemy := enemy.global_position - ball_position()
	var before := pre_contact_velocity(to_enemy.normalized() if to_enemy.length() > 0.01 else Vector3.DOWN)
	var planar := Vector2(before.x, before.z).length()
	var away := Vector3(to_enemy.x, 0.0, to_enemy.z)
	away = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
	if before.y < -STOMP_SPEED and normal.y > 0.3:
		# The one mechanic worth keeping from the orchard: a descending rebound
		# gives the air jump back, so bouncing is a way to keep a line going.
		state.air_actions = 1
		kit.dash_ready = true
		state.impact = maxf(state.impact, -before.y)
		_rigid.set_velocity_now(Vector3(before.x, tuning.f("jump_speed") * 0.95, before.z))
		enemy.knock(away * 0.6 + Vector3.DOWN * 0.2, 7.0)
		shockwave.emit(enemy.global_position, 0.6)
		struck.emit(enemy, STOMP, -before.y)
	elif SpeedTier.of(planar, tuning.f("cruise")) >= SpeedTier.CRUISE:
		enemy.knock(away + Vector3.UP * 0.35, 18.0)
		enemy.flash()
		shockwave.emit(enemy.global_position, 1.0)
		# Planar speed, the same measure punch_now and the crush check use (one query).
		struck.emit(enemy, RAM, planar)
