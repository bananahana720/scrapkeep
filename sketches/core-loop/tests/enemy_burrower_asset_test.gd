extends SceneTree

const Burrower := preload("res://src/combat/burrower.gd")
const T := preload("res://tests/support/t.gd")
const GLB := "res://assets/models/world_two/enemy_burrower.glb"
const NAMED := ["BurrowBody", "BurrowHull", "ShovelNose", "SidePaddles", "CrewVisor", "Exhaust",
	"BurrowMarker", "MarkerWorkingLip", "burrow_root", "nose_forward", "marker_center", "lane_origin"]
# 2026-11-25 (W48-COMBAT): re-pinned _commit, _go_live, _on_end, _on_slammed for Wall-Skim Eruption secondary attack.
const GAMEPLAY := {
	"setup": "384e4992a7096daa0b6843767cd1a0c25483c29222eb2929931aad54de7428e9",
	"_configure": "6fb461ab724a89e299b4929526b6afdac9bf4c46056bd1a996438f8c5ebb1c81",
	"_set_hidden": "53c14e3ea8cf7301302172fa4101c6927662909322c42c6b9d123db8f71d2600",
	"_commit": "c4841a82fa65be2e19afe87974017a84a0b767ff68ed0361eea6345b764320b3",
	"_go_live": "a4b05a08a2aa474874a729e4aef5dd04c7f6942e02b1f89bdf87fa47ec2cb834",
	"_live_motion": "878a18a155fc065e65f4e88b8994818c120c689bc24979ccab0c46bf6875c0e6",
	"_on_end": "4b5c7390967b4478dcb887967e11dfa25dd49a8ad277c44a0d93d9813166abb4",
	"_on_slammed": "6cdbd3a8dc29544ff19c363c56926084e1c041c57d62b00d25d9138e7847eb05",
}
# 2026-10-17 (world rosters, design-v3/WORLD-ROSTERS.md): the lunge lane became a floor burst
# under a ball on the floor, so the gameplay pins and constants moved with it.
const CONSTANTS := {"HP": 45.0, "BURST_RADIUS": 2.6, "MARKER_RADIUS": 1.6, "BURST_DAMAGE": 10.0,
	"POP": 9.0, "SHOVE": 3.0, "SINK": 3.0, "TUNNEL_SPEED": 4.5, "WARN": 1.0, "BURST_REACH": 18.0}
var t := T.new("enemy_burrower_asset_test")
var fixture: Node3D


func _initialize() -> void:
	_run.call_deferred()


func _measure(node: Node) -> Dictionary:
	var counts := {"triangles": 0, "vertices": 0, "draws": 0}
	for m in node.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		t.check("no capsule fallback mesh", not mi.mesh is CapsuleMesh)
		for s in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(s)
			var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var ix = arrays[Mesh.ARRAY_INDEX]
			counts.vertices += vs.size()
			counts.triangles += (ix.size() if ix != null else vs.size()) / 3
			counts.draws += 1
			var mat := mi.get_active_material(s) as BaseMaterial3D
			t.check("opaque surface", mat != null and mat.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED)
			t.check("no persistent emission", mat != null and not mat.emission_enabled)
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			t.check("vertex paint", colors.size() == vs.size())
			for color in colors:
				if color.a < 0.999:
					t.check("opaque vertex paint", false)
	print("measured: %d T / %d V / %d D" % [counts.triangles, counts.vertices, counts.draws])
	t.check("triangle budget", counts.triangles > 0 and counts.triangles <= 10000)
	t.check("vertex budget", counts.vertices > 0 and counts.vertices <= 19100)
	t.check("draw budget", counts.draws > 0 and counts.draws <= 3)
	return counts


func _points(mi: MeshInstance3D) -> PackedVector3Array:
	var points := PackedVector3Array()
	for s in mi.mesh.get_surface_count():
		points.append_array(mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX])
	return points


func _spawn():
	var unit := Burrower.new()
	fixture.add_child(unit)
	unit.setup(null, null, fixture, Callable(), 1.0, {"kind": "burrower"})
	unit.set_physics_process(false)
	return unit


