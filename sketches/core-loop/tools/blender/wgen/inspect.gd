extends SceneTree

const Density := preload("res://tests/park_density_test.gd")
const Sight := preload("res://tests/park_landmark_sight_test.gd")
const Graph := preload("res://src/world/park/park_graph.gd")
const GraphTool := preload("res://tools/park_graph.gd")
const Schema := preload("res://src/world/park/park_schema.gd")

func _initialize() -> void:
	var map_id := preload("res://tools/blender/wgen/context.gd").install()
	var park := Schema.load_park("res://src/world/park/%s.json" % map_id)
	assert(park["errors"].is_empty())
	var graph = Graph.read("res://assets/park/%s/graph.bin" % map_id)
	assert(graph != null)
	var bake := GraphTool.load_bake("res://assets/park/%s" % map_id)
	assert(bake["errors"].is_empty())
	var density := Density.measure(graph, Density.counted_rows(park["data"]))
	var sight := Sight.measure(park["data"], bake["ground"], bake["holes"])
	print("wgen: [density] %s worst %.4f m, over 80 m %d/%d; %s" % [map_id, density["worst"], density["over"], density["open"], "PASS" if density["worst"] <= Density.DENSITY_M else "FAIL"])
	print("wgen: [sight] %s share %.4f (%d/%d), need %.2f; %s" % [map_id, sight["share"], sight["clear"], sight["counted"], park["data"]["landmark"]["sight_share"], "PASS" if sight["share"] >= park["data"]["landmark"]["sight_share"] else "FAIL"])
	quit(0 if density["worst"] <= Density.DENSITY_M and sight["share"] >= park["data"]["landmark"]["sight_share"] else 1)
