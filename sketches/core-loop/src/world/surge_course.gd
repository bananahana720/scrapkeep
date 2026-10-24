extends Node3D

const SurgeRun := preload("res://src/world/surge_run.gd")
const EventView := preload("res://src/world/event_view.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Palette := preload("res://src/core/palette.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")

# The surge course in a park (activities.gd surge_run): the Reach's Surge Run (surge_run.gd) laid
# down a park route's line rows. The ring stands beside the head of the line; rolling in opens the
# sluice (the park's sluice_surge event row, so the siren lands on the bar), and the water then
# chases the ball down the line through the gates. What is drawn is the model: the next gate glows,
# the rest stand in sand, and the front is a wall of water the width of the line.

# A gate's height comes from the nearest graph node of its row within this reach.
const NODE_REACH_M := 24.0
const FRONT_SIZE := Vector3(12.0, 4.0, 3.0)

var model
var _gates: Array[MeshInstance3D] = []
var _front: MeshInstance3D


# The route's grind rows (the flume's water channel), each a straight segment through its at along its yaw and
# length, chained so each runs away from where the last one ended (the first from `start`). rows[i] names the row of
# the segment from points[i] to points[i + 1]; a link between two rows takes the next row's id.
static func path(park: Dictionary, route_id: String, start: Vector2) -> Dictionary:
	var rows := {}
	for row in park.get("park_rows", []):
		rows[row.id] = row
	var via: Array = []
	for route in park.get("routes", []):
		if route.id == route_id:
			via = route.via
	var points := PackedVector2Array()
	var names := PackedStringArray()
	var last := start
	for id in via:
		if not rows.has(id) or String(rows[id].verb) != "grind":
			continue
		var row: Dictionary = rows[id]
		var at := Vector2(float(row.at[0]), float(row.at[1]))
		var half := ParkMap._dir(float(row.yaw_deg)) * float(row.size[0]) * 0.5
		var a := at - half
		var b := at + half
		if b.distance_to(last) < a.distance_to(last):
			var swap := a
			a = b
			b = swap
		if points.is_empty() or points[points.size() - 1].distance_to(a) > 0.5:
			if not points.is_empty():
				names.append(id)
			points.append(a)
		points.append(b)
		names.append(id)
		last = b
	return {"points": points, "rows": names}


# Each gate's deck height: the nearest graph node of the row its stretch of the route runs on, so a gate where two
# decks cross in plan takes its own deck's height. With no node near, the ground there.
static func heights(model_ref, rows: PackedStringArray, graph, ground: Callable) -> Array[float]:
	var nodes := {}
	if graph != null:
		var wanted := {}
		for id in rows:
			wanted[id] = true
		for n in graph.node_count():
			var row: String = graph.node_row(n)
			if wanted.has(row):
				if not nodes.has(row):
					nodes[row] = []
				nodes[row].append(graph.position(n))
	var out: Array[float] = []
	var route = model_ref.route
	for i in model_ref.gates.size():
		var g: Vector2 = model_ref.gates[i]
		var y := float(ground.call(g.x, g.y)) if ground.is_valid() else 0.0
		var segment := 0
		for k in range(1, route.lengths.size()):
			segment = k - 1
			if model_ref.gate_distances[i] <= route.lengths[k]:
				break
		var best := NODE_REACH_M
		for p in nodes.get(rows[segment] if segment < rows.size() else "", []):
			var d := Vector2(p.x, p.z).distance_to(g)
			if d <= best:
				best = d
				y = p.y
		out.append(y)
	return out


func setup(site: Dictionary, cruise: float, graph, park: Dictionary, ground: Callable) -> void:
	name = "SurgeCourse"
	top_level = true
	var ring: Vector2 = site.ring
	var line := path(park, String(site.route), ring)
	model = SurgeRun.new({"ring": ring, "route": line.points}, cruise)
	model.gate_heights = heights(model, line.rows, graph, ground)
	for i in model.gates.size():
		var at := Vector3(model.gates[i].x, model.gate_heights[i], model.gates[i].y)
		var g := EventView.gate_ring(at, model.route.tangent(model.gate_distances[i]))
		g.visible = false
		add_child(g)
		_gates.append(g)
	_front = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = FRONT_SIZE
	_front.mesh = box
	_front.material_override = Palette.water(Palette.VERDIGRIS.lerp(Palette.ARC, 0.5))
	_front.visible = false
	add_child(_front)


func show_live(live: bool, pulse: float) -> void:
	for i in _gates.size():
		var g := _gates[i]
		g.visible = live and i >= model.next_gate
		if g.visible:
			var next: bool = i == model.next_gate
			var mat: StandardMaterial3D = g.material_override
			mat.albedo_color = EventKinds.world_row("sluice_landed").color if next else Palette.SAND
			mat.emission = mat.albedo_color
			mat.emission_energy_multiplier = FlashGuard.spike(1.2, 1.2 + pulse * 2.0) if next else 0.4
	_front.visible = live and model.front > 0.0
	if _front.visible:
		var d: float = maxf(model.front, 0.0)
		var p: Vector2 = model.front_point()
		var t: Vector2 = model.front_tangent()
		_front.position = Vector3(p.x, model.deck_height(d) + FRONT_SIZE.y * 0.5, p.y)
		_front.basis = Basis.looking_at(Vector3(t.x, 0.0, t.y), Vector3.UP)


# The next gate, where a ball on the course aims (the bot's target).
func next_gate_point() -> Vector3:
	var i: int = clampi(model.next_gate, 0, model.gates.size() - 1)
	return Vector3(model.gates[i].x, model.gate_heights[i], model.gates[i].y)
