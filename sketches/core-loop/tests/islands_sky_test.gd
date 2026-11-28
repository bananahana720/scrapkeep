extends SceneTree

# Scope: an energy floor plus pins, not a sky-brightness guard. The gap checks swap only the grade energy (old = live with energy 0.95), so they
# reduce to energy / 0.95; the other golden grade terms are pinned to their base values below, so a change to them fails here instead of cancelling.
#
# Rule: the islands (stage 5, the golden look) read ground against horizon by at least 10 L* in every valid chase pose
# (purpose: #241 comment 6367471497; the 10 L* bar: 6355922548; the measured -8.46 and -7.52 and the open poses: World's receipt 6356177813). World's fitted haze boxes (tools/park_horizon_boxes.gd, park_horizon_lstar.py) measured
# 9 of 11 valid poses passing on the 3060 at e9484509; pose 26 read -8.46 and pose 159 -7.52 because their sky is darker, not their floor.
#
# Model, evidence limit: this is the sky shader's math (time_sky.gdshader, in GDScript, over the shared panorama and the golden grade) at the
# pose's own view directions, not a render. The grade scales the sky linearly, and the 3060 sky L* followed 0.510 x Y^0.410 across the 11 poses
# (Y the modelled sky luminance; leaving one pose out the exponent ranged 0.36 to 0.46), so a pose's new sky L* is its measured one with Y
# multiplied by new/old modelled Y, raised to SKY_EXPONENT, and the gap is its measured near-floor L* minus that. The floor is held where the 3060
# measured it. The bench (RTX 3060) has the last word; this pins the grade from falling back under the number the model says is needed.
#
# Poses (idx, chase yaw in radians, the fitted skyline row, near-floor L*, sky L*) are the 11 valid islands poses of the r349 audit at e9484509
# (measured anchors: branch scratch/render-r349-e9484509 at a309ddc5, render-evidence/r349-e9484509/e9484509/islands/ frames and poses.json)
# with the boxes tool run on acb55972, mid camera (arm 9, fov 72.5, pitch -0.30 as tools/park_props_audit.gd CAMERAS and CAM_PITCH); pose 69
# is invalid (camera under the heightfield). Sky samples: every 16th column, rows skyline-12 to skyline-2 every 2 (the tool's band).
#
# The 3060 bench (23 Oct, scratch merge e6d06658 of c957ab6c, /mnt/project-files/3060-bench-results.md) read the energy lift short: pose 26
# -12.15 (passes), pose 159 -8.45 against -7.33 on the base, so 1.316x the sky moved pose 159 only 1.1 L*. The energy also feeds the sky's
# ambient and reflections, so the floor rose with the sky; the "floor held" premise above did not hold. The fix that remains is away_lift:
# time_sky.gdshader multiplies the low sky 80 or more degrees off the sun's bearing by 1 + away_lift, in the drawn background only (not the
# radiance pass), so the floor does not rise with it. Pose 159 needs about 2.5 L* more (the coordinator's ruling on the bench row); at
# L* about 63 that is a sky Y ratio of about 1.10, and AGX_ROOM below leaves room for the tonemap compressing it. On the cloud renderer
# (xvfb, opengl3, all 11 r349 poses) away_lift 0.5 moved pose 159's haze L* +8.1 and pose 26's +7.4, every near-floor L* unchanged; 0.5 ships.
# The modelled gain at 0.5 clears NEED_DRAWN x AGX_ROOM by 0.004, so any cut to the lift fails here.
#
# Controls (planted): the pre-change grade (energy 0.95) must leave poses 26 and 159 under the bar; a sky dimmer than old must read darker; a
# doubled sun glow alone must not reach the lift pose 159 needs (the glow adds 0.017 Y there against a base of 0.34 Y).

const T := preload("res://tests/support/t.gd")
const WorldLook := preload("res://src/presentation/world_look.gd")
const PaletteMaterials := preload("res://src/presentation/palette_materials.gd")

