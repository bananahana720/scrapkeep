extends SceneTree
# KF6, wave 13 (design-v3/wardens/swarm.md sections 1.1, 5 and 8): the swarm remnant's own body.
# warden_swarm.glb is the hive (warden_base) and warden_swarm_kit_drones.glb the drone dressing
# (warden_kit), both built by tools/blender/warden_swarm.py. Checks, all on the imported scenes:
# - every section 5 clip by name, its length within 0.05 s, on the body and on the drone kit (the
#   drones move in the same clips, so KF8 plays one name on both players);
# - the collider rule on the rest-pose mesh: below 2 m above the base nothing passes the 2.8 m
#   collider radius (warden.gd RADIUS), above it nothing passes 1 m beyond it;
# - the queen: WeakPoint sits at warden_kit.gd's swarm point_offset plus warden.gd HALF_HEIGHT
#   (the body's base is the collider's floor, as hero_assets.gd places the clamp base), and the
#   queen's lit core is there;
# - the budget rows from the folded assets/registry.json and assets/asset_budgets.json;
# - no light node. A missing GLB fails loud.

const Warden := preload("res://src/combat/warden.gd")
const WardenKit := preload("res://src/combat/warden_kit.gd")
const Roster := preload("res://src/combat/roster.gd")

const BODY := "res://assets/models/warden_swarm.glb"
const KIT := "res://assets/models/warden_swarm_kit_drones.glb"
const REGISTRY := "res://assets/registry.json"
const BUDGETS := "res://assets/asset_budgets.json"
# Section 5: pulse is the 2.0 s charge then the 0.4 s pulse in one clip; active loops at 4.0 s
# (the sheet gives no length); brood_dark is 1.0 s and holds its last pose.
const CLIPS := {"idle": 4.0, "pulse": 2.4, "active": 4.0, "hoist_ride": 2.0, "snip": 2.0,
	"stagger_open": 4.0, "chunk_shed": 1.0, "brood_dark": 1.0, "break": 3.0}
const LOOPS := ["idle", "active"]
const LENGTH_TOLERANCE := 0.05
const LOW_BAND := 2.0
const REACH_BEYOND := 1.0
const EPS := 0.005
const POINT_TOLERANCE := 0.05
const QUEEN_CORE_RADIUS := 1.0
const SHUTTERED_CELLS := 19
const GRIPS := 3
const SHED_RINGS := ["Ring5", "Ring4", "Ring3", "Ring2"]
const SHED_DROP := 2.0

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func check(label: String, ok: bool, detail: String = "") -> void:
	if not ok:
		failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func load_scene(path: String) -> Node3D:
	if not ResourceLoader.exists(path):
		check("GLB exists", false, path + " is missing: build it with tools/blender/warden_swarm.py")
		return null
	var packed := load(path) as PackedScene
	check("GLB imports", packed != null, path)
	return packed.instantiate() as Node3D if packed != null else null


func meshes(node: Node) -> Array:
	return node.find_children("*", "MeshInstance3D", true, false)


