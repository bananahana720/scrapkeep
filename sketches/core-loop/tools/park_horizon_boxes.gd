extends SceneTree

# Haze box fitted to each pose's own skyline (World lane, wave 19 islands ground-over-horizon). The render bench measures "ground over
# horizon" as the L* of the near floor against the L* of a fixed haze box (full width, y 365 to 405 of a 1280x720 frame). That box sits on
# fogged far ground under the skyline in the pit noon frame, but the islands audit chase poses put the skyline anywhere from about y 290
# to 330, so the fixed box lands on mid-distance floor. This sidecar finds where the ground ends in each pose and fits the box to it.
# It does not render: it boots the park stage as tools/park_props_audit.gd does (table "park"), places the camera for each pose with the
# audit's own rule (_place: the chase branch, and the eye branch when a pose carries "cam" and "look"), and casts rays itself.
#
#   $GODOT_BIN --headless --path sketches/core-loop --script res://tools/park_horizon_boxes.gd -- --map=park_islands \
#     --poses=<abs poses.json> --out=<abs dir> [--cam=rest|mid|fast]
#
# Writes <out>/<map>/horizon_boxes.json. tools/park_horizon_lstar.py reads it with a directory of frames.
#
# Rays: Camera3D.fov is the vertical field of view (keep_aspect KEEP_HEIGHT, the default), so a pixel (px, py) of a W x H frame has the
# camera-space direction ((2 px / W - 1) tan(fov / 2) W / H, (1 - 2 py / H) tan(fov / 2), -1). The headless viewport is not 1280x720, so
# project_ray_* is not used. A ray hits when the nearer of two things lies within CAM_FAR in view depth: a physics intersect_ray against
# the world (the ball body excluded), and a march along the ray over the game's terrain height function (the one _place reads,
# game.ctx.terrain.height; 0.5 to 4 m steps, 2 percent of the distance, bisected to a hit). Godot clips at far along view depth, not ray
# length, so each ray is cast out to CAM_FAR / cos(theta), theta the angle from the camera's forward (the ray distance is then up to
# about twice CAM_FAR at the frame corners). Pixels are cast through their centres: a skyline column's pixel is floor(x), the ray at x + 0.5.
# Skyline: for 33 columns at x = (i + 0.5) W / 33, the first row from the top whose ray hits (every 8th row, then the 7 rows above the
# first hit, to 1 px); the pose skyline is the median of the columns that hit (the upper middle when the count is even).
# Median haze box (comparison only): [0, skyline + 5, W, skyline + 45] clipped to the frame. Hit samples: a grid of every 32 px by 8 rows over that box, giving
# haze_hit_share (share whose ray hits) and haze_median_hit_m (median ray distance of the hits, null for none). geometric_horizon_y:
# the row of a horizontal ray straight ahead (H / 2 - f tan(pitch down) for a level-roll camera, f = H / 2 / tan(fov / 2)). A skyline
# below the geometric horizon means ground ends at CAM_FAR short of the true horizon.
# Haze rule (the measure): a SKY BAND just above each column's skyline. On islands the far ground fades fully into haze within a few pixels
# of the skyline, and a fog-distance mask over far ground also caught cliffs, terrain slopes and visual-only landforms (idx 142, 222, 81 in
# the r349 audit). "No hit within CAM_FAR" is the one geometric class that cannot be a cliff or a structure with a collider. Known
# limit: a rendered mesh with no collider counts as sky, because the rays only see colliders and the terrain function. It shows in the
# r349 islands poses 74 (the walker's legs), 26 and 95 (pale far blocks and a pole) and 142 (a far tower), on a small share of the
# samples, and is not corrected. Per 8 px
# column (x = 4, 12, ...) take that column's own combined skyline row S (physics plus terrain search), sample rows S - 12 to S - 2 every 2
# rows, and keep a sample only when its ray hits nothing (no physics hit, no terrain hit) within CAM_FAR. A column with no skyline (sky to
# the bottom, the void past an island edge) is skipped, and so is one whose S leaves no row above it. A pose is valid when the camera is not
# below ground and at least MIN_SAMPLES samples were kept; poses short of that are reported invalid with their count.
# Why this reads the pit bar: the pit noon frame (4-stage3-noon.jpg on scratch/render-r349-e9484509 a309ddc5, both heads) has its sky rows just
# above the skyline, y 346 to 358, at mean L* 75.7 against 73.7 to 73.9 for the fixed far-ground box, y 365 to 405 (measured with
# park_horizon_lstar.py's box_lab): the sky band stays within about 2 L* of the pit bar's haze. A fog-distance mask (ln(2) / density, the
# 50 percent point of 1 - exp(-density * d)) was tried first and dropped: it is not in this tool.
# Also recorded: terrain_skyline_y/cols (the same search over the terrain alone) and camera_below_ground (the chase camera sits under
# the heightfield, as in a slope-hugging pose: terrain rays then find nothing from inside, and the skyline is not trustworthy).

