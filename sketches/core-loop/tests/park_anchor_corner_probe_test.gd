extends SceneTree
# smoke: timeout=360s

# Forced-contact probe for the fitted anchor posts (coordinator ruling 6331254683 on #241, item 1). "0 stops near a corner"
# in a bot run proves nothing when the ball never touched a corner, so this test aims scripted balls at them.
#
# Setup per park (dam, pit, sinkhole, islands, crown; islands' posts return with clear_zones' spans_park): the park's own rows through
# ParkRecipes.place_row on a flat ground at y 0 (the posts' turns and box splits do not depend on the ground), with
# ParkRecipes.clear_zones as the Placer passes them. Targets: up to POSTS_PER_PARK fitted posts, over_limit rows first, then
# the shortest sizes, then the rest, ride-line posts first within a row. "Fitted" is read from anchor_fit.json directly
# (variant by ParkRecipes.anchor_variant, size equal to size[1]), so the same targets are picked on a base without the
# wiring, where every post is the one 8 m box.
#
# Per target post, each vertical-edge corner of every collider box that covers the ball's centre height (BALL_R, a ball
# rolling on the ground) is aimed at along the diagonal from the box centre, from AIM_START_M out, centre line through the
# corner and shifted 1 m to either side (the corner region). One ball per shot: RigidBody3D, radius Tuning.RADIUS, the real
# ball's mass, damping, friction 0.9 and bounce 0.25 (rigid_ball.gd setup), rolling without slip, layers as the ball's. All
# shots of a speed run together in fixed physics steps (balls do not collide with each other); no wall clock.
#   ride speed   SpeedTier.MULTIPLES[BLAZING] x the tuned cruise (tuning.gd cruise 14) = 26.6 m/s, the blazing tier that
#                traversal_line.gd records as blazing_mps and the PARK.md section 8 peak band is read against.
#   slow roll    SpeedTier.MULTIPLES[CRUISE] x cruise = 7.7 m/s, the floor of the cruise tier: the slowest speed at which
#                RunLog.Traversal still arms a dead stop (MOVING_TIER), so the slowest roll whose stop the bot would count.
# Per shot: the first tick the ball touches an anchor body is the contact. stop = RunLog.Traversal.step (the bot's own dead
# stop rule) counts one within STOP_WINDOW_S of the contact; bounce = AnchorContacts' rule (the velocity along the nearest
# box face's normal goes from below -1 m/s to above 0).
#
# The visible post is the drawn mesh, measured in engine: the placed "Posts" MultiMesh (anchor_draws' transform per post,
# the variant's render mesh, stretched by tall / 10 and quarter-turned as drawn). air = the distance from the contact point
# (the nearest point of the touched collider box to the ball's centre, so it is the ball's surface that meets the box) to the
# nearest triangle of any drawn post within 12 m. Modeling's anchor_gap.py measures the same thing offline from the GLBs
# (gap_*_m, gap_face_worst_*_m in anchor_fit.json); this one reads what the game places. An event is a stop or a bounce
# with air above FAR_M (1.5 m, the ruling's line). On a ride line = AnchorContacts.on_lane at the contact point (the lane
# mask is generous: its cell is 8 m wide).
# Gate (head only, where anchor_fit_boxes exists): 0 events per park, on a ride line or off it (ruling 6332145318). The same file runs on the
# base 5366a351 (copy it and traversal_line.gd into a base worktree), where it prints the numbers and gates nothing: there the
# 8 m boxes should show the empty-air events Modeling measured (the positive control).

const T := preload("res://tests/support/t.gd")
const PhysicsLayers := preload("res://src/core/physics_layers.gd")
const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const TraversalLine := preload("res://tools/traversal_line.gd")
const RunLog := preload("res://src/core/run_log.gd")
const SpeedTier := preload("res://src/movement/speed_tier.gd")
const Tuning := preload("res://src/movement/tuning.gd")

const PARKS := ["dam", "pit", "sinkhole", "islands", "crown"]
const FIT_PATH := "res://src/world/park/anchors/anchor_fit.json"
const POSTS_PER_PARK := 24
const MIN_POSTS := 20
const POSTS_PER_ROW := 4
const POSTS_PER_OVER_ROW := 6
const AIM_START_M := 10.0
const OFFSETS_M := [-1.0, 0.0, 1.0]
const FAR_M := 1.5
const QUERY_M := 12.0
const STOP_WINDOW_S := 0.8
const MAX_TICKS := 300
const BOUNCE_MIN_MPS := 1.0
const BOX_REACH_M := 25.0
const GATE_PER_PARK := 0
const GATE_ON_LINE := 0

