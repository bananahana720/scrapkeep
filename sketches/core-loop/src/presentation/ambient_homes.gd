extends RefCounted

# Where ambient life lives: a pure planner from a parsed park file (park_schema.gd load_park) and
# the ambient record (src/core/ambient_kinds.gd, the one row per kind). It picks `count` homes per
# kind from the park rows the kind's `homes` names (any landform, element or society match), draws
# each point inside the row's footprint, and keeps every home and every member clear of play:
# ride lines, grapple fields, routes, enemy homes, the Warden ring, spawn, activities, rescues,
# contraptions and the reward gate slots. keepouts() and blocked() are public so a test can ask the
# same question of any position. Deterministic for a seed; no nodes, no ground (the view lifts to it).

const AmbientKinds := preload("res://src/core/ambient_kinds.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")

# Elements a ball rides: homes keep their footprint plus RIDE_M clear. A kicker that is a mesa edge is ground.
const RIDE_ELEMENTS := ["half_pipe", "flow_line", "grind_line", "rail", "bowl", "tunnel", "drop", "elevated_line",
	"kicker", "crater_bowl", "flooded_cavern"]
const RIDE_M := 6.0
const ANCHOR_M := 8.0
const ROUTE_M := 10.0
const ENEMY_HOME_M := 25.0
const RING_EXTRA_M := 10.0
const SPOT_M := 12.0
# A home at least this far from another home of its kind, so a kind spreads over the park.
const SPREAD_M := 40.0
# Members of a group spread over a disc this wide round the home.
const GROUP_RADIUS_M := 2.5
# Homes within this distance of a route are preferred (the player passes them); any valid point is the fallback.
const NEAR_ROUTE_M := 80.0
const ATTEMPTS := 400
const VALID_PER_HOME := 6
const EDGE_M := 20.0
# A home at a crew prop stands this far beside it, so the keeper is at the camp and not inside the prop.
const SPOT_SIDE_M := 3.0


# homes: [{kind, at: Vector2, perch, group: int, members: Array[Vector2] (offsets, the first is ZERO)}].
# `group` is the home's index in this plan, unique per call. `veto` (optional) is the runtime's say on a spot the
# park file cannot judge, (at: Vector2, perch: String) -> bool: true rejects it (ambient_life.gd: too steep, or
# under a structure).
static func plan(park: Dictionary, kind_ids: Array, seed_number: int, veto := Callable()) -> Array:
	var planner := Planner.new(park, kind_ids, seed_number, veto)
	while planner.step():
		pass
	return planner.homes


# plan() as steps, so a caller can spread it over frames: the keepout grid first, then a kind a step.
# Each kind draws from its own seeded stream, so the homes are plan()'s whichever way it runs.
class Planner extends RefCounted:
	const Homes := preload("res://src/presentation/ambient_homes.gd")
	var homes := []
	var _park: Dictionary
	var _kind_ids: Array
	var _seed_number: int
	var _veto: Callable
	var _keep: Dictionary
	var _rows: Array
	var _rect: Rect2
	var _routes: Array
	var _next := -1

	func _init(park: Dictionary, kind_ids: Array, seed_number: int, veto := Callable()) -> void:
		_park = park
		_kind_ids = kind_ids
		_seed_number = seed_number
		_veto = veto

	# One step; false once every kind is planned.
	func step() -> bool:
		if _next < 0:
			_keep = Homes._keep_grid(Homes.keepouts(_park))
			_rows = _park["park_rows"]
			_rect = Homes._rect(_park)
			_routes = Homes._route_lines(_park)
		else:
			_plan_kind(_kind_ids[_next])
		_next += 1
		return _next < _kind_ids.size()

	func _plan_kind(kind_id) -> void:
		var kind: Dictionary = AmbientKinds.row(String(kind_id))
		if kind.is_empty():
			return
		var spec: Dictionary = kind["homes"]
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([_seed_number, String(kind_id), String(_park["map"])])
		# A ride or grapple row is wholly inside its own keepout, so it can never hold a home: skip it up front.
		var rect := _rect
		var want := rng.randi_range(int(spec["count"][0]), int(spec["count"][1]))
		var placed: Array[Vector2] = []
		# A kind with `spots` lives first at the park's crew props of those templates (the camps and yards).
		for found in Homes._spot_homes(rng, String(_park["map"]), spec, _keep, _rect, want, _veto):
			placed.append(found["at"])
			found["kind"] = String(kind_id)
			found["perch"] = String(spec["perch"])
			found["group"] = homes.size()
			homes.append(found)
		var matching := _rows.filter(func(r): return Homes._matches(r, spec) and not Homes._own_keepout(r, rect))
		if matching.is_empty():
			return
		for h in want - placed.size():
			var found := Homes._find_home(rng, matching, _keep, _rect, _routes, spec, kind, placed, _veto)
			if found.is_empty():
				continue
			placed.append(found["at"])
			found["kind"] = String(kind_id)
			found["perch"] = String(spec["perch"])
			found["group"] = homes.size()
			homes.append(found)