const Audit := preload("res://tools/park_props_audit.gd")

const SIZE := Audit.SIZE # 1280x720, audit line 91
const CAMERAS := Audit.CAMERAS # audit line 95
const CAM_UP := Audit.CAM_UP # audit line 96
const CAM_PITCH := Audit.CAM_PITCH # audit line 97
const CAM_FAR := Audit.CAM_FAR # audit line 98
const V_FOV := Audit.V_FOV # audit line 113, the eye frame lens
const COLUMNS := 33
const COARSE_PX := 8
const HAZE_FROM := 5.0
const HAZE_TO := 45.0
const GRID_X := 32
const GRID_ROWS := 8
const NEAR_BOX := [300, 650, 980, 720]
const SETTLE_PHYSICS := 3
const SAMPLE_COL_PX := 8
const SKY_ABOVE_FAR := 12 # rows S - 12 .. S - 2
const SKY_ABOVE_NEAR := 2
const BAND_ROW_STEP := 2
const MIN_SAMPLES := 40

var map_id := ""
var out_root := ""
var poses_file := ""
var cam_name := "mid"
var game
var space: PhysicsDirectSpaceState3D
var ball_rid: RID


# ---- static helpers (tests/park_horizon_boxes_test.gd drives these with a synthetic ground) ----

static func focal_px(fov_deg: float, height_px: float) -> float:
	return height_px * 0.5 / tan(deg_to_rad(fov_deg) * 0.5)


# World direction (unit) of the ray through frame pixel (px, py), py down from the top.
static func ray_dir(xf: Transform3D, fov_deg: float, size: Vector2, px: float, py: float) -> Vector3:
	var th := tan(deg_to_rad(fov_deg) * 0.5)
	var d := Vector3((2.0 * px / size.x - 1.0) * th * size.x / size.y, (1.0 - 2.0 * py / size.y) * th, -1.0)
	return (xf.basis * d).normalized()


# Camera transform and lens for a pose, the audit's _place (lines 1025 to 1036). ground is height(x, z).
static func pose_camera(s: Dictionary, ground: Callable, cam_key: String) -> Dictionary:
	if s.has("cam") and s.has("look"):
		var at := Vector3(float(s["cam"][0]), float(s["cam"][1]), float(s["cam"][2]))
		var target := Vector3(float(s["look"][0]), float(s["look"][1]), float(s["look"][2]))
		return {"xf": Transform3D(Basis.looking_at(target - at, Vector3.UP), at), "fov": V_FOV}
	var x := float(s["x"])
	var z := float(s["z"])
	var anchor := Vector3(x, float(ground.call(x, z)) + 1.0 + CAM_UP, z)
	var basis := Basis(Vector3.UP, float(s["yaw"])) * Basis(Vector3.RIGHT, CAM_PITCH)
	return {"xf": Transform3D(basis, anchor + basis * Vector3(0.0, 0.0, float(CAMERAS[cam_key]["arm"]))), "fov": float(CAMERAS[cam_key]["fov"])}