var _t := T.new("park_anchor_corner_probe_test")
var _AC = TraversalLine.AnchorContacts
var _cruise := 14.0
var _head := false
var _fits := {}
var _floor: StaticBody3D


func _initialize() -> void:
	_run()


func _run() -> void:
	await physics_frame
	for spec: Dictionary in Tuning.SPECS:
		if spec["key"] == "cruise":
			_cruise = float(spec["value"])
	_head = (ParkRecipes as GDScript).source_code.contains("static func anchor_fit_boxes(")
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(FIT_PATH))
	_fits = parsed["fits"] if parsed is Dictionary else {}
	print("PROBE mode=%s cruise=%.1f ride=%.2f slow=%.2f" % ["head (fitted colliders)" if _head else "base (8 m boxes)", _cruise, _ride_speed(), _slow_speed()])
	_t.check("the fit table is readable and the toolchain has the corner helpers", not _fits.is_empty() and _AC != null)
	_check_triangle()
	var speeds := [["ride", _ride_speed()], ["slow", _slow_speed()]]
	for park_name: String in PARKS:
		await _probe_park(park_name, speeds)
	quit(_t.verdict())


func _ride_speed() -> float:
	return SpeedTier.MULTIPLES[SpeedTier.BLAZING] * _cruise


func _slow_speed() -> float:
	return SpeedTier.MULTIPLES[SpeedTier.CRUISE] * _cruise


# --- Point to triangle distance (Ericson, Real-Time Collision Detection 5.1.5), planted ---
func _check_triangle() -> void:
	var a := Vector3(0, 0, 0)
	var b := Vector3(4, 0, 0)
	var c := Vector3(0, 0, 4)
	_t.near("triangle distance: 3 m above the face", _tri_dist(Vector3(1, 3, 1), a, b, c), 3.0)
	_t.near("triangle distance: a corner region is the vertex", _tri_dist(Vector3(-3, 0, -4), a, b, c), 5.0)
	_t.near("triangle distance: beyond the long edge", _tri_dist(Vector3(5, 0, 5), a, b, c), sqrt(18.0))


