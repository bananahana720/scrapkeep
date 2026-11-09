extends SceneTree
# smoke: timeout=360s

# The scrap trail on the real dam and flume (ruling cd; the lay-out rules are scrap_trail_test's). The real Game on the
# park table, calm, no Warden; each of stages 1 and 2 entered and left to build its park rows, then read:
#   field     the scrap field holds the trail's pieces and nothing else: no gears, and no fabricator hoop stands;
#   count     80 to 130 pieces (96 on the dam and 106 on the flume when written: 1.38 km and 1.71 km of line);
#   seated    every piece floats 1.4 m over the surface a ray finds under it (the ground: a kicker ramp built over the
#             ground is a gap in the trail), and no collider but the ground's own lip reaches into it;
#   planted   on the flume, the same read on a trail with its gaps taken out finds the pieces a plate kicker buries, so
#             the gaps are what keeps them out (the dam's kickers are stamped ground and its trail has no gaps).

const Game := preload("res://src/game.gd")
const ScrapField := preload("res://src/build/scrap_field.gd")
const T := preload("res://tests/support/t.gd")

const OVER := ScrapField.TRAIL_OVER_GROUND
const SEAT_SLACK_M := 0.5
const PIECE_RADIUS_M := 0.6
const BUILD_TICKS := 900

var t := T.new("park_scrap_trail_test")
var game


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	game = Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	game.ctx.calm = true
	game.flow.force_warden = false
	game.flow.press_start()
	game.flow.choose_class(1)
	for stage in [1, 2]:
		game.flow.enter_stage(stage, Vector3.ZERO, false)
		var terrain = game.ctx.terrain
		for i in BUILD_TICKS:
			await physics_frame
			if i > 30 and terrain.rows_ready(stage):
				break
		var title: String = terrain.map_for(stage).title
		if not t.check("%s: the park rows are built" % title, terrain.rows_ready(stage)):
			continue
		var trail: Dictionary = terrain.scrap_trail(stage)
		var ground := func(x: float, z: float) -> float: return terrain.height(x, z)
		var spots := ScrapField.trail_spots(trail, ground)
		var field = game.build.scrap
		t.check("%s: the field holds the trail and nothing else" % title,
			field.count() == spots.size() and field.cog_count() == 0 and field.panel_count() == field.cache_count(),
			"%d pieces for %d spots, %d gears" % [field.count(), spots.size(), field.cog_count()])
		t.eq("%s: no fabricator hoop stands" % title, game.build.fabricators.records().size(), 0)
		t.check("%s: 80 to 130 pieces" % title, spots.size() >= 80 and spots.size() <= 130, str(spots.size()))
		t.eq("%s: every piece is seated on open ground" % title, _unseated(spots), [])
		if (trail["gaps"] as Array).is_empty():
			continue
		var bare := trail.duplicate()
		bare["gaps"] = []
		var buried := _unseated(ScrapField.trail_spots(bare, ground))
		t.check("%s: planted, a trail with no gaps buries pieces in a kicker" % title,
			buried.any(func(row: String) -> bool: return row.contains("kicker")), str(buried))
	quit(t.verdict())


# The pieces that are not 1.4 m over the surface under them, or that a built collider reaches into: "(x, z) why".
func _unseated(spots: Array[Vector3]) -> Array:
	var space := root.get_world_3d().direct_space_state
	var ball := SphereShape3D.new()
	ball.radius = PIECE_RADIUS_M
	var out := []
	for spot in spots:
		var at := spot + Vector3.UP * OVER
		var where := "(%.0f, %.0f)" % [at.x, at.z]
		var under := space.intersect_ray(PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * (OVER + 6.0)))
		if under.is_empty():
			out.append(where + " no surface under it")
		elif absf(at.y - under["position"].y - OVER) > SEAT_SLACK_M:
			out.append("%s %.1f m over %s" % [where, at.y - under["position"].y, under["collider"].get_parent().name])
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = ball
		query.transform = Transform3D(Basis(), at)
		for hit in space.intersect_shape(query, 4):
			out.append("%s inside %s" % [where, hit["collider"].get_parent().name])
	return out
