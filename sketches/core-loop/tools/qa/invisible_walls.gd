extends SceneTree

# It needs a real renderer (xvfb-run, opengl3): under --headless the dummy RenderingServer keeps no MultiMesh

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ParkDefs := preload("res://src/core/park_defs.gd")
const Tuning := preload("res://src/movement/tuning.gd")

const WORLD_MASK := 1
const DIRS := 16
const TOL := 0.6
const CLIMB := 2.5
const SKY := 400.0
const AIR_LIMIT := 1.0
const AIR_CAP := 8.0

var map_id := ""
var arena := false
var out_path := ""
var md_path := ""
var run_seed := 1
var step := 4.0
var ray_range := 24.0

var game
var space: RID
var vis_space: RID
var vis_bodies: Array[RID] = []
var shape_cache := {}
var player_rid: RID
var excluded: Array[RID] = []
var rows := {}
var drawn: Node
var rect := Rect2()
var stats := {"wall_rays": 0, "wall_hits": 0, "floor_rays": 0, "cells": 0, "fit_cells": 0}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--map="):
			map_id = a.trim_prefix("--map=")
		elif a == "--arena":
			arena = true
		elif a.begins_with("--out="):
			out_path = a.trim_prefix("--out=")
		elif a.begins_with("--md="):
			md_path = a.trim_prefix("--md=")
		elif a.begins_with("--seed="):
			run_seed = int(a.trim_prefix("--seed="))
		elif a.begins_with("--step="):
			step = float(a.trim_prefix("--step="))
		elif a.begins_with("--range="):
			ray_range = float(a.trim_prefix("--range="))
	if out_path == "" or (map_id == "") == (not arena):
		printerr("invisible_walls: pass --map=<park map> or --arena, and --out=<file.json>")
		quit(2)
		return
	if DisplayServer.get_name() == "headless":
		printerr("invisible_walls: needs a display (xvfb-run, opengl3): headless keeps no MultiMesh instance transforms")
		quit(2)
		return
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	seed(run_seed)
	var stage_index := 2
	if not arena:
		stage_index = 0
		for row in ParkDefs.DEFS:
			if String(row.get("map", "")) == map_id:
				stage_index = int(row["stage"])
		if stage_index == 0:
			printerr("invisible_walls: %s is not a park table map" % map_id)
			quit(2)
			return
	game = Game.new()
	game.test_mode = true
	game.table = "park"
	game.ground_behind_menu = false
	root.add_child(game)
	while game.flow == null:
		await process_frame
	game.run.run_seed_override = run_seed
	game.ctx.calm = true
	game.player.source = Intent.Scripted.new()
	game.flow.press_start()
	game.flow.choose_class(0)
	if stage_index != 1:
		game.flow.enter_stage(stage_index, Vector3.ZERO, false)
	var terrain = game.ctx.terrain
	var waited := 0
	while waited < 3000 and not (terrain.rows_ready(stage_index) and terrain.is_ready(stage_index) and game.flow.state_name() == "stage"):
		await process_frame
		waited += 1
	if game.presentation.park_props != null:
		game.presentation.park_props.finish()
	await _frames(30)
	var start: Vector3 = game.player.ball_position()
	var centre := Vector2(start.x, start.z)
	var half := 0.0
	if arena:
		game.flow._finish_stage()
		var bowl: Node3D = null
		waited = 0
		while waited < 1200 and (bowl == null or not bowl.built()):
			await process_frame
			waited += 1
			bowl = _find_named(game, "SlagBowl")
		await _frames(240)
		if bowl == null:
			printerr("invisible_walls: no SlagBowl after stage 2 finished (flow %s)" % game.flow.state_name())
			quit(1)
			return
		start = game.player.ball_position()
		centre = Vector2(bowl.global_position.x, bowl.global_position.z)
		half = 66.0
	print("invisible_walls: %s seed %d built in %d frames, flow %s, ball %s" % [_label(), run_seed, waited, game.flow.state_name(), start])
	var body: RigidBody3D = game.player.body()
	body.freeze = true
	player_rid = body.get_rid()
	excluded.append(player_rid)
	space = game.get_world_3d().space
	await _physics(2)
	var colliders := _census()
	if half == 0.0:
		var pr: Array = JSON.parse_string(FileAccess.get_file_as_string("res://src/world/park/%s.json" % map_id))["play_rect"]
		rect = Rect2(pr[0], pr[1], pr[2], pr[3])
		centre = rect.get_center()
		half = maxf(rect.size.x, rect.size.y) * 0.5
	drawn = _terrain3d(game)
	_build_visual_space()
	await _physics(2)
	var grid := _grid(centre, half)
	_walls(grid)
	_floors(centre, half)
	var reach := _reach(grid, start)
	_write(colliders, reach, centre, half, start)
	for b in vis_bodies:
		PhysicsServer3D.free_rid(b)
	PhysicsServer3D.free_rid(vis_space)
	game.queue_free()
	await _frames(3)
	quit(0)


