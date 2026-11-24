extends SceneTree

const InkOutline := preload("res://src/presentation/ink_outline.gd")
const Game := preload("res://src/game.gd")
const Palette := preload("res://src/core/palette.gd")
const Warden := preload("res://src/combat/warden.gd")
const ChaseCamera := preload("res://src/movement/chase_camera.gd")
const Clearance := preload("res://tests/lantern_beacon_clearance_test.gd")

# F6 2026-10-04: caps, magnet, brace, tint and shred checks are gone; the weak point opens on a stagger.
# 2026-10-09 (w12 BEACON-CLAMP): the beacon is the authored lantern, so the mast checks become lantern checks when
# the frame loads: the Warden sits on socket_clamp and owns the clamp with nothing cut, added or lit, and its weak
# point clears the frame. Measured cause: with the lantern in, "active mast owner" failed (no mast to split).
class LegacyGame extends "res://src/game.gd":
	func _chosen_table():
		return preload("res://tests/doubles/two_world_defs.gd").FirstWorld

var game
var ticks := 0
var failures := 0
var prior_base: Node3D
var prior_id := 0
var dead_ids: Array[int] = []
var mast_original := {}
var prior_support: Node3D
var lantern: Node3D
var frame_original := []


func _initialize() -> void:
	game = LegacyGame.new()
	game.test_mode = true
	root.add_child(game)


func check(label: String, ok: bool) -> void:
	print("[%s] %s" % [label, "PASS" if ok else "FAIL"])
	if not ok:
		failures += 1


func _physics_process(_delta: float) -> bool:
	if game.flow == null:
		return false
	ticks += 1
	if ticks == 1:
		check_chunk_asset(game.presentation.hero_assets)
		lantern = game.flow.beacon.clamp_seat()
		if lantern != null:
			frame_original = frame_snapshot()
		for child in game.flow.beacon.get_children():
			if child is MeshInstance3D and child.mesh is CylinderMesh:
				mast_original = {"node": child, "mesh": child.mesh, "material": child.material_override, "transform": child.transform, "layers": child.layers, "shadow": child.cast_shadow}
		check("ribbons ready before run starts", game.presentation.hero_assets._meshes.keys().filter(func(k): return k.begins_with("warden_stroke:")).size() == 24)
		game.ctx.calm = true
		game.flow.force_warden = true
		game.flow.press_start()
		game.flow.choose_class(0)
	if ticks in [5, 15, 25]:
		check_family()
	if ticks == 6:
		check_park_shell()
	if ticks in [10, 20]:
		game.flow.enter_stage(2 if ticks == 10 else 3, Vector3.ZERO, false)
	if ticks == 28:
		game.flow.warden._die()
	if ticks == 30:
		check_mast_restored("death")
		game.flow.enter_stage(3, Vector3.ZERO, false)
	if ticks == 33:
		check_family()
	if ticks == 35:
		var hook = game.presentation.hero_assets
		var warden = game.flow.warden
		var rec: Dictionary = hook.warden_of(warden)
		for id in dead_ids:
			check("dead Warden record cleaned", not hook._wardens.has(id))
		var preserved: Array = rec.hidden.duplicate()
		hook.get_parent().remove_child(hook)
		hook.queue_free()
		check_mast_restored("hook teardown")
		for entry in preserved:
			check("restore placeholder layers and shadow", entry.mesh.layers == entry.layers and entry.mesh.cast_shadow == entry.shadow)
	if ticks == 37:
		check("restored hero freed", not is_instance_valid(prior_base))
		var replacement := preload("res://src/presentation/hero_assets.gd").new()
		game.presentation.add_child(replacement)
		game.presentation.hero_assets = replacement
		replacement.setup(game.ctx)
	if ticks == 40:
		check_mast(game.presentation.hero_assets, game.flow.warden)
		game.presentation.remove_child(game.presentation.hero_assets)
		game.presentation.hero_assets.queue_free()
		check_mast_restored("replacement hook teardown")
		print("hero_warden_assets_test: %s" % ("PASS" if failures == 0 else "FAIL"))
		quit(0 if failures == 0 else 1)
	return false


