extends SceneTree

# Rule (ISLE-TIP and PW1-TETHER, Andrew 2026-10-16; LANDMARK-CARDS.md card 5, port note P5): park_islands' Hanging
# Isle takes the tilt and sink the stage-5 hand's driver publishes (warden_mind.gd), about its pivot. A 10 degree tilt
# moves the tip by the driver's own swing (about 20.5 m across, away from the ball) and the sink lowers it; with no hand
# it rests. The tip's collider is an AnimatableBody3D on the world layer that rides the isle, joins the harpoon anchor
# groups and keeps a bite on the moving point (its anchor_point and anchor_velocity). The tether runs from the tip to the
# hand's grip in every pose, stretching when the lens drops, and hangs at rest with no hand. The probe: every ground
# point within the landmark's reach_m that holds the hand inside the rope at a lockable pitch (chase_camera.gd 0.55 rad
# plus the 10 degree lock cone) keeps a clear sight line to the hand with the tip, the isle and the tether present, at
# rest, tilted toward eight headings and in the falter; there is at least one such point, and a ray up from the hand
# hits the tip in every pose (the probe's positive control: the colliders are live). The tether has no collider.

const T := preload("res://tests/support/t.gd")
const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const ParkGraphTool := preload("res://tools/park_graph.gd")
const Terrain := preload("res://src/world/terrain.gd")
const WardenMind := preload("res://src/combat/warden_mind.gd")
const IsleRig := preload("res://src/world/park/isle_rig.gd")
const Augments := preload("res://src/movement/augments.gd")
const Tuning := preload("res://src/movement/tuning.gd")

const MAP := "park_islands"
const ROPE_M := 45.0
const PITCH_MAX := 0.55
const LOCK_CONE_DEG := 10.0
const GRID_M := 4.0
const SWING_BAND := Vector2(20.0, 21.0)


class Hand:
	extends Node3D
	var mounting := "under_island"
	var mount_driver = WardenMind.new()
	var home := Vector3.ZERO

	# Where the driver puts the hand for its published pose (warden_mind.gd _island).
	func follow() -> void:
		var d = mount_driver
		var angle := deg_to_rad(float(d.island_tilt_deg))
		var swing: Vector3 = d.tilt_away * WardenMind.PIVOT_HEIGHT * sin(angle) + Vector3.UP * WardenMind.PIVOT_HEIGHT * (1.0 - cos(angle))
		global_position = home + swing + Vector3.DOWN * float(d.lens_drop)


var t := T.new("isle_tip_test")
var _park: Dictionary
var _ground: Callable


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_park = JSON.parse_string(FileAccess.get_file_as_string("res://src/world/park/%s.json" % MAP))
	var bake := ParkGraphTool.load_bake("res://assets/park/" + MAP)
	_ground = Terrain._park_floor_at.bind(bake["ground"], bake["holes"], bake["under"])
	var parent := Node3D.new()
	root.add_child(parent)
	var node: Node3D = ParkRecipes.place_landmark(_park, parent, _ground)
	var rig = node.get_node_or_null("IsleRig") if node != null else null
	if not t.check("the isle carries its rig", rig != null):
		quit(t.verdict())
		return
	var tip: AnimatableBody3D = node.get_node_or_null("IsleTip")
	if not t.check("the isle's tip is an AnimatableBody3D", tip != null, "proxy %s" % node.get_meta("landmark_proxy", false)):
		quit(t.verdict())
		return
	t.check("the tip is world-layer and a moving anchor", tip.collision_layer == Augments.WORLD_MASK
		and tip.is_in_group(Augments.ANCHOR_GROUP) and tip.is_in_group(Augments.WORLD_ANCHOR_GROUP)
		and Augments.anchor_line(tip))
	t.check("the tether is the GLB's view", rig.tether != null and rig.tether.name == IsleRig.TETHER)
	t.check("the tether has no collider", rig.tether != null and rig.tether.find_children("*", "CollisionObject3D", true, false).is_empty())
	var rest_tip: Vector3 = rig.tip_point()
	var anchor := _v3(_park["landmark"]["warden"]["anchor"])
	t.near("the tip rests PIVOT_HEIGHT under the pivot", rest_tip.y, node.position.y - WardenMind.PIVOT_HEIGHT, 0.01)
	t.check("the hand hangs under the tip", rest_tip.y > anchor.y, "tip %.1f, hand %.1f" % [rest_tip.y, anchor.y])
	await physics_frame
	_tether("no hand: the tether hangs at rest", rig, rest_tip + Vector3.DOWN * IsleRig.TETHER_LENGTH)

	var hand := Hand.new()
	hand.home = anchor
	parent.add_child(hand)
	hand.global_position = anchor
	hand.add_to_group(Augments.ANCHOR_GROUP)
	t.check("the rig finds the hand", IsleRig.find_hand(self, node.global_position) == hand)
	rig.warden = hand
	var driver = hand.mount_driver
	await physics_frame
	_tether("at rest: the tether reaches the grip", rig, anchor + IsleRig.GRIP)

	# A tilt away along +x: the tip moves by the driver's swing.
	driver.tilt_away = Vector3.RIGHT
	driver.island_tilt_deg = WardenMind.TILT_DEGREES
	hand.follow()
	rig.pose(driver)
	var moved: Vector3 = rig.tip_point() - rest_tip
	var swing := Vector3.RIGHT * WardenMind.PIVOT_HEIGHT * sin(deg_to_rad(10.0)) + Vector3.UP * WardenMind.PIVOT_HEIGHT * (1.0 - cos(deg_to_rad(10.0)))
	t.check("a 10 degree tilt moves the tip by the hand's swing", moved.distance_to(swing) < 0.01, "moved %s, swing %s" % [moved, swing])
	var across := Vector2(moved.x, moved.z).length()
	t.check("the tip swings 20 to 21 m away", across >= SWING_BAND.x and across <= SWING_BAND.y and moved.x > 0.0, "%.2f m" % across)
	_tether("tilted: the tether reaches the grip", rig, hand.global_position + IsleRig.GRIP)

	# The moving anchor: a bite on the tip rides it.
	driver.island_tilt_deg = 0.0
	hand.follow()
	rig.pose(driver)
	await physics_frame
	await physics_frame
	var bite := rest_tip + Vector3(0.0, 6.0, 0.0)
	var start: Vector3 = tip.anchor_point(bite, bite + Vector3(0.0, -30.0, 10.0))
	t.check("a bite holds where it bit", start.distance_to(bite) < 0.01)
	var at_bite := tip.global_transform
	driver.island_tilt_deg = 4.0
	hand.follow()
	rig.pose(driver)
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	tip.track(dt)
	var ridden: Vector3 = tip.anchor_point(start)
	var expect: Vector3 = tip.global_transform * (at_bite.affine_inverse() * bite)
	t.check("the bite rides the tilted tip", ridden.distance_to(expect) < 0.01 and ridden.distance_to(bite) > 1.0,
		"ridden %s from %s" % [ridden, bite])
	t.check("the anchor reports the bite's speed", tip.anchor_velocity().distance_to((ridden - bite) / dt) < 0.01,
		"%s" % tip.anchor_velocity())

	# The falter: island down 2 m, lens down 10 m, the tether stretches to the grip.
	driver.island_tilt_deg = 0.0
	driver.island_sink = WardenMind.ISLAND_SINK
	driver.lens_drop = WardenMind.LENS_DROP
	hand.follow()
	rig.pose(driver)
	t.near("the falter sinks the isle 2 m", node.position.y, ParkRecipes.landmark_datum(_park["landmark"]) - WardenMind.ISLAND_SINK, 0.001)
	_tether("falter: the tether stretches to the dropped grip", rig, hand.global_position + IsleRig.GRIP)
	driver.island_sink = 0.0
	driver.lens_drop = 0.0
	hand.follow()
	rig.pose(driver)

	await _probe(rig, hand, driver, anchor)
	parent.free()
	quit(t.verdict())