static func _tri_dist(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> float:
	var ab := b - a
	var ac := c - a
	var ap := p - a
	var d1 := ab.dot(ap)
	var d2 := ac.dot(ap)
	if d1 <= 0.0 and d2 <= 0.0:
		return ap.length()
	var bp := p - b
	var d3 := ab.dot(bp)
	var d4 := ac.dot(bp)
	if d3 >= 0.0 and d4 <= d3:
		return bp.length()
	var vc := d1 * d4 - d3 * d2
	if vc <= 0.0 and d1 >= 0.0 and d3 <= 0.0:
		return (p - (a + ab * (d1 / (d1 - d3)))).length()
	var cp := p - c
	var d5 := ab.dot(cp)
	var d6 := ac.dot(cp)
	if d6 >= 0.0 and d5 <= d6:
		return cp.length()
	var vb := d5 * d2 - d1 * d6
	if vb <= 0.0 and d2 >= 0.0 and d6 <= 0.0:
		return (p - (a + ac * (d2 / (d2 - d6)))).length()
	var va := d3 * d6 - d5 * d4
	if va <= 0.0 and (d4 - d3) >= 0.0 and (d5 - d6) >= 0.0:
		return (p - (b + (c - b) * ((d4 - d3) / ((d4 - d3) + (d5 - d6))))).length()
	var denom := 1.0 / (va + vb + vc)
	return (p - (a + ab * (vb * denom) + ac * (vc * denom))).length()


# --- Targets ---

# The fit entry ({"size", "over_limit", ...}) a kit row's variant has at its height, {} when unlisted.
func _fit_entry(row: Dictionary) -> Dictionary:
	var recipe := String(row.get("recipe", ""))
	if not ParkRecipes.ANCHOR_KITS.has(recipe):
		return {}
	var key: String = ParkRecipes.anchor_paths(recipe)[ParkRecipes.anchor_variant(row)].get_file().get_basename()
	for entry: Dictionary in _fits.get(key, []):
		if is_equal_approx(float(entry["size"]), float(row["size"][1])):
			return {"key": key, "over_limit": bool(entry.get("over_limit", false)), "size": float(entry["size"])}
	return {}


# Up to cap posts: ride-line ones spread first (at most half the cap, rounded up), the rest spread after.
func _pick_posts(posts: PackedVector2Array, mask: Dictionary, cap: int) -> Array:
	var lane: Array = []
	var off: Array = []
	for k in posts.size():
		if _AC.on_lane(mask, posts[k].x, posts[k].y):
			lane.append(k)
		else:
			off.append(k)
	var out := _spread(lane, mini(cap, (cap + 1) / 2))
	out.append_array(_spread(off, cap - out.size()))
	return out


func _spread(list: Array, count: int) -> Array:
	var out: Array = []
	var take := mini(count, list.size())
	for n in take:
		out.append(list[int(floor(float(n) * list.size() / take))])
	return out


func _probe_park(park_name: String, speeds: Array) -> void:
	var path := "res://src/world/park/park_%s.json" % park_name
	var park: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var mask: Dictionary = ParkMap.lane_mask_for(path, park)
	var zones := ParkRecipes.clear_zones(park)
	var candidates: Array = []
	for row: Dictionary in ParkRecipes.placed_rows(park):
		var entry := _fit_entry(row)
		if not entry.is_empty():
			candidates.append({"row": row, "entry": entry})
	candidates.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		if x["entry"]["over_limit"] != y["entry"]["over_limit"]:
			return x["entry"]["over_limit"]
		if not is_equal_approx(float(x["entry"]["size"]), float(y["entry"]["size"])):
			return float(x["entry"]["size"]) < float(y["entry"]["size"])
		return String(x["row"]["id"]) < String(y["row"]["id"]))
	var world := Node3D.new()
	root.add_child(world)
	_floor = _make_floor(world)
	var targets: Array = []
	var posted: Array = []
	var ground := func(_x: float, _z: float) -> float: return 0.0
	for cand: Dictionary in candidates:
		if targets.size() >= POSTS_PER_PARK:
			break
		var row: Dictionary = cand["row"]
		var posts := ParkRecipes.anchor_posts(row, zones)
		if posts.is_empty():
			continue
		var node: Node3D = ParkRecipes.place_row(row, world, ground, Callable(), zones, posts)
		var body := node.get_node_or_null("Collider") as StaticBody3D
		var view := node.get_node_or_null("Posts") as MultiMeshInstance3D
		if body == null or view == null:
			continue
		var cap := POSTS_PER_OVER_ROW if cand["entry"]["over_limit"] else POSTS_PER_ROW
		var picked := _pick_posts(posts, mask, mini(cap, POSTS_PER_PARK - targets.size()))
		var entry := {"row": row, "entry": cand["entry"], "body": body, "view": view, "posts": posts, "node": node, "picked": picked}
		posted.append(entry)
		for k: int in picked:
			targets.append({"entry": entry, "k": k})
	# A park with few fitted rows (pit) gets more posts per row until it has MIN_POSTS.
	for bump in [10, 20, 40]:
		if targets.size() >= MIN_POSTS:
			break
		for entry: Dictionary in posted:
			for k: int in _pick_posts(entry["posts"], mask, bump):
				if targets.size() < POSTS_PER_PARK and not entry["picked"].has(k):
					entry["picked"].append(k)
					targets.append({"entry": entry, "k": k})
	var rows_used := posted.filter(func(e: Dictionary) -> bool: return not e["picked"].is_empty())
	var drawn := _drawn_posts(posted)
	var boxes := _collect_boxes(posted)
	if _head:
		_check_hull_faces_visible(park_name, boxes)
	var shots_by_speed := {}
	for pair: Array in speeds:
		var shots := _make_shots(park_name, targets, boxes, pair[0], float(pair[1]))
		await _fly(shots, world, boxes, drawn, mask)
		shots_by_speed[pair[0]] = shots
	_report(park_name, targets, rows_used, shots_by_speed)
	world.free()


func _make_floor(parent: Node3D) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 0
	body.set_collision_layer_value(PhysicsLayers.WORLD_LAYER, true)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4000.0, 1.0, 4000.0)
	shape.shape = box
	shape.position = Vector3(0.0, -0.5, 0.0)
	body.add_child(shape)
	parent.add_child(body)
	return body


