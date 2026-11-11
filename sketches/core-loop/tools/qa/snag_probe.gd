extends RefCounted

# Snag probe (wave 36, map standard point 8c): rolls the ball at cruise along and over every large
# static piece of a built scene and records each place it snags. Shared by tools/qa/snag_sweep.gd (a
# park stage or the Slag Bowl) and tests/snag_sweep_test.gd (a fixture floor with a planted lip).
#
# A piece is a ball-blocking static body (layer 1, ground tiles and areas left out) whose footprint
# is at least LARGE_M on one side. Each piece gets lanes:
#   ride   a piece no taller than RIDE_H, which the ball is meant to roll over: LANES lanes across it
#          in each of the four axis directions (forward and backward along each axis).
#   graze  a taller piece: along each of its four faces in both directions, aimed GRAZE_DEG into the
#          face, so the ball slides along the whole wall. A flat face gives a contact turned well
#          off the line of travel; a notch, a corner or a lip gives one that faces it.
# A snag is a lane where the ball lost at least `loss` of its planar speed within `window_s` while a
# contact ahead of it faced (in plan) less than `max_angle_deg` off the line of travel. One snag per lane (the
# ball is stopped there; the lane ends). Calm world, no enemies: only the map answers.
#
# The probe only reads the game: ball position, velocity, contacts and the scene's colliders.

const Tuning := preload("res://src/movement/tuning.gd")

const WORLD_MASK := 1
const LARGE_M := 6.0
const RIDE_H := 1.5
const LANES := 3
const RUN_M := 10.0
const GRAZE_DEG := 15.0
const COVER_PAD := 0.6
const CELL := 16.0
const MAX_LANE_S := 14.0
# A contact counts as a wall or lip when its normal leans at least this far off the vertical; the
# angle to the line of travel is then read in plan, so a lip's tilted edge reads as the face it is.
const MIN_FLAT := 0.3

var loss := 0.5
var window_s := 0.2
var max_angle_deg := 45.0
var min_before := 0.5
# How many times a contact faced the ball's line of travel, counted over every frame of every lane
# rolled. The test reads it to tell a probe that saw the lip but missed the loss from a blind one.
var contacts_seen := 0

var _tree: SceneTree
var _game
var _source
var _meshes := {}
var multimesh_trusted := true


func _init(tree: SceneTree, game, source) -> void:
	_tree = tree
	_game = game
	_source = source


# Every large piece under `root`: path, body, AABB (world), the ground it stands on is not asked here.
# `per_shape` makes each convex or box shape of a body its own piece, path "<body>#<shape owner>",
# for a body that is a whole map in one (the Slag Bowl: floor, rim and wall are trimeshes and count
# as ground; its ramps, kickers and masts are the pieces).
func pieces(root: Node, per_shape := false) -> Array:
	var player_rid: RID = _game.player.body().get_rid()
	var out := []
	var nodes := root.find_children("*", "CollisionObject3D", true, false)
	for n in nodes:
		var co: CollisionObject3D = n
		if co is Area3D or co.get_rid() == player_rid or (co.collision_layer & WORLD_MASK) == 0:
			continue
		if co.get_parent() != null and String(co.get_parent().name) == "Tiles":
			continue
		# The piece's box in its own yaw frame (a rotated wall is still a box to lanes along it).
		# A body tilted off the vertical keeps the world frame (yaw 0): its box is read as it stands.
		var yaw := co.global_transform.basis.get_euler().y if co.global_transform.basis.y.normalized().y > 0.99 else 0.0
		var unyaw := Basis(Vector3.UP, -yaw)
		var box := AABB()
		var any := false
		for owner_id in co.get_shape_owners():
			if co.is_shape_owner_disabled(owner_id):
				continue
			var xf: Transform3D = co.global_transform * co.shape_owner_get_transform(owner_id)
			for i in co.shape_owner_get_shape_count(owner_id):
				var shape: Shape3D = co.shape_owner_get_shape(owner_id, i)
				var m := shape.get_debug_mesh()
				if m == null:
					continue
				var b: AABB = Transform3D(unyaw, Vector3.ZERO) * xf * m.get_aabb()
				if per_shape:
					if not (shape is ConcavePolygonShape3D or shape is HeightMapShape3D) and maxf(b.size.x, b.size.z) >= LARGE_M and b.size.y >= 0.05:
						out.append({"path": "%s#%d" % [co.get_path(), owner_id], "aabb": b, "yaw": yaw})
					continue
				box = b if not any else box.merge(b)
				any = true
		if per_shape or not any or maxf(box.size.x, box.size.z) < LARGE_M or box.size.y < 0.05:
			continue
		out.append({"path": String(co.get_path()), "aabb": box, "yaw": yaw})
	# Node names carry creation counters (@StaticBody3D@2512), so order by where the piece stands.
	out.sort_custom(func(a, b): return _key(a) < _key(b))
	return out


