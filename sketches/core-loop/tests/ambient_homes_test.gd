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
		for kind in kinds:
			var count := homes.filter(func(h): return h["kind"] == kind).size()
			var spec: Dictionary = AmbientKinds.row(kind)["homes"]
			_t.check("%s %s has homes" % [map_id, kind], count >= 1, "%d (want %d..%d)" % [count, spec["count"][0], spec["count"][1]])
	# A veto rejects homes and members: with the west half vetoed every position stands east, and kinds still get homes.
	var dam: Dictionary = ParkSchema.load_park("res://src/world/park/park_dam.json")["data"]
	var east := AmbientHomes.plan(dam, AmbientKinds.for_park("park_dam"), SEED, func(at: Vector2, _perch: String) -> bool: return at.x < 0.0)
	var west := 0
	for home in east:
		for offset: Vector2 in home["members"]:
			west += 1 if (home["at"] + offset).x < 0.0 else 0
	_t.check("veto keeps every position east (%d homes)" % east.size(), west == 0 and east.size() > 0, "%d west" % west)
	# blocked() really blocks: the spawn and the beacon are inside keepouts.
	var park: Dictionary = ParkSchema.load_park("res://src/world/park/park_dam.json")["data"]
	var keep := AmbientHomes.keepouts(park)
	_t.check("spawn is blocked", AmbientHomes.blocked(keep, Vector2(float(park["spawn"]["at"][0]), float(park["spawn"]["at"][1]))) != "")
	_t.check("beacon is blocked", AmbientHomes.blocked(keep, Vector2(float(park["landmark"]["beacon"][0]), float(park["landmark"]["beacon"][1]))) != "")


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
