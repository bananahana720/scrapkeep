extends SceneTree
# smoke: solo timeout=300s (boots the game into the dam and the flume and reads every plate against the colliders)

# Lore plate seats (W45 P8): every plate in the Dam and the Flume sits on the surface a ball rolling there stands on.
#   Seat     around the plate's bottom rim (RIM points) and an inner ring, no point floats more than FLOAT_M above
#            the permanent face under it (a ground tile or a placed park row's deck or prop: surface_y), and none is
#            buried deeper than the plate is thick. The surface is read here with its own rays and its own rule, not
#            through terrain.gd top_surface, which the plate seats by.
#   Clear    no world collider stands on the plate's footprint within a ball's height over its face, and no drawn
#            mesh crosses the column over its face samples, so it can be seen and rolled across.
#   Overlay  no park event's overlay sheet stands over a plate once it lands (a plate is seated once).
#   Spot     a plate moved off its row's spot (secrets.gd PLATE_NUDGES) stays inside the row's footprint and within
#            NUDGE_MAX_M of it.
#   Trigger  a ball resting on the plate files it, at its centre and on either side of it along the slope; a ball on
#            the ground under a deck plate, one touching that deck's underside, and one 1.5 m under any face do not.
#   Look     the unread rim and face stand apart from the grounds a plate lies on and from each other; read, the face
#            sinks flush, stops glowing and changes colour. No word, no collider.
#   Planted  the old seat (a level disc at the bare ground under the row's spot) fails the seat on the 23 degree
#            incline, the deck read under the trestle and the cover read under the gate flag's plinth; and a moving
#            body, a breakable one and a contraption's, each planted over every plate, never become its surface.
# Output: one `SEAT <park> <fragment> float=<m> bury=<m> ...` line per plate, plus PASS or FAIL rows from t.gd.

const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Secrets := preload("res://src/core/secrets.gd")
const ParkDefs := preload("res://src/core/park_defs.gd")
const ParkStamps := preload("res://src/world/park/park_stamps.gd")
const ParkTerrain := preload("res://src/world/park/park_terrain.gd")
const Activities := preload("res://src/world/activities.gd")
const Palette := preload("res://src/core/palette.gd")
const DefenceBars := preload("res://src/core/defence_bars.gd")
const Tuning := preload("res://src/movement/tuning.gd")

const MAPS := ["park_dam", "park_flume"]
const FLOAT_M := 0.04
const RIM := 16
const BALL_H := Tuning.RADIUS * 2.0
const NUDGE_MAX_M := 12.0
const REACH_M := 40.0
const BELOW_M := 0.05
const COVER_FROM_M := 0.03
const FLOOR_SHARE := 0.75
# The colour distance an ink keeps from the grounds and from its pair (LEGIBILITY's row test uses 35 for the live
# colour); the read face only has to differ, as its sinking and its dark glow carry the change too.
const APART := 35.0
const READ_APART := 15.0
const PLANTED := {"incline": "dam_era_incline_tally", "deck": "dam_era_trestle_tag", "cover": "dam_era_gate_flags"}