# Indexes what is drawn under `roots` (mesh boxes by 16 m cell) so a contact can say whether a shown
# mesh covers it. Under a headless display MultiMesh instance transforms read as the identity, so
# `multimesh_trusted` goes false and the report says drawn is a lower bound.
func index_drawn(roots: Array) -> void:
	_meshes.clear()
	multimesh_trusted = DisplayServer.get_name() != "headless"
	for holder in roots:
		for g in holder.find_children("*", "GeometryInstance3D", true, false):
			if not g.is_visible_in_tree() or g.visibility_range_begin > 0.0:
				continue
			if g is MultiMeshInstance3D:
				if not multimesh_trusted:
					continue
				var mm: MultiMesh = g.multimesh
				if mm == null or mm.mesh == null:
					continue
				var local := mm.mesh.get_aabb()
				for i in mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count:
					_add_box(g.global_transform * mm.get_instance_transform(i) * local)
			else:
				_add_box(g.global_transform * g.get_aabb())


func _add_box(box: AABB) -> void:
	if box.size.length() > 4000.0:
		return
	for x in range(floori(box.position.x / CELL), floori(box.end.x / CELL) + 1):
		for z in range(floori(box.position.z / CELL), floori(box.end.z / CELL) + 1):
			var key := Vector2i(x, z)
			if not _meshes.has(key):
				_meshes[key] = []
			_meshes[key].append(box)


func shown(p: Vector3) -> bool:
	var key := Vector2i(floori(p.x / CELL), floori(p.z / CELL))
	for box: AABB in _meshes.get(key, []):
		if box.grow(COVER_PAD).has_point(p):
			return true
	return false


static func _key(piece: Dictionary) -> String:
	var c := center(piece)
	return "%09.2f %09.2f %09.2f %09.2f %s" % [c.x + 5000.0, c.z + 5000.0, c.y + 5000.0, piece.aabb.size.x, piece.path]


# The piece's centre in world space.
static func center(piece: Dictionary) -> Vector3:
	return Basis(Vector3.UP, piece.yaw) * piece.aabb.get_center()


# The lanes for one piece: [{kind, from (ground xz), dir (unit xz), length_m}].
func lanes(piece: Dictionary) -> Array:
	var box: AABB = piece.aabb
	var wc := center(piece)
	var c := Vector2(wc.x, wc.z)
	var half := Vector2(box.size.x, box.size.z) * 0.5
	var out := []
	# Lane axes follow the piece's yaw: Basis(UP, yaw) sends local x to (cos, -sin) in (x, z).
	var yaw: float = piece.yaw
	var axes := [Vector2(cos(yaw), -sin(yaw)), Vector2(sin(yaw), cos(yaw))]
	if box.size.y <= RIDE_H:
		for a in axes:
			var perp := Vector2(-a.y, a.x)
			var along_x: bool = a == axes[0]
			var half_along: float = half.x if along_x else half.y
			var half_perp: float = half.y if along_x else half.x
			for sgn in [1.0, -1.0]:
				for k in LANES:
					var lateral := (float(k) - float(LANES - 1) * 0.5) * half_perp * 0.6
					var dir: Vector2 = a * sgn
					out.append({"kind": "ride", "from": c + perp * lateral - dir * (half_along + RUN_M),
						"dir": dir, "length_m": half_along * 2.0 + RUN_M * 2.0})
	else:
		var s := sin(deg_to_rad(GRAZE_DEG))
		var co := cos(deg_to_rad(GRAZE_DEG))
		for a in axes:
			var perp := Vector2(-a.y, a.x)
			var along_x: bool = a == axes[0]
			var half_along: float = half.x if along_x else half.y
			var half_perp: float = half.y if along_x else half.x
			for face in [1.0, -1.0]:
				for sgn in [1.0, -1.0]:
					var into: Vector2 = -perp * face
					var dir: Vector2 = (a * sgn * co + into * s).normalized()
					# Start RUN_M short of the near end, offset so the ball (radius and all) meets the face 2 m past that end.
					var start: Vector2 = c + perp * face * (half_perp + Tuning.RADIUS + (RUN_M + 2.0) * tan(deg_to_rad(GRAZE_DEG))) \
						- a * sgn * (half_along + RUN_M)
					out.append({"kind": "graze", "from": start, "dir": dir, "length_m": half_along * 2.0 + RUN_M * 2.0})
	return out