# Every drawn post: {"xf" rigid world transform, "faces" the row's mesh stretched as drawn, "row"}. The transforms come from
# ParkRecipes.anchor_draws, the call place_anchor_field draws its MultiMesh with (a headless MultiMesh keeps no transforms
# to read back); the mesh is the placed Posts view's. Instance k is post k.
func _drawn_posts(posted: Array) -> Array:
	var out: Array = []
	var ground := func(_x: float, _z: float) -> float: return 0.0
	for entry: Dictionary in posted:
		var view: MultiMeshInstance3D = entry["view"]
		var mesh: Mesh = view.multimesh.mesh
		var node: Node3D = entry["node"]
		var xfs: Array = ParkRecipes.anchor_draws(entry["row"], entry["posts"], ground, node.transform, bool(node.get_meta("anchor_kit", false)))
		if mesh == null or xfs.is_empty():
			continue
		var rigid_basis := (xfs[0] as Transform3D).basis.orthonormalized()
		var stretch := rigid_basis.inverse() * (xfs[0] as Transform3D).basis
		var faces := mesh.get_faces()
		var scaled := PackedVector3Array()
		scaled.resize(faces.size())
		for i in faces.size():
			scaled[i] = stretch * faces[i]
		for k in xfs.size():
			var world_xf: Transform3D = node.global_transform * (xfs[k] as Transform3D)
			out.append({"xf": Transform3D(world_xf.basis.orthonormalized(), world_xf.origin), "faces": scaled, "row": entry["row"]["id"]})
	return out


# AnchorContacts box records of every placed collider box, with the row's fit facts.
func _collect_boxes(posted: Array) -> Array:
	var out: Array = []
	for entry: Dictionary in posted:
		var row: Dictionary = entry["row"]
		var info := {"row": String(row["id"]), "key": entry["entry"]["key"], "size_y": float(row["size"][1]), "fitted": _head, "over_limit": entry["entry"]["over_limit"]}
		for shape: Dictionary in ParkRecipes.collider_shapes(entry["body"]):
			if shape.shape is BoxShape3D:
				var rec: Dictionary = _AC.box_record(shape.global_transform, (shape.shape as BoxShape3D).size, info)
				rec["body"] = entry["body"].get_instance_id()
				out.append(rec)
			elif shape.shape is ConvexPolygonShape3D:
				# A hull band (the drawn mesh's convex hull): its post-local bounding box stands in as the aim target (the
				# old box's corners). The surface tests (contact normal, bounce rule) read the band as the recorder does, a
				# vertical prism of its XZ hull ("surface"), so a glance off a hull face well inside the box still counts.
				var box := AABB()
				var pts := (shape.shape as ConvexPolygonShape3D).points
				for n in pts.size():
					box = AABB(pts[n], Vector3.ZERO) if n == 0 else box.expand(pts[n])
				var xf := Transform3D(shape.global_transform.basis, shape.global_transform * box.get_center())
				var rec: Dictionary = _AC.box_record(xf, box.size, info)
				rec["body"] = entry["body"].get_instance_id()
				rec["hull"] = true
				rec["surface"] = _AC.hull_record(shape.global_transform, _AC.hull_outline(pts), info)
				out.append(rec)
	return out


# The shortest air from a point to the drawn posts within QUERY_M (INF when none).
func _air_gap(at: Vector3, drawn: Array) -> Dictionary:
	var best := INF
	var which := ""
	for post: Dictionary in drawn:
		var xf: Transform3D = post["xf"]
		if Vector2(xf.origin.x - at.x, xf.origin.z - at.z).length() > QUERY_M + 4.0:
			continue
		var local := xf.affine_inverse() * at
		var faces: PackedVector3Array = post["faces"]
		for i in range(0, faces.size(), 3):
			var d := _tri_dist(local, faces[i], faces[i + 1], faces[i + 2])
			if d < best:
				best = d
				which = String(post["row"])
	return {"air": best, "row": which}