const POSES := [
	[11, 2.24554, 230, 51.70, 65.46],
	[26, 2.06075, 221, 55.36, 63.82],
	[32, 2.77070, 222, 36.18, 67.32],
	[74, -3.14159, 213, 49.85, 69.02],
	[81, 2.67795, 244, 54.31, 67.54],
	[95, -2.32215, 226, 52.55, 62.79],
	[99, -2.32215, 243, 51.42, 63.32],
	[104, -2.69549, 245, 42.25, 64.88],
	[142, 2.31917, 176, 52.95, 64.95],
	[159, 2.10661, 127, 54.32, 61.84],
	[222, -2.97644, 217, 50.98, 67.07],
]
const BAR := 10.0 # L*, per valid pose, either sign (the ruling in 6355922548)
# L* the model keeps over the bar. A chosen tolerance, not a measured one: it is set against the model's own fit error (9 of 11 poses within
# 1.6 L*, pose 159 off by 4.2) and the exponent's spread (0.36 to 0.46 leaving one pose out of the fuller-sample fit), and there is no source for 0.25 beyond that choice. With it the energy
# floor is about 1.22 (pose 159: Y ratio 1.287 x 0.95 = 1.2225); the grade ships 1.25, the round value above it. The bench has the last word.
const MARGIN := 0.25
const SKY_EXPONENT := 0.410 # 3060 sky luminance = 0.510 x modelled Y ^ 0.410, least squares over this test's own modelled Y for the 11 poses
const OLD_ENERGY := 0.95 # the golden grade before this change
# The golden grade's other terms at acb55972 (git show acb55972:sketches/core-loop/src/presentation/world_look.gd), pinned so only energy moves.
const BASE_TOP := Color("c9c2c8")
const BASE_HORIZON := Color("ffb47a")
const BASE_RECOLOR := 0.45
const BASE_HIGHLIGHT := 2.0
const BASE_GLOW := Color("c8652a")
const FIT_SCALE := 0.510 # 3060 sky luminance = FIT_SCALE x Y ^ SKY_EXPONENT
const FIT_TOLERANCE := 1.6 # L*, for 9 of 11 poses (poses 74 and 159 miss it)
const FIT_WORST := 4.3 # L*, pose 159, which the fit reads high
const CAM_PITCH := -0.30
const FOV := 72.5
const SIZE := Vector2(1280.0, 720.0)
const AWAY_LIFT := 0.5 # golden grade, see the header
# The drawn-sky Y ratio pose 159 must get from away_lift: 1.10 for 2.5 L* at L* 63, times 1.1 room for the tonemap (a chosen tolerance).
const AGX_ROOM := 1.1
const NEED_DRAWN := 1.10
const EXPECTED_CHECKS := 58

