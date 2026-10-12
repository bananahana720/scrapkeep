extends SceneTree

const Sight := preload("res://tests/park_landmark_sight_test.gd")
const GraphTool := preload("res://tools/park_graph.gd")
const Schema := preload("res://src/world/park/park_schema.gd")

func _initialize() -> void:
	var map_id := preload("res://tools/blender/wgen/context.gd").install()
	var park: Dictionary = Schema.load_park("res://src/world/park/%s.json" % map_id)["data"]
	var bake := GraphTool.load_bake("res://assets/park/%s" % map_id)
	var ground: PackedFloat32Array = bake["ground"]
	var a: Array = park["landmark"]["sight_top"]
	var target := Vector3(float(a[0]), float(a[1]), float(a[2]))
	print("wgen: sight target %s, ground under target %.6f m, target clearance %.6f m" % [target, Sight.height(ground, target.x, target.z), target.y - Sight.height(ground, target.x, target.z)])
	for pair in [park["spawn"]["at"], [-600, 600], [600, 600]]:
		var start := Vector3(float(pair[0]), Sight.height(ground, float(pair[0]), float(pair[1])) + Sight.EYE_M, float(pair[1]))
		var length := Vector2(target.x - start.x, target.z - start.z).length()
		for step in range(1, floori(length / Sight.SAMPLE_M) + 1):
			var d: float = step * Sight.SAMPLE_M
			if d >= length:
				break
			var p := start.lerp(target, d / length)
			var h := Sight.height(ground, p.x, p.z)
			if h > p.y:
				print("wgen: first sight occluder from %s: at %s, ground %.6f m, ray %.6f m, %.3f m before target" % [pair, p, h, p.y, length-d])
				break
	# These are counterfactual probes, not edited parks or passing acceptance results.
	for lift in [1.0, 2.0, 4.0, 8.0]:
		var hypothetical: Dictionary = park.duplicate(true)
		hypothetical["landmark"]["sight_top"][1] = target.y + lift
		var result := Sight.measure(hypothetical, ground, bake["holes"])
		print("wgen: hypothetical sight target +%.1f m: share %.4f (%d/%d); original stage unchanged" % [lift, result["share"], result["clear"], result["counted"]])
	quit(0)
