extends SceneTree

const ChaseCamera := preload("res://src/movement/chase_camera.gd")
const BallState := preload("res://src/movement/ball_state.gd")
const T := preload("res://tests/support/t.gd")
const Requisition := preload("res://src/boss/requisition.gd")
const RigidBall := preload("res://src/movement/rigid_ball.gd")
const Warden := preload("res://src/combat/warden.gd")

# W1-14 / PF-06: with a wall close behind the ball the arm shortens until the ball fills the lens.
# The camera rises over the ball instead, keeps the player's aim, and goes back down when the wall
# is gone. Real boxes on layer 1, the rig stepped one physics frame at a time. After snap(FORWARD)
# the camera sits on the +Z side of the ball, so the wall goes there. T1-T6: a tall wall. L1: a low
# wall whose top the lifted arm clears (the lift must not read its own result and cycle). R1-R2: a
# low roof over the wall, where lifting would shorten the arm further, so the camera must not lift
# and must come back when the wall goes. U1: a rig whose physics never ticked is not lifted. F1: open
# ground is not a wall. P1-P2: a wall that is there for 9 frames does not throw the lens up.

const DT := 1.0 / 60.0

var _t = T.new("camera_tight_test")


class Tuning:
	func f(_key: String) -> float:
		return 20.0


class Target:
	var state := BallState.new()

	func shown_position() -> Vector3:
		return Vector3.ZERO

	func ball_position() -> Vector3:
		return Vector3.ZERO


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	await _tall_wall()
	await _low_wall()
	await _roof()
	await _floor()
	await _pillar()
	await _unstepped()
	await _ship()
	await _grunt()
	await _warden()
	await _ball_in_drum()
	await _lift_in_drum()
	await _touching_drum()
	await _touching_ship()
	await _wall_touching()
	_layers()
	quit(_t.verdict())


func _rig() -> ChaseCamera:
	var cam := ChaseCamera.new()
	root.add_child(cam)
	cam.setup(Target.new(), Tuning.new())
	cam.snap(Vector3.FORWARD)
	return cam


