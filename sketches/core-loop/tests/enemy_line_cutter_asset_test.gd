# 2026-10-12, W13 smoke triage: class c re-pin for 5b903a3, bbe53ec, 17429d6.
# counter.gd SHA256 56b1e9fd180b0c5c06ba67013011c12a26d6f6f1989cb6c140620334b06f0cca -> 5e3d17ed123286ed2c22808f3051a76d450e56697828d7277cef3b8f0af7c554; merged pack stagger, rename and shared-recovery changes.
extends SceneTree

const Game := preload("res://src/game.gd")
const Cutter := preload("res://src/combat/line_cutter.gd")
const T := preload("res://tests/support/t.gd")
const GLB := "res://assets/models/world_three/enemy_line_cutter.glb"
# 2026-10-18 (w17 fix): re-pin for 3059e90 (Highdraft line cutter: gap-only cut, re-bite, grown landing
# throw, RING_REACH 40.0). _commit was 9c7b7d6b, _live was f50d2057, RING_REACH was 6.0; the disc now
# flies to _target (the predicted point) instead of the ring centre.
# _live re-pinned for FX-26 (12 Nov 2026): one display-only ring.land() as the disc arrives.
# W49-COMBAT re-pin: primary warn_seconds floor 0.75 s and Boomerang Rim-Slice secondary attack.
const GAMEPLAY_HASHES := {"_configure": "db59d0f8a712b24626d6ccc067d8c23d37f483bf2f7562f515c18decd09d76c2", "_wants_attack": "b843e7c2cde7c63fe9e8733ab5ad2ef6fa32a7bd46a50e7b86ba4afc9570e5d3", "_commit": "092e94109440f0aac8dae2580d7f2097034ebdd9fcfc6ba505a7f99d3d4f8309", "_warn_progress": "a4f133b9c6623dc807158da687bc519cdfe48d7ef888189b0c583251fdb293c6", "_go_live": "b48c5a203c92e8808916aedef2fa85986393bb0378ebb490c41e891152db95eb", "_live": "f7a09fce77f96a32fc4694c2bee5be96c45a308d7cbdd7bb251ba9037a8e3b12", "_on_end": "ebacebd4af88841033c31417698ebd62dc672fecd55fbbf6b8f74c5810054548", "_rest_disc": "be6103f0498890eba09f9880718efd36de6f401ec2504b715e47a4ff92502d32"}

var t := T.new("enemy_line_cutter_asset_test")
var game


func _initialize() -> void:
	_run.call_deferred()


func _measure(node: Node) -> Dictionary:
	var totals := {"vertices": 0, "triangles": 0, "draws": 0}
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(s)
			var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var ids: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			totals.vertices += vs.size()
			totals.triangles += ids.size() / 3 if not ids.is_empty() else vs.size() / 3
			totals.draws += 1
			var mat := mi.get_active_material(s) as BaseMaterial3D
			t.check("opaque surface", mat != null and mat.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and mat.albedo_color.a == 1.0)
			t.check("no persistent glow", mat != null and not mat.emission_enabled)
			t.check("vertex colours", arrays[Mesh.ARRAY_COLOR] != null)
			if arrays[Mesh.ARRAY_COLOR] != null:
				var opaque := true
				for c: Color in arrays[Mesh.ARRAY_COLOR]:
					opaque = opaque and c.a > 0.999
				t.check("opaque vertex colours", opaque)
	print("assembly: %d V / %d T / %d D" % [totals.vertices, totals.triangles, totals.draws])
	t.check("enemy budget", totals.vertices > 0 and totals.vertices <= 19100 and totals.triangles > 0 and totals.triangles <= 10000 and totals.draws == 3)
	return totals


func _source_function(source: String, name: String) -> String:
	var start := source.find("func " + name + "(")
	if start < 0:
		return ""
	var end := source.find("\nfunc ", start + 1)
	return source.substr(start, end - start if end >= 0 else -1).strip_edges()