func _run() -> void:
	var packed := load(GLB) as PackedScene
	if not t.check("GLB loads", packed != null):
		quit(t.verdict())
		return
	var asset := packed.instantiate()
	for part in NAMED:
		t.check("named part " + part, asset.find_child(part, true, false) != null)
	var body := asset.find_child("BurrowHull", true, false) as MeshInstance3D
	var marker := asset.find_child("BurrowMarker", true, false) as MeshInstance3D
	_measure(asset)
	if body == null or marker == null:
		asset.free()
		quit(t.verdict())
		return
	var slots := []
	for s in body.mesh.get_surface_count():
		slots.append(body.mesh.surface_get_material(s).resource_name)
	t.check("body and tool slots", slots == ["fleet_paint", "working_tool"])
	t.eq("marker state slot", marker.mesh.surface_get_material(0).resource_name, "part_state")
	var reach := 0.0
	var bottom := INF
	var top := -INF
	for p in _points(body):
		reach = maxf(reach, Vector2(p.x, p.z).length())
		bottom = minf(bottom, p.y)
		top = maxf(top, p.y)
	print("body bounds: radial %.4f, Y %.4f..%.4f" % [reach, bottom, top])
	t.check("complete exposed body fits core", reach <= 0.801 and bottom >= -1.101 and top <= 1.101)
	t.near("exposed body height", top - bottom, 2.2, 0.002)
	t.check("marker flat envelope", marker.mesh.get_aabb().size.y <= 0.101)
	t.near("marker radius", marker.mesh.get_aabb().size.x / 2.0, 1.6, 0.001)
	var morph := marker.find_blend_shape_by_name("MarkerWorkingLip")
	t.check("named inset motion", morph >= 0)
	if morph >= 0:
		var moved := 0
		for s in marker.mesh.get_surface_count():
			var base: PackedVector3Array = marker.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			var delta: PackedVector3Array = marker.mesh.surface_get_blend_shape_arrays(s)[morph][Mesh.ARRAY_VERTEX]
			for i in delta.size():
				var d := delta[i] if marker.mesh.blend_shape_mode == Mesh.BLEND_SHAPE_MODE_RELATIVE else delta[i] - base[i]
				if d.length() > 0.001:
					moved += 1
					t.check("inset raises flat by 0.07 m", d.is_equal_approx(Vector3(0, 0.07, 0)))
					t.check("inset rest dimensions", absf(base[i].x) <= 0.501 and base[i].z >= 0.899 and base[i].z <= 1.101)
			t.check("real inset geometry moves", moved >= 20)
	asset.free()
	fixture = Node3D.new()
	root.add_child(fixture)
	var unit = _spawn()
	if not t.check("runtime loads body and named inset", unit._crew.mesh is ArrayMesh and unit._marker_lip >= 0):
		fixture.free()
		quit(t.verdict())
		return
	_measure(unit)
	t.check("GLB replaces complete primitive crew", unit._crew != null and unit._crew.mesh is ArrayMesh and unit._crew.name == "BurrowBody")
	t.check("body keeps reaction parenting", unit._crew.get_parent() == unit.reaction_pivot)
	t.check("marker outside hidden body", unit._marker.get_parent() == unit)
	t.eq("hidden collision layer", unit.collision_layer, 0)
	var shapes := unit.find_children("*", "CollisionShape3D", true, false)
	t.eq("one existing collider", shapes.size(), 1)
	if shapes.size() == 1:
		var cap := shapes[0].shape as CapsuleShape3D
		t.check("existing capsule dimensions", cap != null and is_equal_approx(cap.radius, 0.8) and is_equal_approx(cap.height, 2.2))
	var source := FileAccess.get_file_as_string("res://src/combat/burrower.gd")
	for function in GAMEPLAY:
		var body_source := "func " + source.get_slice("\nfunc " + function + "(", 1).get_slice("\nfunc ", 0)
		body_source = ("func " + function + "(" + body_source.trim_prefix("func ")).strip_edges()
		t.eq("unchanged gameplay " + function, body_source.sha256_text(), GAMEPLAY[function])
	var consts: Dictionary = unit.get_script().get_script_constant_map()
	for key in CONSTANTS:
		t.near("unchanged constant " + key, consts[key], CONSTANTS[key])
	for clock in [0.0, 0.25, 0.5, 1.0]:
		unit.phase = unit.Phase.WARN
		unit._t = clock
		unit._pose()
		t.near("WARN uses existing clock", unit._marker.get_blend_shape_value(unit._marker_lip), clock)
		t.near("pose does not advance clock", unit._t, clock)
		t.near("all body stays sunk in WARN", unit._crew.position.y, -3.0)
		t.check("no body leaks above nominal floor", top + unit._crew.position.y < -1.1)
		t.check("marker visible in WARN", unit._marker.visible)
	unit.phase = unit.Phase.LIVE
	unit._set_hidden(false)
	unit._pose()
	t.near("LIVE reveals body", unit._crew.position.y, 0.0)
	t.check("LIVE hides marker", not unit._marker.visible)
	t.near("LIVE resets inset", unit._marker.get_blend_shape_value(unit._marker_lip), 0.0)
	t.eq("existing exposed collision layer", unit.collision_layer, 4)
	unit.phase = unit.Phase.ROAM
	unit._on_end()
	unit._pose()
	t.check("sink restores hidden marker", unit.hidden and unit._marker.visible and unit._crew.position.y == -3.0)
	var other = _spawn()
	t.check("cached body and marker meshes", unit._crew.mesh == other._crew.mesh and unit._marker.mesh == other._marker.mesh)
	t.check("independent flash materials", unit._material != other._material)
	unit.phase = unit.Phase.WARN
	unit._t = 1.0
	unit._pose()
	t.near("independent marker pose", other._marker.get_blend_shape_value(other._marker_lip), 0.0)
	t.check("body flash slot registered", unit._crew.get_surface_override_material(0) == unit._material)
	unit.flash()
	unit._update_flash(0.0)
	t.check("existing hit flash works", unit._material.emission_enabled)
	unit._update_flash(2.0)
	t.check("hit flash settles", not unit._material.emission_enabled and unit._material.albedo_color == Color.WHITE)
	fixture.free()
	quit(t.verdict())
