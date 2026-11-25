extends SceneTree


const HeroAssets := preload("res://src/presentation/hero_assets.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Subjects := preload("res://tools/look_subjects.gd")

const SIZE := Vector2i(1920, 1080)
const SAMPLES := 16
const PILOT_LAYER := 1
const OCCLUDER_LAYER := 2
const EPS := 0.002


func _initialize() -> void:
	_cli.call_deferred()


func _cli() -> void:
	var opts := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			var kv := a.trim_prefix("--").split("=", true, 1)
			opts[kv[0]] = kv[1]
	if not opts.has("out"):
		printerr("pilot_mask: needs --out=<abs json>")
		quit(2)
		return
	var res: Dictionary = await measure(self, opts)
	var f := FileAccess.open(String(opts["out"]), FileAccess.WRITE)
	f.store_string(JSON.stringify(res, "  "))
	f.close()
	if res.has("error"):
		printerr("pilot_mask: ", res["error"])
		quit(1)
		return
	print("PILOT_MASK %s %s class %d pilot %.1f%% (min %.1f%%) head %.1f%% (min %.1f%%) head_px %.0f samples %d method %s wrote %s" % [
		res["pilot"], res["shell"], res["class"], res["pilot_visible_pct"], res["pilot_visible_min_pct"], res["head_visible_pct"],
		res["head_visible_min_pct"], res["head_px"], res["samples"], res["method"], opts["out"]])
	quit(0)


static func measure(tree: SceneTree, opts: Dictionary) -> Dictionary:
	var pilot_id := String(opts.get("pilot", "pylon_engineer"))
	var heft := int(opts.get("class", 1))
	var samples := int(opts.get("samples", SAMPLES))
	var shot: Array = Subjects.CGE_CAMERAS[1]
	var eye: Vector3 = shot[1]
	var target: Vector3 = shot[2]
	var fov: float = shot[3]
	var hero := HeroAssets.new()
	if opts.has("shell"):
		hero.shell_assets = {pilot_id: String(opts["shell"])}
	tree.root.add_child(hero)
	var ball := Node3D.new()
	ball.name = "PilotMaskBall"
	tree.root.add_child(ball)
	var def = ClassDef.by_id(pilot_id)
	var color: Color = def.color if def != null else Color.WHITE
	var rec: Dictionary = hero.fit_shell_into(ball, pilot_id, "", heft, {"class": color})
	var out := {"tool": "pilot_mask.gd", "method": "jolt-raycast", "pilot": pilot_id, "shell": String(opts.get("shell", HeroAssets.SHELLS.get(pilot_id, ""))),
		"class": heft, "samples": samples, "eye": [eye.x, eye.y, eye.z], "target": [target.x, target.y, target.z], "fov": fov, "size": [SIZE.x, SIZE.y]}
	if rec.is_empty():
		out["error"] = "no shell for %s" % pilot_id
		return _done(hero, ball, out)
	var core: Node3D = rec.core
	var pod: Node3D = rec.pod
	var fitted: Dictionary = hero.fit_pilot_into(pod, pilot_id, color)
	if fitted.is_empty():
		out["error"] = "no pilot rig for %s" % pilot_id
		return _done(hero, ball, out)
	if fitted.animator != null:
		(fitted.animator as AnimationPlayer).stop()
	var skels: Array = (fitted.pilot as Node).find_children("*", "Skeleton3D", true, false)
	for s: Skeleton3D in skels:
		s.reset_bone_poses()
	await tree.process_frame
	await tree.process_frame
	if opts.has("seed-sphere"):
		var seed := MeshInstance3D.new()
		seed.name = "SeedSphere"
		var sphere := SphereMesh.new()
		sphere.radius = float(opts["seed-sphere"])
		sphere.height = 2.0 * sphere.radius
		seed.mesh = sphere
		pod.add_child(seed)
	pod.global_rotation = Vector3.ZERO
	var ring := pod.get_node_or_null("WeaponRing") as Node3D
	if ring != null:
		ring.rotation = Vector3.ZERO
	var groups := {}
	for mi in pod.find_children("*", "MeshInstance3D", true, false) + core.find_children("*", "MeshInstance3D", true, false) + [core, pod]:
		var g := occluder_group(mi, core, pod)
		if g != "" and mi is MeshInstance3D and mi.is_visible_in_tree() and (mi as MeshInstance3D).layers != 0:
			groups[g] = int(groups.get(g, 0)) + int(_body(mi, (mi as MeshInstance3D).mesh, OCCLUDER_LAYER, g))
	var pilot_faces := 0
	var pilot_meshes: Array = (fitted.pilot as Node).find_children("*", "MeshInstance3D", true, false)
	var top_world := -INF
	var skel: Skeleton3D = skels[0] if not skels.is_empty() else null
	for mi: MeshInstance3D in pilot_meshes:
		if not mi.is_visible_in_tree() or mi.mesh == null:
			continue
		var faces := skinned_faces(mi, skel) if mi.skin != null and skel != null else mi.mesh.get_faces()
		pilot_faces += int(_body_faces(mi, faces, PILOT_LAYER, "pilot"))
		for v in faces:
			top_world = maxf(top_world, (mi.global_transform * v).y)
	out["occluder_groups"] = groups
	var neck_idx := skel.find_bone("neck") if skel != null else -1
	if pilot_faces == 0 or neck_idx < 0:
		out["error"] = "pilot rig has no mesh faces (%d) or no neck bone" % pilot_faces
		return _done(hero, ball, out)
	var neck_world: Vector3 = skel.global_transform * skel.get_bone_global_pose(neck_idx).origin
	var cam := Basis.looking_at(target - eye, Vector3.UP)
	var tan_half := tan(deg_to_rad(fov) / 2.0)
	var neck_y := project(cam, eye, tan_half, neck_world).y
	await tree.physics_frame
	await tree.physics_frame
	var space := tree.root.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.new()
	q.hit_back_faces = true
	q.hit_from_inside = false
	var box := _pilot_box(pilot_meshes, cam, eye, tan_half)
	var mask: Array = []
	var top := SIZE.y
	q.collision_mask = PILOT_LAYER
	for y in range(box.position.y, box.end.y):
		for x in range(box.position.x, box.end.x):
			var dir := pixel_dir(cam, tan_half, x, y)
			q.from = eye
			q.to = eye + dir * 60.0
			var hit := space.intersect_ray(q)
			if not hit.is_empty():
				mask.append([x, y, dir, eye.distance_to(hit["position"])])
				top = mini(top, y)
	var head_area := mask.filter(func(p): return p[1] <= neck_y).size()
	out["pilot_px_area"] = mask.size()
	out["head_px_area"] = head_area
	out["neck_y"] = snappedf(neck_y, 0.1)
	out["top_y"] = top
	out["head_px"] = snappedf(neck_y - top, 0.1)
	out["pilot_top_world_y"] = snappedf(top_world, 0.001)
	out["pilot_box"] = [box.position.x, box.position.y, box.size.x, box.size.y]
	if mask.is_empty():
		out["error"] = "the pilot-only mask is empty"
		return _done(hero, ball, out)
	var gyro := pod.get_node_or_null("Gyro") as Node3D
	var rows: Array = []
	var blockers := {}
	var sum_all := 0.0
	var sum_head := 0.0
	var min_all := 100.0
	var min_head := 100.0
	q.collision_mask = OCCLUDER_LAYER
	for k in samples:
		var th := TAU * k / samples
		core.rotation = Vector3(th, 0.0, 0.0)
		if gyro != null and gyro.has_node("GyroInner"):
			HeroAssets.counter_tilt(pod, gyro, core)
		await tree.physics_frame
		await tree.physics_frame
		var seen := 0
		var head_seen := 0
		var by := {}
		for p in mask:
			q.from = eye
			q.to = eye + (p[2] as Vector3) * (float(p[3]) - EPS)
			var hit := space.intersect_ray(q)
			if hit.is_empty():
				seen += 1
				if p[1] <= neck_y:
					head_seen += 1
			else:
				var g := String((hit["collider"] as Node).get_meta("group", "?"))
				by[g] = int(by.get(g, 0)) + 1
		var va := 100.0 * seen / mask.size()
		var vh := 100.0 * head_seen / maxi(1, head_area)
		sum_all += va
		sum_head += vh
		min_all = minf(min_all, va)
		min_head = minf(min_head, vh)
		for g in by:
			blockers[g] = int(blockers.get(g, 0)) + int(by[g])
		rows.append({"roll_deg": snappedf(rad_to_deg(th), 0.01), "pilot_seen_px": seen, "head_seen_px": head_seen,
			"pilot_visible_pct": snappedf(va, 0.01), "head_visible_pct": snappedf(vh, 0.01), "first_blocker_px": by})
	out["pilot_visible_pct"] = snappedf(sum_all / samples, 0.01)
	out["head_visible_pct"] = snappedf(sum_head / samples, 0.01)
	out["pilot_visible_min_pct"] = snappedf(min_all, 0.01)
	out["head_visible_min_pct"] = snappedf(min_head, 0.01)
	var total := mask.size() * samples
	var shares := {}
	for g in blockers:
		shares[g] = snappedf(100.0 * blockers[g] / total, 0.01)
	out["first_blocker_pct"] = shares
	out["rows"] = rows
	return _done(hero, ball, out)


static func _done(hero: Node, ball: Node, out: Dictionary) -> Dictionary:
	ball.free()
	hero.free()
	return out


static func occluder_group(mi: Node, core: Node, pod: Node) -> String:
	if mi == core or core.is_ancestor_of(mi):
		var n := mi.get_parent()
		while n != core and n != null:
			if String(n.name).begins_with("HeftC"):
				return "panels"
			n = n.get_parent()
		return "lattice"
	if mi == pod or not pod.is_ancestor_of(mi):
		return ""
	var top := mi
	while top.get_parent() != pod:
		top = top.get_parent()
	var top_name := String(top.name)
	if top_name == "Gyro":
		return "gimbal"
	if top_name == "WeaponRing":
		return "ring"
	if top_name.begins_with("HeftC"):
		return "panels"
	if top_name == "SeedSphere":
		return "seed"
	return ""


static func skinned_faces(mi: MeshInstance3D, skel: Skeleton3D) -> PackedVector3Array:
	var skin := mi.skin
	var mats: Array[Transform3D] = []
	for b in skin.get_bind_count():
		var bone := skin.get_bind_bone(b)
		if bone < 0:
			bone = skel.find_bone(skin.get_bind_name(b))
		mats.append(skel.get_bone_global_pose(bone) * skin.get_bind_pose(b) if bone >= 0 else Transform3D.IDENTITY)
	var faces := PackedVector3Array()
	for s in mi.mesh.get_surface_count():
		var arr := mi.mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var bones = arr[Mesh.ARRAY_BONES]
		var weights = arr[Mesh.ARRAY_WEIGHTS]
		var posed := verts.duplicate()
		if bones != null and weights != null and not verts.is_empty():
			var per: int = (bones as PackedInt32Array).size() / verts.size()
			for i in verts.size():
				var p := Vector3.ZERO
				for j in per:
					var w: float = weights[i * per + j]
					if w > 0.0:
						p += w * (mats[bones[i * per + j]] * verts[i])
				posed[i] = p
		var index = arr[Mesh.ARRAY_INDEX]
		if index != null:
			for i in index:
				faces.append(posed[i])
		else:
			faces.append_array(posed)
	return faces


static func _body(mi: Node3D, mesh: Mesh, layer: int, group: String) -> bool:
	return mesh != null and _body_faces(mi, mesh.get_faces(), layer, group)


static func _body_faces(mi: Node3D, faces: PackedVector3Array, layer: int, group: String) -> bool:
	if faces.is_empty():
		return false
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	body.set_meta("group", group)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	mi.add_child(body)
	return true


static func pixel_dir(cam: Basis, tan_half: float, x: int, y: int) -> Vector3:
	var aspect := float(SIZE.x) / SIZE.y
	var nx := (2.0 * (x + 0.5) / SIZE.x - 1.0) * tan_half * aspect
	var ny := (1.0 - 2.0 * (y + 0.5) / SIZE.y) * tan_half
	return (cam * Vector3(nx, ny, -1.0)).normalized()


static func project(cam: Basis, eye: Vector3, tan_half: float, p: Vector3) -> Vector2:
	var c := cam.inverse() * (p - eye)
	var aspect := float(SIZE.x) / SIZE.y
	var nx := (c.x / -c.z) / (tan_half * aspect)
	var ny := (c.y / -c.z) / tan_half
	return Vector2((nx + 1.0) * SIZE.x / 2.0 - 0.5, (1.0 - ny) * SIZE.y / 2.0 - 0.5)


static func _pilot_box(meshes: Array, cam: Basis, eye: Vector3, tan_half: float) -> Rect2i:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for mi: MeshInstance3D in meshes:
		if not mi.is_visible_in_tree() or mi.mesh == null:
			continue
		var aabb: AABB = mi.global_transform * mi.get_aabb()
		for i in 8:
			var s := project(cam, eye, tan_half, aabb.get_endpoint(i))
			lo = lo.min(s)
			hi = hi.max(s)
	var a := Vector2i(clampi(floori(lo.x) - 2, 0, SIZE.x), clampi(floori(lo.y) - 2, 0, SIZE.y))
	var b := Vector2i(clampi(ceili(hi.x) + 2, 0, SIZE.x), clampi(ceili(hi.y) + 2, 0, SIZE.y))
	return Rect2i(a, b - a)
