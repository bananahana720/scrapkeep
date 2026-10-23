extends SceneTree

# Rule: tools/park_horizon_boxes.gd finds each pose's skyline from rays over the ground, so its helpers must agree with the pinhole
# geometry. Synthetic ground only, no park boot. Controls: a flat plane at y 0 with the camera H m up and pitched down P; the
# centre column's skyline row is the far-plane crossing at depression d = asin(H / far) along the ray, row = h / 2 - f tan(P - d)
# (f = h / 2 / tan(fov / 2)), and the geometric horizon row is h / 2 - f tan(P); both within 1 px, at two yaws. Planted: a wall of
# height 30 m at 100 m ahead across the columns left of centre moves those columns to the row where its top projects (found by projecting
# the wall-top points, a different path from the ray code), and the median follows the majority either way. Negative: no ground, no hit.

const T := preload("res://tests/support/t.gd")
const Boxes := preload("res://tools/park_horizon_boxes.gd")

const FAR := 700.0
const FOV := 72.5
const PITCH := 0.30
const CAM_H := 30.0
const WALL_D := 100.0
const WALL_H := 30.0

var t := T.new("park_horizon_boxes_test")


func _initialize() -> void:
	_run.call_deferred()


static func flat(_x: float, _z: float) -> float:
	return 0.0


static func nothing(_x: float, _z: float) -> float:
	return -1000.0


# A wall in the plane z = -WALL_D, from the ground to WALL_H, covering world x < 0 (columns left of centre at yaw 0) or x < x_max.
static func wall_hit(origin: Vector3, dir: Vector3, x_max: float, dist := WALL_D) -> float:
	if dir.z >= 0.0:
		return INF
	var d := (-dist - origin.z) / dir.z
	var p := origin + dir * d
	return d if d > 0.0 and p.x < x_max and p.y >= 0.0 and p.y <= WALL_H else INF


# Pixel row of a camera-relative world point (projection, not ray casting).
static func project_row(xf: Transform3D, p: Vector3, fov: float, size: Vector2) -> float:
	var c := xf.affine_inverse() * p
	return size.y * 0.5 - Boxes.focal_px(fov, size.y) * c.y / -c.z


static func project_col(xf: Transform3D, p: Vector3, fov: float, size: Vector2) -> float:
	var c := xf.affine_inverse() * p
	return size.x * 0.5 + Boxes.focal_px(fov, size.y) * c.x / -c.z


# The row where the wall's top edge shows in the column at pixel x: bisect the wall-top x so that it projects to that column.
static func wall_top_row(xf: Transform3D, fov: float, size: Vector2, px: float) -> float:
	var lo := -2000.0
	var hi := 2000.0
	for _i in 60:
		var mid := (lo + hi) * 0.5
		if project_col(xf, Vector3(mid, WALL_H, -WALL_D), fov, size) < px:
			lo = mid
		else:
			hi = mid
	return project_row(xf, Vector3(lo, WALL_H, -WALL_D), fov, size)


