# 2026-10-12, W13 smoke triage: class c re-pin for 5b903a3, bbe53ec, 17429d6.
# counter.gd SHA256 56b1e9fd180b0c5c06ba67013011c12a26d6f6f1989cb6c140620334b06f0cca -> 5e3d17ed123286ed2c22808f3051a76d450e56697828d7277cef3b8f0af7c554; merged pack stagger, rename and shared-recovery changes.
extends SceneTree

const Game := preload("res://src/game.gd")
const Drill := preload("res://src/combat/drill_crew.gd")
const T := preload("res://tests/support/t.gd")
const GLB := "res://assets/models/world_two/enemy_drill_crew.glb"
# 2026-11-25 (W48-COMBAT): re-pinned _commit and _go_live for Horizontal Core-Jet secondary attack.
const GAMEPLAY_HASHES := {
	"_configure": "15276464b7bf2dc3f157684f0ed2225a2139a67e528604e2209cf0fcd4779388",
	"_commit": "ebd17a45cf6dc5cf5860c891f26abc7cb8b4e3e79f3dfb9f1004955172219a44",
	"_go_live": "e1262573d32cd047ff4dad23b60bff2ffa277db48576957746360b32e2aa7ff7",
	"on_struck": "1266591caea08b7f3e0069996dec12035cd1a7cc5c4b8dc56c737b2aa9c846e1",
	"take_damage": "da8f0da2090fa2316550164b6eb7518ef16d2aaf524dd88a2fc90365a292f603",
	"_die": "6fe86d1077f6f165709184282a397ce2ffaa9542f30990cf6cd1658c463792ea",
}
var t := T.new("enemy_drill_crew_asset_test")
var game
var fixture: Node3D


func _initialize() -> void:
	if "--asset-fixture" in OS.get_cmdline_user_args():
		fixture = Node3D.new()
		root.add_child(fixture)
	else:
		game = Game.new()
		game.test_mode = true
		root.add_child(game)
	_run.call_deferred()


func _spawn(at: Vector3):
	if game != null:
		return game.combat.spawn_enemy("drill_crew", at)
	var rig := Drill.new()
	fixture.add_child(rig)
	rig.position = at
	rig.setup(null, null, fixture, Callable(), 1.0, {"kind": "drill_crew"})
	return rig


func _measure(node: Node, vertex_paint := false) -> Dictionary:
	var out := {"tris": 0, "verts": 0, "draws": 0}
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			out.draws += 1
			var arrays := mi.mesh.surface_get_arrays(s)
			var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var ix = arrays[Mesh.ARRAY_INDEX]
			out.verts += vs.size()
			out.tris += (ix.size() if ix != null else vs.size()) / 3
			var mat := mi.get_active_material(s) as BaseMaterial3D
			t.check("opaque surface " + str(mi.name), mat != null
				and mat.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and mat.albedo_color.a == 1.0
				and (not vertex_paint or mat.vertex_color_use_as_albedo) and not mat.emission_enabled)
			var colors = arrays[Mesh.ARRAY_COLOR]
			t.eq("surface carries vertex colours", colors.size() if colors != null else 0, vs.size())
			for c in (colors if colors != null else []):
				if c.a < 0.999:
					t.check("all vertex colours opaque", false)
					break
	print("asset geometry: %d T / %d V / %d D" % [out.tris, out.verts, out.draws])
	t.check("classes.enemy budget", out.tris > 0 and out.tris <= 10000
		and out.verts <= 19100 and out.draws == 3)
	return out


func _points(mi: MeshInstance3D) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for s in mi.mesh.get_surface_count():
		for v in mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array:
			points.append(mi.transform * v)
	return points


