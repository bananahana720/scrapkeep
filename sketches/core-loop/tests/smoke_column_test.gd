extends SceneTree

# W46-07 (transitions-audit T6, rulings cv and ct): Brindle's furnace smoke stands on the flume's east horizon where the
# launch aims, so the next stage is in view before you leave. In the game: enter the flume and read the column the
# Spillway park pass built (src/presentation/smoke_column.gd, placed by spillway_scenery.gd).
#   (a) it stands at the park file's approach.smoke, its foot on the ground nearest it, and the flume's exit gate
#       faces it (within AIM_DEG);
#   (b) it is one code-built surface (no primitive mesh, prim_census), casts no shadow, and is drawn about the eye
#       inside the chase camera's far plane: from the drop-in and from the bend overlook its farthest point lands
#       inside the far plane, on the same ray from the eye as the real column;
#   (c) seen from the bend overlook: on a GRID_M grid over the bend_overlook row, an eye EYE_M above the ground sees
#       the column when it is drawn and a ray from the eye to the column's middle (sight_point) clears the ground,
#       sampled every SAMPLE_M; the share of eyes that see it is at least SIGHT_SHARE.
# Planted: the column hidden, the same measure falls under SIGHT_SHARE, so the measure can fail.
# Evidence limit: the ground the ray reads is the stage's height(); past the 1.6 km square that is the square's edge.

const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const ParkSites := preload("res://src/presentation/park_sites.gd")

const PARK := "res://src/world/park/park_flume.json"
const OVERLOOK := "bend_overlook"
const SIGHT_SHARE := 0.85
const GRID_M := 10.0
const EYE_M := 2.0
const SAMPLE_M := 2.0
const AIM_DEG := 5.0
const FAR := 700.0