func _geometry(scene: Node3D) -> void:
	for name in ["CutterCrewBody", "CutterHead", "ThrowArm", "CutterDisc", "DiscRack", "throw_shoulder", "disc_rest", "disc_launch"]:
		t.check("named part " + name, scene.find_child(name, true, false) != null)
	var disc := scene.find_child("CutterDisc", true, false) as MeshInstance3D
	var body := scene.find_child("CutterCrewBody", true, false) as MeshInstance3D
	var arm := scene.find_child("ThrowArm", true, false) as MeshInstance3D
	if disc == null or body == null or arm == null:
		return
	t.check("disc rest socket", disc.position.is_equal_approx(Vector3(0, 2.1, 0)))
	t.check("shoulder pivot", arm.position.is_equal_approx(Vector3(-0.48, 0.7, 0)))
	var radial := 0.0
	var lo := INF
	var hi := -INF
	for v: Vector3 in disc.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		radial = maxf(radial, Vector2(v.x, v.z).length())
		lo = minf(lo, v.y)
		hi = maxf(hi, v.y)
	t.near("disc radius", radial, 0.7)
	t.near("disc thickness", hi - lo, 0.08)
	t.check("horizontal disc axis", disc.basis.is_equal_approx(Basis.IDENTITY))
	var core_radius := 0.0
	lo = INF
	hi = -INF
	var head_top := -INF
	for v: Vector3 in body.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		lo = minf(lo, v.y)
		head_top = maxf(head_top, v.y)
		if v.y <= 1.1001:
			core_radius = maxf(core_radius, Vector2(v.x, v.z).length())
			hi = maxf(hi, v.y)
	t.check("core radial bound", core_radius <= 0.8001)
	t.near("core measured diameter", core_radius * 2.0, 1.6)
	t.near("core floor", lo, -1.1)
	t.near("core top", hi, 1.1)
	t.near("crew ear top", head_top, 1.82)
	for node: Node3D in scene.find_children("*", "Node3D", true, false):
		t.check("unit scale " + node.name, node.scale.is_equal_approx(Vector3.ONE))
	for pair in [["CutterHead", Vector3(0, 1.3, 0)], ["DiscRack", Vector3(0, 1.9, 0)],
			["disc_launch", Vector3(0, 2.2, 0)]]:
		var marker := scene.find_child(pair[0], true, false) as Node3D
		t.check("measured socket " + pair[0], marker != null and marker.position.is_equal_approx(pair[1]))


