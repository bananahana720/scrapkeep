extends SceneTree

const ASSETS := "res://assets/models/bosses/"
const Warden := preload("res://src/combat/warden.gd")
const WardenKit := preload("res://src/combat/warden_kit.gd")
const Floors := preload("res://src/boss/waking_floors.gd")
const Waking := preload("res://src/boss/waking.gd")
const Posture := preload("res://src/core/boss_posture.gd")
const CLIPS := {
	"sleeping": 3.0, "wake": 1.6, "pulse_warn": 2.0, "pulse": 0.5,
	"floor_warn": 1.0, "floor_drop": 0.6,
	"floor_warn_seam": 1.0, "floor_drop_seam": 0.6,
	"floor_warn_bedrock": 1.0, "floor_drop_bedrock": 0.6,
	"core_open": 0.4, "pit_defeat": 1.2,
}
const BASE_NODES := [
	"WakingRoot", "CeilingCollar", "BellHousing", "BellSocket", "SpineOuter", "SpineInner",
	"CombatSeat", "SeatTether", "CoreSocket", "SeatCasting",
	"IntakeVane0", "IntakeVane1", "IntakeVane2",
	"FloorSocket1", "FloorSocket2", "FloorSocket3", "PitSocket",
]
const KIT_NODES := [
	"CombatSeatAnchor", "CoreSocket", "KitMount", "ReactorCore", "WeakPoint",
	"CoreGlass", "CoreUnready", "CoreLive",
	"CoreShutter0", "CoreShutter1", "CoreShutter2",
	"PressureLip0", "PressureLip1", "PressureLip2", "Vent0", "Vent1", "Vent2",
	"CollarSpoil", "CollarSeam", "CollarBedrock",
]
const MATERIALS := ["ancient_enamel", "dark_joint", "glass", "signal_surface"]

var failures := 0
var fixture_dir := ""


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fixture-dir="):
			fixture_dir = arg.trim_prefix("--fixture-dir=")
	_run.call_deferred()


func check(label: String, condition: bool) -> void:
	print("%s -> %s" % [label, "PASS" if condition else "FAIL"])
	if not condition:
		failures += 1


func node(scene: Node, name_: String) -> Node3D:
	return scene.find_child(name_, true, false) as Node3D


func open_asset(filename: String) -> Node3D:
	if fixture_dir.is_empty():
		var packed := load(ASSETS + filename) as PackedScene
		check(filename + " imports as PackedScene", packed != null)
		return packed.instantiate() as Node3D if packed != null else null
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_file(fixture_dir.path_join(filename), state)
	check(filename + " scratch GLB parses", error == OK)
	return document.generate_scene(state) as Node3D if error == OK else null


func measure(scene: Node3D, cap: Vector3i, filename: String) -> void:
	var counts := Vector3i.ZERO
	var finite := true
	var lower_radius := 0.0
	var low_height := INF
	var top_height := -INF
	for part in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := part as MeshInstance3D
		check(filename + " has mesh on " + String(mi.name), mi.mesh != null)
		if mi.mesh == null:
			continue
		for surface in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			counts.x += (indices.size() if not indices.is_empty() else vertices.size()) / 3
			counts.y += vertices.size()
			counts.z += 1
			var mat := mi.mesh.surface_get_material(surface) as BaseMaterial3D
			check(filename + " shared material on " + String(mi.name), mat != null and String(mat.resource_name) in MATERIALS)
			if mat != null:
				check("neutral enamel and glass emission " + String(mi.name), not mat.emission_enabled)
				if mat.albedo_texture != null:
					check("texture cap " + String(mi.name), mat.albedo_texture.get_width() <= 2048 and mat.albedo_texture.get_height() <= 2048)
			for v in vertices:
				var at: Vector3 = scene.to_local(mi.to_global(v))
				finite = finite and at.is_finite()
				low_height = minf(low_height, at.y)
				top_height = maxf(top_height, at.y)
				if at.y <= 3.2001:
					lower_radius = maxf(lower_radius, Vector2(at.x, at.z).length())
	print("WAK_BUDGET %s tris=%d verts=%d draws=%d cap=%s" % [filename, counts.x, counts.y, counts.z, cap])
	check(filename + " triangle cap", counts.x > 0 and counts.x <= cap.x)
	check(filename + " vertex cap", counts.y > 0 and counts.y <= cap.y)
	check(filename + " draw cap", counts.z > 0 and counts.z <= cap.z)
	check(filename + " finite vertices", finite)
	check(filename + " low geometry fits Warden radius 2.8", lower_radius <= Warden.RADIUS + 0.001)
	if filename.ends_with("base.glb"):
		check("Waking 25 m envelope", absf(low_height) < 0.001 and absf(top_height - 25.0) < 0.001)
	check(filename + " visual geometry has no colliders", scene.find_children("*", "CollisionObject3D", true, false).is_empty() and scene.find_children("*", "CollisionShape3D", true, false).is_empty())