# Distance along the unit ray to the first terrain crossing within far, or INF.
static func march(origin: Vector3, dir: Vector3, ground: Callable, far: float) -> float:
	var t := 0.0
	if is_below(origin, ground):
		return INF # a camera inside the heightfield sees no ground crossing from there; measure() flags it
	while t < far:
		var t2 := minf(t + clampf(t * 0.02, 0.5, 4.0), far)
		var p := origin + dir * t2
		if p.y - float(ground.call(p.x, p.z)) <= 0.0:
			var lo := t
			var hi := t2
			for _i in 14:
				var mid := (lo + hi) * 0.5
				var q := origin + dir * mid
				if q.y - float(ground.call(q.x, q.z)) <= 0.0:
					hi = mid
				else:
					lo = mid
			return hi
		t = t2
	return INF


static func is_below(p: Vector3, ground: Callable) -> bool:
	return p.y - float(ground.call(p.x, p.z)) <= 0.0


# Nearer of the world hit (Callable(origin, dir, range) -> distance or INF, may be invalid) and the terrain march, INF when beyond the
# far clip. Godot clips at far along view depth, so the ray is cast out to far / cos(theta), theta the angle from the camera's forward.
static func hit_dist(xf: Transform3D, dir: Vector3, ground: Callable, world: Callable, far: float) -> float:
	var reach := far / maxf(dir.dot(-xf.basis.z), 0.05)
	var d := march(xf.origin, dir, ground, reach)
	if world.is_valid():
		d = minf(d, float(world.call(xf.origin, dir, reach)))
	return d if d <= reach else INF


static func column_x(i: int, w: float) -> float:
	return (float(i) + 0.5) * w / float(COLUMNS)


# The ray goes through the centre of the pixel column that lstar reads.
static func column_px(i: int, w: float) -> float:
	return floorf(column_x(i, w)) + 0.5


# First row (0 at the top) whose ray hits in the column at pixel x, or -1.
static func column_skyline(px: float, xf: Transform3D, fov: float, size: Vector2, ground: Callable, world: Callable, far: float) -> int:
	var rows := int(size.y)
	var y := 0
	while y < rows:
		if is_finite(hit_dist(xf, ray_dir(xf, fov, size, px, float(y) + 0.5), ground, world, far)):
			for f in range(maxi(y - COARSE_PX + 1, 0), y + 1):
				if is_finite(hit_dist(xf, ray_dir(xf, fov, size, px, float(f) + 0.5), ground, world, far)):
					return f
			return y
		y += COARSE_PX
	if (rows - 1) % COARSE_PX != 0 and is_finite(hit_dist(xf, ray_dir(xf, fov, size, px, float(rows - 1) + 0.5), ground, world, far)):
		for f in range(rows - COARSE_PX, rows):
			if is_finite(hit_dist(xf, ray_dir(xf, fov, size, px, float(f) + 0.5), ground, world, far)):
				return f
	return -1


static func median_int(values: Array) -> int:
	var v := values.duplicate()
	v.sort()
	return int(v[v.size() / 2])


static func median_float(values: Array) -> float:
	var v := values.duplicate()
	v.sort()
	return float(v[v.size() / 2])


# Row of the horizontal ray straight ahead (the camera's forward flattened), at the frame's centre column.
static func horizon_row(xf: Transform3D, fov: float, size: Vector2) -> float:
	var fwd := -xf.basis.z
	var flat := Vector3(fwd.x, 0.0, fwd.z).normalized()
	var c := xf.basis.inverse() * flat
	return size.y * 0.5 - focal_px(fov, size.y) * c.y / -c.z


