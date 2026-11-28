extends "res://src/combat/counter.gd"

const LANE_LENGTH := 18.0
const LANE_WIDTH := 2.4
const PULL := 6.0
const DOWN := 14.0
const WINCH := 2.0
const NEAR := 1.5
const POST_HEIGHT := 1.2
const HP := 60.0

var winched := 0
static var _warned_asset := false
static var _shared: Dictionary = {}
var _windup_rig: Skeleton3D
var _reel: MeshInstance3D


func _configure(threat: float) -> void:
	_set_health(HP * threat)
	scrap_value = 5
	weight = 2.0
	walk_speed = 2.6
	keep_near = 6.0
	warn_seconds = 1.0
	live_seconds = WINCH + 0.1
	rest_seconds = 3.5
	attack_range = 20.0


func _build_tool() -> void:
	var parts := _parts()
	if not parts.is_empty():
		_crew.free()
		_crew = null
		_base_color = Color.WHITE
		_material.albedo_color = Color.WHITE
		_material.vertex_color_use_as_albedo = true
		_windup_rig = parts.rig.instantiate() as Skeleton3D
		_visual_parent().add_child(_windup_rig)
		for part in parts.meshes:
			var mi := MeshInstance3D.new()
			mi.name = part.name
			mi.mesh = part.mesh
			mi.transform = part.xform
			if part.flash >= 0:
				mi.set_surface_override_material(part.flash, _material)
			_visual_parent().add_child(mi)
			if part.skin != null:
				mi.skin = part.skin
				mi.skeleton = mi.get_path_to(_windup_rig)
			if part.name == "DeckReel":
				_reel = mi
		return
	_cylinder(0.55, 0.9, Palette.CHARCOAL, Vector3(0.0, 0.9, -CREW_RADIUS - 0.5))
	_box(Vector3(0.3, POST_HEIGHT * 2.0, 0.3), Palette.CHARCOAL, Vector3(0.0, POST_HEIGHT, -CREW_RADIUS - 0.5))


static func _parts() -> Dictionary:
	if not _shared.is_empty():
		return _shared
	var path := "res://assets/models/world_three/enemy_anchor_crew.glb"
	if not ResourceLoader.exists(path):
		return _shared
	var packed := load(path) as PackedScene
	if packed == null:
		return _shared
	var scene := packed.instantiate()
	var rig := scene.find_child("Skeleton3D", true, false) as Skeleton3D
	if rig == null:
		scene.free()
		return _shared
	var reel := scene.find_child("DeckReel", true, false) as MeshInstance3D
	if reel == null or reel.mesh == null:
		scene.free()
		if not _warned_asset:
			_warned_asset = true
			push_warning("anchor_crew: DeckReel missing; keeping greybox crew")
		return _shared
	var painted := PaletteMaterials.solid(Color.WHITE)
	painted.vertex_color_use_as_albedo = true
	var meshes := []
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var mesh: Mesh = mi.mesh.duplicate()
		var flash := -1
		for i in mesh.get_surface_count():
			var surface_material := mesh.surface_get_material(i)
			if surface_material == null and not _warned_asset:
				_warned_asset = true
				push_warning("anchor_crew: surface has no material; using default finish")
			if surface_material != null and surface_material.resource_name == "fleet_paint":
				flash = i
			mesh.surface_set_material(i, painted)
		meshes.append({"name": mi.name, "mesh": mesh, "xform": mi.transform,
			"flash": flash, "skin": mi.skin})
	for child in rig.get_children():
		child.free()
	rig.get_parent().remove_child(rig)
	var packed_rig := PackedScene.new()
	packed_rig.pack(rig)
	rig.free()
	_shared = {"rig": packed_rig, "meshes": meshes}
	scene.free()
	return _shared


func _pose() -> void:
	if _windup_rig == null:
		return
	var holding := _holding()
	var progress := clampf(_t / warn_seconds, 0.0, 1.0) if phase == Phase.WARN else (1.0 if holding else 0.0)
	var brace := _windup_rig.find_bone("CrewBrace")
	var rest := _windup_rig.get_bone_rest(brace)
	_windup_rig.set_bone_pose_rotation(brace, (Basis(Vector3.RIGHT, deg_to_rad(8.0) * progress) * rest.basis).get_rotation_quaternion())
	_windup_rig.set_bone_pose_position(brace, rest.origin + Vector3(0.0, -0.08 * progress, 0.0))
	for i in 3:
		var tab := _windup_rig.find_bone("ClutchTab" + str(i))
		var angle := TAU * i / 3.0
		_windup_rig.set_bone_pose_position(tab, _windup_rig.get_bone_rest(tab).origin + Vector3(0.0, cos(angle), sin(angle)) * 0.09 * progress)
	var hook := _windup_rig.find_bone("HostileHook")
	_windup_rig.set_bone_pose_position(hook, _windup_rig.get_bone_rest(hook).origin + Vector3(0.0, 0.0, -0.20 * progress))
	_reel.rotation.x = _t * TAU if holding else 0.0


func anchor() -> Vector3:
	return global_position + Vector3.UP * POST_HEIGHT


func _commit(to_ball: Vector3) -> Node3D:
	_facing(to_ball)
	return _commit_lane(Threat.Type.LANE, global_position, to_ball, LANE_LENGTH, LANE_WIDTH)


func _go_live() -> void:
	var lane := telegraph()
	if lane == null or not lane.contains(_real_ball()) or not _catch(WINCH, Vector3.ZERO, anchor()):
		broken_by = "missed"
		return
	winched += 1


func _live(_delta: float) -> bool:
	if not _holding():
		return false
	var to := anchor() - _real_ball()
	to.y = 0.0
	var accel := to.normalized() * PULL if to.length() > NEAR else Vector3.ZERO
	if not _player().state.on_floor():
		accel.y = -DOWN
	_pull(accel)
	return true


func _on_broken(_method: String) -> void:
	if fleet != null:
		fleet.discover("deck_winch", _real_ball())
