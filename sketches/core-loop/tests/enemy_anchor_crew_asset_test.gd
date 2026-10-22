# 2026-10-12, W13 smoke triage: class c re-pin for 5b903a3, bbe53ec, 17429d6.
# counter.gd SHA256 56b1e9fd180b0c5c06ba67013011c12a26d6f6f1989cb6c140620334b06f0cca -> 5e3d17ed123286ed2c22808f3051a76d450e56697828d7277cef3b8f0af7c554; merged pack stagger, rename and shared-recovery changes.
extends SceneTree

const Anchor := preload("res://src/combat/anchor_crew.gd")
const T := preload("res://tests/support/t.gd")
const GLB := "res://assets/models/world_three/enemy_anchor_crew.glb"
const BASE_CONSTANTS := {"LANE_LENGTH": 18.0, "LANE_WIDTH": 2.4, "PULL": 6.0,
	"DOWN": 14.0, "WINCH": 2.0, "NEAR": 1.5, "POST_HEIGHT": 1.2, "HP": 60.0}
const GAMEPLAY := {
	"_configure": "aa6f4ddd3b49700b2cde770e833b9577bc61880f4b1b9337b960c37e870a43eb",
	"anchor": "5d82c9d5dc860b5489b13a06f6c8c78cd755dc2642a7556dcea5fedf48061d20",
	"_commit": "33b68cca3be97d85f1ceca25cd20e9ab9c6bb1fd1a170d1e53462ef00f51a2b6",
	"_go_live": "32432948314db1ed83c1f168c4347b98e0f20bcf8bef23eb80f0143003fb7c82",
	"_live": "284881b86d5ee5a6fc1362199a770222a6ffac05dbc405e07278406ebf451d8e",
	"_on_broken": "dba8bcae678917a5752b106c595b6df15ed90cc0b0c911994414c1a21f3976fd",
}
const SOCKETS := {
	"reel_axis": Vector3(0, 0.9, -1.3), "post_base": Vector3(0, 0, -1.3),
	"post_top": Vector3(0, 2.4, -1.3), "catch_endpoint": Vector3(0, 1.2, 0),
	"AnchorHead": Vector3(0, 1.3, 0), "WinchPost": Vector3(0, 1.2, -1.3),
	"WinchClutch": Vector3(0.45, 0.9, -1.3), "HostileHook": Vector3(0, 1.2, 0.6),
}

var t := T.new("enemy_anchor_crew_asset_test")
var fixture: Node3D


func _initialize() -> void:
	_run.call_deferred()


func _spawn():
	var actor := Anchor.new()
	fixture.add_child(actor)
	actor.setup(null, null, fixture, Callable(), 1.0, {"kind": "anchor_crew"})
	actor.set_physics_process(false)
	return actor


func _material(mi: MeshInstance3D, surface: int) -> BaseMaterial3D:
	var mat: Material = mi.get_surface_override_material(surface)
	if mat == null:
		mat = mi.material_override
	return (mat if mat != null else mi.mesh.surface_get_material(surface)) as BaseMaterial3D


func _measure(node: Node) -> Dictionary:
	var tris := 0
	var verts := 0
	var draws := 0
	var opaque := true
	var emission := false
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		for surface in mi.mesh.get_surface_count():
			draws += 1
			var arrays := mi.mesh.surface_get_arrays(surface)
			var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices = arrays[Mesh.ARRAY_INDEX]
			verts += positions.size()
			tris += (indices.size() if indices != null else positions.size()) / 3
			var mat := _material(mi, surface)
			opaque = opaque and mat != null and mat.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and mat.albedo_color.a == 1.0
			emission = emission or (mat != null and mat.emission_enabled)
			if arrays[Mesh.ARRAY_COLOR] != null:
				for color in arrays[Mesh.ARRAY_COLOR] as PackedColorArray:
					opaque = opaque and color.a == 1.0
	print("%s: %d T / %d V / %d surfaces" % [node.name, tris, verts, draws])
	t.check("budget " + str(node.name), tris > 0 and tris <= 10000 and verts > 0 and verts <= 19100 and draws == 3)
	t.check("opaque and unlit " + str(node.name), opaque and not emission)
	return {"tris": tris, "verts": verts, "draws": draws}