func _terrain3d(n: Node) -> Node:
	if n.get_class() == "Terrain3D" and n.is_inside_tree() and (n as Node3D).is_visible_in_tree():
		return n
	for c in n.get_children():
		var f := _terrain3d(c)
		if f != null:
			return f
	return null


func _tile(hit: Dictionary) -> bool:
	var obj = hit.get("collider")
	return obj is Node and (obj as Node).get_parent() != null and String((obj as Node).get_parent().name) == "Tiles"


func _drawn_height(p: Vector3) -> float:
	if drawn == null:
		return NAN
	return drawn.data.get_height(p)


func _label() -> String:
	return "arena" if arena else map_id


func _find_named(n: Node, wanted: String) -> Node3D:
	if n.name == wanted and n is Node3D:
		return n
	for c in n.get_children():
		var f := _find_named(c, wanted)
		if f != null:
			return f
	return null


func _walk(n: Node, out: Array) -> void:
	out.append(n)
	for c in n.get_children():
		_walk(c, out)


func _census() -> Array:
	var nodes := []
	_walk(root, nodes)
	var out := []
	for n in nodes:
		if not n is CollisionObject3D or n is Area3D:
			continue
		var co: CollisionObject3D = n
		if co.get_rid() == player_rid or (co.collision_layer & WORLD_MASK) == 0:
			continue
		for owner_id in co.get_shape_owners():
			if co.is_shape_owner_disabled(owner_id):
				continue
			var owner_node = co.shape_owner_get_owner(owner_id)
			var xf: Transform3D = co.global_transform * co.shape_owner_get_transform(owner_id)
			for i in co.shape_owner_get_shape_count(owner_id):
				var shape: Shape3D = co.shape_owner_get_shape(owner_id, i)
				var path := String(root.get_path_to(owner_node if owner_node is Node else co))
				out.append({"path": path, "owner": String(co.name), "body": co.get_rid(), "kind": shape.get_class(),
					"shape": shape, "xform": xf, "aabb": xf * _shape_aabb(shape)})
	return out


func _shape_aabb(shape: Shape3D) -> AABB:
	var m := shape.get_debug_mesh()
	if m != null:
		return m.get_aabb()
	return AABB(Vector3(-1, -1, -1), Vector3(2, 2, 2))


func _visible(gi: GeometryInstance3D) -> bool:
	if not gi.is_visible_in_tree():
		return false
	if gi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
		return false
	return gi.transparency < 0.95


func _trimesh(mesh: Mesh) -> Shape3D:
	var key := mesh.get_rid()
	if not shape_cache.has(key):
		var s: Shape3D = null
		if mesh.get_surface_count() > 0:
			s = mesh.create_trimesh_shape()
		shape_cache[key] = s
	return shape_cache[key]


