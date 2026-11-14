extends "res://src/combat/counter.gd"

# The hooker (DESIGN-V2 section 10): a harpoon gun on a tall anchor post. The warning is
# a lane from the post toward the ball; when it fills, a ball the lane contains is
# harpooned and tethered to the post's head. The line has the length it caught you at
# and reels in: roll away and it pulls you back toward the anchor. It snaps when you
# boost, when you outrun it (planar speed at SNAP_SPEED), or at once when your heft is
# at or above its rating. A snap slings you forward: growth and speed are the counter.
# Flow (design-v3/SPILLWAY-ROSTER.md): the Spillway's grapple lesson is hook posts, so a
# harpoon bite on any post or wall also snaps the tether (the "hook" break, holds.gd kicks you
# along your new line). Being caught is a pendulum you can choose to leave by your own line.

const LANE_LENGTH := 24.0
const LANE_WIDTH := 2.4
const POST_HEIGHT := 4.2
const SPRING := 5.0
const RADIAL_DAMP := 3.0
const REEL := 2.5
const MIN_ROPE := 3.0
const SNAP_SPEED := 19.0
const RATING_BASE := 2.2
const RATING_PER_THREAT := 0.5
const HP := 55.0

var rating := RATING_BASE
var rope := 0.0
var snaps := 0


func _configure(threat: float) -> void:
	_set_health(HP * threat)
	scrap_value = 4
	weight = 1.5
	warn_seconds = 1.0
	live_seconds = 2.2
	rest_seconds = 4.0
	attack_range = 22.0
	keep_near = 12.0
	rating = RATING_BASE + RATING_PER_THREAT * (threat - 1.0)


# C14 dressing (enemy_hooker.glb). The counter's capsule crew is replaced by the glb's crew,
# post and anchor crown (the collider _add_capsule laid stays); the harpoon rides its own
# node at the cradle. The glb is read once; every hooker shares its meshes and adds only its
# own flashing body material as a surface override. The resting body is the Fleet oxide
# _add_capsule already set (RUST), so the hit flash and the event colour are unchanged.
const COCK := 0.45
const THRUST := 0.3

static var _warned_asset := false
static var _shared: Dictionary = {}

var _harpoon: MeshInstance3D
var _rest_z := 0.0


func _build_tool() -> void:
	_crew.free()
	_crew = null
	var parts := _parts()
	var dress := Node3D.new()
	dress.name = "HookerBody"
	_visual_parent().add_child(dress)
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = parts["body"]
	body.set_surface_override_material(parts["flash"], _material)
	dress.add_child(body)
	_harpoon = MeshInstance3D.new()
	_harpoon.name = "HookerHarpoon"
	_harpoon.mesh = parts["harpoon"]
	_harpoon.position = parts["pivot"]
	_rest_z = _harpoon.position.z
	dress.add_child(_harpoon)


static func _parts() -> Dictionary:
	if not _shared.is_empty():
		return _shared
	var scene := (load(ModelVariants.path("res://assets/models/world_one/enemy_hooker.glb")) as PackedScene).instantiate()
	var painted := Palette.solid(Color.WHITE)
	painted.vertex_color_use_as_albedo = true
	var flash := 0
	var meshes := {}
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (node as MeshInstance3D).mesh.duplicate()
		for i in mesh.get_surface_count():
			var surface_material := mesh.surface_get_material(i)
			if surface_material == null and not _warned_asset:
				_warned_asset = true
				push_warning("hooker: surface has no material; using default finish")
			var slot := surface_material.resource_name if surface_material != null else ""
			if slot == "fleet_paint":
				flash = i
			mesh.surface_set_material(i, painted)
		meshes[node.name] = mesh
	var pivot := scene.find_child("HookerHarpoonMesh", true, false) as Node3D
	_shared = {"body": meshes["HookerBody"], "harpoon": meshes["HookerHarpoonMesh"], "flash": flash,
		"pivot": pivot.position + (pivot.get_parent() as Node3D).position}
	scene.free()
	return _shared


# The harpoon cocks back along its own axis over the warning, easing with the warning's own
# progress (WARN phase, _warn_progress()), lunges forward while the line is live and settles
# in the roam. It reads existing state and adds no clock; anchor() and the tether do not move.
func _pose() -> void:
	if _harpoon == null:
		return
	var z := 0.0
	match phase:
		Phase.WARN:
			var t := clampf(_warn_progress(), 0.0, 1.0)
			z = -COCK * t * t * (3.0 - 2.0 * t)
		Phase.LIVE:
			z = THRUST
		_:
			z = lerpf(_harpoon.position.z - _rest_z, 0.0, 1.0 - exp(-10.0 * get_physics_process_delta_time()))
	_harpoon.position.z = _rest_z + z


func anchor() -> Vector3:
	return global_position + Vector3(0.0, POST_HEIGHT - CREW_HALF, 0.0)


func _commit(to_ball: Vector3) -> Node3D:
	_facing(to_ball)
	return _commit_lane(Threat.Type.LANE, global_position, to_ball, LANE_LENGTH, LANE_WIDTH)


func _go_live() -> void:
	var lane := telegraph()
	var ball := _real_ball()
	if lane == null or not lane.contains(ball):
		broken_by = "missed"
		return
	if not _catch(0.0, Vector3.ZERO, anchor()):
		broken_by = "ignored"
		return
	rope = maxf(MIN_ROPE, _flat(ball - anchor()).length())
	if _player().heft() >= rating:
		snaps += 1
		holds.snap(self, "speed")


func _live(delta: float) -> bool:
	if not _holding():
		return false
	var player = _player()
	if player.planar_velocity().length() >= SNAP_SPEED:
		snaps += 1
		holds.snap(self, "speed")
		return false
	rope = maxf(MIN_ROPE, rope - REEL * delta)
	var out := _flat(_real_ball() - anchor())
	var accel := Vector3.ZERO
	if out.length() > rope:
		var dir := out.normalized()
		accel -= dir * (out.length() - rope) * SPRING
		var radial: float = player.planar_velocity().dot(dir)
		if radial > 0.0:
			accel -= dir * radial * RADIAL_DAMP
	_pull(accel)
	return true


func _on_broken(method: String) -> void:
	if method == "boost" or method == "hook":
		snaps += 1
	if fleet == null:
		return
	if method == "hook":
		fleet.discover("hook_out", _real_ball())
	else:
		fleet.discover("tether_snap", _real_ball())


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