func _bone_points(mi: MeshInstance3D, rig: Skeleton3D, names: Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	var wanted := []
	for name in names:
		wanted.append(rig.find_bone(name))
	for surface in mi.mesh.get_surface_count():
		var arrays := mi.mesh.surface_get_arrays(surface)
		var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		for i in vs.size():
			for j in 4:
				if weights[i * 4 + j] > 0.99:
					var bind := bones[i * 4 + j]
					var bone := mi.skin.get_bind_bone(bind)
					if bone < 0:
						bone = rig.find_bone(mi.skin.get_bind_name(bind))
					if bone in wanted:
						out.append(rig.get_bone_global_pose(bone) * mi.skin.get_bind_pose(bind) * vs[i])
	return out


func _bounds(points: PackedVector3Array) -> AABB:
	var bounds := AABB(points[0], Vector3.ZERO) if not points.is_empty() else AABB()
	for p in points:
		bounds = bounds.expand(p)
	return bounds


func _geometry(actor) -> void:
	var rig: Skeleton3D = actor._windup_rig
	var body := actor.find_child("AnchorCrewBody", true, false) as MeshInstance3D
	var reel := actor.find_child("DeckReel", true, false) as MeshInstance3D
	var tools := actor.find_child("AnchorWorkingTools", true, false) as MeshInstance3D
	for name in SOCKETS:
		var bone := rig.find_bone(name)
		t.check("named part/socket " + name, bone >= 0)
		if bone >= 0:
			t.check("rest socket " + name, rig.get_bone_global_rest(bone).origin.distance_to(SOCKETS[name]) < 0.001)
	var core := _bone_points(body, rig, ["CrewBrace", "AnchorFeet"])
	var radius := 0.0
	var bottom := INF
	var top := -INF
	for p in core:
		radius = maxf(radius, Vector2(p.x, p.z).length())
		bottom = minf(bottom, p.y)
		top = maxf(top, p.y)
	t.check("measured rounded core", radius <= 0.8001 and absf(radius - 0.8) < 0.001 and absf(bottom + 1.1) < 0.001 and absf(top - 1.1) < 0.001,
		"radius %.4f, y %.4f..%.4f" % [radius, bottom, top])
	var reel_points := PackedVector3Array()
	for p in reel.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array:
		reel_points.append(reel.transform * p)
	var bounds := _bounds(reel_points)
	t.check("side-facing reel diameter/depth", bounds.size.distance_to(Vector3(0.9, 1.1, 1.1)) < 0.001 and reel.position.is_equal_approx(SOCKETS.reel_axis), str(bounds))
	var post := _bounds(_bone_points(body, rig, ["WinchPost"]))
	t.check("post measured 0.3 x 2.4 x 0.3", post.size.distance_to(Vector3(0.3, 2.4, 0.3)) < 0.001 and absf(post.position.y) < 0.001, str(post))
	var hook := _bounds(_bone_points(tools, rig, ["HostileHook"]))
	t.check("short hook measured", hook.size.distance_to(Vector3(0.20, 0.30, 0.12)) < 0.001, str(hook))
	var clutch := _bone_points(tools, rig, ["WinchClutch"])
	var clutch_radius := 0.0
	for p in clutch:
		clutch_radius = maxf(clutch_radius, Vector2(p.y - 0.9, p.z + 1.3).length())
	t.check("clutch diameter 0.3 and axial depth 0.1", absf(clutch_radius - 0.15) < 0.001 and absf(_bounds(clutch).size.x - 0.1) < 0.001)
	for mi in [body, tools]:
		t.check("skinned mesh registered " + str(mi.name), mi.skin != null and mi.get_node(mi.skeleton) == rig)
	for mi in [body, reel, tools, rig]:
		t.check("reaction parent " + str(mi.name), mi.get_parent() == actor.reaction_pivot)


func _pose(actor) -> void:
	var rig: Skeleton3D = actor._windup_rig
	var tools := actor.find_child("AnchorWorkingTools", true, false) as MeshInstance3D
	var body := actor.find_child("AnchorCrewBody", true, false) as MeshInstance3D
	var hook := rig.find_bone("HostileHook")
	var brace := rig.find_bone("CrewBrace")
	var feet_before := _bone_points(body, rig, ["AnchorFeet"])
	var hook_before := _bounds(_bone_points(tools, rig, ["HostileHook"]))
	actor.phase = actor.Phase.WARN
	actor._t = actor.warn_seconds * 0.5
	actor._pose()
	t.check("WARN reads existing clock", is_equal_approx(actor._t, 0.5) and is_equal_approx(rig.get_bone_pose_position(hook).z - rig.get_bone_rest(hook).origin.z, -0.10))
	actor._t = actor.warn_seconds
	actor._pose()
	var hook_warn := _bounds(_bone_points(tools, rig, ["HostileHook"]))
	t.check("WARN retracts actual hook vertices", hook_warn.position.distance_to(hook_before.position + Vector3(0, 0, -0.2)) < 0.001)
	t.check("WARN braces crew", rig.get_bone_pose_rotation(brace).angle_to(rig.get_bone_rest(brace).basis.get_rotation_quaternion()) > 0.13)
	t.check("feet remain planted", _bone_points(body, rig, ["AnchorFeet"]) == feet_before)
	for i in 3:
		var tab := rig.find_bone("ClutchTab" + str(i))
		t.check("clutch opens radially " + str(i), absf(rig.get_bone_pose_position(tab).distance_to(rig.get_bone_rest(tab).origin) - 0.09) < 0.001)
	t.check("WARN has no reel-in", is_zero_approx(actor._reel.rotation.x) and not actor._holding())
	actor.phase = actor.Phase.LIVE
	actor._pose()
	t.check("missed LIVE resets pose", rig.get_bone_pose_position(hook).is_equal_approx(rig.get_bone_rest(hook).origin) and is_zero_approx(actor._reel.rotation.x))
	var hold := Node.new()
	hold.set_script(HoldFixture)
	fixture.add_child(hold)
	actor.holds = hold
	actor._t = 0.125
	actor._pose()
	t.check("held LIVE spins reel on clock", absf(actor._reel.rotation.x - TAU * 0.125) < 0.001)
	hold.active = false
	actor._pose()
	t.check("released LIVE stops reel and closes clutch", is_zero_approx(actor._reel.rotation.x) and rig.get_bone_pose_position(hook).is_equal_approx(rig.get_bone_rest(hook).origin))
	actor.phase = actor.Phase.ROAM
	actor._pose()
	t.check("ROAM neutral", rig.get_bone_pose_rotation(brace).is_equal_approx(rig.get_bone_rest(brace).basis.get_rotation_quaternion()))
	actor.holds = null
	hold.free()


class HoldFixture extends Node:
	var active := true
	func held(_actor) -> bool:
		return active


func _run() -> void:
	var packed := load(GLB) as PackedScene
	t.check("GLB loads", packed != null)
	if packed == null:
		quit(t.verdict())
		return
	fixture = Node3D.new()
	root.add_child(fixture)
	var asset := packed.instantiate()
	fixture.add_child(asset)
	var raw := _measure(asset)
	var source := FileAccess.get_file_as_string("res://src/combat/anchor_crew.gd")
	for method in GAMEPLAY:
		var text := source.get_slice("func " + method + "(", 1).get_slice("\n\n", 0)
		t.check("base gameplay source " + method, text.sha256_text() == GAMEPLAY[method])
	# Shared combat files are not pinned here; the merge-time fence owns shared-file changes (2026-10-13, ENEMY-PINS).
	var actor = _spawn()
	var constants: Dictionary = actor.get_script().get_script_constant_map()
	for name in BASE_CONSTANTS:
		t.check("base constant " + name, constants.get(name) == BASE_CONSTANTS[name])
	t.check("base runtime health and timing", actor.hp == 60.0 and actor.warn_seconds == 1.0 and actor.live_seconds == 2.1 and actor.rest_seconds == 3.5)
	var live := _measure(actor)
	var body := actor.find_child("AnchorCrewBody", true, false) as MeshInstance3D
	var reel := actor.find_child("DeckReel", true, false) as MeshInstance3D
	var tools := actor.find_child("AnchorWorkingTools", true, false) as MeshInstance3D
	t.check("loader replaces capsule fallback", actor._crew == null and body != null and reel != null and tools != null and actor._windup_rig != null)
	for mi in actor.find_children("*", "MeshInstance3D", true, false):
		t.check("no primitive fallback " + str(mi.name), mi.mesh is ArrayMesh)
	t.check("live geometry equals GLB", raw == live)
	var shapes := actor.find_children("*", "CollisionShape3D", true, false)
	var capsule := (shapes[0] as CollisionShape3D).shape as CapsuleShape3D if shapes.size() == 1 else null
	t.check("original capsule collider", capsule != null and is_equal_approx(capsule.radius, 0.8) and is_equal_approx(capsule.height, 2.2) and (shapes[0] as Node3D).transform == Transform3D.IDENTITY)
	t.check("original catch endpoint", actor.anchor().is_equal_approx(actor.global_position + Vector3(0, 1.2, 0)))
	t.check("no new collision or lights", actor.find_children("*", "CollisionObject3D", true, false).is_empty() and actor.find_children("*", "Light3D", true, false).is_empty())
	if body != null and reel != null and tools != null and actor._windup_rig != null:
		_geometry(actor)
		_pose(actor)
		var other = _spawn()
		t.check("meshes cached", body.mesh == other.find_child("AnchorCrewBody", true, false).mesh and reel.mesh == other.find_child("DeckReel", true, false).mesh)
		t.check("pose and flash isolated", actor._windup_rig != other._windup_rig and actor._material != other._material)
		t.check("body and reel flash, hook stays separate", _material(body, 0) == actor._material and _material(reel, 0) == actor._material and _material(tools, 0) != actor._material)
		actor.flash()
		actor._update_flash(0.0)
		t.check("body hit flash", actor._material.emission_enabled and not other._material.emission_enabled)
		actor._update_flash(1.0)
		t.check("paint restores after flash", not actor._material.emission_enabled and actor._material.albedo_color == Color.WHITE and actor._material.vertex_color_use_as_albedo)
	fixture.free()
	quit(t.verdict())
