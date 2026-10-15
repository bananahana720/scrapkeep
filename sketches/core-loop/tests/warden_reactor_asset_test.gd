extends SceneTree

# KF5 (wave 13): the reactor relic's own body, warden_reactor.glb, built by
# tools/blender/warden_reactor.py from design-v3/wardens/reactor.md sections 1 and 5.
# Loads the GLB through the import and fails loud when it is missing. Checks every
# section 5 clip by name and length (within 0.05 s) and that each clip moves the nodes
# its row names; final_quiet darkens the seams one by one; the collider rule on the
# rest-pose mesh (below 2 m nothing passes the 2.8 m radius, above it nothing passes
# 3.8 m, the collider plus 1 m); the weak point (the core) where warden_kit.gd's
# point_offset puts it; the budget row read from the folded registry; no light node.

const WardenKit := preload("res://src/combat/warden_kit.gd")
const Warden := preload("res://src/combat/warden.gd")
const HeroAssets := preload("res://src/presentation/hero_assets.gd")
const GLB := "res://assets/models/warden_reactor.glb"
const REGISTRY := "res://assets/registry.json"
const BUDGETS := "res://assets/asset_budgets.json"
const ID := "warden_reactor"
const LOW := 2.0
const REACH := 1.0
const EPS := 0.001
# design-v3/wardens/reactor.md section 5: clip -> [length s, nodes it must move].
const CLIPS := {
	"idle": [4.0, ["Stack0", "Stack1", "Stack2", "SeamV0", "SeamV1", "SeamV2", "SeamV3"]],
	"pulse_warn": [2.0, ["Stack0", "Stack1", "Stack2", "SeamV0", "CageL", "CageR"]],
	"pulse": [0.3, ["Stack0", "Stack1", "Stack2", "SteamRing"]],
	"active": [0.5, ["JawL", "JawR", "CageL", "CageR", "WeakPoint"]],
	"chunk_lost": [1.0, ["Jacket0"]],
	"shrug": [0.4, ["Hardpoint"]],
	"gates_open": [0.6, ["GateL", "GateR"]],
	"pour": [1.0, ["PourLip"]],
	"final_quiet": [2.0, ["SeamV0", "SeamV1", "SeamV2", "SeamV3", "StackGlow0", "StackGlow1", "StackGlow2", "SeamRing"]],
}
const SEAMS := ["SeamV0", "SeamV1", "SeamV2", "SeamV3", "StackGlow0", "StackGlow1", "StackGlow2", "SeamRing"]

var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func check(label: String, ok: bool) -> void:
	checks += 1
	print("[%s] %s" % [label, "PASS" if ok else "FAIL"])
	if not ok:
		failures += 1


func finish() -> void:
	print("warden_reactor_asset_test: %s (%d checks)" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)


func _run() -> void:
	# ResourceLoader.exists() alone still answers true from the .import file and the
	# .godot/imported cache after the source is deleted; the source file must exist.
	if not FileAccess.file_exists(GLB) or not ResourceLoader.exists(GLB):
		check("GLB present at " + GLB, false)
		finish()
		return
	var packed := load(GLB) as PackedScene
	check("GLB imports as a scene", packed != null)
	if packed == null:
		finish()
		return
	var body := packed.instantiate() as Node3D
	root.add_child(body)
	check_lights(body)
	check_clips(body)
	check_collider(body)
	check_point(body)
	check_budget(body)
	check_ram_materials(body)
	body.free()
	finish()


func check_lights(body: Node3D) -> void:
	check("no light node in the GLB", body.find_children("*", "Light3D", true, false).is_empty())