# Skyline, haze box and its hit samples for one camera.
static func measure(xf: Transform3D, fov: float, size: Vector2, ground: Callable, world: Callable, far: float) -> Dictionary:
	var cols: Array = []
	var hits: Array = []
	for i in COLUMNS:
		var r := column_skyline(column_px(i, size.x), xf, fov, size, ground, world, far)
		cols.append(r if r >= 0 else null)
		if r >= 0:
			hits.append(r)
	var out := {"skyline_cols": cols, "geometric_horizon_y": snappedf(horizon_row(xf, fov, size), 0.1), "near_box": NEAR_BOX, "camera_below_ground": is_below(xf.origin, ground)}
	# The same skyline over the terrain alone (no physics world: props, landforms and cliffs left out), for poses where tall things
	# cover half the columns and the median rides their tops instead of the ground's edge.
	var tcols: Array = []
	var thits: Array = []
	for i in COLUMNS:
		var tr := column_skyline(column_px(i, size.x), xf, fov, size, ground, Callable(), far)
		tcols.append(tr if tr >= 0 else null)
		if tr >= 0:
			thits.append(tr)
	out["terrain_skyline_cols"] = tcols
	out["terrain_skyline_y"] = median_int(thits) if not thits.is_empty() else null
	if hits.is_empty():
		out.merge({"skyline_y": null, "haze_box_median": null, "haze_box_hit_share": null, "haze_box_median_hit_m": null})
		_haze_samples(out, xf, fov, size, ground, world, far)
		return out
	var sky := median_int(hits)
	var y0 := clampi(int(sky + HAZE_FROM), 0, int(size.y))
	var y1 := clampi(int(sky + HAZE_TO), 0, int(size.y))
	var n := 0
	var ds: Array = []
	var gx := GRID_X * 0.5
	while gx < size.x:
		for j in GRID_ROWS:
			n += 1
			var py := float(y0) + (float(j) + 0.5) * float(y1 - y0) / float(GRID_ROWS)
			var d := hit_dist(xf, ray_dir(xf, fov, size, gx, py), ground, world, far)
			if is_finite(d):
				ds.append(d)
		gx += GRID_X
	out.merge({"skyline_y": sky, "haze_box_median": [0, y0, int(size.x), y1], "haze_box_hit_share": snappedf(float(ds.size()) / float(maxi(n, 1)), 0.001),
		"haze_box_median_hit_m": null if ds.is_empty() else snappedf(median_float(ds), 0.1)})
	_haze_samples(out, xf, fov, size, ground, world, far)
	return out


# Sky band: per 8 px column, rows S - 12 .. S - 2 every 2 rows, kept when the ray hits nothing within far.
static func _haze_samples(out: Dictionary, xf: Transform3D, fov: float, size: Vector2, ground: Callable, world: Callable, far: float) -> void:
	var kept: Array = []
	var px := SAMPLE_COL_PX * 0.5 # the pixel column x = 4, 12, ...; rays go through its centre, px + 0.5
	while px < size.x:
		var r := column_skyline(px + 0.5, xf, fov, size, ground, world, far)
		if r >= 0:
			var y := r - SKY_ABOVE_FAR
			while y <= r - SKY_ABOVE_NEAR:
				if y >= 0 and not is_finite(hit_dist(xf, ray_dir(xf, fov, size, px + 0.5, float(y) + 0.5), ground, world, far)):
					kept.append([int(px), y])
				y += BAND_ROW_STEP
		px += SAMPLE_COL_PX
	out["haze_samples"] = kept
	out["haze_sample_count"] = kept.size()
	out["valid"] = not bool(out["camera_below_ground"]) and kept.size() >= MIN_SAMPLES


# ---- run ----

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--map="):
			map_id = a.trim_prefix("--map=")
		elif a.begins_with("--poses="):
			poses_file = a.trim_prefix("--poses=")
		elif a.begins_with("--out="):
			out_root = a.trim_prefix("--out=")
		elif a.begins_with("--cam="):
			cam_name = a.trim_prefix("--cam=")
	if map_id == "" or poses_file == "" or out_root == "" or not CAMERAS.has(cam_name):
		printerr("park_horizon_boxes: pass --map=<park map> --poses=<abs poses.json> --out=<abs dir> [--cam=rest|mid|fast]")
		quit(2)
		return
	_run.call_deferred()