var t := T.new("islands_sky_test")
var _pano: Image


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var tex := load(PaletteMaterials.HDRI_SKY) as Texture2D
	_pano = tex.get_image().duplicate()
	if _pano.is_compressed():
		_pano.decompress()
	var golden: Dictionary = WorldLook.TIME_ROWS.golden
	var live := WorldLook.grade(golden)
	var old := live.duplicate()
	old["shader_parameter/energy"] = OLD_ENERGY

	# The sun and the stage the row serves are unchanged.
	t.eq("sun colour is ffa35c", golden.sun_color, Color("ffa35c"))
	t.near("sun energy is 1.9", float(golden.sun_energy), 1.9)
	t.eq("sun rotation is (-16, 20, 0)", golden.sun_rotation, Vector3(-16.0, 20.0, 0.0))
	t.eq("stage 5 is golden", WorldLook.time_id(5), "golden")
	var users := 0
	for stage in WorldLook.STAGE_TIME:
		users += 1 if WorldLook.STAGE_TIME[stage] == "golden" else 0
	t.eq("golden serves one stage", users, 1)
	t.check("the sky grade is a lift, not a drop", float(live["shader_parameter/energy"]) > OLD_ENERGY, str(live["shader_parameter/energy"]))

	# The other grade terms are the base values (read from the row, compared with the constants above).
	var grade: Dictionary = golden.grade
	t.eq("golden top tint is the base", grade.top, BASE_TOP)
	t.eq("golden horizon tint is the base", grade.horizon, BASE_HORIZON)
	t.near("golden recolor is the base", float(grade.recolor), BASE_RECOLOR)
	t.near("golden highlight cap is the base", float(grade.highlight), BASE_HIGHLIGHT)
	t.eq("golden glow is the base", grade.glow, BASE_GLOW)
	t.check("the live grade differs from the old one in energy only (away_lift is checked on its own)", _only_energy_differs(live, old))

	# Model agrees with itself: the old grade reproduces the measured sky (ratio 1), and the model ranks the anti-sun views as World saw.
	var y_old := {}
	var y_new := {}
	for pose in POSES:
		y_old[pose[0]] = _sky_y(pose, old)
		y_new[pose[0]] = _sky_y(pose, live)
	# The curve's source: FIT_SCALE x Y^SKY_EXPONENT over the old grade's modelled Y reproduces each measured sky L*.
	var within := 0
	var worst := 0.0
	for pose in POSES:
		var err := absf(_to_lstar(FIT_SCALE * pow(float(y_old[pose[0]]), SKY_EXPONENT)) - float(pose[4]))
		within += 1 if err <= FIT_TOLERANCE else 0
		worst = maxf(worst, err)
	t.check("the fit reproduces the measured sky within %.1f L* on %d of 11 poses" % [FIT_TOLERANCE, within], within >= 9)
	t.check("the fit's worst pose is within %.1f L* (%.2f)" % [FIT_WORST, worst], worst <= FIT_WORST)
	t.check("poses 26 and 159 are the two views furthest from the sun's bearing", _furthest_from_sun(live) == [26, 159], str(_furthest_from_sun(live)))
	var anti := float(y_new[159]) / float(y_old[159])
	t.near("energy scales the whole sky: new/old Y at pose 159 is the energy ratio", anti, float(live["shader_parameter/energy"]) / OLD_ENERGY, 0.0005)
	t.near("energy scales the whole sky: new/old Y at pose 26 is the energy ratio", float(y_new[26]) / float(y_old[26]), float(live["shader_parameter/energy"]) / OLD_ENERGY, 0.0005)

	# The needed lift from the measured gaps, by the 3060 curve: pose 159 needs +2.48 L* (a ratio of Y of 1.258), pose 26 +1.54 (1.150).
	var need159 := pow(_to_y(61.84 + (BAR - (61.84 - 54.32))) / _to_y(61.84), 1.0 / SKY_EXPONENT)
	var need26 := pow(_to_y(63.82 + (BAR - (63.82 - 55.36))) / _to_y(63.82), 1.0 / SKY_EXPONENT)
	t.near("pose 159 needs a 1.258x modelled sky (+2.48 L*)", need159, 1.258, 0.005)
	t.near("pose 26 needs a 1.150x modelled sky (+1.54 L*)", need26, 1.150, 0.005)
	t.check("the live grade lifts pose 159's modelled sky by more than it needs (%.3f vs %.3f)" % [anti, need159], anti > need159)
	t.check("the live grade lifts pose 26's modelled sky by more than it needs", float(y_new[26]) / float(y_old[26]) > need26)

	# Per-pose gaps: old fails on 26 and 159, live passes everywhere with the margin, and no sky gets darker.
	var worst_old := -INF
	var worst_live := -INF
	var gaps_old := {}
	var gaps_live := {}
	for pose in POSES:
		var idx: int = pose[0]
		gaps_old[idx] = _gap(pose, float(y_old[idx]), float(y_old[idx]))
		gaps_live[idx] = _gap(pose, float(y_new[idx]), float(y_old[idx]))
		worst_old = maxf(worst_old, gaps_old[idx])
		worst_live = maxf(worst_live, gaps_live[idx])
		t.check("pose %d: modelled sky is not darker than before (%.4f to %.4f)" % [idx, float(y_old[idx]), float(y_new[idx])], float(y_new[idx]) >= float(y_old[idx]))
		t.check("pose %d: modelled gap %.2f is at least %.2f L* of ground under horizon" % [idx, gaps_live[idx], BAR + MARGIN], gaps_live[idx] <= -(BAR + MARGIN))
	# Planted control: the old grade, through the same arithmetic, is the measured -8.46 and -7.52 and fails the bar.
	t.near("control: old grade reproduces pose 26's measured gap", float(gaps_old[26]), -8.46, 0.01)
	t.near("control: old grade reproduces pose 159's measured gap", float(gaps_old[159]), -7.52, 0.01)
	t.check("control: the old grade fails the bar on pose 26", float(gaps_old[26]) > -(BAR + MARGIN))
	t.check("control: the old grade fails the bar on pose 159", float(gaps_old[159]) > -(BAR + MARGIN))
	# Planted control 2: a dimmer sky fails the no-darkening check.
	var dim := live.duplicate()
	dim["shader_parameter/energy"] = OLD_ENERGY * 0.9
	t.check("control: a sky at 0.9x the old energy is darker at pose 159", _sky_y(POSES[9], dim) < float(y_old[159]))
	# Planted control 3: the glow alone, doubled, lifts pose 159 by far less than the lift it needs (the anti-sun poses are base-dominated).
	var glow := old.duplicate()
	glow["shader_parameter/glow"] = ((old["shader_parameter/glow"] as Color).srgb_to_linear() * 2.0).linear_to_srgb() # twice the linear light
	t.check("control: doubling the glow alone falls short of the lift pose 159 needs", _sky_y(POSES[9], glow) / float(y_old[159]) < need159, "%.3f vs %.3f" % [_sky_y(POSES[9], glow) / float(y_old[159]), need159])
	t.check("worst live gap is under the bar and the old worst is over it", worst_live <= -(BAR + MARGIN) and worst_old > -BAR, "%.2f / %.2f" % [worst_live, worst_old])
	_away(live)
	t.eq("every check ran", t.checks, EXPECTED_CHECKS)
	quit(t.verdict())