func dimensions(scene: Node, part_name: String, expected: Vector3) -> void:
	var part := node(scene, part_name) as MeshInstance3D
	if part == null or part.mesh == null:
		check(part_name + " measurable mesh", false)
		return
	var actual := part.mesh.get_aabb().size
	check(part_name + " metre dimensions " + str(actual), actual.distance_to(expected) < 0.025)


func saved_transforms(scene: Node) -> Dictionary:
	var saved := {}
	for child in scene.find_children("*", "Node3D", true, false):
		saved[child] = child.transform
	return saved


func sample(animator: AnimationPlayer, saved: Dictionary, clip: String, seconds: float) -> bool:
	animator.stop()
	for child in saved:
		child.transform = saved[child]
	if not animator.has_animation(clip):
		return false
	animator.play(clip)
	animator.seek(seconds, true)
	animator.advance(0.0)
	return true


func animations(scene: Node3D, filename: String) -> void:
	var animator := scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
	check(filename + " AnimationPlayer", animator != null)
	if animator == null:
		return
	var rest := saved_transforms(scene)
	for clip in CLIPS:
		check(filename + " required clip " + clip, animator.has_animation(clip))
		if not animator.has_animation(clip):
			continue
		var animation := animator.get_animation(clip)
		check(filename + " duration " + clip, absf(animation.length - float(CLIPS[clip])) < 0.035)
		check(filename + " one-shot " + clip, animation.loop_mode == Animation.LOOP_NONE)
		# Runtime GLTFDocument discards constant channels; the editor retains them.
		# These paired base clips deliberately leave all motion to the kit controls.
		var paired_still: bool = filename.ends_with("base.glb") and clip in ["floor_warn", "floor_warn_seam", "floor_warn_bedrock", "core_open"]
		var paths_ok: bool = animation.get_track_count() > 0 or paired_still
		for track in animation.get_track_count():
			var path := animation.track_get_path(track)
			var controlled: Node = animator.get_node(animator.root_node).get_node_or_null(NodePath(path.get_concatenated_names()))
			paths_ok = paths_ok and controlled != null
			if controlled != null:
				paths_ok = paths_ok and not String(controlled.name) in ["WakingRoot", "WakingKit", "CombatSeat", "CombatSeatAnchor", "CoreSocket", "KitMount", "WeakPoint", "FloorSocket1", "FloorSocket2", "FloorSocket3", "PitSocket"]
			paths_ok = paths_ok and animation.track_get_type(track) in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]
		check(filename + " valid rigid paths with no root motion " + clip, paths_ok)
		for fraction in [0.0, 0.25, 0.5, 0.75, 1.0]:
			sample(animator, rest, clip, animation.length * fraction)
			var finite := true
			for child in rest:
				finite = finite and child.transform.is_finite() and absf(child.transform.basis.determinant()) > 0.0000000001
			check(filename + " finite nonsingular pose " + clip + " " + str(fraction), finite)
	if filename.ends_with("base.glb"):
		var spine := node(scene, "SpineInner")
		if spine != null and sample(animator, rest, "floor_drop", 0):
			var start_scale := spine.scale.y
			sample(animator, rest, "floor_drop", 0.6)
			check("visual spine extends exactly four metres", absf((spine.scale.y - start_scale) * 15.6 - Floors.SPACING) < 0.002)
			check("spine top stays on BellSocket", spine.position.is_equal_approx(Vector3.ZERO))
	else:
		var lip := node(scene, "PressureLip0")
		if lip != null and sample(animator, rest, "pulse_warn", 2):
			check("pulse warning raises working face 0.55 m", absf(lip.position.y - 1.55) < 0.002)
			if sample(animator, rest, "pulse", 0.1):
				check("pulse snaps pressure face", lip.position.y < 1.0)
		var live := node(scene, "CoreLive")
		var unready := node(scene, "CoreUnready")
		if live != null and unready != null and sample(animator, rest, "core_open", 0.4):
			check("mint opens only in core_open", live.scale.is_equal_approx(Vector3.ONE) and unready.scale.length() < 0.01)
		for entry in [["floor_warn", "floor_drop", "CollarSpoil"], ["floor_warn_seam", "floor_drop_seam", "CollarSeam"], ["floor_warn_bedrock", "floor_drop_bedrock", "CollarBedrock"]]:
			var collar := node(scene, entry[2])
			if collar == null:
				continue
			if sample(animator, rest, entry[0], 1):
				var initial: Transform3D = rest[collar]
				check(entry[2] + " disengages during one-second warning", absf(collar.position.y - initial.origin.y - 0.32) < 0.002)
			if sample(animator, rest, entry[1], 0.6):
				check(entry[2] + " is spent after floor drop", collar.scale.length() < 0.01)
		if sample(animator, rest, "pit_defeat", 1.2):
			var reactor := node(scene, "ReactorCore")
			if reactor != null:
				check("pit defeat collapses reactor inward", reactor.scale.length() < 0.15)
			for name_ in ["CollarSpoil", "CollarSeam", "CollarBedrock"]:
				var collar := node(scene, name_)
				if collar != null:
					check("pit defeat does not drop another collar " + name_, collar.transform.is_equal_approx(rest[collar]))
	animator.stop()
	for child in rest:
		child.transform = rest[child]