var t := T.new("w45_plate_seat_test")
var faces := {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_look()
	await _live()
	quit(t.verdict())


func _live() -> void:
	var game = Game.new()
	game.test_mode = true
	game.table = "park"
	game.ground_behind_menu = false
	root.add_child(game)
	while game.flow == null:
		await process_frame
	game.run.run_seed_override = 1
	game.ctx.calm = true
	game.player.source = Intent.Scripted.new()
	game.flow.press_start()
	game.flow.choose_class(0)
	for map_id in MAPS:
		var stage := 0
		for row in ParkDefs.DEFS:
			if String(row.get("map", "")) == map_id:
				stage = int(row["stage"])
		if stage != 1:
			game.flow.enter_stage(stage, Vector3.ZERO, false)
		var terrain = game.ctx.terrain
		var waited := 0
		while waited < 3000 and not (terrain.rows_ready(stage) and terrain.is_ready(stage) and game.flow.state_name() == "stage"):
			await process_frame
			waited += 1
		for i in 10:
			await physics_frame
		var acts = game.world.activities
		# Seated by now through the game's own ticks; one more watch from far off seats any that waited.
		for p in acts.plates:
			acts._watch_plate(p, Vector3(1.0e5, 0.0, 1.0e5))
		_plates(map_id, game, stage)
		_planted(map_id, game, stage)
		await _planted_colliders(map_id, game, stage)
	game.queue_free()
	await process_frame


func _plates(map_id: String, game, stage: int) -> void:
	var acts = game.world.activities
	var terrain = game.ctx.terrain
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	var park: Dictionary = terrain.map().park
	var specs := Secrets.plate_sites(park)
	var visuals := visuals_under([terrain.geometry_root(stage), acts])
	t.eq("%s builds a plate at every listed fragment" % map_id, acts.plates.size(), specs.size())
	var rows := {}
	for row: Dictionary in park.get("park_rows", []):
		rows[String(row["id"])] = row
	for i in mini(specs.size(), acts.plates.size()):
		var p = acts.plates[i]
		var fragment := String(specs[i]["fragment"])
		t.check("%s %s is seated and shown" % [map_id, fragment], p.seated and p.visible)
		var fit := seat_fit(space, terrain, p.global_transform)
		var blocked := blockers(space, p.global_transform)
		var covered := []
		var through := []
		var samples := 1 + RIM * 2
		var over: Dictionary = covers(visuals, p, faces, Activities.PLATE_H, Activities.PLATE_H + BALL_H)
		for mesh in over:
			covered.append(mesh)
		# A floor drawn a few centimetres over its collider crosses the plate's body at nearly every sample, under
		# the rim's top; a stone that pokes through crosses it at a few.
		var body: Dictionary = covers(visuals, p, faces, COVER_FROM_M, Activities.PLATE_H)
		for mesh in body:
			if body[mesh] < samples * FLOOR_SHARE:
				through.append("%s (%d of %d)" % [mesh, body[mesh], samples])
		var tilt := rad_to_deg(p.global_basis.y.angle_to(Vector3.UP))
		print("SEAT %s %s float=%.3f bury=%.3f tilt=%.1f y=%.2f ground=%.2f blockers=%d covered=%d through=%d" % [map_id, fragment,
			fit.float, fit.bury, tilt, p.global_position.y, terrain.height(p.global_position.x, p.global_position.z), blocked.size(), covered.size(), through.size()])
		t.check("%s %s floats no more than %.2f m anywhere round its rim" % [map_id, fragment, FLOAT_M], fit.float <= FLOAT_M, "%.3f" % fit.float)
		t.check("%s %s is buried no deeper than its thickness" % [map_id, fragment], fit.bury <= Activities.PLATE_H, "%.3f" % fit.bury)
		t.check("%s %s has no collider on its footprint within a ball's height" % [map_id, fragment], blocked.is_empty(), ", ".join(blocked))
		t.check("%s %s has no mesh over it within a ball's height" % [map_id, fragment], covered.is_empty(), ", ".join(covered))
		t.check("%s %s has no stone poking through it" % [map_id, fragment], through.is_empty(), ", ".join(through))
		t.eq("%s %s carries no word and no collider" % [map_id, fragment],
			p.find_children("*", "Label3D", true, false).size() + p.find_children("*", "CollisionObject3D", true, false).size(), 0)
		_spot(map_id, fragment, specs[i], rows)
		_overlays(map_id, fragment, terrain, p)
		_trigger(map_id, fragment, game, p)


# A park event's overlay sheet (a ramp or slide that lands mid-stage) never stands over a plate's face: the plate is
# seated once, so a sheet landing over it later would bury it.
func _overlays(map_id: String, fragment: String, terrain, p) -> void:
	var m = terrain.map()
	if not "profiles" in m:
		return
	var over := []
	var ground: float = terrain.floor_height(p.global_position.x, p.global_position.z)
	var top: float = (p.global_transform * (Vector3.UP * Activities.PLATE_H)).y
	for id in m.profiles:
		for k in RIM + 1:
			var a := TAU * float(k) / float(RIM)
			var r := 0.0 if k == RIM else Activities.PLATE_RADIUS * 1.08
			var x: float = p.global_position.x + cos(a) * r
			var z: float = p.global_position.z + sin(a) * r
			if m.overlay_height(id, x, z, ground) > top:
				over.append(id)
				break
	t.check("%s %s has no event overlay landing over it" % [map_id, fragment], over.is_empty(), ", ".join(over))


# A nudged plate stays on its own row: inside its footprint (the landmark's plate on its dock, by distance alone)
# and a short way from its spot.
func _spot(map_id: String, fragment: String, spec: Dictionary, rows: Dictionary) -> void:
	if not Secrets.PLATE_NUDGES.has(fragment):
		return
	var nudge: Array = Secrets.PLATE_NUDGES[fragment]
	var moved := Vector2(float(nudge[0]), float(nudge[1])).length()
	t.check("%s %s nudge moves it at most %.0f m" % [map_id, fragment, NUDGE_MAX_M], moved <= NUDGE_MAX_M, "%.1f" % moved)
	var row: Dictionary = rows.get(String(spec["row"]), {})
	if row.is_empty():
		return
	var at: Vector2 = spec["at"]
	t.check("%s %s nudge stays inside its row" % [map_id, fragment], ParkStamps.inside(ParkStamps.frame(row), at.x, at.y), str(at))


# A ball resting on the plate (its centre a radius over the face, along the plate's tilt) files it at the centre
# and a metre either side down the slope; one on the ground under a raised plate does not.
func _trigger(map_id: String, fragment: String, game, p) -> void:
	var acts = game.world.activities
	var up: Vector3 = p.global_basis.y.normalized()
	var down_slope := (Vector3.DOWN - up * Vector3.DOWN.dot(up))
	down_slope = down_slope.normalized() if down_slope.length() > 0.001 else Vector3.RIGHT
	var fired := 0
	for along in [-1.0, 0.0, 1.0]:
		p.read = false
		acts._show_plate(p)
		acts._watch_plate(p, p.global_position + up * (Activities.PLATE_H + Tuning.RADIUS) + down_slope * along)
		fired += int(p.read)
	t.eq("%s %s fires for a ball rolling over it" % [map_id, fragment], fired, 3)
	var ground: float = game.ctx.terrain.floor_height(p.global_position.x, p.global_position.z)
	if p.global_position.y - ground > Activities.LorePlate.HEIGHT_M + BALL_H:
		p.read = false
		acts._watch_plate(p, Vector3(p.global_position.x, ground + Tuning.RADIUS, p.global_position.z))
		t.check("%s %s does not fire for a ball on the ground under it" % [map_id, fragment], not p.read)
		# A ball rolling under the deck, touching its underside, and one a metre and a half under the face (a deck
		# that thin): neither is on the plate.
		var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
		var up_ray := PhysicsRayQueryParameters3D.create(Vector3(p.global_position.x, ground + 0.1, p.global_position.z), p.global_position, 1)
		var underside := space.intersect_ray(up_ray)
		if not underside.is_empty():
			var under: Vector3 = underside.position + Vector3.DOWN * Tuning.RADIUS
			p.read = false
			acts._watch_plate(p, under)
			print("UNDER %s %s underside=%.2f rise=%.2f" % [map_id, fragment, underside.position.y, (under - p.global_position).dot(up)])
			t.check("%s %s does not fire for a ball under its deck" % [map_id, fragment], not p.read)
		p.read = false
		acts._watch_plate(p, p.global_position - up * 1.5)
		t.check("%s %s does not fire for a ball 1.5 m under its face" % [map_id, fragment], not p.read)
	p.read = true
	acts._show_plate(p)


# The old seat, rebuilt as a level transform at the bare ground under the row's spot: the test must fail it.
func _planted(map_id: String, game, stage: int) -> void:
	var terrain = game.ctx.terrain
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	var park: Dictionary = terrain.map().park
	var rows := {}
	for row: Dictionary in park.get("park_rows", []):
		rows[String(row.get("fragment", ""))] = row
	var acts = game.world.activities
	for kind in PLANTED:
		var row: Dictionary = rows.get(PLANTED[kind], {})
		if row.is_empty():
			continue
		var spot := Vector2(float(row["at"][0]), float(row["at"][1]))
		var level := Transform3D(Basis.IDENTITY, Vector3(spot.x, terrain.floor_height(spot.x, spot.y), spot.y))
		var fit := seat_fit(space, terrain, level)
		print("PLANTED %s %s float=%.3f bury=%.3f" % [map_id, PLANTED[kind], fit.float, fit.bury])
		match kind:
			"incline":
				t.check("planted: a level plate on the incline floats past the limit", fit.float > FLOAT_M, "%.3f" % fit.float)
			"deck":
				t.check("planted: a plate on the ground under the trestle is buried under the deck", fit.bury > Activities.PLATE_H, "%.3f" % fit.bury)
			"cover":
				var probe := Node3D.new()
				acts.add_child(probe)
				probe.global_transform = level
				var covered := covers(visuals_under([terrain.geometry_root(stage), acts]), probe, faces, Activities.PLATE_H, Activities.PLATE_H + BALL_H)
				t.check("planted: a plate under the gate flag's plinth is covered", not covered.is_empty(), str(covered))
				probe.free()


# Bodies that are not ground, planted on the world layer a metre and a half over each plate in turn, where the
# game hangs their kind: a moving body under the park rows (the isle's tip is one), a static body under the game
# root (a destructible, a Dispatcher's mast, an ice slab, a cache or a device), and a static body in a node of its
# own under the stage root (a contraption's door or lift). top_surface steps through each and answers the face
# under it, as it does with none.
func _planted_colliders(map_id: String, game, stage: int) -> void:
	var terrain = game.ctx.terrain
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	var specs := Secrets.plate_sites(terrain.map().park)
	var stage_root: Node3D = terrain.geometry_root(stage)
	var door_holder := Node3D.new()
	stage_root.add_child(door_holder)
	var kinds := {"moving": [terrain.park_rows(stage), "AnimatableBody3D"], "breakable": [game, "StaticBody3D"], "door": [door_holder, "StaticBody3D"]}
	var missed := {}
	var vacuous := {}
	for kind in kinds:
		missed[kind] = []
		vacuous[kind] = []
	for i in mini(specs.size(), game.world.activities.plates.size()):
		var at: Vector2 = specs[i]["at"]
		var fragment := String(specs[i]["fragment"])
		var bare: Dictionary = terrain.top_surface(at.x, at.y)
		if bare.is_empty():
			missed["moving"].append(fragment + " (no answer)")
			continue
		for kind in kinds:
			var body: CollisionObject3D = AnimatableBody3D.new() if kinds[kind][1] == "AnimatableBody3D" else StaticBody3D.new()
			body.collision_layer = 1
			body.collision_mask = 0
			if body is AnimatableBody3D:
				(body as AnimatableBody3D).sync_to_physics = false
			if kind == "breakable":
				body.set_meta("destructible_id", "planted")
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(4.0, 0.5, 4.0)
			shape.shape = box
			body.add_child(shape)
			(kinds[kind][0] as Node).add_child(body)
			body.global_position = bare.point + Vector3.UP * 1.5
			for f in 2:
				await physics_frame
			var ray := PhysicsRayQueryParameters3D.create(bare.point + Vector3.UP * 30.0, bare.point + Vector3.DOWN * 0.5, 1)
			var first := {}
			var hit_body := false
			var exclude := []
			for k in 8:
				ray.exclude = exclude
				first = space.intersect_ray(ray)
				if first.is_empty():
					break
				if first.collider == body:
					hit_body = true
					break
				exclude.append(first.rid)
			if not hit_body:
				vacuous[kind].append(fragment)
			var with: Dictionary = terrain.top_surface(at.x, at.y)
			if with.is_empty() or absf(with.point.y - bare.point.y) > 0.001:
				missed[kind].append("%s %.2f -> %s" % [fragment, bare.point.y, "{}" if with.is_empty() else "%.2f" % with.point.y])
			body.free()
	door_holder.free()
	for kind in kinds:
		print("PLANTED_BODY %s %s missed=%d not_in_ray=%d" % [map_id, kind, missed[kind].size(), vacuous[kind].size()])
		t.check("planted: %s top_surface steps through a %s body over every plate" % [map_id, kind], missed[kind].is_empty(), "; ".join(missed[kind]))
		t.check("planted: %s the %s body stands in the ray's path over every plate" % [map_id, kind], vacuous[kind].is_empty(), ", ".join(vacuous[kind]))


# ---- Measures ------------------------------------------------------------------------------------------------

# The plate's worst float and bury: its bottom face's rim and an inner ring and centre, each against the highest
# static world face under it.
static func seat_fit(space: PhysicsDirectSpaceState3D, terrain, frame: Transform3D) -> Dictionary:
	var worst_float := -INF
	var worst_bury := -INF
	var r := Activities.PLATE_RADIUS * 1.08
	var local: Array[Vector3] = [Vector3.ZERO]
	for k in RIM:
		var a := TAU * (float(k) + 0.5) / float(RIM)
		local.append(Vector3(cos(a) * r, 0.0, sin(a) * r))
		local.append(Vector3(cos(a) * r * 0.5, 0.0, sin(a) * r * 0.5))
	for l in local:
		var at: Vector3 = frame * l
		var surface := surface_y(space, terrain, at.x, at.z)
		worst_float = maxf(worst_float, at.y - surface)
		worst_bury = maxf(worst_bury, surface - at.y)
	return {"float": worst_float, "bury": worst_bury}


# The permanent face under (x, z), in this test's own terms: the top hit whose body is a bare StaticBody3D (by class
# name, so no moving or scripted subclass) filed under the stage's geometry root at Ground/ (the tiles) or ParkRows/
# (the placed decks and props), with every shape live and no destructible id; else height(), which carries landed
# overlays and cave roofs. A face more than BELOW_M under height() is not the ground's.
static func surface_y(space: PhysicsDirectSpaceState3D, terrain, x: float, z: float) -> float:
	var ground: float = terrain.height(x, z)
	var root: Node = terrain.geometry_root(terrain.stage)
	var query := PhysicsRayQueryParameters3D.create(Vector3(x, ground + REACH_M, z), Vector3(x, ground - BELOW_M, z), 1)
	for i in 16:
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			break
		if permanent(hit.collider, root):
			return hit.position.y
		query.exclude = query.exclude + [hit.rid]
	return ground


static func permanent(body: Object, root: Node) -> bool:
	if body == null or body.get_class() != "StaticBody3D" or (body as Node).has_meta("destructible_id") or not root.is_ancestor_of(body):
		return false
	var path := str(root.get_path_to(body))
	if not (path.begins_with("Ground/") or path.begins_with("ParkRows/")):
		return false
	for shape in (body as Node).find_children("*", "CollisionShape3D", true, false):
		if (shape as CollisionShape3D).disabled:
			return false
	return true


# Static world colliders in the column a ball's height tall over the plate's face, tilted with it.
static func blockers(space: PhysicsDirectSpaceState3D, frame: Transform3D) -> Array:
	var shape := CylinderShape3D.new()
	shape.radius = Activities.PLATE_RADIUS * 1.08
	shape.height = BALL_H
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1
	query.transform = frame * Transform3D(Basis.IDENTITY, Vector3.UP * (Activities.PLATE_H + 0.05 + BALL_H * 0.5))
	var out := []
	for hit in space.intersect_shape(query, 16):
		if hit.collider is StaticBody3D:
			out.append(str(hit.collider.get_path()).get_slice("/", 4) + "/" + String(hit.collider.get_parent().name))
	return out


# Every shown mesh under the roots, with its global AABB, for covers().
static func visuals_under(roots: Array) -> Array:
	var out := []
	for r in roots:
		for node in (r as Node).find_children("*", "GeometryInstance3D", true, false):
			if not (node as Node3D).is_visible_in_tree() or node is Label3D:
				continue
			if node is MeshInstance3D and node.mesh != null:
				out.append({"node": node, "box": node.global_transform * node.get_aabb()})
			elif node is MultiMeshInstance3D and node.multimesh != null and node.multimesh.mesh != null:
				out.append({"node": node, "box": node.global_transform * node.get_aabb()})
	return out


# The meshes that cross the plate's column from `from` to `to` metres over its base, along its tilt, each with the
# number of samples (its centre, an inner ring and its whole rim) it crosses at; the plate's own are left out.
static func covers(visuals: Array, p: Node3D, cache: Dictionary, from: float, to: float) -> Dictionary:
	var up: Vector3 = p.global_basis.y.normalized()
	var starts: Array[Vector3] = [p.global_transform * (Vector3.UP * from)]
	for k in RIM:
		var a := TAU * float(k) / float(RIM)
		for r in [Activities.PLATE_RADIUS * 0.5, Activities.PLATE_RADIUS * 1.08]:
			starts.append(p.global_transform * Vector3(cos(a) * r, from, sin(a) * r))
	var reach := to - from
	var column := AABB(starts[0], Vector3.ZERO)
	for s in starts:
		column = column.expand(s).expand(s + up * reach)
	var out := {}
	for v in visuals:
		var node: GeometryInstance3D = v.node
		if p.is_ancestor_of(node) or not (v.box as AABB).intersects(column):
			continue
		if node is MeshInstance3D:
			var n := _crossed(_mesh_faces(node.mesh, cache), node.global_transform, starts, up * reach)
			if n > 0:
				out[String(node.get_parent().name) + "/" + String(node.name)] = n
		else:
			var mm: MultiMesh = node.multimesh
			var tris := _mesh_faces(mm.mesh, cache)
			var box := mm.mesh.get_aabb()
			for k in mm.instance_count:
				var xf: Transform3D = node.global_transform * mm.get_instance_transform(k)
				if not (xf * box).intersects(column):
					continue
				var n := _crossed(tris, xf, starts, up * reach)
				if n > 0:
					out[String(node.name) + "#%d" % k] = n
	return out


static func _mesh_faces(mesh: Mesh, cache: Dictionary) -> PackedVector3Array:
	var key := mesh.get_instance_id()
	if not cache.has(key):
		cache[key] = mesh.get_faces()
	return cache[key]


# How many of the segments (each start to start + span) cross a triangle of the mesh placed at xf.
static func _crossed(faces: PackedVector3Array, xf: Transform3D, starts: Array[Vector3], span: Vector3) -> int:
	var inv := xf.affine_inverse()
	var n := 0
	for s in starts:
		var a: Vector3 = inv * s
		var b: Vector3 = inv * (s + span)
		for i in range(0, faces.size(), 3):
			if Geometry3D.segment_intersects_triangle(a, b, faces[i], faces[i + 1], faces[i + 2]) != null:
				n += 1
				break
	return n


# ---- Look ----------------------------------------------------------------------------------------------------

# The rim reads on pale ground, the face on dark; the read face differs from the unread one.
func _look() -> void:
	var grounds := {"sandstone": Palette.SANDSTONE, "steel": Palette.STEEL, "floor": ParkTerrain.GROUND_FLOOR_MEAN,
		"strata": ParkTerrain.GROUND_STRATA_MEAN, "concrete": ParkTerrain.slot_target(2)}
	for g in grounds:
		var rim := DefenceBars.cie76(Palette.CHARCOAL, grounds[g])
		var face := DefenceBars.cie76(Palette.AMBER, grounds[g])
		print("LOOK %s rim=%.1f face=%.1f" % [g, rim, face])
		t.check("the unread plate stands apart from %s" % g, maxf(rim, face) >= APART, "rim %.1f face %.1f" % [rim, face])
	t.check("the unread face stands apart from its rim", DefenceBars.cie76(Palette.AMBER, Palette.CHARCOAL) >= APART)
	var spent := DefenceBars.cie76(Palette.COPPER, Palette.AMBER)
	print("LOOK read face=%.1f from unread, %.1f from rim" % [spent, DefenceBars.cie76(Palette.COPPER, Palette.CHARCOAL)])
	t.check("the read face differs from the unread face", spent >= READ_APART, "%.1f" % spent)