func _add_visual(shape: Shape3D, xfs: Array) -> void:
	if shape == null or xfs.is_empty():
		return
	for start in range(0, xfs.size(), 2048):
		var b := PhysicsServer3D.body_create()
		PhysicsServer3D.body_set_mode(b, PhysicsServer3D.BODY_MODE_STATIC)
		for xf in xfs.slice(start, start + 2048):
			PhysicsServer3D.body_add_shape(b, shape.get_rid(), xf)
		PhysicsServer3D.body_set_space(b, vis_space)
		vis_bodies.append(b)


func _build_visual_space() -> void:
	vis_space = PhysicsServer3D.space_create()
	PhysicsServer3D.space_set_active(vis_space, true)
	var nodes := []
	_walk(root, nodes)
	var meshes := 0
	var instances := 0
	for n in nodes:
		if n == game.player or (n is Node and game.player.is_ancestor_of(n)):
			continue
		if n is MeshInstance3D and n.mesh != null and _visible(n):
			_add_visual(_trimesh(n.mesh), [n.global_transform])
			meshes += 1
		elif n is MultiMeshInstance3D and n.multimesh != null and n.multimesh.mesh != null and _visible(n):
			var mm: MultiMesh = n.multimesh
			var shape := _trimesh(mm.mesh)
			var count := mm.instance_count if mm.visible_instance_count < 0 else mini(mm.visible_instance_count, mm.instance_count)
			var xfs := []
			for i in count:
				var ixf := mm.get_instance_transform(i)
				if ixf.basis.determinant() == 0.0:
					continue
				xfs.append(n.global_transform * ixf)
			_add_visual(shape, xfs)
			instances += xfs.size()
	stats["visual_meshes"] = meshes
	stats["visual_instances"] = instances


func _ray(sp: RID, from: Vector3, to: Vector3, mask := 0xFFFFFFFF) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to, mask, excluded)
	q.hit_back_faces = true
	return PhysicsServer3D.space_get_direct_state(sp).intersect_ray(q)


func _near_visual(p: Vector3, r: float) -> bool:
	var s := SphereShape3D.new()
	s.radius = r
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = s
	q.transform = Transform3D(Basis(), p)
	return not PhysicsServer3D.space_get_direct_state(vis_space).intersect_shape(q, 1).is_empty()


func _fits(p: Vector3) -> bool:
	var s := SphereShape3D.new()
	s.radius = Tuning.RADIUS * 0.95
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = s
	q.transform = Transform3D(Basis(), p)
	q.collision_mask = WORLD_MASK
	q.exclude = excluded
	return PhysicsServer3D.space_get_direct_state(space).intersect_shape(q, 1).is_empty()


func _path_of(hit: Dictionary) -> String:
	var obj = hit.get("collider")
	if obj is CollisionObject3D:
		var co: CollisionObject3D = obj
		var owner_id := co.shape_find_owner(int(hit.get("shape", 0)))
		var owner_node = co.shape_owner_get_owner(owner_id)
		if owner_node is Node:
			return String(root.get_path_to(owner_node))
		return String(root.get_path_to(co))
	return "<rid %s>" % str(hit.get("rid"))


func _note(kind: String, hit: Dictionary, p: Vector3, air := -1.0) -> void:
	var path := _path_of(hit)
	var key := kind + "|" + path
	if not rows.has(key):
		rows[key] = {"kind": kind, "path": path, "samples": 0, "points": [], "box": AABB(p, Vector3.ZERO), "air": []}
	var r: Dictionary = rows[key]
	r["samples"] += 1
	if air >= 0.0:
		r["air"].append(air)
	r["box"] = (r["box"] as AABB).expand(p)
	if r["points"].size() < 6:
		r["points"].append([snappedf(p.x, 0.1), snappedf(p.y, 0.1), snappedf(p.z, 0.1)])


