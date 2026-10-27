extends SceneTree

# Rule (scrapkeep#494, flume entry stall): work the stage entry tick used to do goes elsewhere with
# the same result. The activities' worker hands over a graph whose zone member lists are already
# filled, and they are the lists a fresh graph builds on its first read; an enemy's owned materials,
# read through its script's cached variable names, are the ones a full property scan finds, for the
# base enemy and a subclass. No check here is timed.

const T := preload("res://tests/support/t.gd")
const Terrain := preload("res://src/world/terrain.gd")
const Activities := preload("res://src/world/activities.gd")
const ParkGraph := preload("res://src/world/park/park_graph.gd")
const Enemy := preload("res://src/combat/enemy.gd")
const Warden := preload("res://src/combat/warden.gd")

const TABLE := {"DEFS": [{"stage": 1, "world": 1, "map": "park_flume"}]}

var t := T.new("entry_spread_test")


func _initialize() -> void:
	var map = Terrain.new(TABLE).map_for(1)
	var path := Activities.graph_path(String(map.park.map))
	var rows := {"park": map.park.duplicate(true), "activity_sites": map.activity_sites.duplicate(true), "play_rect": map.play_rect}
	var graph = Activities.prepare_data(path, rows, false).graph
	var fresh = ParkGraph.read(path)
	t.check("the flume graph has zones", graph != null and graph.zone_count() > 0)
	t.check("the worker's graph comes with its zone member lists filled", not graph._members.is_empty())
	var same := true
	for z in fresh.zone_count():
		same = same and graph._members[z] == fresh.zone_nodes(z) and graph.zone_door_nodes(z) == fresh.zone_door_nodes(z)
	t.check("they are the lists a fresh graph builds on its first read", same, "%d zones" % fresh.zone_count())

	for script in [Enemy, Warden]:
		var enemy = script.new()
		enemy._material = StandardMaterial3D.new()
		var scanned := []
		for prop in enemy.get_property_list():
			if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE != 0 and enemy.get(prop.name) is StandardMaterial3D:
				scanned.append(enemy.get(prop.name))
		var first: Array = enemy.owned_materials()
		var again: Array = enemy.owned_materials()
		t.check("%s: the cached variable names find the materials a full scan finds" % script.resource_path.get_file(),
			first == scanned and again == scanned and first.has(enemy._material), "%d materials" % first.size())
		t.check("%s: its variable names are read once and kept for the script" % script.resource_path.get_file(),
			Enemy._variables_by_script.has(script) and Enemy._variables_by_script[script].has("_material"))
		enemy.free()
	quit(t.verdict())