func _bounds(points: Array[Vector3]) -> AABB:
	var bounds := AABB(points[0], Vector3.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	return bounds


# Weld normal/colour seams, then measure actual connected shells of the merged body.
func _shells(mesh: Mesh) -> Array:
	var points: Array[Vector3] = []
	var by_pos := {}
	var edges: Array = []
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var ids := PackedInt32Array()
		for v in arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array:
			var key := Vector3i(roundi(v.x * 100000), roundi(v.y * 100000), roundi(v.z * 100000))
			if not by_pos.has(key):
				by_pos[key] = points.size()
				points.append(v)
				edges.append({})
			ids.append(by_pos[key])
		var ix: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for i in range(0, ix.size(), 3):
			for j in 3:
				var a := ids[ix[i + j]]
				var b := ids[ix[i + (j + 1) % 3]]
				edges[a][b] = true
				edges[b][a] = true
	var seen := {}
	var shells := []
	for start in points.size():
		if seen.has(start):
			continue
		var shell: Array[Vector3] = []
		var pending := [start]
		seen[start] = true
		while not pending.is_empty():
			var at: int = pending.pop_back()
			shell.append(points[at])
			for next in edges[at]:
				if not seen.has(next):
					seen[next] = true
					pending.append(next)
		shells.append(shell)
	return shells


func _near_vec(got: Vector3, want: Vector3) -> bool:
	return got.distance_to(want) < 0.0001


func _geometry(scene: Node3D) -> void:
	var body := scene.find_child("DrillCrewBody", true, false) as MeshInstance3D
	var bit := scene.find_child("DrillBit", true, false) as MeshInstance3D
	var plate := scene.find_child("DrillPlate", true, false) as MeshInstance3D
	if not t.check("three named meshes", body != null and bit != null and plate != null):
		return
	for pair in [[body, "fleet_paint"], [bit, "working_tool"], [plate, "part_state"]]:
		t.eq("exported slot " + str(pair[0].name), pair[0].mesh.surface_get_material(0).resource_name, pair[1])
	var sockets := {"DrillHead": Vector3(0, 1.3, 0), "DrillCarriage": Vector3(0, 0.5, 1.3),
		"DrillRails": Vector3(0, 0.3, 1.3), "DrillFeet": Vector3(0, -1.025, 0),
		"bit_axis": Vector3(0, 0.5, 2.4), "bit_tip": Vector3(0, 0.5, 3.6),
		"rail_slide": Vector3(0, 0.5, 1.3), "plate_attach": Vector3(0, 0.6, -1.0)}
	for name in sockets:
		var node := scene.find_child(name, true, false) as Node3D
		t.check("named assembly/socket " + name, node != null and node.position.is_equal_approx(sockets[name]))
	var found_core := false
	var found_head := false
	var found_carriage := false
	var feet := 0
	var rails := 0
	for shell: Array[Vector3] in _shells(body.mesh):
		var bounds := _bounds(shell)
		if _near_vec(bounds.size, Vector3(1.6, 2.2, 1.6)):
			found_core = true
			for point in shell:
				t.check("core inside unchanged collider", Vector2(point.x, point.z).length() <= 0.8001
					and point.y >= -1.1001 and point.y <= 1.1001)
		elif _near_vec(bounds.size, Vector3(0.76, 0.76, 0.76)):
			found_head = _near_vec(bounds.get_center(), Vector3(0, 1.3, 0))
		elif _near_vec(bounds.size, Vector3(1.6, 0.9, 1.6)):
			found_carriage = _near_vec(bounds.get_center(), Vector3(0, 0.5, 1.3))
		elif _near_vec(bounds.size, Vector3(0.25, 0.15, 0.35)):
			feet += 1
			t.near("foot floor height", bounds.position.y, -1.1)
			for point in shell:
				t.check("foot stays inside radial core", Vector2(point.x, point.z).length() <= 0.8001)
		elif _near_vec(bounds.size, Vector3(0.1, 0.1, 1.6)):
			rails += 1
	t.check("measured rounded core, head and carriage", found_core and found_head and found_carriage)
	t.eq("four measured feet", feet, 4)
	t.eq("two measured rails", rails, 2)
	var bit_points := _points(bit)
	var bit_bounds := _bounds(bit_points)
	var radial := 0.0
	for point in bit_points:
		radial = maxf(radial, Vector2(point.x, point.y - 0.5).length())
	t.near("screw radius", radial, 0.45)
	t.near("screw axis length", bit_bounds.size.z, 2.4)
	t.near("screw tip", bit_bounds.end.z, 3.6)
	t.check("screw has helical flight geometry", bit.mesh.get_faces().size() > 600)
	var plate_bounds := _bounds(_points(plate))
	t.check("plate measured envelope and rear position", _near_vec(plate_bounds.size, Vector3(2.2, 1.8, 0.25))
		and _near_vec(plate_bounds.get_center(), Vector3(0, 0.6, -1.0)))


func _baseline() -> void:
	var source := FileAccess.get_file_as_string("res://src/combat/drill_crew.gd")
	for name in GAMEPLAY_HASHES:
		var re := RegEx.new()
		re.compile("(?ms)^func " + name + ".*?(?=^(?:static )?func |\\z)")
		var match0 := re.search(source)
		t.check("base gameplay function unchanged " + name, match0 != null
			and match0.get_string().strip_edges().sha256_text() == GAMEPLAY_HASHES[name])
	# Shared combat files are not pinned here; the merge-time fence owns shared-file changes (2026-10-13, ENEMY-PINS).
	for pair in [["PLATING", "22.0"], ["HP", "90.0"], ["LEAD", "0.8"], ["BORE_RADIUS", "3.0"],
		["BORE_DAMAGE", "11.0"], ["BORE_SHOVE", "7.0"]]:
		t.check("base constant " + pair[0], source.split("\n").has("const %s := %s" % [pair[0], pair[1]]))


func _pose(rig, bit: MeshInstance3D) -> void:
	var rest := bit.transform
	var actor: Transform3D = rig.transform
	var clock := 0.6
	rig.phase = rig.Phase.WARN
	rig._t = clock
	rig._pose()
	t.near("half WARN withdrawal", bit.position.z, 2.275)
	t.near("pose leaves WARN clock untouched", rig._t, clock)
	rig._t = rig.warn_seconds
	rig._pose()
	t.near("full WARN withdrawal", bit.position.z, 2.15)
	rig.phase = rig.Phase.LIVE
	rig._t = 0.0
	rig._pose()
	t.near("release frame retains brace", bit.position.z, 2.15)
	rig._t = rig.live_seconds
	rig._pose()
	t.check("resolution returns screw", bit.transform.is_equal_approx(rest))
	rig.phase = rig.Phase.WARN
	rig._t = rig.warn_seconds
	rig._pose()
	rig.on_struck("slam", "", {})
	t.check("slam immediately resets visual", bit.transform.is_equal_approx(rest))
	t.eq("slam retains existing interruption", rig.stopped, 1)
	t.check("pose leaves actor transform untouched", rig.transform.is_equal_approx(actor))


func _run() -> void:
	_baseline()
	var packed := load(GLB) as PackedScene
	if not t.check("GLB loads", packed != null):
		quit(t.verdict())
		return
	var scene := packed.instantiate() as Node3D
	var asset := _measure(scene)
	_geometry(scene)
	scene.free()
	if game != null:
		game.ctx.calm = true
	var rig = _spawn(Vector3(0, 30, 0))
	rig.set_physics_process(false)
	var body := rig.find_child("DrillCrewBody", true, false) as MeshInstance3D
	var bit := rig.find_child("DrillBit", true, false) as MeshInstance3D
	var plate := rig.find_child("DrillPlate", true, false) as MeshInstance3D
	t.check("GLB replaces capsule fallback", rig._crew == null and body != null and bit != null and plate != null)
	t.eq("runtime equals exported geometry", _measure(rig, true), asset)
	var shapes := rig.find_children("*", "CollisionShape3D", true, false)
	var capsule := shapes[0].shape as CapsuleShape3D if shapes.size() == 1 else null
	t.check("one unchanged collider capsule", capsule != null and is_equal_approx(capsule.radius, 0.8)
		and is_equal_approx(capsule.height, 2.2) and shapes[0].transform.is_equal_approx(Transform3D.IDENTITY))
	if body != null and bit != null and plate != null:
		t.check("model follows reaction pivot", body.get_parent() == rig._visual_parent()
			and bit.get_parent() == body.get_parent() and plate.get_parent() == body.get_parent())
		t.check("named screw and plate drive script", rig._bit == bit and rig._plate == plate)
		_pose(rig, bit)
		var other = _spawn(Vector3(5, 30, 0))
		other.set_physics_process(false)
		t.check("instances share cached mesh", body.mesh == other.find_child("DrillCrewBody", true, false).mesh)
		t.check("instances own flash material", rig._material != other._material
			and body.get_surface_override_material(0) == rig._material)
		rig.flash()
		rig._update_flash(0.0)
		t.check("body flash still registered", rig._material.emission_enabled and not other._material.emission_enabled)
		rig._update_flash(1.0)
		t.check("flash resets vertex paint", not rig._material.emission_enabled and rig._material.albedo_color == Color.WHITE)
		rig.on_struck("shot", "", {"full": true})
		t.check("plate group hides alone", not plate.visible and body.visible and bit.visible)
		t.check("plate state isolated between instances", other._plate.visible)
		other.free()
	if game != null:
		game.free()
	else:
		fixture.free()
	quit(t.verdict())