func check_family() -> void:
	var hook = game.presentation.hero_assets
	var warden = game.flow.warden
	var rec: Dictionary = hook.warden_of(warden)
	check("automatic attach " + warden.family, not rec.is_empty())
	if rec.is_empty():
		return
	if prior_id != 0:
		check("stage cleanup", not is_instance_valid(prior_base) and not hook._wardens.has(prior_id))
	check_mast(hook, warden)
	prior_base = rec.base
	prior_id = warden.get_instance_id()
	hook._dress_warden(warden)
	check("idempotent attachment", hook.warden_of(warden).base == rec.base and warden.find_children("HeroWarden", "", false, false).size() == 1)
	var shapes: Array = warden.find_children("*", "CollisionShape3D", true, false).filter(func(s): return not _camera_only(s.get_parent()))
	var camera_bodies: Array = warden.find_children("*", "PhysicsBody3D", true, false).filter(_camera_only)
	check("original collider only", shapes.size() == 1 and is_equal_approx(shapes[0].shape.radius, Warden.RADIUS) and is_equal_approx(shapes[0].shape.height, Warden.HALF_HEIGHT * 2.0))
	if warden.family == "reactor":
		check("one camera-only body", camera_bodies.size() == 1)
	check_shell(warden, rec.base, "clamp body")
	check("mount meets kit", rec.base.get_node("Tower/KitMount").global_position.distance_to(rec.kit.global_position) < 0.0001)
	for angle in [0.0, 0.7, -2.4]:
		warden._look._jaws.rotation.y = angle
		hook._update_warden(rec)
		check("world weak point " + str(angle), rec.weak.global_position.distance_to(warden.family_point_at()) < 0.0001)
	check_geometry(rec.base, rec.base)
	check_stroke_surfaces(rec)
	check_ink(rec, "clamp " + warden.family)
	var authored: Node3D = hook._warden_scene(hook.WARDEN_BASE)
	# The dressed jaw draws the ink line's welded copy of the authored mesh, one copy every Warden shares.
	check("jaw meshes and hinges unchanged", InkOutline.hull(authored.get_node("JawL").mesh) == rec.base.get_node("JawL").mesh
		and authored.get_node("JawR").transform == rec.base.get_node("JawR").transform)
	var tower: MeshInstance3D = rec.base.get_node("Tower")
	var low_unchanged := true
	var joint_distance := INF
	for surface in tower.mesh.get_surface_count():
		var old_arrays: Array = authored.get_node("Tower").mesh.surface_get_arrays(surface)
		var new_arrays: Array = tower.mesh.surface_get_arrays(surface)
		for i in new_arrays[Mesh.ARRAY_VERTEX].size():
			var old_v: Vector3 = old_arrays[Mesh.ARRAY_VERTEX][i]
			var new_v: Vector3 = new_arrays[Mesh.ARRAY_VERTEX][i]
			if old_v.y <= 2.2:
				low_unchanged = low_unchanged and old_v == new_v
			joint_distance = minf(joint_distance, (new_v + tower.position).distance_to(rec.kit.position))
	check("lower tower unchanged", low_unchanged)
	check("tower geometry reaches kit joint", joint_distance < 0.5)
	authored.free()
	for entry in rec.hidden:
		check("placeholder hidden without deletion", is_instance_valid(entry.mesh) and entry.mesh.layers == 0 and entry.mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	check("badge remains", warden._look._badge.visible)
	var other := Warden.new()
	game.add_child(other)
	other.position = warden.position + Vector3(20, 0, 0)
	other.setup(game.player, game.ctx.terrain, game, func(): return true, 1.0, {"family": warden.family, "stage": warden.stage})
	var fit_started := Time.get_ticks_usec()
	hook._dress_warden(other)
	hook._dress_mast(other)
	check("extra Warden cannot claim mast", hook._mast.owner == warden.get_instance_id() and hook._mast.root == prior_support)
	print("WARDEN_ATTACH_CPU_MS ", warden.family, " ", float(Time.get_ticks_usec() - fit_started) / 1000.0)
	var second: Dictionary = hook.warden_of(other)
	check("independent materials", rec.materials.ancient_light != second.materials.ancient_light and rec.materials.ancient_enamel != second.materials.ancient_enamel and rec.materials.ancient_light_jaw != second.materials.ancient_light_jaw)
	check("immutable ribbons cached with private animated materials", rec.seams[0].node.mesh == second.seams[0].node.mesh and rec.seams[0].node.material_override != second.seams[0].node.material_override)
	check("independent tower mesh", rec.base.get_node("Tower").mesh != second.base.get_node("Tower").mesh)
	warden._posture.staggered = true
	warden._kit.update(0.0)
	hook._update_warden(rec)
	check("weak point opening", rec.weak.scale.is_equal_approx(Vector3.ONE * 1.3) and rec.materials.ancient_light.emission_energy_multiplier == warden._kit.SEAM_OPEN)
	if warden.family == "swarm":
		check("queen hatch exposes core while open", rec.queen_hatch != null and is_equal_approx(rec.queen_hatch.rotation.z, -PI * 0.5))
		check("other queen hatch stays closed", is_zero_approx(second.queen_hatch.rotation.z))
	check("other stays closed", second.weak.scale.is_equal_approx(Vector3.ONE) and is_equal_approx(second.materials.ancient_light.emission_energy_multiplier, other._kit.SEAM_DIM))
	warden.flash()
	warden._update_flash(0.01)
	hook._update_warden(rec)
	check("damage flash isolated", rec.materials.ancient_enamel.emission_enabled and not second.materials.ancient_enamel.emission_enabled)
	var point: Vector3 = warden.family_point_at()
	check("open weak point hit contract", warden.plating_for("runner", warden.family_point()) == 0.0 and warden.weak_points().any(func(p): return p.id == warden.family_point() and p.at == point))
	warden._posture.staggered = false
	warden._kit.update(0.0)
	hook._update_warden(rec)
	check("weak point recloses", rec.weak.scale.is_equal_approx(Vector3.ONE))
	if warden.family == "swarm":
		check("queen hatch recloses", is_zero_approx(rec.queen_hatch.rotation.z))
	dead_ids.append(other.get_instance_id())
	other._die()


func check_geometry(node: Node3D, base: Node3D) -> void:
	check("finite nonsingular " + node.name, node.transform.is_finite() and absf(node.transform.basis.determinant()) > 0.0001)
	if node is MeshInstance3D:
		var low_ok := true
		var finite := true
		var lower_max := 0.0
		for surface in node.mesh.get_surface_count():
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			for v in arrays[Mesh.ARRAY_VERTEX]:
				var at: Vector3 = base.to_local(node.to_global(v))
				finite = finite and at.is_finite()
				if at.y <= 2.0:
					lower_max = maxf(lower_max, Vector2(at.x, at.z).length())
					low_ok = low_ok and Vector2(at.x, at.z).length() <= 2.8001
			for normal in arrays[Mesh.ARRAY_NORMAL]:
				finite = finite and normal.is_finite() and normal.length() > 0.99
		check("finite vertices and normals " + node.name, finite)
		if not low_ok: print("LOWER_RADIUS ", node.name, " ", lower_max)
		check("lower collider envelope " + node.name, low_ok)
	for child in node.get_children():
		if child is Node3D:
			check_geometry(child, base)


func check_stroke_surfaces(rec: Dictionary) -> void:
	var worst := 0.0
	var minimum := INF
	var samples := 0
	var fitted := true
	for seam in rec.seams:
		var stroke: MeshInstance3D = seam.node
		var jaw := stroke.get_parent().get_parent() as MeshInstance3D
		var faces := jaw.mesh.get_faces()
		var arrays := stroke.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		fitted = fitted and vertices.size() == 34
		if vertices.size() != 34:
			continue
		var to_jaw := jaw.global_transform.affine_inverse() * stroke.global_transform
		var probes := PackedVector3Array()
		# Both endpoints and centre of every cross-section, including stroke centre.
		for row in 17:
			probes.append(to_jaw * vertices[row * 2])
			probes.append(to_jaw * vertices[row * 2 + 1])
			probes.append(to_jaw * ((vertices[row * 2] + vertices[row * 2 + 1]) * 0.5))
		# Interior triangle samples catch a chord bridging across a tapered surface.
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for i in range(0, indices.size(), 3):
			probes.append(to_jaw * ((vertices[indices[i]] + vertices[indices[i + 1]] + vertices[indices[i + 2]]) / 3.0))
		for point in probes:
			var radial := Vector3(point.x + jaw.position.x, 0, point.z + jaw.position.z).normalized()
			var origin := Vector3(-jaw.position.x, point.y, -jaw.position.z) + radial * 10.0
			var surface_distance := INF
			for i in range(0, faces.size(), 3):
				var hit = Geometry3D.ray_intersects_triangle(origin, -radial, faces[i], faces[i + 1], faces[i + 2])
				if hit != null:
					surface_distance = minf(surface_distance, origin.distance_to(hit))
			var clearance := surface_distance - origin.distance_to(point)
			fitted = fitted and is_finite(clearance) and clearance >= 0.0005 and clearance <= 0.03
			minimum = minf(minimum, clearance)
			worst = maxf(worst, clearance)
			samples += 1
	print("STROKE_GEOMETRY ", rec.warden.family, " samples=", samples, " minimum_signed_clearance=", minimum, " maximum_signed_clearance=", worst)
	check("shred centres endpoints and triangle interiors fit actual jaws", fitted and samples == 18 * 83)


func check_mast_restored(reason: String) -> void:
	if lantern != null:
		check("lantern clamp released " + reason, game.presentation.hero_assets._mast.is_empty())
		check("lantern frame untouched " + reason, frame_snapshot() == frame_original)
		return
	var node: MeshInstance3D = mast_original.node
	check("exact mast restoration " + reason, node.mesh == mast_original.mesh and node.material_override == mast_original.material and node.transform == mast_original.transform and node.layers == mast_original.layers and node.cast_shadow == mast_original.shadow)
	check("no orphan support " + reason, node.get_child_count() == 0)


func check_mast(hook, warden) -> void:
	if lantern != null:
		check_lantern(hook, warden)
		return
	check("active mast owner", not hook._mast.is_empty() and hook._mast.owner == warden.get_instance_id())
	if hook._mast.is_empty(): return
	var support: Node3D = hook._mast.root
	if prior_support != null:
		check("old support freed on transition", not is_instance_valid(prior_support))
	prior_support = support
	hook._dress_mast(warden)
	check("idempotent mast", hook._mast.root == support and mast_original.node.get_child_count() == 1)
	check("original mast retained", mast_original.node.mesh == mast_original.mesh and mast_original.node.material_override == mast_original.material and mast_original.node.transform == mast_original.transform and mast_original.node.layers == 0)
	var minimum := INF
	var segments := 0
	var rails := 0
	for visual in support.get_children():
		check("mast material preserved", visual.material_override == mast_original.material)
		check("mast finite transform", visual.transform.is_finite() and absf(visual.basis.determinant()) > 0.99)
		var centre: Vector3 = visual.to_local(warden.family_point_at())
		if visual.mesh is BoxMesh:
			rails += 1
			var half: Vector3 = visual.mesh.size * 0.5
			# Exact distance to the solid oriented box bounds covers faces and interiors.
			var closest := centre.clamp(-half, half)
			minimum = minf(minimum, centre.distance_to(closest))
			check("narrow support rail", is_equal_approx(visual.mesh.size.x, 0.12) and is_equal_approx(visual.mesh.size.z, 0.12))
		else:
			segments += 1
			var cylinder: CylinderMesh = visual.mesh
			minimum = minf(minimum, absf(centre.y) - cylinder.height * 0.5)
			for y in [-cylinder.height * 0.5, cylinder.height * 0.5]:
				var mast_y: float = visual.position.y + y
				var old: CylinderMesh = mast_original.mesh
				var expected := lerpf(old.bottom_radius, old.top_radius, (mast_y + old.height * 0.5) / old.height)
				check("original taper at segment end", absf((cylinder.bottom_radius if y < 0 else cylinder.top_radius) - expected) < 0.00001)
	print("MAST_CLEARANCE ", warden.family, " ", minimum)
	check("entire support outside fixed sphere", minimum >= Warden.FAMILY_POINT_RADIUS and segments == 2 and rails == 6)
	check("lamp and ring retained", game.flow.beacon._core.is_inside_tree() and game.flow.beacon._core.layers != 0 and game.flow.beacon._ring.is_inside_tree() and game.flow.beacon._ring.layers != 0)


func check_lantern(hook, warden) -> void:
	var beacon = game.flow.beacon
	check("active lantern clamp owner", not hook._mast.is_empty() and hook._mast.owner == warden.get_instance_id() and hook._mast.seat == lantern)
	check("Warden on the clamp seat", warden.global_position.distance_to(lantern.global_position) < 0.01)
	hook._dress_mast(warden)
	check("idempotent lantern clamp", hook._mast.owner == warden.get_instance_id() and hook._mast.seat == lantern)
	check("lantern frame untouched " + warden.family, frame_snapshot() == frame_original)
	check("no light on the beacon", beacon.find_children("*", "Light3D", true, false).is_empty())
	var clearance: float = Clearance.surface_clearance(warden.family_point_at(), Clearance.triangles(beacon.get_node("LanternFrame")))
	print("LANTERN_CLEARANCE ", warden.family, " ", snappedf(clearance, 0.001))
	check("weak point clears the lantern frame", clearance >= Warden.FAMILY_POINT_RADIUS)
	check("lamp and ring retained", beacon._core.is_inside_tree() and beacon._core.layers != 0 and beacon._ring.is_inside_tree() and beacon._ring.layers != 0)


# Every node under the lantern frame with its mesh, material, transform, layers and shadow: a runtime cut or
# added part changes it.
func frame_snapshot() -> Array:
	var out := []
	for node in game.flow.beacon.get_node("LanternFrame").find_children("*", "", true, false):
		var row: Array = [node.get_path(), node.get_child_count()]
		if node is Node3D:
			row.append(node.transform)
		if node is MeshInstance3D:
			row.append_array([node.mesh, node.material_override, node.layers, node.cast_shadow])
		out.append(row)
	return out


func check_chunk_asset(hook) -> void:
	var base: Node3D = hook._warden_scene(hook.WARDEN_BASE)
	root.add_child(base)
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)
	for mesh in base.find_children("*", "MeshInstance3D", true, false):
		for vertex in mesh.mesh.get_faces():
			var at: Vector3 = base.transform * base.to_local(mesh.to_global(vertex))
			minimum = minimum.min(at)
			maximum = maximum.max(at)
	var before := Vector3(6.729995012283325, 7.735000431537628, 7.506797790527344)
	var ratio := (maximum - minimum) / before
	print("WM_BASE_BOUNDS min=", minimum, " max=", maximum, " ratio=", ratio)
	check("all armour on keeps base bounds within three percent", absf(ratio.x - 1.0) <= 0.03 and absf(ratio.y - 1.0) <= 0.03 and absf(ratio.z - 1.0) <= 0.03)
	for i in 4:
		var segment := base.find_child("ArmourSegment%d" % i, true, false) as MeshInstance3D
		check("named armour segment %d" % i, segment != null and segment.mesh.get_aabb().size.y > 1.0)
	var core := base.get_node_or_null("CoreAssembly")
	check("named caged heart with one emissive surface", core != null and core.get_child_count() == 2 and core.get_node("HeartSurface").mesh.get_surface_count() == 1 and (core.get_node("HeartSurface").global_basis.get_scale() * core.get_node("HeartSurface").mesh.get_aabb().size).is_equal_approx(Vector3.ONE))
	# Exact triangle union projected from the facing gap. Each missing half removes area
	# above both the fixed jaws and the inner structure, where only armour can occlude.
	var silhouettes: Array = []
	for lost in 5:
		var mask := PackedByteArray()
		mask.resize(160 * 60)
		for i in range(lost, 4):
			var segment := base.find_child("ArmourSegment%d" % i, true, false) as MeshInstance3D
			var faces := segment.mesh.get_faces()
			for triangle in range(0, faces.size(), 3):
				var a: Vector3 = base.to_local(segment.to_global(faces[triangle]))
				var b: Vector3 = base.to_local(segment.to_global(faces[triangle + 1]))
				var c: Vector3 = base.to_local(segment.to_global(faces[triangle + 2]))
				if maxf(a.y, maxf(b.y, c.y)) < 5.9:
					continue
				var polygon := PackedVector2Array([Vector2(a.z, a.y), Vector2(b.z, b.y), Vector2(c.z, c.y)])
				for x in 160:
					var z := -4.0 + (x + 0.5) * 0.05
					if z < minf(a.z, minf(b.z, c.z)) or z > maxf(a.z, maxf(b.z, c.z)):
						continue
					for y in 60:
						var height := 5.9 + (y + 0.5) * 0.01
						if Geometry2D.is_point_in_polygon(Vector2(z, height), polygon):
							mask[y * 160 + x] = 1
		silhouettes.append(mask.count(1))
	print("WM_CROWN_SILHOUETTE_SAMPLES ", silhouettes)
	for i in 4:
		check("loss %d changes the facing crown silhouette" % (i + 1), silhouettes[i] > silhouettes[i + 1])
	base.free()