func _box(size: Vector3, at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var piece := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	piece.shape = shape
	body.add_child(piece)
	body.collision_layer = 1
	root.add_child(body)
	body.global_position = at
	return body


func _tall_wall() -> void:
	var cam := _rig()
	await _settle(cam, 90)
	var open_pitch: float = cam.arm.rotation.x
	var open_rise := _rise(cam)
	var aim_open: Vector3 = cam.aim_forward()
	_t.check("T1 in the open the arm is untouched", absf(open_pitch - cam.pitch) < 0.001, "arm pitch %.3f, player pitch %.3f" % [open_pitch, cam.pitch])
	var wall := _box(Vector3(40.0, 40.0, 1.0), Vector3(0.0, 0.0, 2.75))
	await _settle(cam, 120)
	var hit: float = cam.arm.get_hit_length()
	_t.check("T2 the wall shortens the arm under 4 m", hit < 4.0, "hit length %.2f" % hit)
	_t.check("T3 the lens rises over the ball", _rise(cam) > open_rise + 0.2, "elevation %.2f rad against %.2f in the open" % [_rise(cam), open_rise])
	_t.check("T4 the arm tips up, not the player's pitch", cam.arm.rotation.x < open_pitch - 0.1 and absf(cam.pitch - (-0.30)) < 0.001, "arm %.3f, open %.3f, pitch %.3f" % [cam.arm.rotation.x, open_pitch, cam.pitch])
	_t.check("T5 the aim stays the player's", cam.aim_forward().is_equal_approx(aim_open), "open %s tight %s" % [aim_open, cam.aim_forward()])
	wall.free()
	await _settle(cam, 240)
	_t.check("T6 the lens comes back down when the wall goes", absf(_rise(cam) - open_rise) < 0.02, "elevation %.2f rad, open %.2f" % [_rise(cam), open_rise])
	cam.free()


# A wall whose top is 0.8 m above the pivot: the lifted arm clears it, so the length it reads would
# jump to full and drop the lift again unless the lift reads an arm of its own.
func _low_wall() -> void:
	var cam := _rig()
	var wall := _box(Vector3(40.0, 4.0, 1.0), Vector3(0.0, -0.4, 2.75))
	await _settle(cam, 120)
	var hit_low := INF
	var hit_high := 0.0
	var rot_low := INF
	var rot_high := -INF
	for i in 60:
		cam._process(DT)
		await physics_frame
		var hit: float = cam.arm.get_hit_length()
		hit_low = minf(hit_low, hit)
		hit_high = maxf(hit_high, hit)
		rot_low = minf(rot_low, cam.arm.rotation.x)
		rot_high = maxf(rot_high, cam.arm.rotation.x)
	_t.check("L1 over a low wall the arm length holds steady", hit_high - hit_low < 0.2, "hit length %.2f to %.2f" % [hit_low, hit_high])
	_t.check("L1 over a low wall the arm angle holds steady", rot_high - rot_low < 0.02, "arm angle %.3f to %.3f" % [rot_low, rot_high])
	wall.free()
	cam.free()


func _roof() -> void:
	var cam := _rig()
	var roof := _box(Vector3(40.0, 1.0, 40.0), Vector3(0.0, 2.9, 0.0))
	await _settle(cam, 90)
	var roof_pitch: float = cam.arm.rotation.x
	var roof_rise := _rise(cam)
	var wall := _box(Vector3(40.0, 40.0, 1.0), Vector3(0.0, 0.0, 2.75))
	await _settle(cam, 60)
	_t.check("R1 under a roof the lift would shorten the arm, so the arm is not lifted", absf(cam.arm.rotation.x - roof_pitch) < 0.02, "arm %.3f, with the roof alone %.3f" % [cam.arm.rotation.x, roof_pitch])
	wall.free()
	await _settle(cam, 240)
	_t.check("R2 the lens is where the roof alone left it after the wall goes", absf(_rise(cam) - roof_rise) < 0.02, "elevation %.2f rad, roof alone %.2f" % [_rise(cam), roof_rise])
	roof.free()
	cam.free()


# Looking up on open ground the arm points at the floor and shortens, as it always did. A floor is not
# a wall: no lift, and the arm angle is the player's pitch plus the bias, which is none here.
func _floor() -> void:
	var cam := _rig()
	var ground := _box(Vector3(40.0, 1.0, 40.0), Vector3(0.0, -1.5, 0.0))
	cam.pitch = 0.5
	await _settle(cam, 120)
	_t.check("F1 looking up over open ground the arm is not lifted", absf(cam.arm.rotation.x - 0.5) < 0.001, "arm %.3f, pitch 0.500, hit length %.2f" % [cam.arm.rotation.x, cam.arm.get_hit_length()])
	ground.free()
	cam.free()


# A pillar pass: a wall behind the ball for 9 frames (0.15 s), then gone. The lens must not lurch.
func _pillar() -> void:
	var cam := _rig()
	await _settle(cam, 90)
	var open_y: float = cam.cam.global_position.y
	var wall := _box(Vector3(40.0, 40.0, 1.0), Vector3(0.0, 0.0, 2.75))
	var peak := -INF
	var low := INF
	for i in 9:
		cam._process(DT)
		await physics_frame
		peak = maxf(peak, cam.cam.global_position.y - open_y)
		low = minf(low, cam.cam.global_position.y - open_y)
	wall.free()
	var back := -1
	for i in 240:
		cam._process(DT)
		await physics_frame
		peak = maxf(peak, cam.cam.global_position.y - open_y)
		low = minf(low, cam.cam.global_position.y - open_y)
		if back < 0 and absf(cam.cam.global_position.y - open_y) < 0.05:
			back = i + 1
	# The lens may dip as the arm shortens (the arm's own behaviour, 1.4 m) but must never rise past its
	# open height by more than 0.3 m: under a third of the ball's 1 m radius, so it reads as the camera
	# settling, not lurching up as the wall goes. Before the lift dropped at once it rose 1.9 m.
	_t.check("P1 a pillar pass never lifts the lens over its open height", peak < 0.3, "peak rise %.2f m, lowest %.2f m" % [peak, low])
	_t.check("P2 the lens is back within 0.05 m of open soon after the wall goes", back > 0 and back <= 40, "back after %d frames" % back)
	cam.free()


# camera_profiles_test never ticks physics; the arm there has read no hit yet and must not lift.
func _unstepped() -> void:
	var cam := _rig()
	for i in 60:
		cam._process(DT)
	_t.check("U1 a rig that never ticked physics is not lifted", absf(cam.arm.rotation.x - cam.pitch) < 0.001, "arm %.3f, pitch %.3f" % [cam.arm.rotation.x, cam.pitch])
	cam.free()


func _settle(cam, frames: int) -> void:
	for i in frames:
		cam._process(DT)
		await physics_frame


# The lens's elevation angle above the point it follows (the ball plus 0.8 m).
func _rise(cam) -> float:
	var from: Vector3 = cam.cam.global_position - cam.global_position
	return atan2(from.y, Vector2(from.x, from.z).length())


# PF-06 (film 124): the lens inside Brindle's hull. The ship is built as boss.gd builds it, 10 m behind
# the ball, and its drawn boxes (not the hidden 9 x 5 x 14 placeholder) must stop the arm.
func _ship() -> void:
	var cam := _rig()
	await _settle(cam, 90)
	var open_rise := _rise(cam)
	var ship := Requisition.new()
	root.add_child(ship)
	ship.build(null)
	ship.move_to(Vector3(0.0, -1.0, 10.0), Vector3.FORWARD)
	await _settle(cam, 120)
	var boxes: Array = ship.drawn_boxes()
	var hit: float = cam.arm.get_hit_length()
	var lens: Vector3 = cam.cam.global_position
	var inside := ""
	for pair in boxes:
		var local: Vector3 = (pair[0] as Transform3D).affine_inverse() * lens
		if (pair[1] as AABB).has_point(local):
			inside = "%s" % [pair]
	_t.check("B0 the ship's model loaded, so B1 does not test the primitive fallback", ship.model != null and boxes.size() > 0, "%d boxes, model loaded: %s" % [boxes.size(), ship.model != null])
	_t.check("B1 the lens is outside every drawn box and the arm is cut short", inside == "" and hit < 7.5 and boxes.size() > 0, "hit length %.2f, lens %s, inside box %s" % [hit, lens, inside])
	_t.check("B2 the wall lift raises the lens over the ship", _rise(cam) > open_rise + 0.2, "elevation %.2f rad against %.2f" % [_rise(cam), open_rise])
	ship.free()
	cam.free()


# Negative control: a tall enemy-layer (3) wall on the arm's line is a grunt, not a wall. Red if the arm's
# mask gains layer 3 (the arm would shorten to under 4 m here).
func _grunt() -> void:
	var cam := _rig()
	await _settle(cam, 90)
	var open_hit: float = cam.arm.get_hit_length()
	var open_rise := _rise(cam)
	var grunt := _box(Vector3(40.0, 40.0, 1.0), Vector3(0.0, 0.0, 2.75))
	grunt.collision_layer = 4
	await _settle(cam, 90)
	var hit: float = cam.arm.get_hit_length()
	_t.check("B3 a layer-3 wall on the arm's line does not shorten the arm", absf(hit - open_hit) < 0.2, "hit length %.2f, open %.2f" % [hit, open_hit])
	_t.check("B3 a layer-3 wall does not lift the lens", absf(_rise(cam) - open_rise) < 0.02, "elevation %.2f rad, open %.2f" % [_rise(cam), open_rise])
	grunt.free()
	cam.free()


func _dam() -> Node3D:
	var warden = Warden.new()
	var world := Node3D.new()
	root.add_child(world)
	world.add_child(warden)
	warden.setup(Target.new(), Terrain.new(), world, func(): return true, 1.0, {"family": "reactor", "mounting": "dam_face"})
	warden.set_physics_process(false)
	warden.set_process(false)
	return warden


func _holds_drawn(warden: Node3D, shell: Node3D) -> bool:
	var drum: CylinderShape3D = shell.get_child(0).shape
	var inverse := warden.global_transform.affine_inverse()
	var count := 0
	for view in warden.find_children("*", "MeshInstance3D", true, false):
		var mesh := view as MeshInstance3D
		if mesh.mesh == null or mesh.layers == 0 or not mesh.is_visible_in_tree() or mesh.get_parent().name == "Badge":
			continue
		var local: AABB = inverse * mesh.global_transform * mesh.get_aabb()
		for corner in 8:
			var at: Vector3 = local.get_endpoint(corner) - shell.position
			if maxf(absf(at.x), absf(at.z)) > drum.radius + 0.01 or absf(at.y) > drum.height * 0.5 + 0.01:
				return false
		count += 1
	return count > 0


func _shell(warden: Node3D) -> StaticBody3D:
	for child in warden.get_children():
		if child is PhysicsBody3D and (child.collision_layer & 8) != 0:
			return child
	return null


class Terrain:
	func height(_x: float, _z: float) -> float:
		return 0.0


func _warden() -> void:
	var warden := _dam()
	var shell := _shell(warden)
	var cyl: CylinderShape3D = null
	if shell != null:
		cyl = shell.get_child(0).shape as CylinderShape3D
	_t.check("W1 the primitive Warden has a camera-only body at its jaws' size", cyl != null and cyl.radius >= 3.4 and cyl.height >= 7.0, "shell %s, radius %s, height %s" % [shell, cyl.radius if cyl else -1, cyl.height if cyl else -1])
	if shell == null:
		warden.free()
		return
	_t.check("W1 the shell holds every drawn primitive mesh", _holds_drawn(warden, shell), "")
	var contact: CylinderShape3D = null
	for child in warden.get_children():
		if child is CollisionShape3D:
			contact = child.shape as CylinderShape3D
	_t.check("G1 the contact collider is still the 2.8 m cylinder", contact != null and absf(contact.radius - Warden.RADIUS) < 0.001 and absf(contact.height - Warden.HALF_HEIGHT * 2.0) < 0.001, "%s" % [contact.radius if contact else null])
	var cam := _rig()
	# The drum's centre 4 m behind the pivot.
	var centre_y: float = shell.global_position.y - warden.global_position.y
	warden.global_position = Vector3(0.0, 0.8 - centre_y, 4.0)
	await _settle(cam, 120)
	var hit: float = cam.arm.get_hit_length()
	var lens: Vector3 = cam.cam.global_position
	var rel: Vector3 = lens - shell.global_position
	var in_drum := Vector2(rel.x, rel.z).length() < cyl.radius and absf(rel.y) < cyl.height * 0.5
	_t.check("W1 the lens is outside the drum", not in_drum and hit < 4.0, "hit length %.2f, lens %s, shell at %s" % [hit, lens, shell.global_position])
	cam.free()
	warden.free()


# W2 stands alone, so it cannot hide behind a missing shell. It guards that the arm stays long with the
# ball inside the drum; it is green with or without any ignore code (Jolt skips a shape a cast starts in).
func _ball_in_drum() -> void:
	var warden := _dam()
	var shell := _shell(warden)
	var cam := _rig()
	var centre_y := 0.0
	if shell != null:
		centre_y = shell.global_position.y - warden.global_position.y
	# The ball (the origin) inside the drum: the arm must not collapse onto it.
	warden.global_position = Vector3(0.0, 0.8 - centre_y, 0.0)
	await _settle(cam, 60)
	var inside_hit: float = cam.arm.get_hit_length()
	_t.check("W2 with the ball inside the drum the arm keeps over half its length", inside_hit >= 4.0, "hit length %.2f" % inside_hit)
	# 0.1 m inside the face the arm points out of: the arm's own shape already overlaps the wall.
	warden.global_position = Vector3(0.0, 0.8 - centre_y, -3.2)
	await _settle(cam, 60)
	var edge_hit: float = cam.arm.get_hit_length()
	_t.check("W2 with the ball just inside the drum's face the arm keeps over half its length", edge_hit >= 4.0, "hit length %.2f" % edge_hit)
	warden.global_position = Vector3(0.0, 0.8 - centre_y, 4.0)
	await _settle(cam, 60)
	var out_hit: float = cam.arm.get_hit_length()
	_t.check("W2 once the ball is out the drum shortens the arm again", out_hit < 4.0, "hit length %.2f" % out_hit)
	cam.free()
	warden.free()


# D1: the lift probe reads get_rest_info at the first contact. With the ball inside a Warden's drum and a world
# wall behind it, also inside the drum, the lift must be what the same wall gives alone.
func _lift_in_drum() -> void:
	var cam := _rig()
	var wall := _box(Vector3(40.0, 40.0, 1.0), Vector3(0.0, 0.0, 2.75))
	await _settle(cam, 120)
	var alone := _rise(cam)
	var alone_hit: float = cam.arm.get_hit_length()
	var warden := _dam()
	var shell := _shell(warden)
	var centre_y: float = shell.global_position.y - warden.global_position.y
	warden.global_position = Vector3(0.0, 0.8 - centre_y, 0.0)
	await _settle(cam, 120)
	_t.check("D1 a wall inside a Warden's drum lifts the lens as the wall alone does", absf(_rise(cam) - alone) < 0.02 and alone > 0.5, "elevation %.3f rad in the drum, %.3f alone; hit length %.2f, %.2f alone" % [_rise(cam), alone, cam.arm.get_hit_length(), alone_hit])
	warden.free()
	wall.free()
	cam.free()


# T-cases: the ball touching a Warden. Its contact cylinder is 2.8 m and the ball 1 m, so the ball's centre
# is 3.8 m out, and the arm's 0.3 m probe already overlaps a drum wider than 3.5 m. The cast must still stop
# at the drum, not run its full length through it. The drum is the park reactor's fitted size (3.77 m by
# 10.35 m) and the primitive look's own.
func _touching_drum() -> void:
	for drum in [[3.77, 10.35], [0.0, 0.0]]:
		for dist in [3.85, 3.80, 4.05]:
			var cam := _rig()
			var warden := _dam()
			if drum[0] > 0.0:
				warden.get_node("CameraShell").free()
				var shell := ChaseCamera.camera_body()
				shell.name = "CameraShell"
				var shape := CollisionShape3D.new()
				var cylinder := CylinderShape3D.new()
				cylinder.radius = drum[0]
				cylinder.height = drum[1]
				shape.shape = cylinder
				shell.add_child(shape)
				warden.add_child(shell)
			var body: Node3D = _shell(warden)
			var cyl: CylinderShape3D = body.get_child(0).shape
			var label := "r %.2f at %.2f m" % [cyl.radius, dist]
			var rise_y: float = 0.8 - body.position.y
			warden.global_position = Vector3(0.0, rise_y, dist)
			await _settle(cam, 120)
			var lens: Vector3 = cam.cam.global_position
			var rel: Vector3 = lens - body.global_position
			var in_drum := Vector2(rel.x, rel.z).length() < cyl.radius and absf(rel.y) < cyl.height * 0.5
			var crossed := false
			for i in range(1, 20):
				var at: Vector3 = (cam.global_position.lerp(lens, i / 20.0)) - body.global_position
				if Vector2(at.x, at.z).length() < cyl.radius - 0.05 and absf(at.y) < cyl.height * 0.5:
					crossed = true
			_t.check("T1 touching a Warden (%s) the lens is outside its drum" % label, not in_drum, "lens %s, drum at %s, hit length %.2f" % [lens, body.global_position, cam.arm.get_hit_length()])
			_t.check("T2 touching a Warden (%s) the drum is not between the ball and the lens" % label, not crossed, "hit length %.2f, lens %s" % [cam.arm.get_hit_length(), lens])
			warden.free()
			cam.free()
	# The far side: the ball touches the Warden, the lens trails away from it, and keeps its full arm.
	var cam := _rig()
	var warden := _dam()
	var body: Node3D = _shell(warden)
	warden.global_position = Vector3(0.0, 0.8 - body.position.y, -3.85)
	await _settle(cam, 120)
	_t.check("T3 touching a Warden with the lens on the far side keeps the full arm", cam.arm.get_hit_length() > 7.0, "hit length %.2f" % cam.arm.get_hit_length())
	warden.free()
	cam.free()


# T4: the ball touching Brindle's hull (its contact box is the hull's 14 m length, the ball 1 m out), the arm
# pointing through the ship. No drawn box may hold the lens or sit between the pivot and the lens.
func _touching_ship() -> void:
	for pose in [[Vector3(0.0, -1.0, 8.0), Vector3.FORWARD, "end"], [Vector3(0.0, -1.0, 5.5), Vector3.RIGHT, "side"]]:
		var cam := _rig()
		var ship := Requisition.new()
		root.add_child(ship)
		ship.build(null)
		ship.move_to(pose[0], pose[1])
		await _settle(cam, 120)
		var lens: Vector3 = cam.cam.global_position
		var held := ""
		for pair in ship.drawn_boxes():
			for i in range(0, 21):
				var local: Vector3 = (pair[0] as Transform3D).affine_inverse() * cam.global_position.lerp(lens, i / 20.0)
				if (pair[1] as AABB).has_point(local):
					held = "%s at step %d" % [pair[1], i]
		_t.check("T4 touching the hull's %s no drawn box holds the lens or lies between it and the ball" % pose[2], held == "", "hit length %.2f, lens %s, box %s" % [cam.arm.get_hit_length(), lens, held])
		ship.free()
		cam.free()


# N1: a camera-only face the probe does not reach into leaves what a layer-1 wall at that distance leaves, so the
# two cannot drift apart. A face closer than the probe's 0.3 m cannot be compared with a layer-1 wall: the cast
# starts inside it and skips it, which is the fault; there the arm is none and the lens sits on the ball (T1).
func _wall_touching() -> void:
	for face in [0.4, 1.0]:
		var cam := _rig()
		var wall := _box(Vector3(40.0, 40.0, 1.0), Vector3(0.0, 0.0, face + 0.5))
		await _settle(cam, 120)
		var wall_hit: float = cam.arm.get_hit_length()
		var wall_rise := _rise(cam)
		var wall_lens: Vector3 = cam.cam.global_position
		wall.free()
		cam.free()
		cam = _rig()
		var camera_wall := ChaseCamera.camera_body()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(40.0, 40.0, 1.0)
		shape.shape = box
		camera_wall.add_child(shape)
		root.add_child(camera_wall)
		camera_wall.global_position = Vector3(0.0, 0.0, face + 0.5)
		await _settle(cam, 120)
		var lens: Vector3 = cam.cam.global_position
		_t.check("N1 a camera-only face %.1f m behind the ball acts as a layer-1 wall there" % face, absf(cam.arm.get_hit_length() - wall_hit) < 0.05 and absf(_rise(cam) - wall_rise) < 0.02 and lens.distance_to(wall_lens) < 0.05, "camera body: hit %.3f rise %.3f lens %s; layer-1 wall: hit %.3f rise %.3f lens %s" % [cam.arm.get_hit_length(), _rise(cam), lens, wall_hit, wall_rise, wall_lens])
		camera_wall.free()
		cam.free()


# The camera layer must not have changed any contact: the ball, every enemy and the Warden.
func _layers() -> void:
	var warden := _dam()
	_t.check("G1 the Warden is on layer 3 only and masks the world", warden.collision_layer == 4 and warden.collision_mask == 1, "layer %d mask %d" % [warden.collision_layer, warden.collision_mask])
	var shell := _shell(warden)
	_t.check("G1 the camera shell masks nothing and is on layer 4 only", shell != null and shell.collision_mask == 0 and shell.collision_layer == 8, "")
	warden.free()
	var ship := Requisition.new()
	root.add_child(ship)
	ship.build(null)
	_t.check("G1 the ship's hull piece is still on layer 3 with no mask", ship.hull.collision_layer == 4 and ship.hull.collision_mask == 0, "layer %d mask %d" % [ship.hull.collision_layer, ship.hull.collision_mask])
	ship.free()
	var ball := RigidBall.new()
	root.add_child(ball)
	ball.setup(Tuning.new(), BallState.new())
	_t.check("G1 the ball is on layer 2 and masks layers 1 and 3 only", ball.collision_layer == 2 and ball.collision_mask == 5, "layer %d mask %d" % [ball.collision_layer, ball.collision_mask])
	ball.free()
