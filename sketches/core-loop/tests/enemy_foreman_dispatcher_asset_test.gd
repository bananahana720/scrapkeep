extends SceneTree
# Kill-first bodies (ENEMY-PRIORITY.md levers 3 and 4): the Foreman and the Dispatcher. Asset
# only: no combat script loads these yet (Foreman wave 17, Dispatcher wave 18), so this checks
# the imported files the wiring will read. Enemy budget, opaque vertex-colour surfaces with no
# baked glow, the named meshes and sockets the behaviour is promised, and the floor and
# footprint each recipe documents.

const T := preload("res://tests/support/t.gd")
const FOREMAN := "res://assets/models/world_one/enemy_foreman.glb"
const DISPATCHER := "res://assets/models/world_one/enemy_dispatcher.glb"

var t := T.new("enemy_foreman_dispatcher_asset_test")


func _initialize() -> void:
	_run.call_deferred()


func _load(path: String) -> Node3D:
	var packed := load(path) as PackedScene
	t.check(path.get_file() + " loads", packed != null)
	return packed.instantiate() as Node3D if packed != null else null


# Vertices in the scene root's space, per mesh name.
func _points(scene: Node3D, name: String) -> PackedVector3Array:
	var out := PackedVector3Array()
	var mi := scene.find_child(name, true, false) as MeshInstance3D
	if mi == null:
		return out
	var xf := scene.global_transform.affine_inverse() * mi.global_transform
	for s in mi.mesh.get_surface_count():
		for v: Vector3 in mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			out.append(xf * v)
	return out


func _budget(label: String, scene: Node3D, draws: int, slots: Array) -> void:
	var tris := 0
	var verts := 0
	var surfaces := 0
	var seen := []
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(s)
			verts += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			tris += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
			surfaces += 1
			var mat := mi.mesh.surface_get_material(s) as BaseMaterial3D
			t.check(label + " opaque surface", mat != null and mat.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED)
			t.check(label + " no baked glow", mat != null and not mat.emission_enabled)
			t.check(label + " vertex colours", arrays[Mesh.ARRAY_COLOR] != null)
			if mat != null:
				seen.append(mat.resource_name)
	print("%s: %d V / %d T / %d D" % [label, verts, tris, surfaces])
	# The enemy class cap (assets/asset_budgets.json); each body recipe asserts its own.
	t.check(label + " enemy budget", verts <= 19100 and tris <= 10000 and surfaces == draws)
	for slot in slots:
		t.check(label + " slot " + slot, slot in seen)


func _named(label: String, scene: Node3D, names: Array) -> void:
	for name in names:
		t.check(label + " has " + name, scene.find_child(name, true, false) != null)
	for node: Node3D in scene.find_children("*", "Node3D", true, false):
		t.check(label + " unit scale " + node.name, node.scale.is_equal_approx(Vector3.ONE))


func _bounds(points: PackedVector3Array) -> AABB:
	var box := AABB(points[0], Vector3.ZERO) if points.size() > 0 else AABB()
	for p in points:
		box = box.expand(p)
	return box


# Rest origin of a rig bone in the scene root's space (the clips move the bone, not a node).
func _bone(scene: Node3D, bone: String) -> Vector3:
	var rig := scene.find_child("Skeleton3D", true, false) as Skeleton3D
	if rig == null or rig.find_bone(bone) < 0:
		t.check("bone " + bone, false)
		return Vector3.INF
	return rig.get_bone_global_rest(rig.find_bone(bone)).origin


func _socket(scene: Node3D, name: String) -> Node3D:
	return scene.find_child(name, true, false) as Node3D