# A body only the chase camera sees: its layer is the camera bit and it masks nothing.
func _camera_only(body) -> bool:
	return body is PhysicsBody3D and body.collision_layer == ChaseCamera.CAMERA_BODY_BIT and body.collision_mask == 0


# The camera drum follows what is drawn: its radius and height are within 0.3 m of the dressed body's own
# meshes (the ones still on a render layer), measured in the Warden's frame.
func check_shell(warden, body: Node3D, label: String) -> void:
	var shell = null
	for child in warden.get_children():
		if _camera_only(child) and not child.is_queued_for_deletion():
			shell = child
	if warden.family == "mind":
		print("shell %s mind: none" % label)
		check("%s: the hanging mind has no camera shell" % label, shell == null)
		return
	if shell == null:
		check("%s: a camera shell exists" % label, false)
		return
	var inverse: Transform3D = warden.global_transform.affine_inverse()
	var box := AABB()
	var any := false
	for view in body.find_children("*", "MeshInstance3D", true, false):
		if view.mesh == null or view.layers == 0 or not view.is_visible_in_tree():
			continue
		var local: AABB = inverse * view.global_transform * view.get_aabb()
		box = local if not any else box.merge(local)
		any = true
	var drum: CylinderShape3D = shell.get_child(0).shape
	var radius := 0.0
	for corner in 8:
		var point: Vector3 = box.get_endpoint(corner)
		radius = maxf(radius, maxf(absf(point.x), absf(point.z)))
	var capped := minf(radius, Warden.camera_shell_reach())
	print("shell %s %s: fitted r %.2f, capped r %.2f (drum r %.2f), height %.2f (drum %.2f)" % [label, warden.family, radius, capped, drum.radius, box.size.y, drum.height])
	# The primitive look alone is 3.61 m by 7.6 m, so a shell that kept that size was never refitted to the body.
	check("%s: the shell was refitted to the dressed body, not left at the primitive look" % label, drum.height > 7.6 + 0.3)
	check("%s: the camera shell is the drawn body's capped radius and fitted height" % label, any and absf(drum.radius - capped) < 0.01 and absf(drum.height - box.size.y) < 0.3)
	var overlaps := 0
	var space: PhysicsDirectSpaceState3D = warden.get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	var probe := SphereShape3D.new()
	probe.radius = ChaseCamera.PROBE_RADIUS
	query.shape = probe
	query.collision_mask = ChaseCamera.CAMERA_BODY_BIT
	for i in 16:
		var angle := TAU * i / 16.0
		query.transform = Transform3D(Basis.IDENTITY, warden.global_position + Vector3(cos(angle), 0.0, sin(angle)) * (Warden.RADIUS + 1.0) + Vector3(0.0, shell.position.y, 0.0))
		if not space.intersect_shape(query, 1).is_empty():
			overlaps += 1
	check("%s: a ball touching the contact cylinder starts the arm's probe clear of the shell, all 16 sides" % label, overlaps == 0)


