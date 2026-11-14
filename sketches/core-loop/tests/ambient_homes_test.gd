extends SceneTree

const AmbientHomes := preload("res://src/presentation/ambient_homes.gd")
const AmbientKinds := preload("res://src/core/ambient_kinds.gd")
const ParkSchema := preload("res://src/world/park/park_schema.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const T := preload("res://tests/support/t.gd")

# Ambient life's home planner (ambient_homes.gd) on all six parks: every home and every member
# position is clear of every keepout (rides, anchor fields, routes, enemy homes, the Warden ring,
# spawn, activities, rescues, contraptions, gate slots), every kind gets a home in each of its
# parks, and the plan is the same twice for a seed. A second reading measures every position straight
# from the park file, without the planner's keepout list, so a keepout it forgets still fails.

const SEED := 20261019

var _t := T.new("ambient_homes_test")


func _initialize() -> void:
	_main()


# A kind with `spots` (the keepers) stands beside the park's crew props first: at least half its homes are within
# SPOT_SIDE_M + 1 m of a prop of a listed template. Planted: a camp 200 m from every home fails the same line.
func _at_camps(map_id: String, kind: String, spec: Dictionary, homes: Array) -> void:
	var props = JSON.parse_string(FileAccess.get_file_as_string("res://src/world/park/props/%s.json" % map_id))
	var camps: Array = (props["spots"] as Array).filter(func(sp): return (spec["spots"] as Array).has(String(sp["template"]))) \
		.map(func(sp): return Vector2(float(sp["at"][0]), float(sp["at"][1])))
	var mine := homes.filter(func(h): return h["kind"] == kind)
	var near := func(points: Array) -> int:
		return mine.filter(func(h): return points.any(func(c: Vector2): return c.distance_to(h["at"]) <= AmbientHomes.SPOT_SIDE_M + 1.0)).size()
	var at_camp: int = near.call(camps)
	print("[camps] %s %s: %d of %d homes at a crew prop (%d props)" % [map_id, kind, at_camp, mine.size(), camps.size()])
	_t.check("%s %s: at least half its homes stand at the crew props" % [map_id, kind], at_camp * 2 >= mine.size(), "%d of %d" % [at_camp, mine.size()])
	var far: Array = mine.map(func(h): return (h["at"] as Vector2) + Vector2(200.0, 0.0))
	_t.check("planted: %s camps moved 200 m away hold none of its homes" % map_id, near.call(far) == 0)


func _main() -> void:
	await process_frame
	_run()
	quit(_t.verdict())


func _run() -> void:
	for map_id in ParkSchema.MAP_STAGE:
		if map_id == "park_test":
			continue
		var loaded := ParkSchema.load_park("res://src/world/park/%s.json" % map_id)
		_t.check(map_id + " loads", loaded["errors"].is_empty(), ParkSchema.describe(loaded["errors"]))
		var park: Dictionary = loaded["data"]
		var kinds := AmbientKinds.for_park(map_id)
		var homes := AmbientHomes.plan(park, kinds, SEED)
		var keep := AmbientHomes.keepouts(park)
		var again := AmbientHomes.plan(park, kinds, SEED)
		_t.check(map_id + " deterministic", var_to_str(homes) == var_to_str(again))
		_t.check(map_id + " seed changes the plan", var_to_str(homes) != var_to_str(AmbientHomes.plan(park, kinds, SEED + 1)))
		var bad := []
		var positions := 0
		for home in homes:
			for offset: Vector2 in home["members"]:
				positions += 1
				var what := AmbientHomes.blocked(keep, home["at"] + offset)
				if what != "":
					bad.append("%s %s blocked by %s" % [home["kind"], home["at"] + offset, what])
		_t.check(map_id + " %d homes, %d positions clear" % [homes.size(), positions], bad.is_empty(), str(bad.slice(0, 3)))
		_direct(map_id, park, homes)
		_check_grid(map_id, park, keep)
		for kind in kinds:
			var count := homes.filter(func(h): return h["kind"] == kind).size()
			var spec: Dictionary = AmbientKinds.row(kind)["homes"]
			_t.check("%s %s has homes" % [map_id, kind], count >= 1, "%d (want %d..%d)" % [count, spec["count"][0], spec["count"][1]])
			if spec.has("spots"):
				_at_camps(map_id, kind, spec, homes)
	# A veto rejects homes and members: with the west half vetoed every position stands east, and kinds still get homes.
	var dam: Dictionary = ParkSchema.load_park("res://src/world/park/park_dam.json")["data"]
	var east := AmbientHomes.plan(dam, AmbientKinds.for_park("park_dam"), SEED, func(at: Vector2, _perch: String) -> bool: return at.x < 0.0)
	var west := 0
	for home in east:
		for offset: Vector2 in home["members"]:
			west += 1 if (home["at"] + offset).x < 0.0 else 0
	var east_kinds := {}
	for home in east:
		east_kinds[home["kind"]] = true
	_t.check("veto keeps every position east (%d homes)" % east.size(), west == 0 and east.size() > 0, "%d west" % west)
	_t.eq("every park_dam kind still has an east home", east_kinds.size(), AmbientKinds.for_park("park_dam").size())
	# blocked() really blocks: the spawn and the beacon are inside keepouts.
	var park: Dictionary = ParkSchema.load_park("res://src/world/park/park_dam.json")["data"]
	var keep := AmbientHomes.keepouts(park)
	_t.check("spawn is blocked", AmbientHomes.blocked(keep, Vector2(float(park["spawn"]["at"][0]), float(park["spawn"]["at"][1]))) != "")
	_t.check("beacon is blocked", AmbientHomes.blocked(keep, Vector2(float(park["landmark"]["beacon"][0]), float(park["landmark"]["beacon"][1]))) != "")


# The plan asks blocked() through a cell grid of the keepouts (_blocked_near): it must answer as blocked() does,
# keepout name and all, at points all over the park and on keepout edges, where a cell boundary would show.
func _check_grid(map_id: String, park: Dictionary, keep: Array) -> void:
	var near := AmbientHomes._keep_grid(keep)
	var rect := AmbientHomes._rect(park)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var points: Array[Vector2] = []
	for i in 4000:
		points.append(Vector2(rng.randf_range(rect.position.x, rect.end.x), rng.randf_range(rect.position.y, rect.end.y)))
	for k in keep:
		var centre: Vector2 = k["points"][0] if k["shape"] == "line" else k["centre"]
		var r: float = float(k.get("radius", k.get("reach", 0.0)))
		for a in 16:
			points.append(centre + Vector2.from_angle(TAU * a / 16.0) * r * rng.randf_range(0.97, 1.03))
	var differ := []
	var held := 0
	for p in points:
		var want := AmbientHomes.blocked(keep, p)
		held += 1 if want != "" else 0
		if AmbientHomes._blocked_near(near, p) != want:
			differ.append("%s: %s / %s" % [p, AmbientHomes._blocked_near(near, p), want])
	_t.check("%s the keepout grid answers as blocked() at %d points (%d blocked)" % [map_id, points.size(), held],
		differ.is_empty() and held > 0, str(differ.slice(0, 3)))


# A second reading that skips the planner's keepout list: each position measured straight from the park file
# against every ride row (6 m), anchor field (8 m), enemy home site (25 m from its centre), the Warden beacon
# (its reach) and the spawn (12 m). Mesa-edge kickers are excluded the same way the planner excludes them.
func _direct(map_id: String, park: Dictionary, homes: Array) -> void:
	var sites := {}
	for row in park["park_rows"]:
		sites[row["id"]] = row
	var bad := []
	var rides := 0
	for home in homes:
		for offset: Vector2 in home["members"]:
			var p: Vector2 = home["at"] + offset
			for row in park["park_rows"]:
				var element := String(row["element"])
				var margin := -1.0
				if element == "anchor_field":
					margin = AmbientHomes.ANCHOR_M
				elif AmbientHomes.RIDE_ELEMENTS.has(element) and not ParkMap.mesa_edge(row, AmbientHomes._rect(park)):
					margin = AmbientHomes.RIDE_M
				if margin > 0.0:
					rides += 1
					if ParkMap.footprint_contains(row, p, margin):
						bad.append("%s in %s" % [home["kind"], row["id"]])
			for enemy in park["home_rows"]:
				if sites.has(enemy["site"]):
					var c: Array = sites[enemy["site"]]["at"]
					if p.distance_to(Vector2(float(c[0]), float(c[1]))) < AmbientHomes.ENEMY_HOME_M:
						bad.append("%s near enemy home %s" % [home["kind"], enemy["id"]])
			var beacon: Array = park["landmark"]["beacon"]
			if p.distance_to(Vector2(float(beacon[0]), float(beacon[1]))) < float(park["landmark"]["reach_m"]):
				bad.append("%s in the Warden reach" % home["kind"])
			var spawn: Array = park["spawn"]["at"]
			if p.distance_to(Vector2(float(spawn[0]), float(spawn[1]))) < AmbientHomes.SPOT_M:
				bad.append("%s at the spawn" % home["kind"])
	_t.check("%s measured straight from the park file: clear of rides, anchors, enemy homes, reach, spawn" % map_id, bad.is_empty() and rides > 0, str(bad.slice(0, 3)))