func _make_shots(park_name: String, targets: Array, boxes: Array, speed_name: String, speed: float) -> Array:
	var shots: Array = []
	for target: Dictionary in targets:
		var entry: Dictionary = target["entry"]
		var row: Dictionary = entry["row"]
		var p: Vector2 = entry["posts"][target["k"]]
		for bi in boxes.size():
			var b: Dictionary = boxes[bi]
			if b["row"] != row["id"] or b["y0"] > _ball_y() or b["y1"] < _ball_y():
				continue
			var o: Vector3 = (b["xf"] as Transform3D).origin
			if Vector2(o.x - p.x, o.z - p.y).length() > 8.0:
				continue
			var near: Array = []
			for bj in boxes.size():
				var q: Vector3 = (boxes[bj]["xf"] as Transform3D).origin
				if Vector2(q.x - o.x, q.z - o.z).length() <= BOX_REACH_M:
					near.append(boxes[bj])
			for ci in 4:
				var corner: Vector2 = b["corners"][ci]
				var out := (corner - Vector2(o.x, o.z)).normalized()
				var side := Vector2(-out.y, out.x)
				for off: float in OFFSETS_M:
					var aim := corner + side * off
					var start := aim + out * AIM_START_M
					shots.append({"park": park_name, "speed_name": speed_name, "speed": speed, "row": String(row["id"]), "size_y": float(row["size"][1]),
						"over_limit": bool(entry["entry"]["over_limit"]), "key": entry["entry"]["key"], "post": target["k"], "corner": ci, "offset": off,
						"start": Vector3(start.x, _ball_y(), start.y), "dir": Vector3(-out.x, 0.0, -out.y), "near": near,
						"contact": -1, "gap": INF, "gap_row": "", "stopped": false, "bounced": false, "on_line": false, "at": Vector3.ZERO})
	return shots


func _ball_y() -> float:
	return Tuning.RADIUS


func _make_ball(shot: Dictionary, parent: Node3D) -> RigidBody3D:
	var ball := RigidBody3D.new()
	ball.mass = 6.0
	ball.can_sleep = false
	ball.continuous_cd = true
	ball.contact_monitor = true
	ball.max_contacts_reported = 8
	ball.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	ball.linear_damp = 0.0
	ball.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	ball.angular_damp = 0.25
	var material := PhysicsMaterial.new()
	material.friction = 0.9
	material.bounce = 0.25
	ball.physics_material_override = material
	ball.collision_layer = 0
	ball.collision_mask = 0
	ball.set_collision_layer_value(2, true)
	ball.set_collision_mask_value(1, true)
	ball.set_collision_mask_value(3, true)
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = Tuning.RADIUS
	shape.shape = sphere
	ball.add_child(shape)
	ball.position = shot["start"]
	var v: Vector3 = (shot["dir"] as Vector3) * float(shot["speed"])
	ball.linear_velocity = v
	ball.angular_velocity = Vector3.UP.cross(v) / Tuning.RADIUS
	parent.add_child(ball)
	return ball


func _any_hull(list: Array) -> bool:
	for b: Dictionary in list:
		if b.get("hull", false):
			return true
	return false


# The contact point the engine reports for a ball at `at` (the touched shape's closest point), else the fallback.
# The bounce rule can see a hull face: a point 0.5 m out from a prism edge's midpoint, where that point is still inside
# the band's aim box (the hull is cut well inside it), reads 0.5 m and a level outward normal from the surface the bounce
# rule uses, where the aim box alone reads it as inside (0 m, normal UP), so no sideways arrival could ever count.
func _check_hull_faces_visible(park_name: String, boxes: Array) -> void:
	var planted := 0
	var good := 0
	var first := ""
	for rec: Dictionary in boxes:
		if not rec.has("surface"):
			continue
		var prism: Dictionary = rec["surface"]
		var poly: Array = prism["poly"]
		var y := (float(prism["y0"]) + float(prism["y1"])) * 0.5
		for e in poly.size():
			var a2: Vector2 = poly[e]
			var b2: Vector2 = poly[(e + 1) % poly.size()]
			var edge := b2 - a2
			if edge.length() < 0.5:
				continue
			var out2 := Vector2(edge.y, -edge.x).normalized()
			var p2 := (a2 + b2) * 0.5 + out2 * 0.5
			var at := Vector3(p2.x, y, p2.y)
			if float(_AC.surface_of(at, rec)["dist"]) > 0.0:
				continue
			planted += 1
			var hit: Dictionary = _AC.nearest_surface(at, _surfaces([rec]))
			var n: Vector3 = hit["normal"]
			if absf(float(hit["dist"]) - 0.5) < 0.01 and absf(n.y) < 0.01 and Vector2(n.x, n.z).dot(out2) > 0.99:
				good += 1
			elif first == "":
				first = "%s edge %d: dist %.3f normal %s" % [rec["row"], e, float(hit["dist"]), str(n)]
			break
	_t.check("%s: hull faces cut inside their aim box are planted for the bounce rule (%d bands)" % [park_name, planted], planted > 0)
	_t.check("%s: the bounce rule reads each planted hull face at 0.5 m with its level outward normal (%d of %d)%s" % [park_name, good, planted, "" if first == "" else ", first miss " + first], good == planted)