func check_ram_materials(body: Node3D) -> void:
	# KF7d round 4: six checks cover the runtime paint and the shipped ram slots.
	var hero := HeroAssets.new()
	var hydraulic: StandardMaterial3D = hero.material("hydraulic") if HeroAssets.SLOTS.has("hydraulic") else null
	check("hydraulic runtime material exists", hydraulic != null)
	check("hydraulic has no wear layer", hydraulic != null and not hydraulic.detail_enabled)
	check("hydraulic has no painted texture", hydraulic != null and hydraulic.albedo_texture == null)
	check("hydraulic uses vertex colour", hydraulic != null and hydraulic.vertex_color_use_as_albedo)
	var enamel := hero.material("ancient_enamel") as StandardMaterial3D
	check("ancient_enamel positive control has wear layer", enamel != null and enamel.detail_enabled)
	var rams := body.find_child("JawRams", true, false) as MeshInstance3D
	var hydraulic_only := rams != null and rams.mesh != null and rams.mesh.get_surface_count() > 0
	if hydraulic_only:
		for surface in rams.mesh.get_surface_count():
			var mat := rams.mesh.surface_get_material(surface)
			hydraulic_only = hydraulic_only and mat != null and mat.resource_name == "hydraulic"
	check("every JawRams primitive uses hydraulic", hydraulic_only)
	hero.free()


func moved_nodes(anim: Animation) -> Dictionary:
	var out := {}
	for t in anim.get_track_count():
		var path := anim.track_get_path(t)
		if path.get_name_count() > 0:
			out[str(path.get_name(path.get_name_count() - 1))] = t
	return out


func track_of(anim: Animation, node: String, type: int) -> int:
	for t in anim.get_track_count():
		var path := anim.track_get_path(t)
		if anim.track_get_type(t) == type and path.get_name_count() > 0 and str(path.get_name(path.get_name_count() - 1)) == node:
			return t
	return -1


func check_clips(body: Node3D) -> void:
	var players := body.find_children("*", "AnimationPlayer", true, false)
	check("one AnimationPlayer", players.size() == 1)
	if players.is_empty():
		return
	var player := players[0] as AnimationPlayer
	for clip in CLIPS:
		var want: float = CLIPS[clip][0]
		var has := player.has_animation(clip)
		check("clip %s present" % clip, has)
		if not has:
			continue
		var anim := player.get_animation(clip)
		print("CLIP ", clip, " length=", anim.length, " want=", want)
		check("clip %s length %.2f within 0.05 s" % [clip, want], absf(anim.length - want) <= 0.05)
		var moved := moved_nodes(anim)
		for node in CLIPS[clip][1]:
			check("clip %s moves %s" % [clip, node], moved.has(node) and moves(anim, node))
	if player.has_animation("pulse_warn"):
		var warn := player.get_animation("pulse_warn")
		for i in 3:
			var t := track_of(warn, "Stack%d" % i, Animation.TYPE_POSITION_3D)
			var rise := 0.0
			if t >= 0:
				rise = warn.position_track_interpolate(t, warn.length).y - warn.position_track_interpolate(t, 0.0).y
			print("STACK_RISE ", i, " ", rise)
			check("pulse_warn lifts Stack%d 0.6 m straight up" % i, absf(rise - 0.6) < 0.02)
	if player.has_animation("final_quiet"):
		var quiet := player.get_animation("final_quiet")
		var order := []
		for seam in SEAMS:
			var t := track_of(quiet, seam, Animation.TYPE_SCALE_3D)
			var dark_at := INF
			if t >= 0:
				var step := 0.0
				while step <= quiet.length + 0.001:
					if quiet.scale_track_interpolate(t, step).length() < 0.2:
						dark_at = step
						break
					step += 1.0 / 30.0
			order.append(dark_at)
		print("SEAM_DARK_AT ", order)
		var staggered := true
		for i in order.size():
			staggered = staggered and is_finite(order[i])
			if i > 0:
				staggered = staggered and order[i] > order[i - 1] + 0.05
		check("final_quiet darkens every seam, one by one", staggered)


