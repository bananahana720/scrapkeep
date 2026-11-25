extends RefCounted


const RING_R := 48.0
const PLAZA_R := 26.0
const GATE_R := 70.0
const SPOKE_W := 5.0

const STATIONS := {
	"gate": [0.0, GATE_R],
	"pet": [55.0, RING_R],
	"skee": [120.0, RING_R],
	"settings": [160.0, RING_R],
	"achieve": [205.0, RING_R],
	"moss": [250.0, RING_R],
	"lockers": [305.0, RING_R],
}

const TRIAL_AT := Vector3(122.0, 0.0, -20.0)
const SANDBOX_AT := Vector3(-122.0, 0.0, 10.0)
const SHORTCUT_AT := Vector3(0.0, 0.0, -36.0)

const DRESSING := [
	["camp_lamp_post", 14.0, RING_R + 4.2, 0.0],
	["camp_lamp_post", 69.0, RING_R + 4.2, 0.0],
	["camp_lamp_post", 134.0, RING_R + 4.2, 0.0],
	["camp_lamp_post", 174.0, RING_R + 4.2, 0.0],
	["camp_lamp_post", 219.0, RING_R + 4.2, 0.0],
	["camp_lamp_post", 264.0, RING_R + 4.2, 0.0],
	["camp_lamp_post", 319.0, RING_R + 4.2, 0.0],
	["camp_signpost", 26.0, PLAZA_R + 2.5, 0.0],
	["camp_fire_pit", 160.0, 15.0, 0.0],
	["camp_bench", 145.0, 19.5, 0.0],
	["camp_bench", 175.0, 19.5, 0.0],
	["camp_shift_board", 194.0, 21.0, 0.0],
	["camp_tarp", 270.0, 20.0, 0.0],
	["camp_tool_rack", 280.0, 56.0, 0.0],
	["camp_crate_stack", 232.0, 57.0, 30.0],
	["camp_barrel", 236.0, 54.0, 0.0],
	["camp_barrel", 330.0, 55.0, 0.0],
	["camp_crate_stack", 90.0, 56.0, -20.0],
	["camp_fence", 240.0, 61.0, 90.0],
	["camp_fence", 244.0, 61.0, 90.0],
	["camp_fence", 248.0, 61.0, 90.0],
	["camp_fence", 252.0, 61.0, 90.0],
	["camp_fence", 256.0, 61.0, 90.0],
	["camp_fence", 260.0, 61.0, 90.0],
]

const BARGE_AT := Vector3(-120.0, 5.0, -125.0)
const BARGE_YAW_DEG := -20.0
const TREES := [[-70.0, -40.0], [75.0, 45.0], [-40.0, 75.0], [40.0, -95.0], [-95.0, 55.0], [100.0, -75.0]]


static func at(bearing: float, r: float) -> Vector3:
	var b := deg_to_rad(bearing)
	return Vector3(r * sin(b), 0.0, -r * cos(b))


static func yaw_to_centre(x: float, z: float) -> float:
	return atan2(-x, -z)


static func station(sid: String) -> Dictionary:
	var row: Array = STATIONS[sid]
	var p := at(row[0], row[1])
	return {"at": p, "yaw": yaw_to_centre(p.x, p.z)}


static func place(origin: Vector3, yaw: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), origin)
