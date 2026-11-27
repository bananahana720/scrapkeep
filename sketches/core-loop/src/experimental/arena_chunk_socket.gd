extends RefCounted


const SOCKET_TRAVERSAL_RAIL := &"TRAVERSAL_RAIL"
const SOCKET_JUMP_PAD := &"JUMP_PAD"
const SOCKET_HARPOON_ANCHOR := &"HARPOON_ANCHOR"
const SOCKET_SETPIECE_TRIGGER := &"SETPIECE_TRIGGER"
const SOCKET_COVER_SLOT := &"COVER_SLOT"
const SOCKET_SIGHTLINE_LANDMARK := &"SIGHTLINE_LANDMARK"

const SOCKET_KINDS := [
	SOCKET_TRAVERSAL_RAIL,
	SOCKET_JUMP_PAD,
	SOCKET_HARPOON_ANCHOR,
	SOCKET_SETPIECE_TRIGGER,
	SOCKET_COVER_SLOT,
	SOCKET_SIGHTLINE_LANDMARK,
]

const GROUP_BY_KIND := {
	SOCKET_TRAVERSAL_RAIL: &"socket_traversal_rail",
	SOCKET_JUMP_PAD: &"socket_jump_pad",
	SOCKET_HARPOON_ANCHOR: &"socket_harpoon_anchor",
	SOCKET_SETPIECE_TRIGGER: &"socket_setpiece_trigger",
	SOCKET_COVER_SLOT: &"socket_cover_slot",
	SOCKET_SIGHTLINE_LANDMARK: &"socket_sightline_landmark",
}

const META_KIND := "socket_kind"
const META_ID := "socket_id"
const META_TIER := "tier"
const META_CLEARANCE := "clearance_m"
const META_ROUTE_LINKS := "route_links"
const META_LANDMARK_HEIGHT := "landmark_height_m"
const META_COVER_KIND := "cover_kind"
const META_SETPIECE_KIND := "setpiece_kind"
const META_COVER_SLOT_INDEX := "cover_slot_index"

const BALL_COLLIDER_RADIUS_M := 1.0
const GROWN_HEFT_ENVELOPE_RADIUS_M := 2.1
const MIN_TRAVERSAL_CLEARANCE_M := 4.2
const MIN_COVER_SLOT_SPACING_M := 4.5
const HARD_COVER_MIN_HEIGHT_M := 2.0
const WORLD_LAYER_BIT := 1

const TIER_0_MAX_Y := 4.5
const TIER_1_MAX_Y := 12.0
const MIN_VERTICAL_SPAN_M := 12.0
const MIN_LANDMARK_PROMINENCE_M := 10.0
const MIN_LANDMARK_APEX_M := 26.0
const MIN_SIGHT_SHARE := 0.85
const MIN_BOWL_RIM_DEPTH_M := 2.0

const TRAVERSAL_KINDS := [SOCKET_TRAVERSAL_RAIL, SOCKET_JUMP_PAD, SOCKET_HARPOON_ANCHOR]



static func discover_sockets(chunk_root: Node) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if chunk_root == null or not is_instance_valid(chunk_root):
		return found
	var stack: Array[Node] = [chunk_root]
	var ordered_markers: Array[Marker3D] = []
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if current is Marker3D:
			var kind := _resolve_socket_kind(current as Marker3D)
			if kind != &"":
				ordered_markers.append(current as Marker3D)
		var children := current.get_children()
		for i in range(children.size() - 1, -1, -1):
			stack.append(children[i])

	ordered_markers.sort_custom(func(a: Marker3D, b: Marker3D) -> bool:
		return String(chunk_root.get_path_to(a)) < String(chunk_root.get_path_to(b))
	)

	for marker in ordered_markers:
		var kind := _resolve_socket_kind(marker)
		var local_xform := _local_transform_of(marker, chunk_root)
		var world_xform := _world_transform_of(marker, chunk_root)
		var local_pos := local_xform.origin
		var world_pos := world_xform.origin
		var id := String(marker.get_meta(META_ID, marker.name))
		var tier := _resolve_tier(marker, local_pos.y)
		var clearance := float(marker.get_meta(META_CLEARANCE, MIN_TRAVERSAL_CLEARANCE_M))
		var links := _resolve_links(marker)
		var extra := {}
		for key in marker.get_meta_list():
			extra[String(key)] = marker.get_meta(key)
		found.append({
			"id": id,
			"kind": kind,
			"node_path": String(chunk_root.get_path_to(marker)),
			"node": marker,
			"local_transform": local_xform,
			"local_position": local_pos,
			"transform": world_xform,
			"position": world_pos,
			"forward": (-world_xform.basis.z).normalized(),
			"tier": tier,
			"clearance_m": clearance,
			"route_links": links,
			"meta": extra,
		})
	return found