# Rolls one lane. Returns {} for no snag, or the snag row. `ignore_path` is not needed: the ball is
# dropped on the first collider surface under the start.
func roll(piece: Dictionary, lane: Dictionary) -> Dictionary:
	var player = _game.player
	var box: AABB = piece.aabb
	var from: Vector2 = lane.from
	var dir2: Vector2 = lane.dir
	var dir := Vector3(dir2.x, 0.0, dir2.y)
	var top = _top(Vector3(from.x, 0.0, from.y), box.end.y + 4.0)
	if top == null:
		return {"skipped": "no_floor"}
	var cruise: float = player.tuning.f("cruise")
	_source.hold = {}
	player.reset_to(top + Vector3.UP * (Tuning.RADIUS + 0.3), dir * cruise)
	await _tree.physics_frame
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	var n := maxi(1, roundi(window_s / dt))
	var speeds := []
	var contacts := []
	var limit := minf(float(lane.length_m) / cruise * 1.6 + 1.0, MAX_LANE_S)
	var t := 0.0
	var stalled := 0.0
	var last: Vector3 = player.ball_position()
	var cos_max := cos(deg_to_rad(max_angle_deg))
	while t < limit:
		_game.camera.yaw = atan2(-dir.x, -dir.z)
		_source.hold = {"move": Vector2(0.0, 1.0)}
		player.grant_immunity(1.0)
		await _tree.physics_frame
		t += dt
		var ball: Vector3 = player.ball_position()
		if ball.distance_to(last) > 8.0:
			return {}
		last = ball
		var hit := _facing_contact(ball, dir, cos_max)
		var speed: float = player.planar_velocity().length()
		speeds.append(speed)
		contacts.append(hit)
		if speeds.size() > n + 1:
			speeds.pop_front()
			contacts.pop_front()
		if speeds.size() <= n or t < 0.3:
			continue
		var before: float = speeds[0]
		var seen := {}
		for c in contacts:
			if not c.is_empty():
				seen = c
				break
		if before >= min_before * cruise and speed <= before * (1.0 - loss) and not seen.is_empty():
			seen["piece"] = piece.path
			seen["class"] = classify(String(piece.path), String(seen["hit"]), bool(seen["terrain"]))
			seen["lane"] = lane.kind
			seen["dir"] = [snappedf(dir.x, 0.01), snappedf(dir.z, 0.01)]
			seen["speed_before"] = snappedf(before, 0.1)
			seen["speed_after"] = snappedf(speed, 0.1)
			seen["t"] = snappedf(t, 0.01)
			return seen
		# The lane is over once the ball has crossed its length, or has sat nearly still (a ball stuck
		# against something that did not face its line is not a snag and would run to the time cap).
		if (Vector2(ball.x, ball.z) - from).dot(dir2) >= float(lane.length_m):
			return {}
		stalled = stalled + dt if speed < 0.1 * cruise else 0.0
		if stalled > 0.6:
			return {}
	return {}


# A contact ahead of the ball whose normal faces within the angle of the line of travel, else {}.
func _facing_contact(ball: Vector3, dir: Vector3, cos_max: float) -> Dictionary:
	var body: RigidBody3D = _game.player.body()
	var state: PhysicsDirectBodyState3D = PhysicsServer3D.body_get_direct_state(body.get_rid())
	if state == null:
		return {}
	for i in state.get_contact_count():
		var nrm: Vector3 = state.get_contact_local_normal(i)
		var p: Vector3 = state.get_contact_local_position(i)
		var flat := Vector3(nrm.x, 0.0, nrm.z)
		if (p - ball).dot(dir) <= 0.0 or flat.length() < MIN_FLAT or absf(flat.normalized().dot(dir)) < cos_max:
			continue
		var other = state.get_contact_collider_object(i)
		var path := ""
		var terrain := false
		if other is Node:
			path = String((other as Node).get_path())
		# A body of several shapes names the shape hit; a trimesh among them is the map's own floor.
		if other is CollisionObject3D and (other as CollisionObject3D).get_shape_owners().size() > 1:
			var co := other as CollisionObject3D
			var owner_id := co.shape_find_owner(state.get_contact_collider_shape(i))
			path += "#%d" % owner_id
			var hit_shape := co.shape_owner_get_shape(owner_id, 0)
			terrain = hit_shape is ConcavePolygonShape3D or hit_shape is HeightMapShape3D
		contacts_seen += 1
		return {"at": _v(p), "n": _v(nrm), "hit": path, "terrain": terrain, "visible": shown(p)}
	return {}


