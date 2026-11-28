extends RefCounted

const EventGround := preload("res://src/world/events/event_ground.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const ParkSchema := preload("res://src/world/park/park_schema.gd")
const Placement := preload("res://src/world/park/park_placement.gd")
const Gorge := preload("res://src/world/map_gorge.gd")
const SourceScan := preload("res://tests/support/source_scan.gd")


func run(t) -> void:
	t.eq("EventGround.rectangle returns four corners",
		EventGround.rectangle(Vector2(-1.0, -2.0), Vector2(3.0, 4.0)),
		[Vector2(-1.0, -2.0), Vector2(3.0, -2.0), Vector2(3.0, 4.0), Vector2(-1.0, 4.0)])
	t.eq("ParkMap.v2 converts a 2-element array", ParkMap.v2([3.0, -4.0]), Vector2(3.0, -4.0))
	t.near("ParkMap.yaw_dir(90) x", ParkMap.yaw_dir(90.0).x, 1.0, 0.0001)
	t.near("ParkMap.yaw_dir(90) y", ParkMap.yaw_dir(90.0).y, 0.0, 0.0001)
	t.check("ParkSchema.is_vec accepts matching numeric array", ParkSchema.is_vec([1, 2.5], 2))
	t.check("ParkSchema.is_vec rejects wrong length", not ParkSchema.is_vec([1], 2))
	t.eq("ParkSchema.lead_floor for flood_fill",
		ParkSchema.lead_floor({"family": "natural", "kind": "flood_fill", "effect": {}}),
		ParkSchema.LEAD_GROUND_S)
	t.check("Placement.within checks rarities", Placement.within(["common"], Placement.PAY_ONLINE))
	t.check("Placement.within rejects disallowed rarity", not Placement.within(["rare"], Placement.PAY_ONLINE))
	t.eq("Placement.pay reads rarities", Placement.pay({"rarities": ["rare"]}), {"rarities": ["rare"], "named": ""})

	var gorge := Gorge.new()
	var start: Vector3 = gorge.marble_path[0]
	t.check("Gorge.in_marble_chute is true on marble_path start", gorge.in_marble_chute(start.x, start.z))
	t.check("Gorge.in_marble_chute is false far off marble_path", not gorge.in_marble_chute(190.0, 190.0))

	var src: Array[String] = ["res://src"]
	t.eq("no terrain._ reach-ins in src/",
		SourceScan.matching(t, src, "terrain\\._[a-z]"), [])
	t.eq("no EventGround._ reach-ins in src/",
		SourceScan.matching(t, src, "EventGround\\._[a-z]"), [])
	t.eq("no ParkMap._ reach-ins in src/",
		SourceScan.matching(t, src, "ParkMap\\._[a-z]"), [])
	t.eq("no ParkSchema._ reach-ins in src/",
		SourceScan.matching(t, src, "(?:ParkSchema|park_schema\\.gd\"\\))\\._[a-z]"), [])
	t.eq("no ParkRecipes._ or Recipes._ reach-ins in src/",
		SourceScan.matching(t, src, "(?<![A-Za-z0-9_])(?:ParkRecipes|Recipes)\\._[a-z]"), [])
	t.eq("no Placement._ reach-ins in src/",
		SourceScan.matching(t, src, "Placement\\._[a-z]"), [])
	t.eq("no screens._press reach-ins in src/",
		SourceScan.matching(t, src, "screens\\._press\\b"), [])
	t.eq("only map_gorge.gd names _polyline_channel in src/",
		SourceScan.matching(t, src, "_polyline_channel"), ["res://src/world/map_gorge.gd"])
	t.eq("no director._park_families reach-ins in src/",
		SourceScan.matching(t, src, "director\\._park_families"), [])
	t.eq("only sim_clock.gd declares threaded_in_bot_runs",
		SourceScan.matching(t, ["res://src", "res://tools", "res://tests"], "(?m)^\\s*(?:static\\s+)?var\\s+threaded_in_bot_runs\\b"),
		["res://src/core/sim_clock.gd"])