var t := T.new("smoke_column_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var park: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PARK))
	var smoke := Vector2(float(park["approach"]["smoke"][0]), float(park["approach"]["smoke"][1]))
	var game = Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	game.ctx.calm = true
	game.flow.force_warden = false
	game.player.source = Intent.Scripted.new()
	game.flow.press_start()
	game.flow.choose_class(1)
	var stage := -1
	for i in game.ctx.terrain.maps.size():
		var m = game.ctx.terrain.maps[i]
		if "park" in m and String(m.park.get("map", "")) == "park_flume":
			stage = i + 1
	game.flow.enter_stage(stage, Vector3.ZERO, false)
	await process_frame
	await physics_frame
	var stage_root: Node3D = game.ctx.terrain.geometry_root(stage)
	var column = stage_root.get_node_or_null("SpillwayScenery/SmokeColumn")
	if not t.check("the flume's park pass builds the smoke column", column != null):
		quit(t.verdict())
		return
	var terrain = game.ctx.terrain
	var height := func(x: float, z: float) -> float: return terrain.height(x, z)

	# (a) where it stands and what aims at it.
	var home: Vector3 = column.home
	t.check("it stands at approach.smoke", Vector2(home.x, home.z).distance_to(smoke) < 0.01, str(home))
	var map := ParkMap.new(PARK)
	var exit: Dictionary = map.handover()["exit"]
	var aim := ParkMap.facing(float(exit["heading_deg"]))
	var gate: Vector2 = exit["at"]
	var to_smoke := Vector3(smoke.x - gate.x, 0.0, smoke.y - gate.y).normalized()
	var off_deg := rad_to_deg(aim.angle_to(to_smoke))
	t.check("the exit gate faces the smoke (launch aims at it)", off_deg <= AIM_DEG, "%.2f degrees off" % off_deg)

	# (b) what it is and how it is drawn.
	var view: MeshInstance3D = column.view
	t.check("one code-built surface, no primitive mesh", view.mesh is ArrayMesh and not view.mesh is PrimitiveMesh and view.mesh.get_surface_count() == 1)
	t.check("it casts no shadow", view.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	var drop_in := Vector3(map.spawn.x, height.call(map.spawn.x, map.spawn.y) + EYE_M, map.spawn.y)
	var row := _row(park, OVERLOOK)
	var lookout := Vector3(float(row["at"][0]), 0.0, float(row["at"][1]))
	lookout.y = height.call(lookout.x, lookout.z) + EYE_M
	for eye: Vector3 in [drop_in, lookout]:
		var at: Transform3D = column.show_for(eye, FAR)
		var k: float = at.basis.get_scale().x
		var far_point: float = eye.distance_to(at.origin) + column.radius * k
		var on_ray: Vector3 = (at * (column.sight_point() - home)) - eye
		var true_ray: Vector3 = column.sight_point() - eye
		t.check("drawn inside the far plane from %s" % ("the drop-in" if eye == drop_in else OVERLOOK), k < 1.0 and far_point <= FAR + 0.01,
			"scale %.3f, farthest %.1f m, %.0f m away" % [k, far_point, eye.distance_to(home)])
		t.check("the drawn column keeps the real one's ray from %s" % ("the drop-in" if eye == drop_in else OVERLOOK),
			on_ray.normalized().dot(true_ray.normalized()) > 0.99999)

	# (c) the sight share from the overlook, then the planted hidden column.
	var eyes := _eyes(row, height)
	var seen := _share(column, eyes, height)
	print("[smoke] %s: %d eyes, share %.3f (base glow %.3f), threshold %.2f" % [OVERLOOK, eyes.size(), seen["share"], seen["glow"], SIGHT_SHARE])
	t.check("seen from %s with share >= %.2f" % [OVERLOOK, SIGHT_SHARE], seen["share"] >= SIGHT_SHARE, "%.3f" % seen["share"])
	column.hide()
	var hidden := _share(column, eyes, height)
	t.check("planted: the column hidden falls under the share", hidden["share"] < SIGHT_SHARE, "%.3f" % hidden["share"])
	column.show()
	t.eq("expected check count", t.checks + 1, 12)
	game.queue_free()
	await process_frame
	quit(t.verdict())


func _row(park: Dictionary, id: String) -> Dictionary:
	for r in park["park_rows"]:
		if r["id"] == id:
			return r
	return {}


# Eyes EYE_M over the ground on a GRID_M grid across the row's footprint (its length along its yaw, its width across).
func _eyes(row: Dictionary, height: Callable) -> Array:
	var f := ParkSites.frame(row)
	var out := []
	var half_l: float = f["half_length"]
	var half_w: float = f["half_width"]
	var run: Vector2 = f["run"]
	var side := Vector2(run.y, -run.x)
	var u := -half_l
	while u <= half_l + 0.01:
		var v := -half_w
		while v <= half_w + 0.01:
			var p: Vector2 = f["at"] + run * u + side * v
			out.append(Vector3(p.x, float(height.call(p.x, p.y)) + EYE_M, p.y))
			v += GRID_M
		u += GRID_M
	return out


# {share, glow}: the eyes that see the drawn column's middle over the ground, and (information) its glowing foot.
func _share(column, eyes: Array, height: Callable) -> Dictionary:
	var seen := 0
	var glow := 0
	for eye: Vector3 in eyes:
		if not column.is_visible_in_tree() or not column.view.is_visible_in_tree():
			continue
		var at: Transform3D = column.show_for(eye, FAR)
		if eye.distance_to(at.origin) + column.radius * at.basis.get_scale().x > FAR + 0.01:
			continue
		if _clear(eye, column.sight_point(), height):
			seen += 1
		if _clear(eye, column.home + Vector3.UP * 30.0, height):
			glow += 1
	return {"share": float(seen) / maxf(1.0, eyes.size()), "glow": float(glow) / maxf(1.0, eyes.size())}


func _clear(from: Vector3, to: Vector3, height: Callable) -> bool:
	var planar := Vector2(to.x - from.x, to.z - from.z).length()
	var d := SAMPLE_M
	while d < planar:
		var p := from.lerp(to, d / planar)
		if float(height.call(p.x, p.z)) > p.y:
			return false
		d += SAMPLE_M
	return true