func _run() -> void:
	var packed := load(GLB) as PackedScene
	t.check("GLB loads", packed != null)
	if packed == null:
		quit(t.verdict())
		return
	var scene := packed.instantiate()
	_measure(scene)
	_geometry(scene)
	scene.free()
	var source := FileAccess.get_file_as_string("res://src/combat/line_cutter.gd")
	for name in GAMEPLAY_HASHES:
		t.check("unchanged gameplay " + name, _source_function(source, name).sha256_text() == GAMEPLAY_HASHES[name])
	# Shared combat files are not pinned here; the merge-time fence owns shared-file changes (2026-10-13, ENEMY-PINS).
	t.check("unchanged constants", source.contains("const FLIGHT := 1.1") and source.contains("const HP := 38.0") and source.contains("const STING := 4.0") and source.contains("const HEIGHT := 2.2") and source.contains("const SPIN_RATE := 0.9") and source.contains("const RING_RADIUS := 2.6") and source.contains("const RING_REACH := 40.0"))
	game = Game.new()
	game.test_mode = true
	root.add_child(game)
	game.ctx.calm = true
	var unit = game.ctx.spawner.spawn_enemy("line_cutter", Vector3(0, 30, 0))
	unit.set_physics_process(false)
	var live := _measure(unit)
	t.check("loaded assembly replaces capsule", unit._crew == null and unit._body != null and unit._throw_arm != null and unit._disc != null)
	var no_capsule := true
	for mi: MeshInstance3D in unit.find_children("*", "MeshInstance3D", true, false):
		no_capsule = no_capsule and not mi.mesh is CapsuleMesh
		t.check("reaction parent", mi.get_parent() == unit.reaction_pivot)
	t.check("no capsule fallback mesh", no_capsule)
	var shapes: Array[Node] = unit.find_children("*", "CollisionShape3D", true, false)
	var cap := (shapes[0] as CollisionShape3D).shape as CapsuleShape3D if shapes.size() == 1 else null
	t.check("original collider", cap != null and is_equal_approx(cap.radius, 0.8) and is_equal_approx(cap.height, 2.2) and (shapes[0] as Node3D).transform.is_equal_approx(Transform3D.IDENTITY))
	t.check("no added collision or lights", unit.find_children("*", "CollisionObject3D", true, false).is_empty() and unit.find_children("*", "Light3D", true, false).is_empty())
	if unit._body != null and unit._throw_arm != null:
		_pose_and_flight(unit)
		var other = game.ctx.spawner.spawn_enemy("line_cutter", Vector3(5, 30, 0))
		other.set_physics_process(false)
		t.check("cached meshes", other._body != null and other._body.mesh == unit._body.mesh and other._disc.mesh == unit._disc.mesh)
		t.check("independent body flash", other._material != unit._material)
		t.check("body and arm flash registration", unit._body.get_active_material(0) == unit._material and unit._throw_arm.get_active_material(0) == unit._material and unit._disc.get_active_material(0) != unit._material)
		unit.flash()
		unit._update_flash(0.01)
		t.check("body hit flash", unit._material.emission_enabled and not other._material.emission_enabled)
		unit._update_flash(1.0)
		t.check("flash settles", not unit._material.emission_enabled and unit._material.albedo_color.is_equal_approx(Color.WHITE))
		other.free()
	t.check("same imported/live budget", live.draws == 3)
	game.free()
	quit(t.verdict())


func _pose_and_flight(unit) -> void:
	unit._warn(Vector3.FORWARD * 12.0)
	var ring = unit.telegraph()
	t.check("committed ring", ring != null)
	if ring == null:
		return
	var half_pose := Transform3D.IDENTITY
	for clock in [0.0, 0.3, 0.6]:
		unit._t = clock
		unit._pose()
		var cock: float = clock / unit.warn_seconds
		t.near("clock-driven arm", unit._throw_arm.rotation.x, -0.52 * cock)
		t.near("clock-driven lean", unit._body.rotation.x, 0.08 * cock)
		t.near("ring remains open", unit._warn_progress(), 0.0)
		t.near("pose does not advance clock", unit._t, clock)
		t.check("held disc follows rack", not unit._disc.top_level and unit._disc.position.is_equal_approx(unit._throw_arm.transform * Vector3(0.48, 1.4, 0)))
		if clock == 0.3:
			half_pose = unit._throw_arm.transform
	unit._t = 0.3
	unit._pose()
	t.check("pose is repeatable", half_pose.is_equal_approx(unit._throw_arm.transform))
	unit._end()
	unit._pose()
	t.check("interrupt restores disc and arm", not unit._disc.top_level and unit._disc.position.is_equal_approx(Vector3(0, 2.1, 0)) and unit._throw_arm.basis.is_equal_approx(Basis.IDENTITY))
	unit._warn(Vector3.FORWARD * 12.0)
	ring = unit.telegraph()
	unit.phase = unit.Phase.LIVE
	unit._go_live()
	unit._t = 0.55
	unit._live(0.0)
	var expected: Vector3 = unit.Threat.flight_point(unit._launch, unit._target, unit._bump, 0.5)
	t.check("script-owned flight", unit._disc.top_level and unit._disc.global_position.is_equal_approx(expected))
	var flight: Transform3D = unit._disc.global_transform
	unit._pose()
	t.check("pose leaves flying disc alone", unit._disc.global_transform.is_equal_approx(flight))
	unit._end()
	unit._pose()
	t.check("return restores rest", not unit._disc.top_level and unit._disc.position.is_equal_approx(Vector3(0, 2.1, 0)) and unit._disc.basis.is_equal_approx(Basis.IDENTITY))