func _run() -> void:
	var stage_index := 0
	for row in Audit.ParkDefs.DEFS:
		if String(row.get("map", "")) == map_id:
			stage_index = int(row["stage"])
	if stage_index == 0:
		printerr("park_horizon_boxes: %s is not a park table map" % map_id)
		quit(2)
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(poses_file))
	if not data is Dictionary:
		printerr("park_horizon_boxes: cannot read %s" % poses_file)
		quit(2)
		return
	# The audit's boot (lines 242 to 265).
	game = Audit.Game.new()
	game.test_mode = true
	game.table = "park"
	game.ground_behind_menu = false
	root.add_child(game)
	while game.flow == null:
		await process_frame
	game.ctx.calm = true
	game.player.source = Audit.Intent.Scripted.new()
	game.flow.press_start()
	game.flow.choose_class(0)
	if stage_index != 1:
		game.flow.enter_stage(stage_index, Vector3.ZERO, false)
	var waited := 0
	var terrain = game.ctx.terrain
	while waited < 2400 and not (terrain.rows_ready(stage_index) and terrain.is_ready(stage_index) and game.presentation.set_dressing != null and game.presentation.set_dressing.batches.size() > 0 and game.flow.state_name() == "stage"):
		await process_frame
		waited += 1
	var pp = game.presentation.park_props
	if pp != null:
		pp.finish()
	for _i in 30:
		await process_frame
	print("park_horizon_boxes: %s built in %d frames, flow %s" % [map_id, waited, game.flow.state_name()])
	var body = game.player.body()
	body.freeze = true
	ball_rid = body.get_rid()
	space = game.get_world_3d().direct_space_state
	var ground := Callable(terrain, "height")
	var world := Callable(self, "_world_hit")
	var rows: Array = []
	for p in data.get("poses", []):
		var s := {"idx": int(p["idx"]), "x": float(p["x"]), "z": float(p["z"]), "yaw": float(p["yaw"])}
		if p.get("cam") is Array and p.get("look") is Array:
			s["cam"] = p["cam"]
			s["look"] = p["look"]
		# The ball goes where _place puts it (lines 1020 to 1031), so anything streamed around it is in place.
		var g := float(ground.call(s["x"], s["z"]))
		body.global_position = Vector3(s["x"], g + 1.0, s["z"])
		body.linear_velocity = Vector3.ZERO
		var cam := pose_camera(s, ground, cam_name)
		if s.has("cam"):
			body.global_position = (cam["xf"] as Transform3D).origin + (cam["xf"] as Transform3D).basis.z * 8.0
		for _i in SETTLE_PHYSICS:
			await physics_frame
		space = game.get_world_3d().direct_space_state
		var m := measure(cam["xf"], cam["fov"], Vector2(SIZE), ground, world, CAM_FAR)
		var row := {"idx": s["idx"], "file": String(p.get("file", "")), "x": s["x"], "z": s["z"], "yaw": s["yaw"], "cam_y": snappedf((cam["xf"] as Transform3D).origin.y, 0.01)}
		row.merge(m)
		rows.append(row)
		print("park_horizon_boxes: idx %d skyline %s geometric horizon %s haze samples %s valid %s" % [row["idx"], str(row["skyline_y"]), str(row["geometric_horizon_y"]), str(row["haze_sample_count"]), str(row["valid"])])
	var commit: Array = []
	OS.execute("git", ["rev-parse", "HEAD"], commit)
	var dir := out_root.path_join(map_id)
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(dir.path_join("horizon_boxes.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"map": map_id, "git_commit": String(commit[0]).strip_edges() if not commit.is_empty() else "", "poses_file": poses_file, "cam": cam_name,
		"constants": {"size": [SIZE.x, SIZE.y], "cam_far": CAM_FAR, "cam_up": CAM_UP, "cam_pitch": CAM_PITCH, "cameras": CAMERAS, "eye_fov": V_FOV, "columns": COLUMNS, "coarse_px": COARSE_PX,
			"haze_from": HAZE_FROM, "haze_to": HAZE_TO, "grid_x": GRID_X, "grid_rows": GRID_ROWS, "near_box": NEAR_BOX, "sample_col_px": SAMPLE_COL_PX, "sky_above_far": SKY_ABOVE_FAR, "sky_above_near": SKY_ABOVE_NEAR, "band_row_step": BAND_ROW_STEP, "min_samples": MIN_SAMPLES},
		"poses": rows}, "\t"))
	f.close()
	print("park_horizon_boxes: wrote %s" % dir.path_join("horizon_boxes.json"))
	quit(0)


# The nearest physics hit along the ray within reach (CAM_FAR / cos theta), the ball excluded, or INF.
func _world_hit(origin: Vector3, dir: Vector3, reach: float) -> float:
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * reach)
	query.exclude = [ball_rid]
	var r := space.intersect_ray(query)
	return INF if r.is_empty() else origin.distance_to(r["position"])