func to_root(node: Node3D, ancestor: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var current: Node = node
	while current != ancestor and current != null:
		if current is Node3D:
			result = (current as Node3D).transform * result
		current = current.get_parent()
	return result


func counts(node: Node) -> Dictionary:
	var result := {"tris": 0, "verts": 0, "draws": 0}
	for mi: MeshInstance3D in meshes(node):
		for surface in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices = arrays[Mesh.ARRAY_INDEX]
			result.tris += (indices.size() if indices != null else vertices.size()) / 3
			result.verts += vertices.size()
			result.draws += 1
	return result


# Rest-pose vertices of every surface in the scene root's frame, with the surface's material name.
func rest_points(scene: Node3D) -> Array:
	var out: Array = []
	for mi: MeshInstance3D in meshes(scene):
		var xf := to_root(mi, scene)
		for surface in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(surface)
			var slot := mat.resource_name if mat != null else ""
			var vertices: PackedVector3Array = mi.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for v in vertices:
				out.append([xf * v, slot])
	return out


func check_clips(label: String, scene: Node3D) -> void:
	var players := scene.find_children("*", "AnimationPlayer", true, false)
	check(label + " one AnimationPlayer", players.size() == 1, "%d players" % players.size())
	if players.size() != 1:
		return
	var player := players[0] as AnimationPlayer
	for clip in CLIPS:
		var has := player.has_animation(clip)
		check("%s clip %s present" % [label, clip], has, str(player.get_animation_list()))
		if has:
			var length := player.get_animation(clip).length
			check("%s clip %s length" % [label, clip], absf(length - CLIPS[clip]) <= LENGTH_TOLERANCE,
				"%.3f s, want %.2f within %.2f" % [length, CLIPS[clip], LENGTH_TOLERANCE])
			check("%s clip %s moves something" % [label, clip], player.get_animation(clip).get_track_count() > 0,
				"%d tracks" % player.get_animation(clip).get_track_count())


# Section 3.2: each of the four chunks sheds a ring, and the falling ring is the visible cause of
# the pool's rise. chunk_shed carries the fall on every shed ring bone, so KF8 enables chunk n's.
func check_shed_rings(scene: Node3D) -> void:
	var players := scene.find_children("*", "AnimationPlayer", true, false)
	if players.size() != 1 or not (players[0] as AnimationPlayer).has_animation("chunk_shed"):
		check("chunk_shed for the shed rings", false, "no chunk_shed clip")
		return
	var anim := (players[0] as AnimationPlayer).get_animation("chunk_shed")
	for ring in SHED_RINGS:
		var drop := 0.0
		var found := false
		for track in anim.get_track_count():
			if anim.track_get_type(track) != Animation.TYPE_POSITION_3D:
				continue
			if String(anim.track_get_path(track)).get_slice(":", 1) != ring:
				continue
			found = true
			var first := anim.position_track_interpolate(track, 0.0)
			var last := anim.position_track_interpolate(track, anim.length)
			drop = first.y - last.y
		check("chunk_shed has a position track on %s" % ring, found)
		check("chunk_shed drops %s" % ring, drop >= SHED_DROP, "%.2f m down, want at least %.1f" % [drop, SHED_DROP])


func check_collider(label: String, scene: Node3D) -> void:
	var worst_low := 0.0
	var worst_high := 0.0
	var count := 0
	for row in rest_points(scene):
		var p: Vector3 = row[0]
		var r := Vector2(p.x, p.z).length()
		count += 1
		if p.y < LOW_BAND:
			worst_low = maxf(worst_low, r)
		else:
			worst_high = maxf(worst_high, r)
	check(label + " has rest vertices", count > 0, "%d vertices" % count)
	check(label + " below 2 m inside the collider radius", worst_low <= Warden.RADIUS + EPS,
		"widest %.3f m, collider %.2f m" % [worst_low, Warden.RADIUS])
	check(label + " above 2 m within 1 m of the collider", worst_high <= Warden.RADIUS + REACH_BEYOND + EPS,
		"widest %.3f m, limit %.2f m" % [worst_high, Warden.RADIUS + REACH_BEYOND])


func check_budget(label: String, scene: Node3D, path: String, want_class: String, registry: Dictionary, budgets: Dictionary) -> void:
	var row := {}
	for asset in registry.get("assets", []):
		if asset.get("path", "") == path:
			row = asset
	check(label + " registry row", not row.is_empty(), path)
	if row.is_empty():
		return
	check(label + " registry class", row.get("class", "") == want_class, "%s, want %s" % [row.get("class", ""), want_class])
	check(label + " provenance recipe", str(row.get("provenance", {}).get("recipe", "")) == "tools/blender/warden_swarm.py",
		str(row.get("provenance", {})))
	check(label + " no budget exception", not row.has("exception") and not row.has("exception_why"), str(row.keys()))
	var cap: Dictionary = budgets.classes.get(row.get("class", ""), {})
	check(label + " class has a budget", not cap.is_empty(), row.get("class", ""))
	if cap.is_empty():
		return
	var actual := counts(scene)
	for field in ["tris", "verts", "draws"]:
		check("%s %s" % [label, field], actual[field] <= int(cap[field]) and actual[field] > 0, "%d <= %d" % [actual[field], int(cap[field])])
	print("KF6_BUDGET %s: %d triangles, %d vertices, %d draws" % [label, actual.tris, actual.verts, actual.draws])


func _run() -> void:
	var body := load_scene(BODY)
	var kit := load_scene(KIT)
	if body == null or kit == null:
		print("warden_swarm_asset_test: FAIL (missing GLB)")
		quit(1)
		return
	root.add_child(body)
	root.add_child(kit)
	await process_frame
	await process_frame

	check_clips("body", body)
	check_clips("kit", kit)
	check("no light in the body", body.find_children("*", "Light3D", true, false).is_empty())
	check("no light in the kit", kit.find_children("*", "Light3D", true, false).is_empty())
	check_collider("body", body)
	check_collider("kit", kit)

	# The queen at the kit's point offset: warden_kit.gd's swarm offset from the Warden's centre,
	# lifted by HALF_HEIGHT because the body's origin is the collider's floor.
	var probe := WardenKit.new()
	probe.family = Roster.SWARM
	var want: Vector3 = probe.point_offset() + Vector3.UP * Warden.HALF_HEIGHT
	probe.free()
	var weak := body.find_child("WeakPoint", true, false) as Node3D
	check("WeakPoint node", weak != null)
	if weak != null:
		var at := body.global_transform.affine_inverse() * weak.global_position
		check("queen at the kit point offset", at.distance_to(want) <= POINT_TOLERANCE, "%s, want %s" % [at, want])
	var lit_near := 0
	for row in rest_points(body):
		if row[1] == "ancient_light" and (row[0] as Vector3).distance_to(want) <= QUEEN_CORE_RADIUS:
			lit_near += 1
	check("queen core lit at the point", lit_near > 0, "%d lit vertices within %.1f m" % [lit_near, QUEEN_CORE_RADIUS])

	# The hive's named parts: 19 shuttered cells (queen, 6, 12), three grip cells, the suspension
	# point on top.
	var skeletons := body.find_children("*", "Skeleton3D", true, false)
	check("body one skeleton", skeletons.size() == 1, "%d" % skeletons.size())
	if skeletons.size() == 1:
		var skel := skeletons[0] as Skeleton3D
		var shutters := 0
		for i in skel.get_bone_count():
			if skel.get_bone_name(i).begins_with("Shutter") and skel.get_bone_name(i).ends_with("_0"):
				shutters += 1
		check("shuttered cells", shutters == SHUTTERED_CELLS, "%d, want %d" % [shutters, SHUTTERED_CELLS])
		check_shed_rings(body)
	for i in GRIPS:
		check("grip cell %d" % i, body.find_child("Grip%d" % i, true, false) != null)
	var top := -INF
	for row in rest_points(body):
		top = maxf(top, (row[0] as Vector3).y)
	var hang := body.find_child("Suspension", true, false) as Node3D
	check("suspension point", hang != null)
	if hang != null:
		var at := body.global_transform.affine_inverse() * hang.global_position
		check("suspension on top", at.y >= top - 0.05 and Vector2(at.x, at.z).length() < 0.05, "%s, top %.2f" % [at, top])
		check("suspension above the queen", at.y > want.y, "%.2f > %.2f" % [at.y, want.y])

	var registry = JSON.parse_string(FileAccess.get_file_as_string(REGISTRY))
	var budgets = JSON.parse_string(FileAccess.get_file_as_string(BUDGETS))
	check("registry parses", registry is Dictionary)
	check("budgets parse", budgets is Dictionary)
	if registry is Dictionary and budgets is Dictionary:
		check_budget("body", body, BODY, "warden_base", registry, budgets)
		check_budget("kit", kit, KIT, "warden_kit", registry, budgets)

	body.queue_free()
	kit.queue_free()
	await process_frame
	print("warden_swarm_asset_test: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(0 if failures == 0 else 1)
