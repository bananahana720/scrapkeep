extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const T := preload("res://tests/support/t.gd")
var t := T.new("ground_slump_site_test")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if not t.check("named KD3 park_pit export is present", FileAccess.file_exists("res://src/world/park/park_pit.json")):
		quit(t.verdict())
		return
	var game := Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	game.ctx.calm = true
	game.flow.force_warden = false
	game.player.source = Intent.Scripted.new()
	game.flow.press_start()
	game.flow.choose_class(1)
	game.flow.enter_stage(3, Vector3.ZERO, false)
	await physics_frame
	await physics_frame
	var park: Dictionary = game.world.events._park
	var event: Dictionary = park.event_rows.filter(func(row): return row.id == "tailings_slump")[0]
	var site: Dictionary = park.park_rows.filter(func(row): return row.id == event.site)[0]
	var bench: Dictionary = park.park_rows.filter(func(row): return row.id == "pit_bench_2")[0]
	# The authored bench-2 eastern boundary is its centre plus half of its width.
	var face := Vector2(float(bench.at[0]) + float(bench.size[2]) * 0.5, float(site.at[1]))
	var lower := face + Vector2.LEFT * 1.0
	var upper := face + Vector2.RIGHT * 1.0
	var terrain = game.ctx.terrain
	t.near("authored bench face has requested twenty metre drop", terrain.height(upper.x, upper.y) - terrain.height(lower.x, lower.y), float(event.effect.depth_m))
	t.check("authored slump footprint includes bench face", ParkMap.footprint_contains(site, face), "face=%s site=%s size=%s" % [face, site.at, site.size])
	var half := Vector2(float(site.size[2]), float(site.size[0])) * 0.5
	var centre := Vector2(float(site.at[0]), float(site.at[1]))
	var low := INF
	var high := -INF
	for z in range(ceili(-half.y), floori(half.y) + 1):
		for x in range(ceili(-half.x), floori(half.x) + 1):
			var point := Vector2(x, z).rotated(-deg_to_rad(float(site.yaw_deg))) + centre
			var y: float = terrain.height(point.x, point.y)
			low = minf(low, y)
			high = maxf(high, y)
	t.check("authored slump footprint spans both treads", high - low >= float(event.effect.depth_m), "footprint height range=%s..%s" % [low, high])
	game.free()
	quit(t.verdict())