func _top(at: Vector3, from_y: float):
	var space: PhysicsDirectSpaceState3D = _game.player.body().get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(at.x, from_y, at.z), Vector3(at.x, from_y - 400.0, at.z))
	q.exclude = [_game.player.body().get_rid()]
	var hit: Dictionary = space.intersect_ray(q)
	return null if hit.is_empty() else hit.position


static func _v(v: Vector3) -> Array:
	return [snappedf(v.x, 0.01), snappedf(v.y, 0.01), snappedf(v.z, 0.01)]


# --- Class, places, bounds, control lanes --------------------------------------------------------

const HOLDERS := ["ParkRows", "Contraptions", "Activities", "Tiles"]
const PLACE_M := 2.0
const CONTROL_STEP := 100.0
const CONTROL_LEN := 60.0
const CONTROL_PAD := 8.0
const CONTROL_MAX := 48


# What a snag hit, against the piece the lane was aimed at: "piece" (that piece's own collider, or one
# of its parts), "ground" (terrain tiles or the map's own floor body) or "other" (any other collider).
static func classify(piece_path: String, hit_path: String, terrain := false) -> String:
	if hit_path == piece_path:
		return "piece"
	var pb := piece_path.get_slice("#", 0)
	var hb := hit_path.get_slice("#", 0)
	if hb == pb:
		if "#" not in piece_path:
			return "piece"
		return "ground" if terrain else "other"
	if terrain:
		return "ground"
	if hb.begins_with(pb + "/") or pb.begins_with(hb + "/"):
		return "piece"
	var pp := pb.rsplit("/", true, 1)
	var hp := hb.rsplit("/", true, 1)
	if pp.size() == 2 and hp.size() == 2 and pp[0] == hp[0] and pp[0].get_file() not in HOLDERS and pp[0].count("/") > 3:
		return "piece"
	if "/Tiles/" in hb or hb.ends_with("/Ground") or hb.ends_with("/SlagBowl/Bowl"):
		return "ground"
	return "other"


static func loss_of(row: Dictionary) -> float:
	var before := float(row.get("speed_before", 0.0))
	return snappedf(1.0 - float(row.get("speed_after", 0.0)) / before, 0.01) if before > 0.0 else 0.0


# Snags on the same collider (and class) within PLACE_M of each other are one place. Returns rows
# {at, hit, class, count, pieces, worst_loss, speed_before, speed_after, drawn}, worst loss first.
static func dedupe(snags: Array) -> Array:
	var groups := {}
	for s in snags:
		var key := "%s|%s" % [s.get("hit", ""), s.get("class", "")]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(s)
	var out := []
	var keys := groups.keys()
	keys.sort()
	for key in keys:
		var members: Array = groups[key]
		var parent := []
		for i in members.size():
			parent.append(i)
		for i in members.size():
			for j in range(i + 1, members.size()):
				if _at(members[i]).distance_to(_at(members[j])) <= PLACE_M:
					var a: int = _root(parent, i)
					var b: int = _root(parent, j)
					if a != b:
						parent[maxi(a, b)] = mini(a, b)
		var clusters := {}
		for i in members.size():
			var r: int = _root(parent, i)
			if not clusters.has(r):
				clusters[r] = []
			clusters[r].append(members[i])
		for r in clusters:
			var list: Array = clusters[r]
			var worst: Dictionary = list[0]
			var drawn := false
			var from_pieces := {}
			for m in list:
				if loss_of(m) > loss_of(worst):
					worst = m
				drawn = drawn or bool(m.get("visible", false))
				from_pieces[m.get("piece", "")] = true
			out.append({"at": worst.at, "hit": worst.hit, "class": worst["class"], "count": list.size(),
				"pieces": from_pieces.size(), "worst_loss": loss_of(worst), "speed_before": worst.speed_before,
				"speed_after": worst.speed_after, "drawn": drawn})
	out.sort_custom(func(a, b): return _place_key(a) < _place_key(b))
	return out


