extends SceneTree

# Rule (LANDMARK-CARDS.md port note P7): from its stage's drop-in (spawn, 1.17 to 1.43 km away) each hero landmark is
# drawn although the chase camera's far plane is 700 m. For each landmark the test places the landmark node at its row
# transform and datum, builds src/presentation/landmark_impostor.gd from the landmark's _far.glb and puts the eye EYE_M
# over the baked ground at spawn, with chase_camera.gd's far plane and field of view. It checks that the stand-in shows,
# that every stand-in vertex sits inside FAR_SHARE of the far plane, that every one lies on the eye ray of its full-size
# vertex (so it covers the same pixels), and how many of those pixels clear the baked terrain: the height in pixels at
# 1080 lines of the vertices whose ray from the eye no baked ground blocks must reach MIN_PX. The sinkhole is a hole in
# the plateau, under grade from every drop-in, so it only reports its figure (BELOW_GRADE); terrain hides the flume's tower
# from its spawn (RIDGE_HIDDEN). The ancient beam marks both.
# Planted: a landmark that stands inside the reach keeps its own views and shows no stand-in.

const T := preload("res://tests/support/t.gd")
const Recipes := preload("res://src/world/park/park_recipes.gd")
const Impostor := preload("res://src/presentation/landmark_impostor.gd")

const PARK_DIR := "res://src/world/park"
const OUT_DIR := "res://assets/park"
const GRAPH_TOOL := "res://tools/park_graph.gd"
const FAR := 700.0          # chase_camera.gd cam.far
const FOV_DEG := 65.0       # chase_camera.gd cam.fov (vertical)
const LINES := 1080.0
const EYE_M := 2.0
const SAMPLE_M := 4.0
const MIN_PX := 6.0
const RAY_PX := 0.5         # float32 rounding at a kilometre stays well under a pixel
const HALF_M := 800.0
const BAKE_SIDE := 801
# The GLB origins' y datums (landmarks.py FRAMES; PR #28 landmark_datum).
const DATUM := {"park_dam": 0.0, "park_flume": 0.0, "park_pit": -100.0, "park_sinkhole": 0.0, "park_islands": 200.0,
	"park_crown": -12.0}
const BELOW_GRADE := ["park_sinkhole"]
# Stages whose baked terrain hides the whole landmark from a ground-level eye at spawn: park_flume's spawn (-460, -650,
# ground 109) looks at the tower top (300, 90, 560) over a ridge near (-209, -251) at 138.8, so an eye needs y 162.8
# there. The test asserts the ridge still blocks, so a terrain change that opens the view fails here and drops the entry.
const RIDGE_HIDDEN := ["park_flume"]