func _tether(label: String, rig, grip: Vector3) -> void:
	var xf: Transform3D = rig.tether.global_transform
	var top := xf.origin
	var bottom := xf * (Vector3.DOWN * IsleRig.TETHER_LENGTH)
	t.check(label, top.distance_to(rig.tip_point()) < 0.01 and bottom.distance_to(grip) < 0.01,
		"top %s (tip %s), bottom %s (grip %s)" % [top, rig.tip_point(), bottom, grip])


# The sight-line probe in ten poses: rest, the tilt toward eight headings, and the falter.
func _probe(rig, hand: Hand, driver, anchor: Vector3) -> void:
	var reach := float(_park["landmark"]["reach_m"])
	var limit := PITCH_MAX + deg_to_rad(LOCK_CONE_DEG)
	var poses := [[0.0, Vector3.ZERO, false]]
	for k in 8:
		var a := TAU * k / 8.0
		poses.append([WardenMind.TILT_DEGREES, Vector3(sin(a), 0.0, cos(a)), false])
	poses.append([0.0, Vector3.ZERO, true])
	var worst_blocked := 0
	var fewest := 1 << 30
	var lines := 0
	var controls_missed := 0
	for pose: Array in poses:
		driver.island_tilt_deg = pose[0]
		driver.tilt_away = pose[1]
		driver.island_sink = WardenMind.ISLAND_SINK if pose[2] else 0.0
		driver.lens_drop = WardenMind.LENS_DROP if pose[2] else 0.0
		hand.follow()
		rig.pose(driver)
		await physics_frame
		await physics_frame
		var space: PhysicsDirectSpaceState3D = rig.landmark.get_world_3d().direct_space_state
		var target: Vector3 = hand.global_position
		var lockable := 0
		var blocked := 0
		var steps := int(reach / GRID_M)
		for i in range(-steps, steps + 1):
			for j in range(-steps, steps + 1):
				var x := anchor.x + i * GRID_M
				var z := anchor.z + j * GRID_M
				if Vector2(i, j).length() * GRID_M > reach:
					continue
				var ball := Vector3(x, float(_ground.call(x, z)) + Tuning.RADIUS, z)
				var to := target - ball
				if to.length() > ROPE_M or atan2(to.y, Vector2(to.x, to.z).length()) > limit:
					continue
				lockable += 1
				var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(ball, target, Augments.WORLD_MASK))
				if not hit.is_empty():
					blocked += 1
		var up: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(target, rig.tip_point() + Vector3.UP * 10.0, Augments.WORLD_MASK))
		if up.is_empty() or up["collider"] != rig.tip:
			controls_missed += 1
		lines += lockable
		fewest = mini(fewest, lockable)
		worst_blocked = maxi(worst_blocked, blocked)
	t.check("the hand locks from the ground in every pose", fewest > 0, "fewest %d lockable points, %d lines over %d poses" % [fewest, lines, poses.size()])
	t.eq("a ray up from the hand hits the moving tip in every pose", controls_missed, 0)
	t.eq("the tip, the isle and the tether block no rope or sight line", worst_blocked, 0)


static func _v3(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))
