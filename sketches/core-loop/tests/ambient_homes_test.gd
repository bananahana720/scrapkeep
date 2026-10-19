extends SceneTree

const AmbientHomes := preload("res://src/presentation/ambient_homes.gd")
const AmbientKinds := preload("res://src/core/ambient_kinds.gd")
const ParkSchema := preload("res://src/world/park/park_schema.gd")
const T := preload("res://tests/support/t.gd")

# Ambient life's home planner (ambient_homes.gd) on all six parks: every home and every member
# position is clear of every keepout (rides, anchor fields, routes, enemy homes, the Warden ring,
# spawn, activities, rescues, contraptions, gate slots), every kind gets a home in each of its
# parks, and the plan is the same twice for a seed.

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
		for kind in kinds:
			var count := homes.filter(func(h): return h["kind"] == kind).size()
			var spec: Dictionary = AmbientKinds.row(kind)["homes"]
			_t.check("%s %s has homes" % [map_id, kind], count >= 1, "%d (want %d..%d)" % [count, spec["count"][0], spec["count"][1]])
	# blocked() really blocks: the spawn and the beacon are inside keepouts.
	var park: Dictionary = ParkSchema.load_park("res://src/world/park/park_dam.json")["data"]
	var keep := AmbientHomes.keepouts(park)
	_t.check("spawn is blocked", AmbientHomes.blocked(keep, Vector2(float(park["spawn"]["at"][0]), float(park["spawn"]["at"][1]))) != "")
	_t.check("beacon is blocked", AmbientHomes.blocked(keep, Vector2(float(park["landmark"]["beacon"][0]), float(park["landmark"]["beacon"][1]))) != "")