func _run() -> void:
	var size := Vector2(1280.0, 720.0)
	var f := Boxes.focal_px(FOV, size.y)
	var depression := asin(CAM_H / FAR)
	var want_sky := size.y * 0.5 - f * tan(PITCH - depression)
	var want_hor := size.y * 0.5 - f * tan(PITCH)
	var ground := Callable(self, "flat")
	var none_world := Callable()
	for yaw in [0.0, 0.7]:
		var xf := Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -PITCH), Vector3(0.0, CAM_H, 0.0))
		var m := Boxes.measure(xf, FOV, size, ground, none_world, FAR)
		var centre = (m["skyline_cols"] as Array)[16]
		t.check("positive: flat plane, yaw %.1f, centre column skyline %s within 1 px of the analytic row %.1f" % [yaw, str(centre), want_sky], centre != null and absf(float(centre) - want_sky) <= 1.0)
		t.check("positive: geometric horizon %.1f within 1 px of H/2 - f tan(pitch) = %.1f" % [float(m["geometric_horizon_y"]), want_hor], absf(float(m["geometric_horizon_y"]) - want_hor) <= 1.0)
		t.check("positive: skyline is below the geometric horizon (ground ends short of the true horizon)", float(m["skyline_y"]) > float(m["geometric_horizon_y"]))
		t.check("positive: every column hits a flat plane", (m["skyline_cols"] as Array).count(null) == 0)
		t.check("positive: haze box is [0, sky+5, 1280, sky+45]", m["haze_box_median"] == [0, int(m["skyline_y"]) + 5, 1280, int(m["skyline_y"]) + 45])
		t.check("positive: haze samples hit ground inside the far plane (share %s, median %s m)" % [str(m["haze_box_hit_share"]), str(m["haze_box_median_hit_m"])], float(m["haze_box_hit_share"]) >= 0.95 and float(m["haze_box_median_hit_m"]) < FAR)

	# Far clip by view depth: with a pure pitch the plane-hit condition is independent of the column, so an edge column's skyline matches
	# the analytic row (v <= (sin p - h / far) / cos p, v = (1 - 2 py / H) tan(fov / 2)) rather than the curved ray-length one.
	var xfp := Transform3D(Basis(Vector3.RIGHT, -PITCH), Vector3(0.0, CAM_H, 0.0))
	var th := tan(deg_to_rad(FOV) * 0.5)
	var v_edge := (sin(PITCH) - CAM_H / FAR) / cos(PITCH)
	var depth_row: float = ceil(size.y * 0.5 * (1.0 - v_edge / th) - 0.5)
	var mp := Boxes.measure(xfp, FOV, size, ground, Callable(), FAR)
	var edge_row: float = float(mp["skyline_cols"][0])
	t.check("depth far: edge column skyline %.0f within 1 px of the depth-based analytic row %.0f (centre %s)" % [edge_row, depth_row, str(mp["skyline_cols"][16])], absf(edge_row - depth_row) <= 1.0 and absf(float(mp["skyline_cols"][32]) - depth_row) <= 1.0)

	# Columns and rays: the centre ray is the camera's forward; the frame corner follows the vertical fov and the 16:9 aspect.
	var level := Transform3D(Basis.IDENTITY, Vector3.ZERO)
	var c := Boxes.ray_dir(level, FOV, size, 640.0, 360.0)
	t.check("ray: centre pixel looks along -z", c.distance_to(Vector3(0.0, 0.0, -1.0)) < 0.0001)
	var top := Boxes.ray_dir(level, FOV, size, 640.0, 0.0)
	t.near("ray: the top edge is half the vertical fov above the axis", rad_to_deg(atan2(top.y, -top.z)), FOV * 0.5, 0.001)
	var right := Boxes.ray_dir(level, FOV, size, 1280.0, 360.0)
	t.near("ray: the right edge tan is tan(fov/2) times the aspect", right.x / -right.z, tan(deg_to_rad(FOV) * 0.5) * 1280.0 / 720.0, 0.0001)

	# Planted wall.
	var xf0 := Transform3D(Basis(Vector3.RIGHT, -PITCH), Vector3(0.0, CAM_H, 0.0))
	var left_wall := func(o: Vector3, d: Vector3, _r: float) -> float: return wall_hit(o, d, 0.0)
	var m1 := Boxes.measure(xf0, FOV, size, ground, left_wall, FAR)
	var cols: Array = m1["skyline_cols"]
	var worst := 0.0
	for i in range(0, 16):
		var want := wall_top_row(xf0, FOV, size, Boxes.column_px(i, size.x))
		worst = maxf(worst, absf(float(cols[i]) - want))
	t.check("planted: the 16 wall columns sit on the wall-top row, worst error %.2f px" % worst, worst <= 1.0)
	t.check("planted: the wall lifts those columns above the flat skyline", float(cols[0]) < want_sky - 20.0 and float(cols[15]) < want_sky - 20.0)
	var m0 := Boxes.measure(xf0, FOV, size, ground, none_world, FAR)
	var moved := 0
	for i in range(16, 33):
		moved += 0 if cols[i] == (m0["skyline_cols"] as Array)[i] else 1
	t.check("planted: the 17 clear columns stay where the flat plane puts them (%d moved)" % moved, moved == 0 and absf(float(cols[16]) - want_sky) <= 1.0)
	t.check("planted: the median follows the clear majority (%s)" % str(m1["skyline_y"]), absf(float(m1["skyline_y"]) - want_sky) <= 1.0)
	var big_wall := func(o: Vector3, d: Vector3, _r: float) -> float: return wall_hit(o, d, 1.0e6)
	var m2 := Boxes.measure(xf0, FOV, size, ground, big_wall, FAR)
	var sorted: Array = (m2["skyline_cols"] as Array).duplicate()
	sorted.sort()
	t.check("planted: with the wall across every column the median is the wall's (%s, flat %.1f)" % [str(m2["skyline_y"]), want_sky], int(m2["skyline_y"]) == int(sorted[16]) and float(m2["skyline_y"]) < want_sky - 20.0)
	t.check("planted: the haze box moves with the median", (m2["haze_box_median"] as Array)[1] == int(m2["skyline_y"]) + 5)

	# Sky band: kept samples are only rays that hit nothing within the far plane, in the rows just above each column's skyline.
	var all_sky := true
	for q in m1["haze_samples"]:
		all_sky = all_sky and not is_finite(Boxes.hit_dist(xf0, Boxes.ray_dir(xf0, FOV, size, float(q[0]) + 0.5, float(q[1]) + 0.5), ground, left_wall, FAR))
	t.check("sky: every kept sample is a no-hit ray (%d kept)" % int(m1["haze_sample_count"]), all_sky and int(m1["haze_sample_count"]) > 0)
	var m0b := Boxes.measure(xf0, FOV, size, ground, none_world, FAR)
	t.check("sky: the bare far plane keeps samples above its skyline (%d), valid" % int(m0b["haze_sample_count"]), int(m0b["haze_sample_count"]) >= 40 and bool(m0b["valid"]))
	var all_above := true
	for q in m0b["haze_samples"]:
		all_above = all_above and float(q[1]) <= float((m0b["skyline_cols"] as Array).max())
	t.check("sky: kept rows lie above the skyline", all_above)
	# Over the wall columns the sky band sits above the wall top (the sky over the wall), never on it: already covered by all_sky.
	var on_wall := 0
	for q in m1["haze_samples"]:
		if q[0] < 640:
			on_wall += 1
	t.check("sky: columns behind a 100 m wall keep sky above its top (%d left), not wall" % on_wall, on_wall > 0 and all_sky)
	# A physics box at 400 m: none on the box; ground in front of it is not sky either.
	var far_wall := func(o: Vector3, d: Vector3, _r: float) -> float: return wall_hit(o, d, 0.0, 400.0)
	var m4 := Boxes.measure(xf0, FOV, size, ground, far_wall, FAR)
	var on_box := 0
	for q in m4["haze_samples"]:
		if is_finite(wall_hit(xf0.origin, Boxes.ray_dir(xf0, FOV, size, float(q[0]) + 0.5, float(q[1]) + 0.5), 0.0, 400.0)):
			on_box += 1
	t.check("sky: a physics box at 400 m keeps no samples on itself (%d)" % on_box, on_box == 0)
	# A column whose skyline is the top row keeps none: a camera on a plain looking straight down the ground has no row above.
	var steep := Transform3D(Basis(Vector3.RIGHT, -1.45), Vector3(0.0, CAM_H, 0.0))
	var ms := Boxes.measure(steep, FOV, size, ground, none_world, FAR)
	t.check("sky: columns whose skyline is the top row keep none (skyline %s, kept %d)" % [str(ms["skyline_y"]), int(ms["haze_sample_count"])], int(ms["skyline_y"]) <= 2 and int(ms["haze_sample_count"]) == 0)
	var under := Boxes.measure(Transform3D(xf0.basis, Vector3(0.0, -5.0, 0.0)), FOV, size, ground, none_world, FAR)
	t.check("sky: a camera under the ground is flagged and invalid", bool(under["camera_below_ground"]) and not bool(under["valid"]))

	# Negative.
	var m3 := Boxes.measure(xf0, FOV, size, Callable(self, "nothing"), none_world, FAR)
	t.check("negative: no ground gives no hit in any column", (m3["skyline_cols"] as Array).count(null) == 33)
	t.check("negative: no skyline and no haze box", m3["skyline_y"] == null and m3["haze_box_median"] == null and m3["haze_box_hit_share"] == null and m3["haze_sample_count"] == 0 and not m3["valid"])

	# The audit's chase rule: pose_camera matches the audit's camera for a pose (anchor + arm behind at the pitch).
	var cam := Boxes.pose_camera({"x": 10.0, "z": 20.0, "yaw": 0.5}, ground, "mid")
	var xf: Transform3D = cam["xf"]
	t.near("chase: the mid lens is 72.5 degrees", float(cam["fov"]), 72.5)
	t.near("chase: pitched -0.30 about the yawed frame", (-xf.basis.z).y, sin(-0.30), 0.0001)
	t.near("chase: height is anchor 1.8 m plus arm 9 m * sin(0.30)", xf.origin.y, 1.8 + 9.0 * sin(0.30), 0.0001)
	var eye := Boxes.pose_camera({"x": 0.0, "z": 0.0, "yaw": 0.0, "cam": [1.0, 2.0, 3.0], "look": [1.0, 2.0, -7.0]}, ground, "mid")
	t.check("eye: stands at cam, looks at look, lens 72.5", (eye["xf"] as Transform3D).origin == Vector3(1.0, 2.0, 3.0) and (-(eye["xf"] as Transform3D).basis.z).distance_to(Vector3(0.0, 0.0, -1.0)) < 0.0001 and float(eye["fov"]) == 72.5)
	quit(t.verdict())
