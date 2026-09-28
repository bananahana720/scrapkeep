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
const Contact := preload("res://src/movement/contact.gd")
const Indicator := preload("res://src/movement/indicator.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const UpgradeTree := preload("res://src/core/upgrade_tree.gd")

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
# A held pull the sprint ignores says so at most this often, not every tick.
const CC_IGNORED_GAP_MS := 250
# The arc slam tags steep faces this close for this long, for a vault.
const FACE_TAG_REACH := 12.0
const FACE_TAG_SECONDS := 2.0
const FACE_TAG_RAYS := 16
# Rivet's skid pushes enemies in this cone ahead of the ball, and each one it reaches
# pays back this much sprint recharge.
const SKID_REACH := 10.0
const SKID_CONE := 0.35
const SKID_REFUND := 0.5
const AIM_CONE_LENGTH := 5.0
const AIM_CONE_HALF := 0.3

signal shockwave(position: Vector3, strength: float)
# A physical contact the ball made, for combat to turn into damage. Local, not the bus:
# the bus fact is enemy_struck, which combat publishes once the hit is resolved.
signal struck(enemy: Node3D, kind: String, force: float)

var tuning
var events
var state := BallState.new()
var kit := AugmentKit.new()
var abilities = kit.abilities
# The run's upgrade picks (upgrade_tree.gd): offered at class select and each workshop.
var tree = kit.tree
# The class this ball is fitted as; null before a run (the kit is then the engineer's).
var class_def: Resource
# The skill-shot geometry, player-owned and drawn in the class colour.
var indicator: Node3D
var intent := Intent.new()
var source = Intent.Source.new()
var drive_basis := Basis.IDENTITY
var spawn_point := Vector3.ZERO
# Presentation turns this off when it draws its own squash and stretch.
var builtin_squash := true
# Asks combat whether a contact would kill outright: (enemy, kind, force) -> bool.
# game.gd wires it to ctx.spawner.would_crush once combat is set up.
var crush_check := Callable()
# Answers the heft the ball plays at; combat wires it to its heft(). 1.0 when unwired.
var heft_of := Callable()
# E's first claim (world's interact system, claims() -> bool): true when an interactable
# in reach takes this press, so it never also plants a pylon.
var interact_claim := Callable()
# The arc slam's tagged faces: [{point, left}].
var face_tags: Array = []
var _cc_ignored_at := {}
# Seconds of crowd-control immunity granted from outside the sprint (Unstoppable).
var immune_left := 0.0
# The landing each smash flavour adds to the shared slam.
var _smashes := {}

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
var _wings_material: StandardMaterial3D
var _pylon: Node3D
var _plate: MeshInstance3D
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
	_rigid.kit_fact.connect(_on_kit_fact)
	tree.events = events
	tree.picked.connect(_on_tree_picked)
	_smashes = {"arc": _smash_arc, "skid": _smash_skid, "demo": _smash_demo}
	events.run_started.connect(func(class_id: String):
		fit_class(ClassDef.by_id(class_id))
		tree.open_checkpoint())
	# The workshop visits after stages 1 to 3 each open one more pick: world's bay opens
	# it on entry, or at the stage's clear when the bay was skipped (world.gd).
	events.stage_entered.connect(func(_stage: int, _retry: bool): abilities.refill())
	events.stage_content_cleared.connect(func(_reason: String): abilities.refill())
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
	indicator = Indicator.new()
	indicator.name = "Indicator"
	add_child(indicator)
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


# Fits the class's movement kit, smash and ability slots. Everyone keeps jump, double
# jump, boost and the smash; only the class's own movement augments are on.
func fit_class(def: Resource) -> void:
	class_def = def
	tree.reset(def.id if def != null else "")
	abilities.fit(class_def)
	_refit()


# A pick lands on the live kit: its slot ops, then the movement kit and smash flavour
# the (maybe swapped) slots name. Nothing else about the slots is reset.
func _on_tree_picked(n: Dictionary) -> void:
	UpgradeTree.apply_pick(abilities, n)
	_refit()


# The movement kit the movement slot's row names, the smash flavour, the class colour.
func _refit() -> void:
	if class_def == null:
		kit.fit(Augments.DEFAULT_MOVEMENT, "")
	else:
		kit.fit(abilities.id_of(AbilityState.MOVEMENT), abilities.id_of(AbilityState.SMASH))
	_paint_effects()


# Everything the player's own action lights (rope, pylon plate, glide vane) glows in the
# class colour: class colour means yours (VISUAL-LANGUAGE section 2).
func _paint_effects() -> void:
	var color := class_color()
	_rope.material_override = Palette.unshaded(color)
	_wings_material.albedo_color = Color(color, 0.75)
	_plate.material_override = Palette.solid(color, 1.2)


func class_color() -> Color:
	return class_def.color if class_def != null else ClassDef.SABLE_COLOR


# A skill-shot record dressed as yours: the class colour and the class's rim ticks.
func yours(shape: Dictionary) -> Dictionary:
	shape["color"] = class_color()
	shape["ticks"] = class_def.shape if class_def != null else "ring"
	return shape


func heft() -> float:
	return float(heft_of.call()) if heft_of.is_valid() else 1.0


# The one door for crowd control: a knock, the Warden's pulse and magnet, Brindle's
# shoves, and wave 3's pits, tethers and nets. Rivet's sprint ignores all of it and
# says so (true means it landed). An interrupting hit force-cancels every charging
# gauge with nothing spent and collapses the indicator; a steady pull (a magnet's tug)
# is still a stop the sprint ignores, but it does not wipe a charge every tick. The
# shove, an acceleration like add_external_accel's, is applied here.
func crowd_control(kind: String, shove := Vector3.ZERO, interrupts := true) -> bool:
	if _frozen:
		return false
	if kit.sprinting or immune_left > 0.0 or (kit.mounted and tree.knob("mount_cc_immune")):
		var now := Time.get_ticks_msec()
		if now - int(_cc_ignored_at.get(kind, -100000)) >= CC_IGNORED_GAP_MS:
			_cc_ignored_at[kind] = now
			events.cc_ignored.emit(kind)
		return false
	if interrupts:
		for id in abilities.cancel_gauges():
			events.gauge_cancelled.emit(id, kind)
		if kit.slingshot.cancel():
			events.gauge_cancelled.emit("slingshot", kind)
		indicator.collapse_all()
	if shove != Vector3.ZERO:
		add_external_accel(shove)
	return true


# Crowd control slides off for this long (Unstoppable's boosted window).
func grant_immunity(seconds: float) -> void:
	immune_left = maxf(immune_left, seconds)


# The stomp and rebound refresh, one rule so they never disagree: one air jump and one
# charge of the class movement ability (for Sable, the last face it kicked).
func refresh_air() -> void:
	state.air_actions = 1
	abilities.grant(AbilityState.MOVEMENT)
	kit.refresh_vault()


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
	_route_interact()
	_read_grammar()
	abilities.tick(delta)
	immune_left = maxf(0.0, immune_left - delta)
	if kit.mounted and tree.knob("mounted_recharge") > 1.0:
		abilities.refund(AbilityState.SPECIAL, delta * (tree.knob("mounted_recharge") - 1.0))
	state.tick_timers(delta)
	if intent.jump_pressed:
		state.jump_buffer = Tuning.JUMP_BUFFER
	_rigid.drive_basis = drive_basis
	state.refresh_tier(tuning.f("cruise"))
	if _was_hooked and not kit.hooked:
		events.grapple_released.emit()
	_was_hooked = kit.hooked
	_recheck_bow()
	_tick_face_tags(delta)
	_mark_slots()


# The slot states the ability bar reads that no spend or gauge sets: the grapple is
# active while hooked, and the smash is an air move, so on the ground it is unavailable.
func _mark_slots() -> void:
	if kit.on(Augments.GRAPPLE):
		abilities.slot(AbilityState.MOVEMENT).active = kit.hooked
	var smash = abilities.slot(AbilityState.SMASH)
	smash.active = kit.slamming or kit.plant_time > 0.0
	smash.available = smash.active or not state.grounded


# RMB is the class movement, except while the special or the slingshot charges: then
# its press cancels the charge and moves nothing. Kest's held throw is not included, or
# holding LMB would swallow her blink. Sable's grapple rides RMB here like the other
# classes' movement.
func _read_grammar() -> void:
	var special = abilities.gauge(AbilityState.SPECIAL)
	if intent.movement_pressed and ((special != null and special.charging) or kit.slingshot.charging):
		intent.movement_pressed = false
		intent.cancel_pressed = true
	if _frozen or not kit.on(Augments.GRAPPLE):
		return
	if intent.movement_pressed and kit.aim.get("state", Augments.AIM_NONE) != Augments.AIM_NONE:
		grapple_to(kit.aim["point"], kit.aim["normal"])
	elif intent.movement_released:
		_fling()
		release_grapple()
	# Rope Anchor: winching up to the wall plants the pylon there.
	if tree.knob("winch_mount") and kit.hooked and intent.reel_held and not kit.mounted \
			and ball_position().distance_to(kit.anchor) <= Augments.MIN_ROPE + 2.5:
		intent.mount_pressed = true


# E is interact everywhere (LOOP-REDESIGN section 9): an interactable in reach takes the
# press, else it stays Sable's mount at a face. Mounted, E always drops you off.
func _route_interact() -> void:
	if intent.mount_pressed and not kit.mounted and interact_claim.is_valid() and interact_claim.call():
		intent.mount_pressed = false
		intent.interact_pressed = true


# Coil Hook: letting go of the rope throws you on along your swing.
func _fling() -> void:
	var fling: float = tree.knob("grapple_fling")
	if not kit.hooked or fling <= 0.0:
		return
	var v: Vector3 = state.velocity
	var dir := v.normalized() if v.length() > 0.5 else -drive_basis.z
	set_velocity_now(v + dir * fling)


func _process(_delta: float) -> void:
	var shown := shown_transform()
	_visual_root.global_position = shown.origin
	_visual_root.global_basis = Basis.IDENTITY
	_update_augment_visuals(shown.origin)
	_update_aim_cones(shown.origin)
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
	if kit.sprinting:
		kit.sprint_left += tree.knob("crush_refund")
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
	_rope.material_override = Palette.unshaded(class_color())
	_rope.visible = false
	add_child(_rope)

	_wings = Node3D.new()
	var wing_material := Palette.unshaded(Color(class_color(), 0.75))
	_wings_material = wing_material
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
	plate.material_override = Palette.solid(class_color(), 1.2)
	_plate = plate
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
# Every class slams the same way; the landing then takes the class's flavour.
func _on_slammed(at: Vector3, speed: float, flatness: float) -> void:
	var strength := clampf(speed / 30.0, 0.4, 1.6) * flatness
	events.slammed.emit(at, strength, flatness)
	if strength >= 0.05:
		shockwave.emit(at, strength)
		_push_enemies(at, Augments.SLAM_RADIUS, Augments.SLAM_KNOCK * strength, SLAM)
	if _smashes.has(kit.smash_flavour):
		_smashes[kit.smash_flavour].call(at, speed)


func _smash_arc(at: Vector3, _speed: float) -> void:
	events.arc_slammed.emit(at, _tag_faces(at))


func _smash_skid(at: Vector3, speed: float) -> void:
	events.skid_smashed.emit(at, _skid_push(at, clampf(speed / 30.0, 0.4, 1.6)))


func _smash_demo(at: Vector3, _speed: float) -> void:
	events.demo_slammed.emit(at)


# Sable's arc slam marks every steep face within FACE_TAG_REACH for a vault.
func _tag_faces(at: Vector3) -> int:
	face_tags.clear()
	var space: PhysicsDirectSpaceState3D = _rigid.get_world_3d().direct_space_state
	var from := at + Vector3.UP * 1.0
	for i in FACE_TAG_RAYS:
		var angle := TAU * float(i) / float(FACE_TAG_RAYS)
		var dir := Vector3(cos(angle), 0.0, sin(angle))
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + dir * FACE_TAG_REACH, Augments.WORLD_MASK))
		if hit.is_empty() or absf((hit["normal"] as Vector3).y) >= Augments.FACE_MAX_TILT:
			continue
		face_tags.append({"point": hit["position"] + (hit["normal"] as Vector3) * 0.1, "left": FACE_TAG_SECONDS})
	return face_tags.size()


