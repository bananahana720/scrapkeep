extends SceneTree

const Game := preload("res://src/game.gd")
const Panels := preload("res://src/build/panels.gd")
const T := preload("res://tests/support/t.gd")

# IL-01 rib caches on the real Spillway (park table, stage 1, park_dam):
# 1. Panels.RIB_CACHES panels wait on the ground once the stage is in play, each in an
#    off-spine dead end (director.off_spine), apart from each other and from the spawn.
# 2. Each carries its tell: the tall column and the chime loop.
# 3. A retry puts back the same caches at the same spots, never a second set.
# 4. Rolling onto one takes it as a panel.
# 5. A park row tagged off_spine (the dam's lobber ledge, ruling bc) reads off the spine whatever the graph says.
# smoke: solo timeout=240s

const WAIT_TICKS := 600

var _t := T.new("panels_rib_cache_test")
var _game


func _initialize() -> void:
	_run()


func _run() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "park"
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.flow.press_start()
	_game.flow.choose_class(1)
	var scrap = _game.build.scrap
	for i in WAIT_TICKS:
		await physics_frame
		if scrap.cache_count() > 0:
			break
	var caches: Array = scrap.caches()
	_t.eq("three caches wait", caches.size(), Panels.RIB_CACHES)
	var director = _game.ctx.root.get_node("World").director
	# Ruling bc: the lobber ledge is tagged off-spine, so its kills keep the rib rate though the cliff fill opened a drop in.
	_t.eq("the tagged lobber ledge reads off the spine", director.off_spine(Vector3(-185.0, _game.ctx.terrain.height(-185.0, 455.0), 455.0)), 1)
	var spawn: Vector3 = _game.player.ball_position()
	var apart := true
	for c in caches:
		_t.check("cache off the spine (%s)" % c["id"], director.off_spine(c["at"]) == 1, str(c["at"]))
		_t.check("cache far from the spawn (%s)" % c["id"], c["at"].distance_to(spawn) > 40.0, "%.0f m" % c["at"].distance_to(spawn))
		_t.check("cache holds a panel", Panels.ROWS.has(c["id"]), c["id"])
		var item: Node3D = c["item"]
		var column: MeshInstance3D = item.get_child(0)
		_t.check("tall column tell", column.mesh.get_aabb().size.y >= 10.0, "%.1f m" % column.mesh.get_aabb().size.y)
		_t.check("chime tell", item.get_node_or_null("CacheChime") is AudioStreamPlayer3D, "CacheChime")
		for d in caches:
			if d != c and c["at"].distance_to(d["at"]) < 10.0:
				apart = false
	_t.check("caches stand apart", apart, "%d caches" % caches.size())
	var before := caches.map(func(c): return [c["at"].snapped(Vector3.ONE * 0.01), c["id"]])
	_game.flow.retry_stage()
	for i in 30:
		await physics_frame
	var after: Array = scrap.caches().map(func(c): return [c["at"].snapped(Vector3.ONE * 0.01), c["id"]])
	_t.eq("retry puts back the same caches", after, before)
	_t.eq("panels before the take", _game.run.panels.size(), 0)
	var target: Vector3 = scrap.caches()[0]["at"]
	_game.player.reset_to(target + Vector3.UP * 1.5)
	for i in 30:
		await physics_frame
		if _game.run.panels.size() > 0:
			break
	_t.eq("rolling onto a cache takes it", _game.run.panels.size(), 1)
	_t.eq("one cache left behind fewer", scrap.cache_count(), Panels.RIB_CACHES - 1)
	_game.free()
	quit(_t.verdict())