# The records the surface tests read: a hull band's prism in place of its aim box.
func _surfaces(list: Array) -> Array:
	var out: Array = []
	for rec: Dictionary in list:
		out.append(rec.get("surface", rec))
	return out


func _engine_contact(at: Vector3, fallback: Vector3) -> Vector3:
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = Tuning.RADIUS + 0.1
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, at)
	query.collision_mask = 1 | 4
	query.exclude = [_floor.get_rid()]
	var info := _floor.get_world_3d().direct_space_state.get_rest_info(query)
	return info["point"] if not info.is_empty() else fallback


# Fly every shot together: fixed physics steps until each has run STOP_WINDOW_S past its contact (or MAX_TICKS).
func _fly(shots: Array, parent: Node3D, boxes: Array, drawn: Array, mask: Dictionary) -> void:
	var bodies := {}
	for b: Dictionary in boxes:
		bodies[b["body"]] = true
	var balls: Array = []
	var traversals: Array = []
	var prev_v: Array = []
	var window := int(round(STOP_WINDOW_S * Engine.physics_ticks_per_second))
	for shot: Dictionary in shots:
		balls.append(_make_ball(shot, parent))
		traversals.append(null)
		prev_v.append((shot["dir"] as Vector3) * float(shot["speed"]))
	for tick in MAX_TICKS:
		await physics_frame
		var live := 0
		for i in shots.size():
			var shot: Dictionary = shots[i]
			if balls[i] == null:
				continue
			var ball: RigidBody3D = balls[i]
			var v: Vector3 = ball.linear_velocity
			var at: Vector3 = ball.global_position
			var planar := Vector2(v.x, v.z).length()
			var touching := false
			for body in ball.get_colliding_bodies():
				if bodies.has(body.get_instance_id()):
					touching = true
			if touching and int(shot["contact"]) < 0:
				shot["contact"] = tick
				# The bot's dead stop rule starts at the contact: the roll that arrived (at least tier 1, the ball
				# has been rolling at its speed) arms it, so a ball a hair under the tier floor still counts.
				var arrived := Vector2(prev_v[i].x, prev_v[i].z).length()
				traversals[i] = RunLog.Traversal.new(Engine.physics_ticks_per_second, _cruise)
				traversals[i].step(maxi(SpeedTier.of(arrived, _cruise), SpeedTier.CRUISE), arrived, false, false, false)
				var hit: Dictionary = _AC.nearest_surface(at, _surfaces(shot["near"]))
				var cp: Vector3 = at - (hit["normal"] as Vector3) * float(hit["dist"])
				if _any_hull(shot["near"]):
					cp = _engine_contact(at, cp)
				var gap := _air_gap(cp, drawn)
				shot["gap"] = gap["air"]
				shot["gap_row"] = gap["row"]
				shot["at"] = cp
				shot["on_line"] = _AC.on_lane(mask, cp.x, cp.z)
			if int(shot["contact"]) >= 0:
				traversals[i].step(SpeedTier.of(planar, _cruise), planar, false, false, false)
				if touching or tick - int(shot["contact"]) <= 2:
					var hit2: Dictionary = _AC.nearest_surface(at, _surfaces(shot["near"]))
					if hit2["dist"] <= 2.0 and (prev_v[i] as Vector3).dot(hit2["normal"]) < -BOUNCE_MIN_MPS and v.dot(hit2["normal"]) > 0.0:
						shot["bounced"] = true
				if traversals[i].dead_stops > 0:
					shot["stopped"] = true
				if tick - int(shot["contact"]) >= window:
					ball.queue_free()
					balls[i] = null
					continue
			prev_v[i] = v
			live += 1
		if live == 0:
			break
	for ball in balls:
		if ball != null:
			ball.queue_free()


# --- Report and gate ---

func _is_event(shot: Dictionary) -> bool:
	return int(shot["contact"]) >= 0 and (shot["stopped"] or shot["bounced"]) and float(shot["gap"]) > FAR_M


func _gap_text(gap: float) -> String:
	return "%.2f" % gap if is_finite(gap) else "none within %.0f m" % QUERY_M