func _tick_face_tags(delta: float) -> void:
	for tag in face_tags:
		tag["left"] -= delta
	face_tags = face_tags.filter(func(tag): return tag["left"] > 0.0)


# Rivet's skid knocks what is ahead of the ball forward and refunds sprint per hit.
func _skid_push(at: Vector3, strength: float) -> int:
	var ahead := planar_velocity()
	ahead = ahead.normalized() if ahead.length() > 0.5 else Vector3.FORWARD
	var hits := 0
	for enemy in get_tree().get_nodes_in_group("enemy"):
		var to: Vector3 = enemy.global_position - at
		to.y = 0.0
		if to.length() > SKID_REACH or (to.length() > 1.5 and to.normalized().dot(ahead) < SKID_CONE):
			continue
		var falloff := 1.0 - to.length() / SKID_REACH
		enemy.knock(ahead + Vector3.UP * 0.3, Augments.SLAM_KNOCK * strength * falloff * tree.knob("skid_pins"))
		enemy.flash()
		struck.emit(enemy, SLAM, Augments.SLAM_KNOCK * strength * falloff)
		abilities.refund(AbilityState.MOVEMENT, SKID_REFUND)
		hits += 1
	return hits


# The vault and slingshot aim cones and the arc slam's face tags, in the class colour.
func _update_aim_cones(at: Vector3) -> void:
	if not kit.vault_aim.is_empty():
		indicator.set_shape("vault", yours({"kind": "cone", "apex": at, "dir": kit.vault_aim["dir"],
			"length": AIM_CONE_LENGTH, "half_angle": AIM_CONE_HALF}))
	else:
		indicator.clear("vault")
	if kit.mounted and not kit.slingshot_aim.is_empty():
		var fill: float = kit.slingshot_aim["fill"]
		indicator.set_shape("slingshot", yours({"kind": "cone", "apex": at, "dir": kit.slingshot_aim["dir"],
			"length": AIM_CONE_LENGTH * (1.0 + fill), "half_angle": AIM_CONE_HALF, "fill": fill}))
	else:
		indicator.clear("slingshot")
	if face_tags.is_empty():
		indicator.clear("faces")
	else:
		indicator.set_shape("faces", yours({"kind": "marks", "points": face_tags.map(func(tag): return tag["point"])}))


