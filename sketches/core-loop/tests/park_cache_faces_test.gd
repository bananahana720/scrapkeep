extends SceneTree

# Every park cracked_cache opens onto ground a ball can reach, and no cliff can drop a ball into it:
#   face  the ground out from its open face rises no more than RISE_M within NEAR_M, so a cliff never
#         stands across its mouth (a long slope up the run-up is fine).
#   back  the ground behind its back wall rises no more than RISE_M within BACK_M, so a ball rolling
#         off a ledge above never lands inside the open-topped room, where its walls box it in.
# The flume's bend_cache failed both (24 Oct): it took the rule's north face into a 15 m cliff 4 m
# away, and then, faced south, still stood at that cliff's foot, so explorer bots that rolled off
# the top landed in the room at y 30. Its row now faces south (activity_rows "face", park_map.gd)
# and stands at [42, -96], beyond the reach of a ball launched off the cliff top at speed.
#
# Planted: the bend_cache back at its old spot fails both checks.

const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Activities := preload("res://src/world/activities.gd")

const NEAR_M := 8.0
const RISE_M := 4.0
const BACK_M := 20.0
# The bend_cache's old room: the site [42, -142] moved CACHE_LANE_OFFSET out along its south face.
const OLD_BEND := Vector2(42.0, -136.0)

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
			# The park's own cracked_cache rows and the field finds; other caches draw their spots per run.
			if not is_instance_valid(s) or s.id != "cracked_cache" or not (s.has_meta("find") or _authored(m, s)):
				continue
			caches += 1
			var face: Vector2 = s.rule["face"]
			var at := Vector2(s.global_position.x, s.global_position.z)
			var rise := _rise(game, at, face)
			_t.check("%s %s opens onto reachable ground" % [map_id, s.name], rise <= RISE_M,
				"ground rises %.1f m within %.0f m of its face %s" % [rise, NEAR_M, face])
			var back := _back_rise(game, at, face)
			_t.check("%s %s stands clear of a ledge above" % [map_id, s.name], back <= RISE_M,
				"ground rises %.1f m within %.0f m behind its back wall" % [back, BACK_M])
		if map_id == "park_flume":
			var south := Vector2(0.0, 1.0)
			var north := _rise(game, OLD_BEND - south * 12.0, -south)
			_t.check("planted: the old bend_cache facing north fails", north > RISE_M, "%.1f m" % north)
			var under := _back_rise(game, OLD_BEND, south)
			_t.check("planted: the old bend_cache under the cliff fails", under > RISE_M, "%.1f m" % under)
	_t.check("park caches found", caches >= 8, "%d" % caches)
	quit(_t.verdict())


func _rise(game, at: Vector2, face: Vector2) -> float:
	var y0: float = game.ctx.terrain.height(at.x, at.y)
	var top := -INF
	for d in [2.0, 4.0, 6.0, NEAR_M]:
		var p: Vector2 = at + face * d
		top = maxf(top, game.ctx.terrain.height(p.x, p.y) - y0)
	return top


# The rise behind the back wall, from the room's floor at its face.
func _back_rise(game, at: Vector2, face: Vector2) -> float:
	var y0: float = game.ctx.terrain.height(at.x, at.y)
	var wall := at - face * (Activities.WALL_DEPTH + 0.5)
	var top := -INF
	for d in [0.0, 4.0, 8.0, 12.0, 16.0, BACK_M]:
		var p: Vector2 = wall - face * d
		top = maxf(top, game.ctx.terrain.height(p.x, p.y) - y0)
	return top


func _authored(m, s) -> bool:
	var at := Vector2(s.global_position.x, s.global_position.z)
	for row in m.activity_sites:
		if String(row["id"]) == "cracked_cache" and Vector2(row["at"]).distance_to(at) < 10.0:
			return true
	return false
