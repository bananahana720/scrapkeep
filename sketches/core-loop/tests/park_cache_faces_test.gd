extends SceneTree

# Every park cracked_cache opens onto ground a ball can reach: the ground out from its open face
# rises no more than RISE_M within NEAR_M, so a cliff never stands across its mouth (a long slope
# up the run-up is fine). The flume's bend_cache took the rule's north face into a 15 m cliff 4 m
# away, and explorer bots that broke it were boxed in at y 30 (24 Oct); its row now faces south
# (activity_rows "face", park_map.gd).
#
# Planted: the bend_cache turned back north fails the same check.

const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")

const NEAR_M := 8.0
const RISE_M := 4.0

var _t := T.new("park_cache_faces_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game = Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	game.ctx.calm = true
	game.flow.force_warden = false
	game.player.source = Intent.Scripted.new()
	game.flow.press_start()
	game.flow.choose_class(1)
	var caches := 0
	for i in game.ctx.terrain.maps.size():
		var m = game.ctx.terrain.maps[i]
		if not "park" in m:
			continue
		var map_id := String(m.park.get("map", ""))
		game.flow.enter_stage(i + 1, Vector3.ZERO, false)
		await physics_frame
		await physics_frame
		for s in game.world.activities.sites:
			if not is_instance_valid(s) or s.id != "cracked_cache":
				continue
			caches += 1
			var face: Vector2 = s.rule["face"]
			var at := Vector2(s.global_position.x, s.global_position.z)
			var rise := _rise(game, at, face)
			_t.check("%s %s opens onto reachable ground" % [map_id, s.name], rise <= RISE_M,
				"ground rises %.1f m within %.0f m of its face %s" % [rise, NEAR_M, face])
			if map_id == "park_flume" and is_equal_approx(face.y, 1.0) and s.global_position.distance_to(Vector3(42.0, s.global_position.y, -136.0)) < 3.0:
				var north := _rise(game, at - face * 12.0, -face)
				_t.check("planted: bend_cache facing north fails", north > RISE_M, "%.1f m" % north)
	_t.check("park caches found", caches >= 10, "%d" % caches)
	quit(_t.verdict())


func _rise(game, at: Vector2, face: Vector2) -> float:
	var y0: float = game.ctx.terrain.height(at.x, at.y)
	var top := -INF
	for d in [2.0, 4.0, 6.0, NEAR_M]:
		var p: Vector2 = at + face * d
		top = maxf(top, game.ctx.terrain.height(p.x, p.y) - y0)
	return top