# A kit rule's fact goes on the bus; a dropped slingshot charge also collapses its cone.
func _on_kit_fact(kind: String, args: Array) -> void:
	if kind == "gauge_cancelled":
		indicator.collapse("slingshot")
	if kind == "vault_kicked" and tree.knob("vault_tags"):
		_tag_faces(ball_position())
	events.callv("emit_signal", [kind] + args)


func _on_pylon_planted(at: Vector3, banked_speed: float) -> void:
	events.mounted.emit(at, banked_speed)
	shockwave.emit(at, 0.7)
	_push_enemies(at, Augments.MOUNT_REPEL_RADIUS, Augments.MOUNT_REPEL_KNOCK * tree.knob("plant_repel"), "")


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
		refresh_air()
		state.impact = maxf(state.impact, -before.y)
		_rigid.set_velocity_now(Vector3(before.x, tuning.f("jump_speed") * 0.95, before.z))
		enemy.knock(away * 0.6 + Vector3.DOWN * 0.2, 7.0)
		shockwave.emit(enemy.global_position, 0.6)
		struck.emit(enemy, STOMP, -before.y)
	elif _rebounds_off(enemy) and before.dot(normal) < -Contact.MIN_CLOSING:
		_rebound(enemy, normal, before, planar, away)
	elif SpeedTier.of(planar, tuning.f("cruise")) >= SpeedTier.CRUISE:
		enemy.knock(away + Vector3.UP * 0.35, 18.0)
		enemy.flash()
		shockwave.emit(enemy.global_position, 1.0)
		# Planar speed, the same measure punch_now and the crush check use (one query).
		struck.emit(enemy, RAM, planar)


# Only a body that says what it weighs can bounce you; a boss piece without a weight
# keeps the plain ram.
func _rebounds_off(enemy: Node3D) -> bool:
	var weight = enemy.get("weight")
	if kit.sprinting and tree.knob("sprint_no_rebound"):
		return false
	return weight != null and Contact.rebounds(float(weight), heft(), kit.sprinting)


# The bowling-ball rebound off something at least your weight: the incoming velocity
# reflected with restitution, one refresh, and the ram still lands if you were rolling
# fast enough for one.
func _rebound(enemy: Node3D, normal: Vector3, before: Vector3, planar: float, away: Vector3) -> void:
	var out := Contact.rebound_velocity(before, normal, tuning.f("jump_speed"))
	_rigid.set_velocity_now(out)
	refresh_air()
	state.impact = maxf(state.impact, -before.dot(normal))
	enemy.knock(away + Vector3.UP * 0.2, 6.0)
	enemy.flash()
	shockwave.emit(enemy.global_position, 0.8)
	if SpeedTier.of(planar, tuning.f("cruise")) >= SpeedTier.CRUISE:
		struck.emit(enemy, RAM, planar)
	events.enemy_rebounded.emit(enemy, out.length())