func _foreman() -> void:
	var scene := _load(FOREMAN)
	if scene == null:
		return
	root.add_child(scene)
	_budget("foreman", scene, 3, ["fleet_paint", "requisition_tag"])
	_named("foreman", scene, ["ForemanBody", "ForemanHand", "ForemanSignal", "HornMouth", "ClockFace",
		"SteamValve", "tether_a", "tether_b", "tether_c", "tether_d"])
	var all := _points(scene, "ForemanBody")
	all.append_array(_points(scene, "ForemanSignal"))
	all.append_array(_points(scene, "ForemanHand"))
	var box := _bounds(all)
	t.near("foreman floor on the lobber's wheels", box.position.y, -2.0, 0.01)
	t.check("foreman stands over its crew (top 5.5 to 5.95)", box.end.y >= 5.5 and box.end.y <= 5.95, str(box.end.y))
	# The cart and cabinet (below the hat brim) keep to the lobber's 2.4 m footprint.
	var cart := 0.0
	var parts := _points(scene, "ForemanBody")
	parts.append_array(_points(scene, "ForemanSignal"))
	for p in parts:
		if p.y < 3.6:
			cart = maxf(cart, maxf(absf(p.x), absf(p.z)))
	t.check("foreman cart within the lobber footprint (1.2)", cart <= 1.2001, str(cart))
	# The clock faces forward (-Z), and its hand pivots on the dial centre.
	var clock := _socket(scene, "ClockFace").position
	var hand := _bone(scene, "Hand")
	t.check("clock face leads along -Z", clock.z < -0.45 and absf(clock.x) < 0.01, str(clock))
	t.check("hand pivots on the dial", Vector2(hand.x, hand.y).distance_to(Vector2(clock.x, clock.y)) < 0.01, str(hand))
	var horn := _socket(scene, "HornMouth")
	var blow := horn.basis * Vector3.FORWARD
	t.check("horn mouth at the mast head", horn.position.y > 5.0, str(horn.position))
	t.check("horn blows up and forward", blow.y > 0.7 and blow.z < -0.2, str(blow))
	# Four tether reels, one per deck corner.
	var corners := {}
	for name in ["tether_a", "tether_b", "tether_c", "tether_d"]:
		var p := _socket(scene, name).position
		corners["%d%d" % [signi(int(p.x * 10)), signi(int(p.z * 10))]] = true
		t.check(name + " on the deck", p.y > 1.2 and p.y < 2.0, str(p))
	t.check("tethers on four distinct corners", corners.size() == 4)
	scene.queue_free()


func _dispatcher() -> void:
	var scene := _load(DISPATCHER)
	if scene == null:
		return
	root.add_child(scene)
	_budget("dispatcher", scene, 3, ["fleet_paint", "requisition_tag"])
	_named("dispatcher", scene, ["DispatcherBody", "DispatcherRadar", "DispatcherSignal", "drop_mouth",
		"Beacon", "TicketSlot", "RadarPivot", "perch_foot"])
	var all := _points(scene, "DispatcherBody")
	all.append_array(_points(scene, "DispatcherSignal"))
	all.append_array(_points(scene, "DispatcherRadar"))
	var box := _bounds(all)
	t.near("dispatcher floor on its clamp pads", box.position.y, -1.5, 0.01)
	t.near("perch_foot on the floor", _socket(scene, "perch_foot").position.y, -1.5, 0.001)
	# Behind the face the body is the vault's octagon: nothing reaches past it but the tube.
	var core := 0.0
	for p in _points(scene, "DispatcherBody"):
		if p.z > -1.5:
			core = maxf(core, absf(p.x))
	t.check("dispatcher body within the vault plus headset (1.8)", core <= 1.8, str(core))
	# The tube reaches out front and its mouth aims down and forward, above the floor.
	var mouth := _socket(scene, "drop_mouth")
	var lead := mouth.basis * Vector3.FORWARD
	t.check("drop mouth out front", mouth.position.z < -3.0 and mouth.position.y > -1.5, str(mouth.position))
	t.check("drop mouth aims down and forward", lead.y < -0.4 and lead.z < -0.4 and absf(lead.x) < 0.01, str(lead))
	t.check("tube reach within 3.75", -box.position.z <= 3.75, str(box.position.z))
	# The radar paddle spins on the mast head.
	var radar := _bone(scene, "Radar")
	t.check("radar pivots on RadarPivot", radar.is_equal_approx(_socket(scene, "RadarPivot").position), str(radar))
	t.check("beacon above the radar", _socket(scene, "Beacon").position.y > radar.y, str(radar))
	scene.queue_free()


func _run() -> void:
	_foreman()
	_dispatcher()
	quit(t.verdict())