# Homes at the park's crew props whose template is in spec["spots"] (src/world/park/props/<map>.json): each stands
# SPOT_SIDE_M beside its prop, clear of every keepout, at most `want`, spread SPREAD_M apart, in a seeded order.
static func _spot_homes(rng: RandomNumberGenerator, map_id: String, spec: Dictionary, keep: Dictionary, rect: Rect2,
		want: int, veto := Callable()) -> Array:
	var out := []
	var templates: Array = spec.get("spots", [])
	if templates.is_empty() or want <= 0:
		return out
	var path := "res://src/world/park/props/%s.json" % map_id
	if not FileAccess.file_exists(path):
		return out
	var props = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not props is Dictionary:
		return out
	var spots: Array = (props.get("spots", []) as Array).filter(func(sp): return templates.has(String(sp.get("template", ""))))
	for i in range(spots.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap = spots[i]
		spots[i] = spots[j]
		spots[j] = swap
	var placed: Array[Vector2] = []
	var perch := String(spec["perch"])
	for sp in spots:
		if out.size() >= want:
			break
		var base := Vector2(float(sp["at"][0]), float(sp["at"][1]))
		for k in 6:
			var at := base + Vector2(SPOT_SIDE_M, 0.0).rotated(TAU * (k + rng.randf()) / 6.0)
			if not rect.grow(-EDGE_M).has_point(at) or _blocked_near(keep, at) != "" or _crowded(at, placed):
				continue
			if veto.is_valid() and veto.call(at, perch):
				continue
			placed.append(at)
			out.append({"at": at, "members": [Vector2.ZERO] as Array[Vector2]})
			break
	return out


static func _own_keepout(row: Dictionary, rect: Rect2) -> bool:
	var element := String(row["element"])
	return element == "anchor_field" or (RIDE_ELEMENTS.has(element) and not ParkMap.mesa_edge(row, rect))


static func _matches(row: Dictionary, spec: Dictionary) -> bool:
	return (spec["landforms"] as Array).has(row["landform"]) or (spec["elements"] as Array).has(row["element"]) \
		or (spec["societies"] as Array).has(row["society"])


static func _find_home(rng: RandomNumberGenerator, matching: Array, keep: Dictionary, rect: Rect2, routes: Array, spec: Dictionary,
		kind: Dictionary, placed: Array[Vector2], veto := Callable()) -> Dictionary:
	var valid := []
	var perch := String(spec["perch"])
	for attempt in ATTEMPTS:
		var row: Dictionary = matching[rng.randi() % matching.size()]
		var at := _sample(rng, row)
		if not rect.grow(-EDGE_M).has_point(at) or _blocked_near(keep, at) != "" or _crowded(at, placed):
			continue
		if veto.is_valid() and veto.call(at, perch):
			continue
		var members := _members(rng, at, keep, int(rng.randi_range(int(spec["group"][0]), int(spec["group"][1]))), veto, perch)
		valid.append({"at": at, "members": members, "route": _route_distance(routes, at)})
		if valid.size() >= VALID_PER_HOME:
			break
	if valid.is_empty():
		return {}
	var near := valid.filter(func(v): return v["route"] <= NEAR_ROUTE_M)
	var pool: Array = near if not near.is_empty() else valid
	var pick: Dictionary = pool[rng.randi() % pool.size()]
	return {"at": pick["at"], "members": pick["members"]}


# The first member stands on the home; the rest are drawn round it and kept only where they are clear too.
static func _members(rng: RandomNumberGenerator, at: Vector2, keep: Dictionary, count: int, veto := Callable(), perch := "") -> Array[Vector2]:
	var offsets: Array[Vector2] = [Vector2.ZERO]
	for i in range(1, count):
		for attempt in 8:
			var offset := Vector2.from_angle(rng.randf_range(0.0, TAU)) * rng.randf_range(0.6, GROUP_RADIUS_M)
			if _blocked_near(keep, at + offset) == "" and not (veto.is_valid() and veto.call(at + offset, perch)):
				offsets.append(offset)
				break
	return offsets


static func _crowded(at: Vector2, placed: Array[Vector2]) -> bool:
	for other in placed:
		if other.distance_to(at) < SPREAD_M:
			return true
	return false


# A uniform point in the row's rotated footprint (park_map.gd footprint_contains inverted).
static func _sample(rng: RandomNumberGenerator, row: Dictionary) -> Vector2:
	var half := ParkMap.footprint_half_extents(row)
	var local := Vector2(rng.randf_range(-half.x, half.x), rng.randf_range(-half.y, half.y))
	return Vector2(float(row["at"][0]), float(row["at"][1])) + local.rotated(-deg_to_rad(float(row["yaw_deg"])))


static func _rect(park: Dictionary) -> Rect2:
	var r: Array = park["play_rect"]
	return Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))