var t := T.new("landmark_impostor_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var tool: GDScript = load(GRAPH_TOOL)
	for map_id: String in DATUM:
		var park: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("%s/%s.json" % [PARK_DIR, map_id]))
		var row: Dictionary = park["landmark"]
		var bake: Dictionary = tool.load_bake("%s/%s" % [OUT_DIR, map_id])
		if not t.check("%s bake loads" % map_id, bake["errors"].is_empty(), str(bake["errors"])):
			continue
		var ground: PackedFloat32Array = bake["ground"]
		var far_path: String = Recipes.paths(String(row["recipe"]), "hero_landmark")["far"]
		if not t.check("%s far view exists" % map_id, ResourceLoader.exists(far_path), far_path):
			continue
		var far_scene: Node = (load(far_path) as PackedScene).instantiate()
		var landmark := Node3D.new()
		get_root().add_child(landmark)
		var place := Recipes.row_transform(row)
		place.origin.y = DATUM[map_id]
		landmark.global_transform = place
		var impostor: Node3D = Impostor.make(landmark, far_scene, [])
		var spawn: Array = park["spawn"]["at"]
		var eye := Vector3(float(spawn[0]), height(ground, float(spawn[0]), float(spawn[1])) + EYE_M, float(spawn[1]))
		var shows: bool = impostor.show_for(eye, FAR)
		t.check("%s stand-in shows from the drop-in" % map_id, shows, "%.0f m away" % eye.distance_to(place.origin))
		var stand_in: Transform3D = impostor.impostor(eye, FAR)
		var reach := FAR * Impostor.FAR_SHARE
		var worst_reach := 0.0
		var worst_ray := 0.0
		var visible: Array[float] = []
		var total := 0
		for view: MeshInstance3D in impostor.stand_in.get_children():
			for v: Vector3 in view.mesh.get_faces():
				var real := place * (view.transform * v)
				var drawn := stand_in * (view.transform * v)
				total += 1
				worst_reach = maxf(worst_reach, eye.distance_to(drawn))
				var a := real - eye
				var b := drawn - eye
				worst_ray = maxf(worst_ray, atan2(a.cross(b).length(), a.dot(b)) / deg_to_rad(FOV_DEG) * LINES)
				if clear_ray(ground, eye, real):
					visible.append(atan2(real.y - eye.y, Vector2(real.x - eye.x, real.z - eye.z).length()))
		t.check("%s stand-in inside the far plane share" % map_id, worst_reach <= reach + 0.01, "%.1f m of %.1f" % [worst_reach, reach])
		t.check("%s stand-in on the full-size rays" % map_id, worst_ray <= RAY_PX, "%.3f px off, allowed %.2f" % [worst_ray, RAY_PX])
		var px := 0.0
		if visible.size() > 1:
			px = (visible.max() - visible.min()) / deg_to_rad(FOV_DEG) * LINES
		print("[impostor] %s distance %.0f m, scale %.3f, vertices %d visible %d, height %.1f px at %d lines" % [
			map_id, eye.distance_to(place.origin), impostor.scale_for(eye, FAR), total, visible.size(), px, LINES])
		if map_id in BELOW_GRADE:
			t.check("%s reports its figure (under grade, the beam marks it)" % map_id, true, "%.1f px" % px)
		elif map_id in RIDGE_HIDDEN:
			var top: Array = row["sight_top"]
			t.check("%s terrain still hides the landmark from spawn (the beam marks it)" % map_id,
				not clear_ray(ground, eye, Vector3(float(top[0]), float(top[1]), float(top[2]))) and visible.is_empty(),
				"%d visible vertices" % visible.size())
		else:
			t.check("%s reads from the drop-in" % map_id, px >= MIN_PX, "%.1f px, need %.0f" % [px, MIN_PX])
		if map_id == "park_dam":
			var near_eye := place.origin + Vector3(0.0, 40.0, -300.0)
			t.check("planted: a near eye keeps the landmark's own views", not impostor.show_for(near_eye, FAR),
				"scale %.3f" % impostor.scale_for(near_eye, FAR))
		landmark.free()
		far_scene.free()
	quit(t.verdict())


static func clear_ray(ground: PackedFloat32Array, from: Vector3, to: Vector3) -> bool:
	var run := Vector2(to.x - from.x, to.z - from.z).length()
	var steps := int(run / SAMPLE_M)
	for k in range(1, steps):
		var p := from.lerp(to, float(k) / steps)
		if absf(p.x) > HALF_M or absf(p.z) > HALF_M:
			continue
		if height(ground, p.x, p.z) > p.y + 0.5:
			return false
	return true


static func height(ground: PackedFloat32Array, x: float, z: float) -> float:
	var fx := clampf((x + HALF_M) / 2.0, 0.0, BAKE_SIDE - 1.001)
	var fz := clampf((z + HALF_M) / 2.0, 0.0, BAKE_SIDE - 1.001)
	var i := floori(fx)
	var j := floori(fz)
	var u := fx - i
	var v := fz - j
	var h00 := ground[j * BAKE_SIDE + i]
	var h10 := ground[j * BAKE_SIDE + i + 1]
	var h01 := ground[(j + 1) * BAKE_SIDE + i]
	var h11 := ground[(j + 1) * BAKE_SIDE + i + 1]
	return lerpf(lerpf(h00, h10, u), lerpf(h01, h11, u), v)
