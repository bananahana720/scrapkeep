extends RefCounted

const ParkMap := preload("res://src/world/park/park_map.gd")
const SetDressing := preload("res://src/presentation/set_dressing.gd")

# Where a world's scenery may stand on a park stage. The old maps' scenery stood outside a 300 m
# play rect on a fixed rim; a park is a 1.6 km square whose rows are the ride, so the park pass
# seats each piece on the flank of a named row instead. A seat is refused inside any built row's
# footprint (anchor fields included) plus a margin, near the landmark, and near the spawn, beacon,
# gates, activity sites, rescue cages and kickers (set_dressing.gd keepouts). Nothing seated here
# collides. Presentation only.

const MARGIN := 3.0
const CAGE_CLEAR := 18.0
# A stamped row is ground, not a built piece; a long or wide one (a 750 m terrace, a 900 m bowl) is
# the landform itself and keeps nothing out, while a shorter one (a wash, a haul ramp) is a ride.
const STAMP_KEEP_M := 200.0

var map
var ground: Callable
var _keepouts: Array = []
var _cells := {}


func _init(park_map, ground_at: Callable, stage: int) -> void:
	map = park_map
	ground = ground_at
	_keepouts = SetDressing.keepouts(map, stage)
	for cage in map.park.get("rescue_rows", []):
		_keepouts.append({"what": "rescue cage", "points": PackedVector2Array([ParkMap._v2(cage["at"])]), "radius": CAGE_CLEAR, "ride": false})
	for row in map.park["park_rows"]:
		if row["element"] != "ground" and (String(row["stamp"]).is_empty() or maxf(float(row["size"][0]), float(row["size"][2])) <= STAMP_KEEP_M):
			_bucket(row)
	_bucket(map.park["landmark"])


static func is_park(m) -> bool:
	return m is ParkMap and not m.park.is_empty()


# The rows a world dresses: element and landform both listed (an empty list takes any).
func rows(elements: Array, landforms: Array = []) -> Array:
	return map.park["park_rows"].filter(func(row): return (elements.is_empty() or elements.has(row["element"])) \
		and (landforms.is_empty() or landforms.has(row["landform"])))


func height(at: Vector2) -> float:
	return (ground.call(at.x, at.y, 0.0) as Vector3).y


# True when nothing built or kept out lies within margin (at most MARGIN_MAX) of `at`.
func clear(at: Vector2, margin := MARGIN) -> bool:
	if not map.play_rect.has_point(at):
		return false
	if SetDressing.blocked(_keepouts, at, margin) != "":
		return false
	for row in _cells.get(_cell(at), []):
		if ParkMap.footprint_contains(row, at, margin):
			return false
	return true


# Footprints by CELL_M square, each in every cell its bounding circle (plus MARGIN_MAX) touches, so a
# seat tests only the rows near it: the sinkhole's 339 anchor fields made a flat scan its build's cost.
const CELL_M := 64.0
const MARGIN_MAX := 8.0


static func _cell(at: Vector2) -> Vector2i:
	return Vector2i(floori(at.x / CELL_M), floori(at.y / CELL_M))


func _bucket(row: Dictionary) -> void:
	var centre := ParkMap._v2(row["at"])
	var reach := ParkMap.footprint_half_extents(row).length() + MARGIN_MAX
	var low := _cell(centre - Vector2.ONE * reach)
	var high := _cell(centre + Vector2.ONE * reach)
	for x in range(low.x, high.x + 1):
		for y in range(low.y, high.y + 1):
			var key := Vector2i(x, y)
			if not _cells.has(key):
				_cells[key] = []
			_cells[key].append(row)


# A row's frame in XZ: centre, the run (length) axis and the cross (width) axis, and half sizes.
static func frame(row: Dictionary) -> Dictionary:
	var run := ParkMap._dir(float(row["yaw_deg"]))
	return {"at": ParkMap._v2(row["at"]), "run": run, "cross": Vector2(-run.y, run.x),
		"half_length": float(row["size"][0]) * 0.5, "half_width": float(row["size"][2]) * 0.5}


static func in_clear_view(frame: Dictionary, view: Dictionary, point: Vector2) -> bool:
	var offset := point - Vector2(frame["at"])
	var along := offset.dot(frame["run"])
	var back := -float(frame["half_length"])
	return along <= back and along >= back - float(view["depth_m"]) \
		and absf(offset.dot(frame["cross"])) <= float(view["half_width_m"])


# Up to `count` clear seats beside a row, `out` metres past its side, spread along its run.
# Each seat is {"at", "inward"}: inward points back at the row, so a model can face the ride.
func flank(row: Dictionary, count: int, out: float, rng: RandomNumberGenerator) -> Array:
	var f := frame(row)
	var seats := []
	for k in count:
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var t := rng.randf_range(-0.9, 0.9) * float(f["half_length"])
		var at: Vector2 = f["at"] + f["run"] * t + f["cross"] * side * (float(f["half_width"]) + out)
		if clear(at):
			seats.append({"at": at, "inward": -f["cross"] * side})
	return seats


# A seat's yaw that turns a model's -Z (its front) toward `inward`.
static func yaw_toward(inward: Vector2) -> float:
	return atan2(-inward.x, -inward.y)