static func _v2(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


# Route polylines from the rows' `at`; ids that name no row (waymarks past the rows) are skipped.
static func _route_lines(park: Dictionary) -> Array:
	var at := {}
	for row in park["park_rows"]:
		at[row["id"]] = _v2(row["at"])
	at[park["landmark"]["id"]] = _v2(park["landmark"]["at"])
	var lines := []
	for route in park["routes"]:
		var ids := [route["from"]]
		ids.append_array(route["via"])
		ids.append(route["to"])
		var line := PackedVector2Array()
		for id in ids:
			if at.has(id):
				line.append(at[id])
		if line.size() >= 2:
			lines.append(line)
	return lines


static func _route_distance(routes: Array, p: Vector2) -> float:
	var best := INF
	for line: PackedVector2Array in routes:
		best = minf(best, _line_distance(line, p))
	return best


static func _line_distance(points: PackedVector2Array, p: Vector2) -> float:
	if points.size() == 1:
		return p.distance_to(points[0])
	var best := INF
	for i in points.size() - 1:
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, points[i], points[i + 1])))
	return best


# Every place ambient life keeps out of. Each keepout is {what, shape: "rect"|"circle"|"line", ...}:
# a rect carries the park row and a margin, a circle a centre and radius, a line points and a radius.
static func keepouts(park: Dictionary) -> Array:
	var out := []
	var rect := _rect(park)
	var at := {}
	for row in park["park_rows"]:
		at[row["id"]] = _v2(row["at"])
		var element := String(row["element"])
		if RIDE_ELEMENTS.has(element) and not ParkMap.mesa_edge(row, rect):
			out.append(_rect_keep("ride " + String(row["id"]), row, RIDE_M))
		elif element == "anchor_field":
			out.append(_rect_keep("anchor " + String(row["id"]), row, ANCHOR_M))
	for line in _route_lines(park):
		out.append({"what": "route", "shape": "line", "points": line, "radius": ROUTE_M})
	for home in park["home_rows"]:
		var site: Dictionary = {}
		for row in park["park_rows"]:
			if row["id"] == home["site"]:
				site = row
				break
		if not site.is_empty():
			# The enemy's ground is the row's own; a big row keeps out 25 m plus up to 30 m of its half-size round its centre.
			var reach := ENEMY_HOME_M + minf(maxf(ParkMap.footprint_half_extents(site).x, ParkMap.footprint_half_extents(site).y), 30.0)
			out.append(_circle("enemy home " + String(home["id"]), _v2(site["at"]), reach))
	var mark: Dictionary = park["landmark"]
	out.append(_circle("warden ring", _v2(mark["beacon"]), float(mark["reach_m"]) + RING_EXTRA_M))
	for slot in mark["gate_slots"]:
		out.append(_circle("gate slot", _v2(slot["at"]), SPOT_M))
	out.append(_circle("spawn", _v2(park["spawn"]["at"]), SPOT_M))
	for row in park["activity_rows"]:
		out.append(_circle("activity " + String(row["id"]), _v2(row["at"]), SPOT_M))
	for row in park.get("rescue_rows", []):
		out.append(_circle("rescue " + String(row["id"]), _v2(row["at"]), SPOT_M))
	for row in park["contraption_rows"]:
		var spots := []
		for key in ["at", "from", "to"]:
			if row.has(key):
				var p: Array = row[key]
				spots.append(Vector2(float(p[0]), float(p[p.size() - 1])))
		if spots.is_empty() and at.has(row.get("site", "")):
			spots.append(at[row["site"]])
		if spots.size() == 2 and row.has("from"):
			out.append({"what": "contraption " + String(row["id"]), "shape": "line", "points": PackedVector2Array(spots), "radius": SPOT_M})
		else:
			for p in spots:
				out.append(_circle("contraption " + String(row["id"]), p, SPOT_M))
	return out


