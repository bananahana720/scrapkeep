extends SceneTree

const T := preload("res://tests/support/t.gd")
const Cache := preload("res://src/world/cracked_cache.gd")
const GameEvents := preload("res://src/core/game_events.gd")


class RunStub:
	extends RefCounted
	func add_part(_id: String, _from: String) -> void: pass


class CtxStub:
	extends RefCounted
	var events
	var run := RunStub.new()

# VX-CACHE-RECT: a non-relic cache's 6 m lane offset is taken only inside the play rect on level ground.


func _initialize() -> void:
	var t := T.new("cache_lane_rect_test")
	var rect := Rect2(-50.0, -50.0, 100.0, 100.0)
	var flat := func(_x: float, _z: float) -> float: return 0.0
	var slope := func(x: float, _z: float) -> float: return x * 0.8
	t.check("inside the rect on flat ground the lane is used", Cache.lane_clear(rect, Vector3(0.0, 0.0, 0.0), flat))
	t.check("a lane spot outside the play rect is refused", not Cache.lane_clear(rect, Vector3(60.0, 0.0, 0.0), flat))
	t.check("a lane spot inside the rim margin is refused", not Cache.lane_clear(rect, Vector3(48.0, 0.0, 0.0), flat))
	t.check("a lane spot on a steep face is refused", not Cache.lane_clear(rect, Vector3(0.0, 0.0, 0.0), slope))
	# Taking an offer publishes the spent fact at the cache (VX-FX's ember effect keys on it).
	var events := GameEvents.new()
	var heard := []
	events.world_fact.connect(func(kind: String, at: Vector3) -> void: heard.append([kind, at]))
	var cache := Cache.new()
	var ctx := CtxStub.new()
	ctx.events = events
	cache.ctx = ctx
	cache.offers = ["x"]
	root.add_child(cache)
	await process_frame
	cache.position = Vector3(3.0, 0.0, 4.0)
	cache.take(0)
	t.check("take() marks the cache spent and publishes cache_spent at it", cache.spent and heard == [["cache_spent", Vector3(3.0, 0.0, 4.0)]], str(heard))
	cache.free()
	events.free()
	quit(t.verdict())