# away_lift: pinned on golden and absent elsewhere, drawn-only, aimed at the anti-sun views, and big enough for pose 159 with room.
func _away(live: Dictionary) -> void:
	t.near("golden away_lift is %.2f" % AWAY_LIFT, float(live["shader_parameter/away_lift"]), AWAY_LIFT)
	var others := 0
	for id in WorldLook.TIME_ROWS:
		if id != "golden" and float(WorldLook.grade(WorldLook.TIME_ROWS[id])["shader_parameter/away_lift"]) != 0.0:
			others += 1
	t.eq("no other time row lifts its anti-sun sky", others, 0)
	var shader: String = load("res://src/presentation/time_sky.gdshader").code
	t.check("the lift skips the radiance pass, so the floor's sky light does not rise", shader.contains("!AT_CUBEMAP_PASS && away_lift"))
	var gain159 := _sky_y(POSES[9], live, true) / _sky_y(POSES[9], live)
	var gain26 := _sky_y(POSES[1], live, true) / _sky_y(POSES[1], live)
	t.check("pose 159's drawn sky gains at least %.3f (%.3f)" % [NEED_DRAWN * AGX_ROOM, gain159], gain159 >= NEED_DRAWN * AGX_ROOM)
	t.check("pose 26's drawn sky gains too (%.3f)" % gain26, gain26 > 1.05)
	var sun: Vector3 = live["shader_parameter/sun_dir"]
	var at_sun := Vector3(sun.x, 0.05, sun.z).normalized()
	t.near("a view at the sun's bearing gets no lift", _sky(at_sun, live, true).r / _sky(at_sun, live).r, 1.0, 1e-6)
	var none := live.duplicate()
	none["shader_parameter/away_lift"] = 0.0
	t.check("control: with no lift pose 159's drawn sky misses the gain", _sky_y(POSES[9], none, true) / _sky_y(POSES[9], none) < NEED_DRAWN * AGX_ROOM)
	var short := live.duplicate()
	short["shader_parameter/away_lift"] = 0.4
	t.check("control: a lift of 0.4 misses pose 159's gain", _sky_y(POSES[9], short, true) / _sky_y(POSES[9], short) < NEED_DRAWN * AGX_ROOM)


# CIE L* to relative luminance Y, and back.
func _to_y(lstar: float) -> float:
	var f := (lstar + 16.0) / 116.0
	return f * f * f if f > 6.0 / 29.0 else (f - 16.0 / 116.0) * 108.0 / 841.0


func _to_lstar(y: float) -> float:
	var f := pow(y, 1.0 / 3.0) if y > 216.0 / 24389.0 else (24389.0 / 27.0 * y + 16.0) / 116.0
	return 116.0 * f - 16.0


# The 3060 gap of a pose with its sky luminance scaled from y_old to y_new by the measured curve: measured near L* minus the new sky L*.
func _gap(pose: Array, y_new_pose: float, y_old_pose: float) -> float:
	var sky := _to_lstar(_to_y(float(pose[4])) * pow(y_new_pose / y_old_pose, SKY_EXPONENT))
	return float(pose[3]) - sky