func _report(park_name: String, targets: Array, rows_used: Array, by_speed: Dictionary) -> void:
	var names: Array = []
	for e: Dictionary in rows_used:
		names.append("%s%s(size %s, %d posts)" % [e["row"]["id"], "*" if e["entry"]["over_limit"] else "", e["row"]["size"][1], e["picked"].size()])
	print("PROBE %s: %d target posts in %d rows (* over_limit): %s" % [park_name, targets.size(), rows_used.size(), ", ".join(names)])
	var all_events: Array = []
	var all_line := 0
	var all_stops := 0
	var all_stops_line := 0
	var event_posts := {}
	var all_touched := 0
	var all_shots := 0
	var all_bounces := 0
	for speed_name: String in by_speed:
		var shots: Array = by_speed[speed_name]
		var touched := 0
		var stops := 0
		var bounces := 0
		var any_bounces := 0
		var events: Array = []
		var on_line := 0
		var worst := -1.0
		var over2 := 0
		var rows := {}
		for s: Dictionary in shots:
			if int(s["contact"]) < 0:
				continue
			touched += 1
			var far := float(s["gap"]) > FAR_M
			stops += 1 if s["stopped"] and far else 0
			bounces += 1 if s["bounced"] and far and not s["stopped"] else 0
			any_bounces += 1 if s["bounced"] else 0
			if _is_event(s):
				events.append(s)
				event_posts["%s:%d" % [s["row"], s["post"]]] = true
				all_stops += 1 if s["stopped"] else 0
				all_stops_line += 1 if s["stopped"] and s["on_line"] else 0
				on_line += 1 if s["on_line"] else 0
				over2 += 1 if float(s["gap"]) > 2.0 else 0
				worst = maxf(worst, minf(float(s["gap"]), 99.0))
				var label := "%s%s size %s" % [s["row"], "*" if s["over_limit"] else "", s["size_y"]]
				rows[label] = int(rows.get(label, 0)) + 1
		print("PROBE %s %s %.1f m/s: shots %d, touched %d, far stops %d, far bounces (not stops) %d, bounces at any air %d, events %d, on ride line %d, worst air %.2f m, over 2 m %d, rows %s" % [
			park_name, speed_name, float(shots[0]["speed"]) if not shots.is_empty() else 0.0, shots.size(), touched, stops, bounces, any_bounces, events.size(), on_line, worst, over2, str(rows)])
		all_events.append_array(events)
		all_line += on_line
		all_touched += touched
		all_bounces += any_bounces
		all_shots += shots.size()
		_t.check("%s %s: the probe touched at least 90%% of its shots (%d of %d)" % [park_name, speed_name, touched, shots.size()], not shots.is_empty() and touched * 10 >= shots.size() * 9)
	_t.check("%s: at least %d fitted posts targeted (%d)" % [park_name, MIN_POSTS, targets.size()], targets.size() >= MIN_POSTS)
	_t.check("%s: the bounce rule fires in flight, so a far bounce could be seen (%d bounces at any air)" % [park_name, all_bounces], all_bounces > 0)
	if _head:
		_t.check("%s: no stop or bounce more than %.1f m from the visible post lies on a ride line (%d of %d events)" % [park_name, FAR_M, all_line, all_events.size()], all_line <= GATE_ON_LINE)
		_t.check("%s: at most %d stops or bounces more than %.1f m from the visible post (%d)" % [park_name, GATE_PER_PARK, FAR_M, all_events.size()], all_events.size() <= GATE_PER_PARK)
	if all_events.size() > 0:
		var lines: Array = []
		for s: Dictionary in all_events.slice(0, 12):
			lines.append("%s %s post %d corner %d off %+.0f %s: air %s%s%s" % [s["speed_name"], s["row"], s["post"], s["corner"], s["offset"], "stop" if s["stopped"] else "bounce", _gap_text(float(s["gap"])), " ON LINE" if s["on_line"] else "", " (over_limit)" if s["over_limit"] else ""])
		print("PROBE %s events (first 12): %s" % [park_name, " | ".join(lines)])
	print("PROBE %s total: %d shots, %d touched, %d events (stops or bounces), %d on ride line; stops alone %d, %d on ride line; %d distinct posts with an event" % [park_name, all_shots, all_touched, all_events.size(), all_line, all_stops, all_stops_line, event_posts.size()])
