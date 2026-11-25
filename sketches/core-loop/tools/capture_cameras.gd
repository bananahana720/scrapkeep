extends RefCounted

const SIZE := Vector2i(1920, 1080)
const THUMB := Vector2i(480, 270)

const LOOK := {
	"overview": {"eye": Vector3(145.0, 160.0, -240.0), "target": Vector3(0.0, 44.0, 30.0), "fov": 65.0},
	"launch": {"eye": Vector3(-56.0485877990723, 19.6139030456543, -43.2774467468262), "target": Vector3(-53.8485870361328, 19.1139030456543, -32.0774459838867), "fov": 62.0},
	"warden": {"eye": Vector3(-58.0, 23.6000003814697, -29.0), "target": Vector3(-46.0, 19.6000003814697, -12.0), "fov": 56.0},
	"moss": {"eye": Vector3(48.0, 71.0, -78.0), "target": Vector3(36.0, 67.8000030517578, -90.0), "fov": 58.0},
	"pilot": {"eye": Vector3(-67.6782531738281, 36.8234672546387, -126.02904510498), "target": Vector3(-65.0, 35.476634979248, -130.0), "fov": 39.0},
}

const BAY_HOME := Vector3(50, 65, -90)
const BAY := {
	"approach-in": {"eye": Vector3(68.0, 70.2, -92.0), "target": Vector3(49.0, 69.2, -90.0), "fov": 62.0, "ball": Vector3(59.0, 66.0, -90.0), "barge": Vector3.ZERO},
	"approach-out": {"eye": Vector3(42.0, 70.2, -79.0), "target": Vector3(49.5, 68.5, -89.5), "fov": 62.0, "ball": Vector3(43.5, 66.0, -88.5), "barge": Vector3.ZERO},
	"approach-leave": {"eye": Vector3(54.0, 70.5, -86.5), "target": Vector3(70.0, 68.5, -90.0), "fov": 62.0, "ball": Vector3(62.0, 66.0, -90.0), "barge": Vector3.ZERO},
	"dock-0": {"eye": Vector3(48.0, 74.0, -64.0), "target": Vector3(40.0, 68.0, -90.0), "fov": 62.0, "ball": null, "barge": Vector3(26, 16, -12)},
	"dock-1": {"eye": Vector3(48.0, 74.0, -64.0), "target": Vector3(40.0, 68.0, -90.0), "fov": 62.0, "ball": null, "barge": Vector3(12, 7, -5)},
	"dock-2": {"eye": Vector3(48.0, 74.0, -64.0), "target": Vector3(40.0, 68.0, -90.0), "fov": 62.0, "ball": null, "barge": Vector3.ZERO},
}

const ASSET := {
	"asset-front30": {"dir": Vector3(0, 0, -1), "dist": 30.0, "up": 3.0, "fov": 65.0},
	"asset-side30": {"dir": Vector3(1, 0, 0), "dist": 30.0, "up": 3.0, "fov": 65.0},
	"asset-rear30": {"dir": Vector3(0, 0, 1), "dist": 30.0, "up": 3.0, "fov": 65.0},
	"asset-use6": {"dir": Vector3(0, 0, -1), "dist": 6.0, "up": 3.0, "fov": 65.0},
}


const ORTHO := {
	"ortho-front": {"dir": Vector3(1, 0, 0), "up": Vector3.UP},
	"ortho-side": {"dir": Vector3(0, 0, 1), "up": Vector3.UP},
	"ortho-top": {"dir": Vector3(0, 1, 0), "up": Vector3(0, 0, 1)},
}
const ORTHO_DISTANCE := 250.0
const ORTHO_MARGIN := 1.10
const NEAR := 0.05
const FAR := 1800.0


static func names() -> Array:
	return ASSET.keys() + LOOK.keys()


static func is_look(id: String) -> bool:
	return LOOK.has(id) or BAY.has(id)


static func is_bay(id: String) -> bool:
	return BAY.has(id)


static func view(id: String, anchor: Transform3D = Transform3D.IDENTITY, centre := Vector3.ZERO) -> Dictionary:
	if LOOK.has(id):
		return LOOK[id].duplicate()
	if BAY.has(id):
		return {"eye": BAY[id]["eye"], "target": BAY[id]["target"], "fov": BAY[id]["fov"]}
	var row: Dictionary = ASSET[id]
	var flat_basis := Basis(Vector3.UP, atan2(anchor.basis.z.x, anchor.basis.z.z))
	var eye: Vector3 = anchor.origin + flat_basis * (row["dir"] * row["dist"]) + Vector3.UP * row["up"]
	return {"eye": eye, "target": centre, "fov": row["fov"]}


static func is_ortho(id: String) -> bool:
	return ORTHO.has(id)


static func ortho_view(id: String, box: AABB) -> Dictionary:
	var row: Dictionary = ORTHO[id]
	var centre := box.get_center()
	var dir: Vector3 = row["dir"]
	if id == "ortho-front" and centre.x >= 0.0:
		dir = -dir
	var span := maxf(box.size.y, maxf(box.size.z, box.size.x)) * ORTHO_MARGIN
	return {"eye": centre + dir * ORTHO_DISTANCE, "target": centre, "up": row["up"], "size": span}


static func aim(camera: Camera3D, eye: Vector3, target: Vector3, fov: float) -> void:
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.global_position = eye
	camera.look_at(target)
	camera.fov = fov


static func aim_ortho(camera: Camera3D, v: Dictionary) -> void:
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = v["size"]
	camera.near = NEAR
	camera.far = FAR
	camera.global_position = v["eye"]
	camera.look_at(v["target"], v["up"])


const TARGET := {
	"play": {"ball_xz": Vector2(-80.0, -93.0), "clearance": 1.2,
		"eye_offset": Vector3(0.0, 3.0, -8.0), "target_offset": Vector3(0.0, 1.0, 24.0),
		"fov": 70.0, "enemies_xz": [Vector2(-68.0, -65.0), Vector2(-60.0, -51.0)]},
	"site": {"eye_offset": Vector3(-12.0, 7.0, -17.0),
		"target_offset": Vector3(0.0, 3.0, 0.0), "fov": 56.0},
	"wide": {"eye": Vector3(145.0, 160.0, -240.0),
		"target": Vector3(0.0, 44.0, 30.0), "fov": 65.0},
}

const TARGET_REACH := {"ball_xz": Vector2(-34.0, -118.0), "face_xz": Vector2(-58.0, -116.8),
	"clearance": 1.2, "fov": 70.0, "enemies_xz": []}
