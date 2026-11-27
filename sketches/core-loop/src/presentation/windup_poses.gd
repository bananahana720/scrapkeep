extends RefCounted

const POSES := {
	"e01_brace_back": {"wind": [16.0, 0.0, 0.0, 0.86], "release": [-14.0, 0.0, 0.0, 1.10]},
	"e02_tube_raise": {"wind": [22.0, 0.0, 0.0, 1.04], "release": [30.0, 0.0, 0.0, 0.90]},
	"e03_leap_spread": {"wind": [-6.0, 0.0, 0.0, 0.80], "release": [8.0, 0.0, 0.0, 1.18]},
	"e04_charge_close": {"wind": [-12.0, 0.0, 0.0, 0.90], "release": [-20.0, 0.0, 0.0, 1.06]},
	"e05_stack_hoist": {"wind": [6.0, 0.0, 0.0, 1.14], "release": [-8.0, 0.0, 0.0, 0.84]},
	"e06_harpoon_draw": {"wind": [8.0, 0.0, 18.0, 1.0], "release": [-6.0, 0.0, -12.0, 1.04]},
	"e07_net_umbrella": {"wind": [14.0, 0.0, 0.0, 1.10], "release": [-10.0, 0.0, 0.0, 0.92]},
	"e08_loop_raise": {"wind": [10.0, 12.0, 0.0, 1.04], "release": [-6.0, -10.0, -16.0, 1.0]},
	"e09_pads_raise": {"wind": [20.0, 0.0, 0.0, 1.10], "release": [-22.0, 0.0, 0.0, 0.80]},
	"e10_dish_wall": {"wind": [-6.0, 0.0, 0.0, 0.90], "release": [-10.0, 0.0, 0.0, 1.04]},
	"e11_cable_guide": {"wind": [12.0, 0.0, 0.0, 1.0], "release": [-8.0, 0.0, 0.0, 1.0]},
	"e12_hoops_planes": {"wind": [0.0, 14.0, 0.0, 1.06], "release": [0.0, -8.0, 0.0, 0.92]},
	"e13_paddle_side": {"wind": [0.0, 4.0, 32.0, 1.0], "release": [0.0, -4.0, -28.0, 1.0]},
	"e14_lip_raise": {"wind": [18.0, 0.0, 0.0, 0.94], "release": [-14.0, 0.0, 0.0, 1.06]},
	"e15_cup_splay": {"wind": [0.0, 0.0, 0.0, 0.84], "release": [0.0, 0.0, 0.0, 1.12]},
	"e16_vents_open": {"wind": [0.0, 0.0, 0.0, 1.10], "release": [0.0, 0.0, 0.0, 0.88]},
	"e18_elbow_telescope": {"wind": [8.0, 0.0, 0.0, 1.12], "release": [-10.0, 0.0, 0.0, 0.94]},
	"e31_prop_kicked": {"wind": [10.0, 0.0, 0.0, 0.90], "release": [-12.0, 0.0, 0.0, 1.08]},
}
const SHIVER_FROM := 0.75
const SHIVER_DEGREES := 2.5
const SHIVER_HZ := 12.0
const RELEASE_SNAP := 0.04
const RELEASE_SECONDS := 0.28


static func has_pose(pose: String) -> bool:
	return POSES.has(pose)


static func _basis(v: Array, amount: float) -> Basis:
	var h := lerpf(1.0, float(v[3]), amount)
	var w := 1.0 / sqrt(h)
	var turn := Basis(Vector3.UP, deg_to_rad(float(v[2]) * amount)) \
		* Basis(Vector3.BACK, deg_to_rad(float(v[1]) * amount)) \
		* Basis(Vector3.RIGHT, deg_to_rad(float(v[0]) * amount))
	return turn * Basis.from_scale(Vector3(w, h, w))


static func windup(pose: String, progress: float, age: float, motion := 1.0) -> Basis:
	if not POSES.has(pose) or motion <= 0.0:
		return Basis.IDENTITY
	var p := clampf(progress, 0.0, 1.0)
	var lean := 1.0 - (1.0 - p) * (1.0 - p)
	var out := _basis(POSES[pose]["wind"], lean * motion)
	if p > SHIVER_FROM:
		var shiver := SHIVER_DEGREES * (p - SHIVER_FROM) / (1.0 - SHIVER_FROM) * sin(TAU * SHIVER_HZ * age)
		out = Basis(Vector3.RIGHT, deg_to_rad(shiver * motion)) * out
	return out


static func release(pose: String, age: float, motion := 1.0) -> Basis:
	if not POSES.has(pose) or motion <= 0.0 or age < 0.0 or age >= RELEASE_SECONDS:
		return Basis.IDENTITY
	if age < RELEASE_SNAP:
		var k := age / RELEASE_SNAP
		var wind: Array = POSES[pose]["wind"]
		var hit: Array = POSES[pose]["release"]
		return _basis([lerpf(wind[0], hit[0], k), lerpf(wind[1], hit[1], k), lerpf(wind[2], hit[2], k), lerpf(wind[3], hit[3], k)], motion)
	var e := (age - RELEASE_SNAP) / (RELEASE_SECONDS - RELEASE_SNAP)
	return _basis(POSES[pose]["release"], (1.0 - e * e * (3.0 - 2.0 * e)) * motion)
