extends SceneTree

const T := preload("res://tests/support/t.gd")
const Bridge := preload("res://src/world/terrain3d_bridge.gd")
const Terrain := preload("res://src/world/terrain.gd")
const Spillway := preload("res://src/world/map_spillway.gd")

# Wave 12 addon probe: both owner-allowed addons load on this engine, and a Spillway region
# built through the bridge carries the same heights the 2 m collider grid carries, with no
# collision of its own.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var t := T.new("addon_load_test")
	t.check("Terrain3D class registered", ClassDB.class_exists("Terrain3D"))
	t.check("Terrain3DTextureAsset class registered", ClassDB.class_exists("Terrain3DTextureAsset"))
	t.check("Proton Scatter script compiles", Bridge.scatter_available())
	var holder := Node3D.new()
	root.add_child(holder)
	var m := Spillway.new()
	var terrain := Bridge.build_terrain(holder, m)
	t.check("region built", terrain != null)
	if terrain != null:
		t.eq("one region set per 512 m quadrant", terrain.data.get_region_count(), 4)
		t.eq("visual only: collision disabled", int(terrain.collision.mode), 0)
		var worst := 0.0
		var at := Vector2.ZERO
		for p in [Vector2(0, 0), Vector2(-46, -12), Vector2(24, 22), Vector2(60, -150), Vector2(-120, 90), Vector2(96, 14), Vector2(10, -84)]:
			var want: float = m.sample(p.x, p.y)[0]
			var got: float = terrain.data.get_height(Vector3(p.x, 0.0, p.y))
			if absf(got - want) > worst:
				worst = absf(got - want)
				at = p
		t.check("region heights match the grid samples", worst < 0.01, "worst %.4f m at %s" % [worst, at])
	var scatter := Bridge.build_scatter(holder, Bridge.LAYERS[0], 0.0)
	t.check("scatter node built", scatter != null)
	holder.queue_free()
	await process_frame
	quit(t.verdict())
