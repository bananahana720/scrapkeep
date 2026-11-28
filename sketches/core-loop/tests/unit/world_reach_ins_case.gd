extends RefCounted

const EventGround := preload("res://src/world/events/event_ground.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const ParkSchema := preload("res://src/world/park/park_schema.gd")
const Placement := preload("res://src/world/park/park_placement.gd")
const Gorge := preload("res://src/world/map_gorge.gd")

const ALLOWED_TERRAIN_REACH_INS: Array[String] = []
const ALLOWED_EVENT_GROUND_REACH_INS: Array[String] = []
const ALLOWED_PARK_MAP_REACH_INS: Array[String] = []
const ALLOWED_PARK_SCHEMA_REACH_INS: Array[String] = []
const ALLOWED_PARK_RECIPES_REACH_INS: Array[String] = []
const ALLOWED_PLACEMENT_REACH_INS: Array[String] = []
const ALLOWED_SCREENS_PRESS_REACH_INS: Array[String] = []
const ALLOWED_POLYLINE_CHANNEL_REACH_INS: Array[String] = []
const ALLOWED_DIRECTOR_FAMILIES_REACH_INS: Array[String] = []


func _gd_files(root: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(root)
	if dir == null:
		return out
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.begins_with("."):
			name = dir.get_next()
			continue
		var full := root.path_join(name)
		if dir.current_is_dir():
			out.append_array(_gd_files(full))
		elif name.ends_with(".gd"):
			out.append(full)
		name = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out


func _offenders(root: String, pattern: String, owner: String, allowed: Array[String]) -> Array[String]:
	var re := RegEx.new()
	re.compile(pattern)
	var out: Array[String] = []
	for path in _gd_files(root):
		if path == owner or allowed.has(path):
			continue
		if re.search(FileAccess.get_file_as_string(path)) != null:
			out.append(path)
	return out


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

	t.eq("no terrain._ reach-ins outside terrain.gd",
		_offenders("res://src", "terrain\\._[a-z]", "res://src/world/terrain.gd", ALLOWED_TERRAIN_REACH_INS), [])
	t.eq("no EventGround._ reach-ins outside event_ground.gd",
		_offenders("res://src", "EventGround\\._[a-z]", "res://src/world/events/event_ground.gd", ALLOWED_EVENT_GROUND_REACH_INS), [])
	t.eq("no ParkMap._ reach-ins outside park_map.gd",
		_offenders("res://src", "ParkMap\\._[a-z]", "res://src/world/park/park_map.gd", ALLOWED_PARK_MAP_REACH_INS), [])
	t.eq("no ParkSchema._ reach-ins outside park_schema.gd",
		_offenders("res://src", "ParkSchema\\._[a-z]", "res://src/world/park/park_schema.gd", ALLOWED_PARK_SCHEMA_REACH_INS), [])
	t.eq("no ParkRecipes._ or Recipes._ reach-ins outside park_recipes.gd",
		_offenders("res://src", "(?<![A-Za-z0-9_])(?:ParkRecipes|Recipes)\\._[a-z]", "res://src/world/park/park_recipes.gd", ALLOWED_PARK_RECIPES_REACH_INS), [])
	t.eq("no Placement._ reach-ins outside park_placement.gd",
		_offenders("res://src", "Placement\\._[a-z]", "res://src/world/park/park_placement.gd", ALLOWED_PLACEMENT_REACH_INS), [])
	t.eq("no screens._press reach-ins in src/",
		_offenders("res://src", "screens\\._press\\b", "", ALLOWED_SCREENS_PRESS_REACH_INS), [])
	t.eq("no _polyline_channel outside map_gorge.gd",
		_offenders("res://src", "_polyline_channel", "res://src/world/map_gorge.gd", ALLOWED_POLYLINE_CHANNEL_REACH_INS), [])
	t.eq("no director._park_families reach-ins in src/",
		_offenders("res://src", "director\\._park_families", "", ALLOWED_DIRECTOR_FAMILIES_REACH_INS), [])
