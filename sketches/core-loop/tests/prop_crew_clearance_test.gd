extends SceneTree

# The prop crew leaves the ride line clear (docs/art/reference/GROUNDING.md:269, "Prop crew
# placement check"). The crew's position is runtime (it walks to put its roof over its pack),
# so there is no static layout to plan-check; this pins the grounded claim instead:
# - the roof (ShoredRoof and its canopy), the prop and the falling slab carry no collider
#   (counter.gd _box and the GLB meshes are bare MeshInstance3D), so the standing frame blocks
#   no ride line;
# - the committed RubbleFall (its Hazard child included) carries no collider, frees itself
#   after its live tick, and nothing collidable is left within the disc once it has gone;
# - the roof lands only on a ball on the floor (floor_rule.gd): a ball about 2 m up, inside
#   the hazard's reach so the disc contains it, is still not hit because it is off the floor;
#   a floor ball from the same setup is the positive control;
# - both counters (collider walk, stray scan) are run on a planted collider, so the zero
#   counts are not vacuous.
# The crew's own body is not checked: enemies are hit by design.

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const PropCrew := preload("res://src/combat/prop_crew.gd")
const FloorRule := preload("res://src/combat/floor_rule.gd")
const WarningGap := preload("res://src/world/events/warning_gap.gd")
const T := preload("res://tests/support/t.gd")

var game
var t := T.new("prop_crew_clearance_test")
var ball := Vector3.ZERO


func _initialize() -> void:
	_run.call_deferred()


func _frames(count: int) -> void:
	for frame in count:
		await physics_frame


func _seconds(seconds: float) -> void:
	await _frames(int(seconds * Engine.physics_ticks_per_second))


func _boot() -> void:
	game = Game.new()
	game.test_mode = true
	game.table = "slice"
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	game.ctx.calm = true
	game.ctx.rng.seed = 23
	game.player.source = Intent.Scripted.new()
	game.flow.press_start()
	game.flow.choose_class(0)
	game.run.set_max_hp(99999.0)
	game.presentation.juice.hit_stop_sink = func(_seconds: float): pass
	await _frames(3)
	_clear()
	var spawn: Vector3 = game.ctx.terrain.spawn_point(1)
	ball = game.ctx.terrain.drop_point(spawn.x, spawn.z, 1.05)
	game.player.reset_to(ball)


func _clear() -> void:
	for enemy in get_nodes_in_group("enemy"):
		enemy.free()


func _at(offset: Vector3) -> Vector3:
	var at := ball + offset
	at.y = game.ctx.terrain.height(at.x, at.z) + 1.5
	return at


func _spawn(kind: String, offset: Vector3):
	var enemy = game.combat.spawn_enemy(kind, _at(offset))
	if "_rest" in enemy:
		enemy._rest = 1000.0
	return enemy


func _ram(enemy, force := 30.0) -> void:
	game.combat.deal_hit(enemy, "ram", force, Vector3.RIGHT, 0.0, "", "", "ram")


func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


# Every CollisionObject3D and CollisionShape3D at or under node (the node included).
static func _colliders_under(node: Node) -> int:
	if node == null:
		return 0
	var count := 1 if (node is CollisionObject3D or node is CollisionShape3D) else 0
	for found in node.find_children("*", "CollisionObject3D", true, false):
		count += 1
	for found in node.find_children("*", "CollisionShape3D", true, false):
		count += 1
	return count


# Nodes at or under node, so a zero collider count is known to have walked something.
static func _nodes_under(node: Node) -> int:
	return 0 if node == null else 1 + node.find_children("*", "", true, false).size()


# CollisionObject3D nodes in the tree that were not in before and sit within radius of centre
# in xz. Enemies that existed before are already in before, so the enemy group needs no
# exclusion: anything new the fall leaves, an enemy included, counts.
func _strays(before: Dictionary, centre: Vector3, radius: float) -> Array:
	var found_at := []
	for found in root.find_children("*", "CollisionObject3D", true, false):
		if before.has(found.get_instance_id()):
			continue
		if found is Node3D and _flat(found.global_position).distance_to(_flat(centre)) <= radius:
			found_at.append(found.get_path())
	return found_at


func _all_bodies() -> Dictionary:
	var ids := {}
	for found in root.find_children("*", "CollisionObject3D", true, false):
		ids[found.get_instance_id()] = true
	return ids


# Drops a fresh crew's roof on a ball placed under it (air = hovering above the disc).
# Returns {hit, floored, hp0, hp1, landed}.
func _drop_on_ball(air: bool) -> Dictionary:
	game.player.reset_to(ball)
	await _seconds(1.0)
	var crew = _spawn("prop_crew", Vector3(8.0, 0.0, 0.0))
	await _frames(2)
	crew.set_physics_process(false)
	var here: Vector3 = game.player.ball_position()
	crew.global_position += Vector3(here.x, 0.0, here.z) - Vector3(crew.roof_centre().x, 0.0, crew.roof_centre().z)
	var hp: float = game.run.hp
	var out := {"contained": null, "hit": null, "floored": null, "hp0": hp, "hp1": hp, "landed": false}
	root.remove_meta(WarningGap.LAST_META)
	var fall = crew.knock_prop()
	fall.landed.connect(func(_crushed: Array, hit_ball: bool) -> void:
		out.hit = hit_ball
		out.contained = fall.hazard.contains(game.player.ball_position())
		out.landed = true
		out.floored = FloorRule.on_floor(game.player.state))
	# About 2 m up: inside the hazard's reach (REACH_M 3.5), so contains() is true and only
	# the floor rule keeps the ball clear.
	var held: Vector3 = Vector3(here.x, game.ctx.terrain.height(here.x, here.z) + 2.0, here.z)
	var frames: int = 0
	while not out.landed and frames < 240:
		if air and fall.committed():
			game.player.reset_to(held)
		await physics_frame
		frames += 1
	out.hp1 = game.run.hp
	_clear()
	await _frames(2)
	return out


