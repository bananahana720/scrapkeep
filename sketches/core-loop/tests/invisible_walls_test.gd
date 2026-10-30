extends SceneTree

const Game := preload("res://src/game.gd")
const CampHub := preload("res://src/world/camp_hub.gd")
const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const T := preload("res://tests/support/t.gd")

# Invisible walls found by tools/qa/collision_sweep.gd (30 Oct, Andrew's first sitting):
#   - a solid camp prop collides as a hull of its first mesh up to SOLID_TOP_M, not a box round the whole mesh: each
#     cottonwood's box took its crown down to the ground, 8.4 x 6.6 m round a 1.2 m trunk;
#   - a waisted anchor post (hoodoo a, size 10) splits its upper column, so no one hull spans the narrow neck under the cap.

var _t := T.new("invisible_walls_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game = Game.new()
	game.test_mode = true
	root.add_child(game)
	while game.flow == null:
		await process_frame
	var hub = game.camp_hub
	hub.ensure_built()
	var trees := 0
	for holder: Node in hub.root.get_children():
		if not String(holder.name).contains("Node3D") and not String(holder.name).begins_with("Prop_cottonwood"):
			continue
		var body := holder.get_node_or_null("Collider") as StaticBody3D
		if body == null or not holder.has_node("cottonwood_Trunk"):
			continue
		trees += 1
		var shape := (body.get_child(0) as CollisionShape3D).shape
		_t.check("a cottonwood collides as a hull (%s)" % holder.name, shape is ConvexPolygonShape3D, str(shape))
		if not shape is ConvexPolygonShape3D:
			continue
		var lo := Vector3(INF, INF, INF)
		var hi := -lo
		var mid := PackedVector3Array()
		for p: Vector3 in (shape as ConvexPolygonShape3D).points:
			lo = lo.min(p)
			hi = hi.max(p)
			if p.y > 1.5:
				mid.append(p)
		var trunk_r := 0.0
		for p in mid:
			trunk_r = maxf(trunk_r, Vector2(p.x, p.z).distance_to(Vector2(0.24, 0.05)))
		_t.check("%s: hull reaches SOLID_TOP_M and no higher (%.2f m)" % [holder.name, hi.y], absf(hi.y - CampHub.SOLID_TOP_M) < 0.01)
		_t.check("%s: above the root flare the hull is the trunk (widest %.2f m from its axis, want < 1.2)" % [holder.name, trunk_r],
			not mid.is_empty() and trunk_r < 1.2)
	_t.eq("six cottonwoods checked", trees, 6)
	var jukebox: Node = hub.piece("moss_jukebox")
	var jb := jukebox.get_node_or_null("Collider") as StaticBody3D if jukebox != null else null
	var jshape: Shape3D = (jb.get_child(0) as CollisionShape3D).shape if jb != null and jb.get_child_count() > 0 else null
	var jtop := -INF
	if jshape is ConvexPolygonShape3D:
		for p: Vector3 in (jshape as ConvexPolygonShape3D).points:
			jtop = maxf(jtop, p.y)
	_t.check("the jukebox cabinet stays solid to its top (%.2f m, cabinet 2.6 m)" % jtop, jtop > 2.5)

	var row := {"id": "hoodoo_1", "recipe": "anchor_hoodoo", "size": [283, 10, 273]}
	var fit := ParkRecipes.anchor_fit_boxes(row)
	var upper := fit.filter(func(b): return float(b["h"][0]) >= 2.0)
	_t.check("hoodoo a at size 10 splits its upper column (%d bands)" % upper.size(), upper.size() >= 2)
	var widest := 0.0
	var narrowest := INF
	for b: Dictionary in upper:
		var area := (float(b["x"][1]) - float(b["x"][0])) * (float(b["z"][1]) - float(b["z"][0]))
		widest = maxf(widest, area)
		narrowest = minf(narrowest, area)
	_t.check("its neck band is under half the widest band's footprint (%.1f of %.1f m2)" % [narrowest, widest], narrowest < 0.5 * widest)
	var hulls := ParkRecipes.anchor_hulls(row, fit)
	_t.eq("one hull per band", hulls.size(), fit.size())
	game.free()
	quit(_t.verdict())