func _grid(centre: Vector2, half: float) -> Dictionary:
	var cells := {}
	var n := int(ceil(half / step))
	for ix in range(-n, n + 1):
		for iz in range(-n, n + 1):
			var x := centre.x + ix * step
			var z := centre.y + iz * step
			if rect.has_area() and not rect.has_point(Vector2(x, z)):
				continue
			stats["cells"] += 1
			var hit := _ray(space, Vector3(x, SKY, z), Vector3(x, -SKY, z), WORLD_MASK)
			if hit.is_empty():
				continue
			var c: Vector3 = hit["position"] + Vector3.UP * Tuning.RADIUS
			if (hit["normal"] as Vector3).y < 0.5 or not _fits(c + Vector3.UP * 0.05):
				continue
			cells[Vector2i(ix, iz)] = c
			stats["fit_cells"] += 1
	return cells


func _walls(cells: Dictionary) -> void:
	for key in cells:
		var c: Vector3 = cells[key]
		for d in DIRS:
			var a := TAU * d / DIRS
			var dir := Vector3(cos(a), 0.0, sin(a))
			stats["wall_rays"] += 1
			var hit := _ray(space, c, c + dir * ray_range, WORLD_MASK)
			if hit.is_empty():
				continue
			var n: Vector3 = hit["normal"]
			if n.y > 0.7:
				continue
			stats["wall_hits"] += 1
			var p: Vector3 = hit["position"]
			if _tile(hit):
				var h := _drawn_height(p + dir * 0.3)
				if not is_nan(h) and h < p.y - TOL:
					_note("terrain_wall", hit, p)
				continue
			var vhit := _ray(vis_space, c, p + dir * TOL)
			if not vhit.is_empty():
				continue
			if _near_visual(p, TOL):
				continue
			var past := _ray(vis_space, p, p + dir * AIR_CAP)
			_note("wall", hit, p, AIR_CAP if past.is_empty() else p.distance_to(past["position"]))


func _floors(centre: Vector2, half: float) -> void:
	var s := step * 0.5
	var n := int(ceil(half / s))
	for ix in range(-n, n + 1):
		for iz in range(-n, n + 1):
			var x := centre.x + ix * s
			var z := centre.y + iz * s
			if rect.has_area() and not rect.has_point(Vector2(x, z)):
				continue
			stats["floor_rays"] += 1
			var hit := _ray(space, Vector3(x, SKY, z), Vector3(x, -SKY, z), WORLD_MASK)
			if hit.is_empty():
				continue
			var p: Vector3 = hit["position"]
			if _tile(hit):
				var h := _drawn_height(p)
				if is_nan(h) or absf(h - p.y) > TOL:
					_note("terrain_floor", hit, p)
				continue
			var vhit := _ray(vis_space, Vector3(x, SKY, z), Vector3(x, -SKY, z))
			if not vhit.is_empty() and (vhit["position"] as Vector3).y >= p.y - TOL:
				continue
			if _near_visual(p, TOL):
				continue
			_note("floor", hit, p)