static func _rect_keep(what: String, row: Dictionary, margin: float) -> Dictionary:
	var half := ParkMap.footprint_half_extents(row)
	return {"what": what, "shape": "rect", "row": row, "margin": margin, "centre": _v2(row["at"]), "reach": half.length() + margin * 1.5}


static func _circle(what: String, centre: Vector2, radius: float) -> Dictionary:
	return {"what": what, "shape": "circle", "centre": centre, "radius": radius}


# The `what` of the first keepout that holds `at`, or "".
static func blocked(keep: Array, at: Vector2) -> String:
	for k in keep:
		var what := _holds(k, at)
		if what != "":
			return what
	return ""


# blocked() over only the keepouts whose reach touches at's cell, in keepout order, so it answers the same. The
# plan asks it thousands of times a stage, and walking every keepout each time was a 660 ms stage entry frame
# on the cloud (Brindle's stage 4). keep: {"keep": keepouts(), "cells": {Vector2i: [index]}}.
const KEEP_CELL_M := 48.0


static func _keep_grid(keep: Array) -> Dictionary:
	var cells := {}
	for i in keep.size():
		var k: Dictionary = keep[i]
		match k["shape"]:
			"circle":
				_cover(cells, i, k["centre"], k["centre"], float(k["radius"]))
			"rect":
				_cover(cells, i, k["centre"], k["centre"], float(k["reach"]))
			"line":
				var points: PackedVector2Array = k["points"]
				if points.size() == 1:
					_cover(cells, i, points[0], points[0], float(k["radius"]))
				for j in points.size() - 1:
					_cover(cells, i, points[j], points[j + 1], float(k["radius"]))
	return {"keep": keep, "cells": cells}


# Adds index i to every cell the box round a and b, grown by r, touches (once a cell).
static func _cover(cells: Dictionary, i: int, a: Vector2, b: Vector2, r: float) -> void:
	var lo := Vector2i(floori((minf(a.x, b.x) - r) / KEEP_CELL_M), floori((minf(a.y, b.y) - r) / KEEP_CELL_M))
	var hi := Vector2i(floori((maxf(a.x, b.x) + r) / KEEP_CELL_M), floori((maxf(a.y, b.y) + r) / KEEP_CELL_M))
	for x in range(lo.x, hi.x + 1):
		for y in range(lo.y, hi.y + 1):
			var cell := Vector2i(x, y)
			if not cells.has(cell):
				cells[cell] = []
			var list: Array = cells[cell]
			if list.is_empty() or list.back() != i:
				list.append(i)


static func _blocked_near(near: Dictionary, at: Vector2) -> String:
	var keep: Array = near["keep"]
	for i in near["cells"].get(Vector2i(floori(at.x / KEEP_CELL_M), floori(at.y / KEEP_CELL_M)), []):
		var what := _holds(keep[i], at)
		if what != "":
			return what
	return ""


static func _holds(k: Dictionary, at: Vector2) -> String:
	match k["shape"]:
		"circle":
			if at.distance_to(k["centre"]) < float(k["radius"]):
				return String(k["what"])
		"line":
			if _line_distance(k["points"], at) < float(k["radius"]):
				return String(k["what"])
		"rect":
			if at.distance_to(k["centre"]) <= float(k["reach"]) and ParkMap.footprint_contains(k["row"], at, float(k["margin"])):
				return String(k["what"])
	return ""