func _run() -> void:
	await _boot()

	# 1. Standing crew: roof, canopy and prop carry no collider.
	var crew = _spawn("prop_crew", Vector3(30.0, 0.0, 0.0))
	var mates := [_spawn("drill_crew", Vector3(42.0, 0.0, 8.0)), _spawn("drill_crew", Vector3(44.0, 0.0, -6.0))]
	await _frames(5)
	for mate in mates:
		mate.set_physics_process(false)
	var roof: Node3D = crew._roof
	var prop: Node3D = crew._prop
	t.check("the crew has a roof holder", roof != null and roof.is_inside_tree())
	t.check("the roof holds its canopy", roof != null and roof.get_child_count() > 0, "%d nodes" % _nodes_under(roof))
	t.check("the crew has a prop", prop != null and prop.is_inside_tree())
	var roof_meshes: int = roof.find_children("*", "MeshInstance3D", true, false).size() if roof != null else 0
	t.check("the roof walk found its meshes", roof_meshes > 0, "%d meshes" % roof_meshes)
	t.check("the prop is a mesh", prop is MeshInstance3D)
	t.eq("the roof and canopy carry no collider", _colliders_under(roof), 0)
	t.eq("the prop carries no collider", _colliders_under(prop), 0)

	# 4. Planted control, on the same helper: a collider in a copy of the roof is counted.
	var copy: Node3D = roof.duplicate()
	var planted := StaticBody3D.new()
	planted.add_child(CollisionShape3D.new())
	copy.add_child(planted)
	t.check("the control copy keeps the roof's nodes", _nodes_under(copy) > _nodes_under(roof))
	t.check("a collider planted in a roof copy is counted", _colliders_under(copy) >= 2, "%d" % _colliders_under(copy))
	copy.free()

	# 2. The knock: slab and fall are collider-free, the fall frees itself, nothing is left.
	for i in mates.size():
		mates[i].global_position = _at(crew.roof_centre() - ball + Vector3(2.0 * (i * 2 - 1), 0.0, 1.0))
	var before := _all_bodies()
	t.check("the scene has colliders to compare against", before.size() > 0, "%d" % before.size())
	var centre: Vector3 = crew.roof_centre()
	root.remove_meta(WarningGap.LAST_META)
	_ram(crew)
	var fall = crew.last_fall
	t.check("the ram brings a fall", is_instance_valid(fall))
	var slab: Node3D = fall.get_child(0) if is_instance_valid(fall) and fall.get_child_count() > 0 else null
	t.check("the fall carries the slab", slab == roof, "%s" % slab)
	t.check("the slab walk found its nodes", _nodes_under(slab) > 1, "%d" % _nodes_under(slab))
	t.eq("the falling slab carries no collider", _colliders_under(slab), 0)
	# The Hazard is added when the fall commits; walk the whole fall with it present.
	var committing: int = 0
	while is_instance_valid(fall) and not fall.committed() and committing < 120:
		await physics_frame
		committing += 1
	t.check("the fall committed", is_instance_valid(fall) and fall.committed(), "%d frames" % committing)
	t.check("the fall's hazard is in the walk", fall.hazard != null and fall.is_ancestor_of(fall.hazard))
	t.check("the fall walk found slab and hazard", _nodes_under(fall) >= _nodes_under(slab) + 1, "%d nodes" % _nodes_under(fall))
	t.eq("the committed fall carries no collider", _colliders_under(fall), 0)
	var landed := []
	fall.landed.connect(func(_crushed: Array, _hit_ball: bool) -> void: landed.append(true))
	var waited: int = 0
	while is_instance_valid(fall) and waited < 360:
		await physics_frame
		waited += 1
	t.check("the fall landed", landed.size() == 1, "%d landings" % landed.size())
	t.check("the fall freed itself", not is_instance_valid(fall), "%d frames" % waited)
	var strays := _strays(before, centre, PropCrew.ROOF_RADIUS + 1.0)
	t.eq("nothing collidable is left within the disc", strays, [])
	# Control: a collider planted in the disc after the before-set is found by the same scan.
	var plant := StaticBody3D.new()
	plant.add_child(CollisionShape3D.new())
	root.add_child(plant)
	plant.global_position = centre
	t.eq("a collider planted in the disc is found", _strays(before, centre, PropCrew.ROOF_RADIUS + 1.0).size(), 1)
	plant.free()
	_clear()
	await _frames(2)

	# 3. Air pass, with the floor hit as the positive control from the same setup.
	var floor_drop: Dictionary = await _drop_on_ball(false)
	t.check("the control fall landed on a floor ball", floor_drop.landed and floor_drop.floored == true, "%s" % [floor_drop])
	t.check("the roof hits a ball on the floor (control)", floor_drop.hit == true and floor_drop.hp1 < floor_drop.hp0, "hp %.1f to %.1f" % [floor_drop.hp0, floor_drop.hp1])
	var air_drop: Dictionary = await _drop_on_ball(true)
	t.check("the air fall landed with the disc containing a ball off the floor", air_drop.landed and air_drop.contained == true and air_drop.floored == false, "%s" % [air_drop])
	t.check("the roof passes a ball in the air", air_drop.hit == false and air_drop.hp1 >= air_drop.hp0, "hp %.1f to %.1f" % [air_drop.hp0, air_drop.hp1])
	quit(t.verdict())