func _reach(cells: Dictionary, start: Vector3) -> Dictionary:
	if cells.is_empty():
		return {"cells": 0, "reached": 0, "islands": []}
	var best := Vector2i.ZERO
	var best_d := INF
	for k in cells:
		var d: float = (cells[k] as Vector3).distance_to(start)
		if d < best_d:
			best_d = d
			best = k
	var s := SphereShape3D.new()
	s.radius = Tuning.RADIUS * 0.9
	var st := PhysicsServer3D.space_get_direct_state(space)
	var seen := {best: true}
	var queue: Array[Vector2i] = [best]
	while not queue.is_empty():
		var k: Vector2i = queue.pop_back()
		var a: Vector3 = cells[k]
		for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var m: Vector2i = k + o
			if seen.has(m) or not cells.has(m):
				continue
			var b: Vector3 = cells[m]
			if b.y - a.y > CLIMB:
				continue
			var q := PhysicsShapeQueryParameters3D.new()
			q.shape = s
			var lift := Vector3.UP * (maxf(0.0, b.y - a.y) + 0.3)
			q.transform = Transform3D(Basis(), a + lift)
			q.motion = b + lift - (a + lift)
			q.collision_mask = WORLD_MASK
			q.exclude = excluded
			var frac := st.cast_motion(q)
			if frac.size() > 0 and frac[0] < 0.999:
				continue
			seen[m] = true
			queue.append(m)
	var left := {}
	for k in cells:
		if not seen.has(k):
			left[k] = true
	var islands := []
	var done := {}
	for k in left:
		if done.has(k):
			continue
		var group := [k]
		done[k] = true
		var i := 0
		while i < group.size():
			var g: Vector2i = group[i]
			i += 1
			for dx in range(-1, 2):
				for dz in range(-1, 2):
					var m := g + Vector2i(dx, dz)
					if left.has(m) and not done.has(m):
						done[m] = true
						group.append(m)
		if group.size() >= 3:
			var box := AABB(cells[group[0]], Vector3.ZERO)
			for g in group:
				box = box.expand(cells[g])
			islands.append({"cells": group.size(), "area_m2": group.size() * step * step, "centre": _v(box.get_center()), "size": _v(box.size)})
	islands.sort_custom(func(x, y): return x["cells"] > y["cells"])
	var grid := []
	for k in cells:
		var c: Vector3 = cells[k]
		grid.append([snappedf(c.x, 0.1), snappedf(c.y - Tuning.RADIUS, 0.1), snappedf(c.z, 0.1), 1 if seen.has(k) else 0])
	return {"cells": cells.size(), "reached": seen.size(), "islands": islands.slice(0, 20), "grid": grid}


func _v(p: Vector3) -> Array:
	return [snappedf(p.x, 0.1), snappedf(p.y, 0.1), snappedf(p.z, 0.1)]


func _write(colliders: Array, reach: Dictionary, centre: Vector2, half: float, start: Vector3) -> void:
	var list := []
	for k in rows:
		var r: Dictionary = rows[k].duplicate()
		var box: AABB = r["box"]
		r["box_centre"] = _v(box.get_center())
		r["box_size"] = _v(box.size)
		r.erase("box")
		var air: Array = r["air"]
		r.erase("air")
		if not air.is_empty():
			air.sort()
			r["air_median_m"] = snappedf(air[air.size() / 2], 0.01)
			r["air_max_m"] = snappedf(air[-1], 0.01)
			r["over_limit"] = air.filter(func(a): return a > AIR_LIMIT).size()
		list.append(r)
	list.sort_custom(func(x, y): return x["samples"] > y["samples"])
	var kinds := {}
	for c in colliders:
		kinds[c["kind"]] = int(kinds.get(c["kind"], 0)) + 1
	var report := {"tool": "invisible_walls", "target": _label(), "seed": run_seed, "step_m": step, "range_m": ray_range,
		"tol_m": TOL, "centre": [centre.x, centre.y], "half_m": half, "start": _v(start), "colliders": colliders.size(),
		"collider_kinds": kinds, "stats": stats, "reach": reach, "rows": list}
	DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "  "))
	f.close()
	print("invisible_walls: %s seed %d: %d colliders, %d rows (%s), reach %d/%d -> %s" % [_label(), run_seed, colliders.size(), list.size(),
		_count_kinds(list), int(reach["reached"]), int(reach["cells"]), out_path])
	if md_path != "":
		var lines := ["| kind | samples | over %.1f m air | air median / max m | collider (node path) | centre | size |" % AIR_LIMIT, "|---|---|---|---|---|---|---|"]
		for r in list:
			lines.append("| %s | %d | %s | %s | `%s` | %s | %s |" % [r["kind"], r["samples"], str(r.get("over_limit", "")),
				"%s / %s" % [r["air_median_m"], r["air_max_m"]] if r.has("air_median_m") else "", r["path"], r["box_centre"], r["box_size"]])
		var g := FileAccess.open(md_path, FileAccess.WRITE)
		g.store_string("\n".join(lines) + "\n")
		g.close()


func _count_kinds(list: Array) -> String:
	var c := {}
	for r in list:
		c[r["kind"]] = int(c.get(r["kind"], 0)) + 1
	return str(c)