func moves(anim: Animation, node: String) -> bool:
	for t in anim.get_track_count():
		var path := anim.track_get_path(t)
		if path.get_name_count() == 0 or str(path.get_name(path.get_name_count() - 1)) != node:
			continue
		var first: Variant = null
		var step := 0.0
		while step <= anim.length + 0.001:
			var v: Variant
			match anim.track_get_type(t):
				Animation.TYPE_POSITION_3D:
					v = anim.position_track_interpolate(t, step)
				Animation.TYPE_ROTATION_3D:
					v = anim.rotation_track_interpolate(t, step)
				Animation.TYPE_SCALE_3D:
					v = anim.scale_track_interpolate(t, step)
				_:
					v = null
			if v == null:
				break
			if first == null:
				first = v
			elif v is Quaternion:
				if (v as Quaternion).angle_to(first) > 0.01:
					return true
			elif (v as Vector3).distance_to(first) > 0.005:
				return true
			step += 1.0 / 30.0
	return false


func local_vertices(body: Node3D) -> Array:
	var out := []
	for found in body.find_children("*", "MeshInstance3D", true, false):
		var mi := found as MeshInstance3D
		if mi.mesh == null or not mi.visible:
			continue
		var xf := body.global_transform.affine_inverse() * mi.global_transform
		for s in mi.mesh.get_surface_count():
			for v in mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
				out.append([mi.name, xf * v])
	return out


func check_collider(body: Node3D) -> void:
	var low_max := 0.0
	var high_max := 0.0
	var low_worst := ""
	var high_worst := ""
	var bottom := INF
	for row in local_vertices(body):
		var at: Vector3 = row[1]
		var r := Vector2(at.x, at.z).length()
		bottom = minf(bottom, at.y)
		if at.y <= LOW:
			if r > low_max:
				low_max = r
				low_worst = row[0]
		elif r > high_max:
			high_max = r
			high_worst = row[0]
	print("COLLIDER low_max=%.3f (%s) high_max=%.3f (%s) bottom=%.3f" % [low_max, low_worst, high_max, high_worst, bottom])
	check("below 2 m nothing passes the collider radius", low_max <= Warden.RADIUS + EPS)
	check("above 2 m nothing passes 1 m beyond the collider", high_max <= Warden.RADIUS + REACH + EPS)
	check("origin at the base: nothing below it", bottom >= -EPS)


func check_point(body: Node3D) -> void:
	var weak := body.find_child("WeakPoint", true, false) as Node3D
	check("WeakPoint node", weak != null)
	if weak == null:
		return
	var kit := WardenKit.new()
	kit.family = "reactor"
	var want: Vector3 = kit.point_offset() + Vector3.UP * Warden.HALF_HEIGHT
	kit.free()
	var at: Vector3 = body.global_transform.affine_inverse() * weak.global_position
	print("WEAK_POINT at=", at, " want=", want)
	check("core sits on the kit's point offset", at.distance_to(want) < 0.05)


func check_budget(body: Node3D) -> void:
	var registry: Variant = JSON.parse_string(FileAccess.get_file_as_string(REGISTRY))
	var budgets: Variant = JSON.parse_string(FileAccess.get_file_as_string(BUDGETS))
	var row := {}
	if registry is Dictionary:
		for a in registry.get("assets", []):
			if a is Dictionary and a.get("id", "") == ID:
				row = a
	check("folded registry row " + ID, not row.is_empty() and row.get("path", "") == GLB and row.get("class", "") == "warden_base")
	if row.is_empty() or not (budgets is Dictionary):
		return
	var cap: Dictionary = budgets.classes.get(row["class"], {})
	var tris := 0
	var verts := 0
	var draws := 0
	for found in body.find_children("*", "MeshInstance3D", true, false):
		var mi := found as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			draws += 1
			var arrays := mi.mesh.surface_get_arrays(s)
			var pos: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var idx = arrays[Mesh.ARRAY_INDEX]
			tris += (idx.size() if idx != null else pos.size()) / 3
			verts += pos.size()
	print("BUDGET tris=%d/%d verts=%d/%d draws=%d/%d" % [tris, cap.get("tris", 0), verts, cap.get("verts", 0), draws, cap.get("draws", 0)])
	check("within the warden_base budget", not cap.is_empty() and tris <= cap.tris and verts <= cap.verts and draws <= cap.draws)