static func _place_key(p: Dictionary) -> String:
	return "%06.2f %s %09.2f %09.2f %09.2f" % [1.0 - float(p.worst_loss), p.hit, p.at[0] + 5000.0, p.at[1] + 5000.0, p.at[2] + 5000.0]


static func _at(s: Dictionary) -> Vector3:
	return Vector3(s.at[0], s.at[1], s.at[2])


static func _root(parent: Array, i: int) -> int:
	while parent[i] != i:
		i = parent[i]
	return i


# The box of the stage's ground tiles (world), or an empty AABB when the map has none.
func ground_bounds(root: Node) -> AABB:
	var box := AABB()
	var any := false
	for n in root.find_children("*", "CollisionObject3D", true, false):
		var co: CollisionObject3D = n
		if co.get_parent() == null or String(co.get_parent().name) != "Tiles":
			continue
		for owner_id in co.get_shape_owners():
			var xf: Transform3D = co.global_transform * co.shape_owner_get_transform(owner_id)
			for i in co.shape_owner_get_shape_count(owner_id):
				var m := co.shape_owner_get_shape(owner_id, i).get_debug_mesh()
				if m == null:
					continue
				var b: AABB = xf * m.get_aabb()
				box = b if not any else box.merge(b)
				any = true
	return box


# True when the piece stands over the stage's ground (plan, with a margin) and not far above or
# below it, so a scene parked far off the map (the bay's barge) is not a piece of this stage.
static func inside(piece: Dictionary, bounds: AABB) -> bool:
	var c := center(piece)
	return c.x >= bounds.position.x - CONTROL_PAD and c.x <= bounds.end.x + CONTROL_PAD \
		and c.z >= bounds.position.z - CONTROL_PAD and c.z <= bounds.end.z + CONTROL_PAD \
		and c.y >= bounds.position.y - 40.0 and c.y <= bounds.end.y + 120.0


# Control lanes over open ground: a grid of straight runs along x and z, kept when no piece stands
# within CONTROL_PAD of the run and the ground tiles lie under both ends. They cross tile seams at
# cruise the way a piece lane's approach does. Same lane shape as a piece's, kind "control".
func control_lanes(all: Array, bounds: AABB) -> Array:
	var out := []
	if bounds.size.x <= 0.0:
		return out
	var x := bounds.position.x + CONTROL_STEP * 0.5
	while x < bounds.end.x:
		var z := bounds.position.z + CONTROL_STEP * 0.5
		while z < bounds.end.z:
			for d in [Vector2(1, 0), Vector2(0, 1)]:
				var a := Vector2(x, z)
				var b: Vector2 = a + d * CONTROL_LEN
				if _clear(all, a, b) and _on_tiles(a) and _on_tiles(b):
					out.append({"kind": "control", "from": a, "dir": d, "length_m": CONTROL_LEN})
			z += CONTROL_STEP
		x += CONTROL_STEP
	if out.size() > CONTROL_MAX:
		var keep := []
		for i in CONTROL_MAX:
			keep.append(out[i * out.size() / CONTROL_MAX])
		out = keep
	return out


func _clear(all: Array, a: Vector2, b: Vector2) -> bool:
	for p in all:
		var c := center(p)
		var r := Vector2(p.aabb.size.x, p.aabb.size.z).length() * 0.5 + CONTROL_PAD
		var seg := b - a
		var u := clampf((Vector2(c.x, c.z) - a).dot(seg) / seg.length_squared(), 0.0, 1.0)
		if (a + seg * u).distance_to(Vector2(c.x, c.z)) < r:
			return false
	return true


func _on_tiles(p: Vector2) -> bool:
	var space: PhysicsDirectSpaceState3D = _game.player.body().get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, 600.0, p.y), Vector3(p.x, -400.0, p.y))
	q.exclude = [_game.player.body().get_rid()]
	var hit: Dictionary = space.intersect_ray(q)
	return not hit.is_empty() and hit.collider is Node and "/Tiles/" in String((hit.collider as Node).get_path())