# A park Warden of each family (the harpoon-anchor spec) wears its own model; its shell is that model's size.
func check_park_shell() -> void:
	var hook = game.presentation.hero_assets
	var base = game.flow.warden
	var mountings := {"reactor": "dam_face", "swarm": "headframe", "mind": "under_island"}
	for family in ["reactor", "swarm", "mind"]:
		var world := Node3D.new()
		game.add_child(world)
		var park = Warden.new()
		world.add_child(park)
		park.setup(base.target, base.terrain, base.world_root, base.live, 1.0, {"family": family, "harpoon_anchor": true, "mounting": mountings[family]})
		park.set_physics_process(false)
		hook._dress_warden(park)
		var rec: Dictionary = hook.warden_of(park)
		check("park %s wears the model" % family, not rec.is_empty() and rec.base.name == "HeroWarden")
		if not rec.is_empty():
			check_shell(park, rec.base, "park " + family)
			check_ink(rec, "park " + family)


# W46-INK: a dressed Warden body draws the Warden's ink line on every surface that takes one, and its own enamel and
# lights stay the very materials its updates brighten (the enamel lined in place, the lights unlined).
func check_ink(rec: Dictionary, label: String) -> void:
	var lined := 0
	var missed := 0
	var other_role := 0
	var own_ok := true
	var own: Array = []
	for key in rec.materials:
		if key == "ancient_enamel" or String(key).begins_with("ancient_light"):
			own.append(rec.materials[key])
	for view: MeshInstance3D in rec.base.find_children("*", "MeshInstance3D", true, false):
		# The cool rim draws its own additive shell over a part's mesh.
		if view.mesh == null or view.name == "CoolFill":
			continue
		for i in view.mesh.get_surface_count():
			var mat := view.get_active_material(i)
			var line: Material = mat.next_pass if mat != null else null
			var inked := line != null and line.has_meta("ink_role")
			if inked:
				lined += 1
				if line.get_meta("ink_role") != "warden":
					other_role += 1
			elif InkOutline.drawable(view.mesh, i, InkOutline.strip(mat)):
				missed += 1
			var slot := hook_slot(view.mesh, i)
			# A jaw's inner face wears fixed paint of its own (_paint_warden_inner), never the Warden's enamel.
			if slot == "ancient_enamel" and rec.materials.has("ancient_enamel") and not String(view.name).begins_with("Inner"):
				own_ok = own_ok and mat == rec.materials.ancient_enamel and inked
			elif slot.begins_with("ancient_light"):
				own_ok = own_ok and own.has(mat) and not inked
	check("%s: every body surface draws the Warden's ink line (%d lined, %d missed)" % [label, lined, missed],
		lined >= 3 and missed == 0 and other_role == 0)
	check("%s: its enamel and lights stay its own, the enamel lined in place, the lights unlined" % label, own_ok)


func hook_slot(mesh: Mesh, surface: int) -> String:
	return game.presentation.hero_assets.slot_of(mesh, surface)


func _drum_of(warden) -> CylinderShape3D:
	for child in warden.get_children():
		if _camera_only(child):
			return child.get_child(0).shape
	return null