static func sockets_of_kind(chunk_root: Node, kind: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s in discover_sockets(chunk_root):
		if s["kind"] == kind:
			out.append(s)
	return out


static func find_socket(chunk_root: Node, socket_id: String) -> Dictionary:
	for s in discover_sockets(chunk_root):
		if String(s["id"]) == socket_id:
			return s
	return {}



static func snap_transform(socket: Dictionary, local_offset := Vector3.ZERO) -> Transform3D:
	var xform: Transform3D = socket.get("transform", Transform3D.IDENTITY)
	return xform * Transform3D(Basis.IDENTITY, local_offset)


static func compute_chunk_snap(anchor_socket: Dictionary, incoming_socket: Dictionary) -> Transform3D:
	var anchor_world: Transform3D = anchor_socket.get("transform", Transform3D.IDENTITY)
	var incoming_local: Transform3D = incoming_socket.get("local_transform", incoming_socket.get("transform", Transform3D.IDENTITY))
	var flip := Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
	return anchor_world * flip * incoming_local.affine_inverse()



static func validate_chunk(chunk_root: Node, config: Dictionary = {}) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var sockets := discover_sockets(chunk_root)

	var min_clearance := float(config.get("min_clearance_m", MIN_TRAVERSAL_CLEARANCE_M))
	var min_sight := float(config.get("min_sight_share", MIN_SIGHT_SHARE))
	var min_span := float(config.get("min_vertical_span_m", MIN_VERTICAL_SPAN_M))
	var min_bowl_depth := float(config.get("min_bowl_rim_depth_m", MIN_BOWL_RIM_DEPTH_M))
	var min_landmark_apex := float(config.get("min_landmark_apex_m", MIN_LANDMARK_APEX_M))
	var min_prominence := float(config.get("min_landmark_prominence_m", MIN_LANDMARK_PROMINENCE_M))

	var by_kind := {}
	for k in SOCKET_KINDS:
		by_kind[k] = []
	var by_id := {}
	for s in sockets:
		var sid := String(s["id"])
		if by_id.has(sid):
			errors.append("duplicate socket id: " + sid)
		by_id[sid] = s
		(by_kind[s["kind"]] as Array).append(s)

	if sockets.is_empty():
		errors.append("chunk has zero Marker3D sockets")

	for req_kind in SOCKET_KINDS:
		if (by_kind[req_kind] as Array).is_empty():
			errors.append("missing required socket kind: " + String(req_kind))
	if (by_kind[SOCKET_COVER_SLOT] as Array).size() < 2:
		errors.append("requires at least 2 COVER_SLOT sockets for dynamic cover relocation")

	var solid_boxes := _collect_local_solid_boxes(chunk_root)
	var hard_cover_count := 0
	var bad_cover_layer := 0
	var bad_static_mask := 0
	var rim_max_y := -INF
	var basin_min_y := INF
	for b in solid_boxes:
		var role := String(b["cover_kind"])
		var size: Vector3 = (b["aabb"] as AABB).size
		if int(b["mask"]) != 0:
			bad_static_mask += 1
			errors.append("static body %s has non-zero collision_mask (%d); static arena geometry should use mask 0" % [b["name"], int(b["mask"])])
		if role == "hard":
			hard_cover_count += 1
			if size.y < HARD_COVER_MIN_HEIGHT_M:
				errors.append("hard cover %s is shorter than %.1f m (got %.2f m)" % [b["name"], HARD_COVER_MIN_HEIGHT_M, size.y])
			if (int(b["layer"]) & WORLD_LAYER_BIT) == 0:
				bad_cover_layer += 1
				errors.append("hard cover %s is missing WORLD_LAYER (bit 1)" % b["name"])
		if role == "rim":
			rim_max_y = maxf(rim_max_y, float((b["aabb"] as AABB).end.y))
		elif role == "basin_floor":
			basin_min_y = minf(basin_min_y, float((b["aabb"] as AABB).end.y))

	var tier_counts := {0: 0, 1: 0, 2: 0}
	var min_play_y := INF
	var max_play_y := -INF
	var traversal_sockets: Array[Dictionary] = []
	for s in sockets:
		if s["kind"] in TRAVERSAL_KINDS:
			traversal_sockets.append(s)
			var t := int(s["tier"])
			if tier_counts.has(t):
				tier_counts[t] = int(tier_counts[t]) + 1
			var py := float((s["local_position"] as Vector3).y)
			min_play_y = minf(min_play_y, py)
			max_play_y = maxf(max_play_y, py)
	var populated_tiers := 0
	for t in [0, 1, 2]:
		if int(tier_counts[t]) > 0:
			populated_tiers += 1
		else:
			errors.append("tier %d has zero traversal sockets (3-tier verticality required)" % t)
	var vertical_span := (max_play_y - min_play_y) if max_play_y > -INF and min_play_y < INF else 0.0
	if vertical_span < min_span:
		errors.append("vertical span %.2f m is below %.2f m minimum" % [vertical_span, min_span])

	var clearance_violations: Array[String] = []
	var ball_probe_half := min_clearance * 0.5
	for s in traversal_sockets:
		var declared := float(s["clearance_m"])
		if declared < min_clearance:
			clearance_violations.append("%s declares clearance %.2f m < %.2f m" % [s["id"], declared, min_clearance])
		if s["kind"] == SOCKET_HARPOON_ANCHOR:
			continue
		var p: Vector3 = s["local_position"]
		var probe := AABB(
			Vector3(p.x - ball_probe_half, p.y + 0.35, p.z - ball_probe_half),
			Vector3(min_clearance, min_clearance - 0.35, min_clearance)
		)
		for b in solid_boxes:
			if String(b["cover_kind"]) in ["basin_floor", "deck", "rail_surface"]:
				continue
			if (b["aabb"] as AABB).intersects(probe):
				clearance_violations.append("%s blocked by %s within %.1f m grown-heft clearance" % [s["id"], b["name"], min_clearance])
	var cover_slots: Array = by_kind[SOCKET_COVER_SLOT]
	for i in cover_slots.size():
		for j in range(i + 1, cover_slots.size()):
			var a: Vector3 = cover_slots[i]["local_position"]
			var b_pos: Vector3 = cover_slots[j]["local_position"]
			var dist := Vector2(a.x - b_pos.x, a.z - b_pos.z).length()
			if dist < MIN_COVER_SLOT_SPACING_M:
				clearance_violations.append("cover slots %s and %s are %.2f m apart (< %.2f m)" % [cover_slots[i]["id"], cover_slots[j]["id"], dist, MIN_COVER_SLOT_SPACING_M])
	for msg in clearance_violations:
		errors.append("clearance: " + msg)

	var landmark_apex_y := -INF
	var landmark_target := Vector3.ZERO
	var landmarks: Array = by_kind[SOCKET_SIGHTLINE_LANDMARK]
	for lm in landmarks:
		var pos: Vector3 = lm["local_position"]
		var h := float((lm["meta"] as Dictionary).get(META_LANDMARK_HEIGHT, 0.0))
		var apex := pos.y + h
		if apex > landmark_apex_y:
			landmark_apex_y = apex
			landmark_target = Vector3(pos.x, apex, pos.z)
	var prominence := landmark_apex_y - max_play_y if landmark_apex_y > -INF and max_play_y > -INF else 0.0
	if landmarks.size() > 0:
		if landmark_apex_y < min_landmark_apex:
			errors.append("landmark apex %.2f m < %.2f m minimum" % [landmark_apex_y, min_landmark_apex])
		if prominence < min_prominence:
			errors.append("landmark prominence %.2f m above top tier < %.2f m minimum" % [prominence, min_prominence])

	var sight_observers: Array[Dictionary] = []
	for s in sockets:
		if s["kind"] in [SOCKET_TRAVERSAL_RAIL, SOCKET_JUMP_PAD, SOCKET_COVER_SLOT]:
			sight_observers.append(s)
	var visible_count := 0
	if landmarks.size() > 0 and not sight_observers.is_empty():
		for obs in sight_observers:
			var eye := (obs["local_position"] as Vector3) + Vector3.UP * 2.0
			if _segment_clear_of_occluders(eye, landmark_target, solid_boxes):
				visible_count += 1
	var sight_share := float(visible_count) / float(maxi(1, sight_observers.size()))
	if landmarks.size() > 0 and sight_share < min_sight:
		errors.append("landmark sight share %.2f < %.2f (%d/%d sockets see apex)" % [sight_share, min_sight, visible_count, sight_observers.size()])

	var loop_report := _validate_loop_connectivity(traversal_sockets, by_id)
	for err in loop_report["errors"]:
		errors.append("loop: " + String(err))

	var bowl_depth := (rim_max_y - basin_min_y) if rim_max_y > -INF and basin_min_y < INF else 0.0
	if rim_max_y > -INF and basin_min_y < INF:
		if bowl_depth < min_bowl_depth:
			errors.append("bowl rim depth %.2f m < %.2f m minimum" % [bowl_depth, min_bowl_depth])
	else:
		warnings.append("chunk has no rim/basin_floor cover_kind colliders tagged for bowl depth check")

	var nav_info := _validate_navigation(chunk_root, solid_boxes)
	if bool(config.get("require_navigation", true)):
		for nerr in nav_info["errors"]:
			errors.append("navigation: " + String(nerr))

	var vantage_count := 0
	for s in traversal_sockets:
		if int(s["tier"]) >= 1 and bool((s["meta"] as Dictionary).get("vantage_point", false)):
			vantage_count += 1
	if vantage_count < 2:
		warnings.append("fewer than 2 elevated vantage_point sockets tagged on Tier 1/2")

	var metrics := {
		"socket_count": sockets.size(),
		"tier_counts": tier_counts,
		"populated_tiers": populated_tiers,
		"vertical_span_m": vertical_span,
		"min_clearance_m": min_clearance,
		"clearance_violations": clearance_violations.size(),
		"hard_cover_count": hard_cover_count,
		"bad_cover_layer": bad_cover_layer,
		"bad_static_mask": bad_static_mask,
		"landmark_apex_m": landmark_apex_y if landmark_apex_y > -INF else 0.0,
		"landmark_prominence_m": prominence,
		"sight_share": sight_share,
		"sight_visible": visible_count,
		"sight_total": sight_observers.size(),
		"bowl_depth_m": bowl_depth,
		"has_three_tier_cycle": bool(loop_report["has_three_tier_cycle"]),
		"dead_end_count": int(loop_report["dead_end_count"]),
		"floor_escape_ok": bool(loop_report["floor_escape_ok"]),
		"nav_region_count": int(nav_info["region_count"]),
		"nav_polygon_count": int(nav_info["polygon_count"]),
		"nav_link_count": int(nav_info["link_count"]),
		"nav_tiers_covered": int(nav_info["tiers_covered"]),
		"nav_floating_polygons": int(nav_info["floating_polygons"]),
		"nav_valid": bool(nav_info["ok"]),
		"vantage_count": vantage_count,
	}

	return {
		"ok": errors.is_empty(),
		"errors": errors,
		"warnings": warnings,
		"metrics": metrics,
		"sockets": sockets,
	}



static func _resolve_socket_kind(marker: Marker3D) -> StringName:
	if marker.has_meta(META_KIND):
		var raw := StringName(String(marker.get_meta(META_KIND)))
		if raw in SOCKET_KINDS:
			return raw
	for kind in GROUP_BY_KIND:
		if marker.is_in_group(GROUP_BY_KIND[kind]):
			return kind
	return &""


static func _resolve_tier(marker: Marker3D, local_y: float) -> int:
	if marker.has_meta(META_TIER):
		return int(marker.get_meta(META_TIER))
	if local_y < TIER_0_MAX_Y:
		return 0
	if local_y < TIER_1_MAX_Y:
		return 1
	return 2


static func _resolve_links(marker: Marker3D) -> Array[String]:
	var out: Array[String] = []
	if not marker.has_meta(META_ROUTE_LINKS):
		return out
	var raw: Variant = marker.get_meta(META_ROUTE_LINKS)
	if raw is PackedStringArray or raw is Array:
		for item in raw:
			var s := String(item).strip_edges()
			if s != "":
				out.append(s)
	elif raw is String:
		for part in (raw as String).split(",", false):
			var s := part.strip_edges()
			if s != "":
				out.append(s)
	return out


static func _local_transform_of(node: Node3D, root: Node) -> Transform3D:
	var chain: Array[Node3D] = []
	var cur: Node = node
	while cur != null and cur != root:
		if cur is Node3D:
			chain.append(cur as Node3D)
		cur = cur.get_parent()
	var acc := Transform3D.IDENTITY
	for i in range(chain.size() - 1, -1, -1):
		acc = acc * chain[i].transform
	return acc


static func _world_transform_of(node: Node3D, root: Node) -> Transform3D:
	if node.is_inside_tree():
		return node.global_transform
	var root_xform := (root as Node3D).transform if root is Node3D else Transform3D.IDENTITY
	return root_xform * _local_transform_of(node, root)


static func _collect_local_solid_boxes(chunk_root: Node) -> Array[Dictionary]:
	var boxes: Array[Dictionary] = []
	if chunk_root == null or not is_instance_valid(chunk_root):
		return boxes
	var stack: Array[Node] = [chunk_root]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if cur is StaticBody3D:
			var body := cur as StaticBody3D
			var cover_kind := String(body.get_meta(META_COVER_KIND, ""))
			for child in body.get_children():
				if child is CollisionShape3D:
					var cs := child as CollisionShape3D
					if cs.disabled or cs.shape == null:
						continue
					var aabb := _shape_local_aabb(cs, chunk_root)
					if aabb.size.length() > 0.001:
						boxes.append({
							"name": String(body.name),
							"layer": body.collision_layer,
							"mask": body.collision_mask,
							"cover_kind": cover_kind,
							"aabb": aabb,
						})
		for child in cur.get_children():
			stack.append(child)
	return boxes


static func _shape_local_aabb(cs: CollisionShape3D, chunk_root: Node) -> AABB:
	var half := Vector3.ZERO
	if cs.shape is BoxShape3D:
		half = (cs.shape as BoxShape3D).size * 0.5
	elif cs.shape is CylinderShape3D:
		var cyl := cs.shape as CylinderShape3D
		half = Vector3(cyl.radius, cyl.height * 0.5, cyl.radius)
	elif cs.shape is SphereShape3D:
		var r := (cs.shape as SphereShape3D).radius
		half = Vector3(r, r, r)
	else:
		return AABB()
	var xform := _local_transform_of(cs, chunk_root)
	var first := true
	var out := AABB()
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var corner := xform * Vector3(half.x * sx, half.y * sy, half.z * sz)
				out = AABB(corner, Vector3.ZERO) if first else out.expand(corner)
				first = false
	return out


static func _validate_navigation(chunk_root: Node, solid_boxes: Array[Dictionary]) -> Dictionary:
	var errors: Array[String] = []
	var region_count := 0
	var polygon_count := 0
	var link_count := 0
	var floating_polygons := 0
	var tiers_seen := {}

	if chunk_root != null and is_instance_valid(chunk_root):
		var stack: Array[Node] = [chunk_root]
		while not stack.is_empty():
			var cur: Node = stack.pop_back()
			if cur is NavigationLink3D:
				link_count += 1
			elif cur is NavigationRegion3D:
				region_count += 1
				var region := cur as NavigationRegion3D
				var region_xform := _local_transform_of(region, chunk_root)
				var nav_mesh := region.navigation_mesh
				if nav_mesh == null:
					errors.append("NavigationRegion3D %s has null navigation_mesh" % region.name)
				else:
					if nav_mesh.agent_radius < BALL_COLLIDER_RADIUS_M:
						errors.append("NavigationMesh on %s has agent_radius %.2f < %.2f" % [region.name, nav_mesh.agent_radius, BALL_COLLIDER_RADIUS_M])
					var verts := nav_mesh.get_vertices()
					var polys := nav_mesh.get_polygon_count()
					polygon_count += polys
					if polys < 1 or verts.size() < 3:
						errors.append("NavigationMesh on %s has no walkable polygons" % region.name)
					else:
						for pi in polys:
							var idxs := nav_mesh.get_polygon(pi)
							if idxs.size() < 3:
								continue
							var centroid := Vector3.ZERO
							for idx in idxs:
								centroid += region_xform * verts[idx]
							centroid /= float(idxs.size())
							var tier := 0 if centroid.y < TIER_0_MAX_Y else (1 if centroid.y < TIER_1_MAX_Y else 2)
							tiers_seen[tier] = true
							if not _has_support_under(centroid, solid_boxes):
								floating_polygons += 1
								errors.append("NavigationMesh polygon %d on %s floats over empty space at %s" % [pi, region.name, str(centroid)])
			for child in cur.get_children():
				stack.append(child)

	if region_count == 0:
		errors.append("chunk has zero NavigationRegion3D nodes")
	if tiers_seen.size() < 3:
		errors.append("NavigationMesh covers only %d tier(s); expected all 3 tiers" % tiers_seen.size())
	if link_count < 1:
		errors.append("chunk has zero NavigationLink3D nodes connecting vertical tiers")

	return {
		"ok": errors.is_empty(),
		"region_count": region_count,
		"polygon_count": polygon_count,
		"link_count": link_count,
		"tiers_covered": tiers_seen.size(),
		"floating_polygons": floating_polygons,
		"errors": errors,
	}


static func _has_support_under(point: Vector3, solid_boxes: Array[Dictionary]) -> bool:
	var foot := Vector3(point.x, point.y - 0.5, point.z)
	for entry in solid_boxes:
		var kind := String(entry["cover_kind"])
		if not (kind in ["basin_floor", "deck", "rail_surface", "rim"]):
			continue
		var box: AABB = entry["aabb"]
		if foot.x >= box.position.x - 0.5 and foot.x <= box.end.x + 0.5 \
				and foot.z >= box.position.z - 0.5 and foot.z <= box.end.z + 0.5 \
				and absf(point.y - box.end.y) <= 1.25:
			return true
	return false


static func _segment_clear_of_occluders(a: Vector3, b: Vector3, boxes: Array[Dictionary]) -> bool:
	for entry in boxes:
		var kind := String(entry["cover_kind"])
		if kind == "landmark" or kind == "basin_floor":
			continue
		var box: AABB = entry["aabb"]
		if box.has_point(a) or box.has_point(b):
			continue
		var hit: Variant = box.intersects_segment(a, b)
		if hit != null:
			return false
	return true


static func _validate_loop_connectivity(traversal_sockets: Array[Dictionary], by_id: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var adj := {}
	var ids: Array[String] = []
	var tier_of := {}
	for s in traversal_sockets:
		var sid := String(s["id"])
		ids.append(sid)
		tier_of[sid] = int(s["tier"])
		adj[sid] = []

	for s in traversal_sockets:
		var sid := String(s["id"])
		for dst in s["route_links"]:
			if not by_id.has(dst):
				errors.append("socket %s links to unknown socket %s" % [sid, dst])
				continue
			if adj.has(dst) and not (adj[sid] as Array).has(dst):
				(adj[sid] as Array).append(dst)

	var dead_ends := 0
	for sid in ids:
		if (adj[sid] as Array).is_empty():
			dead_ends += 1
			errors.append("dead-end socket with zero outgoing loop links: " + sid)

	var floor_escape_ok := true
	for sid in ids:
		if int(tier_of[sid]) != 0:
			continue
		var reached := _bfs_reachable(sid, adj)
		var escaped := false
		for r in reached:
			if int(tier_of[r]) >= 1:
				escaped = true
				break
		if not escaped:
			floor_escape_ok = false
			errors.append("floor basin socket %s cannot escape to upper tiers (dead-end pit)" % sid)

	var has_three_tier_cycle := false
	for sid in ids:
		if int(tier_of[sid]) != 0:
			continue
		var forward_reach := _bfs_reachable(sid, adj)
		var saw_t1 := false
		var saw_t2 := false
		for node_id in forward_reach:
			var rev_reach := _bfs_reachable(node_id, adj)
			if not rev_reach.has(sid):
				continue
			if int(tier_of[node_id]) == 1:
				saw_t1 = true
			elif int(tier_of[node_id]) == 2:
				saw_t2 = true
		if saw_t1 and saw_t2:
			has_three_tier_cycle = true
			break
	if not has_three_tier_cycle:
		errors.append("no continuous 3-tier traversal loop connecting Floor Basin, Mid Catwalk, and Upper Gantry")

	return {
		"errors": errors,
		"dead_end_count": dead_ends,
		"floor_escape_ok": floor_escape_ok,
		"has_three_tier_cycle": has_three_tier_cycle,
	}


static func _bfs_reachable(start: String, adj: Dictionary) -> Dictionary:
	var visited := {}
	var queue: Array[String] = []
	for nxt in adj.get(start, []):
		var ns := String(nxt)
		if not visited.has(ns):
			visited[ns] = true
			queue.append(ns)
	while not queue.is_empty():
		var cur: String = queue.pop_front()
		for nxt in adj.get(cur, []):
			var ns := String(nxt)
			if not visited.has(ns):
				visited[ns] = true
				queue.append(ns)
	return visited