# Mean modelled sky luminance of a pose's haze band under the grade values (the keys WorldLook.grade returns). drawn adds away_lift, which
# the drawn background has and the radiance pass does not.
func _sky_y(pose: Array, g: Dictionary, drawn := false) -> float:
	var basis := Basis(Vector3.UP, float(pose[1])) * Basis(Vector3.RIGHT, CAM_PITCH)
	var th := tan(deg_to_rad(FOV) * 0.5)
	var total := 0.0
	var n := 0
	var skyline: int = pose[2]
	for px in range(4, int(SIZE.x), 16):
		for py in range(skyline - 12, skyline - 1, 2):
			if py < 0:
				continue
			var d := Vector3((2.0 * (float(px) + 0.5) / SIZE.x - 1.0) * th * SIZE.x / SIZE.y, (1.0 - 2.0 * (float(py) + 0.5) / SIZE.y) * th, -1.0)
			var c := _sky(basis * d.normalized(), g, drawn)
			total += c.r * 0.2126729 + c.g * 0.7151522 + c.b * 0.072175
			n += 1
	return total / float(n)


func _furthest_from_sun(g: Dictionary) -> Array:
	var sun: Vector3 = g["shader_parameter/sun_dir"]
	var scored := []
	for pose in POSES:
		var basis := Basis(Vector3.UP, float(pose[1])) * Basis(Vector3.RIGHT, CAM_PITCH)
		var fwd := basis * Vector3(0.0, 0.0, -1.0)
		var away := Vector2(fwd.x, fwd.z).normalized().dot(Vector2(sun.x, sun.z).normalized())
		scored.append([away, pose[0]])
	scored.sort()
	var out := [scored[0][1], scored[1][1]]
	out.sort()
	return out


# time_sky.gdshader's sky(), for a unit eye direction. The panorama is read as the engine does: u = atan(x, -z) wrapped to [0, 2 pi) over 2 pi.
func _sky(eye: Vector3, g: Dictionary, drawn := false) -> Color:
	var u := fposmod(atan2(eye.x, -eye.z) / TAU, 1.0)
	var v := acos(clampf(eye.y, -1.0, 1.0)) / PI
	var w := _pano.get_width()
	var h := _pano.get_height()
	var px := _pano.get_pixel(mini(int(u * w), w - 1), mini(int(v * h), h - 1))
	var hl := float(g["shader_parameter/highlight"])
	var c := Vector3(minf(px.r, hl), minf(px.g, hl), minf(px.b, hl))
	var lum := c.dot(Vector3(0.2126, 0.7152, 0.0722))
	var top := (g["shader_parameter/top_tint"] as Color).srgb_to_linear()
	var hor := (g["shader_parameter/horizon_tint"] as Color).srgb_to_linear()
	var s := clampf((eye.y + 0.05) / 0.65, 0.0, 1.0)
	s = s * s * (3.0 - 2.0 * s)
	var tint := Vector3(hor.r, hor.g, hor.b).lerp(Vector3(top.r, top.g, top.b), s)
	var rc := float(g["shader_parameter/recolor"])
	c = c.lerp(Vector3(lum, lum, lum), rc) * tint
	var toward := maxf(eye.dot((g["shader_parameter/sun_dir"] as Vector3).normalized()), 0.0)
	var low_t := clampf(eye.y / 0.45, 0.0, 1.0)
	var low := 1.0 - low_t * low_t * (3.0 - 2.0 * low_t)
	var glow := (g["shader_parameter/glow"] as Color).srgb_to_linear()
	var add := pow(toward, 4.0) * low + pow(toward, 48.0)
	c += Vector3(glow.r, glow.g, glow.b) * add
	var lift := float(g.get("shader_parameter/away_lift", 0.0))
	if drawn and lift > 0.0:
		var a := clampf((Vector2(eye.x, eye.z).normalized().dot(Vector2(g["shader_parameter/sun_dir"].x, g["shader_parameter/sun_dir"].z).normalized()) - 0.17) / 0.43, 0.0, 1.0)
		var b := clampf(eye.y / 0.8, 0.0, 1.0)
		c *= 1.0 + lift * (1.0 - a * a * (3.0 - 2.0 * a)) * (1.0 - b * b * (3.0 - 2.0 * b))
	c *= float(g["shader_parameter/energy"])
	return Color(c.x, c.y, c.z)


func _only_energy_differs(a: Dictionary, b: Dictionary) -> bool:
	for key in a:
		if key != "shader_parameter/energy" and key != "shader_parameter/away_lift" and a[key] != b[key]:
			return false
	return a["shader_parameter/energy"] != b["shader_parameter/energy"]
