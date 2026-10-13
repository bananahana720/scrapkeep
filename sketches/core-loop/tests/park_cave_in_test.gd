extends SceneTree

const Terrain := preload("res://src/world/terrain.gd")
const Natural := preload("res://src/world/events/natural.gd")
const Director := preload("res://src/world/event_director.gd")
const T := preload("res://tests/support/t.gd")

class Table:
	const DEFS := [{"map": "park_sinkhole", "stage": 1, "world": 1}]

class Context:
	extends RefCounted
	var root

class World:
	extends Node3D
	var terrain
	var ctx := Context.new()
	var events
	var presentation = null

var t := T.new("park_cave_in_test")
var w: World
var handler
var row: Dictionary
var point: Vector2
const BASELINE_B3B840D := 1.363632
var before: float
var previous_drop := 0.0
var samples := []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	w = World.new()
	root.add_child(w)
	w.ctx.root = w
	var camera := Camera3D.new()
	w.add_child(camera)
	camera.position = Vector3(0, 200, 0)
	camera.current = true
	w.terrain = Terrain.new(Table)
	w.terrain.build(w)
	w.terrain.use(1)
	var park: Dictionary = w.terrain.map().park
	row = park.event_rows.filter(func(r): return r.id == "west_roof_cave_in")[0]
	var site: Dictionary = park.park_rows.filter(func(r): return r.id == row.site)[0]
	point = Vector2(float(site.at[0]), float(site.at[1]))
	before = w.terrain.height(point.x, point.y)
	await _sample("stage load", 0.0, false)
	w.events = Director.new(823, {}, w.terrain.map(), 14.0, Callable(w.terrain, "height"))
	handler = Natural.new()
	w.add_child(handler)
	handler.setup(w)
	await _sample("before", 0.0, false)
	var ctx := {"clock_s": 0.0, "ball": Vector3(700, 200, 700), "delta_s": 0.0, "rise_s": 0.0}
	handler.handle("telegraph", row, ctx)
	await _sample("telegraph", 0.0, false)
	handler.handle("land", row, ctx)
	await _sample("land", 0.0, true)
	for elapsed in [1.5, 3.0, 5.0]:
		ctx.delta_s = elapsed - float(samples[-1].elapsed)
		ctx.rise_s = float(samples[-1].elapsed)
		handler.handle("step", row, ctx)
		await _sample(str(elapsed), elapsed, true)
	var out := FileAccess.open("user://cave-in-samples.json", FileAccess.WRITE)
	out.store_string(JSON.stringify(samples, "  ") + "\n")
	out.close()
	handler.handle("end", row, ctx)
	await _sample("ended", 5.0, true)
	handler.release()
	w.free()
	var result := t.verdict()
	quit(result)

func _sample(label: String, elapsed: float, landed: bool) -> void:
	await physics_frame
	await physics_frame
	var height: float = w.terrain.height(point.x, point.y)
	var drop := before - height
	var expected := float(row.effect.depth_m) * clampf(elapsed / float(row.effect.fill_s), 0.0, 1.0)
	var query := PhysicsRayQueryParameters3D.create(Vector3(point.x, before + 100.0, point.y), Vector3(point.x, before - 200.0, point.y))
	var hit: Dictionary = w.get_world_3d().direct_space_state.intersect_ray(query)
	var body: Node3D = handler._prepared[row.id].overlay if handler != null else w.terrain.cave_roof(row.id).get("body") if w.terrain.has_method("cave_roof") else null
	var drawn := _mesh_height(body.get_child(0), point) if body != null and body.is_visible_in_tree() else INF
	var ray_y: float = hit.position.y if not hit.is_empty() else INF
	print("SAMPLE %s elapsed=%.2f pre=%.6f height=%.6f drop=%.6f expected=%.6f ray=%.6f drawn=%.6f" % [label, elapsed, before, height, drop, expected, ray_y, drawn])
	samples.append({"label": label, "elapsed": elapsed, "before": before, "height": height, "drop": drop, "expected": expected, "ray": ray_y, "drawn": drawn, "drawn_method": "visible mesh triangles"})
	t.near(label + " authored drop", drop, expected, 0.5 if is_equal_approx(elapsed, 1.5) else 0.25 if elapsed >= 3.0 else 0.05)
	t.check(label + " monotonic drop", drop >= previous_drop - 0.00001)
	t.check(label + " real downward ray hits", not hit.is_empty())
	t.near(label + " ray agrees", ray_y, height, 0.05)
	t.near(label + " drawn mesh agrees", drawn, height, 0.05)
	if not landed:
		t.near(label + " pre-event terrain baseline b3b840d", height, BASELINE_B3B840D, 0.05)
		t.near(label + " pre-event collider baseline b3b840d", ray_y, BASELINE_B3B840D, 0.05)
	previous_drop = drop

func _mesh_height(view: MeshInstance3D, at: Vector2) -> float:
	var arrays := view.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for k in range(0, indices.size(), 3):
		var a: Vector3 = view.global_transform * vertices[indices[k]]
		var b: Vector3 = view.global_transform * vertices[indices[k + 1]]
		var c: Vector3 = view.global_transform * vertices[indices[k + 2]]
		var ab := Vector2(b.x - a.x, b.z - a.z)
		var ac := Vector2(c.x - a.x, c.z - a.z)
		var ap := at - Vector2(a.x, a.z)
		var det := ab.cross(ac)
		if absf(det) < 0.0000001:
			continue
		var u := ap.cross(ac) / det
		var v := ab.cross(ap) / det
		if u >= -0.00001 and v >= -0.00001 and u + v <= 1.00001:
			return a.y + u * (b.y - a.y) + v * (c.y - a.y)
	return INF
