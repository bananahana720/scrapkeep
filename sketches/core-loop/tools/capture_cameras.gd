extends RefCounted

# The named capture cameras of the asset sheet ("Cameras and evidence returned by every unit").
# One table, addressed by name, shared by look_capture.gd and asset_capture.gd.
#
# LOOK holds the five look views, world-fixed, as recorded in look-pass-4a final/frames.json.
# ASSET holds the four asset views, defined against a ground anchor and the asset centre:
# the eye sits `dist` metres from the anchor along `dir` (anchor-local, the asset faces -z) and
# `up` metres above it, aimed at the asset centre.
const SIZE := Vector2i(1920, 1080)
const THUMB := Vector2i(480, 270)

const LOOK := {
	"overview": {"eye": Vector3(145.0, 160.0, -240.0), "target": Vector3(0.0, 44.0, 30.0), "fov": 65.0},
	"launch": {"eye": Vector3(-56.0485877990723, 19.6139030456543, -43.2774467468262), "target": Vector3(-53.8485870361328, 19.1139030456543, -32.0774459838867), "fov": 62.0},
	"warden": {"eye": Vector3(-58.0, 23.6000003814697, -29.0), "target": Vector3(-46.0, 19.6000003814697, -12.0), "fov": 56.0},
	"moss": {"eye": Vector3(48.0, 71.0, -78.0), "target": Vector3(36.0, 67.8000030517578, -90.0), "fov": 58.0},
	"pilot": {"eye": Vector3(-67.6782531738281, 36.8234672546387, -126.02904510498), "target": Vector3(-65.0, 35.476634979248, -130.0), "fov": 39.0},
}

const ASSET := {
	"asset-front30": {"dir": Vector3(0, 0, -1), "dist": 30.0, "up": 3.0, "fov": 65.0},
	"asset-side30": {"dir": Vector3(1, 0, 0), "dist": 30.0, "up": 3.0, "fov": 65.0},
	"asset-rear30": {"dir": Vector3(0, 0, 1), "dist": 30.0, "up": 3.0, "fov": 65.0},
	"asset-use6": {"dir": Vector3(0, 0, -1), "dist": 6.0, "up": 3.0, "fov": 65.0},
}


static func names() -> Array:
	return ASSET.keys() + LOOK.keys()


static func is_look(id: String) -> bool:
	return LOOK.has(id)


# {eye, target, fov} for a named camera. Look views ignore anchor and centre.
static func view(id: String, anchor: Transform3D = Transform3D.IDENTITY, centre := Vector3.ZERO) -> Dictionary:
	if LOOK.has(id):
		return LOOK[id].duplicate()
	var row: Dictionary = ASSET[id]
	var flat_basis := Basis(Vector3.UP, atan2(anchor.basis.z.x, anchor.basis.z.z))
	var eye: Vector3 = anchor.origin + flat_basis * (row["dir"] * row["dist"]) + Vector3.UP * row["up"]
	return {"eye": eye, "target": centre, "fov": row["fov"]}


static func aim(camera: Camera3D, eye: Vector3, target: Vector3, fov: float) -> void:
	camera.global_position = eye
	camera.look_at(target)
	camera.fov = fov