func _run() -> void:
	check("four chunks and three 4-m elevated floors", Posture.CHUNKS == 4 and Floors.SPACING == 4.0 and Waking.FLOOR_NAMES.size() == 3)
	var family := WardenKit.new()
	family.family = "reactor"
	check("reactor target matches real family offset", family.point_offset().is_equal_approx(Vector3(0, 5.2, 0)) and Warden.FAMILY_POINT_RADIUS == 1.3)
	family.free()
	for entry in [["boss_waking_base.glb", BASE_NODES, Vector3i(10000, 9600, 32)], ["boss_waking_kit.glb", KIT_NODES, Vector3i(4000, 4000, 18)]]:
		var scene := open_asset(entry[0])
		if scene == null:
			continue
		root.add_child(scene)
		check(entry[0] + " identity root in metres", scene.transform.is_equal_approx(Transform3D.IDENTITY))
		for name_ in entry[1]:
			check(entry[0] + " required node " + name_, node(scene, name_) != null)
		measure(scene, entry[2], entry[0])
		if entry[0].ends_with("base.glb"):
			var waking_root := node(scene, "WakingRoot")
			check("WakingRoot identity anchor", waking_root != null and waking_root.transform.is_equal_approx(Transform3D.IDENTITY))
			dimensions(scene, "CeilingCollar", Vector3(8, 1.2, 8))
			dimensions(scene, "BellHousing", Vector3(7, 4, 7))
			dimensions(scene, "SpineOuter", Vector3(1.8, 5.6, 1.8))
			dimensions(scene, "SpineInner", Vector3(1.2, 12.4, 1.2))
			var tether := node(scene, "SeatTether")
			if tether != null:
				check("spine lower attachment matches seat casting", tether.global_position.is_equal_approx(Vector3(0, 8.4, 0)))
				var inner := node(scene, "SpineInner")
				if inner != null:
					check("spine terminates at SeatTether", inner.to_global(Vector3(0, -15.6, 0)).is_equal_approx(tether.global_position))
			for i in 3:
				dimensions(scene, "VaneCasting%d" % i, Vector3(1.4, 7, 2.2))
			for socket in [["FloorSocket1", 12.0], ["FloorSocket2", 8.0], ["FloorSocket3", 4.0], ["PitSocket", 0.0]]:
				var found := node(scene, socket[0])
				if found != null:
					check(socket[0] + " floor reference", found.global_position.is_equal_approx(Vector3(0, socket[1], 0)))
		else:
			dimensions(scene, "CoreGlass", Vector3(2.6, 2.6, 2.6))
			for i in 3:
				dimensions(scene, "ShutterCasting%d" % i, Vector3(0.25, 1.4, 0.8))
				dimensions(scene, "PressureCasting%d" % i, Vector3(0.4, 0.35, 1.8))
			for name_ in ["CoreSocket", "WeakPoint", "KitMount", "ReactorCore"]:
				var found := node(scene, name_)
				if found != null:
					check(name_ + " stays 6.8 m above floor", found.global_position.is_equal_approx(Vector3(0, 6.8, 0)))
			for name_ in ["CollarSpoil", "CollarSeam", "CollarBedrock"]:
				dimensions(scene, name_, Vector3(3, 0.65, 3))
		animations(scene, entry[0])
		scene.free()
	print("dress_wak_assets_test: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
