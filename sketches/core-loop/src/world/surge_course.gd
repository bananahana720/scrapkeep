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

# A gate's deck is found by a ray from this far above its row's top to this far below it.
const RAY_ABOVE_M := 3.0
const RAY_BELOW_M := 60.0
const FRONT_SIZE := Vector3(12.0, 4.0, 3.0)
# The ring stands off the head, so the water opens further back than the Reach's: a ball that rolls from the ring to the
# head while the siren winds starts the deck ahead of the front, with room to reach cruise before it closes.
const FRONT_START := -40.0
# And it runs at cruise, not the Reach's 1.15 cruise: the line drops 40 m off the weir deck's end onto the gap reach and
# turns 85 degrees there, which costs a rider seconds the flat Reach never asks for.
const FRONT_SPEED := 1.0

var model
var _rows := PackedStringArray()
var _park := {}
var _ground := Callable()
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


# Each gate's deck height, from the row its stretch of the route runs on, so a gate where two decks cross in plan takes
# its own deck's height. The row's top (its y plus its height; a raised row's graph nodes stand at its base, and a work
# deck's top slopes) is where a ray looks down from; what it hits is the deck. With no world to ray, the row's top; with
# no y on the row, the ground there.
static func heights(model_ref, rows: PackedStringArray, park: Dictionary, ground: Callable, space: PhysicsDirectSpaceState3D = null) -> Array[float]:
	var tops := {}
	for row in park.get("park_rows", []):
		if row.get("y") != null:
			tops[String(row.id)] = float(row.y) + float(row.size[1])
	var out: Array[float] = []
	var route = model_ref.route
	for i in model_ref.gates.size():
		var g: Vector2 = model_ref.gates[i]
		var segment := 0
		for k in range(1, route.lengths.size()):
			segment = k - 1
			if model_ref.gate_distances[i] <= route.lengths[k]:
				break
		var id: String = rows[segment] if segment < rows.size() else ""
		var y: float = tops[id] if tops.has(id) else (float(ground.call(g.x, g.y)) if ground.is_valid() else 0.0)
		if space != null:
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(g.x, y + RAY_ABOVE_M, g.y), Vector3(g.x, y - RAY_BELOW_M, g.y), 1))
			if not hit.is_empty():
				y = hit.position.y
		out.append(y)
	return out


func setup(site: Dictionary, cruise: float, park: Dictionary, ground: Callable) -> void:
	name = "SurgeCourse"
	# The course hangs under its ring's site but draws in world space: a node made top_level keeps the global
	# transform it had (the site's), so it is reset, as the pocket hazards are (activities.gd).
	top_level = true
	transform = Transform3D.IDENTITY
	var ring: Vector2 = site.ring
	var line := path(park, String(site.route), ring)
	model = SurgeRun.new({"ring": ring, "route": line.points}, cruise)
	model.front_start = FRONT_START
	model.front_speed = cruise * FRONT_SPEED
	_rows = line.rows
	_park = park
	_ground = ground
	model.gate_heights = heights(model, _rows, _park, _ground)
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


# The gates onto the decks themselves, by ray, once the stage's colliders stand (the course is built with the stage, on
# its rows' tops; activities.gd calls this as the course goes live).
func settle() -> void:
	if not is_inside_tree():
		return
	model.gate_heights = heights(model, _rows, _park, _ground, get_world_3d().direct_space_state)
	for i in _gates.size():
		_gates[i].position.y = model.gate_heights[i] + EventView.GATE_RADIUS - 1.0


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


# A point `ahead` metres down the line from where the ball is, on the deck: a rider who aims here stays on the
# line's centre between gates (the bot's target; aiming straight at a gate far down a bent line walks off the deck).
# Behind the head, the line runs on back along its first heading, so a rider coming in from the side lines up before
# the deck (the flume's trough is entered from its end).
func lead_point(ball: Vector3, ahead: float) -> Vector3:
	var flat := Vector2(ball.x, ball.z)
	var head: Vector2 = model.route.points[0]
	var t0: Vector2 = model.route.tangent(0.0)
	var behind := (flat - head).dot(t0)
	var d: float = (behind if behind < 0.0 else model.route.project(flat).x) + ahead
	var p: Vector2 = head + t0 * d if d < 0.0 else model.route.at(d)
	return Vector3(p.x, model.deck_height(maxf(d, 0.0)), p.y)


# The next gate, where a ball on the course aims.
func next_gate_point() -> Vector3:
	var i: int = clampi(model.next_gate, 0, model.gates.size() - 1)
	return Vector3(model.gates[i].x, model.gate_heights[i], model.gates[i].y)
